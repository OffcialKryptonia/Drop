<?php

namespace App\Http\Resources;

use App\Models\Coupon;
use App\Models\Region;
use App\Models\Service;
use Illuminate\Http\Resources\Json\JsonResource;
use App\Models\Sos;
use Grimzy\LaravelMysqlSpatial\Types\Point;
use Illuminate\Database\Eloquent\Builder;
class DriverDashboardResource extends JsonResource
{
    public function toArray($request)
    {
        $user = auth()->user();
        $schedule_ride_request = $this->driverRideRequestDetail()->where('is_schedule', 1)->where('status', '!=', 'canceled')
                    ->where(function ($q) {
                        $q->where('status', '!=', 'completed') // 1. Not completed
                        ->orWhere(function ($q2) {           // 2. Completed but unpaid
                            $q2->where('status', 'completed')
                                ->whereHas('payment', function ($q3) {
                                    $q3->where('payment_status', 'pending');
                                });
                        });
                    })->orderBy('schedule_datetime', 'asc')->get();

        $on_ride_request = $this->driverRideRequestDetail()->whereNotIn('status', ['canceled'])->where('is_driver_rated',false)
                            ->latest()->first();

        $pending_payment_ride_request = $this->driverRideRequestDetail()->where('status', 'completed')->where('is_schedule', '!=', 1)->where('is_driver_rated',true)
                        ->whereHas('payment',function ($q) {
                            $q->where('payment_status', 'pending');
                        })->latest()->first();

        $rider = isset($on_ride_request) && optional($on_ride_request->rider) ? $on_ride_request->rider :  null;
        if ($pending_payment_ride_request && $pending_payment_ride_request->is_schedule == 1) {
            $payment = null;
        } else {
            $payment = optional($pending_payment_ride_request)->payment;
        }
        // $payment = isset($pending_payment_ride_request) && optional($pending_payment_ride_request->payment) ? $pending_payment_ride_request->payment : null;

        $enriched_schedule_ride_request = $schedule_ride_request->map(function ($ride) {
            $ride->estimated_price = calculateEstimatedServiceFromRide($ride);
            return $ride;
        });
        $driver_distance_to_pickup = isset($on_ride_request) ? getDriverPickupDistance($on_ride_request) : null;
        if ($on_ride_request && $on_ride_request->is_schedule == 1 && $on_ride_request->status != 'new_ride_requested') {
            $on_ride_request = null;
        }

        if (!empty($on_ride_request)) {
            $service = Service::where('id', $on_ride_request->service_id)->first();
            if ($service) {
                if ($service->region_id) {
                    $service = Service::where('region_id', $service->region_id)->where('id', $service->id)->first();
                }

                if( $on_ride_request->start_latitude && isset($on_ride_request->start_latitude) && $on_ride_request->start_longitude && isset($on_ride_request->start_longitude) )
                {
                    $latitude = (float) $request->pick_lat;
                    $longitude = (float) $request->pick_lat;

                    $point = Region::where('status', 1)
                        ->get()
                        ->filter(function ($region) use ($latitude, $longitude) {
                            $coordinates = $region->coordinates;

                            if (is_string($coordinates)) {
                                $coordinates = json_decode($coordinates, true);
                            }

                            if (is_array($coordinates) && count($coordinates) >= 3) {
                                pointInPolygon([$latitude, $longitude], $coordinates);
                            }
                        });

                    $service->whereHas('region',function ($q) use($point) {
                        $q->where('status', 1)->whereJsonContains('coordinates', $point);
                    });
                }

                if ($on_ride_request->coupon_code) {
                    $coupon = Coupon::find($on_ride_request->coupon_code);
                    $response = verify_coupon_code($coupon->code);

                    if ($response['status'] != 200) {
                        return json_custom_response($response, $response['status']);
                    }
                }

                if (!empty($on_ride_request->multi_drop_location)) {
                    $drop_latlng = json_decode($on_ride_request->multi_drop_location, true);

                    if (is_array($drop_latlng)) {
                        foreach ($drop_latlng as $index => $location) {
                            if (!is_array($location) || !isset($location['lat'], $location['lng'])) {
                                throw new \Exception("Invalid location data at index {$index}: lat and lng are required.");
                            }
                        }

                        $place_details = mighty_get_distance_matrix_multiple_destination(
                            $on_ride_request->start_latitude,
                            $on_ride_request->start_longitude,
                            $on_ride_request->end_latitude,
                            $on_ride_request->end_longitude,
                            $drop_latlng
                        );

                        $dropoff_distance_in_meters = $place_details['distance'];
                        $dropoff_time_in_seconds = $place_details['duration'];
                    } else {
                        throw new \Exception("multi_drop_location must be a valid JSON array.");
                    }
                } else {
                    $place_details = mighty_get_distance_matrix(
                        $on_ride_request->start_latitude,
                        $on_ride_request->start_longitude,
                        $on_ride_request->end_latitude,
                        $on_ride_request->end_longitude
                    );

                    $dropoff_distance_in_meters = distance_value_from_distance_matrix($place_details);
                    $dropoff_time_in_seconds = duration_value_from_distance_matrix($place_details);
                }

                $distance_in_unit = $dropoff_distance_in_meters ? $dropoff_distance_in_meters / 1000 : 0;

                $request['distance_in_unit'] = $distance_in_unit;
                $request['dropoff_distance_in_meters'] = $dropoff_distance_in_meters;
                $request['dropoff_time_in_seconds'] = $dropoff_time_in_seconds;

                $service->start_latitude = $on_ride_request->start_latitude;
                $service->start_longitude = $on_ride_request->start_longitude;
                $service->end_latitude = $on_ride_request->end_latitude;
                $service->end_longitude = $on_ride_request->end_longitude;

                $services = collect([$service]);
                // $items = EstimateServiceResource::collection($services);
            }
        }

        $unread_count = 0;
        $unread_total_count = 0;

        $unread_query = $user->notifications()->whereNull('read_at');
        $unread_total_count = $unread_query->count();

        if ($user->last_notification_seen) {
            $unread_count = (clone $unread_query)
                ->where('created_at', '>', $user->last_notification_seen)
                ->count();
        }

        return [
            'id'                => $this->id,
            'display_name'      => $this->display_name,
            'email'             => $this->email,
            'username'          => $this->username,
            'user_type'         => $this->user_type,
            'profile_image'     => getSingleMedia($this, 'profile_image',null),
            'status'            => $this->status,
            'multi_drop_location'            => json_decode($this->multi_drop_location),
            'ride_has_bid'      => $this->driverRideRequestDetail()->latest()->first()?->ride_has_bid === 1 ? 1 : 0,
            'latitude'          => $this->latitude,
            'longitude'         => $this->longitude,
            'schedule_ride_request' => isset($enriched_schedule_ride_request) ? RideRequestResource::collection($enriched_schedule_ride_request) : null,
            'on_ride_request'   => isset($on_ride_request) ? new RideRequestResource($on_ride_request) : null,
            'rider'             => isset($rider) ? new UserResource($rider) : null,
            'payment'           => isset($payment) ? new PaymentResource($payment) : null,
            'service_marker'     => getServiceSingleMedia($this->service, 'service_marker',null),
            'all_unread_count' => $unread_count,
            'driver_distance_to_pickup' => $driver_distance_to_pickup['distance'] ?? 0,
            'driver_duration_to_pickup' => $driver_distance_to_pickup['duration'] ?? 0,
        ];
    }
}

<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;
use App\Models\Sos;

class RiderDashboardResource extends JsonResource
{
    public function toArray($request)
    {
        $user = auth()->user();
        $ride_request = $this->riderRideRequestDetail()->where('is_schedule', 0)->whereNotIn('status', ['canceled','completed'])->where('is_rider_rated', 0)->latest()->first();
        // $schedule_ride_request = $this->riderRideRequestDetail()->where('is_schedule', 1)->whereNotIn('status', ['canceled'])->where('is_rider_rated', 0)->orderBy('schedule_datetime','asc')->get();
         $schedule_ride_request = $this->riderRideRequestDetail()->where('is_schedule', 1)->where('status', '!=', 'canceled')
                                ->where(function ($q) {
                                $q->where('status', '!=', 'completed')
                                ->orWhere(function ($q2) {
                                    $q2->where('status', 'completed')
                                        ->whereHas('payment', function ($q3) {
                                            $q3->where('payment_status', 'pending');
                                        });
                                });
                            })
                            ->orderBy('schedule_datetime', 'asc')
                            ->get();
        $on_ride_request = $this->riderRideRequestDetail()->where('is_schedule', 0)->whereNotIn('status', ['canceled'])
                        // ->whereHas('payment',function ($q) {
                        //     $q->where('payment_status', 'pending');
                        // })
                        ->latest()
                        ->first();
        $on_ride_request_data = $this->riderRideRequestDetail()->whereNotNull('driver_id')->where('is_schedule', 1)->whereNotIn('status', ['canceled'])
                        // ->whereHas('payment',function ($q) {
                        //     $q->where('payment_status', 'pending');
                        // })
                        ->latest()
                        ->first();

        $pending_payment_ride_request = $this->riderRideRequestDetail()->where('status', 'completed')->where('is_rider_rated',1)
                        ->whereHas('payment',function ($q) {
                            $q->where('payment_status', 'pending');
                        })
                        ->latest()
                        ->first();

        // $driver = isset($on_ride_request) && optional($on_ride_request->driver) ? $on_ride_request->driver : null;
        $driver = null;

        if ($on_ride_request && $on_ride_request->driver) {
            $driver = $on_ride_request->driver;
        } elseif ($on_ride_request_data && $on_ride_request_data->driver) {
            $driver = $on_ride_request_data->driver;
        }

        // $payment = isset($pending_payment_ride_request) && optional($pending_payment_ride_request->payment) ? $pending_payment_ride_request->payment : null;
        $rider = isset($on_ride_request) && optional($on_ride_request->rider) ? $on_ride_request->rider :  null;
        if ($pending_payment_ride_request && $pending_payment_ride_request->is_schedule == 1) {
            $payment = null;
        } else {
            $payment = optional($pending_payment_ride_request)->payment;
        }

        $is_rider_rated = isset($on_ride_request) ? $on_ride_request->rideRequestRating()->where('driver_id', $on_ride_request->driver_id)->first() : null;

        $multiDropLocation = !empty($this->multi_drop_location) ? json_decode($this->multi_drop_location) : json_decode($this->drop_location);
        $type = isset($request->type) ? $request->type : null;
            if($type == "markas_read"){
                if(count($user->unreadNotifications) > 0 ) {
                    $user->unreadNotifications->markAsRead();
                }
            }

        // $unread_count = 0;
        // $unread_total_count = 0;

        // $last_seen = $user->last_notification_seen;
        // $unread_query = $user->notifications()->whereNull('read_at');
        // $unread_total_count = $unread_query->count();

        //  if ($user->last_notification_seen) {
        //      $unread_count = $unread_query->where('created_at', '>', $last_seen)->count();
        //  }


        $unread_count = 0;
        $unread_total_count = 0;

        $unread_query = $user->notifications()->whereNull('read_at');
        $unread_total_count = $unread_query->count();

        if ($user->last_notification_seen) {
            $unread_count = (clone $unread_query)
                ->where('created_at', '>', $user->last_notification_seen)
                ->count();
        }


        // $all_unread_count = isset($user->unreadNotifications) ? $user->unreadNotifications->count() : 0;
        // $driver_distance_to_pickup = getDriverPickupDistance($this);

        $coinValue = SettingData('scratch_card', 'enable_scratch_card') ?? null;

        return [
            'id'                => $this->id,
            'display_name'      => $this->display_name,
            'email'             => $this->email,
            'username'          => $this->username,
            'user_type'         => $this->user_type,
            'profile_image'     => getSingleMedia($this, 'profile_image',null),
            'status'            => $this->status,
            'multi_drop_location' => $multiDropLocation,
            'ride_has_bids' => $ride_request->ride_has_bid ?? 0,
            // 'sos'               => Sos::mySOs()->get(),
            'time_zone'         =>$this->timezone ?? 'UTC',
            'ride_request'      => isset($ride_request) ? new RideRequestResource($ride_request) : null,
            'schedule_ride_request' => RideRequestResource::collection($schedule_ride_request),
            'on_ride_request' => $on_ride_request && $on_ride_request->is_rider_rated == 0 ? new RideRequestResource($on_ride_request) : null,
            'driver'            => isset($driver) ? new DriverResource($driver) : null,
            'payment'           => isset($payment) ? new PaymentResource($payment) : null,
            'service_marker'     => $on_ride_request ? getServiceSingleMedia($on_ride_request->service , 'service_marker',null) : null,
            'all_unread_count' => $unread_count,
            'enable_scratch_card' => (bool) $coinValue,
        ];
    }
}

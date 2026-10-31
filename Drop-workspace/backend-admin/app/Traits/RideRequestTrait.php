<?php

namespace App\Traits;

use Illuminate\Http\Request;
use App\Models\RideRequest;
use App\Models\User;
use App\Models\Setting;
use App\Notifications\CommonNotification;
use App\Notifications\RideNotification;
use App\Jobs\NotifyViaMqtt;
use App\Http\Resources\RideRequestResource;
use App\Models\Airport;
use App\Models\ManageZone;
use App\Models\ZonePrice;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;

trait RideRequestTrait {

    public function acceptDeclinedRideRequest($ride_request,$request_data = null)
    {
        // \Log::info("Accepting ride request {$ride_request->id} in acceptDeclinedRideRequest()");
        $user_type = auth()->user()->user_type ?? null;
        $unit = $ride_request->distance_unit ?? 'km';
        if (!empty($ride_request->driver_id)) {

            $data['riderequest_in_driver_id'] = null;
            $data['riderequest_in_datetime']  = Carbon::now()->format('Y-m-d H:i:s');
            $totalAmountNotify = $ride_request->total_amount - $ride_request->admin_commission;
            $notification_data = [
                'id' => $ride_request->id,
                'type' => 'new_ride_requested',
                'data' => [
                    'rider_id'   => $ride_request->rider_id,
                    'rider_name' => optional($ride_request->rider)->display_name ?? '',
                ],
                // 'message' => __('message.new_ride_requested'),
                'message' => __('message.subject_data', ['distance' => $ride_request->distance , 'distance_unit' => $unit, 'duration' => round($ride_request->duration,2) ,'currency_symbol' => $ride_request->currency_symbol ?? ' ','total_amount' => $totalAmountNotify ]),
                'subject' => __('message.ride.new_ride_requested'),
            ];

            $driver = User::find($ride_request->driver_id);
            if ($driver) {
                $driver->notify(new CommonNotification($notification_data['type'], $notification_data));
            }

            $ride_request->fill($data)->update();
        } else {

            $unit = $ride_request->distance_unit ?? 'km';
            $unit_value = convertUnitvalue($unit);
            $radius = Setting::where('type','DISTANCE')->where('key','DISTANCE_RADIUS')->pluck('value')->first() ?? 50;

            $latitude = $ride_request->start_latitude;
            $longitude = $ride_request->start_longitude;

            $cancelled_driver_ids = $ride_request->cancelled_driver_ids ?: [];

            if (request()->has('is_accept') && request('is_accept') == 0) {
                array_push($cancelled_driver_ids, auth()->user()->id);
            }
            $minumum_amount_get_ride = SettingData('wallet', 'min_amount_to_get_ride') ?? null;

            $nearby_driver = User::selectRaw("id, user_type, player_id, latitude, longitude, ( $unit_value * acos( cos( radians($latitude) ) * cos( radians( latitude ) ) * cos( radians( longitude ) - radians($longitude) ) + sin( radians($latitude) ) * sin( radians( latitude ) ) ) ) AS distance")
                            ->where('user_type', 'driver')->where('status', 'active')->where('is_online',1)->where('is_available',1)
                            ->where('service_id', $ride_request->service_id )
                            ->whereNotIn('id', $cancelled_driver_ids)
                            ->having('distance', '<=', $radius)
                            ->orderBy('distance','asc');
            if( $minumum_amount_get_ride != null ) {
                $nearby_driver = $nearby_driver->whereHas('userWallet', function($q) use($minumum_amount_get_ride) {
                    $q->where('total_amount', '>=', $minumum_amount_get_ride);
                });
            }
            $nearby_driver = $nearby_driver->first();

            // \Log::info('nearby_driver-'.$nearby_driver);

            if( $nearby_driver != null )
            {
                $totalAmountNotify = $ride_request->total_amount - $ride_request->admin_commission;
                $data['riderequest_in_driver_id'] = $nearby_driver->id;
                $data['riderequest_in_datetime'] = Carbon::now()->format('Y-m-d H:i:s');
                // $notification_data = [
                //     'id' => $ride_request->id,
                //     'type' => 'new_ride_requested',
                //     'data' => [
                //         'rider_id' => $ride_request->rider_id,
                //         'rider_name' => optional($ride_request->rider)->display_name ?? '',
                //     ],

                //     'message' => __('message.subject_data', ['distance' => $ride_request->distance , 'distance_unit' => $unit, 'duration' => round($ride_request->duration,2) ,'currency_symbol' => $ride_request->currency_symbol ?? ' ','total_amount' => $totalAmountNotify ]),
                //     'subject' => __('message.new_ride_requested'),
                // ];
                // $notify_data = new \stdClass();
                // $notify_data->success = true;
                // $notify_data->success_type = $ride_request->status;
                // $notify_data->success_message = __('message.ride.new_ride_requested');
                // $notify_data->result = new RideRequestResource($ride_request);

                // $nearby_driver->notify(new CommonNotification($notification_data['type'], $notification_data));
                // dispatch(new NotifyViaMqtt('new_ride_request_'.$nearby_driver->id, json_encode($notify_data), $nearby_driver->id));
                sendNotificationForNewRide($ride_request,$nearby_driver);

            } else {
                $data['riderequest_in_driver_id'] = null;
                $data['riderequest_in_datetime'] = null;
            }

            $data['cancelled_driver_ids'] = $cancelled_driver_ids;
            // $data['status'] = $ride_request->status == 'driver_declined' ? 'finding_drivers' : 'driver_not_found';
            // $data['cancelled_driver_ids'] = array_key_exists('cancelled_driver_ids',$request_data) ? $request_data['cancelled_driver_ids'] : null;
            $ride_request->fill($data)->update();
            // sleep(3);
            // $history_data = [
            //     'history_type'      => $data['status'],
            //     'ride_request_id'   => $ride_request->id,
            //     'ride_request'      => $ride_request,
            // ];

            // saveRideHistory($history_data);
        }
        try {
            $document_name = 'ride_' . $ride_request->id;
            // $collectionName = env('RIDE_COLLECTION');
            $collectionName = config('services.firestore.ride_collection');
            $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document($document_name);

            if ($firebaseData) {
                $rideData = [
                    'driver_ids' => [
                        $data['riderequest_in_driver_id']
                            ?? $ride_request->riderequest_in_driver_id
                            ?? $ride_request->driver_id
                    ],
                    'on_rider_stream_api_call' => 1,
                    'on_stream_api_call' => 1,
                    'ride_id' => $ride_request->id,
                    'rider_id' => $ride_request->rider_id,
                    'status' => $ride_request->status,
                    'payment_status' => '',
                    'payment_type' => '',
                    'tips' => 0,
                    'book_by_admin' => ($user_type === 'admin') ? true : false,
                    'extra_charges_payment_method' => 0,

                ];

                $firebaseData->set($rideData);

                // $nearby_driver->notify(new RideNotification($notification_data));
                // if ($nearby_driver) {
                //     $nearby_driver->notify(new CommonNotification($notification_data['type'], $notification_data));
                // } else {
                //     return null;
                //     // \Log::error('Nearby driver is null. Cannot send notification');
                // }
            } else {
                return null;
            }
        } catch (\Exception $e) {
            // \Log::error('Error from trait 110: ' . $e->getMessage());
            // \Log::error('Error from trait 110: ' . $e->getMessage(), [
            //     'trace' => $e->getTraceAsString()
            // ]);
            return null;
        }
        return $ride_request;
    }

    public function notifyDriverForRide($ride_request)
    {
        $nearby_driver = $ride_request->riderequest_in_driver ?? null;
        if( $nearby_driver != null )
        {
            $data['riderequest_in_driver_id'] = $nearby_driver->id;
            // $notification_data = [
            //     'id' => $ride_request->id,
            //     'type' => 'new_ride_requested',
            //     'data' => [
            //         'rider_id' => $ride_request->rider_id,
            //         'rider_name' => optional($ride_request->rider)->display_name ?? '',
            //     ],
            //     'message' => __('message.new_ride_requested'),
            //     'subject' => __('message.ride.new_ride_requested'),
            // ];
            $notify_data = new \stdClass();
            $notify_data->success = true;
            $notify_data->success_type = $ride_request->status;
            $notify_data->success_message = __('message.ride.new_ride_requested');
            $notify_data->result = new RideRequestResource($ride_request);

            try {
                $document_name = 'ride_' . $ride_request->id;
                $collectionName = config('services.firestore.ride_collection');
                $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document($document_name);

                if ($firebaseData) {
                    $rideData = [
                        'driver_id' => $data['riderequest_in_driver_id'] ?? $ride_request->riderequest_in_driver_id,
                        'on_rider_stream_api_call' => 1,
                        'on_stream_api_call' => 1,
                        'ride_id' => $ride_request->id,
                        'rider_id' => $ride_request->rider_id,
                        'status' => $ride_request->status,
                        'payment_status' => '',
                        'payment_type' => '',
                        'tips' => 0,
                    ];

                    $firebaseData->set($rideData);

                    // $nearby_driver->notify(new RideNotification($notification_data));
                    if ($nearby_driver) {
                        // $nearby_driver->notify(new CommonNotification($notification_data['type'], $notification_data));
                        sendNotificationForNewRide($ride_request,$nearby_driver);

                    } else {
                        return null;
                        // \Log::error('Nearby driver is null. Cannot send notification');
                    }
                } else {
                    \Log::info('Document does not exist: ' . $document_name);
                    return null;
                }
            } catch (\Exception $e) {
                \Log::error('Error from trait 169: ' . $e->getMessage());
                return null;
            }
            // $nearby_driver->notify(new CommonNotification($notification_data['type'], $notification_data));
            // dispatch(new NotifyViaMqtt('new_ride_request_'.$nearby_driver->id, json_encode($notify_data), $nearby_driver->id));
        } else {
            $data['riderequest_in_driver_id'] = null;
            $data['riderequest_in_datetime'] = null;
        }
        $ride_request->fill($data)->update();
        return $ride_request;
    }

    public function findDrivers($ride_request)
    {
        $unit = $ride_request->distance_unit ?? 'km';
        $unit_value = convertUnitvalue($unit);
        $radius = Setting::where('type', 'DISTANCE')->where('key', 'DISTANCE_RADIUS')->pluck('value')->first() ?? 50;

        $latitude = $ride_request->start_latitude;
        $longitude = $ride_request->start_longitude;

        $cancelled_driver_ids = $ride_request->cancelled_driver_ids ?: [];
        $rejected_bid_driver_ids = $ride_request->rejected_bid_driver_ids ?: [];

        if (request()->has('is_accept') && request('is_accept') == 0) {
            array_push($cancelled_driver_ids, auth()->user()->id);
        }

        if (request()->has('is_bid_accept') && request('is_bid_accept') == 2) {
            array_push($rejected_bid_driver_ids, auth()->user()->id);
        }

        $minimum_amount_get_ride = SettingData('wallet', 'min_amount_to_get_ride') ?? null;

        // Fetch previously stored nearby_driver_ids from the database
        $stored_nearby_driver_ids = $ride_request->nearby_driver_ids ?: [];

        // Find nearby drivers if not already stored
        if (empty($stored_nearby_driver_ids)) {
            $nearby_drivers = User::selectRaw("id, user_type, player_id, latitude, longitude, ( $unit_value * acos( cos( radians($latitude) ) * cos( radians( latitude ) ) * cos( radians( longitude ) - radians($longitude) ) + sin( radians($latitude) ) * sin( radians( latitude ) ) ) ) AS distance")
                ->where('user_type', 'driver')
                ->where('status', 'active')
                ->where('is_online', 1)
                ->where('is_available', 1)
                ->where('service_id', $ride_request->service_id)
                ->whereNotIn('id', $cancelled_driver_ids)
                ->whereNotIn('id', $rejected_bid_driver_ids)
                ->having('distance', '<=', $radius);

            if ($minimum_amount_get_ride != null) {
                $nearby_drivers = $nearby_drivers->whereHas('userWallet', function ($q) use ($minimum_amount_get_ride) {
                    $q->where('total_amount', '>=', $minimum_amount_get_ride);
                });
            }

            $nearby_drivers = $nearby_drivers->get();

            if ($nearby_drivers->isEmpty()) {
                $this->updateFirebaseRideData($ride_request, []);
            }

            // Collect the IDs of the nearby drivers
            $totalAmountNotify = $ride_request->total_amount - $ride_request->admin_commission;
            $driver_ids = [];
            foreach ($nearby_drivers as $nearby_driver) {
                if ($nearby_driver->player_id) {
                    // $notification_data = [
                    //     'id' => $ride_request->id,
                    //     'type' => 'new_ride_requested',
                    //     'data' => [
                    //         'rider_id' => $ride_request->rider_id,
                    //         'rider_name' => optional($ride_request->rider)->display_name ?? '',
                    //     ],
                    //     'message' => __('message.subject_data', ['distance' => $ride_request->distance , 'distance_unit' => $unit, 'duration' => round($ride_request->duration,2) ,'currency_symbol' => $ride_request->currency_symbol ?? ' ','total_amount' => $totalAmountNotify ]),
                    //     'subject' => __('message.new_ride_requested'),
                    // ];
                    // $nearby_driver->notify(new CommonNotification($notification_data['type'], $notification_data));
                    sendNotificationForNewRide($ride_request,$nearby_driver);

                }

                $driver_ids[] = $nearby_driver->id;
            }

            // Save nearby_driver_ids in the database
            $ride_request->nearby_driver_ids = $driver_ids;
            $ride_request->rejected_bid_driver_ids = $rejected_bid_driver_ids;
            $ride_request->cancelled_driver_ids = $cancelled_driver_ids;
            $ride_request->save();
        } else {
            // If already stored, use the stored nearby_driver_ids
            $driver_ids = $stored_nearby_driver_ids;
        }

        // Update Firebase with nearby_driver_ids (from stored or newly found)
        $this->updateFirebaseRideData($ride_request, $driver_ids);

        $data['cancelled_driver_ids'] = $cancelled_driver_ids;
        $data['rejected_bid_driver_ids'] = $rejected_bid_driver_ids;
        $data['nearby_driver_ids'] = $driver_ids;
        $ride_request->fill($data)->update();

        return $ride_request;
    }

    private function updateFirebaseRideData($ride_request, $driver_ids)
    {
        $document_name = 'ride_' . $ride_request->id;
        $collectionName = config('services.firestore.ride_collection');
        $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document($document_name);

        if ($firebaseData) {
            $rideData = [
                // 'nearby_driver_ids' => $driver_ids,
                'driver_ids' => $driver_ids,
                'on_rider_stream_api_call' => 1,
                'on_stream_api_call' => 1,
                'ride_id' => $ride_request->id,
                'rider_id' => $ride_request->rider_id,
                'status' => $ride_request->status,
                'payment_status' => '',
                'payment_type' => '',
                'tips' => 0,
                'ride_has_bids' => $ride_request->ride_has_bid == 1 ? 1 : 0,
            ];

            $firebaseData->set($rideData);
        } else {
            \Log::info('Document does not exist: ' . $document_name);
        }
    }

     public function calculateFareAmount($request, $service)
    {
        // Get distance and duration (you might need to calculate this based on coordinates)
        $distance = $this->calculateDistance($request->start_latitude, $request->start_longitude,
                                        $request->end_latitude, $request->end_longitude);
        $duration = $this->estimateDuration($distance); // Implement based on your logic

        // Base fare calculation
        $base_fare = $service->base_fare;
        $minimum_fare = $service->minimum_fare;

        // Distance charges
        $chargeable_distance = max(0, $distance - $service->minimum_distance);
        $per_distance_charge = $chargeable_distance * $service->per_distance_charge;

        // Time charges (if applicable)
        $per_minute_drive_charge = $duration * $service->per_minute_drive;

        // // Weight charges for transport
        // $weight_charge = 0;
        // if ($request->type == 'transport' && isset($request->weight)) {
        //     $chargeable_weight = max(0, $request->weight - $service->minimum_weight);
        //     $weight_charge = $chargeable_weight * $service->per_weight_charge;
        // }

        // Calculate subtotal
        $subtotal = $base_fare + $per_distance_charge + $per_minute_drive_charge;

        // Apply minimum fare
        $subtotal = max($subtotal, $minimum_fare);

        // Add surge if applicable
        $surge_amount = 0; // Implement surge logic if needed

        // Add extra charges
        $extra_charges = $request->extra_charges_amount ?? 0;

        $total_amount = $subtotal + $surge_amount + $extra_charges;

        return [
            'distance' => $distance,
            'duration' => $duration,
            'base_fare' => $base_fare,
            'minimum_fare' => $minimum_fare,
            'per_distance_charge' => $per_distance_charge,
            'per_minute_drive_charge' => $per_minute_drive_charge,
            // 'weight_charge' => $weight_charge,
            'subtotal' => $subtotal,
            'surge_amount' => $surge_amount,
            'extra_charges_amount' => $extra_charges,
            'total_amount' => $total_amount
        ];
    }
    public function calculateDistance($lat1, $lon1, $lat2, $lon2)
    {
        // Haversine formula for distance calculation
        $earthRadius = 6371; // Earth's radius in kilometers

        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat/2) * sin($dLat/2) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon/2) * sin($dLon/2);
        $c = 2 * atan2(sqrt($a), sqrt(1-$a));

        return $earthRadius * $c;
    }
    public function estimateDuration($distance)
    {
        // Simple estimation: assume average speed of 30 km/h
        $averageSpeed = 30; // km/h
        return ($distance / $averageSpeed) * 60; // Convert to minutes
    }
     public function updateRideRequestAddresses($result, $request)
    {
        $pickupZonedata     = ManageZone::find($request->pickup_zone_id);
        $dropoffZonedata    = ManageZone::find($request->drop_zone_id);
        $pickupAirportdata  = Airport::find($request->pickup_airport_id);
        $dropoffAirportdata = Airport::find($request->drop_airport_id);

        if($request->trip_type == "zone_wise"){
            $zone = ZonePrice::where(['zone_pickup' => $request->pickup_zone_id, 'zone_dropoff' => $request->drop_zone_id])->first();
            if(!$zone && $request->discount != null){
                $zoneData = [
                    'ride_request_id' => $result->id,
                    'zone_pickup' => $request->pickup_zone_id,
                    'zone_dropoff' => $request->drop_zone_id,
                    'price' => $result->total_amount // Use calculated amount
                ];
                ZonePrice::create($zoneData);
            }
            $result->start_address = $pickupZonedata->name ?? null;
            $result->end_address = $dropoffZonedata->name ?? null;
            $result->update();
        }
        // elseif ($request->trip_type == "zone_to_airport") {
        //     $zone = ZonePrice::where(['zone_pickup' => $request->pickup_zone_id, 'airport_dropoff' => $request->drop_airport_id])->first();
        //     if(!$zone && $request->discount != null){
        //         $zoneData = [
        //             'ride_request_id' => $result->id,
        //             'zone_pickup' => $request->pickup_zone_id,
        //             'airport_dropoff' => $request->drop_airport_id,
        //             'price' => $result->total_amount
        //         ];
        //         ZonePrice::create($zoneData);
        //     }
        //     $result->start_address = $pickupZonedata->name ?? null;
        //     $result->end_address = $dropoffAirportdata->name ?? null;
        //     $result->zone_pickup = $request->pickup_zone_id;
        //     $result->airport_dropoff = $request->drop_airport_id;
        //     $result->update();
        // }
        // elseif ($request->trip_type == "airport_to_zone") {
        //     $zone = ZonePrice::where(['airport_pickup' => $request->pickup_airport_id, 'zone_dropoff' => $request->drop_zone_id])->first();
        //     if(!$zone && $request->discount != null){
        //         $zoneData = [
        //             'ride_request_id' => $result->id,
        //             'airport_pickup' => $request->pickup_airport_id,
        //             'zone_dropoff' => $request->drop_zone_id,
        //             'price' => $result->total_amount
        //         ];
        //         ZonePrice::create($zoneData);
        //     }
        //     $result->start_address = $pickupAirportdata->name ?? null;
        //     $result->end_address = $dropoffZonedata->name ?? null;
        //     $result->airport_pickup = $request->pickup_airport_id ?? null;
        //     $result->zone_dropoff = $request->drop_zone_id ?? null;
        //     $result->update();
        // }
        // elseif ($request->trip_type == "airport_pickup") {
        //     $result->start_address = $pickupAirportdata->name ?? null;
        //     $result->airport_pickup = $request->pickup_airport_id ?? null;
        //     $result->update();
        // }
        // elseif ($request->trip_type == "airport_drop") {
        //     $result->end_address = $dropoffAirportdata->name ?? null;
        //     $result->airport_dropoff = $request->drop_airport_id;
        //     $result->update();
        // }
    }

}

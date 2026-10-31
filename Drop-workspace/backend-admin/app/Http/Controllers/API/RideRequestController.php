<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\RideRequest;
use App\Models\RideRequestRating;
use App\Models\Coupon;
use App\Http\Resources\RideRequestResource;
use App\Http\Resources\ComplaintResource;
use Carbon\Carbon;
use App\Models\Payment;
use App\Models\Region;
use App\Models\RideRequestBid;
use App\Models\Service;
use App\Models\SurgePrice;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use App\Models\Wallet;
use App\Models\WalletHistory;
use Illuminate\Support\Facades\Validator;

class RideRequestController extends Controller
{
    public function getList(Request $request)
    {
        $riderequest = RideRequest::query();

        $riderequest->when(request('service_id'), function ($q) {
            return $q->where('service_id', request('service_id'));
        });

        $riderequest->when(request('is_schedule'), function ($q) {
            return $q->where('is_schedule', request('is_schedule'));
        });

        $riderequest->when(request('rider_id'), function ($q) {
            return $q->where('rider_id',request('rider_id'));
        });

        $riderequest->when(request('driver_id'), function ($query) {
            return $query->whereHas('driver',function ($q) {
                $q->where('driver_id',request('driver_id'));
            });
        });
        $order = 'desc';
        $riderequest->when(request('status'), function ($query) {
            if( request('status') == 'upcoming' ) {
                return $query->where('datetime', '>=', Carbon::now()->format('Y-m-d H:i:s'));
            } else if( request('status') == 'canceled' ) {
                return $query->whereIn('status',['canceled']);
            } else {
                return $query->where('status', request('status'));
            }
        });

        if( request('from_date') != null && request('to_date') != null ){
            $riderequest = $riderequest->whereBetween('datetime',[ request('from_date'), request('to_date')]);
        }

        $per_page = config('constant.PER_PAGE_LIMIT');
        if( $request->has('per_page') && !empty($request->per_page)){
            if(is_numeric($request->per_page))
            {
                $per_page = $request->per_page;
            }
            if($request->per_page == -1 ){
                $per_page = $riderequest->count();
            }
        }
        if( request('status') == 'upcoming' ) {
            $order = 'asc';
        }
        $riderequest = $riderequest->orderBy('datetime',$order)->paginate($per_page);
        $items = RideRequestResource::collection($riderequest);

        $response = [
            'pagination' => json_pagination_response($items),
            'data' => $items,
        ];

        return json_custom_response($response);
    }

    public function getDetail(Request $request)
    {
        $user = auth()->user();
        $id = $request->id;
        $riderequest = RideRequest::where('id',$id)->first();
        if( $riderequest == null )
        {
            return json_message_response( __('message.not_found_entry',['name' => __('message.riderequest') ]) );
        }

        $driver_distance_to_pickup = getDriverPickupDistance($riderequest);

        $ride_detail = new RideRequestResource($riderequest);

        $wallet_balance = Wallet::where('user_id', $riderequest->rider_id)->value('total_amount') ?? 0;

        $ride_history = optional($riderequest)->rideRequestHistory;
        $rider_rating = optional($riderequest)->rideRequestRiderRating();
        $driver_rating = optional($riderequest)->rideRequestDriverRating();

        $current_user = auth()->user();
        if(count($current_user->unreadNotifications) > 0 ) {
            $current_user->unreadNotifications->where('data.id',$id)->markAsRead();
        }

        $complaint = null;
        if($current_user->hasRole('driver')) {
            $complaint = optional($riderequest)->rideRequestDriverComplaint();
        }

        if($current_user->hasRole('rider')) {
            $complaint = optional($riderequest)->rideRequestRiderComplaint();
        }

        $service = Service::where('id', $riderequest->service_id)->first();

        if ($service) {
            if ($service->region_id) {
                $service = Service::where('region_id', $service->region_id)->where('id', $service->id)->first();
            }

            if( $riderequest->start_latitude && isset($riderequest->start_latitude) && $riderequest->start_longitude && isset($riderequest->start_longitude) )
            {
                $latitude = (float) $riderequest->start_latitude;
                $longitude = (float) $riderequest->start_longitude;

                $point = Region::where('status', 1)
                    ->get()
                    ->filter(function ($region) use ($latitude, $longitude) {
                        $coordinates = $region->coordinates;

                        if (is_string($coordinates)) {
                            $coordinates = json_decode($coordinates, true);
                        }

                        // Ensure coordinates are in proper format
                        if (is_array($coordinates) && count($coordinates) >= 3) {
                            pointInPolygon([$latitude, $longitude], $coordinates);
                        }
                    });

                $service->whereHas('region',function ($q) use($point) {
                    $q->where('status', 1)->whereJsonContains('coordinates', $point);
                });
            }

            if ($riderequest->coupon_code) {
                $coupon = Coupon::find($riderequest->coupon_code);
                $response = verify_coupon_code($coupon->code);

                if ($response['status'] != 200) {
                    return json_custom_response($response, $response['status']);
                }
            }

            if (!empty($riderequest->multi_drop_location)) {
                $drop_latlng = json_decode($riderequest->multi_drop_location, true); // Decode JSON string into an array
                $place_details = mighty_get_distance_matrix_multiple_destination(
                    $riderequest->start_latitude,
                    $riderequest->start_longitude,
                    $riderequest->end_latitude,
                    $riderequest->end_longitude,
                    $drop_latlng
                );
                $dropoff_distance_in_meters = $place_details['distance'];
                $dropoff_time_in_seconds = $place_details['duration'];
            } else {
                $place_details = mighty_get_distance_matrix(
                    $riderequest->start_latitude,
                    $riderequest->start_longitude,
                    $riderequest->end_latitude,
                    $riderequest->end_longitude
                );
                $dropoff_distance_in_meters = distance_value_from_distance_matrix($place_details);
                $dropoff_time_in_seconds = duration_value_from_distance_matrix($place_details);
            }

            $distance_in_unit = $dropoff_distance_in_meters ? $dropoff_distance_in_meters / 1000 : 0;

            $request['distance_in_unit'] = $distance_in_unit;
            $request['dropoff_distance_in_meters'] = $dropoff_distance_in_meters;
            $request['dropoff_time_in_seconds'] = $dropoff_time_in_seconds;
            // $request['coupon'] = $coupon;

            $service->start_latitude = $riderequest->start_latitude;
            $service->start_longitude = $riderequest->start_longitude;
            $service->end_latitude = $riderequest->end_latitude;
            $service->end_longitude = $riderequest->end_longitude;
            $service->multi_drop_location = $riderequest->multi_drop_location;

            // $services = collect([$service]);
            // $items = EstimateServiceResource::collection($services);

            $coinValue = SettingData('scratch_card', 'remaining_value') ?? 0;

            $randomValue = 0;

            if (!empty($coinValue)) {
                $valuesArray = array_map(  'intval', array_map('trim', explode(',', $coinValue)) );
                $randomValue = $valuesArray[array_rand($valuesArray)];
            }

            $pdfUrl = null;
            if($ride_detail->status == 'completed' ){
                $pdfUrl = route('ride-invoice', ['id' => $ride_detail->id]);
                if($user->user_type == 'driver'){
                 $pdfUrl = route('ride-invoice', ['id' => $ride_detail->id]);
                }else{
                    $pdfUrl = route('ride-rider-invoice', ['id' => $ride_detail->id]);
                }
            }

            $bid_data = RideRequestBid::where('ride_request_id',$id)->where('driver_id',$current_user->id)->first();
            if ($bid_data) {
                $bid_data->extra_charge_amount = $riderequest->extra_charges_amount ?? '';
            }
            $response = [
                'data' => $ride_detail,
                'coupon_discount' => $ride_detail->coupon_discount ?? '',
                'ride_history' => $ride_history,
                'rider_rating' => $rider_rating,
                'driver_rating' => $driver_rating,
                'complaint' => isset($complaint) ? new ComplaintResource($complaint) : null,
                'payment' => optional($ride_detail)->payment,
                'invoice_url' => $pdfUrl,
                'invoice_name' => 'Ride_' . $ride_detail->id,
                // 'estimated_price' => $items,
                'ride_has_bids' => $riderequest->ride_has_bid == 1 ? 1 : 0,
                'bid_data' => $bid_data ?? [],
                'driver_distance_to_pickup' => $driver_distance_to_pickup['distance'],
                'driver_duration_to_pickup' => $driver_distance_to_pickup['duration'],
                'rider_wallet_balance' => round($wallet_balance, 2),
                'coin_earnings' => $randomValue,
            ];
            return json_custom_response($response);
        }else{
            return json_custom_response([
                'status' => 404,
                'message' => 'Service not found for this ride request.',
            ], 404);
        }
    }

    public function calculateCommission($amount, $service)
    {
        $admin_commission = 0;
        $fleet_commission = 0;

        if ($service->commission_type === 'percentage') {
            $admin_commission = $amount * ($service->admin_commission / 100);
            $fleet_commission = $amount * ($service->fleet_commission / 100);
        } else {
            $admin_commission = $service->admin_commission;
            $fleet_commission = $service->fleet_commission;
        }

        $total_commission = $admin_commission + $fleet_commission;
        $driver_earning = $amount - $total_commission;

        return [
            'admin_commission' => $admin_commission,
            'fleet_commission' => $fleet_commission,
            'driver_earning' => $driver_earning,
            'total_commission' => $total_commission,
        ];
    }
    public function completeRideRequest(Request $request)
    {
        $id = $request->id;
        $ride_request = RideRequest::where('id',$id)->first();
        if( $ride_request == null ) {
            return json_message_response( __('message.not_found_entry',['name' => __('message.riderequest') ]) );
        }

        if( $ride_request->status == 'completed' ) {
            return json_message_response( __('message.ride.completed'));
        }

        $ride_request->update([
            'end_latitude'  => $request->end_latitude,
            'end_longitude' => $request->end_longitude,
            'end_address'   => $request->end_address,
            'extra_charges' => $request->extra_charges,
            'extra_charges_amount'  => $request->extra_charges_amount
        ]);

        $distance_unit = $ride_request->distance_unit ?? 'km';
        $extra_charges_amount  = $request->extra_charges_amount ?? 0;
        $tips           = $request->input('tips', 0);
        // $distance = $request->distance;
        $place_details = mighty_get_distance_matrix($request->start_latitude, $request->start_longitude,$request->end_latitude,$request->end_longitude);

        $distance = distance_value_from_distance_matrix($place_details) / 1000;

        if($distance_unit == 'mile') {
            $distance = km_to_mile($distance);
        }
        $service = $ride_request->service;

        $start_datetime = $ride_request->rideRequestHistory()->where('history_type', 'in_progress')->pluck('created_at')->first();
        $end_datetime   = $ride_request->rideRequestHistory()->where('history_type', 'completed')->pluck('created_at')->first();
        $ride_datetime  = Carbon::parse($ride_request->created_at);

        $duration = calculateRideDuration($start_datetime, $end_datetime);
         // Waiting Charge Calculation
            $arrived_time = $ride_request->rideRequestHistory()->where('history_type', 'arrived')->pluck('created_at')->first();
            $in_progress_time = $ride_request->rideRequestHistory()->where('history_type', 'in_progress')->pluck('created_at')->first();
            $waiting_charge = 0;
            $waiting_time = 0;
            $per_minute_waiting_charge = 0;

            if ($arrived_time && $in_progress_time) {
                $waiting_time = Carbon::parse($arrived_time)->diffInMinutes(Carbon::parse($in_progress_time));
                $free_limit = $service->waiting_time_limit ?? 0;
                $waiting_time = max(0, $waiting_time - $free_limit);

                $per_minute_waiting_charge = $service->per_minute_wait ?? 0;
                $waiting_charge = $waiting_time * $per_minute_waiting_charge;
            }

            $total_amount = $ride_request->total_amount;
            $ridefee = [];

            $ridefee['waiting_time_limit'] = $service->waiting_time_limit;
            $ridefee['per_minute_drive'] = $service->per_minute_drive;

            $ridefee['per_minute_waiting'] = $per_minute_waiting_charge;
            $ridefee['per_minute_waiting_charge'] = $waiting_charge;

            if( $ride_request->is_ride_for_other == 1 ) {
                $ridefee['is_rider_rated'] = true;
            }

            if ($ride_request->ride_has_bid == 1) {
                $ride_bid_data = $ride_request->approvedBids;
                if ($ride_bid_data) {
                    $ridefee['total_amount'] = $ride_bid_data->bid_amount;
                }
            }
            $ride_request->update(array_merge([
                'status'   => 'completed',
                'distance_travelled'  => $distance,
                'completed_trip_duration' => $duration,
                'service_data' => $service,
            ], $ridefee));

            Payment::create([
                    'rider_id'        => $ride_request->rider_id,
                    'driver_id'        => $ride_request->driver_id,
                    'ride_request_id' => $ride_request->id,
                    'payment_type'    => $ride_request->payment_type ?? 'cash',
                    'datetime'        => now(),
                    'payment_status'  => 'pending',
                    'total_amount'    => $total_amount,
                ]);
            $history_data = [
                'history_type'      => 'completed',
                'ride_request_id'   => $ride_request->id,
                'ride_request'      => $ride_request,
            ];
            saveRideHistory($history_data);
            $ride_request->driver->update(['is_available' => 1]);
            return json_message_response( __('message.ride.completed'));
    }

    public function verifyCoupon(Request $request)
    {
        $coupon_code = $request->coupon_code;

        $coupon = Coupon::where('code', $coupon_code)->first();
        $status = isset($coupon_code) ? 400 : 200;

        if($coupon != null) {
            $status = Coupon::isValidCoupon($coupon);
        }

        $response = couponVerifyResponse($status);

        return json_custom_response($response,$status);
    }

    public function rideRating(Request $request)
    {
        $ride_request = RideRequest::where('id',request('ride_request_id'))->first();

        $message = __('message.not_found_entry', ['name' => __('message.riderequest')]);

        if($ride_request == '') {
            return json_message_response( $message );
        }
        $data = $request->all();

        // Persist both ride participants so rating lists can always resolve
        // the rider and driver details regardless of who submitted the rating.
        $data['rider_id'] = $ride_request->rider_id;
        $data['driver_id'] = $ride_request->driver_id;

        $data['rating_by'] = auth()->user()->user_type;
        RideRequestRating::updateOrCreate([ 'id' => $request->id ], $data);

        if(auth()->user()->user_type =='rider') {
            $ride_request->update(['is_rider_rated' => true]);
            $msg = __('message.rated_successfully', ['form' => __('message.rider')]);
        }
        if(auth()->user()->user_type =='driver') {
            $ride_request->update(['is_driver_rated' => true]);
            $msg = __('message.rated_successfully', ['form' => __('message.driver')]);
        }
        if($ride_request->payment->payment_status == 'pending' && $request->has('tips') && request('tips') != null) {
            $ride_request->update(['tips' => request('tips')]);
        }

        // $notify_data = new \stdClass();
        // $notify_data->success = true;
        // $notify_data->success_type = 'rating';
        // $notify_data->success_message = $msg;
        // $notify_data->result = new RideRequestResource($ride_request);

        if( auth()->user()->hasRole('driver') ) {
            $this->updateFirestoreRideDocument($ride_request, 'driver');
            // dispatch(new NotifyViaMqtt('ride_request_status_'.$ride_request->rider_id, json_encode($notify_data)));
        }

        if( auth()->user()->hasRole('rider') ) {
            $this->updateFirestoreRideDocument($ride_request, 'rider');
            // dispatch(new NotifyViaMqtt('ride_request_status_'.$ride_request->driver_id, json_encode($notify_data)));
        }

        $message = __('message.save_form',[ 'form' => __('message.rating') ] );

        if($request->type == 'web_review') {
            return redirect()->route('ride.payment.detail');
        }

        return json_message_response($message);
    }

    public function placeAutoComplete(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'search_text' => 'required',
            'language' => 'required'
        ]);

        if ( $validator->fails() ) {
            $data = [
                'status' => 'false',
                'message' => $validator->errors()->first(),
                'all_message' =>  $validator->errors()
            ];

            return json_custom_response($data,400);
        }

        $google_map_api_key = env('GOOGLE_MAP_KEY');

        $payload = ['input' => $request->input('search_text')];

        if ($request->has('language')) {
            $payload['languageCode'] = $request->input('language');
        }

        $response = Http::withHeaders([
            'X-Goog-Api-Key' => $google_map_api_key,
            'Content-Type' => 'application/json'
        ])->post('https://places.googleapis.com/v1/places:autocomplete', $payload);
        return $response->json();
    }

    public function placeDetail(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'placeid' => 'required',
        ]);

        if ( $validator->fails() ) {
            $data = [
                'status' => 'false',
                'message' => $validator->errors()->first(),
                'all_message' =>  $validator->errors()
            ];

            return json_custom_response($data,400);
        }

        $google_map_api_key = env('GOOGLE_MAP_KEY');
        $placeId = $request->placeid;
        $apiUrl = "https://places.googleapis.com/v1/places/{$placeId}";

        $headers = [
            'Content-Type' => 'application/json',
            'X-Goog-Api-Key' => $google_map_api_key,
            'X-Goog-FieldMask' => 'id,displayName,formattedAddress,location'
        ];

        $response = Http::withHeaders($headers)->get($apiUrl);
        // $response = Http::get('https://maps.googleapis.com/maps/api/place/details/json?placeid='.$request->placeid.'&key='.$google_map_api_key);

        return $response->json();
    }

    public function getSurgePrice($ride_datetime) {
        if ($ride_datetime === null) {
            return null;
        }
        $ride_datetime = Carbon::parse($ride_datetime);
        $day = $ride_datetime->format('l');
        $current_time = $ride_datetime->format('H:i');

        $surge_prices = SurgePrice::where('day', $day)->get();

        foreach ($surge_prices as $surge) {
            $from_times = $surge->from_time;
            $to_times = $surge->to_time;

            foreach ($from_times as $index => $from_time) {
                $to_time = $to_times[$index];

                if (strtotime($current_time) >= strtotime($from_time) && strtotime($current_time) <= strtotime($to_time)) {
                    return $surge;
                }
            }
        }

        return "";
    }

    public function updateFirestoreRideDocument($ride_request, $role)
    {
        try {
            $document_name = 'ride_' . $ride_request->id;
            $collectionName = config('services.firestore.ride_collection');
            $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document($document_name);

            if ($firebaseData) {
                $rideData = [
                    'driver_ids' => [$ride_request->driver_id],
                    'on_rider_stream_api_call' => 1,
                    'on_stream_api_call' => 1,
                    'ride_id' => $ride_request->id,
                    'rider_id' => $ride_request->rider_id,
                    'status' => $ride_request->status,
                    'payment_status' => $ride_request->payment->payment_status,
                    'payment_type' => $ride_request->payment_type,
                    'tips' => $ride_request->tips ? 1 : 0,
                ];

                $firebaseData->set($rideData, ['merge' => true]);

                if ($ride_request->payment->payment_status === 'paid') {
                    sleep(3);
                    $firebaseData->delete();
                }
            } else {
                Log::info('Document does not exist: ' . $document_name);
                return null;
            }
        } catch (\Exception $e) {
            Log::error('Error updating Firestore document for Ride: ' . $e->getMessage());
        }
    }

    public function snapToRoads(Request $request)
    {
        if (!$request->has('path') || !is_array($request->path)) {
            return response()->json(['error' => 'Invalid path data'], 400);
        }

        $apiKey = env('GOOGLE_MAP_KEY');
        $url = "https://routes.googleapis.com/directions/v2:computeRoutes";

        // Parse the latitude and longitude from the path
        $coordinates = explode(',', $request->path[0]);
        $origin_lat = $coordinates[0];
        $origin_lng = $coordinates[1];

        $coordinates = explode(',', $request->path[1]);
        $destination_lat = $coordinates[0];
        $destination_lng = $coordinates[1];

        // Construct request body for the Routes API
        $requestBody = [
            "origin" => [
                "location" => [
                    "latLng" => ["latitude" => (float)$origin_lat, "longitude" => (float)$origin_lng]
                ]
            ],
            "destination" => [
                "location" => [
                    "latLng" => ["latitude" => (float)$destination_lat, "longitude" => (float)$destination_lng]
                ]
            ],
            "travelMode" => "DRIVE"
        ];
        try {
            $client = new \GuzzleHttp\Client();
            $response = $client->post($url, [
                'headers' => [
                    'Content-Type' => 'application/json',
                    'X-Goog-Api-Key' => $apiKey,
                    'X-Goog-FieldMask' => 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
                ],
                'json' => $requestBody
            ]);
            return response()->json(json_decode($response->getBody(), true));
        } catch (\Exception $e) {
            return response()->json(['error' => $e->getMessage()], 500);
        }
    }

    public function updateExtraChargePaymentMethod(Request $request)
    {
        $id = $request->id;
        $riderequest = RideRequest::where('id',$id)->first();
        if( $riderequest == null )
        {
            return json_message_response( __('message.not_found_entry',['name' => __('message.riderequest') ]) );
        }

        $riderequest->update([ 'extra_charges_payment_method' => $request->extra_charges_payment_method ?? 0 ]);

        $rideData = [ 'extra_charges_payment_method' => $request->extra_charges_payment_method ];

        $collectionName = config('services.firestore.ride_collection', 'rides');
        $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document('ride_' . $id);
        $firebaseData->set($rideData, ['merge' => true]);

        $riderequest->update([
            'extra_charges_payment_date' => Carbon::parse(date('Y-m-d H:i:s'))->setTimezone('UTC')->toDateTimeString(),
        ]);

        if($request->extra_charges_payment_method == 1) //payment method via wallet
        {
            $wallet = Wallet::where('user_id', $riderequest->rider_id)->first();
            $driver_wallet = Wallet::where('user_id', $riderequest->driver_id)->first();
            if($wallet != null) {
                $extra_charges_amount = $riderequest->extra_charges_amount;

                if($extra_charges_amount > $wallet->total_amount)
                {
                    return response()->json([ 'status' => false, 'message' => __('message.invalid_wallet_balance') ], 400);
                }
                $wallet->decrement('total_amount', $extra_charges_amount);
                $currency_code = SettingData('CURRENCY', 'CURRENCY_CODE') ?? 'USD';
                    $currency_data = currencyArray($currency_code);
                    $currency = strtolower($currency_data['code']);
                    //wallet amount debited from the rider
                    $rider_wallet_history = [
                        'user_id' => $riderequest->rider_id,
                        'type' => 'debit',
                        'currency' => $currency,
                        'transaction_type' => 'ride_fee',
                        'amount' => $extra_charges_amount,
                        'balance' => $wallet->total_amount,
                        'datetime'  => date('Y-m-d H:i:s'),
                        'ride_request_id' => $id,
                        'description' => __('message.additional_charge_amount'),
                    ];

                    WalletHistory::create($rider_wallet_history);

                    //wallet amount credited to the driver
                    $driver_wallet->total_amount += $extra_charges_amount;
                    $driver_wallet->save();
                    $rider_wallet_history = [
                        'user_id' => $riderequest->driver_id,
                        'type' => 'credit',
                        'currency' => $currency,
                        'transaction_type' => 'topup',
                        'amount' => $extra_charges_amount,
                        'balance' => $driver_wallet->total_amount,
                        'datetime'  => date('Y-m-d H:i:s'),
                        'ride_request_id' => $id,
                        'description' => __('message.extra_charged_paid'),
                    ];

                    WalletHistory::create($rider_wallet_history);

                return response()->json([ 'status' => true, 'message' => __('message.extra_payment_update_successfull') ], 200);

            } else {
                    $message = __('message.not_found_entry',['name' => __('message.wallet')]);
                    return json_message_response($message,400);
            }
        }

        return response()->json([ 'status' => true, 'message' => __('message.extra_payment_update_successfull') ], 200);

    }

    public function directionsPolyline(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'origin' => 'required',
            'destination' => 'required',
        ]);

        if ($validator->fails()) {
            return json_custom_response([
                'status' => false,
                'message' => $validator->errors()->first()
            ], 400);
        }

        $key = env('GOOGLE_MAP_KEY');

        $response = Http::get(
            'https://maps.googleapis.com/maps/api/directions/json',
            [
                'origin' => $request->origin,
                'destination' => $request->destination,
                'mode' => 'driving',
                'key' => $key,
            ]
        );

        $data = $response->json();

        return response()->json([ 'status' => true, 'polyline' => $data['routes'][0]['overview_polyline']['points'] ?? null ]);
    }
}

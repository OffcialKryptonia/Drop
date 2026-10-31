<?php

namespace App\Http\Controllers;

use App\DataTables\RideRequestDataTable;
use Illuminate\Http\Request;
use App\Models\RideRequest;
use App\Http\Requests\DispatchRequest;
use App\Models\Service;
use App\Models\Coupon;

use App\Traits\RideRequestTrait;
use App\Jobs\NotifyViaMqtt;
use App\Http\Resources\RideRequestResource;
use App\Models\Airport;
use App\Models\ManageZone;
use App\Models\Notification;
use Carbon\Carbon;
use App\Models\User;
use App\Models\RideRequestHistory;
use App\Models\ZonePrice;

class DispatchController extends Controller
{
    use RideRequestTrait;

    /**
     * Show the form for creating a new resource.
     *
     * @return \Illuminate\Http\Response
     */
     public function index(RideRequestDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.riderequest')] );
        $auth_user = authSession();
        $assets = ['datatable'];
        // $button = $auth_user->can('dispatch add') ? '<a href="'.route('dispatch.create').'" class="float-right btn btn-md border-radius-10 btn-outline-dark"><i class="fa fa-plus-circle"></i> '.__('message.book_now').'</a>' : '';
        $button = '';
        $rideRequestfilterButton = true;

        return $dataTable->render('global.datatable', compact('pageTitle', 'auth_user','button', 'rideRequestfilterButton'));

        // return $dataTable->render('global.datatable', compact('pageTitle','button','auth_user'));
    }
    public function create()
    {
        $pageTitle = __('message.book_now');
        $assets = ['map_place'];
        $auth_user = authSession();
        $zoneList = ManageZone::where('status', 'active')->get()->toArray();
        $button = $auth_user->can('riderequest list') ? '<a href="'.route('riderequest.index').'" class="float-right btn btn-sm border-radius-10 btn-primary me-2">'.__('message.list_form_title',['form' => __('message.riderequest')]).'</a>' : '';
        return view('dispatch.form', compact('pageTitle', 'assets', 'button','zoneList'));
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(DispatchRequest $request)
    {
        $data = $request->all();
        // Check if the rider has registred a riderequest already
        $rider_exists_riderequest = RideRequest::whereNotIn('status', ['canceled', 'completed'])->where('rider_id', request('rider_id'))->where('is_schedule', 0)->exists();

        if($rider_exists_riderequest) {
            return redirect()->back()->withError(__('message.rider_already_in_riderequest'));
        }

        // Check if the driver in riderequest already
        if( request('driver_id') != null ) {
            $driver_exists_riderequest = RideRequest::whereNotIn('status', ['canceled', 'completed'])->where('driver_id', request('driver_id'))->where('is_schedule', 0)->exists();

            if($driver_exists_riderequest) {

                return redirect()->back()->withError(__('message.driver_already_in_riderequest'));
            }
        }

        $coupon_code = $request->coupon_code;

        if( $coupon_code != null ) {
            $coupon = Coupon::where('code', $coupon_code)->first();
            $status = isset($coupon_code) ? 200 : 400;

            if($coupon != null) {
                $status = Coupon::isValidCoupon($coupon);
            }
            if( $status != 200 ) {
                $response = couponVerifyResponse($status);
                return json_custom_response($response,$status);
            } else {
                $data['coupon_code'] = $coupon->id;
                $data['coupon_data'] = $coupon;
            }
        }

        $service = Service::with('region')->where('id',$request->service_id)->first();

        $timezone = $service->region->timezone ?? 'UTC';

        if ($request->has('schedule_datetime') && !empty($request->schedule_datetime)) {
            $data['is_schedule'] = 1;
            $data['schedule_datetime'] = Carbon::parse($request->schedule_datetime)->setTimezone($timezone)->toDateTimeString();
        } else {
            $data['is_schedule'] = 0;
        }

        $data['datetime'] = Carbon::parse(date('Y-m-d H:i:s'))->setTimezone($timezone)->toDateTimeString();

        if( request()->has('driver_id') && request('driver_id') != null ) {
            $data['riderequest_in_driver_id'] = $data['driver_id'];
            $data['riderequest_in_datetime'] = $data['datetime'];
            $data['driver_id'] = request('driver_id');
            // unset($data['driver_id']);
        }

        $data['distance_unit'] = $service->region->distance_unit ?? 'km';
        $data['status'] = 'new_ride_requested';
        $data['payment_type'] = 'cash';

        $drop_locations = [];

        if (request()->has('multi_drop_location')) {
            $drop_locations = request('multi_drop_location'); // Mobile booking
        } elseif (request()->has('drop_location')) {
            $drop_location_data = request('drop_location');

            if (is_string($drop_location_data)) {
                $drop_location_data = json_decode($drop_location_data, true);
            }

            if (is_array($drop_location_data)) {
                $drop_locations = $drop_location_data;
            }
        }
        // Ensure drop locations are properly formatted
        if (!empty($drop_locations)) {
            foreach ($drop_locations as $key => $drop) {
                if (is_string($drop)) { // If any item is a JSON string, decode it
                    $decoded = json_decode($drop, true);
                    if (json_last_error() === JSON_ERROR_NONE) {
                        $drop_locations[$key] = $decoded;
                    }
                }
            }
        }
        // If there are multiple drop locations, use the function
        if (!empty(array_filter($drop_locations))) {
            $place_details = mighty_get_distance_matrix_multiple_destination(
                request('pick_lat'),
                request('pick_lng'),
                request('drop_lat'),
                request('drop_lng'),
                $drop_locations
            );
        } else {
            // Fallback to a single destination distance calculation
            $place_details = mighty_get_distance_matrix(
                request('start_latitude'),
                request('start_longitude'),
                request('end_latitude'),
                request('end_longitude')
            );
        }
        // Extract distance and duration
        $dropoff_distance_in_meters = $place_details['distance'] ?? 0;
        $dropoff_time_in_seconds = $place_details['duration'] ?? 0;




        $distance_in_unit = $request['distance'];

        if ($dropoff_distance_in_meters) {
            // Region->distance_unit == km ( convert meter to km )
            $distance_in_unit = $dropoff_distance_in_meters / 1000;
        }
        $service_data = $service;
        $service_data['distance_unit'] = $distance_in_unit;
        $date_time = now()->format('Y-m-d h:i');

        if (!empty($drop_locations)) {
            $data['drop_location'] = json_encode($drop_locations); // Convert array to JSON
        }
       $data['distance'] = $distance_in_unit ?? $request->distance;

        $duration_str = $request->duration;
        $duration_in_minutes = $dropoff_time_in_seconds
            ? round($dropoff_time_in_seconds / 60, 2)
            : (is_numeric($duration_str) ? (float)$duration_str : convertTimeStringToDoubleMinutes($duration_str));

        $data['duration'] = $duration_in_minutes;


        $message = __('message.save_form', ['form' => __('message.riderequest')]);

      switch ($request->trip_type) {
        case 'zone_wise':
            $data['zone_pickup'] = $request->input('pickup_zone_id');     // ✅
            $data['zone_dropoff'] = $request->input('drop_zone_id');      // ✅
            break;

        }

        $currency_symbol = SettingData('CURRENCY', 'CURRENCY_SYMBOL') ?? '$';
        $data['currency_symbol'] = $currency_symbol;
        $result = RideRequest::create($data);

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
                    'service_ids' => $request->service_id,
                    'price' => $request->total_amount
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
        //             'price' => $request->total_amount
        //         ];
        //         ZonePrice::create($zoneData);
        //     }
        //     $result->start_address = $pickupZonedata->name ?? null;
        //     $result->end_address = $dropoffAirportdata->name ?? null;
        //     $result->zone_dropoff = $request->pickup_zone_id;
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
        //             'price' => $request->total_amount
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
        // else{

        // }

        if($result->is_schedule) {
            $rider_data =  [
                'rider_id'          => $result->rider_id,
                'rider_name'        => optional($result->rider)->display_name ?? '',
            ];

            $history_data = [
                'ride_request_id'   => $result->id,
                'history_type'      => $result->status,
                'history_message'   => __('message.ride.new_ride_requested'),
                'datetime'          => date('Y-m-d H:i:s'),
                'history_data'      => json_encode($rider_data),
            ];

            RideRequestHistory::create($history_data);
            // $this->acceptDeclinedRideRequest($result);
        } else {
        if( $result->status == 'new_ride_requested' ) {

                $history_data = [
                    'ride_request_id'   => $result->id,
                    'history_type'      => $result->status,
                    'ride_request'      => $result,
                ];
                saveRideHistory($history_data);
            if( $result->driver_id != null ) {
                    $this->acceptDeclinedRideRequest($result);
                }
                // $notify_data = new \stdClass();
                // $notify_data->success = true;
                // $notify_data->success_type = $result->status;
                // $notify_data->success_message = __('message.ride.new_ride_requested');
                // $notify_data->result = new RideRequestResource($result);
                // dispatch(new NotifyViaMqtt('new_ride_request_'.$result->rider_id, json_encode($notify_data), $result->rider_id));
            } else {
                $history_data = [
                    'history_type'      => $result->status,
                    'ride_request_id'   => $result->id,
                    'ride_request'      => $result,
                ];

                saveRideHistory($history_data);
            }
        }
        // return response()->json(['status' => true, 'event' => 'reset', 'message' => $message]);

        return redirect()->route('riderequest.index')->withSuccess($message);
    }

    public function supplierPayout(Request $request)
    {
        $title = __('message.adjust_price');
        $fleet_fare = $request->fleet_fare;

        return view('dispatch.supplier_payout', compact('title', 'fleet_fare', 'request'));
    }

    public function checkSpecialServices(Request $request)
    {
        $service_type = $request->service_type;
        $service = null;

        if ($service_type == 'transport') {
            // code...
            $service = Service::find($request->service_id);
            if (isset($service)) {
                // code...
                $per_weight_charge = $request->weight > $service->minimum_weight ? ($request->weight - $service->minimum_weight) * $service->per_weight_charge : 0;
                $distance = $request->distance > $service->minimum_distance ? ($request->distance - $service->minimum_distance) * $service->per_distance_charge : 0;
                $total = $per_weight_charge + $distance;
                if ($total) {
                    return response()->json(['status' => true, 'total_amount' => $total]);
                }
            }
        }

        $datetime = $request->date_time;
        if ($datetime) {
            // code...
            $service = null;

            return response()->json(['status' => isset($service) ? true : false, 'total_amount' => isset($service) ? $service->base_fare : null]);
        }
    }
    public function checkZonePayout(Request $request)
    {
        $pickupZone = $request->zone_pickup_id;
        $dropZone = $request->zone_dropoff_id;
        $serviceId = (string) $request->service_id;

        $data = ZonePrice::where('zone_pickup', $pickupZone)
        ->where('zone_dropoff', $dropZone)
        ->whereJsonContains('service_ids',$serviceId)
        ->get()->toArray();

        $showButton = !empty($data) ? false : true;

        return response()->json([
            'success' => true,
            'show_button' => $showButton,
        ]);
    }

    public function storeZoneFare(Request $request)
    {
        $service_ids = is_array($request->service_id) ? $request->service_id : [$request->service_id];

         $zonePrice = ZonePrice::updateOrCreate([
            'pickup_zone_id' => $request->pickup_zone_id,
            'drop_zone_id' => $request->drop_zone_id,
            'service_ids' => $service_ids,
        ],
            [
                'price' => $request->price
            ]
        );
        return back()->with('success', 'Zone price updated successfully!');
    }

}

<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\RideRequest;
use App\DataTables\RideRequestDataTable;
use App\Http\Requests\RideRequestRequest;
use App\Models\Coupon;
use App\Models\Payment;
use App\Models\Service;
use Illuminate\Support\Facades\DB;
use App\Traits\PaymentTrait;
use App\Traits\RideRequestTrait;
use App\Jobs\NotifyViaMqtt;
use App\Http\Resources\RideRequestResource;
use App\Models\Airport;
use App\Models\AppSetting;
use App\Models\ManageZone;
use App\Models\Notification;
use App\Models\RideRequestBid;
use App\Models\Setting;
use App\Models\SurgePrice;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletHistory;
use App\Models\ZonePrice;
use App\Models\MainRoutes;
use App\Models\SubRoutes;
use Barryvdh\DomPDF\Facade\Pdf;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;
use App\Exports\RideRequestReportExport;
use App\Models\CoinWallet;
use App\Models\UserDetail;
use Maatwebsite\Excel\Facades\Excel;

class RideRequestController extends Controller
{
    use PaymentTrait, RideRequestTrait;
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index(RideRequestDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title', ['form' => __('message.riderequest')]);
        $auth_user = authSession();
        $assets = ['datatable'];
        // $button = $auth_user->can('dispatch add') ? '<a href="'.route('dispatch.create').'" class="float-right btn btn-md border-radius-10 btn-outline-dark"><i class="fa fa-plus-circle"></i> '.__('message.book_now').'</a>' : '';
        $button = '';
        $rideRequestfilterButton = true;

        return $dataTable->render('global.ridereuest-datatable', compact('pageTitle', 'auth_user', 'button', 'rideRequestfilterButton'));

        // return $dataTable->render('global.datatable', compact('pageTitle','button','auth_user'));
    }

    /**
     * Show the form for creating a new resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function create()
    {
        $pageTitle = __('message.add_form_title', ['form' => __('message.riderequest')]);

        return view('riderequest.form', compact('pageTitle'));
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
        $data = $request->all();
        $rider_exists_riderequest = RideRequest::where('rider_id', auth()->user()->id)
            ->where('is_schedule', 0)
            ->whereNotIn('status', ['canceled', 'completed'])
            ->exists();

        $scheduled_ride_block = RideRequest::where('rider_id', auth()->user()->id)
            ->where('is_schedule', 1)
            ->whereIn('status', ['in_progress', 'arrived'])
            ->exists();

        if ($rider_exists_riderequest) {
            $riderequest = RideRequest::where('rider_id', auth()->id())->where('is_schedule', 0)->whereNotIn('status', ['canceled', 'completed'])->first();
            $driver = User::find($riderequest->driver_id);
            if ($driver) {
                $driver->update([ 'is_available' => 1 ]);
            }

            if ($riderequest) {
                $riderequest->update([ 'status' => 'canceled', 'cancel_by' => 'auto' ]);
                $collectionName = config('services.firestore.ride_collection', 'rides');
                $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document('ride_' . $riderequest->id);
                $firebaseData->delete();
                 $history_data = [
                    'ride_request_id' => $riderequest->id,
                    'history_type'    => 'canceled',
                    'ride_request'    => $riderequest,
                ];
                saveRideHistory($history_data);
            }
        }
        if ($scheduled_ride_block) {
            return json_message_response(__('message.rider_has_active_scheduled_ride'), 400);
        }
        if ($request->service_id) {
            $service = Service::with('region')->where('id', $request->service_id)->first();
            if (!$service) {
                return json_custom_response(['status' => false, 'message' => 'Service not found'], 404);
            }
            $data['distance_unit'] = $service->region->distance_unit ?? 'km';
            /** ---------------- COMMISSION SAFETY ---------------- */
                if ($service['commission_type'] === 'percentage') {
                    $commission = ($request->total_amount * $service['admin_commission'] / 100) + ($request->total_amount * $service['fleet_commission'] / 100);
                } else {
                    $commission = $service['admin_commission'] + $service['fleet_commission'];
                }
                $data['admin_commission'] = $commission ?? 0;

            // $calculated_amounts = $this->calculateFareAmount($request, $service);
            $data['minimum_fare'] = $service->minimum_fare;
            $data['per_distance'] = $service->per_distance;
            $data['per_distance_charge'] = $request->distance_price;
            $data['per_minute_drive'] = $service->per_minute_drive;
            $data['per_minute_drive_charge'] = 0;
        }


        $coupon_code = $request->coupon_code;
        if ($coupon_code != null) {
            $coupon = Coupon::where('code', $coupon_code)->first();
            $status = isset($coupon_code) ? 200 : 400;

            if ($coupon != null) {
                $status = Coupon::isValidCoupon($coupon);
            }
            if ($status != 200) {
                $response = couponVerifyResponse($status);
                return json_custom_response($response, $status);
            } else {
                $data['coupon_code'] = $coupon->id;
                $data['coupon_data'] = $coupon;
            }
        }

        $data['use_coins']      = $request->use_coins ?? 0;
        $data['coin_discount']  = $request->use_coins ?? 0;
        $data['total_amount']   = $request->total_amount;
        $data['subtotal']       = $request->subtotal;
        $data['base_fare']      = $request->base_fare;
        $data['distance']       = $request->distance;
        $data['base_distance']  = $request->dropoff_distance_in_km;
        $data['duration']       = $request->duration;
        $data['surge_amount']   = $request->surge_amount;
        $data['coupon_discount']   = $request->discount;

        if (isset($data['multi_location'])) {
            $data['multi_drop_location'] = json_encode($data['multi_location']);
        }
        $data['ride_has_bid'] = $request->ride_type == 'with_bidding' ? 1 : 0;
        $data['datetime'] = Carbon::parse(date('Y-m-d H:i:s'))->setTimezone('UTC')->toDateTimeString();
        $data['is_schedule'] = $request->is_schedule;
        if ($request->is_schedule && $request->schedule_datetime) {
            $data['schedule_datetime'] = $request->schedule_datetime;
        }

        switch ($request->trip_type) {
            case 'zone_wise':
                $data['zone_pickup'] = $request->pickup_zone_id;
                $data['zone_dropoff'] = $request->drop_zone_id;
                break;

                // case 'airport_to_zone':
                //     $data['airport_pickup'] = $request->pickup_airport_id;
                //     $data['zone_dropoff'] = $request->drop_zone_id;
                //     break;

                // case 'zone_to_airport':
                //     $data['zone_pickup'] = $request->pickup_zone_id;
                //     $data['airport_dropoff'] = $request->drop_airport_id;
                //     break;

        }

        $currency_symbol = SettingData('CURRENCY', 'CURRENCY_SYMBOL') ?? '$';
        $data['currency_symbol'] = $currency_symbol;
        $result = RideRequest::create($data);

         if($request->use_coins){
            $auth_user = auth()->user();
            $auth_user->decrement('total_coins', $request->use_coins);

            CoinWallet::create([
                'user_id'      => $auth_user->id,
                'ride_id'      => $result->id ?? null,
                'coins'        => $request->use_coins,
                'type'         => 'debit',
                'scratch_time' => null,
            ]);
        }

        $this->updateRideRequestAddresses($result, $request);

        $message = __('message.create_form', ['from' => __('message.riderequest')]);
        $history_data = [
            'ride_request_id' => $result->id,
            'history_type'    => $result->status,
            'ride_request'    => $result,
            'driver_ids'      => $result,
        ];

        // if (!$data['is_schedule'] || $data['is_schedule'] == 0) {
        //     if ($request->ride_type === 'with_bidding') {
        //         if ($result->status === 'new_ride_requested') {
        //             $this->findDrivers($result);
        //             $this->acceptDeclinedRideRequest($result, $request->all());
        //         }
        //     } else {
        //         if ($result->status === 'new_ride_requested') {
        //             $this->acceptDeclinedRideRequest($result, $request->all());
        //         }
        //     }
        // }
        if ($result->status === 'new_ride_requested' && $result->is_schedule == 1) {
            if ($result->driver) {
                $result->driver->update(['is_available' => 1]);
            } else {
                \Log::warning("Scheduled ride created but driver not found for ride ID: {$result->id}");
            }
        }


         if($result->ride_has_bid == 1){
               $this->findDrivers($result);
        }else{
            if ($result->status === 'new_ride_requested') {
                $this->acceptDeclinedRideRequest($result, $request->all());
            }
        }

        saveRideHistory($history_data);

        if ($request->is('api/*')) {
            return json_custom_response([
                'riderequest_id' => $result->id,
                'message' => $message
            ]);
        }

        if ($request->ajax()) {
            if ($result->wasRecentlyCreated) {
                return response()->json([
                    'success' => true,
                    'rideRequestId' => $result->id,
                    'rideData' => $result,
                ]);
            }
        }

        return redirect()->route('riderequest.index')->withSuccess($message);
    }

    public function applyBidRideRequest(Request $request)
    {
        $auth_user = auth()->user();
        $driverID = $auth_user->id;

        $rideRequest = RideRequest::find($request->ride_request_id);

        if (!$rideRequest) {
            return json_message_response(__('message.ride_request_not_found', ['id' => $request->ride_request_id]), 404);
        }

        $existingBid = RideRequestBid::where('ride_request_id', $request->ride_request_id)
            ->where('driver_id', $driverID)
            ->first();

        if ($existingBid) {
            return json_message_response(__('message.already_bid_applied', ['id' => $request->ride_request_id, 'driver_name' => $auth_user->username]), 400);
        }

        RideRequestBid::create([
            'ride_request_id' => $request->ride_request_id,
            'is_bid_accept' => 0,
            'driver_id' => $driverID,
            'bid_amount' => $request->bid_amount,
            'notes' => $request->notes,
        ]);

        // $foundRideRequest = $this->findDrivers($rideRequest,$request->all());
        // $driver_ids = $foundRideRequest->driver_ids ?? [];

        $history_data = [
            'history_type' => 'bid_placed',
            'ride_request_id' => $rideRequest->id,
            'ride_request' => $rideRequest,
            // 'driver_ids' => $driver_ids,

        ];
        saveRideHistory($history_data);

        return json_message_response(__('message.bid_applied', ['id' => $request->ride_request_id, 'driver_name' => $auth_user->username]));
    }


    public function getBiddingDrivers(Request $request)
    {
        // Find the ride request
        $ride_request_id = $request->ride_request_id;
        $ride_request = RideRequest::find($ride_request_id);
        if (!$ride_request) {
            return response()->json(['error' => 'Ride request not found.'], 404);
        }

        $unit = $ride_request->distance_unit ?? 'km';
        $unit_value = convertUnitvalue($unit);
        $radius = Setting::where('type', 'DISTANCE')->where('key', 'DISTANCE_RADIUS')->pluck('value')->first() ?? 50;

        $latitude = $ride_request->start_latitude;
        $longitude = $ride_request->start_longitude;

        // Get nearby drivers who have bid on the ride
        $bidding_drivers = DB::table('ride_request_bids')
            ->join('users', 'ride_request_bids.driver_id', '=', 'users.id')
            ->select(
                'users.id as driver_id',
                'users.display_name as driver_name',
                'ride_request_bids.bid_amount',
                'ride_request_bids.notes',
                DB::raw("($unit_value * acos(cos(radians($latitude)) * cos(radians(users.latitude)) * cos(radians(users.longitude) - radians($longitude)) + sin(radians($latitude)) * sin(radians(users.latitude)))) AS distance")
            )
            ->where('ride_request_bids.is_bid_accept', 0)
            ->where('ride_request_bids.ride_request_id', $ride_request_id)
            ->where('users.status', 'active')
            ->where('users.is_online', 1)
            ->where('users.is_available', 1)
            ->having('distance', '<=', $radius)
            ->orderBy('distance', 'asc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $bidding_drivers,
            'start_address' => $ride_request->start_address,
            'end_address' => $ride_request->end_address,
            'multi_drop_location' => $ride_request->multi_drop_location,
        ]);
    }

    public function acceptBidRequest(Request $request)
    {
        $riderequest = RideRequest::find($request->id);

        if ($riderequest == null) {
            $message = __('message.not_found_entry', ['name' => __('message.riderequest')]);
            return json_message_response($message);
        }

        if ($riderequest->status == 'accepted') {
            $message = __('message.not_found_entry', ['name' => __('message.riderequest')]);
            return json_message_response($message, 400);
        }

        $driverIds = is_array(request('driver_id')) ? request('driver_id') : [request('driver_id')];

        if (request()->has('is_bid_accept') && request('is_bid_accept') == 1) {
            $riderequest->driver_id = $driverIds[0];
            $riderequest->status = 'bid_accepted';
            $riderequest->max_time_for_find_driver_for_ride_request = 0;
            $riderequest->otp = rand(1000, 9999);
            $riderequest->riderequest_in_driver_id = null;
            $riderequest->riderequest_in_datetime = null;

            if ($request->has('total_amount')) {
                $riderequest->total_amount = $request->total_amount;
            }
            $riderequest->save();

            $bid = RideRequestBid::where('ride_request_id', $riderequest->id)
                ->where('driver_id', $driverIds[0])
                ->first();

            if ($bid) {
                $bid->is_bid_accept = 1;
                $bid->save();
            }

            saveRideHistory([
                'history_type' => 'bid_accepted',
                'ride_request_id' => $riderequest->id,
                'ride_request' => $riderequest,
            ]);

            $riderequest->driver->update(['is_available' => 0]);

            $message = __('message.updated');
        } elseif (request()->has('is_bid_accept') && request('is_bid_accept') == 2) {
            $currentRejectedIds = $riderequest->rejected_bid_driver_ids;
            if (is_string($currentRejectedIds)) {
                $currentRejectedIds = json_decode($currentRejectedIds, true);
            }
            if (!is_array($currentRejectedIds)) {
                $currentRejectedIds = [];
            }

            foreach ($driverIds as $driverId) {
                if (!in_array($driverId, $currentRejectedIds)) {
                    $currentRejectedIds[] = $driverId;
                }

                $bid = RideRequestBid::where('ride_request_id', $riderequest->id)
                    ->where('driver_id', $driverId)
                    ->first();

                if (!$bid) {
                    RideRequestBid::create([
                        'ride_request_id' => $riderequest->id,
                        'driver_id' => $driverId,
                        'bid_amount' => 0,
                        'is_bid_accept' => 2,
                    ]);
                } else {
                    $bid->is_bid_accept = 2;
                    $bid->save();
                }
            }

            $riderequest->update(['rejected_bid_driver_ids' => json_encode($currentRejectedIds)]);

            saveRideHistory([
                'history_type' => 'bid_rejected',
                'ride_request_id' => $riderequest->id,
                'ride_request' => $riderequest,
            ]);
        }

        $response = [
            'ride_request_id' => $riderequest->id,
            'message' => $message ?? __('message.save_form', ['form' => __('message.riderequest')]),
        ];

        if ($request->is('api/*')) {
            return json_custom_response($response);
        }

        return response()->json($response);
    }

    public function acceptRideRequest(Request $request)
    {
        $riderequest = RideRequest::find($request->id);


        if ($riderequest == null) {
            $message = __('message.not_found_entry', ['name' => __('message.riderequest')]);
            return json_message_response($message);
        }

        if ($riderequest->status == 'accepted') {
            $message = __('message.not_found_entry', ['name' => __('message.riderequest')]);
            return json_message_response($message, 400);
        }
        $user =UserDetail::where('user_id',request('driver_id'))->first();
        if (request()->has('is_accept') && request('is_accept') == 1) {
            $riderequest->driver_id = request('driver_id');
            $riderequest->status = 'accepted';
            $riderequest->max_time_for_find_driver_for_ride_request = 0;
            $riderequest->otp = rand(1000, 9999);
            $riderequest->riderequest_in_driver_id = null;
            $riderequest->riderequest_in_datetime = null;
            $riderequest->car_model = $user->car_model;
            $riderequest->car_color = $user->car_color;
            $riderequest->car_plate_number = $user->car_plate_number;
            $riderequest->car_production_year = $user->car_production_year;
            $riderequest->save();
            $result = $riderequest;

            $history_data = [
                'history_type'      => 'accepted',
                'ride_request_id'   => $result->id,
                'ride_request'      => $result,
            ];

            saveRideHistory($history_data);
            if ($riderequest->is_schedule == 1) {
                $riderequest->driver->update(['is_available' => 1]);
            } else {
                $riderequest->driver->update(['is_available' => 0]);
            }
        } else {

             if (!empty(request('driver_id'))) {
                $newDriverId = request('driver_id');
                $cancelledDriverIds = $riderequest->cancelled_driver_ids ?? [];

                if (!in_array($newDriverId, $cancelledDriverIds)) {
                    $cancelledDriverIds[] = $newDriverId;
                }
                $riderequest->driver_id = null;
                $riderequest->cancelled_driver_ids = $cancelledDriverIds;
                $riderequest->save();
            }

            // $riderequest->status = 'driver_declined';
            // $riderequest->save();

            // $result = $riderequest;
            // $history_data = [
            //     'history_type'      => 'driver_declined',
            //     'ride_request_id'   => $result->id,
            //     'ride_request'      => $result,
            // ];

            // saveRideHistory($history_data);
            $result = $this->acceptDeclinedRideRequest($riderequest, $request->all());
        }

        $message = __('message.updated');
        if ($result->driver_id == null) {
            $message = __('message.save_form', ['form' => __('message.riderequest')]);
        }
        if ($request->is('api/*')) {
            $response = [
                'ride_request_id' => $result->id,
                'message' => $message
            ];
            return json_custom_response($response);
        }
    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        if (!auth()->user()->can('riderequest show')) {
            abort(403, __('message.action_is_unauthorized'));
        }
        $pageTitle = __('message.add_form_title', ['form' => __('message.riderequest')]);
        $data = RideRequest::findOrFail($id);

        if ($data != null) {
            $auth_user = auth()->user();
            if (count($auth_user->unreadNotifications) > 0) {
                $auth_user->unreadNotifications->where('data.type', '!=', 'complaintcomment')->where('data.id', $id)->markAsRead();
            }
        }
        $minimum_distance = $data->service->minimum_distance ?? 0;
        $distance = $data->distance ?? 0;

        $chargeable_distance = max(0, $distance - $minimum_distance);
        $distance_price = $chargeable_distance * ($data->service->per_distance ?? 0);
        return view('riderequest.show', compact('data', 'distance_price', 'chargeable_distance'));
    }

    /**
     * Show the form for editing the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function edit($id)
    {
        $pageTitle = __('message.update_form_title', ['form' => __('message.riderequest')]);
        $data = RideRequest::findOrFail($id);

        return view('riderequest.form', compact('data', 'pageTitle', 'id'));
    }

    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(RideRequestRequest $request, $id)
    {
        $riderequest = RideRequest::findOrFail($id);

        if ($request->has('otp')) {
            if ($riderequest->otp != $request->otp) {
                return json_message_response(__('message.otp_invalid'), 400);
            }
        }
        // RideRequest data...
        $riderequest->fill($request->all())->update();
        $message = __('message.update_form', ['form' => __('message.riderequest')]);
        if ($riderequest->status == 'new_ride_requested') {
            Log::info('New Ride Request');
            if ($riderequest->riderequest_in_driver_id == null) {
                $this->acceptDeclinedRideRequest($riderequest, $request->all());
            }
            if ($request->is('api/*')) {
                return json_message_response($message);
            }
        }
        $payment = Payment::where('ride_request_id', $id)->first();

        if ($request->has('is_change_payment_type') && request('is_change_payment_type') == 1) {
            $payment->update(['payment_type' => request('payment_type')]);

            $message = __('message.change_payment_type');
            $notify_data = new \stdClass();
            $notify_data->success = true;
            $notify_data->success_type = 'change_payment_type';
            $notify_data->success_message = $message;
            $notify_data->result = new RideRequestResource($riderequest);

            try {
                $document_name = 'ride_' . $riderequest->id;
                // $collectionName = env('RIDE_COLLECTION');
                $collectionName = config('services.firestore.ride_collection', 'rides');
                $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document('ride_' . $riderequest->id);

                $rideData = [
                    'driver_ids' => [$riderequest->driver_id],
                    'on_rider_stream_api_call' => 1,
                    'on_stream_api_call' => 1,
                    'payment_status' => $riderequest->payment->payment_status,
                    'payment_type' => $riderequest->payment->payment_type,
                    'ride_id' => $riderequest->id,
                    'rider_id' => $riderequest->rider_id,
                    'status' => $riderequest->status,
                    'tips' => $riderequest->tips ? 1 : 0,
                ];

                if ($riderequest->status == 'canceled') {
                    sleep(3);
                    $firebaseData->delete();
                } else {
                    $firebaseData->set($rideData, ['merge' => true]);
                }
            } catch (\Exception $e) {
                \Log::error('Error updating Firestore document for Ride:-405 ' . $e->getMessage());
            }
            // dispatch(new NotifyViaMqtt('ride_request_status_'.$riderequest->driver_id, json_encode($notify_data)));

            return json_message_response($message);
        }

        if ($request->status == 'canceled') {
            $message = __('message.cancel_form', ['form' => __('message.riderequest')]);
            $cancellation_fee = $riderequest->service->cancellation_fee ?? 0;
            $this->deductCancellationFee($riderequest->rider_id, $cancellation_fee, $riderequest->id);
        }

        $history_data = [
            'history_type'      => request('status'),
            'ride_request_id'   => $id,
            'ride_request'      => $riderequest,
        ];

        saveRideHistory($history_data);

        if ($request->is('api/*')) {
            return json_message_response($message);
        }

        if (request()->ajax() && $request->type == 'payment_status') {
            return json_message_response($message);
        }

        if (request()->ajax() && $request->type == 'ridecancel') {
            return response()->json([
                'success' => true,
                'message' => $request->cancel_ride_message,
            ]);
        }

        if (auth()->check()) {
            return redirect()->route('riderequest.index')->withSuccess(__('message.update_form', ['form' => __('message.riderequest')]));
        }
        return redirect()->back()->withSuccess(__('message.update_form', ['form' => __('message.riderequest')]));
    }
    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        if (env('APP_DEMO')) {
            $message = __('message.demo_permission_denied');
            if (request()->ajax()) {
                return response()->json(['status' => true, 'message' => $message]);
            }
            return redirect()->route('riderequest.index')->withErrors($message);
        }
        $riderequest = RideRequest::find($id);
        $status = 'errors';
        $message = __('message.not_found_entry', ['name' => __('message.riderequest')]);

        if ($riderequest != '') {
            $search = "id" . '":' . $id;
            Notification::where('data', 'like', "%{$search}%")->delete();

            // $document_name = 'ride_' . $riderequest->id;
            // $collectionName = env('RIDE_COLLECTION');
            // $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document($riderequest->id);
            // $firebaseData->delete();
            // $collectionName = env('RIDE_COLLECTION', 'rides');
            $collectionName = config('services.firestore.ride_collection', 'rides');

            $firebase = app('firebase.firestore');
            $collection = $firebase->database()->collection($collectionName);
            $document = $collection->document('ride_' . $riderequest->id);
            // \Log::info("Trying to delete Firestore doc ID: " . $riderequest->id);

            $document->delete();
            $riderequest->delete();

            $status = 'success';
            $message = __('message.delete_form', ['form' => __('message.riderequest')]);
        }

        if (request()->is('api/*')) {
            return json_message_response($message);
        }

        if (request()->ajax()) {
            return response()->json(['status' => true, 'message' => $message]);
        }

        return redirect()->back()->with($status, $message);
    }

    public function rideInvoicePdf($id)
    {
        // $id = encryptDecryptId(request('id'),'decrypt');
        $ride_detail = RideRequest::find($id);
        $today = now()->format('d/m/Y');
        $app_setting = AppSetting::first();
        $surge_price = getSurgePrice($ride_detail->datetime,$ride_detail->service_id);

        if (isset($surge_price) && !empty($surge_price)) {
            if ($surge_price->type == 'fixed') {
                $fixed_charge = $surge_price->value;
            } elseif ($surge_price->type == 'percentage') {
                $fixed_charge = ($ride_detail->subtotal * $surge_price->value) / 100;
            }
        } else {
            $fixed_charge = 0;
        }
        // return view('riderequest.invoice',compact('ride_detail','today','app_setting','fixed_charge'),[]);

        $pdf = Pdf::loadView('riderequest.invoice', compact('ride_detail', 'today', 'app_setting', 'fixed_charge'), []);
        if (request()->is('api/*')) {
            return $pdf->stream('ride_' . $ride_detail->id . '.pdf');
        }
        return $pdf->download('invoice_' . $ride_detail->id . '.pdf');
    }
    public function rideRiderInvoicePdf($id)
    {
        $ride_detail = RideRequest::find($id);
        $today = now()->format('d/m/Y');
        $app_setting = AppSetting::first();
        $surge_price = getSurgePrice($ride_detail->datetime,$ride_detail->service_id);

        $minimum_distance = $ride_detail->service->minimum_distance ?? 0;
        $distance = $ride_detail->distance ?? 0;

        $chargeable_distance = max(0, $distance - $minimum_distance);
        $distance_price = $chargeable_distance * ($ride_detail->service->per_distance ?? 0);

        if (isset($surge_price) && !empty($surge_price)) {
            if ($surge_price->type == 'fixed') {
                $fixed_charge = $surge_price->value;
            } elseif ($surge_price->type == 'percentage') {
                $fixed_charge = ($ride_detail->subtotal * $surge_price->value) / 100;
            }
        } else {
            $fixed_charge = 0;
        }

        $pdf = Pdf::loadView(
            'riderequest.rider-invoice',
            compact('ride_detail', 'today', 'app_setting', 'fixed_charge','distance_price')
        )->setOption([
            'defaultFont' => 'DejaVu Sans',
            'isHtml5ParserEnabled' => true,
            'isRemoteEnabled' => true,
        ]);

        return $pdf->download('rider-invoice_' . $ride_detail->id . '.pdf');
    }

    public function updateDropLocationTime($rideId, $dropIndex)
    {
        $ride = RideRequest::findOrFail($rideId);
        $updateField = !empty($ride->multi_drop_location) ? 'multi_drop_location' : 'drop_location';

        $locationData = $ride->$updateField;

        // Log raw data before decoding
        \Log::info('Raw location data:', ['data' => $locationData]);

        // Decode JSON if needed
        if (is_string($locationData)) {
            $decoded = json_decode($locationData, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $locationData = $decoded;
            }
        }

        // Ensure we have an array
        if (!is_array($locationData)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid location data format.'
            ], 400);
        }

        // Validate drop index
        if (!isset($locationData[$dropIndex])) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid drop index.'
            ], 400);
        }

        // Update dropped_at timestamp
        $locationData[$dropIndex]['dropped_at'] = now()->toDateTimeString();

        // Log updated data
        \Log::info('Updated location data:', ['updated_data' => $locationData]);

        // Save as a JSON-encoded string
        $ride->$updateField = json_encode($locationData, JSON_UNESCAPED_SLASHES);
        $ride->save();

        return response()->json([
            'success' => true,
            'message' => 'Drop time updated successfully',
            'updated_data' => $locationData
        ]);
    }

    // public function assigndriver($id)
    // {
    //     $riderequest = RideRequest::find($id);
    //     $servicequery = User::where('service_id', $riderequest->service_id)
    //     ->where('status', 'active')
    //     ->where('user_type', 'driver');
    //     $service = $servicequery->get();
    //     $pageTitle = __('message.assign_driver');
    //     return view('riderequest.assgin', compact('pageTitle', 'service', 'id', 'riderequest'))->render();
    // }


    public function assigndriver($id)
    {
        $riderequest = RideRequest::find($id);

        // $latitude = $riderequest->start_latitude;
        // $longitude = $riderequest->start_longitude;
        // $radius = 10;

        $unit = $riderequest->distance_unit ?? 'km';
        $unit_value = convertUnitvalue($unit);
        $radius = Setting::where('type', 'DISTANCE')->where('key', 'DISTANCE_RADIUS')->pluck('value')->first() ?? 50;

        $latitude = $riderequest->start_latitude;
        $longitude = $riderequest->start_longitude;

        $drivers = User::where('status', 'active')
            ->where('user_type', 'driver')
            ->where('is_online', 1)
            ->where('is_available', 1)
            ->where('service_id', $riderequest->service_id)
            ->selectRaw("users.*,( $unit_value * acos( cos( radians($latitude) ) * cos( radians( latitude ) ) * cos( radians( longitude ) - radians($longitude) ) + sin( radians($latitude) ) * sin( radians( latitude ) ) ) ) AS distance")
            ->having("distance", "<=", $radius)
            ->orderBy("distance", "asc")
            ->get();
        $pageTitle = __('message.assign_driver');
        return view('riderequest.assgin', compact('pageTitle', 'drivers', 'id', 'riderequest'))->render();
    }

    public function assigndriversave(Request $request)
    {
        $id = $request->id;
        $rides = RideRequest::where('id', $id)->first();
        if ($request->type == 'assigned_driver') {
            $message = __('message.assign_driver');
            $history_type = 'assign_driver';
            $data['datetime'] = now();

            $riderequest = RideRequest::updateOrCreate(['id' => $request->id]);
            $rides->update(['driver_id' => $request->driver_id, 'riderequest_in_driver_id' => null, 'status' => $request->status, 'otp' => rand(1000, 9999)]);

            $collectionName = config('services.firestore.ride_collection', 'rides');
            $firebaseData = app('firebase.firestore')->database()->collection($collectionName)
                ->document('ride_' . $rides->id);

            $firebaseData->set([
                'driver_id' => $request->driver_id,
                'assigned_at' => now()->toDateTimeString()
            ], ['merge' => true]);

            $history_data = [
                'ride_request_id' => $rides->id,
                'history_type'    => 'assign_driver',
                'ride_request'    => $rides,
                'driver_ids'      => $request->driver_id,
            ];
            // $history_data = [
            //     'history_type' => 'assign_driver',
            //     'history_message' =>  __('message.assign_driver'),
            //     'ride_request_id' => $rides->id,
            //     'datetime' => now(),
            // ];
            saveRideHistory($history_data);
        }
        $message = __('message.assign_driver');
        return redirect()->route('riderequest.index')->withSuccess($message);
    }
    public function downloadRideRequestReport(Request $request)
    {
        $startDate = $request->input('from_date');
        $endDate   = $request->input('to_date');

        $start = $startDate ? Carbon::parse($startDate)->format('Y-m-d') : null;
        $end   = $endDate ? Carbon::parse($endDate)->format('Y-m-d') : null;

        $user_data = RideRequest::when($startDate, fn($q) => $q->whereDate('created_at', '>=', $startDate))
            ->when($endDate, fn($q) => $q->whereDate('created_at', '<=', $endDate))
            ->get();
        $export = new RideRequestReportExport($user_data, $request);

        if ($start && $end) {
            $filenameDatePart = "_{$start}_to_{$end}";
        } elseif ($start) {
            $filenameDatePart = "_from_{$start}";
        } elseif ($end) {
            $filenameDatePart = "_to_{$end}";
        } else {
            $filenameDatePart = "_" . now()->format('Y-m-d');
        }

        $filename = "rider-report{$filenameDatePart}.xlsx";

        // Always XLSX
        return Excel::download($export, $filename, \Maatwebsite\Excel\Excel::XLSX);
    }

}

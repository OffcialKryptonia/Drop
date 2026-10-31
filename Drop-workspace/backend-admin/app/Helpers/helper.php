<?php

use App\Models\User;
use App\Models\AppSetting;
use App\Models\Setting;
use App\Models\RideRequest;
use App\Models\RideRequestHistory;
use App\Models\Coupon;
use App\Notifications\RideNotification;
use App\Notifications\CommonNotification;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Session;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Http;
use App\Http\Resources\RideRequestResource;
use App\Models\Document;
use App\Models\LanguageVersionDetail;
use App\Models\MailTemplate;
use App\Models\RideRequestBid;
use App\Models\SMSSetting;
use App\Models\SMSTemplatRide;
use App\Models\SurgePrice;
use Illuminate\Support\Facades\Log;
use App\Services\SmsService;
use App\Mail\SendMail;
use Illuminate\Support\Facades\Mail;
use App\Mail\OTPVerificationMail;
use App\Models\Service;
use App\Models\Wallet;
use App\Models\WalletHistory;
use App\Models\ZonePrice;
use Carbon\Carbon;

use App\Http\Resources\EstimateServiceResource;

use App\Models\Screen;
use App\Models\DefaultKeyword;
use App\Models\LanguageList;
use App\Models\LanguageWithKeyword;

function DummyData($key){
    $dummy_title = 'XXXXXXXXXXXX';
    $dummy_description = 'xxxxxxxxxxxxxxxx xxxxxxxxx xxxxxxxxxxxxxxxxxxxxx xxxxxxxxxxxxxxxxxxxxxx xxxxxxxxxxxxxxxxxxxxxxxx xxxxxxxxxxxxxxxxxxxxxxxx xxxxxxxxx xxxxxxxxxxx xxxxxxxxxxxxxxxxx';

    switch ($key) {
        case 'dummy_title':
            return $dummy_title;
        case 'dummy_description':
            return $dummy_description;
        default:
            return '';
    }
}

function getSettingFirstData($type = null, $key = null)
{
    return Setting::where('type', $type)->where('key', $key)->first();
}

function getSingleMediaSettingImage($model = null, $collection_name, $check_collection_type = null)
{
    $image = null;
    if ($model !== null) {
        $image = $model->getFirstMedia($collection_name);
    }

    if ($image !== null && getFileExistsCheck($image))
    {
        return $image->getFullUrl();
    }else{
        switch ($collection_name) {
            case 'logo_image':
                $image = asset('frontend-website/img/40x40_black_white_logo.png');
                break;
            case 'background_image':
                $image = asset('frontend-website/img/1920x995.png');
                break;
            case 'frontend_data_image':
                if ($check_collection_type == 'testimonial_image') {
                    $image = asset('frontend-website/img/1920x800.png');
                }
                if ($check_collection_type == 'whychoose_image') {
                    $image = asset('frontend-website/img/200x200.png');
                }
                break;
            case 'download_app_logo':
                $image = asset('frontend-website/img/600x591.png');
                break;
            case 'image':
                if ($check_collection_type == 'contactus_info') {
                    $image = asset('frontend-website/img/1920x437.png');
                }
                if ($check_collection_type == 'download_app') {
                    $image = asset('frontend-website/img/600x591.png');
                }
                if ($check_collection_type == 'our_mission') {
                    $image = asset('frontend-website/img/612x597.png');
                }
                if ($check_collection_type == 'why_choose') {
                    $image = asset('frontend-website/img/1920x800.png');
                }
                break;
        }
        return $image;
    }

}

function authSession($force = false)
{
    $session = new User;
    if ($force) {
        $user = auth()->user()->getRoleNames();
        Session::put('auth_user', $user);
        $session = Session::get('auth_user');
        return $session;
    }
    if (Session::has('auth_user')) {
        $session = Session::get('auth_user');
    } else {
        $user = auth()->user();
        Session::put('auth_user', $user);
        $session = Session::get('auth_user');
    }
    return $session;
}

function appSettingData($type = 'get')
{
    if (Session::get('setting_data') == '') {
        $type = 'set';
    }
    switch ($type) {
        case 'set':
            $settings = AppSetting::first();
            Session::put('setting_data', $settings);
            break;
        default:
            break;
    }
    return Session::get('setting_data');
}

function json_message_response($message, $status_code = 200)
{
    return response()->json(['message' => $message], $status_code);
}

function json_custom_response($response, $status_code = 200)
{
    return response()->json($response, $status_code);
}

function json_pagination_response($items)
{
    return [
        'total_items' => $items->total(),
        'per_page' => $items->perPage(),
        'currentPage' => $items->currentPage(),
        'totalPages' => $items->lastPage()
    ];
}

function imageExtention($media)
{
    $extention = null;
    if ($media != null) {
        $path_info = pathinfo($media);
        $extention = $path_info['extension'];
    }
    return $extention;
}

function saveRideHistory($data)
{
    $user_type = auth()->check()
        ? auth()->user()->user_type
        : ($data['user_type'] ?? 'rider');
    $data['datetime'] = date('Y-m-d H:i:s');
    // $mqtt_event = 'test_connection';
    $history_data = [];
    $sendTo = [];

    $ride_request_id = $data['ride_request']->id;
    $ride_request = RideRequest::find($ride_request_id);
    $riderRequestData = $data['ride_request'];

    $sendEmail = function ($ride_request, $status_key, $dynamicData) {
        $setting = SettingData('mail_template', $status_key);
        // \Log::info("Sending email for status: {$status_key}, Setting: {$setting}");
        if ($setting == 1) {
            $email = $ride_request->rider->email ?? null;
            if ($email) {
                $emailData = MailTemplate::where('type', $status_key)->first();
                if ($emailData) {
                    $mailDescription = str_replace(array_keys($dynamicData), array_values($dynamicData), $emailData->description ?? '');
                    $data = [
                        'ride_id' => $ride_request->id,
                        'status' => $status_key,
                        'company_name' => AppSetting::first()->company_name ?? 'Your Company',
                        'rider_name' => $ride_request->rider->name ?? 'Rider',
                        'driver_name' => $ride_request->driver->name ?? 'Driver',
                    ];
                    try {
                        Mail::to($email)->send(new SendMail($emailData->subject ?? __('message.ride.' . $status_key), $mailDescription, $data));
                    } catch (\Exception $e) {
                        \Log::error("Failed to send email for ride ID: {$ride_request->id}, Status: {$status_key}, Error: {$e->getMessage()}");
                    }

                    // Mail::to($email)->send(new SendMail($emailData->subject ?? __('message.ride.' . $status_key),$mailDescription,$data));
                }
            }
        }
    };
    $dynamicData = [
        '[ride ID]' => $ride_request->id,
        '[status]' => ucfirst($ride_request->status),
        '[Company name]' => config('app.name'),
        '[user name]' => $ride_request->rider->display_name ?? __('message.rider.anonymous'),
        '[driver name]' => $ride_request->driver->display_name ?? __('message.driver.anonymous'),
        '[pickup location]' => $ride_request->start_address ?? __('message.ride.location_unknown'),
        '[dropoff location]' => $ride_request->end_address ?? __('message.ride.location_unknown'),
    ];
    switch ($data['history_type']) {
        case 'new_ride_requested':
            $data['history_message'] = __('message.ride.new_ride_requested');
            $history_data = [
                'rider_id' => $ride_request->rider_id,
                'rider_name' => optional($ride_request->rider)->display_name ?? '',
            ];
            $sendTo = [];
            break;
        case 'booked':
            $data['history_message'] = __('message.ride.booked');
            $history_data = [
                'rider_id' => $ride_request->rider_id,
                'rider_name' => optional($ride_request->rider)->display_name ?? '',
            ];
            $sendTo = removeValueFromArray(['admin', 'rider'], $user_type);
            $subject = __('message.booked');
            $message = __('message.ride.booked');
            sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);
        break;

        case 'no_drivers_available':
            # code...
            break;

        case 'assign_driver':
            $data['history_message'] = __('message.assign_driver');
            $history_data = [
                'driver_id' => $ride_request->driver_id,
                'driver_name' => optional($ride_request->driver)->display_name ?? '',
            ];
            $sendTo = [];

        break;
        // case 'finding_drivers':
        //     $data['history_message'] = __('message.ride.finding_drivers');
        //     $history_data = [
        //         'rider_id' => $ride_request->rider_id,
        //         'rider_name' => optional($ride_request->rider)->display_name ?? '',
        //     ];
        //     $sendTo = [];
        //     break;
        // case 'driver_found':
        //     $data['history_message'] = __('message.ride.driver_found',['name' => optional($ride_request->riderequest_in_driver)->display_name]);
        //     $history_data = [
        //         'driver_id' => $ride_request->driver_id,
        //         'driver_name' => optional($ride_request->driver)->display_name ?? '',
        //     ];
        //     $sendTo = ['admin', 'driver'];
        //     break;
        // case 'driver_not_found':
        //     $data['history_message'] = __('message.ride.driver_not_found');
        //     $history_data = [
        //         'driver_id' => $ride_request->driver_id,
        //         'driver_name' => optional($ride_request->driver)->display_name ?? '',
        //     ];
        //     $sendTo = ['admin', 'rider'];
        //     break;
        // case 'driver_declined':
        //     $data['history_message'] = __('message.ride.driver_declined',['name' => optional($ride_request->riderequest_in_driver)->display_name]);
        //     $history_data = [
        //         'driver_id' => $ride_request->riderequest_in_driver,
        //         'driver_name' => optional($ride_request->driver)->display_name ?? '',
        //     ];
        //     // $mqtt_event = 'ride_request_status';
        //     $sendTo = removeValueFromArray(['admin', 'rider'], $user_type);
        //     break;
        // case 'awaiting_driver_response':
        //     $data['history_message'] = __('message.ride.awaiting_driver_response');
        //     $history_data = [
        //         'driver_id' => $ride_request->driver_id,
        //         'driver_name' => optional($ride_request->driver)->display_name ?? '',
        //     ];
        //     $sendTo = ['driver'];
        //     break;
        case 'accepted':
            $data['history_message'] = __('message.ride.accepted');
            $history_data = [
                'driver_id' => $ride_request->driver_id,
                'driver_name' => optional($ride_request->driver)->display_name ?? '',
            ];

            $sendTo = removeValueFromArray(['admin', 'rider'], $user_type);

            // $mqtt_event = 'ride_request_status';
            $dynamicData = [
                '[ride ID]' => $ride_request->id,
                '[status]' => ucfirst($ride_request->status),
                '[Company name]' => config('app.name'),
                '[user name]' => $ride_request->rider->display_name ?? __('message.rider.anonymous'),
                '[driver name]' => $ride_request->driver->display_name ?? __('message.driver.anonymous'),
                '[pickup location]' => $ride_request->start_address ?? __('message.ride.location_unknown'),
                '[dropoff location]' => $ride_request->end_address ?? __('message.ride.location_unknown'),
            ];
            $subject = __('message.ride_accepted');
            $message = __('message.ride.accepted');
            sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);


            $sendEmail($ride_request, 'accepted', $dynamicData);
        break;

        case 'bid_placed':
            foreach ($ride_request->bids as $bid) {
                $data['history_message'] = __('message.ride.bid_placed', ['name' => optional($bid->driver)->display_name]);
                $history_data = [
                    'driver_id' => $bid->driver_id,
                    'rider_id' => $ride_request->rider_id,
                    'driver_name' => optional($bid->driver)->display_name ?? '',
                ];
                $sendTo = removeValueFromArray(['admin', 'rider'], $user_type);
                $sendEmail($ride_request, 'bid_placed', $dynamicData);
                $subject = __('message.new_bid_placed');
                $message = __('message.ride.bid_placed', ['name' => optional($bid->driver)->display_name]);
                sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);
            }
        break;

        case 'bid_accepted':
            $accepted_bid = $ride_request->bids->where('is_bid_accept', 1)->first();
            if ($accepted_bid) {
                $data['history_message'] = __('message.ride.bid_accept', ['name' => optional($accepted_bid->driver)->display_name]);
                $ride_request->update(['driver_id' => $accepted_bid->driver_id]);
                $history_data = [
                    'driver_id' => $accepted_bid->driver_id,
                    'driver_name' => optional($accepted_bid->driver)->display_name ?? '',
                ];
            }
            $sendEmail($ride_request, 'bid_accepted', $dynamicData);
            $sendTo = removeValueFromArray(['admin', 'driver'], $user_type);
            $subject = __('message.bid_accepted');
            $message = __('message.ride.bid_accept');
            sendPushNotificationForRide('driver',$data['history_type'],$ride_request,$subject,$message);
        break;

        case 'bid_rejected':
            $rejected_bid = $ride_request->bids->where('is_bid_accept', 2)->first();
            if ($rejected_bid) {
                $data['history_message'] = __('message.ride.bid_reject', ['name' => optional($rejected_bid->driver)->display_name]);

                $current_rejected_ids = $ride_request->rejected_bid_driver_ids;
                if (is_string($current_rejected_ids)) {
                    $current_rejected_ids = json_decode($current_rejected_ids, true) ?? [];
                } elseif (!is_array($current_rejected_ids)) {
                    $current_rejected_ids = [];
                }

                if (!in_array($rejected_bid->driver_id, $current_rejected_ids)) {
                    $current_rejected_ids[] = $rejected_bid->driver_id; // Avoid duplicates
                }

                $ride_request->update(['rejected_bid_driver_ids' => json_encode($current_rejected_ids)]);

                $ride_request->update(['status' => 'bid_rejected']);

                $history_data = [
                    'driver_id' => $rejected_bid->driver_id,
                    'driver_name' => optional($rejected_bid->driver)->display_name ?? '',
                ];

                // sleep(2);

                // $ride_request->refresh();

                // if ($ride_request->status === 'bid_rejected') {
                //     $ride_request->update(['status' => 'new_ride_requested']);
                // }
            }
            $sendEmail($ride_request, 'bid_rejected', $dynamicData);
            $sendTo = removeValueFromArray(['admin', 'driver'], $user_type);
            $subject = __('message.bid_rejected');
            $message = __('message.ride.bid_reject', ['name' => optional($rejected_bid->driver)->display_name]);
            sendPushNotificationForRide('driver',$data['history_type'],$ride_request,$subject,$message);
            break;
        case 'arriving':
            $data['history_message'] = __('message.ride.arriving');
            $history_data = [
                'driver_id' => $ride_request->driver_id,
                'driver_name' => optional($ride_request->driver)->display_name ?? '',
            ];
            $sendEmail($ride_request, 'arriving', $dynamicData);
            // $mqtt_event = 'ride_request_status';
            $sendTo = removeValueFromArray(['admin', 'rider'], $user_type);
            $subject = __('message.arriving_ride');
            $message = optional($ride_request->driver)->display_name . ' ' . __('message.ride.arriving');
            sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);
        break;

        case 'arrived':
            $data['history_message'] = __('message.ride.arrived');
            $history_data = [
                'driver_id' => $ride_request->driver_id,
                'driver_name' => optional($ride_request->driver)->display_name ?? '',
            ];
            // $mqtt_event = 'ride_request_status';
            $sendEmail($ride_request, 'arrived', $dynamicData);
            $sendTo = removeValueFromArray(['admin', 'rider'], $user_type);

            $smscheck =  SettingData('ride', 'is_sms_rider');
            // Log::info("Final SMS Check Value: " . $smscheck);

            if ($smscheck === 0) {
                Log::warning("SMS Sending Disabled.");
                return false;
            }

            // Order ke rider ka contact number fetch karna
            $driver =  $data['ride_request']->driver;
            $contactNumber = $driver->contact_number ?? null;

            // Log::info("rider Contact Number: " . $contactNumber);

            if (!empty($contactNumber)) {
                try {
                    $smsType = isset($riderRequestData->sms_type) ? $riderRequestData->sms_type : '';
                    // Log::info("Selected SMS Provider: " . $smsType);
                    $smsService = app()->make(\App\Services\SmsService::class);

                    // Dynamic SMS Message
                    $message = SMSData('twilio', 'get', null, [
                        // 'Ride ID' =>  $data['ride_request']->rider_id,
                        'user name' =>  $data['ride_request']->driver->display_name,
                        'status' =>  $data['ride_request']->status,
                        'OTP Code' => otpCode(5),
                    ]);
                    // Log::info('Generated SMS Message: ' . $message);

                    $response = $smsService->sendSMS($contactNumber, $message);
                    // Log::info("SMS Response: " . print_r($response, true));

                } catch (\Exception $e) {
                    Log::error("SMS Error: " . $e->getMessage());
                }
            }
            $subject = __('message.driver_arrived');
            $message = __('message.ride.arrived');
            sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);
            break;

        // ride is in progress from the start to the end location
        case 'in_progress':
            $data['history_message'] = __('message.ride.in_progress');
            $history_data = [
                'driver_id' => $ride_request->driver_id,
                'driver_name' => optional($ride_request->driver)->display_name ?? '',
            ];
            $sendEmail($ride_request, 'in_progress', $dynamicData);
            // \Log::info("Email sent for ride ID: {$ride_request->id}, status: in_progress");
            // $mqtt_event = 'ride_request_status';
            $sendTo = removeValueFromArray(['admin', 'rider'], $user_type);
            $subject = __('message.ride_started');
            $message = __('message.ride.start_ride');
            sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);
            break;

        break;

        case 'canceled':
            $data['history_message'] = __('message.ride.canceled');

            if ($ride_request->cancel_by == 'auto') {
                $history_data = [
                    'cancel_by' => $ride_request->cancel_by,
                    'rider_id' => $ride_request->rider_id,
                    'rider_name' => optional($ride_request->rider)->display_name ?? '',
                ];
                $subject = __('message.ride_canceled');
                $message = __('message.ride.system_canceled');
                sendPushNotificationForRide('admin',$data['history_type'],$ride_request,$subject,$message);
            }

            if ($ride_request->cancel_by == 'rider') {
                $data['history_message'] = __('message.ride.rider_canceled');
                $history_data = [
                    'cancel_by' => $ride_request->cancel_by,
                    'rider_id' => $ride_request->rider_id,
                    'rider_name' => optional($ride_request->rider)->display_name ?? '',
                ];
                $subject = __('message.ride_canceled');
                $message = __('message.ride.rider_canceled');
                sendPushNotificationForRide('driver',$data['history_type'],$ride_request,$subject,$message);
            }

            if ($ride_request->cancel_by == 'driver') {
                $data['history_message'] = __('message.ride.driver_canceled');
                $history_data = [
                    'cancel_by' => $ride_request->cancel_by,
                    'driver_id' => $ride_request->driver_id,
                    'driver_name' => optional($ride_request->driver)->display_name ?? '',
                ];
                $subject = __('message.ride_canceled');
                $message = __('message.ride.driver_canceled');
                sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);
            }
            if ($ride_request->cancel_by == 'system') {
                $data['history_message'] = __('message.ride.system_canceled');
                $history_data = [
                    'cancel_by' => $ride_request->cancel_by,
                ];
                $subject = __('message.ride_canceled');
                $message = __('message.ride.system_canceled');
                sendPushNotificationForRide('admin',$data['history_type'],$ride_request,$subject,$message);
            }

            if ($ride_request->driver_id) {
                $ride_request->driver->update(['is_available' => 1]);
            } elseif ($ride_request->riderequest_in_driver) {
                $ride_request->riderequest_in_driver->update(['is_available' => 1]);
            }

            $sendEmail($ride_request, 'canceled', $dynamicData);

            // $mqtt_event = 'ride_request_status';
            $sendTo = removeValueFromArray(['admin', 'rider', 'driver'], $user_type);
        break;

        case 'driver_canceled':
            $data['history_message'] = __('message.ride.driver_canceled');
            $history_data = [
                'driver_id' => $ride_request->driver_id,
                'driver_name' => optional($ride_request->driver)->display_name ?? '',
            ];
            // $mqtt_event = 'ride_request_status';
            $sendEmail($ride_request, 'driver_canceled', $dynamicData);
            $sendTo = removeValueFromArray(['admin', 'rider'], $user_type);
            $subject = __('message.canceled');
            $message = __('message.ride.driver_canceled');
            sendPushNotificationForRide('driver',$data['history_type'],$ride_request,$subject,$message);
        break;

        case 'rider_canceled':
            $data['history_message'] = __('message.ride.rider_canceled');
            $history_data = [
                'rider_id' => $ride_request->rider_id,
                'rider_name' => optional($ride_request->rider)->display_name ?? '',
            ];
            $sendEmail($ride_request, 'rider_canceled', $dynamicData);
            $sendTo = removeValueFromArray(['admin', 'driver'], $user_type);
            $subject = __('message.canceled');
            $message = __('message.ride.rider_canceled');
            sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);
            break;

        break;
        case 'completed':
            //$data['history_message'] = __('message.ride.completed');
            try {
                if (!isset($data['history_type']) || !isset($data['ride_request_id'])) {
                    // Log::warning("Missing history_type or ride_request_id in saveRideHistory()");
                    return;
                }

                $history_type = $data['history_type'];
                $ride_request_id = $data['ride_request_id'];
                $ride_request = RideRequest::find($ride_request_id);

                if (!$ride_request) {
                    // Log::warning("Ride request not found for history_type={$history_type}, ride_request_id={$ride_request_id}");
                    return;
                }

                // Log::info("Saving ride history: ride_id={$ride_request_id}, history_type={$history_type}");

                switch ($history_type) {
                    case 'completed':
                        $data['history_message'] = __('message.ride.completed');

                        // Log::info("Processing completed ride history...");

                        $processReferral = function ($user, $ride_request) {
                            if (!$user || !$user->partner_referral_code) {
                                // Log::info("No referral code available for user_id=" . optional($user)->id);
                                return;
                            }

                            // Log::info("Referral process started for user_id={$user->id} with referral_code={$user->partner_referral_code}");

                            $partner = User::where('referral_code', $user->partner_referral_code)->first();

                            if (!$partner) {
                                Log::info("No partner found for referral_code={$user->partner_referral_code}");
                                return;
                            }

                            // Log::info("Partner found: partner_id={$partner->id}");

                            $wallet = Wallet::firstOrCreate(['user_id' => $partner->id], ['total_amount' => 0]);

                            $reference_amount = SettingData('reference_amount', 'reference_amount') ?? 0;
                            $reference_type = SettingData('reference_type', 'reference_type') ?? 'fixed';
                            $maxEarningPerMonth = SettingData('max_earning_per_month', 'max_earning_per_month') ?? 100;

                            // Log::info("Referral Settings => amount={$reference_amount}, type={$reference_type}, maxMonthlyLimit={$maxEarningPerMonth}");

                            $currentMonth = now()->format('Y-m');
                            $totalMonthlyReferrals = WalletHistory::where('user_id', $partner->id)
                                ->where('type', 'credit')
                                ->where('transaction_type', 'reference_reward')
                                ->whereDate('datetime', 'like', "$currentMonth%")
                                ->sum('amount');

                            // Log::info("Referral monthly total={$totalMonthlyReferrals}");

                            if ($reference_type == 'fixed') {
                                $amount_to_credit = $reference_amount;
                            } elseif ($reference_type == 'percentage') {
                                $amount_to_credit = ($reference_amount / 100) * $wallet->total_amount;
                            } else {
                                $amount_to_credit = 0;
                            }

                            // Log::info("Referral amount_to_credit={$amount_to_credit}");

                            if (($totalMonthlyReferrals + $amount_to_credit) <= $maxEarningPerMonth && $amount_to_credit > 0) {
                                $wallet->total_amount += $amount_to_credit;
                                $wallet->save();

                                // Log::info("Wallet updated: partner_id={$partner->id}, new_total={$wallet->total_amount}");

                                try {
                                    WalletHistory::create([
                                        'user_id'           => $partner->id,
                                        'type'              => 'credit',
                                        'transaction_type'  => 'reference_reward',
                                        'currency'          => SettingData('CURRENCY', 'CURRENCY_CODE') ?? 'USD',
                                        'amount'            => $amount_to_credit,
                                        'balance'           => $wallet->total_amount,
                                        'ride_request_id'   => $ride_request->id,
                                        'description'       => __('message.referral_commission_credited'),
                                        'datetime'          => now(),
                                    ]);

                                    // Log::info("Referral reward credited: partner_id={$partner->id}, amount={$amount_to_credit}");
                                } catch (\Exception $e) {
                                    // Log::error("Failed to create WalletHistory: " . $e->getMessage());
                                }
                            } else {
                                // Log::info("Referral reward skipped (limit reached or 0 amount).");
                            }
                        };

                        // Rider Referral
                        if ($ride_request->rider_id && $ride_request->rider) {
                            // Log::info("Checking referral for rider_id={$ride_request->rider_id}");
                            $processReferral($ride_request->rider, $ride_request);
                        }

                        // Driver Referral
                        if ($ride_request->driver_id && $ride_request->driver) {
                            // Log::info("Checking referral for driver_id={$ride_request->driver_id}");
                            $processReferral($ride_request->driver, $ride_request);
                        }

                        // Optional: Email/MQTT notification
                        // $sendEmail($ride_request, 'completed', $dynamicData);
                        break;

                    // Add other history types if needed
                }

                // RideRequestHistory::create([
                //     'ride_request_id' => $ride_request_id,
                //     'history_type'    => $history_type,
                //     'datetime'        => now(),
                //     'message'         => $data['history_message'] ?? '',
                // ]);
                $history_data = [
                    'rider_id'   => $ride_request->rider_id,
                    'rider_name' => optional($ride_request->rider)->display_name ?? '',
                ];
                // Log::info("Ride history saved for ride_id={$ride_request_id}, type={$history_type}");
                Log::info('Wallet Payment Status', [
                    'payment_status' => $ride_request->payment_type
                ]);
                if($ride_request->payment_type == 'wallet'){

                    $subject = __('message.ride_completed');
                    $message = __('message.ride.ride_completed_wallet');
                    sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);
                }else{
                    $subject = __('message.ride_completed');
                    $message = __('message.ride.ride_completed_cash');
                    sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);

                    $subject_driver = __('message.ride_completed');
                    $message_driver = __('message.ride.ride_completed_cash_driver');
                    sendPushNotificationForRide('driver',$data['history_type'],$ride_request,$subject_driver,$message_driver);
                }
            } catch (\Exception $e) {
                Log::error("Error in saveRideHistory(): " . $e->getMessage());
            }
        break;
        case 'payment_status_message':
            $data['history_message'] = __('message.ride.payment_status_message', ['id' => $ride_request->id, 'status' => __('message.' . optional($ride_request->payment)->payment_status)]);
            $history_data = [
                'rider_id' => $ride_request->rider_id,
                'status' => optional($ride_request->payment)->payment_status,
                'rider_name' => optional($ride_request->rider)->display_name ?? '',
            ];
            $dynamicData = array_merge($dynamicData, [
                '[payment_status]' => __('message.' . optional($ride_request->payment)->payment_status)
            ]);
            $sendEmail($ride_request, 'payment_status_message', $dynamicData);
            $sendTo = removeValueFromArray(['admin', 'driver', 'rider'], $user_type);
            // $mqtt_event = 'ride_request_status';

            if($ride_request->payment_type == 'wallet'){
                $subject = __('message.ride.wallet');
                $message = __('message.ride.wallet_payment');
                sendPushNotificationForRide('driver',$data['history_type'],$ride_request,$subject,$message);

                $subject_rider = __('message.payment_confirmed');
                $message_rider = __('message.ride.wallet_payment_rider');
                sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject_rider,$message_rider);

            }else{
                $subject = __('message.payment_confirmed');
                $message = __('message.ride.cash_payment');
                sendPushNotificationForRide('rider',$data['history_type'],$ride_request,$subject,$message);

            }
        break;



        default:
            # code...
            break;
    }

    $data['history_data'] = json_encode($history_data);

    if ($data['history_type'] != null) {
        RideRequestHistory::create($data);
    }

    if (count($sendTo) > 0) {
        $notification_data = [
            'id' => $ride_request->id,
            'type' => $data['history_type'],
            'subject' => __('message.' . $data['history_type']),
            'message' => $data['history_message'],
            'rider_id' => $ride_request->rider_id,
            'driver_id' => $ride_request->driver_id,
        ];

        $notify_data = new \stdClass();
        $notify_data->success = true;
        $notify_data->success_type = $data['history_type'];
        $notify_data->success_message = $data['history_message'];
        $notify_data->result = new RideRequestResource($ride_request);
        foreach ($sendTo as $send) {
            switch ($send) {
                case 'admin':
                    $user = User::admin();
                    break;
                case 'rider':
                    $user = User::whereId($ride_request->rider_id)->first();
                    break;
                case 'driver':
                    $user = User::whereId($ride_request->driver_id)->first();
                    break;
            }

            if ($user != null) {
                if ($send != 'driver') {
                    if ($data['history_type'] != 'new_ride_requested') {
                        try {
                            $document_name = 'ride_' . $ride_request->id;
                            // $collectionName = env('RIDE_COLLECTION');
                            $collectionName = config('services.firestore.ride_collection', 'rides');
                            $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document('ride_' . $ride_request->id);

                            $nearby_driver_ids = $ride_request->nearby_driver_ids;
                            if (is_string($nearby_driver_ids)) {
                                $nearby_driver_ids = json_decode($nearby_driver_ids, true);
                            } elseif (is_object($nearby_driver_ids)) {
                                $nearby_driver_ids = (array) $nearby_driver_ids;
                            }
                            $nearby_driver_ids = is_array($nearby_driver_ids) ? $nearby_driver_ids : [];

                            $rejected_bid_driver_ids = is_string($ride_request->rejected_bid_driver_ids)
                                ? json_decode($ride_request->rejected_bid_driver_ids, true)
                                : [];
                            $rejected_bid_driver_ids = is_array($rejected_bid_driver_ids) ? array_filter($rejected_bid_driver_ids) : [];

                            $updated_nearby_driver_ids = !empty($nearby_driver_ids) && !empty($rejected_bid_driver_ids)
                                ? array_diff($nearby_driver_ids, $rejected_bid_driver_ids)
                                : $nearby_driver_ids;

                            $rideData = [
                                'on_rider_stream_api_call' => 1,
                                'on_stream_api_call' => 1,
                                'ride_id' => $ride_request->id,
                                'rider_id' => $ride_request->rider_id,
                                'status' => $ride_request->status,
                                'ride_has_bid' => $ride_request->ride_has_bid,
                                'driver_ids' => $updated_nearby_driver_ids,
                                'extra_charges_payment_method' => 0,
                            ];

                            $rideRequestStatuses = ['bid_accepted', 'arrived', 'in_progress', 'completed', 'accepted', 'arriving'];
                            if (in_array($data['history_type'], $rideRequestStatuses) || in_array($ride_request->status, $rideRequestStatuses)) {
                                $rideData['driver_ids'] = [$ride_request->driver_id];
                            }

                            if ($data['history_type'] == 'bid_rejected') {
                                $rideData['status'] = 'bid_rejected';
                            }

                            $firebaseData->set($rideData, ['merge' => true]);

                            if ($ride_request->status == 'completed') {
                                $rideData['payment_status'] = $ride_request->payment->payment_status ?? '';
                                $rideData['payment_type'] = $ride_request->payment->payment_type ?? '';
                                $rideData['tips'] = $ride_request->tips ? 1 : 0;

                                $firebaseData->set($rideData, ['merge' => true]);

                                if ($ride_request->payment->payment_status === 'paid') {
                                    sleep(3);
                                    $firebaseData->delete();
                                }
                            } elseif ($data['history_type'] === 'canceled' || $ride_request->status === 'canceled') {
                                sleep(3);
                                $rideData['payment_status'] = 'canceled';
                                $firebaseData->set($rideData, ['merge' => true]);
                                $firebaseData->delete();
                            } else {
                                $rideData['payment_status'] = '';
                                $rideData['payment_type'] = '';
                                $rideData['tips'] = 0;
                                $firebaseData->set($rideData);
                            }
                        } catch (\Exception $e) {
                            \Log::error('Error updating Firestore document for Ride: ' . $e->getMessage());
                            \Log::error('Error context: ride_id=' . $ride_request->id . ' | rideData=' . json_encode($rideData));
                        }

                    }
                    $user->notify(new RideNotification($notification_data));
                }
                // $user->notify(new CommonNotification($notification_data['type'], $notification_data));
            }

            if ($user == null && isset($ride_request->riderequest_in_driver_id) && $ride_request->riderequest_in_driver != null && $data['history_type'] == 'canceled') {
                $ride_request->riderequest_in_driver->notify(new CommonNotification($notification_data['type'], $notification_data));
                $ride_request->update([
                    'riderequest_in_driver_id' => null,
                    'riderequest_in_datetime' => null
                ]);
            }
        }
    }
}

function checkMenuRoleAndPermission($menu)
{
    if (auth()->check()) {
        if ($menu->data('role') == null && auth()->user()->hasRole('admin')) {
            return true;
        }

        if ($menu->data('permission') == null && $menu->data('role') == null) {
            return true;
        }

        if ($menu->data('role') != null) {
            if (auth()->user()->hasAnyRole(explode(',', $menu->data('role')))) {
                return true;
            }
        }

        if ($menu->data('permission') != null) {
            if (auth()->user()->can($menu->data('permission'))) {
                return true;
            }
        }
    }
    return false;
}


function checkRolePermission($role, $permission)
{
    try {
        if ($role->hasPermissionTo($permission)) {
            return true;
        }
        return false;
    } catch (Exception $e) {
        return false;
    }
}

function getSingleMedia($model, $collection = 'profile_image', $skip = true)
{
    if (!auth()->check() && $skip) {
        return asset('images/user/1.jpg');
    }
    $media = null;
    if ($model !== null) {
        $media = $model->getFirstMedia($collection);
    }

    if (getFileExistsCheck($media)) {
        return $media->getFullUrl();
    } else {
        switch ($collection) {
            case 'profile_image':
                $media = asset('images/user/1.jpg');
                break;
            case 'site_logo':
                $media = asset('images/logo.png');
                break;
            case 'site_dark_logo':
                $media = asset('images/dark_logo.png');
                break;
            case 'gateway_image':
                $gateway_name = $model->type ?? 'default';
                $media = asset('images/' . $gateway_name . '.png');
                break;
            case 'site_favicon':
                $media = asset('images/favicon.ico');
                break;
            default:
                $media = asset('images/default.png');
                break;
        }
        return $media;
    }
}
function getServiceSingleMedia($model, $collection = 'profile_image', $skip = true)
{
    if (!auth()->check() && $skip) {
        return asset('images/user/1.jpg');
    }
    $media = null;
    if ($model !== null) {
        $media = $model->getFirstMedia($collection);
    }

    if (getFileExistsCheck($media)) {
        return $media->getFullUrl();
    } else {
        switch ($collection) {
            case 'profile_image':
                $media = asset('images/user/1.jpg');
                break;
            case 'site_logo':
                $media = asset('images/logo.png');
                break;
            case 'site_dark_logo':
                $media = asset('images/dark_logo.png');
                break;
            case 'gateway_image':
                $gateway_name = $model->type ?? 'default';
                $media = asset('images/' . $gateway_name . '.png');
                break;
            case 'site_favicon':
                $media = asset('images/favicon.ico');
                break;
            default:
                $media = asset('images/service_default.png');
                break;
        }
        return $media;
    }
}

function getFileExistsCheck($media)
{
    $mediaCondition = false;

    if ($media) {
        if ($media->disk == 'public') {
            $mediaCondition = file_exists($media->getPath());
        } else {
            $mediaCondition = Storage::disk($media->disk)->exists($media->getPath());
        }
    }
    return $mediaCondition;
}

function uploadMediaFile($model, $file, $name)
{
    if ($file) {
        $model->clearMediaCollection($name);
        if (is_array($file)) {
            foreach ($file as $key => $value) {
                $model->addMedia($value)->toMediaCollection($name);
            }
        } else {
            $model->addMedia($file)->toMediaCollection($name);
        }
    }

    return true;
}

function getAttachments($attchments)
{
    $files = [];
    if (count($attchments) > 0) {
        foreach ($attchments as $attchment) {
            if (getFileExistsCheck($attchment)) {
                array_push($files, $attchment->getFullUrl());
            }
        }
    }

    return $files;
}

function getMediaFileExit($model, $collection = 'profile_image')
{
    if ($model == null) {
        return asset('images/user/1.jpg');
    }

    $media = $model->getFirstMedia($collection);

    return getFileExistsCheck($media);
}

function couponVerifyResponse($status)
{
    $messages = [
        400 => __('message.coupons.code_invalid'),
        405 => __('message.coupons.expire'),
        406 => __('message.coupons.first_rider_only'),
        407 => __('message.coupons.applied_limit'),
        404 => __('message.coupons.code_not_found'),
    ];

    return [
        'message' => $messages[$status] ?? __('message.coupons.code_valid'),
    ];
}


function removeValueFromArray($array = [], $find = null)
{
    foreach (array_keys($array, $find) as $key) {
        unset($array[$key]);
    }

    return array_values($array);
}

function timeZoneList()
{
    $list = \DateTimeZone::listAbbreviations();
    $idents = \DateTimeZone::listIdentifiers();

    $data = $offset = $added = array();
    foreach ($list as $abbr => $info) {
        foreach ($info as $zone) {
            if (!empty($zone['timezone_id']) and !in_array($zone['timezone_id'], $added) and in_array($zone['timezone_id'], $idents)) {

                $z = new \DateTimeZone($zone['timezone_id']);
                $c = new \DateTime(null, $z);
                $zone['time'] = $c->format('H:i a');
                $offset[] = $zone['offset'] = $z->getOffset($c);
                $data[] = $zone;
                $added[] = $zone['timezone_id'];
            }
        }
    }

    array_multisort($offset, SORT_ASC, $data);
    $options = array();
    foreach ($data as $key => $row) {
        $options[$row['timezone_id']] = $row['time'] . ' - ' . formatOffset($row['offset']) . ' ' . $row['timezone_id'];
    }
    return $options;
}

function formatOffset($offset)
{
    $hours = $offset / 3600;
    $remainder = $offset % 3600;
    $sign = $hours > 0 ? '+' : '-';
    $hour = (int) abs($hours);
    $minutes = (int) abs($remainder / 60);

    if ($hour == 0 and $minutes == 0) {
        $sign = ' ';
    }
    return 'GMT' . $sign . str_pad($hour, 2, '0', STR_PAD_LEFT) . ':' . str_pad($minutes, 2, '0');
}
function languagesArray($ids = [])
{
    $language = [
        ['title' => 'Abkhaz', 'id' => 'ab'],
        ['title' => 'Afar', 'id' => 'aa'],
        ['title' => 'Afrikaans', 'id' => 'af'],
        ['title' => 'Akan', 'id' => 'ak'],
        ['title' => 'Albanian', 'id' => 'sq'],
        ['title' => 'Amharic', 'id' => 'am'],
        ['title' => 'Arabic', 'id' => 'ar'],
        ['title' => 'Aragonese', 'id' => 'an'],
        ['title' => 'Armenian', 'id' => 'hy'],
        ['title' => 'Assamese', 'id' => 'as'],
        ['title' => 'Avaric', 'id' => 'av'],
        ['title' => 'Avestan', 'id' => 'ae'],
        ['title' => 'Aymara', 'id' => 'ay'],
        ['title' => 'Azerbaijani', 'id' => 'az'],
        ['title' => 'Bambara', 'id' => 'bm'],
        ['title' => 'Bashkir', 'id' => 'ba'],
        ['title' => 'Basque', 'id' => 'eu'],
        ['title' => 'Belarusian', 'id' => 'be'],
        ['title' => 'Bengali', 'id' => 'bn'],
        ['title' => 'Bihari', 'id' => 'bh'],
        ['title' => 'Bislama', 'id' => 'bi'],
        ['title' => 'Bosnian', 'id' => 'bs'],
        ['title' => 'Breton', 'id' => 'br'],
        ['title' => 'Bulgarian', 'id' => 'bg'],
        ['title' => 'Burmese', 'id' => 'my'],
        ['title' => 'Catalan; Valencian', 'id' => 'ca'],
        ['title' => 'Chamorro', 'id' => 'ch'],
        ['title' => 'Chechen', 'id' => 'ce'],
        ['title' => 'Chichewa; Chewa; Nyanja', 'id' => 'ny'],
        ['title' => 'Chinese', 'id' => 'zh'],
        ['title' => 'Chuvash', 'id' => 'cv'],
        ['title' => 'Cornish', 'id' => 'kw'],
        ['title' => 'Corsican', 'id' => 'co'],
        ['title' => 'Cree', 'id' => 'cr'],
        ['title' => 'Croatian', 'id' => 'hr'],
        ['title' => 'Czech', 'id' => 'cs'],
        ['title' => 'Danish', 'id' => 'da'],
        ['title' => 'Divehi; Dhivehi; Maldivian;', 'id' => 'dv'],
        ['title' => 'Dutch', 'id' => 'nl'],
        ['title' => 'English', 'id' => 'en'],
        ['title' => 'Esperanto', 'id' => 'eo'],
        ['title' => 'Estonian', 'id' => 'et'],
        ['title' => 'Ewe', 'id' => 'ee'],
        ['title' => 'Faroese', 'id' => 'fo'],
        ['title' => 'Fijian', 'id' => 'fj'],
        ['title' => 'Finnish', 'id' => 'fi'],
        ['title' => 'French', 'id' => 'fr'],
        ['title' => 'Fula; Fulah; Pulaar; Pular', 'id' => 'ff'],
        ['title' => 'Galician', 'id' => 'gl'],
        ['title' => 'Georgian', 'id' => 'ka'],
        ['title' => 'German', 'id' => 'de'],
        ['title' => 'Greek, Modern', 'id' => 'el'],
        ['title' => 'Guaraní', 'id' => 'gn'],
        ['title' => 'Gujarati', 'id' => 'gu'],
        ['title' => 'Haitian; Haitian Creole', 'id' => 'ht'],
        ['title' => 'Hausa', 'id' => 'ha'],
        ['title' => 'Hebrew (modern)', 'id' => 'he'],
        ['title' => 'Herero', 'id' => 'hz'],
        ['title' => 'Hindi', 'id' => 'hi'],
        ['title' => 'Hiri Motu', 'id' => 'ho'],
        ['title' => 'Hungarian', 'id' => 'hu'],
        ['title' => 'Interlingua', 'id' => 'ia'],
        ['title' => 'Indonesian', 'id' => 'id'],
        ['title' => 'Interlingue', 'id' => 'ie'],
        ['title' => 'Irish', 'id' => 'ga'],
        ['title' => 'Igbo', 'id' => 'ig'],
        ['title' => 'Inupiaq', 'id' => 'ik'],
        ['title' => 'Ido', 'id' => 'io'],
        ['title' => 'Icelandic', 'id' => 'is'],
        ['title' => 'Italian', 'id' => 'it'],
        ['title' => 'Inuktitut', 'id' => 'iu'],
        ['title' => 'Japanese', 'id' => 'ja'],
        ['title' => 'Javanese', 'id' => 'jv'],
        ['title' => 'Kalaallisut, Greenlandic', 'id' => 'kl'],
        ['title' => 'Kannada', 'id' => 'kn'],
        ['title' => 'Kanuri', 'id' => 'kr'],
        ['title' => 'Kashmiri', 'id' => 'ks'],
        ['title' => 'Kazakh', 'id' => 'kk'],
        ['title' => 'Khmer', 'id' => 'km'],
        ['title' => 'Kikuyu, Gikuyu', 'id' => 'ki'],
        ['title' => 'Kinyarwanda', 'id' => 'rw'],
        ['title' => 'Kirghiz, Kyrgyz', 'id' => 'ky'],
        ['title' => 'Komi', 'id' => 'kv'],
        ['title' => 'Kongo', 'id' => 'kg'],
        ['title' => 'Korean', 'id' => 'ko'],
        ['title' => 'Kurdish', 'id' => 'ku'],
        ['title' => 'Kwanyama, Kuanyama', 'id' => 'kj'],
        ['title' => 'Latin', 'id' => 'la'],
        ['title' => 'Luxembourgish, Letzeburgesch', 'id' => 'lb'],
        ['title' => 'Luganda', 'id' => 'lg'],
        ['title' => 'Limburgish, Limburgan, Limburger', 'id' => 'li'],
        ['title' => 'Lingala', 'id' => 'ln'],
        ['title' => 'Lao', 'id' => 'lo'],
        ['title' => 'Lithuanian', 'id' => 'lt'],
        ['title' => 'Luba-Katanga', 'id' => 'lu'],
        ['title' => 'Latvian', 'id' => 'lv'],
        ['title' => 'Manx', 'id' => 'gv'],
        ['title' => 'Macedonian', 'id' => 'mk'],
        ['title' => 'Malagasy', 'id' => 'mg'],
        ['title' => 'Malay', 'id' => 'ms'],
        ['title' => 'Malayalam', 'id' => 'ml'],
        ['title' => 'Maltese', 'id' => 'mt'],
        ['title' => 'Māori', 'id' => 'mi'],
        ['title' => 'Marathi (Marāṭhī)', 'id' => 'mr'],
        ['title' => 'Marshallese', 'id' => 'mh'],
        ['title' => 'Mongolian', 'id' => 'mn'],
        ['title' => 'Nauru', 'id' => 'na'],
        ['title' => 'Navajo, Navaho', 'id' => 'nv'],
        ['title' => 'Norwegian Bokmål', 'id' => 'nb'],
        ['title' => 'North Ndebele', 'id' => 'nd'],
        ['title' => 'Nepali', 'id' => 'ne'],
        ['title' => 'Ndonga', 'id' => 'ng'],
        ['title' => 'Norwegian Nynorsk', 'id' => 'nn'],
        ['title' => 'Norwegian', 'id' => 'no'],
        ['title' => 'Nuosu', 'id' => 'ii'],
        ['title' => 'South Ndebele', 'id' => 'nr'],
        ['title' => 'Occitan', 'id' => 'oc'],
        ['title' => 'Ojibwe, Ojibwa', 'id' => 'oj'],
        ['title' => 'Oromo', 'id' => 'om'],
        ['title' => 'Oriya', 'id' => 'or'],
        ['title' => 'Ossetian, Ossetic', 'id' => 'os'],
        ['title' => 'Panjabi, Punjabi', 'id' => 'pa'],
        ['title' => 'Pāli', 'id' => 'pi'],
        ['title' => 'Persian', 'id' => 'fa'],
        ['title' => 'Polish', 'id' => 'pl'],
        ['title' => 'Pashto, Pushto', 'id' => 'ps'],
        ['title' => 'Portuguese', 'id' => 'pt'],
        ['title' => 'Quechua', 'id' => 'qu'],
        ['title' => 'Romansh', 'id' => 'rm'],
        ['title' => 'Kirundi', 'id' => 'rn'],
        ['title' => 'Romanian, Moldavian, Moldovan', 'id' => 'ro'],
        ['title' => 'Russian', 'id' => 'ru'],
        ['title' => 'Sanskrit (Saṁskṛta)', 'id' => 'sa'],
        ['title' => 'Sardinian', 'id' => 'sc'],
        ['title' => 'Sindhi', 'id' => 'sd'],
        ['title' => 'Northern Sami', 'id' => 'se'],
        ['title' => 'Samoan', 'id' => 'sm'],
        ['title' => 'Sango', 'id' => 'sg'],
        ['title' => 'Serbian', 'id' => 'sr'],
        ['title' => 'Scottish Gaelic; Gaelic', 'id' => 'gd'],
        ['title' => 'Shona', 'id' => 'sn'],
        ['title' => 'Sinhala, Sinhalese', 'id' => 'si'],
        ['title' => 'Slovak', 'id' => 'sk'],
        ['title' => 'Slovene', 'id' => 'sl'],
        ['title' => 'Somali', 'id' => 'so'],
        ['title' => 'Southern Sotho', 'id' => 'st'],
        ['title' => 'Spanish; Castilian', 'id' => 'es'],
        ['title' => 'Sundanese', 'id' => 'su'],
        ['title' => 'Swahili', 'id' => 'sw'],
        ['title' => 'Swati', 'id' => 'ss'],
        ['title' => 'Swedish', 'id' => 'sv'],
        ['title' => 'Tamil', 'id' => 'ta'],
        ['title' => 'Telugu', 'id' => 'te'],
        ['title' => 'Tajik', 'id' => 'tg'],
        ['title' => 'Thai', 'id' => 'th'],
        ['title' => 'Tigrinya', 'id' => 'ti'],
        ['title' => 'Tibetan Standard, Tibetan, Central', 'id' => 'bo'],
        ['title' => 'Turkmen', 'id' => 'tk'],
        ['title' => 'Tagalog', 'id' => 'tl'],
        ['title' => 'Tswana', 'id' => 'tn'],
        ['title' => 'Tonga (Tonga Islands)', 'id' => 'to'],
        ['title' => 'Turkish', 'id' => 'tr'],
        ['title' => 'Tsonga', 'id' => 'ts'],
        ['title' => 'Tatar', 'id' => 'tt'],
        ['title' => 'Twi', 'id' => 'tw'],
        ['title' => 'Tahitian', 'id' => 'ty'],
        ['title' => 'Uighur, Uyghur', 'id' => 'ug'],
        ['title' => 'Ukrainian', 'id' => 'uk'],
        ['title' => 'Urdu', 'id' => 'ur'],
        ['title' => 'Uzbek', 'id' => 'uz'],
        ['title' => 'Venda', 'id' => 've'],
        ['title' => 'Vietnamese', 'id' => 'vi'],
        ['title' => 'Volapük', 'id' => 'vo'],
        ['title' => 'Walloon', 'id' => 'wa'],
        ['title' => 'Welsh', 'id' => 'cy'],
        ['title' => 'Wolof', 'id' => 'wo'],
        ['title' => 'Western Frisian', 'id' => 'fy'],
        ['title' => 'Xhosa', 'id' => 'xh'],
        ['title' => 'Yiddish', 'id' => 'yi'],
        ['title' => 'Yoruba', 'id' => 'yo'],
        ['title' => 'Zhuang, Chuang', 'id' => 'za']
    ];

    if (!empty($ids)) {
        $language = collect($language)->whereIn('id', $ids)->values();
    }

    return $language;
}

function flattenToMultiDimensional(array $array, $delimiter = '.')
{
    $result = [];
    foreach ($array as $notations => $value) {
        // extract keys
        $keys = explode($delimiter, $notations);
        // reverse keys for assignments
        $keys = array_reverse($keys);

        // set initial value
        $lastVal = $value;
        foreach ($keys as $key) {
            // wrap value with key over each iteration
            $lastVal = [
                $key => $lastVal
            ];
        }
        // merge result
        $result = array_merge_recursive($result, $lastVal);
    }
    return $result;
}

function createLangFile($lang = '')
{
    $langDir = resource_path() . '/lang/';
    $enDir = $langDir . 'en';
    $currentLang = $langDir . $lang;

    if (!File::exists($currentLang)) {
        File::makeDirectory($currentLang, 0755, true);
        if (File::exists($enDir)) {
            File::copyDirectory($enDir, $currentLang);
        }
    }
}

function dateAgoFormate($date, $type2 = '')
{
    if ($date == null || $date == '0000-00-00 00:00:00') {
        return '-';
    }

    $diff_time1 = \Carbon\Carbon::createFromTimeStamp(strtotime($date))->diffForHumans();
    $datetime = new \DateTime($date);
    $la_time = new \DateTimeZone(auth()->check() ? auth()->user()->timezone ?? 'UTC' : 'UTC');
    $datetime->setTimezone($la_time);
    $diff_date = $datetime->format('Y-m-d H:i:s');

    $diff_time = \Carbon\Carbon::parse($diff_date)->isoFormat('LLL');

    if ($type2 != '') {
        return $diff_time;
    }

    return $diff_time1 . ' on ' . $diff_time;
}

function formatTimeOnly($date)
{
    if ($date == null || $date == '0000-00-00 00:00:00') {
        return '-';
    }

    $datetime = new \DateTime($date);
    $timezone = new \DateTimeZone(auth()->check() ? auth()->user()->timezone ?? 'UTC' : 'UTC');
    $datetime->setTimezone($timezone);

    return $datetime->format('h:i A');

}

function timeAgoFormate($date)
{
    if ($date == null) {
        return '-';
    }

    date_default_timezone_set('UTC');

    $diff_time = \Carbon\Carbon::createFromTimeStamp(strtotime($date))->diffForHumans();

    return $diff_time;
}

function timeAgoFormatenotification($date)
{
    if (empty($date)) {
        return '-';
    }
    // Make sure Carbon handles the date and uses Laravel's timezone (not hardcoded UTC)
    return \Carbon\Carbon::parse($date)->diffForHumans();
}

function envChanges($type, $value)
{
    $path = base_path('.env');

    $checkType = $type . '="';
    if (strpos($value, ' ') || strpos(file_get_contents($path), $checkType) || preg_match('/[\'^£$%&*()}{@#~?><>,|=_+¬-]/', $value)) {
        $value = '"' . $value . '"';
    }

    $value = str_replace('\\', '\\\\', $value);

    if (file_exists($path)) {
        $typeValue = env($type);

        if (strpos(env($type), ' ') || strpos(file_get_contents($path), $checkType)) {
            $typeValue = '"' . env($type) . '"';
        }

        file_put_contents($path, str_replace(
            $type . '=' . $typeValue,
            $type . '=' . $value,
            file_get_contents($path)
        ));

        $onesignal = collect(config('constant.ONESIGNAL'))->keys();

        $checkArray = Arr::collapse([['DEFAULT_LANGUAGE']]);


        if (in_array($type, $checkArray)) {
            if (env($type) === null) {
                file_put_contents($path, "\n" . $type . '=' . $value, FILE_APPEND);
            }
        }
    }
}

function convertUnitvalue($unit)
{
    switch ($unit) {
        case 'mile':
            return 3956;
            break;
        default:
            return 6371;
            break;
    }
}

function mile_to_km($mile)
{
    return $mile * 1.60934;
}

function km_to_mile($km)
{
    return $km * 0.621371;
}

// function mighty_get_distance_matrix($pick_lat, $pick_lng, $drop_lat, $drop_lng, $traffic = false)
// {
//     $google_map_api_key = env('GOOGLE_MAP_KEY');

//     $response = Http::withHeaders([
//         'X-Goog-Api-Key' => $google_map_api_key,
//         'Accept-Language' => request('language'),
//         ])->get('https://maps.googleapis.com/maps/api/distancematrix/json?origins=' . $pick_lat . ',' . $pick_lng . '&destinations=' . $drop_lat . ',' . $drop_lng . '&mode=driving');

//     $responses = $response->json();

//     return $responses;
// }

function mighty_get_distance_matrix($pick_lat, $pick_lng, $drop_lat, $drop_lng, $traffic = false)
{
    $google_map_api_key = env('GOOGLE_MAP_KEY');
    if (!$google_map_api_key) {
        return response()->json(['error' => 'Google Map API Key is missing'], 500);
    }


    $originAddress = getFormattedAddress($pick_lat, $pick_lng, $google_map_api_key);
    $destinationAddress = getFormattedAddress($drop_lat, $drop_lng, $google_map_api_key);
    // Log::info('Origin Address: ' . $originAddress);
    // Log::info('Destination Address: ' . $destinationAddress);


    // Request to Distance Matrix API v2
    $response = Http::withHeaders([
        'Content-Type' => 'application/json',
        'X-Goog-Api-Key' => $google_map_api_key,
        'X-Goog-FieldMask' => 'originIndex,destinationIndex,status,distanceMeters,duration'
    ])->post('https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix', [
        "origins" => [
            ["waypoint" => ["location" => ["latLng" => ["latitude" => (float) $pick_lat, "longitude" => (float) $pick_lng]]]]
        ],
        "destinations" => [
            ["waypoint" => ["location" => ["latLng" => ["latitude" => (float) $drop_lat, "longitude" => (float) $drop_lng]]]]
        ],
        "travelMode" => "DRIVE"
    ]);
    // Log::info('Raw Google API Distance Matrix response:', $response->json());


    if (!$response->successful()) {
        return response()->json(['error' => 'Failed to retrieve distance matrix', 'details' => $response->body()], 500);
    }

    $routeData = $response->json()[0] ?? null;

    if (!$routeData || !isset($routeData['distanceMeters']) || !isset($routeData['duration'])) {
        return response()->json([
            'error' => 'Invalid response from Distance Matrix API',
            'api_response' => $response->json()
        ], 400);
    }
    $distanceMeters = is_numeric($routeData['distanceMeters']) ? $routeData['distanceMeters'] : 0;
    $rawDuration = $routeData['duration'] ?? '0s';
    $durationSeconds = (int) rtrim($rawDuration, 's'); // safely cast

    $convertedResponse = [
        "destination_addresses" => [$destinationAddress],
        "origin_addresses" => [$originAddress],
        "rows" => [
            [
                "elements" => [
                    [
                        "distance" => [
                            "text" => round($distanceMeters / 1000, 1) . " km",
                            "value" => $distanceMeters
                        ],
                        "duration" => [
                            "text" => round($durationSeconds / 60) . " mins",
                            "value" => $durationSeconds
                        ],
                        "status" => $routeData['status'] ?? 'UNKNOWN'
                    ]
                ]
            ]
        ],
        "status" => "OK"
    ];
//    Log::info('Final Converted Distance Matrix Response:', $convertedResponse);



    return $convertedResponse;
}
 // Get formatted addresses using Geocoding API
    function getFormattedAddress($lat, $lng, $google_map_api_key) {
        $response = Http::get("https://maps.googleapis.com/maps/api/geocode/json", [
            'latlng' => "$lat,$lng",
            'key' => $google_map_api_key
        ]);

        if ($response->json()['status'] !== 'OK') {
            return "$lat,$lng";
        }

        return $response->json()['results'][0]['formatted_address'] ?? "$lat,$lng";
    }

function distance_value_from_distance_matrix($distance_matrix)
{
    $element = first_element_in_distance_matrix($distance_matrix);
    // Log::info('Extracted distance element:', is_array($element) ? $element : ['element' => $element ?? 'null']);

    if (isset($element) && isset($element['distance'])) {
        return (float) $element['distance']['value'];
    }

    return null;
}

function duration_value_from_distance_matrix($distance_matrix)
{
    $element = first_element_in_distance_matrix($distance_matrix);

    // Log::info('Extracted distance element:', is_array($element) ? $element : ['element' => $element]);

        if (isset($element['duration_in_traffic'])) {
            return (int) $element['duration_in_traffic']['value'];
        } elseif (isset($element['duration'])) {
            return (int) $element['duration']['value'];
        }

    return null;
}



// function first_element_in_distance_matrix($distance_matrix)
// {
//     try {
//         $row = $distance_matrix['rows'][0];
//         return $row['elements'][0];
//     } catch (\Throwable $th) {
//         return null;
//     }

// }

function first_element_in_distance_matrix($distance_matrix)
{
    try {
        if (!is_array($distance_matrix)) {
            return null;
        }

        $row = $distance_matrix['rows'][0] ?? null;
        return $row['elements'][0] ?? null;

    } catch (\Throwable $th) {
        Log::error('Error extracting first element from distance matrix', [
            'error' => $th->getMessage(),
            'distance_matrix' => is_object($distance_matrix) ? get_class($distance_matrix) : $distance_matrix
        ]);
        return null;
    }
}


function calculateNewRideFares( $distance_in_unit, $dropoff_time_in_seconds, $service, $surge_price = null,$trip_type = 'normal')
{
    $minimum_distance = $service['minimum_distance'] ?? 0;

    // Base fare
    $base_fare = $service['base_fare'];

    // Distance fare
    $chargeable_distance = max(0, $distance_in_unit - $minimum_distance);
    $distance_price = $chargeable_distance * $service['per_distance'];

    $perMinuteDrive =  SettingData('ride', 'per_minute_drive');
    // Time fare
    $time_price = 0;
    if($perMinuteDrive){
        $time_price = ($dropoff_time_in_seconds / 60) * $service['per_minute_drive'];
    }

    // Subtotal before surge
    $subtotal = $base_fare + $distance_price + $time_price;

    // Surge for regular ride request
    $surge_amount = 0;
    if ($surge_price) {
        if ($surge_price->type === 'fixed') {
            $surge_amount = $surge_price->value;
        } elseif ($surge_price->type === 'percentage') {
            $surge_amount = ($subtotal * $surge_price->value) / 100;
        }
    }

    // Total before minimum fare
    $total_amount = $subtotal + $surge_amount;

    // Apply minimum fare
    if ($total_amount < $service['minimum_fare']) {
        $total_amount = $service['minimum_fare'];
        $subtotal     = $total_amount;
        $surge_amount = 0;
    }
    /* ---------------- ZONE PRICE ---------------- */
    $is_zoneprice = 0;
    if (request('trip_type') === 'zone_wise') {
        $pickup_zone_id = request('pickup_zone_id');
        $drop_zone_id   = request('drop_zone_id');

        $zone_price = ZonePrice::where('zone_pickup', $pickup_zone_id)->where('zone_dropoff', $drop_zone_id)->whereJsonContains('service_ids', (string) $service['id'])->latest()->first();

        $surge_amount = 0;
        if ($surge_price) {
            if ($surge_price->type === 'fixed') {
                $surge_amount = $surge_price->value;
            } elseif ($surge_price->type === 'percentage') {
                $surge_amount = ($zone_price->price * $surge_price->value) / 100;
            }
        }

        if ($zone_price) {
            $subtotal        = $zone_price->price;
            $total_amount    = $zone_price->price + $surge_amount;
            $surge_amount    = $surge_amount;
            $is_zoneprice    = 1;
        }
    }

    return [
        'distance'       => round($distance_in_unit, 2),
        'distance_price' => round($distance_price, 2),
        'time_price'     => round($time_price, 2),
        'subtotal'       => round($subtotal, 2),
        'surge_amount'   => round($surge_amount, 2),
        'total_amount'   => round($total_amount, 2),
        'is_zoneprice'   => $is_zoneprice,
    ];
}


function haversineDistance($lat1, $lng1, $lat2, $lng2)
{
    $earthRadius = 6371;

    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);

    $a = sin($dLat / 2) * sin($dLat / 2) +
        cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
        sin($dLng / 2) * sin($dLng / 2);

    $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
    $distance = $earthRadius * $c;
    return $distance;
}


function calculateRideDuration($start_time, $end_time = null)
{
    // if (!$start_time || !$end_time) {
    //     return 0;
    // }
    $end_time = $end_time ?? now();
    $start = Carbon::parse($start_time);
    $end   = Carbon::parse($end_time);
    return $start->diffInMinutes($end);
}


function calculate_distance($lat1, $lng1, $lat2, $lng2, $unit)
{
    if (($lat1 == $lat2) && ($lng1 == $lng2)) {
        return 0;
    } else {
        $theta = $lng1 - $lng2;
        $dist = sin(deg2rad($lat1)) * sin(deg2rad($lat2)) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * cos(deg2rad($theta));
        $dist = acos($dist);
        $dist = rad2deg($dist);
        $miles = $dist * 60 * 1.1515;

        if ($unit == "km") {
            return ($miles * 1.609344);
        } elseif ($unit == "mile") {
            return ($miles * 0.8684);
        } else {
            return $miles;
        }
    }
}

function SettingData($type, $key = null)
{
    $setting = Setting::where('type', $type);

    $setting->when($key != null, function ($q) use ($key) {
        return $q->where('key', $key);
    });

    $setting_data = $setting->pluck('value')->first();
    return $setting_data;
}

function getPriceFormat($price)
{
    if (gettype($price) == 'string') {
        return $price;
    }
    if ($price === null) {
        $price = 0;
    }

    $currency_code = SettingData('CURRENCY', 'CURRENCY_CODE') ?? 'USD';
    $currecy = currencyArray($currency_code);

    $code = $currecy['symbol'] ?? '$';
    $position = SettingData('CURRENCY', 'CURRENCY_POSITION') ?? 'left';

    if ($position == 'left') {
        $price = $code . "" . number_format((float) $price, 2, '.', '');
    } else {
        $price = number_format((float) $price, 2, '.', '') . "" . $code;
    }

    return $price;
}

function convertTimeStringToDoubleMinutes($timeString)
{
    $hours = 0;
    $minutes = 0;

    if (preg_match('/(\d+)\s*hr/', $timeString, $hrMatch)) {
        $hours = (int) $hrMatch[1];
    }

    if (preg_match('/(\d+)\s*min/', $timeString, $minMatch)) {
        $minutes = (int) $minMatch[1];
    }

    return round(($hours * 60) + $minutes, 2);
}

function verify_coupon_code($coupon_code)
{
    $coupon = Coupon::where('code', $coupon_code)->first();
    $status = isset($coupon_code) ? 200 : 400;
    if ($coupon != null) {
        $status = Coupon::isValidCoupon($coupon);
    }
    if ($status != 200) {
        $response = couponVerifyResponse($status);
    }
    $response['status'] = $status;
    return $response;
}

function currencyArray($code = null)
{
    $currency = [
        ['code' => 'AED', 'name' => 'United Arab Emirates dirham', 'symbol' => 'د.إ'],
        ['code' => 'AFN', 'name' => 'Afghan afghani', 'symbol' => '؋'],
        ['code' => 'ALL', 'name' => 'Albanian lek', 'symbol' => 'L'],
        ['code' => 'AMD', 'name' => 'Armenian dram', 'symbol' => 'AMD'],
        ['code' => 'ANG', 'name' => 'Netherlands Antillean guilder', 'symbol' => 'ƒ'],
        ['code' => 'AOA', 'name' => 'Angolan kwanza', 'symbol' => 'Kz'],
        ['code' => 'ARS', 'name' => 'Argentine peso', 'symbol' => '$'],
        ['code' => 'AUD', 'name' => 'Australian dollar', 'symbol' => '$'],
        ['code' => 'AWG', 'name' => 'Aruban florin', 'symbol' => 'Afl.'],
        ['code' => 'AZN', 'name' => 'Azerbaijani manat', 'symbol' => 'AZN'],
        ['code' => 'BAM', 'name' => 'Bosnia and Herzegovina convertible mark', 'symbol' => 'KM'],
        ['code' => 'BBD', 'name' => 'Barbadian dollar', 'symbol' => '$'],
        ['code' => 'BDT', 'name' => 'Bangladeshi taka', 'symbol' => '৳ '],
        ['code' => 'BGN', 'name' => 'Bulgarian lev', 'symbol' => 'лв.'],
        ['code' => 'BHD', 'name' => 'Bahraini dinar', 'symbol' => '.د.ب'],
        ['code' => 'BIF', 'name' => 'Burundian franc', 'symbol' => 'Fr'],
        ['code' => 'BMD', 'name' => 'Bermudian dollar', 'symbol' => '$'],
        ['code' => 'BND', 'name' => 'Brunei dollar', 'symbol' => '$'],
        ['code' => 'BOB', 'name' => 'Bolivian boliviano', 'symbol' => 'Bs.'],
        ['code' => 'BRL', 'name' => 'Brazilian real', 'symbol' => 'R$'],
        ['code' => 'BSD', 'name' => 'Bahamian dollar', 'symbol' => '$'],
        ['code' => 'BTC', 'name' => 'Bitcoin', 'symbol' => '฿'],
        ['code' => 'BTN', 'name' => 'Bhutanese ngultrum', 'symbol' => 'Nu.'],
        ['code' => 'BWP', 'name' => 'Botswana pula', 'symbol' => 'P'],
        ['code' => 'BYR', 'name' => 'Belarusian ruble (old)', 'symbol' => 'Br'],
        ['code' => 'BYN', 'name' => 'Belarusian ruble', 'symbol' => 'Br'],
        ['code' => 'BZD', 'name' => 'Belize dollar', 'symbol' => '$'],
        ['code' => 'CAD', 'name' => 'Canadian dollar', 'symbol' => '$'],
        ['code' => 'CDF', 'name' => 'Congolese franc', 'symbol' => 'Fr'],
        ['code' => 'CHF', 'name' => 'Swiss franc', 'symbol' => 'CHF'],
        ['code' => 'CLP', 'name' => 'Chilean peso', 'symbol' => '$'],
        ['code' => 'CNY', 'name' => 'Chinese yuan', 'symbol' => '¥'],
        ['code' => 'COP', 'name' => 'Colombian peso', 'symbol' => '$'],
        ['code' => 'CRC', 'name' => 'Costa Rican colón', 'symbol' => '₡'],
        ['code' => 'CUC', 'name' => 'Cuban convertible peso', 'symbol' => '$'],
        ['code' => 'CUP', 'name' => 'Cuban peso', 'symbol' => '$'],
        ['code' => 'CVE', 'name' => 'Cape Verdean escudo', 'symbol' => '$'],
        ['code' => 'CZK', 'name' => 'Czech koruna', 'symbol' => 'Kč'],
        ['code' => 'DJF', 'name' => 'Djiboutian franc', 'symbol' => 'Fr'],
        ['code' => 'DKK', 'name' => 'Danish krone', 'symbol' => 'kr.'],
        ['code' => 'DOP', 'name' => 'Dominican peso', 'symbol' => 'RD$'],
        ['code' => 'DZD', 'name' => 'Algerian dinar', 'symbol' => 'د.ج'],
        ['code' => 'EGP', 'name' => 'Egyptian pound', 'symbol' => 'EGP'],
        ['code' => 'ERN', 'name' => 'Eritrean nakfa', 'symbol' => 'Nfk'],
        ['code' => 'ETB', 'name' => 'Ethiopian birr', 'symbol' => 'Br'],
        ['code' => 'EUR', 'name' => 'Euro', 'symbol' => '€'],
        ['code' => 'FJD', 'name' => 'Fijian dollar', 'symbol' => '$'],
        ['code' => 'FKP', 'name' => 'Falkland Islands pound', 'symbol' => '£'],
        ['code' => 'GBP', 'name' => 'Pound sterling', 'symbol' => '£'],
        ['code' => 'GEL', 'name' => 'Georgian lari', 'symbol' => 'ლ'],
        ['code' => 'GGP', 'name' => 'Guernsey pound', 'symbol' => '£'],
        ['code' => 'GHS', 'name' => 'Ghana cedi', 'symbol' => '₵'],
        ['code' => 'GIP', 'name' => 'Gibraltar pound', 'symbol' => '£'],
        ['code' => 'GMD', 'name' => 'Gambian dalasi', 'symbol' => 'D'],
        ['code' => 'GNF', 'name' => 'Guinean franc', 'symbol' => 'Fr'],
        ['code' => 'GTQ', 'name' => 'Guatemalan quetzal', 'symbol' => 'Q'],
        ['code' => 'GYD', 'name' => 'Guyanese dollar', 'symbol' => '$'],
        ['code' => 'HKD', 'name' => 'Hong Kong dollar', 'symbol' => '$'],
        ['code' => 'HNL', 'name' => 'Honduran lempira', 'symbol' => 'L'],
        ['code' => 'HRK', 'name' => 'Croatian kuna', 'symbol' => 'kn'],
        ['code' => 'HTG', 'name' => 'Haitian gourde', 'symbol' => 'G'],
        ['code' => 'HUF', 'name' => 'Hungarian forint', 'symbol' => 'Ft'],
        ['code' => 'IDR', 'name' => 'Indonesian rupiah', 'symbol' => 'Rp'],
        ['code' => 'ILS', 'name' => 'Israeli new shekel', 'symbol' => '₪'],
        ['code' => 'IMP', 'name' => 'Manx pound', 'symbol' => '£'],
        ['code' => 'INR', 'name' => 'Indian rupee', 'symbol' => '₹'],
        ['code' => 'IQD', 'name' => 'Iraqi dinar', 'symbol' => 'د.ع'],
        ['code' => 'IRR', 'name' => 'Iranian rial', 'symbol' => '﷼'],
        ['code' => 'IRT', 'name' => 'Iranian toman', 'symbol' => 'تومان'],
        ['code' => 'ISK', 'name' => 'Icelandic króna', 'symbol' => 'kr.'],
        ['code' => 'JEP', 'name' => 'Jersey pound', 'symbol' => '£'],
        ['code' => 'JMD', 'name' => 'Jamaican dollar', 'symbol' => '$'],
        ['code' => 'JOD', 'name' => 'Jordanian dinar', 'symbol' => 'د.ا'],
        ['code' => 'JPY', 'name' => 'Japanese yen', 'symbol' => '¥'],
        ['code' => 'KES', 'name' => 'Kenyan shilling', 'symbol' => 'KSh'],
        ['code' => 'KGS', 'name' => 'Kyrgyzstani som', 'symbol' => 'сом'],
        ['code' => 'KHR', 'name' => 'Cambodian riel', 'symbol' => '៛'],
        ['code' => 'KMF', 'name' => 'Comorian franc', 'symbol' => 'Fr'],
        ['code' => 'KPW', 'name' => 'North Korean won', 'symbol' => '₩'],
        ['code' => 'KRW', 'name' => 'South Korean won', 'symbol' => '₩'],
        ['code' => 'KWD', 'name' => 'Kuwaiti dinar', 'symbol' => 'د.ك'],
        ['code' => 'KYD', 'name' => 'Cayman Islands dollar', 'symbol' => '$'],
        ['code' => 'KZT', 'name' => 'Kazakhstani tenge', 'symbol' => '₸'],
        ['code' => 'LAK', 'name' => 'Lao kip', 'symbol' => '₭'],
        ['code' => 'LBP', 'name' => 'Lebanese pound', 'symbol' => 'ل.ل'],
        ['code' => 'LKR', 'name' => 'Sri Lankan rupee', 'symbol' => 'රු'],
        ['code' => 'LRD', 'name' => 'Liberian dollar', 'symbol' => '$'],
        ['code' => 'LSL', 'name' => 'Lesotho loti', 'symbol' => 'L'],
        ['code' => 'LYD', 'name' => 'Libyan dinar', 'symbol' => 'ل.د'],
        ['code' => 'MAD', 'name' => 'Moroccan dirham', 'symbol' => 'د.م.'],
        ['code' => 'MDL', 'name' => 'Moldovan leu', 'symbol' => 'MDL'],
        ['code' => 'MGA', 'name' => 'Malagasy ariary', 'symbol' => 'Ar'],
        ['code' => 'MKD', 'name' => 'Macedonian denar', 'symbol' => 'ден'],
        ['code' => 'MMK', 'name' => 'Burmese kyat', 'symbol' => 'Ks'],
        ['code' => 'MNT', 'name' => 'Mongolian tögrög', 'symbol' => '₮'],
        ['code' => 'MOP', 'name' => 'Macanese pataca', 'symbol' => 'P'],
        ['code' => 'MRU', 'name' => 'Mauritanian ouguiya', 'symbol' => 'UM'],
        ['code' => 'MUR', 'name' => 'Mauritian rupee', 'symbol' => '₨'],
        ['code' => 'MVR', 'name' => 'Maldivian rufiyaa', 'symbol' => '.ރ'],
        ['code' => 'MWK', 'name' => 'Malawian kwacha', 'symbol' => 'MK'],
        ['code' => 'MXN', 'name' => 'Mexican peso', 'symbol' => '$'],
        ['code' => 'MYR', 'name' => 'Malaysian ringgit', 'symbol' => 'RM'],
        ['code' => 'MZN', 'name' => 'Mozambican metical', 'symbol' => 'MT'],
        ['code' => 'NAD', 'name' => 'Namibian dollar', 'symbol' => 'N$'],
        ['code' => 'NGN', 'name' => 'Nigerian naira', 'symbol' => '₦'],
        ['code' => 'NIO', 'name' => 'Nicaraguan córdoba', 'symbol' => 'C$'],
        ['code' => 'NOK', 'name' => 'Norwegian krone', 'symbol' => 'kr'],
        ['code' => 'NPR', 'name' => 'Nepalese rupee', 'symbol' => '₨'],
        ['code' => 'NZD', 'name' => 'New Zealand dollar', 'symbol' => '$'],
        ['code' => 'OMR', 'name' => 'Omani rial', 'symbol' => 'ر.ع.'],
        ['code' => 'PAB', 'name' => 'Panamanian balboa', 'symbol' => 'B/.'],
        ['code' => 'PEN', 'name' => 'Sol', 'symbol' => 'S/'],
        ['code' => 'PGK', 'name' => 'Papua New Guinean kina', 'symbol' => 'K'],
        ['code' => 'PHP', 'name' => 'Philippine peso', 'symbol' => '₱'],
        ['code' => 'PKR', 'name' => 'Pakistani rupee', 'symbol' => '₨'],
        ['code' => 'PLN', 'name' => 'Polish złoty', 'symbol' => 'zł'],
        ['code' => 'PRB', 'name' => 'Transnistrian ruble', 'symbol' => 'р.'],
        ['code' => 'PYG', 'name' => 'Paraguayan guaraní', 'symbol' => '₲'],
        ['code' => 'QAR', 'name' => 'Qatari riyal', 'symbol' => 'ر.ق'],
        ['code' => 'RON', 'name' => 'Romanian leu', 'symbol' => 'lei'],
        ['code' => 'RSD', 'name' => 'Serbian dinar', 'symbol' => 'рсд'],
        ['code' => 'RUB', 'name' => 'Russian ruble', 'symbol' => '₽'],
        ['code' => 'RWF', 'name' => 'Rwandan franc', 'symbol' => 'Fr'],
        ['code' => 'SAR', 'name' => 'Saudi riyal', 'symbol' => 'ر.س'],
        ['code' => 'SBD', 'name' => 'Solomon Islands dollar', 'symbol' => '$'],
        ['code' => 'SCR', 'name' => 'Seychellois rupee', 'symbol' => '₨'],
        ['code' => 'SDG', 'name' => 'Sudanese pound', 'symbol' => 'ج.س.'],
        ['code' => 'SEK', 'name' => 'Swedish krona', 'symbol' => 'kr'],
        ['code' => 'SGD', 'name' => 'Singapore dollar', 'symbol' => '$'],
        ['code' => 'SHP', 'name' => 'Saint Helena pound', 'symbol' => '£'],
        ['code' => 'SLL', 'name' => 'Sierra Leonean leone', 'symbol' => 'Le'],
        ['code' => 'SOS', 'name' => 'Somali shilling', 'symbol' => 'Sh'],
        ['code' => 'SRD', 'name' => 'Surinamese dollar', 'symbol' => '$'],
        ['code' => 'SSP', 'name' => 'South Sudanese pound', 'symbol' => '£'],
        ['code' => 'STN', 'name' => 'São Tomé and Príncipe dobra', 'symbol' => 'Db'],
        ['code' => 'SYP', 'name' => 'Syrian pound', 'symbol' => 'ل.س'],
        ['code' => 'SZL', 'name' => 'Swazi lilangeni', 'symbol' => 'E'],
        ['code' => 'THB', 'name' => 'Thai baht', 'symbol' => '฿'],
        ['code' => 'TJS', 'name' => 'Tajikistani somoni', 'symbol' => 'ЅМ'],
        ['code' => 'TMT', 'name' => 'Turkmenistan manat', 'symbol' => 'm'],
        ['code' => 'TND', 'name' => 'Tunisian dinar', 'symbol' => 'د.ت'],
        ['code' => 'TOP', 'name' => 'Tongan paʻanga', 'symbol' => 'T$'],
        ['code' => 'TRY', 'name' => 'Turkish lira', 'symbol' => '₺'],
        ['code' => 'TTD', 'name' => 'Trinidad and Tobago dollar', 'symbol' => '$'],
        ['code' => 'TWD', 'name' => 'New Taiwan dollar', 'symbol' => 'NT$'],
        ['code' => 'TZS', 'name' => 'Tanzanian shilling', 'symbol' => 'Sh'],
        ['code' => 'UAH', 'name' => 'Ukrainian hryvnia', 'symbol' => '₴'],
        ['code' => 'UGX', 'name' => 'Ugandan shilling', 'symbol' => 'UGX'],
        ['code' => 'USD', 'name' => 'United States (US) dollar', 'symbol' => '$'],
        ['code' => 'UYU', 'name' => 'Uruguayan peso', 'symbol' => '$'],
        ['code' => 'UZS', 'name' => 'Uzbekistani som', 'symbol' => 'UZS'],
        ['code' => 'VEF', 'name' => 'Venezuelan bolívar', 'symbol' => 'Bs F'],
        ['code' => 'VES', 'name' => 'Bolívar soberano', 'symbol' => 'Bs.S'],
        ['code' => 'VND', 'name' => 'Vietnamese đồng', 'symbol' => '₫'],
        ['code' => 'VUV', 'name' => 'Vanuatu vatu', 'symbol' => 'Vt'],
        ['code' => 'WST', 'name' => 'Samoan tālā', 'symbol' => 'T'],
        ['code' => 'XAF', 'name' => 'Central African CFA franc', 'symbol' => 'CFA'],
        ['code' => 'XCD', 'name' => 'East Caribbean dollar', 'symbol' => '$'],
        ['code' => 'XOF', 'name' => 'West African CFA franc', 'symbol' => 'CFA'],
        ['code' => 'XPF', 'name' => 'CFP franc', 'symbol' => 'Fr'],
        ['code' => 'YER', 'name' => 'Yemeni rial', 'symbol' => '﷼'],
        ['code' => 'ZAR', 'name' => 'South African rand', 'symbol' => 'R'],
        ['code' => 'ZMW', 'name' => 'Zambian kwacha', 'symbol' => 'ZK'],
    ];

    if ($code != null) {
        $currency = collect($currency)->where('code', $code)->first();
    }
    return $currency;
}

function driver_common_document($driver)
{
    $documents = Document::where('is_required', 1)->where('status', 1)->pluck('id')->toArray();
    $is_common_document = $driver->driverDocument()->whereIn('document_id', $documents)->count();

    if (count($documents) == $is_common_document) {
        return true;
    } else {
        return false;
    }
}

function driver_required_document($driver)
{
    $required_document = $driver->driverDocument()->pluck('document_id')->toArray();
    $documents = Document::where('is_required', 1)->where('status', 1)->whereNotIn('id', $required_document)->get();

    return $documents;
}

function stringLong($str = '', $type = 'title', $length = 0) //Add … if string is too long
{
    if ($length != 0) {
        return strlen($str) > $length ? mb_substr($str, 0, $length) . "..." : $str;
    }
    if ($type == 'desc') {
        return strlen($str) > 150 ? mb_substr($str, 0, 150) . "..." : $str;
    } elseif ($type == 'title') {
        return strlen($str) > 15 ? mb_substr($str, 0, 25) . "..." : $str;
    } else {
        return $str;
    }
}

function mighty_get_distance_matrix_multiple_destination($pick_lat, $pick_lng, $drop_lat, $drop_lng, $drop_latlng, $traffic = false)
{
    \Log::info("Drop Location Received", ['drop_latlng' => $drop_latlng]);

    // Ensure drop locations are an array
    if (!is_array($drop_latlng)) {
        $drop_latlng = json_decode($drop_latlng, true);
    }

    // Convert to array if necessary
    if (!is_array($drop_latlng)) {
        $drop_latlng = [$drop_latlng];
    }

    // Filter valid locations
    $drop_latlng = array_filter($drop_latlng, function ($location) {
        return isset($location['lat']) && isset($location['lng']);
    });

    $distance = 0;
    $duration = 0;
    $count = count($drop_latlng);

    for ($i = 0; $i <= $count; $i++) {
        if ($i == 0) {
            $fromLat = $pick_lat;
            $fromLng = $pick_lng;
            $toLat = $drop_latlng[$i]['lat'] ?? null;
            $toLng = $drop_latlng[$i]['lng'] ?? null;
        } elseif ($i == $count) {
            $fromLat = $drop_latlng[$i - 1]['lat'] ?? null;
            $fromLng = $drop_latlng[$i - 1]['lng'] ?? null;
            $toLat = $drop_lat;
            $toLng = $drop_lng;
        } else {
            $fromLat = $drop_latlng[$i - 1]['lat'] ?? null;
            $fromLng = $drop_latlng[$i - 1]['lng'] ?? null;
            $toLat = $drop_latlng[$i]['lat'] ?? null;
            $toLng = $drop_latlng[$i]['lng'] ?? null;
        }

        if ($fromLat === null || $fromLng === null || $toLat === null || $toLng === null) {
            \Log::warning("Skipping invalid drop location", [
                'fromLat' => $fromLat,
                'fromLng' => $fromLng,
                'toLat' => $toLat,
                'toLng' => $toLng
            ]);
            continue;
        }

        $response = mighty_get_distance_matrix($fromLat, $fromLng, $toLat, $toLng);

        if (!empty($response)) {
            $distance += distance_value_from_distance_matrix($response);
            $duration += duration_value_from_distance_matrix($response);
        }
    }

    \Log::info("Total Distance & Duration", ['distance' => $distance, 'duration' => $duration]);

    return [
        'distance' => $distance ?? 0, // Ensure distance exists
        'duration' => $duration ?? 0  // Ensure duration exists
    ];
}

function maskSensitiveInfo($type, $info)
{
    if (($type === 'email' && empty($info)) || ($type === 'contact_number' && empty($info)) || ($type === 'ip_address' && empty($info))) {
        return '-';
    }
    if(env('APP_DEMO')) {
        switch ($type) {
            case 'email':
                $parts = explode('@', $info);
                $username = $parts[0];
                $domain = $parts[1] ?? '';
                $maskedUsername = substr($username, 0, 1) . str_repeat('*', strlen($username) - 1);
                return $maskedUsername . '@' . $domain;

            case 'contact_number':
                return substr($info, 0, 3) . str_repeat('*', strlen($info) - 4) . substr($info, -2);

            case 'ip_address':
                $parts = explode('.', $info);
                if(count($parts) === 4) {
                    return $parts[0] . '.' . $parts[1] . '.*.*';
                }
                return substr($info, 0, 5) . '***';

            default:
                return $info;
        }
    } else {
        return $info;
    }
}

if (!function_exists('getDaysOfWeek')) {
    function getDaysOfWeek()
    {
        return [
            '1' => 'Monday',
            '2' => 'Tuesday',
            '3' => 'Wednesday',
            '4' => 'Thursday',
            '5' => 'Friday',
            '6' => 'Saturday',
            '7' => 'Sunday',
        ];
    }
}

    function getSurgePrice($ride_datetime, $service_id)
    {
        if ($ride_datetime === null) {
            return null;
        }

        $surge_price_setting_value = SettingData('ride', 'surge_price') ?? null;

        if ($surge_price_setting_value == 1) {
            $ride_datetime = \Carbon\Carbon::parse($ride_datetime);
            $day_id = $ride_datetime->format('N'); // 1 = Mon ... 7 = Sun
            $current_time = $ride_datetime->format('H:i');

            $service = Service::find($service_id);
            if (!$service) {
                return 0; // return 0 if service not found
            }

            $region_id = $service->region_id;

            $surge_price = SurgePrice::where('region_id', $region_id)
                ->whereJsonContains('day', $day_id)
                ->first();

            if ($surge_price) {
                $from_times = $surge_price->from_time ?? [];
                $to_times   = $surge_price->to_time ?? [];

                foreach ($from_times as $index => $from_time) {
                    $to_time = $to_times[$index] ?? null;

                  if (strtotime($current_time) >= strtotime($from_time) && strtotime($current_time) <= strtotime($to_time)) {
                        return $surge_price;
                    }
                }
            }

            return 0; // if no surge matched
        } else {
            $surge_price = 0;
        }

        return $surge_price;
    }

function updateLanguageVersion()
{
    $language_version_data = LanguageVersionDetail::find(1);
    return $language_version_data->increment('version_no', 1);
}

function mighty_language_direction($language = null)
{
    if (empty($language)) {
        $language = app()->getLocale();
    }
    $language = strtolower(substr($language, 0, 2));
    $rtlLanguages = [
        'ar', //  'العربية', Arabic
        'arc', //  'ܐܪܡܝܐ', Aramaic
        'bcc', //  'بلوچی مکرانی', Southern Balochi`
        'bqi', //  'بختياري', Bakthiari
        'ckb', //  'Soranî / کوردی', Sorani Kurdish
        'dv', //  'ދިވެހިބަސް', Dhivehi
        'fa', //  'فارسی', Persian
        'glk', //  'گیلکی', Gilaki
        'he', //  'עברית', Hebrew
        'lrc', //- 'لوری', Northern Luri
        'mzn', //  'مازِرونی', Mazanderani
        'pnb', //  'پنجابی', Western Punjabi
        'ps', //  'پښتو', Pashto
        'sd', //  'سنڌي', Sindhi
        'ug', //  'Uyghurche / ئۇيغۇرچە', Uyghur
        'ur', //  'اردو', Urdu
        'yi', //  'ייִדיש', Yiddish
    ];
    if (in_array($language, $rtlLanguages)) {
        return 'rtl';
    }

    return 'ltr';
}

function rideStatus()
{
    return [
        'new_ride_requested' => __('message.new_ride_requested'),
        'pending' => __('message.pending'),
        'accepted' => __('message.accepted'),
        'arriving' => __('message.arriving'),
        'arrived' => __('message.arrived'),
        'in_progress' => __('message.in_progress'),
        'completed' => __('message.completed'),
        'canceled' => __('message.canceled'),
    ];
}

function pointInPolygon(array $point, array $polygon): bool
{
    $x = $point[1];
    $y = $point[0];
    $inside = false;

    $numPoints = count($polygon);
    for ($i = 0, $j = $numPoints - 1; $i < $numPoints; $j = $i++) {
        $xi = $polygon[$i][1];
        $yi = $polygon[$i][0];
        $xj = $polygon[$j][1];
        $yj = $polygon[$j][0];

        $intersect = (($yi > $y) !== ($yj > $y)) &&
            ($x < ($xj - $xi) * ($y - $yi) / (($yj - $yi) ?: 1e-10) + $xi);
        if ($intersect) {
            $inside = !$inside;
        }
    }

    return $inside;
}
function getSmsSettings($type = null, $sms_setting_key = null)
{
    if ($type !== null) {
        $sms_setting = SMSSetting::where('status', 1)->where('type', $type)->first();

        if ($sms_setting) {
            return $sms_setting_key === 'get' ? $sms_setting->values : $sms_setting;
        }

        return false;
    }

    $all_sms_settings = SMSSetting::where('status', 1)->get();

    if ($all_sms_settings->isEmpty()) {
        return false;
    }

    return $all_sms_settings->pluck('values', 'type')->toArray();
}
function SMSData($type, $sms_setting_key = null, $message = null, $data = [])
{
    $sms_setting = SMSSetting::where('type', $type)->first();

    if ($sms_setting) {
        $status = $data['status'] ?? null;

        if (!$status) {
            return false;
        }

        // Status ke basis par directly template fetch karo
        $sms_template = SMSTemplatRide::where('ride_status', $status)->first();

        if (!$sms_template) {
            return false;
        }

        // Template description leke placeholders replace karo
        $message = replacePlaceholders(strip_tags($sms_template->sms_description), $data);

        // Agar "get" pass hua ho to usi message ko return karo
        if ($sms_setting_key === 'get') {
            return $message;
        }
    }

    return false;
}
/**
 * Function to replace placeholders with actual values in SMS templates.
 */
function replacePlaceholders($message, $data)
{
    foreach ($data as $key => $value) {
        $message = str_replace("[$key]", $value, $message);
    }
    return $message;
}

function otpCode($length = 7)
{
    $characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return substr(str_shuffle($characters), 0, $length);
}

function shortenWithTinyURL($longUrl)
{
    $response = Http::get("https://tinyurl.com/api-create.php", [
        'url' => $longUrl
    ]);
    if ($response->successful()) {
        return $response->body();
    } else {
        Log::error("TinyURL API failed: " . $response->status());
    }
    return $longUrl;
}

function sentOTP_mail($otp_verification_status = 'disable', $user)
{
    $otp = Str::random(6);
    $otp = preg_replace('/[^0-9]/', '', $otp);
    $otp = substr($otp, 0, 6);

    if (strlen($otp) < 6) {
        $otp = str_pad(mt_rand(0, 999999), 6, '0');
    }
    Session::put('otp', $otp);

    // Set OTP expiration time (30 mins from now)
    $otpExpiry = Carbon::now()->addMinutes(30);

    $emailData = MailTemplate::where('type', 'otp_verification_mail')->first();
    $dynamicData = [
        '[OTP]' => $otp,
    ];
    $mailDescription = str_replace(array_keys($dynamicData), array_values($dynamicData), $emailData->description ?? '');
    $content = ['mailDescription' => $mailDescription, 'otp' => $otp];
    try {
        Mail::to($user->email)->send(new OTPVerificationMail($content, $emailData->subject));
    } catch (\Exception $e) {
        \Log::error("Failed to send email for for otp verification, Error: {$e->getMessage()}");
    }
    User::where('id', $user->id)->update(['otp' => $otp, 'otp_expires_at' => $otpExpiry]);

}
function generateRandomCode()
{
    $letters = substr(str_shuffle("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), 0, 2);

    // 1 digit from 1–9
    $thirdDigit = rand(1, 9);

    // 3 digits, each from 1–9 (no zeroes)
    $lastThreeDigits = '';
    for ($i = 0; $i < 3; $i++) {
        $lastThreeDigits .= rand(1, 9);
    }

    $randomCode = $letters . $thirdDigit . $lastThreeDigits;

    return $randomCode;
}

    function getDriverPickupDistance($ride_request, $unit = 'km')
    {
        $driverId = $ride_request->driver_id ?? $ride_request->riderequest_in_driver_id;

        $pickup_lat = $ride_request->start_latitude;
        $pickup_lng = $ride_request->start_longitude;

        $driver = \App\Models\User::find($driverId);
        $distance = 0;
        $duration = 0;
        if($driver){

            $driver_lat = $driver->latitude;
            $driver_lng = $driver->longitude;

            $place_details = mighty_get_distance_matrix($driver_lat, $driver_lng, $pickup_lat, $pickup_lng, $unit);

            $distance = round(distance_value_from_distance_matrix($place_details) / 1000, 2);

            $duration = duration_value_from_distance_matrix($place_details);
            if ($duration > 0) {
                $duration = round($duration / 60, 2);
            }
        }

        return compact('distance', 'duration');
    }


    function calculateEstimatedServiceFromRide($ride)
    {
        $dropoff_distance_in_meters = 0;
        $dropoff_time_in_seconds = 0;
        $distance_in_unit = 0;

        if (!empty($ride->multi_drop_location)) {
            $drop_latlng = json_decode($ride->multi_drop_location, true);

            if (is_array($drop_latlng)) {
                $place_details = mighty_get_distance_matrix_multiple_destination(
                    $ride->start_latitude,
                    $ride->start_longitude,
                    $ride->end_latitude,
                    $ride->end_longitude,
                    $drop_latlng
                );

                $dropoff_distance_in_meters = $place_details['distance'] ?? 0;
                $dropoff_time_in_seconds = $place_details['duration'] ?? 0;
            }
        } else {
            $place_details = mighty_get_distance_matrix(
                $ride->start_latitude,
                $ride->start_longitude,
                $ride->end_latitude,
                $ride->end_longitude
            );

            $dropoff_distance_in_meters = distance_value_from_distance_matrix($place_details);
            $dropoff_time_in_seconds = duration_value_from_distance_matrix($place_details);
        }

        if ($dropoff_distance_in_meters) {
            $distance_in_unit = $dropoff_distance_in_meters / 1000;
        }

        $service = Service::find($ride->service_id);
        if ($service) {
            $service->start_latitude = $ride->start_latitude;
            $service->start_longitude = $ride->start_longitude;
            $service->end_latitude = $ride->end_latitude;
            $service->end_longitude = $ride->end_longitude;
            $service->distance_in_unit = $distance_in_unit;
            $service->dropoff_distance_in_meters = $dropoff_distance_in_meters;
            $service->dropoff_time_in_seconds = $dropoff_time_in_seconds;

            return new EstimateServiceResource($service);
        }

        return null;
    }
    function calculateCommission($service, $amount)
    {
        $admin_commission = 0;
        $driver_commission = 0;
        if($service && !empty($service)){
            if ($service->commission_type == 'percentage') {
                $admin_commission = $amount * ($service->admin_commission / 100);
                $fleet_commission = $amount * ($service->fleet_commission / 100);

                $admin_commission += $fleet_commission;
            }else {
                $admin_commission = $service->admin_commission + $service->fleet_commission;
            }
            $driver_commission = $amount - $admin_commission;
        }

        return [
            'admin_commission' => $admin_commission,
            'driver_commission' => $driver_commission,
        ];
    }
  if (!function_exists('get_nearby_driver')) {
    function get_nearby_driver($ride_request)
    {
        $unit = $ride_request->distance_unit ?? 'km';
        $unit_value = convertUnitvalue($unit);
        $radius = Setting::where('type', 'DISTANCE')->where('key', 'DISTANCE_RADIUS')->pluck('value')->first() ?? 50;

        $latitude = $ride_request->start_latitude;
        $longitude = $ride_request->start_longitude;

        return User::where('status', 'active')
            ->where('user_type', 'driver')
            ->where('is_online', 1)
            ->where('is_available', 1)
            ->where('service_id', $ride_request->service_id)
            ->selectRaw("users.*, (
                $unit_value * acos(
                    cos(radians($latitude)) * cos(radians(latitude)) *
                    cos(radians(longitude) - radians($longitude)) +
                    sin(radians($latitude)) * sin(radians(latitude))
                )
            ) AS distance")
            ->having("distance", "<=", $radius)
            ->orderBy("distance", "asc")
            ->first(); // 🔁 only 1 nearest
    }
}

function createAppLanguageSetting($data)
{
    foreach ($data as $screen) {
        $screen_record = Screen::where('screenID', $screen['screenID'])->first();
        if ( empty($screen_record) ) {
            $screen_record = Screen::create([
                'screenId'   => $screen['screenID'],
                'screenName' => $screen['ScreenName']
            ]);
        }

        if ( !empty($screen['keyword_data']) ) {
            foreach ($screen['keyword_data'] as $keyword_data) {
                $check_default_keyword = DefaultKeyword::where('keyword_id', $keyword_data['keyword_id'])->first();
                if ( empty($check_default_keyword) ) {
                    $default_keyword = DefaultKeyword::create([
                        'screen_id' => $screen_record['screenId'],
                        'keyword_id' => $keyword_data['keyword_id'],
                        'keyword_name' => $keyword_data['keyword_name'],
                        'keyword_value' => $keyword_data['keyword_value']
                    ]);

                    $language_list = LanguageList::get();
                    if ( count($language_list) > 0 ) {
                        foreach ($language_list as $value) {
                            $language_with_data = [
                                'id' => null,
                                'keyword_id' => $default_keyword->keyword_id,
                                'screen_id' => $default_keyword->screen_id,
                                'language_id' => $value->id,
                                'keyword_value' => $default_keyword->keyword_value,
                            ];
                            LanguageWithKeyword::create($language_with_data);
                        }
                    }
                }
            }
        }
    }
}
function country()
{
    $country = [
        [
            "countryNameEn" => "Andorra",
            "countryCode" => "AD",
            "region" => "Europe",
            "flag" => "🇦🇩"
        ],
        [
            "countryNameEn" => "Afghanistan",
            "countryCode" => "AF",
            "region" => "Asia & Pacific",
            "flag" => "🇦🇫"
        ],
        [
            "countryNameEn" => "Antigua and Barbuda",
            "countryCode" => "AG",
            "region" => "South/Latin America",
            "flag" => "🇦🇬"
        ],
        [
            "countryNameEn" => "Anguilla",
            "countryCode" => "AI",
            "region" => "South/Latin America",
            "flag" => "🇦🇮"
        ],
        [
            "countryNameEn" => "Albania",
            "countryCode" => "AL",
            "region" => "Europe",
            "flag" => "🇦🇱"
        ],
        [
            "countryNameEn" => "Armenia",
            "countryCode" => "AM",
            "region" => "Europe",
            "flag" => "🇦🇲"
        ],
        [
            "countryNameEn" => "Angola",
            "countryCode" => "AO",
            "region" => "Africa",
            "flag" => "🇦🇴"
        ],
        [
            "countryNameEn" => "Antarctica",
            "countryCode" => "AQ",
            "region" => "Asia & Pacific",
            "flag" => "🇦🇶"
        ],
        [
            "countryNameEn" => "Argentina",
            "countryCode" => "AR",
            "region" => "South/Latin America",
            "flag" => "🇦🇷"
        ],
        [
            "countryNameEn" => "American Samoa",
            "countryCode" => "AS",
            "region" => "Asia & Pacific",
            "flag" => "🇦🇸"
        ],
        [
            "countryNameEn" => "Austria",
            "countryCode" => "AT",
            "region" => "Europe",
            "flag" => "🇦🇹"
        ],
        [
            "countryNameEn" => "Australia",
            "countryCode" => "AU",
            "region" => "Asia & Pacific",
            "flag" => "🇦🇺"
        ],
        [
            "countryNameEn" => "Aruba",
            "countryCode" => "AW",
            "region" => "South/Latin America",
            "flag" => "🇦🇼"
        ],
        [
            "countryNameEn" => "Åland Islands",
            "countryCode" => "AX",
            "region" => "Europe",
            "flag" => "🇦🇽"
        ],
        [
            "countryNameEn" => "Azerbaijan",
            "countryCode" => "AZ",
            "region" => "Asia & Pacific",
            "flag" => "🇦🇿"
        ],
        [
            "countryNameEn" => "Bosnia and Herzegovina",
            "countryCode" => "BA",
            "region" => "Europe",
            "flag" => "🇧🇦"
        ],
        [
            "countryNameEn" => "Barbados",
            "countryCode" => "BB",
            "region" => "South/Latin America",
            "flag" => "🇧🇧"
        ],
        [
            "countryNameEn" => "Bangladesh",
            "countryCode" => "BD",
            "region" => "Asia & Pacific",
            "flag" => "🇧🇩"
        ],
        [
            "countryNameEn" => "Belgium",
            "countryCode" => "BE",
            "region" => "Europe",
            "flag" => "🇧🇪"
        ],
        [
            "countryNameEn" => "Burkina Faso",
            "countryCode" => "BF",
            "region" => "Africa",
            "flag" => "🇧🇫"
        ],
        [
            "countryNameEn" => "Bulgaria",
            "countryCode" => "BG",
            "region" => "Europe",
            "flag" => "🇧🇬"
        ],
        [
            "countryNameEn" => "Bahrain",
            "countryCode" => "BH",
            "region" => "Arab States",
            "flag" => "🇧🇭"
        ],
        [
            "countryNameEn" => "Burundi",
            "countryCode" => "BI",
            "region" => "Africa",
            "flag" => "🇧🇮"
        ],
        [
            "countryNameEn" => "Benin",
            "countryCode" => "BJ",
            "region" => "Africa",
            "flag" => "🇧🇯"
        ],
        [
            "countryNameEn" => "Saint Barthélemy",
            "countryCode" => "BL",
            "region" => "South/Latin America",
            "flag" => "🇧🇱"
        ],
        [
            "countryNameEn" => "Bermuda",
            "countryCode" => "BM",
            "region" => "North America",
            "flag" => "🇧🇲"
        ],
        [
            "countryNameEn" => "Brunei Darussalam",
            "countryCode" => "BN",
            "region" => "Asia & Pacific",
            "flag" => "🇧🇳"
        ],
        [
            "countryNameEn" => "Bolivia (Plurinational State of)",
            "countryCode" => "BO",
            "region" => "South/Latin America",
            "flag" => "🇧🇴"
        ],
        [
            "countryNameEn" => "Bonaire, Sint Eustatius and Saba",
            "countryCode" => "BQ",
            "region" => "Unknown",
            "flag" => "🇧🇶"
        ],
        [
            "countryNameEn" => "Brazil",
            "countryCode" => "BR",
            "region" => "South/Latin America",
            "flag" => "🇧🇷"
        ],
        [
            "countryNameEn" => "Bhutan",
            "region" => "Asia & Pacific",
            "flag" => "🇧🇹"
        ],
        [
            "countryNameEn" => "Bouvet Island",
            "countryCode" => "BV",
            "region" => "South/Latin America",
            "flag" => "🇧🇻"
        ],
        [
            "countryNameEn" => "Botswana",
            "countryCode" => "BW",
            "region" => "Africa",
            "flag" => "🇧🇼"
        ],
        [
            "countryNameEn" => "Belarus",
            "countryCode" => "BY",
            "region" => "Europe",
            "flag" => "🇧🇾"
        ],
        [
            "countryNameEn" => "Belize",
            "countryCode" => "BZ",
            "region" => "South/Latin America",
            "flag" => "🇧🇿"
        ],
        [
            "countryNameEn" => "Canada",
            "countryCode" => "CA",
            "region" => "North America",
            "flag" => "🇨🇦"
        ],
        [
            "countryNameEn" => "Switzerland",
            "countryCode" => "CH",
            "region" => "Europe",
            "flag" => "🇨🇭"
        ],
        [
            "countryNameEn" => "Côte d'Ivoire",
            "countryCode" => "CI",
            "region" => "Africa",
            "flag" => "🇨🇮"
        ],
        [
            "countryNameEn" => "Chile",
            "countryCode" => "CL",
            "region" => "South/Latin America",
            "flag" => "🇨🇱"
        ],
        [
            "countryNameEn" => "Cameroon",
            "countryCode" => "CM",
            "region" => "Africa",
            "flag" => "🇨🇲"
        ],
        [
            "countryNameEn" => "China",
            "countryCode" => "CN",
            "region" => "Asia & Pacific",
            "flag" => "🇨🇳"
        ],
        [
            "countryNameEn" => "Colombia",
            "countryCode" => "CO",
            "region" => "South/Latin America",
            "flag" => "🇨🇴"
        ],
        [
            "countryNameEn" => "Costa Rica",
            "countryCode" => "CR",
            "region" => "South/Latin America",
            "flag" => "🇨🇷"
        ],
        [
            "countryNameEn" => "Cuba",
            "countryCode" => "CU",
            "region" => "South/Latin America",
            "flag" => "🇨🇺"
        ],
        [
            "countryNameEn" => "Cabo Verde",
            "countryCode" => "CV",
            "region" => "Africa",
            "flag" => "🇨🇻"
        ],
        [
            "countryNameEn" => "Curaçao",
            "countryCode" => "CW",
            "region" => "Unknown",
            "flag" => "🇨🇼"
        ],
        [
            "countryNameEn" => "Christmas Island",
            "countryCode" => "CX",
            "region" => "Asia & Pacific",
            "flag" => "🇨🇽"
        ],
        [
            "countryNameEn" => "Cyprus",
            "countryCode" => "CY",
            "region" => "Europe",
            "flag" => "🇨🇾"
        ],
        [
            "countryNameEn" => "Germany",
            "countryCode" => "DE",
            "region" => "Europe",
            "flag" => "🇩🇪"
        ],
        [
            "countryNameEn" => "Djibouti",
            "countryCode" => "DJ",
            "flag" => "🇩🇯"
        ],
        [
            "countryNameEn" => "Denmark",
            "countryCode" => "DK",
            "region" => "Europe",
            "flag" => "🇩🇰"
        ],
        [
            "countryNameEn" => "Dominica",
            "countryCode" => "DM",
            "region" => "South/Latin America",
            "flag" => "🇩🇲"
        ],
        [
            "countryNameEn" => "Algeria",
            "countryCode" => "DZ",
            "region" => "Arab States",
            "flag" => "🇩🇿"
        ],
        [
            "countryNameEn" => "Ecuador",
            "countryCode" => "EC",
            "region" => "South/Latin America",
            "flag" => "🇪🇨"
        ],
        [
            "countryNameEn" => "Estonia",
            "countryCode" => "EE",
            "region" => "Europe",
            "flag" => "🇪🇪"
        ],
        [
            "countryNameEn" => "Egypt",
            "countryCode" => "EG",
            "region" => "Arab States",
            "flag" => "🇪🇬"
        ],
        [
            "countryNameEn" => "Western Sahara",
            "countryCode" => "EH",
            "region" => "Africa",
            "flag" => "🇪🇭"
        ],
        [
            "countryNameEn" => "Eritrea",
            "countryCode" => "ER",
            "region" => "Africa",
            "flag" => "🇪🇷"
        ],
        [
            "countryNameEn" => "Spain",
            "countryCode" => "ES",
            "region" => "Europe",
            "flag" => "🇪🇸"
        ],
        [
            "countryNameEn" => "Ethiopia",
            "countryCode" => "ET",
            "region" => "Africa",
            "flag" => "🇪🇹"
        ],
        [
            "countryNameEn" => "Finland",
            "countryCode" => "FI",
            "region" => "Europe",
            "flag" => "🇫🇮"
        ],
        [
            "countryNameEn" => "Fiji",
            "countryCode" => "FJ",
            "region" => "Asia & Pacific",
            "flag" => "🇫🇯"
        ],
        [
            "countryNameEn" => "Micronesia (Federated States of)",
            "countryCode" => "FM",
            "region" => "Asia & Pacific",
            "flag" => "🇫🇲"
        ],
        [
            "countryNameEn" => "France",
            "countryCode" => "FR",
            "region" => "Europe",
            "flag" => "🇫🇷"
        ],
        [
            "countryNameEn" => "Gabon",
            "countryCode" => "GA",
            "region" => "Africa",
            "flag" => "🇬🇦"
        ],
        [
            "countryNameEn" => "Grenada",
            "countryCode" => "GD",
            "region" => "South/Latin America",
            "flag" => "🇬🇩"
        ],
        [
            "countryNameEn" => "Georgia",
            "countryCode" => "GE",
            "region" => "Europe",
            "flag" => "🇬🇪"
        ],
        [
            "countryNameEn" => "French Guiana",
            "countryCode" => "GF",
            "region" => "South/Latin America",
            "flag" => "🇬🇫"
        ],
        [
            "countryNameEn" => "Guernsey",
            "countryCode" => "GG",
            "region" => "Europe",
            "flag" => "🇬🇬"
        ],
        [
            "countryNameEn" => "Ghana",
            "countryCode" => "GH",
            "region" => "Africa",
            "flag" => "🇬🇭"
        ],
        [
            "countryNameEn" => "Gibraltar",
            "countryCode" => "GI",
            "region" => "Europe",
            "flag" => "🇬🇮"
        ],
        [
            "countryNameEn" => "Greenland",
            "countryCode" => "GL",
            "region" => "Europe",
            "flag" => "🇬🇱"
        ],
        [
            "countryNameEn" => "Guinea",
            "countryCode" => "GN",
            "region" => "Africa",
            "flag" => "🇬🇳"
        ],
        [
            "countryNameEn" => "Guadeloupe",
            "countryCode" => "GP",
            "region" => "South/Latin America",
            "flag" => "🇬🇵"
        ],
        [
            "countryNameEn" => "Equatorial Guinea",
            "countryCode" => "GQ",
            "region" => "Africa",
            "flag" => "🇬🇶"
        ],
        [
            "countryNameEn" => "Greece",
            "countryCode" => "GR",
            "region" => "Europe",
            "flag" => "🇬🇷"
        ],
        [
            "countryNameEn" => "South Georgia and the South Sandwich Islands",
            "countryCode" => "GS",
            "region" => "South/Latin America",
            "flag" => "🇬🇸"
        ],
        [
            "countryNameEn" => "Guatemala",
            "countryCode" => "GT",
            "region" => "South/Latin America",
            "flag" => "🇬🇹"
        ],
        [
            "countryNameEn" => "Guam",
            "countryCode" => "GU",
            "region" => "Asia & Pacific",
            "flag" => "🇬🇺"
        ],
        [
            "countryNameEn" => "Guinea-Bissau",
            "countryCode" => "GW",
            "region" => "Africa",
            "flag" => "🇬🇼"
        ],
        [
            "countryNameEn" => "Guyana",
            "countryCode" => "GY",
            "region" => "South/Latin America",
            "flag" => "🇬🇾"
        ],
        [
            "countryNameEn" => "Hong Kong",
            "countryCode" => "HK",
            "region" => "Asia & Pacific",
            "flag" => "🇭🇰"
        ],
        [
            "countryNameEn" => "Honduras",
            "countryCode" => "HN",
            "region" => "South/Latin America",
            "flag" => "🇭🇳"
        ],
        [
            "countryNameEn" => "Croatia",
            "countryCode" => "HR",
            "region" => "Europe",
            "flag" => "🇭🇷"
        ],
        [
            "countryNameEn" => "Haiti",
            "countryCode" => "HT",
            "region" => "South/Latin America",
            "flag" => "🇭🇹"
        ],
        [
            "countryNameEn" => "Hungary",
            "countryCode" => "HU",
            "region" => "Europe",
            "flag" => "🇭🇺"
        ],
        [
            "countryNameEn" => "Indonesia",
            "countryCode" => "ID",
            "region" => "Asia & Pacific",
            "flag" => "🇮🇩"
        ],
        [
            "countryNameEn" => "Ireland",
            "countryCode" => "IE",
            "region" => "Europe",
            "flag" => "🇮🇪"
        ],
        [
            "countryNameEn" => "Israel",
            "countryCode" => "IL",
            "region" => "Europe",
            "flag" => "🇮🇱"
        ],
        [
            "countryNameEn" => "Isle of Man",
            "countryCode" => "IM",
            "region" => "Europe",
            "flag" => "🇮🇲"
        ],
        [
            "countryNameEn" => "India",
            "countryCode" => "IN",
            "region" => "Asia & Pacific",
            "flag" => "🇮🇳"
        ],
        [
            "countryNameEn" => "British Indian Ocean Territories",
            "countryCode" => "IO",
            "region" => "Indian Ocean",
            "flag" => "🇮🇴",
        ],
        [
            "countryNameEn" => "Iraq",
            "countryCode" => "IQ",
            "region" => "Arab States",
            "flag" => "🇮🇶"
        ],
        [
            "countryNameEn" => "Iran (Islamic Republic of)",
            "countryCode" => "IR",
            "region" => "Asia & Pacific",
            "flag" => "🇮🇷"
        ],
        [
            "countryNameEn" => "Iceland",
            "countryCode" => "IS",
            "region" => "Europe",
            "flag" => "🇮🇸"
        ],
        [
            "countryNameEn" => "Italy",
            "countryCode" => "IT",
            "region" => "Europe",
            "flag" => "🇮🇹"
        ],
        [
            "countryNameEn" => "Jersey",
            "countryCode" => "JE",
            "region" => "Europe",
            "flag" => "🇯🇪"
        ],
        [
            "countryNameEn" => "Jamaica",
            "countryCode" => "JM",
            "region" => "South/Latin America",
            "flag" => "🇯🇲"
        ],
        [
            "countryNameEn" => "Jordan",
            "countryCode" => "JO",
            "region" => "Arab States",
            "flag" => "🇯🇴"
        ],
        [
            "countryNameEn" => "Japan",
            "countryCode" => "JP",
            "region" => "Asia & Pacific",
            "flag" => "🇯🇵"
        ],
        [
            "countryNameEn" => "Kenya",
            "countryCode" => "KE",
            "region" => "Africa",
            "flag" => "🇰🇪"
        ],
        [
            "countryNameEn" => "Kyrgyzstan",
            "countryCode" => "KG",
            "region" => "Asia & Pacific",
            "flag" => "🇰🇬"
        ],
        [
            "countryNameEn" => "Cambodia",
            "countryCode" => "KH",
            "region" => "Asia & Pacific",
            "flag" => "🇰🇭"
        ],
        [
            "countryNameEn" => "North Korea",
            "countryCode" => "KP",
            "region" => "Asia",
            "flag" => "🇰🇵"
        ],
        [
            "countryNameEn" => "South Korea",
            "countryCode" => "KR",
            "region" => "Asia",
            "flag" => "🇰🇷"
        ],
        [
            "countryNameEn" => "Kiribati",
            "countryCode" => "KI",
            "region" => "Asia & Pacific",
            "flag" => "🇰🇮"
        ],
        [
            "countryNameEn" => "Saint Kitts and Nevis",
            "countryCode" => "KN",
            "region" => "South/Latin America",
            "flag" => "🇰🇳"
        ],
        [
            "countryNameEn" => "Kuwait",
            "countryCode" => "KW",
            "region" => "Arab States",
            "flag" => "🇰🇼"
        ],
        [
            "countryNameEn" => "Kazakhstan",
            "countryCode" => "KZ",
            "region" => "Asia & Pacific",
            "flag" => "🇰🇿"
        ],
        [
            "countryNameEn" => "Lebanon",
            "countryCode" => "LB",
            "region" => "Arab States",
            "flag" => "🇱🇧"
        ],
        [
            "countryNameEn" => "Saint Lucia",
            "countryCode" => "LC",
            "region" => "South/Latin America",
            "flag" => "🇱🇨"
        ],
        [
            "countryNameEn" => "Liechtenstein",
            "countryCode" => "LI",
            "region" => "Europe",
            "flag" => "🇱🇮"
        ],
        [
            "countryNameEn" => "Sri Lanka",
            "countryCode" => "LK",
            "region" => "Asia & Pacific",
            "flag" => "🇱🇰"
        ],
        [
            "countryNameEn" => "Liberia",
            "countryCode" => "LR",
            "region" => "Africa",
            "flag" => "🇱🇷"
        ],
        [
            "countryNameEn" => "Lesotho",
            "countryCode" => "LS",
            "region" => "Africa",
            "flag" => "🇱🇸"
        ],
        [
            "countryNameEn" => "Lithuania",
            "countryCode" => "LT",
            "region" => "Europe",
            "flag" => "🇱🇹"
        ],
        [
            "countryNameEn" => "Luxembourg",
            "countryCode" => "LU",
            "region" => "Europe",
            "flag" => "🇱🇺"
        ],
        [
            "countryNameEn" => "Latvia",
            "countryCode" => "LV",
            "region" => "Europe",
            "flag" => "🇱🇻"
        ],
        [
            "countryNameEn" => "Libya",
            "countryCode" => "LY",
            "region" => "Arab States",
            "flag" => "🇱🇾"
        ],
        [
            "countryNameEn" => "Morocco",
            "countryCode" => "MA",
            "region" => "Arab States",
            "flag" => "🇲🇦"
        ],
        [
            "countryNameEn" => "Monaco",
            "countryCode" => "MC",
            "region" => "Europe",
            "flag" => "🇲🇨"
        ],
        [
            "countryNameEn" => "Montenegro",
            "countryCode" => "ME",
            "region" => "Europe",
            "flag" => "🇲🇪"
        ],
        [
            "countryNameEn" => "Saint Martin (French part)",
            "countryCode" => "MF",
            "region" => "South/Latin America",
            "flag" => "🇲🇫"
        ],
        [
            "countryNameEn" => "Madagascar",
            "countryCode" => "MG",
            "region" => "Africa",
            "flag" => "🇲🇬"
        ],
        [
            "countryNameEn" => "Mali",
            "countryCode" => "ML",
            "region" => "Africa",
            "flag" => "🇲🇱"
        ],
        [
            "countryNameEn" => "Myanmar",
            "countryCode" => "MM",
            "region" => "Asia & Pacific",
            "flag" => "🇲🇲"
        ],
        [
            "countryNameEn" => "Mongolia",
            "countryCode" => "MN",
            "region" => "Asia & Pacific",
            "flag" => "🇲🇳"
        ],
        [
            "countryNameEn" => "Macao",
            "countryCode" => "MO",
            "region" => "Asia & Pacific",
            "flag" => "🇲🇴"
        ],
        [
            "countryNameEn" => "Martinique",
            "countryCode" => "MQ",
            "region" => "South/Latin America",
            "flag" => "🇲🇶"
        ],
        [
            "countryNameEn" => "Mauritania",
            "countryCode" => "MR",
            "region" => "Arab States",
            "flag" => "🇲🇷"
        ],
        [
            "countryNameEn" => "Montserrat",
            "countryCode" => "MS",
            "region" => "South/Latin America",
            "flag" => "🇲🇸"
        ],
        [
            "countryNameEn" => "Malta",
            "countryCode" => "MT",
            "region" => "Europe",
            "flag" => "🇲🇹"
        ],
        [
            "countryNameEn" => "Mauritius",
            "countryCode" => "MU",
            "region" => "Africa",
            "flag" => "🇲🇺"
        ],
        [
            "countryNameEn" => "Maldives",
            "countryCode" => "MV",
            "region" => "Asia & Pacific",
            "flag" => "🇲🇻"
        ],
        [
            "countryNameEn" => "Malawi",
            "countryCode" => "MW",
            "region" => "Africa",
            "flag" => "🇲🇼"
        ],
        [
            "countryNameEn" => "Mexico",
            "countryCode" => "MX",
            "region" => "South/Latin America",
            "flag" => "🇲🇽"
        ],
        [
            "countryNameEn" => "Malaysia",
            "countryCode" => "MY",
            "region" => "Asia & Pacific",
            "flag" => "🇲🇾"
        ],
        [
            "countryNameEn" => "Mozambique",
            "countryCode" => "MZ",
            "region" => "Africa",
            "flag" => "🇲🇿"
        ],
        [
            "countryNameEn" => "Namibia",
            "countryCode" => "NA",
            "region" => "Africa",
            "flag" => "🇳🇦"
        ],
        [
            "countryNameEn" => "New Caledonia",
            "countryCode" => "NC",
            "region" => "Asia & Pacific",
            "flag" => "🇳🇨"
        ],
        [
            "countryNameEn" => "Norfolk Island",
            "countryCode" => "NF",
            "region" => "Asia & Pacific",
            "flag" => "🇳🇫"
        ],
        [
            "countryNameEn" => "Nigeria",
            "countryCode" => "NG",
            "region" => "Africa",
            "flag" => "🇳🇬"
        ],
        [
            "countryNameEn" => "Nicaragua",
            "countryCode" => "NI",
            "region" => "South/Latin America",
            "flag" => "🇳🇮"
        ],
        [
            "countryNameEn" => "Norway",
            "countryCode" => "NO",
            "region" => "Europe",
            "flag" => "🇳🇴"
        ],
        [
            "countryNameEn" => "Nepal",
            "countryCode" => "NP",
            "region" => "Asia & Pacific",
            "flag" => "🇳🇵"
        ],
        [
            "countryNameEn" => "Nauru",
            "countryCode" => "NR",
            "region" => "Asia & Pacific",
            "flag" => "🇳🇷"
        ],
        [
            "countryNameEn" => "Niue",
            "countryCode" => "NU",
            "region" => "Asia & Pacific",
            "flag" => "🇳🇺"
        ],
        [
            "countryNameEn" => "New Zealand",
            "countryCode" => "NZ",
            "region" => "Asia & Pacific",
            "flag" => "🇳🇿"
        ],
        [
            "countryNameEn" => "Oman",
            "countryCode" => "OM",
            "region" => "Arab States",
            "flag" => "🇴🇲"
        ],
        [
            "countryNameEn" => "Panama",
            "countryCode" => "PA",
            "region" => "South/Latin America",
            "flag" => "🇵🇦"
        ],
        [
            "countryNameEn" => "Peru",
            "countryCode" => "PE",
            "region" => "South/Latin America",
            "flag" => "🇵🇪"
        ],
        [
            "countryNameEn" => "French Polynesia",
            "countryCode" => "PF",
            "region" => "Asia & Pacific",
            "flag" => "🇵🇫"
        ],
        [
            "countryNameEn" => "Papua New Guinea",
            "countryCode" => "PG",
            "region" => "Asia & Pacific",
            "flag" => "🇵🇬"
        ],
        [
            "countryNameEn" => "Pakistan",
            "countryCode" => "PK",
            "region" => "Asia & Pacific",
            "flag" => "🇵🇰"
        ],
        [
            "countryNameEn" => "Poland",
            "countryCode" => "PL",
            "region" => "Europe",
            "flag" => "🇵🇱"
        ],
        [
            "countryNameEn" => "Saint Pierre and Miquelon",
            "countryCode" => "PM",
            "region" => "North America",
            "flag" => "🇵🇲"
        ],
        [
            "countryNameEn" => "Pitcairn",
            "countryCode" => "PN",
            "region" => "Asia & Pacific",
            "flag" => "🇵🇳"
        ],
        [
            "countryNameEn" => "Puerto Rico",
            "countryCode" => "PR",
            "region" => "South/Latin America",
            "flag" => "🇵🇷"
        ],
        [
            "countryNameEn" => "Palestine, State of",
            "countryCode" => "PS",
            "region" => "Arab States",
            "flag" => "🇵🇸"
        ],
        [
            "countryNameEn" => "Portugal",
            "countryCode" => "PT",
            "region" => "Europe",
            "flag" => "🇵🇹"
        ],
        [
            "countryNameEn" => "Palau",
            "countryCode" => "PW",
            "region" => "Asia & Pacific",
            "flag" => "🇵🇼"
        ],
        [
            "countryNameEn" => "Paraguay",
            "countryCode" => "PY",
            "region" => "South/Latin America",
            "flag" => "🇵🇾"
        ],
        [
            "countryNameEn" => "Qatar",
            "countryCode" => "QA",
            "region" => "Arab States",
            "flag" => "🇶🇦"
        ],
        [
            "countryNameEn" => "Réunion",
            "countryCode" => "RE",
            "region" => "Asia & Pacific",
            "flag" => "🇷🇪"
        ],
        [
            "countryNameEn" => "Romania",
            "countryCode" => "RO",
            "region" => "Europe",
            "flag" => "🇷🇴"
        ],
        [
            "countryNameEn" => "Serbia",
            "countryCode" => "RS",
            "region" => "Europe",
            "flag" => "🇷🇸"
        ],
        [
            "countryNameEn" => "Russia",
            "countryCode" => "RU",
            "region" => "Europe",
            "flag" => "🇷🇺"
        ],
        [
            "countryNameEn" => "Rwanda",
            "countryCode" => "RW",
            "region" => "Africa",
            "flag" => "🇷🇼"
        ],
        [
            "countryNameEn" => "Saudi Arabia",
            "countryCode" => "SA",
            "region" => "Arab States",
            "flag" => "🇸🇦"
        ],
        [
            "countryNameEn" => "Solomon Islands",
            "countryCode" => "SB",
            "region" => "Asia & Pacific",
            "flag" => "🇸🇧"
        ],
        [
            "countryNameEn" => "Seychelles",
            "countryCode" => "SC",
            "region" => "Africa",
            "flag" => "🇸🇨"
        ],
        [
            "countryNameEn" => "Sweden",
            "countryCode" => "SE",
            "region" => "Europe",
            "flag" => "🇸🇪"
        ],
        [
            "countryNameEn" => "Singapore",
            "countryCode" => "SG",
            "region" => "Asia & Pacific",
            "flag" => "🇸🇬"
        ],
        [
            "countryNameEn" => "Saint Helena, Ascension and Tristan da Cunha",
            "countryCode" => "SH",
            "region" => "Africa",
            "flag" => "🇸🇭"
        ],
        [
            "countryNameEn" => "Slovenia",
            "countryCode" => "SI",
            "region" => "Europe",
            "flag" => "🇸🇮"
        ],
        [
            "countryNameEn" => "Svalbard and Jan Mayen",
            "countryCode" => "SJ",
            "region" => "Europe",
            "flag" => "🇸🇯"
        ],
        [
            "countryNameEn" => "Slovakia",
            "countryCode" => "SK",
            "region" => "Europe",
            "flag" => "🇸🇰"
        ],
        [
            "countryNameEn" => "Sierra Leone",
            "countryCode" => "SL",
            "region" => "Africa",
            "flag" => "🇸🇱"
        ],
        [
            "countryNameEn" => "Republic of San Marino",
            "countryCode" => "SM",
            "region" => "Europe",
            "flag" => "🇸🇲"
        ],
        [
            "countryNameEn" => "Senegal",
            "countryCode" => "SN",
            "region" => "Africa",
            "flag" => "🇸🇳"
        ],
        [
            "countryNameEn" => "Somalia",
            "countryCode" => "SO",
            "region" => "Arab States",
            "flag" => "🇸🇴"
        ],
        [
            "countryNameEn" => "Suriname",
            "countryCode" => "SR",
            "region" => "South/Latin America",
            "flag" => "🇸🇷"
        ],
        [
            "countryNameEn" => "South Sudan",
            "countryCode" => "SS",
            "region" => "Africa",
            "flag" => "🇸🇸"
        ],
        [
            "countryNameEn" => "Sao Tome and Principe",
            "countryCode" => "ST",
            "region" => "Africa",
            "flag" => "🇸🇹"
        ],
        [
            "countryNameEn" => "El Salvador",
            "countryCode" => "SV",
            "region" => "South/Latin America",
            "flag" => "🇸🇻"
        ],
        [
            "countryNameEn" => "Sint Maarten (Dutch part)",
            "countryCode" => "SX",
            "region" => "Unknown",
            "flag" => "🇸🇽"
        ],
        [
            "countryNameEn" => "Syrian Arab Republic",
            "countryCode" => "SY",
            "region" => "Asia & Pacific",
            "flag" => "🇸🇾"
        ],
        [
            "countryNameEn" => "Chad",
            "countryCode" => "TD",
            "region" => "Africa",
            "flag" => "🇹🇩"
        ],
        [
            "countryNameEn" => "Togo",
            "countryCode" => "TG",
            "region" => "Africa",
            "flag" => "🇹🇬"
        ],
        [
            "countryNameEn" => "Thailand",
            "countryCode" => "TH",
            "region" => "Asia & Pacific",
            "flag" => "🇹🇭"
        ],
        [
            "countryNameEn" => "Tajikistan",
            "countryCode" => "TJ",
            "region" => "Asia & Pacific",
            "flag" => "🇹🇯"
        ],
        [
            "countryNameEn" => "Tokelau",
            "countryCode" => "TK",
            "region" => "Asia & Pacific",
            "flag" => "🇹🇰"
        ],
        [
            "countryNameEn" => "Timor-Leste",
            "countryCode" => "TL",
            "region" => "Asia & Pacific",
            "flag" => "🇹🇱"
        ],
        [
            "countryNameEn" => "Turkmenistan",
            "countryCode" => "TM",
            "region" => "Asia & Pacific",
            "flag" => "🇹🇲"
        ],
        [
            "countryNameEn" => "Tunisia",
            "countryCode" => "TN",
            "region" => "Arab States",
            "flag" => "🇹🇳"
        ],
        [
            "countryNameEn" => "Tonga",
            "countryCode" => "TO",
            "region" => "Asia & Pacific",
            "flag" => "🇹🇴"
        ],
        [
            "countryNameEn" => "Turkey",
            "countryCode" => "TR",
            "region" => "Europe",
            "flag" => "🇹🇷"
        ],
        [
            "countryNameEn" => "Trinidad and Tobago",
            "countryCode" => "TT",
            "region" => "South/Latin America",
            "flag" => "🇹🇹"
        ],
        [
            "countryNameEn" => "Tuvalu",
            "countryCode" => "TV",
            "region" => "Asia & Pacific",
            "flag" => "🇹🇻"
        ],
        [
            "countryNameEn" => "United Republic of Tanzania",
            "countryCode" => "TZ",
            "region" => "Africa",
            "flag" => "🇹🇿"
        ],
        [
            "countryNameEn" => "Ukraine",
            "countryCode" => "UA",
            "region" => "Europe",
            "flag" => "🇺🇦"
        ],
        [
            "countryNameEn" => "Uganda",
            "countryCode" => "UG",
            "region" => "Africa",
            "flag" => "🇺🇬"
        ],
        [
            "countryNameEn" => "United States",
            "countryCode" => "US",
            "region" => "North America",
            "flag" => "🇺🇸"
        ],
        [
            "countryNameEn" => "Uruguay",
            "countryCode" => "UY",
            "region" => "South/Latin America",
            "flag" => "🇺🇾"
        ],
        [
            "countryNameEn" => "Uzbekistan",
            "countryCode" => "UZ",
            "region" => "Asia & Pacific",
            "flag" => "🇺🇿"
        ],
        [
            "countryNameEn" => "Saint Vincent and the Grenadines",
            "countryCode" => "VC",
            "region" => "South/Latin America",
            "flag" => "🇻🇨"
        ],
        [
            "countryNameEn" => "Venezuela (Bolivarian Republic of)",
            "countryCode" => "VE",
            "region" => "South/Latin America",
            "flag" => "🇻🇪"
        ],
        [
            "countryNameEn" => "Virgin Islands (British)",
            "countryCode" => "VG",
            "region" => "South/Latin America",
            "flag" => "🇻🇬"
        ],
        [
            "countryNameEn" => "Virgin Islands (U.S.)",
            "countryCode" => "VI",
            "region" => "South/Latin America",
            "flag" => "🇻🇮"
        ],
        [
            "countryNameEn" => "Vietnam",
            "countryCode" => "VN",
            "region" => "Asia & Pacific",
            "flag" => "🇻🇳"
        ],
        [
            "countryNameEn" => "Vanuatu",
            "countryCode" => "VU",
            "region" => "Asia & Pacific",
            "flag" => "🇻🇺"
        ],
        [
            "countryNameEn" => "Wallis and Futuna",
            "countryCode" => "WF",
            "region" => "Asia & Pacific",
            "flag" => "🇼🇫"
        ],
        [
            "countryNameEn" => "Samoa",
            "countryCode" => "WS",
            "region" => "Asia & Pacific",
            "flag" => "🇼🇸"
        ],
        [
            "countryNameEn" => "Yemen",
            "countryCode" => "YE",
            "region" => "Arab States",
            "flag" => "🇾🇪"
        ],
        [
            "countryNameEn" => "Mayotte",
            "countryCode" => "YT",
            "region" => "Africa",
            "flag" => "🇾🇹"
        ],
        [
            "countryNameEn" => "South Africa",
            "countryCode" => "ZA",
            "region" => "Africa",
            "flag" => "🇿🇦"
        ],
        [
            "countryNameEn" => "Zambia",
            "countryCode" => "ZM",
            "region" => "Africa",
            "flag" => "🇿🇲"
        ],
        [
            "countryNameEn" => "Zimbabwe",
            "countryCode" => "ZW",
            "region" => "Africa",
            "flag" => "🇿🇼"
        ],
        [
            "countryNameEn" => "Eswatini",
            "countryCode" => "SZ",
            "region" => "Africa",
            "flag" => "🇸🇿"
        ],
        [
            "countryNameEn" => "North Macedonia",
            "countryCode" => "MK",
            "region" => "Europe",
            "flag" => "🇲🇰"
        ],
        [
            "countryNameEn" => "Philippines",
            "countryCode" => "PH",
            "region" => "Asia & Pacific",
            "flag" => "🇵🇭"
        ],
        [
            "countryNameEn" => "Netherlands",
            "countryCode" => "NL",
            "region" => "Europe",
            "flag" => "🇳🇱"
        ],
        [
            "countryNameEn" => "United Arab Emirates",
            "countryCode" => "AE",
            "region" => "Arab States",
            "flag" => "🇦🇪"
        ],
        [
            "countryNameEn" => "Republic of Moldova",
            "countryCode" => "MD",
            "region" => "Europe",
            "flag" => "🇲🇩"
        ],
        [
            "countryNameEn" => "Gambia",
            "countryCode" => "GM",
            "region" => "Africa",
            "flag" => "🇬🇲"
        ],
        [
            "countryNameEn" => "Dominican Republic",
            "countryCode" => "DO",
            "region" => "South/Latin America",
            "flag" => "🇩🇴"
        ],
        [
            "countryNameEn" => "Sudan",
            "countryCode" => "SD",
            "region" => "Arab States",
            "flag" => "🇸🇩"
        ],
        [
            "countryNameEn" => "Lao People's Democratic Republic",
            "countryCode" => "LA",
            "region" => "Asia & Pacific",
            "flag" => "🇱🇦"
        ],
        [
            "countryNameEn" => "Taiwan, Province of China",
            "countryCode" => "TW",
            "region" => "Asia & Pacific",
            "flag" => "🇹🇼"
        ],
        [
            "countryNameEn" => "Republic of the Congo",
            "countryCode" => "CG",
            "flag" => "🇨🇬"
        ],
        [
            "countryNameEn" => "Czechia",
            "countryCode" => "CZ",
            "region" => "Europe",
            "flag" => "🇨🇿"
        ],
        [
            "countryNameEn" => "United Kingdom",
            "countryCode" => "GB",
            "region" => "Europe",
            "flag" => "🇬🇧"
        ],
        [
            "countryNameEn" => "Niger",
            "countryCode" => "NE",
            "region" => "Africa",
            "flag" => "🇳🇪"
        ],
        [
            "countryNameEn" => "Democratic Republic of the Congo",
            "countryCode" => "CD",
            "region" => "Africa",
            "flag" => "🇨🇩",
        ],
        [
            "countryNameEn" => "Commonwealth of The Bahamas",
            "countryCode" => "BS",
            "region" => "Caribbean",
            "flag" => "🇧🇸",
        ],
        [
            "countryNameEn" => "Cocos (Keeling) Islands",
            "countryCode" => "CC",
            "region" => "Australia",
            "flag" => "🇨🇨",
        ],
        [
            "countryNameEn" => "Central African Republic",
            "countryCode" => "CF",
            "region" => "Africa",
            "flag" => "🇨🇫",
        ],
        [
            "countryNameEn" => "Cook Islands",
            "countryCode" => "CK",
            "region" => "South Pacific Ocean",
            "flag" => "🇨🇰",
        ],
        [
            "countryNameEn" => "Falkland Islands",
            "countryCode" => "FK",
            "region" => "South Atlantic Ocean",
            "flag" => "🇫🇰",
        ],
        [
            "countryNameEn" => "Faroe Islands",
            "countryCode" => "FO",
            "region" => "Europe",
            "flag" => "🇫🇴",
        ],
        [
            "countryNameEn" => "Territory of Heard Island and McDonald Islands",
            "countryCode" => "HM",
            "region" => "Indian Ocean",
            "flag" => "🇭🇲",
        ],
        [
            "countryNameEn" => "British Indian Ocean Territory",
            "countryCode" => "IO",
            "region" => "Indian Ocean",
            "flag" => "🇮🇴",
        ],
        [
            "countryNameEn" => "Comoros",
            "countryCode" => "KM",
            "region" => "Indian Ocean",
            "flag" => "🇰🇲",
        ],
        [
            "countryNameEn" => "Cayman Islands",
            "countryCode" => "KY",
            "region" => "Caribbean Sea",
            "flag" => "🇰🇾",
        ],
        [
            "countryNameEn" => "Republic of the Marshall Islands",
            "countryCode" => "MH",
            "region" => "Pacific Ocean",
            "flag" => "🇲🇭",
        ],
        [
            "countryNameEn" => "Commonwealth of the Northern Mariana Islands",
            "countryCode" => "MP",
            "region" => "Pacific Ocean",
            "flag" => "🇲🇵",
        ],
        [
            "countryNameEn" => "Turks and Caicos Islands",
            "countryCode" => "TC",
            "region" => "Atlantic Ocean",
            "flag" => "🇹🇨",
        ],
        [
            "countryNameEn" => "French Southern and Antarctic Lands",
            "countryCode" => "TF",
            "region" => "Indian Ocean",
            "flag" => "🇹🇫",
        ],
        [
            "countryNameEn" => "United States Minor Outlying Islands",
            "countryCode" => "UM",
            "region" => "Pacific Ocean",
            "flag" => "🇺🇲",
        ],
        [
            "countryNameEn" => "Holy See",
            "countryCode" => "VA",
            "region" => "Europe",
            "flag" => "🇻🇦",
        ],
        [
            "countryNameEn" => "Republic of Kosovo",
            "countryCode" => "XK",
            "region" => "Europe",
            "flag" => "🇽🇰",
        ],
        [
            "countryNameEn" => "Netherlands Antilles",
            "countryCode" => "AN",
            "region" => "Europe",
            "flag" => "🇧🇶",
        ],
    ];

    return $country;
}

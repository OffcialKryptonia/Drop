<?php
use App\Notifications\CommonNotification;
use Illuminate\Support\Facades\Log;
use App\Models\User;


function sendNotificationForNewRide($ride_request,$driver){
    $totalAmountNotify = $ride_request->total_amount - $ride_request->admin_commission;
    $unit = $ride_request->distance_unit ?? 'km';
    $notification_data = [
        'id' => $ride_request->id,
        'type' => 'new_ride_requested',
        'data' => [
            'rider_id' => $ride_request->rider_id,
            'rider_name' => optional($ride_request->rider)->display_name ?? '',
        ],
        // 'message' => __('message.new_ride_requested'),
        'message' => __('message.subject_data', ['distance' => $ride_request->distance , 'distance_unit' => $unit, 'duration' => round($ride_request->duration,2) ,'currency_symbol' => $ride_request->currency_symbol ?? ' ','total_amount' => $totalAmountNotify ]),
        'subject' => __('message.ride.new_ride_requested'),
    ];
    try {
        $driver->notify(new CommonNotification($notification_data['type'], $notification_data));
        // Log::info('Notification sent to Driver ID: ' . $driver->id);
    } catch (\Exception $e) {
        Log::error('Error sending notification to Driver ID: ' . $driver->id . '. ' . $e->getMessage());
    }
}

function sendPushNotificationForRide($userType,$historyType,$ride_request,$subject,$message){

    $notification_data = [
        'id' => $ride_request->id,
        'type' => $historyType,
        'subject' => $subject,
        'message' => $message,
        'rider_id' => $ride_request->rider_id,
        'driver_id' => $ride_request->driver_id,
    ];
    if($userType == 'rider'){

        $user = User::whereId($ride_request->rider_id)->first();
        // Log::info('rider',['user' => $user]);

    }elseif($userType == 'driver'){
        $user = User::whereId($ride_request->driver_id)->first();
        // Log::info('driver',['user' => $user]);
    }else{
        $user = User::admin();
    }

    try {
        if($user){
            $user->notify(new CommonNotification($notification_data['type'], $notification_data));
        }
        // Log::info('Notification sent to Driver ID: ' . $driver->id);
    } catch (\Exception $e) {
        Log::error('Error sending notification to Driver ID: ' .$ride_request->driver_id . '. ' . $e->getMessage());
    }
}

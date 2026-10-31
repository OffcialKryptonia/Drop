<?php
return [
    'IMAGE_EXTENTIONS' => ['png','jpg','jpeg','gif'],
    'PER_PAGE_LIMIT' => 10,
    'MAIL_SETTING' => [
        'MAIL_MAILER' => env('MAIL_MAILER'),
        'MAIL_HOST' => env('MAIL_HOST'),
        'MAIL_PORT' => env('MAIL_PORT'),
        'MAIL_USERNAME' => env('MAIL_USERNAME'),
        'MAIL_PASSWORD' => env('MAIL_PASSWORD'),
        'MAIL_ENCRYPTION' => env('MAIL_ENCRYPTION'),
        'MAIL_FROM_ADDRESS' => env('MAIL_FROM_ADDRESS'),
        'EMAIL_OTP_VERIFICATION' => env('EMAIL_OTP_VERIFICATION'),
    ],
    'MAIL_PLACEHOLDER' => [
        'MAIL_MAILER' => 'smtp',
        'MAIL_HOST' => 'smtp.gmail.com',
        'MAIL_PORT' => '587',
        'MAIL_ENCRYPTION' => 'tls',
        'MAIL_USERNAME' => 'youremail@gmail.com',
        'MAIL_PASSWORD' => 'Password',
        'MAIL_FROM_ADDRESS' => 'youremail@gmail.com',
    ],
    'PAYMENT_GATEWAY_SETTING' => [
        // 'cash' => [],
        'stripe' => [ 'url', 'secret_key', 'publishable_key' ],
        'razorpay' => [ 'key_id', 'secret_id' ],
        'paystack' => [ 'public_key', 'secret_key', 'payment_url'],
        'flutterwave' => [ 'public_key', 'secret_key', 'encryption_key' ],
        'paypal' => [ 'tokenization_key', 'public_key', 'secret_key'],
        'paytabs' => [ 'client_key', 'profile_id', 'server_key'],
        // 'mercadopago' => [ 'public_key', 'access_token' ],
        'myfatoorah' => ['access_token'],
        'paytm' => [ 'merchant_id', 'merchant_key' ],
        'pesapal' => [ 'consumer_key', 'consumer_secret' ],
    ],

    'wallet' => [
        'min_amount_to_add'     => '',
        'max_amount_to_add'     => '',
        'min_amount_to_get_ride'=> '',
        'preset_topup_amount'   => '',
    ],

    'ride' => [
        'max_time_for_find_drivers_for_regular_ride_in_minute'  => '',
        'ride_accept_decline_duration_for_driver_in_second'     => '',
        // 'schedule_ride_after_minute'    => '',
        // 'min_time_for_find_driver_for_schedule_ride_in_minute'  => '',
        'preset_tip_amount'   => '',
        'apply_additional_fee'  => '',
        'surge_price'  => '',
        'is_bidding'  => '',
        'is_sms_rider'  => '',
        'per_minute_drive'  => '',
        'enable_eta'  => '',
    ],
    'ride_status' => ['new_ride_requested', 'no_drivers_available', 'accepted', 'arriving', 'arrived', 'in_progress', 'canceled', 'completed' , 'sos'],
    'notification' => [
        'IS_ONESIGNAL' => '',
        // 'IS_FIREBASE' => '',
    ],
    'scratch_card' => [
        'remaining_value' => '',
        'enable_scratch_card' => '',
    ],

    'mail_template_setting' => [
        'new_ride_requested' => '',
        'accepted'   => '',
        'bid_placed' => '',
        'bid_accepted' => '',
        'bid_rejected' => '',
        'arriving'     => '',
        'arrived'      => '',
        'in_progress'  => '',
        'canceled'     => '',
        'driver_canceled' => '',
        'rider_canceled'  => '',
        'completed' => '',
        'payment_status_message' => '',
        'otp_verification_mail' => '',
        'self_billing_statement' => '',

    ],
    'SMS_SETTING' => [
        'twilio' => [ 'sid', 'token', 'service_sid', 'from'],
        // '2factor' => ['api_key'],
        // 'msg91' => ['template_id', 'auth_key'],
        // 'nexmo' => [ 'api_key', 'api_secret', 'token', 'from', 'otp_template'],
        // 'alphanet_sms' => [ 'api_key', 'otp_template'],
    ],

    'SMS_TEMPLATE_SETTING' => [
        'create' => '',
        'courier_assigned' => '',
        'completed' => '',
        'sms_template_description' => '',
    ],

    'app_info' => [
        'app_name' => '', 'image_title' => '', 'background_image' => '', 'logo_image' => '',
    ],

    'our_mission' => [
        'title' => '',
        'image' => '',
    ],

    'download_app' => [
        'title' => '',
        'subtitle' => '',
        'image' => '',
        'play_store' => '',
        'app_store' => ''
    ],

    'contactus_info' => [
        'about_title' => '',
        'image' => '',
    ],

    'client_testimonials' => [
        'title' => '',
        'subtitle' => '',
        'image' => '',
    ],

    'why_choose' => [
        'title' => '',
        'subtitle' => '',
        'image' => '',
    ],

    'mail_alert' => [
        'login_alert'   => '',
        'login_history' => '',
    ],
];

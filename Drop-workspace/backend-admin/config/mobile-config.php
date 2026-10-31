<?php

return [
    'CURRENCY' => [
        // 'NAME' => '',
        'CODE' => '',
        // 'SYMBOL' => '',
        'POSITION' => ''
    ],

    'ONESIGNAL' => [
        'RIDER_APP_ID' => env('RIDER_APP_ID'),
        'RIDER_REST_API_KEY' => env('RIDER_REST_API_KEY'),
        'RIDER_CHANNEL_ID' => env('RIDER_CHANNEL_ID'),
        'DRIVER_APP_ID' => env('DRIVER_APP_ID'),
        'DRIVER_REST_API_KEY' => env('DRIVER_REST_API_KEY'),
        'DRIVER_DEFAULT_CHANNEL_ID' => env('DRIVER_DEFAULT_CHANNEL_ID'),
        'DRIVER_RIDE_NOTIFY_CHANNEL_ID' => env('DRIVER_RIDE_NOTIFY_CHANNEL_ID'),
    ],

    'DISTANCE' => [
        'RADIUS' => ''
    ],

    'RIDE' => [
        'FOR_OTHER' => '',
        'MULTIPLE_DROP_LOCATION' => '',
        'IS_SCHEDULE_RIDE' => '',
        'DRIVER_CAN_REVIEW' => '',
    ],

    'RIDER VERSION' => [
        'ANDROID_FORCE_UPDATE' => '',
        'ANDROID_VERSION_CODE' => '',
        'APPSTORE_URL' => '',
        'IOS_FORCE_UPDATE' => '',
        'IOS_VERSION' => '',
        'PLAYSTORE_URL' => '',
    ],

    'DRIVER VERSION' => [
        'ANDROID_FORCE_UPDATE' => '',
        'ANDROID_VERSION_CODE' => '',
        'APPSTORE_URL' => '',
        'IOS_FORCE_UPDATE' => '',
        'IOS_VERSION' => '',
        'PLAYSTORE_URL' => '',
    ],
    
    // 'CRISP_CHAT_CONFIGURATION' => [
    //     'WEBSITE_ID' => '',
    //     'ENABLE/DISABLE' => '',
    // ],
     'FLIGHT_TRACKING_ENABLE' => [
        'TYPE' => '',
    ],
];
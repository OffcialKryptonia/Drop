<?php

namespace App\Services;

use App\Services\SmsProviders\TwilioProvider;
use App\Services\SmsProviders\TwoFactorProvider;
use App\Services\SmsProviders\Msg91Provider;
use App\Services\SmsProviders\NexmoProvider;
use App\Services\SmsProviders\AlphanetProvider;
use Illuminate\Support\Facades\Log;

class SmsService
{
    protected $provider;

    public function __construct()
    {
        $settings = getSmsSettings();
        Log::info("All SMS settings: " . print_r($settings, true));

        $type = request()->input('sms_type', 'twilio');
        if (!isset($settings[$type])) {
            throw new \Exception("Invalid or missing SMS provider settings for: $type");
        }
        $this->provider = new TwilioProvider($settings['twilio']);
    }

    public function sendSMS($to, $message)
    {
        return $this->provider->send($to, $message);
    }
}

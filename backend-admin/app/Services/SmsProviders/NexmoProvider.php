<?php
namespace App\Services\SmsProviders;

use Vonage\Client;
use Vonage\Client\Credentials\Basic;
use Vonage\SMS\Message\SMS;
use Illuminate\Support\Facades\Log;

class NexmoProvider
{
    protected $client;
    protected $from;

    public function __construct($settings)
    {
        if (!isset($settings['api_key'], $settings['api_secret'], $settings['from'])) {
            throw new \Exception("Nexmo settings are missing.");
        }

        $credentials = new Basic($settings['api_key'], $settings['api_secret']);
        $this->client = new Client($credentials);
        $this->from = $settings['from'];
    }

    public function send($to, $message)
    {
        try {
            $response = $this->client->sms()->send(new SMS($to, $this->from, $message));

            Log::info("Nexmo SMS Response: " . print_r($response, true));
            return $response;
        } catch (\Exception $e) {
            Log::error("Nexmo SMS Error: " . $e->getMessage());
            return false;
        }
    }
}

<?php
namespace App\Services\SmsProviders;

use Twilio\Rest\Client;
use Illuminate\Support\Facades\Log;

class TwilioProvider
{
    protected $client;
    protected $from;

    public function __construct($settings)
    {
        if (!isset($settings['sid'], $settings['token'], $settings['from'])) {
            throw new \Exception("Twilio settings are missing.");
        }

        $this->client = new Client($settings['sid'], $settings['token']);
        $this->from = $settings['from'];
    }

    public function send($to, $message)
    {
        if ($this->from == $to) {
            Log::error("Twilio 'From' number cannot be the same as 'To' number.");
            return false;
        }

        try {
            $response = $this->client->messages->create($to, [
                'from' => $this->from,
                'body' => $message
            ]);

            // Log::info("Twilio SMS sent successfully: " . print_r($response, true));
            return $response;
        } catch (\Exception $e) {
            Log::error("Twilio SMS Error: " . $e->getMessage());
            return false;
        }
    }
}

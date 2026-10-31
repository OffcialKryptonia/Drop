<?php

namespace App\Services\SmsProviders;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class AlphanetProvider
{
    protected $apiKey;
    protected $baseUrl;

    public function __construct($settings)
    {
        // Ensure required settings are provided
        if (!isset($settings['api_key'], $settings['base_url'])) {
            throw new \Exception("Alphanet SMS settings are missing.");
        }

        $this->apiKey  = $settings['api_key'];   // Your Alphanet API Key
        $this->baseUrl = $settings['base_url']; // Alphanet API Endpoint
    }

    /**
     * Send SMS via Alphanet (API Key Based)
     *
     * @param string $to - Recipient's phone number (e.g., +919023534078)
     * @param string $message - SMS content
     * @return array|bool - Response from Alphanet or false on failure
     */
    public function send($to, $message)
    {
        try {
            // Ensure phone number and message are valid
            if (empty($to) || empty($message)) {
                throw new \Exception("Recipient number or message is empty.");
            }

            // Prepare API request payload
            $payload = [
                'apiKey'  => $this->apiKey,
                'to'      => $to,
                'message' => $message,
                'type'    => 'text' // Can be 'unicode' if required
            ];

            // Log the payload before sending
            Log::info("Sending SMS via Alphanet: " . json_encode($payload));

            // Send request to Alphanet API
            $response = Http::post($this->baseUrl, $payload);

            // Check if the request was successful (200 status code)
            if ($response->successful()) {
                Log::info("Alphanet SMS Sent Successfully: " . $response->body());
                return $response->json();
            }

            // Log error if API call fails
            Log::error("Alphanet SMS Failed: " . $response->body());
            return false;
        } catch (\Exception $e) {
            // Log exceptions
            Log::error("Alphanet SMS Error: " . $e->getMessage());
            return false;
        }
    }
}

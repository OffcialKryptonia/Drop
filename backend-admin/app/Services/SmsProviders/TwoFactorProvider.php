<?php
namespace App\Services\SmsProviders;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class TwoFactorProvider
{
    protected $apiKey;

    public function __construct($settings)
    {
        if (!isset($settings['api_key'])) {
            throw new \Exception("2Factor API key is missing.");
        }

        $this->apiKey = $settings['api_key'];
    }

    public function send($to, $message)
    {
        try {
            // API Endpoint for custom SMS (No Sender ID required)
            $url = "https://2factor.in/API/V1/{$this->apiKey}/ADDON_SERVICES/SEND/TSMS";

            $response = Http::post($url, [
                'To'      => $to,
                'Msg'     => $message,
                'MsgType' => 'TEXT' // TEXT or UNICODE
            ]);

            $data = $response->json();
            if (isset($data['Status']) && $data['Status'] == "Success") {
                Log::info("2Factor SMS Sent Successfully: " . json_encode($data));
                return $data;
            } else {
                Log::error("2Factor SMS Failed: " . json_encode($data));
                return false;
            }
        } catch (\Exception $e) {
            Log::error("2Factor SMS Error: " . $e->getMessage());
            return false;
        }
    }
}

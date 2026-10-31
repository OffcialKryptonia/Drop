<?php
namespace App\Services\SmsProviders;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class Msg91Provider
{
    protected $authKey;
    protected $templateId;

    public function __construct($settings)
    {
        if (!isset($settings['auth_key'], $settings['template_id'])) {
            throw new \Exception("MSG91 settings are missing.");
        }

        $this->authKey = $settings['auth_key'];
        $this->templateId = $settings['template_id'];
    }

    public function send($to, $message)
    {
        try {
            $payload = [
                "template_id" => $this->templateId,  // MSG91 Approved Template ID
                "recipients" => [
                    [
                        "mobiles" => $to,  // Mobile number(s) as a string
                        "variables_values" => $message  // Dynamic message content
                    ]
                ]
            ];

            $response = Http::withHeaders([
                "authkey" => $this->authKey,
                "Content-Type" => "application/json",
            ])->post("https://control.msg91.com/api/v5/flow/", $payload);

            $responseBody = $response->json();

            Log::info("MSG91 Full Response: " . json_encode($response->json(), JSON_PRETTY_PRINT));

            if (isset($responseBody['error'])) {
                Log::error("MSG91 SMS Error: " . json_encode($responseBody['error']));
                return false;
            }

            return $responseBody;
        } catch (\Exception $e) {
            Log::error("MSG91 SMS Exception: " . $e->getMessage());
            return false;
        }
    }
}


<?php

namespace App\Mail;

use App\Models\AppSetting;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class OTPVerificationMail extends Mailable
{
    use Queueable, SerializesModels;

    public $content;
    public $subject;

    public function __construct($content, $subject)
    {
        $this->content = $content;
        $this->subject = $subject;
    }
    public function build()
    {
        $email = $this->view('emails.email_otp_verification')
            ->with([
                'mailDescription' => $this->content['mailDescription'],
                'otp' => $this->content['otp'],
                'companyName' => config('app.name'),
                'heading' => __('message.almost_there'),
            ]);

        return $email;
    }
}

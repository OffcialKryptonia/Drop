<?php

namespace App\Mail;

use App\Models\AppSetting;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;
use Illuminate\Contracts\Queue\ShouldQueue;

class LoginAlertMail extends Mailable implements ShouldQueue
{
    use Queueable, SerializesModels;

    public $storeData;

    public function __construct($storeData)
    {
        $this->storeData = $storeData;
    }

    public function build()
    {
        $appsetting = AppSetting :: first();
        $content = "
            <p><strong>" . __('message.new_login_detected_on_your_account') . "</strong></p>
            <ul>
                <li><strong>" . __('message.ip_address') . ":</strong> {$this->storeData['ip_address']}</li>
                <li><strong>" . __('message.city') . ":</strong> {$this->storeData['city']}</li>
                <li><strong>" . __('message.region') . ":</strong> {$this->storeData['region']}</li>
                <li><strong>" . __('message.country') . ":</strong> {$this->storeData['country']}</li>
                <li><strong>" . __('message.browser') . ":</strong> {$this->storeData['browser']}</li>
                <li><strong>" . __('message.platform') . ":</strong> {$this->storeData['platform']}</li>
            </ul>
        ";

        return $this->from(config('mail.from.address'), config('mail.from.name'))
                    ->subject(__('message.new_login_detected_on_your_account'))
                    ->view('emails.sendmail')
                    ->with([
                        'title'   => __('message.login_alert_title'),
                        'content' => $content,
                        'appsetting' =>$appsetting
                    ]);
    }
}

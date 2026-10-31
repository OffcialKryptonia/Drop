<?php

namespace App\Mail;

use App\Http\Controllers\RideRequestController;
use App\Models\AppSetting;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class SendMail extends Mailable
{
    use Queueable, SerializesModels;

    public $content;
    public $ride_id;
    public $status;
    public $company_name;
    public $rider_name;

    public $pdf;

    /**
     * Create a new message instance.
     *
     * @param string $subject
     * @param string $content
     * @param array $data
     */
    public function __construct($subject, $content, $data)
    {
        $this->subject($subject);
        $this->content = $content;
        $this->ride_id = $data['ride_id'];
        $this->status = $data['status'];
        $this->company_name = $data['company_name'];
        $this->rider_name = $data['rider_name'];
        $this->driver_name = $data['driver_name'];

        if ($this->status == 'completed') {
            $rideRequest = new RideRequestController;
            $rideRequest->rideInvoicePdf($this->ride_id);
        }
    }

    /**
     * Build the message.
     *
     * @return $this
     */
    public function build()
    {
        $email = $this->view('emails.sendmail')
                      ->with([
                          'ride_id' => $this->ride_id,
                          'status' => $this->status,
                          'company_name' => $this->company_name,
                          'content' => $this->content,
                      ]);

        if ($this->status === 'completed' && isset($this->pdf)) {
            $email->attachData($this->pdf->output(), 'invoice_' . $this->ride_id . '.pdf', [
                'mime' => 'application/pdf',
            ]);
        }

        return $email;
    }
}

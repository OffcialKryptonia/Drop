<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;

class SelfBillingStatementMail extends Mailable
{
    public $content;
    public $pdfPath;

    public function __construct($content, $pdfPath)
    {
        $this->content = $content;
        $this->pdfPath = $pdfPath;
    }

    public function build()
    {
        return $this->subject('Self Billing Statement')
            ->html($this->content)
            ->attach($this->pdfPath);
    }
}

<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class DriverPayoutReportResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     */
    public function toArray($request)
    {
        $receivedDocument = getSingleMedia(
            $this,
            'driver_payout_report_document',
            null
        );

        return [
            'week_start_date'   => $this->week_start_date,
            'week_end_date'     => $this->week_end_date,
            'total_trips'       => $this->total_trips,
            'total_fare'        => $this->total_fare,
            'total_commission'  => $this->total_commission,
            'payout_amount'     => $this->payout_amount,
            'driver_tips'       => $this->driver_tips,
            'status'            => $this->status,
            'generated_at'      => $this->generated_at,
            'paid_at'           => $this->paid_at,
            'received_document' => ($receivedDocument && !str_contains($receivedDocument, 'default.png'))
                ? $receivedDocument
                : null,
            'created_at'        => $this->created_at,
            'updated_at'        => $this->updated_at,
        ];
    }
}

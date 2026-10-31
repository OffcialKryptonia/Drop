<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DriverPayoutTransaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'driver_id',
        'payout_report_id',
        'amount',
        'method',
        'reference_no',
        'paid_at',
    ];

    protected $casts = [
        'amount'  => 'decimal:2',
        'paid_at' => 'datetime',
    ];

    /**
     * Driver (User)
     */
    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    /**
     * Payout Report
     */
    public function payoutReport()
    {
        return $this->belongsTo(DriverPayoutReport::class, 'payout_report_id');
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class DriverPayoutReport extends Model implements HasMedia
{
    use HasFactory;
    use InteractsWithMedia;

    protected $fillable = [
        'driver_id',
        'week_start_date',
        'week_end_date',
        'total_trips',
        'total_fare',
        'total_commission',
        'payout_amount',
        'status',
        'generated_at',
        'paid_at',
        'driver_tips',
        'is_mail_sent',
        'payment_method',
        'transaction_reference',
    ];

    protected $casts = [
        'driver_tips' => 'integer',
        'week_start_date' => 'date',
        'week_end_date'   => 'date',
        'generated_at'    => 'datetime',
        'paid_at'         => 'datetime',
        'total_fare'      => 'decimal:2',
        'total_commission'=> 'decimal:2',
        'payout_amount'   => 'decimal:2',
        'is_mail_sent' => 'boolean',
    ];

    /**
     * Driver (User) relationship
     */
    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }
    public function userDetail() {
        return $this->hasOne(UserDetail::class, 'user_id', 'driver_id');
    }
}

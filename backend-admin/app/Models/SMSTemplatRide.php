<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SMSTemplatRide extends Model
{
    use HasFactory;
    protected $fillable = ['subject','sms_description','sms_id','type','ride_status'];

    public function smsSetting()
    {
        return $this->belongsTo(SMSSetting::class, 'sms_id');
    }
}

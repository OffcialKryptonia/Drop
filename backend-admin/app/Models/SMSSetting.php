<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class SMSSetting extends Model implements HasMedia
{
    use HasFactory, InteractsWithMedia;
    protected $fillable = [ 'title', 'type', 'status', 'values'];

    protected $casts = [
        'status' => 'integer',
    ];

    // public function smsTemplate()
    // {
    //     return $this->hasOne(SMSTemplate::class, 'sms_id');
    // }

    public function getValuesAttribute($value)
    {
        return isset($value) ? json_decode($value, true) : null;
    }

    public function setValuesAttribute($value)
    {
        $this->attributes['values'] = json_encode($value);
    }
}

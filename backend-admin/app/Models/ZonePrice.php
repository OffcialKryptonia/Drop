<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ZonePrice extends Model
{
    protected $fillable = ['service_ids','zone_pickup','zone_dropoff','price'];

    protected $casts = [
        'service_ids' => 'array',
    ];

    public function zonepickup() {
        return $this->belongsTo( ManageZone::class, 'zone_pickup', 'id');
    }

    public function zonedropoff() {
        return $this->belongsTo( ManageZone::class, 'zone_dropoff', 'id');
    }

    public function getServicesAttribute()
    {
        return Service::whereIn('id', $this->service_ids ?? [])->pluck('name')->toArray();
    }

}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CoinWallet extends Model
{
    use HasFactory;

    protected $fillable = [ 'ride_id', 'scratch_time', 'user_id', 'coins','type'];

    protected $casts = [
        'ride_id' => 'integer',
        'user_id' => 'integer',
        'coins' => 'integer',
        'scratch_time' => 'datetime',
        'type' => 'string',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id', 'id');
    }

    public function ride()
    {
        return $this->belongsTo(RideRequest::class, 'ride_id', 'id');
    }

    public function scopeMyCoin($query)
    {
        $user = auth()->user();

        if ($user) {
            return $query->where('user_id', $user->id);
        }

        return $query;
    }
}

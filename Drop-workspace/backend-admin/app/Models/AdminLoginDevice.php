<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AdminLoginDevice extends Model
{
    use HasFactory;

    protected $table = 'admin_login_devices';

    protected $fillable = [
        'user_id',
        'ip_address',
        'user_agent',
        'login_at',
        'logout_at',
        'is_active',
        'session_id',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
    protected $casts = [
        'user_id'       => 'integer',
        'is_active'  => 'boolean',
    ];

    public function latestLoginHistory()
    {
        return $this->hasOne(AdminLoginHistory::class, 'ip_address', 'ip_address')->latestOfMany();
    }
}

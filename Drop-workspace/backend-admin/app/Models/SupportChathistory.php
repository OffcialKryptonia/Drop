<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SupportChathistory extends Model
{
    use HasFactory;
    protected $fillable =['support_id','user_id','message','datetime'];
    protected $casts = [
        'user_id'       => 'integer',
        'support_id'    => 'integer',
    ];
    
    public function user() {
        return $this->belongsTo(User::class, 'user_id', 'id');
    }

    public function customersupport() {
        return $this->belongsTo(CustomerSupport::class, 'support_id', 'id');
    }
}
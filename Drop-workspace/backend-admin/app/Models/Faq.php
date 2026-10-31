<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;

class Faq extends Model
{
    use HasFactory , SoftDeletes;
    protected $fillable = ['question','answer','type'];


     public function scopemyFaq($query)
    {
        $user = auth()->user();

        if($user->user_type == 'rider'){
            $query = $query->where('type', 'rider');
        } else {
            $query = $query->where('type', 'driver');
        }

        return $query;
    }
}

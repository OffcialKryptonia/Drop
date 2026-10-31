<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Sos extends Model
{
    use HasFactory;

    protected $fillable = [ 'region_id', 'title', 'contact_number', 'added_by', 'status' ];

    protected $casts = [
        'region_id' => 'integer',
        'added_by' => 'integer',
        'status' => 'integer',
    ];
    public function region() {
        return $this->belongsTo( Region::class, 'region_id', 'id');
    }
    public function addedByUser()
    {
        return $this->belongsTo(User::class, 'added_by');
    }


    public function scopemySos($query)
    {
        $user = auth()->user();

        // if($user->hasAnyRole(['driver','rider'])){
        //     $query = $query->where('added_by', $user->id);
        // } else {
        //     $query = $query->where('added_by', $user->id);
        // }
        if ($user->hasAnyRole(['driver', 'rider'])) {
            $query->where(function ($q) use ($user) {
                $q->where('added_by', $user->id)
                ->orWhereHas('addedByUser', function ($q2) {
                    $q2->role('admin');
                });
            });
        }

        return $query;
    }
}

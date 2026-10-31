<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Region extends Model
{
    use HasFactory;

    protected $fillable = [
        'name','distance_unit','status','timezone','coordinates'
    ];
    protected $spatialFields = [
        'coordinates'
    ];

    protected $casts = [
        'status' => 'integer',
    ];
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ManageZone extends Model
{
    use HasFactory;

    protected $fillable =[ 'name', 'latitude', 'longitude', 'description', 'status' ];
}

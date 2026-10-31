<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Airport extends Model
{
    use HasFactory, SoftDeletes;
    protected $fillable = ['airport_id','ident','type','name','latitude_deg','longitude_deg','iso_country','iso_region','municipality'];

}

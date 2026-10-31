<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class AirPortResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return array
     */
    public function toArray($request)
    {
        return [
            'id'                        => $this->id,
            'airport_id'                => $this->airport_id,
            'ident'                     => $this->ident,
            'type'                      => $this->idetypent,
            'name'                      => $this->name,
            'latitude_deg'              => $this->latitude_deg,
            'longitude_deg'             => $this->longitude_deg,
            'iso_country'               => $this->iso_country,
            'iso_region'                => $this->iso_region,
            'municipality'              => $this->municipality,
            'created_at'                => $this->created_at,
            'updated_at'                => $this->updated_at
        ];
    }
}
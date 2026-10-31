<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class RideRequestRatingResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return array|\Illuminate\Contracts\Support\Arrayable|\JsonSerializable
     */
    public function toArray($request)
    {
        $rideRequest = $this->riderequest;
        $driver = $this->driver ?: optional($rideRequest)->driver;
        $rider = $this->rider ?: optional($rideRequest)->rider;

        return [
            'id' => $this->id,
            'ride_request_id' => $this->ride_request_id,
            'rider_id' => optional($rider)->id,
            'driver_id' => optional($driver)->id,
            'rating' => (float) $this->rating,
            'comment' => $this->comment,
            'rating_by' => $this->rating_by,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
            'ride_request' => [
                'id' => optional($rideRequest)->id,
                'status' => optional($rideRequest)->status,
                'datetime' => optional($rideRequest)->datetime,
                'start_address' => optional($rideRequest)->start_address,
                'end_address' => optional($rideRequest)->end_address,
            ],
            'driver' => [
                'id' => optional($driver)->id,
                'display_name' => optional($driver)->display_name,
                'profile_image' => $driver ? getSingleMedia($driver, 'profile_image', null) : null,
            ],
            'rider' => [
                'id' => optional($rider)->id,
                'display_name' => optional($rider)->display_name,
                'profile_image' => $rider ? getSingleMedia($rider, 'profile_image', null) : null,
            ],
        ];
    }
}

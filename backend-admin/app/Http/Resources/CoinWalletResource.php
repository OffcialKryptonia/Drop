<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class CoinWalletResource extends JsonResource
{
    public function toArray($request)
    {
        return [
            'id'           => $this->id,
            'user_id'      => $this->user_id,
            'ride_id'      => $this->ride_id,
            'scratch_time' => dateAgoFormate($this->scratch_time,true),
            'type'         => $this->type,
            'coins'        => $this->coins,
            'created_at'   => dateAgoFormate($this->created_at,true),
            'updated_at'   => dateAgoFormate($this->updated_at,true),
        ];
    }
}

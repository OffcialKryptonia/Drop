<?php

namespace App\Http\Resources;

use App\Models\SupportChathistory;
use Illuminate\Http\Resources\Json\JsonResource;
use Carbon\Carbon;

class CustomerSupportResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return array|\Illuminate\Contracts\Support\Arrayable|\JsonSerializable
     */
    public function toArray($request)
    {
        $support_chat_history = $this->supportchathistory->map(function($q){
            return [
                'send_by'  => optional($q->user)->user_type,
                'message'  => $q->message,
                'datetime' => $q->created_at,
            ];
        });

        return [
            'support_id'             => $this->id,
            'user_id'                => $this->user_id,
            'user_name'              => optional($this->user)->display_name,
            'support_type'           => $this->support_type,
            'message'                => $this->message,
            'resolution_detail'      => $this->resolution_detail,
            'status'                 => $this->status,
            'support_image'          => getSingleMedia($this, 'support_image',null),
            'support_videos'         => getSingleMedia($this, 'support_videos',null),
            'support_chat_history'   => $support_chat_history,
            'created_at'             => $this->created_at,
            'updated_at'             => $this->updated_at,
        ];
    }
}
<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Http\Resources\UserResource;
use App\Models\User;

class ReferenceController extends Controller
{
    public function getList(Request $request)
    {
        $user = auth()->user();
        if ($user->user_type == 'admin') {
            $partner_referral = User::whereNotNull('partner_referral_code');
        } else {
            if (is_null($user->referral_code)) {
                $response = [
                    'message' => __('message.your_code_not_found'),
                ];
                return json_custom_response($response);
            }
            $partner_referral = User::where('partner_referral_code', $user->referral_code);
        }

        if ($partner_referral->count() === 0) {
            $response = [
                'message' => __('message.not_use_any'),
            ];
            return json_custom_response($response);
        }

        $per_page = config('constant.PER_PAGE_LIMIT');
        if ($request->has('per_page') && !empty($request->per_page)) {
            if (is_numeric($request->per_page)) {
                $per_page = $request->per_page;
            }
            if ($request->per_page == -1) {
                $per_page = $partner_referral->count(); 
            }
        }

        $partner_referral = $partner_referral->orderBy('id', 'desc')->paginate($per_page);
        $items = UserResource::collection($partner_referral);

        $response = [
            'pagination' => json_pagination_response($items),
            'data' => $items,
        ];

        return json_custom_response($response);
    }

}

<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Http\Resources\CoinWalletResource;
use App\Models\CoinWallet;
use App\Models\RideRequest;
use Illuminate\Http\Request;

class CoinWalletController extends Controller
{
    public function saveCoinWallet(Request $request)
    {
        $user = auth()->user();

        CoinWallet::create([
            'user_id'      => $user->id,
            'ride_id'      => $request->ride_id ?? null,
            'coins'         => $request->coins,
            'type'         => 'credit',
            'scratch_time' => now(),
        ]);

        $user->increment('total_coins', $request->coins);

         $message =  __('message.new_coin_added');

         return json_custom_response([ 'status' => true, 'message' => $message ]);
    }

    public function getList(Request $request)
    {
        $authUser = auth()->user();
        $coinWallet = CoinWallet::myCoin();

        $per_page = config('constant.PER_PAGE_LIMIT');
        if( $request->has('per_page') && !empty($request->per_page)){
            if(is_numeric($request->per_page))
            {
                $per_page = $request->per_page;
            }
            if($request->per_page == -1 ){
                $per_page = $coinWallet->count();
            }
        }

        $coinWallet = $coinWallet->orderBy('created_at','desc')->paginate($per_page);
        $items = CoinWalletResource::collection($coinWallet);

        $response = [
            'pagination' => json_pagination_response($items),
            'total_coins' => $authUser->total_coins,
            'data' => $items,
        ];

        return json_custom_response($response);
    }
}

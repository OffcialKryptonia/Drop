<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Http\Resources\CustomerSupportResource;
use App\Models\CustomerSupport;

class CustomerSupportController extends Controller
{
    public function getList(Request $request)
    {
        $auth_user = auth()->user();
        $customer_support = CustomerSupport::getCustomersupport();

        $customer_support->when(request('support_id'), function ($q) {
            return $q->where('id', request('support_id'));
        });

        if( $request->has('status') && isset($request->status) ) {
            $customer_support = $customer_support->where('status',request('status'));
        }
        
        $per_page = config('constant.PER_PAGE_LIMIT');
        if( $request->has('per_page') && !empty($request->per_page)){
            if(is_numeric($request->per_page))
            {
                $per_page = $request->per_page;
            }
            if( $request->per_page == -1 ){
                $per_page = $customer_support->count();
            }
        }

        $customer_support = $customer_support->orderBy('id', 'desc')->paginate($per_page);
        $items = CustomerSupportResource::collection($customer_support);

        if(count($auth_user->unreadNotifications) > 0 ) {
            $auth_user->unreadNotifications->where('data.sender_id',request('sender_id'))->markAsRead();
        }

        $response = [
            'pagination' => json_pagination_response($items),
            'data' => $items,
        ];
        
        return json_custom_response($response);
    }
}
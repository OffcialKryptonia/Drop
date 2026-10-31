<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Airport;
use App\Http\Resources\AirPortResource;

class AirportController extends Controller
{
    public function getList(Request $request){

        $airport = Airport::query();
        
        $airport->when(request('airport_id'), function ($q) {
            return $q->where('airport_id', request('airport_id'));
        });
        
        $airport->when(request('name'), function ($q) {
            return $q->where('name', 'LIKE', '%' . request('name') . '%');
        });

        $per_page = config('constant.PER_PAGE_LIMIT');
        
        if( $request->has('per_page') && !empty($request->per_page)){
            if(is_numeric($request->per_page))
            {
                $per_page = $request->per_page;
            }
            if($request->per_page == -1 ){
                $per_page = $airport->count();
            }
        }

        $airport = $airport->orderBy('id','desc')->paginate($per_page);
        $items = AirPortResource::collection($airport);

        $response = [
            'pagination' => json_pagination_response($items),
            'data' => $items,
        ];
        
        return json_custom_response($response);
    }
}
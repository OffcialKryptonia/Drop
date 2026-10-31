<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\ManageZone;
use App\Http\Resources\ManageZoneResource;
use App\Models\ZonePrice;

class ManageZoneController extends Controller
{
    public function getList(Request $request){

        $managezon = ManageZone::query()->whereStatus('active');

        if (request('zone_id') > 0) {
            $zoneDropIds = ZonePrice::where('zone_pickup', request('zone_id'))->pluck('zone_dropoff')->toArray();
            if (empty($zoneDropIds)) {
                return json_custom_response([ 'pagination' => null, 'data' => [] ]);
            }
            $managezon->whereIn('id', $zoneDropIds);
        }

        $managezon->when(request('name'), function ($q) {
            return $q->where('name', 'LIKE', '%' . request('name') . '%');
        });

        $per_page = config('constant.PER_PAGE_LIMIT');

        if( $request->has('per_page') && !empty($request->per_page)){
            if(is_numeric($request->per_page))
            {
                $per_page = $request->per_page;
            }
            if($request->per_page == -1 ){
                $per_page = $managezon->count();
            }
        }

        $managezon = $managezon->orderBy('id','desc')->paginate($per_page);
        $items = ManageZoneResource::collection($managezon);

        $response = [
            'pagination' => json_pagination_response($items),
            'data' => $items,
        ];

        return json_custom_response($response);
    }
}

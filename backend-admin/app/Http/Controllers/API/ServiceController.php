<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Service;
use App\Models\Region;
use App\Http\Resources\ServiceResource;
use App\Http\Resources\EstimateServiceResource;
use App\Http\Requests\ETARequest;
use App\Models\Coupon;
use App\Models\User;

class ServiceController extends Controller
{
    public function getList(Request $request)
    {
        $service = Service::query();

        $service->when(request('region_id'), function ($q) {
            return $q->where('region_id', request('region_id'));
        });

        $service->when(request('name'), function ($q) {
            return $q->where('name', 'LIKE', '%' . request('name') . '%');
        });

        if( $request->has('pick_lat') && isset($request->pick_lat) && $request->has('pick_lng') && isset($request->pick_lng) )
        {
            $latitude = (float) $request->pick_lat;
            $longitude = (float) $request->pick_lng;

            $regionIds = Region::where('status', 1)->get()
                        ->filter(function ($region) use ($latitude, $longitude) {
                            $coordinates = is_string($region->coordinates) ? json_decode($region->coordinates, true) : $region->coordinates;
                            return is_array($coordinates) && pointInPolygon([$latitude, $longitude], $coordinates);
                        })
                        ->pluck('id');
            $service->whereIn('region_id', $regionIds);
        }

        $per_page = config('constant.PER_PAGE_LIMIT');
        if( $request->has('per_page') && !empty($request->per_page)){
            if(is_numeric($request->per_page))
            {
                $per_page = $request->per_page;
            }
            if($request->per_page == -1 ){
                $per_page = $service->count();
            }
        }

        $service = $service->orderBy('name','asc')->paginate($per_page);
        $items = ServiceResource::collection($service);

        $response = [
            'pagination' => json_pagination_response($items),
            'data' => $items,
        ];

        return json_custom_response($response);
    }

    public function estimatePriceTime(ETARequest $request)
    {
        $service = Service::query();

        $service->when(request('region_id'), function ($q) {
            return $q->where('region_id', request('region_id'));
        });

        $service->when(request('id'), function ($q) {
            return $q->where('id', request('id'));
        });

        if( $request->has('pick_lat') && isset($request->pick_lat) && $request->has('pick_lng') && isset($request->pick_lng) )
        {
            $latitude = (float) $request->pick_lat;
            $longitude = (float) $request->pick_lng;

            $regionIds = Region::where('status', 1)
                        ->get()
                        ->filter(function ($region) use ($latitude, $longitude) {
                            $coordinates = is_string($region->coordinates) ? json_decode($region->coordinates, true) : $region->coordinates;
                            return is_array($coordinates) && pointInPolygon([$latitude, $longitude], $coordinates);
                        })
                        ->pluck('id');
            $service->whereIn('region_id', $regionIds);
        }


        $per_page = config('constant.PER_PAGE_LIMIT');
        if( $request->has('per_page') && !empty($request->per_page)){
            if(is_numeric($request->per_page))
            {
                $per_page = $request->per_page;
            }
            if($request->per_page == -1 ){
                $per_page = $service->count();
            }
        }

        $service = $service->where('status','1')->orderBy('name','asc')->paginate($per_page);

        if( !empty(request('multi_location')) ) {
            $place_details = mighty_get_distance_matrix_multiple_destination(request('pick_lat'), request('pick_lng'), request('drop_lat'), request('drop_lng'), request('multi_location'));

            $dropoff_distance_in_meters = $place_details['distance'];
            $dropoff_time_in_seconds = $place_details['duration'];
        } else {
            $place_details = mighty_get_distance_matrix(request('pick_lat'), request('pick_lng'), request('drop_lat'), request('drop_lng'));

            $dropoff_distance_in_meters = distance_value_from_distance_matrix($place_details);
            $dropoff_time_in_seconds = duration_value_from_distance_matrix($place_details);
            // dd($dropoff_time_in_seconds);
        }
        $distance_in_unit = 0;
        if ($dropoff_distance_in_meters) {
            $distance_in_unit = $dropoff_distance_in_meters;
        }

        $coupon_code = $request->coupon_code;
        $coupon = Coupon::where('code', $coupon_code)->first();
        $status = 200;
        if ($coupon) {
            $status = Coupon::isValidCoupon($coupon);
        } else if ($coupon_code) {
            $status = 400; // Invalid coupon code
        }
        if( $status != 200 ) {
            $response = couponVerifyResponse($status);
            return json_custom_response($response,$status);
        }
        $request['distance_in_unit'] = $distance_in_unit;
        $request['dropoff_distance_in_meters'] = $dropoff_distance_in_meters ;
        $request['dropoff_time_in_seconds'] = $dropoff_time_in_seconds ;
        $request['coupon'] = $coupon;

        EstimateServiceResource::$dropoffTimeInSeconds = $dropoff_time_in_seconds;
        EstimateServiceResource::$dropoff_distance_in_meters = $dropoff_distance_in_meters;
        $authUser = User::find($request->user_id);
        $items = EstimateServiceResource::collection($service);
        $response = [
            'pagination' => json_pagination_response($items),
            'total_coins' => $authUser ? $authUser->total_coins : 0,
            'data' => $items,
            'message' => $items->total() <= 0 ? __('message.service_not_available') : null
        ];

        return json_custom_response($response);
    }
}

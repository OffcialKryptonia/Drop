<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Faq;
use App\Http\Resources\FaqResource;

class FaqsController extends Controller
{    
    public function getList(Request $request)
    {
        $items = Faq::myFaq();

        $items->when(request('question'), function ($q) {
            return $q->where('question', 'LIKE', '%' . request('question') . '%');
        });
        $items->when(request('app'), function ($q) {
            return $q->where('type', 'LIKE', '%' . request('app') . '%');
        });


        $per_page = config('constant.PER_PAGE_LIMIT');
        if( $request->has('per_page') && !empty($request->per_page)){
            if(is_numeric($request->per_page))
            {
                $per_page = $request->per_page;
            }
            if($request->per_page == -1 ){
                $per_page = $items->count();
            }
        }

        $items = $items->orderBy('id', 'desc')->paginate($per_page);
        $items = FaqResource::collection($items);

        $response = [
            'pagination'    => json_pagination_response($items),
            'data'          => $items,
        ];
        return json_custom_response($response);
    }
}

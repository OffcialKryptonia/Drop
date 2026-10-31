<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Cancellation;
use App\DataTables\CancellationDataTable;
use App\Http\Requests\CancellationRequest;
use App\Http\Resources\CencelReasonResource;

class CancellationController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(CancellationDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.cancellation')] );
        $auth_user = authSession();
        $assets = ['datatable'];
        $button = !$auth_user->can('cancellation-add') ? '<a href="'.route('cancellation.create').'" class="loadRemoteModel float-right btn btn-sm border-radius-10 btn-primary me-2"><i class="fa fa-plus-circle"></i> '.__('message.add_form_title',['form' => __('message.cancellation')]).'</a>' : '';
        return $dataTable->render('global.datatable', compact('pageTitle','button','auth_user'));
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        $pageTitle = __('message.add_form_title',[ 'form' => __('message.cancellation')]);
        return view('cancellation.form', compact('pageTitle'))->render();
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(CancellationRequest $request)
    {
        Cancellation::create($request->all());
        return response()->json(['status' => true, 'event' => 'submited','message' => __('message.save_form', ['form' => __('message.cancellation')])]);
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        //
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(string $id)
    {
        $pageTitle = __('message.update_form_title',[ 'form' => __('message.cancellation')]);
        $data = Cancellation::findOrFail($id);
        return view('cancellation.form', compact('data', 'pageTitle', 'id'));
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(CancellationRequest $request, string $id)
    {
        $cancellation = Cancellation::findOrFail($id);
        // cancellation data...
        $cancellation->fill($request->all())->update();
        return response()->json(['status' => true, 'event' => 'submited','message' => __('message.update_form',['form' => __('message.cancellation') ] )]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {

        $cancellation = Cancellation::findOrFail($id);
        $status = 'errors';
        $message = __('message.not_found_entry', ['name' => __('message.cancellation')]);

        if($cancellation != '') {
            $cancellation->delete();
            $status = 'success';
            $message = __('message.delete_form', ['form' => __('message.cancellation')]);
        }

        if(request()->ajax()) {
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->back()->with($status,$message);
    }
    public function getList(Request $request)
    {

        $cancellation = Cancellation::query();
        
        $cancellation->when(request('type'), function ($q) {
            return $q->where('type', 'LIKE', '%' . request('type') . '%');
        });
        $per_page = config('constant.PER_PAGE_LIMIT');

        if ($request->has('per_page') && !empty($request->per_page)) {
            if (is_numeric($request->per_page)) {
                $per_page = $request->per_page;
            }
            if ($request->per_page == -1) {
                $per_page = $cancellation->count();
            }
        }

        $cancellation = $cancellation->orderBy('id', 'desc')->paginate($per_page);
        $items = CencelReasonResource::collection($cancellation);

        $response = [
            'pagination' => json_pagination_response($items),
            'data' => $items,
        ];

        return json_custom_response($response);
    }
}

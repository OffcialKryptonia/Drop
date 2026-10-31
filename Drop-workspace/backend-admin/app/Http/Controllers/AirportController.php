<?php

namespace App\Http\Controllers;

use App\DataTables\AirportDataTable;
use App\Http\Requests\AirportImportRequest;
use App\Http\Requests\AirportRequest;
use App\Imports\AirportsImport;
use App\Models\Airport;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;

class AirportController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(AirportDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.airport')] );
        $auth_user = authSession();
        $assets = ['datatable'];
        $button = $auth_user->can('airport-add') ? '<a href="'.route('airport.create').'" class="float-right btn btn-sm border-radius-10 btn-primary me-2"><i class="fa fa-plus-circle"></i> '.__('message.add_form_title',['form' => __('message.airport')]).'</a>' : '';
        $importbutton = $auth_user->can('airport-add') ? '<a href="'.route('airport.data').'" class="float-right btn btn-sm border-radius-10 btn-primary me-2 ml-3"><i class="fa fa-file-import"></i> '.__('message.import_airport_data').'</a>' : '';
        $multi_checkbox_delete = $auth_user->can('airport-delete') ? '<button id="deleteSelectedBtn" checked-title = "airport-checked" class="float-left btn btn-sm ">'.__('message.delete_selected').'</button>' : '';

        return $dataTable->render('global.datatable', compact('assets','pageTitle','button','auth_user','multi_checkbox_delete','importbutton'));
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        if(env('APP_DEMO')){
            $message = __('message.demo_permission_denied');
            return redirect()->route('airport.index')->withErrors($message);
        }
        $assets = ['map'];
        $pageTitle = __('message.add_form_title',[ 'form' => __('message.airport')]);
        return view('airport.form', compact('pageTitle','assets'));
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(AirportRequest $request)
    {
        $data = $request->all();
        $airport = Airport::create($data);
        $message = __('message.save_form', ['form' => __('message.airport')]);
        if (request()->is('api/*')) {
            return json_message_response($message);
        }

        return redirect()->route('airport.index')->withSuccess($message);
    }

    /**
     * Display the specified resource.
     */
    public function show($id)
    {
        $pageTitle = __('message.view_form_title', ['form' => __('message.airport')]);
        $data = Airport::findOrFail($id);

        return view('airport.form', compact('pageTitle', 'data', 'id'));
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit($id)
    {
        $assets = ['map'];
        $pageTitle = __('message.update_form_title', ['form' => __('message.airport')]);
        $data = Airport::findOrFail($id);

        return view('airport.form', compact('data', 'pageTitle', 'id','assets'));
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(AirportRequest $request, $id)
    {
        if(env('APP_DEMO')){
            return redirect()->route('airport.index')->withErrors(__('message.demo_permission_denied'));
        }
        $airport = Airport::find($id);
        $message = __('message.not_found_entry', ['name' => __('message.airport')]);
        if ($airport == null) {
            return json_custom_response(['status' => false, 'message' => $message]);
        }

        $airport->update($request->all());

        $message = __('message.update_form', ['form' => __('message.airport')]);
        if (request()->is('api/*')) {
            return json_message_response($message);
        }
        return redirect()->back()->withSuccess($message);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy($id)
    {
        if(env('APP_DEMO')){
            $message = __('message.demo_permission_denied');
            if(request()->is('api/*')){
                return response()->json(['status' => true, 'message' => $message ]);
            }
            if(request()->ajax()) {
                return response()->json(['status' => true, 'message' => $message ]);
            }
            return redirect()->route('airport.index')->withErrors($message);
        }
        $airport = Airport::findOrFail($id);
        $status = 'errors';
        $message = __('message.not_found_entry', ['name' => __('message.airport')]);

        if($airport != '') {
            $airport->delete();
            $status = 'success';
            $message = __('message.delete_form', ['form' => __('message.airport')]);
        }
        if(request()->is('api/*')){
            return response()->json(['status' => true, 'message' => $message ]);
        }
        if(request()->ajax()) {
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->back()->with($status,$message);
    }

    public function importdata()
    {
        if(env('APP_DEMO')){
            $message = __('message.demo_permission_denied');
            if(request()->is('api/*')){
                return response()->json(['status' => true, 'message' => $message ]);
            }
            if(request()->ajax()) {
                return response()->json(['status' => false, 'message' => $message, 'event' => 'validation']);
            }

        }
        $auth_user = authSession();
        if (!auth()->user()->can('airport-list')) {
            $message = __('message.permission_denied_for_account');
            return redirect()->back()->withErrors($message);
        }
        $pageTitle = __('message.airport_data');

        return view('airport.airportdata',compact([ 'pageTitle' ]));

    }

    public function importairportdata(AirportImportRequest $request)
    {
        // $request->validate([
        //     'airport_data' => 'required|file|mimes:csv,xls,xlsx',
        // ], [
        //     'airport_data.required' => __('message.select_file_required'),
        //     'airport_data.mimes' => __('message.invalid_file_type'),
        // ]);

        Excel::queueImport(new AirportsImport, $request->file('airport_data')->store('files'));
        $message = __('message.save_form', ['form' => __('message.airport_data')]);
        return redirect()->route('airport.data')->withSuccess($message);
    }
    public function action(Request $request)
    {
        $id = $request->id;
        $user = Airport::withTrashed()->where('id',$id)->first();
        $message = __('message.not_found_entry',['name' => __('message.airport')] );
        if($request->type === 'restore'){
            $user->restore();
            $message = __('message.msg_restored',['name' => __('message.airport')] );
        }

        if($request->type === 'forcedelete'){
            if(env('APP_DEMO')){
                $message = __('message.demo_permission_denied');
                if(request()->is('api/*')){
                    return response()->json(['status' => true, 'message' => $message ]);
                }
                if(request()->ajax()) {
                    return response()->json(['status' => false, 'message' => $message, 'event' => 'validation']);
                }
                return redirect()->route('airport.index')->withErrors($message);
            }
            $user->forceDelete();
            $message = __('message.msg_forcedelete',['name' => __('message.airport')] );
        }

        if(request()->is('api/*')){
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->route('airport.index')->withSuccess($message);
    }
}

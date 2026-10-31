<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\ManageZone;
use App\DataTables\ManageZoneDataTable;
use App\Http\Requests\ManageZoneRequest;

class ManageZoneController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(ManageZoneDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.manage_zone')] );
        $auth_user = authSession();
        if (!auth()->user()->can('managezone-list')) {
            $message = __('message.permission_denied_for_account');
            return redirect()->back()->withErrors($message);
        }
        $assets = ['datatable'];

        $button = $auth_user->can('managezone-add') ? '<a href="'.route('managezone.create').'" class="float-right btn btn-sm border-radius-10 btn-primary me-2"><i class="fa fa-plus-circle"></i> '.__('message.add_form_title',['form' => __('message.new_zone')]).'</a>' : '';
        return $dataTable->render('global.datatable', compact('pageTitle','button','auth_user'));
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        $assets = ['map'];
        $pageTitle = __('message.add_form_title',[ 'form' => __('message.manage_zone')]);
        return view('managezone.form', compact('pageTitle','assets'));
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(ManageZoneRequest $request)
    {
        ManageZone::create($request->all());
        $message = __('message.save_form', ['form' => __('message.manage_zone')]);
        if(request()->is('api/*')){
            return response()->json(['status' => true, 'message' => $message ]);
        }
        return redirect()->route('managezone.index')->withSuccess($message);
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
        $assets = ['map'];
        $pageTitle = __('message.update_form_title',[ 'form' => __('message.manage_zone')]);
        $data = ManageZone::findOrFail($id);

        return view('managezone.form', compact('data', 'pageTitle', 'id', 'assets'));
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(ManageZoneRequest $request, string $id)
    {
        $manage_zone = ManageZone::findOrFail($id);

        if ( $manage_zone == null ) {
            return redirect()->route('managezone.index')->withErrors(__('message.not_found_entry', ['name' => __('message.manage_zone')]));
        }

        $manage_zone->fill($request->all())->update();
        $message = __('message.update_form', ['form' => __('message.manage_zone')]);
        if (request()->is('api/*')) {
            return json_message_response($message);
        }

        return redirect()->route('managezone.index')->withSuccess($message);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        $manage_zone = ManageZone::findOrFail($id);
        $status = 'errors';
        $message = __('message.not_found_entry', ['name' => __('message.manage_zone')]);

        if($manage_zone != '') {
            $manage_zone->delete();
            $status = 'success';
            $message = __('message.delete_form', ['form' => __('message.manage_zone')]);
        }
        if(request()->is('api/*')){
            return response()->json(['status' => true, 'message' => $message ]);
        }
        if( request()->ajax() ) {
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->back()->with($status,$message);
    }
}

<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\DataTables\ManageZonePriceDataTable;
use App\Http\Requests\ManageZonePriceRequest;
use App\Models\{ZonePrice,Service,ManageZone};

class ManageZonePriceController extends Controller
{
    public function index(ManageZonePriceDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.manage_zone_price')] );
        $auth_user = authSession();
        if (!auth()->user()->can('managezone-price-list')) {
            $message = __('message.permission_denied_for_account');
            return redirect()->back()->withErrors($message);
        }
        $assets = ['datatable'];

        $button = $auth_user->can('managezone-price-add') ? '<a href="'.route('managezone-price.create').'" class="float-right btn btn-sm border-radius-10 btn-primary me-2"><i class="fa fa-plus-circle"></i> '.__('message.add_form_title',['form' => __('message.zone_price')]).'</a>' : '';
        return $dataTable->render('global.datatable', compact('pageTitle','button','auth_user'));
    }

    public function create()
    {
        $assets = ['map'];
        $pageTitle = __('message.add_form_title',[ 'form' => __('message.manage_zone_price')]);
        $zones = ManageZone::pluck('name', 'id');;
        $services = Service::pluck('name', 'id');;

        return view('managezone-price.form', compact('pageTitle','assets','zones','services'));
    }

    public function store(ManageZonePriceRequest $request)
    {
        $data = ZonePrice::where(['zone_pickup' => $request->pickup_zone_id,'zone_dropoff' => $request->dropoff_zone_id])->first();
        if(!$data && empty($data)){
            ZonePrice::create([
                'service_ids' => $request->service_ids,
                'zone_pickup' => $request->pickup_zone_id,
                'zone_dropoff' => $request->dropoff_zone_id,
                'price' => $request->price,
            ]);
        }else{
            $data->update([
                'service_ids' => $request->service_ids,
                'price' => $request->price,
            ]);
        }

        return redirect()->route('managezone-price.index')->with('success', __('message.save_form', ['form' => __('message.manage_zone_price')]));
    }

    public function show(string $id)
    {
        //
    }

    public function edit(string $id)
    {
        $assets = ['map'];
        $pageTitle = __('message.update_form_title', [ 'form' => __('message.manage_zone_price')]);

        $zonePrice = ZonePrice::findOrFail($id);
        $selectedServiceIds = $zonePrice->service_ids ?? [];
        $selectedServices = [];
        if(isset($selectedServiceIds)){
            $selectedServices = Service::whereIn('id', $selectedServiceIds)->get()->mapWithKeys(function ($item) {
                return [ $item->id => $item->name ];
            });
        }
        $zones = ManageZone::pluck('name', 'id');

        return view('managezone-price.form', compact('zonePrice', 'zones', 'pageTitle', 'id', 'assets', 'selectedServiceIds','selectedServices'));
    }


    public function update(ManageZonePriceRequest $request, string $id)
    {
        ZonePrice::where('id',$id)->update([
            'service_ids' => $request->service_ids,
            'zone_pickup' => $request->pickup_zone_id,
            'zone_dropoff' => $request->dropoff_zone_id,
            'price' => $request->price,
        ]);

        return redirect()->route('managezone-price.index')->with('success', __('message.update_form_title',[ 'form' => __('message.manage_zone_price')]));
    }

    public function destroy(string $id)
    {
        $manage_zone_price = ZonePrice::findOrFail($id);
        $status = 'errors';
        $message = __('message.not_found_entry', ['name' => __('message.manage_zone_price')]);

        if($manage_zone_price != '') {
            $manage_zone_price->delete();
            $status = 'success';
            $message = __('message.delete_form', ['form' => __('message.manage_zone_price')]);
        }
        if( request()->ajax() ) {
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->back()->with($status,$message);
    }
}

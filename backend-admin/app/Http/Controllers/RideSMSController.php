<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\SMSSetting;
use App\Models\SMSTemplatRide;

class RideSMSController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        $rideType =   $orders_type = isset($_GET['sms_type']) ? $_GET['sms_type'] : null;
        $data = SMSTemplatRide::where('type',$rideType)->first();
        $pageTitle = __('message.sms_template_setting');

        return view('ridesms.form', compact('pageTitle','rideType','data'));
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        //
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $data = $request->all();
        
        // Set default order_status based on the subject in the request
        if ($request->type == 'driver_is_arrived') {
            $data['ride_status'] = 'arrived';
        }
        $smsSetting = SMSSetting::first();
        $data['sms_id'] = isset($smsSetting) ? $smsSetting->id : null;
           
        $smsTemplate = SMSTemplatRide::updateOrCreate(
            ['type' => $request->type],$data
        );
        $message = __('message.update_form', ['form' => __('message.ride-sms')]);
    
        if ($smsTemplate->wasRecentlyCreated) {
            $message = __('message.save_form', ['form' => __('message.ride-sms')]);
        }
        return redirect()->route('ridesms.index', ['sms_type' => $request->type])->withSuccess($message);
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
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        //
    }
}

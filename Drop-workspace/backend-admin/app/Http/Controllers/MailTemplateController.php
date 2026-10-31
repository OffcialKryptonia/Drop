<?php

namespace App\Http\Controllers;

use App\Models\MailTemplate;
use Illuminate\Http\Request;

class MailTemplateController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index(Request $request)
    {
        $type = isset($_GET['type']) ? $_GET['type'] : null;
        $data = MailTemplate::where('type',$type)->first();
        $pageTitle = __('message.mail_template',['name' => __('message.'.$type)]);

        if ( !array_key_exists($type,config('constant.mail_template_setting')) ) {
            return redirect()->back()->withError(__('validation.active_url',[ 'attribute' => $type ]));
        }

        return view('mail_template.form', compact('pageTitle','data','type'));
    }

    
    public function otpVerify_template(Request $request)
    {
        $type =   $mails_type = isset($_GET['mails_type']) ? $_GET['mails_type'] : null;
        $data = MailTemplate::where('type',$type)->first();
        $pageTitle = __('message.mail_template_setting');

        return view('ordermail.form', compact('pageTitle','data','type'));
    }
    /**
     * Show the form for creating a new resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function create()
    {
        //
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
        $type = $request->type;
        if ( !array_key_exists($type,config('constant.mail_template_setting')) ) {
            return redirect()->back()->withError(__('validation.active_url',[ 'attribute' => $type ]));
        }

        MailTemplate::updateOrCreate([ 'type' => $type ], $request->all());
        $message = __('message.update_form',[ 'form' => __('message.mail_template', [ 'name' => __('message.'.$type) ]) ] );

        if($request->is('api/*')) {
            return json_message_response($message);
		}

        return redirect()->route('mail-template.index', [ 'type' => $type ])->withSuccess($message);
    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        //
    }

    /**
     * Show the form for editing the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function edit($id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(Request $request, $id)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        //
    }
}

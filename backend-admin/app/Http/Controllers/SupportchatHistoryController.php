<?php

namespace App\Http\Controllers;

use App\Models\SupportChathistory;
use Illuminate\Http\Request;

class SupportchatHistoryController extends Controller
{
    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
        $request->merge([
            'user_id' => auth()->id(),
            'datetime' => now(),
        ]);
        if ($request->has('support_id')) {
            $support_id = $request->input('support_id');
        } else {
            return back()->withErrors(['support_id' => 'Support ID is missing.']);
        }
        $supportchat = SupportChathistory::create($request->all());
        $message = __('message.save_form',['form' => __('message.customer_support')]);
        
        if(request()->is('api/*')){
            return json_message_response( $message );
        }
        return redirect()->route('customersupport.show',$supportchat->support_id)->withSuccess($message);
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
        $supportchat = SupportChathistory::findOrFail($id);

        $supportchat->fill($request->all())->update();

        $message = __('message.update_form',['form' => __('message.supportchathistory')]);

        if(request()->is('api/*')){
            return json_message_response( $message );
        }

        if(auth()->check()){
            return redirect()->route('customersupport.index')->withSuccess($message);
        }
        return redirect()->back()->withSuccess($message);
    }

    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        if(env('APP_DEMO')){
            $message = __('message.demo_permission_denied');
            if(request()->ajax()) {
                return response()->json(['status' => true, 'message' => $message ]);
            }
            return redirect()->route('customersupport.index')->withErrors($message);
        }
        $supportchat = SupportChathistory::find($id);
        $status = 'errors';
        $message = __('message.not_found_entry', ['name' => __('message.customer_support')]);

        if($supportchat != '') {
            $supportchat->delete();
            $status = 'success';
            $message = __('message.delete_form', ['form' => __('message.customer_support')]);
        }
        
        if(request()->is('api/*')){
            return json_message_response( $message );
        }

        if(request()->ajax()) {
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->back()->with($status,$message);
    }
}
<?php

namespace App\Http\Controllers;

use App\DataTables\CustomerSupportDataTable;
use Illuminate\Http\Request;
use App\Models\CustomerSupport;
use App\Models\SupportChathistory;
use App\Models\User;
use Illuminate\Support\Facades\Auth;
use App\Notifications\CustomerSupportNotification;
use App\Models\Notification;

class CustomerSupportController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index(CustomerSupportDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.customer_support')] );
        $auth_user = authSession();
        $assets = ['datatable'];
        $button = '';

        return $dataTable->render('global.datatable', compact('pageTitle','auth_user','button'));
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
        $data = $request->all();
        $data['user_id'] = auth()->id();

        if ($request->is('api/*')) {
            $customer_support = CustomerSupport::create($data);
            
            $data['support_id'] = $customer_support->id;
            $data['datetime'] = now();

            if($request->support_image != null)
            {
                uploadMediaFile($customer_support, $request->support_image, 'support_image');
            }

            if($request->support_videos != null)
            {
                uploadMediaFile($customer_support, $request->support_videos, 'support_videos');
            }

            $support_chat_history = SupportChathistory::create($data);
            $message = __('message.save_form', ['form' => __('message.customer_support')]);
            
            $notification_data = [
                'support_id'  => $customer_support->id,
                'type'      => __('message.customer_support'),
                'support_type' => $customer_support->support_type,
                'subject'     => __('message.customersupport.support_id', ['id' => $customer_support->id]),
                'message'     => __('message.customersupport.notification_message', [
                    'support_id' => $customer_support->id,
                    'support_type' => $customer_support->support_type,
                    'name' => ucfirst(optional($support_chat_history->user)->user_type)
                ]),
                'created_by'  => $support_chat_history->user_id,
            ];
            
            $admins = User::admin()->get();
            foreach ($admins as $admin) {
                $admin->notify(new CustomerSupportNotification($notification_data));
            }
            return json_message_response($message);
        } 
    }
    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        $current_user = auth()->user();
        $pageTitle = __('message.add_form_title',[ 'form' => __('message.customer_support')]);
        $data = CustomerSupport::findOrFail($id);
        $match  = SupportChathistory::where('support_id',$id)->get();

        return view('customer-suport.show', compact('data','pageTitle','current_user','match'));
    }

    /**
     * Show the form for editing the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */

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
            if(request()->is('api/*')){
                return response()->json(['status' => true, 'message' => $message ]);
            }
            if(request()->ajax()) {
                return response()->json(['status' => false, 'message' => $message, 'event' => 'validation']);
            }
            return redirect()->route('customersupport.index')->withErrors($message);
        }
        $customersupport = CustomerSupport::find($id);
        $status = 'errors';
        $message = __('message.not_found_entry', ['name' => __('message.customer_support')]);

          if($customersupport != '') {
            $customersupport->delete();
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

    public function chatMessage(Request $request)
    {
        $data = $request->all();
        $data['datetime'] = now();
        $chatdata = SupportChathistory::create($data);
        $message = __('message.message_sent_successfully');
        return json_message_response( $message );
    }

    public function updateStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:pending,inreview,resolved',
        ]);

        $support = CustomerSupport::findOrFail($id);

        $support->status = $request->input('status');
        $support->resolution_detail = $request->input('resolution_detail');
        $support->save();
        $message = __('message.status_updated');
        if(request()->is('api/*')){
            return json_message_response( $message );
        }
        return redirect()->back()->with('success', __('message.status_updated'));
    }

}
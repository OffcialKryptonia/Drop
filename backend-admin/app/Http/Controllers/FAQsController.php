<?php

namespace App\Http\Controllers;

use App\DataTables\FaqsDataTable;
use App\Http\Requests\FaqsRequest;
use Illuminate\Http\Request;
use App\Models\Faq;

class FAQsController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(FaqsDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.faq')] );
        $auth_user = authSession();
        $assets = ['datatable'];
        $button = $auth_user->can('faq-add') ? '<a href="'.route('faqs.create').'" class="float-right btn btn-sm btn-primary"><i class="fa fa-plus-circle"></i> '.__('message.add_form_title',['form' => __('message.faq')]).'</a>' : '';

        return $dataTable->render('global.datatable', compact('pageTitle','button','auth_user'));
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        $pageTitle = __('message.add_form_title',[ 'form' => __('message.faq')]);
        
        return view('faq.form', compact('pageTitle'));
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(FaqsRequest $request)
    {
        $data = $request->all();
        Faq::create($data);
        $message = __('message.save_form', ['form' => __('message.faq')]);        
        if(request()->is('api/*')) {
            return json_message_response($message);
		}
        return redirect()->route('faqs.index')->withSuccess($message);
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
        $pageTitle = __('message.update_form_title',[ 'form' => __('message.faq')]);
        $data = Faq::findOrFail($id);
        
        return view('faq.form', compact('data', 'pageTitle', 'id'));    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        $faq = Faq::find($id);
        $message = __('message.not_found_entry', ['name' => __('message.faq')]);
        if($faq == null) {
            return response()->json(['status' => false, 'message' => $message ]);
        }

        $faq->fill($request->all())->update();
        $message = __('message.update_form',['form' => __('message.faq')]);

        if(auth()->check()){
            return redirect()->route('faqs.index')->withSuccess($message);
        }
        if(request()->is('api/*')){
            return response()->json(['status' =>  (($faq != '') ? true : false) , 'message' => $message ]);
        }
        return redirect()->back()->withSuccess($message);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        if( env('APP_DEMO') ) {
            $message = __('message.demo_permission_denied');
            if(request()->ajax()) {
                return response()->json(['status' => false, 'message' => $message, 'event' => 'validation']);
            }
            return redirect()->back()->withErrors($message);
        }
        $faq = Faq::find($id);            
        if($faq != '') {
            $faq->delete();
            $status = 'success';
            $message = __('message.delete_form', ['form' => __('message.faq')]);
        }

        if(request()->ajax()) {
            return response()->json(['status' => true, 'message' => $message ]);
        }
        if(request()->is('api/*')){
            return response()->json(['status' =>  (($faq != '') ? true : false) , 'message' => $message ]);
        }

        return redirect()->back()->withSuccess($message);
    }
}

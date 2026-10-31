<?php

namespace App\Http\Controllers;

use App\DataTables\DriverPayoutReportsDataTable;
use App\Models\DriverPayoutReport;
use Illuminate\Http\Request;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;

class DriverPayoutReportsController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(DriverPayoutReportsDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.driver_payout_reports')] );
        $auth_user = authSession();
        $assets = ['datatable'];
        return $dataTable->render('global.datatable', compact('pageTitle','auth_user'));
    }

    public function edit($id)
    {
        if (!auth()->user()->can('driver-payout-reports-edit')) {
            $message = __('message.permission_denied_for_account');
            return redirect()->back()->withErrors($message);
        }
        $pageTitle = __('message.update_form_title',[ 'form' => __('message.driver_payout_reports')]);
        $data = DriverPayoutReport::findOrFail($id);
        return view('driver_payout_report.form', compact('data', 'pageTitle', 'id'));
    }
    public function update(Request $request, $id)
    {
        if (!auth()->user()->can('driver-payout-reports-edit')) {
            $message = __('message.permission_denied_for_account');
            return redirect()->back()->withErrors($message);
        }
        $payoutReport = DriverPayoutReport::findOrFail($id);

        $payoutReport->update([
            'status' => $request->status,
            'payment_method' => $request->payment_method,
            'transaction_reference' => $request->transaction_reference,
            'paid_at' => now(),
        ]);
        $message = __('message.update_form',['form' => __('message.driver_payout_reports')]);
        return response()->json(['status' => true, 'event' => 'submited', 'message'=> $message]);
    }

}

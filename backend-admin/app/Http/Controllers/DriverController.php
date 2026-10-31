<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\User;
use App\DataTables\DriverDataTable;
use App\DataTables\DriverDocumentDataTable;
use App\Models\Role;
use App\Http\Requests\DriverRequest;
use App\Models\DriverDocument;
use App\Models\Payment;
use App\DataTables\PaymentDataTable;
use App\Models\WalletHistory;
use App\DataTables\WalletHistoryDataTable;
use App\DataTables\DriverEarningDataTable;
use App\DataTables\DriverPayoutReportsDataTable;
use App\DataTables\RideRequestDataTable;
use App\DataTables\RideRequestRatingDataTable;
use App\Exports\DriverReportExport;
use Barryvdh\DomPDF\Facade\Pdf;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Maatwebsite\Excel\Facades\Excel;

class DriverController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index(DriverDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.driver')] );
        $auth_user = authSession();
        if(!empty(request('status'))) {
            $pageTitle = __('message.pending_list_form_title',['form' => __('message.driver')] );
        }
        $last_actived_at = request('last_actived_at') ?? null;
        $assets = ['datatable'];
        $button = $auth_user->can('driver add') ? '<a href="'.route('driver.create').'" class="float-right btn btn-sm border-radius-10 btn-primary me-2"><i class="fa fa-plus-circle"></i> '.__('message.add_form_title',['form' => __('message.driver')]).'</a>' : '';
        return $dataTable->with('status', request('status'))->render('global.driver-datatable', compact('assets','pageTitle','button','auth_user','last_actived_at'));
    }

    /**
     * Show the form for creating a new resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function create()
    {
        $pageTitle = __('message.add_form_title',[ 'form' => __('message.driver')]);
        $assets = ['phone'];
        // $selected_service = [];
        return view('driver.form', compact('pageTitle','assets'));
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(DriverRequest $request)
    {
        $request['password'] = bcrypt($request->password);

        $request['username'] = $request->username ?? stristr($request->email, "@", true) . rand(100,1000);
        $request['display_name'] = $request->first_name.' '. $request->last_name;
        $request['user_type'] = 'driver';

        if(auth()->user()->hasRole('fleet')) {
            $request['fleet_id'] = auth()->user()->id;
        }
        $user = User::create($request->all());

        uploadMediaFile($user,$request->profile_image, 'profile_image');
        $user->assignRole('driver');
        // Save Driver detail...
        $user->userDetail()->create($request->userDetail);
        $user->userBankAccount()->create($request->userBankAccount);

        $user->userWallet()->create(['total_amount' => 0 ]);
/*
        if($user->driverService()->count() > 0)
        {
            $user->driverService()->delete();
        }

        if($request->service_id != null) {
            foreach($request->service_id as $service) {
                $driver_services = [
                    'service_id'    => $service->id,
                    'driver_id'     => $user->id,
                ];
                $user->driverService()->insert($driver_services);
            }
        }
*/
        return redirect()->route('driver.index')->withSuccess(__('message.save_form', ['form' => __('driver')]));
    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show(WalletHistoryDataTable $dataTable,RideRequestDataTable $rideRequestDataTable, DriverPayoutReportsDataTable $DriverPayoutReportsDataTable, RideRequestRatingDataTable $rideRequestRatingDataTable, DriverDocumentDataTable $driverDocumentDataTable, $id)
    {
        $pageTitle = __('message.view_form_title',[ 'form' => __('message.driver')]);
        $data = User::where('user_type', 'driver')->with('roles','userDetail', 'userBankAccount')->findOrFail($id);
        $data->rating = $data->driverRating->where('rating', '>', 0)->avg('rating') ? (float) number_format($data->driverRating->where('rating', '>', 0)->avg('rating'), 2) : 0;

        $data->cash_earning = Payment::whereHas('riderequest',function ($q) use($id) {
                $q->where('driver_id',$id);
            })->where('payment_status', 'paid')->where('payment_type', 'cash')->value(DB::raw('SUM(admin_commission + driver_commission)')) ?? 0;

        $data->admin_commission = Payment::whereHas('riderequest',function ($q) use($id) {
            $q->where('driver_id', $id);
        })->where('payment_status', 'paid')->sum('admin_commission') ?? 0;

        $data->wallet_earning = Payment::whereHas('riderequest',function ($q) use($id) {
                $q->where('driver_id',$id);
            })->where('payment_status', 'paid')->where('payment_type', 'wallet')->sum('driver_commission') ?? 0;

        $data->total_earning = $data->cash_earning + $data->wallet_earning;

        $data->driver_earning = Payment::whereHas('riderequest',function ($q) use($id) {
            $q->where('driver_id', $id);
        })->where('payment_status', 'paid')->sum('driver_commission') ?? 0;

        $profileImage = getSingleMedia($data, 'profile_image');
        $type = request('type') ?? 'detail';

        // $validStatuses = [
        //     'new_ride_requested',
        //     'accepted',
        //     'arriving',
        //     'arrived',
        //     'in_progress',
        //     'completed'
        // ];
        // foreach ($data->driverRideRequestDetail as $key => $value) {
        //     if (in_array($value->status, $validStatuses)) {
        //         $data['in_service'] = 1;
        //     }
        // }

        switch ($type) {
                case 'detail':
                    return view('driver.show', compact('pageTitle', 'data', 'profileImage','type'));
                break;

                case 'bank_detail':
                    return view('driver.show', compact('pageTitle', 'data', 'profileImage','type'));
                break;

                case 'wallet_history':
                    return $dataTable->with('user_id',$id)->render('driver.show', compact('pageTitle', 'data', 'profileImage', 'type' ));
                break;

                case 'ride_request':
                    return $rideRequestDataTable->with('driver_id',$id)->render('driver.show', compact('pageTitle', 'data', 'profileImage', 'type' ));
                break;
                case 'driver_payout_report':
                    return $DriverPayoutReportsDataTable->with('driver_id',$id)->render('driver.show', compact('pageTitle', 'data', 'profileImage', 'type' ));
                break;

                case 'driver_rating':
                    return $rideRequestRatingDataTable->with('driver_id',$id)->render('driver.show', compact('pageTitle', 'data', 'profileImage', 'type' ));
                break;

                case 'driver_Document':
                    return $driverDocumentDataTable->with('driver_id',$id)->render('driver.show', compact('pageTitle', 'data', 'profileImage', 'type' ));
                break;

            default:
                # code...
                $type = 'detail';
                return view('driver.show', compact('pageTitle', 'data', 'profileImage','type'));
                break;
        }

    }

    /**
     * Show the form for editing the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function edit($id)
    {
        $pageTitle = __('message.update_form_title',[ 'form' => __('message.driver')]);
        $data = User::where('user_type', 'driver')->with('userDetail','userBankAccount')->findOrFail($id);

        $profileImage = getSingleMedia($data, 'profile_image');
        $assets = ['phone'];
/*
        $selected_service = $data->driverService->mapWithKeys(function ($item) {
            return [ $item->service_id => optional($item->service)->name ];
        });
*/
        return view('driver.form', compact('data', 'pageTitle', 'id', 'profileImage', 'assets'));
    }

    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(DriverRequest $request, $id)
    {
        $user = User::with('userDetail')->findOrFail($id);

        $request['password'] = $request->password != '' ? bcrypt($request->password) : $user->password;

        $request['display_name'] = $request->first_name.' '. $request->last_name;

        if(auth()->user()->hasRole('fleet')) {
            $request['fleet_id'] = auth()->user()->id;
        }

        if ($request->status !== 'active') {
            $request['is_online'] = 0;
            $request['is_available'] = 0;
        }

        $user->fill($request->all())->update();

        if (isset($request->profile_image) && $request->profile_image != null) {
            $user->clearMediaCollection('profile_image');
            $user->addMediaFromRequest('profile_image')->toMediaCollection('profile_image');
        }

        if($user->userDetail != null) {
            $user->userDetail->fill($request->userDetail)->update();
        } else {
            $user->userDetail()->create($request->userDetail);
        }

        if($user->userBankAccount != null) {
            $user->userBankAccount->fill($request->userBankAccount)->update();
        } else {
            $user->userBankAccount()->create($request->userBankAccount);
        }

        /*
        if($user->driverService()->count() > 0)
        {
            $user->driverService()->delete();
        }

        if($request->service_id != null) {
            foreach($request->service_id as $service) {
                $driver_services = [
                    'service_id'    => $service,
                    'driver_id'     => $user->id,
                ];
                $user->driverService()->insert($driver_services);
            }
        }
        */

        if(auth()->check()){
            return redirect()->route('driver.index')->withSuccess(__('message.update_form',['form' => __('message.driver')]));
        }
        return redirect()->back()->withSuccess(__('message.update_form',['form' => __('message.driver') ] ));
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
            return redirect()->route('driver.index')->withErrors($message);
        }
        $user = User::findOrFail($id);
        $status = 'errors';
        $message = __('message.not_found_entry', ['name' => __('message.driver')]);

        if($user!='') {
            $user->delete();
            $status = 'success';
            $message = __('message.delete_form', ['form' => __('message.driver')]);
        }

        if(request()->ajax()) {
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->back()->with($status,$message);
    }
    public function downloadDriverReport(Request $request, $fileType = 'xlsx')
    {
        $startDate = $request->input('from_date');
        $endDate   = $request->input('to_date');
        $driverId  = $request->input('driver_id');

        $start = $startDate ? Carbon::parse($startDate)->format('Y-m-d') : null;
        $end   = $endDate ? Carbon::parse($endDate)->format('Y-m-d') : null;

        $user_data = User::where('user_type', 'driver')
            ->with(['userDetail'])
            ->when($startDate, fn($q) => $q->whereDate('created_at', '>=', $startDate))
            ->when($endDate, fn($q) => $q->whereDate('created_at', '<=', $endDate))
            ->when($driverId, fn($q) => $q->where('id', $driverId))
            ->get();
        $export = new DriverReportExport($user_data, $request);
        $filenameDatePart = '';
        if ($start && $end) {
            $filenameDatePart = "_{$start}_to_{$end}";
        } elseif ($start) {
            $filenameDatePart = "_from_{$start}";
        } elseif ($end) {
            $filenameDatePart = "_to_{$end}";
        } else {
            $filenameDatePart = "_" . now()->format('Y-m-d');
        }

        $filename = "driver-report{$filenameDatePart}.{$fileType}";
        $format = match (strtolower($fileType)) {
            'csv'  => \Maatwebsite\Excel\Excel::CSV,
            'xls'  => \Maatwebsite\Excel\Excel::XLS,
            'ods'  => \Maatwebsite\Excel\Excel::ODS,
            'html' => \Maatwebsite\Excel\Excel::HTML,
            default => \Maatwebsite\Excel\Excel::XLSX,
        };

        return Excel::download($export, $filename, $format);
    }

    public function downloadDriverReportPdf(Request $request)
    {
        ini_set('max_execution_time', 0);
        ini_set('memory_limit', '-1');
        $startDate = $request->input('from_date');
        $endDate   = $request->input('to_date');
        $driverId  = $request->input('driver_id');
        $mode = $request->input('mode', 'fit');

        $start = $startDate ? Carbon::parse($startDate)->format('Y-m-d') : null;
        $end   = $endDate ? Carbon::parse($endDate)->format('Y-m-d') : null;

        $user_data = User::where('user_type', 'driver')
            ->with(['userDetail'])
            ->when($startDate, fn($q) => $q->whereDate('created_at', '>=', $startDate))
            ->when($endDate, fn($q) => $q->whereDate('created_at', '<=', $endDate))
            ->when($driverId, fn($q) => $q->where('id', $driverId))
            ->get();
        $export = new DriverReportExport($user_data, $request);
        $collection = $export->collection();
        $mappedData = $collection->map([$export, 'map'])->values();
        $headings   = $export->headings();
        $headers    = $headings[2] ?? $headings;
        $dateFilterText = '';
        $filenameDatePart = '';
        if ($startDate && $endDate) {
            $fromDateFormatted = Carbon::parse($startDate)->format('Y-m-d');
            $toDateFormatted   = Carbon::parse($endDate)->format('Y-m-d');
            $dateFilterText = 'From Date: '.$fromDateFormatted.' | To Date: '.$toDateFormatted;
            $filenameDatePart = '_from_'.$fromDateFormatted.'_to_'.$toDateFormatted;
        } elseif ($startDate) {
            $fromDateFormatted = Carbon::parse($startDate)->format('Y-m-d');
            $dateFilterText = 'From Date: '.$fromDateFormatted;
            $filenameDatePart = '_from_'.$fromDateFormatted;
        } elseif ($endDate) {
            $toDateFormatted = Carbon::parse($endDate)->format('Y-m-d');
            $dateFilterText = 'To Date: '.$toDateFormatted;
            $filenameDatePart = '_to_'.$toDateFormatted;
        }
        $renderTable = function(array $headers, array $rows, int $startCol = 0, ?int $endCol = null) {
            $end = $endCol ?? (count($headers) - 1);
            $html  = '<table class="report">';
            $html .= '<thead><tr>';
            for ($i = $startCol; $i <= $end; $i++) {
                $html .= '<th>'.e((string)$headers[$i]).'</th>';
            }
            $html .= '</tr></thead><tbody>';
            foreach ($rows as $row) {
                $html .= '<tr>';
                for ($i = $startCol; $i <= $end; $i++) {
                    $cell = $row[$i] ?? '';
                    $html .= '<td><div class="cell">'.e((string)$cell).'</div></td>';
                }
                $html .= '</tr>';
            }
            $html .= '</tbody></table>';
            return $html;
        };

        $styles = '
            <style>
                @page { margin: 16px; }
                body { font-family: DejaVu Sans, sans-serif; font-size: 9px; color: #111; }
                h1 { text-align: center; font-size: 18px; margin: 0 0 6px 0; }
                p.meta { text-align:center; font-size: 10px; margin: 0 0 10px 0; }
                .section-title { text-align:left; font-size: 11px; margin: 14px 0 6px; }
                table.report { width: 100%; border-collapse: collapse; table-layout: fixed; }
                table.report th, table.report td { border: 1px solid #bfbfbf; padding: 2px 4px; vertical-align: top; }
                table.report th { background: #f2f2f2; }
                .cell { overflow-wrap: anywhere; word-break: break-word; }
            </style>
        ';

        $html  = '<h1>Driver Report</h1>';
        if ($dateFilterText) {
            $html .= '<p class="meta"><strong>'.e($dateFilterText).'</strong></p>';
        }

        if ($mode === 'split') {
            $totalCols = count($headers);
            $splitAt   = min(9, $totalCols - 1);

            $html .= '<div class="section-title">Columns 1–'.($splitAt+1).'</div>';
            $html .= $renderTable($headers, $mappedData->toArray(), 0, $splitAt);

            $html .= '<div style="page-break-after: always;"></div>';

            if ($splitAt + 1 <= $totalCols - 1) {
                $html .= '<div class="section-title">Columns '.($splitAt+2).'–'.$totalCols.'</div>';
                $html .= $renderTable($headers, $mappedData->toArray(), $splitAt + 1, $totalCols - 1);
            }
        } else {
            $html .= $renderTable($headers, $mappedData->toArray(), 0, count($headers)-1);
        }

        $htmlContent = $styles.$html;
        $paperSize = ($mode === 'fit') ? 'a3' : 'a3';
        $orientation = 'landscape';

        $pdf = Pdf::loadHTML($htmlContent)->setPaper($paperSize, $orientation);

        $filename = 'driver-report'.$filenameDatePart.(($mode==='split') ? '_split' : '_fit').'.pdf';
        return $pdf->download($filename);
    }
    public function makeOffline($id)
    {
        try {
            $driver = User::findOrFail($id);

            $driver->update([
                'is_online' => 0
            ]);

            return back()->with('success', 'Driver is now offline successfully.');

        } catch (\Throwable $e) {
            \Log::error('Driver Offline Error: ' . $e->getMessage());
            return back()->with('error', 'Something went wrong.');
        }
    }

    public function action(Request $request)
    {
        $id = $request->id;
        $driver = User::withTrashed()->where('id',$id)->first();
        $message = __('message.not_found_entry',['name' => __('message.driver')] );
        if($request->type === 'restore'){
            $driver->restore();
            $message = __('message.msg_restored',['name' => __('message.driver')] );
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
                return redirect()->route('driver.index')->withErrors($message);
            }
            if ($driver) {
                $now = now();
                $driverId = $driver->id;
                $systemTime = $now->format('YmdHis');

                $driver->forceFill([
                    'first_name' => 'Deleted',
                    'last_name' => $driverId . ' Driver',
                    'display_name' => 'Deleted ' . $driverId . ' Driver',
                    'address' => null,
                    'email' => $systemTime . $driverId . '@deleted.com',
                    'contact_number' => $now->format('ymdHis') . $driverId,
                    'deleted_at' => null,
                    'status' => 'inactive',
                    'is_available' => 0,
                ])->save();

                $driver->userBankAccount()->delete();
                $message = __('message.update_form',['form' => __('message.driver')] );
            }
        }

        if(request()->is('api/*')){
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->route('driver.index')->withSuccess($message);
    }
}

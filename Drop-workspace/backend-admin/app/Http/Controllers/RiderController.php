<?php

namespace App\Http\Controllers;

use App\DataTables\CoinsWalletDataTable;
use App\Models\User;
use App\DataTables\RiderDataTable;
use App\Http\Requests\RiderRequest;
use App\DataTables\RideRequestDataTable;
use App\DataTables\RideRequestRatingDataTable;
use App\DataTables\WalletHistoryDataTable;
use App\DataTables\WithdrawRequestDataTable;
use App\Exports\RiderReportExport;
use Barryvdh\DomPDF\Facade\Pdf;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Kreait\Firebase\Exception\AuthException;
use Kreait\Firebase\Exception\FirebaseException;
use Kreait\Firebase\Factory;
use Maatwebsite\Excel\Facades\Excel;

class RiderController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index(RiderDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.rider')] );
        $auth_user = authSession();
        $assets = ['datatable'];
        $last_actived_at = request('last_actived_at') ?? null;
        $button = $auth_user->can('rider add') ? '<a href="'.route('rider.create').'" class="float-right btn btn-sm border-radius-10 btn-primary me-2"><i class="fa fa-plus-circle"></i> '.__('message.add_form_title',['form' => __('message.rider')]).'</a>' : '';

        return $dataTable->render('global.rider-datatable', compact('assets','pageTitle','button','auth_user','last_actived_at'));
    }

    /**
     * Show the form for creating a new resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function create()
    {
        $pageTitle = __('message.add_form_title',[ 'form' => __('message.rider')]);
        $assets = ['phone'];
        return view('rider.form', compact('pageTitle','assets'));
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(RiderRequest $request)
    {
        $data = $request->all();
        $data['status'] = 'active';
        $data['user_type'] = 'rider';
        $data['username'] = $request->username ?? stristr($request->email, "@", true) . rand(100, 1000);
        $data['password'] = Hash::make($request->password);
        $data['display_name'] = $data['first_name'] . " " . $data['last_name'];
        $data['last_actived_at'] = now();

        $user = User::create($data);
        $user->assignRole('rider');

        uploadMediaFile($user,$request->profile_image, 'profile_image');

        $factory = (new Factory)->withServiceAccount(base_path(env('FIREBASE_CREDENTIALS')));

        try {
            $auth = $factory->createAuth();

            $firebaseUser = $auth->createUser([
                'email' => $request->email,
                'password' => $request->password,
            ]);

            $firebaseUid = $firebaseUser->uid;

            $user->uid = $firebaseUid;
            $user->save();

            $collectionName = config('services.firestore.user_collection');
            $firebase = app('firebase.firestore');
            $collection = $firebase->database()->collection($collectionName);
            $document = $collection->document('user_' . $firebaseUid);

             $document->set([
                'uid'            => $firebaseUid,
                'username'       => $request->username,
                'first_name'     => $request['first_name'],
                'last_name'      => $request['last_name'],
                'display_name'   => $request['first_name'] . " " . $request['last_name'],
                'contact_number' => $request->contact_number,
                'email'          => $request->email,
                'user_type'      => 'rider',
                'created_at'     => now()->toDateTimeString(),
                'updated_at'     => now()->toDateTimeString(),
            ]);

        } catch (AuthException | FirebaseException $e) {
            return redirect()->back()->withErrors(['firebase' => 'Failed to register user in Firebase: ' . $e->getMessage()]);
        }

        // Auth::login($user);

        // $user->userBankAccount()->create($request->userBankAccount);
        return redirect()->route('rider.index')->withSuccess(__('message.save_form', ['form' => __('message.rider')]));


    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show(RideRequestDataTable $dataTable, WalletHistoryDataTable $walletHistoryDataTable, WithdrawRequestDataTable $WithdrawRequestDataTable, CoinsWalletDataTable $coinsWalletData, RideRequestRatingDataTable $rideRequestRatingDataTable, $id)
    {
        $pageTitle = __('message.view_form_title',[ 'form' => __('message.rider')]);
        $data = User::where('user_type', 'rider')->with('roles','userBankAccount')->findOrFail($id);
        $data->rating = $data->riderRating->where('rating', '>', 0)->avg('rating') ? (float) number_format($data->riderRating->where('rating', '>', 0)->avg('rating'), 2) : 0;

        $profileImage = getSingleMedia($data, 'profile_image');
        $currency_symbol = SettingData('CURRENCY', 'CURRENCY_SYMBOL') ?? '$';

        $type = request('type') ?? 'detail';
        switch ($type) {
            case 'detail':
                    return view('rider.show', compact('pageTitle', 'data', 'profileImage','type'));
                break;

            case 'wallet_history':
                    return $walletHistoryDataTable->with('user_id',$id)->render('rider.show', compact('pageTitle', 'data', 'type'));
                break;

            case 'ride_request':
                    return $dataTable->with('rider_id',$id)->render('rider.show', compact('pageTitle', 'data', 'type'));
                break;

            case 'withdraw_request':
                    return $WithdrawRequestDataTable->with('rider_id',$id)->render('rider.show', compact('pageTitle', 'data', 'type'));
                break;

            case 'coins_history':
                    return $coinsWalletData->with('rider_id',$id)->render('rider.show', compact('pageTitle', 'data', 'type', 'currency_symbol'));
                break;

            case 'rider_rating':
                    return $rideRequestRatingDataTable->with('rider_id',$id)->render('rider.show', compact('pageTitle', 'data', 'profileImage', 'type' ));
                break;

            default:
                # code...
                $type = 'detail';
                return view('rider.show', compact('pageTitle', 'data', 'profileImage','type'));
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
        $pageTitle = __('message.update_form_title',[ 'form' => __('message.rider')]);
        $data = User::where('user_type', 'rider')->with('userBankAccount')->findOrFail($id);

        $profileImage = getSingleMedia($data, 'profile_image');
        $assets = ['phone'];
        return view('rider.form', compact('data', 'pageTitle', 'id', 'profileImage', 'assets'));
    }

    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(RiderRequest $request, $id)
    {
        $user = User::findOrFail($id);

        $request['password'] = $request->password != '' ? bcrypt($request->password) : $user->password;

        $request['display_name'] = $request->first_name.' '. $request->last_name;
        // User user data...
        $user->fill($request->all())->update();

        // Save user image...
        if (isset($request->profile_image) && $request->profile_image != null) {
            $user->clearMediaCollection('profile_image');
            $user->addMediaFromRequest('profile_image')->toMediaCollection('profile_image');
        }

        if($user->userBankAccount != null) {
            $user->userBankAccount->fill($request->userBankAccount)->update();
        } else {
            $user->userBankAccount()->create($request->userBankAccount);
        }

        if(auth()->check()){
            return redirect()->route('rider.index')->withSuccess(__('message.update_form',['form' => __('message.rider')]));
        }
        return redirect()->back()->withSuccess(__('message.update_form',['form' => __('message.rider') ] ));
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
            return redirect()->route('rider.index')->withErrors($message);
        }
        $user = User::findOrFail($id);
        $status = 'errors';
        $message = __('message.not_found_entry', ['name' => __('message.rider')]);

            $collectionName = config('services.firestore.user_collection');
            if ($user && $user->uid) {
                try {
                    app('firebase.firestore')->database()->collection($collectionName)->document('user_' . $user->uid)->delete();
                } catch (\Exception $e) {
                    \Log::error("Failed to delete Firestore document for UID {$user->uid}: {$e->getMessage()}");
                }

                try {
                    app('firebase.auth')->deleteUser($user->uid);
                } catch (\Kreait\Firebase\Exception\Auth\UserNotFound $e) {
                    \Log::warning("Firebase user not found for UID: {$user->uid}");
                } catch (\Exception $e) {
                    \Log::error("Error deleting Firebase user: {$e->getMessage()}");
                    return redirect()->back()->withErrors(['firebase' => 'Failed to delete user from Firebase.']);
                }
            }

        if($user!='') {
            $user->delete();
            $status = 'success';
            $message = __('message.delete_form', ['form' => __('message.rider')]);
        }

        if(request()->ajax()) {
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->back()->with($status,$message);
    }

    public function downloadRiderReport(Request $request, $fileType = 'xlsx'){
        $startDate = $request->input('from_date');
        $endDate   = $request->input('to_date');
        $driverId  = $request->input('driver_id');

        $start = $startDate ? Carbon::parse($startDate)->format('Y-m-d') : null;
        $end   = $endDate ? Carbon::parse($endDate)->format('Y-m-d') : null;

        $user_data = User::where('user_type', 'rider')
            ->with(['userDetail'])
            ->when($startDate, fn($q) => $q->whereDate('created_at', '>=', $startDate))
            ->when($endDate, fn($q) => $q->whereDate('created_at', '<=', $endDate))
            ->when($driverId, fn($q) => $q->where('id', $driverId))
            ->get();
        $export = new RiderReportExport($user_data, $request);
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

        $filename = "rider-report{$filenameDatePart}.{$fileType}";

        $format = match (strtolower($fileType)) {
            'csv'  => \Maatwebsite\Excel\Excel::CSV,
            'xls'  => \Maatwebsite\Excel\Excel::XLS,
            'ods'  => \Maatwebsite\Excel\Excel::ODS,
            'html' => \Maatwebsite\Excel\Excel::HTML,
            default => \Maatwebsite\Excel\Excel::XLSX,
        };

        return Excel::download($export, $filename, $format);
    }

    public function downloadRiderReportPdf(Request $request)
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
        $export = new RiderReportExport($user_data, $request);
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

        $html  = '<h1>Rider Report</h1>';
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

        $filename = 'rider-report'.$filenameDatePart.(($mode==='split') ? '_split' : '_fit').'.pdf';
        return $pdf->download($filename);
    }

    public function action(Request $request)
    {
        $id = $request->id;
        $rider = User::withTrashed()->where('id',$id)->first();
        $message = __('message.not_found_entry',['name' => __('message.rider')] );
        if($request->type === 'restore'){
            $rider->restore();
            $message = __('message.msg_restored',['name' => __('message.rider')] );
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
                return redirect()->route('rider.index')->withErrors($message);
            }
            if ($rider) {
                $now = now();
                $riderId = $rider->id;
                $systemTime = $now->format('YmdHis');

                $rider->forceFill([
                    'first_name' => 'Deleted',
                    'last_name' => $riderId . ' Rider',
                    'display_name' => 'Deleted ' . $riderId . ' Rider',
                    'address' => null,
                    'email' => $systemTime . $riderId . '@deleted.com',
                    'username' => $systemTime . $riderId . '@deleted.com',
                    'contact_number' => $now->format('ymdHis') . $riderId,
                    'deleted_at' => null,
                    'status' => 'inactive',
                    'is_available' => 0,
                ])->save();

                $rider->userBankAccount()->delete();
                $message = __('message.update_form',['form' => __('message.rider')] );
            }
        }

        if(request()->is('api/*')){
            return response()->json(['status' => true, 'message' => $message ]);
        }

        return redirect()->route('rider.index')->withSuccess($message);
    }
}

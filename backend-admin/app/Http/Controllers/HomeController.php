<?php

namespace App\Http\Controllers;

use App\DataTables\ReferenceDataTable;
use Illuminate\Http\Request;
use App\Models\Service;
use App\Models\Document;
use App\Models\AppSetting;
use App\Models\User;
use App\Models\Complaint;
use App\Models\Payment;
use App\Models\PaymentGateway;
use App\Models\RideRequest;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use PhpMqtt\Client\Facades\MQTT;
use Illuminate\Support\Facades\App;
use App\Http\Resources\DriverResource;
use App\Http\Resources\NearByDriverResource;
use App\Mail\LoginAlertMail;
use App\Models\AdminLoginDevice;
use App\Models\AdminLoginHistory;
use App\Models\Airport;
use App\Models\CoinWallet;
use App\Models\DefaultKeyword;
use App\Models\LanguageDefaultList;
use App\Models\LanguageList;
use App\Models\Pages;
use App\Models\Region;
use App\Models\Screen;
use App\Models\Wallet;
use App\Models\WalletHistory;
use App\Models\ZonePrice;
use App\Providers\RouteServiceProvider;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Session;
use Jenssegers\Agent\Agent;
use Illuminate\Support\Str;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Mail;

class HomeController extends Controller
{
    /**
     * Create a new controller instance.
     *
     * @return void
     */
    public function __construct()
    {
        // $this->middleware('auth');
    }

    /*
     * Dashboard Pages Routs
     */
    public function index(Request $request)
    {
        $auth_user = auth()->user();

        $data['dashboard'] = [
            'pending_driver' => User::where('user_type', 'driver')->where('is_verified_driver', 0)->count(),
            'total_driver' => User::getUser('driver')->count(),
            'total_rider' => User::getUser('rider')->count(),
            'total_ride' => RideRequest::count(),
            'today_earning' => Payment::where('payment_status', 'paid')->whereDate('datetime', Carbon::today())->sum('total_amount'),
            'monthly_earning' => Payment::where('payment_status', 'paid')->whereMonth('datetime', Carbon::now()->month)->sum('total_amount'),
            'total_earning' => Payment::where('payment_status', 'paid')->sum('total_amount'),
            'complaint' => Complaint::where('status', 'pending')->count()
        ];

        $chart_data = [];

        $cash_payment = Payment::selectRaw('sum(total_amount) as total , DATE_FORMAT(datetime , "%m") as month')
            ->myPayment()
            ->where('payment_status', 'paid')
            ->where('payment_type', 'cash')
            ->whereYear('datetime', date('Y'))
            ->groupBy('month')
            ->get()->toArray();

        for ($i = 1; $i <= 12; $i++) {
            $paymentData = 0;
            foreach ($cash_payment as $payment) {
                if ((int) $payment['month'] == $i) {
                    $data['cash_yearly'][] = (int) $payment['total'];
                    $paymentData++;
                }
            }
            if ($paymentData == 0) {
                $data['cash_yearly'][] = 0;
            }
        }

        $wallet_payment = Payment::selectRaw('sum(total_amount) as total , DATE_FORMAT(datetime , "%m") as month')
            ->myPayment()
            ->where('payment_status', 'paid')
            ->where('payment_type', 'wallet')
            ->whereYear('datetime', date('Y'))
            ->groupBy('month')
            ->get()->toArray();
        for ($i = 1; $i <= 12; $i++) {
            $paymentData = 0;
            foreach ($wallet_payment as $payment) {
                if ((int) $payment['month'] == $i) {
                    $data['wallet_yearly'][] = (int) $payment['total'];
                    $paymentData++;
                }
            }
            if ($paymentData == 0) {
                $data['wallet_yearly'][] = 0;
            }
        }

        $recent_riderequest = RideRequest::myRide()->where('created_at', '<=', Carbon::now()->format('Y-m-d H:i:s'))->orderBy('id', 'desc')->take(10)->get();

        return view('dashboards.admin-dashboard', compact('data', 'auth_user', 'recent_riderequest'));
    }

    public function changeLanguage($locale)
    {
        App::setLocale($locale);
        session()->put('locale', $locale);
        return redirect()->back();
    }

    public function chartdata(Request $request)
    {
        $type = $request->type ?? 'daily';
        $series = [];
        if ($type == 'daily') {
            $series = [
                [
                    'name' => __('message.cash'),
                    'data' => 100,
                ],
                [
                    'name' => __('message.wallet'),
                    'data' => 1000,
                ],
            ];
        }

        if ($type == 'yearly') {
            $cash_payment = Payment::selectRaw('count(Date(datetime)) as total , DATE_FORMAT(datetime , "%m") as month')
                ->myPayment()
                ->where('payment_status', 'paid')
                ->where('payment_type', 'cash')
                ->whereYear('datetime', date('Y'))
                ->groupBy('month')
                ->get()->toArray();

            for ($i = 1; $i <= 12; $i++) {
                $paymentData = 0;

                foreach ($cash_payment as $payment) {
                    if ((int) $payment['month'] == $i) {
                        $data['list'][] = (int) $payment['total'];
                        $paymentData++;
                    }
                }

                if ($paymentData == 0) {
                    $data['list'][] = 0;
                }
            }
        }

        return $series;
    }
    /*
     * Auth pages Routs
     */

    function authLogin()
    {
        return view('auth.login');
    }


    public function verifyOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp'   => 'required|numeric'
        ]);

        $user = User::where('email', $request->email)->where('otp', $request->otp)->first();

        if ($user) {
            $user->otp = null;
            $user->save();

            // Authenticate user
            Auth::login($user);

            // Regenerate session ID after login for security
            $request->session()->regenerate();

            // Get session ID AFTER login and regeneration
            $sessionId = session()->getId();

            // Gather device and IP details
            $ip = request()->ip();
            $agent = new Agent();
            $client = new Client();
            $response = $client->get("https://ipinfo.io/{$ip}/json?token=f977119bb77e33");
            $ipDetails = json_decode($response->getBody(), true);

            $storeData = [
                'user_id' => $user->id,
                'ip_address' => $ip,
                'city' => $ipDetails['city'] ?? null,
                'region' => $ipDetails['region'] ?? null,
                'country' => ($countryDetails = $this->getCountryDetailsByCode($ipDetails['country'] ?? null))['countryNameEn'] ?? ($ipDetails['country'] ?? null),
                'lat_long' => $ipDetails['loc'] ?? null,
                'org' => isset($ipDetails['org']) ? Str::after($ipDetails['org'], ' ') : null,
                'postal_code' => $ipDetails['postal'] ?? null,
                'timezone' => $ipDetails['timezone'] ?? null,
                'browser' => $agent->browser(),
                'browser_version' => $agent->version($agent->browser()),
                'platform' => $agent->platform(),
                'platform_version' => $agent->version($agent->platform()),
                'device' => $agent->device(),
                'is_mobile' => (int) $agent->isMobile(),
                'is_desktop' => (int) $agent->isDesktop(),
                'is_tablet' => (int) $agent->isTablet(),
            ];

            AdminLoginHistory::create($storeData);

            $existingDevice = AdminLoginDevice::where('ip_address', $storeData['ip_address'])
                ->first();

            if ($existingDevice) {
                $existingDevice->update([
                    'session_id' => $sessionId,
                    'login_at'   => now(),
                    'is_active'  => true,
                    'logout_at'  => null,
                ]);
            } else {
                AdminLoginDevice::create([
                    'user_id'    => $user->id,
                    'ip_address' => $ip,
                    'user_agent' => $request->header('User-Agent'),
                    'session_id' => $sessionId,
                    'login_at'   => now(),
                    'is_active'  => true,
                ]);
            }

            app()->terminating(function () use ($user, $storeData) {
                try {
                    Mail::to($user->email)->send(new LoginAlertMail($storeData));
                } catch (\Exception $e) {
                    \Log::error("Login alert send failed, Error: {$e->getMessage()}");
                }
            });

            return redirect()->route('home');
        }

        return redirect()->route('auth.otp-form', ['email' => $request->email])->withErrors(['otp' => __('auth.otp')]);
    }

    public function verifyOTP_post(Request $request)
    {
        $user = User::where('email', $request->email)->first();

        if (!$user || empty($request->otp) || $request->otp != $user->otp || Carbon::now()->gt($user->otp_expires_at)) {
            return redirect()->back()->withErrors(__('message.otp_expired'));
        }

        // OTP is valid — login user
        Auth::login($user);
        $request->session()->regenerate();

        $auth_user = auth()->user();
        $auth_user->last_actived_at = now();
        $auth_user->save();
        return redirect(RouteServiceProvider::HOME);
    }
    public function showOtpForm(Request $request)
    {
        $email = session('email') ?? $request->get('email');
        if (!$email) {
            return redirect()->route('auth.login')->withErrors(['email' => __('message.session_expired')]);
        }

        return view('auth.otp_form', compact('email'));
    }

    function authRegister()
    {
        $assets = ['phone'];
        return view('auth.register', compact('assets'));
    }

    function authRecoverPassword()
    {
        return view('auth.forgot-password');
    }

    function authConfirmEmail()
    {
        return view('auth.verify-email');
    }

    function authLockScreen()
    {
        return view();
    }

    public function changeStatus(Request $request)
    {
        if (env('APP_DEMO')) {
            $message = __('message.demo_permission_denied');
            $response = [
                'status' => false,
                'message' => $message
            ];
            return json_custom_response($response);
        }

        $type = $request->type;
        $message_form = "";
        $message = __('message.update_form', ['form' => __('message.status')]);
        switch ($type) {
            case 'role':
                $role = \App\Models\Role::find($request->id);
                $role->status = $request->status;
                $role->save();
                break;
            case 'service_status':
                $service = \App\Models\Service::find($request->id);
                $service->status = $request->status;
                $service->save();
                break;
            case 'coupon_status':
                $coupon = \App\Models\Coupon::find($request->id);
                $coupon->status = $request->status;
                $coupon->save();
                break;
            case 'document_status':
                $document = Document::find($request->id);
                $document->status = $request->status;
                $document->save();
                break;
            case 'document_required':
                $message_form = __('message.required');
                $document = Document::find($request->id);
                $document->is_required = $request->status;
                $document->save();
                break;
            case 'document_has_expiry_date':
                $message_form = __('message.expire_date');
                $document = Document::find($request->id);
                $document->has_expiry_date = $request->status;
                $document->save();
                break;
            case 'driver_is_verified':
                $message_form = __('message.driverdocument');
                $document = \App\Models\DriverDocument::find($request->id);
                $document->is_verified = $request->status;
                $document->save();
                break;
            case 'pages':
                $user = Pages::find($request->id);
                $status = $request->status == 0 ? '0' : '1';
                $user->status = $status;
                $user->save();
                break;
            default:
                $message = 'error';
                break;
        }

        if ($message_form != null) {
            $message = __('message.added_form', ['form' => $message_form]);
            if ($request->status == 0) {
                $message = __('message.remove_form', ['form' => $message_form]);
            }
        }

        return json_custom_response(['message' => $message, 'status' => true]);
    }

    public function getAjaxList(Request $request)
    {
        $items = array();
        $value = $request->q;
        $auth_user = authSession();

        $checked_ids = $request->datatable_checked_ids;
        switch ($request->type) {
            case 'permission':
                $items = \App\Models\Permission::select('id', 'name as text')->whereNull('parent_id');
                if ($value != '') {
                    $items->where('name', 'LIKE', $value . '%');
                }
                $items = $items->get();
                break;
            case 'fleet_driver':
                if ($auth_user->hasRole('admin')) {
                    $user_type = ['driver', 'fleet'];
                } else {
                    $user_type = $auth_user->user_type;
                }
                $items = User::select('id', 'display_name as text')
                    ->whereIn('user_type', $user_type)
                    ->where('status', 'active');

                if ($value != '') {
                    $items->where('display_name', 'LIKE', $value . '%');
                }

                $items = $items->get();
                break;
            case 'rider':
                $items = \App\Models\User::select('id', 'display_name as text')
                    ->where('user_type', 'rider')
                    ->whereNotIn('first_name', ['Anonymized', 'Deleted'])
                    ->where('status', 'active');

                if ($value != '') {
                    $items->where('display_name', 'LIKE', $value . '%');
                }

                $items = $items->get();
                break;
            case 'fleet':
                $items = \App\Models\User::select('id', 'display_name as text')
                    ->where('user_type', 'fleet')
                    ->where('status', 'active');

                if ($value != '') {
                    $items->where('display_name', 'LIKE', $value . '%');
                }

                $items = $items->get();
                break;
            case 'ongoing_driver':
                $items = \App\Models\User::select('id', 'display_name as text')
                    ->where('user_type', 'driver')
                    ->where('status', 'active')
                    ->whereIn('id', function ($query) {
                        $query->select('driver_id')
                            ->from('ride_requests')
                            ->whereNotIn('status', ['canceled', 'completed']);
                    });

                if (isset($request->fleet_id)) {
                    $items->where('fleet_id', $request->fleet_id);
                }

                if (isset($request->status)) {
                    $items->where('status', $request->status); // if status is passed, override the default 'active'
                }

                if ($value != '') {
                    $items->where('display_name', 'LIKE', $value . '%');
                }

                $items = $items->get();
                break;

            case 'driver':
                $items = \App\Models\User::select('id', 'display_name as text')
                    ->where('user_type', 'driver');


                if (isset($request->fleet_id)) {
                    $items->where('fleet_id', $request->fleet_id);
                }

                if (isset($request->status)) {
                    $items->where('status', $request->status);
                } else {
                    $items->where('status', 'active');
                }

                if ($value != '') {
                    $items->where('display_name', 'LIKE', $value . '%');
                }

                $items = $items->get();
                break;


            case 'region':
                $items = \App\Models\Region::select('id', 'name as text', 'distance_unit')->where('status', 1);
                if ($value != '') {
                    $items->where('name', 'LIKE', '%' . $value . '%');
                }

                $items = $items->get();

                break;
            case 'service':
                $items = \App\Models\Service::select('id', 'name as text')->where('status', 1);

                if ($value != '') {
                    $items->where('name', 'LIKE', '%' . $value . '%');
                }

                $items = $items->get();
                break;
            case 'coupon':
                $items = \App\Models\Coupon::select('id', 'code as text')->where('status', 1);

                if ($value != '') {
                    $items->where('code', 'LIKE', '%' . $value . '%');
                }

                $items = $items->get();
                break;

            case 'document':
                $items = Document::select('id', 'name', 'status', 'is_required', 'has_expiry_date', DB::raw('(CASE WHEN is_required = 1 THEN CONCAT(name," * ") ELSE CONCAT(name,"") END) AS text'))->where('status', 1);
                if ($value != '') {
                    $items->where('name', 'LIKE', $value . '%');
                }
                $items = $items->get();
                break;
            case 'riderequest':
                $id = __('message.ride_request_id');

                $items = \App\Models\RideRequest::select('id', DB::raw("CONCAT('#',id) as text"), 'rider_id', 'driver_id')->with(['rider', 'driver']);
                if ($value != '') {
                    $items->where('id', 'LIKE', $value . '%');
                }
                $items = $items->get();
                break;
            case 'timezone':
                $items = timeZoneList();
                foreach ($items as $k => $v) {
                    if ($value != '') {
                        if (strpos($v, $value) !== false) {

                        } else {
                            unset($items[$k]);
                        }
                    }
                }
                $data = [];
                $i = 0;
                foreach ($items as $key => $row) {
                    $data[$i] = [
                        'id' => $key,
                        'text' => $row,
                    ];
                    $i++;
                }
                $items = $data;
                break;
            case 'transaction_type':
                if (request('type_val') != null && request('type_val') == 'debit') {

                    if (request('user_type') == 'rider') {
                        $items = [
                            ['id' => 'ride_fee', 'text' => __('message.ride_fee')],
                        ];
                    } else {
                        $items = [
                            ['id' => 'correction', 'text' => __('message.correction')],
                        ];
                    }
                } else {
                    if (request('user_type') == 'rider') {
                        $items = [
                            ['id' => 'topup', 'text' => __('message.topup')],
                        ];
                    } else {
                        $items = [
                            ['id' => 'topup', 'text' => __('message.topup')],
                            ['id' => 'ride_fee', 'text' => __('message.ride_fee')],
                        ];
                    }
                }
                # code...
                break;

            case 'service_for_ride':
                $items = Service::select('id', 'name as text')->where('status', 1);
                $latitude = (float) $request->latitude;
                $longitude = (float) $request->longitude;

                $regionIds = Region::where('status', 1)
                    ->get()
                    ->filter(function ($region) use ($latitude, $longitude) {
                        $coordinates = is_string($region->coordinates) ? json_decode($region->coordinates, true) : $region->coordinates;
                        return is_array($coordinates) && pointInPolygon([$latitude, $longitude], $coordinates);
                    })
                    ->pluck('id');

                $items->whereIn('region_id', $regionIds);
                $items = $items->get();
                break;
            case 'driver_for_ride':
                $latitude = $request->latitude;
                $longitude = $request->longitude;

                $service = Service::find($request->service_id);

                $distance_unit = optional($service->region)->distance_unit ?? 'km';
                $unit_value = convertUnitvalue($distance_unit);

                $radius = SettingData('DISTANCE', 'DISTANCE_RADIUS') ?? 50;
                $minumum_amount_get_ride = SettingData('wallet', 'min_amount_to_get_ride') ?? null;

                $items = User::selectRaw("id, display_name as text, status, is_online, is_available, last_location_update_at, user_type, latitude, longitude, ( $unit_value * acos( cos( radians($latitude) ) * cos( radians( latitude ) ) * cos( radians( longitude ) - radians($longitude) ) + sin( radians($latitude) ) * sin( radians( latitude ) ) ) ) AS distance")->where('user_type', 'driver')->where('status', 'active')
                    ->whereNotNull('latitude')->whereNotNull('longitude')
                    ->having('distance', '<=', $radius)
                    ->where('service_id', $request->service_id)
                    ->where('is_online', 1)
                    ->where('is_available', 1)
                    ->whereNotIn('first_name', ['Anonymized', 'Deleted'])
                    ->orderBy('distance', 'asc');
                if ($minumum_amount_get_ride != null) {
                    $items = $items->whereHas('userWallet', function ($q) use ($minumum_amount_get_ride) {
                        $q->where('total_amount', '>=', $minumum_amount_get_ride);
                    });
                }

                $items = $items->get();
                break;

            case 'screen':
                $items = Screen::select('screenId', 'screenName as text');
                if ($value != '') {
                    $items->where('screenName', 'LIKE', '%' . $value . '%');
                }
                $items = $items->get()->map(function ($screen_id) {
                    return ['id' => $screen_id->screenId, 'text' => $screen_id->text];
                });
                $items = $items;
                break;
            case 'language-list-data':
                $languageId = $request->id;
                $items = LanguageDefaultList::where('id', $languageId);
                $items = $items->first();
                break;
            case 'languagelist':
                $data = LanguageList::pluck('language_id')->toArray();
                $items = LanguageDefaultList::whereNotIn('id', $data)->select('id', 'languageName as text');
                if ($value != '') {
                    $items->where('languageName', 'LIKE', '%' . $value . '%');
                }
                $items = $items->get();
                break;
            case 'defaultkeyword':
                $items = DefaultKeyword::select('id', 'keyword_name as text');
                if ($value != '') {
                    $items->where('keyword_name', 'LIKE', '%' . $value . '%');
                }
                $items = $items->get();
                break;
            case 'languagewithkeyword-defaultkeyword':
                $items = DefaultKeyword::select('keyword_id as id', 'keyword_name as text');
                if ($value != '') {
                    $items->where('keyword_name', 'LIKE', '%' . $value . '%');
                }
                $items = $items->get();
                break;
            case 'languagetable':
                $items = LanguageList::select('id', 'language_name as text')->where('status', 1);
                if ($value != '') {
                    $items->where('language_name', 'LIKE', '%' . $value . '%');
                }
                $items = $items->get();
                break;

            case 'language-list-checked':
                if (env('APP_DEMO')) {
                    $message = __('message.demo_permission_denied');
                    if (request()->ajax()) {
                        return response()->json(['status' => false, 'message' => $message, 'event' => 'validation']);
                    }
                }
                $data = LanguageList::destroy($checked_ids);
                $message = __('message.delete_form', ['form' => __('message.language')]);
                updateLanguageVersion();
                break;

            case 'service_ids':
                $items = Service::select('id','name as text')->where('status',1);
                if($value != ''){
                    $items->where('name', 'LIKE', '%'.$value.'%');
                }
                $items = $items->get();

            break;
            case 'dispatch-first-rider':
                $rider = User::when(request('rider_id'), function ($query, $rider_id) { return $query->where('id', $rider_id);}, function ($query) {return $query->where('contact_number', request('contact_number'));})->first();
                $items = [
                    'status' => isset($rider) ? true : false,
                    'first_name' => $rider->first_name ?? '',
                    'last_name' => $rider->last_name ?? '',
                    'contact_number' => $rider->contact_number ?? '',
                    'email' => $rider->email ?? ''
                ];
            break;
            case 'airport':
                $page = $request->get('page', 1);
                $perPage = 50;
                $offset = ($page - 1) * $perPage;

                $query = Airport::select('id', 'name as text', 'latitude_deg', 'longitude_deg');

                if ($value) {
                    $query->where('name', 'LIKE', '%' . $value . '%');
                }

                $total = $query->count();
                $airports = $query->offset($offset)->limit($perPage)->get();

                $items = $airports->map(function($airport) {
                    return [
                        'id' => $airport->id,
                        'text' => $airport->text,
                        'lat' => $airport->latitude_deg,
                        'lng' => $airport->longitude_deg,
                    ];
                });

                return response()->json([
                    'results' => $items,
                    'pagination' => [
                        'more' => ($offset + $perPage) < $total
                    ]
                ]);
            break;

            default:
                break;
        }
        return response()->json(['status' => true, 'results' => $items]);
    }

    public function removeFile(Request $request)
    {
        $type = $request->type;
        $data = null;

        if (env('APP_DEMO')) {
            $message = __('message.demo_permission_denied');
            if (request()->ajax()) {
                return response()->json(['status' => true, 'message' => $message]);
            }
        }
        switch ($type) {
            case 'service_image':
                $data = Service::find($request->id);
                $message = __('message.msg_removed', ['name' => __('message.service')]);
                break;

            case 'gateway_image':
                $data = PaymentGateway::find($request->id);
                $message = __('message.msg_removed', ['name' => __('message.paymentgateway')]);
                break;

            case 'language_image':
                $data = LanguageList::find($request->id);
                $message = __('message.msg_removed', ['name' => __('message.slider')]);
                break;
            case 'service_marker':
                $data = Service::find($request->id);
                $message = __('message.msg_removed', ['name' => __('message.service')]);
                break;
            // case 'attachment':
            //     $media = Media::find($request->id);
            //     $media->delete();
            //     $message = __('message.msg_removed',[ 'name' => __('message.attachments')]);
            // break;

            default:
                $data = AppSetting::find($request->id);
                $message = __('message.msg_removed', ['name' => __('message.image')]);
                break;
        }

        if ($data != null) {
            $data->clearMediaCollection($type);
        }

        $response = [
            'status' => true,
            'id' => $request->id,
            'image' => getSingleMedia($data, $type),
            'preview' => $type . "_preview",
            'message' => $message
        ];
        return json_custom_response($response);
    }

    public function destroySelected(Request $request)
    {

        $checked_ids = $request->datatable_checked_ids;
        $types = $request->datatable_button_title;
        $data = null;

        switch ($types) {
            case 'language-list-checked':
                if (env('APP_DEMO')) {
                    $message = __('message.demo_permission_denied');
                    if (request()->ajax()) {
                        return response()->json(['status' => false, 'message' => $message, 'event' => 'validation']);
                    }
                }
                $data = LanguageList::destroy($checked_ids);
                $message = __('message.delete_form', ['form' => __('message.language')]);
                updateLanguageVersion();
                break;
            case 'airport-checked':
                foreach ($checked_ids as $id) {
                    $airport = Airport::where('id', $id)->first();
                    if ($airport) {
                        if (env('APP_DEMO')) {
                            $message = __('message.demo_permission_denied');
                            if (request()->ajax()) {
                                return response()->json(['status' => false,'message' => $message, 'event' => 'validation' ]);
                            }
                        }
                        if ($airport->deleted_at != null) {
                            $airport->forceDelete();
                        } else {
                            $airport->delete();
                        }
                    }
                    $message = __('message.delete_form', ['form' => __('message.airport')]);
                }
            break;
            default:
                $message = false;
                break;
        }
        $response = [
            'success' => true,
            'message' => $message
        ];
        return json_custom_response($response);
    }

    public function map()
    {
        $pageTitle = __('message.driver_location');
        $assets = ['map'];
        return view('map.index', compact('pageTitle', 'assets'));
    }
    public function liveTracking(Request $request)
    {
        $liveTracking = [
            'summaryCards' => collect(),
            'rideItems' => collect(),
            'selectedRide' => null,
            'rideOptions' => $this->getAdminLiveTrackingRideOptions(),
        ];
        $assets = ['map'];

        return view('map.live-tracking', compact('liveTracking', 'assets'));
    }

    public function realTimeDashboard(Request $request)
    {
        $statusConfig = [
            'new_ride_requested' => ['label' => 'New Request', 'color' => 'primary'],
            'accepted' => ['label' => 'Dispatched', 'color' => 'info'],
            'arriving' => ['label' => 'Arriving', 'color' => 'arriving'],
            'arrived' => ['label' => 'Arrived', 'color' => 'warning'],
            'in_progress' => ['label' => 'In Progress', 'color' => 'primary'],
            'completed' => ['label' => 'Completed', 'color' => 'success'],
            'canceled' => ['label' => 'Canceled', 'color' => 'danger'],
        ];
        $statusKeys = array_keys($statusConfig);
        $userRelations = [
            'rider:id,display_name,contact_number',
            'driver:id,display_name,contact_number',
        ];

        $rideRequestsData = RideRequest::myRide()->select('id', 'rider_id', 'driver_id', 'service_id', 'status', 'start_latitude', 'start_longitude', 'start_address', 'end_address', 'total_amount', 'created_at')->whereDate('created_at', Carbon::today())->orderByDesc('id')->get();
        $rideRequestsData->load(array_merge($userRelations, ['service:id,name']));

        $statusCounts = $rideRequestsData->whereIn('status', $statusKeys)->countBy('status')->toArray();

        $userData = function ($rideRequest) {
            return [
                'rider_name' => optional($rideRequest->rider)->display_name ?? '-',
                'driver_name' => optional($rideRequest->driver)->display_name ?? '-',
            ];
        };

        $statusCard = function ($status) use ($statusCounts, $statusConfig) {
            return [
                'label_key' => $status,
                'count' => (int) ($statusCounts[$status] ?? 0),
                'color' => $statusConfig[$status]['color'],
            ];
        };

        $dashboardCards = collect([
            ['label_key' => 'drivers', 'count' => User::where('user_type', 'driver')->where('is_online', 1)->count(), 'color' => 'secondary'],
            ['label_key' => 'today_jobs', 'count' => $rideRequestsData->count(), 'color' => 'secondary'],
            $statusCard('new_ride_requested'),
            $statusCard('accepted'),
            $statusCard('arriving'),
            $statusCard('arrived'),
            $statusCard('in_progress'),
            $statusCard('completed'),
            $statusCard('canceled'),
        ])->values();

        $rideRequests = $rideRequestsData
            ->whereIn('status', $statusKeys)
            ->filter(fn($rideRequest) => !is_null($rideRequest->start_latitude) && !is_null($rideRequest->start_longitude))
            ->values()
            ->map(function ($rideRequest) use ($statusConfig, $userData) {
            return array_merge([
                'id' => $rideRequest->id,
                'status' => $rideRequest->status,
                'status_label' => __('message.' . $rideRequest->status),
                'color' => $statusConfig[$rideRequest->status]['color'] ?? 'secondary',
                'latitude' => (float) $rideRequest->start_latitude,
                'longitude' => (float) $rideRequest->start_longitude,
                'address' => $rideRequest->start_address,
            ], $userData($rideRequest));
        });

        $rideRequestTable = $rideRequestsData->map(function ($rideRequest) use ($statusConfig, $userData) {
            return array_merge([
                'id' => $rideRequest->id,
                'client_number' => optional($rideRequest->rider)->contact_number ?? '-',
                'service_name' => optional($rideRequest->service)->name ?? '-',
                'pickup_address' => $rideRequest->start_address ?? '-',
                'drop_address' => $rideRequest->end_address ?? '-',
                'status' => $rideRequest->status,
                'status_label' => __('message.' . $rideRequest->status),
                'status_color' => $statusConfig[$rideRequest->status]['color'] ?? 'primary',
                'total_amount' => getPriceFormat($rideRequest->total_amount ?? 0),
                'created_at' => formatTimeOnly($rideRequest->created_at),
            ], $userData($rideRequest));
        });

        $dashboardData = compact('rideRequests', 'dashboardCards', 'rideRequestTable');

        if ($request->routeIs('realtime.dashboard.data') || $request->expectsJson() || $request->ajax()) {
            return response()->json($dashboardData);
        }

        return view('map.realtimedashboard', array_merge(['assets' => ['map']], $dashboardData));
    }

    public function adminLiveTrackingData(Request $request)
    {
        return response()->json($this->buildAdminLiveTrackingData($request));
    }

    public function buildAdminLiveTrackingData(Request $request)
    {
        $activeStatuses = ['accepted', 'arriving', 'arrived', 'in_progress'];
        $rideOptions = $this->getAdminLiveTrackingRideOptions($activeStatuses);
        $statusConfig = [
            'accepted' => ['label' => 'Accepted', 'color' => 'info'],
            'arriving' => ['label' => 'Arriving', 'color' => 'arriving'],
            'arrived' => ['label' => 'Arrived', 'color' => 'warning'],
            'in_progress' => ['label' => 'In Progress', 'color' => 'primary'],
        ];
        $defaultRideId = $request->input('ride_id');

        if (!$defaultRideId) {
            return [
                'summaryCards' => collect(),
                'rideItems' => collect(),
                'selectedRide' => null,
                'rideOptions' => $rideOptions,
            ];
        }

        $rides = RideRequest::myRide()
            ->with([
                'rider:id,display_name,contact_number',
                'service:id,name',
            ])
            ->whereIn('status', $activeStatuses)
            ->whereNotNull('driver_id')
            ->whereNotNull('start_latitude')
            ->whereNotNull('start_longitude')
            ->where('id', $defaultRideId)
            ->orderByDesc('updated_at')
            ->get();

        $driverIds = $rides->pluck('driver_id')->filter()->unique()->values();
        $driversById = User::query()
            ->select('id', 'display_name', 'contact_number', 'latitude', 'longitude', 'last_location_update_at', 'currentHeading')
            ->whereIn('id', $driverIds)
            ->get()
            ->keyBy('id');

        $rideItems = $rides->map(function ($rideRequest) use ($statusConfig, $driversById) {
            $driver = $driversById->get($rideRequest->driver_id);
            $targetIsDrop = $rideRequest->status === 'in_progress';
            $targetLatitude = $targetIsDrop ? $rideRequest->end_latitude : $rideRequest->start_latitude;
            $targetLongitude = $targetIsDrop ? $rideRequest->end_longitude : $rideRequest->start_longitude;

            return [
                'id' => $rideRequest->id,
                'status' => $rideRequest->status,
                'status_label' => __('message.' . $rideRequest->status),
                'status_color' => $statusConfig[$rideRequest->status]['color'] ?? 'secondary',
                'driver_id' => $rideRequest->driver_id,
                'driver_name' => $driver->display_name ?? '-',
                'driver_number' => $driver->contact_number ?? '-',
                'driver_latitude' => $driver->latitude ?? null,
                'driver_longitude' => $driver->longitude ?? null,
                'driver_heading' => $driver->currentHeading ?? null,
                'driver_last_update' => $driver->last_location_update_at ? dateAgoFormate($driver->last_location_update_at, true) : '-',
                'rider_name' => optional($rideRequest->rider)->display_name ?? '-',
                'service_name' => optional($rideRequest->service)->name ?? '-',
                'pickup_address' => $rideRequest->start_address ?? '-',
                'drop_address' => $rideRequest->end_address ?? '-',
                'pickup_latitude' => $rideRequest->start_latitude,
                'pickup_longitude' => $rideRequest->start_longitude,
                'drop_latitude' => $rideRequest->end_latitude,
                'drop_longitude' => $rideRequest->end_longitude,
                'target_latitude' => $targetLatitude,
                'target_longitude' => $targetLongitude,
                'target_label' => $targetIsDrop ? __('message.drop_address') : __('message.pickup_address'),
                'target_type' => $targetIsDrop ? 'drop' : 'pickup',
                'created_at' => formatTimeOnly($rideRequest->created_at),
                'updated_at' => formatTimeOnly($rideRequest->updated_at),
            ];
        })->values();

        $selectedRide = null;
        if ($defaultRideId) {
            $selectedRide = $rideItems->firstWhere('id', (int) $defaultRideId);
        }
        if (!$selectedRide) {
            $selectedRide = $rideItems->first();
        }

        $summaryCards = collect([
            [
                'label_key' => 'active_rides',
                'count' => $rideItems->count(),
                'color' => 'primary',
            ],
            [
                'label_key' => 'accepted',
                'count' => $rideItems->where('status', 'accepted')->count(),
                'color' => 'info',
            ],
            [
                'label_key' => 'arriving',
                'count' => $rideItems->where('status', 'arriving')->count(),
                'color' => 'arriving',
            ],
            [
                'label_key' => 'arrived',
                'count' => $rideItems->where('status', 'arrived')->count(),
                'color' => 'warning',
            ],
            [
                'label_key' => 'in_progress',
                'count' => $rideItems->where('status', 'in_progress')->count(),
                'color' => 'success',
            ],
        ])->values();

        return [
            'summaryCards' => $summaryCards,
            'rideItems' => $rideItems,
            'selectedRide' => $selectedRide,
            'rideOptions' => $rideOptions,
        ];
    }

    public function getAdminLiveTrackingRideOptions($activeStatuses = ['accepted', 'arriving', 'arrived', 'in_progress'])
    {
        return RideRequest::myRide()
            ->select('id')
            ->whereIn('status', $activeStatuses)
            ->whereNotNull('driver_id')
            ->whereNotNull('start_latitude')
            ->whereNotNull('start_longitude')
            ->orderByDesc('updated_at')
            ->get()
            ->map(function ($rideRequest) {
                return [
                    'id' => $rideRequest->id,
                ];
            })
            ->values();
    }

    public function driverDetail(Request $request)
    {
        $driver = User::findOrFail($request->id);
        $response = new DriverResource($driver);
        return $response;
    }
    public function search($id)
    {
        $driver = User::find($id);

        if ($driver) {
            return response()->json(['data' => $driver]);
        } else {
            return response()->json(['message' => 'Driver not found'], 404);
        }
    }

    public function driverListMap(Request $request)
    {
        $driver_list = User::where('user_type', 'driver')->where('status', 'active')->whereNotNull('latitude')->whereNotNull('longitude');

        if ($request->filled('service_id')) {
            $driver_list->where('service_id', $request->service_id);
        }

        if ($request->filled('driver_status')) {
            switch ($request->driver_status) {
                case 'online':
                    $driver_list->where('is_online', 1)->where('is_available', 1);
                    break;
                case 'in_service':
                    $driver_list->where('is_online', 1)->where('is_available', 0);
                    break;
                case 'offline':
                    $driver_list->where('is_online', 0);
                    break;
            }
        }

        if ($request->has('latitude') && isset($request->latitude) && $request->has('longitude') && isset($request->longitude)) {
            $latitude = $request->latitude;
            $longitude = $request->longitude;

            $unit_value = convertUnitvalue('km');

            $radius = SettingData('DISTANCE', 'DISTANCE_RADIUS') ?? 50;
            $driver_list->selectRaw("id, first_name, last_name, display_name, status, is_online, is_available, last_location_update_at, user_type, currentHeading, latitude, longitude, ( $unit_value * acos( cos( radians($latitude) ) * cos( radians( latitude ) ) * cos( radians( longitude ) - radians($longitude) ) + sin( radians($latitude) ) * sin( radians( latitude ) ) ) ) AS distance ,service_id")
                ->having('distance', '<=', $radius)
                ->orderBy('distance', 'asc');

            if (!$request->filled('driver_status')) {
                $driver_list->where('is_online', 1)->where('is_available', 1);
            }
        }
        $driver_list = $driver_list->get();

        $response = [
            'data' => NearByDriverResource::collection($driver_list),
            'message' => 'driver list',
        ];
        return json_custom_response($response);
    }

    public function saveWalletHistory(Request $request, $user_id)
    {
        $data = $request->all();

        $wallet = Wallet::firstOrCreate(
            ['user_id' => $user_id]
        );

        if ($data['type'] == 'credit') {
            $total_amount = $wallet->total_amount + $data['amount'];
        }

        if ($data['type'] == 'debit') {
            if ($data['amount'] > $wallet->total_amount) {
                return redirect()->back()->withErrors([
                    'amount' => __('message.debit_amount', [
                        'amount' => $wallet->total_amount
                    ])
                ])->withInput();
            }

            $total_amount = $wallet->total_amount - $data['amount'];
        }
        $currency_code = SettingData('CURRENCY', 'CURRENCY_CODE') ?? 'USD';
        $wallet->currency = strtolower($currency_code);

        $wallet->total_amount = $total_amount;

        try {
            DB::beginTransaction();
            $wallet->save();
            $data['user_id'] = $wallet->user_id;
            $data['balance'] = $total_amount;
            $data['datetime'] = date('Y-m-d H:i:s');
            $result = WalletHistory::create($data);
            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            return $e;
        }
        return redirect()->back()->withSuccess(__('message.transaction_submitted'));
    }

    // publish topic
    public function SendMsgViaMqtt($topic, $message)
    {
        MQTT::publish($topic, $message);
    }

    // subscribe topic
    public function SubscribetoTopic($topic)
    {
        $mqtt = MQTT::connection();
        $mqtt->subscribe($topic, function ($topic, $message) {
            echo sprintf("Received message on topic [%s]: %s\n", $topic, $message);
        }, 0);
    }

    public function demandMap(Request $request)
    {
        $pageTitle = __('message.high_demand_areas');
        $assets = ['map'];
        return view('map.high-demand-areas', compact('pageTitle', 'assets'));
    }

    public function demandZoneList(Request $request)
    {
        $today = Carbon::today();

        // Get today's new ride requests
        $rides = RideRequest::query()
            ->with(['rider:id,first_name,last_name', 'driver:id,first_name,last_name'])
            ->whereDate('created_at', $today)
            ->where('status', 'new_ride_requested')
            ->whereNotNull('start_latitude')
            ->whereNotNull('start_longitude')
            ->get();

        // Fetch all available drivers
        $drivers = User::query()
            ->where('user_type', 'driver')
            ->where('is_online', 1)
            ->where('is_available', 1)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->get();
        $zones = [];

        foreach ($rides as $ride) {
            $lat = $ride->start_latitude;
            $lng = $ride->start_longitude;

            $foundZone = false;

            foreach ($zones as &$zone) {
                $distance = haversineDistance($lat, $lng, $zone['lat'], $zone['lng']);
                if ($distance <= 5) {
                    $zone['rides'][] = $ride;
                    $foundZone = true;
                    break;
                }
            }

            if (!$foundZone) {
                $zones[] = [
                    'lat' => $lat,
                    'lng' => $lng,
                    'rides' => [$ride]
                ];
            }
        }

        $finalZones = [];

        foreach ($zones as $zone) {
            $totalRides = count($zone['rides']);

            $availableDrivers = $drivers->filter(function ($driver) use ($zone) {
                return haversineDistance($zone['lat'], $zone['lng'], $driver->latitude, $driver->longitude) <= 5;
            })->count();

            $status = 'red';
            if ($availableDrivers >= $totalRides) {
                $status = 'green';
            } elseif ($availableDrivers > 0) {
                $status = 'orange';
            }

            $rideDetails = collect($zone['rides'])->map(function ($r) {
                return [
                    'rider_name' => trim(optional($r->rider)->first_name . ' ' . optional($r->rider)->last_name) ?: 'N/A',
                    'driver_name' => optional($r->driver)->first_name,
                    'latitude' => $r->start_latitude,
                    'longitude' => $r->start_longitude
                ];
            });

            $finalZones[] = [
                'lat' => $zone['lat'],
                'lng' => $zone['lng'],
                'status' => $status,
                'total_rides' => $totalRides,
                'available_drivers' => $availableDrivers,
                'ride_details' => $rideDetails
            ];
        }

        $formattedDrivers = $drivers->map(function ($driver) {
            return [
                'name' => trim("{$driver->first_name} {$driver->last_name}"),
                'latitude' => $driver->latitude,
                'longitude' => $driver->longitude,
                'is_available' => $driver->is_available,
                'is_online' => $driver->is_online
            ];
        });

        return response()->json([
            'zones' => $finalZones,
            'drivers' => $formattedDrivers
        ]);
    }
    public function referenceindex(ReferenceDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title', ['form' => __('message.reference_program')]);
        $auth_user = authSession();
        $assets = ['datatable'];
        $button = '';
        return $dataTable->render('global.datatable', compact('assets', 'pageTitle', 'auth_user', 'button'));
    }

    public function fleetFareAjax(Request $request){
        $tripType = $request->trip_type;

        if ($tripType === 'regular') {
            return response()->json(['success' => false]);
        }

        $query = DB::table('zone_prices');
        if($tripType && $tripType == 'zone_wise'){
            $query->whereJsonContains('service_ids', $request->serviceId)->where('zone_pickup', $request->pickup_zone_id)->where('zone_dropoff', $request->drop_zone_id);
        }

        $price = $query->value('price');
        return response()->json([
            'success' => true,
            'price' => $price,
        ]);
    }
    function getCountryDetailsByCode($code)
    {
        $countries = country();
        foreach ($countries as $country) {

          if (is_array($country) && isset($country['countryCode'])) {
            if (strtoupper($country['countryCode']) === strtoupper($code)) {
                return $country;
            }
          }
        }

        return null;
    }

    public function saveCoins(Request $request)
    {
        $user  = User::find($request->rider_id);
        $coins = $request->coins;
        $type  = $request->type;

        if ($type === 'debit' && $user->total_coins < $coins) {
            return redirect()->back()->withErrors(__('message.insufficient_coins'));
        }
        $type === 'credit' ? $user->increment('total_coins', $coins) : $user->decrement('total_coins', $coins);

        CoinWallet::create([
            'user_id'      => $request->rider_id,
            'coins'        => $coins,
            'type'         => $type,
            'scratch_time' => now(),
        ]);

        $message = $type === 'credit' ? __('message.coins_added') : __('message.coins_deducted');

        return redirect()->back()->withSuccess($message);
    }
}

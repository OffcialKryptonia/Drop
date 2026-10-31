<?php

use App\Http\Controllers\HomeController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\RoleController;
use App\Http\Controllers\PermissionController;
use App\Http\Controllers\RiderController;
use App\Http\Controllers\DriverController;
use App\Http\Controllers\FleetController;
use App\Http\Controllers\RegionController;
use App\Http\Controllers\ServiceController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\CouponController;
use App\Http\Controllers\ComplaintController;
use App\Http\Controllers\RideRequestController;
use App\Http\Controllers\SettingController;
use App\Http\Controllers\LanguageController;
use App\Http\Controllers\AdditionalFeesController;
use App\Http\Controllers\AdminLoginDeviceController;
use App\Http\Controllers\AdminLoginHistoryController;
use App\Http\Controllers\AirportController;
use App\Http\Controllers\CancellationController;
use App\Http\Controllers\ClientTestimonialsController;
use App\Http\Controllers\DocumentController;
use App\Http\Controllers\DriverDocumentController;
use App\Http\Controllers\SosController;
use App\Http\Controllers\WithdrawRequestController;

use App\Http\Controllers\ComplaintCommentController;
use App\Http\Controllers\CustomerSupportController;
use App\Http\Controllers\DefaultkeywordController;
use App\Http\Controllers\WalletController;
use App\Http\Controllers\PushNotificationController;

use App\Http\Controllers\DispatchController;
use App\Http\Controllers\DriverPayoutReportsController;
use App\Http\Controllers\FAQsController;
use App\Http\Controllers\Frontendwebsite\FrontendController;
use App\Http\Controllers\LanguageListController;
use App\Http\Controllers\LanguageWithKeywordListController;
use App\Http\Controllers\MailTemplateController;
use App\Http\Controllers\ManageZoneController;
use App\Http\Controllers\ManageZonePriceController;
use App\Http\Controllers\OurMissionController;
use App\Http\Controllers\PagesController;
use App\Http\Controllers\PaymentController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\RideSMSController;
use App\Http\Controllers\ScreenController;
use App\Http\Controllers\SubAdminController;
use App\Http\Controllers\SupportchatHistoryController;
use App\Http\Controllers\SurgePriceController;
use App\Http\Controllers\WhyChooseController;
use Illuminate\Support\Facades\Artisan;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

require __DIR__ . '/auth.php';

Route::get('migrate', function () {
    Artisan::call('migrate');
    return 'Migration completed';
});

Route::get('seed', function () {
    Artisan::call('db:seed');
    return 'Seeding completed';
});

Route::get('storage-link', function(){
    try {
        Artisan::call('storage:link', ['--force' => true]);
        return 'Storage Link successfully';
    } catch (\Exception $e) {
        return 'Storage Link failed: ' . $e->getMessage();
    }
});

Route::get('optimize', function () {
    Artisan::call('optimize:clear');
    return 'Optimization completed';
});


Route::get('storage-link', function () {
    Artisan::call('storage:link');
    return 'Storage link created';
});

Route::get('/mqtt/publish/{topic}/{message}', [HomeController::class, 'SendMsgViaMqtt']);
Route::get('/mqtt/subscribe/{topic}', [HomeController::class, 'SubscribetoTopic']);

//Auth pages Routs
Route::group(['prefix' => 'auth'], function () {
    Route::get('otp-form', [HomeController::class, 'showOtpForm'])->name('auth.otp-form');
    Route::post('verify-otp', [HomeController::class, 'verifyOtp'])->name('auth.verify-otp');
    Route::get('login', [HomeController::class, 'authLogin'])->name('auth.login');
    Route::get('register', [HomeController::class, 'authRegister'])->name('auth.register');
    Route::get('recover-password', [HomeController::class, 'authRecoverPassword'])->name('auth.recover-password');
    Route::get('confirm-email', [HomeController::class, 'authConfirmEmail'])->name('auth.confirm-email');
    Route::get('lock-screen', [HomeController::class, 'authlockScreen'])->name('auth.lock-screen');
    // Route::get('admin/login', [HomeController::class, 'login'])->name('admin-login');
    Route::get('verify-otp', [HomeController::class, 'verifyOTP'])->name('verify-otp');
    Route::post('verify-otp-post', [HomeController::class, 'verifyOTP_post'])->name('verify-otp-post');
});

Route::get('ride-invoice/{id}', [RideRequestController::class, 'rideInvoicePdf'])->name('ride-invoice');
Route::get('ride-rider-invoice/{id}', [RideRequestController::class, 'rideRiderInvoicePdf'])->name('ride-rider-invoice');
Route::get('language/{locale}', [HomeController::class, 'changeLanguage'])->name('change.language');
Route::group(['middleware' => ['auth', 'verified', 'admin']], function () {
    // Route::get('/', [HomeController::class, 'index']);
    Route::get('/home', [HomeController::class, 'index'])->name('home');

    Route::group(['namespace' => ''], function () {
        Route::resource('permission', PermissionController::class);
        Route::get('permission/add/{type}', [PermissionController::class, 'addPermission'])->name('permission.add');
        Route::post('permission/save', [PermissionController::class, 'savePermission'])->name('permission.save');
    });

    Route::resource('role', RoleController::class);
    Route::resource('region', RegionController::class);
    Route::resource('service', ServiceController::class);

    Route::resource('rider', RiderController::class);
    Route::get('rider-restore/{id?}', [RiderController::class, 'action'])->name('rider.restore');
    Route::delete('rider-force-delete/{id?}', [RiderController::class, 'action'])->name('rider.force.delete');
    Route::resource('driver', DriverController::class);
    Route::get('driver-restore/{id?}', [DriverController::class, 'action'])->name('driver.restore');
    Route::delete('driver-force-delete/{id?}', [DriverController::class, 'action'])->name('driver.force.delete');
    Route::patch('driver/{id}/offline', [DriverController::class, 'makeOffline'])->name('driver.makeOffline');
    Route::get('driver/list/{status?}', [DriverController::class, 'index'])->name('driver.pending');

    Route::resource('fleet', FleetController::class);
    Route::resource('additionalfees', AdditionalFeesController::class);
    Route::resource('document', DocumentController::class);
    Route::resource('driverdocument', DriverDocumentController::class);


    Route::resource('riderequest', RideRequestController::class)->except(['create', 'edit']);
    Route::resource('coupon', CouponController::class);
    Route::resource('complaint', ComplaintController::class);
    Route::resource('surge-prices', SurgePriceController::class);
    Route::resource('sos', SosController::class);
    Route::resource('withdrawrequest', WithdrawRequestController::class);
    Route::post('withdrawrequest/status', [WithdrawRequestController::class, 'updateStatus'])->name('withdraw.request.status');
    Route::get('bank-detail/{id}', [WithdrawRequestController::class, 'userBankDetail'])->name('bankdetail');


    Route::post('complaintcomment-save', [ComplaintCommentController::class, 'store'])->name('complaintcomment.store');
    Route::post('complaintcomment-update/{id}', [ComplaintCommentController::class, 'update'])->name('complaintcomment.update');

    Route::get('changeStatus', [HomeController::class, 'changeStatus'])->name('changeStatus');

    Route::get('setting/{page?}', [SettingController::class, 'settings'])->name('setting.index');
    Route::post('/layout-page', [SettingController::class, 'layoutPage'])->name('layout_page');
    Route::post('settings/save', [SettingController::class, 'settingsUpdates'])->name('settingsUpdates');
    Route::post('appsetting/save', [SettingController::class, 'AppSetting'])->name('AppSetting');
    Route::post('mobile-config-save', [SettingController::class, 'settingUpdate'])->name('settingUpdate');
    Route::post('payment-settings/save', [SettingController::class, 'paymentSettingsUpdate'])->name('paymentSettingsUpdate');
    Route::post('wallet-settings/save', [SettingController::class, 'walletSettingsUpdate'])->name('walletSettingsUpdate');
    Route::post('ride-settings/save', [SettingController::class, 'rideSettingsUpdate'])->name('rideSettingsUpdate');
    Route::post('scratch-card-settings/save', [SettingController::class, 'scratchCardSettingsUpdate'])->name('scratchCardSettingsUpdate');
    Route::post('notification-settings/save', [SettingController::class, 'notificationSettingsUpdate'])->name('notificationSettingsUpdate');
    Route::post('update-appsetting', [SettingController::class, 'updateAppSetting'])->name('updateAppsSetting');
    Route::post('mail-template-settings/save', [SettingController::class, 'mailTemplateSettingsUpdate'])->name('mailTemplateSettingsUpdate');

    Route::post('get-lang-file', [LanguageController::class, 'getFile'])->name('getLanguageFile');
    Route::post('save-lang-file', [LanguageController::class, 'saveFileContent'])->name('saveLangContent');

    Route::get('pages/term-condition', [SettingController::class, 'termAndCondition'])->name('term-condition');
    Route::post('term-condition-save', [SettingController::class, 'saveTermAndCondition'])->name('term-condition-save');

    Route::get('pages/privacy-policy', [SettingController::class, 'privacyPolicy'])->name('privacy-policy');
    Route::post('privacy-policy-save', [SettingController::class, 'savePrivacyPolicy'])->name('privacy-policy-save');


    Route::get('pages/billing-statement', [SettingController::class, 'billingStatement'])->name('billing-statement');
    Route::post('billing-statement-save', [SettingController::class, 'saveBillingStatement'])->name('billing-statement-save');

    Route::post('env-setting', [SettingController::class, 'envChanges'])->name('envSetting');
    Route::post('update-profile', [SettingController::class, 'updateProfile'])->name('updateProfile');
    Route::post('change-password', [SettingController::class, 'changePassword'])->name('changePassword');
    Route::post('verify-old-password', [ SettingController::class , 'verifyOldPassword'])->name('verifyOldPassword');
    Route::post('change-email', [SettingController::class, 'changeEmail'])->name('changeEmail');
    Route::post('change-email-otp-verify', [SettingController::class, 'changeEmail_otpVerify'])->name('changeEmail_otpVerify');
    Route::post('mail-alert-settings/save',[ SettingController::class , 'mailAlertSettingsUpdate'])->name('mailAlertSettingsUpdate');

    Route::get('notification-list', [NotificationController::class, 'notificationList'])->name('notification.list');
    Route::get('notification-counts', [NotificationController::class, 'notificationCounts'])->name('notification.counts');
    Route::get('notification', [NotificationController::class, 'index'])->name('notification.index');

    Route::post('remove-file', [HomeController::class, 'removeFile'])->name('remove.file');
    Route::get('mapview', [HomeController::class, 'map'])->name('map');
    Route::get('map-view', [HomeController::class, 'driverListMap'])->name('driver_list.map');
    // Route::get('driver-detail', [ HomeController::class, 'driverDetail' ] )->name('driverdetail');
    Route::get('live-tracking', [HomeController::class, 'liveTracking'])->name('admin.liveTracking');


    Route::get('realtime-dashboard', [HomeController::class, 'realTimeDashboard'])->name('realtime.dashboard');
    Route::get('realtime-dashboard/data', [HomeController::class, 'realTimeDashboard'])->name('realtime.dashboard.data');
    Route::get('admin-live-tracking/data', [HomeController::class, 'adminLiveTrackingData'])->name('admin.liveTracking.data');
    Route::get('admin-live-tracking/directions-polyline', [\App\Http\Controllers\API\RideRequestController::class, 'directionsPolyline'])->name('admin.liveTracking.directionsPolyline');

    Route::get('/demand-map', [HomeController::class, 'demandMap'])->name('demand_map');
    Route::get('demand-zone-list', [HomeController::class, 'demandZoneList'])->name('demand.zone.list');

    Route::get('driver/{id}/details', [HomeController::class, 'driverDetail'])->name('driverDetail');
    Route::get('driver/searchById/{id}', [HomeController::class, 'search'])->name('driver.search');

    Route::post('save-wallet-fund/{user_id}', [HomeController::class, 'saveWalletHistory'])->name('savewallet.fund');
    Route::post('save-coins/{rider_id}', [HomeController::class, 'saveCoins'])->name('coin.save');

    Route::resource('pushnotification', PushNotificationController::class);
    Route::get('resend-pushnotification/{id}', [PushNotificationController::class, 'edit'])->name('resend.pushnotification');

    Route::resource('dispatch', DispatchController::class)->except(['edit']);
    Route::get('supplier-payout',[ DispatchController::class,'supplierPayout' ])->name('supplier.payout');
    Route::get('check-special-services', [DispatchController::class, 'checkSpecialServices'])->name('check.special.services');
    // Route::get('ride-invoice/{id}', [RideRequestController::class, 'rideInvoicePdf'])->name('ride-invoice');

    // Route::get('/check-zone-payout', [DispatchController::class, 'checkZonePayout']);
    Route::post('/check-zone-price', [DispatchController::class, 'checkZonePayout'])->name('check.zone.price');
    Route::post('/save-zone-fare', [DispatchController::class, 'storeZoneFare'])->name('zone.fare.store');

    // Route::get('informations', [SettingController::class, 'information'])->name('information');
    // Route::get('dowloandapp', [SettingController::class, 'downloandapp'])->name('downloandapp');
    // Route::get('contactinfo', [SettingController::class, 'contactinfo'])->name('contactinfo');
    // Route::post('setting-upload-image', [SettingController::class, 'settingUploadImage'])->name('image-save');

    Route::get('website-section/{type}', [ FrontendController::class, 'websiteSettingForm' ] )->name('frontend.website.form');
    Route::post('update-website-information/{type}', [ FrontendController::class, 'websiteSettingUpdate' ] )->name('frontend.website.information.update');

    //pages
    Route::resource('pages', PagesController::class);
    Route::get('pages-edit/{id?}', [PagesController::class, 'edit'])->name('Pages-edit.edit');

    Route::resource('our-mission', OurMissionController::class);
    Route::resource('why-choose', WhyChooseController::class);
    Route::resource('client-testimonials', ClientTestimonialsController::class);
    // Route::get('delete/{id}', [OurMissionController::class, 'destroy'])->name('data-delete');

    Route::resource('screen', ScreenController::class);
    Route::resource('defaultkeyword', DefaultkeywordController::class);
    Route::resource('languagelist', LanguageListController::class);
    Route::resource('languagewithkeyword', LanguageWithKeywordListController::class);
    Route::get('download-language-with-keyword-list', [LanguageWithKeywordListController::class, 'downloadLanguageWithKeywordList'])->name('download.language.with.keyword.list');

    Route::post('import-language-keyword', [LanguageWithKeywordListController::class, 'importlanguagewithkeyword'])->name('import.languagewithkeyword');
    Route::get('bulklanguagedata', [LanguageWithKeywordListController::class, 'bulklanguagedata'])->name('bulk.language.data');
    Route::get('help', [LanguageWithKeywordListController::class, 'help'])->name('help');
    Route::get('download-template', [LanguageWithKeywordListController::class, 'downloadtemplate'])->name('download.template');

    Route::delete('datatble/destroySelected', [HomeController::class, 'destroySelected'])->name('datatble.destroySelected');


    // report data Route
    Route::get('admin-earning-report', [ReportController::class, 'adminEarning'])->name('adminEarningReport');
    Route::get('driver-earning-report', [ReportController::class, 'driverEarning'])->name('driver.earning.report');
    Route::get('driver-report-report', [ReportController::class, 'driverReport'])->name('driver.report.list');
    Route::get('service-wise-report', [ReportController::class, 'serviceWiseReport'])->name('serviceWiseReport');

    // Report Excel Route
    Route::get('download-admin-earning', [ReportController::class, 'downloadAdminEarning'])->name('download-admin-earning');
    Route::get('download-driver-earning', [ReportController::class, 'downloadDriverEarning'])->name('download-driver-earning');
    Route::get('servicewise-report-export', [ReportController::class, 'serviceWiseReportExport'])->name('download.servicewise.report');

    //Report Pdf Route
    Route::get('download-adminearningpdf', [ReportController::class, 'downloadAdminEarningPdf'])->name('download-adminearningpdf');
    Route::get('download-driverearningpdf', [ReportController::class, 'downloadDriverEarningPdf'])->name('download-driverearningpdf');
    Route::get('servicewise-report-pdf-export', [ReportController::class, 'serviceWiseReportPdfExport'])->name('download.servicewise.report.pdf');

    Route::get('download-withdrawrequest-list', [WithdrawRequestController::class, 'downloadWithdrawRequestList'])->name('download.withdrawrequest.list');

    Route::resource('sub-admin', SubAdminController::class);

    Route::resource('payment', PaymentController::class);

    // Route::resource('customersupport', CustomerSupportController::class);
    // Route::resource('supportchathistory', SupportchatHistoryController::class);
    // Route::put('/support/{id}/status', [CustomerSupportController::class, 'updateStatus'])->name('support.updateStatus');

    Route::resource('mail-template', MailTemplateController::class)->except(['create', 'show', 'edit', 'update', 'destroy']);

    Route::get('assign/{id?}', [RideRequestController::class, 'assigndriver'])->name('driver-assign');
    Route::post('driver-assign/{id?}', [RideRequestController::class, 'assigndriversave'])->name('driver.assign');

    //ride SMS
    Route::resource('ridesms', RideSMSController::class);
    Route::post('sms-settings/save', [SettingController::class, 'smsSettingsUpdate'])->name('smsSettingsUpdate');

    Route::resource('cancellation', CancellationController::class);
    Route::resource('faqs', FAQsController::class);
    Route::resource('driver_payout_reports', DriverPayoutReportsController::class);
    Route::get('reference-data', [HomeController::class, 'referenceindex'])->name('reference-list');

    //airports
    Route::resource('airport', AirportController::class);
    Route::delete('airport-force-delete/{id?}', [AirportController::class, 'action'])->name('airport.force.delete');
    Route::get('airport-restore/{id?}', [AirportController::class, 'action'])->name('airport.restore');
    Route::get('importdata', [AirportController::class, 'importdata'])->name('airport.data');
    Route::post('import-airport-data', [AirportController::class, 'importairportdata'])->name('import.airportdata');

    Route::resource('admin-login-history', AdminLoginHistoryController::class);
    Route::resource('admin-login-device', AdminLoginDeviceController::class);
    Route::post('admin/device/logout/{id}',[ AdminLoginDeviceController::class, 'logoutDevice' ])->name('admin.device.logout');
    Route::get('/admin/device/{id}', [AdminLoginDeviceController::class, 'show'])->name('admin.device.show');


    Route::resource('managezone', ManageZoneController::class);
    Route::resource('managezone-price', ManageZonePriceController::class);

    Route::get('download-driver-report/{fileType?}', [DriverController::class, 'downloadDriverReport'])->where('fileType', 'xlsx|xls|csv|ods|html')->name('download.driver.report');
    Route::get('download-driver-report-pdf', [DriverController::class, 'downloadDriverReportPdf'])->name('download.driver.report.pdf');

    Route::get('download-rider-report/{fileType?}', [RiderController::class, 'downloadRiderReport'])->where('fileType', 'xlsx|xls|csv|ods|html')->name('download.rider.report');
    Route::get('download-rider-report-pdf', [RiderController::class, 'downloadRiderReportPdf'])->name('download.rider.report.pdf');
    Route::get('/download-riderrequest-report/{fileType}', [RideRequestController::class, 'downloadRideRequestReport'])->where('fileType', 'xlsx')->name('download.riderrequest.report');

});

Route::get('/ajax-list', [HomeController::class, 'getAjaxList'])->name('ajax-list');
Route::post('fleet-fare-ajax',[ HomeController::class, 'fleetFareAjax' ])->name('fleet-fare-ajax');
Route::get('/payment-success', [App\Http\Controllers\API\PaymentController::class, 'paymentSuccess']);
Route::get('/payment-cancel', [App\Http\Controllers\API\PaymentController::class, 'paymentCancel']);

Route::get('/', [FrontendController::class, 'index'])->name('browse');
Route::get('termofservice', [FrontendController::class, 'termofservice'])->name('termofservice');
Route::get('privacypolicy', [FrontendController::class, 'privacypolicy'])->name('privacypolicy');
Route::get('page/{slug}', [FrontendController::class, 'page'])->name('pages');

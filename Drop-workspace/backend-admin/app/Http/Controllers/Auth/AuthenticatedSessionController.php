<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Mail\SendOtpMail;
use App\Providers\RouteServiceProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Mail;
use App\Traits\LoginHistoryTrait;
use Illuminate\Validation\ValidationException;

class AuthenticatedSessionController extends Controller
{
    use LoginHistoryTrait;
    /**
     * Display the login view.
     *
     * @return \Illuminate\View\View
     */
    public function create()
    {
        return view('auth.login');
    }

    /**
     * Handle an incoming authentication request.
     *
     * @param  \App\Http\Requests\Auth\LoginRequest  $request
     * @return \Illuminate\Http\RedirectResponse
     */
    public function store(LoginRequest $request)
    {
        $request->authenticate();

        $request->session()->regenerate();
        $auth_user = auth()->user();

        if (in_array($auth_user->user_type, ['rider', 'driver'])) {

            Auth::logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

              throw ValidationException::withMessages([ 'email' => __('message.not_login') ]);
        }
        $auth_user->last_actived_at = now();
        $auth_user->save();

        $otp_verification_status = config('constant.MAIL_SETTING.EMAIL_OTP_VERIFICATION');

        if ($otp_verification_status === 'enable') {
            $otp = rand(100000, 999999);
            $auth_user->otp = $otp;
            $auth_user->save();

            try {
                    Mail::to($auth_user->email)->send(new SendOtpMail($otp));
                } catch (\Exception $e) {
                    \Log::error("OTP alert send failed, Error: {$e->getMessage()}");
                }
            Auth::logout();

            return redirect()
                ->route('auth.otp-form')
                ->with('email', $auth_user->email);
        }
        $this->saveLoginHistory($auth_user);
        return redirect(RouteServiceProvider::HOME);
    }

    /**
     * Destroy an authenticated session.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\RedirectResponse
     */
    public function destroy(Request $request)
    {
        Auth::guard('web')->logout();

        $request->session()->invalidate();

        $request->session()->regenerateToken();

        return redirect('/');
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
}

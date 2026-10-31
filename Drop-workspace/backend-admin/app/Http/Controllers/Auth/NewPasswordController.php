<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Exception\AuthException;
use Kreait\Firebase\Exception\FirebaseException;
use Kreait\Firebase\Factory;

class NewPasswordController extends Controller
{
    /**
     * Display the password reset view.
     *
     * @return \Illuminate\View\View
     */
    public function create(Request $request)
    {
        return view('auth.reset-password', ['request' => $request]);
    }

    /**
     * Handle an incoming new password request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\RedirectResponse
     *
     * @throws \Illuminate\Validation\ValidationException
     */
    public function store(Request $request)
    {
        $request->validate([
            'token' => 'required',
            'email' => 'required|email',
            'password' => 'required|string|confirmed|min:8',
        ]);
        $factory = (new Factory)->withServiceAccount(base_path(env('FIREBASE_CREDENTIALS')));
        $auth = $factory->createAuth();

        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function ($user) use ($request, $auth) {
                $user->forceFill([
                    'password' => Hash::make($request->password),
                    'remember_token' => Str::random(60),
                ])->save();

                event(new PasswordReset($user));

                try {
                    $firebaseUser = $auth->getUserByEmail($user->email);
                    $auth->changeUserPassword($firebaseUser->uid, $request->password);
                } catch (AuthException $e) {

                    try {
                        $newFirebaseUser = $auth->createUser([
                            'email' => $user->email,
                            'password' => $request->password,
                        ]);
                        Log::info('Firebase user created: '.$newFirebaseUser->uid);
                    } catch (FirebaseException $ex) {
                        Log::error('Failed to create Firebase user: '.$ex->getMessage());
                    }
                } catch (FirebaseException $e) {
                    Log::error('Firebase error: '.$e->getMessage());
                } catch (\Throwable $e) {
                    Log::error('Unexpected Firebase password update error: '.$e->getMessage());
                }
            }
        );

        return $status == Password::PASSWORD_RESET
                    ? redirect()->route('login')->with('status', __($status))
                    : back()->withInput($request->only('email'))
                            ->withErrors(['email' => __($status)]);
    }
}

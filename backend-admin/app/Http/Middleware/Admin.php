<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\Auth;
use Spatie\Permission\Models\Role;

class Admin
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @return mixed
     */
    public function handle($request, Closure $next)
    {   
        if (Auth::check()) {
            $user = auth()->user();

            $restrictedRoles = ['rider', 'driver'];

            if ($user->hasAnyRole($restrictedRoles)) {
                Auth::logout();
                abort(403, __('message.access_denied'));
            }

            return $next($request);
        }

        Auth::logout();
        abort(403, __('message.access_denied'));
    }

}

<x-guest-layout>
<style>

</style>

<section class="login-content">
    <div class="container h-100">
        <div class="row align-items-center justify-content-center h-100">
            <div class="col-md-5">
                <div class="card">
                    <div class="card-body">
                        <div class="auth-logo">
                            <img src="{{ getSingleMedia(appSettingData('get'),'site_logo',null) }}" class="img-fluid mode light-img rounded-normal" alt="logo">
                            <img src="{{ getSingleMedia(appSettingData('get'),'site_dark_logo',null) }}" class="img-fluid mode dark-img rounded-normal darkmode-logo site_dark_logo_preview" alt="dark-logo">
                        </div>

                        <h2 class="mb-2 text-center">{{ __('message.otp_verification') }}</h2>
                        <p class="text-center">{{__('message.6-digit_otp')}}</p>

                        @if ($errors->any())
                            <div class="alert alert-danger">
                                {{ $errors->first() }}
                            </div>
                        @endif

                        <form method="POST" action="{{ route('auth.verify-otp') }}" data-toggle="validator">
                            @csrf

                            <input type="hidden" name="email" value="{{ $email }}">

                            <div class="form-group">
                                <label>{{ __('message.enter_otp') }}</label>
                                <input type="text" name="otp" class="form-control" placeholder="123456" required>
                            </div>

                            <div class="d-flex justify-content-between align-items-center mt-4">
                                <button type="submit" class="btn btn-primary w-100">{{ __('message.verify_otp') }}</button>
                            </div>
                        </form>

                        <div class="text-center mt-3">
                            <a href="{{ route('auth.login') }}" class="text-primary">{{__('message.back_login')}}</a>
                        </div>

                    </div>
                </div>
            </div>
        </div>
    </div>
</section>
</x-guest-layout>

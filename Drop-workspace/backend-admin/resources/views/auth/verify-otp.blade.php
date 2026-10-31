
<x-guest-layout>


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
                            <h2 class="mb-2 text-center">{{ __('message.verify_otp') }}</h2>
                            <p class="text-center">{{ __('message.enter_your_otp_to_login') }}</p>
                            <!-- Session Status -->
                            <x-auth-session-status class="mb-4" :status="session('status')" />
                            <!-- Validation Errors -->
                            <x-auth-validation-errors class="mb-4" :errors="$errors" />
                            <form method="POST" action="{{ route('verify-otp-post') }}" data-toggle="validator">
                                {{csrf_field()}}
                                <div class="row">
                                    <div class="col-lg-12">
                                        <div class="form-group">
                                            <label >{{ __('message.otp') }}</label>
                                            <input type="text"  id="otp" name="otp"  class="form-control" required autofocus>
                                            <input type="text" hidden  id="email" name="email" value="{{ $user_email }}">
                                        </div>
                                    </div>
                                </div>
                                <div class="d-flex justify-content-between align-items-center">
                                    <button type="submit" class="btn btn-primary">{{ __('message.verify_otp') }}</button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

</x-guest-layout>

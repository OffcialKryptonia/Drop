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
                            <h2 class="mb-2 text-center">{{ __('auth.reset_password') }}</h2>
                            
                            <!-- Validation Errors -->
                            <x-auth-validation-errors class="mb-4" :errors="$errors" />
                            {{ html()->form('POST', route('password.update'))->attribute('data-toggle','validator')->open() }}

                                <!-- Password Reset Token -->
                                <input type="hidden" name="token" value="{{ $request->route('token') }}">
                                <!-- Email Address -->
                                <div class="col-lg-12">
                                    <div class="form-group">
                                        {{ html()->label(__('message.email') . ' <span class="text-danger">*</span>', 'email')->class('form-control-label') }}
							            {{ html()->email('email', old('email') ?? $request->email)->class('form-control')->placeholder(__('message.email'))->required() }}
                                    </div>
                                </div>

                                <!-- Password -->
                                <div class="col-lg-12">
                                    <div class="form-group">
                                        {{ html()->label(__('message.password') . ' <span class="text-danger">*</span>', 'password')->class('form-control-label') }}
                                        {{ html()->password('password',old('password'))->class('form-control')->id('password')->placeholder(__('message.password'))->required() }}
                                    </div>
                                </div>

                                <!-- Confirm Password -->
                                <div class="col-lg-12">
                                    <div class="form-group">
                                        {{ html()->label(__('auth.password_confirmation') . ' <span class="text-danger">*</span>', 'password_confirmation')->class('form-control-label') }}
                                        {{ html()->password('password_confirmation',old('password_confirmation'))->class('form-control')->placeholder(__('auth.password_confirmation'))->required() }}
                                    </div>
                                </div>
                                <button type="submit" class="btn btn-primary btn-block">  {{ __('auth.reset_password') }}</button>
                            {!! html()->form()->close() !!}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
</x-guest-layout>

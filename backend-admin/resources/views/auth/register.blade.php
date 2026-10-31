<x-guest-layout :assets="$assets ?? []">
<section class="login-content">
    <div class="container h-100">
        <div class="row align-items-center justify-content-center h-100">
            <div class="col-md-7">
                <div class="card">
                    <div class="card-body">
                        <div class="auth-logo">
                            <img src="{{ getSingleMedia(appSettingData('get'),'site_logo',null) }}" class="img-fluid mode light-img rounded-normal" alt="logo">
                            <img src="{{ getSingleMedia(appSettingData('get'),'site_dark_logo',null) }}" class="img-fluid mode dark-img rounded-normal darkmode-logo site_dark_logo_preview" alt="dark-logo">
                        </div>
                        <h2 class="mb-2 text-center">{{ __('message.sign_up') }}</h2>
                        <!-- Session Status -->
                        <x-auth-session-status class="mb-4" :status="session('status')" />

                        <!-- Validation Errors -->
                        <x-auth-validation-errors class="mb-4" :errors="$errors" />
                        <form method="POST" action="{{ route('register') }}" data-toggle="validator">
                            {{csrf_field()}}
                            <div class="row">
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.first_name') . ' <span class="text-danger">*</span>')->for('first_name')->class('form-control-label')!!}
                                    {!! html()->text('first_name', old('first_name'))->placeholder(__('message.first_name'))->class('form-control')->required() !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.last_name') . ' <span class="text-danger">*</span>')->for('last_name')->class('form-control-label')!!}
                                    {!! html()->text('last_name', old('last_name'))->placeholder(__('message.last_name'))->class('form-control')->required() !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.email') . ' <span class="text-danger">*</span>')->for('email')->class('form-control-label')!!}
                                    {!! html()->email('email', old('email'))->placeholder(__('message.email'))->class('form-control')->required() !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.username') . ' <span class="text-danger">*</span>')->for('username')->class('form-control-label')!!}
                                    {!! html()->text('username', old('username'))->placeholder(__('message.username'))->class('form-control')->required() !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.password') . ' <span class="text-danger">*</span>')->for('password')->class('form-control-label')!!}
                                    {!! html()->password('password')->placeholder(__('message.password'))->class('form-control') !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.confirm_password') . ' <span class="text-danger">*</span>')->for('password_confirmation')->class('form-control-label')!!}
                                    {!! html()->password('password_confirmation')->placeholder(__('message.password'))->class('form-control') !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.contact_number') . ' <span class="text-danger">*</span>')->for('contact_number')->class('form-control-label')!!}
                                    {!! html()->text('contact_number', old('contact_number'))->placeholder(__('message.contact_number'))->class('form-control')->id('phone') !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.gender') . ' <span class="text-danger">*</span>')->for('gender')->class('form-control-label')!!}
                                    {!! html()->select('gender', [
                                            'male' => __('message.male'),
                                            'female' => __('message.female'),
                                            'other' => __('message.other')
                                        ], old('gender'))->class('form-control select2js')->required() !!}
                                </div>
                                <div class="col-lg-12">
                                    <div class="custom-control custom-checkbox mb-3 form-group">
                                        <input type="checkbox" class="custom-control-input" id="customCheck1" required>
                                        <label class="custom-control-label" for="customCheck1">{{ __('message.i_agree_terms') }}</label>
                                    </div>
                                </div>
                            </div>
                            <div class="d-flex justify-content-between align-items-center">
                                <span> {{ __('message.already_have_an_account') }} <a href="{{route('auth.login')}}" class="text-primary">{{ __('message.sign_in') }}</a></span>
                                <button type="submit" class="btn btn-primary">{{ __('message.sign_up') }}</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>
</x-guest-layout>

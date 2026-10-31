{!! html()->form('POST', route('envSetting'))->attribute('data-toggle', 'validator')->open() !!}

{!! html()->hidden('id', null)->class('form-control') !!}
{!! html()->hidden('page', $page)->class('form-control') !!}
{!! html()->hidden('type', 'mail')->class('form-control') !!}

<div class="col-md-12 mt-20">
    <div class="row">
        @foreach (config('constant.MAIL_SETTING') as $key => $value)
            <div class="col-md-6">
                <div class="form-group">
                    @if ($key != 'EMAIL_OTP_VERIFICATION')
                        <label
                            class="form-control-label text-capitalize">{{ strtolower(str_replace('_', ' ', $key)) }}</label>
                        @if (!env('APP_DEMO') && auth()->user()->hasRole('admin'))
                            <input type="{{ $key == 'MAIL_PASSWORD' ? 'password' : 'text' }}" value="{{ $value }}"
                                name="ENV[{{ $key }}]" class="form-control"
                                placeholder="{{ config('constant.MAIL_PLACEHOLDER.' . $key) }}">
                        @else
                            <input type="{{ $key == 'MAIL_PASSWORD' ? 'password' : 'text' }}" value=""
                                name="ENV[{{ $key }}]" class="form-control"
                                placeholder="{{ config('constant.MAIL_PLACEHOLDER.' . $key) }}">
                        @endif
                    @endif
                    @if ($key == 'EMAIL_OTP_VERIFICATION')
                        <div class="custom-control custom-switch custom-switch-color custom-control-inline ml-2" style="margin-top: 6%;">
                            <input type="hidden" name="ENV[{{ $key }}]" value="disable">
                            <input type="checkbox" name="ENV[{{ $key }}]" value="enable"
                                class="custom-control-input bg-success" id="email_otp_verification"
                                {{ isset($value) && $value == 'enable' ? 'checked' : '' }}>

                            <label for="email_otp_verification" class="custom-control-label">
                                {{ __('message.email_otp_verification') }}
                            </label>
                        </div>
                    @endif
                </div>
            </div>
        @endforeach
    </div>
</div>
{!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-right') !!}
{!! html()->form()->close() !!}

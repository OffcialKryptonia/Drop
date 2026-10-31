@php
    $newEmail = session('new_email');
@endphp
<form action="{{ route('changeEmail_otpVerify') }}" method="POST" autocomplete="off" id="otp_form">
@csrf
    <div class="row">
        <div class="col-md-6 offset-md-3">
            <div class="form-group has-feedback">
                <label for="otp" class="form-control-label col-md-12">
                    {{ __('message.otp') }} <span class="text-danger">*</span>
                </label>
                <div class="col-md-12">
                    <input type="text" hidden name="newEmail" id="newEmail" value="{{ $newEmail }}">
                    <input type="text" name="otp" id="otp" class="form-control" placeholder="OTP" required
                        autocomplete="off" inputmode="numeric" autocorrect="off" autocapitalize="off">
                </div>
            </div>
            <div class="form-group">
                <div class="col-md-12">
                    <button type="submit" id="submit" class="btn btn-md btn-primary float-md-right mt-15">
                        {{ __('message.save') }}
                    </button>
                </div>
            </div>
        </div>
    </div>
</form>

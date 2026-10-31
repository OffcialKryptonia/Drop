{!! html()->modelForm($user_data, 'POST' , route('changePassword'))->attribute('data-toggle', 'validator')->id('user-password')->open() !!}

    <div class="row">
        <div class="col-md-6 offset-md-3">
            {!! html()->hidden('id')->class('form-control')->placeholder('id') !!}
            <div class="form-group has-feedback">
                {!! html()->label(__('message.old_password') . ' <span class="text-danger">*</span>')->for('old_password')->class('form-control-label col-md-12') !!}
                <div class="col-md-12">
                    {!! html()->password('old')->class('form-control')->id('old_password')->placeholder(__('message.old_password'))->required() !!}
                </div>
            </div>
            <div class="form-group has-feedback">
                
                {!! html()->label(__('message.password') . ' <span class="text-danger">*</span>')->for('password')->class('form-control-label col-md-12') !!}
                <div class="col-md-12">
                    {!! html()->password('password')->class('form-control')->id('password')->placeholder(__('message.new_password'))->required() !!}
                </div>
            </div>
            <div class="form-group has-feedback">
                {!! html()->label(__('message.confirm_new_password') . ' <span class="text-danger">*</span>')->for('password-confirm')->class('form-control-label col-md-12') !!}
                <div class="col-md-12">
                    {!! html()->password('password_confirmation')->class('form-control')->id('password-confirm')->placeholder(__('message.confirm_new_password'))->required() !!}
                </div>
            </div>
            <div class="form-group ">
                <div class="col-md-12">
                    {!! html()->submit(__('message.save'))->id('submit')->class('btn btn-md btn-primary float-md-right mt-15') !!}
                </div>
            </div>
        </div>
    </div>
{!! html()->form()->close() !!}
{!! html()->modelForm($user_data, 'POST' , route('changeEmail'))->attribute('data-toggle', 'validator')->id('user-email')->open() !!}
    <div class="row">
        <div class="col-md-6 offset-md-3">
            {!! html()->hidden('id')->class('form-control')->placeholder('id') !!}
            <div class="form-group has-feedback">
                {!! html()->label(__('message.email') . ' <span class="text-danger">*</span>')->for('email')->class('form-control-label col-md-12') !!}
                <div class="col-md-12">
                    {!! html()->email('email')->class('form-control')->id('email')->placeholder(__('message.email'))->required() !!}
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

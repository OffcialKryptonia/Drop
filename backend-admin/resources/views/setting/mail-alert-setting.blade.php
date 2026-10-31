{!! html()->form('POST', route('mailAlertSettingsUpdate'))->attribute('data-toggle', 'validator')->open() !!}
{!! html()->hidden('page', $page)->class('form-control') !!}    
    <div class="row">
        <div class="col-md-12">
            @foreach($mail_alert_setting as $key => $value)
                <div class="col-md-12 form-group">
                    <div class="custom-control custom-switch custom-switch-color custom-control-inline ml-2">
                        <input class="custom-control-input bg-success" name="{{ $key }}" type="checkbox" id="{{ $key }}" {{ $value ? 'checked' : '' }} value="{{ $value ?? 1 }}">
                         <label for="{{ $key }}" class="custom-control-label">
                                 {{ html()->label(__('message.'.$key.'_message'), $key)->class('form-check-label') }}
                        </label>                       
                    </div>
                </div>
            @endforeach
        </div>   
        <div class="col-lg-12">
            <hr>
            <div class="form-group">
                <div class="col-md-offset-3 col-sm-12">
                    {{ html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-end') }}
                </div>
            </div>
        </div>
    </div>
{!! html()->form()->close() !!}
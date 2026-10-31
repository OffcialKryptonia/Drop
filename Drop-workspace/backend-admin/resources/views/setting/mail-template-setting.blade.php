{!! html()->form('POST', route('mailTemplateSettingsUpdate'))->attribute('data-toggle', 'validator')->open() !!}
{!! html()->hidden('page', $page)->class('form-control') !!}

<div class="col-md-12 mt-20">
    <div class="row">
        @foreach($mail_template_setting as $key => $value)
            <div class="col-md-4 form-group">
                <div class="custom-switch custom-switch-color custom-control-inline">
                    <div class="custom-switch-inner">
                        {{-- {!! html()->hidden($key, 0) !!} --}}
                        {!! html()->checkbox($key, $value == 1)->class('custom-control-input bg-success float-right')->id($key) !!}
                        {!! html()->label(__('message.' . $key))->class('custom-control-label')->for($key) !!}
                    </div>
                </div>
            </div>
        @endforeach
    </div>
</div>
{!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-right') !!}
{!! html()->form()->close() !!}

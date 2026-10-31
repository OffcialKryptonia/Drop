<div class="row">
    <div class="col-lg-12">
        <div class="card">
            <div class="card-header">
                <ul class="nav nav-pills nav-fill tabslink" id="tab-text" role="tablist">
                    @foreach(config('constant.SMS_SETTING') as $key => $value)
                        <li class="nav-item">
                            <a href="javascript:void(0)" data-href="{{ route('layout_page') }}?page=sms-settings&type={{ $key }}" data-target=".paste_here" data-value="{{ $key }}" id="pills-{{ $key }}-tab-fill" data-toggle="tabajax" 
                               role="tab" class="nav-link {{ $key == $type ? 'active' : '' }}" aria-controls="pills-{{ $key }}" aria-selected="{{ $key == $type ? 'true' : 'false' }}"> {{ __('message.'.$key) }}
                            </a>
                        </li>
                    @endforeach
                </ul>
            </div>
            <div class="card-body">
                <div class="tab-content" id="pills-tabContent-1">
                    @foreach(config('constant.SMS_SETTING') as $key => $value)
                        <div class="tab-pane fade {{ $key == $type ? 'active show' : '' }}" id="pills-{{ $key }}-fill" role="tabpanel" aria-labelledby="pills-{{ $key }}-tab-fill">
                            {!! html()->modelForm($sms_setting, 'POST', route('smsSettingsUpdate'))->attribute('enctype', 'multipart/form-data')->attribute('data-toggle', 'validator')->open() !!}
                                {!! html()->hidden('id')->class('form-control') !!}
                                {!! html()->hidden('type', $key)->class('form-control') !!}
                                <div class="row">
                                    <div class="form-group col-md-12">
                                        {!! html()->label(__('message.status'))->class('d-block') !!}

                                        <div class="custom-control custom-radio custom-control-inline col-2">
                                            {!! html()->radio('status', old('status',$sms_setting) == '1' , '1')->class('custom-control-input')->id('status_active' . $key) !!}
                                            {!! html()->label(__('message.active'))->for('status_active' . $key)->class('custom-control-label') !!}
                                        </div>
                                        <div class="custom-control custom-radio custom-control-inline col-2">
                                            {!! html()->radio('status', old('status',$sms_setting) == '0','0')->class('custom-control-input')->id('status_inactive' . $key) !!}
                                            {!! html()->label(__('message.inactive'))->for('status_inactive' . $key)->class('custom-control-label') !!}
                                        </div>
                                    </div>
                                    @foreach ($value as $v)
                                        <div class="form-group col-md-6">
                                            {!! html()->label(__('message.' . $v))->for('values[' . $v . ']')->class('form-control-label') !!}
                                            {!! html()->text('values[' . $v . ']')->placeholder(__('message.' . $v))->class('form-control') !!}
                                        </div>
                                    @endforeach
                                </div>
                                <hr>
                                <div class="text-right">
                                    {!! html()->button(__('message.save'))->class('btn btn-md btn-primary') !!}
                                </div>
                            {!! html()->form()->close() !!}
                        </div>
                    @endforeach
                </div>
            </div>
        </div>
    </div>
</div>

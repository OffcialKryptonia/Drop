{!! html()->form('POST', route('rideSettingsUpdate'))->attribute('data-toggle', 'validator')->open() !!}
{!! html()->hidden('page' , $page)->class('form-control') !!}
    <div class="col-md-12 mt-20">
        <div class="row">
            @foreach($ride_setting as $key => $value)
                <div class="col-md-6 form-group">
                    @if($key == 'preset_tip_amount' )
                        {!! html()->label(__('message.' . $key) . ' <span data-toggle="tooltip" data-placement="right" title="' . __('message.preset_tip_amount_info') . '"><i class="fas fa-question-circle"></i></span>')->class('form-control-label')->for($key) !!}
                        {!! html()->text($key, $value ?? null)->placeholder('0|5|10|50')->class('form-control') !!}
                    @elseif($key == 'surge_price')
                    {!! html()->label(__('message.' . 'enable_surge_price'))->for($key)->class('form-control-label') !!}
                    <div class="custom-switch custom-switch-text custom-switch-color custom-control-inline mt-2">
                        <div class="custom-switch-inner">
                            {!! html()->hidden($key, 0) !!}
                            {!! html()->checkbox($key, $value == '1')
                                ->class('custom-control-input bg-dark')
                                ->attribute('data-type', 'pages')
                                ->attribute('data-id', $key)
                                ->id('switch_' . $key) !!}
                            {!! html()->label()->class('custom-control-label ml-2')->for('switch_' . $key) !!}
                        </div>
                    </div>
                    @elseif( $key == 'is_bidding' )
                    {!! html()->label(__('message.' .'enable_bidding'))->class('form-control-label')->for($key) !!}
                    <div class="custom-switch custom-switch-text custom-switch-color custom-control-inline mt-2">
                            <div class="custom-switch-inner">
                                {!! html()->hidden($key, 0) !!}
                                {!! html()->checkbox($key, $value == '1')
                                    ->class('custom-control-input bg-dark')
                                    ->attribute('data-type', 'pages')
                                    ->attribute('data-id', $key)
                                    ->id('switch_' . $key) !!}
                                {!! html()->label('')->for('switch_' . $key)->class('custom-control-label ml-2') !!}
                            </div>
                        </div>
                    @elseif( $key == 'is_sms_rider')
                        {!! html()->label(__('message.' . 'enable_sms_ride_request'))->class('form-control-label')->for($key) !!}
                        <div class="custom-switch custom-switch-text custom-switch-color custom-control-inline mt-2">
                                <div class="custom-switch-inner">
                                    {!! html()->hidden($key, 0) !!}
                                    {!! html()->checkbox($key, $value == '1')
                                        ->class('custom-control-input bg-dark')
                                        ->attribute('data-type', 'pages')
                                        ->attribute('data-id', $key)
                                        ->id('switch_' . $key) !!}
                                    {!! html()->label('')->for('switch_' . $key)->class('custom-control-label ml-2') !!}
                                </div>
                            </div>
                    @elseif( $key == 'per_minute_drive' )
                        {!! html()->label(__('message.' . 'enable_per_minute_drive_charge'))->class('form-control-label')->for($key) !!}
                            <div class="custom-switch custom-switch-text custom-switch-color custom-control-inline mt-2">
                                <div class="custom-switch-inner">
                                    {!! html()->hidden($key, 0) !!}
                                    {!! html()->checkbox($key, $value == '1')
                                        ->class('custom-control-input bg-dark')
                                        ->attribute('data-type', 'pages')
                                        ->attribute('data-id', $key)
                                        ->id('switch_' . $key) !!}
                                    {!! html()->label('')->for('switch_' . $key)->class('custom-control-label ml-2') !!}
                                </div>
                            </div>
                    @elseif( $key == 'enable_eta' )
                        {!! html()->label(__('message.' . $key))->class('form-control-label')->for($key) !!}
                            <div class="custom-switch custom-switch-text custom-switch-color custom-control-inline mt-2">
                                <div class="custom-switch-inner">
                                    {!! html()->hidden($key, 0) !!}
                                    {!! html()->checkbox($key, $value == '1')
                                        ->class('custom-control-input bg-dark')
                                        ->attribute('data-type', 'pages')
                                        ->attribute('data-id', $key)
                                        ->id('switch_' . $key) !!}
                                    {!! html()->label('')->for('switch_' . $key)->class('custom-control-label ml-2') !!}
                                </div>
                            </div>
                    @elseif( $key == 'apply_additional_fee' )
                    {!! html()->label(__('message.' . $key))->class('form-control-label')->for($key) !!}
                        @php
                            $value = isset($value) ? $value : 1;
                        @endphp
                        <div class="d-block">
                            <div class="custom-control custom-radio custom-control-inline col-2">
                                {!! html()->radio('apply_additional_fee', old('apply_additional_fee',$value) == 1, 1)->class('custom-control-input')->id('yes') !!}
                                {!! html()->label(__('message.yes'))->for('yes')->class('custom-control-label') !!}
                            </div>
                            <div class="custom-control custom-radio custom-control-inline col-2">
                                {!! html()->radio('apply_additional_fee', old('apply_additional_fee',$value) == 0 , 0)->class('custom-control-input')->id('no') !!}
                                {!! html()->label(__('message.no'))->for('no')->class('custom-control-label') !!}
                            </div>
                        </div>
                    @else
                    {!! html()->label(__('message.' . $key))->class('form-control-label')->for($key) !!}
                    {!! html()->number($key, $value ?? null)->placeholder(__('message.' . $key))
                        ->attribute('min', 0)
                        ->attribute('step', 'any')
                        ->class('form-control') !!}
                    @endif
                </div>
            @endforeach
        </div>
    </div>
{!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-right') !!}
{!! html()->form()->close() !!}

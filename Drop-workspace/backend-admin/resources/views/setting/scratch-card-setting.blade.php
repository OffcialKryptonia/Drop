{!! html()->form('POST', route('scratchCardSettingsUpdate'))->attribute('data-toggle', 'validator')->open() !!}
    <div class="col-md-12 mt-20">
        <div class="row">
            @foreach($scratch_card_setting as $key => $value)
                <div class="col-md-12 form-group">
                    @if($key == 'remaining_value')
                        {!! html()->label(__('message.' . $key))->class('form-control-label')->for($key) !!}
                        {!! html()->text($key, $value ?? null)->placeholder(__('message.' . $key))->attribute('min', 0)->attribute('step', 'any')->class('form-control') !!}
                    @elseif($key == 'enable_scratch_card')
                        {!! html()->label(__('message.' . 'enable_scratch_card'))->for($key)->class('form-control-label') !!}
                        <div class="custom-switch custom-switch-text custom-switch-color custom-control-inline mt-4">
                            <div class="custom-switch-inner">
                                {!! html()->hidden($key, 0) !!}
                                {!! html()->checkbox($key, $value == '1')->class('custom-control-input bg-dark')->attribute('data-type', 'pages')
                                    ->attribute('data-id', $key)
                                    ->id('switch_' . $key) !!}
                                {!! html()->label()->class('custom-control-label ml-2')->for('switch_' . $key) !!}
                            </div>
                        </div>
                    @endif
                </div>
            @endforeach
        </div>
    </div>
    {!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-right') !!}
{!! html()->form()->close() !!}

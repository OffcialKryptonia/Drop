{!! html()->form('POST', route('walletSettingsUpdate'))->attribute('data-toggle', 'validator')->open() !!}
{!! html()->hidden('page', $page)->class('form-control') !!}   
    <div class="col-md-12 mt-20">
        <div class="row">
            @foreach($wallet_setting as $key => $value)
                <div class="col-md-6 form-group">
                    @if($key == 'preset_topup_amount' )
                        {!! html()->label(__('message.'.$key). ' <span data-toggle="tooltip" data-placement="right" title="'.__('message.preset_topup_amount_info').'"><i class="fas fa-question-circle"></i></span>')->for($key)->class('form-control-label') !!}
                        {!! html()->text($key, $value ?? null)->placeholder('10|50|100|500')->class('form-control') !!}
                    @else
                        {!! html()->label(__('message.'.$key))->for($key)->class('form-control-label') !!}
                        @if($key == 'min_amount_to_get_ride')
                            {!! html()->number($key, $value ?? null)->placeholder(__('message.'.$key))->attribute('step', 'any')->class('form-control') !!}
                        @else
                            {!! html()->number($key, $value ?? null)->placeholder(__('message.'.$key))->attribute('min', 0)->attribute('step', 'any')->class('form-control') !!}
                        @endif
                    @endif
                </div>
            @endforeach
        </div>
    </div>
{!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-right') !!}
{!! html()->form()->close() !!}

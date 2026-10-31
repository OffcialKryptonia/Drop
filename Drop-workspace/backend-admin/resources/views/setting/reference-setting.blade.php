{!! html()->modelForm($setting_value, 'POST', route('settingUpdate'))->open() !!}
{!! html()->hidden('id',  null)->class('form-control') !!}
{!! html()->hidden('page', $page)->class('form-control') !!}
  
    <div class="card shadow mb-10">
        <div class="card-body">
            <div class="row">
                @foreach($setting as $key => $value)
                    @foreach($value as $sub_key => $sub_value)
                        @php
                            $data = null;
                            foreach($setting_value as $v) {
                                if ($v->key == $sub_key) {
                                    $data = $v;
                                }
                            }
                            $type = 'number';
                        @endphp

                        <div class="col-md-6">
                            <div class="form-group">
                                {!! html()->hidden('type[]', $sub_key)->class('form-control') !!}
                                {!! html()->hidden('key[]', $sub_key) !!}
                                @if($key == 'reference')
                                    {!! html()->label(__('message.' . $sub_key))->for('km_one')->class('control-label') !!}
                                    {!! html()->select('value[]', ['fixed' => __('message.fixed'), 'percentage' => __('message.percentage')], isset($data) ? $data->value : 'fixed')->class('form-control select2js') !!}
                                @elseif($key == 'reference_amount')
                                    {!! html()->label(__('message.' . $sub_key))->for($key . '_' . $sub_key)->class('control-label') !!}
                                    {!! html()->input($type, 'value[]', isset($data) ? $data->value : null)
                                        ->id($key . '_' . $sub_key)
                                        ->class('form-control form-control-lg')
                                        ->placeholder(str_replace('_', ' ', $sub_key))
                                        ->attributes($type == 'number' ? ['min' => 0, 'step' => 'any'] : []) !!}
                                @endif
                            </div>
                        </div>
                    @endforeach
                @endforeach
            </div>
        </div>
    </div>

{!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-right') !!}
{!! html()->form()->close() !!}
<script>
    $(document).ready(function() {
        $('.select2js').select2();
    });
</script>

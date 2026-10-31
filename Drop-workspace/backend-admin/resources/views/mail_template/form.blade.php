<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        {!! html()->form('POST', route('mail-template.store'))->open() !!}
        {!! html()->hidden('type', $type) !!}
            <div class="row">
                <div class="col-lg-12">
                    <div class="card border-radius-20">
                        <div class="card-header d-flex justify-content-between border-bottom-0"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                            <div class="header-title">
                                <h4 class="card-title">{{ $pageTitle ?? __('message.list') }}</h5>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-lg-12">
                    <div class="card border-radius-20">
                        <div class="card-body">
                            <div class="row">
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.subject'))->for('subject')->class('form-control-label') !!}
                                    {!! html()->text('subject', old('subject', $data->subject ?? null))->placeholder(__('message.subject'))->class('form-control')->required() !!}
                                </div>
                                <div class="form-group col-md-12">
                                    {!! html()->textarea('description', old('description', $data->description ?? null))->class('form-control tinymce-mail_description')->placeholder(__('message.mail_description')) !!}
                                </div>
                            </div>
                            {!! html()->button(__('message.save'))->type('submit')->class('btn btn-md btn-primary float-right') !!}
                             @if($type === 'self_billing_statement')
                                <small class="text-danger d-block mt-1">
                                    <strong>{{ __('message.mail_template_note') }} {{ '{' }}{Driver Name}{{ '}' }} { '{' }}{Week Start Date}{{ '}' }} { '{' }}{Week End Date}{{ '}' }} { '{' }}{Payout Amount}{{ '}' }} { '{' }}{Payment Method}{{ '}' }} { '{' }}{Payment Date }{{ '}' }} </strong>,
                                </small>
                            @endif
                        </div>
                    </div>
                </div>
            </div>
            {!! html()->form()->close() !!}
        </div>
    @section('bottom_script')
        <script>
            (function($) {
                $(document).ready(function(){
                    tinymceEditor('.tinymce-mail_description',' ',function (ed) {
                    }, 450)
                });
            })(jQuery);
        </script>
    @endsection
</x-master-layout>

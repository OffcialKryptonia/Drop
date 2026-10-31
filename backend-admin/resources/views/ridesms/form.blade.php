<x-master-layout :assets="$assets ?? []">
    <div class="container-fluid">
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data, 'PATCH', route('ridesms.update', $id))->open() !!}
        @else
            {!! html()->form('POST', route('ridesms.store'))->open() !!}
        @endif
        {!! html()->hidden('type', $rideType) !!}
        <div class="row">
            <div class="col-lg-12">
                    <div class="card card-block card-stretch">
                        <div class="card-body p-0">
                            <div class="d-flex justify-content-between align-items-center p-3">
                                <h5 class="font-weight-bold">{{ $pageTitle ?? __('message.list') }}</h5>
                            </div>
                        </div>
                    </div>
            </div>
            <div class="col-lg-12">
                <div class="card">
                    <div class="card-body">
                            <div class="row">
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.subject'))->for('subject')->class('form-control-label') !!}
                                    {!! html()->text('subject', old('subject', $data->subject ?? null))->placeholder(__('message.subject'))->class('form-control')->required() !!}
                                </div>
                                <div class="form-group col-md-12">
                                    {!! html()->label(__('message.description'))->for('sms_description')->class('form-control-label') !!}
                                    {!! html()->textarea('sms_description', old('sms_description', $data->sms_description ?? null))->class('form-control tinymce-sms_description')->placeholder(__('message.description')) !!}
                                </div>
                                <p class="note text-danger">
                                    *Note : {{ __('message.value_can_not_changes') }}
                                </p>
                            </div>
                            {!! html()->button(__('message.save'))->type('submit')->class('btn btn-md btn-primary float-right') !!}
                        {!! html()->form()->close() !!}
                    </div>
                </div>
            </div>
        </div>
    </div>
    @section('bottom_script')
        <script>
            (function($) {
                $(document).ready(function(){
                    tinymceEditor('.tinymce-sms_description',' ',function (ed) {
                    }, 450)
                });
            })(jQuery);
        </script>
    @endsection
</x-master-layout>
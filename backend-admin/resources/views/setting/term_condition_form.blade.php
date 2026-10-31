<x-master-layout>
<div class="container-fluid">
    <div class="row">
        <div class="col-lg-12 mt-3">
            <div class="card border-radius-20">
                <div class="card-body p-0">
                    <div class="d-flex justify-content-between align-items-center p-3">
                        <h5 class="font-weight-bold">{{ $pageTitle ?? __('message.list') }}</h5>
                    </div>
                </div>
            </div>
        </div>
        <div class="col-lg-12">
            <div class="card border-radius-20">
                <div class="card-body">
                    {!! html()->modelForm($setting_data , 'POST', route('term-condition-save'))->attribute('data-toggle', 'validator')->open() !!}
                    {!! html()->hidden('id') !!}
                        <div class="row">
                            <div class="form-group col-md-12">
                                {!! html()->label(__('message.terms_condition'))->for('terms_condition')->class('form-control-label') !!}
                                {!! html()->textarea('value', null)->class('form-control tinymce-terms_condition')->placeholder(__('message.terms_condition')) !!}
                            </div>
                        </div>
                        {!! html()->submit(__('message.save'))->class('btn border-radius-10 btn-primary float-right') !!}
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
                tinymceEditor('.tinymce-terms_condition',' ',function (ed) {

                }, 450)
            
            });

        })(jQuery);
    </script>
@endsection
</x-master-layout>
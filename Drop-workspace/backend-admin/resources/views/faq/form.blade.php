<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {{ html()->modelForm($data, 'PATCH', route('faqs.update', $id))->attribute('enctype', 'multipart/form-data')->id('faq_validation_form')->open() }}
        @else
            {{ html()->form('POST', route('faqs.store'))->attribute('enctype','multipart/form-data')->id('faq_validation_form')->open() }}
        @endif
        <div class="row">
            <div class="col-lg-12">
                <div class="card">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <div class="card-action">
                            <a href="{{ route('faqs.index') }} " class="btn btn-sm btn-primary" role="button">{{ __('message.back') }}</a>
                        </div>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="form-group col-md-6">
                                    {{ html()->label(__('message.type'))->class('form-control-label') }}
                                    {{ html()->select('type',['rider' => __('message.rider'),'driver' => __('message.driver'),],)->class('form-control select2js')->required() }}
                                </div>
                            </div>
                           
                            <div class="row">
                                <div class="form-group col-md-6">
                                    {{ html()->label(__('message.question') . ' <span class="text-danger">*</span>')->class('form-control-label') }}
                                    {{ html()->textarea('question')->class('form-control')->placeholder(__('message.question'))->rows(3)->cols(40) }}
                                </div>

                                <div class="form-group col-md-6">
                                    {{ html()->label(__('message.answer') . ' <span class="text-danger">*</span>')->class('form-control-label') }}
                                    {{ html()->textarea('answer')->class('form-control tinymce-description')->placeholder(__('message.answer'))->rows(3)->cols(40) }}
                                </div>
                            </div>
                            <hr>
                            {{ html()->submit( isset($data) ? __('message.update') : __('message.save'))->class('btn btn-md btn-primary float-right') }}
                        </div>
                    </div>
                </div>
            </div>
        </div>
        {{ html()->form()->close() }}   
    </div>
    @section('bottom_script')
        <script>
            $(document).ready(function(){
                formValidation("#faq_validation_form", {
                    question: { required: true },
                }, {
                    question: { required: "Please type a Question."},
                });
            });
        </script>
    @endsection
</x-master-layout>

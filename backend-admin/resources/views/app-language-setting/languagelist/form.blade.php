<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('languagelist.update', $id))->attribute('enctype', 'multipart/form-data')->open() !!}
        @else
            {!! html()->form('POST', route('languagelist.store'))->attribute('enctype','multipart/form-data')->open() !!}
        @endif
        <div class="row">
            <div class="col-lg-12 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <div class="card-action">
                            <a href="{{ route('languagelist.index') }} " class="float-right btn btn-sm border-radius-10 btn-primary me-2" role="button"><i class="fas fa-arrow-circle-left"></i> {{ __('message.back') }}</a>
                        </div>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.language_list') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('language_id')!!}
                                    {!! html()->select('language_id', isset($id) ? [optional($data->LanguageDefaultList)->id => optional($data->LanguageDefaultList)->languageName] : [])
                                        ->class('select2js form-group languagelist')
                                        ->id('language_id')
                                        ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.language')]))
                                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'languagelist']))
                                        ->required() !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.language_name') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('language_name')!!}
                                    {!! html()->text('language_name', old('language_name'))
                                        ->placeholder(__('message.language_name'))
                                        ->class('form-control')
                                        ->required() !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.country_code') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('country_code')!!}
                                    {!! html()->hidden('country_code', old('country_code'))->id('countryCodeHidden') !!}
                                    {!! html()->text('country_code', old('country_code'))
                                        ->placeholder(__('message.country_code'))
                                        ->class('form-control')
                                        ->required()
                                        ->id('countryCode')
                                        ->attribute('disabled', true)!!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.language_code') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('language_code')!!}
                                    {!! html()->hidden('language_code', old('language_code'))->id('languageCodeHidden') !!}
                                    {!! html()->text('language_code', old('language_code'))
                                        ->placeholder(__('message.language_code'))
                                        ->class('form-control')
                                        ->required()
                                        ->id('languageCode')
                                        ->attribute('disabled', true) !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.status') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('status')!!}
                                    {!! html()->select('status', ['1' => __('message.active'), '0' => __('message.inactive')], old('status'))->class('form-control select2js')->required() !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {{ html()->label(__('message.is_default'), 'is_default-1')->class('form-control-label') }}
                                    <div class="form-check">
                                        {!! html()->hidden('is_default', 0)->class('form-check-input') !!}
                                        {!! html()->checkbox('is_default', null, 1)->id('is_default-1')->class('form-check-input') !!}
                                    </div>
                                </div>
                                
                                <div class="form-group col-md-4">
                                    <label class="form-control-label" for="image">{{ __('message.image') }} </label>
                                    <div class="custom-file">
                                        <input type="file" name="language_image" class="custom-file-input" accept="image/*">
                                        <label class="custom-file-label">{{  __('message.choose_file',['file' =>  __('message.image') ]) }}</label>
                                    </div>
                                    <span class="selected_file"></span>
                                </div>
                                @if( isset($id) && getMediaFileExit($data, 'language_image'))
                                <div class="col-md-2 mb-2">
                                    <img id="language_image_preview" src="{{ getSingleMedia($data,'language_image') }}" alt="amenity-image" class="attachment-image mt-1">
                                    <a class="text-danger remove-file" href="{{ route('remove.file', ['id' => $data->id, 'type' => 'language_image']) }}"
                                        data--submit='confirm_form'
                                        data--confirmation='true'
                                        data--ajax='true'
                                        data-toggle='tooltip'
                                        title='{{ __("message.remove_file_title" , ["name" =>  __("message.image") ]) }}'
                                        data-title='{{ __("message.remove_file_title" , ["name" =>  __("message.image") ]) }}'
                                        data-message='{{ __("message.remove_file_msg") }}'>
                                        <i class="ri-close-circle-line"></i>
                                    </a>
                                </div>
                            @endif
                            </div>
                            <hr>
                            {!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-right') !!}
                        </div>
                    </div>
                </div>
            </div>
        </div>
        {!! html()->form()->close() !!}
    </div>
    @section('bottom_script')
    <script>
        (function ($) {
            $(document).ready(function () {
                $(document).on('change', '#language_id', function () {
                var sub = $(this).val();
                LanguageList(sub);
            });

        function LanguageList(sub) {          
            var LanguageRoute = "{{ route('ajax-list', ['type' => 'language-list-data']) }}";
            $.ajax({
                url: LanguageRoute,
                data: {
                    'id': sub,
                },
                success: function (result) {
                    if (result.results) {
                        if (sub != null) {
                            $("#countryCode").val(result.results.countryCode);
                            $("#languageCode").val(result.results.languageCode);
                            $("#countryCodeHidden").val(result.results.countryCode); 
                            $("#languageCodeHidden").val(result.results.languageCode); 
                            $("#language_name").val(result.results.languageName);

                        }
                    } else {
                        console.log("No results found.");
                    }
                }
            });
        }
    });
    })(jQuery);
      </script>
    @endsection
</x-master-layout>

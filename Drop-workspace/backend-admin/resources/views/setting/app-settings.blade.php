{!! html()->modelForm($settings, 'POST', route('saveAppDownload'))->attribute('enctype', 'multipart/form-data')->attribute('data-toggle', 'validator')->open() !!}

<div class="row">
    <div class="col-lg-6">
        <div class="form-group">
            <label for="" class="col-sm-6 form-control-label">{{ __('message.title') }}</label>
            <div class="col-sm-12">
                {!! html()->text('title')->class('form-control')->placeholder(__('message.title')) !!}
            </div>
        </div>
    </div>
    <div class="col-lg-6">
        <div class="form-group">
            <label for="" class="col-sm-6 form-control-label">{{ __('message.description') }}</label>
            <div class="col-sm-12">
                {{ html()->textarea('description', null)->class('form-control textarea')->rows(2)->placeholder(__('message.description')) }}
            </div>
        </div>
    </div>
    <div class="col-lg-6">
        <div class="form-group">
            <label for="" class="col-sm-6 form-control-label">{{ __('message.playstore_url') }}</label>
            <div class="col-sm-12">
                {!! html()->text('playstore_url')->class('form-control')->placeholder(__('message.playstore_url')) !!}
            </div>
        </div>
    </div>
    <div class="col-lg-6">
        <div class="form-group">
            <label for="" class="col-sm-6 form-control-label">{{ __('message.appstore_url') }}</label>
            <div class="col-sm-12">
                {!! html()->text('appstore_url')->class('form-control')->placeholder(__('message.appstore_url')) !!}
            </div>
        </div>
    </div>
    <div class="form-group">
        <label for="avatar" class="col-sm-3 form-control-label">{{ __('message.logo') }}</label>
        <div class="col-sm-12">
            <div class="row">
                <div class="col-sm-4">
                    <img src="{{ getSingleMedia($settings,'app_image') }}" width="100"  id="app_image_preview" alt="app_image" class="image app_image app_image_preview">
                    @if(getMediaFileExit($settings, 'app_image'))
                        <a class="text-danger remove-file" href="{{ route('remove.file', ['id' => $settings->id, 'type' => 'app_image']) }}"
                            data--submit="confirm_form"
                            data--confirmation='true'
                            data--ajax="true"
                            title='{{ __("message.remove_file_title" , ["name" =>  __("message.image") ]) }}'
                            data-title='{{ __("message.remove_file_title" , ["name" =>  __("message.image") ]) }}'
                            data-message='{{ __("message.remove_file_msg") }}'>
                            <i class="ri-close-circle-line"></i>
                        </a>
                    @endif
                </div>
                <div class="col-sm-8">
                    <div class="custom-file col-md-12">
                        {{ html()->file('app_image')->class('custom-file-input custom-file-input-sm detail')->id('app_image')->attribute('lang', 'en')->attribute('accept', 'image/*') }}
                        <label class="custom-file-label" for="app_image">{{ __('message.image') }}</label>
                    </div>
                </div>
            </div>

        </div>
    </div>
    <div class="col-lg-12"> 
        <div class="form-group">
            <div class="col-md-offset-3 col-sm-12 ">
                {!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-right') !!}
            </div>
        </div>
     </div>
</div>
{!! html()->form()->close() !!}
<?php $id = $id ?? null; ?>
@if (isset($id))
    {!! html()->modelForm($data,'PATCH', route('why-choose.update', $id))->attribute('enctype', 'multipart/form-data')->open() !!}
@else
    {!! html()->form('POST', route('why-choose.store'))->attribute('enctype','multipart/form-data')->open() !!}
@endif

<div class="modal-dialog modal-dialog-centered modal-xl" role="document">
    <div class="modal-content">
        <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLabel">{{ __($pageTitle) }}</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
        </div>
        <div class="modal-body">
            <div class="form-group col-md-12">
                {!! html()->label(__('message.title') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('title') !!}
                {!! html()->text('title', old('title'))->class('form-control')->placeholder(__('message.title'))->required() !!}
            </div>
            
            <div class="form-group col-md-12">
                {!! html()->label(__('message.description') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('description') !!}
                {!! html()->textarea('description', old('description'))->class('form-control textaraea')->rows(2)->placeholder(__('message.description')) !!}
            </div>
            
            <div class="row ml-1">
                <div class="form-group col-md-4">
                    {!! html()->label(__('message.image'))->class('form-control-label')->for('frontend_data_image') !!}
                    <div class="custom-file">
                        {!! html()->file('frontend_data_image')->class('custom-file-input')->id('frontend_data_image')->attribute('lang', 'en')->attribute('accept', 'image/*') !!}
                        <label class="custom-file-label" for="frontend_data_image">{{ __('message.choose_file', ['file' => __('message.image')]) }}</label>
                    </div>
                </div>
                <div class="col-md-2 mb-2">
                    @if (isset($id) && getMediaFileExit($data, 'frontend_data_image'))
                        <img src="{{ getSingleMedia($data, 'frontend_data_image') }}" alt="image" class="attachment-image mt-1 rounded-circle img-fluid avatar-50">
                    @endif
                </div>
            </div>
        </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-md btn-secondary" data-dismiss="modal">{{ __('message.close') }}</button>
                <button type="submit" class="btn btn-md btn-primary" id="btn_submit" data-form="ajax">{{ isset($id) ? __('message.update') : __('message.save') }}</button>
            </div>
        </div>
    </div>
{!! html()->form()->close() !!}


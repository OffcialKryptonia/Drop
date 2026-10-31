<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('driverdocument.update', $id))->attribute('enctype', 'multipart/form-data')->open() !!}
        @else
            {!! html()->form('POST', route('driverdocument.store'))->attribute('enctype', 'multipart/form-data')->open() !!}
        @endif
        <div class="row">
            <div class="col-lg-12 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <a href="{{route('driverdocument.index')}}" class="float-right btn btn-sm border-radius-10 btn-primary me-2" role="button"><i class="fas fa-arrow-circle-left"></i> {{ __('message.back') }}</a>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                @if(auth()->user()->hasAnyRole(['admin','demo_admin']))
                                    <div class="form-group col-md-4">
                                        {!! html()->label(__('message.select_name', ['select' => __('message.driver')]) . ' <span class="text-danger">*</span>')->class('form-control-label')->for('driver_id') !!}
                                        {!! html()->select('driver_id', isset($id) ? [optional($data->driver)->id => optional($data->driver)->display_name] : [], old('driver_id'))->class('select2js form-group driver')->required()
                                            ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.driver')]))
                                            ->attribute('data-ajax--url', route('ajax-list', ['type' => 'driver', 'status' => 'pending'])) !!}
                                    </div>
                                @endif

                                @if(auth()->user()->hasRole('fleet'))
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.select_name', ['select' => __('message.driver')]) . ' <span class="text-danger">*</span>')->class('form-control-label')->for('driver_id') !!}
                                    {!! html()->select('driver_id', isset($id) ? [optional($data->driver)->id => optional($data->driver)->display_name] : [], old('driver_id'))
                                        ->class('select2js form-group driver')
                                        ->required()
                                        ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.driver')]))
                                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'driver', 'fleet_id' => auth()->user()->id, 'status' => 'pending'])) !!}
                                </div>
                                @endif

                                @php
                                    $is_required = isset($id) && optional($data->document)->is_required == 1 ? '*' : '';
                                    $has_expiry_date = isset($id) && optional($data->document)->has_expiry_date == 1 ? 1 : '';
                                @endphp

                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.select_name', ['select' => __('message.document')]) . ' <span class="text-danger">* </span>')
                                        ->class('form-control-label')
                                        ->for('document_id') !!}

                                    {!! html()->select('document_id', isset($id) ? [optional($data->document)->id => optional($data->document)->name . " " . $is_required] : [], old('document_id'))
                                        ->class('select2js form-group document_id')
                                        ->id('document_id')
                                        ->required()
                                        ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.document')]))
                                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'document'])) !!}
                                </div>

                                <div class="form-group col-md-4">
                                    <label class="form-control-label" for="expire_date">{{ __('message.expire_date') }} <span class="text-danger" id="has_expiry_date">{{ $has_expiry_date == 1 ? '*' : ''  }}</span> </label>
                                    {!! html()->text('expire_date', old('expire_date'))->class('form-control min-datepicker')->placeholder(__('message.expire_date')) ->required($has_expiry_date == 1) !!}

                                </div>
                                
                                @if(auth()->user()->hasAnyRole(['admin','demo_admin']))
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.is_verify') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('is_verified') !!}
                                    {!! html()->select('is_verified', [
                                            '0' => __('message.pending'), 
                                            '1' => __('message.approved'), 
                                            '2' => __('message.rejected')
                                        ], old('is_verified'))->class('form-control select2js')->id('is_verified')->required() !!}
                                </div>
                                @endif

                                <div class="form-group col-md-4">
                                    <label class="form-control-label" for="driver_document">{{ __('message.upload_document') }} <span class="text-danger" id="document_required"></span> </label>
                                    <div class="custom-file">
                                        <input type="file" id="driver_document" name="driver_document" class="custom-file-input" >
                                        <label class="custom-file-label">{{ __('message.choose_file', [ 'file' => __('message.document') ]) }}</label>
                                    </div>
                                    <span class="selected_file"></span>
                                </div>
                                @if( isset($id) && getMediaFileExit($data, 'driver_document'))
                                    <div class="col-md-2 mb-2">
                                        <?php
                                            $file_extention = config('constant.IMAGE_EXTENTIONS');
                                            $image = getSingleMedia($data,'driver_document');
                                            
                                            $extention = in_array(strtolower(imageExtention($image)),$file_extention);
                                        ?>
                                            @if($extention)   
                                                <img id="driver_document_preview" src="{{ $image }}" alt="#" class="attachment-image mt-1" >
                                            @else
                                                <img id="driver_document_preview" src="{{ asset('images/file.png') }}" class="attachment-file">
                                            @endif
                                            <a class="text-danger remove-file" href="{{ route('remove.file', ['id' => $data->id, 'type' => 'driver_document']) }}"
                                                data--submit="confirm_form"
                                                data--confirmation='true'
                                                data--ajax="true"
                                                title='{{ __("message.remove_file_title" , ["name" =>  __("message.image") ]) }}'
                                                data-title='{{ __("message.remove_file_title" , ["name" =>  __("message.image") ]) }}'
                                                data-message='{{ __("message.remove_file_msg") }}'>
                                                <i class="ri-close-circle-line"></i>
                                            </a>
                                            <a href="{{ $image }}" class="d-block mt-2" download target="_blank"><i class="fas fa-download "></i> {{ __('message.download') }}</a>
                                    </div>
                                @endif
                            </div>
                            <hr>
                            {!! html()->submit(__('message.save'))->class('btn border-radius-10 btn-primary float-right') !!}
                        </div>
                    </div>
                </div>
            </div>
        </div>
        {!! html()->form()->close() !!}
    </div>
    @section('bottom_script')
        <script type="text/javascript">
            (function($) {
                "use strict";
                    $(document).ready(function(){ 
                        $(document).on('change' , '#document_id' , function (){
                            var data = $('#document_id').select2('data')[0];

                            if(data.is_required == 1)
                            {
                                $('#document_required').text('*');
                                $('#driver_document').attr('required');
                            } else {
                                $('#document_required').text('');
                                $('#driver_document').attr('required', false);
                            }

                            if(data.has_expiry_date == 1)
                            {
                                $('#has_expiry_date').text('*');
                                $('#expire_date').attr('required');
                            } else {
                                $('#has_expiry_date').text('');
                                $('#expire_date').attr('required', false);
                            }
                        })
                    })
            })(jQuery);
        </script>
    @endsection
</x-master-layout>

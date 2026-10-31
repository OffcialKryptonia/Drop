<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('complaint.update', $id))->attribute('enctype', 'multipart/form-data')->open() !!}
        @else
            {!! html()->form('POST', route('complaint.store'))->attribute('enctype', 'multipart/form-data')->open() !!}
        @endif
        <div class="row">
            <div class="col-lg-12">
                <div class="card">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <a href="{{route('complaint.index')}}" class="float-right btn btn-sm border-radius-10 btn-primary me-2" role="button"><i class="fas fa-arrow-circle-left"></i> {{ __('message.back') }}</a>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="row">
                                    <div class="col-md-4">
                                        {!! html()->label(__('message.subject') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('subject') !!}
                                        {!! html()->text('subject', old('subject'))->class('form-control')->placeholder(__('message.subject'))->required() !!}
                                    </div>
                                
                                    <div class="col-md-4">
                                        {!! html()->label(__('message.riderequest'))->class('form-control-label')->for('ride_request_id') !!}
                                        {!! html()->select('ride_request_id', isset($id) ? [ $data->ride_request_id => '#'.$data->ride_request_id ] : [], old('ride_request_id'))
                                            ->class('form-control select2js')
                                            ->id('ride_request_id')
                                            ->attribute('data-ajax--url', route('ajax-list', [ 'type' => 'riderequest' ]))
                                            ->attribute('data-placeholder', __('message.select_field', [ 'name' => __('message.riderequest') ]))
                                            ->required() !!}
                                    </div>
                                
                                    <div class="col-md-4">
                                        {!! html()->label(__('message.rider'))->class('form-control-label')->for('rider_id') !!}
                                        <p class="p-2 border border-radius-10 badge-light-secondary" id="rider_name">
                                            <span class="p-2">{{ isset($id) ? optional($data->rider)->display_name : '-' }}</span>
                                        </p>
                                    </div>
                                
                                    <div class="col-md-4">
                                        {!! html()->label(__('message.driver'))->class('form-control-label')->for('driver_id') !!}
                                        <p class="p-2 border border-radius-10 badge-light-secondary" id="driver_name">
                                            {{ isset($id) ? optional($data->driver)->display_name : '-' }}
                                        </p>
                                    </div>
                                
                                    <div class="col-md-4">
                                        {!! html()->label(__('message.complaint_by') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('complaint_by') !!}
                                        {!! html()->select('complaint_by', [
                                                'rider' => __('message.rider'),
                                                'driver' => __('message.driver')
                                            ], old('complaint_by'))
                                            ->class('form-control select2js')
                                            ->required() !!}
                                    </div>
                                
                                    <div class="col-md-4">
                                        {!! html()->label(__('message.status'))->class('form-control-label')->for('status') !!}
                                        {!! html()->select('status', [
                                                'pending' => __('message.pending'),
                                                'resolved' => __('message.resolved'),
                                                'investigation' => __('message.investigation')
                                            ], old('status'))
                                            ->class('form-control select2js')
                                            ->required() !!}
                                    </div>
                                
                                    <div class="col-md-6">
                                        {!! html()->label(__('message.description'))->class('form-control-label')->for('description') !!}
                                        {!! html()->textarea('description', old('description'))
                                            ->class('form-control textarea')
                                            ->attribute('rows', 3)
                                            ->placeholder(__('message.description')) !!}
                                    </div>
                                </div>
                                
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
        <script>
            $(document).ready(function() {                
                $('#ride_request_id').on('select2:select', function (e) {
                    let data = e.params.data;

                    $('#rider_name').text( data.rider['display_name'] )
                    if( data.driver_id != null ) {
                        $('#driver_name').text( data.driver['display_name'] )
                    } else {
                        $('#driver_name').text('-');
                    }
                });
            });
        </script>
    @endsection
</x-master-layout>

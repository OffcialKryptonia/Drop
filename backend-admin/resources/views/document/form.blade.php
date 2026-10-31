<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('document.update', $id))->open() !!}
        @else
            {!! html()->form('POST', route('document.store'))->open() !!}
        @endif
        <div class="row">
            <div class="col-lg-12 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <a href="{{route('document.index')}}" class="float-right btn btn-sm border-radius-10 btn-primary me-2" role="button"><i class="fas fa-arrow-circle-left"></i> {{ __('message.back') }}</a>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.name') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('name') !!}
                                    {!! html()->text('name', old('name'))->placeholder(__('message.name'))->class('form-control')->required() !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.is_required'))->class('form-control-label')->for('is_required') !!}
                                    {!! html()->select('is_required', ['0' => __('message.no'), '1' => __('message.yes')], old('is_required'))->class('form-control select2js')->required() !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.has_expiry_date'))->class('form-control-label')->for('has_expiry_date') !!}
                                    {!! html()->select('has_expiry_date', ['0' => __('message.no'), '1' => __('message.yes')], old('has_expiry_date'))->class('form-control select2js')->required() !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.status'))->class('form-control-label')->for('status') !!}
                                    {!! html()->select('status', ['1' => __('message.active'), '0' => __('message.inactive')], old('status'))->class('form-control select2js')->required() !!}
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
    @endsection
</x-master-layout>

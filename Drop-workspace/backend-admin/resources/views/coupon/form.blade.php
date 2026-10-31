<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('coupon.update', $id))->open() !!}
        @else
            {!! html()->form('POST', route('coupon.store'))->open() !!}
        @endif
        <div class="row">
            <div class="col-lg-12 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <a href="{{route('coupon.index')}}" class="float-right btn btn-sm border-radius-10 btn-primary me-2" role="button"><i class="fas fa-arrow-circle-left"></i> {{ __('message.back') }}</a>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.code').' <span class="text-danger">*</span>')->for('code')->class('form-control-label') !!}

                                    @if(!isset($id))
                                        {!! html()->text('code',old('code'))->placeholder(__('message.code'))->class('form-control')->required() !!}
                                    @else
                                    <p>{{ $data->code }}</p>
                                    @endif
                                </div>

                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.title').' <span class="text-danger">*</span>')->for('title')->class('form-control-label') !!}
                                    {!! html()->text('title',old('title'))->placeholder(__('message.title'))->class('form-control')->required() !!}
                                </div>

                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.coupon_type') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('coupon_type') !!}
                                    {!! html()->select('coupon_type', [
                                            'all' => __('message.all'),
                                            'first_ride' => __('message.first_ride'),
                                            'region_wise' => __('message.region_wise'),
                                            'service_wise' => __('message.service_wise')
                                        ], old('coupon_type'))->class('form-control select2js')->required() !!}
                                </div>
                                
                                <!-- Region List Multiple -->
                                <div class="form-group col-md-4 region_list">
                                    {!! html()->label(__('message.select_name', ['select' => __('message.region')]))->class('form-control-label')->for('region_ids') !!}
                                    <br/>
                                    {!! html()->select('region_ids[]', $selected_region, old('region_ids', $data->region_ids ?? []))->class('select2js form-group region')
                                        ->multiple()
                                        ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.region')]))
                                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'region'])) !!}
                                </div>
                                
                                <!-- Service List -->
                                <div class="form-group col-md-4 service_list">
                                    {!! html()->label(__('message.select_name', ['select' => __('message.service')]))->class('form-control-label')->for('service_ids') !!}
                                    <br/>
                                    {!! html()->select('service_ids[]', $selected_service, old('service_ids', $data->service_ids ?? []))->class('select2js form-group service')
                                        ->multiple()
                                        ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.service')]))
                                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'service'])) !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.usage_limit_per_rider'))->class('form-control-label')->for('usage_limit_per_rider') !!}
                                    {!! html()->number('usage_limit_per_rider', old('usage_limit_per_rider'))->class('form-control')->attribute('min', 0)->placeholder(__('message.usage_limit_per_rider')) !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.start_date'))->class('form-control-label')->for('start_date') !!}
                                    {!! html()->text('start_date', old('start_date'))->class('form-control min-daterange-picker')->placeholder(__('message.start_date')) !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.end_date'))->class('form-control-label')->for('end_date') !!}
                                    {!! html()->text('end_date', old('end_date'))->class('form-control min-daterange-picker')->placeholder(__('message.end_date')) !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.discount_type'))->class('form-control-label')->for('discount_type') !!}
                                    {!! html()->select('discount_type', [
                                            'fixed' => __('message.fixed'),
                                            'percentage' => __('message.percentage')
                                        ], old('discount_type'))->class('form-control select2js')->required() !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.discount') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('discount') !!}
                                    {!! html()->number('discount', old('discount'))->class('form-control')->attribute('min', 0)->attribute('step', 'any')->required()->placeholder(__('message.discount')) !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.minimum_amount') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('minimum_amount') !!}
                                    {!! html()->number('minimum_amount', old('minimum_amount'))->class('form-control')->attribute('min', 0)->attribute('step', 'any')->required()->placeholder(__('message.minimum_amount')) !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.maximum_discount') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('maximum_discount') !!}
                                    {!! html()->number('maximum_discount', old('maximum_discount'))->class('form-control')->attribute('min', 0)->attribute('step', 'any')->required()->placeholder(__('message.maximum_discount')) !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.status') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('status') !!}
                                    {!! html()->select('status', [
                                            '1' => __('message.active'),
                                            '0' => __('message.inactive')
                                        ], old('status'))->class('form-control select2js')->required() !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.description'))->class('form-control-label')->for('description') !!}
                                    {!! html()->textarea('description')->class('form-control textarea')->attribute('rows', 3)->placeholder(__('message.description')) !!}
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
                selected_coupon_type = $('#coupon_type :selected').val();
                changeCouponType(selected_coupon_type);
                $('#coupon_type').on('select2:select', function (e) {
                    var coupon_type = $(this).val();
                    changeCouponType(coupon_type);
                });
            });

            function changeCouponType(type='all') {

                switch(type) {
                    case 'region_wise':
                        $(document).find('.region_list').removeClass('d-none');
                        $(document).find('.service_list').addClass('d-none');
                        $(document).find('#usage_limit_per_rider').removeAttr('readonly');
                        break;
                    case 'service_wise':
                        $(document).find('.service_list').removeClass('d-none');
                        $(document).find('.region_list').addClass('d-none');
                        $(document).find('#usage_limit_per_rider').removeAttr('readonly');
                        break;
                    case 'first_ride':
                        $(document).find('.service_list').addClass('d-none');
                        $(document).find('.region_list').addClass('d-none');
                        $(document).find('#usage_limit_per_rider').val(1);
                        $(document).find('#usage_limit_per_rider').attr('readonly','true');
                        break;
                    default:
                        $(document).find('#usage_limit_per_rider').removeAttr('readonly')
                        $(document).find('.service_list').addClass('d-none');
                        $(document).find('.region_list').addClass('d-none');
                }
            }
        </script>
    @endsection
</x-master-layout>

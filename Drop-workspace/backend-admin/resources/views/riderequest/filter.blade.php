<div class="modal fade fixed-right" id="filterModal" tabindex="-1" aria-labelledby="filterModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-aside">
        <div class="modal-content h-100">
            <div class="modal-header">
                <h5 class="modal-title" id="filterModalLabel">{{ __('message.filter') }}</h5>
                <a href="javascript:void();" data-bs-dismiss="modal" aria-label="Close"><i class="ri-close-circle-fill" style="font-size: 25px"></i></a>
            </div>
            <div class="modal-body">
                {!! html()->form('GET')->id('riderequest-filter-form')->open() !!}
                    <div class="row mb-3">
                        <div class="col-lg-6">
                            {!! html()->label(__('message.start_date'))->class('form-control-label')->for('start_date') !!}
                            {!! html()->text('start_date', old('start_date'))->class('form-control min-datepickerall')->placeholder(__('message.start_date')) !!}
                        </div>
                    
                        <div class="col-lg-6">
                            {!! html()->label(__('message.end_date'))->class('form-control-label')->for('end_date') !!}
                            {!! html()->text('end_date', old('end_date'))->class('form-control min-datepickerall')->placeholder(__('message.end_date')) !!}
                        </div>
                    </div>
                     <div class="form-group mb-3">
                        {!! html()->label(__('message.trip_type'))->class('form-label')->for('trip_type') !!}
                        {!! html()->select('trip_type', [
                                '' => '',
                                'regular' => __('message.regular'),
                                'airport_pickup' => __('message.airport_pickup'),
                                'airport_drop' => __('message.airport_drop'),
                                'zone_wise' => __('message.zone_wise'),
                                'zone_to_airport' => __('message.zone_to_airport'),
                                'airport_to_zone' => __('message.airport_to_zone')
                            ], request('trip_type'))
                            ->class('form-control select2')
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.trip_type')]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.rider'))->class('form-label')->for('rider_id') !!}
                        {!! html()->select('rider_id', request('rider_id'), [])
                            ->class('form-control select2')
                            ->attribute('data-ajax--url', route('ajax-list', ['type' => 'rider']))
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.rider')]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.driver'))->class('form-label')->for('driver_id') !!}
                        {!! html()->select('driver_id', request('driver_id'), [])
                            ->class('form-control select2')
                            ->attribute('data-ajax--url', route('ajax-list', ['type' => 'driver']))
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.driver')]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.payment_status_message'))->class('form-label')->for('payment_status') !!}
                        {!! html()->select('payment_status', [
                                '' => '',
                                'paid' => __('message.paid'),
                                'pending' => __('message.pending'),
                                'failed' => __('message.failed')
                            ], request('payment_status'))
                            ->class('form-control select2')
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.payment_status_message')]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.payment_method'))->class('form-label')->for('payment_method') !!}
                        {!! html()->select('payment_method', [
                                '' => '',
                                'cash' => __('message.cash'),
                                'wallet' => __('message.wallet')
                            ], request('payment_method'))
                            ->class('form-control select2')
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.payment_method')]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.status'))->class('form-label')->for('ride_status') !!}
                        {!! html()->select('ride_status', ['' => ''] + rideStatus(), request('ride_status'))
                            ->class('form-control select2')
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.status')]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.ride_bid'))->class('form-label')->for('ride_bid') !!}
                        {!! html()->select('ride_bid', [
                                '' => '',
                                '1' => __('message.yes'),
                                '0' => __('message.no')
                            ], request('ride_bid'))
                            ->class('form-control select2')
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.ride_bid')]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    
            </div>
                <div class="modal-footer">
                    <button id="reset-filter-btn" type="button" class="btn btn-warning btn-sm border-radius-10 me-2 text-decoration-none">
                        {{ __('message.reset_filter') }}
                    </button>
                    <button type="submit" class="btn btn-primary btn-sm border-radius-10">{{ __('message.apply_filter') }}</button>
                </div>
            {!! html()->form()->close() !!}
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js" integrity="sha512-v2CJ7UaYy4JwqLDIrZUI/4hqeoQieOmAZNXBeQyjo21dadnwR+8ZaIJVT8EE2iyI61OV8e6M8PP2/4hpQINQ/g==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
<script>
    $(document).ready(function() {
        $('#riderequest-filter-form').on('submit', function(e) {
            e.preventDefault();

            $('#start-date-error').text('');
            $('#end-date-error').text('');

            const startDate = $('#start_date').val();
            const endDate = $('#end_date').val();
            let hasError = false;

            if (startDate && endDate) {
                const start = new Date(startDate);
                const end = new Date(endDate);

                if (start > end) {
                    $('#end-date-error').text("End date must be after start date.");
                    hasError = true;
                }
            }

            if (hasError) return;

            const formData = $(this).serialize();
            const table = $('#dataTableBuilder').DataTable();
            table.ajax.url('{{ route('riderequest.index') }}?' + formData).load();
        });

        $('#reset-filter-btn').on('click', function() {
            $('#start_date').val('').trigger('change');
            $('#end_date').val('').trigger('change');
            $('#trip_type').val('').trigger('change');
            $('#rider_id').val('').trigger('change');
            $('#driver_id').val('').trigger('change');
            $('#payment_status').val('').trigger('change');
            $('#payment_method').val('').trigger('change');
            $('#ride_status').val('').trigger('change');
            $('#ride_bid').val('').trigger('change');

            $('#start-date-error').text('');
            $('#end-date-error').text('');

            const table = $('#dataTableBuilder').DataTable();
            table.ajax.url('{{ route('riderequest.index') }}').load();
        });
    });
</script>
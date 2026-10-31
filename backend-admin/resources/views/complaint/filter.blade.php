<div class="modal fade fixed-right" id="filterModal" tabindex="-1" aria-labelledby="filterModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-aside">
        <div class="modal-content h-100">
            <div class="modal-header">
                <h5 class="modal-title" id="filterModalLabel">{{ __('message.filter') }}</h5>
                <a href="javascript:void();" data-bs-dismiss="modal" aria-label="Close"><i class="ri-close-circle-fill" style="font-size: 25px"></i></a>
            </div>
            <div class="modal-body">
                {!! html()->form('GET')->id('complaint-filter-form')->open() !!}
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.rider'))->class('form-label')->for('rider_id') !!}
                        {!! html()->select('rider_id', [], request('rider_id'))
                            ->class('form-control select2')
                            ->attribute('data-ajax--url', route('ajax-list', [ 'type' => 'rider' ]))
                            ->attribute('data-placeholder', __('message.select_field', [ 'name' => __('message.rider') ]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.driver'))->class('form-label')->for('driver_id') !!}
                        {!! html()->select('driver_id', [], request('driver_id'))
                            ->class('form-control select2')
                            ->attribute('data-ajax--url', route('ajax-list', [ 'type' => 'driver' ]))
                            ->attribute('data-placeholder', __('message.select_field', [ 'name' => __('message.driver') ]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.complaint_by'))->class('form-label')->for('complaint_by') !!}
                        {!! html()->select('complaint_by', [
                                '' => '',
                                'rider' => __('message.rider'),
                                'driver' => __('message.driver')
                            ], request('complaint_by'))
                            ->class('form-control select2')
                            ->attribute('data-placeholder', __('message.select_field', [ 'name' => __('message.complaint_by') ]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.status'))->class('form-label')->for('status') !!}
                        {!! html()->select('status', [
                                '' => '',
                                'pending' => __('message.pending'),
                                'investigation' => __('message.investigation'),
                                'resolved' => __('message.resolved')
                            ], request('status'))
                            ->class('form-control select2')
                            ->attribute('data-placeholder', __('message.select_field', [ 'name' => __('message.status') ]))
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
        $('#complaint-filter-form').on('submit', function(e) {
            e.preventDefault();
            var formData = $(this).serialize();
            var table = $('#dataTableBuilder').DataTable();
            table.ajax.url('{{ route("complaint.index") }}?' + formData).load();
        });

        $('#reset-filter-btn').on('click', function() {
            $('#rider_id').val('').trigger('change');
            $('#driver_id').val('').trigger('change');
            $('#complaint_by').val('').trigger('change');
            $('#status').val('').trigger('change');
            var table = $('#dataTableBuilder').DataTable();
            table.ajax.url('{{ route("complaint.index") }}').load();
        });
    });
</script>
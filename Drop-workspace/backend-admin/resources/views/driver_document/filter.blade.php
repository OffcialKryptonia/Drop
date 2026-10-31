<div class="modal fade fixed-right" id="filterModal" tabindex="-1" aria-labelledby="filterModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-aside">
        <div class="modal-content h-100">
            <div class="modal-header">
                <h5 class="modal-title" id="filterModalLabel">{{ __('message.filter') }}</h5>
                <a href="javascript:void();" data-bs-dismiss="modal" aria-label="Close"><i class="ri-close-circle-fill" style="font-size: 25px"></i></a>
            </div>
            <div class="modal-body">
                {!! html()->form('GET')->id('driver-doc-filter-form')->open() !!}
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.driver'))->class('form-label')->for('driver_id') !!}
                        {!! html()->select('driver_id', [], request('driver_id'))
                            ->class('form-control select2')
                            ->attribute('data-ajax--url', route('ajax-list', ['type' => 'driver']))
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.driver')]))
                            ->attribute('data-allow-clear', 'true')
                        !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.document'))->class('form-label')->for('document_id') !!}
                        {!! html()->select('document_id', [], request('document_id'))
                            ->class('form-control select2')
                            ->attribute('data-ajax--url', route('ajax-list', ['type' => 'document']))
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.document')]))
                            ->attribute('data-allow-clear', 'true')
                        !!}
                    </div>
                    
                    <div class="form-group mb-3">
                        {!! html()->label(__('message.is_verify'))->class('form-label')->for('is_verified') !!}
                        {!! html()->select('is_verified', ['' => '', '0' => __('message.pending'), '1' => __('message.approved'), '2' => __('message.rejected')], request('is_verified'))
                            ->class('form-control select2')
                            ->id('is_verified')
                            ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.is_verify')]))
                            ->attribute('data-allow-clear', 'true')
                        !!}
                    </div>
                    
                    
            </div>
                <div class="modal-footer">
                    <button id="reset-filter-btn" type="button" class="btn btn-warning border-radius-10 text-dark me-2 text-decoration-none">
                        {{ __('message.reset_filter') }}
                    </button>
                    <button type="submit" class="btn btn-primary">{{ __('message.apply_filter') }}</button>
                </div>
            {!! html()->form()->close() !!}
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js" integrity="sha512-v2CJ7UaYy4JwqLDIrZUI/4hqeoQieOmAZNXBeQyjo21dadnwR+8ZaIJVT8EE2iyI61OV8e6M8PP2/4hpQINQ/g==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
<script>
    $(document).ready(function() {
        $('#driver-doc-filter-form').on('submit', function(e) {
            e.preventDefault();
            var formData = $(this).serialize();
            var table = $('#dataTableBuilder').DataTable();
            table.ajax.url('{{ route("driverdocument.index") }}?' + formData).load();
        });

        $('#reset-filter-btn').on('click', function() {
            $('#driver_id').val('').trigger('change');
            $('#document_id').val('').trigger('change');
            $('#is_verified').val('').trigger('change');
            var table = $('#dataTableBuilder').DataTable();
            table.ajax.url('{{ route("driverdocument.index") }}').load();
        });
    });
</script>
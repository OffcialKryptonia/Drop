{!! html()->form('GET')->id('admin_report_filter_form') !!}
    <div class="modal fade" id="filterModal" tabindex="-1" aria-labelledby="filterModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-end">
            <div class="modal-content h-100">
                <div class="modal-header">
                    <h5 class="modal-title">{{ __('message.filter') }}</h5>
                    <a href="javascript:void();" data-bs-dismiss="modal" aria-label="Close"><i class="ri-close-circle-fill" style="font-size: 25px"></i></a>
                </div>
                <div class="modal-body">
                    <div class="row g-3 mb-3">
                        <div class="col-md-6">
                            {!! html()->label(__('message.from') . '<span class="text-danger">*</span>')->for('from_date')->class('form-control-label') !!}
                            {!! html()->date('from_date', $params['from_date'] ?? request('from_date'))->placeholder(__('message.date'))->class('form-control datepicker select2Clear')->id('from_date_main') !!}
                        </div>
                        <div class="col-md-6">
                            {!! html()->label(__('message.to') . ' <span class="text-danger">*</span>')->for('to_date')->class('form-control-label') !!}
                            {!! html()->date('to_date', $params['to_date'] ?? request('to_date'))->placeholder(__('message.date'))->class('form-control datepicker select2Clear')->id('to_date_main') !!}
                        </div>
                    </div>
                    <div class="row mt-1">
                        <div class="col-md-12 mt-1">
                            {!! html()->label(__('message.driver'))->class('form-control-label')->for('driver_id') !!}
                            {!! html()->select('driver_id', [], request('driver_id'))
                                ->class('form-control select2')
                                ->attribute('data-ajax--url', route('ajax-list', ['type' => 'driver']))
                                ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.driver')]))
                                ->attribute('data-allow-clear', 'true') !!}
                       </div>
                    </div>
                </div>

                <div class="modal-footer">
                    <button id="reset-filter-btn" type="button" class="btn btn-warning border-radius-10 text-dark me-2 text-decoration-none">
                        {{ __('message.reset_filter') }}
                    </button>
                    <button type="submit" class="btn btn-dark border-radius-10">{{ __('message.apply_filter') }}</button>
                </div>
            </div>
        </div>
    </div>
    {!! html()->form()->close() !!}
<x-master-layout :assets="$assets ?? []">
    <div class="container-fluid">
        <div class="row">
            <div class="col-lg-12">
                <div class="card card-block card-stretch card-height border-radius-20">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title mb-0">{{ $pageTitle ?? ''}}</h4>
                        </div>

                        <div class="d-flex">
                            <div class="me-2">
                                {!! $button !!}
                            </div>
                            <button id="filterToggle" class="float-right btn btn-sm border-radius-10 btn-warning ml-2 mr-2" type="button" data-bs-toggle="modal" data-bs-target="#filterModal">
                                <i class="fas fa-filter"></i> {{ __('message.filter') }}
                            </button>
                            <button id="exportToggle" class="float-right btn btn-sm border-radius-10 btn-primary me-2"
                                type="button" data-bs-toggle="modal" data-bs-target="#exportModal">
                                <i class="fas fa-file-export"></i> {{ __('message.export') }}
                            </button>
                        </div>
                    </div>
                    <div class="card-body">
                        {{ $dataTable->table(['class' => 'table table table-hover  w-100'],false) }}
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="modal fade fixed-right" id="filterModal" tabindex="-1" aria-labelledby="filterModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-aside">
            <div class="modal-content h-100">
                <div class="modal-header">
                    <h5 class="modal-title" id="filterModalLabel">{{ __('message.filter') }}</h5>
                    <a href="javascript:void();" data-bs-dismiss="modal" aria-label="Close"><i class="ri-close-circle-fill" style="font-size: 25px"></i></a>
                </div>
                <div class="modal-body">
                    {!! html()->form('GET')->id('rider-filter-form')->open() !!}

                    <div class="form-group mb-3">
                        {!! html()->label(__('message.rider'))
                            ->class('form-label')
                            ->for('rider_id') !!}
                        {!! html()->select('rider_id', [], request('rider_id'))
                            ->class('form-control select2')
                            ->attribute('data-ajax--url', route('ajax-list', [ 'type' => 'rider' ]))
                            ->attribute('data-placeholder', __('message.select_field', [ 'name' => __('message.rider') ]))
                            ->attribute('data-allow-clear', 'true') !!}
                    </div>

                    <div class="form-group">
                        {!! html()->label(__('message.status') .
                            '<span data-toggle="tooltip" data-html="true" data-placement="top" title="Active user: Who last activated date in 1 day<br>Engaged user: Who last activated date in 2-15 days<br>Inactive user: Who last activated date in more than 15 days">(info)</span>',
                            'last_actived_at')
                            ->class('form-control-label') !!}

                        {!! html()->select('last_actived_at', [
                                '' => __('message.all'),
                                'active_user' => __('message.active_user'),
                                'engaged_user' => __('message.engaged_user'),
                                'inactive_user' => __('message.inactive_user')
                            ], $last_actived_at ?? [])
                            ->class('form-control select2js')
                            ->attribute('data-allow-clear', 'true')
                            ->id('last_active') !!}
                    </div>

                    <div class="form-group mb-3">
                        {!! html()->label(__('message.contact_number'))
                            ->class('form-label')
                            ->for('contact_number') !!}

                        {!! html()->number('contact_number', request('contact_number'))
                            ->class('form-control')
                            ->attribute('data-placeholder', __('message.please_enter_contact_number'))
                            ->attribute('data-allow-clear', 'true')
                            ->id('contact_number') !!}
                    </div>

                    <div class="form-group mb-3">
                        {!! html()->label(__('message.rating'))
                            ->class('form-label')
                            ->for('rating') !!}

                        {!! html()->text('rating', request('rating'))
                            ->class('form-control')
                            ->attribute('placeholder', __('message.rating'))
                            ->id('rating') !!}
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

    <div class="modal fade" id="exportModal" tabindex="-1" aria-labelledby="exportModalLabel"
        aria-hidden="true">
          <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="exportModalLabel">{{ __('message.export') }}</h5>
                    <a href="javascript:void();" data-bs-dismiss="modal" aria-label="Close"><i class="ri-close-circle-fill" style="font-size: 25px"></i></a>
                    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
                </div>
                <div class="modal-body">
                <form id="exportForm" method="get">
                    <div class="form-group">
                        <label for="date_range" class="d-flex mb-3">{{ __('message.select_date') }}</label>
                        <input type="text" class="form-control" id="date_range" name="date_range" placeholder="{{ __('message.select_date_range') }}">

                        <input type="hidden" id="from_date" name="from_date" value="{{ request('from_date') }}">
                        <input type="hidden" id="to_date" name="to_date" value="{{ request('to_date') }}">
                        <input type="hidden" id="branch_id" name="branch_id" value="{{ request('branch_id') }}">
                    </div>
                    <div class="d-flex justify-content-center mb-3">
                        <div class="btn-group btn-group-toggle" data-toggle="buttons">
                            <label class="btn btn-outline-primary">
                                <input type="radio" name="duration" id="duration3" value="3months"> {{ __('message.three_month') }}
                            </label>
                            <label class="btn btn-outline-primary">
                                <input type="radio" name="duration" id="duration6" value="6months">{{ __('message.six_month') }}
                            </label>
                            <label class="btn btn-outline-primary">
                                <input type="radio" name="duration" id="duration12" value="1year"> {{ __('message.one_year') }}
                            </label>
                        </div>
                    </div>
                    <div class="d-flex justify-content-center mb-3">
                        <div class="btn-group btn-group-toggle" data-toggle="buttons">
                            <label class="btn btn-secondary active">
                                <input type="radio" name="options" id="option1" value="xlsx" checked> {{ __('message.xlsx') }}
                            </label>
                            <label class="btn btn-secondary">
                                <input type="radio" name="options" id="option2" value="xls"> {{ __('message.xls') }}
                            </label>
                            <label class="btn btn-secondary">
                                <input type="radio" name="options" id="option3" value="ods"> {{ __('message.ods') }}
                            </label>
                            <label class="btn btn-secondary">
                                <input type="radio" name="options" id="option4" value="csv"> {{ __('message.csv') }}
                            </label>
                            <label class="btn btn-secondary">
                                <input type="radio" name="options" id="option5" value="pdf"> {{ __('message.pdf') }}
                            </label>
                            <label class="btn btn-secondary">
                                <input type="radio" name="options" id="option6" value="html"> {{ __('message.html') }}
                            </label>
                        </div>
                    </div>
                    <hr>
                    <h6 class="d-flex mb-3">{{ __('message.select_columns') }}</h6>
                    <div class="row">
                        <div class="col-md-6 mr-4">
                            @foreach(['id','name','contact_number','email','status','last_actived_at','created_at'] as $column)
                                <div class="d-flex">
                                    <input type="checkbox" name="columns[]" value="{{ $column }}" checked>
                                    <label class="form-check-label ml-2">{{ __('message.' . $column) }}</label>
                                </div>
                            @endforeach
                        </div>
                        <div class="col-md-6">
                        </div>
                    </div>
                </form>
            </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">{{ __('message.cancel') }}</button>
                    <button type="button" class="btn btn-primary" id="downloadBtn">{{ __('message.download') }}</button>
                </div>
                {!! html()->form()->close() !!}
            </div>
        </div>
    </div>


    @section('bottom_script')
        {{ $dataTable->scripts() }}
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>
        <script>
            $(document).ready(function() {
                // init select2 inside filter modal
                $('.select2').select2({
                    dropdownParent: $('#filterModal'),
                });

                // init flatpickr for manual date range
                flatpickr("#date_range", {
                    mode: "range",
                    dateFormat: "Y-m-d",
                    onChange: function(selectedDates) {
                        if (selectedDates.length === 2) {
                            var fromDate = selectedDates[0].toISOString().split('T')[0];
                            var toDate   = selectedDates[1].toISOString().split('T')[0];

                            $('#from_date').val(fromDate);
                            $('#to_date').val(toDate);
                        }
                    }
                });

                // accessibility for modal
                $('#filterModal').on('show.bs.modal', function () {
                    $(this).attr('aria-hidden', 'false');
                });
                $('#filterModal').on('hide.bs.modal', function () {
                    $(this).attr('aria-hidden', 'true');
                });

                // rider filter form submit
                $('#rider-filter-form').on('submit', function(e) {
                    e.preventDefault();
                    var formData = $(this).serialize();
                    var table = $('#dataTableBuilder').DataTable();
                    table.ajax.url('{{ route('rider.index') }}?' + formData).load();
                });

                // reset filters
                $('#reset-filter-btn').on('click', function(e) {
                    e.preventDefault();
                    $('#rider_id').val('').trigger('change');
                    $('#last_active').val('').trigger('change');
                    $('#contact_number').val('').trigger('change');
                    $('#rating').val('');
                    $('#date_range').val('');
                    $('#from_date').val('');
                    $('#to_date').val('');
                    $('input[name="duration"]').prop('checked', false);

                    var table = $('#dataTableBuilder').DataTable();
                    table.ajax.url('{{ route('rider.index') }}').load();
                });

                // handle duration radio change (auto fill hidden dates)
                $('input[name="duration"]').on('change', function() {
                    var today = new Date();
                    var fromDate = new Date();
                    var toDate = today.toISOString().split('T')[0];

                    if (this.value === '3months') {
                        fromDate.setMonth(today.getMonth() - 3);
                    } else if (this.value === '6months') {
                        fromDate.setMonth(today.getMonth() - 6);
                    } else if (this.value === '1year') {
                        fromDate.setFullYear(today.getFullYear() - 1);
                    }

                    var from = fromDate.toISOString().split('T')[0];
                    $('#from_date').val(from);
                    $('#to_date').val(toDate);

                    // clear manual date range input
                    $('#date_range').val('');
                });

                // download report
                $('#downloadBtn').on('click', function() {
                    var fileType = $('input[name="options"]:checked').val();
                    var columns  = $('input[name="columns[]"]:checked').map(function() {
                        return $(this).val();
                    }).get();

                    var baseUrl = '{{ url('/') }}';
                    var url = fileType === 'pdf'
                        ? baseUrl + '/download-rider-report-pdf'
                        : baseUrl + '/download-rider-report/' + fileType;

                    var fromDate = $('#from_date').val();
                    var toDate   = $('#to_date').val();
                    var branchId = $('#branch_id').val();
                    var durationSelected = $('input[name="duration"]:checked').val();
                    var dateRange = $('#date_range').val().trim();

                    // validation: require either duration OR date range
                    if (!durationSelected && !dateRange) {
                        alert("Please select a date range or choose a duration (3 months, 6 months, 1 year).");
                        return;
                    }

                    var queryString = $.param({
                        columns: columns,
                        from_date: fromDate,
                        to_date: toDate,
                        branch_id: branchId,
                        rider_id: $('#rider_id').val()
                    });

                    window.location.href = url + '?' + queryString;
                    $('#exportModal').modal('hide');
                });
            });
        </script>


    @endsection

</x-master-layout>

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

    <div class="modal fade" id="exportModal" tabindex="-1" aria-labelledby="exportModalLabel"
        aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="exportModalLabel">{{ __('message.export') }}</h5>
                    <a href="javascript:void(0);" data-bs-dismiss="modal" aria-label="Close">
                        <i class="ri-close-circle-fill" style="font-size: 25px"></i>
                    </a>
                    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
                </div>

                <div class="modal-body">
                    <form id="exportForm" method="get">
                        <div class="form-group">
                            <label for="date_range" class="d-flex mb-3">{{ __('message.select_date') }}</label>
                            <input type="text" class="form-control" id="date_range" name="date_range" placeholder="Select Date Range">

                            <input type="hidden" id="from_date" name="from_date" value="{{ request('from_date') }}">
                            <input type="hidden" id="to_date" name="to_date" value="{{ request('to_date') }}">
                            <input type="hidden" id="branch_id" name="branch_id" value="{{ request('branch_id') }}">
                        </div>
                        <div class="d-flex justify-content-center mb-3">
                            <div class="btn-group btn-group-toggle" data-toggle="buttons">
                                <label class="btn btn-outline-primary">
                                    <input type="radio" name="duration" id="duration3" value="3months">   {{ __('message.three_month') }}
                                </label>
                                <label class="btn btn-outline-primary">
                                    <input type="radio" name="duration" id="duration6" value="6months">   {{ __('message.six_month') }}
                                </label>
                                <label class="btn btn-outline-primary">
                                    <input type="radio" name="duration" id="duration12" value="1year">   {{ __('message.one_year') }}
                                </label>
                            </div>
                        </div>
                        <hr>
                        <h6 class="d-flex mb-3">{{ __('message.select_columns') }}</h6>
                        <div class="row">
                            <div class="col-md-6 mr-4">
                                @foreach(['id','rider_name','requested_driver','driver_name','pickup_address','drop_address','trip_type','status','payment_status','payment_method','distance','discount','extra_charges_amount','extra_charges','admin_commission','total_amount','created_at'] as $column)
                                    <div class="d-flex mb-2">
                                        <input type="checkbox" name="columns[]" value="{{ $column }}" checked>
                                        <label class="form-check-label ml-2">{{ __('message.' . $column) }}</label>
                                    </div>
                                @endforeach
                            </div>
                            <div class="col-md-6">
                                <!-- Optional: add more column groups later -->
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
    @if (isset($rideRequestfilterButton) && $rideRequestfilterButton == true)
        @include('riderequest.filter')
    @endif

    @section('bottom_script')
        {{ $dataTable->scripts() }}
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>
        <script>
            $(document).ready(function () {
                // init select2
                $('.select2').select2({
                    dropdownParent: $('#filterModal'),
                });

                // init flatpickr for manual date range
                flatpickr("#date_range", {
                    mode: "range",
                    dateFormat: "Y-m-d",
                    onChange: function (selectedDates) {
                        if (selectedDates.length === 2) {
                            var fromDate = selectedDates[0].toISOString().split('T')[0];
                            var toDate = selectedDates[1].toISOString().split('T')[0];
                            $('#from_date').val(fromDate);
                            $('#to_date').val(toDate);
                        }
                    }
                });

                // handle duration radio change (auto fill hidden dates)
                $('input[name="duration"]').on('change', function () {
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

                // download button click (only XLSX)
                $('#downloadBtn').on('click', function () {
                    var columns = $('input[name="columns[]"]:checked').map(function () {
                        return $(this).val();
                    }).get();

                    var baseUrl = '{{ url('/') }}';
                    var url = baseUrl + '/download-riderrequest-report/xlsx'; // only XLSX

                    var fromDate = $('#from_date').val();
                    var toDate = $('#to_date').val();
                    var branchId = $('#branch_id').val();
                    var durationSelected = $('input[name="duration"]:checked').val();
                    var dateRange = $('#date_range').val().trim();

                    // validation: either duration OR date range required
                    if (!durationSelected && !dateRange) {
                        alert("Please select a date range or choose a duration (3 months, 6 months, 1 year).");
                        return;
                    }

                    var queryString = $.param({
                        columns: columns,
                        from_date: fromDate,
                        to_date: toDate,
                        branch_id: branchId
                    });

                    window.location.href = url + '?' + queryString;
                    $('#exportModal').modal('hide');
                });
            });
        </script>

    @endsection

</x-master-layout>

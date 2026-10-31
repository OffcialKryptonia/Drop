<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {{ html()->modelForm($data, 'PATCH', route('dispatch.update', $id))->attribute('data-toggle', 'validator')->open() }}
        @else
            {!! html()->form('POST' ,route('dispatch.store'))->attribute('data-toggle','validator')->open() !!}
        @endif
        <div class="row">
            <div class="col-lg-12 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <?php echo $button; ?>
                    </div>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-lg-8">
                <div class="card card-body">
                    <div class="row">
                        {!! html()->hidden('start_latitude')->id('start_latitude') !!}
                        {!! html()->hidden('start_longitude')->id('start_longitude') !!}
                        {!! html()->hidden('end_latitude')->id('end_latitude') !!}
                        {!! html()->hidden('end_longitude')->id('end_longitude') !!}
                        <input type="hidden" name="pickup_zone_id" id="pickup_zone_id_hidden">
                        <input type="hidden" name="drop_zone_id" id="drop_zone_id_hidden">
                        <input type="hidden" name="pickup_airport_id" id="pickup_airport_id_hidden">
                        <input type="hidden" name="drop_airport_id" id="drop_airport_id_hidden">


                        <div class="form-group col-md-12" id="trip-type-sec">
                            {{ html()->label(__('message.trip_type'), 'trip_type_lbl')->class('form-control-label') }}
                            {{ html()->select(
                                    'trip_type',
                                    [
                                        'regular' => __('message.regular'),
                                        'airport_pickup' => __('message.airport_pickup'),
                                        'airport_drop' => __('message.airport_drop'),
                                        'zone_wise' => __('message.zone_wise'),
                                        'zone_to_airport' => __('message.zone_to_airport'),
                                        'airport_to_zone' => __('message.airport_to_zone'),
                                    ],
                                )->class('form-control select2js trip_type')->required() }}
                        </div>

                        <div class="form-group col-md-6" id="start_address">
                            {{ html()->label(__('message.pickup_address') . ' <span class="text-danger">*</span>', 'pickup_address')->class('form-control-label') }}
                            <div id="start_address_wrapper"></div>
                        </div>

                        {{-- Pickup Zone Dropdown --}}
                        <div class="form-group col-md-6 d-none" id="pickup_zone_wrapper">
                            <label for="pickup_zone_id">{{ __('message.pickup_address') }}</label>
                            <select name="pickup_zone_id" id="pickup_zone_id" class="form-control select2js">
                                <option value="">Select Zone</option>
                                @foreach($zoneList as $key => $zone)
                                    <option value="{{ $zone['id'] }}" data-lat="{{ $zone['latitude'] }}" data-lng="{{ $zone['longitude'] }}">{{ $zone['name'] }}</option>
                                @endforeach
                            </select>
                        </div>

                        {{-- Pickup Airport Dropdown --}}
                        <div class="form-group col-md-6 d-none" id="pickup_airport_wrapper">
                            <label for="pickup_airport_id">{{ __('message.pickup_address') }}</label>
                            <select name="pickup_airport_id" id="pickup_airport_id" class="form-control">
                                <option value="">Select Airport</option>
                            </select>
                        </div>

                        {{-- Drop Zone Dropdown --}}
                        <div class="form-group col-md-6 d-none" id="drop_zone_wrapper">
                            <label for="drop_zone_id">{{ __('message.drop_address') }}</label>
                            <select name="drop_zone_id" id="drop_zone_id" class="form-control select2js">
                                <option value="">Select Zone</option>
                                @foreach($zoneList as $key => $zone)
                                    <option value="{{ $zone['id'] }}" data-lat="{{ $zone['latitude'] }}" data-lng="{{ $zone['longitude'] }}">{{ $zone['name'] }}</option>
                                @endforeach
                            </select>
                        </div>
                            {{-- Drop Airport Dropdown --}}
                            <div class="form-group col-md-6 d-none" id="drop_airport_wrapper">
                            <label for="drop_airport_id">{{ __('message.drop_address') }}</label>
                            <select name="drop_airport_id" id="drop_airport_id" class="form-control">
                                <option value="">Select Airport</option>
                            </select>
                        </div>

                        <div class="form-group col-md-6" id="end_address">
                            {{ html()->label(__('message.drop_address') . ' <span class="text-danger">*</span>', 'drop_address')->class('form-control-label') }}
                            <div id="end_address_wrapper"></div>
                        </div>
                        <div class="form-group col-md-6 d-none" id="flight_number_wrapper">
                            {{ html()->label(__('message.flight_number') .' <span class="text-danger">*</span>', 'flight_number')->class('form-control-label') }}
                            {{ html()->text('flight_number')->class('form-control')->id('flight_number') }}
                        </div>

                        <div class="form-group col-md-6 d-none" id="pickup_point_wrapper">
                            {{ html()->label(__('message.pickup_point') .' <span class="text-danger">*</span>', 'pickup_point')->class('form-control-label') }}
                            {{ html()->text('pickup_point')->class('form-control')->id('pickup_point') }}
                            <span class="text-muted">(like Arrival Gate A, Terminal 3, etc.)</span>
                        </div>

                        <div class="form-group col-md-6 d-none" id="preferred_pickup_time_wrapper">
                            {{ html()->label(__('message.preferred_pickup_time') .' <span class="text-danger">*</span>', 'preferred_pickup_time')->class('form-control-label') }}
                            {{  html()->text('preferred_pickup_time')->class('form-control datetimepicker')->placeholder(__('message.preferred_pickup_time')) }}
                        </div>

                        <div class="form-group col-md-6 d-none" id="preferred_dropoff_time_wrapper">
                            {{ html()->label(__('message.preferred_dropoff_time') .' <span class="text-danger">*</span>', 'preferred_dropoff_time')->class('form-control-label') }}
                            {{  html()->text('preferred_dropoff_time')->class('form-control datetimepicker')->placeholder(__('message.preferred_dropoff_time')) }}
                        </div>


                        <div class="form-group col-md-6">
                            {!! html()->label(__('message.rider') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('rider_id') !!}
                            {!! html()->select('rider_id', isset($data) ? [optional($data->rider)->id => optional($data->rider)->display_name] : [])
                                ->class('form-control select2js')
                                ->attribute('data-ajax--url', route('ajax-list', ['type' => 'rider']))
                                ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.rider')]))
                                ->required() !!}
                        </div>
                        <div class="form-group col-md-6">
                            {!! html()->label(__('message.service') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('service_id') !!}
                            <a class="float-right serviceList" href="javascript:void(0)"><i class="ri-refresh-line"></i></a>
                            {!! html()->select('service_id', isset($data) ? [ optional($data->service)->id => optional($data->service)->display_name ] : [], old('service_id'))
                                ->class('select2js form-group service')
                                ->required()
                                ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.service')])) !!}
                        </div>

                        <div class="form-group col-md-6">
                            {!! html()->label(__('message.driver'))->class('form-control-label')->for('driver_id') !!}
                            <a class="float-right driverList" href="#"><i class="ri-refresh-line"></i></a>
                            {!! html()->select('driver_id', isset($data) ? [ optional($data->driver)->id => optional($data->driver)->display_name ] : [], old('driver_id'))
                                ->class('select2js form-group driver')
                                ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.driver')])) !!}
                        </div>

                        <div class="form-group col-md-6">
                            {!! html()->label(__('message.schedule_datetime'), 'schedule_datetime')->class('form-control-label') !!}
                            {!! html()->text('schedule_datetime')->value(old('schedule_datetime'))->placeholder(__('message.schedule_datetime'))->class('form-control datetimepicker') !!}
                        </div>
                    </div>
                    <hr>
                    <div class="row">
                        <div class="col-md-12">
                            <div class="d-flex justify-content-between">
                                <h5>{{ __('message.transit_point') }}</h5>
                                <button type="button" id="add_button" class="btn btn-sm btn-primary float-right ml-2 mb-2">{{ __('message.add') }}</button>
                            </div>
                            <div id="dropAddress" class="clone-master">
                                <div class="row clone-item" id="row_0" row="0" data-id="0">
                                    <div class="form-group col-md-6">
                                        <gmp-place-autocomplete id="search_drop_location_0" name="search_drop_location[]" row="0" style="border: 1px solid #0000003b; border-radius: 10px;"></gmp-place-autocomplete>
                                        <input type="hidden" name="drop_location[]" value="" class="form-control hidden_drop_location" id="drop_location_0" row="0" />
                                    </div>
                                    <a href="javascript:void(0)" id="remove_0" class="removebtn text-danger mt-2 p-1" row="0">
                                        <i class="fas fa-times"></i>
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-12">
                            {!! html()->submit(__('message.save'))->class('btn border-radius-10 btn-primary float-right') !!}
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-lg-4">
                <div class="row">
                    <div class="form-group col-md-12">
                        <div class="card">
                            <!-- Use relative on the card, not card-body -->
                            <div class="position-relative" style="height: 355px; width: 100%;">

                                <!-- Map -->
                                <div id="map" class="w-100 h-100"></div>

                                <!-- Button that sits correctly inside this box -->
                                <button type="button"
                                    id="clearMapBtn"
                                    class="btn btn-sm btn-danger clearMapBtn">
                                    {{ __('message.clear_map') }}
                                </button>
                            </div>
                        </div>
                    </div>


                    <div class="form-group col-md-12">
                        <div class="card">
                            <div class="card-header d-flex justify-content-between">
                                <div class="header-title">
                                    <h4 class="card-title">{{ __('message.trip_estimate') }}</h4>
                                </div>
                            </div>
                            <div class="card-body">
                                <div class="row">
                                    {{ html()->hidden('fleet_fare')->id('estimate_fleet_fare') }}
                                    {{ html()->hidden('base_fare')->id('modal_base_fare') }}
                                    {{ html()->hidden('surcharge')->id('modal_surcharge') }}
                                    {{ html()->hidden('discount')->id('modal_discount') }}
                                    {{ html()->hidden('data_model_estimate_type')->id('data_model_estimate_type') }}
                                    {{ html()->hidden('reason')->id('reason') }}
                                    <div class="col-md-4">
                                        {{ html()->label(__('message.distance'), 'Distance')->class('form-control-label') }}
                                        <p id="distance"></p>
                                        {{ html()->hidden('distance')->class('distance') }}
                                    </div>
                                    <div class="col-md-4">
                                        {{ html()->label(__('message.duration'), 'duration')->class('form-control-label') }}
                                        <p id="duration"></p>
                                        {{ html()->hidden('duration')->class('duration') }}
                                    </div>
                                    <div class="col-md-4">
                                        {{ html()->label(__('message.fleet_fare'), 'fleet_fare')->class('form-control-label') }}
                                        {{ html()->hidden('total_amount')->class('total_amount') }}
                                        <a href="#" class="supplier_payout_btn loadRemoteModel d-none" id="supplier_payout_btn">
                                            <i class="fa fa-plus-circle"></i>
                                            {{-- <i class="bg-primary border-radius-20 p-1 fa fa-pen"></i> --}}
                                        </a>
                                        <p id="fleet_fare"></p>
                                        <p><del id="fleet_fare_change"></del></p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <hr>
        </div>
        {!! html()->form()->close() !!}
    </div>
    @section('bottom_script')
        <script>
            $(function () {
                let startAutocomplete, endAutocomplete;

                $(document).ready(function () {
                    $('#start_address, #end_address').val('');
                    $(".drop_location input[type='text']").val('');
                    resetSequenceNumbers();
                });

                $("#add_button").click(function () {
                    let cloneMaster = $("#dropAddress");
                    let lastItem = cloneMaster.find(".clone-item:last");
                    let lastCount = parseInt(lastItem.attr('row')) || 0;
                    let newRow = lastCount + 1;

                    let newDiv = $(`
                        <div class="row clone-item" id="row_${newRow}" row="${newRow}" data-id="${newRow}">
                            <div class="form-group col-md-6" id="drop_wrapper_${newRow}">
                                <!-- gmp element will be appended via JS -->
                                <input type="hidden" name="drop_location[]" value="" class="form-control hidden_drop_location" id="drop_location_${newRow}" row="${newRow}">
                            </div>
                            <a href="javascript:void(0)" id="remove_${newRow}" class="removebtn text-danger mt-2 p-1" row="${newRow}">
                                <i class="fas fa-times"></i>
                            </a>
                        </div>
                    `);

                    cloneMaster.append(newDiv);

                    // Create gmp-place-autocomplete element dynamically
                    const gmpElement = document.createElement('gmp-place-autocomplete');
                    gmpElement.setAttribute('id', `search_drop_location_${newRow}`);
                    gmpElement.setAttribute('name', 'search_drop_location[]');
                    gmpElement.setAttribute('row', newRow);

                    document.getElementById(`drop_wrapper_${newRow}`).prepend(gmpElement);

                    // Attach event
                    initializeAutocomplete(newRow);
                    initializeDropLocations();
                });

                function initializeAutocomplete(row) {
                    const autocompleteEl = document.getElementById(`search_drop_location_${row}`);
                    if (!autocompleteEl || autocompleteEl.hasAttribute('data-hidden-bound')) return;

                    autocompleteEl.setAttribute('data-hidden-bound', 'true');

                    autocompleteEl.addEventListener('gmp-select', async (e) => {
                        const placePrediction = e.detail?.placePrediction;
                        if (!placePrediction) return;

                        try {
                            const place = await placePrediction.toPlace();
                            await place.fetchFields({ fields: ['location', 'formattedAddress'] });

                            const loc = place.location;
                            const address = place.formattedAddress;

                            const hiddenInput = document.getElementById(`drop_location_${row}`);
                            if (hiddenInput) {
                                hiddenInput.value = JSON.stringify({
                                    lat: loc.lat(),
                                    lng: loc.lng(),
                                    address: address,
                                    drop: row,
                                    dropped_at: null
                                });
                            }

                            syncDropLocationsFromInputs();
                            if (locations.start && locations.end) {
                                drawRoute();
                                getFareEstimate();
                            }
                        } catch (err) {
                            console.error('Error fetching place details:', err);
                        }
                    });
                }

                // drop-address
                $(document).on('click', '.removebtn', function () {
                    let $cloneItems = $('#dropAddress .clone-item');

                    // Find the clicked row
                    let $currentRow = $(this).closest('.clone-item');

                    // Check if this is the first/default row (don't allow removing it)
                    if ($currentRow.is($cloneItems.first())) {
                        //alert("Default row cannot be deleted.");
                        return false;
                    }

                    if (!confirm("{{ __('message.delete_msg') }}")) return false;

                    // Remove the clicked row
                    $currentRow.remove();

                    syncDropLocationsFromInputs();
                    rebuildDropMarkers();
                    drawRoute();
                    getFareEstimate();

                    // Optional: Reset row IDs if needed
                    resetSequenceNumbers();
                });

                function resetSequenceNumbers() {
                    $('#dropAddress .clone-item').each(function(index) {
                        $(this).attr('id', 'row_' + index);
                    });
                }

                $(document).on('change', '.service', function () {
                    var service_id = $(this).val();
                    $('.driver').empty();
                    resetServiceFields();

                    if (service_id != null)
                    {
                        driverList(service_id);
                        if (locations.start && locations.end) {
                            getFareEstimate();
                        }
                    }
                    checkZonePayoutVisibility(service_id);
                });

                $('.serviceList').on('click', function () {
                    resetServiceFields();
                    const start_latitude = $('#start_latitude').val();
                    const start_longitude = $('#start_longitude').val();

                    if (start_latitude != '' && start_longitude != '') {
                        serviceList(start_latitude, start_longitude);
                    } else {
                        $('.service').empty();
                    }

                    if ($('#data_model_estimate_type').val() != 'update') {
                        resetServiceFields();
                        adjustPriceDataClear();
                    }
                });

                $('.driverList').on('click', function () {
                    service_id = $('#service_id').val();
                    if (service_id != null) {
                        driverList(service_id);
                    } else {
                        $('.driver').empty();
                    }
                });
            });

            $('#pickup_airport_id, #drop_airport_id').select2({
                placeholder: 'Select Airport',
                ajax: {
                    url: "{{ route('ajax-list') }}",
                    dataType: 'json',
                    delay: 250,
                    data: function (params) {
                        return {
                            q: params.term || '',
                            page: params.page || 1,
                            type: 'airport'
                        };
                    },
                    processResults: function (data, params) {
                        params.page = params.page || 1;

                        return {
                            results: data.results,
                            pagination: {
                                more: data.pagination.more
                            }
                        };
                    },
                    cache: true
                },
                minimumInputLength: 0
            });
            const tripTypeSelect = $('#trip_type');
            const pickup_zoneWrapper = $('#pickup_zone_wrapper');
            const drop_zoneWrapper = $('#drop_zone_wrapper');
            const pickup_airportWrapper = $('#pickup_airport_wrapper');
            const drop_airportWrapper = $('#drop_airport_wrapper');
            const startAddressWrapper = $('#start_address');
            const endAddressWrapper = $('#end_address');

            function toggleFields() {
                const tripType = tripTypeSelect.val();

                pickup_zoneWrapper.addClass('d-none');
                drop_zoneWrapper.addClass('d-none');
                pickup_airportWrapper.addClass('d-none');
                drop_airportWrapper.addClass('d-none');
                startAddressWrapper.addClass('d-none');
                endAddressWrapper.addClass('d-none');

                $('#flight_number_wrapper').addClass('d-none');
                $('#pickup_point_wrapper').addClass('d-none');
                $('#preferred_pickup_time_wrapper').addClass('d-none');
                $('#preferred_dropoff_time_wrapper').addClass('d-none');

                switch (tripType) {
                    case 'regular':
                        startAddressWrapper.removeClass('d-none');
                        endAddressWrapper.removeClass('d-none');
                        break;
                    case 'airport_pickup':
                        pickup_airportWrapper.removeClass('d-none');
                        endAddressWrapper.removeClass('d-none');
                        break;
                    case 'airport_drop':
                        startAddressWrapper.removeClass('d-none');
                        drop_airportWrapper.removeClass('d-none');
                        break;
                    case 'zone_wise':
                        pickup_zoneWrapper.removeClass('d-none');
                        drop_zoneWrapper.removeClass('d-none');
                        break;
                    case 'zone_to_airport':
                        pickup_zoneWrapper.removeClass('d-none');
                        drop_airportWrapper.removeClass('d-none');
                        break;
                    case 'airport_to_zone':
                        pickup_airportWrapper.removeClass('d-none');
                        drop_zoneWrapper.removeClass('d-none');
                        break;
                }

                // Show flight/preferred time fields only when trip type involves an airport
                if (['airport_pickup', 'airport_drop', 'zone_to_airport', 'airport_to_zone'].includes(tripType)) {
                    $('#flight_number_wrapper').removeClass('d-none');
                    $('#pickup_point_wrapper').removeClass('d-none');
                    // $('#preferred_pickup_time_wrapper').removeClass('d-none');
                    // $('#preferred_dropoff_time_wrapper').removeClass('d-none');
                }
            }

            $(document).ready(function() {
                tripTypeSelect.on('change', toggleFields);
                toggleFields();
                initMap();
            });

            // Dropdowns logic
            $('#pickup_zone_id').on('select2:select', function(e) {
                const selected = e.params.data.element;
                if (selected && selected.dataset.lat && selected.dataset.lng) {
                    const lat = parseFloat(selected.dataset.lat);
                    const lng = parseFloat(selected.dataset.lng);
                    const loc = { lat, lng };

                    // Update start location
                    locations.start = loc;
                    $('#start_latitude').val(loc.lat);
                    $('#start_longitude').val(loc.lng);

                    // Update map marker
                    if (startMarker) startMarker.setMap(null);
                    startMarker = new google.maps.Marker({
                        map,
                        position: loc,
                        label: "1"
                    });

                    map.setCenter(loc);

                    // serviceList(loc.lat, loc.lng);

                    if (locations.end) {
                        drawRoute();
                        getFareEstimate();
                    }
                }
            });

            $('#drop_zone_id').on('select2:select', function(e) {
                const selected = e.params.data.element;
                if (selected && selected.dataset.lat && selected.dataset.lng) {
                    const lat = parseFloat(selected.dataset.lat);
                    const lng = parseFloat(selected.dataset.lng);
                    const loc = { lat, lng };

                    // Update end location
                    locations.end = loc;
                    $('#end_latitude').val(loc.lat);
                    $('#end_longitude').val(loc.lng);

                    // Update map marker
                    if (endMarker) endMarker.setMap(null);
                    endMarker = new google.maps.Marker({
                        map,
                        position: loc,
                        label: "2"
                    });

                    map.setCenter(loc);
                    serviceList(loc.lat, loc.lng);

                    if (locations.start) {
                        drawRoute();
                        getFareEstimate();
                    }
                }
            });

            $('#pickup_airport_id').on('select2:select', function(e) {
                const selected = e.params.data;
                if (selected && selected.lat && selected.lng) {
                    const lat = parseFloat(selected.lat);
                    const lng = parseFloat(selected.lng);
                    const loc = { lat, lng };

                    // Update start location
                    locations.start = loc;
                    $('#start_latitude').val(loc.lat);
                    $('#start_longitude').val(loc.lng);

                    // Update map marker
                    if (startMarker) startMarker.setMap(null);
                    startMarker = new google.maps.Marker({
                        map,
                        position: loc,
                        label: "1"
                    });

                    map.setCenter(loc);

                    serviceList(loc.lat, loc.lng);

                    if (locations.end) {
                        drawRoute();
                        getFareEstimate();
                    }
                }
            });

            $('#drop_airport_id').on('select2:select', function(e) {
                const selected = e.params.data;
                if (selected && selected.lat && selected.lng) {
                    const lat = parseFloat(selected.lat);
                    const lng = parseFloat(selected.lng);
                    const loc = { lat, lng };

                    // Update end location
                    locations.end = loc;
                    $('#end_latitude').val(loc.lat);
                    $('#end_longitude').val(loc.lng);

                    // Update map marker
                    if (endMarker) endMarker.setMap(null);
                    endMarker = new google.maps.Marker({
                        map,
                        position: loc,
                        label: "2"
                    });

                    map.setCenter(loc);

                    if (locations.start) {
                        drawRoute();
                        getFareEstimate();
                    }
                }
            });

            function serviceList(latitude, longitude) {
                var route = "{{ route('ajax-list',[ 'type' => 'service_for_ride']) }}&latitude=" + latitude + "&longitude=" + longitude;
                route = route.replaceAll('amp;', '');

                $.ajax({
                    url: route,
                    success: function (result) {
                        $('.service').select2({
                            width: '100%',
                            placeholder: "{{ __('message.select_name',[ 'select' => __('message.service') ]) }}",
                            data: result.results
                        });
                        getFareEstimate();
                        driverList(result.results[0].id);
                    },
                    error: function(xhr, status, error) {
                        console.error('Error loading services:', error);
                    }
                });
                checkZonePayoutVisibility();
            }

            function driverList(service_id) {
                const latitude = $('#start_latitude').val();
                const longitude = $('#start_longitude').val();

                var route = "{{ route('ajax-list',[ 'type' => 'driver_for_ride']) }}&service_id=" + service_id + "&latitude=" + latitude + "&longitude=" + longitude;
                route = route.replaceAll('amp;', '');

                $.ajax({
                    url: route,
                    success: function (result) {
                        $('.driver').select2({
                            width: '100%',
                            placeholder: "{{ __('message.select_name',[ 'select' => __('message.driver') ]) }}",
                            data: result.results
                        });

                        $(".driver").val(service_id).trigger('change');
                    }
                });
            }

            let map, polyline, startMarker, endMarker, infoWindow;
            let locations = {
                start: null,
                end: null,
                drops: []
            };

            let  startAutocomplete;
            let  endAutocomplete;

            async function initMap() {
                const [{
                    Map
                }, {
                    Marker
                }, {
                    PlaceAutocompleteElement
                }] = await Promise.all([
                    google.maps.importLibrary("maps"),
                    google.maps.importLibrary("marker"),
                    google.maps.importLibrary("places")
                ]);

                map = new Map(document.getElementById("map"), {
                    zoom: 14,
                    center: {
                        lat: 22.310696,
                        lng: 70.802288
                    },
                    mapId: '4504f8b37365c3d0',
                    mapTypeControl: false
                });

                infoWindow = new google.maps.InfoWindow();
                polyline = new google.maps.Polyline({
                    strokeColor: '#4788ff',
                    strokeOpacity: 0.8,
                    strokeWeight: 6,
                    map: map
                });

                const startWrapper = document.getElementById('start_address_wrapper');
                const endWrapper = document.getElementById('end_address_wrapper');


                document.getElementById('clearMapBtn').addEventListener('click', function (e) {
                    e.preventDefault();
                    e.stopPropagation();
                    clearStartAutocompleteElement();
                    clearEndAutocompleteElement();
                    resetDropAddresses();
                    $(".service").empty();
                    resetServiceFields();
                });

                if (startWrapper && !startWrapper.querySelector('gmpx-placeautocomplete')) {
                    startAutocomplete = new PlaceAutocompleteElement();
                    startAutocomplete.id = 'start_address';
                    startAutocomplete.setAttribute('name', 'start_address');
                    startAutocomplete.locationBias = map.getCenter();
                    startWrapper.innerHTML = '';
                    startWrapper.appendChild(startAutocomplete);

                    startAutocomplete.addEventListener('gmp-select', async ({
                        placePrediction
                    }) => {

                        const place = placePrediction.toPlace();
                        await place.fetchFields({
                            fields: ['location']
                        });
                        const loc = place.location;

                        $('#start_latitude').val(loc.lat());
                        $('#start_longitude').val(loc.lng());
                        locations.start = {
                            lat: loc.lat(),
                            lng: loc.lng()
                        };

                        if (startMarker) startMarker.setMap(null);
                        startMarker = new google.maps.Marker({
                            map,
                            position: loc,
                            label: "1"
                        });

                        map.setCenter(loc);

                        if (locations.end) {
                            drawRoute();
                            getFareEstimate();
                        }
                    });
                }

                if (endWrapper && !endWrapper.querySelector('gmpx-placeautocomplete')) {
                        endAutocomplete = new PlaceAutocompleteElement();
                    endAutocomplete.id = 'end_address';
                    endAutocomplete.setAttribute('name', 'end_address');
                    endAutocomplete.locationBias = map.getCenter();
                    endWrapper.innerHTML = '';
                    endWrapper.appendChild(endAutocomplete);

                    endAutocomplete.addEventListener('gmp-select', async ({
                        placePrediction
                    }) => {
                        const place = placePrediction.toPlace();
                        await place.fetchFields({
                            fields: ['location', 'displayName', 'formattedAddress']
                        });
                        const loc = place.location;

                        $('#end_latitude').val(loc.lat());
                        $('#end_longitude').val(loc.lng());
                        locations.end = {
                            lat: loc.lat(),
                            lng: loc.lng()
                        };

                        if (endMarker) endMarker.setMap(null);
                        endMarker = new google.maps.Marker({
                            map,
                            position: loc,
                            label: "2"
                        });

                        map.setCenter(loc);
                        infoWindow.setContent(
                            `<strong>${place.displayName || ''}</strong><br>${place.formattedAddress || ''}`
                        );
                        infoWindow.setContent(
                            `<div style="color: #000;">
                                <strong>${place.displayName || ''}</strong><br>
                                ${place.formattedAddress || ''}
                            </div>`
                        );
                        infoWindow.setPosition(loc);
                        infoWindow.open(map, endMarker);

                        if (locations.start) {
                            drawRoute();
                            getFareEstimate();
                        }
                    });
                }
            }

            function clearStartAutocompleteElement() {
                const wrapper = document.getElementById('start_address_wrapper');

                if (startAutocomplete && wrapper.contains(startAutocomplete)) {
                    wrapper.removeChild(startAutocomplete);
                }

                const newStart = new google.maps.places.PlaceAutocompleteElement();
                newStart.id = 'start_address';
                newStart.setAttribute('name', 'start_address');
                newStart.locationBias = map.getCenter();

                startAutocomplete = newStart;
                wrapper.appendChild(startAutocomplete);

                if (startMarker) {
                    startMarker.setMap(null);
                    startMarker = null;
                }

                if (polyline) {
                    polyline.setMap(null);
                    polyline = null;
                }
                if (locations.drops || (locations.start || locations.end) )
                {
                    locations = {
                        start: null,
                        end: null,
                        drops: []
                    }
                    $(".drop_location input[type='text']").val('');
                }
            }

            function clearEndAutocompleteElement() {
                const wrapper = document.getElementById('end_address_wrapper');

                if (endAutocomplete && wrapper.contains(endAutocomplete)) {
                    wrapper.removeChild(endAutocomplete);
                }

                const newStart = new google.maps.places.PlaceAutocompleteElement();
                newStart.id = 'end_address';
                newStart.setAttribute('name', 'end_address');
                newStart.locationBias = map.getCenter();

                endAutocomplete = newStart;
                wrapper.appendChild(endAutocomplete);

                if (endMarker) {
                    endMarker.setMap(null);
                    endMarker = null;
                }

                if (polyline) {
                    polyline.setMap(null);
                    polyline = null;
                }

                if (locations.drops || (locations.start || locations.end))
                {
                    locations = {
                        start: null,
                        end: null,
                        drops: []
                    }
                    $(".drop_location input[type='text']").val('');
                };

                initMap();
            }

            function resetDropAddresses() {
                locations.drops = [];

                if (typeof dropMarkers !== "undefined" && dropMarkers.length > 0) {
                    dropMarkers.forEach(marker => marker.setMap(null));
                    dropMarkers = [];
                }

                // Loop through all .clone-item rows
                $("#dropAddress .clone-item").each(function(index, element) {
                    const auto = $(element).find("gmp-place-autocomplete")[0];
                    const hiddenInput = $(element).find(".hidden_drop_location")[0];

                    if (auto) {
                        auto.remove();
                    }

                    const newDrop = new google.maps.places.PlaceAutocompleteElement();
                    newDrop.id = "search_drop_location_" + index;
                    newDrop.setAttribute("name", "search_drop_location[]");
                    newDrop.setAttribute("row", index);
                    newDrop.style = "border: 1px solid #0000003b; border-radius: 10px;";

                    $(element).find(".form-group").prepend(newDrop);
                    if (hiddenInput) {
                        hiddenInput.value = "";
                    }
                });

                initializeDropLocations();
            }

            function parseDropLocationValue(value) {
                if (!value) {
                    return null;
                }

                if (typeof value === 'string') {
                    try {
                        const parsed = JSON.parse(value);
                        if (parsed && parsed.lat !== undefined && parsed.lng !== undefined) {
                            return {
                                lat: parseFloat(parsed.lat),
                                lng: parseFloat(parsed.lng)
                            };
                        }
                    } catch (error) {
                        const parts = value.split(',');
                        if (parts.length === 2) {
                            const lat = parseFloat(parts[0]);
                            const lng = parseFloat(parts[1]);

                            if (!Number.isNaN(lat) && !Number.isNaN(lng)) {
                                return { lat, lng };
                            }
                        }
                    }
                }

                return null;
            }

            function getMultiLocations() {
                return $('#dropAddress .hidden_drop_location')
                    .map(function () {
                        return parseDropLocationValue($(this).val());
                    })
                    .get()
                    .filter(function (location) {
                        return location && !Number.isNaN(location.lat) && !Number.isNaN(location.lng);
                    });
            }

            function syncDropLocationsFromInputs() {
                const multiLocations = getMultiLocations();
                locations.drops = multiLocations;

                return multiLocations;
            }

            function rebuildDropMarkers() {
                Object.values(dropMarkers).forEach(function (marker) {
                    if (marker) {
                        marker.setMap(null);
                    }
                });

                dropMarkers = {};

                $('#dropAddress .hidden_drop_location').each(function (index) {
                    const location = parseDropLocationValue($(this).val());

                    if (!location) {
                        return;
                    }

                    dropMarkers[index] = new google.maps.Marker({
                        map,
                        position: location,
                        label: `${index + 3}`
                    });
                });
            }

            function getDestinationSequence() {
                const transitLocations = syncDropLocationsFromInputs();
                const destinations = [];

                if (locations.end) {
                    destinations.push(locations.end);
                }

                if (transitLocations.length) {
                    destinations.push(...transitLocations);
                }

                return destinations.filter(function (location) {
                    return location && !Number.isNaN(location.lat) && !Number.isNaN(location.lng);
                });
            }

            let dropMarkers = {};
            initializeDropLocations();
            function initializeDropLocations() {
                const dropInputs = document.querySelectorAll('gmp-place-autocomplete[id^="search_drop_location_"]');

                dropInputs.forEach((input) => {
                    const row = input.getAttribute('row');
                    const hiddenInput = document.getElementById(`drop_location_${row}`);

                    if (!input.hasAttribute('data-initialized')) {
                        input.setAttribute('data-initialized', 'true');

                        input.addEventListener('gmp-select', async ({ placePrediction }) => {
                            const place = placePrediction.toPlace();
                            await place.fetchFields({ fields: ['location', 'displayName', 'formattedAddress'] });
                            const loc = place.location;

                                const dropIndex = parseInt(row);
                                locations.drops[dropIndex] = {
                                    lat: loc.lat(),
                                    lng: loc.lng()
                                };
                            if (hiddenInput) {
                                hiddenInput.value = JSON.stringify({
                                    lat: loc.lat(),
                                    lng: loc.lng(),
                                    address: place.formattedAddress
                                });
                            }

                            if (dropMarkers[row]) {
                                dropMarkers[row].setMap(null);
                            }

                            const marker = new google.maps.Marker({
                                map,
                                position: loc,
                                label: `${parseInt(row) + 3}`
                            });

                            dropMarkers[row] = marker;

                            map.setCenter(loc);
                            syncDropLocationsFromInputs();
                            rebuildDropMarkers();
                            drawRoute();
                            getFareEstimate();
                        });
                    }
                });
            }

            function drawRoute() {
                if (!locations.start || !locations.end) return;

                const pathPoints = [locations.start];
                const destinations = getDestinationSequence();

                pathPoints.push(...destinations);
                polyline.setPath([]);

                snapAllSegments(pathPoints);
            }

            async function snapAllSegments(points) {
                const fullPath = [];

                for (let i = 0; i < points.length - 1; i++) {
                    const segment = [points[i], points[i + 1]];
                    const path = segment.map(p => `${p.lat},${p.lng}`);

                    try {
                        const response = await $.post("{{ url('api/snap-to-roads') }}", { path });
                        const encoded = response.routes?.[0]?.polyline?.encodedPolyline;

                        if (encoded) {
                            const decoded = google.maps.geometry.encoding.decodePath(encoded);
                            fullPath.push(...decoded);
                        } else {
                            // fallback for this segment
                            fullPath.push(...segment.map(p => new google.maps.LatLng(p.lat, p.lng)));
                        }
                    } catch (e) {
                        // fallback on error
                        fullPath.push(...segment.map(p => new google.maps.LatLng(p.lat, p.lng)));
                    }
                }

                polyline.setPath(fullPath);

                const bounds = new google.maps.LatLngBounds();
                fullPath.forEach(p => bounds.extend(p));
                map.fitBounds(bounds);
            }

            function adjustPriceDataClear() {
                $('#fleet_fare_change').text('');
                $('#estimate_fleet_fare').val('');
                $('#modal_base_fare').val('');
                $('#modal_surcharge').val('');
                $('#modal_discount').val('');
                $('#reason').val('');
                $('#fleet_fare_change').text('');
            }

            function getFareEstimate()
            {
                const serviceId = $('#service_id').val();
                resetServiceFields();

                if (!locations.start || !locations.end || !serviceId) return;

                const destinations = getDestinationSequence();
                const finalDestination = destinations.length ? destinations[destinations.length - 1] : locations.end;
                const multiLocations = destinations.slice(0, -1);

                const data = {
                    pick_lat: locations.start.lat,
                    pick_lng: locations.start.lng,
                    drop_lat: finalDestination.lat,
                    drop_lng: finalDestination.lng,
                    multi_location: multiLocations,
                    id: serviceId
                };

                $.post("{{ url('api/estimate-price-time') }}", data, function (response) {
                    if (response?.data?.length) {

                        checkZonePayoutVisibility(serviceId);
                        $('#multiple_services').empty(); // Clear existing list

                        response.data.forEach(function(service, index) {
                            // Distance
                            let distanceText = '';
                            let distanceKm = parseFloat(service.dropoff_distance_in_km || service.distance || 0);

                            if (service.distance_unit === 'mile') {
                                distanceText = distanceKm.toFixed(2) + " mi";
                            } else {
                                distanceText = distanceKm.toFixed(2) + " km";
                            }

                            // Duration
                            let mins = parseFloat(service.duration || 0);
                            let durationText;

                            if (mins > 0) {
                                durationText = `${Math.floor(mins / 60)} hr ${Math.round(mins % 60)} min`;
                            } else {
                                const averageSpeed = 40; // km/h
                                const durationMin = (distanceKm / averageSpeed) * 60;

                                durationText = `${Math.floor(durationMin / 60)} hr ${Math.round(durationMin % 60)} min`;
                            }

                            //Fare
                            const fleet_fare = service.total_amount.toFixed(2);

                            // Show result
                            $('#multiple_services').append(`
                                <div class="service-info">
                                    <strong>Service ${index + 1}</strong><br>
                                    Distance: ${distanceText}<br>
                                    Duration: ${durationText}<br>
                                    Fare: ₹${fleet_fare}<br>
                                    <hr>
                                </div>
                            `);

                            // Populate main fields from the first result
                            if (index === 0) {
                                $("#distance").text(distanceText);
                                $(".distance").val(distanceKm.toFixed(2));
                                $("#duration").text(durationText);
                                $(".duration").val(durationText);
                                $("#fleet_fare").text(fleet_fare);
                                $(".total_amount").val(fleet_fare);

                                const supplier_payout_route = "{{ route('supplier.payout') }}" + "?fleet_fare=" + fleet_fare;
                                $('.supplier_payout_btn').attr('href', supplier_payout_route);
                            }
                        });

                        // Discount fare (if not 'regular')
                        const tripType = $('.trip_type').val();
                        if (tripType && tripType == 'zone_wise') {
                            $.post('{{ route("fleet-fare-ajax") }}', {
                                _token: '{{ csrf_token() }}',
                                trip_type: tripType,
                                pickup_zone_id: $('#pickup_zone_id').val(),
                                drop_zone_id: $('#drop_zone_id').val(),
                                serviceId: serviceId
                            }, function (discountResponse) {
                                if (discountResponse.success && discountResponse.price) {
                                    const discountedFare = parseFloat(discountResponse.price).toFixed(2);
                                    $("#fleet_fare").text(discountedFare);
                                    $(".total_amount").val(discountedFare);
                                    $('.supplier_payout_btn').attr('href', "{{ route('supplier.payout') }}" + "?fleet_fare=" + discountedFare);
                                } else {
                                    $("#fleet_fare_change").text('');
                                }
                            });
                        } else {
                            $("#fleet_fare_change").text('');
                        }

                        // Transport-specific logic
                        if ($('#type').val() === 'transport') {
                            scheduleDatetime();
                        }
                    } else {
                        alert('No service available');
                    }
                });
            }

            function resetServiceFields() {
                $("#distance").text("");
                $(".distance").val('');
                $("#duration").text("");
                $(".duration").val('');
                $("#fleet_fare").text("0.00");
                $(".total_amount").val('');
                $("#distance").val('');
            }

            $(document).ready(function() {
                window.initMap = initMap;
                if (typeof google !== 'undefined' && google.maps) initMap();

                $('#service_id').on('change', function() {
                    const serviceId = $(this).val();
                    $('#special_services').val('');

                    if ($('#data_model_estimate_type').val() !== 'update') {
                        drawRoute();
                        getFareEstimate();
                    }
                    checkZonePayoutVisibility(serviceId);
                });
            });

            function checkZonePayoutVisibility(serviceId) {
                const trip_type = $('#trip_type').val();
                const zone_pickup_id = $('#pickup_zone_id').val();
                const zone_dropoff_id = $('#drop_zone_id').val();
                const service_id = serviceId;

                if (trip_type == 'zone_wise' && zone_pickup_id && zone_dropoff_id && service_id) {
                    $.post('{{ route("check.zone.price") }}', {
                        _token: '{{ csrf_token() }}',
                        zone_pickup_id,
                        zone_dropoff_id,
                        service_id
                    }, function(response) {
                        if (response.show_button) {
                            $('#supplier_payout_btn').removeClass('d-none');
                        } else {
                            $('#supplier_payout_btn').addClass('d-none');
                        }
                    });
                } else {
                    $('#supplier_payout_btn').removeClass('d-none');
                }
            }
        </script>
    @endsection
</x-master-layout>

<x-master-layout :assets="$assets ?? []">
    <div class="container-fluid">
        <div class="row">
            <div class="col-lg-12">
                <div class="card card-block card-stretch border-radius-10">
                    <div class="card-body p-0">
                        <div class="d-flex justify-content-between align-items-center p-3">
                            <h5 class="font-weight-bold">{{ $pageTitle }}</h5>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-md-12">
                <div class="card border-radius-10">
                    <div class="card-body">
                        <div class="row">
                            <div class="col-md-3 p-2">
                                {!! html()->select('driver_id', [], request('driver_id'))
                                    ->class('form-control select2js')
                                    ->id('driverSearch')
                                    ->attribute('data-ajax--url', route('ajax-list', ['type' => 'driver']))
                                    ->attribute('data-ajax--cache', 'true')
                                    ->attribute('data-ajax--delay', '250')
                                    ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.driver')]))
                                    ->attribute('data-allow-clear', 'true') !!}

                            </div>

                            <div class="col-md-3 p-2">
                                {!! html()->select('ongoing_driver_id', [])
                                    ->value(request('ongoing_driver_id'))
                                    ->id('ongoing_driver_id')
                                    ->class('form-control select2js')
                                    ->attribute('data-ajax--url', route('ajax-list', ['type' => 'ongoing_driver']))
                                    ->attribute('data-ajax--cache', 'true')
                                    ->attribute('data-ajax--delay', '250')
                                    ->attribute('data-placeholder', __('message.ongoing_driver'))
                                    ->attribute('data-allow-clear', 'true') !!}
                            </div>

                            <div class="col-md-3 p-2">
                                {!! html()->select('driver_status', [
                                        '' => __('message.all'),
                                        'online' => __('message.online'),
                                        'in_service' => __('message.in_service'),
                                        'offline' => __('message.offline'),
                                    ], request('driver_status'))
                                    ->id('driver_status')
                                    ->class('form-control select2js')
                                    ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.status')]))
                                    ->attribute('data-allow-clear', 'true') !!}
                            </div>

                            <div class="col-md-3 p-2">
                                {!! html()->select('service_id', [], request('service_id'))
                                    ->id('service_id')
                                    ->class('form-control select2js')
                                    ->attribute('data-ajax--url', route('ajax-list', ['type' => 'service']))
                                    ->attribute('data-ajax--cache', 'true')
                                    ->attribute('data-ajax--delay', '250')
                                    ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.service')]))
                                    ->attribute('data-allow-clear', 'true') !!}
                            </div>
                        </div>

                        <div class="border-radius-10" id="map" style="height: 600px;"></div>
                        <div id="maplegend" class="">
                            <div class="d-flex align-items-center gap-2 mb-2">
                                <span class="driver-dot online"></span> {{ __('message.online') }}
                            </div>
                            <div class="d-flex align-items-center gap-2 mb-2">
                                <span class="driver-dot in_service"></span> {{ __('message.in_service') }}
                            </div>
                            <div class="d-flex align-items-center gap-2">
                                <span class="driver-dot offline"></span> {{ __('message.offline') }}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    </div>
    @section('bottom_script')
        <script>
            $(document).ready(function() {
                let map;
                let markerCluster = null;
                let markers = [];
                let markerLookup = {};
                let infoWindow = null;
                const defaultCenter = { lat: 20, lng: 0 };
                const defaultZoom = 3;

                initializeMap();
                initOngoingDriverSearch();
                initDriverSearch();
                initDriverStatusFilter();
                initServiceFilter();
                loadDriverList();

                function initializeMap() {
                    map = new google.maps.Map(document.getElementById('map'), {
                        zoom: defaultZoom,
                        center: defaultCenter
                    });
                    infoWindow = new google.maps.InfoWindow();

                    const legend = document.getElementById("maplegend");
                    map.controls[google.maps.ControlPosition.RIGHT_BOTTOM].push(legend);
                    $('#maplegend').removeClass('d-none');
                }

                function loadDriverList() {
                    $.ajax({
                        type: 'GET',
                        url: "{{ route('driver_list.map') }}",
                        data: {
                            driver_status: $('#driver_status').val(),
                            service_id: $('#service_id').val()
                        },
                        success: function(res) {
                            const drivers = (res.data || []).map(driver => ({
                                ...driver,
                                lat: Number(driver.latitude),
                                lng: Number(driver.longitude),
                                status: getDriverStatus(driver)
                            })).filter(driver => !Number.isNaN(driver.lat) && !Number.isNaN(driver.lng));

                            if (drivers.length > 0) {
                                updateDriverMarkers(drivers);
                            } else {
                                clearAllMarkers();
                            }
                        }
                    });
                }

                function updateDriverMarkers(drivers) {
                    clearAllMarkers();

                    const bounds = new google.maps.LatLngBounds();
                    markers = drivers.map(driver => {

                        const marker = new google.maps.Marker({
                            position: { lat: driver.lat, lng: driver.lng },
                            map: map,
                            title: driver.display_name,
                            icon: {
                                path: google.maps.SymbolPath.CIRCLE,
                                scale: 7,
                                fillColor: getDriverColor(driver.status),
                                fillOpacity: 1,
                                strokeWeight: 1,
                                strokeColor: "#ffffff"
                            }
                        });

                        marker.addListener('click', function() {
                            showDriverInfo(driver.id, marker);
                        });

                        markerLookup[driver.id] = marker;
                        bounds.extend(marker.getPosition());

                        return marker;
                    });

                    markerCluster = new markerClusterer.MarkerClusterer({
                        map,
                        markers
                    });

                    if (!bounds.isEmpty()) {
                        map.fitBounds(bounds);
                    }
                }

                function clearAllMarkers() {
                    if (markerCluster) {
                        markerCluster.clearMarkers();
                        markerCluster = null;
                    }
                    markers.forEach(marker => {
                        marker.setMap(null);
                    });
                    markers = [];
                    markerLookup = {};
                }

                function showDriverInfo(driverId, marker) {
                    const url = "{{ route('driverDetail', ['id' => '__id__']) }}".replace('__id__', driverId);
                    $.ajax({
                        type: 'GET',
                        url: url,
                        success: function(res) {
                            if (res.data) {
                                const driver = res.data;
                                const contentString = `
                                    <div class="map_driver_detail">
                                        <ul class="list-unstyled mb-0">
                                            <li><i class="fa fa-address-card"></i>: ${driver.display_name}</li>
                                            <li><i class="fa fa-phone"></i>: ${driver.contact_number}</li>
                                            <li><i class="fa fa-taxi"></i>: ${driver.driver_service?.name || '-'}</li>
                                            <li><i class="fa fa-clock"></i>: ${driver.last_location_update_at_ago || driver.last_location_update_at || '-'}</li>
                                            <li>
                                                <a href="{{ route('driver.show', '') }}/${driverId}">
                                                    <i class="fa fa-eye"></i> {{ __('message.view_form_title', ['form' => __('message.driver')]) }}
                                                </a>
                                            </li>
                                        </ul>
                                    </div>`;
                                infoWindow.setContent(contentString);
                                infoWindow.open(map, marker);
                            }
                        }
                    });
                }

                function initDriverSearch() {
                    $('#driverSearch').select2({
                        ajax: {
                            url: "{{ route('ajax-list', ['type' => 'driver']) }}",
                            dataType: 'json',
                            delay: 250,
                            processResults: function(data) {
                                return { results: data.results };
                            }
                        },
                        placeholder: "{{ __('message.select_field', ['name' => __('message.driver')]) }}",
                        allowClear: true
                    });

                    $('#driverSearch').on('select2:select', function(e) {
                        zoomToDriver(e.params.data.id);
                    });

                    $('#driverSearch').on('select2:clear', resetMap);
                }

                function initOngoingDriverSearch() {
                    $('#ongoing_driver_id').select2({
                        ajax: {
                            url: "{{ route('ajax-list', ['type' => 'ongoing_driver']) }}",
                            dataType: 'json',
                            delay: 250,
                            processResults: function(data) {
                                return { results: data.results };
                            }
                        },
                        placeholder: "{{ __('message.select_field', ['name' => __('message.ongoing_driver')]) }}",
                        allowClear: true
                    });

                    $('#ongoing_driver_id').on('select2:select', function(e) {
                        zoomToDriver(e.params.data.id);
                    });

                    $('#ongoing_driver_id').on('select2:clear', resetMap);
                }

                function initDriverStatusFilter() {
                    $('#driver_status').on('change', loadDriverList);
                }

                function initServiceFilter() {
                    $('#service_id').select2({
                        ajax: {
                            url: "{{ route('ajax-list', ['type' => 'service']) }}",
                            dataType: 'json',
                            delay: 250,
                            processResults: function(data) {
                                return {
                                    results: [
                                        { id: '', text: "{{ __('message.all') }}" },
                                        ...(data.results || [])
                                    ]
                                };
                            }
                        },
                        placeholder: "{{ __('message.select_field', ['name' => __('message.service')]) }}",
                        allowClear: true
                    });

                    $('#service_id').on('select2:select select2:clear', loadDriverList);
                }

                function zoomToDriver(driverId) {
                    const url = "{{ route('driver.search', ['id' => '__id__']) }}".replace('__id__', driverId);
                    $.ajax({
                        type: 'GET',
                        url: url,
                        success: function(res) {
                            if (res.data) {
                                const driver = res.data;

                                const position = {
                                    lat: Number(driver.latitude),
                                    lng: Number(driver.longitude)
                                };

                                if (!Number.isNaN(position.lat) && !Number.isNaN(position.lng)) {
                                    map.panTo(position);
                                    map.setZoom(15);
                                }

                                const marker = markerLookup[driverId];
                                if (marker) {
                                    showDriverInfo(driverId, marker);
                                }
                            } else {
                                alert("{{ __('message.driver_not_found') }}");
                            }
                        }
                    });
                }

                function resetMap() {
                    map.setZoom(defaultZoom);
                    map.setCenter(defaultCenter);
                    loadDriverList();
                }
                function getDriverStatus(driver) {
                    if (!Number(driver.is_online)) return 'offline';
                    return Number(driver.is_available) ? 'online' : 'in_service';
                }

                function getDriverColor(status) {
                    switch (status) {
                        case 'online': return '#22c55e';
                        case 'in_service': return '#facc15';
                        case 'offline': return '#ef4444';
                        default: return '#6b7280';
                    }
                }
            });
        </script>
    @endsection

</x-master-layout>

<x-master-layout :assets="$assets ?? []">
    <div class="realtime-dashboard-page">
    <div class="card border-radius-10 realtime-dashboard-card overflow-hidden mb-0">
        <div class="card-body p-3 p-lg-4">
            <div class="dashboard-status-strip mb-3 bg-white border border-radius-10 p-2">
                <div class="d-flex justify-content-end align-items-center mb-2">
                    <span class="realtime-refresh-label mr-2">{{__('message.update_in_time')}}</span>
                    <span class="badge badge-light-primary text-primary px-3 py-2" id="refreshCountdown">60s</span>
                </div>
                <div class="dashboard-status-grid" id="dashboardStatusGrid">
                    @foreach ($dashboardCards as $card)
                        <div class="status-tile status-tile-{{ $card['color'] }} bg-white text-center">
                            <div class="status-tile-count">{{ $card['count'] }}</div>
                            <div class="status-tile-label">{{ __('message.' . $card['label_key']) }}</div>
                        </div>
                    @endforeach
                </div>
            </div>

            <div class="border border-radius-10 realtime-map-frame mb-3 overflow-hidden">
                <div class="border-radius-10" id="map"></div>
            </div>

            <div class="realtime-data-panel bg-white border border-radius-10 p-3">
                <div class="table-responsive realtime-table-wrap">
                    <table class="table table-striped table-hover mb-0 realtime-table">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>{{ __('message.rider') }}</th>
                                <th>{{ __('message.contact_number') }}</th>
                                <th>{{ __('message.driver') }}</th>
                                <th>{{ __('message.service') }}</th>
                                <th>{{ __('message.pickup_address') }}</th>
                                <th>{{ __('message.drop_address') }}</th>
                                <th>{{ __('message.total_amount') }}</th>
                                <th>{{ __('message.status') }}</th>
                                <th>{{ __('message.created_at') }}</th>
                                <th>{{ __('message.action') }}</th>
                            </tr>
                        </thead>
                        <tbody id="rideRequestTableBody">
                            @forelse ($rideRequestTable as $ride)
                                <tr>
                                    <td>#{{ $ride['id'] }}</td>
                                    <td>{{ $ride['rider_name'] }}</td>
                                    <td>{{ $ride['client_number'] }}</td>
                                    <td>{{ $ride['driver_name'] }}</td>
                                    <td>{{ $ride['service_name'] }}</td>
                                    <td class="text-break">{{ $ride['pickup_address'] }}</td>
                                    <td class="text-break">{{ $ride['drop_address'] }}</td>
                                    <td>{{ $ride['total_amount'] }}</td>
                                    <td>
                                        <span class="text-{{ $ride['status_color'] }} badge badge-light-{{ $ride['status_color'] }}">
                                            {{ $ride['status_label'] }}
                                        </span>
                                    </td>
                                    <td>{{ $ride['created_at'] }}</td>
                                    <td>
                                        <a href="{{ route('riderequest.show', $ride['id']) }}" class="text-primary">
                                            {{ __('message.view') }}
                                        </a>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="11" class="text-center">{{ __('message.no_record_found') }}</td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
    </div>

    @section('bottom_script')
        <script>
            $(document).ready(function() {
                let refreshSeconds = 60;
                let map;
                let rideMarkers = [];
                let rideMarkerCluster = null;
                let rideRequests = @json($rideRequests);
                let refreshRequestInFlight = false;
                const refreshUrl = "{{ route('realtime.dashboard.data') }}";
                const rideShowUrlTemplate = "{{ route('riderequest.show', '__id__') }}";
                const noRecordFoundText = @json(__('message.no_record_found'));
                const viewText = @json(__('message.view'));
                const focusedRideZoom = 15;
                const markerColorMap = {
                    arriving: '#6366F1',
                    info: '#00B5D8',
                    primary: '#2563EB',
                    warning: '#F59E0B',
                    success: '#16A34A',
                    danger: '#DC2626',
                    secondary: '#6B7280'
                };

                startRefreshCountdown();
                initializeMap();
                renderRideMarkers(rideRequests);

                function startRefreshCountdown() {
                    const countdownElement = document.getElementById('refreshCountdown');

                    setInterval(() => {
                        refreshSeconds -= 1;

                        if (countdownElement) {
                            countdownElement.textContent = `${refreshSeconds}s`;
                        }

                        if (refreshSeconds <= 0) {
                            refreshDashboardData();
                        }
                    }, 1000);
                }

                function refreshDashboardData() {
                    if (refreshRequestInFlight) {
                        return;
                    }

                    refreshRequestInFlight = true;

                    $.ajax({
                        type: 'GET',
                        url: refreshUrl,
                        success: function(res) {
                            updateDashboardCards(res.dashboardCards || []);
                            updateRideTable(res.rideRequestTable || []);
                            rideRequests = res.rideRequests || [];
                            renderRideMarkers(rideRequests);
                            refreshSeconds = 60;
                            $('#refreshCountdown').text('60s');
                        },
                        complete: function() {
                            refreshRequestInFlight = false;
                        }
                    });
                }

                function initializeMap() {
                    const defaultLocation = new google.maps.LatLng(22.9734, 78.6569);
                    const mapOptions = {
                        zoom: 2,
                        center: defaultLocation,
                        mapTypeId: google.maps.MapTypeId.ROADMAP
                    };
                    map = new google.maps.Map(document.getElementById('map'), mapOptions);
                }

                function renderRideMarkers(rides) {
                    if (rideMarkerCluster) {
                        rideMarkerCluster.clearMarkers();
                        rideMarkerCluster = null;
                    }

                    rideMarkers.forEach(marker => marker.setMap(null));
                    rideMarkers = [];

                    rides.forEach(ride => {
                        const position = new google.maps.LatLng(ride.latitude, ride.longitude);
                        const markerColor = markerColorMap[ride.color] || markerColorMap.secondary;
                        const marker = new google.maps.Marker({
                            position: position,
                            map: map,
                            title: `#${ride.id} - ${ride.status_label}`,
                            icon: {
                                path: google.maps.SymbolPath.CIRCLE,
                                fillColor: markerColor,
                                fillOpacity: 1,
                                strokeColor: '#ffffff',
                                strokeWeight: 2,
                                scale: 8
                            }
                        });
                        marker.clusterColor = markerColor;

                        rideMarkers.push(marker);

                        const contentString = `
                            <div class="map_driver_detail">
                                <ul class="list-unstyled mb-0">
                                    <li><strong>ride_id:</strong> <a href="${rideShowUrlTemplate.replace('__id__', ride.id)}" class="text-primary">${ride.id}</a></li>
                                    <li><strong>{{ __('message.status') }}:</strong>
                                        <span class="badge badge-light-${ride.color} text-${ride.color}">${ride.status_label}</span>
                                    </li>
                                </ul>
                            </div>`;

                        const infowindow = new google.maps.InfoWindow({
                            content: contentString
                        });

                        marker.addListener('click', function() {
                            map.panTo(position);
                            if (map.getZoom() < focusedRideZoom) {
                                map.setZoom(focusedRideZoom);
                            }
                            infowindow.open(map, marker);
                        });
                    });

                    rideMarkerCluster = new markerClusterer.MarkerClusterer({
                        map,
                        markers: rideMarkers,
                        renderer: {
                            render({ count, position, markers }) {
                                const clusterColor = getClusterColor(markers);

                                return new google.maps.Marker({
                                    position,
                                    zIndex: Number(google.maps.Marker.MAX_ZINDEX) + count,
                                    icon: {
                                        url: `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(`
                                            <svg xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 56 56">
                                                <circle cx="28" cy="28" r="24" fill="${clusterColor}" fill-opacity="0.22"/>
                                                <circle cx="28" cy="28" r="18" fill="${clusterColor}" fill-opacity="0.5"/>
                                                <circle cx="28" cy="28" r="13" fill="${clusterColor}"/>
                                                <text x="28" y="32" text-anchor="middle" font-size="12" font-family="Arial, sans-serif" font-weight="700" fill="#ffffff">${count}</text>
                                            </svg>
                                        `)}`,
                                        scaledSize: new google.maps.Size(56, 56)
                                    }
                                });
                            }
                        }
                    });
                }

                function getClusterColor(markers) {
                    const colorCounts = markers.reduce((accumulator, marker) => {
                        const color = marker.clusterColor || markerColorMap.secondary;
                        accumulator[color] = (accumulator[color] || 0) + 1;
                        return accumulator;
                    }, {});

                    return Object.entries(colorCounts).sort((a, b) => b[1] - a[1])[0]?.[0] || markerColorMap.secondary;
                }

                function updateDashboardCards(cards) {
                    const grid = document.getElementById('dashboardStatusGrid');

                    if (!grid) {
                        return;
                    }

                    grid.innerHTML = cards.map(card => `
                        <div class="status-tile status-tile-${card.color} bg-white text-center">
                            <div class="status-tile-count">${escapeHtml(card.count)}</div>
                            <div class="status-tile-label">${escapeHtml(getCardLabel(card))}</div>
                        </div>
                    `).join('');
                }

                function updateRideTable(rides) {
                    const tableBody = document.getElementById('rideRequestTableBody');

                    if (!tableBody) {
                        return;
                    }

                    if (!rides.length) {
                        tableBody.innerHTML = `<tr><td colspan="11" class="text-center">${noRecordFoundText}</td></tr>`;
                        return;
                    }

                    tableBody.innerHTML = rides.map(ride => `
                        <tr>
                            <td>#${escapeHtml(ride.id)}</td>
                            <td>${escapeHtml(ride.rider_name)}</td>
                            <td>${escapeHtml(ride.client_number)}</td>
                            <td>${escapeHtml(ride.driver_name)}</td>
                            <td>${escapeHtml(ride.service_name)}</td>
                            <td class="text-break">${escapeHtml(ride.pickup_address)}</td>
                            <td class="text-break">${escapeHtml(ride.drop_address)}</td>
                            <td>${escapeHtml(ride.total_amount)}</td>
                            <td><span class="text-${escapeHtml(ride.status_color)} badge badge-light-${escapeHtml(ride.status_color)}">${escapeHtml(ride.status_label)}</span></td>
                            <td>${escapeHtml(ride.created_at)}</td>
                            <td><a href="${rideShowUrlTemplate.replace('__id__', ride.id)}" class="text-primary">${viewText}</a></td>
                        </tr>
                    `).join('');
                }

                function escapeHtml(value) {
                    return String(value ?? '')
                        .replace(/&/g, '&amp;')
                        .replace(/</g, '&lt;')
                        .replace(/>/g, '&gt;')
                        .replace(/"/g, '&quot;')
                        .replace(/'/g, '&#039;');
                }

                function getCardLabel(card) {
                    const labelMap = {
                        drivers: @json(__('message.drivers')),
                        today_jobs: @json(__('message.today_jobs')),
                        new_ride_requested: @json(__('message.new_ride_requested')),
                        accepted: @json(__('message.accepted')),
                        arrived: @json(__('message.arrived')),
                        arriving: 'Arriving',
                        in_progress: @json(__('message.in_progress')),
                        completed: @json(__('message.completed')),
                        canceled: @json(__('message.canceled'))
                    };

                    return labelMap[card.label_key] || card.label_key;
                }
            });
        </script>
    @endsection
</x-master-layout>

<x-master-layout :assets="$assets ?? []">
    <div class="container-fluid">
        <h5 class="font-weight-bold p-3">High Demand Zones</h5>
        <div class="card border-radius-10">
            <div class="card-body">
                <div class="border-radius-10" id="map" style="height: 600px;"></div>
                <div id="maplegend" class="maplegend">
                    <div style="margin-bottom: 8px;"><span style="color:red;">🔴</span> No Drivers Nearby</div>
                    <div style="margin-bottom: 8px;"><span style="color:orange;">🟠</span> Drivers Nearby</div>
                    <div><span style="color:green;">🟢</span> Assigned Ride</div>
                    <hr>
                    <div style="margin-bottom: 8px;"><img src="{{ asset('images/car-green.png') }}" width="18" />
                        Available Driver</div>
                    <div><img src="{{ asset('images/car-red.png') }}" width="18" /> Busy Driver</div>
                </div>
            </div>
        </div>
    </div>

    @section('bottom_script')
        <script>
            $(document).ready(function() {
                let map;
                let circleOverlays = {
                    red: [],
                    orange: [],
                    green: []
                };
                let driverMarkers = {
                    available: [],
                    busy: []
                };
                let allDriverMarkers = [];

                const driverIcons = {
                    available: "{{ asset('images/car-green.png') }}",
                    busy: "{{ asset('images/car-red.png') }}"
                };

                const circleColors = {
                    red: '#FF0000',
                    orange: '#FFA500',
                    green: '#008000'
                };

                initializeMap();
                loadData();

                function initializeMap() {
                    map = new google.maps.Map(document.getElementById('map'), {
                        zoom: 6,
                        center: {
                            lat: 22.3,
                            lng: 70.8
                        },
                        mapTypeId: google.maps.MapTypeId.ROADMAP
                    });

                    // Show/hide driver markers on zoom
                    map.addListener('zoom_changed', function() {
                        toggleDriverMarkers(map.getZoom());
                    });
                }

                function loadData() {
                    $.get("{{ route('demand.zone.list') }}", function(res) {
                        drawZones(res.zones);
                        drawDrivers(res.drivers); // just create markers, don't show yet
                        toggleDriverMarkers(map.getZoom()); // apply visibility based on initial zoom
                    });
                }

                function drawZones(zones) {
                    clearCircles();

                    zones.forEach(zone => {
                        const color = circleColors[zone.status];

                        const circle = new google.maps.Circle({
                            strokeColor: color,
                            strokeOpacity: 0.8,
                            strokeWeight: 10,
                            fillColor: color,
                            fillOpacity: 0.35,
                            map: map,
                            center: {
                                lat: parseFloat(zone.lat),
                                lng: parseFloat(zone.lng)
                            },
                            radius: 5000
                        });

                        circle.addListener('click', () => {
                            map.setZoom(12);
                            map.setCenter(circle.getCenter());

                            const rideInfo = zone.ride_details.map(r => {
                                const driverInfo = r.driver_name ?
                                    `<br/><strong>Driver:</strong> ${r.driver_name}` : '';
                                return `<div>
                                            <strong>Rider:</strong> ${r.rider_name || 'Unknown'}${driverInfo}<br/>
                                            <strong>Location:</strong> (${parseFloat(r.latitude).toFixed(3)}, ${parseFloat(r.longitude).toFixed(3)})
                                        </div>`;
                            }).join('<hr>');

                            const summary = `<div>
                                                <strong>Total Rides:</strong> ${zone.total_rides}<br/>
                                                <strong>Available Drivers:</strong> ${zone.available_drivers}
                                            </div><hr>`;

                            const infoWindow = new google.maps.InfoWindow({
                                content: `<div style="max-height:300px;overflow:auto">${summary}${rideInfo || 'No ride details'}</div>`,
                                position: circle.getCenter()
                            });

                            infoWindow.open(map);
                        });

                        circleOverlays[zone.status].push(circle);
                    });
                }


                function drawDrivers(drivers) {
                    clearDrivers();
                    allDriverMarkers = [];

                    drivers.forEach(driver => {
                        const status = driver.is_available == 1 ? 'available' : 'busy';
                        const icon = {
                            url: driverIcons[status],
                            scaledSize: new google.maps.Size(25, 25)
                        };

                        const marker = new google.maps.Marker({
                            position: {
                                lat: parseFloat(driver.latitude),
                                lng: parseFloat(driver.longitude)
                            },
                            map: null, // hidden initially
                            icon: icon,
                            title: `Driver ${driver.name} - ${status}`
                        });

                        const infoWindow = new google.maps.InfoWindow({
                            content: `<div>
                                <strong>Driver:</strong> ${driver.name}<br/>
                                <strong>Status:</strong> ${status}<br/>
                                <strong>Online:</strong> ${driver.is_online ? 'Yes' : 'No'}<br/>
                                <strong>Available:</strong> ${driver.is_available ? 'Yes' : 'No'}<br/>
                                <strong>Location:</strong> (${parseFloat(driver.latitude).toFixed(3)}, ${parseFloat(driver.longitude).toFixed(3)})
                            </div>`
                        });

                        marker.addListener('click', () => {
                            infoWindow.open(map, marker);
                        });

                        driverMarkers[status].push(marker);
                        allDriverMarkers.push(marker);
                    });
                }

                function toggleDriverMarkers(zoomLevel) {
                    const show = zoomLevel >= 10;

                    allDriverMarkers.forEach(marker => {
                        marker.setMap(show ? map : null);
                    });
                }

                function clearCircles() {
                    Object.values(circleOverlays).flat().forEach(c => c.setMap(null));
                    circleOverlays = {
                        red: [],
                        orange: [],
                        green: []
                    };
                }

                function clearDrivers() {
                    Object.values(driverMarkers).flat().forEach(m => m.setMap(null));
                    driverMarkers = {
                        available: [],
                        busy: []
                    };
                    allDriverMarkers = [];
                }
            });
        </script>
    @endsection
</x-master-layout>

<x-master-layout :assets="$assets ?? []">
    <style>
        .live-tracking-page {
            padding-bottom: 1rem;
        }

        .live-tracking-map {
            min-height: 72vh;
            width: 100%;
        }

        .live-tracking-shell {
            background: linear-gradient(180deg, #ffffff 0%, #f7fbff 100%);
        }

        .live-tracking-controls {
            min-width: min(360px, 100%);
        }
    </style>

    <div class="container-fluid live-tracking-page">
        <div class="row">
            <div class="col-lg-12">
                <div class="card card-block card-stretch card-height border-radius-20 live-tracking-shell mb-0">
                    <div class="card-header d-flex flex-wrap justify-content-between align-items-center border-radius-20 gap-2">
                        <div class="header-title">
                            <h4 class="card-title mb-0">{{ __('message.live_tracking') }}</h4>
                        </div>
                        <div class="d-flex flex-wrap align-items-center gap-2 live-tracking-controls">
                            <select id="liveRideRequestSelect" class="form-control select2js" data-placeholder="{{ __('message.select_field', ['name' => __('message.ride_request_id')]) }}">
                                <option value=""></option>
                                @foreach (($liveTracking['rideOptions'] ?? []) as $ride)
                                    <option value="{{ $ride['id'] }}">{{ __('message.ride_request_id') }} #{{ $ride['id'] }}</option>
                                @endforeach
                            </select>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="border rounded-3 overflow-hidden bg-white">
                            <div id="liveTrackingMap" class="live-tracking-map"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    @section('bottom_script')
        <script>
            $(document).ready(function() {
                const liveTrackingDataUrl = "{{ route('admin.liveTracking.data') }}";
                const liveTrackingPolylineUrl = "{{ route('admin.liveTracking.directionsPolyline') }}";
                const rideShowUrlTemplate = "{{ route('riderequest.show', '__id__') }}";
                const liveTrackingDefaultCenter = { lat: 22.9734, lng: 78.6569 };
                let liveTrackingMap = null;
                let liveDirectionsService = null;
                let liveDirectionsRenderer = null;
                let liveDriverMarker = null;
                let liveDriverMarkers = {};
                let liveTargetMarker = null;
                let liveInfoWindow = null;
                let liveRoutePolyline = null;
                let liveRouteOutlinePolyline = null;
                let liveCurrentRoutePath = [];
                let liveTrackingRides = @json($liveTracking['rideItems'] ?? []);
                let liveTrackingRideOptions = @json($liveTracking['rideOptions'] ?? []);
                let liveSelectedRideId = null;
                let liveRefreshInFlight = false;
                let liveRouteRequestToken = 0;
                let liveMarkerAnimationToken = 0;
                let liveTrackingMode = 'idle';
                let liveRenderedRideId = null;
                let liveOverviewBoundsInitialized = false;
                const liveMarkerAnimationDuration = 1000;
                const liveTrackingFollowZoom = 17;

                initializeLiveRideRequestDropdown();
                initializeLiveTrackingMap();
                renderLiveTrackingState(liveTrackingRides, liveSelectedRideId);
                setInterval(refreshLiveTracking, 2000);

                function initializeLiveRideRequestDropdown() {
                    const rideSelect = $('#liveRideRequestSelect');

                    rideSelect.on('change', function() {
                        liveSelectedRideId = $(this).val() || null;

                        if (!liveSelectedRideId) {
                            liveTrackingRides = [];
                            renderLiveTrackingState(liveTrackingRides, liveSelectedRideId);
                            return;
                        }

                        refreshLiveTracking();
                    });
                }

                function initializeLiveTrackingMap() {
                    const mapElement = document.getElementById('liveTrackingMap');

                    if (!mapElement || typeof google === 'undefined' || !google.maps) {
                        return;
                    }

                    liveTrackingMap = new google.maps.Map(mapElement, {
                        zoom: 4,
                        center: liveTrackingDefaultCenter,
                        mapTypeId: google.maps.MapTypeId.ROADMAP
                    });

                    if (google.maps.DirectionsService) {
                        liveDirectionsService = new google.maps.DirectionsService();
                    }

                    if (google.maps.DirectionsRenderer) {
                        liveDirectionsRenderer = new google.maps.DirectionsRenderer({
                            suppressMarkers: true,
                            preserveViewport: true,
                            polylineOptions: {
                                strokeColor: '#1d4ed8',
                                strokeOpacity: 1,
                                strokeWeight: 8,
                                zIndex: 3
                            }
                        });
                        liveDirectionsRenderer.setMap(liveTrackingMap);
                    }

                    liveInfoWindow = new google.maps.InfoWindow();
                }

                function refreshLiveTracking() {
                    if (liveRefreshInFlight || !liveSelectedRideId) {
                        return;
                    }

                    liveRefreshInFlight = true;

                    $.ajax({
                        type: 'GET',
                        url: liveTrackingDataUrl,
                        data: {
                            ride_id: liveSelectedRideId
                        },
                        success: function(res) {
                            liveTrackingRides = res.rideItems || [];
                            liveTrackingRideOptions = res.rideOptions || liveTrackingRideOptions;

                            const rideExists = liveTrackingRides.some(ride => Number(ride.id) === Number(liveSelectedRideId));
                            if (!rideExists) {
                                liveSelectedRideId = null;
                            }

                            updateLiveRideRequestDropdown(liveTrackingRideOptions, liveSelectedRideId);
                            renderLiveTrackingState(liveTrackingRides, liveSelectedRideId);
                        },
                        complete: function() {
                            liveRefreshInFlight = false;
                        }
                    });
                }

                function updateLiveRideRequestDropdown(rideOptions, selectedRideId) {
                    const rideSelect = $('#liveRideRequestSelect');
                    const currentValue = rideSelect.val();
                    const nextValue = selectedRideId ? String(selectedRideId) : '';

                    rideSelect.empty().append(new Option('', '', false, false));

                    (rideOptions || []).forEach(ride => {
                        const optionValue = String(ride.id);
                        const optionLabel = `{{ __('message.ride_request_id') }} #${ride.id}`;
                        rideSelect.append(new Option(optionLabel, optionValue, false, optionValue === nextValue));
                    });

                    if (currentValue !== nextValue) {
                        rideSelect.val(nextValue).trigger('change.select2');
                    } else {
                        rideSelect.trigger('change.select2');
                    }
                }

                function renderLiveTrackingState(rides, selectedRideId) {
                    const selectedRide = rides.find(ride => Number(ride.id) === Number(selectedRideId)) || null;

                    if (!selectedRide) {
                        clearLiveTrackingMap();
                        liveTrackingMode = 'idle';
                        liveRenderedRideId = null;
                        return;
                    }

                    liveTrackingMode = 'ride';
                    renderLiveRideOnMap(selectedRide);
                }

                function renderLiveDriverMarkers(rides) {
                    if (!liveTrackingMap) {
                        return;
                    }

                    const bounds = new google.maps.LatLngBounds();
                    let hasDriverMarker = false;
                    const activeRideIds = new Set();
                    const previousMarkerCount = Object.keys(liveDriverMarkers).length;

                    (rides || []).forEach(ride => {
                        const driverLat = parseFloat(ride.driver_latitude);
                        const driverLng = parseFloat(ride.driver_longitude);

                        if ([driverLat, driverLng].some(Number.isNaN)) {
                            return;
                        }

                        const driverPosition = { lat: driverLat, lng: driverLng };
                        const markerKey = String(ride.id);
                        activeRideIds.add(markerKey);

                        let marker = liveDriverMarkers[markerKey];
                        if (!marker) {
                            marker = new google.maps.Marker({
                                position: driverPosition,
                                map: liveTrackingMap,
                                title: ride.driver_name,
                                optimized: false,
                                icon: buildLiveTrackingMarker('#2563eb', 'DR', parseFloat(ride.driver_heading), false)
                            });

                            marker.addListener('click', function() {
                                if (Number(liveSelectedRideId) === Number(ride.id)) {
                                    const showUrl = rideShowUrlTemplate.replace('__id__', ride.id);
                                    const content = `
                                        <div style="padding: 8px; font-family: sans-serif; color: #1f2937;">
                                            <h6 style="margin: 0 0 8px 0; font-size: 14px; font-weight: 600;">Ride Request #${ride.id}</h6>
                                            <p style="margin: 0 0 12px 0; font-size: 12px; color: #6b7280;">Driver: ${escapeHtml(ride.driver_name)}</p>
                                            <a href="${showUrl}" target="_blank" style="display: inline-block; padding: 6px 12px; background: #2563eb; color: white; text-decoration: none; border-radius: 6px; font-size: 12px; font-weight: 500;">View Ride Details</a>
                                        </div>
                                    `;
                                    liveInfoWindow.setContent(content);
                                    liveInfoWindow.open(liveTrackingMap, marker);
                                } else {
                                    liveSelectedRideId = ride.id;
                                    renderLiveRideOnMap(ride);
                                }
                            });

                            liveDriverMarkers[markerKey] = marker;
                        } else {
                            marker.setTitle(ride.driver_name);
                            animateLiveMarker(marker, driverPosition, {
                                color: '#2563eb',
                                label: 'DR',
                                heading: parseFloat(ride.driver_heading),
                                useRouteAnimation: true
                            });
                        }

                        bounds.extend(driverPosition);
                        hasDriverMarker = true;
                    });

                    Object.keys(liveDriverMarkers).forEach(markerKey => {
                        if (activeRideIds.has(markerKey)) {
                            return;
                        }

                        stopLiveMarkerAnimation(liveDriverMarkers[markerKey]);
                        liveDriverMarkers[markerKey].setMap(null);
                        delete liveDriverMarkers[markerKey];
                    });

                    if (hasDriverMarker) {
                        if (!liveOverviewBoundsInitialized || previousMarkerCount !== Object.keys(liveDriverMarkers).length) {
                            liveTrackingMap.fitBounds(bounds);
                            liveOverviewBoundsInitialized = true;
                        }
                    } else {
                        clearLiveTrackingMap();
                    }
                }

                function renderLiveRideOnMap(ride) {
                    if (!liveTrackingMap || !ride) {
                        return;
                    }

                    const driverLat = parseFloat(ride.driver_latitude);
                    const driverLng = parseFloat(ride.driver_longitude);
                    const targetLat = parseFloat(ride.target_latitude);
                    const targetLng = parseFloat(ride.target_longitude);

                    if ([driverLat, driverLng, targetLat, targetLng].some(Number.isNaN)) {
                        clearLiveTrackingMap();
                        return;
                    }

                    const driverPosition = { lat: driverLat, lng: driverLng };
                    const targetPosition = { lat: targetLat, lng: targetLng };
                    const bounds = new google.maps.LatLngBounds();
                    const isSameRide = Number(liveRenderedRideId) === Number(ride.id) && liveDriverMarker;
                    const shouldFitBounds = !isSameRide;

                    if (!isSameRide) {
                        clearLiveTrackingMap(false);

                        liveDriverMarker = new google.maps.Marker({
                            position: driverPosition,
                            map: liveTrackingMap,
                            title: ride.driver_name,
                            optimized: false,
                            icon: buildLiveTrackingMarker('#2563eb', 'DR', parseFloat(ride.driver_heading), false)
                        });

                        liveDriverMarker.addListener('click', function() {
                            const showUrl = rideShowUrlTemplate.replace('__id__', ride.id);
                            const content = `
                                <div style="padding: 8px; font-family: sans-serif; color: #1f2937;">
                                    <h6 style="margin: 0 0 8px 0; font-size: 14px; font-weight: 600;">Ride Request #${ride.id}</h6>
                                    <p style="margin: 0 0 12px 0; font-size: 12px; color: #6b7280;">Driver: ${escapeHtml(ride.driver_name)}</p>
                                    <a href="${showUrl}" target="_blank" style="display: inline-block; padding: 6px 12px; background: #2563eb; color: white; text-decoration: none; border-radius: 6px; font-size: 12px; font-weight: 500;">View Ride Details</a>
                                </div>
                            `;
                            liveInfoWindow.setContent(content);
                            liveInfoWindow.open(liveTrackingMap, liveDriverMarker);
                        });

                        liveTargetMarker = new google.maps.Marker({
                            position: targetPosition,
                            map: liveTrackingMap,
                            title: ride.target_label,
                            icon: buildLiveTrackingMarker('#ef4444', ride.target_type === 'drop' ? 'DL' : 'PU')
                        });

                        liveRouteOutlinePolyline = new google.maps.Polyline({
                            map: liveTrackingMap,
                            strokeColor: '#93c5fd',
                            strokeOpacity: 0.85,
                            strokeWeight: 14,
                            geodesic: false,
                            zIndex: 2
                        });

                        liveRoutePolyline = new google.maps.Polyline({
                            map: liveTrackingMap,
                            strokeColor: '#1d4ed8',
                            strokeOpacity: 1,
                            strokeWeight: 8,
                            geodesic: false,
                            zIndex: 3
                        });
                    } else {
                        liveDriverMarker.setTitle(ride.driver_name);
                        animateLiveMarker(liveDriverMarker, driverPosition, {
                            color: '#2563eb',
                            label: 'DR',
                            heading: parseFloat(ride.driver_heading),
                            followMarker: true,
                            keepCentered: true,
                            useRouteAnimation: true,
                            syncRoutePath: true,
                            routeDestination: targetPosition
                        });

                        if (liveTargetMarker) {
                            liveTargetMarker.setTitle(ride.target_label);
                            liveTargetMarker.setPosition(targetPosition);
                            liveTargetMarker.setIcon(buildLiveTrackingMarker('#ef4444', ride.target_type === 'drop' ? 'DL' : 'PU'));
                        }
                    }

                    bounds.extend(driverPosition);
                    bounds.extend(targetPosition);
                    liveRenderedRideId = ride.id;

                    const lastRefPos = liveDriverMarker.__lastRefetchPos;
                    const distanceMoved = lastRefPos
                        ? calculateLiveTrackingDistance(lastRefPos, driverPosition)
                        : 999;

                    if (distanceMoved > 0.0001) {
                        const currentToken = ++liveRouteRequestToken;
                        liveDriverMarker.__lastRefetchPos = driverPosition;

                        fetchLiveTrackingRoute(driverPosition, targetPosition)
                            .then(function(routeData) {
                                if (currentToken !== liveRouteRequestToken) {
                                    return;
                                }

                                applyLiveRouteResult(routeData);

                                if (shouldFitBounds && routeData.bounds) {
                                    liveTrackingMap.fitBounds(routeData.bounds);
                                } else if (shouldFitBounds && routeData.path.length) {
                                    routeData.path.forEach(point => bounds.extend(point));
                                    liveTrackingMap.fitBounds(bounds);
                                }
                            })
                            .catch(function() {
                                if (currentToken !== liveRouteRequestToken) {
                                    return;
                                }

                                clearLiveRoutePath();
                            });
                    }
                }

                function clearLiveTrackingMap(resetCenter = true) {
                    liveRouteRequestToken++;

                    Object.keys(liveDriverMarkers).forEach(markerKey => {
                        stopLiveMarkerAnimation(liveDriverMarkers[markerKey]);
                        liveDriverMarkers[markerKey].setMap(null);
                    });
                    liveDriverMarkers = {};

                    if (liveDriverMarker) {
                        stopLiveMarkerAnimation(liveDriverMarker);
                        liveDriverMarker.setMap(null);
                        liveDriverMarker = null;
                    }

                    if (liveTargetMarker) {
                        liveTargetMarker.setMap(null);
                        liveTargetMarker = null;
                    }

                    if (liveRoutePolyline) {
                        liveRoutePolyline.setMap(null);
                        liveRoutePolyline = null;
                    }

                    if (liveRouteOutlinePolyline) {
                        liveRouteOutlinePolyline.setMap(null);
                        liveRouteOutlinePolyline = null;
                    }

                    if (liveDirectionsRenderer) {
                        liveDirectionsRenderer.setDirections({ routes: [] });
                    }

                    liveCurrentRoutePath = [];
                    liveOverviewBoundsInitialized = false;

                    if (resetCenter && liveTrackingMap) {
                        liveTrackingMap.setCenter(liveTrackingDefaultCenter);
                        liveTrackingMap.setZoom(4);
                    }
                }

                function animateLiveMarker(marker, nextPosition, options = {}) {
                    if (!marker || !nextPosition || Number.isNaN(nextPosition.lat) || Number.isNaN(nextPosition.lng)) {
                        return;
                    }

                    if (marker.__liveTarget && positionsMatch(marker.__liveTarget, nextPosition)) {
                        return;
                    }
                    marker.__liveTarget = nextPosition;

                    const currentPosition = marker.getPosition();
                    const startPosition = currentPosition
                        ? { lat: currentPosition.lat(), lng: currentPosition.lng() }
                        : nextPosition;

                    const targetPosition = {
                        lat: nextPosition.lat,
                        lng: nextPosition.lng
                    };

                    const hasMovement = !positionsMatch(startPosition, targetPosition);
                    const heading = Number.isFinite(options.heading)
                        ? options.heading
                        : calculateLiveTrackingHeading(startPosition, targetPosition);

                    stopLiveMarkerAnimation(marker);
                    marker.setIcon(buildLiveTrackingMarker(options.color || '#2563eb', options.label || 'DR', heading, hasMovement));

                    if (!hasMovement) {
                        marker.setPosition(targetPosition);
                        return;
                    }

                    if (options.useRouteAnimation) {
                        animateLiveMarkerOnRoute(marker, startPosition, targetPosition, options, heading);
                        return;
                    }

                    startLiveMarkerAnimation(marker, [startPosition, targetPosition], options, heading);
                }

                function stopLiveMarkerAnimation(marker) {
                    if (marker && marker.__liveAnimationFrame) {
                        cancelAnimationFrame(marker.__liveAnimationFrame);
                        marker.__liveAnimationFrame = null;
                    }
                }

                function animateLiveMarkerOnRoute(marker, startPosition, targetPosition, options, heading) {
                    const distanceSinceLastRoute = marker.__lastRoutedPos
                        ? calculateLiveTrackingDistance(marker.__lastRoutedPos, targetPosition)
                        : 999;

                    if (distanceSinceLastRoute < 0.0002 && marker.__lastRoute) {
                        startLiveMarkerAnimation(marker, marker.__lastRoute, options, heading);
                        return;
                    }

                    const animationToken = ++liveMarkerAnimationToken;

                    fetchLiveTrackingRoute(startPosition, targetPosition)
                        .then(function(routeData) {
                            if (animationToken !== liveMarkerAnimationToken) {
                                return;
                            }

                            const animationPath = routeData.path.length >= 2
                                ? routeData.path
                                : [startPosition, targetPosition];

                            marker.__lastRoutedPos = targetPosition;
                            marker.__lastRoute = animationPath;

                            startLiveMarkerAnimation(marker, animationPath, options, heading);
                        })
                        .catch(function() {
                            if (animationToken !== liveMarkerAnimationToken) {
                                return;
                            }

                            startLiveMarkerAnimation(marker, [startPosition, targetPosition], options, heading);
                        });
                }

                function fetchLiveTrackingRoute(origin, destination) {
                    if (liveDirectionsService && google.maps.TravelMode) {
                        return new Promise(function(resolve, reject) {
                            liveDirectionsService.route({
                                origin: origin,
                                destination: destination,
                                travelMode: google.maps.TravelMode.DRIVING
                            }, function(result, status) {
                                if (status !== 'OK' || !result?.routes?.length) {
                                    reject(new Error('No road route found.'));
                                    return;
                                }

                                const route = result.routes[0];
                                resolve({
                                    directions: result,
                                    path: (route.overview_path || []).map(point => ({
                                        lat: point.lat(),
                                        lng: point.lng()
                                    })),
                                    bounds: route.bounds || null
                                });
                            });
                        });
                    }

                    return new Promise(function(resolve, reject) {
                        $.ajax({
                            type: 'GET',
                            url: liveTrackingPolylineUrl,
                            data: {
                                origin: `${origin.lat},${origin.lng}`,
                                destination: `${destination.lat},${destination.lng}`
                            },
                            success: function(res) {
                                const encodedPolyline = res?.polyline;
                                if (!(encodedPolyline && google.maps.geometry && google.maps.geometry.encoding)) {
                                    reject(new Error('No routed polyline found.'));
                                    return;
                                }

                                resolve({
                                    directions: null,
                                    path: google.maps.geometry.encoding.decodePath(encodedPolyline).map(point => ({
                                        lat: point.lat(),
                                        lng: point.lng()
                                    })),
                                    bounds: null
                                });
                            },
                            error: function() {
                                reject(new Error('Route lookup failed.'));
                            }
                        });
                    });
                }

                function startLiveMarkerAnimation(marker, animationPath, options, heading) {
                    const normalizedPath = (animationPath || []).map(point => ({
                        lat: typeof point.lat === 'function' ? point.lat() : point.lat,
                        lng: typeof point.lng === 'function' ? point.lng() : point.lng
                    })).filter(point => !Number.isNaN(point.lat) && !Number.isNaN(point.lng));

                    if (normalizedPath.length < 2) {
                        return;
                    }

                    const segmentLengths = [];
                    let totalDistance = 0;

                    for (let index = 1; index < normalizedPath.length; index++) {
                        const segmentDistance = calculateLiveTrackingDistance(normalizedPath[index - 1], normalizedPath[index]);
                        segmentLengths.push(segmentDistance);
                        totalDistance += segmentDistance;
                    }

                    if (totalDistance <= 0) {
                        marker.setPosition(normalizedPath[normalizedPath.length - 1]);
                        marker.setIcon(buildLiveTrackingMarker(options.color || '#2563eb', options.label || 'DR', heading, false));
                        if (options.syncRoutePath) {
                            syncLiveRoutePathWithMarker(normalizedPath[normalizedPath.length - 1], options.routeDestination);
                        }
                        return;
                    }

                    const animationStartedAt = performance.now();
                    const animationDuration = liveMarkerAnimationDuration;

                    let lastViewportUpdateAt = 0;
                    const step = function(now) {
                        const progress = Math.min((now - animationStartedAt) / animationDuration, 1);
                        const distanceToTravel = totalDistance * progress;
                        const routeProgress = getLiveTrackingRouteProgress(normalizedPath, segmentLengths, distanceToTravel);
                        const interpolatedPosition = routeProgress.position;

                        marker.setPosition(interpolatedPosition);
                        if (options.syncRoutePath) {
                            syncLiveRoutePathWithMarker(interpolatedPosition, options.routeDestination);
                        }

                        if (options.followMarker && liveTrackingMap) {
                            if (now - lastViewportUpdateAt > 1000 || progress === 1) {
                                updateLiveTrackingViewport(interpolatedPosition, options);
                                lastViewportUpdateAt = now;
                            }
                        }

                        if (progress < 1) {
                            marker.__liveAnimationFrame = requestAnimationFrame(step);
                            return;
                        }

                        marker.setPosition(normalizedPath[normalizedPath.length - 1]);
                        marker.setIcon(buildLiveTrackingMarker(options.color || '#2563eb', options.label || 'DR', heading, false));
                        if (options.syncRoutePath) {
                            syncLiveRoutePathWithMarker(normalizedPath[normalizedPath.length - 1], options.routeDestination);
                        }
                        marker.__liveAnimationFrame = null;
                    };

                    marker.__liveAnimationFrame = requestAnimationFrame(step);
                }

                function setLiveRoutePath(routePath) {
                    liveCurrentRoutePath = (routePath || []).map(point => ({
                        lat: typeof point.lat === 'function' ? point.lat() : point.lat,
                        lng: typeof point.lng === 'function' ? point.lng() : point.lng
                    })).filter(point => !Number.isNaN(point.lat) && !Number.isNaN(point.lng));

                    if (liveRouteOutlinePolyline) {
                        liveRouteOutlinePolyline.setPath(liveCurrentRoutePath);
                    }

                    if (liveRoutePolyline) {
                        liveRoutePolyline.setPath(liveCurrentRoutePath);
                    }
                }

                function drawLiveRoutePath(routePath) {
                    if (liveRouteOutlinePolyline) {
                        liveRouteOutlinePolyline.setPath(routePath);
                    }

                    if (liveRoutePolyline) {
                        liveRoutePolyline.setPath(routePath);
                    }
                }

                function syncLiveRoutePathWithMarker(markerPosition, fallbackDestination = null) {
                    if (!markerPosition) {
                        return;
                    }

                    if (!liveCurrentRoutePath.length) {
                        drawLiveRoutePath(fallbackDestination ? [markerPosition, fallbackDestination] : [markerPosition]);
                        return;
                    }

                    let closestIndex = 0;
                    let closestDistance = Number.POSITIVE_INFINITY;

                    liveCurrentRoutePath.forEach((point, index) => {
                        const distance = calculateLiveTrackingDistance(markerPosition, point);
                        if (distance < closestDistance) {
                            closestDistance = distance;
                            closestIndex = index;
                        }
                    });

                    const remainingPath = liveCurrentRoutePath.slice(Math.min(closestIndex + 1, liveCurrentRoutePath.length - 1));
                    drawLiveRoutePath([markerPosition, ...remainingPath]);
                }

                function clearLiveRoutePath() {
                    setLiveRoutePath([]);
                    if (liveDirectionsRenderer) {
                        liveDirectionsRenderer.setDirections({ routes: [] });
                    }
                }

                function applyLiveRouteResult(routeData) {
                    if (liveDirectionsRenderer) {
                        liveDirectionsRenderer.setDirections({ routes: [] });
                    }

                    setLiveRoutePath(routeData?.path || []);
                }

                function updateLiveTrackingViewport(position, options = {}) {
                    if (!liveTrackingMap) {
                        return;
                    }

                    const mapCenter = liveTrackingMap.getCenter();
                    const currentZoom = liveTrackingMap.getZoom() || 0;
                    const targetZoom = Math.max(currentZoom, liveTrackingFollowZoom);

                    if (options.keepCentered) {
                        if (currentZoom < targetZoom) {
                            liveTrackingMap.setZoom(targetZoom);
                        }
                        liveTrackingMap.setCenter(position);
                        return;
                    }

                    const bounds = liveTrackingMap.getBounds();
                    if (!bounds || !bounds.contains(position)) {
                        if (mapCenter) {
                            liveTrackingMap.panTo(position);
                        } else {
                            liveTrackingMap.setCenter(position);
                        }
                    }
                }

                function positionsMatch(firstPosition, secondPosition) {
                    return Math.abs(firstPosition.lat - secondPosition.lat) < 0.000001
                        && Math.abs(firstPosition.lng - secondPosition.lng) < 0.000001;
                }

                function calculateLiveTrackingHeading(startPosition, endPosition) {
                    if (positionsMatch(startPosition, endPosition)) {
                        return 0;
                    }

                    const startLat = startPosition.lat * (Math.PI / 180);
                    const startLng = startPosition.lng * (Math.PI / 180);
                    const endLat = endPosition.lat * (Math.PI / 180);
                    const endLng = endPosition.lng * (Math.PI / 180);
                    const deltaLng = endLng - startLng;
                    const y = Math.sin(deltaLng) * Math.cos(endLat);
                    const x = Math.cos(startLat) * Math.sin(endLat) - Math.sin(startLat) * Math.cos(endLat) * Math.cos(deltaLng);

                    return ((Math.atan2(y, x) * (180 / Math.PI)) + 360) % 360;
                }

                function calculateLiveTrackingDistance(startPosition, endPosition) {
                    const latDiff = endPosition.lat - startPosition.lat;
                    const lngDiff = endPosition.lng - startPosition.lng;

                    return Math.sqrt((latDiff * latDiff) + (lngDiff * lngDiff));
                }

                function getLiveTrackingPointAtDistance(path, segmentLengths, distanceToTravel) {
                    return getLiveTrackingRouteProgress(path, segmentLengths, distanceToTravel).position;
                }

                function getLiveTrackingRouteProgress(path, segmentLengths, distanceToTravel) {
                    let traversedDistance = 0;

                    for (let index = 1; index < path.length; index++) {
                        const segmentDistance = segmentLengths[index - 1];
                        const nextTraversedDistance = traversedDistance + segmentDistance;

                        if (distanceToTravel <= nextTraversedDistance) {
                            const segmentProgress = segmentDistance === 0
                                ? 1
                                : (distanceToTravel - traversedDistance) / segmentDistance;

                            return {
                                position: {
                                    lat: path[index - 1].lat + ((path[index].lat - path[index - 1].lat) * segmentProgress),
                                    lng: path[index - 1].lng + ((path[index].lng - path[index - 1].lng) * segmentProgress)
                                },
                                segmentIndex: index - 1
                            };
                        }

                        traversedDistance = nextTraversedDistance;
                    }

                    return {
                        position: path[path.length - 1],
                        segmentIndex: Math.max(path.length - 2, 0)
                    };
                }

                function easeInOutCubic(progress) {
                    return progress < 0.5
                        ? 4 * progress * progress * progress
                        : 1 - Math.pow(-2 * progress + 2, 3) / 2;
                }

                function buildLiveTrackingMarker(color, label, heading = 0, isMoving = false) {
                    const safeHeading = Number.isFinite(heading) ? heading : 0;
                    const movingRing = isMoving
                        ? `<circle cx="24" cy="24" r="20" fill="none" stroke="${color}" stroke-opacity="0.24" stroke-width="6"></circle>`
                        : '';

                    return {
                        url: `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(`
                            <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
                                ${movingRing}
                                <circle cx="24" cy="24" r="16" fill="${color}" stroke="#ffffff" stroke-width="4"></circle>
                                <g transform="rotate(${safeHeading} 24 24)">
                                    <path d="M24 4 L29 14 L24 11 L19 14 Z" fill="#0f172a" opacity="0.9"></path>
                                </g>
                                <text x="24" y="29" text-anchor="middle" font-size="12" font-family="Arial, sans-serif" font-weight="700" fill="#ffffff">${label}</text>
                            </svg>
                        `)}`,
                        scaledSize: new google.maps.Size(48, 48),
                        anchor: new google.maps.Point(24, 24)
                    };
                }

                function escapeHtml(value) {
                    return String(value ?? '').replace(/[&<>"']/g, function(character) {
                        return {
                            '&': '&amp;',
                            '<': '&lt;',
                            '>': '&gt;',
                            '"': '&quot;',
                            "'": '&#039;'
                        }[character];
                    });
                }
            });
        </script>
    @endsection
</x-master-layout>

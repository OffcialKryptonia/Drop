<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null; ?>
        {!! html()->modelForm($data,'PATCH', route('region.update', $id))
            ->attribute('enctype', 'multipart/form-data')
            ->open() !!}
        <div class="row">
            <div class="col-lg-12">
                <div class="card">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.name') . ' <span class="text-danger">*</span>')
                                        ->for('name')->class('form-control-label') !!}
                                    {!! html()->text('name', old('name'))
                                        ->placeholder(__('message.name'))
                                        ->class('form-control')
                                        ->required() !!}
                                </div>

                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.distance_unit') . ' <span class="text-danger">*</span>')
                                        ->for('distance_unit')->class('form-control-label') !!}
                                    {!! html()->select('distance_unit', ['km' => __('message.km'),'mile' => __('message.mile')], old('distance_unit'))
                                        ->class('form-control select2js')
                                        ->required() !!}
                                </div>

                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.timezone'))->for('timezone')->class('form-control-label') !!}
                                    {!! html()->select('timezone', [ $data['timezone'] => timeZoneList()[$data['timezone']] ], old('timezone'))
                                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'timezone']))
                                        ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.timezone')]))
                                        ->class('form-control select2js')
                                        ->required() !!}
                                </div>

                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.status') . ' <span class="text-danger">*</span>')
                                        ->for('status')->class('form-control-label') !!}
                                    {!! html()->select('status', ['1' => __('message.active'),'0' => __('message.inactive')], old('status'))
                                        ->class('form-control select2js')
                                        ->required() !!}
                                </div>
                            </div>

                            <div class="row mt-4">
                                <div class="col-md-4">
                                    <img class="w-100" src="{{ asset('images/region.gif') }}" alt="">
                                    <p><i class="far fa-hand-paper"></i> {{ __('message.drag_map_area') }}</p>
                                    <p>{{ __('message.connect_dot_draw_area') }}</p>
                                </div>

                                <div class="form-group col-md-8" style="height:500px;">
                                    <div id="map-canvas" style="height: 100%; width: 100%;"></div>
                                    {!! html()->hidden('coordinates', json_encode($data->coordinates))->id('coordinates') !!}
                                </div>
                            </div>

                            <hr>
                            {!! html()->submit(__('message.save'))->class('btn border-radius-10 btn-primary float-right') !!}
                        </div>
                    </div>
                </div>
            </div>
        </div>
        {!! html()->form()->close() !!}
    </div>

    @section('bottom_script')
        <script>
            $(function(){
                var map;
                var drawingManager;
                var lastPolygon = null;
                var bounds = new google.maps.LatLngBounds();

                function initialize() {
                    let polygonData = @json(is_string($data->coordinates) ? json_decode($data->coordinates, true) : ($data->coordinates ?? []));
                    if (typeof polygonData === 'string') {
                        try {
                            polygonData = JSON.parse(polygonData);
                        } catch (e) {
                            polygonData = [];
                        }
                    }
                    if (!Array.isArray(polygonData)) polygonData = [];
                    let centerPoint = { lat: 0, lng: 0 }; // fallback
                    if (polygonData.length) {
                        centerPoint = { lat: polygonData[0][0], lng: polygonData[0][1] };
                    }

                    let myLatlng = new google.maps.LatLng(centerPoint.lat, centerPoint.lng);

                    map = new google.maps.Map(document.getElementById('map-canvas'), {
                        zoom: 13,
                        center: myLatlng,
                        mapTypeId: google.maps.MapTypeId.ROADMAP
                    });

                    if (polygonData.length) {
                        let polygonCoords = polygonData.map(function(coord) {
                            return { lat: coord[0], lng: coord[1] };
                        });

                        let zonePolygon = new google.maps.Polygon({
                            paths: polygonCoords,
                            strokeColor: "#050df2",
                            strokeOpacity: 0.8,
                            strokeWeight: 2,
                            fillOpacity: 0.1,
                            editable: false
                        });

                        zonePolygon.setMap(map);

                        zonePolygon.getPaths().forEach(function (path) {
                            path.forEach(function (latlng) {
                                bounds.extend(latlng);
                            });
                        });

                        map.fitBounds(bounds);
                    }

                    drawingManager = new google.maps.drawing.DrawingManager({
                        drawingMode: google.maps.drawing.OverlayType.POLYGON,
                        drawingControl: true,
                        drawingControlOptions: {
                            position: google.maps.ControlPosition.TOP_CENTER,
                            drawingModes: [google.maps.drawing.OverlayType.POLYGON]
                        },
                        polygonOptions: {
                            editable: true
                        }
                    });

                    drawingManager.setMap(map);

                    google.maps.event.addListener(drawingManager, 'overlaycomplete', function (event) {
                        if (lastPolygon) lastPolygon.setMap(null);
                        lastPolygon = event.overlay;

                        const path = event.overlay.getPath().getArray().map(function (latlng) {
                            return [latlng.lat(), latlng.lng()];
                        });

                        $('#coordinates').val(JSON.stringify(path));
                    });

                    const resetDiv = document.createElement('div');
                    resetMap(resetDiv);
                    map.controls[google.maps.ControlPosition.TOP_CENTER].push(resetDiv);
                }

                function resetMap(controlDiv) {
                    const controlUI = document.createElement('div');
                    controlUI.style.backgroundColor = '#fff';
                    controlUI.style.border = '2px solid #fff';
                    controlUI.style.borderRadius = '3px';
                    controlUI.style.boxShadow = '0 2px 6px rgba(0,0,0,.3)';
                    controlUI.style.cursor = 'pointer';
                    controlUI.style.marginTop = '8px';
                    controlUI.style.marginBottom = '22px';
                    controlUI.style.textAlign = 'center';
                    controlUI.title = "{{ __('message.reset_map') }}";
                    controlDiv.appendChild(controlUI);
                    const controlText = document.createElement('div');
                    controlText.style.color = 'rgb(25,25,25)';
                    controlText.style.fontFamily = 'Roboto,Arial,sans-serif';
                    controlText.style.fontSize = '10px';
                    controlText.style.lineHeight = '16px';
                    controlText.style.paddingLeft = '2px';
                    controlText.style.paddingRight = '2px';
                    controlText.innerHTML = 'X';
                    controlUI.appendChild(controlText);
                    controlUI.addEventListener('click', () => {
                        if (lastPolygon) lastPolygon.setMap(null);
                        $('#coordinates').val('');
                    });
                }

                if (window.google && window.google.maps) {
                    initialize();
                }
            });
        </script>
    @endsection
</x-master-layout>

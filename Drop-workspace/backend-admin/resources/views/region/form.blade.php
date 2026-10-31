<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('region.update', $id))->attribute('enctype', 'multipart/form-data')->open() !!}
        @else
            {!! html()->form('POST', route('region.store'))->attribute('enctype','multipart/form-data')->open() !!}
        @endif
        <div class="row">
            <div class="col-lg-12 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <a href="{{route('region.index')}}" class="float-right btn btn-sm border-radius-10 btn-primary me-2" role="button"><i class="fas fa-arrow-circle-left"></i> {{ __('message.back') }}</a>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                {!! html()->hidden('coordinates', old('coordinates'))->id('coordinates') !!}
                            
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.name') . ' <span class="text-danger">*</span>')->for('name')->class('form-control-label') !!}
                                    {!! html()->text('name', old('name'))->placeholder(__('message.name'))->class('form-control')->required() !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.distance_unit') . ' <span class="text-danger">*</span>')->for('distance_unit')->class('form-control-label') !!}
                                    {!! html()->select('distance_unit', ['km' => __('message.km'),'mile' => __('message.mile')], old('distance_unit'))->class('form-control select2js')->required() !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.timezone'))->for('timezone')->class('form-control-label') !!}
                                    {!! html()->select('timezone', [], old('timezone'))->attribute('data-ajax--url', route('ajax-list', ['type' => 'timezone']))->attribute('data-placeholder', __('message.select_field', ['name' => __('message.timezone')]))->class('form-control select2js')->required() !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.status') . ' <span class="text-danger">*</span>')->for('status')->class('form-control-label') !!}
                                    {!! html()->select('status', ['1' => __('message.active'),'0' => __('message.inactive')], old('status'))->class('form-control select2js')->required() !!}
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-4">
                                    <img class="w-100 border-radius-10" src="{{asset('images/region.gif')}}" alt="">
                                    <p><i class="far fa-hand-paper"></i> {{ __('message.drag_map_area') }} </p>
                                    <p>{{ __('message.connect_dot_draw_area') }} </p>
                                    <p>{{ __('message.follow_coordinates') }} </p>
                                </div>
                                <div class="form-group col-md-8" style="height:500px;">
                                    <div id="map-canvas" class="border-radius-20"></div>
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
        $(document).ready(function() {
            
            var map; // Global declaration of the map
            var drawingManager;
            var last_latlong = null;
            var polygons = [];
            
            function initialize() {
                var myLatlng = new google.maps.LatLng(20.947940, 72.955786);
                var myOptions = {
                    zoom: 13,
                    center: myLatlng,
                    mapTypeId: google.maps.MapTypeId.ROADMAP
                }
                
                map = new google.maps.Map(document.getElementById('map-canvas'), myOptions);
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

                const resetDiv = document.createElement('div');
                resetMap(resetDiv, last_latlong);
                map.controls[google.maps.ControlPosition.TOP_CENTER].push(resetDiv);
            }             
            if(window.google || window.google.maps) {
                initialize();
            }
            if (navigator.geolocation) {
                navigator.geolocation.getCurrentPosition( 
                    (position) => {
                    const pos = {
                        lat: position.coords.latitude,
                        lng: position.coords.longitude,
                    };
                    map.setCenter(pos);
                });
            }
            
            google.maps.event.addListener(drawingManager, 'overlaycomplete', function(event) {
                if ( last_latlong ) {
                    last_latlong.setMap(null);
                }
                
                $('#coordinates').val(event.overlay.getPath().getArray());
                last_latlong = event.overlay;
                auto_grow();
            });

            function auto_grow() {
                let element = document.getElementById('coordinates');
                element.style.height = '5px';
                element.style.height = (element.scrollHeight)+'px';
            }

            function resetMap(controlDiv)
            {
                // Set CSS for the control border.
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
                // Set CSS for the control interior.
                const controlText = document.createElement('div');
                controlText.style.color = 'rgb(25,25,25)';
                controlText.style.fontFamily = 'Roboto,Arial,sans-serif';
                controlText.style.fontSize = '10px';
                controlText.style.lineHeight = '16px';
                controlText.style.paddingLeft = '2px';
                controlText.style.paddingRight = '2px';
                controlText.innerHTML = 'X';
                controlUI.appendChild(controlText);
                // Setup the click event listeners: simply set the map to Chicago.
                controlUI.addEventListener('click', () => {
                    last_latlong.setMap(null);
                    $('#coordinates').val('');
                });
            }
        
        });
    </script>
    @endsection
</x-master-layout>

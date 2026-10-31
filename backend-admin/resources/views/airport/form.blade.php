<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('airport.update', $id))->open() !!}
        @else
            {!! html()->form('POST', route('airport.store'))->open() !!}
        @endif
        <div class="row">
            <div class="col-lg-12 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <a href="{{route('airport.index')}}" class="float-right btn btn-sm border-radius-10 btn-primary me-2" role="button"><i class="fas fa-arrow-circle-left"></i> {{ __('message.back') }}</a>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.airport_id').' <span class="text-danger">*</span>')->class('form-control-label')->for('airport_id')!!}
                                    {!! html()->number('airport_id', old('airport_id'))->class('form-control')->placeholder(__('message.airport_id'))->id('airport_id') !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.ident').' <span class="text-danger">*</span>')->class('form-control-label') !!}
                                    {!! html()->text('ident',old('ident'))->class('form-control')->placeholder(__('message.ident')) !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.type').' <span class="text-danger">*</span>')->class('form-control-label') !!}
                                    {!! html()->text('type',old('type'))->class('form-control')->placeholder(__('message.type')) !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.name').' <span class="text-danger">*</span>')->class('form-control-label') !!}
                                    {!! html()->text('name',old('name'))->class('form-control')->placeholder(__('message.name')) !!}
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.iso_country').' <span class="text-danger">*</span>')->class('form-control-label') !!}
                                    {!! html()->text('iso_country',old('iso_country'))->class('form-control')->placeholder(__('message.iso_country')) !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.iso_region').' <span class="text-danger">*</span>')->class('form-control-label') !!}
                                    {!! html()->text('iso_region',old('iso_region'))->class('form-control')->placeholder(__('message.iso_region')) !!}
                                </div>
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.municipality').' <span class="text-danger">*</span>')->class('form-control-label') !!}
                                    {!! html()->text('municipality',old('municipality'))->class('form-control')->placeholder(__('message.municipality')) !!}
                                </div>
                            </div>   

                        <h4 class="card-title">{{ __('message.location') }}</h4>
                        <hr>
                        <div class="row">
                            <div class="col-lg-6">
                                <div class="row" style="padding:10px">
                                    <div style="height: 355px;width: 600px;" id="map"></div>                              
                                </div>
                            </div>                           
                            <div class="col-lg-6">
                                <div class="row">
                                    <div class="form-group col-md-12">
                                        {{ html()->label(__('message.latitude') . ' <span class="text-danger">*</span>', 'latitude')->class('form-control-label') }}
                                        {{ html()->number('latitude_deg')->class('form-control')->attribute('step','any')->placeholder(__('message.latitude')) }}
                                    </div>
                                    <div class="form-group col-md-12">
                                        {{ html()->label(__('message.longitude') . ' <span class="text-danger">*</span>', 'longitude')->class('form-control-label') }}
                                        {{ html()->number('longitude_deg')->class('form-control')->attribute('step','any')->placeholder(__('message.longitude')) }}
                                    </div>
                                </div>
                            </div>
                        </div>
                            </div>
                            <hr>
                            {!! html()->submit(isset($id) ? __('message.update') : __('message.save'))->class('btn border-radius-10 btn-primary float-right') !!}
                        </div>
                    </div>
                </div>
            </div>
        </div>
        {!! html()->form()->close() !!}
    </div>
    @section('bottom_script')
    <script>
        var map;
        var marker;
        var geocoder;

        function initMap() {
            geocoder = new google.maps.Geocoder();

            if ('{{ $id }}' !== '' && '{{ $id }}' !== undefined) {
                var get_latitude_data = {{ $data->latitude_deg ?? 0 }};
                var get_longitude_data = {{ $data->longitude_deg ?? 0 }};
                var myLatlng = { lat: get_latitude_data, lng: get_longitude_data };
                initializeMap(myLatlng);
            } else {
                if (navigator.geolocation) {
                    navigator.geolocation.getCurrentPosition(function(position) {
                        var myLatlng = {
                            lat: position.coords.latitude,
                            lng: position.coords.longitude
                        };
                        initializeMap(myLatlng);
                    }, function(error) {
                        var myLatlng = { lat: 22.316258503105992, lng: 70.83204484790207 };
                        initializeMap(myLatlng);
                    });
                } else {
                    var myLatlng = { lat: 22.316258503105992, lng: 70.83204484790207 };
                    initializeMap(myLatlng);
                }
            }
        }    
        function initializeMap(myLatlng) {
            map = new google.maps.Map(document.getElementById('map'), {
                zoom: 3,
                center: myLatlng
            });

            marker = new google.maps.Marker({
                position: myLatlng,
                map: map,
                draggable: true 
            });

            google.maps.event.addListener(map, 'click', function(event) {
                placeMarker(event.latLng);
            });
            google.maps.event.addListener(marker, 'dragend', function () {
                updateMarkerPosition(marker.getPosition());
            });
        
            // Input change listener
            document.getElementById('latitude_deg').addEventListener('input', updateMapFromInput);
            document.getElementById('longitude_deg').addEventListener('input', updateMapFromInput);
        }

        function placeMarker(location) {
            if (marker) {
                marker.setPosition(location);
            } else {
                marker = new google.maps.Marker({
                    position: location,
                    map: map,
                    draggable: true
                });
            }
            updateMarkerPosition(location);
        }

        function updateMarkerPosition(location) {
            document.getElementById('latitude_deg').value = location.lat();
            document.getElementById('longitude_deg').value = location.lng();
        }
        function updateMapFromInput() {
            var lat = parseFloat(document.getElementById('latitude_deg').value);
            var lng = parseFloat(document.getElementById('longitude_deg').value);
        
            if (!isNaN(lat) && !isNaN(lng)) {
                var location = new google.maps.LatLng(lat, lng);
                marker.setPosition(location);
                map.setCenter(location);
                map.setZoom(13);
                document.getElementById('map').scrollIntoView({ behavior: 'smooth' });
            }
        }
        window.onload = initMap;
    </script>
@endsection
</x-master-layout>
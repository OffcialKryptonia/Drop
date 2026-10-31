<x-master-layout :assets="$assets ?? []">
<style>
    #place-autocomplete-card {
        background: white;
        padding: 10px;
        border-radius: 8px;
        max-width: 100%;
        width: 100%;
        margin-bottom: 10px;
    }
    #map {
  border-radius: 12px;
  overflow: hidden;
}

</style>
<div>
    <?php $id = $id ?? null;?>
    @if(isset($id))
        {{ html()->modelForm($data, 'PATCH', route('managezone.update', $id) )->open() }}
    @else
        {{ html()->form('POST', route('managezone.store'))->open() }} 
    @endif
        <div class="row">
            <div class="col-lg-12">
                <div class="card">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                        <div class="card-action">
                            <a href="{{ route('managezone.index') }} " class="btn btn-sm btn-primary" role="button">{{ __('message.back') }}</a>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="form-group col-md-6">
                                    {{ html()->label(__('message.name') . ' <span class="text-danger">*</span>', 'name')->class('form-control-label') }}
                                    {{ html()->text('name', old('name'))->class('form-control')->placeholder(__('message.name'))->required()}}
                                </div>
                                <div class="form-group col-md-6">
                                    {{ html()->label(__('message.status') . ' <span class="text-danger">*</span>', 'status')->class('form-control-label') }}
                                    {{ html()->select('status', ['active' => __('message.active'), 'inactive' => __('message.inactive')], old('status'))->class('form-control select2js')->required() }}
                                </div>
                            </div>
                        </div>
                        <h4 class="card-title">{{ __('message.location') }}</h4>
                        <hr>
                        <div class="row">
                                <div class="col-lg-6">
                                <div class="form-group">
                                    <label>{{ __('message.search_location') }}</label>
                                    <div id="place-autocomplete-card"></div>
                                </div>
                                <div class="row" style="padding:10px">
                                    <div style="height: 355px;width: 800px;" id="map"></div>                              
                                </div>
                            </div>                           
                            <div class="col-lg-6">
                                <div class="row">
                                    <div class="form-group col-md-12">
                                        {{ html()->label(__('message.latitude') . ' <span class="text-danger">*</span>', 'latitude')->class('form-control-label') }}
                                        {{ html()->number('latitude')->class('form-control')->attribute('step','any')->placeholder(__('message.latitude'))->attribute('readonly', true) }}
                                    </div>
                                    <div class="form-group col-md-12">
                                        {{ html()->label(__('message.longitude') . ' <span class="text-danger">*</span>', 'longitude')->class('form-control-label') }}
                                        {{ html()->number('longitude')->class('form-control')->attribute('step','any')->placeholder(__('message.longitude'))->attribute('readonly', true) }}
                                    </div>
                                    <div class="form-group col-md-12">
                                        {{ html()->label(__('message.description'), 'description')->class('form-control-label') }}
                                        {{ html()->textarea('description')->class('form-control textarea')->attribute('rows',3)->placeholder(__('message.description'))->required() }}
                                    </div>
                                </div>
                            </div>
                        </div>
                        <hr>
                        {{ html()->submit( __('message.save') )->class('btn btn-md btn-primary float-right') }}
                    </div>
                </div>
            </div>
        </div>
        <div id="place-autocomplete-card" style="margin:10px; z-index: 5; position: absolute;">
        </div>
    {{ html()->form()->close() }}
</div>
@section('bottom_script')
    <script>
        var map;
        var marker;
        var geocoder;
        var infoWindow;

        async function initMap() {
            geocoder = new google.maps.Geocoder();
            const [{ Map }, { AdvancedMarkerElement }] = await Promise.all([
                google.maps.importLibrary("maps"),
                google.maps.importLibrary("marker"),
                google.maps.importLibrary("places")
            ]);

            let myLatlng;

            if ('{{ $id }}' !== '' && '{{ $id }}' !== undefined) {
                myLatlng = { lat: {{ $data->latitude ?? 0 }}, lng: {{ $data->longitude ?? 0 }} };
                initializeMap(myLatlng);
            } else if (navigator.geolocation) {
                navigator.geolocation.getCurrentPosition(
                    position => {
                        myLatlng = { lat: position.coords.latitude, lng: position.coords.longitude };
                        initializeMap(myLatlng);
                    },
                    () => {
                        myLatlng = { lat: 22.316258503105992, lng: 70.83204484790207 };
                        initializeMap(myLatlng);
                    }
                );
            } else {
                myLatlng = { lat: 22.316258503105992, lng: 70.83204484790207 };
                initializeMap(myLatlng);
            }

            function initializeMap(myLatlng) {
                map = new Map(document.getElementById('map'), {
                    center: myLatlng,
                    zoom: 13,
                    mapId: '4504f8b37365c3d0',
                    mapTypeControl: true
                });

                // Add place autocomplete input
                const placeAutocomplete = new google.maps.places.PlaceAutocompleteElement();
                placeAutocomplete.id = 'place-autocomplete-input';
                placeAutocomplete.locationBias = myLatlng;

                const card = document.getElementById('place-autocomplete-card');
                card.appendChild(placeAutocomplete);

                // Add marker and info window
                marker = new AdvancedMarkerElement({
                    map,
                    position: myLatlng,
                    gmpDraggable: true
                });

                infoWindow = new google.maps.InfoWindow({});

                // When dragging ends
                marker.addListener('dragend', () => {
                    const pos = marker.position;
                    updateMarkerPosition(pos);
                });

                // When clicking map
                map.addListener('click', function (event) {
                    marker.position = event.latLng;
                    updateMarkerPosition(event.latLng);
                });

                // On selecting from autocomplete
                placeAutocomplete.addEventListener('gmp-select', async ({ placePrediction }) => {
                    const place = placePrediction.toPlace();
                    await place.fetchFields({ fields: ['displayName', 'formattedAddress', 'location', 'viewport'] });

                    if (place.viewport) {
                        map.fitBounds(place.viewport);
                    } else {
                        map.setCenter(place.location);
                        map.setZoom(17);
                    }

                    const content = `
                        <div><strong>${place.displayName}</strong><br>${place.formattedAddress}</div>
                    `;
                    marker.position = place.location;
                    updateMarkerPosition(place.location);
                });
            }

            function updateMarkerPosition(location) {
                document.getElementById('latitude').value = location.lat();
                document.getElementById('longitude').value = location.lng();

                geocoder.geocode({ location: location }, function (results, status) {
                    if (status === 'OK') {
                        if (results[0]) {
                            const fullAddress = results[0].formatted_address;
                            document.getElementById('address').value = fullAddress || '';
                        } else {
                            alert("{{ __('message.no_result_found') }}");
                        }
                    } else {
                        alert("{{ __('message.geocoder_failed') }} " + status);
                    }
                });
            }

            function updateInfoWindow(content, center) {
                infoWindow.setContent(content);
                infoWindow.setPosition(center);
                infoWindow.open({ map, anchor: marker, shouldFocus: false });
            }
        }
        window.onload = initMap;
    </script>
@endsection
</x-master-layout>

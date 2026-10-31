<x-master-layout>
@php
    $id = $id ?? null;
@endphp

<div class="row">
    <div class="col-lg-12">
        <div class="card">
            <div class="card-header d-flex justify-content-between">
                <h4 class="card-title">
                    {{ $pageTitle }}
                </h4>
                <a href="{{ route('managezone-price.index') }}" class="btn btn-primary btn-sm">Back</a>
            </div>
            <div class="card-body">
                @if($id)
                    {{ html()->modelForm($zonePrice, 'PATCH', route('managezone-price.update', $id))->open() }}
                @else
                    {{ html()->form('POST', route('managezone-price.store'))->open() }}
                @endif

                <div class="row">
                    <div class="form-group col-md-6">
                        {{ html()->label(__("message.zone_pickup"))->class('form-control-label') }}
                        {{ html()->select('pickup_zone_id', $zones, old('pickup_zone_id', $zonePrice->zone_pickup ?? null))->class('form-control select2js')->id('pickup_zone')->required() }}
                    </div>

                    <div class="form-group col-md-6">
                        {{ html()->label(__("message.zone_dropoff"))->class('form-control-label') }}
                        {{ html()->select('dropoff_zone_id', $zones, old('dropoff_zone_id', $zonePrice->zone_dropoff ?? null))->class('form-control select2js')->id('dropoff_zone')->required() }}
                    </div>
                    <div class="form-group col-md-12">
                        {{ html()->label(__('message.service'))->class('form-control-label') }}
                        {{ html()->select('service_ids[]', $selectedServices ?? [], isset($id) ? $selectedServiceIds : [])
                            ->class('select2js form-group')
                            ->multiple('multiple')
                            ->attribute('data-ajax--url', route('ajax-list', ['type' => 'service_ids']))
                            ->attribute('required', 'required')
                        }}
                    </div>

                    <div class="form-group col-md-6">
                        {{ html()->label(__('message.price'))->class('form-control-label') }}
                        {{ html()->number('price', old('price', $zonePrice->price ?? null))->class('form-control')->required() }}
                    </div>
                </div>

                <div class="form-group text-right">
                    {{ html()->submit($id ? __('message.update') : __('message.save'))->class('btn btn-md btn-primary') }}
                </div>

                {{ html()->form()->close() }}
            </div>
        </div>
    </div>
</div>

@section('bottom_script')
<script>
    $(document).ready(function () {
        function filterDropoffOptions() {
            let selectedPickup = $('#pickup_zone').val();
            let currentDropoff = $('#dropoff_zone').val();

            $('#dropoff_zone option').each(function () {
                const val = $(this).val();
                $(this).prop('disabled', false);
                if (val === selectedPickup) {
                    $(this).prop('disabled', true);
                }
            });
            if (currentDropoff === selectedPickup) {
                $('#dropoff_zone').val('').trigger('change');
            }
            $('#dropoff_zone').select2(); // Refresh Select2 to apply changes
        }
        $('#pickup_zone').on('change', filterDropoffOptions);

        filterDropoffOptions();
    });
</script>
@endsection

</x-master-layout>

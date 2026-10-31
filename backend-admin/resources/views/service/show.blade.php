<x-master-layout>
    <div class="container-fluid">
        <div class="row">
            <div class="col-lg-12">
                <div class="card shadow-sm border-0">
                    <div class="card-header border-bottom">
                        <div class="d-flex justify-content-between align-items-center">
                            <h5 class="mb-0">{{ $pageTitle }}</h5>
                            <a href="{{ route('service.index') }}" class="btn btn-sm btn-primary">
                                <i class="fa fa-angle-double-left me-1"></i> {{ __('message.back') }}
                            </a>
                        </div>
                    </div>
                    <div class="card-body">
                        @if ($data)
                            <div class="row g-4">
                                <div class="col-md-6 col-lg-3">
                                    <div class="border rounded p-3 h-100">
                                        <h6 class="text-primary border-bottom pb-2 mb-3">
                                            <i class="fa fa-car me-1"></i> {{ $pageTitle }}
                                        </h6>
                                        <dl class="row mb-0">
                                            <dt class="col-6">{{ __('message.name') }}</dt>
                                            <dd class="col-6">{{ $data->name }}</dd>
        
                                            <dt class="col-6">{{ __('message.service_type') }}</dt>
                                            {{-- <dd class="col-6">{{ str_replace('_',' ', ucfirst($data->service_type ?? 'N/A')) }}</dd> --}}
        
                                            <dt class="col-6">{{ __('message.region') }}</dt>
                                            <dd class="col-6">{{ optional($data->region)->name }}</dd>
                                            @if(in_array($data->service_type, ['book_ride','both']))
                                                <dt class="col-6">{{ __('message.capacity') }}</dt>
                                                <dd class="col-6">{{ $data->capacity }}</dd>
                                            @endif    
                                        </dl>
                                    </div>
                                </div>
        
                                {{-- Fare Details --}}
                                <div class="col-md-6 col-lg-3">
                                    <div class="border rounded p-3 h-100">
                                        <h6 class="text-success border-bottom pb-2 mb-3">
                                            <i class="fa fa-money-bill me-1"></i> {{ __('message.fare_details') }}
                                        </h6>
                                        <dl class="row mb-0">
                                                <dt class="col-7">{{ __('message.base_fare') }}</dt>
                                                <dd class="col-5">{{ getPriceFormat($data->base_fare) ?? 0 }}</dd>
                                        
                                                <dt class="col-7">{{ __('message.minimum_fare') }}</dt>
                                                <dd class="col-5">{{ getPriceFormat($data->minimum_fare) ?? 0 }}</dd>
                                        
                                                <dt class="col-7">{{ __('message.per_distance') }}</dt>
                                                <dd class="col-5">{{ getPriceFormat($data->per_distance) }}</dd>
                                        
                                                <dt class="col-7">{{ __('message.per_minute_drive') }}</dt>
                                                <dd class="col-5">{{ getPriceFormat($data->per_minute_drive) }}</dd>
                                        
                                                <dt class="col-7">{{ __('message.per_minute_wait') }}</dt>
                                                <dd class="col-5">{{ getPriceFormat($data->per_minute_wait) }}</dd>
                                        
                                                <dt class="col-7">{{ __('message.waiting_time_limit') }}</dt>
                                                <dd class="col-5">{{ $data->waiting_time_limit }}</dd>
                                        
                                                <dt class="col-7">{{ __('message.cancellation_fee') }}</dt>
                                                <dd class="col-5">{{ getPriceFormat($data->cancellation_fee) ?? 0 }}</dd>
                                        
                                                <dt class="col-7">{{ __('message.minimum_distance') }}</dt>
                                                <dd class="col-5">{{ $data->minimum_distance ?? 0 }}</dd>
                                        </dl>
                                    </div>
                                </div>
        
                                {{-- Commission Info --}}
                                <div class="col-md-6 col-lg-3">
                                    <div class="border rounded p-3 h-100">
                                        <h6 class="text-warning border-bottom pb-2 mb-3">
                                            <i class="fa fa-percent me-1"></i> {{ __('message.commission_details') }}
                                        </h6>
                                        <dl class="row mb-0">
                                            <dt class="col-7">{{ __('message.commission_type') }}</dt>
                                            <dd class="col-5">{{ ucfirst($data->commission_type) }}</dd>
        
                                            <dt class="col-7">{{ __('message.admin_commission') }}</dt>
                                            <dd class="col-5">
                                                {{ $data->commission_type == 'percentage' ? $data->admin_commission . '%' : getPriceFormat($data->admin_commission ?? 0) }}
                                            </dd>

        
                                            {{--  <dt class="col-7">{{ __('message.fleet_commission') }}</dt>
                                            <dd class="col-5">{{ $data->fleet_commission }}%</dd>  --}}
        
                                            <dt class="col-7">{{ __('message.payment_method') }}</dt>
                                            {{-- <dd class="col-5">{{ str_replace('_',' & ',ucfirst($data->payment_method)) }}</dd> --}}
                                            <dd class="col-5">
                                                {{ collect($data->payment_method)->map(fn($m) => ucfirst(str_replace('_', ' ', $m)))->implode(' & ') }}
                                            </dd>

                                        </dl>
        
                                        @if(!empty($data->description))
                                            <h6 class="mt-3 mb-1 text-muted">{{ __('message.description') }}</h6>
                                            <p class="small text-muted">{{ $data->description }}</p>
                                        @endif
                                    </div>
                                </div>
        
                                {{-- Additional Info --}}
                                <div class="col-md-6 col-lg-3">
                                    <div class="border rounded p-3 h-100">
                                        <h6 class="text-info border-bottom pb-2 mb-3">
                                            <i class="fa fa-info-circle me-1"></i> {{ __('message.additional_info') }}
                                        </h6>
                                        <dl class="row mb-0">
                                            <dt class="col-6">{{ __('message.created_at') }}</dt>
                                            <dd class="col-6">{{ $data->created_at->format('Y-m-d H:i') ?? '-' }}</dd>
        
                                            <dt class="col-6">{{ __('message.status') }}</dt>
                                            <dd class="col-6">
                                                @php
                                                    $status = $data->status == '1' ? 'success' : 'danger';
                                                    $status_name = $data->status == '1' ? __('message.active') : __('message.inactive');
                                                @endphp
                                                <span class="badge bg-{{ $status }}">{{ $status_name }}</span>
                                            </dd>
                                        </dl>
                                    </div>
                                </div>
                            </div>
                        @else
                            <div class="alert alert-info mt-4">
                                {{ __('message.no_record_found') }}
                            </div>
                        @endif
                    </div>
                </div>
            </div>
        </div>
        @section('bottom_script')
        @endsection
    </div>
</x-master-layout>

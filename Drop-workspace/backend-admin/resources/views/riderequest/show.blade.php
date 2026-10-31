<x-master-layout :assets="$assets ?? []">
    <div class="container-fluid">
        <div class="row">
            <div class="col-lg-8">
                <div class="card">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h5></h5>
                            <h4 class="card-title mb-0">{{ __('message.riderequest') }} ({{ __('message.'.$data->trip_type) }})</h4>
                             @if(!empty($data->schedule_datetime))
                                <small>{{ __('message.schedule_datetime') }} : {{ $data->schedule_datetime ?? '' }}</small>
                            @endif
                        </div>
                        <div class="d-flex align-items-center gap-2">
                            <h4 class="bg-primary rounded p-1 px-3 mb-0 ml-3">#{{ $data->id }}</h4>
                        </div>
                    </div>

                    <div class="card shadow-sm border-0 mb-4">
                        <div class="card-body">
                            <div class="row mb-4">
                                <div class="col-md-6">
                                    <div class="d-flex flex-column">
                                        <span class="text-muted medium mb-1">{{ __('message.pickup_address') }}</span>
                                        <span class="font-weight-bold">{{ $data->start_address }}</span>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="d-flex flex-column">
                                        <span class="text-muted medium mb-1">{{ __('message.drop_address') }}</span>
                                        <span class="font-weight-bold">{{ $data->end_address }}</span>
                                    </div>
                                </div>
                            </div>
                            <hr>

                            <div class="row">
                                <div class="col-md-3 col-6 mb-3 mb-md-0 border-end">
                                    <div class="d-flex flex-column">
                                        <h6 class="text-muted">
                                            {{ __('message.distance_travelled') }} / {{ __('message.total_distance') }}
                                        </h6>

                                        <span class="fw-bold">
                                            {{ number_format($data->distance_travelled, 2) }} / {{ number_format($data->distance, 2) }} {{ $data->distance_unit }}
                                        </span>
                                    </div>
                                </div>
                                <div class="col-md-3 col-6 mb-3 mb-md-0 border-end">
                                    <div class="d-flex flex-column">
                                        <h6 class="text-muted">{{__('message.completed_trip_duration')}} / {{ __('message.total_duration') }}</h6>
                                        <span class="fw-bold">{{ number_format($data->completed_trip_duration, 2) }} / {{ number_format($data->duration, 2) }} {{ __('message.min') }}</span>
                                    {{-- @dd($data->duration); --}}
                                    </div>

                                </div>
                                @php
                                    $totalAmount = $data->total_amount ?? 0;
                                    $commission = $data->admin_commission ?? 0;
                                    $driverEarning = $totalAmount - $commission;
                                @endphp
                                <div class="col-md-3 col-6 border-end">
                                    <div class="d-flex flex-column">
                                        <h6 class="text-muted">{{ __('message.admin_commission') }}</h6>
                                        <span class="fw-bold">{{ getPriceFormat($commission)}}</span>
                                        {{-- @dd($data->payment); --}}
                                    </div>
                                </div>
                                <div class="col-md-3 col-6">
                                    <div class="d-flex flex-column">
                                        <h6 class="text-muted">{{ __('message.driver_earning') }}</h6>
                                        <span class="fw-bold">{{ getPriceFormat($driverEarning) }}</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                @if($data->trip_type == 'airport_pickup' || $data->trip_type == 'airport_drop' || $data->trip_type == 'zone_to_airport' || $data->trip_type == 'airport_to_zone')
                    <div class="row">
                        <div class="col-md-12 mb-4">
                            <div class="card shadow-sm border-0">
                                <div class="card-header">
                                    <h6 class="mb-0"><strong>{{ __('message.flight_details') }}</strong></h6>
                                </div>
                                <div class="card-body">
                                    <div class="row g-3">
                                        <div class="col-md-6">
                                            <p><strong>{{ __('message.trip_type') }}:</strong> {{ $data->trip_type ? ucwords(str_replace('_', ' ', $data->trip_type)) : 'regular' }}</p>
                                            @if($data->trip_type == 'airport_pickup' || $data->trip_type == 'airport_drop' || $data->trip_type == 'zone_to_airport' || $data->trip_type == 'airport_to_zone')
                                            <p><strong>{{ __('message.flight_number') }}:</strong> {{ $data->flight_number ?? '-' }}</p>
                                            <p><strong>{{ __('message.pickup_point') }}:</strong> {{ $data->pickup_point ?? '-' }}</p>
                                                @if($data->preferred_pickup_time !== null || $data->preferred_dropoff_time !== null)
                                                    @if($data->preferred_pickup_time !== null)
                                                        <p><strong>{{ __('message.preferred_pickup_time') }}:</strong> {{ $data->preferred_pickup_time }}</p>
                                                    @endif

                                                    @if($data->preferred_dropoff_time !== null)
                                                        <p><strong>{{ __('message.preferred_dropoff_time') }}:</strong> {{ $data->preferred_dropoff_time }}</p>
                                                    @endif
                                                @endif

                                            @endif
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                @endif
                @if ($data->status == 'completed')
                    <div class="row g-4">
                        {{-- ================= RIDER CARD ================= --}}
                        <div class="col-md-6">
                            <div class="card shadow-sm border-0 h-100">
                                <div class="card-header text-center">
                                    <h6 class="mb-0 fw-bold">{{ __('message.rider_fare_breakdown') }}</h6>
                                </div>
                                <div class="card-body px-3">
                                    @if(($data->surge_amount ?? 0) > 0)
                                        <div class="d-flex justify-content-between mb-2 fw-semibold">
                                            <span>{{ __('message.fare_amount') }}</span>
                                            <span>{{ getPriceFormat($data->subtotal ?? 0) }}</span>
                                        </div>
                                        <div class="d-flex justify-content-between mb-2 text-danger">
                                            <span>{{ __('message.high_demand_charge') }}</span>
                                            <span>+ {{ getPriceFormat($data->surge_amount) }}</span>
                                        </div>
                                        <hr>
                                    @endif
                                    @if(($data->coupon_discount ?? 0) > 0)
                                        <div class="d-flex justify-content-between mb-2 text-success">
                                            <span>{{ __('message.coupon_discount') }}</span>
                                            <span>- {{ getPriceFormat($data->coupon_discount) }}</span>
                                        </div>
                                        <hr>
                                    @endif
                                    @if($data->extra_charges_amount > 0)
                                        <h5>{{ __('message.additional_charge_amount') }}</h5>
                                        <hr>
                                        @foreach($data->extra_charges as $charge)
                                            <div class="d-flex justify-content-between mb-2 fw-bold">
                                                <span>{{ $charge['key'] ?? '' }}</span>
                                                <span>
                                                + {{ getPriceFormat($charge['value'] ?? 0) }}
                                                </span>
                                            </div>
                                        @endforeach
                                        <hr>
                                    @endif
                                    @php
                                        $total = $data->total_amount ?? 0;
                                        $extra_charge = $data->extra_charges_amount ?? 0;
                                        $total_amount = $total + $extra_charge;
                                    @endphp
                                    <div class="d-flex justify-content-between fs-5 fw-bold">
                                        <span>{{ __('message.total_amount') }}</span>
                                        <span class="{{ $data->status === 'canceled' ? 'text-danger' : 'text-success' }}">
                                            {{ getPriceFormat($total_amount) }}
                                        </span>
                                    </div>
                                </div>
                            </div>
                        </div>
                        {{-- ================= DRIVER CARD ================= --}}
                        <div class="col-md-6">
                            <div class="card shadow-sm border-0 h-100">
                                <div class="card-header text-center">
                                    <h6 class="mb-0 fw-bold">{{ __('message.driver_fare_breakdown') }}</h6>
                                </div>
                                <div class="card-body px-3">
                                    @if($data->trip_type != 'zone_wise' && $data->ride_has_bid != 1)
                                        <div class="d-flex justify-content-between mb-2">
                                            <span>{{ __('message.base_fare') }}</span>
                                            <span>{{ getPriceFormat($data->base_fare ?? 0) }}</span>
                                        </div>
                                        @if(round($chargeable_distance, 2) > 0)
                                            <div class="d-flex justify-content-between mb-2">
                                                <span>
                                                    {{ __('message.distance_fare') }}
                                                    ({{ round($chargeable_distance, 2) }} × {{ getPriceFormat($data->service?->per_distance ?? 0) }})
                                                </span>
                                                <span>{{ getPriceFormat($distance_price ?? 0) }}</span>
                                            </div>
                                        @endif
                                        <div class="d-flex justify-content-between mb-2">
                                            <span>{{ __('message.extra_ride_time') }}</span>
                                            <span>{{ getPriceFormat($data->time_price ?? 0) }}</span>
                                        </div>

                                        <hr>
                                    @endif
                                    <div class="d-flex justify-content-between mb-2 fw-semibold">
                                        <span>{{ __('message.sub_total') }}</span>
                                        <span>{{ getPriceFormat($data->subtotal ?? 0) }}</span>
                                    </div>
                                    @if(($data->surge_amount ?? 0) > 0)
                                        <div class="d-flex justify-content-between mb-2 text-danger">
                                            <span>{{ __('message.high_demand_charge') }}</span>
                                            <span>+ {{ getPriceFormat($data->surge_amount) }}</span>
                                        </div>
                                        <hr>
                                    @endif

                                    @if(($data->coupon_discount ?? 0) > 0)
                                        <div class="d-flex justify-content-between mb-2 text-success">
                                            <span>{{ __('message.coupon_discount') }}</span>
                                            <span>- {{ getPriceFormat($data->coupon_discount) }}</span>
                                        </div>
                                        <hr>
                                    @endif
                                    <div class="d-flex justify-content-between mb-2 fw-bold">
                                        <span>{{ __('message.estimated_fare') }}</span>
                                        <span class="text-success">
                                            {{ getPriceFormat($data->total_amount ?? 0) }}
                                        </span>
                                    </div>

                                    <div class="d-flex justify-content-between mb-2 fw-bold">
                                        <span>{{ __('message.platform_commission') }}</span>
                                        <span class="text-danger">
                                            - {{ getPriceFormat($commission ?? 0) }}
                                        </span>
                                    </div>

                                    <hr>

                                    <div class="d-flex justify-content-between fs-5 fw-bold">
                                        <span>{{ __('message.driver_trip_earnings') }}</span>
                                        <span class="text-primary">
                                            {{ getPriceFormat($driverEarning ?? 0) }}
                                        </span>
                                    </div>
                                    <hr>
                                    @php
                                        $paymentMethod = $data->extra_charges_payment_method ?? null;
                                    @endphp
                                    @if($paymentMethod == 1)
                                        <div class="d-flex justify-content-between fs-5 fw-bold">
                                            <span>{{ __('message.credited_to_driver_wallet') }}</span>
                                            <span class="text-primary">
                                                {{ getPriceFormat($extra_charge ) }}
                                            </span>
                                        </div>
                                    @endif
                                    @if($paymentMethod == 2)
                                        <div class="d-flex justify-content-between fs-5 fw-bold">
                                            <span>{{ __('message.extra_charges_collected_in_cash') }}</span>
                                            <span class="text-primary">
                                                {{ getPriceFormat($extra_charge ) }}
                                            </span>
                                        </div>
                                    @endif
                                </div>
                            </div>
                        </div>
                    </div>
                @endif
                @php
                    $status_name = ['rider_canceled','completed','canceled','driver_canceled'];
                @endphp
                <div class="card card-block border-radius-20 p-2 {{ in_array($data->status,$status_name)  ? 'd-none' : '' }}">
                    <div class="row">
                        @if(!in_array($data->status,$status_name))
                            {{-- <div class="col-6 pe-1">
                                <a href="{{ route('cancel.ride', $data->id) }}" class="loadRemoteModel btn btn-sm btn-danger w-100">
                                    {{ __('message.cancel_ride') }}
                                </a>
                            </div> --}}
                        @endif
                        @if($data->status == 'pending')
                            <div class="col-6 ps-1">
                                <a href="{{ route('supplier.payout', ['id' => $data->id, 'fleet_fare' => $data->base_fare, 'surcharge' => $data->surcharge, 'discount' => $data->discount, 'reason' => $data->reason ]) }}" class="loadRemoteModel view_supplier_payout_btn btn btn-sm btn-primary w-100">
                                    {{ __('message.adjust_price') }}
                                </a>
                            </div>
                        @endif
                    </div>
                </div>

            </div>
            <div class="col-lg-4">
                <div class="card card-block border-radius-20">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title mb-0">{{ __('message.detail_form_title', [ 'form' => __('message.rider') ]) }}</h4>
                        </div>
                        @if ($data->status == 'completed')
                            <a href="{{ route('ride-rider-invoice', $data->id) }}" class="btn btn-primary d-inline-flex align-items-center gap-2 px-3 rounded-pill">
                                <i class="ri-download-2-line"></i>
                                <span class="ml-2">{{ __('message.download_invoice') }}</span>
                            </a>
                        @endif
                    </div>
                    <div class="card-body">
                        <div class="row">
                            <div class="col-3">
                                <img src="{{ getSingleMedia(optional($data->rider), 'profile_image',null) }}" alt="rider-profile" class="img-fluid avatar-60 rounded-small">
                            </div>
                            <div class="col-9">
                                @if( $data->is_ride_for_other == 0 )
                                <a href="{{ route('rider.show',$data->rider ?? '') }}" class="mb-0"> {{ optional($data->rider)->display_name ?? '' }}</a>
                                <p class="mb-0">{{ optional($data->rider)->display_name }}</p>
                                <p class="mb-0">{{ optional($data->rider)->contact_number }}</p>
                                <p class="mb-0">{{ optional($data->rider)->email }}</p>
                                <p class="mb-0">
                                    @php
                                        $rating = optional($data->rideRequestDriverRating())->rating ?? 0;
                                    @endphp

                                    {{ $rating > 0 ? $rating : '0' }}

                                    @if($rating)
                                        @for($i = 1; $i <= 5; $i++)
                                            <i class="fa fa-star" style="color: {{ $i <= $rating ? 'gold' : 'grey' }}"></i>
                                        @endfor
                                    @endif
                                </p>
                                @else
                                    <p class="mb-0"><b>{{ __('message.booked_by') }}:</b> {{ optional($data->rider)->display_name }}</p>
                                    @if(!empty($data->other_rider_data))
                                        @foreach($data->other_rider_data as $key)
                                            <p class="mb-0">{{ $key ?? '' }}</p>
                                        @endforeach
                                    @endif
                                @endif
                            </div>
                        </div>
                    </div>
                </div>

                @if( isset($data->driver) )
                <div class="card card-block border-radius-20">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title mb-0">{{ __('message.detail_form_title', [ 'form' => __('message.driver') ]) }}</h4>
                        </div>
                        @if ($data->status == 'completed')
                            <a href="{{ route('ride-invoice', $data->id) }}" class="btn btn-primary d-inline-flex align-items-center gap-2 px-3 rounded-pill">
                                <i class="ri-download-2-line"></i>
                                <span class="ml-2">{{ __('message.download_invoice') }}</span>
                            </a>
                        @endif
                    </div>
                    <div class="card-body">
                        <div class="row">
                            <div class="col-3">
                                <img src="{{ getSingleMedia(optional($data->driver), 'profile_image',null) }}" alt="driver-profile" class="img-fluid avatar-60 rounded-small">
                            </div>
                            <div class="col-9">
                                 <a href="{{ route('driver.show',$data->driver ?? '') }}" class="mb-0"> {{ optional($data->driver)->display_name ?? '' }}</a>
                                <p class="mb-0">{{ optional($data->driver)->display_name }}</p>
                                <p class="mb-0">{{ optional($data->driver)->contact_number }}</p>
                                <p class="mb-0">{{ optional($data->driver)->email }}</p>
                                <p class="mb-0">
                                    @php
                                        $rating = optional($data->rideRequestDriverRating())->rating ?? 0;
                                    @endphp

                                    {{ $rating > 0 ? $rating : '0' }}

                                    @if($rating)
                                        @for($i = 1; $i <= 5; $i++)
                                            <i class="fa fa-star" style="color: {{ $i <= $rating ? 'gold' : 'grey' }}"></i>
                                        @endfor
                                    @endif
                                </p>
                            </div>
                        </div>
                    </div>
                </div>
                @endif

                <div class="card card-block border-radius-20">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title mb-0">{{ __('message.detail_form_title', [ 'form' => __('message.service') ]) }}</h4>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="row">
                            <div class="col-3">
                                <img src="{{ getSingleMedia($data->service, 'service_image',null) }}" alt="service-detail" class="img-fluid avatar-60 rounded-small">
                            </div>
                            <div class="col-3">
                                <h6>{{ __('message.name') }}</h6>
                                {{-- <p class="mb-0">{{ optional($data->service)->name }}</p> --}}
                                <a href="{{ route('service.show',$data->service ?? '') }}" class="mb-0"> {{ optional($data->service)->name ?? '' }}</a>
                            </div>
                            <div class="col-3">
                                <h6>{{ __('message.region') }}</h6>
                                <p class="mb-0">{{ $data->service->region->name ?? '' }}</p>
                            </div>
                            <div class="col-3 p-1">
                                <h6>{{ __('message.capacity') }}</h6>
                                <p class="mb-0">{{ $data->service->capacity ?? '' }}</p>
                            </div>
                        </div>
                    </div>
                </div>
                 @if(count($data->rideRequestHistory) > 0)
                    <div class="card card-block border-radius-20">
                        <div class="card-header d-flex justify-content-between">
                            <div class="header-title">
                                <h4 class="card-title mb-0">{{ __('message.activity_timeline') }}</h4>
                            </div>
                        </div>
                        <div class="card-body">
                            <div class="mm-timeline0 m-0 d-flex align-items-center justify-content-between position-relative">
                                <ul class="list-inline p-0 m-0">
                                    @php
                                        $sequence = [
                                            'new_ride_requested',
                                            'bid_placed',
                                            'bid_rejected',
                                            'bid_accepted',
                                            'arrived',
                                            'in_progress',
                                            'completed',
                                            'payment_status_message',
                                        ];

                                        $bidPlacedDrivers = [];
                                        $bidRejectedDrivers = [];
                                        $historyEntries = [];

                                        $colorMapping = [
                                            'new_ride_requested' => 'border-info text-info',
                                            'bid_placed' => 'border-success text-success',
                                            'bid_rejected' => 'border-danger text-danger',
                                            'bid_accepted' => 'border-success text-success',
                                            'arrived' => 'border-warning text-warning',
                                            'in_progress' => 'border-primary text-primary',
                                            'completed' => 'border-secondary text-secondary',
                                            'payment_status_message' => 'border-dark text-dark',
                                            'driver_declined' => 'border-danger text-danger',
                                        ];

                                        foreach ($data->rideRequestHistory as $history) {
                                            $historyData = is_string($history->history_data) ? json_decode($history->history_data, true) : $history->history_data; // Decode as associative array

                                            if ($history->history_type === 'driver_declined') {
                                                $historyEntries[] = [
                                                    'type' => 'driver_declined',
                                                    'message' => '<a href="'. route('driver.show', ['driver' => $history->rideRequest->riderequest_in_driver_id]) .'">'. $history->history_message .'</a>',
                                                    'datetime' => $history->datetime,
                                                ];
                                            } elseif (in_array($history->history_type, ['bid_placed', 'bid_rejected'])) {
                                                $driverName = $historyData['driver_name'] ?? '';
                                                $driverId = $historyData['driver_id'] ?? '';
                                                $driverLink = '<a href="'. route('driver.show', ['driver' => $driverId]) .'">'.  $driverName . ' ('.$driverId .')' . '</a>';

                                                if ($history->history_type === 'bid_placed') {
                                                    $bidPlacedDrivers[] = $driverLink;
                                                } else {
                                                    $bidRejectedDrivers[] = $driverLink;
                                                }
                                            } else {
                                                $historyEntries[] = [
                                                    'type' => $history->history_type,
                                                    'message' => $history->history_message,
                                                    'datetime' => $history->datetime,
                                                ];
                                            }
                                        }

                                        if ($bidPlacedDrivers) {
                                            $historyEntries[] = [
                                                'type' => 'bid_placed',
                                                'message' => 'Placed bids drivers: ' . implode(' , ', $bidPlacedDrivers),
                                                'datetime' => now(),
                                            ];
                                        }

                                        if ($bidRejectedDrivers) {
                                            $historyEntries[] = [
                                                'type' => 'bid_rejected',
                                                'message' => 'Rejected bids: ' . implode(' , ', $bidRejectedDrivers),
                                                'datetime' => now(),
                                            ];
                                        }

                                        usort($historyEntries, function ($a, $b) use ($sequence) {
                                            return array_search($a['type'], $sequence) - array_search($b['type'], $sequence);
                                        });
                                    @endphp

                                    @foreach($historyEntries as $entry)
                                        @php
                                            // Get the color class based on the type
                                            $colorClass = $colorMapping[$entry['type']] ?? 'border-primary text-primary';
                                        @endphp
                                        <li>
                                            <div class="timeline-dots1 {{ $colorClass }}"></div>
                                            <h6 class="float-left mb-1">{{ __('message.' . $entry['type']) }}</h6>
                                            <small class="float-right mt-1">{{ $entry['datetime'] }}</small>
                                            <div class="d-inline-block w-100">
                                                <p>{!! $entry['message'] !!}</p>
                                            </div>
                                        </li>
                                    @endforeach
                                </ul>
                            </div>
                        </div>
                    </div>
                @endif
            </div>
        </div>
    </div>
</x-master-layout>

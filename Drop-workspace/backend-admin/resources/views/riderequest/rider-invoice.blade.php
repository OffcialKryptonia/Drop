<!DOCTYPE html>
<html>
    <head>
        <meta charset="UTF-8">
        <title>{{ __('message.rider_invoice') }}</title>

        <style>
            body {
                font-family: DejaVu Sans, sans-serif;
                background: #ffffff;
                padding: 25px;
                color: #374151;
                font-size: 13px;
            }

            .invoice-box {
                max-width: 750px;
                margin: auto;
            }

            .title {
                font-size: 22px;
                font-weight: bold;
                color: #2563eb;
                margin-bottom: 15px;
            }

            .meta {
                width: 100%;
                margin-bottom: 15px;
            }

            .meta td {
                font-size: 13px;
                padding: 3px 0;
            }

            .divider {
                border-top: 1px solid #e5e7eb;
                margin: 12px 0;
            }

            .section-title {
                font-weight: bold;
                margin-top: 15px;
                margin-bottom: 8px;
                color: #2563eb;
            }

            table {
                width: 100%;
                border-collapse: collapse;
            }

            table td {
                padding: 6px 4px;
                border-bottom: 1px solid #e5e7eb;
            }

            .text-right {
                text-align: right;
            }

            .highlight {
                background: #f3f4f6;
                font-weight: bold;
            }

            .total-paid {
                background: #e5e7eb;
                font-weight: bold;
                font-size: 15px;
            }
            .footer {
                font-size: 12px;
                margin-top: 15px;
                display: flex;
                justify-content: space-between;
            }
        </style>
    </head>

    <body>

        @php
            $tripFare = $ride_detail->total_amount ?? 0;
            $extraCharges = $ride_detail->extra_charges_amount ?? 0;
            $totalPaid = $tripFare + $extraCharges;
        @endphp

        <div class="invoice-box">

            <div class="title">{{ __('message.rider_invoice') }}</div>

            <table class="meta">
                <tr>
                    <td>
                        {{ __('message.invoice_no') }}: {{ $ride_detail->id }} <br>
                    </td>
                    <td class="text-right">
                        {{ __('message.date') }}: {{ \Carbon\Carbon::parse($ride_detail->created_at)->format('d M Y') }}
                    </td>
                </tr>
            </table>

            <p><strong>{{ __('message.rider_name') }}:</strong> {{ optional($ride_detail->rider)->display_name }}</p>
            <p><strong>{{ __('message.driver_name') }}:</strong> {{ optional($ride_detail->driver)->display_name }}</p>
            <p><strong>{{ __('message.vehicle') }}:</strong> {{ $ride_detail->car_model }} ({{ $ride_detail->car_plate_number }})</p>
            <p><strong>{{ __('message.trip_date_time') }}: </strong>{{ dateAgoFormate($ride_detail->created_at, true) }}</p>
            <p><strong>{{ __('message.pickup_address') }}:</strong> {{ $ride_detail->start_address }}</p>
            <p><strong>{{ __('message.drop_address') }}:</strong> {{ $ride_detail->end_address }}</p>

            <div class="divider"></div>

            <div class="section-title">{{ __('message.fare_summary') }}</div>

            <table>
                @if($ride_detail->trip_type != 'zone_wise' && $ride_detail->ride_has_bid != 1)
                    <tr>
                        <td>{{ __('message.base_fare') }}</td>
                        <td class="text-right">{!! getPriceFormat($ride_detail->base_fare ?? 0) !!}</td>
                    </tr>
                    <tr>
                        <td> {{ __('message.distance_charge') }} ({{ number_format($ride_detail->distance ?? 0,1) }} {{$ride_detail->distance_unit}}) </td>
                        <td class="text-right">{!! getPriceFormat($distance_price ?? 0) !!}</td>
                    </tr>

                    <tr class="highlight">
                        <td>{{ __('message.sub_total') }}</td>
                        <td class="text-right">{!! getPriceFormat($ride_detail->subtotal ?? 0) !!}</td>
                    </tr>
                    <tr>
                        <td>{{ __('message.high_demand_charge') }}</td>
                        <td class="text-right">{!! getPriceFormat($ride_detail->surge_amount ?? 0) !!}</td>
                    </tr>
                @endif

                @if(($ride_detail->coupon_discount ?? 0) > 0)
                    <tr>
                        <td>{{ __('message.coupon_discount') }}</td>
                        <td class="text-right">- {!! getPriceFormat($ride_detail->coupon_discount) !!}</td>
                    </tr>
                @endif

                <tr class="highlight">
                    <td>{{ __('message.trip_fare') }}</td>
                    <td class="text-right">{!! getPriceFormat($tripFare) !!}</td>
                </tr>
            </table>

            @if($extraCharges > 0)
                <div class="section-title">{{ __('message.additional_charge_amount') }}</div>
                <table>
                    <tr>
                        <td>{{ __('message.total_extra_charges') }}</td>
                        <td class="text-right">{!! getPriceFormat($extraCharges) !!}</td>
                    </tr>
                </table>
            @endif
            <div class="section-title">{{ __('message.total_summary') }}</div>
                <table>
                    <tr>
                        <td>{{ __('message.trip_fare') }}</td>
                        <td class="text-right">{!! getPriceFormat($tripFare) !!}</td>
                    </tr>
                    @if($extraCharges > 0)
                        <tr>
                            <td>{{ __('message.extra_charges') }}</td>
                            <td class="text-right">{{ getPriceFormat($extraCharges) }}</td>
                        </tr>
                    @endif
                    <tr class="total-paid">
                        <td>{{ __('message.total_amount_paid') }}</td>
                        <td class="text-right">{!! getPriceFormat($totalPaid) !!}</td>
                    </tr>
                </table>
            </div>

            <div class="footer">
                <table width="100%">
                    <tr>
                        <td style="text-align:left; font-size:12px;">
                            {{ __('message.payment_method') }}:
                            {{ ucfirst($ride_detail->payment_type ?? '-') }}
                        </td>
                        <td style="text-align:right; font-size:12px;">
                            {{ __('message.for_support') }}: {{ $app_setting->help_support_url }}
                        </td>
                    </tr>
                </table>
            </div>
        </div>
    </body>
</html>

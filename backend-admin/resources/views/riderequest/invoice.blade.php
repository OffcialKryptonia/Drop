<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>{{ __('message.driver_invoice') }}</title>

    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: DejaVu Sans, sans-serif;
            background: #f4f6f9;
            padding: 30px;
            color: #333;
        }

        .card {
            background: #ffffff;
            border-radius: 8px;
            padding: 25px;
            max-width: 750px;
            margin: auto;
            border: 1px solid #e0e0e0;
        }

        h1 {
            font-size: 22px;
            margin-bottom: 15px;
            color: #2c3e50;
        }

        .row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 6px;
            font-size: 14px;
        }

        .section {
            margin-top: 20px;
        }

        .section-title {
            font-size: 16px;
            font-weight: bold;
            color: #1f4e8c;
            margin-bottom: 10px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }

        table tr {
            border-bottom: 1px solid #eee;
        }

        table td {
            padding: 8px 5px;
        }

        .text-right {
            text-align: right;
        }

        .highlight {
            background: #e9eef5;
            font-weight: bold;
            color: #1f4e8c;
        }

        .wallet {
            color: #1f4e8c;
            font-weight: bold;
        }

        .total-section {
            margin-top: 25px;
        }

        .total-highlight {
            background: #e9eef5;
            font-weight: bold;
            font-size: 16px;
            color: #1f4e8c;
        }
    </style>
</head>
<body>

<div class="card">

    <h1>{{ __('message.driver_invoice') }}</h1>

    <div class="row">
        <div><strong> {{ __('message.invoice_no') }}:</strong> {{ optional($ride_detail)->id }}</div>
        <div><strong>{{ __('message.date') }}:</strong> {{ $today }}</div>
    </div>
    <br>
    <div class="row">
        <div><strong>{{ __('message.driver_name') }}:</strong> {{ $ride_detail->driver->display_name }}</div>
    </div>

    <div class="row">
        <div><strong>{{ __('message.vehicle') }}:</strong>  {{ $ride_detail->car_model }} ({{ $ride_detail->car_plate_number }})</div>
    </div>

    <div class="row">
        <div><strong>{{ __('message.trip_distance') }}:</strong>  {{ number_format($ride_detail->distance_travelled, 2) }} {{ $ride_detail->distance_unit }} | <strong>{{ __('message.trip_duration') }}:</strong> {{ number_format($ride_detail->completed_trip_duration, 2) }} {{ __('message.min') }}</div>
    </div>

    <!-- Earnings Breakdown -->
    @php
        $totalAmount = $ride_detail->total_amount ?? 0;
        $commission = $ride_detail->admin_commission ?? 0;
        $driverEarning = $totalAmount - $commission;
        $extraCharges = $ride_detail->extra_charges_amount ?? 0;
        $totalDriverEarnings = $driverEarning + $extraCharges;
    @endphp
    <div class="section">
        <div class="section-title">{{ __('message.earnings_breakdown') }}</div>

        <table>
            <tr>
                <td>{{ __('message.trip_fare_collected') }}</td>
                <td class="text-right">{{ getPriceFormat($totalAmount) }}</td>
            </tr>

            <tr>
                <td>{{ __('message.platform_commission') }}</td>
                <td class="text-right">- {{ getPriceFormat($commission) }}</td>
            </tr>

            <tr class="highlight">
                <td>{{ __('message.driver_trip_earnings') }}</td>
                <td class="text-right">{{ getPriceFormat($driverEarning) }}</td>
            </tr>
        </table>
    </div>

    <!-- Extra Charges -->
    @if($extraCharges > 0)
        <div class="section">
            <div class="section-title">{{ __('message.extra_charges_settlement') }}</div>

            <table>
                <tr>
                    <td>{{ __('message.additional_charge_amount') }}</td>
                    <td class="text-right">{{ getPriceFormat($extraCharges) }}</td>
                </tr>
                @php
                    $paymentMethod = $ride_detail->extra_charges_payment_method ?? null;
                @endphp
                @if($paymentMethod == 1)
                    <tr>
                        <td> {{ __('message.credited_to_driver_wallet') }}</td>
                        <td class="text-right">{{ getPriceFormat($extraCharges) }}</td>
                    </tr>
                @endif

                @if($paymentMethod == 2)
                    <tr class="highlight">
                        <td>{{ __('message.extra_charges_collected_in_cash') }}</td>
                        <td class="text-right">{{ getPriceFormat($extraCharges) }}</td>
                    </tr>
                @endif
            </table>
        </div>
    @endif

    <!-- Total Earnings -->
    <div class="section total-section">
        <div class="section-title">{{ __('message.final_driver_summary') }}</div>

        <table>
            <tr>
                <td>{{ __('message.driver_trip_earnings') }}</td>
                <td class="text-right">{{ getPriceFormat($driverEarning) }}</td>
            </tr>
            @if($extraCharges > 0)
                <tr>
                    <td>{{ __('message.extra_charges') }}</td>
                    <td class="text-right">{{ getPriceFormat($extraCharges) }}</td>
                </tr>
            @endif
            <tr class="total-highlight">
                <td>{{ __('message.total_driver_earnings') }}</td>
                <td class="text-right">{{ getPriceFormat($totalDriverEarnings) }}</td>
            </tr>
        </table>
    </div>

</div>

</body>
</html>

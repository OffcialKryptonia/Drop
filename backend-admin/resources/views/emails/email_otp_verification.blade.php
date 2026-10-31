@php
    $companyName = $companyName ?? config('app.name');
    $heading = $heading ?? __('message.almost_there');
    $year = date('Y');
@endphp

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{{ $companyName }} {{__('message.otp')}}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            background-color: #f0f2f5;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            padding: 40px 0;
            margin: 0;
        }

        .email-container {
            max-width: 480px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 16px;
            padding: 40px 30px;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.06);
            text-align: center;
        }

        .logo {
            width: 60px;
            margin-bottom: 20px;
        }

        .heading {
            font-size: 22px;
            font-weight: 700;
            margin-bottom: 16px;
            color: #1f1f1f;
        }

        .intro {
            font-size: 16px;
            color: #555;
            margin-bottom: 32px;
        }

        .otp-box {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            background-color: #f3f4f6;
            border-radius: 12px;
            padding: 16px 24px;
            font-size: 26px;
            font-weight: bold;
            color: #111827;
            letter-spacing: 6px;
            margin-bottom: 24px;
        }

        .otp-box img {
            width: 27px;
            height: 30px;
            margin-right: 10px;
        }

        .details {
            font-size: 14px;
            color: #6b7280;
            line-height: 1.5;
            margin-bottom: 24px;
        }

        .footer {
            font-size: 12px;
            color: #a1a1aa;
        }

        .footer a {
            color: #2563eb;
            text-decoration: none;
        }
    </style>
</head>

<body>
    <div class="email-container">
        <img src="https://apps.meetmighty.com/mighty-taxi/images/logo.png" alt="Mighty Taxi" class="logo">
        <div class="heading">{{ __('message.verification_code_heading', ['company_name' => $companyName]) }}</div>
        <div class="intro">{{__('message.hi_there')}}<br>{{__('message.verification_intro')}}</div>
        <div class="otp-box">
            <img src="https://cdn-icons-png.flaticon.com/512/61/61457.png" alt="lock-icon">
            {{ $otp }}
        </div>
        <div class="details">
            {!! $mailDescription !!}
        </div>
        <div class="footer">
           {{__('message.thanks')}} <br><strong> {{__('message.the')}} {{ $companyName }} {{__('message.team')}}</strong><br><br>
            <a href="{{ env('APP_URL') }}">{{__('message.our_website')}}</a><br><br>
            &copy; {{ $year }} {{ $companyName }}.{{__('message.all_rights_reserved')}}
        </div>
    </div>
</body>

</html>


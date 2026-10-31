<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ __('message.login_otp_title') }}</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            background-color: #f4f6f8;
            padding: 40px 0;
            margin: 0;
        }
        .email-wrapper {
            max-width: 600px;
            margin: auto;
            background: #fff;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 5px 20px rgba(0,0,0,0.08);
        }
        .email-header {
            color: #fff;
            padding: 30px;
            text-align: center;
        }
        .email-header h1 {
            margin: 0;
            font-size: 26px;
        }
        .email-body {
            padding: 30px 40px;
            color: #333;
            text-align: center;
        }
        .email-body p {
            margin: 10px 0;
            font-size: 16px;
            line-height: 1.6;
        }
        .otp-box {
            display: inline-block;
            padding: 15px 30px;
            margin: 25px 0;
            background-color: #f9fafb;
            border: 2px dashed;
            border-radius: 8px;
            font-size: 32px;
            font-weight: bold;
            letter-spacing: 4px;
        }
        .email-footer {
            background-color: #f9fafb;
            padding: 20px;
            text-align: center;
            font-size: 14px;
            color: #888;
        }
        .email-footer a {
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="email-wrapper">
        <div class="email-header">
            <h1>{{ __('message.login_verification') }}</h1>
        </div>

        <div class="email-body">
            <p>{{ __('message.hello') }}!</p>
            <p>{{ __('message.loigin_otp') }}:</p>
            <div class="otp-box">{{ $otp }}</div>
            <p>{{ __('message.otp_dont_share') }}</p>
        </div>

        <div class="email-footer">
            {{ config('app.name') }}
        </div>
    </div>
</body>
</html>

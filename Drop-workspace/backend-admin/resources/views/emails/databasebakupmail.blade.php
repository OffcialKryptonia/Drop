<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ __('message.database_backup') . ' ' . env('APP_NAME') }}</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            background-color: #f9f9f9;
            padding: 30px;
            margin: 0; /* Reset default margin */
        }
        .container {
            max-width: 600px;
            margin: auto;
            background: #ffffff;
            border-radius: 8px;
            box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        .header {
            color: white;
            padding: 20px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 24px;
        }
        .order-summary {
            padding: 20px;
        }
        .order-summary p {
            font-size: 16px;
            margin: 8px 0;
            color: #333;
        }
        .order-content {
            background-color: #f1f1f1;
            padding: 15px;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            padding: 20px;
            font-size: 14px;
            background-color: #f1f1f1;
            color: #555;
        }
        .footer a {
            text-decoration: none;
        }
    </style>
</head>
    <body>
        <div class="container">
            <div class="header">

            </div>
            <div class="footer">
                <p>{{ __('message.database_backup') . ' ' . env('APP_NAME') }}</p>
                <strong>{{__('message.regards')}}</strong><br>
                {{ config('app.name') }}<br>
                <a href="{{ env('APP_URL') }}">{{ __('message.our_website') }}</a>
            </div>
        </div>
    </body>
</html>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ $title ?? __('message.email_notification') }}</title>
    <style>
        /* General Styles */
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f4f4f4;
            color: #333;
        }
        .email-container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        .email-content {
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 20px;
            color: #555;
        }
        .email-footer {
            text-align: center;
            font-size: 12px;
            color: #aaa;
            margin-top: 20px;
        }

        /* Responsive Design */
        @media (max-width: 600px) {
            .email-container {
                padding: 15px;
            }
        }
    </style>
</head>
<body>
    <div class="email-container">
        <div class="email-header">
            <p>{{ __('message.assist_with_request') }}</p>
        </div>
        <div class="email-content">
            {!! $content !!}
        </div>
        <div class="email-footer">
            <p>&copy; {{ date('Y') }} - {{ config('app.name') }} .{{ __('message.all_rights_reserved') }}</p>
            <p>
                {{ __('message.have_questions') }}
                <a href="{{ $appsetting->help_support_url ?? '#' }}" style="color: #000000;">{{ __('message.contact_us') }}</a>.
            </p>
        </div>
    </div>
</body>
</html>

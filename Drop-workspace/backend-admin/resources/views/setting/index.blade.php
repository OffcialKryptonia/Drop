<x-master-layout :assets="$assets ?? []">
    <div>
        <div class="row">
            <div class="col-lg-12">
                <div class="card border-radius-20 card-block card-stretch">
                    <div class="card-body p-0">
                        <div class="d-flex justify-content-between align-items-center p-3">
                            <h5 class="font-weight-bold">{{ $pageTitle ?? __('message.list') }}</h5>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <div class="row">
            <div class="col-md-12">
                <div class="card border-radius-20">
                    <div class="card-body">
                        <ul class="nav nav-tabs" role="tablist">
                            @if (in_array($page, ['profile_form', 'password_form', 'verify-old-password', 'change_email_form', 'otp_form']))
                                <li class="nav-item">
                                    <a href="javascript:void(0)"
                                        data-href="{{ route('layout_page') }}?page=profile_form"
                                        data-target=".paste_here"
                                        class="nav-link {{ $page == 'profile_form' ? 'active' : '' }}"
                                        data-toggle="tabajax" rel="tooltip"> {{ __('message.profile') }} </a>
                                </li>
                                <li class="nav-item">
                                    <a href="javascript:void(0)"
                                        data-href="{{ route('layout_page') }}?page=password_form"
                                        data-target=".paste_here"
                                        class="nav-link {{ $page == 'password_form' ? 'active' : '' }}"
                                        data-toggle="tabajax" rel="tooltip"> {{ __('message.change_password') }} </a>
                                </li>
                                <li class="nav-item">
                                    <a href="javascript:void(0)"
                                        data-href="{{ route('layout_page') }}?page=verify-old-password"
                                        data-target=".paste_here"
                                        class="nav-link {{ $page == 'verify-old-password' ? 'active' : '' }}"
                                        data-toggle="tabajax" rel="tooltip"> {{ __('message.change_email') }} </a>
                                </li>
                            @else
                                @hasanyrole('admin|demo_admin')
                                    <li class="nav-item">
                                        <a href="javascript:void(0)"
                                            data-href="{{ route('layout_page') }}?page=general-setting"
                                            data-target=".paste_here"
                                            class="nav-link {{ $page == 'general-setting' ? 'active' : '' }}"
                                            data-toggle="tabajax" rel="tooltip"> {{ __('message.general_settings') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)"
                                            data-href="{{ route('layout_page') }}?page=mobile-config"
                                            data-target=".paste_here"
                                            class="nav-link {{ $page == 'mobile-config' ? 'active' : '' }}"
                                            data-toggle="tabajax" rel="tooltip"> {{ __('message.mobile_config') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)"
                                            data-href="{{ route('layout_page') }}?page=wallet-setting"
                                            data-target=".paste_here"
                                            class="nav-link {{ $page == 'wallet-setting' ? 'active' : '' }}"
                                            data-toggle="tabajax" rel="tooltip"> {{ __('message.wallet_setting') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)"
                                            data-href="{{ route('layout_page') }}?page=ride-setting"
                                            data-target=".paste_here"
                                            class="nav-link {{ $page == 'ride-setting' ? 'active' : '' }}"
                                            data-toggle="tabajax" rel="tooltip"> {{ __('message.ride_setting') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)"
                                            data-href="{{ route('layout_page') }}?page=mail-setting"
                                            data-target=".paste_here"
                                            class="nav-link {{ $page == 'mail-setting' ? 'active' : '' }}"
                                            data-toggle="tabajax" rel="tooltip"> {{ __('message.mail_settings') }}</a>
                                    </li>

                                    <li class="nav-item">
                                        <a href="javascript:void(0)"
                                            data-href="{{ route('layout_page') }}?page=language-setting"
                                            data-target=".paste_here"
                                            class="nav-link {{ $page == 'language-setting' ? 'active' : '' }}"
                                            data-toggle="tabajax" rel="tooltip"> {{ __('message.language_settings') }}</a>
                                    </li>

                                    {{-- <li class="nav-item">
                                        <a href="javascript:void(0)" data-href="{{ route('layout_page') }}?page=notification-setting" data-target=".paste_here" class="nav-link {{$page=='notification-setting'?'active':''}}"  data-toggle="tabajax" rel="tooltip"> {{ __('message.notification_settings') }}</a>
                                    </li> --}}
                                    <li class="nav-item">
                                        <a href="javascript:void(0)"
                                            data-href="{{ route('layout_page') }}?page=payment-setting"
                                            data-target=".paste_here"
                                            class="nav-link {{ $page == 'payment-setting' ? 'active' : '' }}"
                                            data-toggle="tabajax" rel="tooltip"> {{ __('message.payment_settings') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)"
                                            data-href="{{ route('layout_page') }}?page=databasebackup-setting"
                                            data-target=".paste_here"
                                            class="nav-link {{ $page == 'databasebackup-setting' ? 'active' : '' }}"
                                            data-toggle="tabajax" rel="tooltip">
                                            {{ __('message.database_backup_settings') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)"
                                            data-href="{{ route('layout_page') }}?page=mail-template-setting"
                                            data-target=".paste_here"
                                            class="nav-link {{ $page == 'mail-template-setting' ? 'active' : '' }}"
                                            data-toggle="tabajax" rel="tooltip"> {{ __('message.mail_templated') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)" data-href="{{ route('layout_page') }}?page=sms-settings" data-target=".paste_here" class="nav-link {{$page=='sms-settings'?'active':''}}"  data-toggle="tabajax" rel="tooltip"> {{ __('message.sms_setting') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)" data-href="{{ route('layout_page') }}?page=reference-setting" data-target=".paste_here" class="nav-link {{$page=='reference-setting'?'active':''}}"  data-toggle="tabajax" rel="tooltip"> {{ __('message.reference_setting') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)" data-href="{{ route('layout_page') }}?page=mail-alert-setting" data-target=".paste_here" class="nav-link {{ $page == 'mail-alert-setting' ?' active' : '' }}" data-toggle="tabajax" rel="tooltip"> {{ __('message.mail_alert_setting') }}</a>
                                    </li>
                                    <li class="nav-item">
                                        <a href="javascript:void(0)" data-href="{{ route('layout_page') }}?page=scratch-card-setting" data-target=".paste_here" class="nav-link {{ $page == 'scratch-card-setting' ?' active' : '' }}" data-toggle="tabajax" rel="tooltip"> {{ __('message.scratch_card_config') }}</a>
                                    </li>
                                @endhasanyrole
                            @endif
                        </ul>
                        <div class="tab-content">
                            <div class="paste_here"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    @section('bottom_script')
        <script>
            $(document).ready(function(event) {
                var $this = $('.nav-item').find('a.active');
                loadurl = "{{ route('layout_page') }}?page={{ $page }}";

                targ = $this.attr('data-target');

                id = this.id || '';

                $.post(loadurl, {
                    '_token': $('meta[name=csrf-token]').attr('content')
                }, function(data) {
                    $(targ).html(data);
                });

                $this.tab('show');
                return false;
            });
        </script>
        @if (request('page') == 'change_email_form')
            <script>
                $(document).ready(function() {
                    const page = '{{ request('page') }}';
                    const target = $('.paste_here');

                    $.ajax({
                        url: '{{ route('layout_page') }}?page=' + page,
                        success: function(data) {
                            target.html(data);
                        },
                        type: 'POST',
                        data: {
                            _token: '{{ csrf_token() }}'
                        },
                        success: function(data) {
                            target.html(data);
                        },
                        error: function() {
                            target.html('<div class="alert alert-danger">Failed to load Email form.</div>');
                        }
                    });
                });
            </script>
        @endif
        @if (request('page') == 'otp_form')
            <script>
                $(document).ready(function() {
                    const page = '{{ request('page') }}';
                    const target = $('.paste_here');

                    $.ajax({
                        url: '{{ route('layout_page') }}?page=' + page,
                        success: function(data) {
                            target.html(data);
                        },
                        type: 'POST',
                        data: {
                            _token: '{{ csrf_token() }}'
                        },
                        success: function(data) {
                            target.html(data);
                        },
                        error: function() {
                            target.html('<div class="alert alert-danger">Failed to load OTP form.</div>');
                        }
                    });
                });
            </script>
        @endif
    @endsection
</x-master-layout>

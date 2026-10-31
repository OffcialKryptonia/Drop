<?php
    $auth_user = authSession();
?>

<div class="d-flex justify-content-end align-items-center">

    <a class="mr-2" href="{{ route('admin.device.show', $ip_address ?? '') }}">
       <i class="fas fa-eye text-secondary"></i>
    </a>

     @if ($is_active)
            {{ html()->form('POST', route('admin.device.logout', $id))->attribute('data--submit', 'device-logout' . $id)->open() }}
            {{ html()->hidden('_method', 'POST') }}

            <a class="btn btn-sm btn-icon btn-danger me-2 ml-2" href="javascript:void(0)"data-bs-toggle="tooltip"
                data--submit="device-logout{{ $id }}" data--confirmation="true"
                data-title="{{ __('message.admin_device_login') }}" title="{{ __('message.admin_device_login') }}"
                data-message="{{ __('message.logout_confirm') }}">
                <span class="btn-inner">
                    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"
                        fill="currentColor"class="bi bi-box-arrow-right" viewBox="0 0 16 16">
                        <path
                            fill-rule="evenodd"d="M10 12.5a.5.5 0 0 1-.5.5h-8a.5.5 0 0 1-.5-.5v-9a.5.5 0 0 1 .5-.5h8a.5.5 0 0 1 .5.5v2a.5.5 0 0 0 1 0v-2A1.5 1.5 0 0 0 9.5 2h-8A1.5 1.5 0 0 0 0 3.5v9A1.5 1.5 0 0 0 1.5 14h8a1.5 1.5 0 0 0 1.5-1.5v-2a.5.5 0 0 0-1 0z" />
                        <path
                            fill-rule="evenodd"d="M15.854 8.354a.5.5 0 0 0 0-.708l-3-3a.5.5 0 0 0-.708.708L14.293 7.5H5.5a.5.5 0 0 0 0 1h8.793l-2.147 2.146a.5.5 0 0 0 .708.708z" />
                    </svg>
                </span>
            </a>

            {{ html()->form()->close() }}
        @endif

</div>

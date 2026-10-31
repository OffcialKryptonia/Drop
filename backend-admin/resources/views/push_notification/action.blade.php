<?php
    $auth_user= authSession();
?>
<div class="d-flex justify-content-end align-items-center">    
    @if($auth_user->can('pushnotification delete'))
        <a class="btn btn-sm btn-icon  me-2" href="{{ route('resend.pushnotification', $id) }}" data-bs-toggle="tooltip" title="{{ __('message.resend_pushnotification') }}">
            <i class="fa fa-paper-plane" aria-hidden="true"></i>
        </a>
        {{ html()->form('DELETE', route('pushnotification.destroy', $id))->attribute('data--submit', 'pushnotification'.$id)->open() }}
                <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="pushnotification{{$id}}" 
                    data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.pushnotification') ]) }}"
                    title="{{ __('message.delete_form_title',[ 'form'=>  __('message.pushnotification') ]) }}"
                    data-message='{{ __("message.delete_msg") }}'>
                    <i class="fas fa-trash-alt"></i>
                </a>
        {{ html()->form()->close() }}
    @endif
</div>
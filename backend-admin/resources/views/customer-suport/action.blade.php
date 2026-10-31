<?php
    $auth_user= authSession();
?>
<div class="d-flex justify-content-end align-items-center">

    @if($auth_user->can('customersupport-show'))
        <a class="mr-2 mt-1" href="{{ route('customersupport.show',$id) }}"><i class="ri-chat-1-fill" style="font-size:19px"></i></a>
    @endif

    @if($auth_user->can('customersupport-delete'))
        {{ html()->form('DELETE', route('customersupport.destroy', $id))->attribute('data--submit', 'customer_support'.$id)->open() }}
                <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="customer_support{{$id}}"
                    data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.customer_support') ]) }}"
                    title="{{ __('message.delete_form_title',['form'=>  __('message.customer_support') ]) }}"
                    data-message='{{ __("message.delete_msg") }}'>
                    <i class="fas fa-trash-alt"></i>
                </a>
        {!! html()->form()->close() !!}
    @endif
</div>
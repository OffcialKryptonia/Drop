<?php
    $auth_user= authSession();
?>
<div class="d-flex justify-content-end align-items-center">
    @if($auth_user->can('managezone-edit'))
        <a class="mr-2" href="{{ route('managezone.edit', $id) }}" title="{{ __('message.update_form_title',['form' => __('message.manage_zone') ]) }}"><i class="fas fa-edit text-primary"></i></a>
    @endif
    @if($auth_user->can('managezone-delete'))
        {{ html()->form('DELETE', route('managezone.destroy', $id))->attribute('data--submit', 'managezone' . $id)->open() }}
            <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="managezone{{$id}}" 
                data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.manage_zone') ]) }}"
                title="{{ __('message.delete_form_title',['form'=>  __('message.manage_zone') ]) }}"
                data-message='{{ __("message.delete_msg") }}'>
                <i class="fas fa-trash-alt"></i>
            </a>
        {{ html()->form()->close() }}
    @endif
</div>

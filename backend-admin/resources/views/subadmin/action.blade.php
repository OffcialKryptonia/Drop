<?php
    $auth_user= authSession();
?>
<div class="d-flex justify-content-end align-items-center">
    @if($auth_user->can('subadmin-edit'))
        <a class="mr-2" href="{{ route('sub-admin.edit', $id) }}" title="{{ __('message.update_form_title',['form' => __('message.sub_admin') ]) }}"><i class="fas fa-edit text-primary"></i></a>
    @endif

    @if($auth_user->can('subadmin-delete'))
        {{ html()->form('DELETE', route('sub-admin.destroy', $id))->attribute('data--submit', 'users' . $id)->open()}}
            <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="users{{$id}}"
                data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.sub_admin') ]) }}"
                title="{{ __('message.delete_form_title',['form'=>  __('message.sub_admin') ]) }}"
                data-message='{{ __("message.delete_msg") }}'>
                <i class="fas fa-trash-alt"></i>
            </a>
        {!! html()->form()->close() !!}
    @endif
</div>

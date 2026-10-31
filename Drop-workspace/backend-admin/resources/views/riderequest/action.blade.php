
<?php
    $auth_user= authSession();
?>
{{ html()->form('DELETE', route('riderequest.destroy', $id))->attribute('data--submit', 'riderequest' . $id)->open()}}
<div class="d-flex justify-content-end align-items-center">
    @if($auth_user->can('riderequest show'))
    <a class="mr-2" href="{{ route('riderequest.show',$id) }}"><i class="fas fa-eye text-secondary"></i></a>
    @endif

    @if($auth_user->can('riderequest delete'))
    <a class="mr-2" href="javascript:void(0)" data--submit="riderequest{{$id}}" 
        data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.riderequest') ]) }}"
        title="{{ __('message.delete_form_title',['form'=>  __('message.riderequest') ]) }}"
        data-message='{{ __("message.delete_msg") }}'>
        <i class="fas fa-trash-alt text-danger"></i>
    </a>
    @endif
</div>
{!! html()->form()->close() !!}
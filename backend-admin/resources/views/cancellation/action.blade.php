
<?php
    $auth_user= authSession();
?>

<div class="d-flex justify-content-end align-items-center">
    @if(!$auth_user->can('cancellation edit'))       
        <a class="mr-2 loadRemoteModel" href="{{ route('cancellation.edit', $id) }}" title="{{ __('message.update_form_title',['form' => __('message.cancellation') ]) }}"><i class="fas fa-edit text-primary"></i></a>
    @endif

    @if(!$auth_user->can('cancellation delete'))
        {{ html()->form('DELETE', route('cancellation.destroy', $id))->attribute('data--submit', 'cancellation' . $id)->open() }}
            <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="cancellation{{$id}}" 
                data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.cancellation') ]) }}"
                title="{{ __('message.delete_form_title',['form'=>  __('message.cancellation') ]) }}"
                data-message='{{ __("message.delete_msg") }}'>
                <i class="fas fa-trash-alt"></i>
            </a>
        {{ html()->form()->close() }}
    @endif
</div>
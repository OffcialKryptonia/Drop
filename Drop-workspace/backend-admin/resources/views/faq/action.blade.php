<?php
    $auth_user= authSession();
?>

<div class="d-flex justify-content-end align-items-center">
    @if($auth_user->can('faq-edit'))
    <a class="mr-2" href="{{ route('faqs.edit', $id) }}" data-toggle="tooltip" title="{{ __('message.update_form_title',['form' => __('message.faq') ]) }}"><i class="fas fa-edit text-primary"></i></a>
    @endif
    
    @if($auth_user->can('faq-delete'))
        {{ html()->form('DELETE', route('faqs.destroy', $id))->attribute('data--submit', 'faqs'.$id)->open() }}
            <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="faqs{{$id}}" data-toggle="tooltip"
                data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.faq') ]) }}"
                title="{{ __('message.delete_form_title',['form'=>  __('message.faq') ]) }}"
                data-message='{{ __("message.delete_msg") }}'>
                <i class="fas fa-trash-alt"></i>
            </a>
        {{ html()->form()->close() }}
    @endif
</div>
<?php
    $auth_user= authSession();
?>
<div class="d-flex justify-content-end align-items-center">
    @if($auth_user->can('managezone-price-edit'))
        <a class="mr-2" href="{{ route('managezone-price.edit', $id) }}" title="{{ __('message.update_form_title',['form' => __('message.manage_zone_price') ]) }}"><i class="fas fa-edit text-primary"></i></a>
    @endif
    @if($auth_user->can('managezone-price-delete'))
        {{ html()->form('DELETE', route('managezone-price.destroy', $id))->attribute('data--submit', 'managezone-price' . $id)->open() }}
            <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="managezone-price{{$id}}" 
                data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.manage_zone_price') ]) }}"
                title="{{ __('message.delete_form_title',['form'=>  __('message.manage_zone_price') ]) }}"
                data-message='{{ __("message.delete_msg") }}'>
                <i class="fas fa-trash-alt"></i>
            </a>
        {{ html()->form()->close() }}
    @endif
</div>

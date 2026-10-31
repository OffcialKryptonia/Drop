
<?php
    $auth_user= authSession();
?>
{{ html()->form('DELETE', route('surge-prices.destroy', $id))->attribute('data--submit', 'surge_price' . $id)->open()}}
    <div class="d-flex justify-content-end align-items-center">
        {{--  @if($auth_user->can('surge_price-edit') &&  $surge_price->status != 'resolved')  --}}
            <a class="mr-2" href="{{ route('surge-prices.edit', $id) }}" title="{{ __('message.update_form_title',['form' => __('message.surge_price') ]) }}"><i class="fas fa-edit text-primary"></i></a>
        {{--  @endif  --}}

        {{--  @if($auth_user->can('surge_price-delete'))  --}}
            <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="surge_price{{$id}}" 
                data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.surge_price') ]) }}"
                title="{{ __('message.delete_form_title',['form'=>  __('message.surge_price') ]) }}"
                data-message='{{ __("message.delete_msg") }}'>
                <i class="fas fa-trash-alt"></i>
            </a>
        {{--  @endif  --}}
    </div>
{!! html()->form()->close() !!}
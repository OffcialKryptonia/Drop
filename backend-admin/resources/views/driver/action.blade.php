
<?php
    $auth_user= authSession();
?>
@if($deleted_at != null)
    <div class="d-flex justify-content-end align-items-center">
        @if($auth_user->can('driver edit'))
        <a class="mr-2" href="{{ route('driver.restore', ['id' => $id ,'type'=>'restore']) }}" data--confirmation--restore="true" title="{{ __('message.restore_title') }}"><i class="ri-refresh-line" style="font-size:18px"></i></a>
        @endif
        {{ html()->form('DELETE', route('driver.force.delete', ['id' => $id, 'type' => 'forcedelete']))->attribute('data--submit', 'driver' . $id)->open()}}
            @if($auth_user->can('driver delete'))
                <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="driver{{$id}}"
                    data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.driver') ]) }}"
                    title="{{ __('message.force_delete_form_title',['form'=>  __('message.driver') ]) }}"
                    data-message='{{ __("message.force_delete_msg") }}'>
                    <i class="ri-delete-bin-2-fill" style="font-size:18px"></i>
                </a>
            @endif
        {{ html()->form()->close() }}
    </div>
@else
    {{ html()->form('DELETE', route('driver.destroy', $id))->attribute('data--submit', 'driver' . $id)->open()}}

    <div class="d-flex justify-content-end align-items-center">
        @if($auth_user->can('driver edit'))
        <a class="mr-2" href="{{ route('driver.edit', $id) }}" title="{{ __('message.update_form_title',['form' => __('message.driver') ]) }}"><i class="fas fa-edit text-primary"></i></a>
        @endif

        @if( $data->status == 'active' && $auth_user->can('driver show') )
            <a class="mr-2" href="{{ route('driver.show',$id) }}"><i class="fas fa-eye text-secondary"></i></a>
        @endif

        @if($auth_user->can('driver delete'))
        <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="driver{{$id}}"
            data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.driver') ]) }}"
            title="{{ __('message.delete_form_title',['form'=>  __('message.driver') ]) }}"
            data-message='{{ __("message.delete_msg") }}'>
            <i class="fas fa-trash-alt"></i>
        </a>
        @endif
    </div>
    {!! html()->form()->close() !!}
@endif


<?php
    $auth_user= authSession();
?>
@if($deleted_at != null)
    <div class="d-flex justify-content-end align-items-center">
        @if($auth_user->can('rider edit'))
        <a class="mr-2" href="{{ route('rider.restore', ['id' => $id ,'type'=>'restore']) }}" data--confirmation--restore="true" title="{{ __('message.restore_title') }}"><i class="ri-refresh-line" style="font-size:18px"></i></a>
        @endif
        {{ html()->form('DELETE', route('rider.force.delete', ['id' => $id, 'type' => 'forcedelete']))->attribute('data--submit', 'rider' . $id)->open()}}
            @if($auth_user->can('rider delete'))
                <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="rider{{$id}}"
                    data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.rider') ]) }}"
                    title="{{ __('message.force_delete_form_title',['form'=>  __('message.rider') ]) }}"
                    data-message='{{ __("message.force_delete_msg") }}'>
                    <i class="ri-delete-bin-2-fill" style="font-size:18px"></i>
                </a>
            @endif
        {{ html()->form()->close() }}
    </div>
@else
    {{ html()->form('DELETE', route('rider.destroy', $id))->attribute('data--submit', 'rider' . $id)->open()}}
    <div class="d-flex justify-content-end align-items-center">
        @if($auth_user->can('rider edit'))
        <a class="mr-2" href="{{ route('rider.edit', $id) }}" title="{{ __('message.update_form_title',['form' => __('message.rider') ]) }}"><i class="fas fa-edit text-primary"></i></a>
        @endif

        @if($auth_user->can('rider show'))
            <a class="mr-2" href="{{ route('rider.show',$id) }}"><i class="fas fa-eye text-secondary"></i></a>
        @endif

        @if($auth_user->can('rider delete'))
        <a class="mr-2 text-danger" href="javascript:void(0)" data--submit="rider{{$id}}"
            data--confirmation='true' data-title="{{ __('message.delete_form_title',['form'=> __('message.rider') ]) }}"
            title="{{ __('message.delete_form_title',['form'=>  __('message.rider') ]) }}"
            data-message='{{ __("message.delete_msg") }}'>
            <i class="fas fa-trash-alt"></i>
        </a>
        @endif
    </div>
    {!! html()->form()->close() !!}
@endif

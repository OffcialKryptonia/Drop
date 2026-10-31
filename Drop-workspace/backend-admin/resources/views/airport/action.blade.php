
<?php
    $auth_user= authSession();
?>
@if($delete_at != null)
    <div class="d-flex justify-content-end align-items-center">
        @if($auth_user->can('airport-edit'))
            <a class="mr-2" href="{{ route('airport.restore', ['id' => $id ,'type'=>'restore']) }}" data--confirmation--restore="true" title="{{ __('message.restore_title') }}"><i class="ri-refresh-line" style="font-size:18px"></i></a>
        @endif
        {{ html()->form('DELETE', route('airport.force.delete', ['id' => $id, 'type' => 'forcedelete']))->attribute('data--submit', 'airport'.$id)->open() }}
            @if($auth_user->can('airport-delete'))
                <a class="mr-2 text-danger" href="javascript:void(0)"
                    data--submit="airport{{ $id }}"
                    data--confirmation="true"
                    data-title="{{ __('message.delete_form_title', ['form' => __('message.airport')]) }}"
                    title="{{ __('message.force_delete_form_title', ['form' => __('message.airport')]) }}"
                    data-message="{{ __('message.force_delete_msg') }}">
                    <i class="ri-delete-bin-2-fill" style="font-size:18px"></i>
                </a>
            @endif
        {{ html()->form()->close() }}
    </div>
@else
    @if($action_type == 'action')
        <div class="d-flex justify-content-end align-items-center">
            @if($auth_user->can('airport-edit'))
            <a class="mr-2" href="{{ route('airport.edit', $id) }}" title="{{ __('message.update_form_title',['form' => __('message.airport') ]) }}"><i class="fas fa-edit text-primary"></i></a>
            @endif

            {{-- @if($auth_user->can('airport show'))
                <a class="mr-2" href="{{ route('airport.show',$id) }}"><i class="fas fa-eye text-secondary"></i></a>
            @endif --}}

            @if($auth_user->can('airport-delete'))
            {{ html()->form('DELETE', route('airport.destroy', $id))->attribute('data--submit', 'airport'.$id)->open() }}
                <a class="mr-2 text-danger" href="javascript:void(0)"
                    data--submit="airport{{ $id }}"
                    data--confirmation="true"
                    data-title="{{ __('message.delete_form_title', ['form' => __('message.airport')]) }}"
                    title="{{ __('message.delete_form_title', ['form' => __('message.airport')]) }}"
                    data-message="{{ __('message.delete_msg') }}">
                    <i class="fas fa-trash-alt"></i>
                </a>
            {{ html()->form()->close() }}
            @endif
        </div>
    @endif
@endif
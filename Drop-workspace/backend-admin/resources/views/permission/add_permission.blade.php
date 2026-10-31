<!-- Modal -->

<div class="modal-dialog" role="document">
    <div class="modal-content border-radius-20">
        <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLabel">{{ $title }}</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
        </div>
       {{ html()->form('POST', route('permission.save'))->attribute('data-toggle', 'validator')->open() }} 
        <div class="modal-body">

           {{ html()->hidden('type',$type) }}
           {{ html()->hidden('id',-1) }}
            <div class="row">
                <div class="col-md-12 form-group">
                   {!! html()->label(__('message.name').' <span class="text-danger">*</span>')->for('name')->class('form-control-label') !!}
                   {!! html()->text('name', null)->placeholder(__('message.name'))->class('form-control')->required() !!}
                </div>
            </div>
            @if( $type == 'permission' )
                <div class="row">
                    <div class="col-md-12 form-group">
                    {!! html()->label(__('message.parent_permission'))->for('parent_id')->class('form-control-label') !!}
                    <select name="parent_id" id="parent_id" class="select2js form-control" data-ajax--url="{{ route('ajax-list', ['type' => 'permission']) }}" data-ajax--cache = "true">
                       
                    </select>
                    </div>
                </div>
            @endif
        </div>
        <div class="modal-footer">
            <button type="button" class="btn border-radius-10 btn-secondary" data-dismiss="modal">{{ __('message.close') }}</button>
            <button type="submit" class="btn border-radius-10 btn-primary" id="btn_submit" data-form="ajax" >{{ __('message.save') }}</button>
        </div>
        {!! html()->form()->close() !!}
    </div>
</div>
<script>
    $('#parent_id').select2({
        width: '100%',
        placeholder: "{{ __('message.select_name',['select' => __('message.parent_permission')]) }}",
    });
</script>


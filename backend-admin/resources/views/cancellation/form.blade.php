<!-- Modal -->
<div class="modal-dialog" role="document">
    <div class="modal-content">
        <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLabel">{{ $pageTitle }}</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
        </div>
        @if(isset($id))
            {{ html()->modelForm($data,'PATCH', route('cancellation.update', $id))->open() }}
        @else
            {{ html()->form('POST', route('cancellation.store'))->open() }}
        @endif
            <div class="modal-body">
                <div class="form-group">
                    <div class="form-group col-md-12">
                        {{ html()->label(__('message.title') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('title')}}
                        {{ html()->text('title', old('title'))->placeholder(__('message.title'))->class('form-control')->required() }}
                    </div>
                    <div class="form-group col-md-12">
                        {!! html()->label(__('message.type'))->class('form-control-label')->for('type') !!}
                        {!! html()->select('type', ['rider' => __('message.rider'), 'driver' => __('message.driver')], old('type'))->class('form-control select2js')->required() !!}
                    </div>
                </div>       
            </div>
            <div class="modal-footer">
                {{ html()->submit(__('message.save'))->class('btn btn-md btn-primary float-right')->id('btn_submit')->attribute('data-form', 'ajax') }}
                <button type="button" class="btn btn-md btn-secondary float-right mr-1" data-dismiss="modal">{{ __('message.close') }}</button>
            </div>
        {{ html()->form()->close() }}
    </div>
</div>
<script>
    $(".select2js").select2({
        width: "100%",
        tags: true
    });
</script>
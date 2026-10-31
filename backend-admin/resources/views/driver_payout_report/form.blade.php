<!-- Modal -->
<div class="modal-dialog" role="document">
    <div class="modal-content">
        <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLabel">{{ $pageTitle }}</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
        </div>
        {!! html()->modelForm($data,'PATCH', route('driver_payout_reports.update', $id))->open() !!}
        <div class="modal-body">
            <div class="form-group">
               <div class="form-group col-md-12">
                    {{-- Status --}}
                    {!! html()->label(__('message.status'))->for('status') !!}
                    {!! html()->select(
                            'status',
                            [
                                'pending' => 'Pending',
                                'progress' => 'Progress',
                                'paid' => 'Paid',
                            ],
                            old('status', $data->status ?? null)
                        )
                        ->class('form-control')
                        ->id('status')
                        ->placeholder('Select status')
                    !!}
                </div>

                <div class="form-group col-md-12">
                    {{-- Payment Method --}}
                    {!! html()->label(__('message.payment_method'))->for('payment_method') !!}
                    {!! html()->text('payment_method')
                        ->class('form-control')
                        ->id('payment_method')
                        ->placeholder('Enter payment method')
                    !!}
                </div>

                <div class="form-group col-md-12">
                    {{-- Transaction Reference --}}
                    {!! html()->label(__('message.transaction_reference'))->for('transaction_reference') !!}
                    {!! html()->text('transaction_reference')
                        ->class('form-control')
                        ->id('transaction_reference')
                        ->placeholder('Enter transaction reference')
                    !!}
                </div>


            </div>
        </div>
        <div class="modal-footer">
            {!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-right')->id('btn_submit')->attribute('data-form', 'ajax') !!}

            <button type="button" class="btn btn-md btn-secondary float-right mr-1"
                data-dismiss="modal">{{ __('message.close') }}</button>
        </div>
        {!! html()->form()->close() !!}
    </div>
</div>
<script>
    $('#screenName').select2({
        width: '100%',
        placeholder: "{{ __('message.select_name', ['select' => __('message.screen_name')]) }}",
    });
</script>

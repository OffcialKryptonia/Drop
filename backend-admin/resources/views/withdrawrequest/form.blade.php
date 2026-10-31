<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('withdrawrequest.update', $id))->open() !!}
        @else
            {!! html()->form('POST',route('withdrawrequest.store'))->open() !!}
        @endif
        <div class="row">
            <div class="col-lg-12">
                <div class="card">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                    </div>

                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                @if(isset($id))
                                    <div class="form-group col-md-4">
                                        {!! html()->label(__('message.name'))->for('user_id')->class('form-control-label') !!}
                                        <p>{{ optional($data->user)->display_name }}</p>
                                    </div>
                                @endif

                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.amount').' <span class="text-danger">*</span>')->for('amount')->class('form-control-label') !!}
                                    @if(!isset($id))
                                        {!! html()->number('amount', old('amount'))->placeholder(__('message.amount'))->class('form-control')->attribute('min', 0)->attribute('step', 'any')->required() !!}
                                    @else
                                        <p>{{ $data->amount }}</p>
                                    @endif
                                </div>
                                
                                <div class="form-group col-md-4">
                                    {!! html()->label(__('message.status'))->for('status')->class('form-control-label')!!}
                                    {!! html()->select('status', ['0' => __('message.requested'), '1' => __('message.approved'),'2' => __('message.decline')], old('status'))->class('form-control select2js')->required() !!}
                                </div>
                            </div>
                            <hr>
                            {!! html()->submit(__('message.save'))->class('btn border-radius-10 btn-primary float-right') !!}
                        </div>
                    </div>
                </div>
            </div>
        </div>
        {!! html()->form()->close() !!}
    </div>
</x-master-layout>
<x-master-layout>
<div class="container-fluid">
    <div class="row">
        <div class="col-lg-12">
            <div class="card card-block card-stretch border-radius-20">
                <div class="card-body p-0">
                    <div class="d-flex justify-content-between align-items-center p-3">
                        <h5 class="font-weight-bold">{{ $pageTitle }}</h5>
                        <a href="{{ route('driver.index') }}" class="float-right btn btn-sm btn-primary"><i class="fa fa-angle-double-left"></i> {{ __('message.back') }}</a>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="row">
        <div class="col-lg-12">
            <div class="card border-radius-20">
                <div class="card-body">
                    <ul class="nav nav-tabs" role="tablist">
                        <li class="nav-item">
                            <a href="{{ route('driver.show',$data->id) }}" class="nav-link {{ $type == 'detail' ? 'active': '' }}"> {{ __('message.detail_form_title',['form'=>__('message.driver')]) }} </a>
                        </li>
                        <li class="nav-item">
                            <a href="{{ route('driver.show', [ $data->id, 'type' => 'bank_detail']) }}" class="nav-link {{ $type == 'bank_detail' ? 'active': '' }}"> {{ __('message.detail_form_title', [ 'form' => __('message.bank') ]) }} </a>
                        </li>
                        <li class="nav-item">
                            <a href="{{ route('driver.show', [ $data->id, 'type' => 'wallet_history']) }}" class="nav-link {{ $type == 'wallet_history' ? 'active': '' }}"> {{ __('message.wallethistory') }} </a>
                        </li>
                        <li class="nav-item">
                            <a href="{{ route('driver.show', [ $data->id, 'type' => 'ride_request']) }}" class="nav-link {{ $type == 'ride_request' ? 'active': '' }}"> {{ __('message.riderequest') }} </a>
                        </li>
                        <li class="nav-item">
                            <a href="{{ route('driver.show', [ $data->id, 'type' => 'driver_payout_report']) }}" class="nav-link {{ $type == 'driver_payout_report' ? 'active': '' }}"> {{ __('message.driver_payout_reports') }} </a>
                        </li>
                        <li class="nav-item">
                            <a href="{{ route('driver.show', [ $data->id, 'type' => 'driver_rating']) }}" class="nav-link {{ $type == 'driver_rating' ? 'active': '' }}"> {{ __('message.rating') }} </a>
                        </li>
                          <li class="nav-item">
                            <a href="{{ route('driver.show', [$data->id, 'type' => 'driver_Document']) }}" class="nav-link {{ $type == 'driver_Document' ? 'active': '' }}"> {{ __('message.document') }} </a>
                        </li>
                    </ul>
                    @if($data->is_online == 1)
                        <div style="position:absolute; top:15px; right:20px;">
                            <form action="{{ route('driver.makeOffline', $data->id) }}" method="POST">
                                @csrf
                                @method('PATCH')
                                <button type="submit"
                                        class="btn btn-danger btn-sm">

                                    {{ __('message.offline_driver') }}
                                </button>
                            </form>
                        </div>
                    @endif
                </div>
            </div>
        </div>
        @if( $type == 'detail' )
            <div class="col-lg-4">
                <div class="card card-block p-card border-radius-20">
                    <div class="profile-box">
                        <div class="profile-card border-radius-20">
                            <img src="{{ $profileImage }}" alt="01.jpg" class="avatar-100 rounded d-block mx-auto img-fluid mb-3">
                            <h3 class="font-600 text-white text-center mb-0">{{ $data->display_name }}</h3>
                            <p class="text-white text-center mb-5">
                                @php
                                    $status = 'danger';
                                    $status_label = __('message.offline');
                                    switch ($data->is_online) {
                                        case '1':
                                            $status = 'success';
                                            $status_label = __('message.online');
                                            break;
                                    }
                                @endphp
                                <span class="badge bg-{{$status}}">{{ $status_label }}</span>
                                @if($data->is_online == 1)
                                    @if($data->is_available == 1)
                                        <span class="badge bg-success">
                                            {{ __('message.driver_available_service') }}
                                        </span>
                                    @else
                                        <span class="badge bg-danger">
                                            {{ __('message.driver_not_available_service') }}
                                        </span>
                                    @endif
                                @endif
                            </p>
                            @php
                                $rating = $data->rating ?? 0;
                                $fullStars = floor($rating);
                                $halfStar = $rating - $fullStars;
                            @endphp
                            @if($rating > 0)
                                <div class="d-flex justify-content-center mt-0 {{ $data->rating ? 'mb-5' : '' }}">
                                    <div class="d-inline-flex rounded">
                                        @for ($i = 0; $i < $fullStars; $i++)
                                            <i class="fas fa-star mt-1" style="color: yellow"></i>
                                        @endfor
                                        @if ($halfStar > 0)
                                            <i class="fas fa-star-half mt-1" style="color: yellow"></i>
                                        @endif
                                        <span class="ml-2 font-600 text-white text-center mb-0">{{ "(" .number_format($rating, 1) . ")" }}</span>
                                    </div>
                                </div>
                            @endif
                        </div>
                        <div class="pro-content border-radius-20">
                            <div class="d-flex align-items-center mb-3">
                                <div class="p-icon mr-3">
                                    <i class="fas fa-envelope"></i>
                                </div>
                                <p class="mb-0 eml">{{ maskSensitiveInfo('email', $data->email) }}</p>
                            </div>
                            <div class="d-flex align-items-center mb-3">
                                <div class="p-icon mr-3">
                                    <i class="fas fa-phone-alt"></i>
                                </div>
                                <p class="mb-0">{{ maskSensitiveInfo('contact_number', $data->contact_number) }}</p>
                            </div>
                            <div class="d-flex align-items-center mb-3">
                                <div class="p-icon mr-3">

                                    @if( $data->gender == 'female' )
                                        <i class="fas fa-female"></i>
                                    @elseif( $data->gender == 'other' )
                                        <i class="fas fa-transgender"></i>
                                    @else
                                        <i class="fas fa-male"></i>
                                    @endif
                                </div>
                                <p class="mb-0">{{ $data->gender }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-lg-8">
                <div class="row">
                    <div class="col-md-9">
                        <div class="card card-block border-radius-20">
                            <div class="card-header d-flex justify-content-between">
                                <div class="header-title">
                                    <h4 class="card-title mb-0">{{ __('message.detail_form_title', [ 'form' => __('message.service') ]) }}</h4>
                                </div>
                            </div>
                            <div class="card-body">
                                <div class="row">
                                    <div class="col-3">
                                        <img src="{{ getSingleMedia($data->service, 'service_image',null) }}" alt="service-detail" class="img-fluid avatar-60 rounded-small">
                                    </div>
                                    <div class="col-9">
                                        <p class="mb-0">{{ optional($data->service)->name }}</p>
                                        <p class="mb-0">{{ optional($data->userDetail)->car_model }} ( {{ optional($data->userDetail)->car_color }} )</p>
                                        <p class="mb-0">{{ optional($data->userDetail)->car_plate_number }}</p>
                                        <p class="mb-0">{{ optional($data->userDetail)->car_production_year }}</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <!-- <div class="col-md-7">
                        <div class="card card-block border-radius-20">
                            <div class="card-header d-flex justify-content-between">
                                <div class="header-title">
                                    <h4 class="card-title mb-0">{{ __('message.detail_form_title', [ 'form' => __('message.bank') ]) }}</h4>
                                </div>
                            </div>
                            <div class="card-body">
                                <div class="row">
                                    <div class="col-6">
                                        <h5>{{ __('message.bank_name') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->bank_name ?? '-' }}</p>
                                    </div>
                                    <div class="col-6">
                                        <h5>{{ __('message.bank_code') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->bank_code ?? '-' }}</p>
                                    </div>
                                    <div class="col-6">
                                        <h5>{{ __('message.account_holder_name') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->account_holder_name ?? '-' }}</p>
                                    </div>
                                    <div class="col-6">
                                        <h5>{{ __('message.account_number') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->account_number ?? '-' }}</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div> -->
                    <div class="col-md-4">
                        <div class="card card-block border-radius-20">
                            <div class="card-body">
                                <div class="top-block-one">
                                    <p class="mb-1">{{ __('message.total_earning') }}</p>
                                    <p></p>
                                    <h5>{{ getPriceFormat( $data->total_earning ) ?? 0 }} </h5>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card card-block border-radius-20">
                            <div class="card-body">
                                <div class="top-block-one">
                                    <p class="mb-1">{{ __('message.cash_earning') }}</p>
                                    <p></p>
                                    <h5>{{ getPriceFormat( $data->cash_earning ) ?? 0 }} </h5>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card card-block border-radius-20">
                            <div class="card-body">
                                <div class="top-block-one">
                                    <p class="mb-1">{{ __('message.wallet_earning') }}</p>
                                    <p></p>
                                    <h5>{{ getPriceFormat( $data->wallet_earning ) ?? 0 }} </h5>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card card-block border-radius-20">
                            <div class="card-body">
                                <div class="top-block-one">
                                    <p class="mb-1">{{ __('message.admin_commission') }}</p>
                                    <p></p>
                                    <h5>{{ getPriceFormat( $data->admin_commission ) ?? 0 }} </h5>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card card-block border-radius-20">
                            <div class="card-body">
                                <div class="top-block-one">
                                    <p class="mb-1">{{ __('message.driver_earning') }}</p>
                                    <p></p>
                                    <h5>{{ getPriceFormat( $data->driver_earning ) ?? 0 }} </h5>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card card-block border-radius-20">
                            <div class="card-body">
                                <div class="top-block-one">
                                    <p class="mb-1">{{ __('message.wallet_balance') }}</p>
                                    <p></p>
                                    <h5>{{ getPriceFormat(optional($data->userWallet)->total_amount) ?? 0 }} </h5>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card card-block border-radius-20">
                            <div class="card-body">
                                <div class="top-block-one">
                                    <div class="">
                                        <p class="mb-1">{{ __('message.total_withdraw') }}</p>
                                        <p></p>
                                        <h5>{{ getPriceFormat(optional($data->userWallet)->total_withdrawn) ?? 0 }} </h5>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        @endif
        @if( $type == 'bank_detail' )
            <div class="col-lg-12">
                <div class="row">
                    <div class="col-md-12">
                        <div class="card">
                            <div class="card-header d-flex justify-content-between align-items-center">
                                <h4 class="card-title mb-0">{{ __('message.detail_form_title', [ 'form' => __('message.bank') ]) }}</h4>
                            </div>
                            <div class="card-body">
                                <div class="row">
                                    <div class="col-md-6 mb-3">
                                        <h5>{{ __('message.bank_name') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->bank_name ?? '-' }}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <h5>{{ __('message.bank_code') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->bank_code ?? '-' }}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <h5>{{ __('message.account_holder_name') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->account_holder_name ?? '-' }}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <h5>{{ __('message.account_number') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->account_number ?? '-' }}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <h5>{{ __('message.bank_address') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->bank_address ?? '-' }}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <h5>{{ __('message.routing_number') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->routing_number ?? '-' }}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <h5>{{ __('message.bank_iban') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->bank_iban ?? '-' }}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <h5>{{ __('message.bank_swift') }}</h5>
                                        <p class="mb-0">{{ optional($data->userBankAccount)->bank_swift ?? '-' }}</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        @endif
        @if( $type == 'wallet_history' )
            <div class="col-md-4">
                <div class="row">
                    <div class="col-md-12">
                        <div class="card card-block border-radius-20">
                            <div class="card-body">
                                <div class="top-block-one">
                                    <p class="mb-1">{{ __('message.wallet_balance') }}</p>
                                    <p></p>
                                    <h5>{{ getPriceFormat(optional($data->userWallet)->total_amount) ?? 0 }} </h5>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                @if(env('APP_DEMO') != true)
                    <div class="card card-block border-radius-20">
                        <div class="card-header d-flex justify-content-between">
                            <div class="header-title">
                                <h4 class="card-title mb-0">{{ __('message.add_form_title', [ 'form' => __('message.wallet') ]) }}</h4>
                            </div>
                        </div>
                        <div class="card-body">
                            {!! html()->form('POST', route('savewallet.fund',$data->id))->open() !!}
                                <div class="row">
                                    <div class="form-group col-md-4">
                                        {!! html()->label(__('message.type') . ' <span class="text-danger">*</span>')->for('type')->class('form-control-label') !!}
                                        {!! html()->select('type', [ 'credit' => __('message.credit'), 'debit' => __('message.debit') ], old('type'))->class('form-control select2js')->required() !!}
                                    </div>

                                    <div class="form-group col-md-8">
                                        {!! html()->label(__('message.transaction_type') . ' <span class="text-danger">*</span>')->for('transaction_type')->class('form-control-label') !!}
                                        {!! html()->select('transaction_type', [], old('transaction_type'))->class('form-control select2js')->required() !!}
                                    </div>

                                    <div class="form-group col-md-12">
                                        {!! html()->label(__('message.amount') . ' <span class="text-danger">*</span>')->for('amount')->class('form-control-label') !!}
                                        {!! html()->number('amount', old('amount'))->class('form-control')->attribute('min',0)->attribute('step','any')->required()->placeholder(__('message.amount')) !!}
                                    </div>

                                    <div class="form-group col-md-12">
                                        {!! html()->label(__('message.description'))->for('description')->class('form-control-label') !!}
                                        {!! html()->textarea('description', old('description'))->class('form-control textarea')->attribute('rows',2)->placeholder(__('message.description')) !!}
                                    </div>
                                    <hr>
                                    {!! html()->button(__('message.save'))->type('submit')->class('btn border-radius-10 btn-success float-right') !!}

                            {!! html()->form()->close() !!}
                        </div>
                    </div>
                @endif
            </div>
            </div>
            <div class="col-md-8">
                <div class="card card-block border-radius-20">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title mb-0">{{ __('message.list_form_title', [ 'form' => __('message.wallethistory') ]) }}</h4>
                        </div>
                    </div>
                    <div class="card-body">
                        {{ $dataTable->table(['class' => 'table  w-100'],false) }}
                    </div>
                </div>
            </div>
        @endif
        @if( $type == 'ride_request' )
            <div class="col-md-12">
                <div class="card card-block border-radius-20">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title mb-0">{{ __('message.list_form_title', [ 'form' => __('message.riderequest') ]) }}</h4>
                        </div>
                    </div>
                    <div class="card-body">
                        {{ $dataTable->table(['class' => 'table  w-100'],false) }}
                    </div>
                </div>
            </div>
        @endif
        @if($type == 'driver_payout_report')
            <div class="col-md-12">
                <div class="card card-block border-radius-20">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title mb-0">{{ __('message.list_form_title', [ 'form' => __('message.driver_payout_reports') ]) }}</h4>
                        </div>
                    </div>
                    <div class="card-body">
                        {{ $dataTable->table(['class' => 'table  w-100'],false) }}
                    </div>
                </div>
            </div>
        @endif
        @if($type == 'driver_rating')
            <div class="col-md-12">
                <div class="card card-block border-radius-20">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title mb-0">{{ __('message.list_form_title', [ 'form' => __('message.rating') ]) }}</h4>
                        </div>
                    </div>
                    <div class="card-body">
                        {{ $dataTable->table(['class' => 'table  w-100'],false) }}
                    </div>
                </div>
            </div>
        @endif
        @if($type == 'driver_Document')
            <div class="col-md-12">
                <div class="card card-block border-radius-20">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title">
                            <h4 class="card-title mb-0">
                                {{ __('message.list_form_title', ['form' => __('message.document')]) }}
                            </h4>
                        </div>
                    </div>
                    <div class="card-body">
                        {{ $dataTable->table(['class' => 'table w-100'] , false) }}
                    </div>
                </div>
            </div>
        @endif
    </div>
</div>
@section('bottom_script')
    {{ in_array($type,['wallet_history','ride_request','driver_payout_report','driver_rating','driver_Document']) ? $dataTable->scripts() : '' }}
    <script type="text/javascript">
        (function($) {
            "use strict";
            $(document).ready(function() {

                var type = $("#type :selected").val();
                transactionTypeList(type);
                $(document).on('change', '#type' , function (){
                    var type = $("#type :selected").val();
                    $('#transaction_type').empty();
                    transactionTypeList(type);
                })
            })

            function transactionTypeList(type) {
                var route = "{{ route('ajax-list',['type' => 'transaction_type','user_type' => 'driver', 'type_val' =>'']) }}"+type;
                route = route.replaceAll('amp;','');

                $.ajax({
                    url: route,
                    success: function(result){
                        $('#transaction_type').select2({
                            width : '100%',
                            placeholder: "{{ __('message.select_name',['select' => __('message.transaction_type')]) }}",
                            data: result.results
                        });
                        if(type != null ){
                            $("#transaction_type").val(type).trigger('change');
                        }
                    }
                })
            }
        })(jQuery);
    </script>
@endsection
</x-master-layout>

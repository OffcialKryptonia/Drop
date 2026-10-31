<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('driver.update', $id))->attribute('enctype', 'multipart/form-data')->open() !!}
        @else
            {!! html()->form('POST', route('driver.store'))->attribute('enctype', 'multipart/form-data')->open() !!}
        @endif
        <div class="row">
            <div class="col-xl-3 col-lg-4 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between" style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }}</h4>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="form-group">
                            <div class="crm-profile-img-edit position-relative text-center">
                                <img src="{{ $profileImage ?? asset('images/user/1.jpg')}}" alt="User-Profile" class="crm-profile-pic rounded-circle avatar-100">
                                <div class="crm-p-image bg-primary">
                                    <svg class="upload-button" width="14" height="14" viewBox="0 0 24 24">
                                        <path fill="#ffffff" d="M14.06,9L15,9.94L5.92,19H5V18.08L14.06,9M17.66,3C17.41,3 17.15,3.1 16.96,3.29L15.13,5.12L18.88,8.87L20.71,7.04C21.1,6.65 21.1,6 20.71,5.63L18.37,3.29C18.17,3.09 17.92,3 17.66,3M14.06,6.19L3,17.25V21H6.75L17.81,9.94L14.06,6.19Z" />
                                    </svg>
                                    <input class="file-upload" type="file" accept="image/*" name="profile_image">
                                </div>
                            </div>
                            <div class="img-extension mt-3">
                                <div class="d-inline-block align-items-center">
                                    <span>{{ __('message.only') }}</span>
                                    @foreach(config('constant.IMAGE_EXTENTIONS') as $extention)
                                        <a href="javascript:void();">.{{ $extention }}</a>
                                    @endforeach
                                    <span>{{ __('message.allowed') }}</span>
                                </div>
                                <hr>
                            </div>
                        </div>
                        <div class="form-group">
                            <label class="form-label">{{ __('message.status') }}</label>
                            <div class="row" style="--bs-gap: 1rem;">
                                <div class="col-md-6">
                                    <div class="custom-control custom-radio custom-control-inline">
                                        {!! html()->radio('status', old('status') === 'active', 'active')->class('custom-control-input')->id('status-active') !!}
                                        {!! html()->label(__('message.active'))->class('custom-control-label')->for('status-active') !!}
                                    </div>
                                    <div class="custom-control custom-radio custom-control-inline">
                                        {!! html()->radio('status', old('status') === 'inactive', 'inactive')->class('custom-control-input')->id('status-inactive') !!}
                                        {!! html()->label(__('message.inactive'))->class('custom-control-label')->for('status-inactive') !!}
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="custom-control custom-radio custom-control-inline">
                                        {!! html()->radio('status', old('status') === 'pending', 'pending')->class('custom-control-input')->id('status-pending') !!}
                                        {!! html()->label(__('message.pending'))->class('custom-control-label')->for('status-pending') !!}
                                    </div>
                                    <div class="custom-control custom-radio custom-control-inline">
                                        {!! html()->radio('status', old('status') === 'banned', 'banned')->class('custom-control-input')->id('status-banned') !!}
                                        {!! html()->label(__('message.banned'))->class('custom-control-label')->for('status-banned') !!}
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="custom-control custom-radio custom-control-inline">
                                        {!! html()->radio('status', old('status') === 'reject', 'reject')->class('custom-control-input')->id('status-reject') !!}
                                        {!! html()->label(__('message.reject'))->class('custom-control-label')->for('status-reject') !!}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xl-9 col-lg-8 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between" style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle }} {{ __('message.information') }}</h4>
                        </div>
                        <div class="card-action">
                            <a href="{{route('driver.index')}}" class="float-right btn btn-sm border-radius-10 btn-primary me-2" role="button"><i class="fas fa-arrow-circle-left"></i> {{ __('message.back') }}</a>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.first_name') . ' <span class="text-danger">*</span>')->for('first_name')->class('form-control-label') !!}
                                    {!! html()->text('first_name')->class('form-control')->placeholder(__('message.first_name'))->required() !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.last_name') . ' <span class="text-danger">*</span>')->for('last_name')->class('form-control-label') !!}
                                    {!! html()->text('last_name')->class('form-control')->placeholder(__('message.last_name'))->required() !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.email') . ' <span class="text-danger">*</span>')->for('email')->class('form-control-label') !!}
                                    {!! html()->email('email')->class('form-control')->placeholder(__('message.email'))->required() !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.username') . ' <span class="text-danger">*</span>')->for('username')->class('form-control-label') !!}
                                    {!! html()->text('username')->class('form-control')->placeholder(__('message.username'))->required() !!}
                                </div>

                                @if(!isset($id))
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.password') . ' <span class="text-danger">*</span>')->for('password')->class('form-control-label') !!}
                                        {!! html()->password('password')->class('form-control')->placeholder(__('message.password')) !!}
                                    </div>
                                @endif

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.contact_number') . ' <span class="text-danger">*</span>')->for('contact_number')->class('form-control-label') !!}
                                    {!! html()->text('contact_number')->class('form-control')->id('phone')->placeholder(__('message.contact_number')) !!}
                                        <input type="hidden" id="country_code" name="country_code">
                                </div>

                                {{-- <div class="form-group col-md-6">
                                    {!! html()->label(__('message.gender') . ' <span class="text-danger">*</span>')->for('gender')->class('form-control-label') !!}
                                    {!! html()->select('gender', [
                                            'male' => __('message.male'),
                                            'female' => __('message.female'),
                                            'other' => __('message.other')
                                        ], old('gender'))->class('form-control select2js')->required() !!}
                                </div> --}}

                                {{-- @if(auth()->user()->hasAnyRole(['admin','demo_admin'])) --}}
                                {{-- <div class="form-group col-md-6">
                                    {!! html()->label(__('message.fleet'))
                                        ->for('fleet_id')
                                        ->class('form-control-label') !!}
                                    {!! html()->select('fleet_id', isset($id) ? [ optional($data->fleet)->id => optional($data->fleet)->display_name ] : [])
                                        ->class('form-control select2js')
                                        ->attribute('data-ajax--url', route('ajax-list', [ 'type' => 'fleet' ]))
                                        ->attribute('data-placeholder', __('message.select_field', [ 'name' => __('message.fleet') ])) !!}
                                </div> --}}
                                {{-- @endif --}}




                                 <!-- Service List -->
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.select_name', ['select' => __('message.service')]). ' <span class="text-danger">*</span>')->for('service_id')->class('form-control-label') !!}
                                    {!! html()->select('service_id', isset($id) ? [optional($data->service)->id => optional($data->service)->name] : [], old('service_id'))
                                        ->class('select2js form-group service')
                                        ->required()
                                        ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.service')]))
                                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'service'])) !!}
                                </div>
                                {{--
                                <div class="form-group col-md-6">
                                   {!! html()->label(__('message.select_name',[ 'select' => __('message.service') ]))->for('service_id')->class('form-control-label') !!}
                                    <br />
                                     {!! html()->select('service_id[]', $selected_service, isset($id) ? $data->driverService->pluck('service_id') : null, [
                                            ->class('select2js form-group service')
                                            ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.service')]))
                                            ->attribute('multiple','multiple')
                                            ->attribute('data-ajax--url', route('ajax-list', ['type' => 'service'])) !!}
                                </div>
                                --}}
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.car_model') . ' <span class="text-danger">*</span>')->for('car_model')->class('form-control-label') !!}
                                    {!! html()->text('userDetail[car_model]', old('userDetail[car_model]'))->class('form-control')->placeholder(__('message.car_model')) !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.car_color') . ' <span class="text-danger">*</span>')->for('car_color')->class('form-control-label') !!}
                                    {!! html()->text('userDetail[car_color]', old('userDetail[car_color]'))->class('form-control')->placeholder(__('message.car_color')) !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.car_plate_number') . ' <span class="text-danger">*</span>')->for('car_plate_number')->class('form-control-label') !!}
                                    {!! html()->text('userDetail[car_plate_number]', old('userDetail[car_plate_number]'))->class('form-control')->placeholder(__('message.car_plate_number')) !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.car_production_year') . ' <span class="text-danger">*</span>')->for('car_production_year')->class('form-control-label') !!}
                                    {!! html()->text('userDetail[car_production_year]', old('userDetail[car_production_year]'))->class('form-control')->placeholder(__('message.car_production_year')) !!}
                                </div>


                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.bank_name') . ' <span class="text-danger">*</span>')->for('bank_name')->class('form-control-label') !!}
                                    {!! html()->text('userBankAccount[bank_name]', old('userBankAccount[bank_name]'))->class('form-control')->placeholder(__('message.bank_name')) !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.bank_code') . ' <span class="text-danger">*</span>')->for('bank_code')->class('form-control-label') !!}
                                    {!! html()->text('userBankAccount[bank_code]', old('userBankAccount[bank_code]'))->class('form-control')->placeholder(__('message.bank_code')) !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.account_holder_name') . ' <span class="text-danger">*</span>')->for('account_holder_name')->class('form-control-label') !!}
                                    {!! html()->text('userBankAccount[account_holder_name]', old('userBankAccount[account_holder_name]'))->class('form-control')->placeholder(__('message.account_holder_name')) !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.account_number') . ' <span class="text-danger">*</span>')->for('account_number')->class('form-control-label') !!}
                                    {!! html()->text('userBankAccount[account_number]', old('userBankAccount[account_number]'))->class('form-control')->placeholder(__('message.account_number')) !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.routing_number'))->for('routing_number')->class('form-control-label') !!}
                                    {!! html()->text('userBankAccount[routing_number]', old('userBankAccount[routing_number]'))->class('form-control')->placeholder(__('message.routing_number')) !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.bank_iban'))->for('bank_iban')->class('form-control-label') !!}
                                    {!! html()->text('userBankAccount[bank_iban]', old('userBankAccount[bank_iban]'))->class('form-control')->placeholder(__('message.bank_iban')) !!}
                                </div>

                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.bank_swift'))->for('bank_swift')->class('form-control-label') !!}
                                    {!! html()->text('userBankAccount[bank_swift]', old('userBankAccount[bank_swift]'))->class('form-control')->placeholder(__('message.bank_swift')) !!}
                                </div>

                                {{-- <div class="form-group col-md-6">
                                    {!! html()->label(__('message.address'))->for('address')->class('form-control-label') !!}
                                    {!! html()->textarea('address', old('address'))->class('form-control textarea')->attribute('row',2)->placeholder(__('message.address')) !!}
                                </div> --}}
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

<x-master-layout :assets="$assets ?? []">
    <div>
        <?php $id = $id ?? null;?>
        @if(isset($id))
            {!! html()->modelForm($data,'PATCH', route('rider.update', $id))->attribute('enctype', 'multipart/form-data')->id('rider_form')->open() !!}
        @else
            {!! html()->form('POST', route('rider.store'))->attribute('enctype', 'multipart/form-data')->id('rider_form')->open() !!}

        @endif
        <div class="row">
            <div class="col-xl-3 col-lg-4 mt-3">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
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
                                        {!! html()->radio('status', old('status', 'active') === 'active', 'active')->class('custom-control-input')->id('status-active') !!}
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
                                        {!! html()->radio('status', old('status') === 'banned','banned')->class('custom-control-input')->id('status-banned') !!}
                                        {!! html()->label(__('message.banned'))->class('custom-control-label')->for('status-banned') !!}
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
                        <a href="{{route('rider.index')}}" class="btn border-radius-10 btn-sm btn-primary float-right" role="button"><i class="fas fa-arrow-circle-left"></i> {{ __('message.back') }}</a>
                    </div>
                    <div class="card-body">
                        <div class="new-user-info">
                            <div class="row">
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.first_name') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('first_name') !!}
                                    {!! html()->text('first_name', old('first_name'))->class('form-control')->placeholder(__('message.first_name')) !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.last_name') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('last_name') !!}
                                    {!! html()->text('last_name', old('last_name'))->class('form-control')->placeholder(__('message.last_name')) !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.email') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('email') !!}
                                    {!! html()->email('email', old('email'))->class('form-control')->placeholder(__('message.email')) !!}
                                </div>
                                
                                <div class="form-group col-md-6">
                                    {!! html()->label(__('message.username') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('username') !!}
                                    {!! html()->text('username', old('username'))->class('form-control')->placeholder(__('message.username')) !!}
                                </div>
                                
                                @if(!isset($id))
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.password') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('password') !!}
                                        {!! html()->password('password')->class('form-control')->placeholder(__('message.password')) !!}
                                    </div>
                                @endif
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.contact_number') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('contact_number') !!}
                                        {!! html()->text('contact_number', old('contact_number'))->class('form-control')->id('phone')->placeholder(__('message.contact_number')) !!}
                                       <input type="hidden" id="country_code" name="country_code">
                                        

                                    </div>
                                
                                {{-- <div class="form-group col-md-6">
                                    {!! html()->label(__('message.gender') . ' <span class="text-danger">*</span>')->class('form-control-label')->for('gender') !!}
                                    {!! html()->select('gender', [
                                            'male' => __('message.male'),
                                            'female' => __('message.female'),
                                            'other' => __('message.other')
                                        ], old('gender'))->class('form-control select2js') !!}
                                </div> --}}
                                
                                @if(isset($id))
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.bank_name'))->class('form-control-label')->for('bank_name') !!}
                                        {!! html()->text('userBankAccount[bank_name]', old('userBankAccount[bank_name]'))->class('form-control')->placeholder(__('message.bank_name')) !!}
                                    </div>
                                
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.bank_code'))->class('form-control-label')->for('bank_code') !!}
                                        {!! html()->text('userBankAccount[bank_code]', old('userBankAccount[bank_code]'))->class('form-control')->placeholder(__('message.bank_code')) !!}
                                    </div>
                                
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.account_holder_name'))->class('form-control-label')->for('account_holder_name') !!}
                                        {!! html()->text('userBankAccount[account_holder_name]', old('userBankAccount[account_holder_name]'))->class('form-control')->placeholder(__('message.account_holder_name')) !!}
                                    </div>
                                
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.account_number'))->class('form-control-label')->for('account_number') !!}
                                        {!! html()->text('userBankAccount[account_number]', old('userBankAccount[account_number]'))->class('form-control')->placeholder(__('message.account_number')) !!}
                                    </div>
                                
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.routing_number'))->class('form-control-label')->for('routing_number') !!}
                                        {!! html()->text('userBankAccount[routing_number]', old('userBankAccount[routing_number]'))->class('form-control')->placeholder(__('message.routing_number')) !!}
                                    </div>
                                
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.bank_iban'))->class('form-control-label')->for('bank_iban') !!}
                                        {!! html()->text('userBankAccount[bank_iban]', old('userBankAccount[bank_iban]'))->class('form-control')->placeholder(__('message.bank_iban')) !!}
                                    </div>
                                
                                    <div class="form-group col-md-6">
                                        {!! html()->label(__('message.bank_swift'))->class('form-control-label')->for('bank_swift') !!}
                                        {!! html()->text('userBankAccount[bank_swift]', old('userBankAccount[bank_swift]'))->class('form-control')->placeholder(__('message.bank_swift')) !!}
                                    </div>
                                @endif
                                
                                {{-- <div class="form-group col-md-6">
                                    {!! html()->label(__('message.address'))->class('form-control-label')->for('address') !!}
                                    {!! html()->textarea('address')->class('form-control textarea')->rows(3)->placeholder(__('message.address')) !!}
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
    @section('bottom_script')
        <script>
            $(document).ready(function(){
                formValidation("#rider_form", {
                    first_name: { required: true },
                    last_name: { required: true },
                    email: { required: true, email: true },
                    username: { required: true },
                    password: { required: true },
                    contact_number: { required: true },
                    gender: { required: true },
                }, {
                    first_name: { required: "{{__('message.please_enter_first_name')}}" },
                    last_name: { required: "{{__('message.please_enter_last_name')}}" },
                    email: { required: "{{__('message.please_enter_email')}}", email: "{{__('message.please_enter_valid_email')}}" },
                    username: { required: "{{__('message.please_enter_username')}}" },
                    password: { required: "{{__('message.please_enter_password')}}" },
                    contact_number: { required: "{{__('message.please_enter_contact_number')}}" },
                    gender: { required: "{{__('message.please_select_gender')}}" },
                });
            });   
        </script>
     
                
    @endsection
</x-master-layout>


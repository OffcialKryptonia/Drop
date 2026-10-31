<x-master-layout>
    <div class="container-fluid">
        <!-- Header Row -->
        <div class="row">
            <div class="col-lg-12">
                <div class="card card-block card-stretch">
                    <div class="card-body p-0">
                        <div class="d-flex justify-content-between align-items-center p-3">
                            <h5 class="font-weight-bold">{{ $pageTitle }}</h5>
                            <a href="{{ route('customersupport.index') }}" class="float-right btn btn-sm btn-primary">
                                <i class="fa fa-angle-double-left"></i> {{ __('message.back') }}
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Main Content Row -->
        <div class="row">
            <!-- Chat Section -->
            <div class="col-xl-8 content">
                <div class="card card-block">
                    @php
                        $user = auth()->user();
                    @endphp

                    <!-- Chat History -->
                    <div class="card-body chat-body bg-body" style="max-height: 400px; overflow-y: auto;">
                        @foreach($match as $supportchat)
                        @php
                            if ($supportchat->user_id == $current_user->id) {
                                
                                if ($current_user->user_type == 'admin') {
                                    $current_user_class = 'mm-current-user';
                                    $message_class = 'justify-content-end';
                                } elseif ($current_user->user_type == 'rider') {
                                    $current_user_class = 'mm-other-user';
                                    $message_class = 'justify-content-start';
                                }
                            } else {
                                $current_user_class = 'mm-other-user';
                                $message_class = 'justify-content-start';
                            }
                        @endphp
                
                            <div class="chat-day-title d-none">
                                <span class="main-title">Dec 1,2022</span>
                            </div>

                            <div class="mm-message-body {{ $current_user_class }}">
                                <div class="chat-profile">
                                    <img src="{{ getSingleMedia(optional($supportchat->user), 'profile_image', null) }}" alt="chat-user" class="avatar-40 rounded-pill" loading="lazy">
                                </div>
                                <div class="mm-chat-text">
                                    <small class="mm-chating p-0">
                                        {{ optional($supportchat->user)->display_name }}, {{ date('h:i A', strtotime(dateAgoFormate($supportchat->datetime))) }}
                                    </small>
                                    <div class="d-flex align-items-center {{ $message_class }}">
                                        <div class="mm-chating-content d-flex align-items-center">
                                            <p class="mr-2 mb-0">{{ $supportchat->message }}</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        @endforeach
                    </div>
                    <!-- Chat Form -->
                    <div class="card-footer px-3 py-3">
                            {{ html()->form('POST', route('supportchathistory.store'))->attribute('data-toggle', 'validator')->id('commentForm')->attribute('button-loader', 'true')->attribute('data-ajax', 'true')->attribute('data-submit-reset', 'true')->open() }}
                            {{ html()->hidden('support_id', $data->id) }}
                           
                            <div class="input-group mb-3">
                                {!! html()->text('message', old('message'))->placeholder(__('message.enter_name', ['name' => 'here...']))->class('form-control mr-1')->required() !!}

                                <div class="input-group-append">
                                    <button type="submit" class="btn btn-outline-primary">
                                        <i class="fas fa-paper-plane"></i>
                                    </button>
                                </div>
                            </div>
                        {!! html()->form()->close() !!}
                    </div>
                </div>
            </div>

            <!-- Sidebar Section -->
            <div class="col-md-4 pl-0 sidebar">
                <div class="card">
                    <div class="card-header d-flex justify-content-between">
                        <div class="header-title d-flex align-items-center">
                            <h4 class="card-title">
                                <span class="pr-2">{{ __('message.detail_form_title', ['form' => __('message.customer_support')]) }}</span>
                            </h4>
                            <div class="ml-auto">
                                @php
                                    $status = 'warning';
                                    switch ($data->status) {
                                        case 'inreview':
                                            $status = 'primary';
                                            break;
                                        case 'resolved':
                                            $status = 'success';
                                            break;
                                        default:
                                            break;
                                    }
                                @endphp
                                <h5 class="card-title ml-3">
                                    <span class="badge bg-{{ $status }}" data-toggle="tooltip" title="{{ __('message.status') }}">
                                        {{ __('message.' . $data->status) }}
                                    </span>
                                </h5>
                            </div>
                        </div>                         
                    </div>
                   
                    <div class="table-responsive">
                        <table class="table align-items-center border-0">
                            <tbody>
                                <tr>
                                    <td class="t-head">{{ __('message.support_id') }}</td>
                                    <td class="t-head">
                                        #{{ $data->id }} | 
                                        <span data-toggle="tooltip" title="{{ date('d M Y', strtotime($data->created_at)) }}">
                                            {{ timeAgoFormate($data->created_at) }}
                                        </span><br>
                                    </td>
                                </tr>
                                <tr>
                                    <td class="t-head">{{ __('message.support_type') }}</td>
                                    <td class="t-head">{{ $data->support_type ?? '-' }}</td>
                                </tr>
                                <tr>
                                    <td class="t-head">{{ __('message.email_address')}}</td>
                                    <td class="t-head">{{ optional($data->user)->email ?? '-' }}</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    <hr>
                    {!! html()->form('PUT', route('support.updateStatus', $data->id))->open() !!}
                    <div class="row col-md-12">
                        <div class="form-group col-md-5">
                            {!! html()->label(__('message.resolution_detail'))->class('form-control-label')->for('resolution_detail') !!}
                            {!! html()->text('resolution_detail', $data->resolution_detail ?? old('resolution_detail'))
                                ->placeholder(__('message.resolution_detail'))
                                ->class('form-control') !!}
                        </div>
                        <div class="form-group col-md-5">
                            {!! html()->label(__('message.status') . ' <span class="text-danger">*</span>')->class('form-label')->for('status') !!}
                            {!! html()->select('status', [
                                    'pending' => __('message.pending'), 
                                    'inreview' => __('message.inreview'), 
                                    'resolved' => __('message.resolved')
                                ], $data->status)
                                ->class('form-control select2js') !!}
                        </div>
                        <div class="form-group col-sm-2 mt-4 d-flex justify-content-end">
                            {!! html()->submit(__('message.save'))->class('btn btn-sm btn-primary float-right') !!}
                        </div>
                    </div>
                {!! html()->form()->close() !!}

            </div>
            </div>          
        </div>
    </div>
</x-master-layout>

{!! html()->modelForm($notification_setting_data,'POST', route('notificationSettingsUpdate'))->attribute('data-toggle','validator')->open() !!}
{{ html()->hidden('page', $page)->class('form-control') }}

    <div class="col-md-12 mt-20">
        <table class="table table-condensed ">
            <thead>
                <tr>
                    <th>{{ __('message.type') }}</th>
                    @foreach($notification_setting as $key => $notification_types)
                        <th class="text-center">{{ __("message.notification_list.$key") }}</th>
                    @endforeach
                </tr>
            </thead>
            <tbody>
                @foreach( config('constant.ride_status') as $key => $value)
                    <tr>
                        <td>{{ __("message.$value") }} </td>
                        @foreach( $notification_setting as $key => $val)
                            <td align="center">
                                <div class="custom-control custom-checkbox">
                                    {!! html()->hidden("notification_settings[$value][$key]", 0) !!}
                                    {!! html()->checkbox("notification_settings[$value][$key]", 1)->class('custom-control-input')->id("notification_settings-$key-$value") !!}
                                    {!! html()->label()->for("notification_settings-$key-$value")->class('custom-control-label') !!}
                                </div>
                            </td>
                        @endforeach
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
{!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-right') !!}
{!! html()->form()->close() !!}
{!! html()->modelForm($databasebackup_setting, 'POST', route('updateAppsSetting'))->attribute('data-toggle', 'validator')->open() !!}
{!! html()->hidden('id')->class('form-control') !!}
{!! html()->hidden('page', $page)->class('form-control') !!}

<div class="row">
    <div class="form-group col-lg-6">
        {!! html()->label(__('message.backup_type'). ' <span class="text-danger">*</span>')->for('backup_type')->class('form-control-label') !!}
        {!! html()->select('backup_type', [
                'daily' => __('message.daily'),
                'monthly' => __('message.monthly'),
                'weekly' => __('message.weekly'),
                'none' => __('message.none')
            ], old('backup_type'))->class('form-control select2js')->required() !!}
    </div>

    <div class="form-group col-md-6">
        {!! html()->label(__('message.email'). ' <span class="text-danger">*</span>')->for('backup_email')->class('form-control-label') !!}
        {!! html()->email('backup_email', old('backup_email'))->placeholder(__('message.email'))->class('form-control') !!}
    </div>
</div>

{!! html()->submit(__('message.save'))->class('btn btn-md btn-primary float-md-right') !!}

{!! html()->form()->close() !!}

<script>
    $(document).ready(function() {
        $('.select2js').select2();
    });
</script>
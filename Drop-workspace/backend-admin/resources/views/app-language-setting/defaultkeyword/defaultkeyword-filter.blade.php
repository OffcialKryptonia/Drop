<form method="GET" id="default_keyword_filter_form">
    <div class="row align-items-end">
        <div class="form-group col-md-3">
            {!! html()->label(__('message.select_name', ['select' => __('message.screen')]))->for('screen')->class('form-control-label') !!}
            {!! html()->select('screen', isset($screen) ? [$screen->screenId => $screen->screenName] : [], old('screen'))
                ->class('select2js form-group screen')
                ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.screen')]))
                ->attribute('data-ajax--url', route('ajax-list', ['type' => 'screen'])) !!}
        </div>
        <div class="form-group col-md-3">
            {!! html()->label(__('message.keyword_title'))->class('form-label')->for('keyword_title') !!}
            {!! html()->select('keyword_title', [], request('keyword_title'))
                ->class('form-control select2js')
                ->attribute('data-ajax--url', route('ajax-list', ['type' => 'defaultkeyword']))
                ->attribute('data-placeholder', __('message.select_field', ['name' => __('message.keyword_title')]))
                ->attribute('data-allow-clear', 'true') !!}
        </div>

        <div class="form-group col-md-4 d-flex justify-content-start align-items-end">
            <button type="submit" class="btn btn-primary border-radius-10 mr-2">
                {{ __('message.apply_filter') }}
            </button>
            <button id="reset-filter-btn" type="button" class="btn btn-warning border-radius-10 me-2">
                {{ __('message.reset_filter') }}
            </button>
        </div>
    </div>
</form>

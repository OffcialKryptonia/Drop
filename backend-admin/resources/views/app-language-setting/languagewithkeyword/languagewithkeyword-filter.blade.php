{!! html()->form('GET')->open() !!}
    <div class="row">
        <div class="form-group col-md-3">
            {!! html()->label(__('message.select_name', ['select' => __('message.language')]))
                ->class('form-control-label')
                ->for('language') !!}

            {!! html()->select('language', isset($language) ? [$language->id => $language->language_name] : [], old('language'))
                ->class('select2Clear form-group language')
                ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.language')]))
                ->attribute('data-ajax--url', route('ajax-list', ['type' => 'languagetable'])) !!}
        </div>

        <div class="form-group col-md-3">
            {!! html()->label(__('message.select_name', ['select' => __('message.keyword')]))
                ->class('form-control-label')
                ->for('keyword') !!}

            {!! html()->select('keyword', isset($keyword) ? [$keyword->id => $keyword->keyword_name] : [], old('keyword'))
                ->class('select2Clear form-group keyword')
                ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.keyword')]))
                ->attribute('data-ajax--url', route('ajax-list', ['type' => 'defaultkeyword'])) !!}
        </div>
        <div class="form-group col-md-3">
            {!! html()->label(__('message.select_name', ['select' => __('message.screen')]))
                ->class('form-control-label')
                ->for('screen') !!}

            {!! html()->select('screen', isset($screen) ? [$screen->screenId => $screen->screenName] : [], old('screen'))
                ->class('select2Clear form-group screen')
                ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.screen')]))
                ->attribute('data-ajax--url', route('ajax-list', ['type' => 'screen'])) !!}
        </div>

        <div class="form-group col-md-2 mt-1">
            {!! html()->button(__('message.apply_filter'))
                ->class('btn btn-sm border-radius-10 btn-outline-success mt-4 p-2') !!}

            @if(isset($reset_file_button))
                {!! $reset_file_button !!}
            @endif
        </div>
    </div>
{!! html()->form()->close() !!}


<div class="modal fade fixed-right" id="filterModal" tabindex="-1" aria-labelledby="filterModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-aside">
        <div class="modal-content h-100">
            <div class="modal-header">
                <h5 class="modal-title" id="filterModalLabel">{{ __('message.filter') }}</h5>
                <a href="javascript:void();" data-bs-dismiss="modal" aria-label="Close"><i class="ri-close-circle-fill" style="font-size: 25px"></i></a>
            </div>
            <div class="modal-body">
                {!! html()->form('GET')->id('lang_keyword_filter_form')->open() !!}

                <div class="form-group">
                    {!! html()->label(__('message.select_name', ['select' => __('message.language')]))
                        ->class('form-control-label')
                        ->for('language') !!}

                    {!! html()->select('language', isset($language) ? [$language->id => $language->language_name] : [], old('language'))
                        ->class('select2 form-group language')
                        ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.language')]))
                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'languagetable'])) !!}
                </div>

                <div class="form-group">
                    {!! html()->label(__('message.select_name', ['select' => __('message.keyword')]))
                        ->class('form-control-label')
                        ->for('keyword_id') !!}
                    {!! html()->select('keyword_id', isset($keyword) ? [$keyword->keyword_id => $keyword->keyword_name] : [], old('keyword_id'))
                        ->class('select2 form-group keyword_id')
                        ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.keyword')]))
                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'languagewithkeyword-defaultkeyword'])) !!}
                </div>

                <div class="form-group">
                    {!! html()->label(__('message.select_name', ['select' => __('message.screen')]))
                        ->class('form-control-label')
                        ->for('screen') !!}

                    {!! html()->select('screen', isset($screen) ? [$screen->screenId => $screen->screenName] : [], old('screen'))
                        ->class('select2 form-group screen')
                        ->attribute('data-placeholder', __('message.select_name', ['select' => __('message.screen')]))
                        ->attribute('data-ajax--url', route('ajax-list', ['type' => 'screen'])) !!}
                </div>
            </div>
                <div class="modal-footer">
                    <button id="reset-filter-btn" type="button" class="btn btn-warning btn-sm border-radius-10 me-2 text-decoration-none">
                        {{ __('message.reset_filter') }}
                    </button>
                    <button type="submit" class="btn btn-primary btn-sm border-radius-10">{{ __('message.apply_filter') }}</button>
                </div>
            {!! html()->form()->close() !!}
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js" integrity="sha512-v2CJ7UaYy4JwqLDIrZUI/4hqeoQieOmAZNXBeQyjo21dadnwR+8ZaIJVT8EE2iyI61OV8e6M8PP2/4hpQINQ/g==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
<script>
    $(document).ready(function() {
        $('#lang_keyword_filter_form').on('submit', function(e) {
            e.preventDefault();
            var formData = $(this).serialize();
            var table = $('#dataTableBuilder').DataTable();
            table.ajax.url('{{ route("languagewithkeyword.index") }}?' + formData).load();
            $('.download-csv-keyword').attr('href', '{{ route("download.language.with.keyword.list") }}?' + formData);
        });

        $('#reset-filter-btn').on('click', function() {
            $('#language').val('').trigger('change');
            $('#keyword_id').val('').trigger('change');
            $('#screen').val('').trigger('change');
            var table = $('#dataTableBuilder').DataTable();
            table.ajax.url('{{ route("languagewithkeyword.index") }}').load();
        });
    });
</script>

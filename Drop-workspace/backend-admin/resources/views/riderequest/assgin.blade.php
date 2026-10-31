<div class="modal fade" id="assignModal" tabindex="-1" role="dialog" aria-labelledby="assignModalLabel" aria-hidden="true">
    {!! html()->form('POST', route('driver.assign'))->id('assign_driver_form')->open() !!}
    {!! html()->hidden('type', 'assigned_driver') !!}
    {!! html()->hidden('status', 'assign_driver') !!}
    {!! html()->hidden('id', $id ?? null) !!}

    <div class="modal-dialog modal-dialog-centered modal-xl" role="document">
        <div class="modal-content border-radius-20">
            <div class="modal-header">
                <h5 class="modal-title" id="assignModalLabel">{{ __('message.assign_driver') }}</h5>
                <a href="javascript:void();" data-bs-dismiss="modal" aria-label="Close"><i class="ri-close-circle-fill" style="font-size: 25px"></i></a>
            </div>

            <div class="modal-body">
                <div class="table-responsive mt-4">
                    <table id="basic-table" class="table mb-0 text-center">
                        <thead>
                            <tr>
                                <th>{{ __('message.id') }}</th>
                                <th>{{ __('message.driver') }}</th>
                                <th>{{ __('message.service') }}</th>
                                <th>{{ __('message.assign') }}</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($drivers as $value)
                                <tr>
                                    <td>{{ $value->id ?? '-' }}</td>
                                    <td>{{ $value->display_name ?? '-' }}</td>
                                    <td>{{ optional($value->service)->name ?? '-' }}</td>
                                    <td>
                                        <a class="btn btn-sm assign-btn btn-outline-primary" data-id="{{ $value->id }}">{{ __('message.assign_driver') }}</a>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                    {!! html()->hidden('driver_id')->id('driver_id_input') !!}
                </div>
            </div>

            <div class="modal-footer">
                <button type="button" class="btn btn-secondary border-radius-10" data-bs-dismiss="modal">
                    {{ __('message.close') }}
                </button>
                <button type="submit" class="btn btn-primary border-radius-10" id="btn_submit">
                    {{ __('message.save') }}
                </button>
            </div>
        </div>
    </div>

    {!! html()->form()->close() !!}
</div>

<script>
    $(document).ready(function () {
        $(document).on('click', '.assign-btn', function () {
            var driverId = $(this).data('id');
            $('#driver_id_input').val(driverId);
            $('#assign_driver_form').submit();
        });
        

        $('#basic-table').DataTable({
            "dom": '<"row align-items-center"<"col-md-2"><"col-md-6"B><"col-md-4"f>>' +
                   '<"table-responsive my-3" rt>' +
                   '<"d-flex" <"flex-grow-1" l><"p-2" i><"mt-4" p>><"clear">',
            "order": [[0, "desc"]]
        });
    });
</script>
<x-master-layout :assets="$assets ?? []">
    <div class="row">
        <div class="col-lg-12">
            <div class="card">
                <div class="container my-5">
                    <div class="row justify-content-center">
                        <div class="col-lg-12">
                            <div class="card shadow rounded">
                                <div class="card-header d-flex justify-content-between align-items-center text-white">
                                    <h5 class="mb-0">{{ __('message.import_airport_data')}}</h5>
                                    <a href="{{ route('airport.index') }}" class="btn btn-primary btn-sm">
                                        <i class="fa fa-angle-double-left"></i> {{ __('message.back') }}
                                    </a>
                                </div>
                                <div class="card-body">
                                    <form method="POST" action="{{ route('import.airportdata') }}" enctype="multipart/form-data">
                                        @csrf
                                        <div class="form-group text-center">
                                            <label for="fileInput" class="w-100">
                                                <div class="upload-box border border-dashed rounded p-4 text-center"
                                                    style="transition: background 0.3s;">
                                                    <i class="fa fa-cloud-upload fa-2x text-primary mb-2"></i>
                                                    <p class="mb-1">{{ __('message.browser_file') }}</p>
                                                    <small class="text-muted">{{ __('message.accepted_files') ?? '.csv, .xls, .xlsx' }}</small>
                                                    <input type="file" name="airport_data" id="fileInput" class="d-none"
                                                        accept=".csv, .xls, .xlsx, application/vnd.ms-excel, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                                                        required onchange="showFileName(this)">
                                                </div>
                                            </label>
                                            <div class="mt-2 text-muted" id="fileName">{{ __('message.no_file') }}</div>
                                        </div>

                                        <div class="text-center mt-4">
                                            <button type="submit" class="btn btn-success px-4" onclick="this.disabled=true; this.form.submit();">
                                                <i class="fa fa-upload"></i> {{ __('message.import') }}
                                            </button>
                                        </div>
                                    </form>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <script>
        function showFileName(input) {
            const fileName = document.getElementById('fileName');
            if (input.files.length > 0) {
                fileName.textContent = input.files[0].name;
            } else {
                fileName.textContent = '{{ __("message.no_file") }}';
            }
        }
    </script>
</x-master-layout>

<x-master-layout>
    <div class="container-fluid">
        <div class="row">
            <div class="col-lg-12">
                <div class="card border-radius-20">
                    <div class="card-header d-flex justify-content-between border-bottom-0"  style="border-top-left-radius: 20px; border-top-right-radius: 20px;">
                        <div class="header-title">
                            <h4 class="card-title">{{ $pageTitle ?? __('message.list') }}</h5>
                        </div>
                        <a href="{{ route('client-testimonials.create') }}"class="float-right btn btn-md border-radius-10 btn-primary loadRemoteModel">{{ __('message.add_form_title', ['form' => __('message.client_testimonials')]) }}</a>
                    </div>
                </div>
            </div>
            <div class="col-lg-12">
                <div class="card border-radius-20">
                    <div class="card-body">
                        {{ html()->form('POST',route('frontend.website.information.update', 'client_testimonials'))->attribute('enctype','multipart/form-data')->attribute('data-toggle','validator')->open() }}
                            <div class="row">
                                @foreach($client_testimonials as $key => $value)
                                    @if( in_array( $key, ['title', 'subtitle'] ))
                                        <div class="col-md-6 form-group">
                                            {{ html()->label( __('message.'.$key),$key)->class('form-control-label') }}
                                            {{ html()->text($key, $value ?? null)->placeholder(__('message.'.$key))->class('form-control') }}
                                        </div>
                                    @endif
                                @endforeach
                            </div>
                            <hr>
                            <div class="col-md-12 mt-1 mb-4">
                                <button class="btn border-radius-10 btn-primary float-md-right" id="saveButton">{{ __('message.save') }}</button>
                            </div>
                        {{ html()->form()->close() }}
                    </div>
                    @if(count($data) > 0)
                        @include('client_testimonials.list')
                    @endif
                    <br>
                </div>
            </div>
        </div>
    </div>
</x-master-layout>

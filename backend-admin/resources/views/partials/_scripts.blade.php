<!-- Backend Bundle JavaScript -->
<script src="{{ asset('js/backend-bundle.min.js') }}"></script>

<script src="{{ asset('js/raphael-min.js') }}"></script>

<script src="{{ asset('js/morris.js') }}"></script>
<script src="{{ asset('vendor/tinymce/js/tinymce/tinymce.min.js') }}"></script>
<script src="{{ asset('vendor/confirmJS/jquery-confirm.min.js') }}"></script>
<script src="{{ asset('js/jquery.validate.min.js') }}"></script>
<script>
    // Text Editor code
      if (typeof(tinyMCE) != "undefined") {
         // tinymceEditor()
         function tinymceEditor(target, button, height = 200) {
            var rtl = $("html[lang=ar]").attr('dir');
            tinymce.init({
               selector: target || '.textarea',
               directionality : rtl,
               height: height,
               plugins: [ 'advlist', 'autolink', 'lists', 'link', 'image', 'charmap', 'preview', 'anchor', 'searchreplace', 'visualblocks', 'code', 'fullscreen', 'insertdatetime', 'media', 'table', 'help', 'wordcount' ],
               toolbar: 'undo redo | blocks | bold italic backcolor | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | removeformat | help',
               content_style: 'body { font-family:Helvetica,Arial,sans-serif; font-size:16px }',
               automatic_uploads: false,
               /*file_picker_types: 'image',
               file_picker_callback: function(cb, value, meta) {
                  var input = document.createElement('input');
                  input.setAttribute('type', 'file');
                  input.setAttribute('accept', 'image/*');

                  input.onchange = function() {
                     var file = this.files[0];

                     var reader = new FileReader();
                     reader.onload = function() {
                        var id = 'blobid' + (new Date()).getTime();
                        var blobCache = tinymce.activeEditor.editorUpload.blobCache;
                        var base64 = reader.result.split(',')[1];
                        var blobInfo = blobCache.create(id, file, base64);
                        blobCache.add(blobInfo);

                        cb(blobInfo.blobUri(), { title: file.name });
                     };
                     reader.readAsDataURL(file);
                  };
                  input.click();
               }*/
            });
         }
      }
      function showCheckLimitData(id){
         var checkbox =  $('#'+id).is(":checked")
         if(checkbox == true){
            $('.'+id).removeClass('d-none')
         }else{
            $('.'+id).addClass('d-none')

         }
      }

      $('#submit-btn').on('click', function(e) {
         e.preventDefault();

             $('#button-loader').show();
             $('#submit-btn').prop('disabled', true);

             setTimeout(function() {
                 $('form').submit();
             }, 1000);
     });

      function formValidation(formId, rules, messages) {
         $(formId).validate({
            rules: rules,
            messages: messages,
            errorClass: "help-block error",
            highlight: function(element) {
               $(element).closest(".form-group.row").addClass("has-error");
            },
            unhighlight: function(element) {
               $(element).closest(".form-group.row").removeClass("has-error");
            },
            errorPlacement: function(error, element) {
               if (element.hasClass('select2js')) {
                  error.insertAfter(element.next('.select2-container'));
               } else {
                  error.insertAfter(element);
               }
            }
         });
         $('.select2js').on('change', function() {
            $(this).valid();
         });
     }
</script>
@if(isset($assets) && in_array('map', $assets))
    <script src="https://maps.googleapis.com/maps/api/js?key={{env('GOOGLE_MAP_KEY')}}&libraries=marker,drawing,geometry"></script>
    <script src="https://unpkg.com/@googlemaps/markerclusterer/dist/index.min.js"></script>
@endif

@if(isset($assets) && in_array('map_place', $assets))
   <script src="https://maps.googleapis.com/maps/api/js?key={{env('GOOGLE_MAP_KEY')}}&libraries=places" defer></script>
@endif

@yield('bottom_script')

<!-- Masonary Gallery Javascript -->
<script src="{{ asset('js/masonry.pkgd.min.js') }}"></script>
<script src="{{ asset('js/imagesloaded.pkgd.min.js') }}"></script>

<!-- Vectoe Map JavaScript -->
<script src="{{ asset('js/vector-map-custom.js') }}"></script>

<!-- Chart Custom JavaScript -->
<script src="{{ asset('js/customizer.js') }}"></script>

<!-- Chart Custom JavaScript -->
<script src="{{ asset('js/chart-custom.js') }}"></script>

<!-- slider JavaScript -->
<script src="{{ asset('js/slider.js') }}"></script>

<!-- Emoji picker -->
<script type="module" src="{{ asset('vendor/emoji-picker-element/index.js') }}"></script>

@if(isset($assets) && (in_array('datatable',$assets)))
<!-- <script src="{{ asset('vendor/datatables/js/jquery.dataTables.min.js') }}"></script> -->
<!-- <script src="{{ asset('vendor/datatables/js/dataTables.bootstrap4.min.js') }}"></script> -->
<!-- <script src="{{ asset('vendor/datatables/js/dataTables.buttons.min.js') }}"></script> -->
<!-- <script src="{{ asset('vendor/datatables/js/buttons.bootstrap4.min.js') }}"></script> -->
<script src="{{ asset('vendor/datatables/buttons.server-side.js') }}"></script>
<!-- <script src="{{ asset('vendor/datatables/js/dataTables.select.min.js') }}"></script> -->
@endif

<!-- app JavaScript -->
@if(isset($assets) && in_array('phone', $assets))
    <script src="{{ asset('vendor/intlTelInput/js/intlTelInput-jquery.min.js') }}"></script>
    <script src="{{ asset('vendor/intlTelInput/js/intlTelInput.min.js') }}"></script>
@endif

<script src="{{ asset('js/app.js') }}" defer></script>
<script src="{{ asset('js/sweetalert.min.js')}}"></script>
@include('helper.app_message')

<script>
   $(document).ready(function() {
       // mm sidebar search script
       if (!$('#no-results').length) {
         $('.mm-sidebar-menu').append(`
               <div id="no-results" style="display: none; text-align: center; padding: 1rem;">
                  <img src="{{ asset('images/error/errors.png') }}" alt="No results found" style="max-width: 100%;">
                  <p style="color: #999; margin-top: 10px;">{{ __('message.no_menu_item_fount')}}</p>
               </div>
         `);
      }

       $('.search-input').on('keyup', function () {
           var value = $(this).val().toLowerCase().trim();
           var hasVisibleItem = false;

           $('#mm-sidebar-toggle li').filter(function () {
               var itemText = $(this).text().toLowerCase();
               var match = itemText.indexOf(value) > -1;
               $(this).toggle(match);
           });

           $('#mm-sidebar-toggle li:has(h6)').each(function () {
               var nextItems = $(this).nextUntil('li:has(h6)');
               var hasVisible = nextItems.filter(':visible').length > 0;
               $(this).toggle(hasVisible);
               if (hasVisible) hasVisibleItem = true;
           });

           $('#no-results').toggle(!hasVisibleItem);

       });

       var root = document.documentElement;
       var siteColor = getComputedStyle(root).getPropertyValue('--site-color').trim();

       var hoverColor = lightenColor(siteColor, 20);
       root.style.setProperty('--site-hover-color', hoverColor);

       function lightenColor(color, percent) {
           var num = parseInt(color.slice(1), 16),
               amt = Math.round(2.55 * percent),
               R = (num >> 16) + amt,
               G = (num >> 8 & 0x00FF) + amt,
               B = (num & 0x0000FF) + amt;

           return `#${(0x1000000 + (R<255?R<1?0:R:255)*0x10000 + (G<255?G<1?0:G:255)*0x100 + (B<255?B<1?0:B:255)).toString(16).slice(1)}`;
       }
   });

   function getFormatPrice(price) {
      const currency_symbol = "{{ currencyArray(SettingData('CURRENCY', 'CURRENCY_CODE') ?? 'USD')['symbol'] ?? '$' }}";
      const currency_position = "{{ SettingData('CURRENCY', 'CURRENCY_POSITION') ?? 'left' }}";

      if (price === null || price === undefined) {
            price = 0;
      }

      if (typeof price === 'string') {
         const numeric = parseFloat(price);
         if (!isNaN(numeric)) {
            price = numeric;
         } else {
            return price;
         }
      }

      price = parseFloat(price).toFixed(2);

      if (currency_position === 'left') {
         return currency_symbol + price;
      } else {
         return price + currency_symbol;
      }
   }
</script>

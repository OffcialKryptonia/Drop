<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;

class DriverDocumentRequest extends FormRequest
{
    public function authorize()
    {
        return true;
    }

    public function rules()
    {
          $driver_id = auth()->user()->hasRole('driver') ? auth()->id() : $this->driver_id;
            return [
                'driver_document' => 'file|mimes:jpeg,jpg,png,pdf,doc,docx',
            ];
    }

    public function messages()
    {
        return [
            'driver_document' => 'Document file is required.',
            'driver_document.mimes'    => 'Only jpeg, jpg, png, pdf, doc, and docx files are allowed.',
        ];
    }

    protected function failedValidation(Validator $validator)
    {
        $data = [
            'status' => false,
            'message' => $validator->errors()->first(),
            'all_message' =>  $validator->errors()
        ];

        // API response
        if (request()->is('api/*')) {
            throw new HttpResponseException(response()->json($data, 400));
        }

        // AJAX response
        if ($this->ajax()) {
            throw new HttpResponseException(response()->json($data, 422));
        }

        // Normal web response
        throw new HttpResponseException(
            redirect()->back()->withInput()->with('errors', $validator->errors())
        );
    }
}

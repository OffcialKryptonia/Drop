<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;

class PushNotificationRequest extends FormRequest
{
    public function authorize()
    {
        return true;
    }

    public function rules()
    {
        return [
            'notification_image' => 'nullable|image|mimes:jpg,jpeg,png,gif',
        ];
    }

    public function messages()
    {
        return [
            'notification_image.mimes'    => __('message.invalid_file_type'),
        ];
    }

    protected function failedValidation(Validator $validator)
    {
        $data = [
            'status'      => false,
            'message'     => $validator->errors()->first(),
            'all_message' => $validator->errors()
        ];

        if (request()->is('api/*')) {
            throw new HttpResponseException(response()->json($data, 422));
        }

        if ($this->ajax()) {
            throw new HttpResponseException(response()->json($data, 422));
        }

        throw new HttpResponseException(
            redirect()->back()->withInput()->with('errors', $validator->errors())
        );
    }
}

<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;


class RiderRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     *
     * @return bool
     */
    public function authorize()
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array
     */
    public function rules()
    {
        $method = strtolower($this->method());
        $user_id = $this->route()->rider;

        $rules = [];
        switch ($method) {
            case 'post':
                $rules = [
                    'first_name'=>'required|string',
                    'last_name'=>'required|string',
                    'username' => 'required|unique:users,username',
                    'password' => 'required|min:8',
                    'email' => 'required|email|unique:users',
                    'contact_number' => 'max:20|unique:users,contact_number',
                    'profile_image'   => 'nullable|image|mimes:png,jpg,jpeg,gif',
                ];
                break;
            case 'patch':
                $rules = [
                    'first_name'=>'required|string',
                    'last_name'=>'required|string',
                    'username'  => 'required|unique:users,username,'.$user_id,
                    'email'     => 'required|email|unique:users,email,'.$user_id,
                    'contact_number' => 'max:20|unique:users,contact_number,'.$user_id,
                    'profile_image'   => 'nullable|image|mimes:png,jpg,jpeg,gif',
                ];
                break;
        }

        return $rules;
    }

    public function messages()
    {
        return [
            'userProfile.dob.*'  =>'DOB is required.',
            'profile_image.image' => 'Profile image must be an image file.',
            'profile_image.mimes' => 'Only PNG, JPG, JPEG, and GIF image formats are allowed.',
        ];
    }

     /**
     * @param Validator $validator
     */
    protected function failedValidation(Validator $validator) {
        $data = [
            'status' => true,
            'message' => $validator->errors()->first(),
            'all_message' =>  $validator->errors()
        ];

        if ( request()->is('api*')){
           throw new HttpResponseException( response()->json($data,422) );
        }

        if ($this->ajax()) {
            throw new HttpResponseException(response()->json($data,422));
        } else {
            throw new HttpResponseException(redirect()->back()->withInput()->with('errors', $validator->errors()));
        }
    }
}

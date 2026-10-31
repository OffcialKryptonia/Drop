<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Http\Exceptions\HttpResponseException;


class UserRequest extends FormRequest
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

        $rules = [];
        if(request()->is('api*')) {
            $user_id = auth()->user()->id ?? request()->id;
            $rules = [
                'username' => 'required|unique:users,username,'.$user_id,
                'email' => 'required|max:191|email|unique:users,email,'.$user_id,
                'phone_number' => 'nullable|max:20|unique:users,phone_number,'.$user_id,
                'profile_image' => 'nullable|image|mimes:jpg,jpeg,png,gif',
            ];
        } else {

            $method = strtolower($this->method());
            $routeUser = $this->route('sub_admin');
            if($routeUser){
                $user_id = is_object($routeUser) ? $routeUser->id : $routeUser;
            }else{
                $user_id = $this->id;
            }
            switch ($method) {
                case 'post':
                    $rules = [
                        'username' => 'required|unique:users,username,'.$user_id,
                        'email' => 'required|max:191|email|unique:users,email,'.$user_id,
                        'phone_number' => 'nullable|max:20|unique:users,phone_number,'.$user_id,
                        'profile_image' => 'nullable|image|mimes:jpg,jpeg,png,gif',
                    ];
                break;


                case 'patch':
                    $rules = [
                        'username' => 'required|unique:users,username,'.$user_id,
                        'email' => 'required|max:191|email|unique:users,email,'.$user_id,
                        'phone_number' => 'nullable|max:20|unique:users,phone_number,'.$user_id,
                        'profile_image' => 'nullable|image|mimes:jpg,jpeg,png,gif',
                    ];
                break;
            }
        }

        return $rules;
    }

    public function messages()
    {
        return [
         ];
    }

     /**
     * @param Validator $validator
     */
    protected function failedValidation(Validator $validator){
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

<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\LanguageVersionDetail;
use App\Http\Resources\LanguageTableResource;
use App\Models\LanguageList;

class LanguageTableController extends Controller
{
    public function getList(Request $request)
    {
        $is_allow_deliveryman = SettingData('allow_deliveryman', 'allow_deliveryman') ? true : false;
        $version_data = LanguageVersionDetail::where('version_no', request('version_no'))->first();

        $rider_version = [
            'android_force_update'  => SettingData('RIDER VERSION', 'RIDER VERSION_ANDROID_FORCE_UPDATE'),
            'android_version_code'  => SettingData('RIDER VERSION', 'RIDER VERSION_ANDROID_VERSION_CODE'),
            'appstore_url'          => SettingData('RIDER VERSION', 'RIDER VERSION_APPSTORE_URL'),
            'ios_force_update'      => SettingData('RIDER VERSION', 'RIDER VERSION_IOS_FORCE_UPDATE'),
            'ios_version'           => SettingData('RIDER VERSION', 'RIDER VERSION_IOS_VERSION'),
            'playstore_url'         => SettingData('RIDER VERSION', 'RIDER VERSION_PLAYSTORE_URL'),
        ];

        $driver_version = [
            'android_force_update'  => SettingData('DRIVER VERSION', 'DRIVER VERSION_ANDROID_FORCE_UPDATE'),
            'android_version_code'  => SettingData('DRIVER VERSION', 'DRIVER VERSION_ANDROID_VERSION_CODE'),
            'appstore_url'          => SettingData('DRIVER VERSION', 'DRIVER VERSION_APPSTORE_URL'),
            'ios_force_update'      => SettingData('DRIVER VERSION', 'DRIVER VERSION_IOS_FORCE_UPDATE'),
            'ios_version'           => SettingData('DRIVER VERSION', 'DRIVER VERSION_IOS_VERSION'),
            'playstore_url'         => SettingData('DRIVER VERSION', 'DRIVER VERSION_PLAYSTORE_URL'),
        ];

        $crisp_chat_data = [
            'crisp_chat_website_id' => SettingData('CRISP_CHAT_CONFIGURATION', 'CRISP_CHAT_CONFIGURATION_WEBSITE_ID') ?? null,
            'is_crisp_chat_enabled' => SettingData('CRISP_CHAT_CONFIGURATION', 'CRISP_CHAT_CONFIGURATION_ENABLE/DISABLE') ? true : false,
        ];
        if (isset($version_data) && !empty($version_data)) {
            return json_custom_response([
                'status' => false,
                'data' => [],
                'rider_version' => $rider_version,
                'driver_version' => $driver_version
            ]);
        }


        $language_content = LanguageList::query()->where('status', '1')->orderBy('id', 'asc')->get();
        $language_version = LanguageVersionDetail::find(1);
        $items = LanguageTableResource::collection($language_content);

        $response = [
            'status' => true,
            'version_code' => $language_version->version_no,
            'default_language_id' => $language_version->default_language_id,
            'data' => $items,
            'allow_deliveryman' => $is_allow_deliveryman,
            'rider_version' => $rider_version,
            'driver_version' => $driver_version,
            'crisp_chat_data' => $crisp_chat_data,
        ];

        return json_custom_response($response);
    }

}

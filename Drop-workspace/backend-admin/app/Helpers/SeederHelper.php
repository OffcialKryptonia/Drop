<?php

namespace App\Helpers;

use App\Models\DefaultKeyword;
use App\Models\LanguageList;
use App\Models\LanguageWithKeyword;
use App\Models\Permission;
use App\Models\Role;
use App\Models\Screen;

class SeederHelper
{

    public static function seedAppLanguageSetting(array $data)
    {
        foreach ($data as $screen) {
            $screen_record = Screen::where('screenID', $screen['screenID'])->first();
            if ( empty($screen_record) ) {
                $screen_record = Screen::create([
                    'screenId'   => $screen['screenID'],
                    'screenName' => $screen['ScreenName']
                ]);
            }

            if ( !empty($screen['keyword_data']) ) {
                foreach ($screen['keyword_data'] as $keyword_data) {
                    $check_default_keyword = DefaultKeyword::where('keyword_id', $keyword_data['keyword_id'])->first();
                    if ( empty($check_default_keyword) ) {
                        $default_keyword = DefaultKeyword::create([
                            'screen_id' => $screen_record['screenId'],
                            'keyword_id' => $keyword_data['keyword_id'],
                            'keyword_name' => $keyword_data['keyword_name'],
                            'keyword_value' => $keyword_data['keyword_value']
                        ]);

                        $language_list = LanguageList::get();
                        if ( count($language_list) > 0 ) {
                            foreach ($language_list as $value) {
                                $language_with_data = [
                                    'id' => null,
                                    'language_id' => $value->id,
                                    'keyword_id' => $default_keyword->keyword_id,
                                    'screen_id' => $default_keyword->screen_id,
                                    'keyword_value' => $default_keyword->keyword_value,
                                ];
                                LanguageWithKeyword::create($language_with_data);
                            }
                        }
                    }
                }
            }
        }
    }

    public static function seedPermissions(array $permissions, $parent_id = null)
    {
        foreach ($permissions as $permission) {

            $parent = Permission::firstOrCreate(
                ['name' => $permission['name']],
                ['parent_id' => null]
            );

            foreach ($permission['sub_permission'] as $sub) {
                Permission::firstOrCreate([
                    'name' => $sub,
                    'parent_id' => $parent->id,
                ]);
            }
        }
    }

    public static function seedRoles(array $roles)
    {
        foreach ($roles as $value) {
            $permissionNames = $value['permissions'] ?? [];
            unset($value['permissions']);

            // Find existing role or skip if not found
            $role = Role::where('name', $value['name'])->first();

            // If role doesn't exist, create it
            if (!$role) {
                $role = Role::create([
                    'name'      => $value['name'],
                    'status'    => $value['status'] ?? 1,
                ]);
            }

            // Filter only existing permissions by name
            $existingPermissions = Permission::whereIn('name', $permissionNames)->pluck('name')->toArray();

            // Assign only existing permissions (overwrite previous ones)
            $role->givePermissionTo($existingPermissions);
        }
    }

}

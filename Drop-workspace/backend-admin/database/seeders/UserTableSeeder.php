<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use App\Models\User;

class UserTableSeeder extends Seeder
{

    /**
     * Auto generated seed file
     *
     * @return void
     */
    public function run()
    {        
        $users = [
            [
                'id' => NULL,
                'first_name' => 'Admin',
                'last_name' => 'Admin',
                'username' => 'admin',
                'contact_number' => '+919876543210',
                'address' => NULL,
                'email' => 'admin@admin.com',
                'password' => bcrypt('12345678'),
                'email_verified_at' => NULL,
                'user_type' => 'admin',
                'player_id' => NULL,
                'remember_token' => NULL,
                'last_notification_seen' => NULL,
                'status' => 'active',
                'timezone' => 'UTC',
                'display_name' => 'Admin',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
                'updated_at' => NULL,    
            ],
        ];

        foreach ($users as $key => $value) {
            $user = User::create($value);
            $user->assignRole($value['user_type']);
        }
        
    }
}
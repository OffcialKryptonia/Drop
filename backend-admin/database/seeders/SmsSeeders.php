<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Carbon\Carbon;

class SmsSeeders extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */ 
    public function run()
    {
        // Ensure foreign key record exists
        \DB::table('s_m_s_settings')->updateOrInsert(
            ['id' => 1],
            [
                'title' => 'Twilio', 
                'type' => 'twilio', 
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ]
        );

        // \DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        \DB::table('s_m_s_templat_rides')->delete();
        // \DB::statement('SET FOREIGN_KEY_CHECKS=1;');

        \DB::table('s_m_s_templat_rides')->insert(array (
            0 =>
            array (
                'id' => 1,
                'subject' => 'Drivers is Arrived',
                'sms_description' =>'<p>Hi [user name],</p>
                    <p>Your OTP is [OTP Code].</p>
                    <p>Your driver has arrived at the pickup location. Please proceed to meet them.</p>
                    <p>Please do not share this OTP with anyone.</p>
                    <p>We hope you have a pleasant ride!</p>',

                'sms_id' => 1,
                'ride_status' => 'arrived',
                'type' => 'driver_is_arrived',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
        ));
    }
}

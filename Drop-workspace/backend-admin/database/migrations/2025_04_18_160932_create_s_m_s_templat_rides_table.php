<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('s_m_s_templat_rides', function (Blueprint $table) {
            $table->id();
            $table->string('subject')->nullable();
            $table->longText('sms_description')->nullable();
            $table->unsignedBigInteger('sms_id')->nullable();
            $table->string('type')->nullable();
            $table->string('ride_status')->nullable();
            $table->timestamps();
            $table->foreign('sms_id')->references('id')->on('s_m_s_settings')->onDelete('cascade');
        });

        DB::table('s_m_s_settings')->updateOrInsert(
            ['id' => 1],
            [
                'title' => 'Twilio', 
                'type' => 'twilio', 
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ]
        );

        DB::table('s_m_s_templat_rides')->insert(array (
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

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('s_m_s_templat_rides',function(Blueprint $table){
            $table->dropForeign(['sms_id']);
        });
        Schema::dropIfExists('s_m_s_templat_rides');
    }
};

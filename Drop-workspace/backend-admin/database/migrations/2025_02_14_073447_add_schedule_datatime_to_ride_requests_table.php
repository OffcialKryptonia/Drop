<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class AddScheduleDatatimeToRideRequestsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->dateTime('schedule_datetime')->nullable()->after('is_schedule');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            //
        });
    }
}

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('cancellations', function (Blueprint $table) {
            $table->id();
            $table->string('title')->nullable();
            $table->string('type')->nullable();
            $table->timestamps();
        });
        
         DB::table('cancellations')->insert(array(
            0 =>
            array(
                'id' => null,
                'title' => 'Rider not at pickup location',
                'type' => 'driver',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            1 =>
            array(
                'id' => null,
                'title' => 'Rider is unresponsive to calls/messages',
                'type' => 'driver',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            2 =>
            array(
                'id' => null,
                'title' => 'Trip is too far from my current location',
                'type' => 'driver',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            3 =>
            array(
                'id' => null,
                'title' => 'Vehicle issue',
                'type' => 'driver',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            4 =>
            array(
                'id' => null,
                'title' => 'Rider asked to cancel',
                'type' => 'driver',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            5 =>
            array(
                'id' => null,
                'title' => 'Emergency or personal reason',
                'type' => 'driver',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            6 =>
            array(
                'id' => null,
                'title' => 'Destination not suitable (e.g., long-distance, no return ride)',
                'type' => 'driver',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            7 =>
            array(
                'id' => null,
                'title' => 'Duplicate or fake booking',
                'type' => 'driver',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            8 =>
            array(
                'id' => null,
                'title' => 'Driver is taking too long to arrive',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            9 =>
            array(
                'id' => null,
                'title' => 'Driver is not moving on the map',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            10 =>
            array(
                'id' => null,
                'title' => 'Changed my mind',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            11 =>
            array(
                'id' => null,
                'title' => 'Found an alternative transport',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            12 =>
            array(
                'id' => null,
                'title' => 'Entered wrong pickup or drop location',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            13 =>
            array(
                'id' => null,
                'title' => 'Fare seems too high',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            14 =>
            array(
                'id' => null,
                'title' => 'Booking was made by mistake',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            15 =>
            array(
                'id' => null,
                'title' => 'Personal emergency',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            16 =>
            array(
                'id' => null,
                'title' => 'Driver asked to cancel',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            17 =>
            array(
                'id' => null,
                'title' => 'Driver behavior was inappropriate',
                'type' => 'rider',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
        ));
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('cancellations');
    }
};

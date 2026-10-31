<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->string('trip_type')->comment('regular, airport_pickup, airport_drop, zone_wise, zone_to_airport, airport_to_zone')->default('regular')->nullable();
            $table->string('flight_number')->nullable();
            $table->string('pickup_point')->nullable();
            $table->timestamp('preferred_pickup_time')->nullable();
            $table->timestamp('preferred_dropoff_time')->nullable();
            $table->unsignedBigInteger('airport_pickup')->nullable();
            $table->unsignedBigInteger('airport_dropoff')->nullable();
            $table->text('internal_note')->nullable();
            $table->text('driver_note')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            //
        });
    }
};

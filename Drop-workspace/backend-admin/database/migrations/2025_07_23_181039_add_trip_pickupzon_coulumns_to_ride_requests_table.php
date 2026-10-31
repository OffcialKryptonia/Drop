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
            $table->unsignedBigInteger('zone_pickup')->nullable();
            $table->unsignedBigInteger('zone_dropoff')->nullable();
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

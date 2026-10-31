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
            $table->double('admin_commission')->nullable()->default('0');
            $table->double('distance_travelled')->nullable();
            $table->double('completed_trip_duration')->nullable();
            $table->double('time_price')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->dropColumn('admin_commission');
            $table->dropColumn('distance_travelled');
            $table->dropColumn('completed_trip_duration');
            $table->dropColumn('time_price');
        });
    }
};

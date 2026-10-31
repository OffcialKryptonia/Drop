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
            $table->string('car_model')->nullable();
            $table->string('car_color')->nullable();
            $table->string('car_plate_number')->nullable();
            $table->string('car_production_year')->nullable();
            $table->string('currency_symbol')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->dropColumn('car_model');
            $table->dropColumn('car_color');
            $table->dropColumn('car_plate_number');
            $table->dropColumn('car_production_year');
            $table->dropColumn('currency_symbol');
        });
    }
};

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
            $table->double('surcharge')->nullable()->after('cancelled_driver_ids');
            $table->double('discount')->nullable()->after('surcharge');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->dropColumn(['surcharge','discount','reason']);
        });
    }
};

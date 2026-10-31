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
            $table->string('sms_type')->nullable()->after('is_ride_for_other');

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

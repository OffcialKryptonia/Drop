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
        // 1. Users Table
        Schema::table('users', function (Blueprint $table) {
            $table->index('user_type');
            $table->index('status');
            $table->index('is_online');
            $table->index('is_available');
            $table->index('last_location_update_at');
            $table->index('player_id');
        });

        // 2. Ride Requests Table
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->index('status');
            $table->index('rider_id');
            $table->index('driver_id');
            $table->index('is_schedule');
        });

        // 3. Ride Request Histories Table
        Schema::table('ride_request_histories', function (Blueprint $table) {
            $table->index('ride_request_id');
        });

        // 4. Financial Tables
        Schema::table('payments', function (Blueprint $table) {
            $table->index('ride_request_id');
            $table->index('trx_id');
        });

        Schema::table('wallet_histories', function (Blueprint $table) {
            $table->index('user_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['user_type', 'status', 'is_online', 'is_available', 'last_location_update_at', 'player_id']);
        });

        Schema::table('ride_requests', function (Blueprint $table) {
            $table->dropIndex(['status', 'rider_id', 'driver_id', 'is_scheduled']);
        });

        Schema::table('ride_request_histories', function (Blueprint $table) {
            $table->dropIndex(['ride_request_id']);
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->dropIndex(['ride_request_id', 'trx_id']);
        });

        Schema::table('wallet_histories', function (Blueprint $table) {
            $table->dropIndex(['user_id']);
        });
    }
};

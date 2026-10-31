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
       Schema::create('admin_login_history', function (Blueprint $table) {
        $table->id();
        $table->unsignedBigInteger('user_id')->nullable();
        $table->string('ip_address')->nullable();
        $table->string('city')->nullable();
        $table->string('region')->nullable();
        $table->string('country')->nullable();
        $table->string('lat_long')->nullable();
        $table->string('org')->nullable();
        $table->string('postal_code')->nullable();
        $table->string('timezone')->nullable();
        $table->string('browser')->nullable();
        $table->string('browser_version')->nullable();
        $table->string('platform')->nullable();
        $table->string('platform_version')->nullable();
        $table->string('device')->nullable();
        $table->boolean('is_mobile')->default(0);
        $table->boolean('is_desktop')->default(0);
        $table->boolean('is_tablet')->default(0);
        $table->timestamps();
    });

    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('admin_login_history');
    }
};

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
        Schema::create('coin_wallets', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('ride_id')->nullable();
            $table->unsignedBigInteger('user_id');
            $table->dateTime('scratch_time')->nullable();
            $table->enum('type', ['credit', 'debit'])->nullable();
            $table->integer('coins')->default(0);
            $table->timestamps();
            $table->foreign('ride_id')->references('id')->on('ride_requests')->onDelete('set null');
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('coin_wallets');
    }
};

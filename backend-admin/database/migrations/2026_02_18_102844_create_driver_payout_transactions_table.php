<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('driver_payout_transactions', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('driver_id');
            $table->unsignedBigInteger('payout_report_id');
            $table->decimal('amount', 10, 2);
            $table->enum('method', ['bank', 'cash', 'wallet']);
            $table->string('reference_no')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();
            $table->foreign('driver_id')->references('id')->on('users')->onDelete('cascade');
            $table->foreign('payout_report_id')->references('id')->on('driver_payout_reports')->onDelete('cascade');
            $table->index(['driver_id', 'payout_report_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('driver_payout_transactions');
    }
};

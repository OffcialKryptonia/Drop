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
        Schema::table('payments', function (Blueprint $table) {
            $table->unsignedBigInteger('driver_id')->after('rider_id')->nullable();

            $table->tinyInteger('is_settled')
                ->default(0)
                ->comment('0 = false, 1 = true')
                ->after('updated_at');
            $table->integer('payout_report_id')->nullable()->after('is_settled');
            $table->foreign('driver_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {

            $table->dropColumn([
                'driver_id',
                'is_settled',
                'payout_report_id',
            ]);
        });
    }
};

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
             $table->integer('extra_charges_payment_method')->default(0)->after('extra_charges');
             $table->timestamp('extra_charges_payment_date')->nullable()->after('extra_charges_payment_method');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('ride_requests', function (Blueprint $table) {
            $table->dropColumn('extra_charges_payment_method');
            $table->dropColumn('extra_charges_payment_date');
        });
    }
};

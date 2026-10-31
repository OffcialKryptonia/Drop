<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wallet_histories', function (Blueprint $table) {
            $table->string('week_date')
                  ->nullable()
                  ->after('updated_at'); // Adds column at last
        });
    }

    public function down(): void
    {
        Schema::table('wallet_histories', function (Blueprint $table) {
            $table->dropColumn('week_date');
        });
    }
};

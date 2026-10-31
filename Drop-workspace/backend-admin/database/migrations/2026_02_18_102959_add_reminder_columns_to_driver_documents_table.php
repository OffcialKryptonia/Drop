<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('driver_documents', function (Blueprint $table) {
            $table->boolean('reminder_sent')
                ->default(false)
                ->after('is_verified');

            $table->timestamp('reminder_sent_at')
                ->nullable()
                ->after('reminder_sent');
        });
    }

    public function down(): void
    {
        Schema::table('driver_documents', function (Blueprint $table) {
            $table->dropColumn(['reminder_sent', 'reminder_sent_at']);
        });
    }
};

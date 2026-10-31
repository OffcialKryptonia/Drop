<?php

use App\Helpers\SeederHelper;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('apple_user_identifier')->nullable()->after('email');
        });

         SeederHelper::seedAppLanguageSetting(config('app-Language.SCREEN_DATA'));
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('apple_user_identifier');
        });
    }
};

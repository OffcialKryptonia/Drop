<?php

use App\Helpers\SeederHelper;
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
        Schema::table('users', function (Blueprint $table) {
            $table->integer('total_coins')->default(0)->after('apple_user_identifier');
        });

         SeederHelper::seedAppLanguageSetting(config('app-Language.SCREEN_DATA'));
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('total_coins');
        });
    }
};

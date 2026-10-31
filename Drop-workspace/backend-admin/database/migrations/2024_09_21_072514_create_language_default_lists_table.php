<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\File;
use App\Models\LanguageDefaultList;

class CreateLanguageDefaultListsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('language_default_lists', function (Blueprint $table) {
            $table->id();
            $table->string('languageName')->nullable();
            $table->string('languageCode')->nullable();
            $table->string('countryCode')->nullable();
            $table->timestamps();
        });

        $json = File::get(public_path('json/languagedefaultlist.json'));
        $data = json_decode($json, true);

        foreach ($data as $item) {
            LanguageDefaultList::create([
                'languageName' => $item['languageName'],
                'languageCode' => $item['languageCode'],
                'countryCode' => $item['countryCode'],
            ]);
        }
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('language_default_lists');
    }
}

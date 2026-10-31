<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateSupportChathistoriesTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('support_chathistories', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('support_id')->nullable();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->longText('message')->nullable();
            $table->dateTime('datetime')->nullable();
            $table->foreign('support_id')->references('id')->on('customer_supports')->onDelete('cascade');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('support_chathistories');
    }
}
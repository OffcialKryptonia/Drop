<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('faqs', function (Blueprint $table) {
            $table->string('type')->nullable()->after('answer');

        });

        DB::table('faqs')->insert([
            [
                'id' => NULL,
                'type' => 'rider',
                'question' => 'How can a rider book a ride?',
                'answer' => 'Open the app, select pickup and drop location, and tap on "Book Now".',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => NULL,
                'type' => 'rider',
                'question' => 'What payment methods are available?',
                'answer' => 'You can pay using cash, card, or wallet depending on availability.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => NULL,
                'type' => 'rider',
                'question' => 'Can I cancel a ride after booking?',
                'answer' => 'Yes, but cancellation charges may apply based on the timing.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => NULL,
                'type' => 'rider',
                'question' => 'What to do if the driver does not arrive?',
                'answer' => 'You can contact the driver or cancel and book another ride.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => NULL,
                'type' => 'rider',
                'question' => 'What if the driver behaves inappropriately?',
                'answer' => 'You can report the driver from the app or contact support.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => NULL,
                'type' => 'driver',
                'question' => 'How is the fare calculated?',
                'answer' => 'Fare is based on distance, time, and service type.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => NULL,
                'type' => 'driver',
                'question' => 'Why did my driver cancel the ride?',
                'answer' => 'Drivers may cancel due to distance, issues with the vehicle, or personal reasons.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => NULL,
                'type' => 'driver',
                'question' => 'How do I contact support?',
                'answer' => 'Go to Help section in the app and raise a ticket or call support.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => NULL,
                'type' => 'driver',
                'question' => 'What if I forgot an item in the car?',
                'answer' => 'Contact the driver from trip history or reach out to support.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => NULL,
                'type' => 'driver',
                'question' => 'Can I add multiple stops in one ride?',
                'answer' => 'Yes, you can add extra stops before booking.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
       Schema::dropIfExists('faqs');
    }
};
<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class ReasonFaqAdditionalSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
       // Cancellation reasons
        DB::table('cancellations')->insert([
            ['id' => 1, 'title' => 'Rider not at pickup location', 'type' => 'driver', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 2, 'title' => 'Rider is unresponsive to calls/messages', 'type' => 'driver', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 3, 'title' => 'Trip is too far from my current location', 'type' => 'driver', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 4, 'title' => 'Vehicle issue', 'type' => 'driver', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 5, 'title' => 'Rider asked to cancel', 'type' => 'driver', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 6, 'title' => 'Emergency or personal reason', 'type' => 'driver', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 7, 'title' => 'Destination not suitable (e.g., long-distance, no return ride)', 'type' => 'driver', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 8, 'title' => 'Duplicate or fake booking', 'type' => 'driver', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 9, 'title' => 'Driver is taking too long to arrive', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 10, 'title' => 'Driver is not moving on the map', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 11, 'title' => 'Changed my mind', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 12, 'title' => 'Found an alternative transport', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 13, 'title' => 'Entered wrong pickup or drop location', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 14, 'title' => 'Fare seems too high', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 15, 'title' => 'Booking was made by mistake', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 16, 'title' => 'Personal emergency', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 17, 'title' => 'Driver asked to cancel', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 18, 'title' => 'Driver behavior was inappropriate', 'type' => 'rider', 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
        ]);

        // Additional Fees
        DB::table('additional_fees')->insert([
            ['id' => 1, 'title' => 'Paid Parking', 'status' => 1, 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 2, 'title' => 'Fuel Charges', 'status' => 1, 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 3, 'title' => 'Waiting Charge', 'status' => 1, 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 4, 'title' => 'Other Charges', 'status' => 1, 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
            ['id' => 5, 'title' => 'Toll Tax Charges', 'status' => 1, 'created_at' => Carbon::now()->format('Y-m-d H:i:s')],
        ]);

        // FAQs
        DB::table('faqs')->insert([
            [
                'id' => 1,
                'type' => 'rider',
                'question' => 'How can a rider book a ride?',
                'answer' => 'Open the app, select pickup and drop location, and tap on "Book Now".',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => 2,
                'type' => 'rider',
                'question' => 'What payment methods are available?',
                'answer' => 'You can pay using cash, card, or wallet depending on availability.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => 3,
                'type' => 'rider',
                'question' => 'Can I cancel a ride after booking?',
                'answer' => 'Yes, but cancellation charges may apply based on the timing.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => 4,
                'type' => 'rider',
                'question' => 'What to do if the driver does not arrive?',
                'answer' => 'You can contact the driver or cancel and book another ride.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => 5,
                'type' => 'rider',
                'question' => 'What if the driver behaves inappropriately?',
                'answer' => 'You can report the driver from the app or contact support.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => 6,
                'type' => 'driver',
                'question' => 'How is the fare calculated?',
                'answer' => 'Fare is based on distance, time, and service type.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => 7,
                'type' => 'driver',
                'question' => 'Why did my driver cancel the ride?',
                'answer' => 'Drivers may cancel due to distance, issues with the vehicle, or personal reasons.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => 8,
                'type' => 'driver',
                'question' => 'How do I contact support?',
                'answer' => 'Go to Help section in the app and raise a ticket or call support.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => 9,
                'type' => 'driver',
                'question' => 'What if I forgot an item in the car?',
                'answer' => 'Contact the driver from trip history or reach out to support.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
            [
                'id' => 10,
                'type' => 'driver',
                'question' => 'Can I add multiple stops in one ride?',
                'answer' => 'Yes, you can add extra stops before booking.',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s')
            ],
        ]);
    }
}

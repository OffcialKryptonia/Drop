<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Carbon\Carbon;

class MailSeeders extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        \DB::table('mail_templates')->delete();

        \DB::table('mail_templates')->insert(array(
            0 =>
            array(
                'id' => 1,
                'subject' => 'New ride',
                'description' => '<p>Hi [user name],</p>
                    <p>Thank you for booking a ride with us! Your request has been received and is being processed.</p>
                    <p>We will update you once the status changes. Have a great day!</p>
                    <p>Best regards,</p>',
                'type' => 'new_ride_requested',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            1 =>
            array(
                'id' => 2,
                'subject' => 'Your ride has been accepted.',
                'description' => '<p>Dear [user name],</p>
                    <p>We are pleased to inform you that your ride request has been accepted! The current status is: [status].</p>
                    <p>We look forward to serving you. Thank you for choosing us!</p>
                    <p>Best regards,</p>',
                'type' => 'accepted',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            2 =>
            array(
                'id' => 3,
                'subject' => 'Driver placed bid on your ride.',
                'description' => '<p>Dear [user name],</p>
                    <p>We have successfully placed your bid for the ride. The current status is: [status].</p>
                    <p>We hope you have a smooth journey. Thank you for your trust in us!</p>
                    <p>Best regards,</p>',
                'type' => 'bid_placed',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            3 =>
            array(
                'id' => 4,
                'subject' => 'Rider accepted your bid.',
                'description' => '<p>Dear [user name],</p>
                    <p>Good news! Your bid for the ride has been accepted. Please get ready for your upcoming trip.</p>
                    <p>Thank you for choosing us!</p>
                    <p>Best regards,</p>',
                'type' => 'bid_accepted',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            4 =>
            array(
                'id' => 5,
                'subject' => 'rider rejected your bid.',
                'description' => '<p>Hi [user name],</p>
                    <p>We regret to inform you that your bid for the ride was not accepted. You may try placing another bid or contact support for assistance.</p>
                    <p>Thank you for understanding.</p>
                    <p>Best regards,</p>',
                'type' => 'bid_rejected',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            5 =>
            array(
                'id' => 6,
                'subject' => 'Driver is arriving soon.',
                'description' => '<p>Hi [user name],</p>
                    <p>Your ride is on its way! The driver will arrive shortly. Please be ready at the pickup location.</p>
                    <p>Thank you for choosing us!</p>
                    <p>Best regards,</p>',
                'type' => 'arriving',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            6 =>
            array(
                'id' => 7,
                'subject' => 'Driver is arrived.',
                'description' => '<p>Hello [user name],</p>
                    <p>Your driver has arrived at the pickup location. Please proceed to meet them.</p>
                    <p>We hope you have a pleasant ride!</p>
                    <p>Best regards,</p>',
                'type' => 'arrived',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            7 =>
            array(
                'id' => 8,
                'subject' => 'Your ride is in progress.',
                'description' => '<p>Hi [user name],</p>
                    <p>Your ride is currently in progress. Sit back and enjoy the journey!</p>
                    <p>Thank you for riding with us!</p>
                    <p>Best regards,</p>',
                'type' => 'in_progress',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            8 =>
            array(
                'id' => 9,
                'subject' => 'Your ride has been cancelled.',
                'description' => '<p>Hi [user name],</p>
                    <p>We regret to inform you that your ride has been cancelled. If you have any questions, please contact support.</p>
                    <p>Thank you for understanding.</p>
                    <p>Best regards,</p>',
                'type' => 'canceled',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            9 =>
            array(
                'id' => 10,
                'subject' => 'ride has been cancelled by driver',
                'description' => '<p>Hello [user name],</p>
                    <p>We regret to inform you that your ride has been cancelled by the driver. Please book another ride or contact support for assistance.</p>
                    <p>Thank you for your patience.</p>
                    <p>Best regards,</p>',
                'type' => 'driver_canceled',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            10 =>
            array(
                'id' => 11,
                'subject' => 'ride has been cancelled by rider',
                'description' => '<p>Hi [user name],</p>
                    <p>We have noted that you have cancelled your ride. If this was an error, please contact support to rebook your ride.</p>
                    <p>Thank you for choosing us!</p>
                    <p>Best regards,</p>',
                'type' => 'rider_canceled',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            11 =>
            array(
                'id' => 12,
                'subject' => 'ride has been completed',
                'description' => '<p>Hi [user name],</p>
                    <p>Your ride has been completed successfully. Thank you for choosing us!</p>
                    <p>Best regards,</p>',
                                    'type' => 'completed',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
            12 =>
            array(
                'id' => 13,
                'subject' => 'Payment Status',
                'description' => '<p>Hi [user name],</p>
                    <p>Your payment status for the ride is: [payment_status]. Please reach out to support if you have any questions.</p>
                    <p>Thank you for riding with us!</p>
                    <p>Best regards,</p>',
                'type' => 'payment_status_message',
                'created_at' => Carbon::now()->format('Y-m-d H:i:s'),
            ),
        ));
    }
}

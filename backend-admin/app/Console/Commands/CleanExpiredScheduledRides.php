<?php

namespace App\Console\Commands;

use App\Models\Notification;
use Illuminate\Console\Command;
use App\Models\RideRequest;
use Carbon\Carbon;


class CleanExpiredScheduledRides extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'ride:schedule-delete-rides';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Delete accepted scheduled rides with no action after 1 hour';

    /**
     * Execute the console command.
     */
    public function handle()
    {
       $nowUtc = now();

        $ridesToDelete = RideRequest::where('is_schedule', 1)
            ->whereIn('status', ['accepted', 'new_ride_requested'])
            ->where('schedule_datetime', '<=', $nowUtc->copy()->subHour())
            ->get();

        $count = $ridesToDelete->count();

        foreach ($ridesToDelete as $ride) {
            if($ride != '') {
                $search = "id".'":'.$ride->id;
                Notification::where('data','like',"%{$search}%")->delete();
                $history_data = [
                    'history_type'      => 'canceled',
                    'ride_request_id'   => $ride->id,
                    'ride_request'      => $ride,
                ];
                
                saveRideHistory($history_data);
                $document_name = 'ride_' . $ride->id;
                $collectionName = config('services.firestore.ride_collection');
                $firebaseData = app('firebase.firestore')->database()->collection($collectionName)->document($document_name);
                $firebaseData->delete();
                $ride->update([
                    'status' => 'canceled',
                    'cancelled_by' => 'auto',
                    'cancelled_at' => now(),
                ]);
            }
        }

        \Log::info("Cron: Deleted {$count} accepted scheduled rides with no action after 1 hour.");
        $this->info("Deleted {$count} ride(s).");
    }
}

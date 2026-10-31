<?php

namespace App\Console\Commands;

use App\Models\RideRequest;
use Carbon\Carbon;
use Illuminate\Console\Command;
use App\Traits\RideRequestTrait;

class FindScheduledRides extends Command
{
    protected $signature = 'rides:find-scheduled';
    protected $description = 'Find drivers for scheduled rides at the scheduled time';
    use RideRequestTrait;
    public function __construct()
    {
        parent::__construct();
    }

    public function handle()
    {
        $nowUtc = Carbon::now('UTC')->toDateTimeString();
        // \Log::info($nowUtc);
        $rides = RideRequest::where('is_schedule', 1)
            ->where('schedule_datetime', '<=', $nowUtc)
            ->where('status', 'new_ride_requested')
            ->get();

        foreach ($rides as $ride) {
            // $this->info("Finding driver for scheduled ride: {$ride->id}");
            if ($ride->ride_has_bid == 1) {
                $this->findDrivers($ride);
            } else {
                $this->acceptDeclinedRideRequest($ride);
            }
            // \Log::info("Processed ride {$ride->id} at scheduled time: " . now());

        }

        $this->info('Scheduled rides processed.');
    }
}

<?php

namespace App\Console\Commands;

use App\Models\RideRequest;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class OfflineInactiveDrivers extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:offline-inactive-drivers';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Command description';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $thresholdTime = Carbon::now()->subHours(1);

        $affectedRows = DB::table('users')
            ->where('user_type', 'driver')
            ->where('is_online', 1)
            ->where('is_available', 1)
            ->where(function ($q) use ($thresholdTime) {
                $q->where('last_actived_at', '<', $thresholdTime)
                ->orWhereNull('last_actived_at');
            })->update([ 'is_online' => 0 ]);

        Log::info('OfflineInactiveDrivers cron executed', [
            'affected_rows' => $affectedRows,
        ]);

        $this->info("Drivers set offline: {$affectedRows}");

        $rides = RideRequest::with('driver')->whereNotIn('status', ['canceled', 'completed'])->where('created_at', '<', now()->subHours(24))->get();

        foreach ($rides as $ride) {
            /** 1️⃣ Cancel ride */
            $ride->update([ 'status' => 'canceled' ,'cancel_by' => 'auto']);
            try {
                $collectionName = config('services.firestore.ride_collection', 'rides');
                app('firebase.firestore')
                    ->database()
                    ->collection($collectionName)
                    ->document('ride_' . $ride->id)
                    ->delete();
            } catch (\Throwable $e) {
                Log::error('Firebase delete failed', [
                    'ride_id' => $ride->id,
                    'error'   => $e->getMessage(),
                ]);
            }

            /** 3️⃣ Make driver available */
            if ($ride->driver) {
                $ride->driver->update([ 'is_available' => 1 ]);
            }

            $history_data = [
                'ride_request_id' => $ride->id,
                'history_type'    => 'canceled',
                'ride_request'    => $ride,
            ];
             saveRideHistory($history_data);
        }

        $this->info('Old ride requests cancelled successfully');
    }
}

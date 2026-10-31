<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

use App\Console\Commands\AssignDriverToRide;
use App\Console\Commands\CleanExpiredScheduledRides;
use App\Console\Commands\DatabaseBackup;
use App\Console\Commands\FindScheduledRides;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     *
     * @param  \Illuminate\Console\Scheduling\Schedule  $schedule
     * @return void
     */
    protected $command = [
        AssignDriverToRide::class,
        DatabaseBackup::class,
        FindScheduledRides::class,
        CleanExpiredScheduledRides::class,
    ];
    protected function schedule(Schedule $schedule)
    {
        $schedule->command('ride:schedule-delete-rides')->hourly();  //->cron('*/2 * * * *');
        $schedule->command('ride:assign-drivers-for-regular-rides')->everyMinute();

        $backup_type = appSettingData('get')->backup_type;
        switch ($backup_type) {
            case 'daily':
                $schedule->command('backup:database')->daily()->at('02:00');
                break;
            case 'weekly':
                $schedule->command('backup:database')->weekly()->sundays()->at('03:00');
                break;
            case 'monthly':
                $schedule->command('backup:database')->monthly()->at('04:00');
                break;
            default:
                // $schedule->command('backup:database')->everyMinute();
                break;
        }
        $schedule->command('rides:find-scheduled')->everyMinute();
        $schedule->command('app:offline-inactive-drivers')->hourly();
        $schedule->command('app:anonymize-inactive-users')->dailyAt('00:00');
        $schedule->command('app:generate-driver-payout-reports')->weeklyOn(0, '02:00'); // sunday at 2 AM
        $schedule->command('app:send-driver-payout-report-mail')->everyThirtyMinutes()->withoutOverlapping();

    }

    /**
     * Register the commands for the application.
     *
     * @return void
     */
    protected function commands()
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}

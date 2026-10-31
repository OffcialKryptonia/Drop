<?php

namespace App\Console\Commands;

use App\Models\Wallet;
use App\Models\WalletHistory;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

class GenerateDriverPayoutReports extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:generate-driver-payout-reports';

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
        $startDate = Carbon::now()->subWeek()->startOfWeek(); // Monday last week
        $endDate   = Carbon::now()->subWeek()->endOfWeek();   // Sunday last week

        $drivers = DB::table('payments')
            ->where('is_settled', 0)
            ->where('payment_type','wallet')
            ->whereNotNull('driver_id')
            ->select('driver_id')
            ->distinct()
            ->get();


        foreach ($drivers as $driver) {

            $earnings = DB::table('payments')
                ->where('driver_id', $driver->driver_id)
                ->where('is_settled', 0)
                ->get();
            if ($earnings->count() == 0) {
                continue;
            }

            $totalFare = $earnings->sum('total_amount');
            $totalCommission = $earnings->sum('admin_commission');
            $totalEarnings = $earnings->sum('driver_fee');
            $totalTips = $earnings->sum('driver_tips');
            $totalTrips = $earnings->count();
            $finalTotal = $totalEarnings + $totalTips;

            DB::beginTransaction();

            try {
                $reportId = DB::table('driver_payout_reports')->insertGetId([
                    'driver_id' => $driver->driver_id,
                    'week_start_date' => $startDate,
                    'week_end_date' => $endDate,
                    'total_trips' => $totalTrips,
                    'total_fare' => $totalFare,
                    'total_commission' => $totalCommission,
                    'driver_tips' => $totalTips,
                    // 'total_earnings' => $totalEarnings,
                    'payout_amount' => $finalTotal,
                    'status' => 'pending',
                    'generated_at' => now(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);

                DB::table('payments')
                    ->where('driver_id', $driver->driver_id)
                    ->where('is_settled', 0)
                    ->update([
                        'is_settled' => true,
                        'payout_report_id' => $reportId
                    ]);
                $currency_code = SettingData('CURRENCY', 'CURRENCY_CODE') ?? 'USD';
                $currency_data = currencyArray($currency_code);
                $currency = strtolower($currency_data['code']);
                $wallet = Wallet::firstOrCreate(
                    ['user_id' => $driver->driver_id]
                );
                $total_amount = $wallet->total_amount - $totalCommission;
                $wallet->total_amount = $total_amount;
                $wallet->save();

                 $wallet = [
                    'user_id'           => $driver->driver_id,
                    'type'              => 'debit',
                    'description'       => __('message.driver_payoutreport'),
                    'currency'          => $currency,
                    'amount'            => $totalCommission,
                    'balance'           => $total_amount,
                    'datetime'          => date('Y-m-d H:i:s'),
                    'week_date'         => $startDate .'    '. $endDate
                ];
                WalletHistory::create($wallet);

                DB::commit();

                $this->info("Payout report generated for driver ID: {$driver->driver_id}");

            } catch (\Exception $e) {
                DB::rollBack();
                $this->error("Failed for driver {$driver->driver_id}: " . $e->getMessage());
            }
        }
        $this->info('Running payout report mail cron...');
        Artisan::call('app:send-driver-payout-report-mail');

        return Command::SUCCESS;
    }
}

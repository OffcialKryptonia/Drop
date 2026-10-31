<?php

namespace App\Console\Commands;

use App\Models\User;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class AnonymizeInactiveUsers extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:anonymize-inactive-users';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Anonymize users inactive for 24 months and clear their bank details';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $threshold = Carbon::now()->subMonths(24);
        $anonymizedCount = 0;

        User::query()
            ->where(function ($query) use ($threshold) {
                $query->where('last_actived_at', '<=', $threshold)
                    ->orWhere(function ($subQuery) use ($threshold) {
                        $subQuery->whereNull('last_actived_at')
                            ->where('created_at', '<=', $threshold);
                    });
            })
            ->where('email', 'not like', '%' . '@anonymized.com')
            ->chunkById(200, function ($users) use (&$anonymizedCount) {
                foreach ($users as $user) {
                    $now = now();

                    $user->forceFill([
                        'first_name' => 'Anonymized',
                        'last_name' => $user->id . ' User',
                        'display_name' => 'Anonymized ' . $user->id . ' User',
                        'address' => null,
                        'email' => $now->format('YmdHis') . $user->id . '@anonymized.com',
                        'username' => $now->format('YmdHis') . $user->id . '@anonymized.com',
                        'contact_number' => $now->format('ymdHis') . $user->id,
                        'status' => 'inactive',
                        'is_available' => 0,
                    ])->save();

                    $user->userBankAccount()->delete();

                    $anonymizedCount++;
                }
            });

        $this->info("Inactive users anonymized: {$anonymizedCount}");

        return self::SUCCESS;
    }
}

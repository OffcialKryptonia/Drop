<?php

use App\Models\Permission;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('driver_payout_reports', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('driver_id');
            $table->date('week_start_date');
            $table->date('week_end_date');
            $table->integer('total_trips')->default(0);
            $table->integer('driver_tips')->default(0);
            $table->boolean('is_mail_sent')->default(0);
            $table->decimal('total_fare', 10, 2)->default(0);
            $table->decimal('total_commission', 10, 2)->default(0);
            $table->decimal('payout_amount', 10, 2)->default(0);
            $table->string('payment_method')->nullable();
            $table->string('transaction_reference')->nullable();
            $table->enum('status', ['pending', 'processing', 'paid'])->default('pending');
            $table->timestamp('generated_at')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();
            $table->foreign('driver_id')->references('id')->on('users')->onDelete('cascade');
        });
        $parent = Permission::firstOrCreate([
            'name' => 'driver-payout-reports',
            'guard_name' => 'web',
        ]);

        Permission::firstOrCreate([
            'name' => 'driver-payout-reports-list',
            'guard_name' => 'web',
            'parent_id' => $parent->id,
        ]);

        Permission::firstOrCreate([
            'name' => 'driver-payout-reports-edit',
            'guard_name' => 'web',
            'parent_id' => $parent->id,
        ]);

    }

    public function down(): void
    {
        Schema::dropIfExists('driver_payout_reports');
    }
};

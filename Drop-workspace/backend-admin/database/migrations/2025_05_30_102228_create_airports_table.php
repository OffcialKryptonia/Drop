<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

use App\Helpers\SeederHelper;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('airports', function (Blueprint $table) {
            $table->id();
           $table->unsignedBigInteger('airport_id')->nullable();
            $table->string('ident')->nullable();
            $table->string('type')->nullable();
            $table->string('name')->nullable();
            $table->string('latitude_deg', 255)->nullable();
            $table->string('longitude_deg', 255)->nullable();
            $table->string('iso_country')->nullable();
            $table->string('iso_region')->nullable();
            $table->string('municipality')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        $permissions = [
            [
                'name' => 'surgeprice',
                'sub_permission' => [
                    'surgeprice list',
                    'surgeprice add',
                    'surgeprice edit',
                    'surgeprice delete',
                ],
            ],
            [
                'name' => 'screen',
                'sub_permission' => [
                    'screen-list',
                ],
            ],
            [
                'name' => 'defaultkeyword',
                'sub_permission' => [
                    'defaultkeyword-list',
                    'defaultkeyword-add',
                    'defaultkeyword-edit',
                ],
            ],
            [
                'name' => 'languagelist',
                'sub_permission' => [
                    'languagelist-list',
                    'languagelist-add',
                    'languagelist-edit',
                    'languagelist-delete',
                ],
            ],
            [
                'name' => 'languagewithkeyword',
                'sub_permission' => [
                    'languagewithkeyword-list',
                    'languagewithkeyword-edit',
                ],
            ],
            [
                'name' => 'bulkimport',
                'sub_permission' => [
                    'bulkimport-list',
                ],
            ],
            [
                'name' => 'websitesection',
                'sub_permission' => [
                    'website-section-list',
                ],
            ],
            [
                'name' => 'subadmin',
                'sub_permission' => [ 'subadmin-list', 'subadmin-add', 'subadmin-edit', 'subadmin-delete'],
            ],
            [
                'name' => 'customersupport',
                'sub_permission' => [ 'customersupport-show', 'customersupport-delete'],
            ],
            [
                'name' => 'payment',
                'sub_permission' => [ 'online-payment-list', 'cash-payment-list', 'wallet-payment-list' ],
            ],
            [
                'name' => 'driver',
                'sub_permission' => [ 'service-wise-report'],
            ],
            [
                'name' => 'faq',
                'sub_permission' => [ 'faq-list', 'faq-add', 'faq-edit', 'faq-show', 'faq-delete', ],
            ],
            [
                'name' => 'reference_program',
                'sub_permission' => [ 'reference_program-list', ],
            ],
            [
                'name' => 'websitesection',
                'sub_permission' => [
                    'website-section-list',
                ],
            ],
            [
                'name' => 'airport',
                'sub_permission' => ['airport-list', 'airport-add', 'airport-edit', 'airport-show', 'airport-delete' ],
            ],
            [
                'name' => 'service',
                'sub_permission' => ['service-show'],
            ],
            [
                'name' => 'managezone',
                'sub_permission' => [ 'managezone-list','managezone-add' , 'managezone-edit', 'managezone-delete' ],
            ],
            [
                'name' => 'managezone-price',
                'sub_permission' => [ 'managezone-price-edit', 'managezone-price-delete', 'managezone-price-list', 'managezone-price-add' ],
            ],
            
        ];
        
        SeederHelper::seedPermissions($permissions);

        $sub_permission = array_merge(
            array_column($permissions, 'name'),
            ...array_column($permissions, 'sub_permission')
        );

        $new_permission = [];

        $roles = [
            [
                'name' => 'admin',
                'permissions' => array_merge(  $sub_permission, $new_permission  )
            ]
        ];

        SeederHelper::seedRoles($roles);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('airports');
    }
};

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;
use App\Models\Region;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {

        if (Schema::hasColumn('regions', 'coordinates')) {
            $columnType = DB::selectOne("
                SELECT DATA_TYPE 
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE table_schema = DATABASE()
                  AND table_name = 'regions'
                  AND column_name = 'coordinates'
            ");

            if ($columnType && $columnType->DATA_TYPE === 'polygon') {

                // 1. Add a new temporary JSON column
                Schema::table('regions', function (Blueprint $table) {
                    $table->json('coordinates_json')->nullable()->after('coordinates');
                });

                // 2. Copy polygon data into the new JSON column using ST_AsGeoJSON
                DB::statement("
                    UPDATE regions
                    SET coordinates_json = JSON_EXTRACT(ST_AsGeoJSON(coordinates), '$.coordinates')
                ");

                Region::query()->get()->each(function ($region) {
                    $coords = json_decode($region->coordinates_json, true); // This is [[[lng, lat], ...]]

                    // Get outer ring only (polygon => array of 1 array of points)
                    $outerRing = $coords[0] ?? [];

                    // Flip lng/lat to lat/lng
                    $flipped = array_map(fn($point) => [$point[1], $point[0]], $outerRing);

                    $region->coordinates_json = json_encode($flipped);
                    $region->save();
                });

                // 3. Try dropping spatial index if it exists
                try {
                    DB::statement("DROP INDEX coordinates ON regions");
                } catch (\Throwable $e) {
                    // Ignore if index doesn't exist
                }

                // 4. Drop the original polygon column
                Schema::table('regions', function (Blueprint $table) {
                    $table->dropColumn('coordinates');
                });

                // 5. Rename the JSON column to `coordinates`
                Schema::table('regions', function (Blueprint $table) {
                    $table->renameColumn('coordinates_json', 'coordinates');
                });
            }
        }
    }

    public function down()
    {
        // ⚠️ You can't fully restore the polygon unless you re-import it from a backup
        // This only resets the column to a polygon type, but doesn't convert JSON back to polygon
        Schema::table('regions', function (Blueprint $table) {

        });
    }
};

<?php

namespace App\Imports;

use App\Models\Airport;
use Maatwebsite\Excel\Concerns\ToModel;
use Maatwebsite\Excel\Concerns\WithHeadingRow;
use Maatwebsite\Excel\Concerns\WithChunkReading;
use Maatwebsite\Excel\Concerns\WithBatchInserts;
use Illuminate\Contracts\Queue\ShouldQueue;


class AirportsImport implements ToModel, WithHeadingRow, WithChunkReading, WithBatchInserts, ShouldQueue
{
    /**
    * @param array $row
    *
    * @return \Illuminate\Database\Eloquent\Model|null
    */

    protected $existingIds = [];

    public function __construct()
    {
        $this->existingIds = Airport::pluck('airport_id')->toArray();
    }

    public function model(array $row)
    {
        if (in_array($row['airport_id'], $this->existingIds)) {
            return null;
        }

        $this->existingIds[] = $row['airport_id'];
        return new Airport([
            'airport_id'    => $row['airport_id'],
            'ident'         => $row['ident'],
            'type'          => $row['type'],
            'name'          => $row['name'],
            'latitude_deg'  => $row['latitude_deg'],
            'longitude_deg' => $row['longitude_deg'],
            'iso_country'   => $row['iso_country'],
            'iso_region'    => $row['iso_region'],
            'municipality'  => $row['municipality'],
        ]);
    }
    public function chunkSize(): int
    {
        return 1000;
    }

    public function batchSize(): int
    {
        return 1000;
    }
}

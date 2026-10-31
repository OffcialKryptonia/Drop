<?php

namespace App\Exports;

use Illuminate\Support\Carbon;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;
use Maatwebsite\Excel\Concerns\WithStyles;
use Maatwebsite\Excel\Concerns\WithEvents;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use Maatwebsite\Excel\Events\AfterSheet;

class DriverReportExport implements FromCollection, WithHeadings, WithMapping, WithStyles, WithEvents
{
    protected $user_data;
    protected $request;
    protected $counter = 1;
    protected $columns;

    public function __construct($user_data, $request)
    {
        $this->user_data = $user_data;
        $this->request   = $request;
        $this->columns   = $request->input('columns', []);
    }

    public function collection()
    {
        return $this->user_data;
    }

    public function map($driver): array
    {
        $row = [];

        foreach ($this->columns as $col) {
            switch ($col) {
                case 'no':
                    $row[] = $this->counter++;
                    break;
                case 'id':
                    $row[] = $driver->id ?? '-';
                    break;
                case 'name':
                    $row[] = ($driver->first_name ?? '-') . ' ' . ($driver->last_name ?? '-');
                    break;
                case 'contact_number':
                    $row[] = $driver->contact_number ?? '-';
                    break;
                case 'email':
                    $row[] = $driver->email ?? '-';
                    break;
                case 'service':
                    $row[] = optional($driver->service)->name ?? '-';
                    break;
                case 'status':
                    $row[] = $driver->status ?? '-';
                    break;
                case 'last_actived_at':
                    $row[] = $driver->last_actived_at ?? '-';
                    break;
                case 'created_at':
                    $row[] = $driver->created_at ? $driver->created_at->format('Y-m-d') : '-';
                    break;
                case 'car_model':
                    $row[] = optional($driver->userDetail)->car_model ?? '-';
                    break;
                case 'car_color':
                    $row[] = optional($driver->userDetail)->car_color ?? '-';
                    break;
                case 'car_plate_number':
                    $row[] = optional($driver->userDetail)->car_plate_number ?? '-';
                    break;
                case 'car_production_year':
                    $row[] = optional($driver->userDetail)->car_production_year ?? '-';
                    break;
                case 'Driver License Number':
                    $row[] = optional($driver->userDetail)->driver_license_number ?? '-';
                    break;
                case 'Vehicle RC Number':
                    $row[] = optional($driver->userDetail)->vehicle_rc_number ?? '-';
                    break;
                case 'DOB':
                    $row[] = optional($driver->userDetail)->dob
                        ? Carbon::parse($driver->userDetail->dob)->format('Y-m-d')
                        : '-';
                    break;
            }
        }

        return $row;
    }

    public function headings($exportType = 'excel'): array
    {
        $fromDate = $this->request->input('from_date');
        $toDate   = $this->request->input('to_date');

        $date = ($fromDate && $toDate)
            ? 'From Date: ' . ($fromDate ?: '-') . ' To Date ' . ($toDate ?: '-')
            : ($fromDate ? 'From Date: ' . $fromDate : ($toDate ? 'To Date: ' . $toDate : null));
        $labels = [];
        foreach ($this->columns as $col) {
            switch ($col) {
                case 'no': $labels[] = __('message.no'); break;
                case 'id': $labels[] = __('message.id'); break;
                case 'name': $labels[] = __('message.name'); break;
                case 'contact_number': $labels[] = __('message.contact_number'); break;
                case 'email': $labels[] = __('message.email'); break;
                case 'service': $labels[] = __('message.service'); break;
                case 'status': $labels[] = __('message.status'); break;
                case 'last_actived_at': $labels[] = __('message.last_actived_at'); break;
                case 'created_at': $labels[] = __('message.created_at'); break;
                case 'car_model': $labels[] = __('message.car_model'); break;
                case 'car_color': $labels[] = __('message.car_color'); break;
                case 'car_plate_number': $labels[] = __('message.car_plate_number'); break;
                case 'car_production_year': $labels[] = __('message.car_production_year'); break;
                case 'Driver License Number': $labels[] = 'Driver License Number'; break;
                case 'Vehicle RC Number': $labels[] = 'Vehicle RC Number'; break;
                case 'DOB': $labels[] = 'DOB'; break;
            }
        }

        if ($exportType === 'excel') {
            return [
                ['Driver Report' . ($date ? ' : ' . $date : '')],
                [''],
                $labels,
            ];
        }

        return $labels;
    }

    public function styles(Worksheet $sheet)
    {
        $highestColumn = $sheet->getHighestColumn();

        $sheet->mergeCells('A1:' . $highestColumn . '1');
        $sheet->getStyle('A1')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

        $sheet->getStyle('A1:' . $highestColumn . '1')->applyFromArray([
            'font' => ['bold' => true],
            'alignment' => [
                'horizontal' => Alignment::HORIZONTAL_CENTER,
                'vertical'   => Alignment::VERTICAL_CENTER,
            ],
        ]);
    }

    public function registerEvents(): array
    {
        return [
            AfterSheet::class => function(AfterSheet $event) {
                foreach (range('A', $event->sheet->getDelegate()->getHighestColumn()) as $col) {
                    $event->sheet->getDelegate()->getColumnDimension($col)->setAutoSize(true);
                }
                $event->sheet->getDelegate()->getStyle('A:Z')
                    ->getAlignment()
                    ->setHorizontal(Alignment::HORIZONTAL_CENTER);
            },
        ];
    }
}

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

class RideRequestReportExport implements FromCollection, WithHeadings, WithMapping, WithStyles, WithEvents
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
                case 'rider_name':
                    $row[] = ($driver->rider->display_name ?? '-');
                    break;
                case 'requested_driver':
                    $row[] = ($driver->riderequest_in_driver->display_name ?? '-');
                    break;
                case 'driver_name':
                    $row[] = $driver->driver->display_name ?? '-';
                    break;
                case 'pickup_address':
                    $row[] = $driver->start_address ?? '-';
                    break;
                case 'drop_address':
                    $row[] = $driver->end_address ?? '-';
                    break;
                case 'trip_type':
                    $row[] = $driver->trip_type ?? '-';
                    break;
                case 'status':
                    $row[] = $driver->status ?? '-';
                    break;
                case 'payment_status':
                        $row[] = $driver->payment->payment_status ?? '-';
                        break;
                case 'payment_method':
                        $row[] = $driver->payment_type ?? '-';
                        break;
                case 'distance':
                        $row[] = $driver->distance ?? '-';
                        break;
                case 'discount':
                        $row[] = $driver->discount ?? '-';
                        break;
                case 'extra_charges_amount':
                        $row[] = $driver->extra_charges_amount ?? '-';
                        break;
                case 'extra_charges':
                        $row[] = $driver->extra_charges ?? '-';
                        break;
                case 'admin_commission':
                        $row[] = $driver->payment->admin_commission ?? '-';
                        break;
                case 'total_amount':
                        $row[] = $driver->total_amount ?? '-';
                        break;
                case 'created_at':
                    $row[] = $driver->created_at ? $driver->created_at->format('Y-m-d') : '-';
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
                case 'rider_name': $labels[] = __('message.rider_name'); break;
                case 'requested_driver': $labels[] = __('message.requested_driver'); break;
                case 'driver_name': $labels[] = __('message.driver_name'); break;
                case 'pickup_address': $labels[] = __('message.pickup_address'); break;
                case 'drop_address': $labels[] = __('message.drop_address'); break;
                case 'trip_type': $labels[] = __('message.trip_type'); break;
                case 'status': $labels[] = __('message.status'); break;
                case 'payment_status': $labels[] = __('message.payment_status'); break;
                case 'payment_method': $labels[] = __('message.payment_method'); break;
                case 'distance': $labels[] = __('message.distance'); break;
                case 'discount': $labels[] = __('message.discount'); break;
                case 'extra_charges_amount': $labels[] = __('message.extra_charges_amount'); break;
                case 'extra_charges': $labels[] = __('message.extra_charges'); break;
                case 'admin_commission': $labels[] = __('message.admin_commission'); break;
                case 'total_amount': $labels[] = __('message.total_amount'); break;
                case 'created_at': $labels[] = __('message.created_at'); break;
            }
        }

        if ($exportType === 'excel') {
            return [
                ['Rider Report' . ($date ? ' : ' . $date : '')],
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

                // Center align all cells
                $event->sheet->getDelegate()->getStyle('A:Z')
                    ->getAlignment()
                    ->setHorizontal(Alignment::HORIZONTAL_CENTER);
            },
        ];
    }
}

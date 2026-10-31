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

class RiderReportExport implements FromCollection, WithHeadings, WithMapping, WithStyles, WithEvents
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
                case 'status':
                    $row[] = $driver->status ?? '-';
                    break;
                case 'last_actived_at':
                    $row[] = $driver->last_actived_at ?? '-';
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
                case 'name': $labels[] = __('message.name'); break;
                case 'contact_number': $labels[] = __('message.contact_number'); break;
                case 'email': $labels[] = __('message.email'); break;
                case 'status': $labels[] = __('message.status'); break;
                case 'last_actived_at': $labels[] = __('message.last_actived_at'); break;
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

    /** ✅ implements WithStyles */
    public function styles(Worksheet $sheet)
    {
        $highestColumn = $sheet->getHighestColumn();

        // Merge first row for title
        $sheet->mergeCells('A1:' . $highestColumn . '1');
        $sheet->getStyle('A1')->getAlignment()->setHorizontal(Alignment::HORIZONTAL_CENTER);

        // Bold + center for title
        $sheet->getStyle('A1:' . $highestColumn . '1')->applyFromArray([
            'font' => ['bold' => true],
            'alignment' => [
                'horizontal' => Alignment::HORIZONTAL_CENTER,
                'vertical'   => Alignment::VERTICAL_CENTER,
            ],
        ]);
    }

    /** ✅ implements WithEvents */
    public function registerEvents(): array
    {
        return [
            AfterSheet::class => function(AfterSheet $event) {
                // Auto-size all columns
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

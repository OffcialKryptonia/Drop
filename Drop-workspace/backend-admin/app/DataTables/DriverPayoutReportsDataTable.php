<?php

namespace App\DataTables;

use App\Models\DriverPayoutReport;
use App\Traits\DataTableTrait;
use Carbon\Carbon;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;

class DriverPayoutReportsDataTable extends DataTable
{
    use DataTableTrait;

    public function dataTable($query)
    {
        return datatables()
            ->eloquent($query)

            ->editColumn('driver_id', function ($report) {
                 return '<a href="'.route('driver.show',$report->driver_id).'">'.($report->driver)->display_name.'</span></a>';
            })

            ->editColumn('week', function ($report) {
                return Carbon::parse($report->week_start_date)->format('M j, Y')
                    .' - '.
                    Carbon::parse($report->week_end_date)->format('M j, Y');
            })
            ->editColumn('document', function ($report) {

                if ($report->is_mail_sent != 1) {
                    return '-';
                }

                $fileUrl = getSingleMedia($report, 'driver_payout_report_document', null);
                if (!$fileUrl || str_contains($fileUrl, 'default.png')) {
                    return '-';
                }

                return '<a href="'.$fileUrl.'" target="_blank" title="View Document">
                            <i class="fas fa-file-pdf text-danger" style="font-size:18px;"></i>
                        </a>';
            })

            ->editColumn('status', function ($report) {

                $status = strtolower($report->status);

                $class = match ($status) {
                    'pending'  => 'badge-danger',
                    'paid'     => 'badge-success',
                    'progress' => 'badge-warning',
                    default    => 'badge-secondary',
                };

                return '<span class="badge '.$class.'">'.ucfirst($status).'</span>';
            })

            ->editColumn('generated_at', function ($report) {
                return dateAgoFormate($report->generated_at, true);
            })

            ->editColumn('paid_at', function ($report) {
                return $report->paid_at
                    ? dateAgoFormate($report->paid_at, true)
                    : '-';
            })
            ->editColumn('driver_tips', function ($report) {
                return $report->driver_tips
                    ? $report->driver_tips
                    : '-';
            })
            ->editColumn('payment_method', function ($report) {
                return $report->payment_method
                    ? $report->payment_method
                    : '-';
            })
            ->editColumn('transaction_reference', function ($report) {
                return $report->transaction_reference
                    ? $report->transaction_reference
                    : '-';
            })

            ->addIndexColumn()
            ->addColumn('action', function($data){
                if ($data->status === 'paid') {
                    return ''; // no buttons
                }
                $id = $data->id;
                return view('driver_payout_report.action',compact('data','id'))->render();
            })

            ->order(function ($query) {
                if (request()->has('order')) {
                    $order = request()->order[0];
                    $columnIndex = $order['column'];
                    $direction = 'desc';
                    $column_name = 'generated_at';
                    if( $columnIndex != 0) {
                        $column_name = request()->columns[$columnIndex]['data'];
                        $direction = $order['dir'];
                    }
                    $query->orderBy($column_name, $direction);
                }
            })

            ->rawColumns(['action','status','driver_id','document']);
    }

    /**
     * Query
     */
    public function query(DriverPayoutReport $model)
    {
        $query = $model->newQuery()->with('driver');
        if (($this->driver_id)) {
            $query->where('driver_id', $this->driver_id);
        }

        return $query;
    }

    /**
     * Columns
     */
    protected function getColumns()
    {
         $columns = [
            Column::make('id')
                ->title(__('message.id')),

            Column::make('driver_id')
                ->title(__('message.driver'))
                ->orderable(false),

            Column::computed('week')
                ->title(__('message.week'))
                ->orderable(false)
                ->width(180)
                ->addClass('text-nowrap'),

            Column::make('total_fare')
                ->title(__('message.total_fare')),

            Column::make('total_commission')
                ->title(__('message.total_commission')),

            Column::make('total_trips')
                ->title(__('message.total_trips')),

            Column::make('payout_amount')
                ->title(__('message.payout_amount')),

            Column::make('driver_tips')
                ->title(__('message.driver_tips')),
            Column::make('document')
                ->title(__('message.document_mail'))
                ->orderable(false)
                ->searchable(false),
            Column::make('payment_method')
                ->title(__('message.payment_method'))
                ->orderable(false)
                ->searchable(false),

            Column::make('transaction_reference')
                ->title(__('message.transaction_reference'))
                ->orderable(false)
                ->searchable(false),

            Column::make('status')
                ->title(__('message.status')),

            Column::make('generated_at')
                ->data('generated_at')
                ->title(__('message.generated_at')),

            Column::make('paid_at')
                ->title(__('message.paid_at'))
                ->width(180)
                ->addClass('text-nowrap'),
        ];
        if (!($this->driver_id)) {
            $columns[] = Column::computed('action')
                ->exportable(false)
                ->printable(false)
                ->width(60)
                ->addClass('text-center');
        }
        return $columns;
    }
}

<?php

namespace App\DataTables;

use App\Models\ZonePrice;
use App\Traits\DataTableTrait;
use Illuminate\Database\Eloquent\Builder as QueryBuilder;
use Yajra\DataTables\EloquentDataTable;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;

class ManageZonePriceDataTable extends DataTable
{
    use DataTableTrait;
    /**
     * Build the DataTable class.
     *
     * @param QueryBuilder $query Results from query() method.
     */
    public function dataTable(QueryBuilder $query): EloquentDataTable
    {
        return datatables()
            ->eloquent($query)
            ->addIndexColumn()
            ->editColumn('service_ids', function ($query) {
                return is_array($query->services) ? implode(', ', $query->services) : $query->services; 
            })
            ->editColumn('zone_pickup', function ($query) {
                return $query->zonepickup->name;
            })
            ->editColumn('zone_dropoff', function ($query) {
                return $query->zonedropoff->name;
            })
            ->editColumn('price', function ( $row ) {
                return getPriceFormat( (float) $row->price ) ?? '-';
            })
            ->editColumn('created_at', function ($query) {
                return dateAgoFormate($query->created_at, true);
            })
            ->addColumn('action', 'managezone-price.action')
            ->order(function ($query) {
                if (request()->has('order')) {
                    $order = request()->order[0];
                    $column_index = $order['column'];

                    $column_name = 'created_at';
                    $direction = 'desc';
                    if( $column_index != 0) {
                        $column_name = request()->columns[$column_index]['data'];
                        $direction = $order['dir'];
                    }
                    $query->orderBy($column_name, $direction);
                }
            })
            ->rawColumns(['action']);
    }

    public function query(ZonePrice $model): QueryBuilder
    {
        return $model->newQuery();
    }

    public function getColumns(): array
    {
        return [
            Column::make('DT_RowIndex')->searchable(false)->title(__('message.srno'))->orderable(false),
            Column::make('service_ids')->title( __('message.service') ),
            Column::make('zone_pickup')->title( __('message.zone_pickup')),
            Column::make('zone_dropoff')->title( __('message.zone_dropoff')),
            Column::make('price')->title( __('message.price')),
            Column::make('created_at')->title( __('message.created_at')),
            Column::computed('action')
                  ->exportable(false)
                  ->printable(false)
                  ->width(60)
                  ->addClass('text-center'),
        ];
    }

    protected function filename(): string
    {
        return 'ManageZonePrice_' . date('YmdHis');
    }
}

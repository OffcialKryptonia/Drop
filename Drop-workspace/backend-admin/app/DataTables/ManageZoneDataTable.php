<?php

namespace App\DataTables;

use App\Models\ManageZone;
use App\Traits\DataTableTrait;
use Illuminate\Database\Eloquent\Builder as QueryBuilder;
use Yajra\DataTables\EloquentDataTable;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;

class ManageZoneDataTable extends DataTable
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
            
            ->editColumn('status', function($query) {
                $status = $query->status == 'active' ? 'primary' : 'danger';
                return '<span class="text-capitalize badge bg-'.$status.'">'.$query->status.'</span>';
            })
            ->editColumn('created_at', function ($query) {
                return dateAgoFormate($query->created_at, true);
            })
            ->editColumn('description', function($property) {
                return isset($property->description) ? '<span data-toggle="tooltip" title="'.$property->description.'">'.stringLong($property->description, 'desc').'</span>' : null;
            })
            ->addIndexColumn()
            ->addColumn('action', 'managezone.action')
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
            ->rawColumns(['action', 'description', 'status']);
    }

    /**
     * Get the query source of dataTable.
     */
    public function query(ManageZone $model): QueryBuilder
    {
        return $model->newQuery();
    }

    /**
     * Get the dataTable columns definition.
     */
    public function getColumns(): array
    {
        return [
            Column::make('DT_RowIndex')
                ->searchable(false)
                ->title(__('message.srno'))
                ->orderable(false),
            Column::make('name')->title( __('message.name') ),
            Column::make('description')->title( __('message.description')),
            Column::make('status')->title( __('message.status')),
            Column::make('created_at')->title( __('message.created_at')),
            Column::computed('action')
                  ->exportable(false)
                  ->printable(false)
                  ->width(60)
                  ->addClass('text-center'),
        ];
    }

    /**
     * Get the filename for export.
     */
    protected function filename(): string
    {
        return 'ManageZone_' . date('YmdHis');
    }
}

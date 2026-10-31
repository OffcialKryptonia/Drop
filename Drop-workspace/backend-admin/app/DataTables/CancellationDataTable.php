<?php

namespace App\DataTables;

use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;
use App\Traits\DataTableTrait;
use App\Models\Cancellation;

class CancellationDataTable extends DataTable
{
    use DataTableTrait;
    /**
     * Build DataTable class.
     *
     * @param mixed $query Results from query() method.
     * @return \Yajra\DataTables\DataTableAbstract
     */
    public function dataTable($query)
    {
        return datatables()
            ->eloquent($query)
            ->editColumn('created_at', function ($query) {
                return dateAgoFormate($query->created_at, true);
            })
            ->addIndexColumn()
            ->addColumn('action', 'cancellation.action')
            ->order(function ($query) {
                if (request()->has('order')) {
                    $order = request()->order[0];
                    $column_index = $order['column'];

                    $column_name = 'created_at';
                    $direction = 'asc';
                    if( $column_index != 0) {
                        $column_name = request()->columns[$column_index]['data'];
                        $direction = $order['dir'];
                    }
    
                    $query->orderBy($column_name, $direction);
                }
            })
            ->rawColumns([]);
    }

    /**
     * Get query source of dataTable.
     *
     * @param \App\Models\LanguageWithKeyword $model
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function query(Cancellation $model)
    {
        return $model->newQuery();
    }


    /**
     * Get columns.
     *
     * @return array
     */
    protected function getColumns()
    {
        return [
            Column::make('DT_RowIndex')
                ->searchable(false)
                ->title(__('message.srno'))
                ->orderable(false),
            ['data' => 'title', 'name' => 'title', 'title' => __('message.title')],
            ['data' => 'type', 'name' => 'type', 'title' => __('message.type')],
            ['data' => 'created_at', 'name' => 'created_at', 'title' => __('message.created_at')],
            Column::computed('action')
                  ->title(__('message.action'))
                  ->exportable(false)
                  ->printable(false)
                  ->width(60)
                  ->addClass('text-center'),
        ];
    }
}

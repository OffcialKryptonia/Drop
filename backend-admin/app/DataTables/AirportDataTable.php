<?php

namespace App\DataTables;

use App\Models\Airport;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;
use App\Traits\DataTableTrait;


class AirportDataTable extends DataTable
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
            ->addColumn('checkbox', function ($row) {
                return '<input type="checkbox" class=" select-table-row-checked-values" id="datatable-row-' . $row->id . '" name="datatable_ids[]" value="' . $row->id . '" onclick="dataTableRowCheck(' . $row->id . ')">';
            })
          
            ->editColumn('created_at', function ($row) {
                return dateAgoFormate($row->created_at, true);
            })
            ->editColumn('type', function($row){
                return str_replace('_' , ' ',ucfirst($row->type));
            })

            ->addColumn('action', function($row){
                $id = $row->id;
                $delete_at = $row->deleted_at;
                $action_type= 'action';
                return view('airport.action',compact('id','delete_at','action_type'))->render();
            })

            ->addIndexColumn()
            ->rawColumns(['action','checkbox','id']);
    }

    /**
     * Get query source of dataTable.
     *
     * @param \App\Models\Airport $model
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function query(Airport $model)
    {
        $model = Airport::query()->orderBy('created_at','desc');
        return $model->withTrashed();
    }

    /**
     * Get columns.
     *
     * @return array
     */
    protected function getColumns()
    {
        return [
            Column::make('checkbox')
                ->searchable(false)
                ->title('<input type="checkbox" class ="select-all-table" name="select_all" id="select-all-table">')
                ->orderable(false)
                ->addClass('text-capitalize')
                ->width(60),
                ['data' => 'id', 'name' => 'id', 'title' => __('message.id')],
                ['data' => 'airport_id', 'name' => 'airport_id', 'title' => __('message.airport_id')],
                ['data' => 'ident', 'name' => 'ident', 'title' => __('message.ident')],
                ['data' => 'type', 'name' => 'type', 'title' => __('message.type')],
                ['data' => 'name', 'name' => 'name', 'title' => __('message.name'),'class' => 'text-capitalize'],
                ['data' => 'iso_country', 'name' => 'iso_country', 'title' => __('message.country')],
                ['data' => 'iso_region', 'name' => 'iso_region', 'title' => __('message.region')],
                ['data' => 'municipality', 'name' => 'municipality', 'title' => __('message.municipality')],
                ['data' => 'created_at', 'name' => 'created_at', 'title' => __('message.created_at')],
            Column::computed('action')
                  ->exportable(false)
                  ->printable(false)
                  ->width(60)
                  ->addClass('text-center hide-search'),
        ];
    }
}

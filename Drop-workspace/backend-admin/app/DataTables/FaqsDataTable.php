<?php

namespace App\DataTables;

use App\Models\Faq;
use App\Traits\DataTableTrait;
use Yajra\DataTables\Html\Button;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;

class FaqsDataTable extends DataTable
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
            ->editColumn('answer', function ($query) {
                return '<span class="faq-content" data-toggle="tooltip" data-html="true" data-bs-placement="bottom" title="'.$query->answer.'">'.$query->answer.'</span>';
            })
            ->editColumn('question', function ($query) {
                return '<span class="faq-content" data-toggle="tooltip" data-html="true" data-bs-placement="bottom" title="'.$query->question.'">'.$query->question.'</span>';
            })
           
           ->editColumn('created_at', function ($query) {
                return dateAgoFormate($query->created_at, true);
            })

            ->addColumn('action', function($faq){
                $id = $faq->id;
                $deleted_at = $faq->deleted_at;
                return view('faq.action',compact('faq','id','deleted_at'))->render();
            })
            ->addIndexColumn()
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
            ->rawColumns(['action','answer','category_id','created_at','status','question']);
    }

    /**
     * Get query source of dataTable.
     *
     * @param \App\Models\FaqsDataTable $model
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function query(Faq $model)
    {
        $model = Faq::query();
        return $model;
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
            ->orderable(false)
            ->width(60),
            ['data' => 'question', 'name' => 'question', 'title' => __('message.question'), 'width' => '20%'],
            ['data' => 'answer', 'name' => 'answer', 'title' => __('message.answer'), 'width' => '30%'],
            ['data' => 'type', 'name' => 'type', 'title' => __('message.type')],
            ['data' => 'created_at', 'name' => 'created_at', 'title' => __('message.created_at')],
            Column::computed('action')
                  ->exportable(false)
                  ->printable(false)
                  ->title(__('message.action'))
                  ->width(60)
                  ->addClass('text-center hide-search'),
        ];
    }
}

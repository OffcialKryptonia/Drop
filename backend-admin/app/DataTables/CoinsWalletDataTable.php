<?php

namespace App\DataTables;

use App\Models\CoinWallet;
use App\Models\Coupon;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;

use App\Traits\DataTableTrait;

class CoinsWalletDataTable extends DataTable
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
            ->editColumn('type', function($query) {
                $status = 'warning';
                switch ($query->type) {
                    case 'credit':
                        $status = 'success';
                        $status_label =  __('message.credit');
                        break;
                    case 'debit':
                        $status = 'danger';
                        $status_label =  __('message.debit');
                        break;
                    default:
                        $status_label = null;
                        break;
                }
                return '<span class="text-capitalize text-' .$status .' badge badge-light-'.$status.'">'.$status_label.'</span>';
            })
            ->editColumn('created_at', function ($query) {
                return dateAgoFormate($query->created_at, true);
            })
            ->editColumn('scratch_time', function ($query) {
                return dateAgoFormate($query->scratch_time, true);
            })
            ->addIndexColumn()
            ->editColumn('ride_id' , function ( $query ) {
                if( $query->ride_id != null ) {
                    return '<a href="'.route('riderequest.show', $query->ride_id) .'" ># '.$query->ride_id.'</a>';
                } else {
                    return '<span>-</span>';
                }
            })
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
            ->rawColumns([ 'ride_id', 'type' ]);
    }

    /**
     * Get query source of dataTable.
     *
     * @param \App\Models\Coupon $model
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function query()
    {
        $model = CoinWallet::query();
        if($this->rider_id){
            $model->where('user_id', $this->rider_id);
        }
        return $this->applyScopes($model);
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
            Column::make('ride_id')->title( __('message.ride_request_id') ),
            Column::make('coins')->title( __('message.coin') ),
            Column::make('scratch_time')->title( __('message.scratch_at') ),
            Column::make('type')->title( __('message.type') ),
        ];
    }

}

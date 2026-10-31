<?php

namespace App\DataTables;

use App\Models\RideRequestRating;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;

use App\Traits\DataTableTrait;

class RideRequestRatingDataTable extends DataTable
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

            ->editColumn('ride_request_id' , function ( $query ) {
                if( $query->ride_request_id != null ) {
                    return '<a href="'.route('riderequest.show', $query->ride_request_id ) .'" ># '.$query->ride_request_id.'</a>';
                } else {
                    return '<span>-</span>';
                }
            })

            ->editColumn('rider_id', function ($rating) {
                $rider = optional($rating->riderequest->rider);
                if ($rider && $rider->id) {
                    return '<a href="' . route('rider.show', $rider->id) . '" target="_blank">' . e($rider->display_name) . '</a>';
                }
                return '';
            })

            ->filterColumn('rider_id', function( $query, $keyword ){
                $query->whereHas('riderequest.rider', function ($q) use($keyword){
                    $q->where('display_name', 'like' , '%'.$keyword.'%');
                });
            })

            ->editColumn('driver_id', function ($rating) {
                $driver = optional($rating->riderequest->driver);
                if ($driver && $driver->id) {
                    return '<a href="' . route('driver.show', $driver->id) . '" target="_blank">' . e($driver->display_name) . '</a>';
                }
                return '';
            })

            ->filterColumn('driver_id', function( $query, $keyword ){
                $query->whereHas('riderequest.driver', function ($q) use($keyword){
                    $q->where('display_name', 'like' , '%'.$keyword.'%');
                });
            })

            ->editColumn('created_at', function ($query) {
                return dateAgoFormate($query->created_at, true);
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
            ->rawColumns(['ride_request_id','driver_id','rider_id']);
    }

    /**
     * Get query source of dataTable.
     *
     * @param \App\Models\RideRequestRating $model
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function query()
    {
        $model = RideRequestRating::query()
            ->with(['riderequest.rider', 'riderequest.driver'])
            ->where('rating', '>', 0);

        if ($this->driver_id) {
            $model = $model->where('driver_id', $this->driver_id)->where('rating_by','driver');
        }
        if ($this->rider_id) {
            $model = $model->where('rider_id', $this->rider_id)->where('rating_by','rider');
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
            Column::make('ride_request_id')->title( __('message.ride_request_id') ),
            Column::make('rider_id')->title( __('message.rider') )->visible(!$this->rider_id),
            Column::make('driver_id')->title(__('message.driver'))->visible(!$this->driver_id),
            Column::make('rating')->title( __('message.rating') ),
            Column::make('comment')->title( __('message.comment') ),
            Column::make('created_at')->title( __('message.created_at') ),
        ];
    }
}

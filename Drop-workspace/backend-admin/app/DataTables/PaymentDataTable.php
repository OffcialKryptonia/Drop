<?php

namespace App\DataTables;

use App\Models\Payment;
use Yajra\DataTables\Html\Button;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Html\Editor\Editor;
use Yajra\DataTables\Html\Editor\Fields;
use Yajra\DataTables\Services\DataTable;

use App\Traits\DataTableTrait;

class PaymentDataTable extends DataTable
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
            ->editColumn('status', function($query) {
                $status = 'warning';
                switch ($query->status) {
                    case 1:
                        $status = 'primary';
                        $status_label =  __('message.active');
                        break;
                    case 0:
                        $status = 'danger';
                        $status_label =  __('message.inactive');
                        break;
                    default:
                        $status_label = null;
                        break;
                }
                return '<span class="text-capitalize text-'.$status.' badge badge-light-'.$status.'">'.$status_label.'</span>';
            })
            ->editColumn('region_id' , function ( $service ) {
                return $service->region_id != null ? optional($service->region)->name : '';
            })
            ->editColumn('rider_id' , function ( $query ) {
                return '<a href="'.route('rider.show',$query->riderequest->rider_id).'">'.optional($query->riderequest)->rider->display_name.'</span></a>';
            })
            ->editColumn('driver_id', function ($query) {
                return optional($query->riderequest->driver)->id ? '<a href="'.route('driver.show', $query->riderequest->driver->id).'">'. e($query->riderequest->driver->display_name) . '</a>' : '-';
            })
            ->editColumn('payment_status' , function ( $query ) {
                return $query->payment_status == 'paid' ? '<span class="text-capitalize text-success badge badge-light-success">'.$query->payment_status.'</span>' : '';
            })
            ->filterColumn('region_id', function($query, $keyword) {
                $query->whereHas('region', function ($q) use($keyword) {
                    $q->where('name', 'like', '%'.$keyword.'%');
                });
            })
            ->filterColumn('rider_id', function($query, $keyword) {
                $query->whereHas('riderequest.rider', function ($q) use ($keyword) {
                    $q->where('display_name', 'like', '%'.$keyword.'%')
                    ->orWhere('email', 'like', '%'.$keyword.'%');
                });
            })
            ->filterColumn('driver_id', function($query, $keyword) {
                $query->whereHas('riderequest.driver', function ($q) use ($keyword) {
                    $q->where('display_name', 'like', '%'.$keyword.'%')
                    ->orWhere('email', 'like', '%'.$keyword.'%');
                });
            })

            ->addIndexColumn()

            ->rawColumns([ 'status' ,'rider_id','driver_id','payment_status']);
    }


    /**
     * Get query source of dataTable.
     *
     * @param \App\Models\Payment $model
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function query()
    {
        $model = Payment::query();

        $payment_type = isset($_GET['payment_type']) ? $_GET['payment_type'] : null;
        if ( in_array($payment_type,['online','cash','wallet']) ) {
            $model = $model->where('payment_type', $payment_type);
        }

        if($this->driver_id != null) {
            return $model->whereHas('riderequest',function ($q) {
                $q->where('driver_id', $this->driver_id);
            });
        } else {
            return $model->myPayment();
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
            Column::make('ride_request_id')->title( '#' ),
            Column::make('rider_id')->title( __('message.rider') ),
            Column::make('driver_id')->title( __('message.driver') ),
            Column::make('total_amount')->title( __('message.total_amount') ),
            Column::make('driver_commission')->title( __('message.driver_commission') ),
            Column::make('received_by')->title( __('message.received_by') ),
            Column::make('payment_type')->title( __('message.payment_type') ),
            Column::make('payment_status')->title( __('message.payment_status') ),
        ];
    }
}

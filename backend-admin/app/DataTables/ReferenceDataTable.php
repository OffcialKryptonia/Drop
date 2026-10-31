<?php

namespace App\DataTables;

use App\Models\DeliveryManDocument;
use App\Models\User;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;
use App\Traits\DataTableTrait;

class ReferenceDataTable extends DataTable
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
            ->order(function ($query) {
                if (request()->has('order')) {
                    $order = request()->order[0];
                    $column_index = $order['column'];

                    $column_name = 'id';
                    $direction = 'desc';
                    if ($column_index != 0) {
                        $column_name = request()->columns[$column_index]['data'];
                        $direction = $order['dir'];
                    }

                    $query->orderBy($column_name, $direction);
                }
            })
            ->addColumn('app_version', function ($row) {
                return $row->app_version ?? '-';
            })
            ->editColumn('contact_number', function($query) {
                return auth()->user()->hasRole('admin') ? maskSensitiveInfo('contact_number', $query->contact_number) : maskSensitiveInfo('contact_number', $query->contact_number);
            })
            ->editColumn('email', function($query) {
                return auth()->user()->hasRole('admin') ? maskSensitiveInfo('email', $query->email) : maskSensitiveInfo('email', $query->email);
            })
            ->editColumn('last_actived_at', function ($query) {
                return dateAgoFormate($query->last_actived_at, true) ?? '-';
            })
            ->editColumn('display_name', function ($row) {
                if ($row->user_type === 'driver') {
                    return '<a href="' . route('driver.show', $row->id) . '" class="link-success">' . $row->display_name . '</a>';
                } elseif ($row->user_type === 'rider') {
                    return '<a href="' . route('rider.show', $row->id) . '" class="link-success">' . $row->display_name . '</a>';
                }
                return '-';
            })
            ->addIndexColumn()
            ->rawColumns(['action','display_name']);
    }

    /**
     * Get query source of dataTable.
     *
     * @param \App\Models\User $model
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function query(User $model)
    {
         $model = User::whereNotNull('partner_referral_code');
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
                ->orderable(false),
                ['data' => 'display_name', 'name' => 'display_name', 'title' => __('message.name'),  'class' => 'text-capitalize'],
                ['data' => 'email', 'name' => 'email', 'title' => __('message.email')],
                ['data' => 'contact_number', 'name' => 'contact_number', 'title' => __('message.contact_number')],
                ['data' => 'created_at', 'name' => 'created_at', 'title' => __('message.created_at')],
                ['data' => 'last_actived_at', 'name' => 'last_actived_at', 'title' => __('message.last_actived_at')],
                ['data' => 'app_version', 'name' => 'app_version', 'title' => __('message.app_version')],
                ['data' => 'partner_referral_code', 'name' => 'partner_referral_code', 'title' => __('message.use_referral')],
        ];
    }
}

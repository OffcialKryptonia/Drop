<?php

namespace App\DataTables;

use App\Models\AdminLoginDevice;
use Illuminate\Support\Facades\DB;
use Yajra\DataTables\Html\Column;
use Yajra\DataTables\Services\DataTable;
use App\Traits\DataTableTrait;
use Illuminate\Support\Facades\Auth;

class AdminLoginDeviceDataTable extends DataTable
{
    use DataTableTrait;

    /**
     * Build DataTable class.
     */
    public function dataTable($query)
    {
        $auth_user = Auth::user();

        return datatables()
            ->eloquent($query)
            ->editColumn('created_at', function ($row) {
                return dateAgoFormate($row->created_at, true);
            })
            ->editColumn('login_at', function ($row) {
                return $row->login_at ? date('d-m-Y H:i:s', strtotime($row->login_at)) : '-';
            })
            ->editColumn('ip_address', function ($row) {
                $currentIp = request()->ip();
                $ip = is_array($row) ? ($row['ip_address'] ?? null) : $row->ip_address ?? null;

                if ($ip && $ip === $currentIp) {
                    return __('message.your_ip_address') . ' (' . e($ip) . ')';
                }
                return maskSensitiveInfo('ip_address', $ip);
            })
            ->addColumn('city', function ($row) {
                return optional($row->latestLoginHistory)->city ?? '-';
            })
            ->addColumn('region', function ($row) {
                return optional($row->latestLoginHistory)->region ?? '-';
            })
            ->addColumn('country', function ($row) {
                return optional($row->latestLoginHistory)->country ?? '-';
            })
            ->addColumn('browser', function ($row) {
                return optional($row->latestLoginHistory)->browser ?? '-';
            })
            ->addColumn('action', function($row){
                $id = $row->id;
                $ip_address = $row->ip_address;
                $is_active = $row->is_active;
                return view('device.action', compact('id', 'ip_address', 'is_active'))->render();
            })
            ->addIndexColumn()
            ->rawColumns(['action', 'ip_address']);
    }

    /**
     * Get query source of dataTable.
     */
    public function query(AdminLoginDevice $model)
    {
        return $model->newQuery()
            ->with([
                'user:id,display_name',
                'latestLoginHistory'
            ])
            ->where('is_active', 1)
            ->orderByDesc('login_at');
    }

    protected function getColumns()
    {
        return [
            Column::make('DT_RowIndex')
                ->searchable(false)
                ->title(__('message.srno'))
                ->orderable(false)
                ->width(60),
            ['data' => 'ip_address', 'name' => 'ip_address', 'title' => __('message.ip_address')],
            ['data' => 'city', 'name' => 'city', 'title' => __('message.city')],
            ['data' => 'region', 'name' => 'region', 'title' => __('message.region')],
            ['data' => 'country', 'name' => 'country', 'title' => __('message.country')],
            ['data' => 'browser', 'name' => 'browser', 'title' => __('message.browser')],
            ['data' => 'login_at', 'name' => 'login_at', 'title' => __('message.login_at')],
            ['data' => 'action', 'name' => 'action', 'title' => __('message.action'), 'orderable' => false, 'searchable' => false],
        ];
    }
}

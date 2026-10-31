<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\DriverDocument;
use App\Http\Resources\DriverPayoutReportResource;
use App\Models\DriverPayoutReport;
use Illuminate\Support\Facades\Log;

class DriverPayoutReportsController extends Controller
{
    public function getList(Request $request)
    {
        $baseQuery = DriverPayoutReport::where('driver_id', $request->driver_id);

        // Clone query for listing (so totals are not affected)
        $query = clone $baseQuery;

        $query->when(
            $request->filled('status') && $request->status !== 'null',
            function ($q) use ($request) {
                $q->where('status', $request->status);
            }
        );

        $per_page = 10;

        if ($request->filled('per_page')) {
            if (is_numeric($request->per_page)) {
                $per_page = (int) $request->per_page;
            }

            if ((int) $request->per_page === -1) {
                $per_page = $query->count();
            }
        }

        $reports = $query->orderByDesc('id')->paginate($per_page);
        $items   = DriverPayoutReportResource::collection($reports);

        $totalPayout = (clone $baseQuery)
            ->where('status', 'paid')
            ->sum('payout_amount');

        $totalPayoutCount = (clone $baseQuery)
            ->where('status', 'paid')
            ->count();

        $totalPendingPayout = (clone $baseQuery)
            ->where('status', 'pending')
            ->sum('payout_amount');

        $totalPendingPayoutCount = (clone $baseQuery)
            ->where('status', 'pending')
            ->count();

        $totalCount = (clone $baseQuery)->count();

        return json_custom_response([

            'total_payout'                => $totalPayout,
            'total_payout_count'          => $totalPayoutCount,
            'total_pending_payout'        => $totalPendingPayout,
            'total_pending_payout_count'  => $totalPendingPayoutCount,
            'total_count'                 => $totalCount,
            'pagination' => json_pagination_response($items),
            'data'       => $items,
        ]);
    }
}

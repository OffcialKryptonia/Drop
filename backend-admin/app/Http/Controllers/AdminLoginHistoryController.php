<?php

namespace App\Http\Controllers;

use App\DataTables\AdminLoginHistoryDataTable;
use App\Models\AdminLoginHistory;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;

class AdminLoginHistoryController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(AdminLoginHistoryDataTable $dataTable)
    {
        $pageTitle = __('message.list_form_title',['form' => __('message.admin_login_history')] );
        $auth_user = authSession();
        $assets = ['datatable'];
        return $dataTable->render('global.datatable', compact('assets','pageTitle','auth_user'));
    }

}

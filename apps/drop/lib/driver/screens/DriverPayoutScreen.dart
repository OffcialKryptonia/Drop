import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drop/driver/model/PayoutRecord.dart';
import 'package:drop/driver/network/RestApis.dart';
import 'package:drop/driver/screens/PDF_Screen.dart';
import 'package:drop/driver/screens/PayoutPdfScreen.dart';
import 'package:drop/driver/utils/Colors.dart';
import 'package:drop/driver/utils/Common.dart';
import 'package:drop/driver/utils/Constants.dart';
import 'package:drop/driver/utils/Extensions/app_common.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';

import '../main.dart';

class DriverPayoutListScreen extends StatefulWidget {
  const DriverPayoutListScreen({super.key});

  @override
  State<DriverPayoutListScreen> createState() => _DriverPayoutListScreenState();
}

class _DriverPayoutListScreenState extends State<DriverPayoutListScreen> {
  List<PayoutRecordList> _records = [];
  Pagination? _pagination;
  PayoutRecord? payoutRecord;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _selectedStatus = 'all';
  int _currentPage = 1;

  final ScrollController _scrollController = ScrollController();

  final List<String> _statusFilters = [
    'all',
    'pending',
    'processing',
    'paid',
  ];

  @override
  void initState() {
    super.initState();
    _loadPayouts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading) return;
    if (_pagination == null) return;
    if (_currentPage >= _pagination!.totalPages) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await getDriverPayout(
        page: nextPage,
        driverId: sharedPref.getInt(USER_ID) ?? 0,
        status: _selectedStatus == "all" ? null : _selectedStatus,
      );
      setState(() {
        payoutRecord = response;
        _records.addAll(response.data);
        _pagination = response.pagination;
        _currentPage = nextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadPayouts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _records = [];
      });
    }
    setState(() => _isLoading = true);

    try {
      final response = await getDriverPayout(
        page: _currentPage,
        driverId: sharedPref.getInt(USER_ID) ?? 0,
        status: _selectedStatus == "all" ? null : _selectedStatus,
      );
      setState(() {
        payoutRecord = response;
        _records = response.data;
        _pagination = response.pagination;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: () => _loadPayouts(reset: true),
        child: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: const BackButton(color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payout Reports', style: boldTextStyle(color: Colors.white)),
          Text(
            'Weekly earnings overview',
            style: secondaryTextStyle(color: Colors.white54, size: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _records.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.black,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null && _records.isEmpty) {
      return _buildErrorState();
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(child: _buildSummaryCard()),
        SliverToBoxAdapter(child: _buildFilterChips()),
        if (_records.isEmpty && !_isLoading)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == _records.length) {
                  return _buildLoadMoreIndicator();
                }
                return PayoutCard(record: _records[index], selectedStatus: _selectedStatus);
              },
              childCount: _records.length + 1,
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    'TOTAL PAYOUT',
                    style: boldTextStyle(
                      color: Colors.white38,
                      size: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  printAmountWidget(amount: '${payoutRecord!.totalPayout.toDouble().toStringAsFixed(2)}', color: Colors.white, size: 34)
                ],
              ),
              Column(
                children: [
                  Text(
                    'TOTAL PENDING PAYOUT',
                    style: boldTextStyle(
                      color: Colors.white38,
                      size: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  printAmountWidget(amount: '${payoutRecord!.totalPendingPayout.toDouble().toStringAsFixed(2)}', color: Colors.white, size: 34)
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryPill(
                label: 'Pending',
                value: '${payoutRecord!.totalPendingPayoutCount}',
                bg: Colors.white12,
                fg: Colors.white,
              ),
              const SizedBox(width: 10),
              _SummaryPill(
                label: 'Paid',
                value: '${payoutRecord!.totalPayoutCount}',
                bg: Colors.white,
                fg: Colors.black,
              ),
              const SizedBox(width: 10),
              _SummaryPill(
                label: 'Total',
                value: '${payoutRecord!.totalCount}',
                bg: Colors.white12,
                fg: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statusFilters.map((s) {
            final selected = _selectedStatus == s;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedStatus = s);
                _loadPayouts(reset: true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: selected ? Colors.black : const Color(0xFFDDDDDD),
                  ),
                ),
                child: Text(
                  _capitalize(s),
                  style: primaryTextStyle(
                    color: selected ? Colors.white : Colors.black54,
                    size: 12,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    final hasMore = _pagination != null && _currentPage < _pagination!.totalPages;

    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No more records',
            style: secondaryTextStyle(size: 12, color: Colors.black38),
          ),
        ),
      );
    }

    return const SizedBox(height: 24);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, size: 48, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          Text(
            'No payout records found',
            style: secondaryTextStyle(size: 16, weight: FontWeight.w600, color: Colors.black),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to refresh',
            style: secondaryTextStyle(size: 13, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black38),
            const SizedBox(height: 16),
            Text(
              'Failed to load payouts',
              style: secondaryTextStyle(size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: secondaryTextStyle(size: 12, color: Colors.black45),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _loadPayouts(reset: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Try Again',
                  style: secondaryTextStyle(color: Colors.white, weight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Payout Card ──────────────────────────────────────────────────────────────

class PayoutCard extends StatelessWidget {
  final PayoutRecordList record;
  final String selectedStatus;

  const PayoutCard({super.key, required this.record, required this.selectedStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Icon(Icons.calendar_month_rounded, size: 18, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weekRange(record.weekStartDate.toString(), record.weekEndDate.toString()),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Generated ${_formatDate(record.generatedAt.toString())}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                if (selectedStatus == "all") _StatusBadge(status: record.status),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey[200]),

          const SizedBox(height: 16),

          // ── Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatBox(
                  label: 'Total Fare',
                  value: '${record.totalFare.toStringAsFixed(2)}',
                ),
                _vDivider(),
                _StatBox(
                  label: 'Commission',
                  value: '${record.totalCommission.toStringAsFixed(2)}',
                  valueColor: Colors.black45,
                ),
                _vDivider(),
                _StatBox(
                  label: 'Tips',
                  value: record.driverTips > 0 ? '${record.driverTips.toStringAsFixed(2)}' : '—',
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Payout highlight
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Text(
                  'Payout Amount',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Text(
                //   '${record.payoutAmount.toStringAsFixed(2)}',
                //   style: const TextStyle(
                //     color: Colors.white,
                //     fontSize: 20,
                //     fontWeight: FontWeight.w800,
                //     letterSpacing: -0.5,
                //   ),
                // ),
                printAmountWidget(
                  amount: '${record.payoutAmount.toDouble().toStringAsFixed(2)}',
                  color: Colors.white,
                  size: 20,
                  weight: FontWeight.w800,
                ),
              ],
            ),
          ),

          // ── Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 12, color: Colors.black38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Generated ${DateFormat('MMM d, yyyy h:mm a').format(record.generatedAt.toLocal())}',
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ),
                InkWell(
                  onTap: () {
                    launchScreen(
                        context,
                        Payoutpdfscreen(
                          invoice: record.receivedDocument!,
                        ),
                        pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      "View Document",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 36,
        color: const Color(0xFFEEEEEE),
      );
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status.toLowerCase()) {
      'paid' => ('Paid', Colors.black, Colors.white, Icons.check_rounded),
      'processing' => ('Processing', const Color(0xFFF0F0F0), Colors.black, Icons.sync_rounded),
      'failed' => ('Failed', Colors.black, Colors.white, Icons.close_rounded),
      _ => ('Pending', const Color(0xFFF0F0F0), Colors.black, Icons.hourglass_empty_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.$2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.$4, size: 11, color: config.$3),
          const SizedBox(width: 4),
          Text(
            config.$1,
            style: TextStyle(
              color: config.$3,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatBox({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          // Text(
          //   value,
          //   style: TextStyle(
          //     fontSize: 15,
          //     fontWeight: FontWeight.w700,
          //     color: valueColor ?? Colors.black,
          //   ),
          // ),
          printAmountWidget(amount: '${value.toDouble().toStringAsFixed(2)}', color: valueColor ?? Colors.black, size: 15),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color fg;

  const _SummaryPill({required this.label, required this.value, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _weekRange(String start, String end) => '${_formatDate(start)} – ${_formatDate(end)}';

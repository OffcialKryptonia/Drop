import '../manage_imports.dart';

class CoinWalletListScreen extends StatefulWidget {
  const CoinWalletListScreen({super.key});

  @override
  State<CoinWalletListScreen> createState() => _CoinWalletListScreenState();
}

class _CoinWalletListScreenState extends State<CoinWalletListScreen> {
  final ScrollController _scrollController = ScrollController();

  List<CoinWalletModel> _coinList = [];
  num _totalCoins = 0;
  int _page = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchList();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore && !appStore.isLoading && _page < _totalPages) {
      _page++;
      _fetchList(isLoadMore: true);
    }
  }

  Future<void> _fetchList({bool isLoadMore = false}) async {
    if (isLoadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      appStore.setLoading(true);
    }

    await getCoinWalletList(page: _page).then((value) {
      appStore.setLoading(false);
      _isLoadingMore = false;

      _totalPages = value.pagination?.totalPages ?? 1;
      _page = value.pagination?.currentPage ?? 1;
      _totalCoins = value.totalCoins ?? 0;

      if (_page == 1) _coinList.clear();
      _coinList.addAll(value.data ?? []);

      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      setState(() => _isLoadingMore = false);
      toast(error.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Coin Wallet',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Observer(
        builder: (_) => Stack(
          children: [
            Column(
              children: [
                _TotalCoinsBanner(totalCoins: _totalCoins),
                Expanded(
                  child: _coinList.isNotEmpty
                      ? ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _coinList.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _coinList.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            return _CoinTransactionCard(
                              item: _coinList[index],
                              index: index,
                            );
                          },
                        )
                      : !appStore.isLoading
                          ? emptyWidget()
                          : const SizedBox(),
                ),
              ],
            ),
            loaderWidget().center().visible(appStore.isLoading),
          ],
        ),
      ),
    );
  }
}

/// ── Top banner showing total coins ──
class _TotalCoinsBanner extends StatelessWidget {
  final num totalCoins;

  const _TotalCoinsBanner({required this.totalCoins});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: boxDecorationWithShadow(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        backgroundColor: primaryColor,
        blurRadius: 16,
        offset: const Offset(0, 4),
        spreadRadius: 0,
        shadowColor: primaryColor.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              ic_coin, // Ensure you have a pattern image
              fit: BoxFit.cover,
              height: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Coins',
                  style: secondaryTextStyle(color: Colors.white70, size: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalCoins',
                  style: boldTextStyle(color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
              const SizedBox(height: 4),
              Text(
                'Coins',
                style: secondaryTextStyle(color: Colors.white70, size: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── Individual transaction card ──
class _CoinTransactionCard extends StatelessWidget {
  final CoinWalletModel item;
  final int index;

  const _CoinTransactionCard({required this.item, required this.index});

  bool get _isCredit => (item.type ?? '').toLowerCase() == 'credit';

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 350),
      delay: const Duration(milliseconds: 50),
      child: SlideAnimation(
        verticalOffset: 24,
        child: FadeInAnimation(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: boxDecorationWithRoundedCorners(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isCredit ? Colors.green.withValues(alpha: 0.25) : Colors.red.withValues(alpha: 0.25),
              ),
              backgroundColor: _isCredit ? Colors.green.withValues(alpha: 0.04) : Colors.red.withValues(alpha: 0.04),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCredit ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    _isCredit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                    color: _isCredit ? Colors.green : Colors.red,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCredit ? 'Coins Earned' : 'Coins Redeemed',
                        style: boldTextStyle(size: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 12, color: textSecondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Ride #${item.rideId ?? '-'}',
                            style: secondaryTextStyle(size: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: textSecondaryColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.scratchTime ?? item.createdAt ?? '-',
                              style: secondaryTextStyle(size: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isCredit ? '+' : '-',
                          style: boldTextStyle(
                            size: 18,
                            color: _isCredit ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(
                          '${item.coins ?? 0}',
                          style: boldTextStyle(
                            size: 22,
                            color: _isCredit ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          ic_coin,
                          height: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'coins',
                          style: secondaryTextStyle(size: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

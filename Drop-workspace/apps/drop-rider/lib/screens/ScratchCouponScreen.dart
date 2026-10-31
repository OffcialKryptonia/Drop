import '../manage_imports.dart';
import 'package:scratcher/scratcher.dart';

class ScratchCouponScreen extends StatefulWidget {
  final num? coin_earnings;
  final int? ride_id;

  ScratchCouponScreen({this.coin_earnings, this.ride_id});

  @override
  ScratchCouponScreenState createState() => ScratchCouponScreenState();
}

class ScratchCouponScreenState extends State<ScratchCouponScreen> {
  final GlobalKey<ScratcherState> _scratchKey = GlobalKey<ScratcherState>();

  double _scratchPercent = 0.0;
  bool _isRevealed = false;

  static const double _revealThreshold = 40.0;

  void _onScratchUpdate(double value) {
    setState(() {
      _scratchPercent = value;
    });
  }

  void _onThreshold() {
    setState(() => _isRevealed = true);
    _scratchKey.currentState?.reveal(
      duration: const Duration(milliseconds: 400),
    );
  }

  Future<void> _onDone() async {
    if (!_isRevealed) {
      toast('Please scratch the coupon to reveal your reward!');
      return;
    }

    appStore.setLoading(true);

    await saveCoinWallet({
      'ride_id': widget.ride_id,
      'coins': widget.coin_earnings,
    }).then((value) {
      appStore.setLoading(false);
      toast(value.message.validate());
      launchScreen(
        getContext,
        DashBoardScreen(),
        isNewTask: true,
        pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
      );
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        launchScreen(getContext, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () {
              launchScreen(getContext, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
            },
          ),
          title: Text(
            'Your Reward',
            style: boldTextStyle(color: Colors.white, size: 20),
          ),
          centerTitle: true,
        ),
        body: Observer(
          builder: (_) => Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                // decoration: BoxDecoration(
                //   gradient: LinearGradient(
                //     begin: Alignment.topLeft,
                //     end: Alignment.bottomRight,
                //     colors: [
                //       primaryColor.withValues(alpha: 0.15),
                //       Colors.white,
                //       primaryColor.withValues(alpha: 0.05),
                //     ],
                //   ),
                // ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.redeem_rounded, color: primaryColor, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scratch & Win!',
                        style: boldTextStyle(size: 26, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reveal your exclusive reward below',
                        style: secondaryTextStyle(size: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Container(
                          width: double.infinity,
                          decoration: boxDecorationWithShadow(
                            borderRadius: BorderRadius.circular(24),
                            backgroundColor: Colors.white,
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                            shadowColor: Colors.black.withValues(alpha: 0.08),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 6,
                                width: 60,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (widget.coin_earnings == 0) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Oops!',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Better Luck',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                                Text(
                                  'Next Time!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ] else ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Scratcher(
                                    key: _scratchKey,
                                    brushSize: 50,
                                    threshold: _revealThreshold,
                                    color: Colors.grey.shade300,
                                    image: Image.asset(
                                      ic_scratch, // Ensure you have a pattern image
                                      fit: BoxFit.cover,
                                    ),
                                    onThreshold: _onThreshold,
                                    onChange: _onScratchUpdate,
                                    child: Container(
                                      height: 200,
                                      width: 250,
                                      alignment: Alignment.center,
                                      color: Colors.white,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            ic_coin, // Ensure you have a pattern image
                                            fit: BoxFit.cover,
                                            height: 48,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${widget.coin_earnings ?? 0}',
                                            style: boldTextStyle(size: 32, color: primaryColor),
                                          ),
                                          Text('Coins Won!', style: secondaryTextStyle()),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (!_isRevealed)
                                Text(
                                  '${(100 - (_scratchPercent * 100 / _revealThreshold)).clamp(0, 100).toInt()}% more to go',
                                  style: secondaryTextStyle(size: 12),
                                ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      AppButtonWidget(
                        text: _isRevealed ? "CLAIM REWARD" : "SCRATCH TO REVEAL",
                        textStyle: boldTextStyle(color: Colors.white),
                        color: _isRevealed ? primaryColor : Colors.grey,
                        width: context.width() * 0.7,
                        onTap: _onDone,
                      ),
                    ],
                  ),
                ),
              ),
              if (appStore.isLoading) Loader(),
            ],
          ),
        ),
      ),
    );
  }
}

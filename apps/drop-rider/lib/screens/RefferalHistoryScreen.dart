import '../manage_imports.dart';

class ReferralHistoryScreen extends StatefulWidget {
  const ReferralHistoryScreen({super.key});

  @override
  State<ReferralHistoryScreen> createState() => _ReferralHistoryScreenState();
}

class _ReferralHistoryScreenState extends State<ReferralHistoryScreen> {
  List<UserData> referralList = [];
  ScrollController scrollController = ScrollController();
  int page = 1;
  int totalPage = 1;

  @override
  void initState() {
    super.initState();
    init();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
              scrollController.position.maxScrollExtent &&
          !appStore.isLoading) {
        if (page < totalPage) {
          page++;
          appStore.setLoading(true);
          init();
        }
      }
    });
  }

  void init() {
    getReferralListApiCall();
  }

  Future<void> getReferralListApiCall() async {
    appStore.setLoading(true);
    await getReferralList(page: page).then((value) {
      appStore.setLoading(false);
      totalPage = value.pagination!.totalPages??1;
      page = value.pagination!.currentPage??1;
      if (page == 1) {
        referralList.clear();
      }
      value.data!.forEach((element) {
        referralList.add(element);
      });
      appStore.setLoading(false);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${language.lblReferralHistory}",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Observer(builder: (context) {
        return Stack(
          children: [
            referralList.isNotEmpty
                ? ListView.builder(
                    itemCount: referralList.length,
                    shrinkWrap: true,
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    itemBuilder: (context, index) {
                      UserData item = referralList[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(8),
                        decoration: boxDecorationWithRoundedCorners(
                            borderRadius: BorderRadius.circular(defaultRadius),
                            border: Border.all(
                                color: appStore.isDarkMode
                                    ? Colors.grey.withValues(alpha: 0.3)
                                    : primaryColor.withValues(alpha: 0.4)),
                            backgroundColor: Colors.transparent),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text('${language.name} : ',
                                    style: secondaryTextStyle()),
                                Row(
                                  children: [
                                    Text(item.displayName.toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: primaryTextStyle(
                                                weight: FontWeight.w500))
                                        .expand(),
                                    Text(
                                        " (${item.userType.toString().toUpperCase()})",
                                        style: secondaryTextStyle(size: 12)),
                                  ],
                                ).expand(),
                              ],
                            ),
                            8.height,
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text('${language.email} : ',
                                    style: secondaryTextStyle()),
                                Text(item.email.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: primaryTextStyle(
                                            weight: FontWeight.w500))
                                    .expand(),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : !appStore.isLoading
                    ? emptyWidget()
                    : SizedBox(),
            loaderWidget().center().visible(appStore.isLoading),
          ],
        );
      }),
    );
  }
}

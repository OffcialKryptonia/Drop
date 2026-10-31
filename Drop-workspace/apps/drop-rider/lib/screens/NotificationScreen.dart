import '../manage_imports.dart';

class NotificationScreen extends StatefulWidget {
  @override
  NotificationScreenState createState() => NotificationScreenState();
}

class NotificationScreenState extends State<NotificationScreen>
    with TickerProviderStateMixin {
  ScrollController scrollController = ScrollController();
  int currentPage = 1;

  bool mIsLastPage = false;
  List<NotificationData> notificationData = [];

  @override
  void initState() {
    super.initState();
    init();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (!mIsLastPage) {
          appStore.setLoading(true);

          currentPage++;
          setState(() {});

          init();
        }
      }
    });
    afterBuildCreated(() => appStore.setLoading(true));
  }

  void init() async {
    getNotification(page: currentPage).then((value) {
      appStore.setLoading(false);
      mIsLastPage = value.notificationData!.length < currentPage;
      if (currentPage == 1) {
        notificationData.clear();
      }
      notificationData.addAll(value.notificationData!);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      log(error);
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(language.notification,
            style: boldTextStyle(color: appTextPrimaryColorWhite)),
      ),
      body: Observer(builder: (context) {
        return Stack(
          children: [
            notificationData.isNotEmpty
                ? ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.all(16),
                    itemCount: notificationData.length,
                    itemBuilder: (_, index) {
                      NotificationData data = notificationData[index];
                      return inkWellWidget(
                        onTap: () {
                          if (data.data!.type == COMPLAIN_COMMENT) {
                            launchScreen(
                                context,
                                ComplaintListScreen(
                                    complaint: data.data!.complaintId!));
                          } else if (data.data!.subject! == 'Completed') {
                            launchScreen(context,
                                RideDetailScreen(orderId: data.data!.id!));
                          }
                        },
                        child: Container(
                          // color: data.readAt==null?Colors.grey.shade200:null,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // if(data.readAt==null)
                              // Padding(
                              //   padding:EdgeInsets.symmetric(horizontal: 8.0),
                              //   child: Lottie.asset(messageDetect, width: 18, height: 18, fit: BoxFit.cover),
                              // ),
                              if (data.data != null &&
                                  data.data!.type != "push_notification")
                                Container(
                                  padding: EdgeInsets.all(8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    border: Border.all(
                                        color: dividerColor
                                            .withValues(alpha: 0.5)
                                            .withValues(alpha: 0.5)),
                                    borderRadius: radius(),
                                  ),
                                  child: ImageIcon(
                                      AssetImage(statusTypeIcon(
                                          type: data.data!.type)),
                                      color: primaryColor,
                                      size: 26),
                                ),
                              if (data.data != null &&
                                  data.data!.type != "push_notification")
                                SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        data.data != null &&
                                                data.data!.type !=
                                                    "push_notification" &&
                                                data.data!.id != null
                                            ? Expanded(
                                                child: Text(
                                                    '${language.rideId} #${data.data!.id} ${data.data!.subject}',
                                                    style: boldTextStyle(
                                                        size: 14)))
                                            : Expanded(
                                                child: Text(
                                                    "${data.data!.subject}",
                                                    style: boldTextStyle(
                                                        size: 14))),
                                        SizedBox(width: 4),
                                        // Text(data.createdAt.validate(), style: secondaryTextStyle()),
                                        // if(data.readAt==null)
                                        // Lottie.asset(messageDetect, width: 18, height: 18, fit: BoxFit.cover)
                                        Row(
                                          children: [
                                            Text(data.createdAt.validate(),
                                                style: secondaryTextStyle()),
                                            if (data.isRead == 0)
                                              Lottie.asset(
                                                messageDetect,
                                                height: 20,
                                                width: 20,
                                                fit: BoxFit.cover,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text('${data.data!.message}',
                                        style: primaryTextStyle(size: 14)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) {
                      return Divider(height: 20);
                    },
                  )
                : !appStore.isLoading
                    ? emptyWidget()
                    : SizedBox(),
            Visibility(visible: appStore.isLoading, child: loaderWidget()),
          ],
        );
      }),
    );
  }
}

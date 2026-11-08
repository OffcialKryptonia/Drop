import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';
import 'package:drop/driver/utils/Extensions/int_extensions.dart';
import 'package:drop/driver/utils/Images.dart';

import '../../main.dart';
import '../../network/RestApis.dart';
import '../../utils/Colors.dart';
import '../../utils/Common.dart';
import '../../utils/Extensions/app_common.dart';
import '../model/NotificationListModel.dart';
import '../utils/Constants.dart';
import 'ComplaintListScreen.dart';
import 'RideDetailScreen.dart';
import 'package:lottie/lottie.dart' as lt;

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
            style: boldTextStyle(color: Colors.white)),
      ),
      body: Observer(builder: (context) {
        return Stack(
          children: [
            if (notificationData.isNotEmpty)
              ListView.separated(
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
                        launchScreen(
                            context, RideDetailScreen(orderId: data.data!.id!));
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data.data != null &&
                            data.data!.type != "push_notification" &&
                            data.data!.type != "document_approved")
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
                                AssetImage(
                                    statusTypeIcon(type: data.data!.type)),
                                color: primaryColor,
                                size: 26),
                          ),
                        if (data.data != null &&
                            data.data!.type != "push_notification" &&
                            data.data!.type != "document_approved")
                          SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  data.data != null &&
                                          data.data!.type !=
                                              "push_notification" &&
                                          data.data!.type !=
                                              "document_approved" &&
                                          data.data!.id != null &&
                                          data.data!.type != DOC_APPROVED &&
                                          data.data!.type != DOC_REJECTED
                                      ? Expanded(
                                          child: Text(
                                              '${language.rideId} #${data.data!.id} ${data.data!.subject}',
                                              style: boldTextStyle(size: 14)))
                                      : Expanded(
                                          child: Text("${data.data!.subject}",
                                              style: boldTextStyle(size: 14))),
                                  SizedBox(width: 8),
                                  Row(
                                    children: [
                                      Text(data.createdAt.validate(),
                                          style: secondaryTextStyle()),
                                      8.width,
                                      if (data.isRead == 0)
                                        // Container(
                                        //   height: 6,
                                        //   width: 6,
                                        //   decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                                        // )
                                        lt.Lottie.asset(
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
                  );
                },
                separatorBuilder: (context, index) {
                  return Divider(height: 20);
                },
              )
            else
              !appStore.isLoading ? emptyWidget() : SizedBox(),
            Visibility(visible: appStore.isLoading, child: loaderWidget()),
          ],
        );
      }),
    );
  }
}

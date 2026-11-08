import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:drop/driver/utils/Colors.dart';
import 'package:drop/driver/utils/Common.dart';
import 'package:drop/driver/utils/Extensions/ResponsiveWidget.dart';
import 'package:drop/driver/utils/Extensions/int_extensions.dart';

import '../main.dart';
import '../model/rewardsListModel.dart';
import '../network/RestApis.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Extensions/decorations.dart';

class RewardListScreen extends StatefulWidget {
  const RewardListScreen({super.key});

  @override
  State<RewardListScreen> createState() => _RewardListScreenState();
}

class _RewardListScreenState extends State<RewardListScreen> {
  List<RewardsModel> rewardsList = [];
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
    getRewardsListApi();
  }

  Future<void> getRewardsListApi() async {
    appStore.setLoading(true);
    await getRewardsList(page: page).then((value) {
      appStore.setLoading(false);
      totalPage = value.pagination!.totalPages.validate(value: 1);
      page = value.pagination!.currentPage.validate(value: 1);
      if (page == 1) {
        rewardsList.clear();
      }
      value.data!.forEach((element) {
        rewardsList.add(element);
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
          language.earned_reward,
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Observer(builder: (context) {
        return Stack(
          children: [
            rewardsList.isNotEmpty
                ? ListView.builder(
                    itemCount: rewardsList.length,
                    shrinkWrap: true,
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    itemBuilder: (context, index) {
                      RewardsModel item = rewardsList[index];
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("# ${item.orderId.validate().toString()}",
                                    style: boldTextStyle()),
                                printAmountWidget(
                                    amount: "${item.amount}",
                                    color: Colors.green),
                              ],
                            ),
                            8.height,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${language.availableBalance} : ',
                                    style: secondaryTextStyle()),
                                printAmountWidget(
                                    amount: "${item.walletBalance}",
                                    weight: FontWeight.w100),
                              ],
                            ),
                            8.height,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${language.orderedDate} :',
                                    style: secondaryTextStyle()),
                                Text(
                                    "${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.parse(item.createdAt.toString()).toLocal())}",
                                    style: secondaryTextStyle()),
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

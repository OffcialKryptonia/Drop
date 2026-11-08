import '../manage_imports.dart';

class RideDetailScreen extends StatefulWidget {
  final int orderId;

  RideDetailScreen({required this.orderId});

  @override
  RideDetailScreenState createState() => RideDetailScreenState();
}

class RideDetailScreenState extends State<RideDetailScreen> {
  RiderModel? riderModel;
  List<RideHistory> rideHistory = [];
  DriverRatting? driverRatting;
  DriverRatting? riderRatting;
  ComplaintModel? complaintData;
  Payment? payment;
  UserData? userData;
  String? invoice_name;
  String? invoice_url;
  bool? isChatHistory;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    Future.delayed(
      Duration.zero,
      () {
        appStore.setLoading(true);
      },
    );
    isChatHistory = await chatMessageService.isRideChatHistory(rideId: widget.orderId.toString());
    await rideDetail(orderId: widget.orderId).then((value) {
      invoice_name = value.invoice_name!;
      invoice_url = value.invoice_url!;
      riderModel = value.data!;
      riderModel!.ride_has_bids = value.ride_has_bids;
      rideHistory.addAll(value.rideHistory!);
      if (value.driverRatting != null) {
        driverRatting = value.driverRatting!;
      }
      if (value.riderRatting != null) {
        riderRatting = value.riderRatting;
      }
      complaintData = value.complaintModel;
      payment = value.payment;
      getDriverDetail(userId: riderModel!.driverId).then((value) {
        userData = value.data!;
        setState(() {});

        appStore.setLoading(false);
      }).catchError((error) {
        appStore.setLoading(false);
        log(error.toString());
      });
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
    // setState(() {});
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    // ignore:deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          return true;
        } else {
          launchScreen(context, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
          return false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: Text(riderModel != null ? "${language.lblRide} #${riderModel!.id}" : "", style: boldTextStyle(color: Colors.white)),
          actions: [
            if (riderModel != null)
              IconButton(
                  onPressed: () {
                    if (riderModel == null) {
                      return;
                    }
                    launchScreen(
                      context,
                      ComplaintScreen(
                        driverRatting: driverRatting ?? DriverRatting(),
                        complaintModel: complaintData,
                        riderModel: riderModel,
                      ),
                      pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
                    );
                  },
                  icon: Icon(MaterialCommunityIcons.head_question))
          ],
        ),
        body: Stack(
          children: [
            if (riderModel != null)
              SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    driverInformationComponent(),
                    SizedBox(height: 12),
                    if (riderModel!.otherRiderData != null) otherRiderInfoComponent(),
                    if (riderModel!.otherRiderData != null) SizedBox(height: 12),
                    if (driverRatting!.comment != null) driverRatingDetailWidget(),
                    if (driverRatting!.comment != null) SizedBox(height: 12),
                    addressComponent(),
                    SizedBox(height: 12),
                    priceDetailComponent(),
                    if (riderModel!.extraChargesAmount != 0 && riderModel!.extraCharges!.isNotEmpty) ...[
                      SizedBox(height: 12),
                      extraChargeWidget(),
                    ],
                    SizedBox(height: 12),
                    paymentDetail(),
                    Visibility(
                      visible: Navigator.canPop(context) == false,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: AppButtonWidget(
                          text: language.continueNewRide,
                          width: MediaQuery.of(context).size.width,
                          onTap: () {
                            launchScreen(context, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                          },
                        ),
                      ),
                    )
                  ],
                ),
              ),
            Observer(builder: (context) {
              if (!appStore.isLoading && riderModel == null) return emptyWidget();
              return Visibility(
                visible: appStore.isLoading,
                child: loaderWidget(),
              );
            })
          ],
        ),
      ),
    );
  }

  Widget addressComponent() {
    return Container(
      decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: dividerColor.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Ionicons.calendar, color: textSecondaryColorGlobal, size: 16),
                  SizedBox(width: 4),
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('${printDate(riderModel!.createdAt.validate())}', style: primaryTextStyle(size: 14)),
                  ),
                ],
              ),
              inkWellWidget(
                onTap: () {
                  if (invoice_url.validate().isEmpty) {
                    return toast("Something wrong");
                  }
                  launchScreen(
                      context,
                      PDFViewer(
                        invoice: invoice_url!,
                        filename: invoice_name,
                      ),
                      pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(language.invoice, style: primaryTextStyle(color: primaryColor)),
                    SizedBox(width: 4),
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(MaterialIcons.file_download, size: 18, color: primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text('${language.lblDistance} ${riderModel!.distance!.toStringAsFixed(2)} ${riderModel!.distanceUnit.toString()}', style: boldTextStyle(size: 14)),
          SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.near_me, color: Colors.green, size: 18),
                  SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (riderModel!.startTime != null) Text(riderModel!.startTime != null ? printDate(riderModel!.startTime!) : '', style: secondaryTextStyle(size: 12)),
                        if (riderModel!.startTime != null) SizedBox(height: 4),
                        Text(riderModel!.startAddress.validate(), style: primaryTextStyle(size: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(width: 10),
                  SizedBox(
                    height: 30,
                    child: DottedLine(
                      direction: Axis.vertical,
                      lineLength: double.infinity,
                      lineThickness: 1,
                      dashLength: 2,
                      dashColor: primaryColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red, size: 18),
                  SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (riderModel!.endTime != null) Text(riderModel!.endTime != null ? printDate(riderModel!.endTime!) : '', style: secondaryTextStyle(size: 12)),
                        if (riderModel!.endTime != null) SizedBox(height: 4),
                        Text(riderModel!.endAddress.validate(), style: primaryTextStyle(size: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              if (riderModel!.multiDropLocation != null && riderModel!.multiDropLocation!.isNotEmpty)
                Row(
                  children: [
                    SizedBox(width: 8),
                    SizedBox(
                      height: 24,
                      child: DottedLine(
                        direction: Axis.vertical,
                        lineLength: double.infinity,
                        lineThickness: 1,
                        dashLength: 2,
                        dashColor: primaryColor,
                      ),
                    ),
                  ],
                ),
              if (riderModel!.multiDropLocation != null && riderModel!.multiDropLocation!.isNotEmpty)
                AppButtonWidget(
                  textColor: primaryColor,
                  color: Colors.white,
                  // margin: EdgeInsets.all(4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  height: 30,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon(Icons.location_on, color: Colors.red, size: 18),
                      Icon(
                        Icons.add,
                        color: primaryColor,
                        size: 12,
                      ),
                      Text(
                        language.viewMore,
                        style: primaryTextStyle(size: 14),
                      ),
                    ],
                  ),
                  onTap: () {
                    showOnlyDropLocationsDialog(context, riderModel!.multiDropLocation!);
                  },
                )
            ],
          ),
          SizedBox(height: 16),
          inkWellWidget(
            onTap: () {
              launchScreen(context, RideHistoryScreen(rideHistory: rideHistory), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(language.viewHistory, style: secondaryTextStyle()),
                Icon(Entypo.chevron_right, color: dividerColor, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget paymentDetail() {
    return Container(
      decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: dividerColor.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(language.paymentDetails, style: boldTextStyle(size: 16)),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(language.via, style: secondaryTextStyle()),
              Text(paymentStatus(riderModel!.paymentType.validate()), style: boldTextStyle()),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(language.status, style: secondaryTextStyle()),
              Text(paymentStatus(riderModel!.paymentStatus.validate()), style: boldTextStyle(color: paymentStatusColor(riderModel!.paymentStatus.validate()))),
            ],
          ),
        ],
      ),
    );
  }

  Widget otherRiderInfoComponent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: dividerColor.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(language.riderInformation, style: boldTextStyle()),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Ionicons.person_outline, size: 18),
                  SizedBox(width: 8),
                  Text(riderModel!.otherRiderData!.name.validate(), style: primaryTextStyle()),
                ],
              ),
              SizedBox(height: 10),
            ],
          ),
        )
      ],
    );
  }

  Widget driverRatingDetailWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: dividerColor.withValues(alpha: 0.5).withValues(alpha: 0.5)),
            borderRadius: radius(),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${language.riderReview}", style: boldTextStyle()),
              SizedBox(height: 16),
              Row(
                children: [
                  Text(riderRatting?.comment ?? "", style: primaryTextStyle()).expand(),
                  20.width,
                  RatingBar.builder(
                    direction: Axis.horizontal,
                    glow: false,
                    allowHalfRating: false,
                    ignoreGestures: true,
                    wrapAlignment: WrapAlignment.spaceBetween,
                    itemCount: 5,
                    itemSize: 16,
                    initialRating: double.parse(riderRatting!.rating.toString()),
                    itemPadding: EdgeInsets.symmetric(horizontal: 0),
                    itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: (rating) {
                      //
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget driverInformationComponent() {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            contentPadding: EdgeInsets.zero,
            content: AboutWidget(userData: userData),
          ),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          border: Border.all(color: dividerColor.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(defaultRadius),
        ),
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(language.aboutDriver, style: boldTextStyle(size: 16)),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        contentPadding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        content: AboutWidget(userData: userData),
                      ),
                    );
                  },
                  child: Icon(Icons.info_outline),
                )
              ],
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(defaultRadius),
                  child: commonCachedNetworkImage(riderModel!.driverProfileImage.validate(), height: 50, width: 50, fit: BoxFit.cover),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(riderModel!.driverName.validate(), style: boldTextStyle()),
                    // SizedBox(height: 2),
                    if (riderModel!.status != COMPLETED) Text(riderModel!.driverContactNumber.validate()),
                    SizedBox(height: 1),
                    if (driverRatting != null)
                      RatingBar.builder(
                        direction: Axis.horizontal,
                        glow: false,
                        allowHalfRating: false,
                        ignoreGestures: true,
                        wrapAlignment: WrapAlignment.spaceBetween,
                        itemCount: 5,
                        itemSize: 16,
                        initialRating: double.parse(driverRatting!.rating.toString()),
                        itemPadding: EdgeInsets.symmetric(horizontal: 0),
                        itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) {
                          //
                        },
                      ),
                    if (driverRatting != null) SizedBox(height: 2),
                  ],
                ),
                SizedBox(width: 12),
                Spacer(),
                if (riderModel!.status != COMPLETED)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: InkWell(
                      onTap: () {
                        launchUrl(Uri.parse('tel:${riderModel!.driverContactNumber.validate()}'), mode: LaunchMode.externalApplication);
                      },
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: dividerColor), borderRadius: radius(10)),
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.call,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                Visibility(
                  visible: isChatHistory == true,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: InkWell(
                      onTap: () {
                        launchScreen(context, ChatScreen(userData: null, ride_id: riderModel!.id!, show_history: true));
                        // launchUrl(Uri.parse('tel:${riderModel!.riderContactNumber}'), mode: LaunchMode.externalApplication);
                      },
                      child: Container(
                          decoration: BoxDecoration(border: Border.all(color: dividerColor), borderRadius: radius(10)),
                          padding: EdgeInsets.all(4),
                          child: Image.asset(
                            ic_chat_history,
                            width: 18,
                            height: 18,
                            color: Colors.green,
                          )
                          // child: Icon(Icons.message_sharp, size: 18, color: Colors.green),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget priceDetailComponent() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: dividerColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(defaultRadius),
      ),
      padding: EdgeInsets.all(12),
      child: riderModel!.ride_has_bids == 1
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(language.priceDetail, style: boldTextStyle(size: 16)),
                // SizedBox(height: 12),
                // totalCount(title: language.amount, amount: riderModel!.surgeCharge != null && riderModel!.surgeCharge! > 0 ? riderModel!.subtotal! - riderModel!.surgeCharge! : riderModel!.subtotal!, space: 8),
                // if (riderModel!.couponData != null && riderModel!.couponDiscount != 0)
                //   Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       Text(language.couponDiscount, style: secondaryTextStyle()),
                //       Row(
                //         children: [Text("-", style: boldTextStyle(color: Colors.green, size: 14)), printAmountWidget(amount: '${riderModel!.couponDiscount!.toStringAsFixed(digitAfterDecimal)}', color: Colors.green, size: 14, weight: FontWeight.normal)],
                //       ),
                //     ],
                //   ),
                // if (riderModel!.couponData != null && riderModel!.couponDiscount != 0) SizedBox(height: 8),
                // if (riderModel!.tips != null) totalCount(title: language.tip, amount: riderModel!.tips),
                // if (riderModel!.extraCharges!.isNotEmpty)
                //   SizedBox(
                //     height: 8,
                //   ),
                // if (riderModel!.extraCharges!.isNotEmpty)
                //   Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(language.additionalFees, style: boldTextStyle()),
                //       ...riderModel!.extraCharges!.map((e) {
                //         return Padding(
                //           padding: EdgeInsets.only(top: 8, bottom: 0),
                //           child: Row(
                //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //             children: [Text(e.key.validate().capitalizeFirstLetter(), style: secondaryTextStyle()), printAmountWidget(amount: e.value!.toStringAsFixed(digitAfterDecimal), size: 14)],
                //           ),
                //         );
                //       }).toList()
                //     ],
                //   ),
                // Divider(height: 16, thickness: 1),
                // riderModel!.tips != null
                //     ? riderModel!.extraChargesAmount != null
                //         ? totalCount(title: language.total, amount: riderModel!.subtotal! + riderModel!.tips! + riderModel!.extraChargesAmount!, isTotal: true)
                //         : totalCount(title: language.total, amount: riderModel!.subtotal! + riderModel!.tips!, isTotal: true)
                //     : riderModel!.extraChargesAmount != null
                //         ? totalCount(title: language.total, amount: riderModel!.subtotal! + riderModel!.extraChargesAmount!, isTotal: true)
                //         : totalCount(title: language.total, amount: riderModel!.subtotal, isTotal: true),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(language.totalFare, style: boldTextStyle(size: 24)), printAmountWidget(amount: '${riderModel!.totalAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.bold, size: 24)],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(language.priceDetail, style: boldTextStyle(size: 16)),
                // SizedBox(height: 12),
                // riderModel!.subtotal! <= riderModel!.minimumFare!
                //     ? totalCount(title: language.minimumFare, amount: riderModel!.minimumFare)
                //     : Column(
                //         children: [
                //           totalCount(title: language.basePrice, amount: riderModel!.baseFare, space: 8),
                //           totalCount(title: language.distancePrice, amount: riderModel!.perDistanceCharge, space: 8),
                //           totalCount(
                //               title: language.minutePrice,
                //               amount: riderModel!.perMinuteDriveCharge,
                //               space: riderModel!.perMinuteWaitingCharge != 0
                //                   ? 8
                //                   : riderModel!.surgeCharge != 0
                //                       ? 8
                //                       : 0),
                //           totalCount(title: language.waitingTimePrice, amount: riderModel!.perMinuteWaitingCharge, space: riderModel!.surgeCharge != 0 ? 8 : 0),
                //         ],
                //       ),
                // SizedBox(height: 8),
                // if (riderModel!.adminCommission != null && riderModel!.adminCommission! > 0) totalCount(title: language.platformFee, amount: riderModel!.adminCommission, space: 0),
                // SizedBox(height: 8),
                // if (riderModel!.surgeCharge != null && riderModel!.surgeCharge! > 0) totalCount(title: language.fixedPrice, amount: riderModel!.surgeCharge, space: 0),
                // SizedBox(height: 8),
                // if (riderModel!.couponData != null && riderModel!.couponDiscount != 0)
                //   Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       Text(language.couponDiscount, style: secondaryTextStyle()),
                //       Row(
                //         children: [Text("-", style: boldTextStyle(color: Colors.green, size: 14)), printAmountWidget(amount: '${riderModel!.couponDiscount!.toStringAsFixed(digitAfterDecimal)}', color: Colors.green, size: 14, weight: FontWeight.normal)],
                //       ),
                //     ],
                //   ),
                // if (riderModel!.couponData != null && riderModel!.couponDiscount != 0) SizedBox(height: 8),
                // if (riderModel!.tips != null) totalCount(title: language.tip, amount: riderModel!.tips),
                // if (riderModel!.tips != null) SizedBox(height: 8),
                // if (riderModel!.extraCharges!.isNotEmpty)
                //   Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(language.additionalFees, style: boldTextStyle()),
                //       ...riderModel!.extraCharges!.map((e) {
                //         return Padding(
                //           padding: EdgeInsets.only(top: 4, bottom: 4),
                //           child: Row(
                //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //             children: [
                //               Text(e.key.validate().capitalizeFirstLetter(), style: secondaryTextStyle()),
                //               printAmountWidget(amount: '${e.value!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, size: 14),
                //             ],
                //           ),
                //         );
                //       }).toList()
                //     ],
                //   ),
                // Divider(thickness: 1),
                // payment != null && payment!.driverTips != 0 ? totalCount(title: language.total, amount: riderModel!.totalAmount! + payment!.driverTips!, isTotal: true) : totalCount(title: language.total, amount: riderModel!.totalAmount, isTotal: true),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(language.totalFare, style: boldTextStyle(size: 24)), printAmountWidget(amount: '${riderModel!.totalAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.bold, size: 24)],
                ),
              ],
            ),
    );
  }

  Widget extraChargeWidget() {
    if (riderModel == null) {
      return SizedBox();
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: dividerColor.withValues(alpha: 0.5).withValues(alpha: 0.5)),
        borderRadius: radius(),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(language.additionalChargesSummary, style: boldTextStyle(size: 16)),
          SizedBox(height: 8),
          Text(language.yourTripCompleted, style: secondaryTextStyle()),
          Text(language.driverCoveredFollowingCharge, style: secondaryTextStyle()),
          SizedBox(height: 14),
          Text(language.additionalCharges, style: boldTextStyle(size: 16)),
          SizedBox(height: 6),
          if (riderModel!.extraCharges != null)
            Column(
              children: List.generate(riderModel!.extraCharges!.length, (index) {
                final item = riderModel!.extraCharges![index];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(item.key.toString(), style: primaryTextStyle()), printAmountWidget(amount: '${item.value!.toStringAsFixed(digitAfterDecimal)}')],
                  ),
                );
              }),
            ),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(language.totalAdditionalAmount, style: boldTextStyle()),
              Row(
                children: [printAmountWidget(amount: '${riderModel!.extraChargesAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal)],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

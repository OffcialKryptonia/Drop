import '../manage_imports.dart';

class RidePaymentDetailScreen extends StatefulWidget {
  final int? rideId;
  final bool? schedule_flow;

  //
  RidePaymentDetailScreen({this.rideId, this.schedule_flow});

  @override
  RidePaymentDetailScreenState createState() => RidePaymentDetailScreenState();
}

class RidePaymentDetailScreenState extends State<RidePaymentDetailScreen> {
  List<RideHistory> rideHistory = [];
  RideService rideService = RideService();

  // CurrentRequestModel? currentData;
  bool isCashPayment = true;
  bool isShow = false;
  bool currentScreen = true;
  bool navigateDone = false;
  RiderModel? riderModel;
  Payment? paymentData;
  bool isPaymentDone = false;
  bool paymentPressed = false;
  num? balance;
  num? requiredAmount;
  num? payableAmount;
  double fareDistance = 0.0;

  String selectedPaymentMethod = '';
  bool isExpanded = false;

  num riderWalletBalance = 0;

  @override
  void initState() {
    super.initState();

    init();
  }

  void init() async {
    if (widget.schedule_flow == true) {
      await orderDetailApi();
    } else {
      getCurrentRide();
    }
  }

  getCurrentRide() async {
    Future.delayed(
      Duration.zero,
      () {
        appStore.setLoading(true);
        getCurrentRideRequest().then((value) async {
          appStore.setLoading(false);
          // paymentData! = value;
          await orderDetailApi();
          setState(() {});
        }).catchError((error) {
          appStore.setLoading(false);
          log(error.toString());
        });
      },
    );
  }

  Future<void> savePaymentApi() async {
    if (paymentPressed == true) return;
    paymentPressed = true;
    appStore.setLoading(true);
    Map req = {"id": paymentData!.id, "rider_id": paymentData!.riderId, "ride_request_id": paymentData!.rideRequestId, "datetime": DateTime.now().toString(), "total_amount": riderModel!.totalAmount, "payment_type": WALLET, "txn_id": "", "payment_status": PAID, "transaction_detail": ""};
    await savePayment(req).then((value) async {
      appStore.setLoading(false);
      await rideService.updateStatusOfRide(rideID: paymentData!.rideRequestId, req: {
        "on_stream_api_call": 0, /*"payment_status": PAID*/
      });
      orderDetailApi();
      paymentPressed = false;
    }).catchError((error) {
      paymentPressed = false;
      isShow = true;
      setState(() {});
      appStore.setLoading(false);
      log(error.toString());
      toast(error.toString());
      getWalletList(page: 1).then((value) {
        appStore.setLoading(false);
        if (value.walletBalance != null) balance = value.walletBalance!.totalAmount!;
        payableAmount = paymentData!.totalAmount!;
        requiredAmount = payableAmount! - balance!;
        requiredAmount = requiredAmount! + 1;
        setState(() {});
      }).catchError((error) {
        appStore.setLoading(false);
        log(error.toString());
      });
    });
  }

  Future<void> rideRequest() async {
    appStore.setLoading(true);
    Map req = {
      "payment_type": isCashPayment ? CASH : WALLET,
      "is_change_payment_type": 1,
    };
    log(req);
    await rideRequestUpdate(request: req, rideId: paymentData!.rideRequestId).then((value) async {
      await rideService.updateStatusOfRide(rideID: paymentData!.rideRequestId, req: {
        /*"tips": 1,*/ "on_stream_api_call": 0,
        "payment_type": isCashPayment ? CASH : WALLET,
      });
      appStore.setLoading(false);
      init();
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> orderDetailApi() async {
    // appStore.setLoading(true);
    await rideDetail(orderId: widget.rideId).then((value) async {
      riderModel = value.data;

      double distance = double.parse(
        value.data!.dropoffDistanceInKm!.toStringAsFixed(digitAfterDecimal),
      );

      fareDistance = distance - value.data!.minimumDistance!.toDouble();
      riderWalletBalance = value.riderWalletBalance!;
      if (value.ride_has_bids != null) {
        riderModel!.ride_has_bids = value.ride_has_bids;
      }
      if (value.payment != null) {
        // currentData!.payment = value.payment;
        paymentData = value.payment;
      }

      if (riderModel!.extraChargesPaymentMethod == 1) {
        selectedPaymentMethod = 'wallet';
      } else if (riderModel!.extraChargesPaymentMethod == 2) {
        selectedPaymentMethod = 'cash';
      }

      rideHistory = value.rideHistory!;
      setState(() {});
      if (paymentData != null && paymentData!.paymentStatus == "paid") {
        isPaymentDone = true;
        if (navigateDone == true) return;
        navigateDone = true;
        if (sharedPref.getBool("ENABLE_SCRATCH_CARD") ?? false) {
          Future.delayed(
            Duration(seconds: 3),
            () {
              launchScreen(
                  getContext,
                  ScratchCouponScreen(
                    coin_earnings: value.coinEarnings,
                    ride_id: widget.rideId,
                  ),
                  isNewTask: true,
                  pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
            },
          );
        } else {
          Future.delayed(
            Duration(seconds: 3),
            () {
              launchScreen(getContext, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
            },
          );
        }
      }
    }).catchError((error, s) {
      print("CheckError:::$error ::::$s");
      toast(error.toString());
      appStore.setLoading(false);
    });
  }

  Future<void> updateExtraChargePaymentMethodApi() async {
    appStore.setLoading(true);
    Map req = {
      "id": riderModel!.id,
      "extra_charges_payment_method": selectedPaymentMethod == 'wallet' ? 1 : 2,
    };
    await updateExtraChargePaymentMethod(req).then((value) {
      appStore.setLoading(false);
      orderDetailApi();
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
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
        centerTitle: true,
        title: Text(language.detailScreen, style: boldTextStyle(color: appTextPrimaryColorWhite)),
      ),
      body: StreamBuilder(
          stream: rideService.fetchRide(rideId: widget.rideId),
          builder: (context, snap) {
            if (snap.hasData) {
              List<FRideBookingModel> data = [];
              try {
                data = snap.data!.docs.map((e) => FRideBookingModel.fromJson(e.data() as Map<String, dynamic>)).toList();
              } catch (e) {
                data = [];
              }
              if (data.length == 0) {
                Future.delayed(
                  Duration(seconds: 2),
                  () {
                    if (currentScreen == false) return;
                    currentScreen = false;
                    orderDetailApi();
                  },
                );
              }
              if (data.isNotEmpty && data[0].paymentStatus.toString() == PAID && data[0].status.toString() == COMPLETED) {
                // isPaymentDone = true;
                Future.delayed(
                  Duration(seconds: 1),
                  () {
                    isPaymentDone = false;
                    if (currentScreen == false) return;
                    currentScreen = false;
                    orderDetailApi();
                  },
                );
              }

              return Stack(
                children: [
                  paymentData != null
                      ? SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              addressComponent(),
                              SizedBox(height: 12),
                              paymentDetailWidget(),
                              SizedBox(height: 12),
                              priceDetailWidget(),
                              if (riderModel!.extraChargesAmount != 0 && riderModel!.extraCharges!.isNotEmpty) ...[
                                SizedBox(height: 12),
                                extraChargeWidget(),
                                if (riderModel!.extraChargesPaymentMethod == 0) ...[
                                  SizedBox(height: 12),
                                  extraAMountPaymentWidget(),
                                ]
                              ],
                              SizedBox(height: 12),
                              if (paymentData != null && paymentData!.paymentStatus != COMPLETED && isShow)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(language.payment, style: boldTextStyle()),
                                    SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.grey.shade300),
                                          // boxShadow: [
                                          // BoxShadow(color: Colors.grey.shade300,spreadRadius: 1,blurRadius: 1.5)
                                          // ],
                                          borderRadius: BorderRadius.circular(14)),
                                      padding: EdgeInsets.all(6),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: inkWellWidget(
                                                onTap: () {
                                                  isCashPayment = true;
                                                  setState(() {});
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(color: isCashPayment ? primaryColor : null, boxShadow: isCashPayment ? [BoxShadow(color: Colors.grey.shade400, spreadRadius: 1, blurRadius: 1)] : [], borderRadius: BorderRadius.circular(12)),
                                                  padding: EdgeInsets.all(12),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      ImageIcon(AssetImage(icCash), size: 20, color: isCashPayment ? Colors.white : Colors.grey),
                                                      SizedBox(
                                                        width: 8,
                                                      ),
                                                      Text(
                                                        language.cash,
                                                        style: boldTextStyle(color: isCashPayment ? Colors.white : Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                )),
                                          ),
                                          SizedBox(width: 16),
                                          Expanded(
                                            child: inkWellWidget(
                                                onTap: () {
                                                  isCashPayment = false;
                                                  setState(() {});
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(color: isCashPayment == false ? primaryColor : null, boxShadow: isCashPayment == false ? [BoxShadow(color: Colors.grey.shade400, spreadRadius: 1, blurRadius: 1)] : [], borderRadius: BorderRadius.circular(12)),
                                                  padding: EdgeInsets.all(12),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      ImageIcon(AssetImage(icCard), size: 20, color: isCashPayment == false ? Colors.white : Colors.grey),
                                                      SizedBox(
                                                        width: 8,
                                                      ),
                                                      Text(
                                                        language.addMoney,
                                                        style: boldTextStyle(color: isCashPayment == false ? Colors.white : Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                )),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text("${language.note} ", style: secondaryTextStyle(color: Colors.red, size: 14, weight: FontWeight.bold)),
                                        Expanded(
                                            child: Text(
                                          isCashPayment
                                              ? "${riderModel!.tips != null && payableAmount != null ? riderModel!.tips! + payableAmount! : payableAmount}${appStore.currencyCode} - ${language.fullCashPayment}"
                                              : "+$requiredAmount${appStore.currencyCode} ${language.moreMoneyForWalletPayment}",
                                          style: secondaryTextStyle(color: Colors.red, size: 12, weight: FontWeight.bold),
                                          maxLines: 1,
                                        )),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    AppButtonWidget(
                                      width: context.width(),
                                      text: isCashPayment == true ? language.updatePaymentStatus : language.continueD,
                                      textStyle: boldTextStyle(color: Colors.white),
                                      color: primaryColor,
                                      onTap: () async {
                                        if (isCashPayment == false) {
                                          appStore.setLoading(true);
                                          bool res = await launchScreen(context, PaymentScreen(amount: requiredAmount), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                                          if (res == true) {
                                            await getWalletList(page: 1).then((value) {
                                              appStore.setLoading(false);
                                              if (value.walletBalance != null) balance = value.walletBalance!.totalAmount!;
                                              payableAmount = paymentData!.totalAmount!;
                                              requiredAmount = payableAmount! - balance!;
                                              requiredAmount = requiredAmount! + 1;
                                              setState(() {});
                                              isShow = false;
                                              rideRequest();
                                            }).catchError((error) {
                                              appStore.setLoading(false);
                                              log(error.toString());
                                            });
                                          } else {
                                            toast("Add MONEY");
                                          }
                                        } else {
                                          isShow = false;
                                          rideRequest();
                                        }
                                      },
                                    )
                                  ],
                                ),
                              SizedBox(height: 8),
                              // if (currentData!.payment != null && data.length>0 && data[0].paymentStatus.toString() != PAID )
                            ],
                          ),
                        )
                      : Observer(builder: (context) {
                          return Visibility(
                            visible: appStore.isLoading,
                            child: loaderWidget(),
                          );
                        }),
                  Visibility(
                      visible: isPaymentDone,
                      child: Center(
                        child: Container(
                            // width: 250,
                            //     height: 200,
                            width: context.width(),
                            margin: EdgeInsets.symmetric(horizontal: 40),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(defaultRadius),
                              boxShadow: [
                                BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 0, offset: Offset(0.0, 0.0)),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Lottie.asset(paymentSuccessful, width: 120, height: 120, fit: BoxFit.contain),
                                Text(
                                  "${language.paymentSuccess}",
                                  style: boldTextStyle(color: Colors.green, size: 24),
                                )
                              ],
                            )),
                      )),
                  Observer(builder: (context) {
                    return Visibility(
                      visible: appStore.isLoading,
                      child: loaderWidget(),
                    );
                  })
                ],
              );
            } else {
              return SizedBox();
            }
          }),
      bottomNavigationBar: paymentData != null && isShow == false
          ? Wrap(
              children: [
                Column(
                  children: [
                    if (riderModel!.extraChargesAmount != 0 && riderModel!.extraCharges!.isNotEmpty) ...[
                      4.height,
                      Text(
                        language.extraChargesNote,
                        style: secondaryTextStyle(color: Colors.black),
                      ).paddingSymmetric(horizontal: 16),
                    ],
                    AppButtonWidget(
                      text: getButtonText(),
                      width: MediaQuery.of(context).size.width,
                      onTap: () {
                        if (riderModel!.extraChargesAmount != 0 && riderModel!.extraChargesPaymentMethod == 0) {
                          if (selectedPaymentMethod.isEmpty) {
                            toast(language.pleaseSelectPaymentMethod);
                          } else {
                            updateExtraChargePaymentMethodApi();
                          }
                        } else if (paymentData!.paymentStatus == PAID) {
                          orderDetailApi();
                          // launchScreen(context, DashBoardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                        } else if (paymentData!.paymentStatus != PAID && paymentData!.paymentType == CASH) {
                          toast(language.waitingForDriverConformation);
                        } else if (paymentData!.paymentStatus != PAID && paymentData!.paymentType == WALLET) {
                          savePaymentApi();
                        }
                      },
                    ).paddingAll(16),
                  ],
                ),
              ],
            )
          : SizedBox(),
    );
  }

  String? getButtonText() {
    if (riderModel!.extraChargesAmount != 0 && riderModel!.extraChargesPaymentMethod == 0) {
      return '${language.extraChargesPayVia} ${selectedPaymentMethod == 'wallet' ? language.wallet : language.cash}';
    } else if (paymentData!.paymentStatus == COMPLETED) {
      return language.continueNewRide;
    } else if (paymentData!.paymentStatus != COMPLETED && paymentData!.paymentType == CASH) {
      return language.waitingForDriverConformation;
    } else if (paymentData!.paymentStatus != COMPLETED && paymentData!.paymentType == WALLET) {
      return language.payToPayment;
    }
    return '';
  }

  Widget addressComponent() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Ionicons.calendar, color: textSecondaryColorGlobal, size: 16),
                  SizedBox(width: 4),
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('${printDate(riderModel!.createdAt.validate())}', style: primaryTextStyle(size: 14)),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(language.rideId, style: boldTextStyle(size: 16)),
                  SizedBox(width: 8),
                  Text('#${riderModel!.id}', style: boldTextStyle(size: 16)),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${language.lblDistance} ${riderModel!.distance!.toStringAsFixed(2)} ${riderModel!.distanceUnit}',
                    style: boldTextStyle(size: 14),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                    child: Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 24,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.near_me, color: Colors.green, size: 18),
                        SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (riderModel!.startTime != null)
                                Text(
                                  printDate(riderModel!.startTime!),
                                  style: secondaryTextStyle(size: 12),
                                ),
                              if (riderModel!.startTime != null) SizedBox(height: 4),
                              Text(
                                riderModel!.startAddress.validate(),
                                style: primaryTextStyle(size: 14),
                              ),
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
                              if (riderModel!.endTime != null)
                                Text(
                                  printDate(riderModel!.endTime!),
                                  style: secondaryTextStyle(size: 12),
                                ),
                              if (riderModel!.endTime != null) SizedBox(height: 4),
                              Text(
                                riderModel!.endAddress.validate(),
                                style: primaryTextStyle(size: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (riderModel!.multiDropLocation != null && riderModel!.multiDropLocation!.isNotEmpty) ...[
                      SizedBox(height: 8),
                      AppButtonWidget(
                        textColor: primaryColor,
                        color: Colors.white,
                        height: 30,
                        shapeBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(defaultRadius),
                          side: BorderSide(color: primaryColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: primaryColor, size: 12),
                            SizedBox(width: 4),
                            Text(
                              language.viewMore,
                              style: primaryTextStyle(size: 14),
                            ),
                          ],
                        ),
                        onTap: () {
                          showOnlyDropLocationsDialog(context, riderModel!.multiDropLocation!);
                        },
                      ),
                    ],
                  ],
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: Duration(milliseconds: 250),
              ),
            ],
          ),
          SizedBox(height: 12),
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

  Widget paymentDetailWidget() {
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
          Text(language.paymentDetails, style: boldTextStyle(size: 16)),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(language.via, style: primaryTextStyle()),
              Text(paymentStatus(riderModel!.paymentType.validate()), style: boldTextStyle()),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(language.status, style: primaryTextStyle()),
              Text(paymentStatus(riderModel!.paymentStatus.validate()), style: boldTextStyle(color: paymentStatusColor(riderModel!.paymentStatus.validate()))),
            ],
          ),
        ],
      ),
    );
  }

  Widget priceDetailWidget() {
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
      child: riderModel!.ride_has_bids == 1
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(language.priceDetail, style: boldTextStyle(size: 16)),
                // SizedBox(height: 12),
                // totalCount(
                //     title: language.amount,
                //     amount:
                //         riderModel!.totalAmount,
                //     space: 8),
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
                // if (riderModel!.extraCharges!.isNotEmpty) SizedBox(height: 8),
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
                // riderModel!.tips != null ? totalCount(title: language.total, amount: riderModel!.totalAmount! + riderModel!.tips!, isTotal: true) : totalCount(title: language.total, amount: riderModel!.totalAmount, isTotal: true),
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
                // if (riderModel!.surgeAmount != null && riderModel!.surgeAmount! > 0) ...[
                //   SizedBox(height: 8),
                //   Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [Text(language.highDemandCharge, style: primaryTextStyle(color: Colors.red)), printAmountWidgetForEstimate(amount: '${riderModel!.surgeAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, color: Colors.red, sign: "+")],
                //   ),
                // ],
                // if (riderModel!.discountAmount != null && riderModel!.discountAmount! > 0) ...[
                //   SizedBox(height: 8),
                //   Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [Text(language.couponDiscount, style: primaryTextStyle(color: Colors.green)), printAmountWidgetForEstimate(amount: '${riderModel!.discountAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal, color: Colors.green, sign: "-")],
                //   ),
                //   SizedBox(height: 8),
                // ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(language.totalFare, style: boldTextStyle(size: 24)), printAmountWidget(amount: '${riderModel!.totalAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.bold, size: 24)],
                ),
                // riderModel!.subtotal! <= riderModel!.estimated_price['minimum_fare'] ?? riderModel!.minimumFare!
                //     ? totalCount(title: language.minimumFare, amount: riderModel!.estimated_price['minimum_fare'] ?? riderModel!.minimumFare!)
                //     :
                // Column(
                //   children: [
                //     totalCount(title: language.basePrice, amount: riderModel!.baseFare, space: 8),
                //     totalCount(title: language.distancePrice, amount: riderModel!.perDistanceCharge, space: 8),
                //     totalCount(
                //         title: language.minutePrice,
                //         amount: riderModel!.perMinuteDriveCharge,
                //         space: riderModel!.perMinuteWaitingCharge != 0
                //             ? 8
                //             : riderModel!.surgeCharge != 0
                //                 ? 8
                //                 : 0),
                //     totalCount(title: language.waitingTimePrice, amount: riderModel!.perMinuteWaitingCharge, space: riderModel!.surgeCharge != 0 ? 8 : 0),
                //   ],
                // ),
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
                //       SizedBox(height: 8),
                //       ...riderModel!.extraCharges!.map((e) {
                //         return Padding(
                //           padding: EdgeInsets.only(top: 4, bottom: 4),
                //           child: totalCount(title: e.key.validate(), amount: e.value),
                //         );
                //       }).toList()
                //     ],
                //   ),
                // Divider(height: 16, thickness: 1),
                // riderModel!.tips != null ? totalCount(title: language.total, amount: riderModel!.totalAmount! + riderModel!.tips!, isTotal: true) : totalCount(title: language.total, amount: riderModel!.totalAmount, isTotal: true),
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
          Text(language.settleAdditionalCharges, style: boldTextStyle(size: 16)),
          SizedBox(height: 8),
          Text(language.yourTripAlreadyPaid, style: secondaryTextStyle()),
          Text(language.driverPaidFollowingCharge, style: secondaryTextStyle()),
          SizedBox(height: 14),
          Text(language.additionalChargesPaidByDriver, style: boldTextStyle(size: 16)),
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
              Text(language.totalExtraAmount, style: boldTextStyle()),
              Row(
                children: [printAmountWidget(amount: '${riderModel!.extraChargesAmount!.toStringAsFixed(digitAfterDecimal)}', weight: FontWeight.normal)],
              ),
            ],
          ),
          if (riderModel!.extraChargesPaymentMethod != 0) ...[
            SizedBox(height: 16),
            Text('${language.noAdditionalPaymentRequired} ${riderModel!.extraChargesPaymentDate}.', style: boldTextStyle(color: Colors.green)),
          ],
        ],
      ),
    );
  }

  Widget extraAMountPaymentWidget() {
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
          Text(language.choosePaymentMethod, style: boldTextStyle(size: 16)),
          SizedBox(height: 8),
          Column(
            children: [
              _buildPaymentOption(
                title: language.payViaWallet,
                subtitle: '${language.lblWalletBalance}:',
                description: language.fastAndCashless,
                value: 'wallet',
              ),
              const SizedBox(height: 16),
              _buildPaymentOption(
                title: language.payInCashToDriver,
                subtitle: '',
                description: language.amountHandelToDriver,
                value: 'cash',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required String description,
    required String value,
  }) {
    final isSelected = selectedPaymentMethod == value;

    return GestureDetector(
      onTap: () {
        if (riderModel!.extraChargesPaymentMethod! == 0) {
          if (value == "wallet" && riderWalletBalance < riderModel!.extraChargesAmount) {
            // toast(language.noBalanceValidate);
          } else {
            setState(() {
              selectedPaymentMethod = value;
            });
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: boldTextStyle(size: 16)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Row(
                            children: [Text(subtitle, style: secondaryTextStyle()), 5.width, printAmountWidget(amount: '${riderWalletBalance.toStringAsFixed(digitAfterDecimal)}', size: 14, color: textSecondaryColorGlobal, weight: FontWeight.normal)],
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(description, style: secondaryTextStyle()),
                    4.height,
                    if (value == "wallet" && riderWalletBalance < riderModel!.extraChargesAmount) Text(language.insufficientWalletBalanceToPay, style: secondaryTextStyle(color: Colors.red)),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey[400]!,
                    width: 2,
                  ),
                  color: isSelected ? primaryColor : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

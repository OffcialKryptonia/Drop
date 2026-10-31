import '../manage_imports.dart';

class Bidingscreen extends StatefulWidget {
  final Map? multiDropLocationNamesObj, multiDropObj, endLocation, source;
  final String? dt;
  final int ride_id;

  @override
  BidingscreenState createState() => BidingscreenState();

  Bidingscreen({
    this.multiDropObj,
    this.dt,
    this.multiDropLocationNamesObj,
    this.endLocation,
    this.source,
    required this.ride_id,
  });
}

class BidingscreenState extends State<Bidingscreen> {
  BidListingModel? dataModel;
  RideService rideService = RideService();

  // int duration = 0;
  int currentSeconds = 0;
  Timer? timer;
  DateTime? d2;
  int count = 0;

  // String get timerText => '${((duration - currentSeconds) ~/ 60).toString().padLeft(2, '0')}: ${((duration - currentSeconds) % 60).toString().padLeft(2, '0')}';
  final int timerMaxSeconds = appStore.rideMinutes != null ? int.parse(appStore.rideMinutes!) * 60 : 5 * 60;
  bool called = false;

  @override
  void initState() {
    super.initState();
    updateData();
    startTimeout();
    // init();
  }

  startTimeout() {
    if (called == true) return;
    called = true;
    if (widget.dt != null) {
      DateTime? d1 = DateTime.tryParse(widget.dt!.toString().validate());
      if (d1 != null) {
        // d1=d1.toUtc();
        print("CheckDateTime:::${d1}");
        // d1=d1.t
        setState(
          () {
            // d2 = d1.toUtc().add(Duration(seconds: timerMaxSeconds));
            d2 = d1.add(Duration(seconds: timerMaxSeconds));
          },
        );
        print("CheckDateTimedafjfkljf:::${d2}");
        return;
      }
    }
    return;
  }

  @override
  void dispose() {
    super.dispose();
    try {
      timer!.cancel();
    } catch (e) {}
  }

  // void init() async {
  //   print(REMAINING_TIME2);
  //   print(IS_TIME2);
  //   if (sharedPref.getString(IS_TIME2) == null) {
  //     duration = timerMaxSeconds;
  //     startTimeout();
  //     sharedPref.setString(IS_TIME2, DateTime.now().add(Duration(seconds: timerMaxSeconds)).toString());
  //     sharedPref.setString(REMAINING_TIME2, timerMaxSeconds.toString());
  //   } else {
  //     duration = DateTime.parse(sharedPref.getString(IS_TIME2)!).difference(DateTime.now()).inSeconds;
  //     if (duration > 0) {
  //       startTimeout();
  //     } else {
  //       sharedPref.remove(IS_TIME2);
  //       duration = timerMaxSeconds;
  //       setState(() {});
  //       startTimeout();
  //     }
  //   }
  // }
  // startTimeout() {
  //   var duration2 = Duration(seconds: 1);
  //   timer = Timer.periodic(duration2, (timer) {
  //     setState(
  //           () {
  //         currentSeconds = timer.tick;
  //         count++;
  //         if (count >= 60) {
  //           int data = int.parse(sharedPref.getString(REMAINING_TIME2)!);
  //           data = data - count;
  //           Map req = {
  //             'max_time_for_find_driver_for_ride_request': data,
  //           };
  //           rideRequestUpdate(request: req, rideId: widget.ride_id).then((value) {
  //             //
  //           }).catchError((error) {
  //             log(error.toString());
  //           });
  //           sharedPref.setString(REMAINING_TIME2, data.toString());
  //           count = 0;
  //         }
  //         if (timer.tick >= duration) {
  //           timer.cancel();
  //           Map req = {
  //             'status': CANCELED,
  //             'cancel_by': AUTO,
  //             "reason": "Ride is auto cancelled",
  //           };
  //           appStore.setLoading(true);
  //           rideRequestUpdate(request: req, rideId: widget.ride_id).then((value) async {
  //             appStore.setLoading(false);
  //             toast(language.noNearByDriverFound);
  //             sharedPref.remove(REMAINING_TIME2);
  //             sharedPref.remove(IS_TIME2);
  //             toast(value.message);
  //             launchScreen(context, DashBoardScreen(), isNewTask: true);
  //           }).catchError((error) {
  //             appStore.setLoading(false);
  //             log(error.toString());
  //           });
  //         }
  //       },
  //     );
  //   });
  // }

  Future<void> cancelRequest(String reason) async {
    appStore.setLoading(true);
    Map req = {
      "id": widget.ride_id,
      "cancel_by": RIDER,
      "status": CANCELED,
      "reason": reason,
    };
    await rideRequestUpdate(
      request: req,
      rideId: widget.ride_id,
    ).then((value) async {
      appStore.setLoading(false);
      toast(value.message);
      launchScreen(context, DashBoardScreen(), isNewTask: true);
    }).catchError((error, s) {
      appStore.setLoading(false);
      try {} catch (e) {}
      log(error.toString() + "Stack::$s");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(language.bid_for_ride, style: boldTextStyle(color: appTextPrimaryColorWhite)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(language.lblRide + " #${widget.ride_id}", style: primaryTextStyle(color: appTextPrimaryColorWhite)),
          )
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: AppButtonWidget(
            width: MediaQuery.of(context).size.width,
            text: language.cancel,
            textColor: primaryColor,
            color: Colors.white,
            shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
            onTap: () {
              showModalBottomSheet(
                  context: context,
                  isDismissible: false,
                  isScrollControlled: true,
                  builder: (context) {
                    return CancelOrderDialog(
                      onCancel: (reason) async {
                        Navigator.pop(context);
                        appStore.setLoading(true);
                        sharedPref.remove(REMAINING_TIME2);
                        sharedPref.remove(IS_TIME2);
                        await cancelRequest(reason);
                        appStore.setLoading(false);
                      },
                    );
                  });
            }),
      ),
      body: dataModel == null
          ? SizedBox()
          : Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 16, right: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SizedBox(
                          height: 16,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.near_me, color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Expanded(child: Text(dataModel!.startAddress ?? ''.validate(), style: primaryTextStyle(size: 14), maxLines: 2)),
                              ],
                            ),
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
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Expanded(child: Text(dataModel!.endAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2)),
                              ],
                            ),
                            if (widget.multiDropObj != null && widget.multiDropObj!.isNotEmpty)
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
                            if (widget.multiDropObj != null && widget.multiDropObj!.isNotEmpty)
                              AppButtonWidget(
                                textColor: primaryColor,
                                color: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                height: 30,
                                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                                  List<String> temp = [];
                                  List<MultiDropLocation> dataVal = [];
                                  widget.multiDropLocationNamesObj!.forEach(
                                    (key, value) {
                                      temp.add(value.toString());
                                      dataVal.add(MultiDropLocation(address: value.toString(), drop: 0, droppedAt: null, lat: 0, lng: 0));
                                    },
                                  );
                                  showOnlyDropLocationsDialog(context, dataVal);
                                },
                              ),
                            SizedBox(
                              height: 8,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(language.bids, style: boldTextStyle()),
                                    if (dataModel != null && dataModel!.data != null && dataModel!.data!.length > 0)
                                      Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: primaryColor,
                                          ),
                                          margin: EdgeInsets.symmetric(horizontal: 8),
                                          alignment: Alignment.center,
                                          padding: EdgeInsets.all(6),
                                          child: Text("${dataModel!.data!.length}", style: boldTextStyle(size: 12, color: Colors.white))),
                                  ],
                                ),
                                if (d2 != null)
                                  Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: primaryColor, borderRadius: radius(8)),
                                      child: StreamBuilder(
                                        stream: Stream.periodic(Duration(seconds: 1)),
                                        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                                          if (d2 != null && d2!.difference(DateTime.parse(DateTime.now().toUtc().toString().replaceAll("Z", ""))).isNegative) {
                                            // print("CheckDateTImeIssue++++++++++123186:${d2!.difference(DateTime.now().toUtc())}");
                                            Map req = {
                                              'status': CANCELED,
                                              'cancel_by': AUTO,
                                              "reason": "Ride is auto cancelled",
                                            };
                                            d2 = null;
                                            print("AutoCancelFunctionCall:::::");
                                            appStore.setLoading(true);
                                            rideRequestUpdate(request: req, rideId: widget.ride_id).then((value) async {
                                              appStore.setLoading(false);
                                              toast(language.noNearByDriverFound);
                                              sharedPref.remove(REMAINING_TIME);
                                              sharedPref.remove(IS_TIME);
                                              launchScreen(context, DashBoardScreen(), isNewTask: true);
                                            }).catchError((error) {
                                              appStore.setLoading(false);
                                              log(error.toString());
                                            });
                                          }
                                          if (d2 != null && d2!.difference(DateTime.parse(DateTime.now().toUtc().toString().replaceAll("Z", ""))).isNegative)
                                            return Text("--:--", style: boldTextStyle(color: Colors.white));
                                          if (d2 == null) return Text("--:--", style: boldTextStyle(color: Colors.white));
                                          return Text(
                                              (d2!.difference(DateTime.parse(DateTime.now().toUtc().toString().replaceAll("Z", ""))).inSeconds / 60).toInt().toString().padLeft(2, "0") +
                                                  ":" +
                                                  (d2!.difference(DateTime.parse(DateTime.now().toUtc().toString().replaceAll("Z", ""))).inSeconds % 60).toString().padLeft(2, "0").toString(),
                                              style: boldTextStyle(color: Colors.white));
                                        },
                                      )
                                      // Text(timerText, style: boldTextStyle(color: Colors.white)),
                                      )
                              ],
                            ),
                            Divider(),
                            StreamBuilder(
                              stream: rideService.fetchRide(rideId: widget.ride_id),
                              builder: (context, snap) {
                                if (snap.hasData) {
                                  List<FRideBookingModel> data = snap.data!.docs.map((e) => FRideBookingModel.fromJson(e.data() as Map<String, dynamic>)).toList();
                                  if (data.isNotEmpty) {
                                    if (data[0].onRiderStreamApiCall == 0) {
                                      updateData();
                                      rideService.updateStatusOfRide(rideID: widget.ride_id, req: {'on_rider_stream_api_call': 1});
                                    }
                                  }
                                }
                                return SizedBox();
                              },
                            ),
                            if ((dataModel != null && dataModel!.data != null && dataModel!.data!.isEmpty) || dataModel == null) emptyView(),
                            ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.only(bottom: 10),
                              physics: NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Container(
                                      padding: EdgeInsets.only(left: 8, bottom: 8),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          // border: Border.all(color: Colors.grey.shade300),
                                          boxShadow: [BoxShadow(color: Colors.black45, spreadRadius: 1, blurRadius: 1)],
                                          borderRadius: BorderRadius.circular(14)),
                                      // decoration: BoxDecoration(border: Border.all(color: dividerColor), borderRadius: BorderRadius.circular(defaultRadius)),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    printAmountWidget(amount: dataModel!.data![index].bidAmount),
                                                    Text(dataModel!.data![index].driverName, maxLines: 1, overflow: TextOverflow.ellipsis, style: secondaryTextStyle()),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  IconButton(
                                                    onPressed: () {
                                                      d2 = null;
                                                      acceptBid(driverId: dataModel!.data![index].driverId.toString(), amount: dataModel!.data![index].bidAmount.toString());
                                                    },
                                                    icon: Icon(
                                                      Icons.check_circle,
                                                      size: 35,
                                                    ),
                                                    color: Colors.green,
                                                  ),
                                                  IconButton(
                                                    onPressed: () {
                                                      rejectBid(driverId: dataModel!.data![index].driverId.toString(), amount: dataModel!.data![index].bidAmount.toString());
                                                    },
                                                    icon: Icon(
                                                      Icons.cancel,
                                                      size: 35,
                                                    ),
                                                    color: Colors.red,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: 8,
                                          ),
                                          if (dataModel!.data![index].notes.isNotEmpty)
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(dataModel!.data![index].notes, style: secondaryTextStyle()),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      )),
                                );
                              },
                              itemCount: dataModel!.data!.length,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Observer(builder: (context) {
                  return Visibility(visible: appStore.isLoading, child: loaderWidget());
                }),
              ],
            ),
    );
  }

  void updateData() async {
    Map req = {"ride_request_id": widget.ride_id.toString()};
    dataModel = await getBidListing(req);
    setState(() {});
  }

  void acceptBid({required String driverId, required String amount}) async {
    appStore.setLoading(true);
    Map req = {"id": "${widget.ride_id}", "total_amount": "${amount}", "driver_id": "$driverId", "is_bid_accept": "1"};
    try {
      await responseBidListing(req);
    } catch (e) {}
    appStore.setLoading(false);
    await rideService.updateStatusOfRide(rideID: widget.ride_id, req: {"on_stream_api_call": 0});
    launchScreen(context, DashBoardScreen(), isNewTask: true);
  }

  void rejectBid({required String driverId, required String amount}) async {
    Map req = {"id": "${widget.ride_id}", "driver_id": "$driverId", "total_amount": "${amount}", "is_bid_accept": "2"};
    appStore.setLoading(true);
    LDBaseResponse b = await responseBidListing(req);
    appStore.setLoading(false);
    toast(b.message.toString());
    updateData();
  }

  emptyView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Lottie.asset(bookingAnim, height: 100, width: MediaQuery.of(context).size.width, fit: BoxFit.contain),
        SizedBox(
          height: 16,
        ),
        Text(language.no_bids_note),
      ],
    );
  }
}

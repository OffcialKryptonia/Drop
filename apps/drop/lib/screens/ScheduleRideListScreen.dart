import '../manage_imports.dart';

class ScheduleRideListScreen extends StatefulWidget {
  ScheduleRideListScreen({super.key});

  @override
  State<ScheduleRideListScreen> createState() => _ScheduleRideListScreenState();
}

class _ScheduleRideListScreenState extends State<ScheduleRideListScreen> {
  List<OnRideRequest> schedule_ride_request = [];
  Driver? driver;
  bool paymentPressed = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  getCurrentRequest() async {
    appStore.setLoading(true);
    await getCurrentRideRequest().then((value) {
      appStore.setLoading(false);
      try {
        driver = value.driver;
      } catch (e) {
        print(e.toString());
      }
      schedule_ride_request = value.schedule_ride_request ?? [];
      setState(() {});
    }).catchError((error, stack) {
      appStore.setLoading(false);
      log("Error-- " + error.toString());
    });
  }

  void init() async {
    getCurrentRequest();
  }

  @override
  Widget build(BuildContext context) {
    // ignore:deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, schedule_ride_request);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "${language.schedule_list_title}",
            style: primaryTextStyle(size: 18, weight: FontWeight.bold, color: Colors.white),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "🚖 ${language.schedule_list_desc}",
                    style: secondaryTextStyle(size: 14, color: Colors.black, weight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      init();
                    },
                    child: ListView.builder(
                        itemCount: schedule_ride_request.length,
                        itemBuilder: (context, i) {
                          return Container(
                            width: context.width(),
                            padding: EdgeInsets.all(8),
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: primaryColor),
                              borderRadius: BorderRadius.circular(defaultRadius),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade300,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  "${language.rideId}: ${schedule_ride_request[i].id}",
                                                  style: primaryTextStyle(size: 15, weight: FontWeight.bold),
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: primaryColor,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text('${statusName(status: schedule_ride_request[i].status.toString())}', style: boldTextStyle(size: 14, color: Colors.white)),
                                              ),
                                            ],
                                          ),

                                          5.height,
                                          if (schedule_ride_request[i].driverId != null)
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(defaultRadius),
                                                  child: commonCachedNetworkImage(schedule_ride_request[i].driverProfileImage, height: 38, width: 38, fit: BoxFit.cover),
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('${schedule_ride_request[i].driverName!.capitalizeFirstLetter()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                                      SizedBox(height: 4),
                                                      Text('${schedule_ride_request[i].driverEmail.validate()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: secondaryTextStyle()),
                                                    ],
                                                  ),
                                                ),
                                                inkWellWidget(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (_) {
                                                        return AlertDialog(
                                                          contentPadding: EdgeInsets.all(0),
                                                          content: AlertScreen(rideId: schedule_ride_request[i].id, regionId: schedule_ride_request[i].regionId),
                                                        );
                                                      },
                                                    );
                                                  },
                                                  child: chatCallWidget(Icons.sos),
                                                ),
                                                SizedBox(width: 8),
                                                inkWellWidget(
                                                  onTap: () {
                                                    launchUrl(Uri.parse('tel:${schedule_ride_request[i].driverContactNumber}'), mode: LaunchMode.externalApplication);
                                                  },
                                                  child: chatCallWidget(Icons.call),
                                                ),
                                                SizedBox(width: 8),
                                                if (schedule_ride_request[i].driverId != null)
                                                  inkWellWidget(
                                                    onTap: () {
                                                      if (schedule_ride_request[i].driverId != null) {
                                                        getUserDetail(userId: schedule_ride_request[i].driverId).then(
                                                          (value) {
                                                            launchScreen(context, ChatScreen(userData: value.data, ride_id: schedule_ride_request[i].id!), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                                                          },
                                                        );
                                                      }
                                                    },
                                                    child: chatCallWidget(
                                                      Icons.chat_bubble_outline,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          // 5.height,
                                          Divider(),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        "${language.schedule_at}: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.parse(schedule_ride_request[i].schedule_datetime.toString() + "Z").toLocal())}",
                                                        style: secondaryTextStyle(size: 13, color: Colors.white, weight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                  if (schedule_ride_request[i].otp != null) ...[
                                                    8.width,
                                                    Container(
                                                      padding: EdgeInsets.all(8),
                                                      decoration: BoxDecoration(border: Border.all(color: dividerColor), borderRadius: radius(defaultRadius)),
                                                      child: Text('${language.otp} ${schedule_ride_request[i].otp ?? ''}', style: boldTextStyle(size: 14)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              Text(
                                                "${language.paymentDetails} : ${schedule_ride_request[i].paymentStatus.toString().toUpperCase()}",
                                                style: primaryTextStyle(size: 12, weight: FontWeight.bold, color: schedule_ride_request[i].paymentStatus == PAID ? Colors.green : Colors.red /* Colors.white*/),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(),
                                if (schedule_ride_request[i].trip_type == 'airport_pickup' || schedule_ride_request[i].trip_type == 'airport_drop' || schedule_ride_request[i].trip_type == 'zone_to_airport' || schedule_ride_request[i].trip_type == 'airport_to_zone') ...[
                                  airportPickupSection(
                                    flightNumber: schedule_ride_request[i].flightNumber!,
                                    terminal: schedule_ride_request[i].pickupPoint!,
                                  ),
                                  Divider(),
                                ],
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.near_me, color: Colors.green, size: 18),
                                        SizedBox(width: 8),
                                        Expanded(child: Text(schedule_ride_request[i].startAddress.validate(), style: primaryTextStyle(size: 14), maxLines: 2)),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        SizedBox(width: 8),
                                        SizedBox(
                                          height: 12,
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
                                        Expanded(child: Text(schedule_ride_request[i].endAddress.validate(), style: primaryTextStyle(size: 14), maxLines: 2)),
                                      ],
                                    ),
                                    if (schedule_ride_request[i].multiDropLocation != null && schedule_ride_request[i].multiDropLocation!.isNotEmpty)
                                      Row(
                                        children: [
                                          SizedBox(width: 8),
                                          SizedBox(
                                            height: 12,
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
                                    if (schedule_ride_request[i].multiDropLocation != null && schedule_ride_request[i].multiDropLocation!.isNotEmpty)
                                      AppButtonWidget(
                                        textColor: primaryColor,
                                        color: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        // height: 30,
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
                                          showOnlyDropLocationsDialog(
                                            context,
                                            schedule_ride_request[i].multiDropLocation!,
                                          );
                                        },
                                      ),
                                    10.height,
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (schedule_ride_request[i].status == COMPLETED) ...[
                                          Expanded(
                                            child: AppButtonWidget(
                                                text: schedule_ride_request[i].isRiderRated == 0
                                                    // ? language.addReviews
                                                    ? language.viewDetails
                                                    : schedule_ride_request[i].paymentType == WALLET && schedule_ride_request[i].paymentStatus != PAID
                                                        ? language.payToPayment
                                                        : language.waitingForDriverConformation,
                                                textColor: primaryColor,
                                                color: Colors.white,
                                                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                                                onTap: () async {
                                                  if (schedule_ride_request[i].isRiderRated == 0) {
                                                    await launchScreen(getContext, ReviewScreen(rideRequest: schedule_ride_request[i], driverData: driver, schedule_ride: true), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                                                    init();
                                                  } else if (/*schedule_ride_request[
                                                                  i]
                                                              .paymentType ==
                                                          WALLET &&*/
                                                      schedule_ride_request[i].paymentStatus != PAID) {
                                                    launchScreen(
                                                      getContext,
                                                      RidePaymentDetailScreen(rideId: schedule_ride_request[i].id, schedule_flow: true),
                                                      pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
                                                    );
                                                  }
                                                  toast(language.waitingForDriverConformation);
                                                }),
                                          ),
                                        ] else if (schedule_ride_request[i].status != IN_PROGRESS && schedule_ride_request[i].status != COMPLETED) ...[
                                          AppButtonWidget(
                                            text: language.cancel,
                                            textColor: primaryColor,
                                            color: Colors.white,
                                            shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                                            onTap: () async {
                                              showModalBottomSheet(
                                                  context: context,
                                                  isDismissible: false,
                                                  isScrollControlled: true,
                                                  builder: (context) {
                                                    return CancelOrderDialog(
                                                      onCancel: (reason) async {
                                                        Navigator.pop(context);
                                                        appStore.setLoading(true);
                                                        sharedPref.remove(REMAINING_TIME);
                                                        sharedPref.remove(IS_TIME);
                                                        await cancelRequest(reason, ride_id: schedule_ride_request[i].id);
                                                        appStore.setLoading(false);
                                                      },
                                                    );
                                                  });
                                            },
                                          ),
                                        ]
                                      ],
                                    )
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                  ),
                ),
              ],
            ),
            Observer(builder: (context) {
              if (!appStore.isLoading && schedule_ride_request.isEmpty) {
                return emptyWidget();
              }
              return Visibility(
                visible: appStore.isLoading,
                child: loaderWidget(),
              );
            }),
            // Observer(builder: (context) => Visibility(visible: appStore.isLoading, child: Positioned.fill(child: loaderWidget()))),
          ],
        ),
      ),
    );
  }

  Widget airportPickupSection({
    required String flightNumber,
    required String terminal,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                language.airportPickupInformation,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                "${language.flightNumber}:",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(width: 6),
              Text(
                flightNumber,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              SizedBox(width: 12),
              Text(
                "|  ${language.terminal}:",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(width: 6),
              Text(
                terminal,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (driver != null) ...[
            Row(
              children: [
                Text(
                  language.vehicleInformation,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1),
            SizedBox(height: 12),
            Row(
              children: [
                Text(
                  "${language.numberPlate}:",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  driver!.userDetail!.carPlateNumber!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Text(
                  "${language.carModel}:",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  driver!.userDetail!.carModel!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Text(
                  "${language.vehicleColor}:",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  driver!.userDetail!.carColor!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> cancelRequest(String reason, {int? ride_id}) async {
    Map req = {
      "id": ride_id,
      "cancel_by": RIDER,
      "status": CANCELED,
      "reason": reason,
    };
    appStore.setLoading(true);
    await rideRequestUpdate(request: req, rideId: ride_id).then((value) async {
      appStore.setLoading(false);
      toast(value.message);
    }).catchError((error) {
      appStore.setLoading(false);
    });
    init();
  }
}

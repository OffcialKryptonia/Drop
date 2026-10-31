import '../manage_imports.dart';

class RideAcceptWidget extends StatefulWidget {
  final Driver? driverData;
  final OnRideRequest? rideRequest;

  RideAcceptWidget({this.driverData, this.rideRequest});

  @override
  RideAcceptWidgetState createState() => RideAcceptWidgetState();
}

class RideAcceptWidgetState extends State<RideAcceptWidget> {
  UserModel? userData;
  double duration = 0;

  @override
  void initState() {
    super.initState();
    init();
    listenForNewDuration();
  }

  void init() async {
    await getUserDetail(userId: widget.rideRequest!.driverId).then((value) {
      sharedPref.remove(IS_TIME);
      appStore.setLoading(false);
      userData = value.data;
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
    });
  }

  void listenForNewDuration() {
    FirebaseFirestore.instance.collection(RIDE_COLLECTION).where('rider_id', isEqualTo: sharedPref.getInt(USER_ID)!).where('ride_id', isEqualTo: widget.rideRequest!.id).snapshots().listen((QuerySnapshot snapshot) {
      for (var doc in snapshot.docs) {
        var rideData = doc.data() as Map<String, dynamic>;

        if (rideData['duration'] != null) {
          duration = (rideData['duration'] as num).toDouble();
        } else {
          duration = 0;
        }
        setState(() {});
      }
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> cancelRequest(String reason) async {
    Map req = {
      "id": widget.rideRequest!.id,
      "cancel_by": RIDER,
      "status": CANCELED,
      "reason": reason,
    };
    await rideRequestUpdate(request: req, rideId: widget.rideRequest!.id).then((value) async {
      toast(value.message);
      chatMessageService.justDeleteChat(
        senderId: sharedPref.getString(UID).validate(),
        receiverId: userData!.uid.validate(),
      );
    }).catchError((error) {
      try {
        chatMessageService.justDeleteChat(
          senderId: sharedPref.getString(UID).validate(),
          receiverId: userData!.uid.validate(),
        );
      } catch (e) {}
      log(error.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              alignment: Alignment.center,
              height: 5,
              width: 70,
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(color: primaryColor, borderRadius: radius()),
                  child: InkWell(
                    onTap: () {},
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ImageIcon(
                          AssetImage(statusTypeIcon(type: widget.rideRequest!.status.validate())),
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(
                          width: 4,
                        ),
                        Text(
                          statusName(status: widget.rideRequest!.status.validate()),
                          style: boldTextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.rideRequest!.status == ACCEPTED || widget.rideRequest!.status == BID_ACCEPTED || widget.rideRequest!.status == ARRIVING)
                if (duration != 0)
                  Row(
                    children: [
                      Text("${language.ETA} :", style: boldTextStyle()),
                      5.width,
                      Text(
                        (duration ?? 0) < 1 ? language.arrivingNow : "${duration.toString()} min",
                        style: boldTextStyle(
                          color: (duration ?? 0) < 1 ? Color(0xFF2E7D32) : Color(0xFF1E88E5),
                        ),
                      ),
                    ],
                  )
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.driverData!.driverService!.name.validate(), style: boldTextStyle()),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Text(language.lblCarNumberPlate, style: secondaryTextStyle()),
                        Text('(${widget.driverData!.userDetail!.carPlateNumber.validate()})', style: secondaryTextStyle()),
                      ],
                    ),
                  ],
                ),
              ),
              Visibility(
                visible: widget.rideRequest!.status != IN_PROGRESS && widget.rideRequest!.status != COMPLETED,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: dividerColor), borderRadius: radius(defaultRadius)),
                  child: Text('${language.otp} ${widget.rideRequest!.otp ?? ''}', style: boldTextStyle()),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(defaultRadius),
                child: commonCachedNetworkImage(widget.driverData!.profileImage.validate(), fit: BoxFit.cover, height: 40, width: 40),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${widget.driverData!.firstName.validate()} ${widget.driverData!.lastName.validate()}', style: boldTextStyle()),
                    SizedBox(height: 2),
                    Text('${widget.driverData!.email.validate()}', style: secondaryTextStyle()),
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
                        content: AlertScreen(rideId: widget.rideRequest!.id, regionId: widget.rideRequest!.regionId),
                      );
                    },
                  );
                },
                child: chatCallWidget(Icons.sos),
              ),
              SizedBox(width: 8),
              Visibility(
                visible: userData != null,
                child: inkWellWidget(
                  onTap: () async {
                    if (userData == null || (userData != null && userData!.uid == null)) {
                      init();
                      return;
                    }
                    launchScreen(context, ChatScreen(userData: userData, ride_id: widget.rideRequest!.id!), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                  },
                  child: chatCallWidget(Icons.chat_bubble_outline, chat: true),
                ),
              ),
              SizedBox(width: 8),
              inkWellWidget(
                onTap: () {
                  launchUrl(Uri.parse('tel:${widget.driverData!.contactNumber}'), mode: LaunchMode.externalApplication);
                },
                child: chatCallWidget(Icons.call),
              ),
            ],
          ),
          SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.near_me, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(widget.rideRequest!.startAddress ?? ''.validate(), style: primaryTextStyle(size: 14), maxLines: 2)),
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
                  Expanded(child: Text(widget.rideRequest!.endAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2)),
                ],
              ),
              if (widget.rideRequest!.multiDropLocation != null && widget.rideRequest!.multiDropLocation!.isNotEmpty)
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
              if (widget.rideRequest!.multiDropLocation != null && widget.rideRequest!.multiDropLocation!.isNotEmpty)
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
                    showOnlyDropLocationsDialog(context, widget.rideRequest!.multiDropLocation!);
                  },
                )
            ],
          ),
          SizedBox(height: 16),
          if (widget.rideRequest!.status != IN_PROGRESS && widget.rideRequest!.status != COMPLETED)
            AppButtonWidget(
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
                            sharedPref.remove(REMAINING_TIME);
                            sharedPref.remove(IS_TIME);
                            await cancelRequest(reason);
                            appStore.setLoading(false);
                          },
                        );
                      });
                }),
        ],
      ),
    );
  }

  Widget chatCallWidget(IconData icon, {bool chat = false}) {
    if (sharedPref.getString(UID) != null && chat == true) {
      return Stack(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: dividerColor), color: appStore.isDarkMode ? scaffoldColorDark : scaffoldColorLight, borderRadius: BorderRadius.circular(defaultRadius)),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          StreamBuilder<int>(
              stream: chatMessageService.getUnReadCount(senderId: "${sharedPref.getString(UID)}", receiverId: widget.driverData!.uid.toString()),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null && snapshot.data! > 0) {
                  return Positioned(top: -2, right: 0, child: Lottie.asset(messageDetect, width: 18, height: 18, fit: BoxFit.cover));
                }
                return SizedBox();
              })
        ],
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(border: Border.all(color: dividerColor), color: appStore.isDarkMode ? scaffoldColorDark : scaffoldColorLight, borderRadius: BorderRadius.circular(defaultRadius)),
        child: Icon(icon, size: 18, color: primaryColor),
      );
    }
  }
}

void showOnlyDropLocationsDialog(
  BuildContext context,
  List<MultiDropLocation> dropLocations,
) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          language.viewDropLocations,
          style: primaryTextStyle(size: 18, weight: FontWeight.w500),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: dropLocations.map((location) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text(location.address, style: primaryTextStyle(size: 14), overflow: TextOverflow.ellipsis, maxLines: 2)),
                      if (location.droppedAt != null)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        )
                    ],
                  ),
                  Divider(
                    height: 10,
                  )
                ],
              );
            }).toList(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(
              language.close,
              style: primaryTextStyle(),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
        ],
      );
    },
  );
}

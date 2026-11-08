import '../manage_imports.dart';

class DashBoardScreen extends StatefulWidget {
  @override
  DashBoardScreenState createState() => DashBoardScreenState();
  final String? cancelReason;

  DashBoardScreen({this.cancelReason});
}

class DashBoardScreenState extends State<DashBoardScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  RideService rideService = RideService();
  List<Marker> markers = [];
  Set<Polyline> _polyLines = Set<Polyline>();
  List<LatLng> polylineCoordinates = [];
  // late PolylinePoints polylinePoints;
  OnRideRequest? servicesListData;
  double cameraZoom = 17.0, cameraTilt = 0;
  double cameraBearing = 30;
  int onTapIndex = 0;
  int selectIndex = 0;
  late StreamSubscription<ServiceStatus> serviceStatusStream;
  LocationPermission? permissionData;
  late BitmapDescriptor driverIcon;
  List<NearByDriverListModel>? nearDriverModel;
  GoogleMapController? mapController;

  List<OnRideRequest> schedule_ride_request = [];
  String selectedTripType = tripTypeRegular;

  int notificationCount = 0;

  var flightNumberController = TextEditingController();
  var terminalAddressController = TextEditingController();
  var pickupTimeController = TextEditingController();
  var pickupTimeValue /*dropTimeValue*/;

  int serviceType = 0;
  double? lat;
  double? long;
  String? addressTitle;
  Offset position = Offset(200, 150);

  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    listenForNewRideRequests();
    _animController = AnimationController(vsync: this, duration: Duration(milliseconds: 800))..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 0.4).animate(_animController);

    locationPermission();
    if (app_update_check != null) {
      VersionService().getVersionData(context, app_update_check);
    }
    if (widget.cancelReason != null) {
      afterBuildCreated(() {
        _triggerCanceledPopup();
      });
    }
    afterBuildCreated(() {
      init();
      checkAndShowFirebasePopup();
    });
  }

  void init() async {
    getCurrentRequest();

    getCurrentUserLocation();
    riderIcon = await getResizedMarker(SourceIcon);
    driverIcon = await getResizedMarker(DriverIcon);

    // polylinePoints = PolylinePoints();
  }

  Future<void> checkAndShowFirebasePopup() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('show_popup').doc('config'); // single config document
      final doc = await docRef.get();
      if (!doc.exists) {
        // Create default document
        await docRef.set({
          "show_popup": false,
          "message": "",
          "title": "",
        });
        return;
      }
      bool showPopup = doc.data()?['show_popup'] ?? false;
      String message = doc.data()?['message'] ?? "";
      String title = doc.data()?['title'] ?? "";

      if (showPopup) {
        Future.delayed(Duration(milliseconds: 500), () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return popupDialog(title, message, context);
            },
          );
        });
      }
    } catch (e) {
      print("Popup Error: $e");
    }
  }

  Future<void> getCurrentUserLocation() async {
    if (permissionData != LocationPermission.denied) {
      final geoPosition = await Geolocator.getCurrentPosition(timeLimit: Duration(seconds: 30), desiredAccuracy: LocationAccuracy.high);

      lat = geoPosition.longitude;
      long = geoPosition.longitude;

      sourceLocation = LatLng(geoPosition.latitude, geoPosition.longitude);
      try {
        List<Placemark>? placemarks = await placemarkFromCoordinates(geoPosition.latitude, geoPosition.longitude);
        Placemark places = placemarks[0];
        addressTitle = "${places.name != null ? places.name : places.subThoroughfare}, ${places.subLocality}, ${places.locality}, ${places.administrativeArea} ${places.postalCode}, ${places.country}";
        await getNearByDriver();

        //set Country
        sharedPref.setString(COUNTRY, placemarks[0].isoCountryCode.validate(value: defaultCountry));

        Placemark place = placemarks[0];
        sourceLocationTitle = "${place.name != null ? place.name : place.subThoroughfare}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}, ${place.country}";
        polylineSource = LatLng(geoPosition.latitude, geoPosition.longitude);
      } catch (e) {
        throw e;
      }
      addMarker();
      startLocationTracking();

      setState(() {});
    } else {
      launchScreen(navigatorKey.currentState!.overlay!.context, LocationPermissionScreen());
    }
  }

  Future<void> getCurrentRequest() async {
    await getCurrentRideRequest().then((value) async {
      servicesListData = value.rideRequest ?? value.onRideRequest;
      schedule_ride_request = value.schedule_ride_request ?? [];
      notificationCount = value.all_unread_count;

      // Save scratch card flag whenever API responds (not just when ride is active)
      if (value.enable_scratch_card != null) {
        sharedPref.setBool("ENABLE_SCRATCH_CARD", value.enable_scratch_card!);
      }

      if (servicesListData == null) {
        sharedPref.remove(REMAINING_TIME);
        sharedPref.remove(IS_TIME);
        setState(() {});
      }
      if (servicesListData != null) {
        if ((value.ride_has_bids == 1) && (servicesListData!.status == NEW_RIDE_REQUESTED || servicesListData!.status == "bid_rejected")) {
          launchScreen(
            context,
            isNewTask: true,
            Bidingscreen(dt: servicesListData!.isSchedule == 1 ? servicesListData!.schedule_datetime : servicesListData!.datetime, ride_id: servicesListData!.id!, source: {}, endLocation: {}, multiDropObj: {}, multiDropLocationNamesObj: {}),
            pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
          );
        } else if (servicesListData!.status != COMPLETED && servicesListData!.status != CANCELED) {
          int x = 0;
          if (value.rideRequest == null && value.onRideRequest == null) {
            x = servicesListData!.id!;
          } else {
            x = value.rideRequest != null ? value.rideRequest!.id! : value.onRideRequest!.id!;
          }
          QuerySnapshot<Object?> b = await rideService.checkIsRideExist(rideId: x);
          if (b.docs.length > 0) {
            // Check Condition so screen looping issue not occur
            // if Ride Not exist in firebase than don't navigate to next screen
            // return;
            launchScreen(
              getContext,
              Newestimateridelistwidget(
                dt: servicesListData!.isSchedule == 1 ? servicesListData!.schedule_datetime : servicesListData!.datetime,
                timezone: value.timezone,
                sourceLatLog: LatLng(double.parse(servicesListData!.startLatitude!), double.parse(servicesListData!.startLongitude!)),
                destinationLatLog: LatLng(double.parse(servicesListData!.endLatitude!), double.parse(servicesListData!.endLongitude!)),
                sourceTitle: servicesListData!.startAddress!,
                destinationTitle: servicesListData!.endAddress!,
                isCurrentRequest: true,
                servicesId: servicesListData!.serviceId,
                id: servicesListData!.id,
                is_taxi_service: true,
                trip_type: servicesListData?.trip_type ?? '',
              ),
              pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
            );
          } else {
            if (value.schedule_ride_request != null && value.schedule_ride_request!.isNotEmpty) {
              if (value.schedule_ride_request!.first.id == x) {
                return;
              }
            }
            return toast(rideNotFound);
          }
        } else if (servicesListData!.status == COMPLETED && servicesListData!.isRiderRated == 0) {
          Future.delayed(Duration(seconds: 1), () {
            launchScreen(
              getContext,
              ReviewScreen(rideRequest: servicesListData!, driverData: value.driver),
              pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
              isNewTask: true,
            );
          });
        }
      } else if (value.payment != null && value.payment!.paymentStatus != "paid") {
        launchScreen(getContext, RidePaymentDetailScreen(rideId: value.payment!.rideRequestId), pageRouteAnimation: PageRouteAnimation.SlideBottomTop, isNewTask: true);
      }
    }).catchError((error, s) {
      log(error.toString() + "::$s");
      print("CHecking200:::$error ===$s");
    });
  }

  Future<void> locationPermission() async {
    serviceStatusStream = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) {
        if (status == ServiceStatus.disabled) {
          launchScreen(navigatorKey.currentState!.overlay!.context, LocationPermissionScreen());
        } else if (status == ServiceStatus.enabled) {
          getCurrentUserLocation();
          if (locationScreenKey.currentContext != null) {
            if (Navigator.canPop(navigatorKey.currentState!.overlay!.context)) {
              Navigator.pop(navigatorKey.currentState!.overlay!.context);
            }
          }
        }
      },
      onError: (error) {
        //
      },
    );
  }

  addMarker() {
    markers.add(
      Marker(
        markerId: MarkerId('Order Detail'),
        position: sourceLocation!,
        draggable: true,
        infoWindow: InfoWindow(title: sourceLocationTitle, snippet: ''),
        icon: riderIcon,
      ),
    );
  }

  Future<void> startLocationTracking() async {
    Map req = {"latitude": sourceLocation!.latitude.toString(), "longitude": sourceLocation!.longitude.toString()};
    await updateStatus(req).then((value) {}).catchError((error) {
      log(error);
    });
  }

  Future<void> getNearByDriver() async {
    await getNearByDriverList(latLng: sourceLocation).then((value) async {
      value.data!.forEach((element) async {
        print("CHECKIMAGE:::${element}");
        try {
          var driverIcon1 = await getNetworkImageMarker(element.service_marker.validate());
          // markers.add(
          //   Marker(
          //     markerId: MarkerId('Driver${element.id}'),
          //     position: LatLng(double.parse(element.latitude!.toString()), double.parse(element.longitude!.toString())),
          //     infoWindow: InfoWindow(title: '${element.firstName} ${element.lastName}', snippet: ''),
          //     icon: driverIcon1,
          //   ),
          // );

          markers.removeWhere((marker) => marker.markerId.value == "Driver${element.id}");

          markers.add(
            Marker(
              markerId: MarkerId('Driver${element.id}'),
              position: LatLng(double.parse(element.latitude!.toString()), double.parse(element.longitude!.toString())),
              rotation: element.currentHeading?.toDouble() ?? 0.0,
              anchor: Offset(0.5, 0.5),
              infoWindow: InfoWindow(title: '${element.firstName} ${element.lastName}', snippet: ''),
              icon: driverIcon1,
            ),
          );

          setState(() {});
        } catch (e, s) {
          print(e.toString());
          print(s.toString());
          markers.add(
            Marker(
              markerId: MarkerId('Driver${element.id}'),
              position: LatLng(double.parse(element.latitude!.toString()), double.parse(element.longitude!.toString())),
              infoWindow: InfoWindow(title: '${element.firstName} ${element.lastName}', snippet: ''),
              icon: driverIcon,
            ),
          );
          setState(() {});
        }
      });
    }).catchError((e, s) {
      print("ERROR  FOUND:::$e ++++>$s");
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void listenForNewRideRequests() {
    FirebaseFirestore.instance.collection(RIDE_COLLECTION).where('rider_id', isEqualTo: sharedPref.getInt(USER_ID)!).where('status', isEqualTo: NEW_RIDE_REQUESTED).where('book_by_admin', isEqualTo: true).snapshots().listen((QuerySnapshot snapshot) {
      for (var doc in snapshot.docs) {
        var rideData = doc.data() as Map<String, dynamic>;

        if (rideData['book_by_admin'] == true && !isPopupOpen) {
          isPopupOpen = true;
          getCurrentRequest();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    LiveStream().on(CHANGE_LANGUAGE, (p0) {
      setState(() {});
    });
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarColor: Colors.transparent, statusBarBrightness: Brightness.dark),
        toolbarHeight: 0,
      ),
      resizeToAvoidBottomInset: true,
      key: _scaffoldKey,
      // drawer: DrawerComponent(),
      drawer: DrawerComponent(
        onClose: (value) {
          if (value == 'openBottom') {
            Future.delayed(Duration.zero).then((val) {
              serviceType = 1;
              setState(() {});
            });
          }
        },
      ),
      body: Stack(
        children: [
          if (sharedPref.getDouble(LATITUDE) != null && sharedPref.getDouble(LONGITUDE) != null)
            GoogleMap(
              onMapCreated: (controller) {
                mapController = controller;
              },
              padding: EdgeInsets.only(top: context.statusBarHeight + 4 + 24),
              compassEnabled: true,
              myLocationButtonEnabled: false,
              myLocationEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              markers: markers.map((e) => e).toSet(),
              polylines: _polyLines,
              initialCameraPosition: CameraPosition(target: sourceLocation ?? LatLng(sharedPref.getDouble(LATITUDE)!, sharedPref.getDouble(LONGITUDE)!), zoom: cameraZoom, tilt: cameraTilt, bearing: cameraBearing),
            ),
          Positioned(
            top: context.statusBarHeight + 4,
            right: 14,
            left: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                topWidget(),
                SizedBox(height: 8),
                inkWellWidget(
                  onTap: () async {
                    // final geoPosition = await Geolocator.getCurrentPosition(timeLimit: Duration(seconds: 30), desiredAccuracy: LocationAccuracy.high);
                    // mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(geoPosition.latitude, geoPosition.longitude)));
                    appStore.setLoading(true);
                    try {
                      final geoPosition = await Geolocator.getCurrentPosition(
                        timeLimit: const Duration(seconds: 30),
                        desiredAccuracy: LocationAccuracy.high,
                      );

                      mapController!.animateCamera(
                        CameraUpdate.newLatLng(
                          LatLng(geoPosition.latitude, geoPosition.longitude),
                        ),
                      );
                    } on TimeoutException catch (_) {
                      toast("Location request timed out");
                    } on PermissionDeniedException catch (_) {
                      toast("Location permission denied");
                    } catch (e) {
                      toast("Unable to fetch location: $e");
                    } finally {
                      appStore.setLoading(false);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), spreadRadius: 1)],
                      borderRadius: BorderRadius.circular(defaultRadius),
                    ),
                    child: Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          if (serviceType == 0)
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      serviceType = 1;
                      setState(() {});
                    },
                    child: BookServiceButton(),
                  ),
                ],
              ),
            ),
          if (serviceType == 1)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(defaultRadius),
                  boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 2, spreadRadius: 1)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SizedBox(width: 24),
                        Container(
                          alignment: Alignment.center,
                          margin: EdgeInsets.only(bottom: 12),
                          height: 5,
                          width: 70,
                          decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                        ),
                        inkWellWidget(
                          onTap: () {
                            setState(() {
                              serviceType = 0;
                              pickupTimeValue = null;
                              pickupTimeController.clear();
                              flightNumberController.clear();
                              terminalAddressController.clear();
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: dividerColor),
                            ),
                            child: Icon(Icons.close, color: context.iconColor, size: 24),
                          ),
                        ),
                      ],
                    ),
                    Text("${language.tripType}".capitalizeFirstLetter(), style: primaryTextStyle()),
                    SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(defaultRadius), color: Colors.grey.withValues(alpha: 0.15)),
                      width: MediaQuery.of(context).size.width,
                      padding: EdgeInsets.only(right: 8),
                      child: DropdownButton<String>(
                        value: selectedTripType,
                        borderRadius: BorderRadius.circular(defaultRadius),
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        underline: SizedBox(),
                        items: tripTypeList.map((e) {
                          return DropdownMenuItem(
                            value: e,
                            child: Padding(
                              padding: EdgeInsets.only(left: 16, right: 16),
                              child: Text(getMultiLanguageTripType(e.validate()), style: primaryTextStyle()),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          selectedTripType = val ?? '';
                          pickupTimeValue = null;
                          pickupTimeController.clear();
                          flightNumberController.clear();
                          terminalAddressController.clear();
                          setState(() {});
                        },
                      ),
                    ),
                    // if Airport Pick Or Drop case view
                    if (selectedTripType == tripTypeAirportDropoff || selectedTripType == tripTypeAirportPickup || selectedTripType == tripTypeAirportToZone || selectedTripType == tripTypeZoneToAirport)
                      Column(
                        children: [
                          // preferred drop-off time
                          // preferred pickup time
                          SizedBox(height: 12),
                          // flight number
                          AppTextField(
                            controller: flightNumberController,
                            autoFocus: false,
                            textFieldType: TextFieldType.NAME,
                            errorThisFieldRequired: errorThisFieldRequired,
                            decoration: inputDecoration(context, label: '${language.flightNumber}', prefixIcon: Icon(Icons.flight)),
                          ),
                          SizedBox(height: 8),
                          // Pickup points
                          AppTextField(
                            controller: terminalAddressController,
                            autoFocus: false,
                            textFieldType: TextFieldType.NAME,
                            errorThisFieldRequired: errorThisFieldRequired,
                            decoration: inputDecoration(context, label: '${language.terminalAddress}', prefixIcon: Icon(Icons.airport_shuttle)),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(padding: EdgeInsets.only(top: 4.0, right: 2), child: Icon(Icons.info_outline_rounded, size: 12)),
                              Expanded(child: Text('${language.terminalHelperText}', style: secondaryTextStyle())),
                            ],
                          ),
                          SizedBox(height: 8),
                          // Preferred Pickup Time
                          AppTextField(
                            controller: pickupTimeController,
                            autoFocus: false,
                            textFieldType: TextFieldType.NAME,
                            readOnly: true,
                            enabled: true,
                            onTap: () async {
                              DateTime? d1 = await showDatePicker(
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      primaryColor: primaryColor, // Header background color
                                      hintColor: primaryColor, // Selected date highlight color
                                      colorScheme: ColorScheme.light(primary: primaryColor),
                                      buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
                                    ),
                                    child: child!,
                                  );
                                },
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(Duration(days: 45)),
                              );

                              bool isToday = DateUtils.isSameDay(d1, DateTime.now());

                              TimeOfDay initialTime = TimeOfDay(hour: isToday ? DateTime.now().hour : 0, minute: isToday ? DateTime.now().minute : 0);

                              if (d1 != null) {
                                TimeOfDay? t1 = await showTimePicker(
                                  initialTime: initialTime,
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.light().copyWith(
                                        primaryColor: primaryColor,
                                        hintColor: primaryColor,
                                        colorScheme: ColorScheme.light(primary: primaryColor),
                                        buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
                                      ),
                                      child: child!,
                                    );
                                  },
                                  context: context,
                                );

                                if (t1 != null) {
                                  final selectedDateTime = DateTime(d1.year, d1.month, d1.day, t1.hour, t1.minute);
                                  final now = DateTime.now();

                                  if (selectedDateTime.isAfter(now)) {
                                    setState(() {
                                      pickupTimeValue = selectedDateTime.toString();
                                      pickupTimeController.text = DateFormat('dd MMM yy hh:mm a').format(selectedDateTime);
                                    });
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a future time.')));
                                  }
                                }
                              }
                            },
                            errorThisFieldRequired: errorThisFieldRequired,
                            decoration: inputDecoration(context, label: '${language.preferredPickupTime}', prefixIcon: Icon(Icons.access_time_rounded)),
                          ),
                          SizedBox(height: 8),
                        ],
                      ),
                    SizedBox(height: 12),
                    AppButtonWidget(
                      color: primaryColor,
                      onTap: () async {
                        var tripDetail = {};
                        if (selectedTripType == tripTypeAirportDropoff || selectedTripType == tripTypeAirportPickup || selectedTripType == tripTypeAirportToZone || selectedTripType == tripTypeZoneToAirport) {
                          tripDetail['flight_number'] = flightNumberController.text;
                          tripDetail['pickup_point'] = terminalAddressController.text;
                          tripDetail['preferred_pickup_time'] = pickupTimeValue;
                        }
                        tripDetail['trip_type'] = getTripTypeValue(selectedTripType);
                        if (selectedTripType.toLowerCase().contains("airport") && flightNumberController.text.isEmpty) {
                          return toast("Please Provide Flight Number");
                        }
                        if (selectedTripType.toLowerCase().contains("airport") && pickupTimeController.text.isEmpty) {
                          return toast("Please Pickup Time");
                        }
                        showModalBottomSheet(
                          isScrollControlled: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius)),
                          ),
                          context: context,
                          builder: (_) {
                            return TripTypeLocationComponent(
                              trip_type: selectedTripType,
                              tripDetail: tripDetail,
                              pickupTimeValue: pickupTimeValue,
                              // lat: lat,
                              // long: long,
                              addressTitle: addressTitle,
                            );
                          },
                        );
                      },
                      text: language.continueD,
                      textStyle: boldTextStyle(color: Colors.white),
                      width: MediaQuery.of(context).size.width,
                    ),
                  ],
                ),
              ),
            ),
          Visibility(visible: appStore.isLoading, child: loaderWidget()),
          if (schedule_ride_request.isNotEmpty)
            Positioned(
              left: position.dx,
              top: position.dy,
              child: Draggable(
                feedback: buildFloatingWidget(),
                childWhenDragging: Container(),
                onDragEnd: (details) {
                  final newOffset = details.offset;

                  final screenSize = MediaQuery.of(context).size;
                  final safeX = newOffset.dx.clamp(0.0, screenSize.width - 150);
                  final safeY = newOffset.dy.clamp(0.0, screenSize.height - 56);

                  setState(() {
                    position = Offset(safeX, safeY);
                  });
                },
                child: GestureDetector(
                  onTap: () {
                    launchScreen(context, ScheduleRideListScreen());
                  },
                  child: buildFloatingWidget(),
                ),
              ),
            ),
          Observer(
            builder: (context) => Visibility(
              visible: appStore.isLoading,
              child: Positioned.fill(child: loaderWidget()),
            ),
          ),
        ],
      ),
    );
  }

  Widget topWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        inkWellWidget(
          onTap: () {
            _scaffoldKey.currentState!.openDrawer();
          },
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), spreadRadius: 1)],
              borderRadius: BorderRadius.circular(defaultRadius),
            ),
            child: Icon(Icons.drag_handle),
          ),
        ),
        inkWellWidget(
          onTap: () async {
            launchScreen(context, NotificationScreen(), pageRouteAnimation: PageRouteAnimation.Slide).then((v) {
              notificationCount = 0;
              setState(() {});
            });
          },
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), spreadRadius: 1)],
              borderRadius: BorderRadius.circular(defaultRadius),
            ),
            child: Stack(
              children: [
                Icon(Ionicons.notifications_outline),
                if (notificationCount != 0)
                  Positioned(
                    right: 0,
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.only(bottom: 2),
                      height: 12,
                      width: 12,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                      child: Text(
                        notificationCount.toString(),
                        style: boldTextStyle(color: Colors.white, size: 8, weight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _triggerCanceledPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text("${language.rideCanceledByDriver}", maxLines: 2, style: boldTextStyle())),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Icon(Icons.clear),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${language.cancelledReason}", style: secondaryTextStyle()),
              Text(widget.cancelReason.validate(), style: primaryTextStyle()),
            ],
          ),
        );
      },
    );
  }

  Widget buildFloatingWidget() {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        height: 56,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 2, spreadRadius: 1)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(messageDetect, height: 30, width: 30, fit: BoxFit.cover),
            SizedBox(width: 8),
            Text('${language.lblUpcomingService}', style: boldTextStyle(size: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> cancelRequest(String reason, {int? ride_id}) async {
    Map req = {"id": ride_id, "cancel_by": RIDER, "status": CANCELED, "reason": reason};
    await rideRequestUpdate(request: req, rideId: ride_id).then((value) async {
      getCurrentRequest();
      toast(value.message);
    }).catchError((error) {});
  }
}

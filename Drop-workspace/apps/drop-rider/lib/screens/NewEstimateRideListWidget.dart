import '../manage_imports.dart';

// ignore: must_be_immutable
class Newestimateridelistwidget extends StatefulWidget {
  final LatLng sourceLatLog;
  final LatLng destinationLatLog;
  final String sourceTitle;
  final String destinationTitle;
  bool isCurrentRequest;
  final int? servicesId;
  final int? id;
  Map? multiDropLocationNamesObj;
  Map? multiDropObj;
  String? dt;
  String? timezone;
  String? pickupTimeValue;
  bool is_taxi_service;
  var tripDetail;
  String trip_type;

  Newestimateridelistwidget({
    required this.sourceLatLog,
    required this.destinationLatLog,
    required this.sourceTitle,
    required this.destinationTitle,
    this.isCurrentRequest = false,
    this.servicesId,
    this.id,
    this.multiDropLocationNamesObj,
    this.multiDropObj,
    this.pickupTimeValue,
    this.dt,
    this.timezone,
    required this.is_taxi_service,
    this.tripDetail,
    required this.trip_type,
  });

  @override
  NewestimateridelistwidgetState createState() => NewestimateridelistwidgetState();
}

class NewestimateridelistwidgetState extends State<Newestimateridelistwidget> with WidgetsBindingObserver {
  late Stream stream;
  String serviceMarker = '';
  double driverCarHeading = 0.0;
  StreamSubscription<Position>? positionStream;
  late StreamSubscription<ServiceStatus> serviceStatusStream;
  bool locationEnable = true;
  RideService rideService = RideService();
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController promoCode = TextEditingController();
  Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? googleMapController;
  final Set<Marker> markers = {};
  String countryCode = defaultCountryCode;
  Set<Polyline> polyLines = Set<Polyline>();
  // late PolylinePoints polylinePoints;
  late Marker sourceMarker;
  late Marker destinationMarker;
  late LatLng userLatLong;
  late DateTime scheduleData;
  String? distanceUnit = DISTANCE_TYPE_KM;
  bool isBooking = false;
  bool isRideSelection = false;
  bool bidingEnabled = false;
  bool bidRaised = false;
  bool isRideForOther = true;
  int selectedIndex = 0;
  int rideRequestId = 0;
  num mTotalAmount = 0;
  double? durationOfDrop = 0.0;
  bool rideCancelDetected = false;
  double? distance = 0;
  double locationDistance = 0.0;
  String? mSelectServiceAmount;
  List<String> cashList = [CASH, WALLET];
  List<ServicesListData> serviceList = [];
  List<LatLng> polylineCoordinates = [];
  LatLng? driverLatitudeLocation;
  LatLng? myLocation;
  String paymentMethodType = '';
  String? oldPaymentType;
  ServicesListData? servicesListData;
  OnRideRequest? rideRequestData;
  Driver? driverData;
  Timer? timer;
  DateTime? schduleRideDateTime;
  var key = GlobalKey<ScaffoldState>();
  late BitmapDescriptor sourceIcon;
  late BitmapDescriptor destinationIcon;
  late BitmapDescriptor driverIcon;
  bool currentScreen = true;

  String? formattedTime;
  String? parsedDate;
  late FocusNode myFocusNode;
  TextEditingController bidAmountController = TextEditingController();

  LatLng? lastSentLocation;
  LatLng? riderLocation;

  // COIN FEATURE VARIABLES - ADDED
  int usedCoins = 0;
  bool useCoinsEnabled = false;
  num totalCoins = 0;
  double coinDiscount = 0.0;

  List<List<LatLng>> fullMultiRoutes = []; // store all segments
  List<List<LatLng>> remainingMultiRoutes = [];
  List<LatLng> fullRouteCoordinates = [];

  bool isRouteLoaded = false;
  int count = 0;
  bool shouldForceUpdate = false;
  int _markerAnimToken = 0;
  double currentHeading = 0.0;
  double? lastHeading;

  @override
  void initState() {
    super.initState();
    myFocusNode = FocusNode();
    WidgetsBinding.instance.addObserver(this);

    init();
    getNewService();
    if (appStore.isLoggedIn) {
      startLocationTracking();
    }
  }

  Future<void> locationPermission() async {
    try {
      await startLocationTracking();
      addDriverMarker();
    } catch (e) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (key.currentContext != null) {
      if (state == AppLifecycleState.paused) {
        positionStream?.pause(); // safe
      } else if (state == AppLifecycleState.resumed) {
        // final GoogleMapController controller = await _controller.future;
        // onMapCreated(controller);
        positionStream?.resume();
      }
    }
  }

  void init() async {
    sourceIcon = await getResizedMarker(SourceIcon);
    driverIcon = await getResizedMarker(DriverIcon);
    destinationIcon = await getResizedMarker(DestinationIcon);

    //destinationIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DestinationIcon);

    // driverIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), Platform.isIOS ? DriverIOSIcon : DriverIcon);
    getCurrentRequest();
    // if (!widget.isCurrentRequest) getNewService();
    isBooking = widget.isCurrentRequest;
    getWalletDataApi();
  }

  /// Get Current Location
  // Future<void> startLocationTracking() async {
  //   print("CheckLocation UpdateCall");
  //   await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((value) async {
  //     await Geolocator.isLocationServiceEnabled().then((value) async {
  //       if (locationEnable) {
  //         final LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 100, timeLimit: Duration(seconds: 30));
  //         positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((event) async {
  //           if (rideRequestData!.status == IN_PROGRESS) {
  //             if (myLocation != null) {
  //               bool b = isDistanceMoreThan100Meters(startLat: myLocation!.latitude, startLng: myLocation!.longitude, endLat: event.latitude, endLng: event.longitude);
  //               if (b) {
  //                 final newLocation = LatLng(event.latitude, event.longitude);
  //                 print("100 m update");
  //                 setPolyLines(
  //                   sourceLocation: LatLng(event.latitude, event.longitude),
  //                   destinationLocation: LatLng(widget.destinationLatLog.latitude, widget.destinationLatLog.longitude),
  //                   driverLocation: driverLatitudeLocation,
  //                 );
  //                 moveCameraToDriver(googleMapController!, newLocation);
  //               }
  //             } else {
  //               myLocation = LatLng(event.latitude, event.longitude);
  //             }
  //           }
  //         }, onError: (error) {
  //           positionStream?.cancel();
  //         });
  //       }
  //     });
  //   }).catchError((error) {
  //     Future.delayed(
  //       Duration(seconds: 1),
  //       () {
  //         launchScreen(navigatorKey.currentState!.overlay!.context, LocationPermissionScreen());
  //       },
  //     );
  //   });
  // }

  Future<void> startLocationTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          launchScreen(
            navigatorKey.currentState!.overlay!.context,
            LocationPermissionScreen(),
          );
          return;
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        launchScreen(
          navigatorKey.currentState!.overlay!.context,
          LocationPermissionScreen(),
        );
        return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high, // avoid drift
        distanceFilter: 2, // OS hint
      );

      await positionStream?.cancel();

      positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position event) async {
        print(
          "GPS → Lat:${event.latitude}, "
          "Lng:${event.longitude}, "
          "Accuracy:${event.accuracy}",
        );

        try {
          if (event.accuracy > 25) {
            print("Ignored due to bad accuracy");
            return;
          }

          final rawLocation = LatLng(event.latitude, event.longitude);

          LatLng newLocation;

          if (lastSentLocation != null) {
            newLocation = smoothLocation(lastSentLocation!, rawLocation);
          } else {
            newLocation = rawLocation;
          }

          if (lastSentLocation == null) {
            lastSentLocation = newLocation;
            riderLocation = newLocation;

            return;
          }

          final now = DateTime.now();
          final lastCall = sharedPref.getString("UPDATE_CALL");

          if (lastCall != null) {
            final last = DateTime.parse(lastCall);

            if (now.difference(last).inSeconds >= 10) {
              shouldForceUpdate = true;
            }
          }

          final distance = Geolocator.distanceBetween(
            lastSentLocation!.latitude,
            lastSentLocation!.longitude,
            newLocation.latitude,
            newLocation.longitude,
          );

          if (distance >= 5 || event.speed > 2 || event.speed == 0 || shouldForceUpdate) {
            final double gpsBearing = getBearing(lastSentLocation!, newLocation);
            currentHeading = gpsBearing;
            lastHeading = gpsBearing;

            final LatLng animStart = lastSentLocation!;

            lastSentLocation = newLocation;
            riderLocation = newLocation;

            _animateDriverMarker(animStart, newLocation);
            if (distance > 12) {
              setPolyLines(
                sourceLocation: LatLng(event.latitude, event.longitude),
                destinationLocation: LatLng(widget.destinationLatLog.latitude, widget.destinationLatLog.longitude),
                driverLocation: riderLocation,
              );
            }
            if (count % 5 == 0) {
              moveCameraToRider(googleMapController!, newLocation);
            }
            count++;

            sharedPref.setString("UPDATE_CALL", DateTime.now().toIso8601String());
          }
        } catch (e) {
          log("Error inside location stream: $e");
        }
      }, onError: (error) {
        log("STREAM ERROR: $error");
        restartLocationTracking();
      });
    } catch (e) {
      log("startLocationTracking ERROR: $e");
    }
  }

  double getBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;
    double dLon = lon2 - lon1;
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double brng = atan2(y, x);
    return (brng * 180 / pi + 360) % 360;
  }

  void addDriverMarker() async {
    // late BitmapDescriptor driverIcon;
    try {
      driverIcon = await getNetworkImageMarker(serviceMarker.validate());
    } catch (e) {
      driverIcon = await getResizedMarker(DriverIcon);
    }
    markers.removeWhere((marker) => marker.markerId.value == "driver");

    markers.add(
      Marker(
        markerId: MarkerId("driver"),
        position: riderLocation!,
        icon: driverIcon,
        rotation: currentHeading,
        anchor: Offset(0.5, 0.5),
        infoWindow: InfoWindow(title: ''),
      ),
    );
    setState(() {});
  }

  Future<void> _animateDriverMarker(LatLng start, LatLng end) async {
    // var driverIcon = await getNetworkImageMarker(serviceMarker.validate());

    final int myToken = ++_markerAnimToken;

    const int steps = 60;
    const Duration stepDelay = Duration(milliseconds: 16);
    const MarkerId driverId = MarkerId('driver');

    final double latDelta = end.latitude - start.latitude;
    final double lngDelta = end.longitude - start.longitude;
    final double bearing = getBearing(start, end);

    if (!markers.any((m) => m.markerId == driverId)) {
      markers.add(Marker(
        markerId: driverId,
        position: start,
        icon: driverIcon,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        rotation: bearing,
        infoWindow: const InfoWindow(title: ''),
      ));
    }

    for (int i = 1; i <= steps; i++) {
      if (_markerAnimToken != myToken || !mounted) return;

      final double t = i / steps;
      final LatLng interpolated = LatLng(
        start.latitude + latDelta * t,
        start.longitude + lngDelta * t,
      );

      final Marker? existing = markers.cast<Marker?>().firstWhere(
            (m) => m?.markerId == driverId,
            orElse: () => null,
          );

      if (existing != null) {
        markers.remove(existing);
        markers.add(existing.copyWith(
          positionParam: interpolated,
          rotationParam: bearing,
          iconParam: driverIcon,
          flatParam: true,
          anchorParam: const Offset(0.5, 0.5),
        ));
      } else {
        markers.add(Marker(
          markerId: driverId,
          position: interpolated,
          icon: driverIcon,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          rotation: bearing,
          infoWindow: const InfoWindow(title: ''),
        ));
      }

      if (mounted) setState(() {});
      await Future.delayed(stepDelay);
    }
  }

  LatLng smoothLocation(LatLng old, LatLng current) {
    return LatLng(
      old.latitude + (current.latitude - old.latitude) * 0.3,
      old.longitude + (current.longitude - old.longitude) * 0.3,
    );
  }

  Future<void> moveCameraToRider(GoogleMapController mapController, LatLng riderLocation) async {
    try {
      // Apply a small downward shift (move map upward visually)
      final adjustedLocation = LatLng(
        riderLocation.latitude - 0.0030, // adjust this value as needed
        riderLocation.longitude,
      );

      await mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: adjustedLocation,
            zoom: 15.5,
          ),
        ),
      );
    } catch (e) {
      print("Error moving camera: $e");
    }
  }

  void restartLocationTracking() {
    Future.delayed(Duration(seconds: 2), () {
      startLocationTracking();
    });
  }

  getCurrentRequest() async {
    try {
      timer!.cancel();
    } catch (e) {}
    await getCurrentRideRequest().then((value) {
      serviceMarker = value.service_marker.validate();
      rideRequestData = value.rideRequest ?? value.onRideRequest;
      if (rideRequestData == null && value.schedule_ride_request!.isNotEmpty) {
        rideRequestData = value.schedule_ride_request!.first;
      }
      if (value.driver != null) {
        driverData = value.driver!;
        getUserDetailLocation();
      } else {
        getServiceList();
      }
      if (rideRequestData != null) {
        if (rideRequestData != null) {
          if (driverData != null && rideRequestData!.status != COMPLETED && rideRequestData!.status != IN_PROGRESS) {
            timer = Timer.periodic(Duration(seconds: 10), (Timer t) {
              DateTime? d = DateTime.tryParse(sharedPref.getString("UPDATE_CALL").toString());
              if (d != null && DateTime.now().difference(d).inSeconds > 10) {
                if (rideRequestData != null && (rideRequestData!.status == ACCEPTED || rideRequestData!.status == ARRIVING || rideRequestData!.status == ARRIVED)) {
                  getUserDetailLocation();
                } else {
                  try {
                    timer!.cancel();
                  } catch (e) {}
                }
                sharedPref.setString("UPDATE_CALL", DateTime.now().toString());
              } else if (d == null) {
                sharedPref.setString("UPDATE_CALL", DateTime.now().toString());
              }
            });
          } else {
            timer?.cancel();
            timer = null;
          }
        }
        setState(() {});
        if (rideRequestData!.status == COMPLETED && rideRequestData != null && driverData != null) {
          if (timer != null) {
            timer!.cancel();
          }
          timer = null;
          if (currentScreen != false) {
            currentScreen = false;
            launchScreen(context, ReviewScreen(rideRequest: rideRequestData!, driverData: driverData), pageRouteAnimation: PageRouteAnimation.SlideBottomTop, isNewTask: true);
          }
        }
        if (rideRequestData!.status == IN_PROGRESS) {
          locationPermission();
        }
      } else if (appStore.isRiderForAnother == "1" && value.payment != null && value.payment!.paymentStatus == SUCCESS) {
        if (currentScreen != false) {
          currentScreen = false;
          Future.delayed(
            Duration(seconds: 1),
            () {
              launchScreen(context, RidePaymentDetailScreen(rideId: value.payment!.rideRequestId), pageRouteAnimation: PageRouteAnimation.SlideBottomTop, isNewTask: true);
            },
          );
        }
      }
    }).catchError((error, stack) {
      FirebaseCrashlytics.instance.recordError("review_navigate_issue::" + error.toString(), stack, fatal: true);
      log("Error-- " + error.toString());
    });
  }

  Future<void> getServiceList() async {
    markers.clear();
    // polylinePoints = PolylinePoints();
    setPolyLines(
      sourceLocation: LatLng(widget.sourceLatLog.latitude, widget.sourceLatLog.longitude),
      destinationLocation: LatLng(widget.destinationLatLog.latitude, widget.destinationLatLog.longitude),
      driverLocation: driverLatitudeLocation,
    );
    MarkerId id = MarkerId('Source');
    markers.add(
      Marker(
        markerId: id,
        position: LatLng(widget.sourceLatLog.latitude, widget.sourceLatLog.longitude),
        infoWindow: InfoWindow(title: widget.sourceTitle),
        icon: sourceIcon,
      ),
    );
    MarkerId id2 = MarkerId('DriverLocation');
    markers.remove(id2);
    if (rideRequestData != null && rideRequestData!.multiDropLocation != null && rideRequestData!.multiDropLocation!.isNotEmpty && rideRequestData!.status != ACCEPTED && rideRequestData!.status != ARRIVING && rideRequestData!.status != ARRIVED) {
    } else {
      MarkerId id3 = MarkerId('Destination');
      markers.remove(id3);
      if (rideRequestData != null && (rideRequestData!.status == ACCEPTED || rideRequestData!.status == ARRIVING || rideRequestData!.status == ARRIVED)) {
        try {
          var driverIcon1 = await getNetworkImageMarker(serviceMarker.validate());
          markers.add(
            Marker(
              markerId: id2,
              rotation: driverCarHeading,
              position: LatLng(driverLatitudeLocation!.latitude, driverLatitudeLocation!.longitude),
              icon: driverIcon1,
            ),
          );
          setState(() {});
        } catch (e) {
          markers.add(
            Marker(
              markerId: id2,
              rotation: driverCarHeading,
              position: LatLng(driverLatitudeLocation!.latitude, driverLatitudeLocation!.longitude),
              icon: driverIcon,
            ),
          );
        }
        // markers.add(
        //   Marker(
        //     markerId: id2,
        //     position: LatLng(driverLatitudeLocation!.latitude, driverLatitudeLocation!.longitude),
        //     icon: driverIcon,
        //   ),
        // );
      } else {
        markers.add(
          Marker(
            markerId: id3,
            position: LatLng(widget.destinationLatLog.latitude, widget.destinationLatLog.longitude),
            infoWindow: InfoWindow(title: widget.destinationTitle),
            icon: destinationIcon,
          ),
        );
      }
    }
    setState(() {});
  }

  Future<void> getNewService({bool coupon = false}) async {
    appStore.setLoading(true);
    // final tripDetail = widget.tripDetail;
    Map req = {
      "user_id": sharedPref.getInt(USER_ID),
      "pick_lat": widget.sourceLatLog.latitude,
      "pick_lng": widget.sourceLatLog.longitude,
      "drop_lat": widget.destinationLatLog.latitude,
      "drop_lng": widget.destinationLatLog.longitude,
      "pickup_zone_id": widget.is_taxi_service != true || widget.tripDetail == null ? "" : widget.tripDetail["pickup_zone_id"],
      "drop_zone_id": widget.is_taxi_service != true || widget.tripDetail == null ? "" : widget.tripDetail["drop_zone_id"],
      "pickup_airport_id": widget.is_taxi_service != true || widget.tripDetail == null ? "" : widget.tripDetail["pickup_airport_id"],
      "drop_airport_id": widget.is_taxi_service != true || widget.tripDetail == null ? "" : widget.tripDetail["drop_airport_id"],
      "trip_type": widget.is_taxi_service != true || widget.tripDetail == null ? "" : widget.tripDetail["trip_type"],
      if (coupon) "coupon_code": promoCode.text.trim(),
    };
    var dataJustCheck = [];
    dataJustCheck.add({"lat": widget.sourceLatLog.latitude, "lng": widget.sourceLatLog.longitude});
    if (widget.multiDropObj != null && widget.multiDropObj!.isNotEmpty) {
      widget.multiDropObj!.forEach(
        (key, value) {
          LatLng s = value as LatLng;
          dataJustCheck.add({
            "lat": s.latitude,
            "lng": s.longitude,
          });
        },
      );
      req['multi_location'] = dataJustCheck;
    }

    await estimatePriceList(req).then((value) {
      appStore.setLoading(false);
      serviceList.clear();
      value.data!.sort((a, b) => a.totalAmount!.compareTo(b.totalAmount!));
      serviceList.addAll(value.data!);
      if (value.totalCoins != null) {
        totalCoins = value.totalCoins!;
      }
      if (serviceList.isNotEmpty) {
        locationDistance = serviceList[0].dropoffDistanceInKm!.toDouble();
        if (serviceList[0].distanceUnit == DISTANCE_TYPE_KM) {
          locationDistance = serviceList[0].dropoffDistanceInKm!.toDouble();
          distanceUnit = DISTANCE_TYPE_KM;
        } else {
          locationDistance = serviceList[0].dropoffDistanceInKm!.toDouble() * 0.621371;
          distanceUnit = DISTANCE_TYPE_MILE;
        }
        durationOfDrop = serviceList[0].duration!.toDouble();
      }

      if (serviceList.isNotEmpty) servicesListData = serviceList[0];
      if (serviceList.isNotEmpty) paymentMethodType = serviceList[0].paymentMethod!;
      if (serviceList.isNotEmpty) cashList = paymentMethodType == CASH_WALLET ? cashList = [CASH, WALLET] : cashList = [paymentMethodType];
      if (serviceList.isNotEmpty) {
        if (serviceList[0].discountAmount != 0) {
          mSelectServiceAmount = serviceList[0].subtotal!.toStringAsFixed(fixedDecimal);
        } else {
          mSelectServiceAmount = serviceList[0].totalAmount!.toStringAsFixed(fixedDecimal);
        }
      }
      if (oldPaymentType != null) {
        paymentMethodType = oldPaymentType ?? '';
      }
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString(), print: true);
    });
  }

  Future<void> getCouponNewService() async {
    appStore.setLoading(true);
    final tripDetail = widget.tripDetail;
    Map req = {
      "user_id": sharedPref.getInt(USER_ID),
      "pick_lat": widget.sourceLatLog.latitude,
      "pick_lng": widget.sourceLatLog.longitude,
      "drop_lat": widget.destinationLatLog.latitude,
      "drop_lng": widget.destinationLatLog.longitude,
      "pickup_zone_id": widget.is_taxi_service != true || tripDetail == null ? "" : tripDetail["pickup_zone_id"] ?? "",
      "drop_zone_id": widget.is_taxi_service != true || tripDetail == null ? "" : tripDetail["drop_zone_id"] ?? "",
      "pickup_airport_id": widget.is_taxi_service != true || tripDetail == null ? "" : tripDetail["pickup_airport_id"] ?? "",
      "drop_airport_id": widget.is_taxi_service != true || tripDetail == null ? "" : tripDetail["drop_airport_id"] ?? "",
      "trip_type": widget.is_taxi_service != true || tripDetail == null ? "" : tripDetail["trip_type"] ?? "",
      if (promoCode.text.trim().isNotEmpty) "coupon_code": promoCode.text.trim(),
      if (useCoinsEnabled && usedCoins > 0) "use_coins": usedCoins, // ADDED FOR COINS
    };
    if (widget.multiDropObj != null) {
      var dataJustCheck = [];
      dataJustCheck.add({"lat": widget.sourceLatLog.latitude, "lng": widget.sourceLatLog.longitude});
      widget.multiDropObj!.forEach(
        (key, value) {
          LatLng s = value as LatLng;
          dataJustCheck.add({
            "lat": s.latitude,
            "lng": s.longitude,
          });
        },
      );
      req['multi_location'] = dataJustCheck;
    }

    await estimatePriceList(req).then((value) {
      appStore.setLoading(false);
      serviceList.clear();
      value.data!.sort((a, b) => a.totalAmount!.compareTo(b.totalAmount!));
      serviceList.addAll(value.data!);
      if (value.totalCoins != null) {
        totalCoins = value.totalCoins!;
      }
      if (serviceList.isNotEmpty) {
        locationDistance = serviceList[0].dropoffDistanceInKm!.toDouble();
        if (serviceList[0].distanceUnit == DISTANCE_TYPE_KM) {
          locationDistance = serviceList[0].dropoffDistanceInKm!.toDouble();
          distanceUnit = DISTANCE_TYPE_KM;
        } else {
          locationDistance = serviceList[0].dropoffDistanceInKm!.toDouble() * 0.621371;
          distanceUnit = DISTANCE_TYPE_MILE;
        }
        durationOfDrop = serviceList[0].duration!.toDouble();
      }

      if (serviceList.isNotEmpty) servicesListData = serviceList[0];
      if (serviceList.isNotEmpty) paymentMethodType = serviceList[0].paymentMethod!;
      if (serviceList.isNotEmpty) cashList = paymentMethodType == CASH_WALLET ? cashList = [CASH, WALLET] : cashList = [paymentMethodType];
      if (serviceList.isNotEmpty) {
        if (serviceList[0].discountAmount != 0) {
          mSelectServiceAmount = serviceList[0].subtotal!.toStringAsFixed(fixedDecimal);
        } else {
          mSelectServiceAmount = serviceList[0].totalAmount!.toStringAsFixed(fixedDecimal);
        }
      }
      if (oldPaymentType != null) {
        paymentMethodType = oldPaymentType ?? '';
      }
      setState(() {});
    }).catchError((error) {
      if (promoCode.text.isNotEmpty) promoCode.clear();
      Navigator.pop(context);
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  // COIN SELECTION DIALOG METHOD - ADDED
  // Future<void> showCoinSelectionDialog() async {
  //   if (totalCoins <= 0) {
  //     toast("You don't have any coins available");
  //     return;
  //   }
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) => CoinSelectionDialog(
  //       totalCoins: totalCoins,
  //       rideAmount: double.parse(mSelectServiceAmount ?? '0'),
  //       coinValue: 1, // 1 coin = 1 currency unit, adjust as needed
  //       onConfirm: (selectedCoins) {
  //         setState(() {
  //           usedCoins = selectedCoins;
  //           useCoinsEnabled = selectedCoins > 0;
  //           coinDiscount = selectedCoins.toDouble();
  //         });
  //         // Call API to recalculate price with coins
  //         getCouponNewService();
  //       },
  //     ),
  //   );
  // }

  Future<void> showCoinSelectionBottomSheet() async {
    if (totalCoins <= 0) {
      toast("You don't have any coins available");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CoinSelectionDialog(
        totalCoins: totalCoins,
        rideAmount: double.parse(mSelectServiceAmount ?? '0'),
        coinValue: 1,
        onConfirm: (selectedCoins) {
          setState(() {
            usedCoins = selectedCoins;
            useCoinsEnabled = selectedCoins > 0;
            coinDiscount = selectedCoins.toDouble();
          });
          getCouponNewService();
        },
      ),
    );
  }

  Future<void> setPolyLinesDriver({
    required LatLng sourceLocation,
    LatLng? driverLocation,
  }) async {
    try {
      for (int i = 0; i < rideRequestData!.multiDropLocation!.length; i++) {
        LatLng origin = i == 0
            ? sourceLocation
            : LatLng(
                rideRequestData!.multiDropLocation![i - 1].lat,
                rideRequestData!.multiDropLocation![i - 1].lng,
              );

        LatLng destination = LatLng(
          rideRequestData!.multiDropLocation![i].lat,
          rideRequestData!.multiDropLocation![i].lng,
        );

        String origins = "${origin.latitude},${origin.longitude}";
        String destinations = "${destination.latitude},${destination.longitude}";

        List<LatLng> routeCoordinates = [];

        final value = await getPolylineData(origins, destinations);

        if (value.status != null && value.status!) {
          if (value.polyline != null) {
            final points = decodePolyline(value.polyline!);
            if (points.isNotEmpty) {
              routeCoordinates = points;
            } else {
              debugPrint('---No Data--');
            }
          } else {
            debugPrint('---Polyline Null---');
          }
        } else {
          debugPrint('---Status False or Null---');
        }

        markers.add(
          Marker(
            markerId: MarkerId("multi_drop_$i"),
            position: destination,
            infoWindow: InfoWindow(title: "${rideRequestData!.multiDropLocation![i].address}"),
            icon: destinationIcon,
          ),
        );

        polyLines.add(
          Polyline(
            endCap: Cap.roundCap,
            startCap: Cap.roundCap,
            jointType: JointType.round,
            visible: true,
            width: 7,
            polylineId: PolylineId('multi_poly_$i'),
            color: polyLineColor,
            points: routeCoordinates,
          ),
        );
      }

      setState(() {});
    } catch (e) {
      throw e;
    }
  }

  Future<void> setPolyLines({
    required LatLng sourceLocation,
    required LatLng destinationLocation,
    LatLng? driverLocation,
  }) async {
    print("PolyLineCreatedCall");

    polyLines.clear();
    polylineCoordinates.clear();

    if (rideRequestData != null && rideRequestData!.multiDropLocation != null && rideRequestData!.multiDropLocation!.isNotEmpty && rideRequestData!.status != ACCEPTED && rideRequestData!.status != ARRIVING && rideRequestData!.status != ARRIVED) {
      print("PolyLineCreatedCall410");
      await setPolyLinesDriver(sourceLocation: sourceLocation, driverLocation: driverLocation);
    } else if (widget.multiDropObj != null && widget.multiDropObj!.isNotEmpty && rideRequestData == null) {
      print("PolyLineCreatedCall414");

      try {
        for (int i = 0; i < widget.multiDropObj!.length; i++) {
          LatLng origin = i == 0
              ? sourceLocation
              : LatLng(
                  widget.multiDropObj![i - 1].latitude,
                  widget.multiDropObj![i - 1].longitude,
                );

          LatLng destination = LatLng(
            widget.multiDropObj![i].latitude,
            widget.multiDropObj![i].longitude,
          );

          String origins = "${origin.latitude},${origin.longitude}";
          String destinations = "${destination.latitude},${destination.longitude}";

          List<LatLng> routeCoordinates = [];

          final value = await getPolylineData(origins, destinations);

          if (value.status != null && value.status!) {
            if (value.polyline != null) {
              final points = decodePolyline(value.polyline!);
              if (points.isNotEmpty) {
                routeCoordinates = points;
              } else {
                debugPrint('---No Data--');
              }
            } else {
              debugPrint('---Polyline Null---');
            }
          } else {
            debugPrint('---Status False or Null---');
          }

          markers.add(
            Marker(
              markerId: MarkerId("multi_drop_$i"),
              position: destination,
              infoWindow: InfoWindow(title: "${widget.multiDropLocationNamesObj![i]}"),
              icon: destinationIcon,
            ),
          );

          polyLines.add(
            Polyline(
              endCap: Cap.roundCap,
              startCap: Cap.roundCap,
              jointType: JointType.round,
              visible: true,
              width: 7,
              polylineId: PolylineId('multi_poly_$i'),
              color: polyLineColor,
              points: routeCoordinates,
            ),
          );
        }

        setState(() {});
      } catch (e) {
        throw e;
      }
    } else {
      try {
        LatLng originLatLng;
        LatLng destinationLatLng;

        if (rideRequestData != null && rideRequestData!.status == IN_PROGRESS) {
          originLatLng = sourceLocation;
          destinationLatLng = destinationLocation;
        } else if (rideRequestData != null && (rideRequestData!.status == ACCEPTED || rideRequestData!.status == ARRIVING || rideRequestData!.status == ARRIVED)) {
          originLatLng = sourceLocation;
          destinationLatLng = driverLocation!;
        } else {
          originLatLng = sourceLocation;
          destinationLatLng = destinationLocation;
        }

        /// CALL API ONLY ONCE
        if (!isRouteLoaded) {
          String origins = "${originLatLng.latitude},${originLatLng.longitude}";
          String destinations = "${destinationLatLng.latitude},${destinationLatLng.longitude}";

          final value = await getPolylineData(origins, destinations);

          if (value.status == true && value.polyline != null) {
            fullRouteCoordinates = decodePolyline(value.polyline!);
            polylineCoordinates = List.from(fullRouteCoordinates);

            isRouteLoaded = true;
          }
        }

        /// UPDATE ONLY REMAINING ROUTE
        if (driverLocation != null && fullRouteCoordinates.isNotEmpty) {
          polylineCoordinates = getRemainingRoute(driverLocation, fullRouteCoordinates);
        }

        /// UPDATE POLYLINE WITHOUT CLEARING EVERYTHING
        polyLines.removeWhere((p) => p.polylineId.value == 'poly');

        polyLines.add(
          Polyline(
            polylineId: const PolylineId('poly'),
            color: polyLineColor,
            width: 7,
            points: polylineCoordinates,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );

        setState(() {});
      } catch (e) {
        print(e);
      }
    }
  }

  List<LatLng> getRemainingRoute(LatLng driverLocation, List<LatLng> fullRoute) {
    if (fullRoute.isEmpty) return [];

    int nearestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < fullRoute.length; i++) {
      double distance = Geolocator.distanceBetween(
        driverLocation.latitude,
        driverLocation.longitude,
        fullRoute[i].latitude,
        fullRoute[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return fullRoute.sublist(nearestIndex);
  }

  // Future<void> setPolyLinesDriver({required LatLng sourceLocation, LatLng? driverLocation}) async {
  //   try {
  //     for (int i = 0; i < rideRequestData!.multiDropLocation!.length; i++) {
  //       PolylineResult b = await polylinePoints.getRouteBetweenCoordinates(
  //         googleApiKey: GOOGLE_MAP_API_KEY,
  //         request: PolylineRequest(
  //             origin: i == 0 ? PointLatLng(sourceLocation.latitude, sourceLocation.longitude) : PointLatLng(rideRequestData!.multiDropLocation![i - 1].lat, rideRequestData!.multiDropLocation![i - 1].lng),
  //             destination: PointLatLng(rideRequestData!.multiDropLocation![i].lat, rideRequestData!.multiDropLocation![i].lng),
  //             mode: TravelMode.driving),
  //       );
  //       List<LatLng> routeCoordinates = [];
  //       markers.add(
  //         Marker(
  //           markerId: MarkerId("multi_drop_$i"),
  //           position: LatLng(rideRequestData!.multiDropLocation![i].lat, rideRequestData!.multiDropLocation![i].lng),
  //           infoWindow: InfoWindow(title: "${rideRequestData!.multiDropLocation![i].address}"),
  //           icon: destinationIcon,
  //         ),
  //       );
  //       b.points.forEach((element) {
  //         routeCoordinates.add(LatLng(element.latitude, element.longitude));
  //       });
  //       polyLines.add(Polyline(
  //         endCap: Cap.roundCap,
  //         startCap: Cap.roundCap,
  //         jointType: JointType.round,
  //         visible: true,
  //         width: 7,
  //
  //         polylineId: PolylineId('multi_poly_$i'),
  //         color: polyLineColor,
  //         points: routeCoordinates, // Use the local list for this polyline
  //       ));
  //     }
  //     setState(() {});
  //   } catch (e) {
  //     throw e;
  //   }
  // }
  //
  // Future<void> setPolyLines({required LatLng sourceLocation, required LatLng destinationLocation, LatLng? driverLocation}) async {
  //   print("PolyLineCreatedCall");
  //   polyLines.clear();
  //   polylineCoordinates.clear();
  //   PolylineResult result;
  //   if (rideRequestData != null && rideRequestData!.multiDropLocation != null && rideRequestData!.multiDropLocation!.isNotEmpty && rideRequestData!.status != ACCEPTED && rideRequestData!.status != ARRIVING && rideRequestData!.status != ARRIVED) {
  //     print("PolyLineCreatedCall410");
  //     await setPolyLinesDriver(sourceLocation: sourceLocation, driverLocation: driverLocation);
  //   } else if (widget.multiDropObj != null && widget.multiDropObj!.isNotEmpty && rideRequestData == null) {
  //     print("PolyLineCreatedCall414");
  //     try {
  //       for (int i = 0; i < widget.multiDropObj!.length; i++) {
  //         PolylineResult b = await polylinePoints.getRouteBetweenCoordinates(
  //           googleApiKey: GOOGLE_MAP_API_KEY,
  //           request: PolylineRequest(
  //               origin: i == 0 ? PointLatLng(sourceLocation.latitude, sourceLocation.longitude) : PointLatLng(widget.multiDropObj![i - 1].latitude, widget.multiDropObj![i - 1].longitude),
  //               destination: PointLatLng(widget.multiDropObj![i].latitude, widget.multiDropObj![i].longitude),
  //               mode: TravelMode.driving),
  //         );
  //         List<LatLng> routeCoordinates = [];
  //         markers.add(
  //           Marker(
  //             markerId: MarkerId("multi_drop_$i"),
  //             position: LatLng(widget.multiDropObj![i].latitude, widget.multiDropObj![i].longitude),
  //             infoWindow: InfoWindow(title: "${widget.multiDropLocationNamesObj![i]}"),
  //             icon: destinationIcon,
  //           ),
  //         );
  //         b.points.forEach((element) {
  //           routeCoordinates.add(LatLng(element.latitude, element.longitude));
  //         });
  //         polyLines.add(Polyline(
  //           endCap: Cap.roundCap,
  //           startCap: Cap.roundCap,
  //           jointType: JointType.round,
  //           visible: true,
  //           width: 7,
  //
  //           polylineId: PolylineId('multi_poly_$i'),
  //           color: polyLineColor,
  //           points: routeCoordinates, // Use the local list for this polyline
  //         ));
  //       }
  //       setState(() {});
  //     } catch (e) {
  //       throw e;
  //     }
  //   } else {
  //     try {
  //       LatLng originLatLng;
  //       LatLng destinationLatLng;
  //
  //       if (rideRequestData != null && rideRequestData!.status == IN_PROGRESS) {
  //         originLatLng = sourceLocation; // Rider current live location
  //         destinationLatLng = destinationLocation; // Final drop location
  //       } else if (rideRequestData != null && (rideRequestData!.status == ACCEPTED || rideRequestData!.status == ARRIVING || rideRequestData!.status == ARRIVED)) {
  //         originLatLng = sourceLocation; // Driver location
  //         destinationLatLng = driverLocation!; // Pickup location
  //       } else {
  //         originLatLng = sourceLocation;
  //         destinationLatLng = destinationLocation;
  //       }
  //
  //       PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
  //         googleApiKey: GOOGLE_MAP_API_KEY,
  //         request: PolylineRequest(
  //           origin: PointLatLng(originLatLng.latitude, originLatLng.longitude),
  //           destination: PointLatLng(destinationLatLng.latitude, destinationLatLng.longitude),
  //           mode: TravelMode.driving,
  //         ),
  //       );
  //
  //       if (result.points.isNotEmpty) {
  //         polyLines.clear(); // IMPORTANT
  //         polylineCoordinates.clear();
  //
  //         for (var point in result.points) {
  //           polylineCoordinates.add(LatLng(point.latitude, point.longitude));
  //         }
  //
  //         polyLines.add(
  //           Polyline(
  //             visible: true,
  //             endCap: Cap.roundCap,
  //             startCap: Cap.roundCap,
  //             jointType: JointType.round,
  //             width: 7,
  //             polylineId: PolylineId('poly'),
  //             color: polyLineColor,
  //             points: polylineCoordinates,
  //           ),
  //         );
  //
  //         setState(() {});
  //       }
  //     } catch (e) {
  //       print(e);
  //     }
  //   }
  // }

  onMapCreated(GoogleMapController controller) async {
    try {
      googleMapController = controller;
      _controller.complete(controller);
      await Future.delayed(Duration(milliseconds: 50));
      await googleMapController!.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
              southwest:
                  LatLng(widget.sourceLatLog.latitude <= widget.destinationLatLog.latitude ? widget.sourceLatLog.latitude : widget.destinationLatLog.latitude, widget.sourceLatLog.longitude <= widget.destinationLatLog.longitude ? widget.sourceLatLog.longitude : widget.destinationLatLog.longitude),
              northeast:
                  LatLng(widget.sourceLatLog.latitude <= widget.destinationLatLog.latitude ? widget.destinationLatLog.latitude : widget.sourceLatLog.latitude, widget.sourceLatLog.longitude <= widget.destinationLatLog.longitude ? widget.destinationLatLog.longitude : widget.sourceLatLog.longitude)),
          100));
      setState(() {});
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  getWalletDataApi() {
    getWalletData().then((value) {
      mTotalAmount = value.totalAmount!;
      setState(() {});
    }).catchError((error) {
      log('${error.toString()}');
    });
  }

  Future<void> getUserDetailLocation() async {
    // if (rideRequestData!.status != COMPLETED) {
    if (driverData == null) return;
    // currentHeading
    getUserDetail(userId: driverData!.id).then((value) {
      driverLatitudeLocation = LatLng(double.parse(value.data!.latitude!), double.parse(value.data!.longitude!));
      driverCarHeading = value.data?.currentHeading?.toDouble() ?? 0.0;
      getServiceList();
    }).catchError((error) {
      log(error.toString());
    });
    // } else {
    //   if (timer != null) timer?.cancel();
    // }
  }

  @override
  void dispose() {
    // Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((value) {
    //   polylineSource = LatLng(value.latitude, value.longitude);
    // });
    WidgetsBinding.instance.removeObserver(this);
    if (timer != null) timer!.cancel();
    try {
      positionStream?.cancel();
    } catch (e) {}
    myFocusNode.dispose();
    nameController.dispose();
    phoneController.dispose();
    promoCode.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Widget mSomeOnElse() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(language.lblRideInformation, style: boldTextStyle()),
              ),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(Icons.close),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppTextField(
              controller: nameController,
              autoFocus: false,
              isValidationRequired: false,
              textFieldType: TextFieldType.NAME,
              keyboardType: TextInputType.name,
              errorThisFieldRequired: language.thisFieldRequired,
              decoration: inputDecoration(context, label: language.enterName),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppTextField(
              controller: phoneController,
              autoFocus: false,
              isValidationRequired: false,
              textFieldType: TextFieldType.PHONE,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorThisFieldRequired: language.thisFieldRequired,
              decoration: inputDecoration(
                context,
                label: language.enterContactNumber,
                prefixIcon: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryCodePicker(
                        padding: EdgeInsets.zero,
                        initialSelection: countryCode,
                        showCountryOnly: false,
                        dialogSize: Size(MediaQuery.of(context).size.width - 60, MediaQuery.of(context).size.height * 0.6),
                        showFlag: true,
                        showFlagDialog: true,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        textStyle: primaryTextStyle(),
                        dialogBackgroundColor: Theme.of(context).cardColor,
                        barrierColor: Colors.black12,
                        dialogTextStyle: primaryTextStyle(),
                        searchDecoration: InputDecoration(
                          focusColor: primaryColor,
                          iconColor: Theme.of(context).dividerColor,
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                        ),
                        searchStyle: primaryTextStyle(),
                        onInit: (c) {
                          countryCode = c!.dialCode!;
                        },
                        onChanged: (c) {
                          countryCode = c.dialCode!;
                        },
                      ),
                      VerticalDivider(color: Colors.grey.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: AppButtonWidget(
              width: MediaQuery.of(context).size.width,
              text: language.done,
              textStyle: boldTextStyle(color: Colors.white),
              color: primaryColor,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  // COIN SELECTION UI WIDGET - ADDED
  Widget coinSelectionWidget() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          if (coinDiscount > 0) {
            toast("Remove existing coins to apply new coins.");
          } else {
            showCoinSelectionBottomSheet();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: dividerColor),
            borderRadius: BorderRadius.circular(defaultRadius),
            color: useCoinsEnabled ? primaryColor.withOpacity(0.05) : Colors.white,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  ic_coin,
                  height: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      useCoinsEnabled && usedCoins > 0 ? '$usedCoins Coins Applied' : 'Use Coins',
                      style: boldTextStyle(
                        size: 14,
                        color: useCoinsEnabled ? primaryColor : textPrimaryColorGlobal,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      useCoinsEnabled && usedCoins > 0 ? 'Save ${coinDiscount.toString()}' : 'You have $totalCoins coins available',
                      style: secondaryTextStyle(
                        size: 12,
                        color: useCoinsEnabled ? primaryColor : textSecondaryColorGlobal,
                      ),
                    ),
                  ],
                ),
              ),
              if (useCoinsEnabled && usedCoins > 0)
                InkWell(
                  onTap: () {
                    setState(() {
                      usedCoins = 0;
                      useCoinsEnabled = false;
                      coinDiscount = 0.0;
                    });
                    // Refresh prices without coins
                    getCouponNewService();
                  },
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: textSecondaryColorGlobal,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isBooking,
      onPopInvokedWithResult: (didPop, v2) {
        if (didPop == false) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: key,
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          // systemOverlayStyle: SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarColor: Colors.black, statusBarBrightness: Brightness.dark),
          leadingWidth: 50,
          leading: Visibility(
            visible: !isBooking,
            child: inkWellWidget(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                margin: EdgeInsets.only(left: 12, bottom: 16),
                padding: EdgeInsets.all(0),
                decoration: BoxDecoration(color: context.cardColor, shape: BoxShape.circle, border: Border.all(color: dividerColor)),
                child: Icon(Icons.close, color: context.iconColor, size: 20),
              ),
            ),
          ),
          actions: [
            inkWellWidget(
              onTap: () async {
                final geoPosition = await Geolocator.getCurrentPosition(timeLimit: Duration(seconds: 30), desiredAccuracy: LocationAccuracy.high);

                googleMapController!.animateCamera(CameraUpdate.newLatLng(LatLng(geoPosition.latitude, geoPosition.longitude)));
              },
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), spreadRadius: 1),
                  ],
                  borderRadius: BorderRadius.circular(defaultRadius),
                ),
                margin: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.my_location,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            if (sharedPref.getDouble(LATITUDE) != null && sharedPref.getDouble(LONGITUDE) != null)
              SizedBox(
                height: MediaQuery.of(context).size.height,
                child: GoogleMap(
                  padding: EdgeInsets.only(top: context.statusBarHeight + 4 + 24),
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  // myLocationEnabled: /*rideRequestData != null && (rideRequestData!.status == IN_PROGRESS) ? true : false*/ false,
                  myLocationEnabled: false,
                  compassEnabled: true,
                  onMapCreated: onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: widget.sourceLatLog,
                    zoom: 17,
                  ),
                  markers: markers,
                  mapType: MapType.normal,
                  polylines: polyLines,
                ),
              ),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(2 * defaultRadius), topRight: Radius.circular(2 * defaultRadius))),
              child: !isBooking
                  ? bookRideWidget()
                  : StreamBuilder(
                      stream: rideService.fetchRide(rideId: rideRequestId == 0 ? widget.id : rideRequestId),
                      builder: (context, snap) {
                        if (snap.hasData) {
                          List<FRideBookingModel> data = snap.data!.docs.map((e) => FRideBookingModel.fromJson(e.data() as Map<String, dynamic>)).toList();
                          if (data.isEmpty) {
                            Future.delayed(
                              Duration(seconds: 1),
                              () {
                                if (currentScreen == false) return;
                                currentScreen = false;
                                checkRideCancel();
                              },
                            );
                          }
                          if (data.length != 0) {
                            if (data[0].onRiderStreamApiCall == 0) {
                              getCurrentRequest();
                              rideService.updateStatusOfRide(rideID: rideRequestId == 0 ? widget.id : rideRequestId, req: {'on_rider_stream_api_call': 1});
                            }

                            if (rideRequestData != null && rideRequestData!.status == COMPLETED) {
                              if (currentScreen != false) {
                                currentScreen = false;
                                if (rideRequestData!.isRiderRated == 1) {
                                  launchScreen(context, RideDetailScreen(orderId: rideRequestData!.id!), pageRouteAnimation: PageRouteAnimation.SlideBottomTop, isNewTask: true);
                                  // launchScreen(context, DashBoardScreen(), isNewTask: true);
                                } else {
                                  Future.delayed(
                                    Duration(seconds: 1),
                                    () {
                                      launchScreen(context, ReviewScreen(rideRequest: rideRequestData!, driverData: driverData), pageRouteAnimation: PageRouteAnimation.SlideBottomTop, isNewTask: true);
                                    },
                                  );
                                }
                              }
                              ;
                            }
                            // widget.rideRequest!.status == COMPLETED,
                            return rideRequestData != null
                                ? rideRequestData!.status == NEW_RIDE_REQUESTED
                                    ? BookingWidget(
                                        id: rideRequestId == 0 ? widget.id : rideRequestId,
                                        dt: widget.dt,
                                        timezone: widget.timezone,
                                      )
                                    : RideAcceptWidget(rideRequest: rideRequestData, driverData: driverData)
                                // :SizedBox();
                                : data[0].status == NEW_RIDE_REQUESTED
                                    ? BookingWidget(
                                        id: rideRequestId == 0 ? widget.id : rideRequestId,
                                        dt: widget.dt,
                                        timezone: widget.timezone,
                                      )
                                    : loaderWidget();
                          } else {
                            return SizedBox();
                          }
                        } else {
                          return SizedBox();
                        }
                      }),
            ),
            Observer(builder: (context) {
              return Visibility(visible: appStore.isLoading, child: loaderWidget());
            }),
          ],
        ),
      ),
    );
  }

  Widget bookRideWidget() {
    return Stack(
      children: [
        Visibility(
          visible: serviceList.isNotEmpty,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(2 * defaultRadius), topRight: Radius.circular(2 * defaultRadius))),
            child: SingleChildScrollView(
              child:
                  // true?bidBookingOption():
                  isRideSelection == false && appStore.isRiderForAnother == "1" ? riderSelectionWidget() : serviceSelectWidget(),
            ),
          ),
        ),
        Visibility(
          visible: !appStore.isLoading && serviceList.isEmpty,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(2 * defaultRadius), topRight: Radius.circular(2 * defaultRadius))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                emptyWidget(),
                Text(language.servicesNotFound, style: boldTextStyle()),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget riderSelectionWidget() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              alignment: Alignment.center,
              margin: EdgeInsets.only(bottom: 16),
              height: 5,
              width: 70,
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
            ),
          ),
          Text(language.whoWillBeSeated, style: primaryTextStyle(size: 18)),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              inkWellWidget(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 70,
                            width: 70,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: textSecondaryColorGlobal, width: 1)),
                            padding: EdgeInsets.all(12),
                            child: Image.asset(ic_add_user, fit: BoxFit.fill),
                          ),
                          if (!isRideForOther)
                            Container(
                              height: 70,
                              width: 70,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                              child: Icon(Icons.check, color: Colors.white),
                            ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(language.lblSomeoneElse, style: primaryTextStyle()),
                    ],
                  ),
                  onTap: () {
                    isRideForOther = false;
                    showDialog(
                      context: context,
                      builder: (_) {
                        return StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                          return AlertDialog(
                            contentPadding: EdgeInsets.all(0),
                            content: mSomeOnElse(),
                          );
                        });
                      },
                    ).then((value) {
                      setState(() {});
                    });
                    setState(() {});
                  }),
              SizedBox(width: 30),
              inkWellWidget(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: commonCachedNetworkImage(appStore.userProfile.validate(), height: 70, width: 70, fit: BoxFit.cover),
                          ),
                          if (isRideForOther)
                            Container(
                              height: 70,
                              width: 70,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                              child: Icon(Icons.check, color: Colors.white),
                            ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(language.lblYou, style: primaryTextStyle()),
                    ],
                  ),
                  onTap: () {
                    isRideForOther = true;
                    setState(() {});
                  })
            ],
          ),
          SizedBox(height: 12),
          Text(language.lblWhoRidingMsg, style: secondaryTextStyle()),
          SizedBox(height: 8),
          AppButtonWidget(
            color: primaryColor,
            onTap: () async {
              if (!isRideForOther) {
                if (nameController.text.isEmptyOrNull || phoneController.text.isEmptyOrNull) {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                        return AlertDialog(
                          contentPadding: EdgeInsets.all(0),
                          content: mSomeOnElse(),
                        );
                      });
                    },
                  ).then((value) {
                    setState(() {});
                  });
                } else {
                  isRideSelection = true;
                }
              } else {
                isRideSelection = true;
              }
              setState(() {});
            },
            text: language.lblNext,
            textStyle: boldTextStyle(color: Colors.white),
            width: MediaQuery.of(context).size.width,
          ),
        ],
      ),
    );
  }

  Widget serviceSelectWidget() {
    print("totalCoins ${totalCoins}");
    if (!widget.pickupTimeValue.isEmptyOrNull) {
      DateTime parsedDate = DateTime.parse(widget.pickupTimeValue ?? "");

      formattedTime = DateFormat('yyyy-MM-dd hh:mm a').format(parsedDate);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            alignment: Alignment.center,
            margin: EdgeInsets.only(bottom: 8, top: 16),
            height: 5,
            width: 70,
            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
          ),
        ),
        SingleChildScrollView(
          padding: EdgeInsets.only(left: 8, right: 8),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: serviceList.map((e) {
              return GestureDetector(
                onTap: () {
                  if (servicesListData == e) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(2 * defaultRadius), topLeft: Radius.circular(2 * defaultRadius))),
                      builder: (_) {
                        return CarDetailWidget(service: e, tripType: widget.trip_type);
                      },
                    );
                    return;
                  }
                  if (cashList.length > 1) {
                    oldPaymentType = paymentMethodType;
                  }
                  if (e.discountAmount != 0) {
                    mSelectServiceAmount = e.subtotal!.toStringAsFixed(fixedDecimal);
                  } else {
                    mSelectServiceAmount = e.totalAmount!.toStringAsFixed(fixedDecimal);
                  }
                  selectedIndex = serviceList.indexOf(e);
                  servicesListData = e;
                  if (e.distanceUnit == DISTANCE_TYPE_KM) {
                    locationDistance = e.dropoffDistanceInKm!.toDouble();
                    distanceUnit = DISTANCE_TYPE_KM;
                  } else {
                    locationDistance = e.dropoffDistanceInKm!.toDouble() * 0.621371;
                    distanceUnit = DISTANCE_TYPE_MILE;
                  }
                  durationOfDrop = serviceList[0].duration!.toDouble();
                  paymentMethodType = e.paymentMethod!;

                  // cashList =
                  paymentMethodType == CASH_WALLET ? cashList = [CASH, WALLET] : cashList = [paymentMethodType];
                  if (e.paymentMethod == CASH_WALLET && oldPaymentType != null) {
                    paymentMethodType = oldPaymentType!;
                  }
                  setState(() {});
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  margin: EdgeInsets.only(top: 16, left: 8, right: 8),
                  decoration: BoxDecoration(
                    color: selectedIndex == serviceList.indexOf(e) ? primaryColor : Colors.white,
                    border: Border.all(color: dividerColor),
                    borderRadius: BorderRadius.circular(defaultRadius),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      commonCachedNetworkImage(e.serviceImage.validate(), height: 50, width: 100, fit: BoxFit.contain, alignment: Alignment.center),
                      // SizedBox(height: 6),
                      Text(e.name.validate(), style: boldTextStyle(color: selectedIndex == serviceList.indexOf(e) ? Colors.white : textPrimaryColorGlobal)),
                      // SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(language.capacity, style: secondaryTextStyle(size: 12, color: selectedIndex == serviceList.indexOf(e) ? Colors.white : textPrimaryColorGlobal)),
                          SizedBox(width: 4),
                          Text(e.capacity.toString() + " + 1", style: secondaryTextStyle(color: selectedIndex == serviceList.indexOf(e) ? Colors.white : textPrimaryColorGlobal)),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              printAmountWidget(
                                amount: '${e.totalAmount!.toStringAsFixed(digitAfterDecimal)}',
                                weight: e.totalAmount! != e.totalAmountAfterDiscount ? FontWeight.normal : FontWeight.bold,
                                decorationThickness: 2.5,
                                decorationColor: Colors.red,
                                textDecoration: e.totalAmount! != e.totalAmountAfterDiscount ? TextDecoration.lineThrough : TextDecoration.none,
                                color: selectedIndex == serviceList.indexOf(e) ? Colors.white : textPrimaryColorGlobal,
                              ),
                              if (e.totalAmount! != e.totalAmountAfterDiscount)
                                printAmountWidget(
                                  amount: '${e.totalAmountAfterDiscount!.toStringAsFixed(digitAfterDecimal)}',
                                  color: selectedIndex == serviceList.indexOf(e) ? Colors.white : textPrimaryColorGlobal,
                                ),
                            ],
                          ),
                          SizedBox(width: 8),
                          inkWellWidget(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(2 * defaultRadius), topLeft: Radius.circular(2 * defaultRadius))),
                                builder: (_) {
                                  return CarDetailWidget(service: e, tripType: widget.trip_type);
                                },
                              );
                            },
                            child: Icon(Icons.info_outline_rounded, size: 16, color: selectedIndex == serviceList.indexOf(e) ? Colors.white : textPrimaryColorGlobal),
                          ),
                        ],
                      ),
                      if (promoCode.text.isNotEmpty && e.discountAmount == 0) SizedBox(height: 20)
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 8),
        if (mSelectServiceAmount != null && paymentMethodType != CASH_WALLET && paymentMethodType == WALLET && double.parse(mSelectServiceAmount!) >= mTotalAmount.toDouble())
          Padding(
            padding: EdgeInsets.zero,
            // padding: EdgeInsets.only(top: 4,left: 16,right: 16),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: dividerColor), borderRadius: BorderRadius.circular(defaultRadius)),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Text(language.lblLessWalletAmount, style: boldTextStyle(size: 12, color: Colors.red, letterSpacing: 0.5, weight: FontWeight.w500))),
                  if (mSelectServiceAmount != null && paymentMethodType != CASH_WALLET && paymentMethodType == WALLET && double.parse(mSelectServiceAmount!) >= mTotalAmount.toDouble())
                    inkWellWidget(
                      onTap: () {
                        oldPaymentType = paymentMethodType;
                        launchScreen(context, WalletScreen()).then((value) {
                          init();
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: dividerColor), color: primaryColor, borderRadius: radius()),
                        child: Text(language.addMoney, style: primaryTextStyle(size: 14, color: Colors.white)),
                      ),
                    )
                ],
              ),
            ),
          ),

        // COIN SELECTION WIDGET - ADDED
        if (totalCoins > 0) coinSelectionWidget(),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: inkWellWidget(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                        return Observer(builder: (context) {
                          return Stack(
                            children: [
                              AlertDialog(
                                contentPadding: EdgeInsets.all(16),
                                backgroundColor: Colors.white,
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(language.paymentMethod, style: boldTextStyle()),
                                          inkWellWidget(
                                            onTap: () {
                                              Navigator.pop(context);
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(6),
                                              decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                                              child: Icon(Icons.close, color: Colors.white),
                                            ),
                                          )
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(language.chooseYouPaymentLate, style: secondaryTextStyle()),
                                      Column(
                                        children: cashList.map((e) {
                                          return RadioListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            controlAffinity: ListTileControlAffinity.trailing,
                                            activeColor: primaryColor,
                                            value: e,
                                            groupValue: paymentMethodType == CASH_WALLET ? CASH : paymentMethodType,
                                            title: Text(paymentStatus(e), style: boldTextStyle()),
                                            onChanged: (String? val) {
                                              paymentMethodType = val!;
                                              setState(() {});
                                            },
                                          );
                                        }).toList(),
                                      ),
                                      SizedBox(height: 16),
                                      AppTextField(
                                        controller: promoCode,
                                        autoFocus: false,
                                        textFieldType: TextFieldType.EMAIL,
                                        keyboardType: TextInputType.emailAddress,
                                        errorThisFieldRequired: language.thisFieldRequired,
                                        readOnly: true,
                                        onTap: () async {
                                          // servicesListData.id;
                                          // selectedIndex;
                                          var data = await showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.white,
                                            builder: (_) {
                                              return CouPonWidget(servicesListData!.serviceId!.toInt());
                                            },
                                          );
                                          if (data != null) {
                                            promoCode.text = data;
                                            setState(() {});
                                          }
                                        },
                                        decoration: inputDecoration(context,
                                            label: language.enterPromoCode,
                                            suffixIcon: promoCode.text.isNotEmpty
                                                ? inkWellWidget(
                                                    onTap: () {
                                                      getNewService(coupon: false);
                                                      promoCode.clear();
                                                      setState(() {});
                                                    },
                                                    child: Icon(Icons.close, color: Colors.black, size: 25),
                                                  )
                                                : null),
                                      ),
                                      SizedBox(height: 16),
                                      AppButtonWidget(
                                        width: MediaQuery.of(context).size.width,
                                        text: language.confirm,
                                        textStyle: boldTextStyle(color: Colors.white),
                                        color: primaryColor,
                                        onTap: () {
                                          if (promoCode.text.isNotEmpty) {
                                            getCouponNewService();
                                          } else {
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Observer(builder: (context) {
                                return Visibility(visible: appStore.isLoading, child: loaderWidget());
                              }),
                            ],
                          );
                        });
                      });
                    },
                  ).then((value) {
                    setState(() {});
                  });
                },
                child: Container(
                  margin: EdgeInsets.fromLTRB(16, 8, appStore.isScheduleRide == "1" ? 4 : 16, 16),
                  decoration: BoxDecoration(border: Border.all(color: dividerColor), borderRadius: BorderRadius.circular(defaultRadius)),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(language.paymentVia, style: secondaryTextStyle(size: 12, weight: FontWeight.bold)),
                            Container(
                              child: Icon(
                                Icons.cancel_outlined,
                                color: Colors.transparent,
                              ),
                            )
                          ],
                        ),
                        Divider(
                          height: 8,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(4),
                              margin: EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                              child: paymentMethodType == CASH_WALLET || paymentMethodType == CASH
                                  ? Text(
                                      "${appStore.currencyCode}",
                                      style: boldTextStyle(color: Colors.white),
                                    ).paddingSymmetric(horizontal: 5, vertical: 0)
                                  : Icon(Icons.wallet_outlined, size: 20, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          isRideForOther == false
                                              ? language.cash
                                              : paymentMethodType == CASH_WALLET
                                                  ? language.cash
                                                  : paymentStatus(paymentMethodType),
                                          style: boldTextStyle(size: 14),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    paymentMethodType != CASH_WALLET ? language.forInstantPayment : language.lblPayWhenEnds,
                                    style: secondaryTextStyle(size: 12),
                                    maxLines: 2,
                                  ),
                                  SizedBox(height: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (appStore.isScheduleRide == "1")
              Expanded(
                child: inkWellWidget(
                  onTap: () async {
                    print(widget.trip_type);
                    if (!widget.trip_type.toLowerCase().contains("airport")) {
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
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 45)));
                      if (d1 != null) {
                        TimeOfDay? t1 = await showTimePicker(
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
                            initialTime: TimeOfDay(hour: 0, minute: 0));
                        if (t1 != null) {
                          d1 = DateTime(d1.year, d1.month, d1.day, t1.hour, t1.minute);

                          DateTime now = DateTime.now();
                          DateTime minValid = now.add(Duration(minutes: 15));
                          if (d1.isBefore(minValid)) {
                            toast("Please select a time at least 15 minutes from now."); // todo language
                          } else {
                            setState(() {
                              schduleRideDateTime = d1;
                            });
                          }
                        }
                      }
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.fromLTRB(4, 8, 16, 16),
                    decoration: BoxDecoration(border: Border.all(color: dividerColor), borderRadius: BorderRadius.circular(defaultRadius)),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(language.schedule, style: secondaryTextStyle(size: 12, weight: FontWeight.bold)),
                            if (schduleRideDateTime != null)
                              inkWellWidget(
                                onTap: () {
                                  setState(() {
                                    schduleRideDateTime = null;
                                  });
                                },
                                child: Container(
                                  child: Icon(
                                    Icons.cancel_outlined,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            if (schduleRideDateTime == null)
                              Container(
                                child: Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.transparent,
                                ),
                              )
                          ],
                        ),
                        Divider(
                          height: 8,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(4),
                              margin: EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                              child: Icon(Icons.access_time_filled_outlined, size: 20, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          language.schedule_at,
                                          style: boldTextStyle(size: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  if (!widget.pickupTimeValue.isEmptyOrNull) ...[
                                    Text(formattedTime ?? '', style: secondaryTextStyle(size: 12)),
                                  ] else ...[
                                    Text(schduleRideDateTime != null ? "${DateFormat('dd MMM yyyy hh:mm a').format(schduleRideDateTime!)}" : "${language.now}", style: secondaryTextStyle(size: 12)),
                                  ],
                                  SizedBox(height: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: 0),
          child: AppButtonWidget(
            onTap: () {
              if (mSelectServiceAmount != null && paymentMethodType != CASH_WALLET && paymentMethodType == WALLET && double.parse(mSelectServiceAmount!) >= mTotalAmount.toDouble()) {
                return toast(language.noBalanceValidate);
              }
              saveBookingData();
            },
            text: language.bookNow,
            textStyle: boldTextStyle(color: Colors.white),
            width: MediaQuery.of(context).size.width,
          ),
        ),
        if (appStore.isBidEnable == "1" && schduleRideDateTime == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text("OR"),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
        if (appStore.isBidEnable == "1" && schduleRideDateTime == null)
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: AppButtonWidget(
              onTap: () {
                if (mSelectServiceAmount != null && paymentMethodType != CASH_WALLET && paymentMethodType == WALLET && double.parse(mSelectServiceAmount!) >= mTotalAmount.toDouble()) {
                  return toast(language.noBalanceValidate);
                }
                saveBookingData(ride_type: "with_bidding");
                // saveBidBookingData();
              },
              text: language.bid_book,
              textStyle: boldTextStyle(color: Colors.white),
              width: MediaQuery.of(context).size.width,
            ),
          ),
        if (appStore.isBidEnable != "1" || schduleRideDateTime != null)
          SizedBox(
            height: 12,
          )
      ],
    );
  }

  Future<void> saveBookingData({String? ride_type}) async {
    if (schduleRideDateTime != null && schduleRideDateTime!.isBefore(DateTime.now())) {
      return toast("Enter Valid Schedule Time");
    }
    DateFormat format = DateFormat("yyyy-MM-dd hh:mm a");
    if (formattedTime != null && format.parse(formattedTime.toString()).isBefore(DateTime.now())) {
      return toast("Enter Valid Schedule Time");
    }

    if (isRideForOther == false && nameController.text.isEmpty) {
      return toast(language.nameFieldIsRequired);
    } else if (isRideForOther == false && phoneController.text.isEmpty) {
      return toast(language.phoneNumberIsRequired);
    }
    appStore.setLoading(true);
    widget.dt = DateTime.now().toUtc().toString().replaceAll("Z", "");
    if (!formattedTime.isEmptyOrNull) {
      DateFormat inputFormat = DateFormat("yyyy-MM-dd hh:mm a");
      DateTime fixDate = inputFormat.parse(formattedTime ?? "");
      parsedDate = fixDate.toUtc().toIso8601String().replaceAll("Z", "");
    }
    Map req = {
      "rider_id": sharedPref.getInt(USER_ID).toString(),
      "service_id": servicesListData!.id.toString(),
      "datetime": DateTime.now().toUtc().toString().replaceAll("Z", ""),
      "start_latitude": widget.sourceLatLog.latitude.toString(),
      "start_longitude": widget.sourceLatLog.longitude.toString(),
      "start_address": widget.sourceTitle,
      "end_latitude": widget.destinationLatLog.latitude.toString(),
      "end_longitude": widget.destinationLatLog.longitude.toString(),
      "end_address": widget.destinationTitle,
      "seat_count": servicesListData!.capacity.toString(),
      "status": NEW_RIDE_REQUESTED,
      "payment_type": paymentMethodType == CASH_WALLET ? CASH : paymentMethodType,
      if (promoCode.text.isNotEmpty) "coupon_code": promoCode.text,
      if (useCoinsEnabled && usedCoins > 0) "use_coins": usedCoins, // ADDED FOR COINS
      "is_schedule": schduleRideDateTime == null && formattedTime.isEmptyOrNull ? 0 : 1,
      "schedule_datetime": schduleRideDateTime == null && formattedTime.isEmptyOrNull
          ? null
          : schduleRideDateTime == null
              ? parsedDate
              : schduleRideDateTime?.toUtc().toString().replaceAll("Z", ""),
      if (isRideForOther == false) "is_ride_for_other": 1,
      if (isRideForOther == false)
        "other_rider_data": {
          "name": nameController.text.trim(),
          "contact_number": '${countryCode}${phoneController.text.trim()}',
        }
    };
    if (ride_type != null) {
      req['ride_type'] = ride_type;
    }
    print("CHeckTRIPDETAIL::::::${widget.tripDetail}");
    if (widget.tripDetail != null) {
      req['flight_number'] = widget.tripDetail["flight_number"];
      req['pickup_point'] = widget.tripDetail["pickup_point"];
      req['preferred_pickup_time'] = widget.tripDetail["preferred_pickup_time"];
      req['preferred_dropoff_time'] = widget.tripDetail["preferred_dropoff_time"];
      req['trip_type'] = widget.tripDetail["trip_type"];
      req['airport_pickup'] = widget.tripDetail["airport_pickup"];
      req['airport_name'] = widget.tripDetail["airport_name"];
      req['pickup_airport_id'] = widget.tripDetail["pickup_airport_id"];
      req['drop_airport_id'] = widget.tripDetail["drop_airport_id"];
      req['drop_zone_id'] = widget.tripDetail["drop_zone_id"];
      req['pickup_zone_id'] = widget.tripDetail["pickup_zone_id"];
      req['distance'] = servicesListData?.distance ?? '';
      req['duration'] = servicesListData?.duration;
      req['base_fare'] = servicesListData?.baseFare;
      req['discount'] = servicesListData?.discountAmount;
      req['dropoff_distance_in_km'] = servicesListData?.dropoffDistanceInKm ?? '';
      req['total_amount'] = servicesListData?.totalAmountAfterDiscount ?? '';
      req['subtotal'] = servicesListData?.subtotal ?? '';
      req['time_price'] = servicesListData?.timePrice ?? '';
      req['surge_amount'] = servicesListData?.surgeAmount ?? '';
    }
    var abc = [];
    if (widget.multiDropObj != null) {
      widget.multiDropObj!.forEach(
        (key, value) {
          LatLng s = value as LatLng;
          abc.add({"drop": key, "lat": s.latitude, "lng": s.longitude, "dropped_at": null, "address": widget.multiDropLocationNamesObj![key]});
        },
      );
      req['multi_location'] = abc;
    }
    print("Just CHeckLOG:::${req}");

    FRideBookingModel rideBookingModel = FRideBookingModel();
    rideBookingModel.riderId = sharedPref.getInt(USER_ID);
    rideBookingModel.status = NEW_RIDE_REQUESTED;
    rideBookingModel.paymentStatus = null;
    rideBookingModel.paymentType = isRideForOther == false
        ? CASH
        : paymentMethodType == CASH_WALLET
            ? CASH
            : paymentMethodType;
    log('$req');
    await saveRideRequest(req).then((value) async {
      rideRequestId = value.rideRequestId!;
      rideBookingModel.rideId = rideRequestId;
      Future.delayed(
        Duration(seconds: 3),
        () {
          rideService.updateStatusOfRide(rideID: rideRequestId, req: {'on_stream_api_call': 0});
        },
      );
      widget.isCurrentRequest = true;
      if (schduleRideDateTime != null || formattedTime != null) {
        appStore.setLoading(false);
        launchScreen(
          context,
          isNewTask: true,
          DashBoardScreen(),
          pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
        );
        toast(value.message.validate());
        return;
      }
      if (ride_type != null) {
        appStore.setLoading(false);
        setState(() {});
        launchScreen(
          context,
          isNewTask: true,
          Bidingscreen(
            dt: widget.dt,
            ride_id: value.rideRequestId!,
            source: {
              "start_latitude": widget.sourceLatLog.latitude.toString(),
              "start_longitude": widget.sourceLatLog.longitude.toString(),
              "start_address": widget.sourceTitle,
            },
            endLocation: {
              "end_latitude": widget.destinationLatLog.latitude.toString(),
              "end_longitude": widget.destinationLatLog.longitude.toString(),
              "end_address": widget.destinationTitle,
            },
            multiDropObj: widget.multiDropObj,
            multiDropLocationNamesObj: widget.multiDropLocationNamesObj,
          ),
          pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
        );
      } else {
        isBooking = true;
        appStore.setLoading(false);
        setState(() {});
      }
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  void checkRideCancel() async {
    if (rideCancelDetected) return;
    rideCancelDetected = true;
    appStore.setLoading(true);
    sharedPref.remove(IS_TIME);
    sharedPref.remove(REMAINING_TIME);
    await rideDetail(orderId: rideRequestId == 0 ? widget.id : rideRequestId).then((value) {
      appStore.setLoading(false);
      if (value.data!.status == CANCELED && value.data!.cancelBy == DRIVER) {
        isPopupOpen = false;
        launchScreen(getContext, DashBoardScreen(cancelReason: value.data!.reason), isNewTask: true);
      } else {
        isPopupOpen = false;
        launchScreen(getContext, DashBoardScreen(), isNewTask: true);
      }
    }).catchError((error) {
      appStore.setLoading(false);
      isPopupOpen = false;
      launchScreen(getContext, DashBoardScreen(), isNewTask: true);
      log(error.toString());
    });
  }
}

// COIN SELECTION DIALOG WIDGET - ADD THIS CLASS AT THE END OF FILE
class CoinSelectionDialog extends StatefulWidget {
  final num totalCoins;
  final double rideAmount;
  final int coinValue;
  final Function(int selectedCoins) onConfirm;

  const CoinSelectionDialog({
    Key? key,
    required this.totalCoins,
    required this.rideAmount,
    this.coinValue = 1,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<CoinSelectionDialog> createState() => _CoinSelectionDialogState();
}

class _CoinSelectionDialogState extends State<CoinSelectionDialog> {
  late TextEditingController _coinsController;
  int selectedCoins = 0;
  double discountAmount = 0.0;
  int maxUsableCoins = 0;

  @override
  void initState() {
    super.initState();
    _coinsController = TextEditingController();

    maxUsableCoins = widget.totalCoins.toInt() < widget.rideAmount.toInt() ? widget.totalCoins.toInt() : widget.rideAmount.toInt();
  }

  @override
  void dispose() {
    _coinsController.dispose();
    super.dispose();
  }

  void _updateCoins(String value) {
    if (value.isEmpty) {
      setState(() {
        selectedCoins = 0;
        discountAmount = 0.0;
      });
      return;
    }

    int coins = int.tryParse(value) ?? 0;

    if (coins > maxUsableCoins) {
      coins = maxUsableCoins;
      _coinsController.text = coins.toString();
      _coinsController.selection = TextSelection.fromPosition(
        TextPosition(offset: _coinsController.text.length),
      );
    }

    setState(() {
      selectedCoins = coins;
      discountAmount = coins * widget.coinValue.toDouble();
    });
  }

  void _setCoinsPercentage(double percentage) {
    int coins = (maxUsableCoins * percentage).toInt();
    _coinsController.text = coins.toString();
    _updateCoins(coins.toString());
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Use Coins',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      ic_coin,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Coins',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.totalCoins} Coins',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Max Usable',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$maxUsableCoins Coins',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Enter Coins to Use',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _coinsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _updateCoins,
              decoration: InputDecoration(
                hintText: 'Enter coins',
                prefixIcon: Image.asset(
                  ic_coin,
                  scale: 20,
                ),
                suffixIcon: selectedCoins > 0
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _coinsController.clear();
                          _updateCoins('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Quick Select',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickSelectButton(
                    label: '25%',
                    onTap: () => _setCoinsPercentage(0.25),
                    primaryColor: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickSelectButton(
                    label: '50%',
                    onTap: () => _setCoinsPercentage(0.50),
                    primaryColor: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickSelectButton(
                    label: '75%',
                    onTap: () => _setCoinsPercentage(0.75),
                    primaryColor: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickSelectButton(
                    label: 'Max',
                    onTap: () => _setCoinsPercentage(1.0),
                    primaryColor: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (selectedCoins > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ride Amount:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          widget.rideAmount.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Coin Discount:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          '-${discountAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 16, color: Colors.grey[300]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Final Amount:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          (widget.rideAmount - discountAmount).toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: selectedCoins > 0
                        ? () {
                            widget.onConfirm(selectedCoins);
                            Navigator.pop(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply ${selectedCoins > 0 ? "$selectedCoins Coins" : ""}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
}

class _QuickSelectButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color primaryColor;

  const _QuickSelectButton({
    required this.label,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: primaryColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}

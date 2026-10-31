import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart' as lt;
import 'package:pinput/pinput.dart';
import 'package:taxi_driver/Services/driver_background_service.dart';
import 'package:taxi_driver/model/LDBaseResponse.dart';
import 'package:taxi_driver/model/ModelBid.dart';
import 'package:taxi_driver/screens/ChatScreen.dart';
import 'package:taxi_driver/screens/DetailScreen.dart';
import 'package:taxi_driver/screens/ReviewScreen.dart';
import 'package:taxi_driver/screens/WalletScreen.dart';
import 'package:taxi_driver/utils/Extensions/context_extensions.dart';
import 'package:taxi_driver/utils/Extensions/dataTypeExtensions.dart';
import 'package:taxi_driver/utils/Extensions/int_extensions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Services/RideService.dart';
import '../Services/VersionServices.dart';
import '../components/AlertScreen.dart';
import '../components/CancelOrderDialog.dart';
import '../components/DrawerComponent.dart';
import '../components/ExtraChargesWidget.dart';
import '../components/RideForWidget.dart';
import '../main.dart';
import '../model/CurrentRequestModel.dart';
import '../model/ExtraChargeRequestModel.dart';
import '../model/FRideBookingModel.dart';
import '../model/RiderModel.dart';
import '../model/UserDetailModel.dart';
import '../model/WalletDetailModel.dart';
import '../network/RestApis.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/ConformationDialog.dart';
import '../utils/Extensions/LiveStream.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Extensions/app_textfield.dart';
import '../utils/Images.dart';
import 'LocationPermissionScreen.dart';
import 'NotificationScreen.dart';
import 'ScheduleRideListScreen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  RideService rideService = RideService();
  Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? mapController;
  final otpController = TextEditingController();
  late StreamSubscription<ServiceStatus> serviceStatusStream;

  List<RiderModel> riderList = [];
  OnRideRequest? servicesListData;
  int bidIsProcessing = 0;
  int rideHasBid = 0;
  ModelBidData? bidData;
  UserData? riderData;
  WalletDetailModel? walletDetailModel;
  List<OnRideRequest> schedule_ride_request = [];

  LatLng? userLatLong;
  final Set<Marker> markers = {};
  Set<Polyline> _polyLines = Set<Polyline>();
  late PolylinePoints polylinePoints;
  List<LatLng> polylineCoordinates = [];

  List<ExtraChargeRequestModel> extraChargeList = [];
  num extraChargeAmount = 0;
  StreamSubscription<Position>? positionStream;
  LocationPermission? permissionData;

  LatLng? lastSentLocation;
  LatLng? driverLocation;
  LatLng? sourceLocation;
  LatLng? destinationLocation;
  bool isOnLine = true;
  bool locationEnable = true;
  bool current_screen = true;
  String? otpCheck;
  String endLocationAddress = '';
  double totalDistance = 0.0;
  late BitmapDescriptor driverIcon;
  int notificationCount = 0;
  late BitmapDescriptor destinationIcon;
  late BitmapDescriptor sourceIcon;
  int reqCheckCounter = 0;
  int startTime = 60;
  int end = 0;
  int duration = 0;
  double distance = 0;
  double rideDuration = 0;
  int count = 0;
  int riderId = 0;
  num platformFee = 0;
  num youWillGet = 0;
  var commission_type = '';
  num admin_commission = 0;
  num surge_charge = 0;
  Offset position = Offset(10, 100);

  Timer? timerUpdateLocation;
  Timer? timerData;
  bool rideCancelDetected = false;
  bool rideDetailsFetching = false;

  String service_marker = '';

  var bidNoteController = TextEditingController();
  var bidAmountController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _animation;
  bool isCurrentRequestCalled = false;

  List<LatLng> driverToPickupPolyline = [];
  List<LatLng> pickupToDropPolyline = [];
  double currentHeading = 0.0;
  double? lastHeading;

  static final AudioPlayer _player = AudioPlayer();
  bool isFetchingAddress = false;

  bool shouldForceUpdate = false;

  List<LatLng> fullRoutePoints = [];
  List<LatLng> remainingRoutePoints = [];
  PolylineId? activePolylineId;
  int _markerAnimToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 0.4).animate(_animController);
    // listenToCompass();
    if (sharedPref.getInt(IS_ONLINE) == 1) {
      setState(() {
        isOnLine = true;
      });
    } else {
      setState(() {
        isOnLine = false;
      });
    }
    locationPermission();
    if (app_update_check != null) {
      VersionService().getVersionData(context, app_update_check);
    }
    init();
    checkAndShowFirebasePopup();
  }

  void init() async {
    if (sharedPref.getDouble(LATITUDE) != null && sharedPref.getDouble(LONGITUDE) != null) {
      driverLocation = LatLng(sharedPref.getDouble(LATITUDE)!, sharedPref.getDouble(LONGITUDE)!);
    }
    // _messageSubscription = _messageController.stream.listen((message) {
    getCurrentRequest();
    // });
    await checkPermission();
    _updateUserLocation();
    // Geolocator.getPositionStream().listen((event) {
    //   // driverLocation = LatLng(event.latitude, event.longitude);
    //   // driverHeading = event.heading ?? 0.0;
    //   // if (previousLatLng != null) {
    //   //   updateMarker(driverLocation!);
    //   // }
    //   // previousLatLng = driverLocation!;
    //   setState(() {});
    // });
    LiveStream().on(CHANGE_LANGUAGE, (p0) {
      setState(() {});
    });
    walletCheckApi();
    getCurrentRequest();
    polylinePoints = PolylinePoints();
    startTime = REQUEST_TIME_VAL;
    // ignore:deprecated_member_use
    // sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), Platform.isIOS ? SourceIOSIcon : SourceIcon);
    sourceIcon = await getResizedMarker(SourceIcon);
    // ignore:deprecated_member_use
    // destinationIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), Platform.isIOS ? DestinationIOSIcon : DestinationIcon);
    destinationIcon = await getResizedMarker(DestinationIcon);

    if (appStore.isLoggedIn) {
      startLocationTracking();
    }
    // setSourceAndDestinationIcons();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      positionStream?.pause(); // safe
    } else if (state == AppLifecycleState.resumed) {
      positionStream?.resume(); // safe
    }
  }

  void listenToCompass() {
    FlutterCompass.events?.listen((CompassEvent event) {
      double newHeading = (event.heading ?? 0) % 360;

      if (lastHeading == null) {
        lastHeading = newHeading;
        currentHeading = newHeading;
        updateDriverMarker();
        return;
      }

      double angleDiff = (newHeading - lastHeading!).abs();
      if (angleDiff > 180) {
        angleDiff = 360 - angleDiff; // Normalize wrap-around
      }

      if (angleDiff > 20) {
        lastHeading = newHeading;
        currentHeading = newHeading;
        updateDriverMarker();
      }
    });
  }

  Future<void> updateDriverMarker() async {
    try {
      driverIcon = await getNetworkImageMarker(service_marker.validate());
    } catch (e) {
      driverIcon = await getResizedMarker(DriverIcon);
    }
    markers.removeWhere((marker) => marker.markerId.value == "driver");

    markers.add(
      Marker(
        markerId: MarkerId("driver"),
        position: driverLocation!,
        icon: driverIcon,
        rotation: currentHeading,
        anchor: Offset(0.5, 0.5),
        infoWindow: InfoWindow(title: ''),
      ),
    );
    setState(() {});
  }

  void _updateUserLocation() async {
    Position b = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    driverLocation = LatLng(b.latitude, b.longitude);
    Map req = {
      "latitude": driverLocation!.latitude.toString(),
      "longitude": driverLocation!.longitude.toString(),
      "currentHeading": currentHeading.toString(),
    };
    sharedPref.setDouble(LATITUDE, driverLocation!.latitude);
    sharedPref.setDouble(LONGITUDE, driverLocation!.longitude);
    await updateStatus(req).then((value) {
      setState(() {});
    }).catchError((error) {
      log(error);
    });
  }

  Future<void> locationPermission() async {
    // serviceStatusStream = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
    //   if (status == ServiceStatus.disabled) {
    //     locationEnable = false;
    //     Future.delayed(
    //       Duration(seconds: 1),
    //       () {
    //         launchScreen(navigatorKey.currentState!.overlay!.context, LocationPermissionScreen());
    //       },
    //     );
    //   } else if (status == ServiceStatus.enabled) {
    //     locationEnable = true;
    startLocationTracking();
    //     if (locationScreenKey.currentContext != null) {
    //       if (Navigator.canPop(navigatorKey.currentState!.overlay!.context)) {
    //         Navigator.pop(navigatorKey.currentState!.overlay!.context);
    //       }
    //     }
    //   }
    // });
  }

  cancelRideTimeOut() {
    Future.delayed(Duration(seconds: 1)).then((value) {
      appStore.setLoading(true);
      try {
        sharedPref.remove(ON_RIDE_MODEL);
        sharedPref.remove(IS_TIME2);
        duration = startTime;
        print("assign ride 300");
        servicesListData = null;
        _polyLines.clear();
        setMapPins();
        setState(() {});
        // FlutterRingtonePlayer().stop();
        stopAlertLoop();
      } catch (e) {}
      Map req = {
        "id": riderId,
        "driver_id": sharedPref.getInt(USER_ID),
        "is_accept": "0",
      };
      duration = startTime;
      rideRequestResPond(request: req).then((value) {
        print("rideRequestResPond 321");
        appStore.setLoading(false);
      }).catchError((error) {
        appStore.setLoading(false);
        log(error.toString());
      });
    });
  }

  Future<void> setTimeData() async {
    if (sharedPref.getString(IS_TIME2) == null) {
      duration = startTime;
      await sharedPref.setString(IS_TIME2, DateTime.now().add(Duration(seconds: startTime)).toString());
      startTimer(tag: "line222");
    } else {
      duration = DateTime.parse(sharedPref.getString(IS_TIME2)!).difference(DateTime.now()).inSeconds;
      await sharedPref.setString(IS_TIME2, DateTime.now().add(Duration(seconds: duration)).toString());
      if (duration < 0) {
        await sharedPref.remove(IS_TIME2);
        sharedPref.remove(ON_RIDE_MODEL);
        if (sharedPref.getString("RIDE_ID_IS") == null || sharedPref.getString("RIDE_ID_IS") == "$riderId") {
          return cancelRideTimeOut();
        } else {
          duration = startTime;
          startTimer(tag: "line248");
        }
      }
      sharedPref.setString("RIDE_ID_IS", "$riderId");
      if (duration > 0) {
        if (sharedPref.getString(ON_RIDE_MODEL) != null) {
          servicesListData = OnRideRequest.fromJson(jsonDecode(sharedPref.getString(ON_RIDE_MODEL)!));
        }

        startTimer(tag: "line238");
      } else {}
    }
  }

  Future<void> startTimer({required String tag}) async {
    try {
      timerData!.cancel();
    } catch (e) {}
    // await FlutterRingtonePlayer().stop();
    // await FlutterRingtonePlayer().play(
    //   fromAsset: ringtonePath,
    //   android: AndroidSounds.notification,
    //   ios: IosSounds.triTone,
    //   looping: true,
    //   volume: 0.1,
    //   asAlarm: false,
    // );

    stopAlertLoop();
    startAlertLoop();

    timerData = new Timer.periodic(
      Duration(seconds: 1),
      (Timer timer) {
        if (duration <= 0) {
          // timerRunning=false;
          try {
            timerData!.cancel();
          } catch (e) {}
          // if (duration == 0) {
          Future.delayed(Duration(seconds: 1)).then((value) {
            duration = startTime;
            try {
              // FlutterRingtonePlayer().stop();
              stopAlertLoop();
              timer.cancel();
            } catch (e) {}
            sharedPref.remove(ON_RIDE_MODEL);
            sharedPref.remove(IS_TIME2);
            print("assign ride 381");
            servicesListData = null;
            _polyLines.clear();
            setMapPins();
            // isOnLine=false;
            setState(() {});
            Map req = {
              "id": riderId,
              "driver_id": sharedPref.getInt(USER_ID),
              "is_accept": "0",
            };
            rideRequestResPond(request: req).then((value) {}).catchError((error) {
              print("rideRequestResPond 402");
              log(error.toString());
            });
          });
        } else {
          if (timerData != null && timerData!.isActive) {
            setState(() {
              duration--;
            });
          }
        }
      },
    );
  }

  Future<void> setSourceAndDestinationIcons() async {
    try {
      driverIcon = await getNetworkImageMarker(service_marker.validate());
    } catch (e) {
      driverIcon = await getResizedMarker(DriverIcon);
    }
    try {
      if (driverLocation != null) {
        markers.add(
          Marker(
            markerId: MarkerId("driver"),
            position: driverLocation!,
            icon: driverIcon,
            anchor: Offset(0.5, 0.5),
            infoWindow: InfoWindow(title: ''),
          ),
        );
      }
    } catch (e) {}
    // driverIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), Platform.isIOS ? DriverIOSIcon : DriverIcon);
    if (servicesListData != null)
      servicesListData!.status != IN_PROGRESS
          // ignore:deprecated_member_use
          ? sourceIcon = await getResizedMarker(SourceIcon)
          // sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), Platform.isIOS ? SourceIOSIcon : SourceIcon)
          // ignore:deprecated_member_use
          : destinationIcon = await getResizedMarker(DestinationIcon);
    // destinationIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), Platform.isIOS ? DestinationIOSIcon : DestinationIcon);
  }

  onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
    mapController = controller;
  }

  Future<void> driverStatus({int? status}) async {
    appStore.setLoading(true);
    Map req = {
      // "status": "active",
      "is_online": status,
    };
    await updateStatus(req).then((value) {
      sharedPref.setInt(IS_ONLINE, status ?? 0);
      appStore.setLoading(false);
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  void listenForNewDistance(int rideRequestId) {
    FirebaseFirestore.instance.collection(RIDE_COLLECTION).where('driver_ids', arrayContains: sharedPref.getInt(USER_ID)).where('ride_id', isEqualTo: rideRequestId).snapshots().listen((QuerySnapshot snapshot) {
      for (var doc in snapshot.docs) {
        var rideData = doc.data() as Map<String, dynamic>;

        if (rideData['distance'] != null) {
          distance = (rideData['distance'] as num).toDouble();
        } else {
          distance = 0;
        }
        if (rideData['duration'] != null) {
          rideDuration = (rideData['duration'] as num).toDouble();
        } else {
          rideDuration = 0;
        }

        print("update distance");
        setState(() {});
      }
    });
  }

  Future<void> getCurrentRequest() async {
    getCurrentRideRequest().then((value) async {
      if (value.schedule_ride_request != null && value.schedule_ride_request!.isNotEmpty) {
        schedule_ride_request = value.schedule_ride_request ?? [];
      }
      service_marker = value.service_marker.validate();
      driverIcon = await getNetworkImageMarker(service_marker.validate());

      if (value.all_unread_count != null) notificationCount = value.all_unread_count;
      setSourceAndDestinationIcons();

      try {
        await rideService.updateStatusOfRide(rideID: value.onRideRequest!.id, req: {'on_rider_stream_api_call': 0});
      } catch (e) {}
      appStore.setLoading(false);

      if (value.onRideRequest != null) {
        appStore.currentRiderRequest = value.onRideRequest;

        servicesListData = value.onRideRequest;
        if (value.onRideRequest != null && value.onRideRequest!.multiDropLocation != null) {
          servicesListData!.multiDropLocation = value.onRideRequest!.multiDropLocation;
        }
        userDetail(driverId: value.onRideRequest?.riderId);
        listenForNewDistance(servicesListData!.id!);
        setState(() {});

        if (servicesListData != null) {
          if (servicesListData?.status != COMPLETED) {
            setMapPins();
            DriverBackgroundService.startService();
            print("DriverBackgroundService.startService();");
          } else {
            DriverBackgroundService.stopService();
            print("DriverBackgroundService.stopService();");
          }
          if (servicesListData!.status == COMPLETED && servicesListData!.isDriverRated == 0) {
            if (current_screen == false) return;
            current_screen = false;
            // REVIEW IS DISABLED THEN AUTO SUBMIT 0 else Navigate TO Review Screen
            if (appStore.isShowRiderReview == '0') {
              appStore.setLoading(true);
              Map req = {
                "ride_request_id": value.onRideRequest!.id!,
                "rating": 0,
                "comment": '',
              };
              await ratingReview(request: req).then((value2) async {
                await rideDetail(rideId: value.onRideRequest!.id!).then((value3) {
                  RideService rideService = RideService();

                  rideService.updateStatusOfRide(rideID: value.onRideRequest!.id!, req: {'on_rider_stream_api_call': 0});
                  if (value3.payment != null && value3.payment!.paymentStatus == PENDING) {
                    launchScreen(context, DetailScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
                  } else {
                    launchScreen(context, DashboardScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
                  }
                }).catchError((error) {
                  appStore.setLoading(false);
                  toast(error.toString());
                });
                appStore.setLoading(false);
              }).catchError((error, s) {
                appStore.setLoading(false);
                print("ExceptionFound.E+>$error:::STACK:::$s");
              });
            } else {
              launchScreen(context, ReviewScreen(rideId: value.onRideRequest!.id!, currentData: value), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
            }
          } else if (value.payment != null && value.payment!.paymentStatus == PENDING) {
            if (current_screen == false) return;
            current_screen = false;
            launchScreen(context, DetailScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
          }
        }
      } else {
        if (value.payment != null && value.payment!.paymentStatus == PENDING) {
          if (current_screen == false) return;
          current_screen = false;
          launchScreen(context, DetailScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
        } else {
          servicesListData = null;
          _polyLines.clear();
          setState(() {});
        }
      }
      // if (servicesListData != null) await rideService.updateStatusOfRide(rideID: servicesListData!.id, req: {'status': servicesListData!.status});

      // await changeStatus();
      isCurrentRequestCalled = false;
    }).catchError((error, s) {
      print("TET::::$error ===>$s");
      toast(error.toString());

      appStore.setLoading(false);
      print("assign ride 634");
      servicesListData = null;
      setState(() {});
    });
  }

  getNewRideReq(int? riderID, {bool? refresh}) async {
    if (refresh != true) {
      if (servicesListData != null && servicesListData!.status == NEW_RIDE_REQUESTED) return;
    }

    await Future.delayed(Duration(seconds: 1));

    await rideDetail(rideId: riderID).then((value) async {
      if (value.ride_has_bids != null) {
        rideHasBid = value.ride_has_bids ?? 0;

        try {
          // admin_commission = num.tryParse(value.estimated_price[0]['admin_commission'].toString()) ?? 0;
          admin_commission = num.tryParse(value.data!.adminCommission!.toString()) ?? 0;

          // surge_charge = num.tryParse(value.estimated_price[0]['fixed_charge'].toString()) ?? 0;
          surge_charge = num.tryParse(value.data!.totalAmount!.toString()) ?? 0;

          // commission_type = value.estimated_price[0]['commission_type'].toString();
          commission_type = value.data!.commissionType!;

          calculateDriverEarning(value.data!);
        } catch (e, s) {
          print("checkComissions::::$e ==>$s");
        }
      } else {
        rideHasBid = 0;

        bidIsProcessing = 0;
      }

      // passengerCount = value.data?.passenger ?? 0;

      // luggageCount = value.data?.luggage ?? 0;

      if (value.bid_data != null && value.bid_data!.bidAmount != null) {
        bidIsProcessing = 1;
        try {
          bidData = value.bid_data!;
        } catch (e, s) {
          print("Exception FOUND:::${e}====>$s");
        }
      } else {
        bidIsProcessing = 0;
      }

      setState(() {});

      appStore.setLoading(false);

      if (value.data?.status == NEW_RIDE_REQUESTED || value.data?.status == BID_REJECTED) {
        try {
          OnRideRequest ride = OnRideRequest();

          ride.startAddress = value.data?.startAddress;

          ride.totalAmount = value.data?.totalAmount;

          ride.adminCommission = value.data?.adminCommission;

          //ride.driver_distance_to_pickup = value.driver_distance_to_pickup;

          // ride.dropoff_distance_in_km = value.data!.dropoff_distance_in_km;

          // ✅ Use 'distance' field from API since dropoff_distance_in_km is always null
          ride.dropoff_distance_in_km = (value.data?.dropoff_distance_in_km != null && value.data!.dropoff_distance_in_km! > 0)
              ? value.data!.dropoff_distance_in_km
              : (value.data?.distance as num?)?.toDouble();

          ride.distanceUnit = value.data!.distanceUnit;

          ride.isSchedule = value.data?.isSchedule;

          ride.trip_type = value.data?.trip_type;

          ride.schedule_datetime = value.data?.schedule_datetime;

          ride.startLatitude = value.data?.startLatitude;

          ride.startLongitude = value.data?.startLongitude;

          ride.endAddress = value.data?.endAddress;

          ride.endLongitude = value.data?.endLongitude;

          ride.endLatitude = value.data?.endLatitude;

          ride.riderName = value.data?.riderName;

          ride.riderContactNumber = value.data?.riderContactNumber;

          ride.riderProfileImage = value.data?.riderProfileImage;

          ride.riderEmail = value.data?.riderEmail;

          ride.id = value.data?.id;

          ride.status = value.data?.status;

          ride.otherRiderData = value.data?.otherRiderData;

          ride.multiDropLocation = value.data?.multiDropLocation;

          ride.type = value.data?.type;

          ride.weight = value.data?.weight;

          ride.parcelDescription = value.data?.parcelDescription;

          ride.pickupContactNumber = value.data?.pickupContactNumber;

          ride.pickupPersonName = value.data?.pickupPersonName;

          ride.pickupDescription = value.data?.pickupDescription;

          ride.deliveryContactNumber = value.data?.deliveryContactNumber;

          ride.deliveryPersonName = value.data?.deliveryPersonName;

          ride.deliveryDescription = value.data?.deliveryDescription;

          servicesListData = ride;
          rideDetailsFetching = false;

// ✅ driver → pickup distance (3.19 km) shown BEFORE accept
          if (value.driver_distance_to_pickup != null &&
              value.driver_distance_to_pickup! > 0) {
            distance = value.driver_distance_to_pickup!; // 3.19 km
          }

// ✅ ETA to pickup (7.13 min) shown BEFORE accept
          if (value.driver_duration_to_pickup != null &&
              value.driver_duration_to_pickup! > 0) {
            rideDuration = value.driver_duration_to_pickup!; // 7.13 min
          }

// ✅ pickup → dropoff ride distance (41 km) shown AFTER accept
          servicesListData!.dropoff_distance_in_km = value.data?.distance; // 41 km


          if (servicesListData != null) await rideService.updateStatusOfRide(rideID: servicesListData?.id, req: {'on_rider_stream_api_call': 0});
          // servicesListData = ride;
          //
          // rideDetailsFetching = false;
          //
          // ride.otherRiderData;
          //
          // if (servicesListData != null) await rideService.updateStatusOfRide(rideID: servicesListData?.id, req: {'on_rider_stream_api_call': 0});


          sharedPref.setString(ON_RIDE_MODEL, jsonEncode(servicesListData));

          riderId = value.data?.id ?? 0;

          listenForNewDistance(servicesListData!.id!);

          setState(() {});

          if (rideHasBid == 0 && value.data?.status == NEW_RIDE_REQUESTED) {
            setTimeData();
          }
        } catch (error, stack) {
          log('error:${error.toString()}  Stack ::::$stack');
        }
      }

      // requestDataFetching = false;

      setMapPins();
    }).catchError((error, stack) {
      // requestDataFetching = false;

      rideDetailsFetching = false;

      FirebaseCrashlytics.instance.recordError("pop_up_issue::" + error.toString(), stack, fatal: false);

      appStore.setLoading(false);

      log('ExceptionFound.E+>:${error.toString()}  Stack ::::$stack');
    });
  }

  Future<void> rideRequest({String? status}) async {
    appStore.setLoading(true);
    Map req = {
      "id": servicesListData!.id,
      "status": status,
    };
    await rideRequestUpdate(request: req, rideId: servicesListData!.id).then((value) async {
      appStore.setLoading(false);

      getCurrentRequest().then((value) async {
        if (/*status == ARRIVED ||*/ status == IN_PROGRESS) {
          _polyLines.clear();
          setMapPins();
        }
        setState(() {});
      });
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> rideRequestAccept({bool deCline = false}) async {
    appStore.setLoading(true);
    Map req = {
      "id": servicesListData!.id,
      "driver_id": sharedPref.getInt(USER_ID),
      "is_accept": deCline ? "0" : "1",
    };
    await rideRequestResPond(request: req).then((value) async {
      print("rideRequestResPond 771");
      appStore.setLoading(false);
      if (!deCline) {
        DriverBackgroundService.startService();
      }
      getCurrentRequest();

      if (deCline || servicesListData?.isSchedule == 1) {
        rideService.updateStatusOfRide(rideID: servicesListData!.id, req: {
          'on_stream_api_call': 0, /* 'driver_id': null*/
        });
        print("assign ride 848");
        servicesListData = null;
        _polyLines.clear();
        sharedPref.remove(ON_RIDE_MODEL);
        sharedPref.remove(IS_TIME2);
        setMapPins();
      }
    }).catchError((error) {
      setMapPins();
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> completeRideRequest() async {
    appStore.setLoading(true);
    Map req = {
      "id": servicesListData?.id ?? 0,
      "service_id": servicesListData!.serviceId,
      "start_latitude": servicesListData!.startLatitude,
      "start_longitude": servicesListData!.startLongitude,
      "end_latitude": driverLocation!.latitude,
      "end_longitude": driverLocation!.longitude,
      "end_address": endLocationAddress,
      // "distance": totalDistance,
      if (extraChargeList.isNotEmpty) "extra_charges": extraChargeList,
      if (extraChargeList.isNotEmpty) "extra_charges_amount": extraChargeAmount,
    };
    log(req);
    await completeRide(request: req).then((value) async {
      chatMessageService.exportChat(rideId: servicesListData!.id.toString(), senderId: sharedPref.getString(UID).validate(), receiverId: riderData!.uid.validate());
      try {
        await rideService.updateStatusOfRide(rideID: servicesListData?.id ?? 0, req: {'on_rider_stream_api_call': 0});
      } catch (e) {}
      // ignore:deprecated_member_use
      // sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), Platform.isIOS ? SourceIOSIcon : SourceIcon);
      sourceIcon = await getResizedMarker(SourceIcon);
      appStore.setLoading(false);
      DriverBackgroundService.stopService();
      getCurrentRequest();
    }).catchError((error) {
      chatMessageService.exportChat(rideId: servicesListData!.id.toString(), senderId: sharedPref.getString(UID).validate(), receiverId: riderData!.uid.validate());
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  // Future<void> setPolyLines({bool isFromLocationUpdate = false}) async {
  //   try {
  //     if (servicesListData != null) {
  //       LatLng pickupLatLng = LatLng(
  //         double.parse(servicesListData?.startLatitude ?? '0.0'),
  //         double.parse(servicesListData?.startLongitude ?? '0.0'),
  //       );
  //
  //       LatLng destinationLatLng;
  //
  //       // Handle multi-drop if exists
  //       if (servicesListData!.multiDropLocation != null && servicesListData!.multiDropLocation!.isNotEmpty) {
  //         var nextDrop = servicesListData!.multiDropLocation!.firstWhere(
  //           (drop) => drop.droppedAt == null,
  //           orElse: () => servicesListData!.multiDropLocation!.last,
  //         );
  //         destinationLatLng = LatLng(nextDrop.lat, nextDrop.lng);
  //       } else {
  //         destinationLatLng = LatLng(
  //           double.parse(servicesListData!.endLatitude.validate()),
  //           double.parse(servicesListData!.endLongitude.validate()),
  //         );
  //       }
  //
  //       bool isRideStarted = servicesListData!.status == IN_PROGRESS;
  //
  //       // --- STEP 1: DRIVER → PICKUP (only before ride starts)
  //       if (!isRideStarted) {
  //         await _updateSinglePolyline(
  //           polylineId: const PolylineId("driverToPickup"),
  //           start: driverLocation!,
  //           end: pickupLatLng,
  //           color: polyLineColor,
  //         );
  //       }
  //
  //       // --- STEP 2: PICKUP → DESTINATION (after ride started)
  //       if (isRideStarted) {
  //         await _updateSinglePolyline(
  //           polylineId: const PolylineId("pickupToDestination"),
  //           start: driverLocation!,
  //           end: destinationLatLng,
  //           color: polyLineColor2,
  //         );
  //       } else {
  //         // prepare route for later (optional preload)
  //         await _updateSinglePolyline(
  //           polylineId: const PolylineId("pickupToDestination"),
  //           start: pickupLatLng,
  //           end: destinationLatLng,
  //           color: polyLineColor2,
  //         );
  //       }
  //
  //       setState(() {});
  //     }
  //   } catch (e, s) {
  //     log("Polyline update error: $e\n$s");
  //   }
  // }

  Future<void> setPolyLines() async {
    try {
      if (servicesListData == null || driverLocation == null) return;

      LatLng pickupLatLng = LatLng(
        double.parse(servicesListData?.startLatitude ?? '0.0'),
        double.parse(servicesListData?.startLongitude ?? '0.0'),
      );

      LatLng destinationLatLng;

      if (servicesListData!.multiDropLocation != null && servicesListData!.multiDropLocation!.isNotEmpty) {
        var nextDrop = servicesListData!.multiDropLocation!.firstWhere(
          (drop) => drop.droppedAt == null,
          orElse: () => servicesListData!.multiDropLocation!.last,
        );
        destinationLatLng = LatLng(nextDrop.lat, nextDrop.lng);
      } else {
        destinationLatLng = LatLng(
          double.parse(servicesListData!.endLatitude.validate()),
          double.parse(servicesListData!.endLongitude.validate()),
        );
      }

      bool isRideStarted = servicesListData!.status == IN_PROGRESS;

      /// 🚀 DRIVER → PICKUP
      if (!isRideStarted) {
        if (activePolylineId?.value != "driverToPickup" || fullRoutePoints.isEmpty) {
          await loadRouteOnce(
            start: driverLocation!,
            end: pickupLatLng,
            polylineId: const PolylineId("driverToPickup"),
            color: polyLineColor,
          );
        } else {
          updatePolylineLocally(polyLineColor);
        }
      }

      /// 🚀 DRIVER → DESTINATION
      if (isRideStarted) {
        if (activePolylineId?.value != "pickupToDestination" || fullRoutePoints.isEmpty) {
          await loadRouteOnce(
            start: driverLocation!,
            end: destinationLatLng,
            polylineId: const PolylineId("pickupToDestination"),
            color: polyLineColor2,
          );
        } else {
          updatePolylineLocally(polyLineColor2);
        }
      }

      setState(() {});
    } catch (e, s) {
      log("Polyline update error: $e\n$s");
    }
  }

  Future<void> loadRouteOnce({
    required LatLng start,
    required LatLng end,
    required PolylineId polylineId,
    required Color color,
  }) async {
    try {
      String origins = "${start.latitude},${start.longitude}";
      String destinations = "${end.latitude},${end.longitude}";

      final value = await getPolylineData(origins, destinations);

      if (value.status == true && value.polyline != null) {
        fullRoutePoints = decodePolyline(value.polyline!);
        remainingRoutePoints = List.from(fullRoutePoints);

        activePolylineId = polylineId;

        _polyLines.clear();

        _polyLines.add(
          Polyline(
            polylineId: polylineId,
            color: color,
            width: 7,
            points: remainingRoutePoints,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      }
    } catch (e) {
      log("loadRouteOnce error: $e");
    }
  }

  List<LatLng> getRemainingRoute(LatLng driverLocation) {
    if (fullRoutePoints.isEmpty) return [];

    int nearestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < fullRoutePoints.length; i++) {
      double distance = Geolocator.distanceBetween(
        driverLocation.latitude,
        driverLocation.longitude,
        fullRoutePoints[i].latitude,
        fullRoutePoints[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return fullRoutePoints.sublist(nearestIndex);
  }

  void updatePolylineLocally(Color color) {
    if (driverLocation == null || activePolylineId == null) return;

    remainingRoutePoints = getRemainingRoute(driverLocation!);

    _polyLines.removeWhere((p) => p.polylineId == activePolylineId);

    _polyLines.add(
      Polyline(
        polylineId: activePolylineId!,
        color: color,
        width: 7,
        points: remainingRoutePoints,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    );
  }

  Future<void> setMapPins() async {
    try {
      MarkerId driverId = const MarkerId("driver");

      markers.clear();

      try {
        driverIcon = await getNetworkImageMarker(service_marker.validate());
      } catch (e, s) {
        print("UPDATE_MARKER_ERROR::$e ==>$s");
        driverIcon = await getResizedMarker(DriverIcon);
      }

      // markers.add(
      //   Marker(
      //     markerId: driverId,
      //     position: driverLocation!,
      //     icon: driverIcon,
      //     infoWindow: const InfoWindow(title: ''),
      //   ),
      // );

      markers.add(
        Marker(
          markerId: driverId,
          position: driverLocation!,
          icon: driverIcon,
          rotation: currentHeading,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: ''),
        ),
      );

      // Add static source and destination markers once
      if (servicesListData != null) {
        if (servicesListData!.status != IN_PROGRESS) {
          markers.add(
            Marker(
              markerId: const MarkerId('sourceLocation'),
              position: LatLng(
                double.parse(servicesListData!.startLatitude!),
                double.parse(servicesListData!.startLongitude!),
              ),
              icon: sourceIcon,
              infoWindow: InfoWindow(title: servicesListData!.startAddress),
            ),
          );
        }

        if (servicesListData!.multiDropLocation != null && servicesListData!.multiDropLocation!.isNotEmpty) {
          for (var element in servicesListData!.multiDropLocation!) {
            if (element.droppedAt == null) {
              markers.add(
                Marker(
                  markerId: MarkerId('destinationLocation_${element.drop}'),
                  position: LatLng(element.lat, element.lng),
                  icon: destinationIcon,
                  infoWindow: InfoWindow(title: element.address),
                ),
              );
            }
          }
        } else {
          markers.add(
            Marker(
              markerId: const MarkerId('destinationLocation'),
              position: LatLng(
                double.parse(servicesListData?.endLatitude ?? ''),
                double.parse(servicesListData?.endLongitude ?? ''),
              ),
              icon: destinationIcon,
              infoWindow: InfoWindow(title: servicesListData?.endAddress),
            ),
          );
        }
      }

      setState(() {});
    } catch (e) {
      print("Marker update error: $e");
    }

    await setPolyLines();
  }

  /// Get Current Location
  // Future<void> startLocationTracking() async {
  //   try {
  //     // 1. Permission check
  //     LocationPermission permission = await Geolocator.checkPermission();
  //     if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
  //       permission = await Geolocator.requestPermission();
  //       if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
  //         launchScreen(
  //           navigatorKey.currentState!.overlay!.context,
  //           LocationPermissionScreen(),
  //         );
  //         return;
  //       }
  //     }
  //
  //     // 2. GPS enabled check
  //     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  //     if (!serviceEnabled) {
  //       launchScreen(
  //         navigatorKey.currentState!.overlay!.context,
  //         LocationPermissionScreen(),
  //       );
  //       return;
  //     }
  //
  //     // 3. Location settings (STABLE)
  //     const locationSettings = LocationSettings(
  //       accuracy: LocationAccuracy.medium, // avoid drift
  //       distanceFilter: 150, // OS hint
  //     );
  //
  //     // 4. Cancel old stream
  //     await positionStream?.cancel();
  //
  //     // 5. Start stream
  //     positionStream = Geolocator.getPositionStream(
  //       locationSettings: locationSettings,
  //     ).listen((Position event) async {
  //       print(
  //         "GPS → Lat:${event.latitude}, "
  //         "Lng:${event.longitude}, "
  //         "Accuracy:${event.accuracy}",
  //       );
  //
  //       try {
  //         if (event.accuracy > 40) {
  //           print("Ignored due to bad accuracy");
  //           return;
  //         }
  //
  //         final newLocation = LatLng(event.latitude, event.longitude);
  //
  //         if (lastSentLocation == null) {
  //           lastSentLocation = newLocation;
  //           driverLocation = newLocation;
  //           return;
  //         }
  //
  //         final distance = Geolocator.distanceBetween(
  //           lastSentLocation!.latitude,
  //           lastSentLocation!.longitude,
  //           newLocation.latitude,
  //           newLocation.longitude,
  //         );
  //
  //         print("Distance from last sent: $distance meters");
  //
  //         if (distance >= 120) {
  //           lastSentLocation = newLocation;
  //           driverLocation = newLocation;
  //
  //           Map req = {
  //             "latitude": newLocation.latitude.toString(),
  //             "longitude": newLocation.longitude.toString(),
  //             "currentHeading": currentHeading.toString(),
  //           };
  //
  //           sharedPref.setDouble(LATITUDE, newLocation.latitude);
  //           sharedPref.setDouble(LONGITUDE, newLocation.longitude);
  //
  //           await updateStatus(req).catchError((e) {
  //             log("API error while updating location");
  //           });
  //
  //           setMapPins(isFromLocationUpdate: true);
  //           moveCameraToDriver(mapController!, newLocation);
  //
  //           sharedPref.setString("UPDATE_CALL", DateTime.now().toIso8601String());
  //         }
  //       } catch (e) {
  //         log("Error inside location stream: $e");
  //       }
  //     }, onError: (error) {
  //       log("STREAM ERROR: $error");
  //       restartLocationTracking();
  //     });
  //   } catch (e) {
  //     log("startLocationTracking ERROR: $e");
  //   }
  // }

  Future<void> startLocationTracking() async {
    try {
      // 1. Permission check
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

      // 2. GPS enabled check
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        launchScreen(
          navigatorKey.currentState!.overlay!.context,
          LocationPermissionScreen(),
        );
        return;
      }

      // 3. Location settings (STABLE)
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high, // avoid drift
        distanceFilter: 2, // OS hint
      );

      // 4. Cancel old stream
      await positionStream?.cancel();

      // 5. Start stream
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
            driverLocation = newLocation;

            // await updateStatus({
            //   "latitude": newLocation.latitude.toString(),
            //   "longitude": newLocation.longitude.toString(),
            //   "currentHeading": "0",
            // });

            return;
          }

          // ADD THIS BLOCK HERE (BEFORE distance calculation)

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
            driverLocation = newLocation;

            sharedPref.setDouble(LATITUDE, newLocation.latitude);
            sharedPref.setDouble(LONGITUDE, newLocation.longitude);

            _animateDriverMarker(animStart, newLocation);
            if (distance > 10) {
              setPolyLines();
            }
            if (count % 5 == 0) {
              moveCameraToDriver(mapController!, newLocation);
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

  void restartLocationTracking() {
    Future.delayed(Duration(seconds: 2), () {
      startLocationTracking();
    });
  }

  LatLng smoothLocation(LatLng old, LatLng current) {
    return LatLng(
      old.latitude + (current.latitude - old.latitude) * 0.3,
      old.longitude + (current.longitude - old.longitude) * 0.3,
    );
  }

  Future<void> _animateDriverMarker(LatLng start, LatLng end) async {
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

  Future<void> moveCameraToDriver(GoogleMapController mapController, LatLng driverLocation) async {
    try {
      // Apply a small downward shift (move map upward visually)
      final adjustedLocation = LatLng(
        driverLocation.latitude - 0.0030, // adjust this value as needed
        driverLocation.longitude,
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

  Future<void> checkAndUpdateLocation(Position event) async {
    LatLng newLocation = LatLng(event.latitude, event.longitude);

    double? oldLat = sharedPref.getDouble(LATITUDE);
    double? oldLng = sharedPref.getDouble(LONGITUDE);

    // If no previous location, set and update
    if (oldLat == null || oldLng == null) {
      await updateLocationAndCallAPI(newLocation);
      return;
    }

    double distance = Geolocator.distanceBetween(
      oldLat,
      oldLng,
      newLocation.latitude,
      newLocation.longitude,
    );

    if (distance > 100) {
      await updateLocationAndCallAPI(newLocation);
    }
  }

  Future<void> updateLocationAndCallAPI(LatLng newLocation) async {
    if (!appStore.isLoggedIn) return;

    driverLocation = newLocation;

    Map req = {
      "latitude": newLocation.latitude.toString(),
      "longitude": newLocation.longitude.toString(),
    };

    sharedPref.setDouble(LATITUDE, newLocation.latitude);
    sharedPref.setDouble(LONGITUDE, newLocation.longitude);
    sharedPref.setString("UPDATE_CALL", DateTime.now().toString());

    await updateStatus(req).then((value) {
      setState(() {});
    }).catchError((error) {
      log(error);
    });

    setMapPins();
    // if (servicesListData != null) setPolyLines();
  }

  Future<void> userDetail({int? driverId}) async {
    await getUserDetail(userId: driverId).then((value) {
      appStore.setLoading(false);
      riderData = value.data!;
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
    });
  }

  /// WalletCheck
  Future<void> walletCheckApi() async {
    await walletDetailApi().then((value) async {
      if (value.totalAmount! >= value.minAmountToGetRide!) {
        //
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return emptyWalletAlertDialog();
          },
        );
      }
    }).catchError((e) {
      log("Error $e");
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    // positionStream.cancel();
    // _messageSubscription.cancel();
    // FlutterRingtonePlayer().stop();
    stopAlertLoop();
    if (timerData != null) {
      timerData!.cancel();
    }
    try {
      positionStream?.cancel();
    } catch (e) {}
    _animController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ignore:deprecated_member_use
      onPopInvoked: (v) async {
        return Future.value(true);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          // backgroundColor: Colors.transparent,
          // systemOverlayStyle: SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarColor: Colors.black, statusBarBrightness: Brightness.dark),
        ),
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        key: scaffoldKey,
        drawer: DrawerComponent(onCall: () async {
          await driverStatus(status: 0);
        }),
        body: Stack(
          children: [
            if (sharedPref.getDouble(LATITUDE) != null && sharedPref.getDouble(LONGITUDE) != null)
              GoogleMap(
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                compassEnabled: true,
                padding: EdgeInsets.only(top: context.statusBarHeight + 4 + 24),
                // padding: const EdgeInsets.only(top: 70),
                onMapCreated: onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: driverLocation ?? LatLng(sharedPref.getDouble(LATITUDE)!, sharedPref.getDouble(LONGITUDE)!),
                  zoom: 17.0,
                ),
                markers: markers,
                mapType: MapType.normal,
                polylines: _polyLines,
              ),
            onlineOfflineSwitch(),
            StreamBuilder<QuerySnapshot>(
                stream: rideService.fetchRide(userId: sharedPref.getInt(USER_ID)),
                builder: (c, snapshot) {
                  if (snapshot.hasData) {
                    List<FRideBookingModel> data = snapshot.data!.docs.map((e) => FRideBookingModel.fromJson(e.data() as Map<String, dynamic>)).toList();
                    data.forEach(
                      (element) {},
                    );
                    if (data.length >= 2) {
                      rideService.removeOldRideEntry(userId: sharedPref.getInt(USER_ID));
                    }

                    if (data.length != 0) {
                      if (data.length > 1) {
                        List<int> numbers = data
                            .map(
                              (e) => e.rideId ?? 0,
                            )
                            .toList();
                        int maxNumber = numbers.reduce((a, b) => a > b ? a : b);
                        data.removeWhere(
                          (element) => element.rideId != maxNumber,
                        );
                      }
                      rideCancelDetected = false;
                      if (data[0].onStreamApiCall == 0) {
                        print("1553");
                        rideService.updateStatusOfRide(rideID: data[0].rideId, req: {'on_stream_api_call': 1});
                        if (data[0].status == NEW_RIDE_REQUESTED || data[0].status == BID_REJECTED) {
                          getNewRideReq(data[0].rideId);
                        } else {
                          getCurrentRequest();
                        }
                      }

                      if (servicesListData != null && data.isNotEmpty && data[0].rideId != servicesListData!.id) {
                        print("1565");
                        servicesListData = null;
                        setMapPins();
                        // getCurrentRequest();
                      }
                      if (servicesListData == null && (data[0].status == NEW_RIDE_REQUESTED || data[0].status == BID_REJECTED) && data[0].onStreamApiCall == 1) {
                        reqCheckCounter++;
                        if (reqCheckCounter < 2) {
                          rideService.updateStatusOfRide(rideID: data[0].rideId, req: {'on_stream_api_call': 0});
                        }
                      }
                      if ((servicesListData != null && servicesListData!.status != NEW_RIDE_REQUESTED && data[0].status == NEW_RIDE_REQUESTED && data[0].onStreamApiCall == 1) || (servicesListData == null && data[0].status == NEW_RIDE_REQUESTED && data[0].onStreamApiCall == 1)) {
                        if (rideDetailsFetching != true) {
                          rideDetailsFetching = true;
                          rideService.updateStatusOfRide(rideID: data[0].rideId, req: {'on_stream_api_call': 0});
                        }
                      }
                      return servicesListData != null
                          ? rideHasBid == 1 && (data[0].status == NEW_RIDE_REQUESTED || data[0].status == BID_REJECTED)
                              ? bidIsProcessing == 1 && (data[0].status == NEW_RIDE_REQUESTED || data[0].status == BID_REJECTED)
                                  ? bidProcessView()
                                  : bidAcceptView()
                              : servicesListData!.status != null && servicesListData!.status == NEW_RIDE_REQUESTED && rideHasBid != 1
                                  ? SizedBox.expand(
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          servicesListData != null && duration >= 0
                                              ? Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.only(topLeft: Radius.circular(2 * defaultRadius), topRight: Radius.circular(2 * defaultRadius)),
                                                  ),
                                                  child: SingleChildScrollView(
                                                    // controller: scrollController,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Align(
                                                          alignment: Alignment.center,
                                                          child: Container(
                                                            margin: EdgeInsets.only(top: 16),
                                                            height: 6,
                                                            width: 60,
                                                            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                                                            alignment: Alignment.center,
                                                          ),
                                                        ),
                                                        SizedBox(height: 8),
                                                        Padding(
                                                          padding: EdgeInsets.only(left: 16),
                                                          child: Text(language.requests, style: primaryTextStyle(size: 18)),
                                                        ),
                                                        // SizedBox(height: 4),
                                                        Padding(
                                                          padding: EdgeInsets.all(16),
                                                          child: Column(
                                                            children: [
                                                              Row(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  ClipRRect(
                                                                    borderRadius: BorderRadius.circular(defaultRadius),
                                                                    child: commonCachedNetworkImage(servicesListData!.riderProfileImage.validate(), height: 35, width: 35, fit: BoxFit.cover),
                                                                  ),
                                                                  SizedBox(width: 12),
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text('${servicesListData!.riderName.capitalizeFirstLetter()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                                                        SizedBox(height: 4),
                                                                        Text('${servicesListData!.riderEmail.validate()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: secondaryTextStyle()),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  if (duration > 0)
                                                                    Container(
                                                                      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                                                                      padding: EdgeInsets.all(6),
                                                                      child: Text("$duration".padLeft(2, "0"), style: boldTextStyle(color: Colors.white)),
                                                                    )
                                                                ],
                                                              ),
                                                              if (!(servicesListData?.schedule_datetime.isEmptyOrNull ?? false) && servicesListData?.isSchedule == 1) ...[
                                                                8.height,
                                                                Row(
                                                                  children: [
                                                                    Container(
                                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.green,
                                                                        borderRadius: BorderRadius.circular(8),
                                                                      ),
                                                                      child: Text(
                                                                        "${language.schedule_at}: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.parse(servicesListData!.schedule_datetime.toString() + "Z").toLocal())}",
                                                                        style: secondaryTextStyle(size: 13, color: Colors.white, weight: FontWeight.bold),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                // Padding(
                                                                //   padding: EdgeInsets.symmetric(horizontal: 10),
                                                                //   child: TaxiCourierButton(ScheduleTime: servicesListData?.schedule_datetime),
                                                                // ),
                                                              ],
                                                              10.height,
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  if (distance != null && distance != 0)
                                                                    Row(
                                                                      children: [
                                                                        Container(
                                                                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                                                                          child: Image.asset(ic_pickup, height: 30, width: 30, fit: BoxFit.cover),
                                                                        ),
                                                                        8.width,
                                                                        Column(
                                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text('${distance} ${servicesListData?.distanceUnit ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                                                            Text('${language.pickupdistance}', style: secondaryTextStyle(size: 16)),
                                                                          ],
                                                                        )
                                                                      ],
                                                                    ),
                                                                  Spacer(),
                                                                  if (servicesListData?.dropoff_distance_in_km != null)
                                                                    Row(
                                                                      children: [
                                                                        Column(
                                                                          crossAxisAlignment: CrossAxisAlignment.end,
                                                                          children: [
                                                                            Text('${servicesListData?.dropoff_distance_in_km?.toStringAsFixed(2) ?? ""} ${servicesListData?.distanceUnit ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                                                            Text('${language.distance}', style: secondaryTextStyle(size: 16)),
                                                                          ],
                                                                        ),
                                                                        8.width,
                                                                        Container(
                                                                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                                                                          child: Image.asset(ic_distance, height: 30, width: 30, fit: BoxFit.cover),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                ],
                                                              ),
                                                              8.height,
                                                              DottedLine(
                                                                direction: Axis.horizontal,
                                                                lineLength: double.infinity,
                                                                lineThickness: 1,
                                                                dashLength: 2,
                                                                dashColor: primaryColor,
                                                              ),
                                                              6.height,
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Text(language.estimateFare, style: secondaryTextStyle(size: 14)),
                                                                  printAmountWidget(amount: servicesListData?.totalAmount!.toStringAsFixed(digitAfterDecimal) ?? "", size: 14),
                                                                ],
                                                              ),
                                                              5.height,
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Text(language.platformFee, style: secondaryTextStyle(size: 14)),
                                                                  Row(
                                                                    children: [Text("-", style: boldTextStyle(color: Colors.red, size: 14)), printAmountWidget(amount: '${platformFee}', color: Colors.red, size: 14)],
                                                                  ),
                                                                ],
                                                              ),
                                                              5.height,
                                                              Container(
                                                                padding: EdgeInsets.all(5),
                                                                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        Icon(Icons.check_circle, color: Colors.green),
                                                                        5.width,
                                                                        Text(language.youWillGet, style: boldTextStyle(color: Colors.black)),
                                                                      ],
                                                                    ),
                                                                    printAmountWidget(amount: '${youWillGet.toStringAsFixed(digitAfterDecimal)}', color: Colors.green, size: 14)
                                                                  ],
                                                                ),
                                                              ),
                                                              6.height,
                                                              DottedLine(
                                                                direction: Axis.horizontal,
                                                                lineLength: double.infinity,
                                                                lineThickness: 1,
                                                                dashLength: 2,
                                                                dashColor: primaryColor,
                                                              ),
                                                              8.height,
                                                              addressDisplayWidget(
                                                                  endLatLong: LatLng(servicesListData!.endLatitude.toDouble(), servicesListData!.endLongitude.toDouble()),
                                                                  endAddress: servicesListData!.endAddress,
                                                                  startLatLong: LatLng(servicesListData!.startLatitude.toDouble(), servicesListData!.startLongitude.toDouble()),
                                                                  startAddress: servicesListData!.startAddress),
                                                              if (servicesListData != null && servicesListData!.otherRiderData != null)
                                                                Divider(
                                                                  color: Colors.grey.shade300,
                                                                  thickness: 0.7,
                                                                  height: 8,
                                                                ),
                                                              _bookingForView(),
                                                              SizedBox(height: 8),
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: inkWellWidget(
                                                                      onTap: () {
                                                                        showConfirmDialogCustom(dialogType: DialogType.DELETE, primaryColor: primaryColor, title: language.areYouSureYouWantToCancelThisRequest, positiveText: language.yes, negativeText: language.no, context, onAccept: (v) {
                                                                          reqCheckCounter = 0;

                                                                          try {
                                                                            // FlutterRingtonePlayer().stop();
                                                                            stopAlertLoop();
                                                                            timerData!.cancel();
                                                                          } catch (e) {}
                                                                          sharedPref.remove(IS_TIME2);
                                                                          sharedPref.remove(ON_RIDE_MODEL);
                                                                          rideRequestAccept(deCline: true);
                                                                        }).then(
                                                                          (value) {
                                                                            _polyLines.clear();
                                                                            setState;
                                                                          },
                                                                        );
                                                                      },
                                                                      child: Container(
                                                                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(defaultRadius), border: Border.all(color: Colors.red)),
                                                                        child: Text(language.decline, style: boldTextStyle(color: Colors.red), textAlign: TextAlign.center),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  SizedBox(width: 16),
                                                                  Expanded(
                                                                    child: AppButtonWidget(
                                                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                                                      text: language.accept,
                                                                      shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius)),
                                                                      color: primaryColor,
                                                                      textStyle: boldTextStyle(color: Colors.white),
                                                                      onTap: () {
                                                                        reqCheckCounter = 0;
                                                                        showConfirmDialogCustom(primaryColor: primaryColor, dialogType: DialogType.ACCEPT, positiveText: language.yes, negativeText: language.no, title: language.areYouSureYouWantToAcceptThisRequest, context, onAccept: (v) {
                                                                          try {
                                                                            // FlutterRingtonePlayer().stop();
                                                                            stopAlertLoop();
                                                                            timerData!.cancel();
                                                                          } catch (e) {}
                                                                          sharedPref.remove(IS_TIME2);

                                                                          sharedPref.remove(ON_RIDE_MODEL);
                                                                          rideRequestAccept();
                                                                        });
                                                                      },
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              : SizedBox(),
                                          Observer(builder: (context) {
                                            return appStore.isLoading ? loaderWidget() : SizedBox();
                                          })
                                        ],
                                      ),
                                    )
                                  : Positioned(
                                      bottom: 0,
                                      child: Container(
                                        width: MediaQuery.of(context).size.width,
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.only(topLeft: Radius.circular(2 * defaultRadius), topRight: Radius.circular(2 * defaultRadius)),
                                        ),
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
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(defaultRadius),
                                                  child: commonCachedNetworkImage(servicesListData!.riderProfileImage, height: 38, width: 38, fit: BoxFit.cover),
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('${servicesListData!.riderName.capitalizeFirstLetter()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                                      SizedBox(height: 4),
                                                      Text('${servicesListData!.riderEmail.validate()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: secondaryTextStyle()),
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
                                                          content: AlertScreen(rideId: servicesListData!.id, regionId: servicesListData!.regionId),
                                                        );
                                                      },
                                                    );
                                                  },
                                                  child: chatCallWidget(Icons.sos),
                                                ),
                                                SizedBox(width: 8),
                                                inkWellWidget(
                                                  onTap: () {
                                                    launchUrl(Uri.parse('tel:${servicesListData!.riderContactNumber}'), mode: LaunchMode.externalApplication);
                                                  },
                                                  child: chatCallWidget(Icons.call),
                                                ),
                                                SizedBox(width: 8),
                                                inkWellWidget(
                                                  onTap: () {
                                                    if (riderData == null || (riderData != null && riderData!.uid == null)) {
                                                      init();
                                                      return;
                                                    }
                                                    if (riderData != null) {
                                                      launchScreen(
                                                          context,
                                                          ChatScreen(
                                                            userData: riderData,
                                                            ride_id: riderId,
                                                          ));
                                                    }
                                                  },
                                                  child: chatCallWidget(Icons.chat_bubble_outline, data: riderData),
                                                ),
                                              ],
                                            ),
                                            10.height,
                                            if (servicesListData!.status != IN_PROGRESS) ...[
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  if (distance != null && distance != 0)
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                                                          child: Image.asset(ic_pickup, height: 30, width: 30, fit: BoxFit.cover),
                                                        ),
                                                        8.width,
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text('${distance} ${servicesListData?.distanceUnit ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                                            Text('${language.pickupdistance}', style: secondaryTextStyle(size: 16)),
                                                          ],
                                                        )
                                                      ],
                                                    ),
                                                  Spacer(),
                                                  if (rideDuration != null && rideDuration != 0)
                                                    Row(
                                                      children: [
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.end,
                                                          children: [
                                                            Text(
                                                              (rideDuration ?? 0) < 1 ? language.arrivingAtPickup : "${rideDuration.toString()} min",
                                                              style: boldTextStyle(
                                                                size: 14,
                                                              ),
                                                            ),
                                                            5.width,
                                                            Text("${language.timeToPickup} ", style: secondaryTextStyle(size: 16)),
                                                          ],
                                                        ),
                                                        8.width,
                                                        Container(
                                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                                                          child: Image.asset(ic_time, height: 22, width: 22, fit: BoxFit.cover),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ] else ...[
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  if (distance != null && distance != 0)
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                                                          child: Image.asset(ic_distance, height: 30, width: 30, fit: BoxFit.cover),
                                                        ),
                                                        8.width,
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text('${distance} ${servicesListData?.distanceUnit ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                                            Text('${language.distance}', style: secondaryTextStyle(size: 16)),
                                                          ],
                                                        )
                                                      ],
                                                    ),
                                                  Spacer(),
                                                  if (rideDuration != null && rideDuration != 0)
                                                    Row(
                                                      children: [
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.end,
                                                          children: [
                                                            Text(
                                                              (rideDuration ?? 0) < 1 ? language.arrivingAtDropOff : "${rideDuration.toString()} min",
                                                              style: boldTextStyle(
                                                                size: 14,
                                                              ),
                                                            ),
                                                            5.width,
                                                            Text("${language.timeToDropOff} ", style: secondaryTextStyle(size: 16)),
                                                          ],
                                                        ),
                                                        8.width,
                                                        Container(
                                                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                                                          child: Image.asset(ic_time, height: 22, width: 22, fit: BoxFit.cover),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ],
                                            8.height,
                                            addressDisplayWidget(
                                                endLatLong: LatLng(servicesListData!.endLatitude.toDouble(), servicesListData!.endLongitude.toDouble()),
                                                endAddress: servicesListData!.endAddress,
                                                startLatLong: LatLng(servicesListData!.startLatitude.toDouble(), servicesListData!.startLongitude.toDouble()),
                                                startAddress: servicesListData!.startAddress),
                                            SizedBox(height: 8),
                                            servicesListData!.status != NEW_RIDE_REQUESTED
                                                ? Padding(
                                                    padding: EdgeInsets.only(bottom: servicesListData!.status == IN_PROGRESS ? 0 : 8),
                                                    child: _bookingForView(),
                                                  )
                                                : SizedBox(),
                                            if (servicesListData!.status == IN_PROGRESS && servicesListData != null && servicesListData!.otherRiderData != null) SizedBox(height: 8),
                                            if (servicesListData!.status == IN_PROGRESS)
                                              if (appStore.extraChargeValue != null)
                                                Observer(builder: (context) {
                                                  return Visibility(
                                                    visible: int.parse(appStore.extraChargeValue!) != 0,
                                                    child: inkWellWidget(
                                                      onTap: () async {
                                                        List<ExtraChargeRequestModel>? extraChargeListData = await showModalBottomSheet(
                                                          isScrollControlled: true,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius))),
                                                          context: context,
                                                          builder: (_) {
                                                            return Padding(
                                                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                                              child: ExtraChargesWidget(data: extraChargeList),
                                                            );
                                                          },
                                                        );
                                                        if (extraChargeListData != null) {
                                                          extraChargeAmount = 0;
                                                          extraChargeList.clear();
                                                          extraChargeListData.forEach((element) {
                                                            extraChargeAmount = extraChargeAmount + element.value!;
                                                            extraChargeList = extraChargeListData;
                                                          });
                                                        }
                                                      },
                                                      child: Column(
                                                        children: [
                                                          Padding(
                                                            padding: EdgeInsets.only(bottom: 8),
                                                            child: Container(
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.max,
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  if (extraChargeAmount != 0)
                                                                    Row(
                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                      children: [
                                                                        Text('${language.extraCharges} : ', style: secondaryTextStyle(color: Colors.green)),
                                                                        printAmountWidget(amount: '${extraChargeAmount.toStringAsFixed(digitAfterDecimal)}', size: 14, color: Colors.green, weight: FontWeight.normal)
                                                                      ],
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }),
                                            buttonWidget()
                                          ],
                                        ),
                                      ),
                                    )
                          : SizedBox();
                    } else {
                      if (data.isEmpty) {
                        rideHasBid = 0;
                        bidIsProcessing = 0;
                        reqCheckCounter = 0;
                        try {
                          // FlutterRingtonePlayer().stop();
                          stopAlertLoop();
                          if (timerData != null) {
                            timerData!.cancel();
                          }
                        } catch (e) {}
                      }
                      if (servicesListData != null) {
                        checkRideCancel();
                      }
                      if (riderId != 0) {
                        riderId = 0;
                        try {
                          sharedPref.remove(IS_TIME2);
                          timerData!.cancel();
                        } catch (e) {}
                      }
                      servicesListData = null;
                      _polyLines.clear();
                      return SizedBox();
                    }
                  } else {
                    return snapWidgetHelper(snapshot, loadingWidget: loaderWidget());
                  }
                }),
            Positioned(
              top: context.statusBarHeight + 4,
              right: 14,
              left: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  topWidget(),
                  SizedBox(
                    height: 8,
                  ),
                  inkWellWidget(
                    onTap: () async {
                      final geoPosition = await Geolocator.getCurrentPosition(timeLimit: Duration(seconds: 30), desiredAccuracy: LocationAccuracy.high);
                      mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(geoPosition.latitude, geoPosition.longitude)));
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
                      child: Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),
            // Visibility(
            //   visible: appStore.isLoading,
            //   child: loaderWidget(type: '3'),
            // ),
            Observer(
              builder: (context) {
                return Visibility(
                  visible: appStore.isLoading,
                  child: loaderWidget(),
                );
              },
            ),
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
                    final safeX = newOffset.dx.clamp(0.0, screenSize.width - 180);
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
          ],
        ),
      ),
    );
  }

  Future<void> getUserLocation() async {
    List<Placemark> placemarks = await placemarkFromCoordinates(driverLocation!.latitude, driverLocation!.longitude);
    Placemark place = placemarks[0];
    endLocationAddress = '${place.street},${place.subLocality},${place.thoroughfare},${place.locality}';
  }

  Widget topWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        inkWellWidget(
          onTap: () {
            scaffoldKey.currentState!.openDrawer();
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
            child: Icon(Icons.drag_handle),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), spreadRadius: 1),
                ],
                borderRadius: BorderRadius.circular(defaultRadius),
                border: Border.all(color: isOnLine ? Colors.green : Colors.red)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                lt.Lottie.asset(
                  taxiAnim,
                  height: 25,
                  fit: BoxFit.cover,
                  animate: isOnLine,
                ),
                SizedBox(width: 8),
                Text(isOnLine ? language.youAreOnlineNow : language.youAreOfflineNow, style: secondaryTextStyle(color: primaryColor)),
              ],
            ),
          ),
        ),
        inkWellWidget(
          onTap: () {
            launchScreen(getContext, NotificationScreen()).then((v) {
              notificationCount = 0;
              setState(() {});
            });
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

  Widget onlineOfflineSwitch() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 30,
      // width:context.width(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () async {
                await showConfirmDialogCustom(dialogType: DialogType.CONFIRMATION, primaryColor: primaryColor, title: isOnLine ? language.areYouCertainOffline : language.areYouCertainOnline, context, onAccept: (v) {
                  driverStatus(status: isOnLine ? 0 : 1);
                  isOnLine = !isOnLine;
                  setState(() {});
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 600),
                decoration: BoxDecoration(
                    // color:isOnLine?Colors.green:Colors.red,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isOnLine ? Colors.green : Colors.red,
                    )),
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    isOnLine
                        ? Text(
                            language.online,
                            style: boldTextStyle(color: Colors.green, size: 18, weight: FontWeight.w700),
                          )
                        : ImageIcon(AssetImage(ic_red_car), color: Colors.red, size: 30),
                    SizedBox(width: 8),
                    isOnLine
                        ? ImageIcon(AssetImage(ic_green_car), color: Colors.green, size: 30)
                        : Text(
                            language.offLine,
                            style: boldTextStyle(color: Colors.red, size: 18, weight: FontWeight.w700),
                          )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buttonWidget() {
    return Row(
      children: [
        if (servicesListData!.status != IN_PROGRESS)
          Expanded(
            flex: 0,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: AppButtonWidget(
                  // width: MediaQuery.of(context).size.width,
                  text: language.cancel,
                  textColor: primaryColor,
                  color: Colors.white,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                  // color: Colors.grey,
                  // textStyle: boldTextStyle(color: Colors.white),
                  onTap: () {
                    showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        isDismissible: false,
                        builder: (context) {
                          return CancelOrderDialog(onCancel: (reason) async {
                            Navigator.pop(context);
                            appStore.setLoading(true);
                            await cancelRequest(reason);
                            appStore.setLoading(false);
                          });
                        });
                  }),
            ),
          ),
        if (servicesListData!.status == IN_PROGRESS)
          Expanded(
            flex: 0,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: AppButtonWidget(
                  child: Row(
                    children: [
                      Icon(
                        Icons.add,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        language.extraFees,
                        style: boldTextStyle(
                          color: primaryColor,
                        ),
                      )
                    ],
                  ),
                  // width: MediaQuery.of(context).size.width,
                  text: language.extraFees,
                  textColor: primaryColor,
                  color: Colors.white,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                  // color: Colors.grey,
                  // textStyle: boldTextStyle(color: Colors.white),
                  onTap: () async {
                    List<ExtraChargeRequestModel>? extraChargeListData = await showModalBottomSheet(
                      isScrollControlled: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius))),
                      context: context,
                      builder: (_) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                          child: ExtraChargesWidget(data: extraChargeList),
                        );
                      },
                    );
                    if (extraChargeListData != null) {
                      extraChargeAmount = 0;
                      extraChargeList.clear();
                      extraChargeListData.forEach((element) {
                        extraChargeAmount = extraChargeAmount + element.value!;
                        extraChargeList = extraChargeListData;
                      });
                    }
                  }),
            ),
          ),
        Expanded(
          flex: 1,
          child: AppButtonWidget(
            // width: MediaQuery.of(context).size.width,
            text: buttonText(status: servicesListData!.status),
            color: primaryColor,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ImageIcon(
                  AssetImage(statusTypeIconForButton(
                      type: servicesListData!.status == IN_PROGRESS && servicesListData!.multiDropLocation != null && servicesListData!.multiDropLocation!.isNotEmpty && servicesListData!.multiDropLocation!.where((element) => element.droppedAt == null).length > 1
                          ? ARRIVED
                          : servicesListData!.status.validate())),
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(
                  width: 4,
                ),
                Text(
                    servicesListData!.status == IN_PROGRESS && servicesListData!.multiDropLocation != null && servicesListData!.multiDropLocation!.isNotEmpty && servicesListData!.multiDropLocation!.where((element) => element.droppedAt == null).length > 1
                        ? language.updateDrop
                        : buttonText(status: servicesListData!.status),
                    style: boldTextStyle(color: Colors.white)),
              ],
            ),
            textStyle: boldTextStyle(color: Colors.white),
            onTap: () async {
              if (await checkPermission()) {
                if (servicesListData!.status == ACCEPTED || servicesListData!.status == BID_ACCEPTED) {
                  showConfirmDialogCustom(primaryColor: primaryColor, positiveText: language.yes, negativeText: language.no, dialogType: DialogType.CONFIRMATION, title: language.areYouSureYouWantToArriving, context, onAccept: (v) {
                    rideRequest(status: ARRIVING);
                  });
                } else if (servicesListData!.status == ARRIVING) {
                  showConfirmDialogCustom(primaryColor: primaryColor, positiveText: language.yes, negativeText: language.no, dialogType: DialogType.CONFIRMATION, title: language.areYouSureYouWantToArrived, context, onAccept: (v) {
                    rideRequest(status: ARRIVED);
                  });
                } else if (servicesListData!.status == ARRIVED) {
                  otpController.clear();
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) {
                      return AlertDialog(
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(language.enterOtp, style: boldTextStyle(), textAlign: TextAlign.center),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: inkWellWidget(
                                    onTap: () {
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                                      child: Icon(Icons.close, size: 20, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(language.startRideAskOTP, style: secondaryTextStyle(size: 12), textAlign: TextAlign.center),
                            SizedBox(height: 16),
                            Center(
                              child: Pinput(
                                keyboardType: TextInputType.number,
                                readOnly: false,
                                autofocus: true,
                                length: 4,
                                onTap: () {},
                                onLongPress: () {},
                                cursor: Text(
                                  "|",
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                                ),
                                focusedPinTheme: PinTheme(
                                  width: 40,
                                  height: 44,
                                  textStyle: TextStyle(
                                    fontSize: 18,
                                  ),
                                  decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.all(Radius.circular(8)), border: Border.all(color: primaryColor)),
                                ),
                                toolbarEnabled: true,
                                useNativeKeyboard: true,
                                defaultPinTheme: PinTheme(
                                  width: 40,
                                  height: 44,
                                  textStyle: TextStyle(
                                    fontSize: 18,
                                  ),
                                  decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.all(Radius.circular(8)), border: Border.all(color: dividerColor)),
                                ),
                                isCursorAnimationEnabled: true,
                                showCursor: true,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                closeKeyboardWhenCompleted: false,
                                enableSuggestions: false,
                                autofillHints: [],
                                controller: otpController,
                                onCompleted: (val) {
                                  otpCheck = val;
                                },
                              ),
                            ),
                            SizedBox(height: 16),
                            AppButtonWidget(
                              width: MediaQuery.of(context).size.width,
                              text: language.confirm,
                              onTap: () {
                                if (otpCheck == null || otpCheck != servicesListData!.otp) {
                                  return toast(language.pleaseEnterValidOtp);
                                } else {
                                  Navigator.pop(context);
                                  rideRequest(status: IN_PROGRESS);
                                }
                              },
                            )
                          ],
                        ),
                      );
                    },
                  );
                } else if (servicesListData!.status == IN_PROGRESS) {
                  // check is all drop location passed
                  if (servicesListData!.multiDropLocation != null && servicesListData!.multiDropLocation!.isNotEmpty && servicesListData!.multiDropLocation!.where((element) => element.droppedAt == null).length > 1
                      // servicesListData!.multiDropLocation!.any((element) => element.droppedAt == null)
                      ) {
                    for (int i = 0; i < servicesListData!.multiDropLocation!.length; i++) {
                      if (servicesListData!.multiDropLocation![i].droppedAt == null) {
                        await dropOupUpdate(rideId: '${servicesListData!.id}', dropIndex: '${servicesListData!.multiDropLocation![i].drop}').then(
                          (v) {
                            servicesListData!.multiDropLocation![i].droppedAt = DateTime.now().toString();
                            if (v != null && v['message'] != null) {
                              toast(v['message'].toString());
                            }
                          },
                        );
                        getCurrentRequest();
                        break;
                      }
                    }
                    setMapPins();
                    // showDropLocationsDialog(context);
                  } else {
                    showConfirmDialogCustom(primaryColor: primaryColor, dialogType: DialogType.ACCEPT, title: language.finishMsg, context, positiveText: language.yes, negativeText: language.no, onAccept: (v) {
                      appStore.setLoading(true);
                      getUserLocation().then((value2) async {
                        // totalDistance = calculateDistance(double.parse(servicesListData!.startLatitude.validate()), double.parse(servicesListData!.startLongitude.validate()), driverLocation!.latitude, driverLocation!.longitude);
                        await completeRideRequest();
                      });
                    });
                  }
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget addressDisplayWidget({String? startAddress, String? endAddress, required LatLng startLatLong, required LatLng endLatLong, bool? isMultiple}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.near_me, color: Colors.green, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(startAddress ?? ''.validate(), style: primaryTextStyle(size: 14), maxLines: 2)),
            mapRedirectionWidget(latLong: LatLng(startLatLong.latitude.toDouble(), startLatLong.longitude.toDouble()))
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
            Expanded(child: Text(endAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2)),
            SizedBox(width: 8),
            mapRedirectionWidget(latLong: LatLng(endLatLong.latitude.toDouble(), endLatLong.longitude.toDouble()))
          ],
        ),
        if (servicesListData != null && servicesListData!.multiDropLocation != null && servicesListData!.multiDropLocation!.isNotEmpty)
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
        if (servicesListData != null && servicesListData!.multiDropLocation != null && servicesListData!.multiDropLocation!.isNotEmpty)
          AppButtonWidget(
            textColor: primaryColor,
            color: Colors.white,
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
              showOnlyDropLocationsDialog(context: context, multiDropData: servicesListData!.multiDropLocation!);
            },
          )
      ],
    );
  }

  Widget emptyWalletAlertDialog() {
    return AlertDialog(
      content: Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(walletGIF, height: 150, fit: BoxFit.contain),
            SizedBox(height: 8),
            Text(language.lessWalletAmountMsg, style: primaryTextStyle(), textAlign: TextAlign.justify),
            SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: AppButtonWidget(
                    padding: EdgeInsets.zero,
                    color: Colors.red,
                    text: language.no,
                    textColor: Colors.white,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: AppButtonWidget(
                    padding: EdgeInsets.zero,
                    text: language.yes,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, WalletScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  _bookingForView() {
    if (servicesListData != null && servicesListData!.otherRiderData != null) {
      return Rideforwidget(name: servicesListData!.otherRiderData!.name.validate(), contact: servicesListData!.otherRiderData!.conatctNumber.validate());
    }
    return SizedBox();
  }

  void rejectBid() async {
    Map req = {"id": "${servicesListData!.id}", "driver_id": sharedPref.getInt(USER_ID), "is_bid_accept": "2"};
    await responseBidListing(req).then((value) async {
      setMapPins();
      toast(value.message.toString());
    });
    ;
  }

  Future<void> cancelRequest(String? reason) async {
    Map req = {
      "id": servicesListData!.id,
      "cancel_by": DRIVER,
      "status": CANCELED,
      "reason": reason,
    };
    await rideRequestUpdate(request: req, rideId: servicesListData!.id).then((value) async {
      toast(value.message);
      chatMessageService.exportChat(rideId: "", senderId: sharedPref.getString(UID).validate(), receiverId: riderData!.uid.validate(), onlyDelete: true);
      setMapPins();
    }).catchError((error) {
      setMapPins();
      try {
        chatMessageService.exportChat(rideId: "", senderId: sharedPref.getString(UID).validate(), receiverId: riderData!.uid.validate(), onlyDelete: true);
      } catch (e) {
        throw e;
      }
      log(error.toString());
    });
  }

  void checkRideCancel() async {
    if (rideCancelDetected) return;
    rideCancelDetected = true;
    appStore.setLoading(true);
    sharedPref.remove(ON_RIDE_MODEL);
    sharedPref.remove(IS_TIME2);
    await rideDetail(rideId: servicesListData!.id).then((value) {
      appStore.setLoading(false);
      if (value.data!.status == CANCELED && value.data!.cancelBy == RIDER) {
        _polyLines.clear();
        setMapPins();
        _triggerCanceledPopup(reason: value.data!.reason.validate());
      }
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  void _triggerCanceledPopup({required String reason}) {
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
              Expanded(
                  child: Text(
                language.rideCanceledByRider,
                maxLines: 2,
                style: boldTextStyle(),
              )),
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
              Text(
                language.cancelledReason,
                style: secondaryTextStyle(),
              ),
              Text(
                reason,
                style: primaryTextStyle(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget bidAcceptView() {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          servicesListData != null && duration >= 0
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(2 * defaultRadius), topRight: Radius.circular(2 * defaultRadius)),
                  ),
                  child: SingleChildScrollView(
                    // controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            margin: EdgeInsets.only(top: 16),
                            height: 6,
                            width: 60,
                            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                            alignment: Alignment.center,
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Text(language.bid_for_ride, style: primaryTextStyle(size: 18)),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(defaultRadius),
                                    child: commonCachedNetworkImage(servicesListData!.riderProfileImage.validate(), height: 35, width: 35, fit: BoxFit.cover),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${servicesListData!.riderName.capitalizeFirstLetter()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                        SizedBox(height: 4),
                                        Text('${servicesListData!.riderEmail.validate()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: secondaryTextStyle()),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              10.height,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (distance != null && distance != 0)
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                                          child: Image.asset(ic_pickup, height: 30, width: 30, fit: BoxFit.cover),
                                        ),
                                        8.width,
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${distance} ${servicesListData?.distanceUnit ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                            Text('${language.pickupdistance}', style: secondaryTextStyle(size: 16)),
                                          ],
                                        )
                                      ],
                                    ),
                                  Spacer(),
                                  if (servicesListData?.dropoff_distance_in_km != null)
                                    Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('${servicesListData?.dropoff_distance_in_km} ${servicesListData?.distanceUnit ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                            Text('${language.distance}', style: secondaryTextStyle(size: 16)),
                                          ],
                                        ),
                                        8.width,
                                        Container(
                                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                                          child: Image.asset(ic_distance, height: 30, width: 30, fit: BoxFit.cover),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              8.height,
                              DottedLine(
                                direction: Axis.horizontal,
                                lineLength: double.infinity,
                                lineThickness: 1,
                                dashLength: 2,
                                dashColor: primaryColor,
                              ),
                              6.height,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(language.estimateFare, style: secondaryTextStyle(size: 14)),
                                  printAmountWidget(amount: servicesListData?.totalAmount!.toStringAsFixed(digitAfterDecimal) ?? "", size: 14),
                                ],
                              ),
                              5.height,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(language.platformFee, style: secondaryTextStyle(size: 14)),
                                  Row(
                                    children: [Text("-", style: boldTextStyle(color: Colors.red, size: 14)), printAmountWidget(amount: '${platformFee}', color: Colors.red, size: 14)],
                                  ),
                                ],
                              ),
                              5.height,
                              Container(
                                padding: EdgeInsets.all(5),
                                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green),
                                        5.width,
                                        Text(language.youWillGet, style: boldTextStyle(color: Colors.black)),
                                      ],
                                    ),
                                    printAmountWidget(amount: '${youWillGet.toStringAsFixed(digitAfterDecimal)}', color: Colors.green, size: 14)
                                  ],
                                ),
                              ),
                              6.height,
                              DottedLine(
                                direction: Axis.horizontal,
                                lineLength: double.infinity,
                                lineThickness: 1,
                                dashLength: 2,
                                dashColor: primaryColor,
                              ),
                              8.height,
                              addressDisplayWidget(
                                  endLatLong: LatLng(servicesListData!.endLatitude.toDouble(), servicesListData!.endLongitude.toDouble()),
                                  endAddress: servicesListData!.endAddress,
                                  startLatLong: LatLng(servicesListData!.startLatitude.toDouble(), servicesListData!.startLongitude.toDouble()),
                                  startAddress: servicesListData!.startAddress),
                              if (servicesListData != null && servicesListData!.otherRiderData != null)
                                Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 0.7,
                                  height: 8,
                                ),
                              _bookingForView(),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: inkWellWidget(
                                      onTap: () {
                                        reqCheckCounter = 0;
                                        rejectBid();
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(defaultRadius), border: Border.all(color: Colors.red)),
                                        child: Text(language.decline, style: boldTextStyle(color: Colors.red), textAlign: TextAlign.center),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: AppButtonWidget(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      text: language.place_bid,
                                      shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius)),
                                      color: primaryColor,
                                      textStyle: boldTextStyle(color: Colors.white),
                                      onTap: () async {
                                        num x = num.tryParse(servicesListData?.totalAmount!.toString() ?? "") ?? 0.0;
                                        bidAmountController.text = x.toStringAsFixed(digitAfterDecimal).toString();
                                        calculateFees(refreshCall: () {});
                                        // if(commission_type=="fixed"){
                                        //   platformFee=admin_commission;
                                        //
                                        //   youWillGet=x-platformFee;
                                        // }else if(commission_type=="percentage"){
                                        //   platformFee=admin_commission*x/100;
                                        //
                                        //   youWillGet=x-platformFee;
                                        // }
                                        // youWillGet=x-platformFee;
                                        // bidAmountController.text=x.toStringAsFixed(digitAfterDecimal).toString();
                                        await showModalBottomSheet(
                                            context: context,
                                            isDismissible: false,
                                            backgroundColor: Colors.white,
                                            isScrollControlled: true,
                                            builder: (context) {
                                              return StatefulBuilder(builder: (context, stUpdate) {
                                                return Wrap(
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                                      child: SizedBox(
                                                        child: Padding(
                                                          padding: const EdgeInsets.only(left: 0, right: 0, top: 16),
                                                          child: Column(
                                                            children: [
                                                              Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Text(language.place_your_bid, style: boldTextStyle(size: 18)),
                                                                    InkWell(
                                                                      onTap: () {
                                                                        Navigator.pop(context);
                                                                      },
                                                                      child: Icon(Icons.clear),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                height: 16,
                                                              ),
                                                              Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                                child: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        Expanded(
                                                                          child: AppTextField(
                                                                            controller: bidAmountController,
                                                                            textFieldType: TextFieldType.PHONE,
                                                                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                                                                            decoration: inputDecoration(context, label: language.amount),
                                                                            maxLines: 1,
                                                                            minLines: 1,
                                                                            enabled: false,
                                                                            // onChanged: (p0) {
                                                                            //   num x=num.tryParse(bidAmountController.text.toString())??0;
                                                                            //   if(commission_type=="fixed"){
                                                                            //     platformFee=admin_commission;
                                                                            //
                                                                            //     youWillGet=x-platformFee;
                                                                            //     stUpdate(() {});
                                                                            //     if(x<platformFee)return;
                                                                            //   }else if(commission_type=="percentage"){
                                                                            //     platformFee=admin_commission*x/100;
                                                                            //
                                                                            //     youWillGet=x-platformFee;
                                                                            //     stUpdate(() {});
                                                                            //     if(x<platformFee)return;
                                                                            //   }
                                                                            //   stUpdate((){});
                                                                            // },
                                                                            validator: (value) {
                                                                              if (value!.isEmpty) return language.thisFieldRequired;
                                                                              return null;
                                                                            },
                                                                          ),
                                                                        ),
                                                                        IconButton(
                                                                            // onPressed: () {
                                                                            //   try {
                                                                            //     num x = num.tryParse(bidAmountController.text.toString()) ?? 0;
                                                                            //     // num price=x-surge_charge;
                                                                            //     // platformFee=admin_commission*price/100;
                                                                            //     // youWillGet=x-platformFee;
                                                                            //     x -= 10;
                                                                            //     // if (x > surge_charge) {
                                                                            //     //   if (commission_type == "fixed" && x > admin_commission + surge_charge) {
                                                                            //     //     bidAmountController.text = x.toString();
                                                                            //     //     calculateFees(refreshCall: () => stUpdate(() {}));
                                                                            //     //   } else if (commission_type == "percentage" && platformFee > 0) {
                                                                            //     //     bidAmountController.text = x.toString();
                                                                            //     //     calculateFees(refreshCall: () => stUpdate(() {}));
                                                                            //     //   }
                                                                            //     // }
                                                                            //     bidAmountController.text = x.toString();
                                                                            //     calculateFees(refreshCall: () => stUpdate(() {}));
                                                                            //     // stUpdate(() {});
                                                                            //   } catch (e) {}
                                                                            // },
                                                                            onPressed: () {
                                                                              num x = num.tryParse(bidAmountController.text) ?? 0;

                                                                              // Calculate fee BEFORE reducing
                                                                              num tempPlatformFee = 0;
                                                                              if (commission_type == "fixed") {
                                                                                tempPlatformFee = admin_commission;
                                                                              } else if (commission_type == "percentage") {
                                                                                tempPlatformFee = admin_commission * x / 100;
                                                                              }

                                                                              num tempYouWillGet = x - tempPlatformFee;

                                                                              //  Do NOT allow minus
                                                                              if (tempYouWillGet - 10 < 0) {
                                                                                toast(language.bidAmountLesEarning);
                                                                                return;
                                                                              }
                                                                              ;

                                                                              x -= 10;
                                                                              bidAmountController.text = x.toStringAsFixed(2);

                                                                              calculateFees(refreshCall: () => stUpdate(() {}));
                                                                            },
                                                                            icon: Icon(
                                                                              Icons.remove_circle_outline,
                                                                              color: primaryColor,
                                                                              size: 45,
                                                                            )),
                                                                        IconButton(
                                                                            onPressed: () {
                                                                              try {
                                                                                num x = num.tryParse(bidAmountController.text.toString()) ?? 0;
                                                                                x += 10;
                                                                                bidAmountController.text = x.toStringAsFixed(2);
                                                                                calculateFees(refreshCall: () => stUpdate(() {}));
                                                                                // num x=num.tryParse(bidAmountController.text.toString())??0;
                                                                                // x+=10;
                                                                                // if(commission_type=="fixed"){
                                                                                //   platformFee=admin_commission;
                                                                                //
                                                                                //   youWillGet=x-platformFee;
                                                                                //   if(x<platformFee)return toast("${language.enterValidAmount}");
                                                                                // }else if(commission_type=="percentage"){
                                                                                //   platformFee=admin_commission*x/100;
                                                                                //
                                                                                //   youWillGet=x-platformFee;
                                                                                //   if(x<platformFee)return toast("${language.enterValidAmount}");
                                                                                // }
                                                                                // youWillGet=x-platformFee;
                                                                                // bidAmountController.text=x.toStringAsFixed(digitAfterDecimal).toString();
                                                                                // stUpdate(() {});
                                                                              } catch (e) {}
                                                                            },
                                                                            icon: Icon(
                                                                              Icons.add_circle_outline_sharp,
                                                                              color: primaryColor,
                                                                              size: 45,
                                                                            )),
                                                                      ],
                                                                    ),
                                                                    Row(
                                                                      children: [Text("${language.platformFee} : ", style: secondaryTextStyle()), printAmountWidget(amount: platformFee.toStringAsFixed(2).toString(), size: 14)],
                                                                    ),
                                                                    Row(
                                                                      children: [Text("${language.youWillGet}  : ", style: secondaryTextStyle()), printAmountWidget(amount: "${youWillGet.toStringAsFixed(2)}".toString(), size: 14)],
                                                                    ),
                                                                    SizedBox(
                                                                      height: 8,
                                                                    ),
                                                                    AppTextField(
                                                                      controller: bidNoteController,
                                                                      textFieldType: TextFieldType.ADDRESS,
                                                                      keyboardType: TextInputType.multiline,
                                                                      inputFormatters: [],
                                                                      decoration: inputDecoration(context, label: language.note_optional),
                                                                      // maxLines: 6,
                                                                      // minLines: 2,
                                                                      validator: (value) {
                                                                        if (value!.isEmpty) return language.thisFieldRequired;
                                                                        return null;
                                                                      },
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                height: 16,
                                                              ),
                                                              Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                                child: Align(
                                                                  alignment: Alignment.centerRight,
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    mainAxisSize: MainAxisSize.max,
                                                                    children: [
                                                                      Expanded(
                                                                        child: AppButtonWidget(
                                                                          onTap: () async {
                                                                            reqCheckCounter = 0;
                                                                            try {
                                                                              num x = num.tryParse(bidAmountController.text.toString()) ?? 0;
                                                                              if (x > 0) {
                                                                                // if(commission_type=="fixed"){
                                                                                //   platformFee=admin_commission;
                                                                                //   youWillGet=x-platformFee;
                                                                                //   if(x<platformFee)return toast("${language.enterValidAmount}");
                                                                                // }else if(commission_type=="percentage"){
                                                                                //   platformFee=admin_commission*x/100;
                                                                                //   youWillGet=x-platformFee;
                                                                                //   if(x<platformFee)return toast("${language.enterValidAmount}");
                                                                                // }
                                                                                if (youWillGet <= 0) return toast("${language.enterValidAmount}");
                                                                                hideKeyboard(context);
                                                                                Navigator.pop(context);
                                                                                appStore.setLoading(true);
                                                                                int rideId = servicesListData!.id ?? 0;
                                                                                Map req = {"ride_request_id": "${rideId}", "bid_amount": bidAmountController.text, "notes": bidNoteController.text};
                                                                                LDBaseResponse b = await applyBid(request: req);
                                                                                bidData = ModelBidData(
                                                                                  bidAmount: bidAmountController.text,
                                                                                  isBidAccept: 0,
                                                                                  notes: bidNoteController.text,
                                                                                );
                                                                                bidIsProcessing = 1;
                                                                                setState(() {});
                                                                                // getNewRideReq(rideId,refresh:true);
                                                                                // 'on_stream_api_call':0
                                                                                await rideService.updateStatusOfRide(
                                                                                  rideID: rideId,
                                                                                  req: {
                                                                                    'on_rider_stream_api_call': 0,
                                                                                  },
                                                                                );
                                                                                bidAmountController.clear();
                                                                                bidNoteController.clear();
                                                                                appStore.setLoading(false);
                                                                                toast(b.message.toString());
                                                                              } else {
                                                                                toast("${language.enterValidAmount}");
                                                                              }
                                                                            } catch (e, s) {
                                                                              log("Error ::$e stack:::$s");
                                                                              toast(e.toString());
                                                                            }
                                                                          },
                                                                          text: language.confirm,
                                                                          color: primaryColor,
                                                                          textStyle: boldTextStyle(color: Colors.white),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(height: 16),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              });
                                            });
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SizedBox(),
          Observer(builder: (context) {
            return appStore.isLoading ? loaderWidget() : SizedBox();
          })
        ],
      ),
    );
  }

  Widget bidProcessView() {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          servicesListData != null
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(2 * defaultRadius), topRight: Radius.circular(2 * defaultRadius)),
                  ),
                  child: SingleChildScrollView(
                    // controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            margin: EdgeInsets.only(top: 16),
                            height: 6,
                            width: 60,
                            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                            alignment: Alignment.center,
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(language.bid_under_review, style: primaryTextStyle(size: 18, weight: FontWeight.w700)),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(language.bid_under_review_note, style: secondaryTextStyle()),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Divider(),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(defaultRadius),
                                child: commonCachedNetworkImage(servicesListData!.riderProfileImage.validate(), height: 35, width: 35, fit: BoxFit.cover),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${servicesListData!.riderName.capitalizeFirstLetter()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                    SizedBox(height: 4),
                                    Text('${servicesListData!.riderEmail.validate()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: secondaryTextStyle()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: addressDisplayWidget(
                              endLatLong: LatLng(servicesListData!.endLatitude.toDouble(), servicesListData!.endLongitude.toDouble()),
                              endAddress: servicesListData!.endAddress,
                              startLatLong: LatLng(servicesListData!.startLatitude.toDouble(), servicesListData!.startLongitude.toDouble()),
                              startAddress: servicesListData!.startAddress),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("${language.amount}: ", style: primaryTextStyle(size: 16, weight: FontWeight.w400)),
                              printAmountWidget(amount: bidData!.bidAmount.toString()),
                            ],
                          ),
                        ),
                        if (bidData!.notes != null && bidData!.notes!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(bidData!.notes.toString(), style: secondaryTextStyle()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (bidData!.notes != null && bidData!.notes!.isNotEmpty) SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: AppButtonWidget(
                              width: MediaQuery.of(context).size.width,
                              text: language.cancel_my_bid,
                              textColor: primaryColor,
                              color: Colors.white,
                              shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                              onTap: () {
                                rejectBid();
                              }),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                )
              : SizedBox(),
          Observer(builder: (context) {
            return appStore.isLoading ? loaderWidget() : SizedBox();
          })
        ],
      ),
    );
  }

  void calculateDriverEarning(RiderModel riderModel) {
    num total = riderModel.totalAmount ?? 0;
    num adminCommission = admin_commission ?? 0;

    if (commission_type == "fixed") {
      platformFee = adminCommission;
      youWillGet = total - platformFee;
    } else if (commission_type == "percentage") {
      platformFee = (adminCommission * total) / 100;
      youWillGet = total - platformFee;
    }
  }

  void calculateFees({var refreshCall}) {
    num x = num.tryParse(bidAmountController.text.toString()) ?? 0;
    if (commission_type == "fixed") {
      platformFee = admin_commission;
      youWillGet = x - platformFee;
      refreshCall();
      if (x < platformFee) return;
    } else if (commission_type == "percentage") {
      if (x < surge_charge) {
        bidAmountController.text = (surge_charge + 10).toString();
      }
      num price = x;
      platformFee = admin_commission * price / 100;
      youWillGet = x - platformFee;
      refreshCall();
      if (x < platformFee) return;
    }
    youWillGet = x - platformFee;
    refreshCall();
  }

  Widget buildFloatingWidget() {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        height: 56,
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 2, spreadRadius: 1)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            lt.Lottie.asset(
              messageDetect,
              height: 30,
              width: 30,
              fit: BoxFit.cover,
            ),
            SizedBox(width: 8),
            Text(
              '${language.upcomingRideStartsIn} ${getRemainingTime(schedule_ride_request[0].schedule_datetime!)}',
              style: boldTextStyle(size: 12),
            ),
          ],
        ),
      ),
    );
  }

  String getRemainingTime(String apiTime) {
    if (apiTime.isEmpty) return '';

    DateTime scheduleTime = parseScheduleTime(apiTime);
    DateTime now = DateTime.now();

    Duration diff = scheduleTime.difference(now);

    if (diff.isNegative || diff.inSeconds <= 0) {
      return language.startingNow;
    }

    int days = diff.inDays; // defined here
    int hours = diff.inHours % 24;
    int minutes = diff.inMinutes % 60;

    if (days > 0) {
      return "$days day${days > 1 ? 's' : ''} $hours hr remaining";
    } else if (hours > 0) {
      return "$hours hr $minutes min remaining";
    } else {
      return "$minutes min remaining";
    }
  }

  DateTime parseScheduleTime(String apiTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').parseUtc(apiTime).toLocal();
  }

  static Future<void> startAlertLoop() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    try {
      await _player.play(AssetSource('sounds/rideringtone.mp3'));
    } catch (e, s) {
      print("---->>>>>>>>>>${e.toString()} ${s.toString()}");
    }
  }

  static Future<void> stopAlertLoop() async {
    try {
      await _player.stop();
    } catch (e, s) {
      print("---->>>>>>>>>>${e.toString()} ${s.toString()}");
    }
  }
}

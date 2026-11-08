import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:pinput/pinput.dart';
import 'package:drop/driver/Services/RideService.dart';
import 'package:drop/driver/components/AlertScreen.dart';
import 'package:drop/driver/components/CancelOrderDialog.dart';
import 'package:drop/driver/components/ExtraChargesWidget.dart';
import 'package:drop/driver/main.dart';
import 'package:drop/driver/model/CurrentRequestModel.dart';
import 'package:drop/driver/model/ExtraChargeRequestModel.dart';
import 'package:drop/driver/model/UserDetailModel.dart';
import 'package:drop/driver/network/RestApis.dart';
import 'package:drop/driver/screens/ChatScreen.dart';
import 'package:drop/driver/screens/DashboardScreen.dart';
import 'package:drop/driver/screens/DetailScreen.dart';
import 'package:drop/driver/screens/ReviewScreen.dart';
import 'package:drop/driver/utils/Colors.dart';
import 'package:drop/driver/utils/Common.dart';
import 'package:drop/driver/utils/Constants.dart';
import 'package:drop/driver/utils/Extensions/extension.dart';
import 'package:drop/driver/utils/Extensions/int_extensions.dart';
import 'package:drop/driver/utils/Images.dart';
import 'package:url_launcher/url_launcher.dart';
import 'FlightTrackingPage.dart';

class ScheduleRideListScreen extends StatefulWidget {
  ScheduleRideListScreen({
    super.key,
  });

  @override
  State<ScheduleRideListScreen> createState() => _ScheduleRideListScreenState();
}

class _ScheduleRideListScreenState extends State<ScheduleRideListScreen> {
  List<OnRideRequest> schedule_ride_request = [];
  LatLng? driverLocation;
  late BitmapDescriptor driverIcon;
  late BitmapDescriptor destinationIcon;
  late BitmapDescriptor sourceIcon;
  final otpController = TextEditingController();
  String endLocationAddress = '';
  double totalDistance = 0.0;
  String? otpCheck;
  RideService rideService = RideService();
  int rideHasBid = 0;
  bool paymentPressed = false;

  num youWillGet = 0;
  num admin_commission = 0;
  num platformFee = 0;
  double distance = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  getCurrentRequest({OnRideRequest? servicesListData}) async {
    appStore.setLoading(true);
    await getCurrentRideRequest().then((value) {
      appStore.setLoading(false);
      schedule_ride_request = value.schedule_ride_request ?? [];
      for (var ride in schedule_ride_request) {
        listenForNewDistance(ride.id!);
      }
      setState(() {});
    }).catchError((error, stack) {
      appStore.setLoading(false);
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
        if (!mounted) return;
        setState(() {});
      }
    });
  }

  void init() async {
    if (sharedPref.getDouble(LATITUDE) != null && sharedPref.getDouble(LONGITUDE) != null) {
      driverLocation = LatLng(sharedPref.getDouble(LATITUDE)!, sharedPref.getDouble(LONGITUDE)!);
    }
    await checkPermission();
    LiveStream().on(CHANGE_LANGUAGE, (p0) {
      setState(() {});
    });
    getCurrentRequest();
  }

  Future<void> rideRequest({OnRideRequest? servicesListData, String? status}) async {
    appStore.setLoading(true);
    Map req = {
      "id": servicesListData!.id,
      "status": status,
    };
    await rideRequestUpdate(request: req, rideId: servicesListData.id).then((value) async {
      appStore.setLoading(false);

      rideService.updateStatusOfRide(rideID: servicesListData.id, req: {'on_rider_stream_api_call': 0}).catchError((e) {
        getCurrentRequest().then((value) async {});
      });

      getCurrentRequest().then((value) async {});
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  void calculateDriverEarning(OnRideRequest data) {
    num total = data.totalAmount ?? 0;
    num adminCommission = data.adminCommission ?? 0;

    if (data.commissionType == "fixed") {
      platformFee = adminCommission;
      youWillGet = total - platformFee;
    } else if (data.commissionType == "percentage") {
      platformFee = (adminCommission * total) / 100;
      youWillGet = total - platformFee;
    }
  }

  Future<void> completeRideRequest(OnRideRequest? servicesListData) async {
    appStore.setLoading(true);

    Map req = {
      "id": servicesListData?.id,
      "service_id": servicesListData?.serviceId,
      "start_latitude": servicesListData?.startLatitude,
      "start_longitude": servicesListData?.startLongitude,
      "end_latitude": driverLocation?.latitude,
      "end_longitude": driverLocation?.longitude,
      "end_address": endLocationAddress,
      // "distance": totalDistance,
      if (servicesListData != null && servicesListData.extraCharges != null && servicesListData.extraCharges!.isNotEmpty) "extra_charges": servicesListData.extraCharges,
      if (servicesListData != null && servicesListData.extraCharges != null && servicesListData.extraCharges!.isNotEmpty) "extra_charges_amount": servicesListData.extraChargeAmount,
    };
    log(req);
    await completeRide(request: req).then((value) async {
      chatMessageService.exportChat(rideId: servicesListData?.id.toString() ?? "", senderId: sharedPref.getString(UID).validate(), receiverId: servicesListData?.riderId.toString() ?? '');
      try {
        await rideService.updateStatusOfRide(rideID: servicesListData?.id, req: {'on_rider_stream_api_call': 0});
      } catch (e) {}
      // ignore:deprecated_member_use
      sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), Platform.isIOS ? SourceIOSIcon : SourceIcon);
      appStore.setLoading(false);
      getCurrentRequest(servicesListData: servicesListData);
    }).catchError((error) {
      if (servicesListData != null) {
        chatMessageService.exportChat(rideId: servicesListData.id.toString(), senderId: sharedPref.getString(UID).validate(), receiverId: servicesListData.riderId.toString());
      }
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> getUserLocation() async {
    Position b = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    driverLocation = LatLng(b.latitude, b.longitude);
    List<Placemark> placemarks = await placemarkFromCoordinates(driverLocation?.latitude ?? 0.0, driverLocation?.longitude ?? 0.0);
    Placemark place = placemarks[0];
    endLocationAddress = '${place.street},${place.subLocality},${place.thoroughfare},${place.locality}';
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          return true;
        } else {
          launchScreen(getContext, DashboardScreen(), isNewTask: true);
          return false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(language.schedule_list_title, style: boldTextStyle(color: appTextPrimaryColorWhite)),
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                init();
              },
              child: ListView.builder(
                itemCount: schedule_ride_request.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  var data = schedule_ride_request[index];
                  calculateDriverEarning(data);
                  // listenForNewDistance(data.id!);
                  return GestureDetector(
                    onTap: () {},
                    child: Container(
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
                                            "${language.rideId}: ${data.id}",
                                            style: primaryTextStyle(size: 12, weight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                          decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(8)),
                                          child: Text(
                                            "${statusName(status: data.status.toString())}",
                                            style: primaryTextStyle(size: 12, weight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    5.height,
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(defaultRadius),
                                          child: commonCachedNetworkImage(data.riderProfileImage, height: 38, width: 38, fit: BoxFit.cover),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${data.riderName.capitalizeFirstLetter()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                              SizedBox(height: 4),
                                              Text('${data.riderEmail.validate()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: secondaryTextStyle()),
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
                                                  content: AlertScreen(rideId: data.id, regionId: data.regionId),
                                                );
                                              },
                                            );
                                          },
                                          child: chatCallWidget(Icons.sos),
                                        ),
                                        SizedBox(width: 8),
                                        inkWellWidget(
                                          onTap: () {
                                            launchUrl(Uri.parse('tel:${data.riderContactNumber}'), mode: LaunchMode.externalApplication);
                                          },
                                          child: chatCallWidget(Icons.call),
                                        ),
                                        SizedBox(width: 8),
                                        inkWellWidget(
                                          onTap: () {
                                            if (data.riderId != null) {
                                              getUserDetail(userId: data.riderId).then(
                                                (value) {
                                                  launchScreen(context, ChatScreen(userData: value.data, ride_id: data.id!), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                                                },
                                              );
                                            }
                                          },
                                          child: chatCallWidget(
                                            Icons.chat_bubble_outline,
                                          ),
                                        ),
                                        if (appStore.flightTracking == "1" && data.trip_type.toString().toLowerCase().contains('airport')) SizedBox(width: 8),
                                        if (appStore.flightTracking == "1" && data.trip_type.toString().toLowerCase().contains('airport'))
                                          inkWellWidget(
                                            onTap: () {
                                              showDialog(
                                                barrierDismissible: false,
                                                context: context,
                                                builder: (context) {
                                                  return Theme(
                                                    data: Theme.of(context).copyWith(
                                                      dialogTheme: DialogThemeData(shape: dialogShape()), // Optional
                                                      colorScheme: Theme.of(context).colorScheme.copyWith(
                                                            primary: primaryColor, // Your primary color here
                                                          ),
                                                      textTheme: TextTheme(
                                                        titleLarge: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                                        bodyMedium: TextStyle(color: Colors.black87),
                                                      ),
                                                    ),
                                                    child: AlertDialog(
                                                      title: Text(
                                                        '${language.flightDetails}',
                                                        style: primaryTextStyle(color: Colors.black),
                                                      ),
                                                      content: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          _detailRow('${language.flightNumber}', "${data.flight_number}").visible(!(data.flight_number.isEmptyOrNull)),
                                                          _detailRow('${language.terminalAddress}', "${data.pickup_point}").visible(!(data.pickup_point.isEmptyOrNull)),
                                                          _detailRow('${language.preferredPickupTime}', "${data.preferred_pickup_time}").visible(!(data.preferred_pickup_time.isEmptyOrNull)),
                                                          _detailRow('${language.preferredDropTime}', "${data.preferred_dropoff_time}").visible(!(data.preferred_dropoff_time.isEmptyOrNull)),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: Text('${language.cancel}'),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            launchScreen(context, FlightTrackingScreen(flightNumber: data.flight_number ?? ''), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: false);
                                                          },
                                                          child: Text('${language.track}'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                            child: chatCallWidget(
                                              Icons.flight,
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
                                                  Text('${distance} ${data.distanceUnit}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
                                                  Text('${language.pickupdistance}', style: secondaryTextStyle(size: 16)),
                                                ],
                                              )
                                            ],
                                          ),
                                        Spacer(),
                                        if (data.dropoff_distance_in_km != null && data.distance != null)
                                          Row(
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text('${data.dropoff_distance_in_km!.toInt() == 0 ? data.distance.toString() : data.dropoff_distance_in_km.toString()} ${data.distanceUnit}', maxLines: 1, overflow: TextOverflow.ellipsis, style: boldTextStyle(size: 14)),
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
                                    if (!(data.schedule_datetime.isEmptyOrNull) && data.isSchedule == 1) ...[
                                      6.height,
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "${language.schedule_at}: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.parse(data.schedule_datetime.toString() + "Z").toLocal())}",
                                              style: secondaryTextStyle(size: 13, color: Colors.white, weight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    8.height,
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "${language.paymentDetails} : ${data.paymentStatus.toString().toUpperCase()}",
                                              style: primaryTextStyle(size: 12, weight: FontWeight.bold, color: data.paymentStatus == PAYMENT_PAID ? Colors.green : Colors.red /* Colors.white*/),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Divider(),
                          // buildInfoTile(
                          //   icon: Icons.wallet,
                          //   title_widget: printAmountWidget(amount: data.totalAmount!.toStringAsFixed(digitAfterDecimal), size: 14),
                          //   subtitle: "${language.estAmount}",
                          // ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(language.estimateFare, style: secondaryTextStyle(size: 14)),
                              printAmountWidget(amount: data.totalAmount!.toStringAsFixed(digitAfterDecimal), size: 14),
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
                          Divider(),
                          if (data.trip_type == 'airport_pickup' || data.trip_type == 'airport_drop' || data.trip_type == 'zone_to_airport' || data.trip_type == 'airport_to_zone') ...[
                            airportPickupSection(
                              flightNumber: data.flight_number!,
                              terminal: data.pickup_point!,
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
                                  Expanded(child: Text(data.startAddress.validate(), style: primaryTextStyle(size: 14), maxLines: 2)),
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
                                  Expanded(child: Text(data.endAddress.validate(), style: primaryTextStyle(size: 14), maxLines: 2)),
                                ],
                              ),
                              if (data.multiDropLocation != null && data.multiDropLocation!.isNotEmpty)
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
                              if (data.multiDropLocation != null && data.multiDropLocation!.isNotEmpty)
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
                                    showOnlyDropLocationsRiderDialog(context, data.multiDropLocation!);
                                  },
                                ),
                              if (data.status == IN_PROGRESS)
                                if (data.extraChargeAmount != null) ...[
                                  SizedBox(height: 8),
                                  Observer(builder: (context) {
                                    return Visibility(
                                      visible: int.parse(data.extraChargeAmount!.toString()) != 0,
                                      child: inkWellWidget(
                                        onTap: () async {
                                          List<ExtraChargeRequestModel>? extraChargeListData = await showModalBottomSheet(
                                            isScrollControlled: true,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius))),
                                            context: context,
                                            builder: (_) {
                                              return Padding(
                                                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                                child: ExtraChargesWidget(data: data.extraCharges),
                                              );
                                            },
                                          );
                                          if (extraChargeListData != null) {
                                            data.extraChargeAmount = 0;
                                            extraChargeListData.forEach((element) {
                                              data.extraChargeAmount = data.extraChargeAmount! + element.value!;
                                              data.extraCharges = extraChargeListData;
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
                                                    if (data.extraChargeAmount != 0)
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text('${language.extraCharges} : ', style: secondaryTextStyle(color: Colors.green)),
                                                          printAmountWidget(amount: '${data.extraChargeAmount!.toStringAsFixed(digitAfterDecimal)}', size: 14, color: Colors.green, weight: FontWeight.normal)
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
                                ],
                              5.height,
                              buttonWidget(data),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
              Icon(Icons.flight_takeoff, color: Colors.black87, size: 22),
              SizedBox(width: 8),
              Text(
                "Airport Pickup",
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
                "${language.flight}:",
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
        ],
      ),
    );
  }

  Future<void> cancelRequest(String reason, {int? ride_id}) async {
    Map req = {
      "id": ride_id,
      "cancel_by": DRIVER,
      "status": CANCELED,
      "reason": reason,
    };
    appStore.setLoading(true);
    await rideRequestUpdate(request: req, rideId: ride_id).then((value) async {
      appStore.setLoading(false);
      toast(value.message);
      schedule_ride_request.removeWhere(
        (element) => element.id == ride_id,
      );
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
    });
    init();
  }

  Widget buttonWidget(OnRideRequest? servicesListData) {
    return Row(
      children: [
        // if(data.status==IN_PROGRESS || data.status==ACCEPTED)
        if (servicesListData?.status != IN_PROGRESS && /*servicesListData != ACCEPTED ||*/
            servicesListData?.status != COMPLETED)
          Expanded(
            flex: 0,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: AppButtonWidget(
                  text: language.cancel,
                  textColor: primaryColor,
                  color: Colors.white,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                  onTap: () {
                    showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        isDismissible: false,
                        builder: (context) {
                          return CancelOrderDialog(
                              service_type: servicesListData?.type ?? '',
                              onCancel: (reason) async {
                                Navigator.pop(context);
                                appStore.setLoading(true);
                                await cancelRequest(reason, ride_id: servicesListData?.id);
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
                  text: language.extraFees,
                  textColor: primaryColor,
                  color: Colors.white,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                  onTap: () async {
                    List<ExtraChargeRequestModel>? extraChargeListData = await showModalBottomSheet(
                      isScrollControlled: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius))),
                      context: context,
                      builder: (_) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                          child: ExtraChargesWidget(data: servicesListData.extraCharges),
                        );
                      },
                    );
                    if (extraChargeListData != null) {
                      servicesListData.extraChargeAmount = 0;
                      extraChargeListData.forEach((element) {
                        servicesListData.extraChargeAmount = servicesListData.extraChargeAmount! + element.value!;
                        servicesListData.extraCharges = extraChargeListData;
                      });
                    }
                  }),
            ),
          ),
        if (servicesListData.status != COMPLETED)
          Expanded(
            flex: 1,
            child: AppButtonWidget(
              text: buttonText(status: servicesListData.status),
              color: primaryColor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ImageIcon(
                    AssetImage(statusTypeIconForButton(type: servicesListData.status == IN_PROGRESS ? ARRIVED : servicesListData.status.validate())),
                    color: Colors.white,
                    size: 18,
                  ),
                  4.width,
                  Text(
                      // servicesListData.status == ARRIVED && servicesListData.paymentStatus != PAYMENT_PAID
                      //     ? "${language.startRide}"
                      //     : servicesListData.status == ARRIVED
                      //         ? "${language.collectOrder}"
                      //         : servicesListData.status == IN_PROGRESS
                      //             ? "${language.completed}"
                      //             : servicesListData.status == IN_PROGRESS && servicesListData.multiDropLocation != null && servicesListData.multiDropLocation!.isNotEmpty && servicesListData.multiDropLocation!.where((element) => element.droppedAt == null).length > 1
                      //                 ? language.updateDrop
                      //                 : buttonText(status: servicesListData.status, paymentStatus: servicesListData.paymentStatus, paymentType: servicesListData.paymentType),
                      servicesListData.status == IN_PROGRESS && servicesListData.multiDropLocation != null && servicesListData.multiDropLocation!.isNotEmpty && servicesListData.multiDropLocation!.where((element) => element.droppedAt == null).length > 1
                          ? language.updateDrop
                          : buttonText(status: servicesListData.status, paymentStatus: servicesListData.paymentStatus, paymentType: servicesListData.paymentType),
                      style: boldTextStyle(color: Colors.white)),
                ],
              ),
              textStyle: boldTextStyle(color: Colors.white),
              onTap: () async {
                DateTime date1 = DateTime.parse(servicesListData.schedule_datetime.toString() + "Z").toLocal();
                DateTime date2 = DateTime.now();
                Duration diff = date1.difference(date2);
                if (diff.inMinutes <= 60) {
                  if (await checkPermission()) {
                    if (servicesListData.status == ACCEPTED || servicesListData.status == BID_ACCEPTED) {
                      showConfirmDialogCustom(primaryColor: primaryColor, positiveText: language.yes, negativeText: language.no, dialogType: DialogType.CONFIRMATION, title: language.areYouSureYouWantToArriving, context, onAccept: (v) {
                        rideRequest(servicesListData: servicesListData, status: ARRIVING);
                      });
                    } else if (servicesListData.status == ARRIVING) {
                      showConfirmDialogCustom(primaryColor: primaryColor, positiveText: language.yes, negativeText: language.no, dialogType: DialogType.CONFIRMATION, title: language.areYouSureYouWantToArrived, context, onAccept: (v) {
                        rideRequest(servicesListData: servicesListData, status: ARRIVED);
                      });
                    } else if (servicesListData.status == ARRIVED) {
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
                                    if (otpCheck == null || otpCheck != servicesListData.otp) {
                                      return toast(language.pleaseEnterValidOtp);
                                    } else {
                                      Navigator.pop(context);
                                      rideRequest(servicesListData: servicesListData, status: IN_PROGRESS);
                                    }
                                  },
                                )
                              ],
                            ),
                          );
                        },
                      );
                    } else if (servicesListData.status == IN_PROGRESS) {
                      if (servicesListData.multiDropLocation != null && servicesListData.multiDropLocation!.isNotEmpty && servicesListData.multiDropLocation!.where((element) => element.droppedAt == null).length > 1) {
                        for (int i = 0; i < servicesListData.multiDropLocation!.length; i++) {
                          if (servicesListData.multiDropLocation![i].droppedAt == null) {
                            await dropOupUpdate(rideId: '${servicesListData.id}', dropIndex: '${servicesListData.multiDropLocation![i].drop}').then(
                              (v) {
                                servicesListData.multiDropLocation![i].droppedAt = DateTime.now().toString();
                                if (v != null && v['message'] != null) {
                                  toast(v['message'].toString());
                                }
                              },
                            );
                            getCurrentRequest(servicesListData: servicesListData);
                            break;
                          }
                        }
                        // setMapPins();
                      } else {
                        showConfirmDialogCustom(primaryColor: primaryColor, dialogType: DialogType.ACCEPT, title: language.finishMsg, context, positiveText: language.yes, negativeText: language.no, onAccept: (v) {
                          appStore.setLoading(true);
                          getUserLocation().then((value2) async {
                            await completeRideRequest(servicesListData);
                          });
                        });
                      }
                    } else if (servicesListData.status == COMPLETED && servicesListData.paymentStatus != PAYMENT_PAID) {
                      if (servicesListData.paymentType == CASH) {
                        showConfirmDialogCustom(primaryColor: primaryColor, positiveText: language.yes, negativeText: language.no, dialogType: DialogType.CONFIRMATION, title: language.areYouSureCollectThisPayment, context, onAccept: (v) async {
                          if (paymentPressed == true) return;
                          paymentPressed = true;
                          appStore.setLoading(true);
                          Map req = {
                            "id": servicesListData.paymentId,
                            "rider_id": servicesListData.riderId,
                            "ride_request_id": servicesListData.id,
                            "datetime": DateTime.now().toString(),
                            "total_amount": servicesListData.totalAmount,
                            "payment_type": servicesListData.paymentType,
                            "txn_id": "",
                            "payment_status": PAYMENT_PAID,
                            "transaction_detail": ""
                          };
                          await savePayment(req).then((value) async {
                            appStore.setLoading(false);
                            getCurrentRequest();
                            showDialog(
                              context: context,
                              builder: (context) => Wrap(
                                alignment: WrapAlignment.center,
                                runAlignment: WrapAlignment.center,
                                children: [
                                  Container(
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
                                ],
                              ),
                            );
                            Future.delayed(
                              Duration(seconds: 3),
                              () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                            );
                          }).catchError((error) {
                            appStore.setLoading(false);
                            log(error.toString());
                          });
                        });
                      } else {
                        toast(language.waitingForDriverConformation);
                      }
                    }
                  }
                } else {
                  return toast("You can update the ride status only on the scheduled time.");
                }
              },
            ),
          ),
        if (servicesListData.status == COMPLETED && servicesListData.paymentStatus != PAYMENT_PAID)
          Expanded(
            child: AppButtonWidget(
                text: servicesListData.isDriverRated == 1
                    ? servicesListData.paymentType == CASH
                        ? language.cashCollected
                        : language.waitingForDriverConformation
                    : appStore.isShowRiderReview == '1'
                        // ? "${language.addReviews}"
                        ? language.viewDetails
                        : servicesListData.paymentType == CASH
                            ? language.cashCollected
                            : language.waitingForDriverConformation,
                textColor: primaryColor,
                color: Colors.white,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius), side: BorderSide(color: primaryColor)),
                onTap: () async {
                  if (servicesListData.isDriverRated == 0 && appStore.isShowRiderReview == '1') {
                    await launchScreen(
                      getContext,
                      ReviewScreen(
                        schedule_ride: true,
                        rideId: servicesListData.id!,
                        currentData: CurrentRequestModel(
                          rider: UserData(
                            profileImage: servicesListData.riderProfileImage,
                            firstName: servicesListData.riderName,
                            email: servicesListData.riderEmail,
                          ),
                        ),
                      ),
                      pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
                    );
                    init();
                    return;
                  } else {
                    if (servicesListData.isDriverRated == 0 && appStore.isShowRiderReview == '0') {
                      appStore.setLoading(true);
                      Map req = {
                        "ride_request_id": servicesListData.id!,
                        "rating": 0,
                        "comment": '',
                      };
                      await ratingReview(request: req).then((value2) async {
                        appStore.setLoading(false);
                      }).catchError((error, s) {
                        appStore.setLoading(false);
                      });
                    }
                    launchScreen(getContext, DetailScreen(rideId: servicesListData.id), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                    return;
                  }
                }),
          ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

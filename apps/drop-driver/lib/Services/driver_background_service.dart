import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mighty_core/core_mighty/mighty_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_driver/main.dart';
import 'package:taxi_driver/network/RestApis.dart';

import '../utils/Constants.dart';

@pragma('vm:entry-point')
class DriverBackgroundService {
  // Request all necessary permissions before starting service
  static Future<bool> requestPermissions() async {
    // Request notification permission (Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // Request background location (needed for foreground service with location)
    if (permission == LocationPermission.whileInUse) {
      // Show explanation to user before requesting background location
      await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  static Future<void> startService() async {
    // Request permissions first
    bool hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      print("Required permissions not granted");
      return;
    }

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: 'trip_tracking',
        initialNotificationTitle: 'Trip in progress',
        initialNotificationContent: 'Location is being shared',
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(),
    );

    service.startService();
  }

  @pragma('vm:entry-point')
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
  }
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    try {
      sharedPref = await SharedPreferences.getInstance();
      MightyCore().init(
        baseUrl: mBaseUrl,
        sharedPref: sharedPref,
        navigatorKey: navigatorKey,
      );
      await appStore.setLoggedIn(true);
      Timer? periodicTimer;
      service.on("stopService").listen((event) {
        periodicTimer?.cancel();
        service.stopSelf();
      });

      periodicTimer = Timer.periodic(
        const Duration(seconds: 30),
            (timer) async {
          await updateLocationAndSend();
        },
      );

      await updateLocationAndSend();
    } catch (e, s) {
      print("BG Service initialization error: $e");
      print(s);
      service.stopSelf();
    }
  }

  static Future<void> updateLocationAndSend() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("BG Service: Location services are disabled.");
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        print("BG Service: Location permission denied.");
        return;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      await sendLocation(position);
    } catch (e) {
      print("BG Service Error: $e");
    }
  }

  static Future<void> sendLocation(Position position) async {
    try {
      print("Sending location: ${position.latitude}, ${position.longitude}");

      Map req = {
        "latitude": position.latitude.toString(),
        "longitude": position.longitude.toString(),
        "currentHeading": '0',
      };

      await updateStatus(req).then((value) {
        print("Location updated successfully");
      }).catchError((error) {
        log("Location update error: $error");
      });
    } catch (e, s) {
      print("API Error: $e");
      print("Stack trace: $s");
    }
  }
}

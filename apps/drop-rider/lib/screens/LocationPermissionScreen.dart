import '../manage_imports.dart';

class LocationPermissionScreen extends StatefulWidget {
  @override
  LocationPermissionScreenState createState() =>
      LocationPermissionScreenState();
}

class LocationPermissionScreenState extends State<LocationPermissionScreen> {
  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    // determinePosition();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: locationScreenKey,
        appBar: AppBar(automaticallyImplyLeading: false),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Lottie.asset(locationAnim,
                    height: 200, width: 200, fit: BoxFit.cover),
                SizedBox(height: 32),
                Text(language.mostReliableMightyRiderApp,
                    style: boldTextStyle(size: 18)),
                SizedBox(height: 16),
                Text(language.toEnjoyYourRideExperiencePleaseAllowPermissions,
                    style: secondaryTextStyle(color: primaryColor),
                    textAlign: TextAlign.center),
                SizedBox(height: 32),
                AppButtonWidget(
                  width: MediaQuery.of(context).size.width,
                  text: language.allow,
                  textStyle: boldTextStyle(color: Colors.white),
                  color: primaryColor,
                  onTap: () async {
                    if (await checkPermission()) {
                      if (Navigator.canPop(
                          navigatorKey.currentState!.overlay!.context)) {
                        // Navigator.pop(navigatorKey.currentState!.overlay!.context);
                      }
                      await Geolocator.getCurrentPosition().then((value) {
                        sharedPref.setDouble(LATITUDE, value.latitude);
                        sharedPref.setDouble(LONGITUDE, value.longitude);
                      });
                      // Navigator.pop(context);
                    }
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

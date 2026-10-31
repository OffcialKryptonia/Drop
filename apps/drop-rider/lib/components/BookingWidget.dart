import '../manage_imports.dart';
import 'package:timezone/timezone.dart' as tz;

class BookingWidget extends StatefulWidget {
  final int? id;
  final String? dt;
  final String? timezone;

  BookingWidget({required this.id, this.dt, this.timezone});

  @override
  BookingWidgetState createState() => BookingWidgetState();
}

class BookingWidgetState extends State<BookingWidget> {
  final int timerMaxSeconds = appStore.rideMinutes != null ? int.parse(appStore.rideMinutes!) * 60 : 5 * 60;

  int currentSeconds = 0;
  int duration = 0;

  DateTime? d2;
  bool called = false;
  bool isCancelled = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    if (sharedPref.getString(IS_TIME) == null) {
      duration = timerMaxSeconds;
      startTimeout();
      sharedPref.setString(
        IS_TIME,
        DateTime.now().toUtc().add(Duration(seconds: timerMaxSeconds)).toString(),
      );
      sharedPref.setString(REMAINING_TIME, timerMaxSeconds.toString());
    } else {
      duration = DateTime.parse(sharedPref.getString(IS_TIME)!).difference(DateTime.now().toUtc()).inSeconds;

      if (duration > 0) {
        startTimeout();
      } else {
        sharedPref.remove(IS_TIME);
        duration = timerMaxSeconds;
        setState(() {});
        startTimeout();
      }
    }
  }

  DateTime parseApiTimeSmart(String apiTime, String? apiTimezone) {
    final normalized = apiTime.replaceAll(" ", "T");
    final parsed = DateTime.tryParse(normalized);

    if (parsed == null) return DateTime.now().toUtc();

    // Timezone provided → use timezone package
    if (apiTimezone != null && apiTimezone.isNotEmpty) {
      try {
        final location = tz.getLocation(apiTimezone);

        final zoned = tz.TZDateTime(
          location,
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );

        return zoned.toUtc();
      } catch (e) {
        log("Timezone parse failed: $e");
      }
    }

    // Timezone NOT provided → treat API time as UTC
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  void startTimeout() {
    if (called) return;
    called = true;

    if (widget.dt != null) {
      print("api timer ${widget.dt} | tz ${widget.timezone}");

      final DateTime d1Utc = parseApiTimeSmart(
        widget.dt.validate(),
        widget.timezone,
      );

      print("timer d1 UTC $d1Utc");

      setState(() {
        d2 = d1Utc.add(Duration(seconds: timerMaxSeconds));
        print("timer d2 UTC $d2");
      });
    }
  }

  Future<void> cancelRequest(String? reason) async {
    Map req = {
      "id": widget.id,
      "cancel_by": RIDER,
      "status": CANCELED,
      "reason": reason,
    };

    await rideRequestUpdate(request: req, rideId: widget.id).then((value) async {
      isPopupOpen = false;
      toast(value.message);
    }).catchError((error) {
      log(error.toString());
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(language.lookingForNearbyDrivers, style: boldTextStyle()),
              if (d2 != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: radius(8),
                  ),
                  child: StreamBuilder(
                    stream: Stream.periodic(Duration(seconds: 1)),
                    builder: (context, snapshot) {
                      if (d2 == null) {
                        return Text("--:--", style: boldTextStyle(color: Colors.white));
                      }

                      // 🔑 Always compare in UTC
                      final now = DateTime.now().toUtc();
                      final diff = d2!.difference(now);

                      if (diff.isNegative && !isCancelled) {
                        isCancelled = true;

                        Future.microtask(() async {
                          Map req = {
                            'status': CANCELED,
                            'cancel_by': AUTO,
                            "reason": "Ride is auto cancelled",
                          };

                          d2 = null;
                          appStore.setLoading(true);

                          try {
                            await rideRequestUpdate(
                              request: req,
                              rideId: widget.id,
                            ).then((v) {
                              isPopupOpen = false;
                              toast(language.noNearByDriverFound);
                              sharedPref.remove(REMAINING_TIME);
                              sharedPref.remove(IS_TIME);
                            });
                          } catch (e) {
                            log(e.toString());
                          } finally {
                            appStore.setLoading(false);
                          }
                        });

                        return Text("--:--", style: boldTextStyle(color: Colors.white));
                      }

                      final minutes = (diff.inSeconds ~/ 60).toString().padLeft(2, "0");
                      final seconds = (diff.inSeconds % 60).toString().padLeft(2, "0");

                      return Text(
                        "$minutes:$seconds",
                        style: boldTextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Lottie.asset(
            bookingAnim,
            height: 100,
            width: MediaQuery.of(context).size.width,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 20),
          Text(
            language.weAreLookingForNearDriversAcceptsYourRide,
            style: primaryTextStyle(),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          AppButtonWidget(
            width: MediaQuery.of(context).size.width,
            text: language.cancel,
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
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

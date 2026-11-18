import '../manage_imports.dart';
import 'dart:async';

import '../service/DriverApplicationApi.dart';

// ignore:must_be_immutable
class TripTypeLocationComponent extends StatefulWidget {
  String trip_type;
  String? addressTitle;
  String? pickupTimeValue;
  var tripDetail;

  TripTypeLocationComponent({required this.trip_type, this.tripDetail, this.addressTitle, this.pickupTimeValue});

  @override
  TripTypeLocationComponentState createState() => TripTypeLocationComponentState();
}

class TripTypeLocationComponentState extends State<TripTypeLocationComponent> {
  TextEditingController sourceLocation = TextEditingController();
  TextEditingController destinationLocation = TextEditingController();
  var sourceId, destinationId;
  var SourceZoneId;

  FocusNode sourceFocus = FocusNode();
  FocusNode desFocus = FocusNode();
  List<TextEditingController> multipleDropPoints = [];
  var multiDropLatLng = {};
  List<FocusNode> multipleDropPointsFocus = [];
  int multiDropFieldPosition = 0;
  bool isDone = true;

  List<Map<String, dynamic>> listAddress = [];
  Timer? _placeSearchTimer;
  int _placeSearchSequence = 0;
  String _activePlaceField = 'source';
  int _activeMultiDropIndex = 0;

  void _onPlaceQueryChanged(String value, {required String field, int index = 0}) {
    _activePlaceField = field;
    if (field == 'multi') { _activeMultiDropIndex = index; multiDropLatLng.remove(index); }
    final request = ++_placeSearchSequence;
    _placeSearchTimer?.cancel();
    if (value.trim().length < 2) { listAddress = []; setState(() {}); return; }
    listAddress = [];
    setState(() {});
    _placeSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final bias = polylineSource;
        final useBias = bias.latitude != 0 || bias.longitude != 0;
        final hits = await DriverApplicationApi.searchPlaces(value, latitude: useBias ? bias.latitude : null, longitude: useBias ? bias.longitude : null);
        if (!mounted || request != _placeSearchSequence) return;
        listAddress = hits;
        setState(() {});
      } catch (error) {
        if (!mounted || request != _placeSearchSequence) return;
        listAddress = [];
        setState(() {});
        log(error);
      }
    });
  }

  void _selectPlace(Map<String, dynamic> place) {
    final lat = (place['lat'] as num?)?.toDouble();
    final lng = (place['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final title = (place['title'] ?? '').toString().trim();
    final subtitle = (place['subtitle'] ?? '').toString().trim();
    final address = subtitle.isEmpty || title.isEmpty ? (title.isEmpty ? subtitle : title) : '$title, $subtitle';
    final point = LatLng(lat, lng);
    if (_activePlaceField == 'source') { sourceLocation.text = address; polylineSource = point; }
    else if (_activePlaceField == 'destination') { destinationLocation.text = address; polylineDestination = point; }
    else if (_activePlaceField == 'multi' && _activeMultiDropIndex < multipleDropPoints.length) {
      multipleDropPoints[_activeMultiDropIndex].text = address;
      multiDropLatLng[_activeMultiDropIndex] = point;
    }
    _placeSearchTimer?.cancel();
    _placeSearchSequence++;
    listAddress = [];
    hideKeyboard(context);
    setState(() {});
  }

  @override
  void dispose() {
    _placeSearchTimer?.cancel();
    sourceLocation.dispose();
    destinationLocation.dispose();
    sourceFocus.dispose();
    desFocus.dispose();
    for (final controller in multipleDropPoints) { controller.dispose(); }
    for (final focus in multipleDropPointsFocus) { focus.dispose(); }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    getCurrantLocation();
  }

  void getCurrantLocation() {
    if (widget.trip_type == tripTypeRegular || widget.trip_type == tripTypeAirportDropoff) {
      polylineSource = LatLng(sharedPref.getDouble(LATITUDE) ?? 0.0, sharedPref.getDouble(LONGITUDE) ?? 0.0);
      sourceLocation.text = widget.addressTitle ?? "";
      setState(() {});
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
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
                  SizedBox(height: 16),
                  Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.only(bottom: 16),
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(defaultRadius)),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.near_me,
                                    color: Colors.green,
                                    shadows: [
                                      BoxShadow(color: Colors.black, blurRadius: 1, offset: Offset(1.5, 1.5), spreadRadius: 5),
                                      BoxShadow(color: Colors.white70, blurRadius: 1, offset: Offset(-1, -1), spreadRadius: 5),
                                    ],
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            widget.trip_type == tripTypeAirportPickup || widget.trip_type == tripTypeAirportToZone
                                                ? '${language.selectAirport}'
                                                : widget.trip_type == tripTypeZoneWise || widget.trip_type == tripTypeZoneToAirport
                                                    ? '${language.selectZone}'
                                                    : '${language.lblWhereAreYou}',
                                            style: secondaryTextStyle()),
                                        130.width,
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: sourceLocation,
                                                focusNode: sourceFocus,
                                                readOnly: widget.trip_type == tripTypeAirportDropoff || widget.trip_type == tripTypeRegular ? false : true,
                                                decoration: searchInputDecoration(hint: language.sourceLocation),
                                                onTap: () async {
                                                  var pickUpDetails;
                                                  if (widget.trip_type == tripTypeAirportPickup || widget.trip_type == tripTypeAirportToZone) {
                                                    pickUpDetails = await launchScreen(context, ChooseAirportOrZoneScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                                                    if (pickUpDetails != null) {
                                                      setState(() {
                                                        sourceId = pickUpDetails['id'];
                                                        sourceLocation.text = pickUpDetails['name'];
                                                        polylineSource = LatLng(double.parse(pickUpDetails['latitude_deg'].toString()), double.parse(pickUpDetails['longitude_deg'].toString()));
                                                      });
                                                    }
                                                  } else if (widget.trip_type == tripTypeZoneWise || widget.trip_type == tripTypeZoneToAirport) {
                                                    pickUpDetails = await launchScreen(
                                                        context,
                                                        ChooseAirportOrZoneScreen(
                                                          zone_selection: true,
                                                        ),
                                                        pageRouteAnimation: PageRouteAnimation.Slide);
                                                    if (pickUpDetails != null) {
                                                      setState(() {
                                                        if (widget.trip_type == tripTypeZoneWise) {
                                                          SourceZoneId = pickUpDetails['id'];
                                                        }
                                                        sourceId = pickUpDetails['id'];
                                                        sourceLocation.text = pickUpDetails['name'];
                                                        polylineSource = LatLng(double.parse(pickUpDetails['latitude'].toString()), double.parse(pickUpDetails['longitude'].toString()));
                                                      });
                                                    }
                                                  }
                                                },
                                                onChanged: (val) => _onPlaceQueryChanged(val, field: 'source'),,
                                              ),
                                            ),
                                            IconButton(
                                              iconSize: 22,
                                              color: primaryColor,
                                              onPressed: () async {
                                                sourceId = null;
                                                SourceZoneId = null;
                                                sourceLocation.clear();

                                                destinationId = null;
                                                destinationLocation.clear();
                                              },
                                              icon: Icon(Icons.cancel_outlined),
                                            ),
                                            if (widget.trip_type == tripTypeRegular || widget.trip_type == tripTypeAirportDropoff)
                                              IconButton.outlined(
                                                iconSize: 18,
                                                color: primaryColor,
                                                onPressed: () async {
                                                  var selectedPlace = await launchScreen(context, GoogleMapScreen(isDestination: true), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                                                  sourceLocation.text = selectedPlace['formatted_address'];
                                                  polylineSource = selectedPlace['position'];
                                                },
                                                icon: Icon(Icons.map_outlined),
                                              )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                ],
                              ),
                              Row(
                                children: [
                                  SizedBox(width: 8),
                                  SizedBox(
                                    height: 46,
                                    child: DottedLine(
                                      direction: Axis.vertical,
                                      lineLength: double.infinity,
                                      lineThickness: 1,
                                      dashLength: 3,
                                      dashColor: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (multipleDropPoints.isEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      shadows: [
                                        BoxShadow(color: Colors.black, blurRadius: 1, offset: Offset(1.5, 1.5), spreadRadius: 5),
                                        BoxShadow(color: Colors.white70, blurRadius: 1, offset: Offset(-1, -1), spreadRadius: 5),
                                      ],
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              widget.trip_type == tripTypeAirportPickup
                                                  ? '${language.lblDropOff}'
                                                  : widget.trip_type == tripTypeZoneWise
                                                      ? '${language.selectZone}'
                                                      : widget.trip_type == tripTypeAirportToZone
                                                          ? '${language.selectZone}'
                                                          : widget.trip_type == tripTypeAirportDropoff || widget.trip_type == tripTypeZoneToAirport
                                                              ? '${language.selectAirport}'
                                                              : '${language.lblDropOff}',
                                              style: secondaryTextStyle()),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  controller: destinationLocation,
                                                  focusNode: desFocus,
                                                  autofocus: false,
                                                  readOnly: widget.trip_type == tripTypeAirportPickup || widget.trip_type == tripTypeRegular ? false : true,
                                                  decoration: searchInputDecoration(hint: language.destinationLocation),
                                                  onTap: () async {
                                                    var dropDetails;
                                                    if (widget.trip_type == tripTypeAirportDropoff || widget.trip_type == tripTypeZoneToAirport) {
                                                      dropDetails = await launchScreen(context, ChooseAirportOrZoneScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                                                      if (dropDetails != null) {
                                                        destinationLocation.text = dropDetails['name'];
                                                        destinationId = dropDetails['id'];
                                                        polylineDestination = LatLng(double.parse(dropDetails['latitude_deg'].toString()), double.parse(dropDetails['longitude_deg'].toString()));
                                                      }
                                                    } else if (widget.trip_type == tripTypeZoneWise || widget.trip_type == tripTypeAirportToZone) {
                                                      if (widget.trip_type == tripTypeZoneWise && sourceId == null) {
                                                        toast('Please first select source location');
                                                        return;
                                                      }
                                                      dropDetails = await launchScreen(
                                                          context,
                                                          ChooseAirportOrZoneScreen(
                                                            zone_selection: true,
                                                            zoneId: widget.trip_type == tripTypeZoneWise ? SourceZoneId : null,
                                                          ),
                                                          pageRouteAnimation: PageRouteAnimation.Slide);
                                                      if (dropDetails != null) {
                                                        destinationId = dropDetails['id'];
                                                        destinationLocation.text = dropDetails['name'];
                                                        polylineDestination = LatLng(double.parse(dropDetails['latitude'].toString()), double.parse(dropDetails['longitude'].toString()));
                                                      }
                                                    }
                                                    setState(() {});
                                                  },
                                                  onChanged: (val) => _onPlaceQueryChanged(val, field: 'destination'),,
                                                ),
                                              ),
                                              IconButton(
                                                iconSize: 22,
                                                color: primaryColor,
                                                onPressed: () async {
                                                  destinationId = null;
                                                  destinationLocation.clear();
                                                },
                                                icon: Icon(Icons.cancel_outlined),
                                              ),
                                              if (widget.trip_type == tripTypeRegular || widget.trip_type == tripTypeAirportPickup)
                                                IconButton.outlined(
                                                  iconSize: 18,
                                                  color: primaryColor,
                                                  onPressed: () async {
                                                    var selectedPlace = await launchScreen(context, GoogleMapScreen(isDestination: true), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                                                    destinationLocation.text = selectedPlace['formatted_address'];
                                                    polylineDestination = selectedPlace['position'];
                                                  },
                                                  icon: Icon(Icons.map_outlined),
                                                )
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                  ],
                                ),
                              if (multipleDropPoints.isNotEmpty) reorderedView(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (appStore.isMultiDrop != null && appStore.isMultiDrop == "1" && widget.tripDetail['trip_type'] == 'regular')
                    TextButton(
                        onPressed: () {
                          if (multipleDropPoints.isEmpty) {
                            hideKeyboard(context);
                            multipleDropPoints = [TextEditingController(), TextEditingController()];
                            multipleDropPointsFocus = [FocusNode(), FocusNode()];
                          } else {
                            multipleDropPoints.add(TextEditingController());
                            multipleDropPointsFocus.add(FocusNode());
                          }
                          setState(() {});
                        },
                        child: Text(
                          language.addDropPoint,
                          style: primaryTextStyle(),
                        )),
                  if (listAddress.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Material(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 2,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: listAddress.length,
                        separatorBuilder: (_, __) => Divider(height: 1),
                        itemBuilder: (context, index) {
                          final place = listAddress[index];
                          final title = (place['title'] ?? '').toString();
                          final subtitle = (place['subtitle'] ?? '').toString();
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.location_on_outlined, color: primaryColor),
                            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: primaryTextStyle()),
                            subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: secondaryTextStyle()),
                            onTap: () => _selectPlace(place),
                          );
                        },
                      ),
                    ),
                  ],
                  AppButtonWidget(
                    width: MediaQuery.of(context).size.width,
                    onTap: () async {
                      if (multipleDropPoints.isNotEmpty) {
                        var abc = {};
                        polylineDestination = multiDropLatLng[multipleDropPoints.length - 1];
                        destinationLocation.text = multipleDropPoints.last.text;
                        for (int i = 0; i < multipleDropPoints.length; i++) {
                          abc[i] = multipleDropPoints[i].text;
                        }
                        await launchScreen(
                            context,
                            Newestimateridelistwidget(
                              tripDetail: widget.tripDetail,
                              sourceLatLog: polylineSource,
                              destinationLatLog: polylineDestination,
                              sourceTitle: sourceLocation.text,
                              multiDropObj: multiDropLatLng,
                              multiDropLocationNamesObj: abc,
                              destinationTitle: destinationLocation.text,
                              is_taxi_service: true,
                              trip_type: widget.trip_type,
                            ),
                            pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                        multiDropLatLng.clear();
                        multipleDropPoints.clear();
                        multipleDropPointsFocus.clear();
                        multiDropFieldPosition = 0;
                        sourceLocation.clear();
                        destinationLocation.clear();
                      } else if (!sourceLocation.text.isEmptyOrNull && !destinationLocation.text.isEmptyOrNull) {
                        if (widget.trip_type == tripTypeAirportPickup || widget.trip_type == tripTypeAirportToZone) {
                          widget.tripDetail['airport_name'] = sourceLocation.text;
                          widget.tripDetail['pickup_airport_id'] = sourceId;
                          if (widget.trip_type == tripTypeAirportToZone) {
                            widget.tripDetail['drop_zone_id'] = destinationId;
                            widget.tripDetail['zone_name'] = destinationLocation.text;
                          }
                        } else if (widget.trip_type == tripTypeAirportDropoff || widget.trip_type == tripTypeZoneToAirport) {
                          widget.tripDetail['airport_name'] = destinationLocation.text;
                          widget.tripDetail['drop_airport_id'] = destinationId;
                          if (widget.trip_type == tripTypeZoneToAirport) {
                            widget.tripDetail['pickup_zone_id'] = sourceId;
                            widget.tripDetail['zone_name'] = sourceLocation.text;
                          }
                        } else if (widget.trip_type == tripTypeZoneWise) {
                          widget.tripDetail['pickup_zone_id'] = sourceId;
                          widget.tripDetail['drop_zone_id'] = destinationId;
                        }
                        launchScreen(
                            context,
                            Newestimateridelistwidget(
                                trip_type: widget.trip_type,
                                is_taxi_service: true,
                                tripDetail: widget.tripDetail,
                                pickupTimeValue: widget.pickupTimeValue,
                                sourceLatLog: polylineSource,
                                destinationLatLog: polylineDestination,
                                sourceTitle: sourceLocation.text,
                                destinationTitle: destinationLocation.text),
                            pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                        sourceLocation.clear();
                        destinationLocation.clear();
                      } else {
                        toast("Please Select Location");
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(language.continueD, style: boldTextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget reorderedView() {
    return ReorderableListView(
      shrinkWrap: true,
      children: [
        for (int i = 0; i < multipleDropPoints.length; i++)
          Row(
            key: ValueKey("$i"),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.red,
                      shadows: [
                        BoxShadow(color: Colors.black, blurRadius: 1, offset: Offset(1.5, 1.5), spreadRadius: 5),
                        BoxShadow(color: Colors.white70, blurRadius: 1, offset: Offset(-1, -1), spreadRadius: 5),
                      ],
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: multipleDropPoints[i],
                            focusNode: multipleDropPointsFocus[i],
                            autofocus: false,
                            decoration: searchInputDecoration(hint: "${language.dropPoint} ${i + 1}"),
                            onTap: () {
                              multiDropFieldPosition = i;
                              setState(() {});
                            },
                            onChanged: (val) => _onPlaceQueryChanged(val, field: 'multi', index: i),,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4),
                  ],
                ),
              ),
              if (i > 0)
                IconButton(
                  onPressed: () {
                    if (multipleDropPoints.length == 2) {
                      multipleDropPoints.clear();
                      multipleDropPointsFocus.clear();
                      multiDropLatLng.clear();
                    } else {
                      multipleDropPoints.removeAt(i);
                      multipleDropPointsFocus.removeAt(i);
                      multiDropLatLng.remove(i);
                    }
                    print("MM::${multipleDropPoints.length}");
                    setState(() {});
                  },
                  icon: Icon(Icons.remove_circle_outline),
                ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.menu),
              )
            ],
          ),
      ],
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = multipleDropPoints.removeAt(oldIndex);
          multipleDropPoints.insert(newIndex, item);
        });
      },
    );
  }
}

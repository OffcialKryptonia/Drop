import 'package:taxi_booking/model/search_location_model.dart' hide Text;

import '../manage_imports.dart';
import '../model/select_location_model.dart';

class GoogleMapScreen extends StatefulWidget {
  final bool? isDestination;

  const GoogleMapScreen({super.key, this.isDestination});

  @override
  GoogleMapScreenState createState() => GoogleMapScreenState();
}

class GoogleMapScreenState extends State<GoogleMapScreen> {
  GoogleMapController? mapController;
  LatLng? selectedPosition;
  String selectedAddress = "Fetching address...";
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  List<Suggestion> placeSuggestions = [];
  bool isTappedSuggested = false;

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        selectedAddress = "Location services are disabled";
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          selectedAddress = "Permission denied. Enable location.";
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        selectedAddress = "Permission permanently denied. Enable from settings.";
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      selectedPosition = LatLng(position.latitude, position.longitude);
      isLoading = false;
    });

    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLng(selectedPosition!),
      );
    }

    _fetchAddress(selectedPosition!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(),
        body: Stack(
          children: [
            selectedPosition == null
                ? Center(child: loaderWidget())
                : GoogleMap(
                    zoomControlsEnabled: false,
                    initialCameraPosition: CameraPosition(
                      target: selectedPosition!,
                      zoom: 15,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      mapController = controller;
                      if (!isLoading) {
                        mapController!.animateCamera(
                          CameraUpdate.newLatLng(selectedPosition!),
                        );
                      }
                    },
                    onCameraMove: (CameraPosition position) {
                      setState(() {
                        selectedPosition = position.target;
                        selectedAddress = "Fetching address...";
                      });
                    },
                    onCameraIdle: () {
                      _fetchAddress(selectedPosition!);
                      print("selectedPosition ${selectedPosition}");
                    },
                  ),
            Center(
              child: Icon(Icons.location_pin, size: 50, color: Colors.red),
            ),
            Positioned(
              top: 10,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    onChanged: (t) => fetchPlaceSuggestions(searchController.text),
                    decoration: InputDecoration(
                      hintText: "Search for a place",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (value) {
                      fetchPlaceSuggestions(searchController.text);
                    },
                  ),
                  if (placeSuggestions.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 5),
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                      ),
                      child: ListView.builder(
                        itemCount: placeSuggestions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            // title: Text(placeSuggestions[index].placePrediction!.text!.text.validate()),
                            title: Text(placeSuggestions[index].placePrediction.text.text),
                            onTap: () async {
                              // Call places detail api and get lat and long.
                              SelectLocationModel response = await searchAddressRequestPlaceId(
                                placeSuggestions[index].placePrediction.placeId,
                              );

                              searchController.text = placeSuggestions[index].placePrediction.text.text.validate();

                              mapController?.animateCamera(
                                CameraUpdate.newLatLng(
                                  LatLng(
                                    response.location.latitude,
                                    response.location.longitude,
                                  ),
                                ),
                              );

                              setState(() {
                                isTappedSuggested = true;
                                placeSuggestions.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                    ),
                    child: Text(
                      selectedAddress,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(height: 10),
                  AppButtonWidget(
                    width: MediaQuery.of(context).size.width,
                    onTap: selectedPosition == null && selectedAddress != "Fetching address..."
                        ? null
                        : () {
                            Navigator.pop(context, {
                              "position": selectedPosition,
                              "formatted_address": selectedAddress,
                            });
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
        ));
  }

  // Future<void> fetchPlaceSuggestions(String query) async {
  //   if (query.isEmpty) {
  //     setState(() {
  //       placeSuggestions.clear();
  //     });
  //     return;
  //   }
  //
  //   var headers = {'X-Goog-Api-Key': '$GOOGLE_MAP_API_KEY', 'Content-Type': 'application/json'};
  //
  //   var request = http.Request('POST', Uri.parse('https://places.googleapis.com/v1/places:autocomplete'));
  //   request.body = json.encode({"input": query});
  //   request.headers.addAll(headers);
  //
  //   http.StreamedResponse response = await request.send();
  //
  //   if (response.statusCode == 200) {
  //     String responseData = await response.stream.bytesToString();
  //     var data = json.decode(responseData);
  //     print("CheckDate::::${data}");
  //     setState(() {
  //       placeSuggestions = List<Suggestion>.from(data["suggestions"]!.map((x) => Suggestion.fromJson(x)));
  //     });
  //     print("CheckDat163::::${placeSuggestions.length}");
  //     print("CheckDat164::::${placeSuggestions}");
  //   } else {
  //     print(response.reasonPhrase);
  //   }
  // }

  Future<void> fetchPlaceSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        placeSuggestions.clear();
      });
      return;
    }

    try {
      Map req = {
        "search_text": query,
        "language": appStore.selectedLanguage.validate(value: defaultLanguageCode),
      };
      SearchLocationModel response = await searchAddressRequest(req);

      setState(() {
        placeSuggestions = response.suggestions ?? [];
      });
    } catch (e) {
      log("Autocomplete Error: $e");
    }
  }

  Future<void> _fetchAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        setState(() {
          selectedAddress = "${place.name}, ${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
        });
      }
    } catch (e) {
      setState(() {
        selectedAddress = "Error fetching address";
      });
    }
  }
}

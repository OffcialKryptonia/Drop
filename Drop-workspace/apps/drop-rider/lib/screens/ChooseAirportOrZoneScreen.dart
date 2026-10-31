import '../manage_imports.dart';

class ChooseAirportOrZoneScreen extends StatefulWidget {
  final bool? zone_selection;
  int? zoneId;

  ChooseAirportOrZoneScreen({super.key, this.zone_selection, this.zoneId});

  @override
  State<ChooseAirportOrZoneScreen> createState() => _ChooseAirportOrZoneScreenState();
}

class _ChooseAirportOrZoneScreenState extends State<ChooseAirportOrZoneScreen> {
  List<AirportItem> airportList = [];
  List<AirportItem> filteredAirportList = [];

  String? searchAirPort;

  List<ZoneItem> ZoneList = [];
  List<ZoneItem> filteredZoneList = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 1)).then((val) {
      if (widget.zone_selection == true) {
        getZoneListCall();
      } else {
        getAirPortListCall();
      }
    });
  }

  getZoneListCall({String? airPortName}) {
    appStore.setLoading(true);

    getZoneList(name: airPortName ?? '', zoneId: widget.zoneId ?? 0).then(
      (value) {
        setState(() {
          ZoneList.clear();
          filteredZoneList.clear();
          ZoneList.addAll(value.data ?? []);
          filteredZoneList = List.from(ZoneList);
          appStore.setLoading(false);
        });
      },
    );
  }

  getAirPortListCall({String? airPortName}) {
    appStore.setLoading(true);
    getAirportList(name: airPortName ?? '').then(
      (value) {
        setState(() {
          airportList.clear();
          filteredAirportList.clear();
          airportList.addAll(value.data ?? []);
          filteredAirportList = List.from(airportList);
          appStore.setLoading(false);
        });
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    airportList.clear();
    filteredAirportList.clear();
    ZoneList.clear();
    filteredZoneList.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.zone_selection == true ? '${language.selectZone}' : '${language.selectAirport}',
          style: primaryTextStyle(weight: FontWeight.w500, color: Colors.white, size: 22),
        ),
      ),
      body: Observer(builder: (context) {
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  SizedBox(
                    height: 8,
                  ),
                  AppTextField(
                    controller: searchController,
                    autoFocus: false,
                    readOnly: false,
                    textFieldType: TextFieldType.EMAIL,
                    keyboardType: TextInputType.emailAddress,
                    onFieldSubmitted: (p0) {},
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        if (widget.zone_selection == true) {
                          if (searchController.text.length > 2) {
                            getZoneListCall(airPortName: searchController.text);
                          } else {
                            getZoneListCall();
                          }
                        } else {
                          if (searchController.text.length > 2) {
                            getAirPortListCall(airPortName: searchController.text);
                          } else {
                            getAirPortListCall();
                          }
                        }
                      } else {
                        if (widget.zone_selection == true) {
                          getZoneListCall();
                        } else {
                          getAirPortListCall();
                        }
                      }
                    },
                    decoration: InputDecoration(
                      focusColor: primaryColor,
                      prefixIcon: Icon(Feather.search),
                      filled: false,
                      isDense: true,
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  searchController.text = '';
                                  if (widget.zone_selection == true) {
                                    getZoneListCall();
                                  } else {
                                    getAirPortListCall();
                                  }
                                });
                              },
                            )
                          : null,
                      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: Colors.black)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: dividerColor)),
                      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(defaultRadius), borderSide: BorderSide(color: Colors.red)),
                      alignLabelWithHint: true,
                      hintText: widget.zone_selection == true ? '${language.searchZone}' : '${language.searchAirport}',
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  //   Airport Listing
                  Expanded(
                    child: ListView.separated(
                      itemCount: widget.zone_selection == true ? filteredZoneList.length : filteredAirportList.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context, widget.zone_selection == true ? filteredZoneList[index].toJson() : filteredAirportList[index].toJson());
                            },
                            child: Text(
                              widget.zone_selection == true ? '${filteredZoneList[index].name}' : '${filteredAirportList[index].name}',
                              style: primaryTextStyle(),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return Divider();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Visibility(
              visible: appStore.isLoading,
              child: loaderWidget(),
            ),
          ],
        );
      }),
    );
  }
}

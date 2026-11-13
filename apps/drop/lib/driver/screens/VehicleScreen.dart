import 'package:drop/service/DriverApplicationApi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:drop/driver/main.dart';
import 'package:drop/driver/model/UserDetailModel.dart';
import 'package:drop/driver/network/RestApis.dart';
import 'package:drop/driver/utils/Colors.dart';
import 'package:drop/driver/utils/Extensions/AppButtonWidget.dart';
import 'package:drop/driver/utils/Extensions/app_common.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';

import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/app_textfield.dart';

class VehicleScreen extends StatefulWidget {
  @override
  VehicleScreenState createState() => VehicleScreenState();
}

class VehicleScreenState extends State<VehicleScreen> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController carModelController = TextEditingController();
  TextEditingController carColorController = TextEditingController();
  TextEditingController carPlateNumberController = TextEditingController();
  TextEditingController carProductionYearController = TextEditingController();
  TextEditingController vehicleService = TextEditingController();

  UserDetail userDetail = UserDetail();

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    appStore.setLoading(true);
    try {
      final r = await DriverApplicationApi.driverProfile();
      final v = r['vehicle'] is Map ? Map<String, dynamic>.from(r['vehicle'] as Map) : <String, dynamic>{};
      carModelController.text = (v['model'] ?? '').toString();
      carColorController.text = (v['color'] ?? '').toString();
      carPlateNumberController.text = (v['plate'] ?? '').toString();
      carProductionYearController.text = (v['year'] ?? '').toString();
      vehicleService.text = (r['service_name'] ?? '').toString();
    } catch (error) {
      log(error.toString());
      toast('Could not load your vehicle details. Check your connection and try again.');
    }
    appStore.setLoading(false);
    setState(() {});
  }

  Future<void> updateVehicle() async {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      appStore.setLoading(true);
      updateVehicleDetail(
        carColor: carColorController.text.trim(),
        carModel: carModelController.text.trim(),
        carPlateNumber: carPlateNumberController.text.trim(),
        carProduction: carProductionYearController.text.trim(),
      ).then((value) {
        appStore.setLoading(false);

        // Navigator.pop(context);
        toast(language.vehicleInfoUpdateSucessfully);
      }).catchError((error) {
        appStore.setLoading(false);
        log(error.toString());
      });
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(language.updateVehicleInfo,
            style: boldTextStyle(color: appTextPrimaryColorWhite)),
      ),
      body: Form(
        key: formKey,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  AppTextField(
                    controller: vehicleService,
                    textFieldType: TextFieldType.NAME,
                    errorThisFieldRequired: language.thisFieldRequired,
                    readOnly: true,
                    decoration:
                        inputDecoration(context, label: language.serviceInfo),
                    onTap: () {
                      toast(language.youCannotChangeService);
                    },
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: carModelController,
                    textFieldType: TextFieldType.NAME,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration:
                        inputDecoration(context, label: language.vehicleModel),
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: carColorController,
                    textFieldType: TextFieldType.NAME,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration:
                        inputDecoration(context, label: language.vehicleColor),
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: carPlateNumberController,
                    textFieldType: TextFieldType.NAME,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration: inputDecoration(context,
                        label: language.vehiclePlateNumber),
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: carProductionYearController,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textFieldType: TextFieldType.PHONE,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration: inputDecoration(context,
                        label: language.vehicleProductionYear),
                  ),
                ],
              ),
            ),
            Observer(builder: (context) {
              return Visibility(
                visible: appStore.isLoading,
                child: loaderWidget(),
              );
            })
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: AppButtonWidget(
          text: language.updateVehicle,
          color: primaryColor,
          textStyle: boldTextStyle(color: Colors.white),
          onTap: () {
            updateVehicle();
          },
        ),
      ),
    );
  }
}

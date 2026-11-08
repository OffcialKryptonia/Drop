import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pinput/pinput.dart';
import 'package:drop/driver/screens/DocumentsScreen.dart';
import 'package:drop/driver/utils/Extensions/dataTypeExtensions.dart';

import '../../main.dart';
import '../../network/RestApis.dart';
import '../Services/AuthService.dart';
import '../languageConfiguration/LanguageDefaultJson.dart';
import '../screens/DashboardScreen.dart';
import '../screens/SignUpScreen.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Extensions/app_textfield.dart';
import '../utils/utils.dart';

class OTPDialog extends StatefulWidget {
  final String? verificationId;
  final String? phoneNumber;
  final bool? isCodeSent;
  final PhoneAuthCredential? credential;

  OTPDialog(
      {this.verificationId,
      this.isCodeSent,
      this.phoneNumber,
      this.credential});

  @override
  OTPDialogState createState() => OTPDialogState();
}

class OTPDialogState extends State<OTPDialog> {
  AuthServices authService = AuthServices();
  final otpController = TextEditingController();
  TextEditingController phoneController = TextEditingController();

  String verId = '';
  String otpCode = defaultCountryCode;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    //
  }

  Future<void> submit() async {
    appStore.setLoading(true);

    AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId!, smsCode: verId.validate());

    await FirebaseAuth.instance
        .signInWithCredential(credential)
        .then((result) async {
      Map req = {
        "email": '',
        "login_type": "mobile",
        "user_type": "driver",
        "username": widget.phoneNumber!.split(" ").last,
        'accessToken': widget.phoneNumber!.split(" ").last,
        'contact_number': widget.phoneNumber!.replaceAll(" ", ""),
      };

      log(req);
      await logInApi(req, isSocialLogin: true).then((value) async {
        appStore.setLoading(false);
        if (value.data == null) {
          Navigator.pop(context);
          launchScreen(
              context,
              SignUpScreen(
                  countryCode: widget.phoneNumber!.split(" ").first,
                  userName: widget.phoneNumber!.split(" ").last,
                  socialLogin: true));
        } else {
          updatePlayerId();
          if (sharedPref.getInt(IS_Verified_Driver) == 1) {
            Navigator.pop(context);
            launchScreen(context, DashboardScreen(), isNewTask: true);
          } else {
            Navigator.pop(context);
            launchScreen(context, DocumentsScreen(isShow: true),
                pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
          }
        }
      }).catchError((e) {
        Navigator.pop(context);
        toast(e.toString());
        appStore.setLoading(false);
      });
    }).catchError((e) {
      Navigator.pop(context);
      toast(e.toString());

      appStore.setLoading(false);
    });
  }

  Future<void> sendOTP() async {
    appStore.setLoading(true);

    String number = '$otpCode ${phoneController.text.trim()}';

    log('$otpCode${phoneController.text.trim()}');

    try {
      await authService.loginWithOTP(context, number).then((value) {
        //
      });
    } catch (e) {
      toast(e.toString());
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCodeSent.validate()) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  language.signInUsingYourMobileNumber,
                  style: boldTextStyle(),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.cancel_outlined, color: Colors.black),
              )
            ],
          ),
          SizedBox(height: 30),
          AppTextField(
            controller: phoneController,
            textFieldType: TextFieldType.PHONE,
            decoration: inputDecoration(
              context,
              label: language.phoneNumber,
              prefixIcon: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountryCodePicker(
                      padding: EdgeInsets.zero,
                      initialSelection: otpCode,
                      showCountryOnly: false,
                      dialogSize: Size(MediaQuery.of(context).size.width - 60,
                          MediaQuery.of(context).size.height * 0.6),
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
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: primaryColor)),
                      ),
                      searchStyle: primaryTextStyle(),
                      onInit: (c) {
                        otpCode = c!.dialCode!;
                      },
                      onChanged: (c) {
                        otpCode = c.dialCode!;
                      },
                    ),
                    VerticalDivider(color: Colors.grey.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
            validator: (value) {
              if (value!.trim().isEmpty) return language.thisFieldRequired;
              return null;
            },
          ),
          SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              AppButtonWidget(
                onTap: () {
                  if (phoneController.text.trim().isEmpty) {
                    return toast(language.thisFieldRequired);
                  } else {
                    hideKeyboard(context);
                    sendOTP();
                  }
                },
                text: language.sendOTP,
                width: MediaQuery.of(context).size.width,
              ),
              Positioned(
                child: Observer(builder: (context) {
                  return Visibility(
                    visible: appStore.isLoading,
                    child: loaderWidget(),
                  );
                }),
              ),
            ],
          )
        ],
      );
    } else {
      return Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Icon(Icons.cancel_outlined)),
              ),
              Icon(Icons.message, color: primaryColor, size: 50),
              SizedBox(height: 16),
              Text(language.validateOtp, style: boldTextStyle(size: 18)),
              SizedBox(height: 16),
              Column(
                children: [
                  Text(language.otpCodeHasBeenSentTo,
                      style: secondaryTextStyle(size: 16),
                      textAlign: TextAlign.center),
                  SizedBox(height: 4),
                  Text(widget.phoneNumber.validate(), style: boldTextStyle()),
                  SizedBox(height: 10),
                  Text(language.pleaseEnterOtp,
                      style: secondaryTextStyle(size: 16),
                      textAlign: TextAlign.center),
                ],
              ),
              SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Pinput(
                    keyboardType: TextInputType.number,
                    readOnly: false,
                    autofocus: true,
                    length: 6,
                    onTap: () {},
                    onLongPress: () {},
                    cursor: Text(
                      "|",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 40,
                      height: 44,
                      textStyle: TextStyle(
                        fontSize: 18,
                      ),
                      decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          border: Border.all(color: primaryColor)),
                    ),
                    toolbarEnabled: true,
                    useNativeKeyboard: true,
                    defaultPinTheme: PinTheme(
                      width: 40,
                      height: 44,
                      textStyle: TextStyle(
                        fontSize: 18,
                      ),
                      decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          border: Border.all(color: dividerColor)),
                    ),
                    isCursorAnimationEnabled: true,
                    showCursor: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    closeKeyboardWhenCompleted: false,
                    enableSuggestions: false,
                    autofillHints: [AutofillHints.oneTimeCode],
                    controller: otpController,
                    onCompleted: (val) {
                      otpController.text = val;
                      verId = val;
                      submit();
                    },
                  ),
                ),
              ),
            ],
          ),
          Observer(
            builder: (context) => Positioned.fill(
              child: Visibility(
                visible: appStore.isLoading,
                child: loaderWidget(),
              ),
            ),
          ),
        ],
      );
    }
  }
}

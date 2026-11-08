import '../manage_imports.dart';

class OTPDialog extends StatefulWidget {
  final String? verificationId;
  final String? phoneNumber;
  final bool? isCodeSent;
  final PhoneAuthCredential? credential;

  OTPDialog({this.verificationId, this.isCodeSent, this.phoneNumber, this.credential});

  @override
  OTPDialogState createState() => OTPDialogState();
}

class OTPDialogState extends State<OTPDialog> {
  var otpController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AuthServices authService = AuthServices();

  String verId = '';
  String otpCode = defaultCountryCode;

  Future<void> submit() async {
    appStore.setLoading(true);

    AuthCredential credential = PhoneAuthProvider.credential(verificationId: widget.verificationId!, smsCode: verId.validate());

    await FirebaseAuth.instance.signInWithCredential(credential).then((result) async {
      Map req = {
        "email": "",
        "login_type": "mobile",
        "user_type": RIDER,
        "username": widget.phoneNumber!.split(" ").last,
        'accessToken': widget.phoneNumber!.split(" ").last,
        'contact_number': widget.phoneNumber!.replaceAll(" ", ""),
        "player_id": sharedPref.getString(PLAYER_ID).validate(),
      };

      log(req);
      await logInApi(req, isSocialLogin: true).then((value) async {
        appStore.setLoading(false);
        if (value.data == null) {
          Navigator.pop(context);
          launchScreen(context, SignUpScreen(countryCode: widget.phoneNumber!.split(" ").first, userName: widget.phoneNumber!.split(" ").last, socialLogin: true));
        } else {
          updatePlayerId();
          Navigator.pop(context);
          launchScreen(context, DashBoardScreen(), isNewTask: true);
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
    if (formKey.currentState!.validate()) {
      appStore.setLoading(true);

      String number = '$otpCode ${phoneController.text.trim()}';

      log('sendotp $otpCode${phoneController.text.trim()}');
      await authService.loginWithOTP(context, number).then((value) {}).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString());
      });
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
          Form(
            key: formKey,
            child: AppTextField(
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
                        dialogSize: Size(MediaQuery.of(context).size.width - 60, MediaQuery.of(context).size.height * 0.6),
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
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
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
                color: primaryColor,
                textStyle: boldTextStyle(color: Colors.white),
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
                    child: Icon(Icons.cancel_outlined, color: Colors.black)),
              ),
              Icon(Icons.message, color: primaryColor, size: 50),
              SizedBox(height: 16),
              Text(language.validateOtp, style: boldTextStyle(size: 18)),
              SizedBox(height: 16),
              Column(
                children: [
                  Text(language.otpCodeHasBeenSentTo, style: secondaryTextStyle(size: 16), textAlign: TextAlign.center),
                  SizedBox(height: 4),
                  Text(widget.phoneNumber.validate(), style: boldTextStyle()),
                  SizedBox(height: 10),
                  Text(language.pleaseEnterOtp, style: secondaryTextStyle(size: 16), textAlign: TextAlign.center),
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
                    onClipboardFound: (value) {},
                    length: 6,
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

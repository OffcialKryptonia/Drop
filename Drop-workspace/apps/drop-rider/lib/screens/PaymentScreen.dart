import '../manage_imports.dart';
import 'package:flutter_paytabs_bridge/BaseBillingShippingInfo.dart' as payTab;
import 'package:http/http.dart' as http;

class PaymentScreen extends StatefulWidget {
  final num? amount;

  PaymentScreen({this.amount});

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  List<PaymentModel> paymentList = [];

  String? selectedPaymentType, stripPaymentKey, stripPaymentPublishKey, payStackPublicKey, flutterWavePublicKey, flutterWaveSecretKey, flutterWaveEncryptionKey, payTabsProfileId, payTabsServerKey, payTabsClientKey, myFatoorahToken, paytmMerchantId, paytmMerchantKey;

  String? razorKey;
  bool isTestType = true;
  bool loading = false;

  final plugin = PaystackPlugin();
  late Razorpay _razorpay;
  CheckoutMethod method = CheckoutMethod.card;
  bool is_myFatoorah_test = false;
  Map<String, dynamic> paypalValue = {
    "is_test": true,
    "client_id": "1234",
    "client_secret": "1234",
  };

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    await paymentListApiCall();
    if (paymentList.any((element) => element.type == PAYMENT_TYPE_STRIPE)) {
      Stripe.publishableKey = stripPaymentPublishKey.validate();
      if (Platform.isIOS) {
        Stripe.merchantIdentifier = mStripeIdentifier;
      }
      await Stripe.instance.applySettings().catchError((e) {
        log("${e.toString()}");
      });
    }
    if (paymentList.any((element) => element.type == PAYMENT_TYPE_PAYSTACK)) {
      plugin.initialize(publicKey: payStackPublicKey.validate());
    }
    if (paymentList.any((element) => element.type == PAYMENT_TYPE_RAZORPAY)) {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  /// Get Payment Gateway Api Call
  Future<void> paymentListApiCall() async {
    appStore.setLoading(true);
    await getPaymentList().then((value) {
      appStore.setLoading(false);
      paymentList.addAll(value.data!);
      selectedPaymentType = paymentList.first.type;
      if (paymentList.isNotEmpty) {
        paymentList.forEach((element) {
          if (element.type == PAYMENT_TYPE_STRIPE) {
            stripPaymentKey = element.isTest == 1 ? element.testValue!.secretKey : element.liveValue!.secretKey;
            stripPaymentPublishKey = element.isTest == 1 ? element.testValue!.publishableKey : element.liveValue!.publishableKey;
          } else if (element.type == PAYMENT_TYPE_PAYSTACK) {
            payStackPublicKey = element.isTest == 1 ? element.testValue!.publicKey : element.liveValue!.publicKey;
          } else if (element.type == PAYMENT_TYPE_RAZORPAY) {
            razorKey = element.isTest == 1 ? element.testValue!.keyId.validate() : element.liveValue!.keyId.validate();
          } else if (element.type == PAYMENT_TYPE_PAYPAL) {
            if (element.isTest == 1) {
              paypalValue = {
                "is_test": true,
                "client_id": "${element.testValue?.publicKey}",
                "client_secret": "${element.testValue?.secretKey}",
              };
            } else {
              paypalValue = {
                "is_test": false,
                "client_id": "${element.liveValue?.publicKey}",
                "client_secret": "${element.liveValue?.secretKey}",
              };
            }
          } else if (element.type == PAYMENT_TYPE_FLUTTERWAVE) {
            flutterWavePublicKey = element.isTest == 1 ? element.testValue!.publicKey : element.liveValue!.publicKey;
            flutterWaveSecretKey = element.isTest == 1 ? element.testValue!.secretKey : element.liveValue!.secretKey;
            flutterWaveEncryptionKey = element.isTest == 1 ? element.testValue!.encryptionKey : element.liveValue!.encryptionKey;
          } else if (element.type == PAYMENT_TYPE_PAYTABS) {
            payTabsProfileId = element.isTest == 1 ? element.testValue!.profileId : element.liveValue!.profileId;
            payTabsClientKey = element.isTest == 1 ? element.testValue!.clientKey : element.liveValue!.clientKey;
            payTabsServerKey = element.isTest == 1 ? element.testValue!.serverKey : element.liveValue!.serverKey;
          } else if (element.type == PAYMENT_TYPE_MYFATOORAH) {
            myFatoorahToken = element.isTest == 1 ? element.testValue!.accessToken : element.liveValue!.accessToken;
            is_myFatoorah_test = element.isTest == 1;
          } else if (element.type == PAYMENT_TYPE_PAYTM) {
            paytmMerchantId = element.isTest == 1 ? element.testValue!.merchantId : element.liveValue!.merchantId;
            paytmMerchantKey = element.isTest == 1 ? element.testValue!.merchantKey : element.liveValue!.merchantKey;
          }
        });
      }
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      log('${error.toString()}');
    });
  }

  /// Razor Pay
  void razorPayPayment() {
    var options = {
      'key': razorKey.validate(),
      'amount': (widget.amount! * 100),
      'name': mAppName,
      'description': mRazorDescription,
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {
        'contact': sharedPref.getString(CONTACT_NUMBER),
        'email': sharedPref.getString(USER_EMAIL),
      },
      'external': {
        'wallets': ['paytm']
      }
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      log(e.toString());
      debugPrint('Error: e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    toast(language.transactionSuccessful);
    paymentConfirm();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    toast(language.transactionFailed);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    toast("EXTERNAL_WALLET: " + response.walletName!);
  }

  /// StripPayment
  // void stripePay() async {
  //   Map<String, String> headers = {
  //     HttpHeaders.authorizationHeader: 'Bearer ${stripPaymentKey.validate()}',
  //     HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
  //   };
  //
  //   var request = http.Request('POST', Uri.parse(stripeURL));
  //
  //   request.bodyFields = {
  //     'amount': '${(widget.amount! * 100)}',
  //     'currency': "${appStore.currencyName.toUpperCase()}",
  //
  //     /// 'currency': "INR",   Test for ind currency payment
  //   };
  //
  //   log(request.bodyFields);
  //   request.headers.addAll(headers);
  //
  //   log(request);
  //
  //   appStore.setLoading(true);
  //
  //   await request.send().then((value) {
  //     appStore.setLoading(false);
  //     http.Response.fromStream(value).then((response) async {
  //       if (response.statusCode == 200) {
  //         var res = StripePayModel.fromJson(await handleResponse(response));
  //         SetupPaymentSheetParameters setupPaymentSheetParameters = SetupPaymentSheetParameters(
  //           paymentIntentClientSecret: res.clientSecret.validate(),
  //           style: ThemeMode.light,
  //           appearance: PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: primaryColor)),
  //           // applePay: PaymentSheetApplePay(merchantCountryCode: appStore.currencyName.toUpperCase()),
  //           googlePay: PaymentSheetGooglePay(merchantCountryCode: appStore.currencyName.toUpperCase(), testEnv: true),
  //           merchantDisplayName: mAppName,
  //           customerId: appStore.userId.toString(),
  //         );
  //         await Stripe.instance.initPaymentSheet(paymentSheetParameters: setupPaymentSheetParameters).then((value) async {
  //           await Stripe.instance.presentPaymentSheet().then((value) async {
  //             toast(language.transactionSuccessful);
  //             paymentConfirm();
  //           });
  //         }).catchError((e) {
  //           toast(language.transactionFailed);
  //           log("presentPaymentSheet ${e.toString()}");
  //         });
  //       }
  //     }).catchError((e) {
  //       appStore.setLoading(false);
  //       toast(e.toString(), print: true);
  //     });
  //   }).catchError((e) {
  //     appStore.setLoading(false);
  //     toast(e.toString(), print: true);
  //   });
  // }

  void stripePay() async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${stripPaymentKey.validate()}',
      HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
    };

    var request = http.Request('POST', Uri.parse(stripeURL));

    request.bodyFields = {
      'amount': '${(widget.amount! * 100)}',
      'currency': "${appStore.currencyName.toUpperCase()}",
    };

    log(request.bodyFields);
    request.headers.addAll(headers);

    log(request);

    appStore.setLoading(true);

    await request.send().then((value) {
      appStore.setLoading(false);
      http.Response.fromStream(value).then((response) async {
        if (response.statusCode == 200) {
          var res = StripePayModel.fromJson(jsonDecode(response.body));
          SetupPaymentSheetParameters setupPaymentSheetParameters = SetupPaymentSheetParameters(
            paymentIntentClientSecret: res.clientSecret.validate(),
            style: ThemeMode.light,
            appearance: PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: primaryColor)),
            googlePay: PaymentSheetGooglePay(merchantCountryCode: appStore.currencyName.toUpperCase(), testEnv: true),
            merchantDisplayName: mAppName,
            customerId: appStore.userId.toString(),
          );
          await Stripe.instance.initPaymentSheet(paymentSheetParameters: setupPaymentSheetParameters).then((value) async {
            await Stripe.instance.presentPaymentSheet().then((value) async {
              toast(language.transactionSuccessful);
              paymentConfirm();
            });
          }).catchError((e) {
            toast(language.transactionFailed);
            log("presentPaymentSheet ${e.toString()}");
          });
        }
      }).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString(), print: true);
      });
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString(), print: true);
    });
  }

  Future<void> paymentConfirm() async {
    Map req = {
      "user_id": sharedPref.getInt(USER_ID),
      "type": "credit",
      "amount": widget.amount,
      "transaction_type": "topup",
      "currency": appStore.currencyName,
    };
    appStore.isLoading = true;
    await saveWallet(req).then((value) {
      appStore.isLoading = false;
      Navigator.pop(context, true);
    }).catchError((error) {
      appStore.isLoading = false;

      log(error.toString());
    });
  }

  ///PayStack Payment
  void payStackPayment(BuildContext context) async {
    Charge charge = Charge()
      ..amount = (widget.amount! * 100).round() // In base currency
      ..email = sharedPref.getString(USER_EMAIL)
      ..currency = 'NGN';

    charge.reference = _getReference();

    try {
      CheckoutResponse response = await plugin.checkout(context, method: method, charge: charge, fullscreen: false);
      payStackUpdateStatus(response.reference, response.message);
      if (response.message == 'Success') {
        toast(language.transactionSuccessful);
        paymentConfirm();
      } else {
        toast(language.paymentFailed);
      }
    } catch (e) {
      payStackShowMessage(language.checkConsoleForError);
      rethrow;
    }
  }

  payStackUpdateStatus(String? reference, String message) {
    payStackShowMessage(message, const Duration(seconds: 7));
  }

  void payStackShowMessage(String message, [Duration duration = const Duration(seconds: 4)]) {
    toast(message);
    log(message);
  }

  String _getReference() {
    String platform;
    if (Platform.isIOS) {
      platform = 'iOS';
    } else {
      platform = 'Android';
    }
    return 'ChargedFrom${platform}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String?> getPaypalAccessToken() async {
    String url = paypalValue['is_test'] == true ? 'https://api-m.sandbox.paypal.com/v1/oauth2/token' : 'https://api-m.paypal.com/v1/oauth2/token';
    String credentials = '${paypalValue['client_id']}:${paypalValue['client_secret']}';
    String encodedCredentials = base64Encode(utf8.encode(credentials));

    Map<String, String> headers = {
      'Authorization': 'Basic $encodedCredentials',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    Map<String, String> body = {
      'grant_type': 'client_credentials',
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String accessToken = data['access_token'];
        return accessToken;
      } else {
        print('Failed to get token: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  void payPalPayments() async {
    appStore.setLoading(true);
    var accessToken = await getPaypalAccessToken();
    String url = paypalValue['is_test'] == true ? 'https://api-m.sandbox.paypal.com/v2/checkout/orders' : 'https://api-m.paypal.com/v2/checkout/orders';
    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    Map<String, dynamic> body = {
      'intent': 'CAPTURE',
      'purchase_units': [
        {
          'amount': {
            'currency_code': '${appStore.currencyName.toUpperCase()}',
            'value': '${widget.amount?.toInt()}',
          },
          'description': 'Wallet Top UP',
        }
      ],
      'application_context': {
        'return_url': 'https://www.google.com',
        'cancel_url': 'https://login.yahoo.com',
        'shipping_preference': 'NO_SHIPPING',
      }
    };
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        String orderId = data['id'];
        var link = paypalValue['is_test'] == true ? "https://www.sandbox.paypal.com/checkoutnow?token=${orderId}" : "https://www.paypal.com/checkoutnow?token=${orderId}";
        appStore.setLoading(false);
        launchScreen(
            navigatorKey.currentState!.overlay!.context,
            WebViewScreen(
                onClick: (msg) {
                  if (msg == "Success") {
                    paymentConfirm();
                  }
                },
                mInitialUrl: link));
      } else {
        toast("Payment failed: Invalid token or unsupported currency.", length: Toast.LENGTH_LONG);
        appStore.setLoading(false);
        return null;
      }
    } catch (e) {
      appStore.setLoading(false);
      return null;
    }
  }

  /// FlutterWave Payment
  void flutterWaveCheckout() async {
    final customer = Customer(name: sharedPref.getString(USER_NAME).validate(), phoneNumber: sharedPref.getString(CONTACT_NUMBER).validate(), email: sharedPref.getString(USER_EMAIL).validate());

    final Flutterwave flutterwave = Flutterwave(
      context: context,
      publicKey: flutterWavePublicKey.validate(),
      currency: appStore.currencyName.toLowerCase(),
      redirectUrl: "https://www.google.com",
      txRef: DateTime.now().millisecond.toString(),
      amount: widget.amount.toString(),
      customer: customer,
      paymentOptions: "card, payattitude",
      customization: Customization(title: "Test Payment"),
      isTestMode: isTestType,
    );
    final ChargeResponse response = await flutterwave.charge();
    if (response.status == 'successful') {
      toast(language.transactionSuccessful);
      paymentConfirm();
    } else {
      FlutterwaveViewUtils.showToast(context, language.transactionFailed);
    }
  }

  /// PayTabs Payment
  void payTabsPayment() {
    FlutterPaytabsBridge.startCardPayment(generateConfig(), (event) {
      setState(() {
        if (event["status"] == "success") {
          var transactionDetails = event["data"];
          if (transactionDetails["isSuccess"]) {
            toast(language.transactionSuccessful);
            paymentConfirm();
          } else {
            toast(language.transactionFailed);
          }
          toast(language.transactionSuccessful);
        } else if (event["status"] == "error") {
        } else if (event["status"] == "event") {
          //
        }
      });
    });
  }

  PaymentSdkConfigurationDetails generateConfig() {
    List<PaymentSdkAPms> apms = [];
    apms.add(PaymentSdkAPms.STC_PAY);
    var configuration = PaymentSdkConfigurationDetails(
        profileId: payTabsProfileId,
        serverKey: payTabsServerKey,
        clientKey: payTabsClientKey,
        cartDescription: language.appName,
        //cartId: widget..toString(),
        screentTitle: language.payWithCard,
        amount: widget.amount!.toDouble(),
        showBillingInfo: true,
        forceShippingInfo: false,
        currencyCode: appStore.currencyName.toUpperCase(),
        merchantCountryCode: "IN",
        billingDetails: payTab.BillingDetails(
          sharedPref.getString(USER_NAME).validate(),
          sharedPref.getString(USER_EMAIL).validate(),
          sharedPref.getString(CONTACT_NUMBER).validate(),
          sharedPref.getString(ADDRESS).validate(),
          '',
          '',
          '',
          '',
        ),
        alternativePaymentMethods: apms,
        linkBillingNameWithCardHolderName: true);

    var theme = IOSThemeConfigurations();

    theme.logoImage = ic_logo_white;

    configuration.iOSThemeConfigurations = theme;

    return configuration;
  }

  initiatePayment() async {
    try {
      await MFSDK.init(
        "$myFatoorahToken",
        MFCountry.KUWAIT,
        is_myFatoorah_test ? MFEnvironment.TEST : MFEnvironment.LIVE,
      );
      MFInitiatePaymentRequest request = MFInitiatePaymentRequest(
        invoiceAmount: 10,
        currencyIso: MFCurrencyISO.SAUDIARABIA_SAR,
      );
      await MFSDK.initiatePayment(request, MFLanguage.ENGLISH).then((value) {}).catchError((error) {});
    } catch (e) {
      print("Exception during initiatePayment(): $e");
    }
  }

  executeFatoorahPayment() async {
    try {
      await initiatePayment(); // Optional: depends on when you want to call it
      MFExecutePaymentRequest request = MFExecutePaymentRequest(invoiceValue: widget.amount);
      // 1 is for knet
      // 2 is for card payment
      request.paymentMethodId = 1; // Replace with valid method ID from init response
      try {
        MFGetPaymentStatusResponse b1 = await MFSDK.executePayment(request, MFLanguage.ENGLISH, (invoiceId) {});
        if (b1.invoiceStatus?.toLowerCase() == "paid") {
          paymentConfirm();
        }
      } catch (e) {
        toast("Payment failed: Invalid token or unsupported currency.", length: Toast.LENGTH_LONG);
      }
    } catch (e) {
      toast("Payment failed: Invalid token or unsupported currency.", length: Toast.LENGTH_LONG);
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
        title: Text(language.payment, style: boldTextStyle(color: appTextPrimaryColorWhite)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: paymentList.map((e) {
                return inkWellWidget(
                  onTap: () {
                    selectedPaymentType = e.type;
                    setState(() {});
                  },
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      //backgroundColor: Colors.white,
                      borderRadius: BorderRadius.circular(defaultRadius),
                      border: Border.all(color: selectedPaymentType == e.type ? primaryColor : dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Image.network(e.gatewayLogo!, width: 40, height: 40),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(e.title.validate(), style: primaryTextStyle(), maxLines: 2),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Observer(builder: (context) {
            if (!appStore.isLoading && paymentList.isEmpty) {
              return emptyWidget();
            }
            return Visibility(
              visible: appStore.isLoading,
              child: loaderWidget(),
            );
          }),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: Visibility(
          visible: paymentList.isNotEmpty,
          child: AppButtonWidget(
            text: language.pay,
            onTap: () {
              if (selectedPaymentType == PAYMENT_TYPE_RAZORPAY) {
                razorPayPayment();
              } else if (selectedPaymentType == PAYMENT_TYPE_STRIPE) {
                stripePay();
              } else if (selectedPaymentType == PAYMENT_TYPE_PAYSTACK) {
                payStackPayment(context);
              } else if (selectedPaymentType == PAYMENT_TYPE_PAYPAL) {
                payPalPayments();
              } else if (selectedPaymentType == PAYMENT_TYPE_FLUTTERWAVE) {
                flutterWaveCheckout();
              } else if (selectedPaymentType == PAYMENT_TYPE_PAYTABS) {
                payTabsPayment();
              } else if (selectedPaymentType == PAYMENT_TYPE_MYFATOORAH) {
                executeFatoorahPayment();
              }
            },
          ),
        ),
      ),
    );
  }
}

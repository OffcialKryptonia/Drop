import '../manage_imports.dart';

class BankInfoScreen extends StatefulWidget {
  @override
  BankInfoScreenState createState() => BankInfoScreenState();
}

class BankInfoScreenState extends State<BankInfoScreen> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController bankNameController = TextEditingController();
  TextEditingController bankCodeController = TextEditingController();
  TextEditingController accountHolderNameController = TextEditingController();
  TextEditingController accountNumberController = TextEditingController();
  TextEditingController routingController = TextEditingController();
  TextEditingController ibanController = TextEditingController();
  TextEditingController swiftController = TextEditingController();

  UserBankAccount? bankDetail;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    appStore.setLoading(true);
    await getUserDetail(userId: sharedPref.getInt(USER_ID)).then((value) {
      appStore.setLoading(false);
      if (value.data!.userBankAccount != null) {
        bankDetail = value.data!.userBankAccount!;
        bankNameController.text = bankDetail!.bankName.validate();
        bankCodeController.text = bankDetail!.bankCode.validate();
        accountHolderNameController.text =
            bankDetail!.accountHolderName.validate();
        accountNumberController.text = bankDetail!.accountNumber.validate();
        routingController.text = bankDetail!.routingNumber.validate();
        ibanController.text = bankDetail!.bankIban.validate();
        swiftController.text = bankDetail!.bankSwift.validate();
        appStore.setLoading(false);
        setState(() {});
      }
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> updateBankInfo() async {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      appStore.setLoading(true);
      updateBankDetail(
        accountName: accountHolderNameController.text.trim(),
        accountNumber: accountNumberController.text.trim(),
        bankCode: bankCodeController.text.trim(),
        bankName: bankNameController.text.trim(),
        iban: ibanController.text.trim(),
        routing: routingController.text.trim(),
        swift: swiftController.text.trim(),
      ).then((value) {
        appStore.setLoading(false);

        // Navigator.pop(context, true);
        toast(language.bankInfoUpdated);
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
        title:
            Text(language.bankInfo, style: boldTextStyle(color: Colors.white)),
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
                    controller: bankNameController,
                    textFieldType: TextFieldType.NAME,
                    decoration:
                        inputDecoration(context, label: language.bankName),
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: bankCodeController,
                    textFieldType: TextFieldType.NAME,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration:
                        inputDecoration(context, label: language.bankCode),
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: accountHolderNameController,
                    textFieldType: TextFieldType.NAME,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration: inputDecoration(context,
                        label: language.accountHolderName),
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: accountNumberController,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textFieldType: TextFieldType.PHONE,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration:
                        inputDecoration(context, label: language.accountNumber),
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: routingController,
                    textFieldType: TextFieldType.OTHER,
                    // errorThisFieldRequired: language.thisFieldRequired,
                    decoration:
                        inputDecoration(context, label: language.routingNumber),
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: ibanController,
                    textFieldType: TextFieldType.OTHER,
                    // errorThisFieldRequired: language.thisFieldRequired,
                    decoration: inputDecoration(context, label: language.iban),
                  ),
                  SizedBox(height: 16),
                  AppTextField(
                    controller: swiftController,
                    textFieldType: TextFieldType.OTHER,
                    // errorThisFieldRequired: language.thisFieldRequired,
                    decoration: inputDecoration(context, label: language.swift),
                  ),
                ],
              ),
            ),
            Observer(builder: (context) {
              return Visibility(
                visible: appStore.isLoading,
                child: loaderWidget(),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: AppButtonWidget(
          text: bankDetail != null
              ? language.updateBankDetail
              : language.addBankDetail,
          color: primaryColor,
          textStyle: boldTextStyle(color: Colors.white),
          onTap: () {
            updateBankInfo();
          },
        ),
      ),
    );
  }
}

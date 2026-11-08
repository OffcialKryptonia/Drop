import '../manage_imports.dart';


class CancelOrderDialog extends StatefulWidget {
  static String tag = '/CancelOrderDialog';

  final Function(String)? onCancel;

  CancelOrderDialog({this.onCancel});

  @override
  CancelOrderDialogState createState() => CancelOrderDialogState();
}

class CancelOrderDialogState extends State<CancelOrderDialog> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  TextEditingController reasonController = TextEditingController();
  int selectedReason = 0;
  List<CancleData> cancelReasonList = [];
  late FocusNode myFocusNode;

  @override
  void initState() {
    myFocusNode = FocusNode();
    super.initState();
    getCancelReasonApi();
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    super.dispose();
  }

  Future<void> getCancelReasonApi() async {
    appStore.setLoading(true);
    await getCancelReasonList(type: "rider").then((value) {
      appStore.setLoading(false);
      cancelReasonList.clear();
      cancelReasonList.addAll(value.data);
      appStore.setLoading(false);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            child: Padding(
              padding: const EdgeInsets.only(left: 0, right: 0, top: 16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(language.cancelRide, style: boldTextStyle(size: 18)),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Icon(Icons.clear),
                        ),
                      ],
                    ),
                  ),
                  cancelReasonList.isNotEmpty
                      ? SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < cancelReasonList.length; i++)
                                  RadioListTile(
                                    value: i,
                                    groupValue: selectedReason,
                                    onChanged: (value) {
                                      selectedReason = value ?? -1;
                                      if (selectedReason != -1 && cancelReasonList[selectedReason] == language.others) {
                                        myFocusNode.requestFocus();
                                      }
                                      setState(() {});
                                    },
                                    title: Text(cancelReasonList[i].title),
                                    activeColor: primaryColor,
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity(vertical: VisualDensity.minimumDensity, horizontal: VisualDensity.minimumDensity),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                if (selectedReason != -1 && cancelReasonList[selectedReason] == language.others)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: AppTextField(
                                      focus: myFocusNode,
                                      controller: reasonController,
                                      textFieldType: TextFieldType.OTHER,
                                      maxLength: 1000,
                                      decoration: inputDecoration(context, label: language.writeReasonHere),
                                      maxLines: 3,
                                      minLines: 3,
                                      validator: (value) {
                                        if (value!.isEmpty) return language.thisFieldRequired;
                                        return null;
                                      },
                                    ),
                                  ),
                                if (selectedReason != -1 && cancelReasonList[selectedReason] == language.others) SizedBox(height: 16),
                              ],
                            ),
                          ),
                        )
                      : !appStore.isLoading
                          ? emptyWidget()
                          : SizedBox(),
                  loaderWidget().center().visible(appStore.isLoading),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppButtonWidget(
                        onTap: () {
                          if (formKey.currentState!.validate()) {
                            widget.onCancel?.call(selectedReason != -1 && cancelReasonList[selectedReason] != language.others ? cancelReasonList[selectedReason].title : reasonController.text);
                          }
                        },
                        text: language.submit,
                        color: primaryColor,
                        textStyle: boldTextStyle(color: Colors.white),
                        width: MediaQuery.of(context).size.width,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

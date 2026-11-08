import 'package:flutter/material.dart';
import 'package:drop/driver/model/CancleListResponse.dart';
import 'package:drop/driver/utils/Extensions/extension.dart';

import '../../main.dart';
import '../network/RestApis.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';

class CancelOrderDialog extends StatefulWidget {
  static String tag = '/CancelOrderDialog';
  final String? service_type;
  final Function(String)? onCancel;

  CancelOrderDialog({this.onCancel, this.service_type});

  @override
  CancelOrderDialogState createState() => CancelOrderDialogState();
}

class CancelOrderDialogState extends State<CancelOrderDialog> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  TextEditingController reasonController = TextEditingController();
  String? reason;
  int selectedReason = 0;
  late FocusNode myFocusNode;
  List<CancleData> cancelReasonList = [];

  @override
  void initState() {
    myFocusNode = FocusNode();
    super.initState();
    getCancelReasonApi();
    init();
  }

  Future<void> init() async {
    LiveStream().on('UpdateLanguage', (p0) {
      getCancelReasonApi();
      setState(() {});
    });
  }

  Future<void> getCancelReasonApi() async {
    appStore.setLoading(true);
    await getCancelReason(type: "driver").then((value) {
      appStore.setLoading(false);
      cancelReasonList.clear();
      cancelReasonList.addAll(value.data);
      appStore.setLoading(false);
      setState(() {});
    }).catchError((error, s) {
      print("cancel error ${error.toString()} ${s.toString()}");
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
              child: Form(
                key: formKey,
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
                            // padding: EdgeInsets.only(top: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < cancelReasonList.length; i++)
                                  RadioListTile(
                                    value: i,
                                    groupValue: selectedReason,
                                    visualDensity: VisualDensity(vertical: VisualDensity.minimumDensity, horizontal: VisualDensity.minimumDensity),
                                    onChanged: (value) {
                                      selectedReason = value ?? -1;
                                      if (selectedReason != -1 && cancelReasonList[selectedReason].title == language.other) {
                                        myFocusNode.requestFocus();
                                      }
                                      setState(() {});
                                    },
                                    title: Text(cancelReasonList[i].title),
                                    activeColor: primaryColor,
                                    contentPadding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                if (selectedReason != -1 && cancelReasonList[selectedReason].title == language.other)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: AppTextField(
                                      maxLength: 1000,
                                      focus: myFocusNode,
                                      controller: reasonController,
                                      textFieldType: TextFieldType.OTHER,
                                      decoration: inputDecoration(context, label: language.writeReasonHere),
                                      maxLines: 3,
                                      minLines: 3,
                                      validator: (value) {
                                        if (value!.isEmpty) return language.thisFieldRequired;
                                        return null;
                                      },
                                    ),
                                  ),
                                if (selectedReason != -1 && cancelReasonList[selectedReason].title == language.other) SizedBox(height: 16),
                              ],
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
                              widget.onCancel?.call(selectedReason != -1 && cancelReasonList[selectedReason].title != language.other ? cancelReasonList[selectedReason].title : reasonController.text);
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
        ),
      ],
    );
  }
}

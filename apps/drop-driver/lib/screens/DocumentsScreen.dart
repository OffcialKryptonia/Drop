import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mighty_core/utils/core_enum.dart';
import 'package:mighty_core/utils/core_network_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taxi_driver/main.dart';
import 'package:taxi_driver/utils/Colors.dart';
import 'package:taxi_driver/utils/Extensions/AppButtonWidget.dart';
import 'package:taxi_driver/utils/Extensions/app_common.dart';
import 'package:taxi_driver/utils/Extensions/dataTypeExtensions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/ImageSourceDialog.dart';
import '../model/DocumentListModel.dart';
import '../model/DriverDocumentList.dart';
import '../network/RestApis.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/ConformationDialog.dart';
import '../utils/Images.dart';
import 'DashboardScreen.dart';

class DocumentsScreen extends StatefulWidget {
  final bool isShow;

  DocumentsScreen({this.isShow = false});

  @override
  DocumentsScreenState createState() => DocumentsScreenState();
}

class DocumentsScreenState extends State<DocumentsScreen> {
  DateTime selectedDate = DateTime.now();

  List<DocumentModel> documentList = [];
  List<DriverDocumentModel> driverDocumentList = [];

  List<int> uploadedDocList = [];
  List<String> eAttachments = [];
  String? imagePath;
  int docId = 0;
  var compressedImg;

  int? isExpire;

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: primaryColor,
            colorScheme: ColorScheme.light(primary: primaryColor),
            buttonTheme: ButtonThemeData(
                // textTheme: ButtonTextTheme.primary
                ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(),
            ),
            datePickerTheme: DatePickerThemeData(backgroundColor: Colors.white, cancelButtonStyle: ButtonStyle(), headerBackgroundColor: Colors.white),
            dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    afterBuildCreated(() async {
      appStore.setLoading(true);
      await getDocument();
      await driverDocument();
    });
  }

  ///Driver Document List
  Future<void> getDocument() async {
    appStore.setLoading(true);
    await getDocumentList().then((value) {
      documentList.addAll(value.data!);
      appStore.setLoading(false);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);

      toast(error.toString());
    });
  }

  ///Document List
  Future<void> driverDocument() async {
    appStore.setLoading(true);
    await getDriverDocumentList().then((value) {
      driverDocumentList.clear();
      driverDocumentList.addAll(value.data!);
      uploadedDocList.clear();
      driverDocumentList.forEach((element) {
        uploadedDocList.add(element.documentId!);
      });
      appStore.setLoading(false);

      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      // throw error;
      log(error.toString());
    });
  }

  /// Add Documents
  // addDocument(int? docId, int? isExpire, {int? updateId, DateTime? dateTime}) async {
  //   MultipartRequest multiPartRequest = await getMultiPartRequest(updateId == null ? 'driver-document-save' : 'driver-document-update/$updateId');
  //   multiPartRequest.fields['driver_id'] = sharedPref.getInt(USER_ID).toString();
  //   multiPartRequest.fields['document_id'] = docId.toString();
  //   multiPartRequest.fields['is_verified'] = '0';
  //   if (isExpire != null) multiPartRequest.fields['expire_date'] = dateTime.toString();
  //   if (imagePath != null) {
  //     multiPartRequest.files.add(await MultipartFile.fromPath("driver_document", imagePath!));
  //   }
  //   multiPartRequest.headers.addAll(await buildCoreHeaderTokens());
  //   appStore.setLoading(true);
  //   sendMultiPartRequest(
  //     multiPartRequest,
  //     onSuccess: (data) async {
  //       appStore.setLoading(false);
  //       await driverDocument();
  //     },
  //     onError: (error) {
  //       appStore.setLoading(false);
  //       // throw error;
  //       print("errror doc ${error}");
  //       toast(error.toString(), print: true);
  //     },
  //   ).catchError((e) {
  //     appStore.setLoading(false);
  //     print("catchError doc ${e}");
  //     // throw e;
  //     toast(e.toString());
  //   });
  // }

  Future addDocument(int? docId, int? isExpire, {int? updateId, DateTime? dateTime}) async {
    String endpoint = updateId == null ? 'driver-document-save' : 'driver-document-update/$updateId';

    Map<String, File> files = {};
    if (imagePath != null) {
      files['driver_document'] = File(imagePath!);
    }

    Map<String, dynamic> fields = {
      'driver_id': sharedPref.getInt(USER_ID).toString(),
      'document_id': docId.toString(),
      'is_verified': '0',
    };

    if (isExpire != null && dateTime != null) {
      fields['expire_date'] = dateTime.toString();
    }

    appStore.setLoading(true);

    return executeRequest(
      endpoint,
      method: HttpMethods.POST,
      fields: fields,
      files: files,
    ).then((res) async {
      appStore.setLoading(false);

      if (res != null) {
        await driverDocument();
      }
    }).catchError((error) {
      appStore.setLoading(false);
      print("error doc $error");
      toast(error.toString(), print: true);
    });
  }

  Future<File> compressFile(File file) async {
    Directory d = await getTemporaryDirectory();
    FlutterImageCompress.validator.ignoreCheckExtName = true;
    try {
      Uint8List? result = await FlutterImageCompress.compressWithFile(
        file.path,
        minHeight: 512,
        minWidth: 512,
        quality: 100,
      );
      if (result == null) {
        return file;
      }
      File file2 = await File('${d.path}/image.png').create();
      file2.writeAsBytesSync(result);
      return file2;
    } catch (e) {
      return file;
    }
  }

  /// SelectImage
  getMultipleFile(int? docId, int? isExpire, {int? updateId, DateTime? dateTime}) async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius))),
      builder: (_) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: ImageSourceDialog(
                onCamera: () async {
                  Navigator.pop(context);
                  try {
                    var result = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 100);
                    if (result != null) {
                      File result2 = await compressFile(File(result.path));
                      int b = await result2.length();
                      double fileSizeInMB = b / (1024 * 1024);
                      if (fileSizeInMB > 2) {
                        return toast(language.fileSizeValidateMsg);
                      }
                      uploadFile(result2.path, docId, isExpire, updateId: updateId);
                    }
                  } catch (e) {
                    toast(e.toString());
                    return;
                  }
                },
                onGallery: () async {
                  Navigator.pop(context);
                  var result = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 100);
                  if (result != null) {
                    File result2 = await compressFile(File(result.path));
                    int b = await result2.length();
                    double fileSizeInMB = b / (1024 * 1024);
                    if (fileSizeInMB > 2) {
                      return toast(language.fileSizeValidateMsg);
                    }
                    uploadFile(result.path, docId, isExpire, updateId: updateId);
                  }
                },
                onFile: () async {
                  Navigator.pop(context);
                  FilePickerResult? filePickerResult = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'], allowMultiple: false);
                  if (filePickerResult != null) {
                    int b = filePickerResult.files.first.size;
                    double fileSizeInMB = b / (1024 * 1024);
                    if (fileSizeInMB > 2) {
                      return toast(language.fileSizeValidateMsg);
                    }
                    uploadFile(filePickerResult.files.first.path, docId, isExpire, updateId: updateId);
                  }
                },
                isFile: true,
              ),
            );
          },
        );
      },
    );
  }

  uploadFile(String? file, int? docId, int? isExpire, {int? updateId}) {
    if (file != null) {
      showConfirmDialogCustom(
        context,
        title: language.uploadFileConfirmationMsg,
        onAccept: (BuildContext context) {
          setState(() {
            imagePath = file;
          });
          addDocument(docId, isExpire, dateTime: selectedDate, updateId: updateId);
        },
        positiveText: language.yes,
        negativeText: language.no,
        primaryColor: primaryColor,
      );
      if (isExpire == 1) selectDate(context);
    }
  }

  /// Delete Documents
  deleteDoc(int? id) {
    appStore.setLoading(true);
    deleteDeliveryDoc(id!).then((value) {
      toast(value.message, print: true);

      driverDocument();
      appStore.setLoading(false);
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
    });
  }

  Future<void> getDetailAPi() async {
    appStore.setLoading(true);
    await getUserDetail(userId: sharedPref.getInt(USER_ID)).then((value) {
      appStore.setLoading(false);

      sharedPref.setInt(IS_Verified_Driver, value.data!.isVerifiedDriver!);
      if (value.data!.isDocumentRequired != 0) {
        toast(language.someRequiredDocumentAreNotUploaded);
      } else {
        if (sharedPref.getInt(IS_Verified_Driver) == 1) {
          launchScreen(context, DashboardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
        } else {
          toast('${language.userNotApproveMsg}');
        }
      }
    }).catchError((error) {
      appStore.setLoading(false);

      log(error.toString());
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    //ignore:deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          return true;
        } else {
          SystemNavigator.pop();
          return false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(language.documents, style: boldTextStyle(color: appTextPrimaryColorWhite)),
          actions: [
            if (widget.isShow)
              IconButton(
                onPressed: () async {
                  await logout();
                },
                icon: Icon(Icons.logout, color: Colors.white),
              ),
          ],
        ),
        body: Observer(builder: (context) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: dividerColor), borderRadius: radius()),
                            child: DropdownButtonFormField<DocumentModel>(
                              hint: Text(language.selectDocument, style: primaryTextStyle()),
                              decoration: InputDecoration.collapsed(
                                hintText: null,
                                focusColor: primaryColor,
                              ),
                              isExpanded: true,
                              isDense: true,
                              items: documentList.map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: RichText(
                                    text: TextSpan(
                                      text: e.name.validate(),
                                      style: primaryTextStyle(),
                                      children: [
                                        TextSpan(text: '${e.isRequired == 1 ? ' *' : ''}', style: boldTextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (DocumentModel? val) {
                                docId = val!.id!;
                                isExpire = val.hasExpiryDate!;

                                setState(() {});
                              },
                            ),
                          ),
                        ),
                        if (docId != 0)
                          SizedBox(
                            width: 16,
                          ),
                        if (docId != 0)
                          Visibility(
                            visible: !uploadedDocList.contains(docId),
                            child: inkWellWidget(
                              onTap: () {
                                if (isExpire == 1) {
                                  getMultipleFile(docId, isExpire == 0 ? null : 1, dateTime: selectedDate);
                                } else {
                                  getMultipleFile(docId, isExpire == 0 ? null : 1);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(10),
                                // margin: EdgeInsets.only(left: 16),
                                decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: dividerColor), borderRadius: radius()),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, color: primaryColor, size: 24),
                                    SizedBox(width: 8),
                                    Text(language.addDocument, style: secondaryTextStyle()),
                                  ],
                                ),
                              ),
                            ),
                          )
                      ],
                    ),
                    SizedBox(height: 8),
                    // Text(language.fileSizeValidate, style: secondaryTextStyle(size: 12)),
                    Text(language.isMandatoryDocument, style: primaryTextStyle(color: Colors.red)),
                    SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      itemCount: driverDocumentList.length,
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (_, index) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driverDocumentList[index].documentName!, style: boldTextStyle()),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(defaultRadius)),
                              child: Column(
                                children: [
                                  driverDocumentList[index].driverDocument!.contains('.pdf')
                                      ? InkWell(
                                          child: Column(
                                            children: [
                                              Image.asset(ic_pdf, fit: BoxFit.cover, height: 35, width: 35),
                                              SizedBox(height: 8),
                                              Text(driverDocumentList[index].driverDocument!.split('/').last, style: primaryTextStyle()),
                                            ],
                                          ),
                                          onTap: () {
                                            launchUrl(Uri.parse(driverDocumentList[index].driverDocument.validate()), mode: LaunchMode.externalApplication);
                                          },
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(defaultRadius),
                                          child: commonCachedNetworkImage(driverDocumentList[index].driverDocument!, height: 200, width: MediaQuery.of(context).size.width, fit: BoxFit.cover),
                                        ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      driverDocumentList[index].expireDate != null ? Text(language.expireDate, style: boldTextStyle()) : Text(''),
                                      SizedBox(width: 8),
                                      driverDocumentList[index].expireDate != null
                                          ? Expanded(child: Text(driverDocumentList[index].expireDate.toString(), style: primaryTextStyle()))
                                          : Expanded(
                                              child: Text(
                                              '',
                                              style: primaryTextStyle(),
                                            )),
                                      Visibility(
                                        visible: driverDocumentList[index].isVerified == 0,
                                        child: inkWellWidget(
                                          onTap: () {
                                            if (isExpire == 1) {
                                              getMultipleFile(driverDocumentList[index].documentId, driverDocumentList[index].expireDate != null ? 1 : null, dateTime: selectedDate, updateId: driverDocumentList[index].id);
                                            } else {
                                              getMultipleFile(driverDocumentList[index].documentId, driverDocumentList[index].expireDate != null ? 1 : null, updateId: driverDocumentList[index].id);
                                            }
                                          },
                                          child: Container(
                                            height: 25,
                                            width: 25,
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: primaryColor),
                                            ),
                                            child: Icon(Icons.edit, color: primaryColor, size: 14),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Visibility(
                                        visible: driverDocumentList[index].isVerified == 0,
                                        child: inkWellWidget(
                                          onTap: () async {
                                            showConfirmDialogCustom(
                                              context,
                                              title: language.areYouSureYouWantToDeleteThisDocument,
                                              onAccept: (BuildContext context) async {
                                                await deleteDoc(driverDocumentList[index].id);
                                              },
                                              positiveText: language.yes,
                                              negativeText: language.no,
                                              primaryColor: primaryColor,
                                            );
                                          },
                                          child: Container(
                                            height: 25,
                                            width: 25,
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.red),
                                            ),
                                            child: Icon(Icons.delete, color: Colors.red, size: 14),
                                          ),
                                        ),
                                      ),
                                      driverDocumentList[index].isVerified == 1 ? SizedBox(width: 16) : SizedBox(),
                                      Visibility(
                                        visible: driverDocumentList[index].isVerified == 1,
                                        child: Icon(Icons.verified_user, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      separatorBuilder: (_, index) {
                        return Divider();
                      },
                    )
                  ],
                ),
              ),
              Visibility(
                visible: appStore.isLoading,
                child: loaderWidget(),
              ),
              if (!appStore.isLoading && driverDocumentList.isEmpty) emptyWidget()
            ],
          );
        }),
        bottomNavigationBar: driverDocumentList.isNotEmpty
            ? Visibility(
                visible: widget.isShow,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: AppButtonWidget(
                    text: language.goDashBoard,
                    onTap: () {
                      getDetailAPi();
                    },
                  ),
                ),
              )
            : SizedBox(),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:http/http.dart' as http;
import 'package:internet_file/internet_file.dart';
import 'package:mighty_core/utils/core_network_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdf;
import 'package:pdfx/pdfx.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';
import '../utils/Common.dart';
import '../utils/Extensions/app_common.dart';

class Payoutpdfscreen extends StatefulWidget {
  final String invoice;

  Payoutpdfscreen({required this.invoice});

  @override
  State<Payoutpdfscreen> createState() => _PayoutpdfscreenState();
}

class _PayoutpdfscreenState extends State<Payoutpdfscreen> {
  PdfController? pdfController;

  @override
  void initState() {
    super.initState();
    viewPDF();
  }

  Future<void> viewPDF() async {
    try {
      pdfController = PdfController(
        document: pdf.PdfDocument.openData(InternetFile.get(
          "${widget.invoice}",
          headers: await buildCoreHeaderTokens(),
        )),
        initialPage: 0,
      );
    } catch (e) {}
  }

  Future<void> downloadPDF() async {
    appStore.setLoading(true);
    try {
      final response = await http.get(Uri.parse(widget.invoice), headers: await buildCoreHeaderTokens());
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        await Permission.storage.request();

        Directory? directory;
        if (Platform.isAndroid) {
          directory = await getExternalStorageDirectory();
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory == null) throw Exception("Unable to access storage directory");

        final fileName = "PayoutDoc";

        final filePath = "${directory.path}/$fileName.pdf";
        final file = File(filePath);

        await file.writeAsBytes(bytes, flush: true);

        appStore.setLoading(false);
        toast("invoice downloaded at ${filePath}");

        if (await file.exists()) {
          await OpenFile.open(file.path);
          ;
        } else {
          throw Exception("File not found after saving");
        }
      } else {
        appStore.setLoading(false);
        toast("Failed to download PDF: ${response.statusCode}");
      }
    } catch (e) {
      appStore.setLoading(false);
      print("catch ${e.toString()}");

      if (e.toString().contains("Permission denied")) {
        await Permission.storage.request();
        toast("Please allow storage permission and try again.");
        return;
      }
      toast("Error while downloading PDF");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: Text("Driver Payout Report Document", style: boldTextStyle(color: Colors.white)),
          actions: [
            IconButton(
              onPressed: () {
                downloadPDF();
              },
              icon: Icon(Icons.download, color: Colors.white),
            ),
          ],
        ),
        body: Stack(
          children: [
            PdfView(
              controller: pdfController!,
            ),
            PdfPageNumber(
              controller: pdfController!,
              builder: (_, loadingState, page, pagesCount) {
                if (page == 0) return loaderWidget();
                return SizedBox();
              },
            ),
            Observer(builder: (context) => Visibility(visible: appStore.isLoading, child: Positioned.fill(child: loaderWidget()))),
          ],
        ));
  }
}

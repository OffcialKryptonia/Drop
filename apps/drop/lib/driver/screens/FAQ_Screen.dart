import 'package:flutter/material.dart';
import 'package:drop/driver/main.dart';
import 'package:drop/driver/network/RestApis.dart';
import 'package:drop/driver/utils/Colors.dart';
import '../model/ModelFAQ.dart';
import '../utils/Extensions/app_common.dart';

class FAQScreen extends StatefulWidget {
  @override
  _FAQScreenState createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  List<FaqItem> faqList = [];
  int currentPage = 1;
  int totalPages = 1;
  bool isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchFAQs(currentPage);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !isLoadingMore &&
          currentPage < totalPages) {
        fetchFAQs(currentPage + 1);
      }
    });
  }

  Future<void> fetchFAQs(int page) async {
    setState(() {
      isLoadingMore = true;
    });

    try {
      ModelFAQ response = await getFaqList(page: page);
      setState(() {
        currentPage = page;
        totalPages = response.pagination?.totalPages ?? 1;
        faqList.addAll(response.data ?? []);
      });
    } catch (e) {
      print("Error fetching FAQs: $e");
    }

    setState(() {
      isLoadingMore = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(language.lblfaq,
            style: boldTextStyle(color: appTextPrimaryColorWhite)),
      ),
      body: ListView.builder(
        padding: EdgeInsets.zero,
        controller: _scrollController,
        itemCount: faqList.length + 1,
        itemBuilder: (context, index) {
          if (index < faqList.length) {
            final faq = faqList[index];
            return ExpansionTile(
              title: Text(
                faq.question ?? "",
                style: boldTextStyle(),
              ),
              backgroundColor: Colors.grey.shade200,
              collapsedBackgroundColor: Colors.white,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8),
                    child: Text(
                      faq.answer ?? "",
                      style: secondaryTextStyle(),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ),
              ],
            );
          } else {
            return isLoadingMore
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                        child: CircularProgressIndicator(
                      color: primaryColor,
                    )),
                  )
                : SizedBox.shrink();
          }
        },
      ),
    );
  }
}

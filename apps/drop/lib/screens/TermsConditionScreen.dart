import '../manage_imports.dart';

class TermsConditionScreen extends StatefulWidget {
  final String? title;
  final String? subtitle;

  TermsConditionScreen({this.title, this.subtitle});

  @override
  TermsConditionScreenState createState() => TermsConditionScreenState();
}

class TermsConditionScreenState extends State<TermsConditionScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!, style: boldTextStyle(color: appTextPrimaryColorWhite)),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.subtitle == null ? 'https://www.google.com' : widget.subtitle ?? '')),
      ),
    );
  }
}

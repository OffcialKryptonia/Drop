import '../manage_imports.dart';

class UpdateAvailable extends StatefulWidget {
  final bool? force;
  final String storeUrl;

  UpdateAvailable({super.key, this.force, required this.storeUrl});

  @override
  State<UpdateAvailable> createState() => _UpdateAvailableState();
}

class _UpdateAvailableState extends State<UpdateAvailable> {
  @override
  Widget build(BuildContext context) {
    // ignore:deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (widget.force != true) {
          return true;
        }
        return false;
      },
      child: Material(
        color: Colors.transparent,
        child: Wrap(
          runAlignment: WrapAlignment.center,
          children: [
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: 45,
              ),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Stack(children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: context.width() * 0.40,
                        child: Image.asset(updateAvailableImg)),
                    SizedBox(
                      height: 16,
                    ),
                    Text(
                      textAlign: TextAlign.center,
                      language.updateAvailable,
                      style: boldTextStyle(color: primaryColor),
                    ),
                    SizedBox(
                      height: 8,
                    ),
                    Text(
                      textAlign: TextAlign.center,
                      language.updateNote,
                      style: secondaryTextStyle(color: primaryColor),
                    ),
                    SizedBox(
                      height: 32,
                    ),
                    Row(
                      mainAxisAlignment: widget.force != true
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        AppButtonWidget(
                          text: language.updateNow,
                          color: primaryColor,
                          textStyle:
                              boldTextStyle(size: 18, color: Colors.white),
                          onTap: () {
                            if (Platform.isAndroid) {
                              launchUrl(Uri.parse('${widget.storeUrl}'),
                                  mode: LaunchMode.externalApplication);
                            } else if (Platform.isIOS) {
                              launchUrl(Uri.parse("${widget.storeUrl}"),
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        if (widget.force != true)
                          SizedBox(
                            width: 8,
                          ),
                        if (widget.force != true)
                          AppButtonWidget(
                            text: language.skip,
                            color: Colors.white,
                            shapeBorder: RoundedRectangleBorder(
                                side: BorderSide(color: primaryColor),
                                borderRadius: BorderRadius.circular(12)),
                            textStyle:
                                boldTextStyle(size: 18, color: primaryColor),
                            onTap: () {
                              Navigator.pop(context);
                            },
                          )
                      ],
                    ),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

import '../manage_imports.dart';

class AboutWidget extends StatefulWidget {
  final UserData? userData;

  AboutWidget({this.userData});

  @override
  AboutWidgetState createState() => AboutWidgetState();
}

class AboutWidgetState extends State<AboutWidget> {
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
    return widget.userData != null
        ? Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(language.driverInformation, style: boldTextStyle()),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: primaryColor),
                        child: Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(defaultRadius),
                      child: commonCachedNetworkImage(
                          widget.userData!.profileImage.validate(),
                          height: 45,
                          width: 45,
                          fit: BoxFit.cover),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(widget.userData!.firstName.validate(),
                            style: boldTextStyle(size: 14)),
                        SizedBox(height: 4),
                        Text(widget.userData!.email.validate(),
                            style: secondaryTextStyle()),
                      ],
                    ),
                  ],
                ),
                Divider(thickness: 1, height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(language.carModel, style: primaryTextStyle(size: 14)),
                    Text(widget.userData!.userDetail!.carModel!.validate(),
                        style: secondaryTextStyle()),
                  ],
                ),
                SizedBox(
                  height: 8,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(language.lblCarNumberPlate,
                        style: primaryTextStyle(size: 14)),
                    Text(
                        widget.userData!.userDetail!.carPlateNumber!.validate(),
                        style: secondaryTextStyle()),
                  ],
                ),
              ],
            ),
          )
        : Visibility(
            visible: widget.userData != null && appStore.isLoading,
            child: loaderWidget(),
          );
  }
}

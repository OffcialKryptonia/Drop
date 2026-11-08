import '../manage_imports.dart';

class DrawerWidget extends StatefulWidget {
  final String title;
  final String iconData;
  final Function() onTap;
  final bool? paddingApply;

  DrawerWidget(
      {required this.title,
      this.paddingApply,
      required this.iconData,
      required this.onTap});

  @override
  DrawerWidgetState createState() => DrawerWidgetState();
}

class DrawerWidgetState extends State<DrawerWidget> {
  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return inkWellWidget(
      onTap: widget.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: dividerColor),
                      borderRadius: radius(defaultRadius)),
                  child: widget.paddingApply == true
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            widget.iconData,
                            height: 30 - 16,
                            width: 30 - 16,
                            color: primaryColor,
                          ),
                        )
                      : Image.asset(
                          widget.iconData,
                          height: 30,
                          width: 30,
                          color: primaryColor,
                        ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(widget.title, style: primaryTextStyle()),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: dividerColor)
              ],
            ),
          ],
        ),
      ),
    );
  }
}

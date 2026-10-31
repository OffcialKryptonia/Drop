import '../../manage_imports.dart';


enum DeviceSize { mobile, tablet, desktop }

extension LayoutUtils on BoxConstraints {
  /// returns DeviceSize
  DeviceSize get device {
    if (this.maxWidth >= desktopBreakpointGlobal) {
      return DeviceSize.desktop;
    }
    if (this.maxWidth >= tabletBreakpointGlobal) {
      return DeviceSize.tablet;
    }
    return DeviceSize.mobile;
  }
}

extension WidgetExtension on Widget? {
  /// With custom height and width
  /// Validate given widget is not null and returns given value if null.
  Widget validate({Widget value = const SizedBox()}) => this ?? value;

  /// set parent widget in center
  Widget center({double? heightFactor, double? widthFactor}) {
    return Center(
      heightFactor: heightFactor,
      widthFactor: widthFactor,
      child: this,
    );
  }

  /// add tap to parent widget
  Widget onTap(
    Function? function, {
    BorderRadius? borderRadius,
    Color? splashColor = Colors.transparent,
    Color? hoverColor = Colors.transparent,
    Color? highlightColor = Colors.transparent,
  }) {
    return InkWell(
      onTap: function as void Function()?,
      borderRadius: borderRadius ??
          (defaultInkWellRadius != null ? radius(defaultInkWellRadius) : null),
      child: this,
      splashColor: splashColor ?? defaultInkWellSplashColor,
      hoverColor: hoverColor ?? defaultInkWellHoverColor,
      highlightColor: highlightColor ?? defaultInkWellHighlightColor,
    );
  }

  /// add Expanded to parent widget
  Widget expand({flex = 1}) => Expanded(child: this!, flex: flex);

  /// return padding all
  Padding paddingAll(double padding) {
    return Padding(padding: EdgeInsets.all(padding), child: this);
  }

  /// return custom padding from each side
  Padding paddingOnly({
    double top = 0.0,
    double left = 0.0,
    double bottom = 0.0,
    double right = 0.0,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(left, top, right, bottom),
      child: this,
    );
  }

  /// return padding symmetric
  Padding paddingSymmetric({double vertical = 0.0, double horizontal = 0.0}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical, horizontal: horizontal),
      child: this,
    );
  }

  /// set visibility
  Widget visible(bool visible, {Widget? defaultWidget}) {
    return visible ? this! : (defaultWidget ?? SizedBox());
  }
}

extension BooleanExtensions on bool? {
  /// Validate given bool is not null and returns given value if null.
  bool validate({bool value = false}) => this ?? value;
}

/// set different layout based on current screen size (mobile, web, desktop)
class Responsive extends StatelessWidget {
  final Widget? web;
  final Widget mobile;
  final Widget? tablet;
  final bool? useFullWidth;
  final double? width;
  final double? minHeight;
  final Widget? defaultWidget;

  Responsive({
    this.web,
    required this.mobile,
    this.tablet,
    this.useFullWidth,
    this.width,
    this.minHeight,
    this.defaultWidget,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.device == DeviceSize.tablet) {
          return tablet ?? mobile;
        } else if (constraints.device == DeviceSize.mobile) {
          return mobile;
        } else if (constraints.device == DeviceSize.desktop) {
          /// $desktopBreakpointGlobal checkout this variable to breakout desktop widget

          if (minHeight != null && constraints.minHeight < minHeight!) {
            return defaultWidget.validate();
          } else {
            return Container(
              alignment: Alignment.topCenter,
              child: Container(
                constraints: useFullWidth??true
                    ? null
                    : BoxConstraints(
                        maxWidth:
                            width ?? (MediaQuery.of(context).size.width * 0.9)),
                child: web ?? SizedBox(),
              ),
            );
          }
        }
        return web ?? tablet ?? mobile;
      },
    );
  }
}

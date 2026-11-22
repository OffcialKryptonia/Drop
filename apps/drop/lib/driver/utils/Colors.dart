import 'package:flutter/material.dart';
import '../../drop/design/drop_theme.dart';

import '../main.dart';

Color primaryColor = Color(0xFFE5441A); // Drop orange
const polyLineColor = Color.fromARGB(255, 33, 83, 229);
const polyLineColor2 = Color.fromARGB(255, 229, 33, 33);
// Color polyLineColor = Color.fromARGB(255, 40, 122, 198);
Color get borderColor => DropTheme.isDark ? const Color(0xFF332F2B) : const Color(0xFFEAEAEA);
const scaffoldSecondaryDark = Color(0xFF1E1E1E);
const scaffoldColorDark = Color(0xFF090909);
const scaffoldColorLight = Colors.white;
const appButtonColorDark = Color(0xFF282828);
// Theme-aware: these follow Light/Dark (see DropTheme). Do not use them in `const` expressions.
Color get dividerColor => DropTheme.isDark ? const Color(0xFF3A3531) : const Color(0xFFD3D3D3);
Color get textPrimaryColor => DropTheme.isDark ? const Color(0xFFF5F2EF) : const Color(0xFF2E3033);
Color get textSecondaryColor => DropTheme.isDark ? const Color(0xFFB9B2AC) : const Color(0xFF757575);
Color get viewLineColor => DropTheme.isDark ? const Color(0xFF332F2B) : const Color(0xFFEAEAEA);

Color appBarBackgroundColorGlobal = Colors.white;
Color appButtonBackgroundColorGlobal = primaryColor;
Color defaultAppButtonTextColorGlobal = textPrimaryColorGlobal;
const appButtonTextStyleColor = Colors.white;
const appTextPrimaryColorWhite = Colors.white;

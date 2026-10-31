import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taxi_driver/utils/Colors.dart';

import '../utils/Extensions/extension.dart';

class AppTheme {
  //
  AppTheme._();

  static final ThemeData lightTheme = ThemeData(
    textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryColor,
        selectionHandleColor: primaryColor,
        selectionColor: primaryColor.withValues(alpha: 0.3)),
    primarySwatch: createMaterialColor(primaryColor),
    primaryColor: primaryColor,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: GoogleFonts.play().fontFamily,
    bottomNavigationBarTheme:
        BottomNavigationBarThemeData(backgroundColor: Colors.white),
    iconTheme: IconThemeData(color: scaffoldSecondaryDark),
    textTheme: TextTheme(titleLarge: TextStyle()),
    unselectedWidgetColor: Colors.black,
    dividerColor: viewLineColor,
    cardColor: Colors.white,
    dialogTheme: DialogThemeData(shape: dialogShape()),
    appBarTheme: AppBarTheme(
      color: primaryColor,
      iconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.light,
      ),
    ),
  ).copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    primarySwatch: createMaterialColor(primaryColor),
    primaryColor: primaryColor,
    scaffoldBackgroundColor: scaffoldColorDark,
    fontFamily: GoogleFonts.nunito().fontFamily,
    bottomNavigationBarTheme:
        BottomNavigationBarThemeData(backgroundColor: scaffoldSecondaryDark),
    iconTheme: IconThemeData(color: Colors.white),
    textTheme: TextTheme(titleLarge: TextStyle(color: textSecondaryColor)),
    unselectedWidgetColor: Colors.white60,
    dividerColor: Colors.white12,
    cardColor: scaffoldSecondaryDark,
    dialogTheme: DialogThemeData(shape: dialogShape()),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
  ).copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

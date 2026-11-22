import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../drop/design/drop_theme.dart';

/// The user's appearance choice. [system] follows the phone's light/dark setting.
enum DropThemePref { system, light, dark }

/// Central light/dark state and colour tokens for the whole app (rider, driver, dialogs, sheets).
///
/// * The choice is stored in shared preferences and read synchronously at start-up, so the very first
///   frame already uses the right theme (no flash).
/// * Screens that cannot easily read a [BuildContext] use the static tokens below; screens that can
///   should prefer `Theme.of(context)`. Both stay in step because every change bumps [revision] and
///   the app root rebuilds the tree.
class DropTheme {
  DropTheme._();

  static const String prefsKey = 'drop_theme_pref';

  /// What the user picked.
  static final ValueNotifier<DropThemePref> pref = ValueNotifier<DropThemePref>(DropThemePref.system);

  /// Increases every time the *effective* brightness changes (a pick, or the phone switching while on System).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Brightness _platform = Brightness.light;
  static SharedPreferences? _prefs;
  static bool _lastDark = false;
  static _PlatformWatcher? _watcher;

  static bool get isDark => pref.value == DropThemePref.dark || (pref.value == DropThemePref.system && _platform == Brightness.dark);
  static Brightness get brightness => isDark ? Brightness.dark : Brightness.light;

  static ThemeMode get themeMode {
    switch (pref.value) {
      case DropThemePref.light:
        return ThemeMode.light;
      case DropThemePref.dark:
        return ThemeMode.dark;
      case DropThemePref.system:
        return ThemeMode.system;
    }
  }

  static DropThemePref parse(Object? raw) {
    for (final p in DropThemePref.values) {
      if (p.name == raw) return p;
    }
    return DropThemePref.system;
  }

  /// Reads the saved choice. Call once at start-up, before `runApp`.
  static void load(SharedPreferences prefs, {Brightness? platform}) {
    _prefs = prefs;
    _platform = platform ?? ui.PlatformDispatcher.instance.platformBrightness;
    pref.value = parse(prefs.getString(prefsKey));
    _lastDark = isDark;
  }

  /// Starts following the phone's light/dark setting (only matters while the choice is System).
  static void attach() {
    _watcher ??= _PlatformWatcher();
    WidgetsBinding.instance.addObserver(_watcher!);
    _platform = ui.PlatformDispatcher.instance.platformBrightness;
    _emitIfChanged();
  }

  static void detach() {
    if (_watcher != null) WidgetsBinding.instance.removeObserver(_watcher!);
  }

  /// Applies and saves a new choice.
  static Future<void> setPref(DropThemePref next) async {
    pref.value = next;
    _emitIfChanged();
    try {
      await _prefs?.setString(prefsKey, next.name);
    } catch (_) {
      // Storage failure only means the choice is not remembered next launch.
    }
  }

  /// Flips between Light and Dark based on what is showing now (System counts as what the phone is using).
  static Future<void> toggle() => setPref(isDark ? DropThemePref.light : DropThemePref.dark);

  /// Test hook and platform callback.
  static void updatePlatform(Brightness b) {
    _platform = b;
    _emitIfChanged();
  }

  static void _emitIfChanged() {
    final now = isDark;
    if (now != _lastDark) {
      _lastDark = now;
      revision.value++;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    pref.value = DropThemePref.system;
    _platform = Brightness.light;
    _prefs = null;
    _lastDark = false;
    revision.value = 0;
  }

  /// Rebuilds every mounted widget so colours read from the static tokens refresh too.
  static void rebuildAll() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    visit(root);
  }

  // ---------------------------------------------------------------- tokens
  static const Color _lightScaffold = Color(0xFFFFFFFF);
  static const Color _darkScaffold = Color(0xFF0A0908);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _darkCard = Color(0xFF1A1715);
  static const Color _lightCardAlt = Color(0xFFF5F3F1);
  static const Color _darkCardAlt = Color(0xFF24201D);
  static const Color _lightText = Color(0xFF14110F);
  static const Color _darkText = Color(0xFFF5F2EF);
  static const Color _lightMuted = Color(0xFF6B6560);
  static const Color _darkMuted = Color(0xFFB9B2AC);
  static const Color _lightBorder = Color(0xFFEAEAEA);
  static const Color _darkBorder = Color(0xFF332F2B);
  static const Color _lightInput = Color(0xFFFFFFFF);
  static const Color _darkInput = Color(0xFF1F1B18);

  /// Page background.
  static Color get scaffold => isDark ? _darkScaffold : _lightScaffold;

  /// Cards, sheets, dialogs and anything that used to be plain white.
  static Color get card => isDark ? _darkCard : _lightCard;

  /// A quieter panel on top of a card (used to be light grey).
  static Color get cardAlt => isDark ? _darkCardAlt : _lightCardAlt;

  /// Main text and icons.
  static Color get text => isDark ? _darkText : _lightText;

  /// Secondary text.
  static Color get muted => isDark ? _darkMuted : _lightMuted;

  /// Dividers and outlines.
  static Color get border => isDark ? _darkBorder : _lightBorder;

  static Color get inputFill => isDark ? _darkInput : _lightInput;

  /// Dim layer behind sheets and dialogs.
  static Color get scrim => isDark ? const Color(0xB3000000) : const Color(0x66000000);

  /// Text/icon colour that is readable on the brand orange (always white).
  static const Color onBrand = Color(0xFFFFFFFF);

  /// Google Maps night style (standard JSON styling), used by every Google map when the app is dark.
  static const String googleDarkMapStyle = '[{"elementType":"geometry","stylers":[{"color":"#1d1b19"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#b9b2ac"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#1d1b19"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#262220"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f2a22"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#3a3531"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#5a4a3c"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#262220"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#0f1a24"}]}]';

  // ---------------------------------------------------------------- ThemeData
  /// The dark ThemeData shared by the rider and driver apps. Light themes keep their existing definitions
  /// so nothing changes for light-mode users.
  static ThemeData dark({required Color primary, String? fontFamily, PageTransitionsTheme? transitions}) {
    final scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: onBrand,
      secondary: primary,
      onSecondary: onBrand,
      surface: _darkCard,
      onSurface: _darkText,
      surfaceContainerHighest: _darkCardAlt,
      error: const Color(0xFFFF6B5E),
      outline: _darkBorder,
    );
    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      primaryColor: primary,
      scaffoldBackgroundColor: _darkScaffold,
      canvasColor: _darkScaffold,
      cardColor: _darkCard,
      dividerColor: _darkBorder,
      disabledColor: const Color(0xFF6E6862),
      unselectedWidgetColor: _darkMuted,
      fontFamily: fontFamily,
      iconTheme: const IconThemeData(color: _darkText),
      textTheme: ThemeData.dark().textTheme.apply(bodyColor: _darkText, displayColor: _darkText, fontFamily: fontFamily),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionHandleColor: primary,
        selectionColor: primary.withValues(alpha: 0.35),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF14110F),
        foregroundColor: _darkText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _darkText),
        systemOverlayStyle: SystemUiOverlayStyleLight.value,
      ),
      cardTheme: CardThemeData(color: _darkCard, surfaceTintColor: Colors.transparent, elevation: 0),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkCard,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: _darkText, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: fontFamily),
        contentTextStyle: TextStyle(color: _darkMuted, fontSize: 15, fontFamily: fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkCard,
        modalBackgroundColor: _darkCard,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0xB3000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkCard,
        selectedItemColor: Color(0xFFFF7A4D),
        unselectedItemColor: _darkMuted,
      ),
      listTileTheme: const ListTileThemeData(iconColor: _darkText, textColor: _darkText, tileColor: Colors.transparent),
      dividerTheme: const DividerThemeData(color: _darkBorder, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkInput,
        hintStyle: const TextStyle(color: Color(0xFF8C857F)),
        labelStyle: const TextStyle(color: _darkMuted),
        border: outline(_darkBorder),
        enabledBorder: outline(_darkBorder),
        focusedBorder: outline(primary, 1.5),
        errorBorder: outline(const Color(0xFFFF6B5E)),
        focusedErrorBorder: outline(const Color(0xFFFF6B5E), 1.5),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: _darkCardAlt, surfaceTintColor: Colors.transparent, textStyle: TextStyle(color: _darkText)),
      snackBarTheme: const SnackBarThemeData(backgroundColor: _darkCardAlt, contentTextStyle: TextStyle(color: _darkText)),
      tabBarTheme: const TabBarThemeData(labelColor: _darkText, unselectedLabelColor: _darkMuted, dividerColor: _darkBorder),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onBrand : const Color(0xFFB9B2AC)),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : const Color(0xFF3A3531)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(onBrand),
        side: const BorderSide(color: _darkMuted, width: 1.5),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : _darkMuted)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      pageTransitionsTheme: transitions ?? const PageTransitionsTheme(),
    );
  }
}

class SystemUiOverlayStyleLight {
  SystemUiOverlayStyleLight._();
  static const SystemUiOverlayStyle value = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );
}

class _PlatformWatcher with WidgetsBindingObserver {
  @override
  void didChangePlatformBrightness() {
    DropTheme.updatePlatform(ui.PlatformDispatcher.instance.platformBrightness);
  }
}

import 'package:flutter/foundation.dart';
import 'package:mighty_core/utils/core_enum.dart';
import 'package:mighty_core/utils/core_network_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/Constants.dart' show USER_ID;

const String ACTIVE_MODE_KEY = 'ACTIVE_MODE';
const String DRIVER_STATUS_KEY = 'DRIVER_STATUS';
const String USER_ROLES_KEY = 'USER_ROLES';

/// Single source of truth for rider/driver mode in the unified DROP app.
/// Rider is the default. The server decides who may be a driver; this class
/// only mirrors the answer (POST /mode) and tells the app root which shell to show.
class ModeController {
  ModeController._();

  /// 'rider' or 'driver'. The app root listens to this.
  static final ValueNotifier<String> mode = ValueNotifier<String>('rider');

  /// '' (never applied), draft, submitted, in_review, needs_changes, approved, rejected, suspended
  static String driverStatus = '';
  static List<String> roles = ['rider'];

  /// Set by the rider side so signing out of driver mode also signs out the rider shell.
  static Future<void> Function()? onSignedOut;

  static bool get isDriverApproved => driverStatus == 'approved';

  static Future<void> restore(SharedPreferences prefs) async {
    driverStatus = prefs.getString(DRIVER_STATUS_KEY) ?? '';
    roles = prefs.getStringList(USER_ROLES_KEY) ?? ['rider'];
    final saved = prefs.getString(ACTIVE_MODE_KEY) ?? 'rider';
    final loggedIn = prefs.getBool('IS_LOGGED_IN') ?? false;
    mode.value = (loggedIn && saved == 'driver' && isDriverApproved) ? 'driver' : 'rider';
  }

  /// Applies what the server says about the signed-in user (login, user-detail, POST /mode).
  static Future<void> applyUser(List<String>? userRoles, String? activeMode, String? status) async {
    final prefs = await SharedPreferences.getInstance();
    roles = (userRoles == null || userRoles.isEmpty) ? ['rider'] : userRoles;
    driverStatus = status ?? '';
    await prefs.setStringList(USER_ROLES_KEY, roles);
    await prefs.setString(DRIVER_STATUS_KEY, driverStatus);
    final next = (activeMode == 'driver' && isDriverApproved) ? 'driver' : 'rider';
    await prefs.setString(ACTIVE_MODE_KEY, next);
    mode.value = next;
  }

  /// Asks the server to switch mode. Returns null on success or a message to show the person.
  static Future<String?> switchTo(String target) async {
    try {
      final res = await parseModel<Map<String, dynamic>>(
        apiCall: executeRequest('mode', method: HttpMethods.POST, request: {'mode': target}),
        fromJson: (json) => Map<String, dynamic>.from(json as Map),
      );
      final data = res['data'];
      if (data is Map) {
        final r = data['roles'];
        await applyUser(r is List ? r.map((e) => e.toString()).toList() : null, data['active_mode']?.toString(), data['driver_status']?.toString());
      } else {
        return 'Could not switch mode. Please try again.';
      }
      return null;
    } catch (e) {
      final msg = e.toString();
      return msg.isEmpty ? 'Could not switch mode. Please try again.' : msg;
    }
  }

  /// Asks the server for the current roles and driver status (approval can change while the app is open).
  static Future<void> refreshFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(USER_ID);
      if (id == null || id == 0) return;
      final res = await parseModel<Map<String, dynamic>>(
        apiCall: executeRequest('user-detail?id=$id', method: HttpMethods.GET),
        fromJson: (json) => Map<String, dynamic>.from(json as Map),
      );
      final data = res['data'];
      if (data is Map) {
        final r = data['roles'];
        await applyUser(r is List ? r.map((e) => e.toString()).toList() : null, data['active_mode']?.toString(), data['driver_status']?.toString());
      }
    } catch (_) {}
  }

  /// Back to a clean passenger state after sign-out.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ACTIVE_MODE_KEY);
    await prefs.remove(DRIVER_STATUS_KEY);
    await prefs.remove(USER_ROLES_KEY);
    driverStatus = '';
    roles = ['rider'];
    await onSignedOut?.call();
    mode.value = 'rider';
  }
}

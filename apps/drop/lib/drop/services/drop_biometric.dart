import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint / face unlock for sign-in. The phone or username and password are kept in the
/// device's secure storage and only released after the biometric check succeeds.
class DropBiometric {
  DropBiometric._();

  static const FlutterSecureStorage _store = FlutterSecureStorage();
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _kId = 'drop_bio_identifier';
  static const String _kPw = 'drop_bio_password';

  /// True when the phone has a fingerprint or face enrolled.
  static Future<bool> deviceSupported() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final List<BiometricType> types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (e) {
      debugPrint('biometric check failed: $e');
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    try {
      return (await _store.read(key: _kId)) != null && (await _store.read(key: _kPw)) != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> enable({required String identifier, required String password}) async {
    await _store.write(key: _kId, value: identifier);
    await _store.write(key: _kPw, value: password);
  }

  static Future<void> disable() async {
    try {
      await _store.delete(key: _kId);
      await _store.delete(key: _kPw);
    } catch (_) {}
  }

  /// Asks for the fingerprint; on success returns the saved sign-in details, otherwise null.
  static Future<({String identifier, String password})?> unlock() async {
    try {
      final bool ok = await _auth.authenticate(
        localizedReason: 'Confirm it is you to log in to DROP',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!ok) return null;
      final String? id = await _store.read(key: _kId);
      final String? pw = await _store.read(key: _kPw);
      if (id == null || pw == null) return null;
      return (identifier: id, password: pw);
    } catch (e) {
      debugPrint('biometric unlock failed: $e');
      return null;
    }
  }
}

import 'package:onesignal_flutter/onesignal_flutter.dart';

/// All OneSignal calls live here. The App ID is not in the app: it is read from DROP's server
/// (Admin, Push notifications), so push can be switched on or changed without a new build.
class PushService {
  static bool _started = false;
  static void Function(String id)? _onRegistered;

  // Kept in a static so the observer is never garbage collected.
  static void _observer(OSPushSubscriptionChangedState state) => syncId();

  /// A real subscription id: not empty and not the temporary "local-..." id OneSignal uses before it registers.
  static bool isRealId(String? id) => id != null && id.isNotEmpty && !id.startsWith('local-');

  /// Starts OneSignal once. [onRegistered] gets the phone's subscription id as soon as it is real.
  /// Notification permission is NOT asked here: call [askPermission] once the person is signed in.
  static void start(String appId, {required void Function(OSNotificationClickEvent e) onClick, required void Function(String id) onRegistered}) {
    if (_started) return;
    _started = true;
    _onRegistered = onRegistered;
    OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    OneSignal.consentRequired(false);
    OneSignal.initialize(appId);
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();
      event.notification.display();
    });
    OneSignal.Notifications.addClickListener(onClick);
    OneSignal.User.pushSubscription.addObserver(_observer);
    syncId(); // the id may already exist, so do not wait for a change
  }

  /// Reports the current subscription id when it is real. Safe to call at any time, even before start().
  static void syncId() {
    if (!_started) return;
    try {
      final id = OneSignal.User.pushSubscription.id;
      if (isRealId(id)) _onRegistered?.call(id!);
    } catch (_) {}
  }

  /// Shows the system "allow notifications" prompt (once; the system remembers the answer).
  static Future<void> askPermission() async {
    if (!_started) return;
    try {
      await OneSignal.Notifications.requestPermission(true);
    } catch (_) {}
  }
}

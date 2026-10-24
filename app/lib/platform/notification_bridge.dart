import 'package:flutter/services.dart';

import '../data/alert.dart';

/// Talks to the native side (AlertNotifier.kt), which owns everything about
/// how a notification looks.
///
/// Notifications are drawn natively rather than from Dart because the FCM
/// service that will receive data messages runs without a Flutter engine;
/// keeping one renderer means the test buttons here show exactly what a real
/// push will.
class NotificationBridge {
  NotificationBridge({this.onOpened});

  static const _channel = MethodChannel('com.csenneff.notifier/notifications');

  /// Called with an alert id when the user taps one of our notifications
  /// while the app is already running.
  final void Function(String alertId)? onOpened;

  void attach() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') {
        onOpened?.call(call.arguments as String);
      }
    });
  }

  /// The alert id from the notification that launched the app, if any.
  Future<String?> initialAlertId() =>
      _channel.invokeMethod<String>('initialAlertId');

  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  /// Posts [alert] as a system notification, exactly as a push would.
  Future<void> show(Alert alert) => _channel.invokeMethod('show', {
    'id': alert.id,
    'system': alert.system,
    'level': alert.level.name,
    'title': alert.title,
  });
}

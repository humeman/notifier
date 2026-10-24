import 'package:flutter/services.dart';

import '../data/alert.dart';

/// Talks to the native side (AlertNotifier.kt, NotifierMessagingService.kt),
/// which owns FCM and everything about how a notification looks.
///
/// Notifications are drawn natively rather than from Dart because the FCM
/// service that receives data messages runs without a Flutter engine; keeping
/// one renderer means the test buttons here show exactly what a real push
/// will.
class NotificationBridge {
  NotificationBridge({this.onOpened, this.onReceived, this.onTokenChanged});

  static const _channel = MethodChannel('com.csenneff.notifier/notifications');

  /// The user tapped one of our notifications while the app was running.
  final void Function(String alertId)? onOpened;

  /// A push arrived while the app is in the foreground.
  final void Function(String alertId)? onReceived;

  /// FCM rotated this device's token.
  final void Function(String token)? onTokenChanged;

  void attach() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'opened':
          onOpened?.call(call.arguments as String);
        case 'received':
          onReceived?.call(call.arguments as String);
        case 'token':
          onTokenChanged?.call(call.arguments as String);
      }
    });
  }

  /// The alert id from the notification that launched the app, if any.
  Future<String?> initialAlertId() =>
      _channel.invokeMethod<String>('initialAlertId');

  /// This device's current FCM registration token.
  Future<String?> fcmToken() => _channel.invokeMethod<String>('fcmToken');

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

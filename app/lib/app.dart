import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'data/alert_repository.dart';
import 'data/api_alert_repository.dart';
import 'platform/notification_bridge.dart';
import 'state/alerts_controller.dart';
import 'theme/app_theme.dart';
import 'ui/pages/inbox_page.dart';

/// App root. Wires the controller and the native notification bridge, and
/// routes notification taps to the matching alert.
class NotifierApp extends StatefulWidget {
  const NotifierApp({super.key, this.repository});

  /// Injected by tests. Otherwise the API when configured at build time
  /// (see [AppConfig]), else mock data.
  final AlertRepository? repository;

  @override
  State<NotifierApp> createState() => _NotifierAppState();
}

class _NotifierAppState extends State<NotifierApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AlertsController _controller;
  late final NotificationBridge _bridge;

  @override
  void initState() {
    super.initState();
    _controller = AlertsController(
      repository:
          widget.repository ??
          (AppConfig.hasApi
              ? ApiAlertRepository(
                  baseUrl: AppConfig.apiUrl,
                  appKey: AppConfig.appKey,
                )
              : MockAlertRepository()),
    );
    _bridge = NotificationBridge(
      onOpened: _open,
      onReceived: (_) => _controller.refresh(),
      onTokenChanged: _controller.registerDevice,
    )..attach();
    unawaited(_start());
  }

  Future<void> _start() async {
    await _controller.refresh();
    final launchedFrom = await _bridge.initialAlertId().catchError((_) => null);
    if (launchedFrom != null) _open(launchedFrom);
    if (widget.repository == null && AppConfig.hasApi) {
      unawaited(_registerForPush());
    }
  }

  /// Asks for notification permission (a no-op once granted) and registers
  /// the current FCM token. Runs every launch, so a token that rotated while
  /// the app was closed gets picked up.
  Future<void> _registerForPush() async {
    try {
      await _bridge.requestPermission();
      final token = await _bridge.fcmToken();
      if (token != null) await _controller.registerDevice(token);
    } catch (e) {
      debugPrint('push registration failed: $e');
    }
  }

  void _open(String alertId) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    // Drop anything already pushed, so a tap always lands one level deep.
    Navigator.of(context).popUntil((route) => route.isFirst);
    openAlert(context, alertId);
    // Pushes that arrived while backgrounded aren't in the list yet. Marked
    // read first, so the refreshed list already reflects it.
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Providers wrap MaterialApp, not its home: pushed routes are siblings of
    // "/" under the Navigator, so a provider below `home` wouldn't reach them.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _controller),
        Provider.value(value: _bridge),
      ],
      child: MaterialApp(
        title: 'Notifier',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const InboxPage(),
      ),
    );
  }
}

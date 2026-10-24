import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/alert.dart';
import '../data/alert_repository.dart';

/// Inbox state: the loaded alerts plus the active filters.
class AlertsController extends ChangeNotifier {
  AlertsController({required this.repository});

  final AlertRepository repository;

  List<Alert> _alerts = const [];
  Object? _error;
  bool _loading = true;

  /// Full alerts (with descriptions) fetched for the detail page, by id.
  final Map<String, Alert> _details = {};

  /// Alerts marked read on this device. Applied over refreshed lists so a
  /// refresh racing the mark-read request can't flip one back to unread.
  final Set<String> _readHere = {};

  /// Null means "all levels".
  AlertLevel? _levelFilter;

  bool get loading => _loading;
  Object? get error => _error;
  AlertLevel? get levelFilter => _levelFilter;

  /// Alerts passing the current filter, most recent first.
  List<Alert> get visible => _levelFilter == null
      ? _alerts
      : _alerts.where((a) => a.level == _levelFilter).toList();

  int get unreadCount => _alerts.where((a) => !a.read).length;

  int countFor(AlertLevel level) =>
      _alerts.where((a) => a.level == level).length;

  Future<void> refresh() async {
    try {
      _alerts = [
        for (final a in await repository.list())
          _readHere.contains(a.id) && !a.read ? a.copyWith(read: true) : a,
      ];
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setLevelFilter(AlertLevel? level) {
    if (_levelFilter == level) return;
    _levelFilter = level;
    notifyListeners();
  }

  /// The best copy available: the full one if fetched, else the list's.
  Alert? byId(String id) {
    final detail = _details[id];
    for (final alert in _alerts) {
      if (alert.id == id) {
        // Read state lives on the list copy; keep it authoritative.
        return detail == null ? alert : detail.copyWith(read: alert.read);
      }
    }
    return detail;
  }

  /// Fetches [id] in full when the description is missing or the alert isn't
  /// in the list at all (e.g. opened from a push that arrived after the last
  /// refresh). Errors surface as a null result; the page shows what it has.
  Future<Alert?> loadDetail(String id) async {
    final known = byId(id);
    if (known != null && !known.needsDetail) return known;
    try {
      final full = await repository.get(id);
      if (full != null) {
        _details[id] = full;
        notifyListeners();
      }
      return full;
    } catch (e) {
      debugPrint('loading alert $id failed: $e');
      return known;
    }
  }

  /// Marks [id] read locally and in the API. The alert may not be in the list
  /// yet (opened from a push that arrived while the app was backgrounded), so
  /// the API call doesn't depend on finding it.
  void markRead(String id) {
    if (!_readHere.add(id)) return;
    final i = _alerts.indexWhere((a) => a.id == id);
    if (i >= 0) {
      if (_alerts[i].read) return;
      _alerts = [..._alerts]..[i] = _alerts[i].copyWith(read: true);
      notifyListeners();
    }
    unawaited(
      repository.markRead(id).catchError((Object e) {
        debugPrint('marking $id read failed: $e');
      }),
    );
  }

  /// Registers this device's FCM token. Called at every launch and whenever
  /// the token rotates; the API treats re-registration as an upsert.
  Future<void> registerDevice(String token) async {
    try {
      await repository.registerDevice(token);
    } catch (e) {
      debugPrint('device registration failed: $e');
    }
  }
}

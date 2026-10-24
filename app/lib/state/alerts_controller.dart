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
      _alerts = await repository.list();
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

  Alert? byId(String id) {
    for (final alert in _alerts) {
      if (alert.id == id) return alert;
    }
    return null;
  }

  /// Local only for now; the API will persist this once it exists.
  void markRead(String id) {
    final i = _alerts.indexWhere((a) => a.id == id);
    if (i < 0 || _alerts[i].read) return;
    _alerts = [..._alerts]..[i] = _alerts[i].copyWith(read: true);
    notifyListeners();
  }
}

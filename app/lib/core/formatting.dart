import 'package:intl/intl.dart';

/// Display formatting shared across screens.
abstract final class Fmt {
  static final _time = DateFormat('HH:mm');
  static final _weekday = DateFormat('EEEE');
  static final _date = DateFormat('MMM d');
  static final _full = DateFormat('EEE MMM d, yyyy · HH:mm:ss');

  /// Compact age for list rows: `now`, `4m`, `2h`, then the clock time for
  /// anything older than today (the day header already says which day).
  static String age(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final d = n.difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (_sameDay(t, n)) return '${d.inHours}h';
    return _time.format(t);
  }

  /// Header for a day group in the inbox.
  static String day(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    if (_sameDay(t, n)) return 'Today';
    if (_sameDay(t, n.subtract(const Duration(days: 1)))) return 'Yesterday';
    if (n.difference(t).inDays < 7) return _weekday.format(t);
    return _date.format(t);
  }

  static String full(DateTime t) => _full.format(t);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

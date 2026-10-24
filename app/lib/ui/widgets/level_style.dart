import 'package:flutter/material.dart';

import '../../data/alert.dart';
import '../../theme/palette.dart';

/// Color and icon per level, shared by every place a level is drawn so the
/// in-app badge matches the notification's small icon.
extension AlertLevelStyle on AlertLevel {
  Color get color => switch (this) {
    AlertLevel.info => Palette.accent,
    AlertLevel.warning => Palette.warning,
    AlertLevel.error => Palette.error,
  };

  IconData get icon => switch (this) {
    AlertLevel.info => Icons.notifications_rounded,
    AlertLevel.warning => Icons.warning_rounded,
    AlertLevel.error => Icons.report_rounded,
  };

  String get label => name.toUpperCase();
}

/// Rounded square with the level's icon on a faint wash of its color.
class LevelIcon extends StatelessWidget {
  const LevelIcon({super.key, required this.level, this.size = 36});

  final AlertLevel level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(level.icon, size: size * 0.55, color: level.color),
    );
  }
}

/// Small uppercase pill, e.g. `ERROR`.
class LevelChip extends StatelessWidget {
  const LevelChip({super.key, required this.level});

  final AlertLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: level.color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../data/alert.dart';
import '../../state/alerts_controller.dart';
import '../../theme/palette.dart';
import '../widgets/alert_row.dart';
import '../widgets/async_states.dart';
import '../widgets/level_style.dart';
import 'alert_detail_page.dart';
import 'test_page.dart';

/// Home screen: every alert, newest first, grouped by day, with a level filter.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AlertsController>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('ALERTS'),
            if (controller.unreadCount > 0) ...[
              const SizedBox(width: 10),
              _CountPill(count: controller.unreadCount),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Test notifications',
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const TestPage())),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(top: false, child: _body(context, controller)),
    );
  }

  Widget _body(BuildContext context, AlertsController controller) {
    if (controller.loading) return const LoadingState();
    if (controller.error != null) {
      return ErrorState(error: controller.error!, onRetry: controller.refresh);
    }

    final alerts = controller.visible;
    final children = <Widget>[
      _LevelFilterBar(controller: controller),
      if (alerts.isEmpty)
        const EmptyState(message: 'Nothing here. Quiet is good.', height: 240),
    ];

    String? currentDay;
    for (final alert in alerts) {
      final day = Fmt.day(alert.receivedAt);
      if (day != currentDay) {
        currentDay = day;
        children.add(_DayHeader(label: day));
      }
      children.add(
        AlertRow(alert: alert, onTap: () => openAlert(context, alert.id)),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      color: Palette.accent,
      backgroundColor: Palette.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: children,
      ),
    );
  }
}

/// Pushes the detail page for [id] and marks it read. Shared with the
/// notification-tap handler so both routes behave the same.
void openAlert(BuildContext context, String id) {
  context.read<AlertsController>().markRead(id);
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => AlertDetailPage(alertId: id)));
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Palette.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Palette.accent,
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

/// All / Info / Warning / Error, each with its count.
class _LevelFilterBar extends StatelessWidget {
  const _LevelFilterBar({required this.controller});

  final AlertsController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.levelFilter;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _FilterChip(
            label: 'ALL',
            color: Palette.accent,
            selected: selected == null,
            onTap: () => controller.setLevelFilter(null),
          ),
          for (final level in AlertLevel.values) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: level.label,
              icon: level.icon,
              count: controller.countFor(level),
              color: level.color,
              selected: selected == level,
              onTap: () =>
                  controller.setLevelFilter(selected == level ? null : level),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? color : Palette.textMuted;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? color.withValues(alpha: 0.4) : Palette.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: fg,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

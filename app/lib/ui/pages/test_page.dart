import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/alert.dart';
import '../../platform/notification_bridge.dart';
import '../../state/alerts_controller.dart';
import '../../theme/palette.dart';
import '../widgets/level_style.dart';
import '../widgets/section.dart';

/// Fires local notifications built from the mock alerts, one per level, so the
/// notification styling can be checked without the backend.
class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bridge = context.read<NotificationBridge>();
    final alerts = context.read<AlertsController>().visible;
    final theme = Theme.of(context);

    Alert sampleFor(AlertLevel level) => alerts.firstWhere(
      (a) => a.level == level,
      orElse: () => Alert(
        id: 'test-${level.name}',
        system: 'test',
        level: level,
        title: 'Test ${level.name} notification',
        receivedAt: DateTime.now(),
      ),
    );

    Future<void> send(List<AlertLevel> levels) async {
      if (!await bridge.requestPermission()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission denied')),
        );
        return;
      }
      for (final level in levels) {
        await bridge.show(sampleFor(level));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TEST NOTIFICATIONS'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListView(
        children: [
          Section(
            title: 'Send one',
            subtitle:
                'Posts a local notification through the same native code '
                'path a push will use.',
            child: Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final level in AlertLevel.values)
                    ListTile(
                      leading: LevelIcon(level: level, size: 32),
                      title: Text(
                        level.label,
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        sampleFor(level).title,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(
                        Icons.send_rounded,
                        size: 16,
                        color: Palette.accent,
                      ),
                      onTap: () => send([level]),
                    ),
                ],
              ),
            ),
          ),
          Section(
            title: 'Send all',
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => send(AlertLevel.values),
                style: TextButton.styleFrom(
                  foregroundColor: Palette.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Palette.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Palette.border),
                  ),
                ),
                child: const Text('SEND ONE OF EACH LEVEL'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

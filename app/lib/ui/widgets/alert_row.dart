import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../data/alert.dart';
import '../../theme/palette.dart';
import 'level_style.dart';

/// One inbox row: level icon, system + age, title, and an unread dot.
class AlertRow extends StatelessWidget {
  const AlertRow({super.key, required this.alert, required this.onTap});

  final Alert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !alert.read;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LevelIcon(level: alert.level),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.system.toUpperCase(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: unread ? Palette.text : Palette.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        Fmt.age(alert.receivedAt),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Palette.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unread ? Palette.text : Palette.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (alert.description != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.subject_rounded,
                          size: 12,
                          color: Palette.textFaint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'details',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Palette.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

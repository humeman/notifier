import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../data/alert.dart';
import '../../state/alerts_controller.dart';
import '../../theme/palette.dart';
import '../widgets/async_states.dart';
import '../widgets/level_style.dart';
import '../widgets/section.dart';

/// Full view of one alert, including its description (logs, traces) in a
/// selectable, horizontally scrollable code block.
class AlertDetailPage extends StatefulWidget {
  const AlertDetailPage({super.key, required this.alertId});

  final String alertId;

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  /// True until the full alert (with description) has been fetched, or it's
  /// known there's nothing more to fetch.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    context.read<AlertsController>().loadDetail(widget.alertId).whenComplete(
      () {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final alert = context.select<AlertsController, Alert?>(
      (c) => c.byId(widget.alertId),
    );
    final theme = Theme.of(context);

    if (alert == null && _loading) {
      return const Scaffold(body: LoadingState());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(alert == null ? 'ALERT' : alert.system.toUpperCase()),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: alert == null
          ? const EmptyState(message: 'Alert not found.', height: 240)
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            LevelIcon(level: alert.level, size: 28),
                            const SizedBox(width: 10),
                            LevelChip(level: alert.level),
                            const Spacer(),
                            Text(
                              Fmt.age(alert.receivedAt),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          alert.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Fmt.full(alert.receivedAt),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Section(
                    title: 'Details',
                    trailing: alert.description == null
                        ? null
                        : _CopyButton(text: alert.description!),
                    child: alert.description == null
                        ? Text(
                            alert.hasDescription
                                ? (_loading
                                      ? 'Loading details…'
                                      : 'Could not load details.')
                                : 'No description was sent with this alert.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Palette.textFaint,
                            ),
                          )
                        : _CodeBlock(text: alert.description!),
                  ),
                  Section(
                    title: 'Metadata',
                    child: Panel(
                      child: Column(
                        children: [
                          _MetaRow(label: 'System', value: alert.system),
                          _MetaRow(label: 'Level', value: alert.level.name),
                          _MetaRow(label: 'ID', value: alert.id),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Monospace block that keeps log lines unwrapped and scrolls sideways
/// instead, since wrapped stack traces are hard to read.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(14),
        child: SelectableText(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Palette.text, fontSize: 11, height: 1.55),
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Copied details')));
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, size: 12, color: Palette.accent),
            SizedBox(width: 4),
            Text('COPY', style: TextStyle(color: Palette.accent, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label.toUpperCase(), style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

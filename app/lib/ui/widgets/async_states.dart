import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// Full-page loading state.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message = 'Loading'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Full-page error state with the failure text and a retry affordance.
///
/// The message is shown verbatim because the failures that actually occur here
/// — a missing key, a missing IAM grant — are ones the exact text tells you how
/// to fix.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Palette.error, size: 16),
                const SizedBox(width: 8),
                Text(
                  'COULD NOT LOAD',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Palette.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              '$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Palette.textMuted,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: Palette.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  backgroundColor: Palette.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Palette.border),
                  ),
                ),
                child: const Text('RETRY', style: TextStyle(fontSize: 11)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline "nothing here" message for a section that loaded but has no rows.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.height = 80});

  final String message;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

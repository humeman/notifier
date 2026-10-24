import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// A titled block: uppercase label, optional trailing widget, then content.
///
/// Every page is a stack of these, which is what gives the tabs a shared
/// rhythm without any per-page layout code.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 0),
  });

  final String title;
  final Widget child;

  /// Right-aligned accessory, e.g. a count or total.
  final Widget? trailing;

  /// Small explanatory line under the title.
  final String? subtitle;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (trailing != null)
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodySmall!,
                  child: trailing!,
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A bordered surface panel. The default container for charts and tables.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.border),
      ),
      child: child,
    );
  }
}

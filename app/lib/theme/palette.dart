import 'package:flutter/material.dart';

/// Monochrome dark palette with a single accent used for emphasis.
///
/// Everything structural is a neutral gray; color is reserved for meaning
/// (alert levels, the active filter, focus). Keeping the set small is what
/// makes new screens look like they belong without effort.
abstract final class Palette {
  /// App background, behind all scrollables.
  static const background = Color(0xFF0A0A0B);

  /// Cards and elevated blocks sitting on [background].
  static const surface = Color(0xFF121215);

  /// Pressed state, code blocks, chip fills.
  static const surfaceHigh = Color(0xFF1B1B1F);

  /// Hairlines and card borders.
  static const border = Color(0xFF26262B);

  /// Primary reading color.
  static const text = Color(0xFFEDEDF0);

  /// Labels, timestamps, secondary metadata.
  static const textMuted = Color(0xFF8B8B95);

  /// Read alerts and disabled controls.
  static const textFaint = Color(0xFF4E4E57);

  /// The one highlight color: selected filters, unread dots, focus. Also the
  /// Info level, which is "nothing special" and so takes the app's own color.
  static const accent = Color(0xFF7CC8FF);

  /// Warning level.
  static const warning = Color(0xFFFFC24B);

  /// Error level.
  static const error = Color(0xFFFF6B6B);
}

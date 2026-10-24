/// How loudly an alert announces itself. Drives the notification channel,
/// icon, and title prefix, and the badge color in the app.
enum AlertLevel {
  info,
  warning,
  error;

  /// Parses the wire value, falling back to [info] — the API's default — for
  /// anything missing or unrecognized.
  static AlertLevel parse(String? value) => switch (value?.toLowerCase()) {
    'warning' => warning,
    'error' => error,
    _ => info,
  };

  /// Prefix shown before the system name in the notification title. Info is
  /// deliberately undecorated.
  String? get titlePrefix => switch (this) {
    info => null,
    warning => 'Warning',
    error => 'Error',
  };
}

/// One alert sent by a system.
class Alert {
  const Alert({
    required this.id,
    required this.system,
    required this.level,
    required this.title,
    required this.receivedAt,
    this.description,
    this.read = false,
  });

  final String id;

  /// Resolved server-side from the sender's key; never sent by the system.
  final String system;
  final AlertLevel level;

  /// Short summary, shown as the notification body.
  final String title;

  /// Optional long-form detail (logs, stack traces), only shown in the app.
  final String? description;
  final DateTime receivedAt;
  final bool read;

  Alert copyWith({bool? read}) => Alert(
    id: id,
    system: system,
    level: level,
    title: title,
    description: description,
    receivedAt: receivedAt,
    read: read ?? this.read,
  );
}

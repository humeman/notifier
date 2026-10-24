import 'alert.dart';

/// Where alerts come from. The real implementation talks to the notifier
/// function; [MockAlertRepository] stands in until that exists.
abstract interface class AlertRepository {
  /// Most recent first.
  Future<List<Alert>> list();

  Future<Alert?> get(String id);
}

/// Canned alerts covering every level, with and without descriptions, spread
/// over a few days so the inbox's day grouping has something to show.
class MockAlertRepository implements AlertRepository {
  MockAlertRepository({DateTime? now}) : _alerts = _seed(now ?? DateTime.now());

  final List<Alert> _alerts;

  @override
  Future<List<Alert>> list() async => List.unmodifiable(_alerts);

  @override
  Future<Alert?> get(String id) async {
    for (final alert in _alerts) {
      if (alert.id == id) return alert;
    }
    return null;
  }

  static List<Alert> _seed(DateTime now) => [
    Alert(
      id: 'a1',
      system: 'homelab',
      level: AlertLevel.error,
      title: 'Service jellyfin.service has failed',
      receivedAt: now.subtract(const Duration(minutes: 4)),
      description: _jellyfinLog,
    ),
    Alert(
      id: 'a2',
      system: 'backups',
      level: AlertLevel.warning,
      title: 'Nightly snapshot took 3h 12m (budget 2h)',
      receivedAt: now.subtract(const Duration(hours: 2, minutes: 15)),
      description:
          'restic backup finished, but well over its time budget.\n\n'
          'Files:        412,983 new, 1,204 changed, 9,812,331 unmodified\n'
          'Added to the repository: 48.213 GiB (47.902 GiB stored)\n'
          'processed 9,826,518 files, 2.114 TiB in 3:12:07\n\n'
          'Likely cause: the photo library import on the NAS.',
    ),
    Alert(
      id: 'a3',
      system: 'financials',
      level: AlertLevel.info,
      title: 'Weekly budget report is ready',
      receivedAt: now.subtract(const Duration(hours: 5)),
      read: true,
    ),
    Alert(
      id: 'a4',
      system: 'homelab',
      level: AlertLevel.info,
      title: 'Task: rotate the Cloudflare API token before Nov 1',
      receivedAt: now.subtract(const Duration(days: 1, hours: 3)),
      description:
          'The token used by the DNS updater expires on 2026-11-01.\n'
          'Create a new one scoped to Zone.DNS:Edit and update the secret.',
      read: true,
    ),
    Alert(
      id: 'a5',
      system: 'ci',
      level: AlertLevel.error,
      title: 'terraform apply failed on csenneff-prod',
      receivedAt: now.subtract(const Duration(days: 1, hours: 9)),
      description:
          'Error: Error creating Secret: googleapi: Error 403: Permission '
          "'secretmanager.secrets.create' denied on resource "
          "'projects/csenneff-prod' (or it may not exist).\n\n"
          '  with module.financials.google_secret_manager_secret.api_key,\n'
          '  on ../../modules/financials/secret_manager.tf line 1',
      read: true,
    ),
    Alert(
      id: 'a6',
      system: 'backups',
      level: AlertLevel.warning,
      title: 'Disk /mnt/deepstorage is 91% full',
      receivedAt: now.subtract(const Duration(days: 3, hours: 1)),
      read: true,
    ),
  ];
}

const _jellyfinLog = '''× jellyfin.service - Jellyfin Media Server
     Loaded: loaded (/usr/lib/systemd/system/jellyfin.service; enabled)
     Active: failed (Result: exit-code) since Sat 2026-10-24 09:41:12 CDT
    Process: 48211 ExecStart=/usr/bin/jellyfin (code=exited, status=134)
   Main PID: 48211 (code=exited, status=134)
        CPU: 2.418s

Oct 24 09:41:09 nas jellyfin[48211]: [09:41:09] [INF] Loading assemblies
Oct 24 09:41:11 nas jellyfin[48211]: [09:41:11] [ERR] Error opening database
Oct 24 09:41:11 nas jellyfin[48211]: Microsoft.Data.Sqlite.SqliteException (0x80004005): SQLite Error 11: 'database disk image is malformed'.
Oct 24 09:41:11 nas jellyfin[48211]:    at Microsoft.Data.Sqlite.SqliteException.ThrowExceptionForRC(Int32 rc, sqlite3 db)
Oct 24 09:41:11 nas jellyfin[48211]:    at Microsoft.Data.Sqlite.SqliteDataReader.NextResult()
Oct 24 09:41:11 nas jellyfin[48211]:    at Jellyfin.Server.Migrations.MigrationRunner.Run(IApplicationHost host)
Oct 24 09:41:12 nas systemd[1]: jellyfin.service: Main process exited, code=exited, status=134/n/a
Oct 24 09:41:12 nas systemd[1]: jellyfin.service: Failed with result 'exit-code'.
Oct 24 09:41:12 nas systemd[1]: jellyfin.service: Start request repeated too quickly.''';

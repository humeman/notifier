import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifier/app.dart';
import 'package:notifier/core/formatting.dart';
import 'package:notifier/data/alert.dart';
import 'package:notifier/data/alert_repository.dart';
import 'package:notifier/state/alerts_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The native side isn't there under test; answer the launch query with
  // "not opened from a notification".
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.csenneff.notifier/notifications'),
          (call) async => null,
        );
  });

  group('AlertLevel.parse', () {
    test('defaults to info', () {
      expect(AlertLevel.parse(null), AlertLevel.info);
      expect(AlertLevel.parse('bogus'), AlertLevel.info);
    });

    test('is case-insensitive', () {
      expect(AlertLevel.parse('ERROR'), AlertLevel.error);
      expect(AlertLevel.parse('Warning'), AlertLevel.warning);
    });

    test('only warning and error get a title prefix', () {
      expect(AlertLevel.info.titlePrefix, isNull);
      expect(AlertLevel.warning.titlePrefix, 'Warning');
      expect(AlertLevel.error.titlePrefix, 'Error');
    });
  });

  group('AlertsController', () {
    test('filters by level and tracks unread', () async {
      final c = AlertsController(repository: MockAlertRepository());
      await c.refresh();
      final total = c.visible.length;
      final unread = c.unreadCount;

      c.setLevelFilter(AlertLevel.error);
      expect(
        c.visible,
        everyElement(
          isA<Alert>().having((a) => a.level, 'level', AlertLevel.error),
        ),
      );
      expect(c.visible.length, c.countFor(AlertLevel.error));

      c.setLevelFilter(null);
      expect(c.visible.length, total);

      final first = c.visible.firstWhere((a) => !a.read);
      c.markRead(first.id);
      expect(c.unreadCount, unread - 1);
      expect(c.byId(first.id)!.read, isTrue);
    });
  });

  group('Fmt', () {
    final now = DateTime(2026, 10, 24, 12);

    test('age', () {
      expect(Fmt.age(now, now: now), 'now');
      expect(Fmt.age(now.subtract(const Duration(minutes: 4)), now: now), '4m');
      expect(Fmt.age(now.subtract(const Duration(hours: 2)), now: now), '2h');
      expect(Fmt.age(DateTime(2026, 10, 23, 9, 5), now: now), '09:05');
    });

    test('day', () {
      expect(Fmt.day(now, now: now), 'Today');
      expect(Fmt.day(DateTime(2026, 10, 23), now: now), 'Yesterday');
      expect(Fmt.day(DateTime(2026, 10, 21), now: now), 'Wednesday');
      expect(Fmt.day(DateTime(2026, 9, 1), now: now), 'Sep 1');
    });
  });

  testWidgets('inbox lists alerts and opens details', (tester) async {
    await tester.pumpWidget(NotifierApp(repository: MockAlertRepository()));
    await tester.pumpAndSettle();

    expect(find.text('ALERTS'), findsOneWidget);
    expect(find.text('Service jellyfin.service has failed'), findsOneWidget);

    await tester.tap(find.text('Service jellyfin.service has failed'));
    await tester.pumpAndSettle();

    expect(find.text('HOMELAB'), findsOneWidget);
    expect(find.text('DETAILS'), findsOneWidget);
    expect(
      find.textContaining('database disk image is malformed'),
      findsOneWidget,
    );
  });
}

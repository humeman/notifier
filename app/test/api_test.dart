import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notifier/data/alert.dart';
import 'package:notifier/data/api_alert_repository.dart';
import 'package:notifier/data/alert_repository.dart';
import 'package:notifier/state/alerts_controller.dart';

const _summary = {
  'id': 'abc',
  'system': 'homelab',
  'level': 'error',
  'title': 'Service has failed',
  'received_at': '2026-10-24T16:41:15.209335Z',
  'read': false,
  'has_description': true,
};

void main() {
  late List<http.Request> requests;

  ApiAlertRepository repo(http.Response Function(http.Request) handler) {
    requests = [];
    return ApiAlertRepository(
      baseUrl: 'https://example.test/notifier',
      appKey: 'k',
      client: MockClient((req) async {
        requests.add(req);
        return handler(req);
      }),
    );
  }

  test('list parses summaries and sends the app key', () async {
    final r = repo(
      (_) => http.Response(
        jsonEncode({
          'alerts': [_summary],
          'next_before': null,
        }),
        200,
      ),
    );
    final alerts = await r.list();

    expect(
      requests.single.url.toString(),
      'https://example.test/notifier/v1/alerts?limit=100',
    );
    expect(requests.single.headers['Authorization'], 'Bearer k');
    final a = alerts.single;
    expect(a.level, AlertLevel.error);
    expect(a.hasDescription, isTrue);
    expect(a.needsDetail, isTrue);
    expect(a.receivedAt.isUtc, isFalse);
  });

  test('get returns null on 404 and the full alert otherwise', () async {
    final missing = repo((_) => http.Response('{"error":"not found"}', 404));
    expect(await missing.get('nope'), isNull);

    final found = repo(
      (_) => http.Response(
        jsonEncode(
          {..._summary, 'description': 'log'}..remove('has_description'),
        ),
        200,
      ),
    );
    final a = (await found.get('abc'))!;
    expect(a.description, 'log');
    expect(a.needsDetail, isFalse);
  });

  test('errors carry the API message', () async {
    final r = repo(
      (_) => http.Response('{"error":"invalid or missing key"}', 401),
    );
    expect(
      r.list(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.message, 'message', 'invalid or missing key'),
      ),
    );
  });

  test('registerDevice and markRead POST JSON', () async {
    final r = repo((_) => http.Response('{}', 200));
    await r.registerDevice('tok');
    await r.markRead('abc');

    expect(requests[0].url.path, '/notifier/v1/devices');
    expect(jsonDecode(requests[0].body), {'token': 'tok'});
    expect(requests[1].url.path, '/notifier/v1/alerts/abc/read');
  });

  test('controller fetches descriptions on demand', () async {
    final r = repo(
      (req) => req.url.path.endsWith('/v1/alerts')
          ? http.Response(
              jsonEncode({
                'alerts': [_summary],
              }),
              200,
            )
          : http.Response(
              jsonEncode(
                {..._summary, 'description': 'full log'}
                  ..remove('has_description'),
              ),
              200,
            ),
    );
    final AlertRepository asRepo = r;
    final c = AlertsController(repository: asRepo);
    await c.refresh();
    expect(c.byId('abc')!.description, isNull);

    await c.loadDetail('abc');
    expect(c.byId('abc')!.description, 'full log');

    c.markRead('abc');
    expect(c.byId('abc')!.read, isTrue);
  });
}

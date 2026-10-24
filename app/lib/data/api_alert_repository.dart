import 'dart:convert';

import 'package:http/http.dart' as http;

import 'alert.dart';
import 'alert_repository.dart';

/// Talks to the notifier function's app endpoints (`/v1/alerts`,
/// `/v1/devices`) with the app key.
class ApiAlertRepository implements AlertRepository {
  ApiAlertRepository({
    required String baseUrl,
    required String appKey,
    http.Client? client,
  }) : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _headers = {
         'Authorization': 'Bearer $appKey',
         'Content-Type': 'application/json',
       },
       _client = client ?? http.Client();

  final Uri _base;
  final Map<String, String> _headers;
  final http.Client _client;

  /// The inbox shows the most recent page; older alerts age out server-side
  /// after 90 days anyway.
  static const pageSize = 100;

  @override
  Future<List<Alert>> list() async {
    final body = await _get('v1/alerts', {'limit': '$pageSize'});
    return [
      for (final item in body!['alerts'] as List)
        Alert.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<Alert?> get(String id) async {
    final body = await _get('v1/alerts/${Uri.encodeComponent(id)}');
    return body == null ? null : Alert.fromJson(body);
  }

  @override
  Future<void> markRead(String id) =>
      _post('v1/alerts/${Uri.encodeComponent(id)}/read', {});

  @override
  Future<void> registerDevice(String token) =>
      _post('v1/devices', {'token': token});

  /// Returns null on 404.
  Future<Map<String, dynamic>?> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = _base.resolve(path).replace(queryParameters: query);
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode == 404) return null;
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final res = await _client.post(
      _base.resolve(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    _check(res);
  }

  void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String message;
    try {
      message = (jsonDecode(res.body) as Map)['error'] as String;
    } catch (_) {
      message = res.reasonPhrase ?? 'request failed';
    }
    throw ApiException(res.statusCode, message);
  }
}

class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'Notifier API error $status: $message';
}

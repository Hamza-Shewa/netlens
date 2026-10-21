import 'dart:convert' show JsonEncoder, jsonDecode;

import 'package:netlens/mock/data/netlens_mock_importer.dart';
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_response.dart';

/// Reads and writes mocks in the NetLens mocks format, a JSON document which
/// can be edited by hand, kept next to tests or loaded from app assets:
///
/// ```json
/// {
///   "netlensMocks": 1,
///   "mocks": [
///     {
///       "method": "GET",
///       "url": "https://api.example.com/users/*",
///       "response": {"status": 200, "body": "[]"}
///     }
///   ]
/// }
/// ```
///
/// Only `method`, `url` and `response.status` are required.
class NetLensMockJsonCodec implements NetLensMockImporter {
  const NetLensMockJsonCodec();

  /// Version of the format written by [encode].
  static const int version = 1;

  static const String _versionKey = 'netlensMocks';
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Returns [mocks] as a JSON document.
  String encode(List<NetLensMock> mocks) => _encoder.convert({
    _versionKey: version,
    'mocks': [for (final NetLensMock mock in mocks) _encodeMock(mock)],
  });

  /// Returns mocks of a JSON document written by [encode].
  List<NetLensMock> decode(String content) => import(jsonDecode(content));

  @override
  bool canImport(Object? json) => json is Map && json.containsKey(_versionKey);

  @override
  List<NetLensMock> import(Object? json) {
    if (!canImport(json)) {
      throw const FormatException('Not a NetLens mocks document.');
    }
    final Map<dynamic, dynamic> document = json! as Map;
    final Object? version = document[_versionKey];
    if (version is! int || version > NetLensMockJsonCodec.version) {
      throw FormatException('Unsupported NetLens mocks version: $version.');
    }
    final List<dynamic> mocks = document['mocks'] as List<dynamic>? ?? const [];
    return [
      for (final dynamic mock in mocks)
        _decodeMock(mock as Map<String, dynamic>),
    ];
  }

  Map<String, dynamic> _encodeMock(NetLensMock mock) => {
    'id': mock.id,
    'method': mock.method,
    'url': mock.url.toString(),
    if (mock.requestBody != null) 'requestBody': mock.requestBody,
    if (!mock.enabled) 'enabled': false,
    'createdTime': mock.createdTime.toUtc().toIso8601String(),
    'response': {
      'status': mock.response.status,
      'headers': mock.response.headers,
      'body': mock.response.body,
      if (mock.response.bodyEncoding != NetLensMockBodyEncoding.text)
        'bodyEncoding': mock.response.bodyEncoding.name,
      'delayMs': mock.response.delay.inMilliseconds,
    },
  };

  NetLensMock _decodeMock(Map<String, dynamic> json) {
    final Map<String, dynamic> response =
        json['response'] as Map<String, dynamic>? ?? const {};
    final Map<String, dynamic> headers =
        response['headers'] as Map<String, dynamic>? ?? const {};
    return NetLensMock(
      id: '${json['id'] ?? ''}',
      method: '${json['method'] ?? 'GET'}'.toUpperCase(),
      url: Uri.parse('${json['url'] ?? '/'}'),
      requestBody: json['requestBody'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      createdTime:
          DateTime.tryParse('${json['createdTime']}')?.toLocal() ??
          DateTime.now(),
      response: NetLensMockResponse(
        status: response['status'] as int? ?? 200,
        headers: {
          for (final MapEntry<String, dynamic> header in headers.entries)
            header.key.toLowerCase(): '${header.value}',
        },
        body: _decodeBody(response['body']),
        bodyEncoding: NetLensMockBodyEncoding.values.firstWhere(
          (NetLensMockBodyEncoding encoding) =>
              encoding.name == response['bodyEncoding'],
          orElse: () => NetLensMockBodyEncoding.text,
        ),
        delay: Duration(milliseconds: response['delayMs'] as int? ?? 0),
      ),
    );
  }

  /// A body written by hand may be JSON instead of text which holds JSON.
  String _decodeBody(Object? body) => switch (body) {
    null => '',
    String text => text,
    _ => const JsonEncoder().convert(body),
  };
}

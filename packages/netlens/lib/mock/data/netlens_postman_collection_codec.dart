import 'dart:convert' show JsonEncoder, jsonDecode;

import 'package:netlens/core/netlens_http_status.dart';
import 'package:netlens/mock/data/netlens_mock_headers.dart';
import 'package:netlens/mock/data/netlens_mock_importer.dart';
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_response.dart';

/// Reads and writes mocks as a Postman collection (v2.1), which Postman,
/// Insomnia, Bruno and other API clients can import. Each mock becomes a
/// request with its response saved as an example, so the collection can also
/// back a Postman mock server. Requests are grouped in a folder per host.
///
/// Binary response bodies can't be stored in a collection, so their examples
/// have an empty body.
class NetLensPostmanCollectionCodec implements NetLensMockImporter {
  const NetLensPostmanCollectionCodec();

  /// Schema of the format written by [encode].
  static const String schema =
      'https://schema.getpostman.com/json/collection/v2.1.0/collection.json';

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Returns [mocks] as a collection named [name].
  String encode(List<NetLensMock> mocks, {String name = 'NetLens'}) {
    final Map<String, List<NetLensMock>> byHost = {};
    for (final NetLensMock mock in mocks) {
      byHost.putIfAbsent(mock.url.host, () => []).add(mock);
    }
    return _encoder.convert({
      'info': {'name': name, 'schema': schema},
      'item': [
        for (final MapEntry<String, List<NetLensMock>> host in byHost.entries)
          {
            'name': host.key.isEmpty ? name : host.key,
            'item': [
              for (final NetLensMock mock in host.value) _encodeItem(mock),
            ],
          },
      ],
    });
  }

  /// Returns mocks of a collection written by [encode] or by an API client.
  List<NetLensMock> decode(String content) => import(jsonDecode(content));

  @override
  bool canImport(Object? json) =>
      json is Map &&
      json['info'] is Map &&
      json['item'] is List &&
      '${json['info']['schema']}'.contains('schema.getpostman.com');

  @override
  List<NetLensMock> import(Object? json) {
    if (!canImport(json)) {
      throw const FormatException('Not a Postman collection.');
    }
    final List<NetLensMock> mocks = [];
    _importItems((json! as Map)['item'] as List<dynamic>, mocks);
    return mocks;
  }

  Map<String, dynamic> _encodeItem(NetLensMock mock) {
    final String path = mock.url.path.isEmpty ? '/' : mock.url.path;
    final Map<String, dynamic> request = _encodeRequest(mock);
    final NetLensMockResponse response = mock.response;
    final bool isText = response.bodyEncoding == NetLensMockBodyEncoding.text;
    return {
      'name': '${mock.method} $path',
      'request': request,
      'response': [
        {
          'name': '${response.status} ${_getReason(response.status)}'.trim(),
          'originalRequest': request,
          'status': _getReason(response.status),
          'code': response.status,
          '_postman_previewlanguage': _isJson(response.headers['content-type'])
              ? 'json'
              : 'text',
          'header': [
            for (final MapEntry<String, String> header
                in response.headers.entries)
              if (header.key != NetLensMockResponse.mockHeader)
                {'key': header.key, 'value': header.value},
          ],
          'body': isText ? response.body : '',
        },
      ],
    };
  }

  Map<String, dynamic> _encodeRequest(NetLensMock mock) {
    final String? body = mock.requestBody;
    final String? contentType = mock.requestHeaders.entries
        .where(
          (MapEntry<String, String> header) =>
              header.key.toLowerCase() == 'content-type',
        )
        .map((MapEntry<String, String> header) => header.value)
        .firstOrNull;
    return {
      'method': mock.method,
      'header': [
        for (final MapEntry<String, String> header
            in mock.requestHeaders.entries)
          {'key': header.key, 'value': header.value},
      ],
      if (body != null)
        'body': {
          'mode': 'raw',
          'raw': body,
          if (_isJson(contentType))
            'options': {
              'raw': {'language': 'json'},
            },
        },
      'url': _encodeUrl(mock.url),
    };
  }

  Map<String, dynamic> _encodeUrl(Uri url) => {
    'raw': url.toString(),
    if (url.hasScheme) 'protocol': url.scheme,
    if (url.host.isNotEmpty) 'host': url.host.split('.'),
    if (url.hasPort) 'port': '${url.port}',
    'path': url.pathSegments,
    if (url.hasQuery)
      'query': [
        for (final MapEntry<String, List<String>> parameter
            in url.queryParametersAll.entries)
          for (final String value in parameter.value)
            {'key': parameter.key, 'value': value},
      ],
  };

  /// Adds mocks of [items] to [mocks]. Folders are read recursively; each
  /// saved example of a request becomes a mock.
  void _importItems(List<dynamic> items, List<NetLensMock> mocks) {
    for (final dynamic item in items) {
      if (item is! Map) {
        continue;
      }
      if (item['item'] is List) {
        _importItems(item['item'] as List<dynamic>, mocks);
        continue;
      }
      for (final dynamic example
          in item['response'] as List<dynamic>? ?? const []) {
        if (example is! Map) {
          continue;
        }
        final NetLensMock? mock = _importExample(
          example['originalRequest'] as Map? ?? item['request'] as Map?,
          example,
        );
        if (mock != null) {
          mocks.add(mock);
        }
      }
    }
  }

  NetLensMock? _importExample(Map<dynamic, dynamic>? request, Map example) {
    final int status = example['code'] as int? ?? 0;
    final Uri? url = _decodeUrl(request?['url']);
    if (request == null || status <= 0 || url == null || !url.hasAuthority) {
      return null;
    }
    final Map<dynamic, dynamic>? body = request['body'] as Map?;
    final String? requestBody = body?['mode'] == 'raw'
        ? body!['raw'] as String?
        : null;
    return NetLensMock(
      id: '',
      method: '${request['method'] ?? 'GET'}'.toUpperCase(),
      url: url,
      requestBody: requestBody == null || requestBody.isEmpty
          ? null
          : requestBody,
      requestHeaders: _decodeHeaders(request['header']),
      createdTime: DateTime.now(),
      response: NetLensMockResponse(
        status: status,
        headers: NetLensMockHeaders.normalize(
          _decodeHeaders(example['header']),
        ),
        body: '${example['body'] ?? ''}',
      ),
    );
  }

  Uri? _decodeUrl(Object? url) {
    if (url is String) {
      return Uri.tryParse(url);
    }
    if (url is! Map) {
      return null;
    }
    if (url['raw'] is String) {
      return Uri.tryParse(url['raw'] as String);
    }
    final Object? host = url['host'];
    final Object? path = url['path'];
    return Uri.tryParse(
      '${url['protocol'] ?? 'https'}://'
      '${host is List ? host.join('.') : host ?? ''}'
      '${url['port'] == null ? '' : ':${url['port']}'}'
      '/${path is List ? path.join('/') : path ?? ''}',
    );
  }

  /// Returns enabled headers of a Postman header list.
  Map<String, String> _decodeHeaders(Object? headers) => {
    if (headers is List)
      for (final dynamic header in headers)
        if (header is Map &&
            header['key'] != null &&
            header['disabled'] != true)
          '${header['key']}': '${header['value'] ?? ''}',
  };

  static bool _isJson(String? contentType) =>
      contentType?.toLowerCase().contains('json') ?? false;

  static String _getReason(int status) =>
      NetLensHttpStatus.get(status: status, languageCode: 'en')?.name ?? '';
}

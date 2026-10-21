import 'dart:convert' show utf8;
import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:dio/dio.dart';
import 'package:netlens/netlens_mocks.dart';

/// Dio HTTP client adapter which answers requests with NetLens mocks and sends
/// the other requests with [inner]. Mocks are served below the interceptors,
/// so [NetLensDioAdapter] and the transformer of Dio handle mocked responses
/// like real ones.
///
/// ```dart
/// NetLensDioMockAdapter.install(dio, netLens.mocks);
/// ```
class NetLensDioMockAdapter implements HttpClientAdapter {
  NetLensDioMockAdapter({required this.resolver, HttpClientAdapter? inner})
    : inner = inner ?? HttpClientAdapter();

  /// Wraps the current HTTP client adapter of [dio], so its requests can be
  /// answered by [resolver].
  static NetLensDioMockAdapter install(Dio dio, NetLensMockResolver resolver) {
    final NetLensDioMockAdapter adapter = NetLensDioMockAdapter(
      resolver: resolver,
      inner: dio.httpClientAdapter,
    );
    dio.httpClientAdapter = adapter;
    return adapter;
  }

  /// Finds the mock which answers a request.
  final NetLensMockResolver resolver;

  /// Adapter which sends requests which aren't mocked.
  final HttpClientAdapter inner;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // The body can be read only once, so it's kept for the network request.
    final Uint8List? body = requestStream == null
        ? null
        : await _readBody(requestStream);
    final NetLensMockResponse? response = await resolver.resolve(
      NetLensMockRequest(
        method: options.method,
        uri: options.uri,
        headers: {
          for (final MapEntry<String, dynamic> header
              in options.headers.entries)
            header.key: '${header.value}',
        },
        body: body == null ? null : utf8.decode(body, allowMalformed: true),
      ),
    );
    if (response == null) {
      return inner.fetch(
        options,
        body == null ? null : Stream<Uint8List>.value(body),
        cancelFuture,
      );
    }
    return ResponseBody.fromBytes(
      response.bodyBytes,
      response.status,
      headers: {
        for (final MapEntry<String, String> header in response.headers.entries)
          header.key: [header.value],
      },
    );
  }

  @override
  void close({bool force = false}) => inner.close(force: force);

  Future<Uint8List> _readBody(Stream<Uint8List> stream) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    await stream.forEach(builder.add);
    return builder.takeBytes();
  }
}

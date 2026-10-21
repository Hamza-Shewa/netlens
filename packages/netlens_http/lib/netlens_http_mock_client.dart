import 'dart:convert' show utf8;

import 'package:http/http.dart' as http;
import 'package:netlens/netlens_mocks.dart';

/// Client of the http package which answers requests with NetLens mocks and
/// sends the other requests with [inner]. It also works with Chopper, which
/// sends its requests with a client of the http package.
///
/// ```dart
/// final client = NetLensHttpMockClient(resolver: netLens.mocks);
/// await client.get(url).interceptWithNetLens(adapter);
/// ```
class NetLensHttpMockClient extends http.BaseClient {
  NetLensHttpMockClient({required this.resolver, http.Client? inner})
    : inner = inner ?? http.Client();

  /// Finds the mock which answers a request.
  final NetLensMockResolver resolver;

  /// Client which sends requests which aren't mocked.
  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final NetLensMockResponse? response = await resolver.resolve(
      NetLensMockRequest(
        method: request.method,
        uri: request.url,
        headers: request.headers,
        // Bodies of streamed and multipart requests can be read only once, so
        // they aren't compared.
        body: request is http.Request
            ? utf8.decode(request.bodyBytes, allowMalformed: true)
            : null,
      ),
    );
    if (response == null) {
      return inner.send(request);
    }
    final List<int> bytes = response.bodyBytes;
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      response.status,
      contentLength: bytes.length,
      request: request,
      headers: response.headers,
    );
  }

  @override
  void close() => inner.close();
}

import 'dart:async' show StreamSubscription;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:io';

import 'package:netlens/mock/domain/netlens_mock_request.dart';
import 'package:netlens/mock/domain/netlens_mock_resolver.dart';
import 'package:netlens/mock/domain/netlens_mock_response.dart';

/// Local HTTP server which answers requests with mocks. It works with any
/// HTTP client, including HttpClient from dart:io: point the base URL of the
/// app at [uri]. The host of the request is ignored, so mocks recorded against
/// any backend match.
///
/// Requests which no mock answers get 404.
class NetLensMockServer {
  NetLensMockServer({required this.resolver});

  final NetLensMockResolver resolver;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  /// Whether the server is running.
  bool get isRunning => _server != null;

  /// Base URL of the running server, or null when it isn't running.
  Uri? get uri {
    final HttpServer? server = _server;
    if (server == null) {
      return null;
    }
    final InternetAddress address = server.address;
    final String host =
        address.isLoopback || address == InternetAddress.anyIPv4
            ? InternetAddress.loopbackIPv4.address
            : address.address;
    return Uri(scheme: 'http', host: host, port: server.port);
  }

  /// Starts the server on [address] and [port]. A [port] of 0 picks a free
  /// port. Returns the base URL of the server.
  Future<Uri> start({Object? address, int port = 0}) async {
    if (isRunning) {
      return uri!;
    }
    final HttpServer server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    _server = server;
    _subscription = server.listen(_handle);
    return uri!;
  }

  /// Stops the server.
  Future<void> stop() async {
    await _subscription?.cancel();
    await _server?.close(force: true);
    _subscription = null;
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final HttpResponse response = request.response;
    try {
      final List<int> bytes = await request.fold<List<int>>(
        <int>[],
        (List<int> body, List<int> chunk) => body..addAll(chunk),
      );
      final Map<String, String> headers = {};
      request.headers.forEach((String name, List<String> values) {
        headers[name] = values.join(', ');
      });
      final NetLensMockResponse? mock = await resolver.resolve(
        NetLensMockRequest(
          method: request.method,
          // Without the host, so mocks of any host match.
          uri: Uri(
            path: request.uri.path,
            query: request.uri.hasQuery ? request.uri.query : null,
          ),
          headers: headers,
          body: bytes.isEmpty ? null : utf8.decode(bytes, allowMalformed: true),
        ),
      );
      if (mock == null) {
        _writeNotFound(request);
      } else {
        response.statusCode = mock.status;
        mock.headers.forEach(response.headers.set);
        response.add(mock.bodyBytes);
      }
    } catch (exception) {
      response.statusCode = HttpStatus.internalServerError;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({'error': '$exception'}));
    }
    await response.close();
  }

  void _writeNotFound(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.notFound
      ..headers.contentType = ContentType.json
      ..headers.set(
        NetLensMockResponse.mockHeader,
        NetLensMockResponse.missingMockId,
      )
      ..write(
        jsonEncode({
          'error': 'No NetLens mock for ${request.method} ${request.uri.path}',
        }),
      );
  }
}

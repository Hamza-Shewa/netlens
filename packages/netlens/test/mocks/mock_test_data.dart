import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_http_request.dart';
import 'package:netlens/model/netlens_http_response.dart';
import 'package:netlens/netlens_mocks.dart';

/// Returns a finished call of `GET https://api.example.com/users?page=1`.
NetLensHttpCall finishedCall({
  int id = 1,
  String method = 'GET',
  String uri = 'https://api.example.com/users?page=1',
  dynamic requestBody = '',
  int? status = 200,
  dynamic responseBody = const [
    {'id': 1},
  ],
  Map<String, String>? responseHeaders,
  bool loading = false,
}) {
  final Uri url = Uri.parse(uri);
  return NetLensHttpCall(id)
    ..method = method
    ..uri = uri
    ..server = url.host
    ..endpoint = url.path
    ..secure = url.scheme == 'https'
    ..client = 'Dio'
    ..loading = loading
    ..duration = 250
    ..request =
        (NetLensHttpRequest()
          ..body = requestBody
          ..queryParameters = url.queryParameters)
    ..response =
        (NetLensHttpResponse()
          ..status = status
          ..headers = responseHeaders
          ..body = responseBody);
}

/// Returns a mock of `GET` [url] which answers with [body].
NetLensMock mock({
  String id = 'mock',
  String method = 'GET',
  String url = 'https://api.example.com/users',
  String? requestBody,
  int status = 200,
  String body = '[]',
  bool enabled = true,
  Duration delay = Duration.zero,
}) => NetLensMock(
  id: id,
  method: method,
  url: Uri.parse(url),
  requestBody: requestBody,
  enabled: enabled,
  createdTime: DateTime(2026),
  response: NetLensMockResponse(
    status: status,
    headers: const {'content-type': 'application/json'},
    body: body,
    delay: delay,
  ),
);

/// Returns a request of [method] [url].
NetLensMockRequest request(String url, {String method = 'GET', String? body}) =>
    NetLensMockRequest(method: method, uri: Uri.parse(url), body: body);

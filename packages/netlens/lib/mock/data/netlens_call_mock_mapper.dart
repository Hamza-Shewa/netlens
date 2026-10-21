import 'dart:convert' show jsonEncode;

import 'package:netlens/mock/data/netlens_mock_headers.dart';
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_response.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_http_response.dart';
import 'package:netlens/model/netlens_replay_request.dart';

/// Builds mocks from calls caught by NetLens.
class NetLensCallMockMapper {
  NetLensCallMockMapper({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Returns true when [call] finished with a response which can be replayed.
  /// Calls which failed without a response, for example offline, can't.
  static bool canMap(NetLensHttpCall call) {
    final int status = call.response?.status ?? 0;
    return !call.loading && call.request != null && status > 0;
  }

  /// Returns the mock which answers the request of [call] with its response,
  /// or null when [canMap] is false. The mock has no id until it is saved by
  /// [NetLensMockRecorder].
  NetLensMock? map(NetLensHttpCall call) {
    if (!canMap(call)) {
      return null;
    }
    final NetLensReplayRequest request = NetLensReplayRequest.fromCall(call);
    final Uri? url = Uri.tryParse(request.url);
    if (url == null) {
      return null;
    }
    return NetLensMock(
      id: '',
      method: request.method,
      url: url,
      requestBody: request.body,
      response: _mapResponse(call),
      createdTime: _clock(),
    );
  }

  NetLensMockResponse _mapResponse(NetLensHttpCall call) {
    final NetLensHttpResponse response = call.response!;
    final Map<String, String> headers = NetLensMockHeaders.normalize(
      response.headers,
    );
    final Duration delay = Duration(
      milliseconds: call.duration < 0 ? 0 : call.duration,
    );
    final dynamic body = response.body;
    if (body is List<int>) {
      return NetLensMockResponse.bytes(
        body,
        status: response.status!,
        headers: headers,
        delay: delay,
      );
    }
    final bool isJson = body is Map || body is List;
    if (isJson && !headers.containsKey('content-type')) {
      // Clients decode JSON only when the content type says so.
      headers['content-type'] = 'application/json; charset=utf-8';
    }
    return NetLensMockResponse(
      status: response.status!,
      headers: headers,
      body: isJson ? _encodeJson(body) : '${body ?? ''}',
      delay: delay,
    );
  }

  String _encodeJson(dynamic body) {
    try {
      return jsonEncode(body);
    } catch (_) {
      return body.toString();
    }
  }
}

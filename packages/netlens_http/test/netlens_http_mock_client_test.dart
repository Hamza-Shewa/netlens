import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:netlens/core/netlens_core.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/netlens_mocks.dart';
import 'package:netlens_http/netlens_http.dart';
import 'package:netlens_test/netlens_test.dart';
import 'package:test/test.dart';

void main() {
  late NetLensMocks mocks;
  late List<http.Request> sent;
  late NetLensHttpMockClient client;

  setUp(() {
    mocks = NetLensMocks(
      mode: NetLensMockMode.replay,
      matcher: const NetLensDefaultMockMatcher(matchBody: true),
      repository: NetLensMemoryMockRepository(
        mocks: [
          NetLensMock(
            id: 'login',
            method: 'POST',
            url: Uri.parse('https://api.example.com/login'),
            requestBody: '{"user":"ada"}',
            createdTime: DateTime(2026),
            response: const NetLensMockResponse(
              status: 200,
              headers: {'content-type': 'application/json'},
              body: '{"token":"abc"}',
            ),
          ),
        ],
      ),
    );
    sent = [];
    client = NetLensHttpMockClient(
      resolver: mocks,
      inner: MockClient((http.Request request) async {
        sent.add(request);
        return http.Response('network', 200);
      }),
    );
  });

  tearDown(() => mocks.dispose());

  group('NetLensHttpMockClient', () {
    test('answers matching requests with the mock', () async {
      final http.Response response = await client.post(
        Uri.parse('https://api.example.com/login'),
        body: '{"user":"ada"}',
      );

      expect(response.statusCode, 200);
      expect(jsonDecode(response.body), {'token': 'abc'});
      expect(response.headers[NetLensMockResponse.mockHeader], 'login');
      expect(response.request?.url, Uri.parse('https://api.example.com/login'));
      expect(sent, isEmpty);
    });

    test('sends other requests with the inner client', () async {
      final http.Response response = await client.post(
        Uri.parse('https://api.example.com/login'),
        body: '{"user":"bob"}',
      );

      expect(response.body, 'network');
      expect(sent.single.body, '{"user":"bob"}');
    });

    test('lets the adapter catch mocked calls', () async {
      registerFallbackValue(NetLensHttpCall(0));
      final NetLensCore core = NetLensCoreMock();
      when(() => core.addCall(any())).thenAnswer((_) => {});
      final NetLensHttpAdapter adapter = NetLensHttpAdapter()..injectCore(core);

      await client
          .post(
            Uri.parse('https://api.example.com/login'),
            body: '{"user":"ada"}',
          )
          .interceptWithNetLens(adapter);

      final NetLensHttpCall call =
          verify(() => core.addCall(captureAny())).captured.single
              as NetLensHttpCall;
      expect(call.method, 'POST');
      expect(call.uri, 'https://api.example.com/login');
      expect(call.request?.body, '{"user":"ada"}');
      expect(call.response?.status, 200);
      expect(call.response?.body, '{"token":"abc"}');
      expect(call.response?.headers?[NetLensMockResponse.mockHeader], 'login');
    });
  });
}

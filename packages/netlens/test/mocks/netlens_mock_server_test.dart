import 'dart:convert';
import 'dart:io';

import 'package:netlens/netlens_mocks.dart';
import 'package:test/test.dart';

import 'mock_test_data.dart';

void main() {
  group('NetLensMockServer', () {
    late NetLensMocks mocks;
    late NetLensMockServer server;
    late HttpClient client;

    setUp(() {
      mocks = NetLensMocks(
        mode: NetLensMockMode.replay,
        repository: NetLensMemoryMockRepository(
          mocks: [
            mock(
              id: 'user',
              url: 'https://api.example.com/users/*',
              body: '{"id":1}',
            ),
          ],
        ),
      );
      server = NetLensMockServer(resolver: mocks);
      client = HttpClient();
    });
    tearDown(() async {
      client.close(force: true);
      await server.stop();
      mocks.dispose();
    });

    Future<(int, Map<String, String>, String)> get(Uri url) async {
      final HttpClientRequest request = await client.getUrl(url);
      final HttpClientResponse response = await request.close();
      final Map<String, String> headers = {};
      response.headers.forEach(
        (String name, List<String> values) => headers[name] = values.join(),
      );
      return (
        response.statusCode,
        headers,
        await utf8.decoder.bind(response).join(),
      );
    }

    test('answers requests of any host with mocks', () async {
      final Uri base = await server.start();
      expect(server.isRunning, isTrue);
      expect(base.host, '127.0.0.1');

      final (int status, Map<String, String> headers, String body) = await get(
        base.replace(path: '/users/1'),
      );
      expect(status, 200);
      expect(body, '{"id":1}');
      expect(headers['content-type'], 'application/json');
      expect(headers[NetLensMockResponse.mockHeader], 'user');
    });

    test('answers unknown requests with 404', () async {
      final Uri base = await server.start();
      final (int status, Map<String, String> headers, String body) = await get(
        base.replace(path: '/teams'),
      );
      expect(status, 404);
      expect(
        headers[NetLensMockResponse.mockHeader],
        NetLensMockResponse.missingMockId,
      );
      expect(jsonDecode(body), {'error': 'No NetLens mock for GET /teams'});
    });

    test('stops', () async {
      await server.start();
      await server.stop();
      expect(server.isRunning, isFalse);
      expect(server.uri, isNull);
    });
  });
}

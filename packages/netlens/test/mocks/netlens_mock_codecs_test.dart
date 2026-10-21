import 'dart:convert';

import 'package:netlens/helper/netlens_har_builder.dart';
import 'package:netlens/netlens_mocks.dart';
import 'package:test/test.dart';

import 'mock_test_data.dart';

void main() {
  group('NetLensMockJsonCodec', () {
    const NetLensMockJsonCodec codec = NetLensMockJsonCodec();

    test('decodes what it encodes', () {
      final List<NetLensMock> mocks = [
        mock(id: 'a', delay: const Duration(milliseconds: 40)),
        mock(
          id: 'b',
          method: 'POST',
          requestBody: '{"name":"Ada"}',
          enabled: false,
        ),
        mock(
          id: 'c',
        ).copyWith(response: NetLensMockResponse.bytes([1, 2, 3], status: 206)),
      ];

      final List<NetLensMock> decoded = codec.decode(codec.encode(mocks));

      expect(
        decoded.map(
          (NetLensMock mock) => mock.copyWith(createdTime: DateTime(2026)),
        ),
        mocks,
      );
    });

    test('reads short mocks written by hand', () {
      final List<NetLensMock> mocks = codec.decode(
        jsonEncode({
          'netlensMocks': 1,
          'mocks': [
            {
              'method': 'get',
              'url': '/users/*',
              'response': {
                'status': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': [
                  {'id': 1},
                ],
              },
            },
          ],
        }),
      );

      expect(mocks.single.method, 'GET');
      expect(mocks.single.url, Uri.parse('/users/*'));
      expect(mocks.single.enabled, isTrue);
      expect(mocks.single.response.body, '[{"id":1}]');
      expect(mocks.single.response.headers, {
        'content-type': 'application/json',
      });
    });

    test('rejects other documents and newer versions', () {
      expect(() => codec.decode('{"log":{}}'), throwsFormatException);
      expect(
        () => codec.decode('{"netlensMocks":99,"mocks":[]}'),
        throwsFormatException,
      );
    });
  });

  group('NetLensHarMockImporter', () {
    const NetLensHarMockImporter importer = NetLensHarMockImporter();

    test('imports HAR files exported by NetLens', () {
      final Object? har = jsonDecode(
        NetLensHarBuilder.encode([
          finishedCall(
            method: 'POST',
            requestBody: '{"name":"Ada"}',
            status: 201,
            responseHeaders: {'content-type': 'application/json'},
            responseBody: '{"id":7}',
          ),
          finishedCall(id: 2, status: -1),
        ]),
      );

      expect(importer.canImport(har), isTrue);
      final NetLensMock mock = importer.import(har).single;
      expect(mock.method, 'POST');
      expect(mock.url, Uri.parse('https://api.example.com/users?page=1'));
      expect(mock.requestBody, '{"name":"Ada"}');
      expect(mock.response.status, 201);
      expect(mock.response.body, '{"id":7}');
      expect(mock.response.headers, {'content-type': 'application/json'});
      expect(mock.response.delay, const Duration(milliseconds: 250));
    });

    test('reads base64 bodies', () {
      final NetLensMock mock = importer.import({
        'log': {
          'entries': [
            {
              'request': {'method': 'GET', 'url': 'https://cdn.example.com/a'},
              'response': {
                'status': 200,
                'headers': <dynamic>[],
                'content': {
                  'text': base64Encode([1, 2]),
                  'encoding': 'base64',
                },
              },
            },
          ],
        },
      }).single;
      expect(mock.response.bodyBytes, [1, 2]);
    });

    test('does not import other documents', () {
      expect(importer.canImport({'netlensMocks': 1}), isFalse);
    });
  });
}

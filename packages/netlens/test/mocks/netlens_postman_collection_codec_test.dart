import 'dart:async';
import 'dart:convert';

import 'package:netlens/helper/netlens_call_redactor.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_redaction.dart';
import 'package:netlens/netlens_mocks.dart';
import 'package:test/test.dart';

import 'mock_test_data.dart';

void main() {
  const NetLensPostmanCollectionCodec codec = NetLensPostmanCollectionCodec();

  final NetLensMock login = NetLensMock(
    id: 'login',
    method: 'POST',
    url: Uri.parse('https://api.example.com:8443/auth/login?lang=en'),
    requestBody: '{"user":"a"}',
    requestHeaders: const {'Content-Type': 'application/json'},
    createdTime: DateTime(2026),
    response: const NetLensMockResponse(
      status: 201,
      headers: {
        'content-type': 'application/json',
        NetLensMockResponse.mockHeader: 'login',
      },
      body: '{"token":"t"}',
    ),
  );

  group('NetLensPostmanCollectionCodec', () {
    test('writes requests with their responses as examples', () {
      final Map<String, dynamic> collection =
          jsonDecode(
                codec.encode([
                  login,
                  mock(url: 'https://other.example.com/users'),
                ], name: 'QA'),
              )
              as Map<String, dynamic>;
      expect(collection['info'], {
        'name': 'QA',
        'schema': NetLensPostmanCollectionCodec.schema,
      });
      final List<dynamic> folders = collection['item'] as List<dynamic>;
      expect(folders.map((folder) => folder['name']), [
        'api.example.com',
        'other.example.com',
      ]);

      final Map<String, dynamic> item = folders.first['item'].single;
      expect(item['name'], 'POST /auth/login');
      final Map<String, dynamic> request = item['request'];
      expect(request['method'], 'POST');
      expect(request['header'], [
        {'key': 'Content-Type', 'value': 'application/json'},
      ]);
      expect(request['body'], {
        'mode': 'raw',
        'raw': '{"user":"a"}',
        'options': {
          'raw': {'language': 'json'},
        },
      });
      expect(request['url'], {
        'raw': 'https://api.example.com:8443/auth/login?lang=en',
        'protocol': 'https',
        'host': ['api', 'example', 'com'],
        'port': '8443',
        'path': ['auth', 'login'],
        'query': [
          {'key': 'lang', 'value': 'en'},
        ],
      });
      final Map<String, dynamic> example = item['response'].single;
      expect(example['code'], 201);
      expect(example['status'], 'Created');
      expect(example['body'], '{"token":"t"}');
      expect(example['header'], [
        {'key': 'content-type', 'value': 'application/json'},
      ]);
    });

    test('reads back what it wrote', () {
      final NetLensMock read = codec.decode(codec.encode([login])).single;
      expect(read.method, 'POST');
      expect(read.url, login.url);
      expect(read.requestBody, login.requestBody);
      expect(read.requestHeaders, login.requestHeaders);
      expect(read.response.status, 201);
      expect(read.response.body, '{"token":"t"}');
      expect(read.response.headers, {'content-type': 'application/json'});
    });

    test('reads folders, examples and URLs written by API clients', () {
      final List<NetLensMock> mocks = codec.import({
        'info': {
          'name': 'Shared',
          'schema':
              'https://schema.getpostman.com/json/collection/v2.0.0/collection.json',
        },
        'item': [
          {
            'name': 'Folder',
            'item': [
              {
                'name': 'Users',
                'request': {
                  'method': 'get',
                  'header': [
                    {'key': 'Accept', 'value': 'json'},
                    {'key': 'Old', 'value': 'x', 'disabled': true},
                  ],
                  'url': {
                    'host': ['api', 'example', 'com'],
                    'path': ['users'],
                  },
                },
                'response': [
                  {'code': 200, 'body': '[]'},
                  {
                    'code': 404,
                    'originalRequest': {
                      'method': 'GET',
                      'url': 'https://api.example.com/users/9',
                    },
                  },
                ],
              },
              {
                'name': 'Without example',
                'request': {'url': 'https://api.example.com/none'},
              },
              {
                'name': 'With variable',
                'request': {'url': '{{baseUrl}}/users'},
                'response': [
                  {'code': 200},
                ],
              },
            ],
          },
        ],
      });
      expect(mocks.map((NetLensMock mock) => '${mock.method} ${mock.url}'), [
        'GET https://api.example.com/users',
        'GET https://api.example.com/users/9',
      ]);
      expect(mocks.first.requestHeaders, {'Accept': 'json'});
      expect(mocks.last.response.status, 404);
    });

    test('is one of the formats mocks import', () async {
      final NetLensMocks mocks = NetLensMocks();
      addTearDown(mocks.dispose);
      final List<NetLensMock> imported = await mocks.import(
        mocks.exportCollection(mocks: [login]),
      );
      expect(imported.single.url, login.url);
      expect(() => codec.import({'item': []}), throwsFormatException);
    });
  });

  group('requestHeaders', () {
    test('are recorded and kept by the NetLens format', () async {
      final NetLensMocks mocks = NetLensMocks();
      addTearDown(mocks.dispose);
      final NetLensHttpCall call = finishedCall()
        ..request!.headers = {'Accept': 'json', 'Host': 'api.example.com'};
      final NetLensMock? recorded = await mocks.record(call);
      expect(recorded?.requestHeaders, {'Accept': 'json'});

      final NetLensMock read = const NetLensMockJsonCodec()
          .decode(mocks.export())
          .single;
      expect(read.requestHeaders, {'Accept': 'json'});
    });

    test('are masked when sensitive', () {
      const NetLensCallRedactor redactor = NetLensCallRedactor(
        NetLensRedaction(),
      );
      final NetLensMock redacted = redactor.redactMock(
        login.copyWith(
          requestHeaders: {'Authorization': 'Bearer secret', 'Accept': 'json'},
        ),
      );
      expect(redacted.requestHeaders, {
        'Authorization': NetLensRedaction.defaultMask,
        'Accept': 'json',
      });
      expect(redacted.url, login.url);
    });
  });

  group('saveAllCalls', () {
    test('records finished calls whatever the mode is', () async {
      final NetLensMocks mocks = NetLensMocks(
        mode: NetLensMockMode.replay,
        saveAllCalls: true,
      );
      addTearDown(mocks.dispose);
      final StreamController<List<NetLensHttpCall>> calls = StreamController();
      final StreamSubscription<List<NetLensHttpCall>> subscription = mocks
          .recordFrom(calls.stream);
      addTearDown(subscription.cancel);
      addTearDown(calls.close);

      calls.add([
        finishedCall(),
        finishedCall(
          id: 2,
          uri: 'https://api.example.com/mocked',
          responseHeaders: {'X-NetLens-Mock': 'abc'},
        ),
      ]);
      await pumpEventQueue();
      expect(
        mocks.mocks.map((NetLensMock mock) => mock.url.path),
        ['/users'],
        reason: 'Calls answered by a mock are not saved again',
      );

      mocks.saveAllCalls = false;
      calls.add([finishedCall(id: 3, uri: 'https://api.example.com/teams')]);
      await pumpEventQueue();
      expect(mocks.mocks, hasLength(1));
    });

    test('notifies changes', () async {
      final NetLensMocks mocks = NetLensMocks();
      addTearDown(mocks.dispose);
      expect(mocks.saveAllCalls, isFalse);
      final Future<void> changes = expectLater(
        mocks.saveAllCallsStream,
        emitsInOrder([false, true]),
      );
      mocks.saveAllCalls = true;
      await changes;
    });
  });
}

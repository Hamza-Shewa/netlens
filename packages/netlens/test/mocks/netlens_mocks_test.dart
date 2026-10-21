import 'dart:async';
import 'dart:convert';

import 'package:netlens/helper/netlens_har_builder.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/netlens_mocks.dart';
import 'package:test/test.dart';

import 'mock_test_data.dart';

void main() {
  group('NetLensMocks', () {
    late NetLensMocks mocks;
    int ids = 0;

    NetLensMocks create({
      NetLensMockMode mode = NetLensMockMode.replay,
      NetLensMockFallback fallback = NetLensMockFallback.network,
      bool simulateLatency = false,
      List<NetLensMock> initial = const [],
    }) => NetLensMocks(
      mode: mode,
      fallback: fallback,
      simulateLatency: simulateLatency,
      repository: NetLensMemoryMockRepository(mocks: initial),
      idGenerator: () => 'id${ids++}',
    );

    setUp(() {
      ids = 0;
      mocks = create(initial: [mock(id: 'users')]);
    });
    tearDown(() => mocks.dispose());

    group('resolve', () {
      test('answers matching requests in replay mode', () async {
        final NetLensMockResponse? response = await mocks.resolve(
          request('https://api.example.com/users'),
        );
        expect(response?.status, 200);
        expect(response?.body, '[]');
        expect(response?.headers, {
          'content-type': 'application/json',
          NetLensMockResponse.mockHeader: 'users',
        });
      });

      test('does not answer in other modes', () async {
        for (final NetLensMockMode mode in [
          NetLensMockMode.off,
          NetLensMockMode.record,
        ]) {
          mocks.mode = mode;
          expect(
            await mocks.resolve(request('https://api.example.com/users')),
            isNull,
          );
        }
      });

      test('sends unknown requests to the network by default', () async {
        expect(
          await mocks.resolve(request('https://api.example.com/teams')),
          isNull,
        );
      });

      test('answers unknown requests with 404 when asked', () async {
        final NetLensMocks strict = create(
          fallback: NetLensMockFallback.notFound,
        );
        final NetLensMockResponse? response = await strict.resolve(
          request('https://api.example.com/teams'),
        );
        expect(response?.status, 404);
        expect(
          response?.headers[NetLensMockResponse.mockHeader],
          NetLensMockResponse.missingMockId,
        );
        expect(jsonDecode(response!.body), {
          'error': 'No NetLens mock for GET /teams',
        });
      });

      test('waits for the recorded latency when simulated', () async {
        final NetLensMocks slow = create(
          simulateLatency: true,
          initial: [mock(delay: const Duration(milliseconds: 60))],
        );
        final Stopwatch stopwatch = Stopwatch()..start();
        await slow.resolve(request('https://api.example.com/users'));
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
      });
    });

    group('record', () {
      test('saves a call as a mock', () async {
        mocks = create();
        final NetLensMock? saved = await mocks.record(finishedCall());
        expect(saved?.id, 'id0');
        expect(mocks.mocks, [saved]);
      });

      test('replaces the mock of the same request', () async {
        mocks = create();
        await mocks.record(finishedCall(responseBody: 'old'));
        final NetLensMock? updated = await mocks.record(
          finishedCall(id: 2, responseBody: 'new'),
        );
        expect(mocks.mocks.single.id, 'id0');
        expect(mocks.mocks.single, updated);
        expect(mocks.mocks.single.response.body, 'new');
      });

      test('skips calls which can not be replayed', () async {
        mocks = create();
        expect(await mocks.record(finishedCall(loading: true)), isNull);
        expect(await mocks.recordAll([finishedCall(status: -1)]), isEmpty);
        expect(mocks.mocks, isEmpty);
      });

      test('records finished calls of a stream once in record mode', () async {
        mocks = create(mode: NetLensMockMode.off);
        final StreamController<List<NetLensHttpCall>> calls =
            StreamController();
        final StreamSubscription<List<NetLensHttpCall>> subscription = mocks
            .recordFrom(calls.stream);

        calls.add([finishedCall()]);
        await pumpEventQueue();
        expect(mocks.mocks, isEmpty);

        mocks.mode = NetLensMockMode.record;
        final NetLensHttpCall pending = finishedCall(
          id: 2,
          uri: 'https://api.example.com/teams',
          loading: true,
        );
        calls.add([finishedCall(), pending]);
        await pumpEventQueue();
        expect(mocks.mocks.map((NetLensMock mock) => mock.url.path), [
          '/users',
        ]);

        pending.loading = false;
        calls.add([finishedCall(responseBody: 'changed'), pending]);
        await pumpEventQueue();
        expect(mocks.mocks.map((NetLensMock mock) => mock.url.path), [
          '/users',
          '/teams',
        ]);
        expect(
          mocks.mocks.first.response.body,
          '[{"id":1}]',
          reason: 'A call is recorded only once',
        );

        await subscription.cancel();
        await calls.close();
      });
    });

    test('turns mocks on and off and removes them', () async {
      await mocks.setEnabled('users', enabled: false);
      expect(mocks.mocks.single.enabled, isFalse);
      expect(
        await mocks.resolve(request('https://api.example.com/users')),
        isNull,
      );

      await mocks.remove('users');
      expect(mocks.mocks, isEmpty);

      await mocks.record(finishedCall());
      await mocks.clear();
      expect(mocks.mocks, isEmpty);
    });

    group('import', () {
      test('reads exported mocks', () async {
        final String exported = mocks.export();
        final NetLensMocks other = create();
        final List<NetLensMock> imported = await other.import(exported);
        expect(imported.single.url, mocks.mocks.single.url);
        expect(other.mocks, imported);
      });

      test('reads HAR files', () async {
        final NetLensMocks other = create();
        await other.import(
          NetLensHarBuilder.encode([
            finishedCall(),
            finishedCall(id: 2, uri: 'https://api.example.com/teams'),
          ]),
        );
        expect(other.mocks.map((NetLensMock mock) => mock.url.path), [
          '/users',
          '/teams',
        ]);
      });

      test('gives imported mocks new ids', () async {
        final NetLensMocks other = create();
        final String har = NetLensHarBuilder.encode([finishedCall()]);
        await other.import(har);
        await other.import(
          NetLensHarBuilder.encode([
            finishedCall(uri: 'https://api.example.com/teams'),
          ]),
        );
        await other.import(har);
        expect(other.mocks.map((NetLensMock mock) => mock.id), ['id0', 'id1']);
      });

      test('rejects unknown documents', () {
        expect(() => mocks.import('{"foo":1}'), throwsFormatException);
      });
    });

    test('emits mode changes', () async {
      expectLater(
        mocks.modeStream,
        emitsInOrder([NetLensMockMode.replay, NetLensMockMode.record]),
      );
      mocks.mode = NetLensMockMode.record;
    });
  });
}

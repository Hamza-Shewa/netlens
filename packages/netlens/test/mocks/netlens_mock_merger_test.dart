import 'package:netlens/netlens_mocks.dart';
import 'package:test/test.dart';

import 'mock_test_data.dart';

void main() {
  const NetLensMockMerger merger = NetLensMockMerger();

  NetLensMockSource source(String name, List<NetLensMock> mocks) =>
      NetLensMockSource(name: name, mocks: mocks);

  NetLensMock order(String body, {String response = '{"ok":true}'}) => mock(
    method: 'POST',
    url: 'https://api.example.com/orders',
    requestBody: body,
    body: response,
  );

  group('NetLensMockMerger', () {
    test('keeps mocks of every source and equal mocks once', () {
      final NetLensMockMergePlan plan = merger.plan([
        source('A', [mock(), mock(url: 'https://api.example.com/teams')]),
        source('B', [
          mock(id: 'other'),
          mock(url: 'https://api.example.com/x'),
        ]),
      ]);
      expect(plan.hasConflicts, isFalse);
      expect(plan.resolve().map((NetLensMock mock) => mock.url.path), [
        '/users',
        '/teams',
        '/x',
      ]);
    });

    test('keeps requests which send other values of the same types', () {
      final NetLensMockMergePlan plan = merger.plan([
        source('A', [order('{"id":1,"note":"a"}')]),
        source('B', [order('{"id":2,"note":"b"}'), order('{"id":3}')]),
      ]);
      expect(plan.hasConflicts, isFalse);
      expect(plan.resolve(), hasLength(3));
    });

    test('lays out fields sent as different types', () {
      final NetLensMockMergePlan plan = merger.plan([
        source('A', [order('{"id":1,"user":{"age":30}}')]),
        source('B', [
          order('{"id":"1","user":{"age":30}}'),
          order('{"id":"2"}'),
        ]),
        source('C', [order('{"id":null}')]),
      ]);
      final NetLensMockConflict conflict = plan.inputConflicts.single;
      expect(conflict.type, NetLensMockConflictType.input);
      expect(conflict.method, 'POST');
      expect(conflict.url.toString(), 'https://api.example.com/orders');
      expect(conflict.options.map((option) => option.sources), [
        ['A'],
        ['B'],
      ]);
      expect(conflict.options.first.inputTypes, {r'$.id': 'number'});
      expect(conflict.options.last.inputTypes, {r'$.id': 'string'});
      expect(conflict.options.last.mocks, hasLength(2));

      expect(
        plan.resolve().map((NetLensMock mock) => mock.requestBody),
        ['{"id":1,"user":{"age":30}}', '{"id":null}'],
        reason: 'The first option is the default; null fits every option',
      );
      expect(
        plan.resolve({conflict: 1}).map((NetLensMock mock) => mock.requestBody),
        ['{"id":"1","user":{"age":30}}', '{"id":"2"}', '{"id":null}'],
      );
    });

    test('compares types of list items and of the whole body', () {
      expect(
        NetLensMockMerger.getInputTypes(order('{"tags":["a",1],"n":null}')),
        {
          r'$': {'object'},
          r'$.tags': {'array'},
          r'$.tags[]': {'string', 'number'},
        },
      );
      expect(NetLensMockMerger.getInputTypes(order('a=1&b=2')), {
        r'$': {'text'},
      });

      final NetLensMockMergePlan plan = merger.plan([
        source('A', [order('{"id":1}')]),
        source('B', [order('[1]')]),
      ]);
      expect(
        plan.inputConflicts.single.options.first.inputTypes,
        {r'$': 'object'},
        reason: 'Fields of a conflicting body are not listed again',
      );
    });

    test('lays out different responses to the same request', () {
      final NetLensMockMergePlan plan = merger.plan([
        source('A', [mock(body: '[1]')]),
        source('B', [mock(body: '[2]')]),
        source('C', [mock(body: '[1]')]),
      ]);
      final NetLensMockConflict conflict = plan.responseConflicts.single;
      expect(conflict.type, NetLensMockConflictType.response);
      expect(conflict.options.map((option) => option.sources), [
        ['A', 'C'],
        ['B'],
      ]);
      expect(plan.resolve().single.response.body, '[1]');
      expect(plan.resolve({conflict: 1}).single.response.body, '[2]');
    });

    test('hides response conflicts dropped by an input choice', () {
      final NetLensMockMergePlan plan = merger.plan([
        source('A', [order('{"id":1}', response: 'a')]),
        source('B', [
          order('{"id":"1"}', response: 'b'),
          order('{"id":"1"}', response: 'c'),
        ]),
      ]);
      final NetLensMockConflict input = plan.inputConflicts.single;
      expect(plan.responseConflicts, hasLength(1));
      expect(plan.getConflicts(), [input]);
      expect(plan.getConflicts({input: 1}), hasLength(2));
      expect(
        plan
            .resolve({input: 1, plan.responseConflicts.single: 1})
            .single
            .response
            .body,
        'c',
      );
    });
  });

  group('NetLensMocks merge', () {
    test('merges sources with the saved mocks and keeps their ids', () async {
      final NetLensMocks mocks = NetLensMocks(
        repository: NetLensMemoryMockRepository(
          mocks: [
            mock(id: 'users', body: '[1]', enabled: false),
            mock(id: 'old', url: 'https://api.example.com/old'),
          ],
        ),
        idGenerator: () => 'new',
      );
      addTearDown(mocks.dispose);

      final NetLensMockMergePlan plan = mocks.planMerge([
        source('B', [
          mock(body: '[2]'),
          mock(url: 'https://api.example.com/b'),
        ]),
      ], currentName: 'Mine');
      final NetLensMockConflict conflict = plan.responseConflicts.single;
      expect(conflict.options.first.sources, ['Mine']);

      await mocks.replaceAll(plan.resolve({conflict: 1}));
      expect(mocks.mocks.map((NetLensMock mock) => mock.url.path).toSet(), {
        '/users',
        '/old',
        '/b',
      });
      final NetLensMock users = mocks.mocks.firstWhere(
        (NetLensMock mock) => mock.url.path == '/users',
      );
      expect(users.id, 'users');
      expect(users.enabled, isFalse);
      expect(users.response.body, '[2]');
    });

    test('removes saved mocks which the merge left out', () async {
      final NetLensMocks mocks = NetLensMocks(
        repository: NetLensMemoryMockRepository(mocks: [mock(id: 'users')]),
      );
      addTearDown(mocks.dispose);
      await mocks.replaceAll([mock(url: 'https://api.example.com/teams')]);
      expect(mocks.mocks.single.url.path, '/teams');
    });
  });
}

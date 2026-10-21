import 'dart:math' show Random;

import 'package:netlens/mock/data/netlens_call_mock_mapper.dart';
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_repository.dart';
import 'package:netlens/model/netlens_http_call.dart';

/// Saves calls and imported mocks to a repository. A mock for a request which
/// already has one replaces it, so recording an endpoint again updates it.
class NetLensMockRecorder {
  NetLensMockRecorder({
    required NetLensMockRepository repository,
    NetLensCallMockMapper? mapper,
    String Function()? idGenerator,
  }) : _repository = repository,
       _mapper = mapper ?? NetLensCallMockMapper(),
       _idGenerator = idGenerator ?? _randomId;

  final NetLensMockRepository _repository;
  final NetLensCallMockMapper _mapper;
  final String Function() _idGenerator;

  static final Random _random = Random();

  /// Saves [call] as a mock. Returns the mock, or null when [call] can't be
  /// replayed, for example because it has no response yet.
  Future<NetLensMock?> record(NetLensHttpCall call) async {
    final NetLensMock? mock = _mapper.map(call);
    if (mock == null) {
      return null;
    }
    final List<NetLensMock> saved = await saveAll([mock]);
    return saved.single;
  }

  /// Saves every call of [calls] which can be replayed. Returns the saved
  /// mocks.
  Future<List<NetLensMock>> recordAll(Iterable<NetLensHttpCall> calls) =>
      saveAll(calls.map(_mapper.map).nonNulls);

  /// Saves [mocks]. Each mock keeps the id of the mock it replaces, or gets a
  /// new id, so ids of imported mocks never collide. Returns the saved mocks.
  Future<List<NetLensMock>> saveAll(Iterable<NetLensMock> mocks) async {
    final Map<String, NetLensMock> byKey = {
      for (final NetLensMock existing in _repository.getMocks())
        existing.requestKey: existing,
    };
    final Map<String, NetLensMock> saved = {};
    for (final NetLensMock mock in mocks) {
      final NetLensMock? existing =
          byKey[mock.requestKey] ?? saved[mock.requestKey];
      final NetLensMock withId = mock.copyWith(
        id: existing?.id ?? _idGenerator(),
        enabled: existing?.enabled ?? mock.enabled,
      );
      saved[mock.requestKey] = withId;
    }
    if (saved.isNotEmpty) {
      await _repository.saveAll(saved.values);
    }
    return saved.values.toList();
  }

  static String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${_random.nextInt(0x7fffffff).toRadixString(36)}';
}

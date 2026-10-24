import 'dart:async' show StreamSubscription;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:netlens/mock/application/netlens_mock_merger.dart';
import 'package:netlens/mock/application/netlens_mock_recorder.dart';
import 'package:netlens/mock/data/netlens_call_mock_mapper.dart';
import 'package:netlens/mock/data/netlens_har_mock_importer.dart';
import 'package:netlens/mock/data/netlens_memory_mock_repository.dart';
import 'package:netlens/mock/data/netlens_mock_importer.dart';
import 'package:netlens/mock/data/netlens_mock_json_codec.dart';
import 'package:netlens/mock/data/netlens_postman_collection_codec.dart';
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_matcher.dart';
import 'package:netlens/mock/domain/netlens_mock_mode.dart';
import 'package:netlens/mock/domain/netlens_mock_repository.dart';
import 'package:netlens/mock/domain/netlens_mock_request.dart';
import 'package:netlens/mock/domain/netlens_mock_resolver.dart';
import 'package:netlens/mock/domain/netlens_mock_response.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:rxdart/subjects.dart';

/// Records calls as mock endpoints and replays them, so the app can be run and
/// tested offline. It's the entry point of the mocks feature: the inspector,
/// the HTTP client adapters and [NetLensMockServer] all go through it.
///
/// In [NetLensMockMode.record] every finished call is saved as a mock. In
/// [NetLensMockMode.replay] the mock adapters of the HTTP clients answer
/// matching requests with the saved responses. With [saveAllCalls] every
/// finished call is saved whatever the mode is.
class NetLensMocks implements NetLensMockResolver {
  NetLensMocks({
    NetLensMockMode mode = NetLensMockMode.off,
    bool saveAllCalls = false,
    NetLensMockRepository? repository,
    this.matcher = const NetLensDefaultMockMatcher(),
    this.fallback = NetLensMockFallback.network,
    this.simulateLatency = false,
    NetLensCallMockMapper? mapper,
    String Function()? idGenerator,
    List<NetLensMockImporter>? importers,
  }) : repository = repository ?? NetLensMemoryMockRepository(),
       _modeSubject = BehaviorSubject.seeded(mode),
       _saveAllCallsSubject = BehaviorSubject.seeded(saveAllCalls),
       _importers =
           importers ??
           const [
             NetLensMockJsonCodec(),
             NetLensHarMockImporter(),
             NetLensPostmanCollectionCodec(),
           ] {
    _recorder = NetLensMockRecorder(
      repository: this.repository,
      mapper: mapper,
      idGenerator: idGenerator,
    );
  }

  /// Place where mocks are kept.
  final NetLensMockRepository repository;

  /// Decides which mock answers a request.
  final NetLensMockMatcher matcher;

  /// What happens in replay mode when no mock matches a request.
  final NetLensMockFallback fallback;

  /// Whether mocks wait as long as the recorded call took before answering.
  final bool simulateLatency;

  final BehaviorSubject<NetLensMockMode> _modeSubject;
  final BehaviorSubject<bool> _saveAllCallsSubject;
  final List<NetLensMockImporter> _importers;
  late final NetLensMockRecorder _recorder;

  /// Ids of calls which were already recorded in this record session.
  final Set<int> _recordedCallIds = {};

  static const NetLensMockJsonCodec _codec = NetLensMockJsonCodec();
  static const NetLensPostmanCollectionCodec _collectionCodec =
      NetLensPostmanCollectionCodec();

  /// Current mode.
  NetLensMockMode get mode => _modeSubject.value;

  set mode(NetLensMockMode mode) {
    if (mode != this.mode) {
      _recordedCallIds.clear();
      _modeSubject.add(mode);
    }
  }

  /// Stream which returns the mode on change.
  Stream<NetLensMockMode> get modeStream => _modeSubject.stream;

  /// Whether every finished call is saved as a mock, whatever the mode is, so
  /// it can be replayed or exported later. Calls answered by a mock aren't
  /// saved again. Users can change it in the NetLens settings.
  bool get saveAllCalls => _saveAllCallsSubject.value;

  set saveAllCalls(bool saveAllCalls) {
    if (saveAllCalls != this.saveAllCalls) {
      _saveAllCallsSubject.add(saveAllCalls);
    }
  }

  /// Stream which returns [saveAllCalls] on change.
  Stream<bool> get saveAllCallsStream => _saveAllCallsSubject.stream;

  /// Returns all mocks.
  List<NetLensMock> get mocks => repository.getMocks();

  /// Stream which returns all mocks on change.
  Stream<List<NetLensMock>> get mocksStream => repository.mocksStream;

  /// Returns the enabled mock which answers [request], whatever the mode is.
  NetLensMock? findMock(NetLensMockRequest request) => mocks.firstWhereOrNull(
    (NetLensMock mock) => matcher.matches(mock, request),
  );

  /// Returns the response of the mock which answers [request]. Returns null
  /// when mocks aren't replayed, or when no mock matches and [fallback] is
  /// [NetLensMockFallback.network].
  @override
  Future<NetLensMockResponse?> resolve(NetLensMockRequest request) async {
    if (mode != NetLensMockMode.replay) {
      return null;
    }
    final NetLensMock? mock = findMock(request);
    if (mock == null) {
      return switch (fallback) {
        NetLensMockFallback.network => null,
        NetLensMockFallback.notFound => _notFound(request),
      };
    }
    if (simulateLatency && mock.response.delay > Duration.zero) {
      await Future<void>.delayed(mock.response.delay);
    }
    return mock.response.copyWith(
      headers: {
        ...mock.response.headers,
        NetLensMockResponse.mockHeader: mock.id,
      },
    );
  }

  /// Saves [call] as a mock. Returns the mock, or null when [call] has no
  /// response which can be replayed.
  Future<NetLensMock?> record(NetLensHttpCall call) => _recorder.record(call);

  /// Saves every call of [calls] which can be replayed. Returns the saved
  /// mocks.
  Future<List<NetLensMock>> recordAll(Iterable<NetLensHttpCall> calls) =>
      _recorder.recordAll(calls);

  /// Records calls of [callsStream] while the mode is
  /// [NetLensMockMode.record] or [saveAllCalls] is true. Each call is recorded
  /// once, after it finished.
  StreamSubscription<List<NetLensHttpCall>> recordFrom(
    Stream<List<NetLensHttpCall>> callsStream,
  ) => callsStream.listen(_onCallsChanged);

  Future<void> _onCallsChanged(List<NetLensHttpCall> calls) async {
    if (mode != NetLensMockMode.record && !saveAllCalls) {
      return;
    }
    final List<NetLensHttpCall> finished = [
      for (final NetLensHttpCall call in calls)
        if (NetLensCallMockMapper.canMap(call) &&
            !_isAnsweredByMock(call) &&
            _recordedCallIds.add(call.id))
          call,
    ];
    if (finished.isNotEmpty) {
      await _recorder.recordAll(finished);
    }
  }

  /// Turns the mock with [id] on or off.
  Future<void> setEnabled(String id, {required bool enabled}) async {
    final NetLensMock? mock = mocks.firstWhereOrNull(
      (NetLensMock mock) => mock.id == id,
    );
    if (mock != null && mock.enabled != enabled) {
      await repository.save(mock.copyWith(enabled: enabled));
    }
  }

  /// Removes the mock with [id].
  Future<void> remove(String id) async => repository.remove(id);

  /// Removes all mocks.
  Future<void> clear() async => repository.clear();

  /// Returns [mocks], all mocks by default, in the NetLens mocks JSON format.
  String export({Iterable<NetLensMock>? mocks}) =>
      _codec.encode((mocks ?? this.mocks).toList());

  /// Returns [mocks], all mocks by default, as a Postman collection named
  /// [name]. See [NetLensPostmanCollectionCodec].
  String exportCollection({
    Iterable<NetLensMock>? mocks,
    String name = 'NetLens',
  }) => _collectionCodec.encode((mocks ?? this.mocks).toList(), name: name);

  /// Adds mocks from [content], a document in the NetLens mocks JSON format, a
  /// HAR file or a Postman collection. Mocks of requests which already have
  /// one replace them. Returns the added mocks. Throws [FormatException] when
  /// the format is unknown.
  Future<List<NetLensMock>> import(String content) =>
      _recorder.saveAll(decode(content));

  /// Returns mocks of [content], in any format [import] reads, without saving
  /// them. Throws [FormatException] when the format is unknown.
  List<NetLensMock> decode(String content) {
    final Object? json = jsonDecode(content);
    final NetLensMockImporter? importer = _importers.firstWhereOrNull(
      (NetLensMockImporter importer) => importer.canImport(json),
    );
    if (importer == null) {
      throw const FormatException('Unknown mocks format.');
    }
    return importer.import(json);
  }

  /// Plans merging the saved mocks, as a source named [currentName], with
  /// [sources], for example collections shared by teammates. Saved mocks win
  /// the default choices of conflicts. Save the result with [replaceAll].
  NetLensMockMergePlan planMerge(
    List<NetLensMockSource> sources, {
    String currentName = 'Current',
  }) => const NetLensMockMerger().plan([
    if (mocks.isNotEmpty) NetLensMockSource(name: currentName, mocks: mocks),
    ...sources,
  ]);

  /// Replaces all mocks with [mocks], for example the result of a merge.
  /// Saved mocks of the same request keep their id and enabled state. Returns
  /// the saved mocks.
  Future<List<NetLensMock>> replaceAll(Iterable<NetLensMock> mocks) async {
    final List<NetLensMock> next = mocks.toList();
    final Set<String> keys = {
      for (final NetLensMock mock in next) mock.requestKey,
    };
    for (final NetLensMock mock in this.mocks) {
      if (!keys.contains(mock.requestKey)) {
        await repository.remove(mock.id);
      }
    }
    return _recorder.saveAll(next);
  }

  /// Releases resources.
  void dispose() {
    _modeSubject.close();
    _saveAllCallsSubject.close();
  }

  /// Returns true when a mock, or the missing mock fallback, answered [call].
  static bool _isAnsweredByMock(NetLensHttpCall call) =>
      call.response?.headers?.keys.any(
        (String name) => name.toLowerCase() == NetLensMockResponse.mockHeader,
      ) ??
      false;

  NetLensMockResponse _notFound(NetLensMockRequest request) =>
      NetLensMockResponse(
        status: 404,
        headers: const {
          'content-type': 'application/json; charset=utf-8',
          NetLensMockResponse.mockHeader: NetLensMockResponse.missingMockId,
        },
        body: jsonEncode({
          'error':
              'No NetLens mock for ${request.method.toUpperCase()} '
              '${request.uri.path}',
        }),
      );
}

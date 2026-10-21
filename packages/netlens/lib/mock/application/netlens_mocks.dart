import 'dart:async' show StreamSubscription;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:netlens/mock/application/netlens_mock_recorder.dart';
import 'package:netlens/mock/data/netlens_call_mock_mapper.dart';
import 'package:netlens/mock/data/netlens_har_mock_importer.dart';
import 'package:netlens/mock/data/netlens_memory_mock_repository.dart';
import 'package:netlens/mock/data/netlens_mock_importer.dart';
import 'package:netlens/mock/data/netlens_mock_json_codec.dart';
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
/// matching requests with the saved responses.
class NetLensMocks implements NetLensMockResolver {
  NetLensMocks({
    NetLensMockMode mode = NetLensMockMode.off,
    NetLensMockRepository? repository,
    this.matcher = const NetLensDefaultMockMatcher(),
    this.fallback = NetLensMockFallback.network,
    this.simulateLatency = false,
    NetLensCallMockMapper? mapper,
    String Function()? idGenerator,
    List<NetLensMockImporter>? importers,
  }) : repository = repository ?? NetLensMemoryMockRepository(),
       _modeSubject = BehaviorSubject.seeded(mode),
       _importers =
           importers ??
           const [NetLensMockJsonCodec(), NetLensHarMockImporter()] {
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
  final List<NetLensMockImporter> _importers;
  late final NetLensMockRecorder _recorder;

  /// Ids of calls which were already recorded in this record session.
  final Set<int> _recordedCallIds = {};

  static const NetLensMockJsonCodec _codec = NetLensMockJsonCodec();

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
  /// [NetLensMockMode.record]. Each call is recorded once, after it finished.
  StreamSubscription<List<NetLensHttpCall>> recordFrom(
    Stream<List<NetLensHttpCall>> callsStream,
  ) => callsStream.listen(_onCallsChanged);

  Future<void> _onCallsChanged(List<NetLensHttpCall> calls) async {
    if (mode != NetLensMockMode.record) {
      return;
    }
    final List<NetLensHttpCall> finished = [
      for (final NetLensHttpCall call in calls)
        if (NetLensCallMockMapper.canMap(call) && _recordedCallIds.add(call.id))
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

  /// Returns all mocks in the NetLens mocks JSON format.
  String export() => _codec.encode(mocks);

  /// Adds mocks from [content], a document in the NetLens mocks JSON format or
  /// a HAR file. Mocks of requests which already have one replace them.
  /// Returns the added mocks. Throws [FormatException] when the format is
  /// unknown.
  Future<List<NetLensMock>> import(String content) {
    final Object? json = jsonDecode(content);
    final NetLensMockImporter? importer = _importers.firstWhereOrNull(
      (NetLensMockImporter importer) => importer.canImport(json),
    );
    if (importer == null) {
      throw const FormatException('Unknown mocks format.');
    }
    return _recorder.saveAll(importer.import(json));
  }

  /// Releases resources.
  void dispose() => _modeSubject.close();

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

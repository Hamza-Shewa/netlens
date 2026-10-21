import 'dart:async' show FutureOr;
import 'dart:developer' show log;
import 'dart:io' show File;

import 'package:netlens/mock/data/netlens_memory_mock_repository.dart';
import 'package:netlens/mock/data/netlens_mock_json_codec.dart';
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_repository.dart';

/// Repository which saves mocks to a JSON file, so mocks recorded once can be
/// replayed after the app is restarted. The file has the format of
/// [NetLensMockJsonCodec], so it can be shared and loaded in tests.
class NetLensFileMockRepository implements NetLensMockRepository {
  NetLensFileMockRepository(
    this.file, {
    NetLensMockJsonCodec codec = const NetLensMockJsonCodec(),
  }) : _codec = codec;

  final File file;
  final NetLensMockJsonCodec _codec;
  final NetLensMemoryMockRepository _cache = NetLensMemoryMockRepository();

  /// Writes are chained, so the file always ends with the latest mocks.
  Future<void> _pendingWrite = Future<void>.value();

  /// Reads mocks saved in [file]. Call it once before the mocks are used. A
  /// missing or broken file leaves the repository empty.
  Future<void> load() async {
    try {
      if (await file.exists()) {
        _cache
          ..clear()
          ..saveAll(_codec.decode(await file.readAsString()));
      }
    } catch (exception) {
      log('Loading mocks failed: $exception', name: 'NetLens');
    }
  }

  @override
  Stream<List<NetLensMock>> get mocksStream => _cache.mocksStream;

  @override
  List<NetLensMock> getMocks() => _cache.getMocks();

  @override
  Future<void> save(NetLensMock mock) => _write(() => _cache.save(mock));

  @override
  Future<void> saveAll(Iterable<NetLensMock> mocks) =>
      _write(() => _cache.saveAll(mocks));

  @override
  Future<void> remove(String id) => _write(() => _cache.remove(id));

  @override
  Future<void> clear() => _write(_cache.clear);

  Future<void> _write(FutureOr<void> Function() change) {
    change();
    final String content = _codec.encode(getMocks());
    return _pendingWrite = _pendingWrite.then((_) async {
      try {
        await file.parent.create(recursive: true);
        await file.writeAsString(content, flush: true);
      } catch (exception) {
        log('Saving mocks failed: $exception', name: 'NetLens');
      }
    });
  }
}

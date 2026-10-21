import 'dart:io';

import 'package:netlens/netlens_mocks.dart';
import 'package:test/test.dart';

import 'mock_test_data.dart';

void main() {
  group('NetLensFileMockRepository', () {
    late Directory directory;
    late File file;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('netlens_mocks');
      file = File('${directory.path}/mocks/mocks.json');
    });
    tearDown(() => directory.delete(recursive: true));

    test('keeps mocks after a restart', () async {
      final NetLensFileMockRepository repository = NetLensFileMockRepository(
        file,
      );
      await repository.load();
      expect(repository.getMocks(), isEmpty);

      await repository.saveAll([mock(id: 'a'), mock(id: 'b', url: '/b')]);
      await repository.remove('a');

      final NetLensFileMockRepository restarted = NetLensFileMockRepository(
        file,
      );
      await restarted.load();
      expect(restarted.getMocks().map((NetLensMock mock) => mock.id), ['b']);
    });

    test('stays empty when the file is broken', () async {
      await file.create(recursive: true);
      await file.writeAsString('not json');
      final NetLensFileMockRepository repository = NetLensFileMockRepository(
        file,
      );
      await repository.load();
      expect(repository.getMocks(), isEmpty);
    });
  });
}

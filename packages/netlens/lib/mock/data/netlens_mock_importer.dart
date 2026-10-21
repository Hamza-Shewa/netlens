import 'package:netlens/mock/domain/netlens_mock.dart';

/// Reads mocks from a decoded JSON document of one format.
abstract interface class NetLensMockImporter {
  /// Returns true when [json] has the format of this importer.
  bool canImport(Object? json);

  /// Returns mocks found in [json].
  List<NetLensMock> import(Object? json);
}

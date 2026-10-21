import 'dart:async' show FutureOr;

import 'package:netlens/mock/domain/netlens_mock.dart';

/// Place where mocks are kept.
abstract interface class NetLensMockRepository {
  /// Stream which returns all mocks on change.
  Stream<List<NetLensMock>> get mocksStream;

  /// Returns all mocks in the order they were added.
  List<NetLensMock> getMocks();

  /// Adds [mock], or replaces the mock which has the same id.
  FutureOr<void> save(NetLensMock mock);

  /// Adds or replaces all [mocks] at once.
  FutureOr<void> saveAll(Iterable<NetLensMock> mocks);

  /// Removes the mock with [id].
  FutureOr<void> remove(String id);

  /// Removes all mocks.
  FutureOr<void> clear();
}

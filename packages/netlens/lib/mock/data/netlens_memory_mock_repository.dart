import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_repository.dart';
import 'package:rxdart/subjects.dart';

/// Repository which keeps mocks in memory. It's the default repository, so
/// mocks are gone when the app is closed.
class NetLensMemoryMockRepository implements NetLensMockRepository {
  NetLensMemoryMockRepository({Iterable<NetLensMock> mocks = const []})
    : _mocksSubject = BehaviorSubject.seeded(List.unmodifiable(mocks));

  final BehaviorSubject<List<NetLensMock>> _mocksSubject;

  @override
  Stream<List<NetLensMock>> get mocksStream => _mocksSubject.stream;

  @override
  List<NetLensMock> getMocks() => _mocksSubject.value;

  @override
  void save(NetLensMock mock) => saveAll([mock]);

  @override
  void saveAll(Iterable<NetLensMock> mocks) {
    final List<NetLensMock> updated = [...getMocks()];
    for (final NetLensMock mock in mocks) {
      final int index = updated.indexWhere(
        (NetLensMock existing) => existing.id == mock.id,
      );
      if (index == -1) {
        updated.add(mock);
      } else {
        updated[index] = mock;
      }
    }
    _emit(updated);
  }

  @override
  void remove(String id) =>
      _emit(getMocks().where((NetLensMock mock) => mock.id != id).toList());

  @override
  void clear() => _emit(const []);

  void _emit(List<NetLensMock> mocks) =>
      _mocksSubject.add(List.unmodifiable(mocks));
}

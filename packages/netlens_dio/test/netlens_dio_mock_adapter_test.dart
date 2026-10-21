import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart' as http_mock_adapter;
import 'package:mocktail/mocktail.dart';
import 'package:netlens/core/netlens_core.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_http_error.dart';
import 'package:netlens/model/netlens_http_response.dart';
import 'package:netlens/model/netlens_log.dart';
import 'package:netlens/netlens_mocks.dart';
import 'package:netlens_dio/netlens_dio.dart';
import 'package:netlens_test/netlens_test.dart';
import 'package:test/test.dart';

void main() {
  late NetLensCore netLensCore;
  late NetLensMocks mocks;
  late Dio dio;
  late http_mock_adapter.DioAdapter network;

  setUp(() {
    registerFallbackValue(NetLensHttpCall(0));
    registerFallbackValue(NetLensHttpResponse());
    registerFallbackValue(NetLensHttpError());
    registerFallbackValue(NetLensLog(message: ''));

    netLensCore = NetLensCoreMock();
    when(() => netLensCore.addCall(any())).thenAnswer((_) => {});
    when(() => netLensCore.addResponse(any(), any())).thenAnswer((_) => {});
    when(() => netLensCore.addError(any(), any())).thenAnswer((_) => {});
    when(() => netLensCore.addLog(any())).thenAnswer((_) => {});

    mocks = NetLensMocks(
      mode: NetLensMockMode.replay,
      repository: NetLensMemoryMockRepository(
        mocks: [
          NetLensMock(
            id: 'users',
            method: 'GET',
            url: Uri.parse('https://api.example.com/users'),
            createdTime: DateTime(2026),
            response: const NetLensMockResponse(
              status: 200,
              headers: {'content-type': 'application/json; charset=utf-8'},
              body: '[{"id":1}]',
            ),
          ),
          NetLensMock(
            id: 'missing',
            method: 'GET',
            url: Uri.parse('https://api.example.com/missing'),
            createdTime: DateTime(2026),
            response: const NetLensMockResponse(status: 404, body: 'Nope'),
          ),
        ],
      ),
    );

    final NetLensDioAdapter adapter =
        NetLensDioAdapter()..injectCore(netLensCore);
    dio = Dio()..interceptors.add(adapter);
    network = http_mock_adapter.DioAdapter(dio: dio);
    NetLensDioMockAdapter.install(dio, mocks);
  });

  tearDown(() => mocks.dispose());

  group('NetLensDioMockAdapter', () {
    test('answers matching requests with the mock', () async {
      final Response<dynamic> response = await dio.get<dynamic>(
        'https://api.example.com/users',
      );

      expect(response.statusCode, 200);
      expect(response.data, [
        {'id': 1},
      ]);
      expect(response.headers.value(NetLensMockResponse.mockHeader), 'users');
    });

    test('lets NetLens catch mocked calls', () async {
      await dio.get<dynamic>('https://api.example.com/users');

      verify(() => netLensCore.addCall(any())).called(1);
      final NetLensHttpResponse response =
          verify(
                () => netLensCore.addResponse(captureAny(), any()),
              ).captured.single
              as NetLensHttpResponse;
      expect(response.status, 200);
      expect(response.headers?[NetLensMockResponse.mockHeader], '[users]');
    });

    test('keeps error statuses of mocks', () async {
      await expectLater(
        dio.get<dynamic>('https://api.example.com/missing'),
        throwsA(
          isA<DioException>().having(
            (DioException exception) => exception.response?.statusCode,
            'status',
            404,
          ),
        ),
      );
    });

    test('sends other requests to the network with their body', () async {
      network.onPost(
        'https://api.example.com/teams',
        (server) => server.reply(201, {'created': true}),
        data: {'name': 'NetLens'},
      );

      final Response<dynamic> response = await dio.post<dynamic>(
        'https://api.example.com/teams',
        data: {'name': 'NetLens'},
      );

      expect(response.statusCode, 201);
      expect(response.data, {'created': true});
    });

    test('sends all requests to the network when mocks are off', () async {
      mocks.mode = NetLensMockMode.off;
      network.onGet(
        'https://api.example.com/users',
        (server) => server.reply(200, ['network']),
      );

      final Response<dynamic> response = await dio.get<dynamic>(
        'https://api.example.com/users',
      );

      expect(response.data, ['network']);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:netlens/core/netlens_core.dart';
import 'package:netlens/model/netlens_form_data_file.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_http_error.dart';
import 'package:netlens/model/netlens_http_response.dart';
import 'package:netlens/model/netlens_log.dart';
import 'package:netlens/model/netlens_replay_request.dart';
import 'package:netlens_dio/netlens_dio_adapter.dart';
import 'package:netlens_test/netlens_test.dart';
import 'package:test/test.dart';

/// HTTP client adapter which keeps the bodies it sends.
class _RecordingAdapter implements HttpClientAdapter {
  final List<String> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final List<int> bytes = [
      if (requestStream != null)
        for (final Uint8List chunk in await requestStream.toList()) ...chunk,
    ];
    bodies.add(latin1.decode(bytes));
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late NetLensCore core;
  late _RecordingAdapter httpAdapter;

  setUp(() {
    registerFallbackValue(NetLensHttpCall(0));
    registerFallbackValue(NetLensHttpResponse());
    registerFallbackValue(NetLensHttpError());
    registerFallbackValue(NetLensLog(message: ''));
    core = NetLensCoreMock();
    when(() => core.addCall(any())).thenAnswer((_) => {});
    when(() => core.addResponse(any(), any())).thenAnswer((_) => {});
    when(() => core.addError(any(), any())).thenAnswer((_) => {});
    when(() => core.addLog(any())).thenAnswer((_) => {});
    httpAdapter = _RecordingAdapter();
  });

  Dio createDio(NetLensDioAdapter adapter) {
    final Dio dio = Dio()
      ..httpClientAdapter = httpAdapter
      ..interceptors.add(adapter);
    adapter
      ..injectCore(core)
      ..replayClient = dio;
    return dio;
  }

  List<NetLensHttpCall> capturedCalls() =>
      verify(() => core.addCall(captureAny())).captured.cast<NetLensHttpCall>();

  test('sends form fields and file content again', () async {
    final NetLensDioAdapter adapter = NetLensDioAdapter();
    final Dio dio = createDio(adapter);
    await dio.post<void>(
      'https://test.com/upload',
      data: FormData.fromMap({
        'title': 'Holiday',
        'photo': MultipartFile.fromBytes(
          utf8.encode('PNGDATA'),
          filename: 'photo.png',
          contentType: DioMediaType('image', 'png'),
        ),
      }),
    );
    final NetLensHttpCall call = capturedCalls().single;
    final NetLensFormDataFile file = call.request!.formDataFiles!.single;
    expect(file.name, 'photo');
    expect(file.canRead, isTrue);

    final NetLensReplayRequest request = NetLensReplayRequest.fromCall(call);
    await adapter.replay(request);

    expect(httpAdapter.bodies, hasLength(2));
    final String replayed = httpAdapter.bodies.last;
    expect(replayed, contains('name="title"'));
    expect(replayed, contains('Holiday'));
    expect(replayed, contains('name="photo"; filename="photo.png"'));
    expect(replayed, contains('content-type: image/png'));
    expect(replayed, contains('PNGDATA'));

    final NetLensHttpCall replayedCall = capturedCalls().single;
    expect(
      replayedCall.request!.formDataFiles!.single.canRead,
      isTrue,
      reason: 'A replayed call can be sent again too',
    );
  });

  test('does not keep files when told not to', () async {
    final NetLensDioAdapter adapter = NetLensDioAdapter(
      keepFormDataFiles: false,
    );
    await createDio(adapter).post<void>(
      'https://test.com/upload',
      data: FormData.fromMap({
        'photo': MultipartFile.fromString('x', filename: 'a.txt'),
      }),
    );
    final NetLensHttpCall call = capturedCalls().single;
    expect(call.request!.formDataFiles!.single.canRead, isFalse);
    expect(NetLensReplayRequest.fromCall(call).omitsFormData, isTrue);
  });
}

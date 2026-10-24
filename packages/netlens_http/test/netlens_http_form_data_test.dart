import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:netlens/core/netlens_core.dart';
import 'package:netlens/model/netlens_form_data_file.dart';
import 'package:netlens/model/netlens_from_data_field.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_replay_request.dart';
import 'package:netlens_http/netlens_http_adapter.dart';
import 'package:netlens_test/netlens_test.dart';
import 'package:test/test.dart';

void main() {
  late NetLensCore core;
  late NetLensHttpAdapter adapter;
  late List<String> sentBodies;
  late MockClient client;

  setUp(() {
    registerFallbackValue(NetLensHttpCall(0));
    core = NetLensCoreMock();
    when(() => core.addCall(any())).thenAnswer((_) {});
    sentBodies = [];
    client = MockClient.streaming((
      http.BaseRequest request,
      http.ByteStream body,
    ) async {
      sentBodies.add(await body.bytesToString());
      return http.StreamedResponse(
        Stream.value(utf8.encode('{}')),
        200,
        request: request,
      );
    });
    adapter = NetLensHttpAdapter(replayClient: client)..injectCore(core);
  });

  NetLensHttpCall capturedCall() =>
      verify(() => core.addCall(captureAny())).captured.single
          as NetLensHttpCall;

  test('records fields and files of a multipart request', () async {
    final http.MultipartRequest request =
        http.MultipartRequest('POST', Uri.parse('https://test.com/upload'))
          ..fields['title'] = 'Holiday'
          ..files.add(
            http.MultipartFile.fromString('photo', 'DATA', filename: 'a.png'),
          );
    adapter.onResponse(
      await http.Response.fromStream(await client.send(request)),
    );

    final NetLensHttpCall call = capturedCall();
    expect(call.request?.body, 'Form data');
    final NetLensFormDataField field = call.request!.formDataFields!.single;
    expect('${field.name}=${field.value}', 'title=Holiday');
    final NetLensFormDataFile file = call.request!.formDataFiles!.single;
    expect(file.name, 'photo');
    expect(file.fileName, 'a.png');
    expect(file.length, 4);
    expect(
      file.canRead,
      isFalse,
      reason: 'The http package sends the file stream only once',
    );

    final NetLensReplayRequest replay = NetLensReplayRequest.fromCall(call);
    expect(replay.omitsFormData, isTrue);
    await adapter.replay(replay);
    expect(sentBodies.last, contains('name="title"'));
    expect(sentBodies.last, isNot(contains('DATA')));
  });

  test('sends files whose content was kept', () async {
    await adapter.replay(
      NetLensReplayRequest(
        method: 'POST',
        url: 'https://test.com/upload',
        formDataFields: const [NetLensFormDataField('title', 'Trip')],
        formDataFiles: [
          NetLensFormDataFile(
            'a.png',
            'image/png',
            7,
            name: 'photo',
            read: () => Stream.value(utf8.encode('PNGDATA')),
          ),
        ],
      ),
    );

    final String body = sentBodies.single;
    expect(body, contains('name="title"'));
    expect(body, contains('Trip'));
    expect(body, contains('name="photo"; filename="a.png"'));
    expect(body, contains('content-type: image/png'));
    expect(body, contains('PNGDATA'));
    expect(capturedCall().request!.formDataFiles!.single.canRead, isTrue);
  });
}

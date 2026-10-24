import 'package:netlens/model/netlens_form_data_file.dart';
import 'package:netlens/model/netlens_from_data_field.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_http_request.dart';
import 'package:netlens/model/netlens_replay_request.dart';
import 'package:test/test.dart';

void main() {
  group('NetLensReplayRequest', () {
    test('is built from a call', () {
      final NetLensReplayRequest request = NetLensReplayRequest.fromCall(
        NetLensHttpCall(1)
          ..method = 'post'
          ..uri = 'https://api.example.com/items?page=1'
          ..request = (NetLensHttpRequest()
            ..headers = {
              'content-type': 'application/json',
              'Content-Length': '12',
              'Host': 'api.example.com',
            }
            ..body = {'name': 'a'}),
      );
      expect(request.method, 'POST');
      expect(request.url, 'https://api.example.com/items?page=1');
      expect(request.headers, {'content-type': 'application/json'});
      expect(request.body, '{"name":"a"}');
      expect(request.omitsFormData, false);
    });

    test('builds the URL from server, endpoint and query parameters', () {
      final NetLensReplayRequest request = NetLensReplayRequest.fromCall(
        NetLensHttpCall(1)
          ..method = 'GET'
          ..secure = true
          ..server = 'api.example.com'
          ..endpoint = '/items'
          ..request = (NetLensHttpRequest()..queryParameters = {'page': 2}),
      );
      expect(request.url, 'https://api.example.com/items?page=2');
      expect(request.hasBody, false);
    });

    test('keeps form fields and files of a call', () {
      Stream<List<int>> read() => Stream.value([1, 2, 3]);
      final NetLensReplayRequest request = NetLensReplayRequest.fromCall(
        NetLensHttpCall(1)
          ..method = 'POST'
          ..uri = 'https://api.example.com/upload'
          ..request = (NetLensHttpRequest()
            ..headers = {
              'Content-Type': 'multipart/form-data; boundary=old',
              'x-token': 'abc',
            }
            ..body = 'Form data'
            ..formDataFields = [const NetLensFormDataField('a', 'b')]
            ..formDataFiles = [
              NetLensFormDataFile(
                'photo.png',
                'image/png',
                3,
                name: 'photo',
                read: read,
              ),
            ]),
      );
      expect(request.body, null);
      expect(request.isFormData, true);
      expect(request.formDataFields.single.name, 'a');
      expect(request.formDataFiles.single.name, 'photo');
      expect(request.omitsFormData, false);
      expect(request.headers, {
        'x-token': 'abc',
      }, reason: 'The client sets a new multipart boundary');
    });

    test('tells which files can not be sent again', () {
      final NetLensReplayRequest request = NetLensReplayRequest.fromCall(
        NetLensHttpCall(1)
          ..method = 'POST'
          ..uri = 'https://api.example.com/upload'
          ..request = (NetLensHttpRequest()
            ..body = 'Form data'
            ..formDataFiles = [const NetLensFormDataFile('a.txt', '', 1)]),
      );
      expect(request.omitsFormData, true);
      expect(request.omittedFiles.single.fileName, 'a.txt');
    });

    test('converts headers to and from text', () {
      expect(
        NetLensReplayRequest.headersToText({'Accept': 'json', 'X-Id': '1'}),
        'Accept: json\nX-Id: 1',
      );
      final parsed = NetLensReplayRequest.parseHeaders(
        'Accept: json\n\n X-Url: http://a ',
      );
      expect(parsed.headers, {'Accept': 'json', 'X-Url': 'http://a'});
      expect(parsed.invalidLine, null);
      expect(
        NetLensReplayRequest.parseHeaders('Accept: json\nbroken').invalidLine,
        2,
      );
    });
  });
}

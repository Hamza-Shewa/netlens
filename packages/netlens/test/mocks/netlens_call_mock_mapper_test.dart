import 'dart:convert';

import 'package:netlens/model/netlens_from_data_field.dart';
import 'package:netlens/netlens_mocks.dart';
import 'package:test/test.dart';

import 'mock_test_data.dart';

void main() {
  group('NetLensCallMockMapper', () {
    final NetLensCallMockMapper mapper = NetLensCallMockMapper(
      clock: () => DateTime(2026),
    );

    test('maps request and response of a finished call', () {
      final NetLensMock mock =
          mapper.map(
            finishedCall(
              method: 'post',
              requestBody: {'name': 'Ada'},
              status: 201,
              responseHeaders: {
                'Content-Type': '[application/json; charset=utf-8]',
                'content-length': '12',
                'x-request-id': 'abc',
              },
            ),
          )!;

      expect(mock.id, isEmpty);
      expect(mock.method, 'POST');
      expect(mock.url, Uri.parse('https://api.example.com/users?page=1'));
      expect(mock.requestBody, '{"name":"Ada"}');
      expect(mock.createdTime, DateTime(2026));
      expect(mock.response.status, 201);
      expect(mock.response.body, '[{"id":1}]');
      expect(mock.response.delay, const Duration(milliseconds: 250));
      expect(mock.response.headers, {
        'content-type': 'application/json; charset=utf-8',
        'x-request-id': 'abc',
      });
    });

    test('adds JSON content type to decoded JSON bodies', () {
      final NetLensMock mock = mapper.map(finishedCall())!;
      expect(
        mock.response.headers['content-type'],
        'application/json; charset=utf-8',
      );
    });

    test('keeps text bodies as they are', () {
      final NetLensMock mock =
          mapper.map(finishedCall(responseBody: 'plain text'))!;
      expect(mock.response.body, 'plain text');
      expect(mock.response.headers, isEmpty);
    });

    test('stores binary bodies as base64', () {
      final NetLensMock mock =
          mapper.map(finishedCall(responseBody: <int>[0, 255, 1]))!;
      expect(mock.response.bodyEncoding, NetLensMockBodyEncoding.base64);
      expect(mock.response.body, base64Encode([0, 255, 1]));
      expect(mock.response.bodyBytes, [0, 255, 1]);
    });

    test('drops the body of form data, which NetLens does not keep', () {
      final call = finishedCall(method: 'POST', requestBody: 'Form data');
      call.request!.formDataFields = [NetLensFormDataField('name', 'Ada')];
      expect(mapper.map(call)!.requestBody, isNull);
    });

    test('skips calls which have no response to replay', () {
      expect(mapper.map(finishedCall(loading: true)), isNull);
      expect(mapper.map(finishedCall(status: -1)), isNull);
      expect(mapper.map(finishedCall(status: null)), isNull);
      expect(mapper.map(finishedCall()..response = null), isNull);
    });
  });
}

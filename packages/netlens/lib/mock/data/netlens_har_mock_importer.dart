import 'package:netlens/mock/data/netlens_mock_headers.dart';
import 'package:netlens/mock/data/netlens_mock_importer.dart';
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_response.dart';

/// Reads mocks from an HTTP Archive (HAR 1.2), for example one exported by
/// NetLens, Chrome DevTools, Proxyman or Charles. Entries without a response
/// are skipped.
class NetLensHarMockImporter implements NetLensMockImporter {
  const NetLensHarMockImporter();

  @override
  bool canImport(Object? json) =>
      json is Map && json['log'] is Map && json['log']['entries'] is List;

  @override
  List<NetLensMock> import(Object? json) {
    if (!canImport(json)) {
      throw const FormatException('Not a HAR document.');
    }
    final List<dynamic> entries = (json! as Map)['log']['entries'] as List;
    final List<NetLensMock> mocks = [];
    for (final dynamic entry in entries) {
      final NetLensMock? mock = _importEntry(entry as Map<String, dynamic>);
      if (mock != null) {
        mocks.add(mock);
      }
    }
    return mocks;
  }

  NetLensMock? _importEntry(Map<String, dynamic> entry) {
    final Map<String, dynamic>? request =
        entry['request'] as Map<String, dynamic>?;
    final Map<String, dynamic>? response =
        entry['response'] as Map<String, dynamic>?;
    final int status = response?['status'] as int? ?? 0;
    final Uri? url = Uri.tryParse('${request?['url'] ?? ''}');
    if (request == null || status <= 0 || url == null || !url.hasAuthority) {
      return null;
    }
    final Map<String, dynamic> content =
        response!['content'] as Map<String, dynamic>? ?? const {};
    final String? requestBody =
        (request['postData'] as Map<String, dynamic>?)?['text'] as String?;
    return NetLensMock(
      id: '',
      method: '${request['method'] ?? 'GET'}'.toUpperCase(),
      url: url,
      requestBody: requestBody == null || requestBody.isEmpty
          ? null
          : requestBody,
      createdTime:
          DateTime.tryParse('${entry['startedDateTime']}')?.toLocal() ??
          DateTime.now(),
      response: NetLensMockResponse(
        status: status,
        headers: NetLensMockHeaders.normalize(_headers(response['headers'])),
        body: '${content['text'] ?? ''}',
        bodyEncoding: content['encoding'] == 'base64'
            ? NetLensMockBodyEncoding.base64
            : NetLensMockBodyEncoding.text,
        delay: Duration(milliseconds: (entry['time'] as num? ?? 0).round()),
      ),
    );
  }

  Map<String, String> _headers(Object? headers) => {
    for (final dynamic header in headers as List<dynamic>? ?? const [])
      '${header['name']}': '${header['value']}',
  };
}

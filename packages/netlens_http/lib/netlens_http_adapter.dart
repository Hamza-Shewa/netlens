import 'dart:convert';

import 'package:netlens/core/netlens_adapter.dart';
import 'package:netlens/core/netlens_call_replayer.dart';
import 'package:netlens/model/netlens_form_data_file.dart';
import 'package:netlens/model/netlens_from_data_field.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_http_request.dart';
import 'package:netlens/model/netlens_http_response.dart';
import 'package:netlens/model/netlens_replay_request.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

class NetLensHttpAdapter with NetLensAdapter implements NetLensCallReplayer {
  NetLensHttpAdapter({this.replayClient});

  /// Name of the client shown in NetLens.
  static const String clientName = 'HttpClient (http package)';

  /// Client used to send calls again from NetLens. When it is null, a new
  /// [http.Client] is used for each replay.
  http.Client? replayClient;

  @override
  bool canReplay(NetLensHttpCall call) => call.client == clientName;

  @override
  Future<void> replay(NetLensReplayRequest request) async {
    final http.Client client = replayClient ?? http.Client();
    // Files which are sent; the content of the new call can be read again.
    final List<NetLensFormDataFile> files = [
      for (final NetLensFormDataFile file in request.formDataFiles)
        if (file.canRead) file,
    ];
    try {
      final http.BaseRequest httpRequest = request.isFormData
          ? _buildMultipartRequest(request, files)
          : _buildRequest(request);
      final http.Response response = await http.Response.fromStream(
        await client.send(httpRequest),
      );
      _onResponse(response, files: files);
    } finally {
      if (replayClient == null) {
        client.close();
      }
    }
  }

  /// Builds a request with the body of [request].
  http.Request _buildRequest(NetLensReplayRequest request) {
    final http.Request httpRequest = http.Request(
      request.method,
      Uri.parse(request.url),
    )..headers.addAll(request.headers);
    if (request.body != null) {
      httpRequest.body = request.body!;
    }
    return httpRequest;
  }

  /// Builds a multipart request with the fields of [request] and [files].
  http.MultipartRequest _buildMultipartRequest(
    NetLensReplayRequest request,
    List<NetLensFormDataFile> files,
  ) {
    final http.MultipartRequest multipartRequest =
        http.MultipartRequest(request.method, Uri.parse(request.url))
          ..headers.addAll(request.headers)
          ..fields.addAll({
            for (final NetLensFormDataField field in request.formDataFields)
              field.name: field.value,
          });
    for (final NetLensFormDataFile file in files) {
      multipartRequest.files.add(
        http.MultipartFile(
          file.name ?? 'file',
          file.read!(),
          file.length,
          filename: file.fileName,
          contentType: _tryParseMediaType(file.contentType),
        ),
      );
    }
    return multipartRequest;
  }

  /// Returns [contentType] as a media type, or null when it isn't one.
  MediaType? _tryParseMediaType(String contentType) {
    try {
      return MediaType.parse(contentType);
    } on FormatException {
      return null;
    }
  }

  /// Handles http response. It creates both request and response from http call
  void onResponse(http.Response response, {dynamic body}) =>
      _onResponse(response, body: body);

  /// Handles http response. [files] are the files of a replayed multipart
  /// request, in the order they were sent, so their content can be read again.
  void _onResponse(
    http.Response response, {
    dynamic body,
    List<NetLensFormDataFile> files = const [],
  }) {
    if (response.request == null) {
      return;
    }
    final request = response.request!;

    final call = NetLensHttpCall(response.request.hashCode)
      ..loading = true
      ..client = clientName
      ..uri = request.url.toString()
      ..method = request.method;
    var path = request.url.path;
    if (path.isEmpty) {
      path = '/';
    }
    call
      ..endpoint = path
      ..server = request.url.host;
    if (request.url.scheme == 'https') {
      call.secure = true;
    }

    final httpRequest = NetLensHttpRequest();

    if (response.request is http.Request) {
      // we are guaranteed` the existence of body and headers
      if (body != null) {
        httpRequest.body = body;
      }
      // ignore: cast_nullable_to_non_nullable
      httpRequest
        ..body = body ?? (response.request! as http.Request).body ?? ''
        ..size = utf8.encode(httpRequest.body.toString()).length
        ..headers = Map<String, String>.from(response.request!.headers);
    } else if (request is http.MultipartRequest) {
      // The content of files was already sent, so only files of a replayed
      // request can be read again.
      httpRequest
        ..body = body ?? 'Form data'
        ..size = request.contentLength
        ..headers = Map<String, String>.from(request.headers)
        ..formDataFields = [
          for (final MapEntry<String, String> field in request.fields.entries)
            NetLensFormDataField(field.key, field.value),
        ]
        ..formDataFiles = [
          for (int index = 0; index < request.files.length; index++)
            NetLensFormDataFile(
              request.files[index].filename,
              request.files[index].contentType.toString(),
              request.files[index].length,
              name: request.files[index].field,
              read: index < files.length ? files[index].read : null,
            ),
        ];
    } else if (body == null) {
      httpRequest
        ..size = 0
        ..body = '';
    } else {
      httpRequest
        ..size = utf8.encode(body.toString()).length
        ..body = body;
    }

    httpRequest.time = DateTime.now();

    String? contentType = 'unknown';
    if (httpRequest.headers.containsKey('Content-Type')) {
      contentType = httpRequest.headers['Content-Type'];
    }

    httpRequest
      ..contentType = contentType
      ..queryParameters = response.request!.url.queryParameters;

    final httpResponse = NetLensHttpResponse()
      ..status = response.statusCode
      ..body = response.body
      // ignore: noop_primitive_operations
      ..size = utf8.encode(response.body.toString()).length
      ..time = DateTime.now();
    final responseHeaders = <String, String>{};
    response.headers.forEach((header, values) {
      responseHeaders[header] = values;
    });
    httpResponse.headers = responseHeaders;

    call
      ..request = httpRequest
      ..response = httpResponse
      ..loading = false
      ..duration =
          httpResponse.time.millisecondsSinceEpoch -
          httpRequest.time.millisecondsSinceEpoch;
    netLensCore.addCall(call);
  }
}

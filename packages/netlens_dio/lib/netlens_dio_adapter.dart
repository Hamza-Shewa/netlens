import 'dart:convert';

import 'package:netlens/core/netlens_adapter.dart';
import 'package:netlens/core/netlens_call_replayer.dart';
import 'package:netlens/model/netlens_form_data_file.dart';
import 'package:netlens/model/netlens_from_data_field.dart';
import 'package:netlens/model/netlens_http_call.dart';
import 'package:netlens/model/netlens_http_error.dart';
import 'package:netlens/model/netlens_http_request.dart';
import 'package:netlens/model/netlens_http_response.dart';
import 'package:netlens/model/netlens_log.dart';
import 'package:netlens/model/netlens_replay_request.dart';
import 'package:netlens/utils/netlens_parser.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class NetLensDioAdapter extends InterceptorsWrapper
    with NetLensAdapter
    implements NetLensCallReplayer {
  NetLensDioAdapter({this.replayClient, this.keepFormDataFiles = true});

  /// Name of the client shown in NetLens.
  static const String clientName = 'Dio';

  /// Dio used to send calls again from NetLens. Set it to the Dio which has
  /// this adapter, so replayed calls use its base options, interceptors and
  /// HTTP client adapter. When it is null, a plain Dio with this adapter is
  /// used.
  Dio? replayClient;

  /// Whether files of form data are kept, so calls which upload them can be
  /// sent again. A file made from a path is read again from the path; a file
  /// made from bytes keeps the bytes in memory while its call is kept. Set it
  /// to false when the app uploads large files from memory.
  final bool keepFormDataFiles;

  Dio? _defaultReplayClient;

  @override
  bool canReplay(NetLensHttpCall call) => call.client == clientName;

  @override
  Future<void> replay(NetLensReplayRequest request) async {
    final Dio dio =
        replayClient ??
        (_defaultReplayClient ??= Dio()..interceptors.add(this));
    try {
      await dio.request<dynamic>(
        request.url,
        data: request.isFormData ? _buildFormData(request) : request.body,
        options: Options(
          method: request.method,
          headers: request.headers,
          // Error responses are results of the replay, not failures.
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (exception) {
      // The adapter caught the error; only a failure without any response is
      // reported to the caller.
      if (exception.response == null) {
        rethrow;
      }
    }
  }

  /// Builds form data with the fields and the files of [request]. Files whose
  /// content wasn't kept are left out.
  FormData _buildFormData(NetLensReplayRequest request) {
    final FormData formData = FormData();
    formData.fields.addAll([
      for (final NetLensFormDataField field in request.formDataFields)
        MapEntry(field.name, field.value),
    ]);
    for (final NetLensFormDataFile file in request.formDataFiles) {
      final Stream<List<int>> Function()? read = file.read;
      if (read == null) {
        continue;
      }
      formData.files.add(
        MapEntry(
          file.name ?? 'file',
          MultipartFile.fromStream(
            read,
            file.length,
            filename: file.fileName,
            contentType: _tryParseMediaType(file.contentType),
          ),
        ),
      );
    }
    return formData;
  }

  /// Returns [contentType] as a media type, or null when it isn't one.
  DioMediaType? _tryParseMediaType(String contentType) {
    try {
      return DioMediaType.parse(contentType);
    } on FormatException {
      return null;
    }
  }

  /// Returns a function which reads the content of [file] again. A clone is
  /// read, so the file sent by the app is left untouched.
  Stream<List<int>> Function() _getReader(MultipartFile file) =>
      () => file.clone().finalize();

  /// Handles dio request and creates netLens http call based on it
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final call = NetLensHttpCall(options.hashCode);

    // A typo in base URL or path (e.g. "http://host:505" + "api/login")
    // makes the URL unparsable. Record the call anyway, so NetLens can show
    // what went wrong instead of silently dropping it.
    final Uri? uri = _tryGetUri(options);
    call.method = options.method;
    if (uri != null) {
      var path = uri.path;
      if (path.isEmpty) {
        path = '/';
      }
      call
        ..endpoint = path
        ..server = uri.host
        ..uri = uri.toString()
        ..secure = uri.scheme == 'https';
    } else {
      final rawUrl = _getRawUrl(options);
      final match = RegExp(
        r'^(?:([a-zA-Z][a-zA-Z0-9+.-]*):\/\/)?([^\/?#]*)(.*)$',
      ).firstMatch(rawUrl);
      final path = match?.group(3) ?? '';
      call
        ..endpoint = path.isEmpty ? '/' : path
        ..server = match?.group(2) ?? ''
        ..uri = rawUrl
        ..secure = match?.group(1) == 'https';
    }
    call.client = clientName;

    final request = NetLensHttpRequest();

    final dynamic data = options.data;
    if (data == null) {
      request
        ..size = 0
        ..body = '';
    } else {
      if (data is FormData) {
        // ignore: avoid_dynamic_calls
        request.body += 'Form data';

        if (data.fields.isNotEmpty == true) {
          final fields = <NetLensFormDataField>[];
          for (var entry in data.fields) {
            fields.add(NetLensFormDataField(entry.key, entry.value));
          }
          request.formDataFields = fields;
        }

        if (data.files.isNotEmpty == true) {
          final files = <NetLensFormDataFile>[];
          for (var entry in data.files) {
            files.add(
              NetLensFormDataFile(
                entry.value.filename,
                entry.value.contentType.toString(),
                entry.value.length,
                name: entry.key,
                read: keepFormDataFiles ? _getReader(entry.value) : null,
              ),
            );
          }

          request.formDataFiles = files;
        }
      } else {
        request
          ..size = utf8.encode(data.toString()).length
          ..body = data;
      }
    }

    request
      ..time = DateTime.now()
      ..headers = NetLensParser.parseHeaders(headers: options.headers)
      ..contentType = options.contentType.toString()
      ..queryParameters = uri?.queryParameters ?? options.queryParameters;

    call
      ..request = request
      ..response = NetLensHttpResponse();

    netLensCore.addCall(call);
    handler.next(options);
  }

  /// Returns [options] URI or null when the URL can't be parsed.
  Uri? _tryGetUri(RequestOptions options) {
    try {
      return options.uri;
    } on FormatException {
      return null;
    }
  }

  /// Returns URL built the same way as [RequestOptions.uri], but without
  /// parsing it.
  String _getRawUrl(RequestOptions options) {
    final path = options.path;
    if (path.startsWith(RegExp(r'https?:'))) {
      return path;
    }
    return options.baseUrl + path;
  }

  /// Handles dio response and adds data to netLens http call
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final httpResponse = NetLensHttpResponse()..status = response.statusCode;

    if (response.data == null) {
      httpResponse
        ..body = ''
        ..size = 0;
    } else {
      httpResponse
        ..body = response.data
        ..size = utf8.encode(response.data.toString()).length;
    }

    httpResponse.time = DateTime.now();
    final headers = <String, String>{};
    response.headers.forEach((header, values) {
      headers[header] = values.toString();
    });
    httpResponse.headers = headers;

    netLensCore.addResponse(httpResponse, response.requestOptions.hashCode);
    handler.next(response);
  }

  /// Handles error and adds data to netLens http call
  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    final httpError = NetLensHttpError()..error = error.toString();
    if (error is Error) {
      final basicError = error as Error;
      httpError.stackTrace = basicError.stackTrace;
    }

    netLensCore.addError(httpError, error.requestOptions.hashCode);
    final httpResponse = NetLensHttpResponse()..time = DateTime.now();
    if (error.response == null) {
      httpResponse.status = -1;
      netLensCore.addResponse(httpResponse, error.requestOptions.hashCode);
    } else {
      httpResponse.status = error.response!.statusCode;

      if (error.response!.data == null) {
        httpResponse
          ..body = ''
          ..size = 0;
      } else {
        httpResponse
          ..body = error.response!.data
          ..size = utf8.encode(error.response!.data.toString()).length;
      }
      final headers = <String, String>{};
      error.response!.headers.forEach((header, values) {
        headers[header] = values.toString();
      });
      httpResponse.headers = headers;
      netLensCore.addResponse(
        httpResponse,
        error.response!.requestOptions.hashCode,
      );
      netLensCore.addLog(
        NetLensLog(
          message: error.toString(),
          level: DiagnosticLevel.error,
          error: error,
          stackTrace: error.stackTrace,
        ),
      );
    }
    handler.next(error);
  }
}

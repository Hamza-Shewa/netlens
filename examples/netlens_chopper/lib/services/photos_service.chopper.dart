// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'photos_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$PhotosService extends PhotosService {
  _$PhotosService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = PhotosService;

  @override
  Future<Response<List<Photo>>> getAll({int? albumId}) {
    final Uri $url = Uri.parse('/photos/');
    final Map<String, dynamic> $params = <String, dynamic>{'albumId': albumId};
    final ChopperCompleter<void> $abortTrigger = ChopperCompleter<void>();
    final ChopperTimer $timeout = ChopperTimer(
      const Duration(microseconds: 10000000),
      () {
        if (!$abortTrigger.isCompleted) $abortTrigger.complete();
      },
    );
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
      abortTrigger: $abortTrigger.future,
    );
    return client
        .send<List<Photo>, Photo>($request)
        .catchError(
          (_) => Future<Response<List<Photo>>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Photo>> get(int id) {
    final Uri $url = Uri.parse('/photos/${id}');
    final ChopperCompleter<void> $abortTrigger = ChopperCompleter<void>();
    final ChopperTimer $timeout = ChopperTimer(
      const Duration(microseconds: 10000000),
      () {
        if (!$abortTrigger.isCompleted) $abortTrigger.complete();
      },
    );
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      abortTrigger: $abortTrigger.future,
    );
    return client
        .send<Photo, Photo>($request)
        .catchError(
          (_) => Future<Response<Photo>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Photo>> post(Photo body) {
    final Uri $url = Uri.parse('/photos/');
    final $body = body;
    final ChopperCompleter<void> $abortTrigger = ChopperCompleter<void>();
    final ChopperTimer $timeout = ChopperTimer(
      const Duration(microseconds: 10000000),
      () {
        if (!$abortTrigger.isCompleted) $abortTrigger.complete();
      },
    );
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      abortTrigger: $abortTrigger.future,
    );
    return client
        .send<Photo, Photo>($request)
        .catchError(
          (_) => Future<Response<Photo>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Photo>> put(int id, Photo body) {
    final Uri $url = Uri.parse('/photos/${id}');
    final $body = body;
    final ChopperCompleter<void> $abortTrigger = ChopperCompleter<void>();
    final ChopperTimer $timeout = ChopperTimer(
      const Duration(microseconds: 10000000),
      () {
        if (!$abortTrigger.isCompleted) $abortTrigger.complete();
      },
    );
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      body: $body,
      abortTrigger: $abortTrigger.future,
    );
    return client
        .send<Photo, Photo>($request)
        .catchError(
          (_) => Future<Response<Photo>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Photo>> patch(int id, Photo body) {
    final Uri $url = Uri.parse('/photos/${id}');
    final $body = body;
    final ChopperCompleter<void> $abortTrigger = ChopperCompleter<void>();
    final ChopperTimer $timeout = ChopperTimer(
      const Duration(microseconds: 10000000),
      () {
        if (!$abortTrigger.isCompleted) $abortTrigger.complete();
      },
    );
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
      abortTrigger: $abortTrigger.future,
    );
    return client
        .send<Photo, Photo>($request)
        .catchError(
          (_) => Future<Response<Photo>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<void>> delete(int id) {
    final Uri $url = Uri.parse('/photos/${id}');
    final ChopperCompleter<void> $abortTrigger = ChopperCompleter<void>();
    final ChopperTimer $timeout = ChopperTimer(
      const Duration(microseconds: 10000000),
      () {
        if (!$abortTrigger.isCompleted) $abortTrigger.complete();
      },
    );
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      abortTrigger: $abortTrigger.future,
    );
    return client
        .send<void, void>($request)
        .catchError(
          (_) => Future<Response<void>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }
}

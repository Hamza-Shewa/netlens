// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'albums_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$AlbumsService extends AlbumsService {
  _$AlbumsService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = AlbumsService;

  @override
  Future<Response<List<Album>>> getAll({int? userId}) {
    final Uri $url = Uri.parse('/albums/');
    final Map<String, dynamic> $params = <String, dynamic>{'userId': userId};
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
        .send<List<Album>, Album>($request)
        .catchError(
          (_) => Future<Response<List<Album>>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Album>> get(int id) {
    final Uri $url = Uri.parse('/albums/${id}');
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
        .send<Album, Album>($request)
        .catchError(
          (_) => Future<Response<Album>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<List<Photo>>> getPhotos(int id) {
    final Uri $url = Uri.parse('/albums/${id}/photos');
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
  Future<Response<Album>> post(Album body) {
    final Uri $url = Uri.parse('/albums/');
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
        .send<Album, Album>($request)
        .catchError(
          (_) => Future<Response<Album>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Album>> put(int id, Album body) {
    final Uri $url = Uri.parse('/albums/${id}');
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
        .send<Album, Album>($request)
        .catchError(
          (_) => Future<Response<Album>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Album>> patch(int id, Album body) {
    final Uri $url = Uri.parse('/albums/${id}');
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
        .send<Album, Album>($request)
        .catchError(
          (_) => Future<Response<Album>>.error(
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
    final Uri $url = Uri.parse('/albums/${id}');
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

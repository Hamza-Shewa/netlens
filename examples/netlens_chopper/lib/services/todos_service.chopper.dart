// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'todos_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$TodosService extends TodosService {
  _$TodosService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = TodosService;

  @override
  Future<Response<List<Todo>>> getAll({int? userId, bool? completed}) {
    final Uri $url = Uri.parse('/todos/');
    final Map<String, dynamic> $params = <String, dynamic>{
      'userId': userId,
      'completed': completed,
    };
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
        .send<List<Todo>, Todo>($request)
        .catchError(
          (_) => Future<Response<List<Todo>>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Todo>> get(int id) {
    final Uri $url = Uri.parse('/todos/${id}');
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
        .send<Todo, Todo>($request)
        .catchError(
          (_) => Future<Response<Todo>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Todo>> post(Todo body) {
    final Uri $url = Uri.parse('/todos/');
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
        .send<Todo, Todo>($request)
        .catchError(
          (_) => Future<Response<Todo>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Todo>> put(int id, Todo body) {
    final Uri $url = Uri.parse('/todos/${id}');
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
        .send<Todo, Todo>($request)
        .catchError(
          (_) => Future<Response<Todo>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<Todo>> patch(int id, Todo body) {
    final Uri $url = Uri.parse('/todos/${id}');
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
        .send<Todo, Todo>($request)
        .catchError(
          (_) => Future<Response<Todo>>.error(
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
    final Uri $url = Uri.parse('/todos/${id}');
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

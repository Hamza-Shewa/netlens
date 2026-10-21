// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'invalid_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$InvalidService extends InvalidService {
  _$InvalidService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = InvalidService;

  @override
  Future<Response<InvalidModel>> get(int id) {
    final Uri $url = Uri.parse('/posts/${id}');
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
        .send<InvalidModel, InvalidModel>($request)
        .catchError(
          (_) => Future<Response<InvalidModel>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }
}

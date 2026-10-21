// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'broken_articles_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$BrokenArticlesService extends BrokenArticlesService {
  _$BrokenArticlesService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = BrokenArticlesService;

  @override
  Future<Response<List<BrokenArticle>>> getAll({int? userId}) {
    final Uri $url = Uri.parse('/posts/');
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
        .send<List<BrokenArticle>, BrokenArticle>($request)
        .catchError(
          (_) => Future<Response<List<BrokenArticle>>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }

  @override
  Future<Response<BrokenArticle>> get(int id) {
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
        .send<BrokenArticle, BrokenArticle>($request)
        .catchError(
          (_) => Future<Response<BrokenArticle>>.error(
            ChopperTimeoutException('Request timed out after 10 seconds'),
          ),
          test: (Object err) =>
              err is ChopperRequestAbortedException &&
              $abortTrigger.isCompleted,
        )
        .whenComplete($timeout.cancel);
  }
}

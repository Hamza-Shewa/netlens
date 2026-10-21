import 'package:equatable/equatable.dart';

/// Request made by the app which may be answered by a mock.
class NetLensMockRequest with Equatable {
  const NetLensMockRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.body,
  });

  /// HTTP method, for example GET.
  final String method;

  /// URL of the request. A URL without a host, as received by
  /// [NetLensMockServer], matches mocks of any host.
  final Uri uri;

  final Map<String, String> headers;

  /// Body as text, or null when the request has no body or it can't be read.
  final String? body;

  @override
  List<Object?> get props => [method, uri, headers, body];
}

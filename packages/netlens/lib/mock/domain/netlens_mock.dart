import 'package:netlens/mock/domain/netlens_mock_response.dart';
import 'package:equatable/equatable.dart';

/// Endpoint which answers matching requests with a recorded response, so the
/// app can run without the backend.
class NetLensMock with Equatable {
  const NetLensMock({
    required this.id,
    required this.method,
    required this.url,
    required this.response,
    required this.createdTime,
    this.requestBody,
    this.enabled = true,
  });

  final String id;

  /// HTTP method in upper case, for example GET.
  final String method;

  /// URL of the endpoint. A path segment `*` matches any segment, for example
  /// `https://api.example.com/users/*`.
  final Uri url;

  /// Body of the recorded request. It is compared only when the matcher
  /// matches bodies.
  final String? requestBody;

  final NetLensMockResponse response;

  /// Time the mock was recorded.
  final DateTime createdTime;

  /// Disabled mocks never match.
  final bool enabled;

  /// Identifies the request this mock answers. Recording the same request again
  /// replaces the mock which has the same key.
  String get requestKey =>
      '$method ${url.removeFragment()}${requestBody == null ? '' : ' $requestBody'}';

  NetLensMock copyWith({
    String? id,
    String? method,
    Uri? url,
    NetLensMockResponse? response,
    DateTime? createdTime,
    String? requestBody,
    bool? enabled,
  }) => NetLensMock(
    id: id ?? this.id,
    method: method ?? this.method,
    url: url ?? this.url,
    response: response ?? this.response,
    createdTime: createdTime ?? this.createdTime,
    requestBody: requestBody ?? this.requestBody,
    enabled: enabled ?? this.enabled,
  );

  @override
  List<Object?> get props => [
    id,
    method,
    url,
    requestBody,
    response,
    createdTime,
    enabled,
  ];
}

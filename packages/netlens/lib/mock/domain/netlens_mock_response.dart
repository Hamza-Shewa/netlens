import 'dart:convert' show base64Decode, base64Encode, utf8;

import 'package:equatable/equatable.dart';

/// How [NetLensMockResponse.body] is stored.
enum NetLensMockBodyEncoding {
  /// The body is text, for example JSON.
  text,

  /// The body is binary data stored as base64, for example an image.
  base64,
}

/// Response which a mock sends back instead of the network.
class NetLensMockResponse with Equatable {
  const NetLensMockResponse({
    this.status = 200,
    this.headers = const {},
    this.body = '',
    this.bodyEncoding = NetLensMockBodyEncoding.text,
    this.delay = Duration.zero,
  });

  /// Builds a response which sends [bytes] as its body.
  factory NetLensMockResponse.bytes(
    List<int> bytes, {
    int status = 200,
    Map<String, String> headers = const {},
    Duration delay = Duration.zero,
  }) => NetLensMockResponse(
    status: status,
    headers: headers,
    body: base64Encode(bytes),
    bodyEncoding: NetLensMockBodyEncoding.base64,
    delay: delay,
  );

  /// Header added to every response sent by a mock. Its value is the id of the
  /// mock, or [missingMockId] when no mock matched the request.
  static const String mockHeader = 'x-netlens-mock';

  /// Value of [mockHeader] when no mock matched the request.
  static const String missingMockId = 'missing';

  /// HTTP status code.
  final int status;

  /// Headers with lower case names.
  final Map<String, String> headers;

  /// Body as text, or as base64 when [bodyEncoding] is
  /// [NetLensMockBodyEncoding.base64].
  final String body;

  final NetLensMockBodyEncoding bodyEncoding;

  /// Time the original call took. It is waited before the response is sent
  /// when latency is simulated.
  final Duration delay;

  /// Returns [body] as bytes.
  List<int> get bodyBytes => switch (bodyEncoding) {
    NetLensMockBodyEncoding.text => utf8.encode(body),
    NetLensMockBodyEncoding.base64 => base64Decode(body),
  };

  NetLensMockResponse copyWith({
    int? status,
    Map<String, String>? headers,
    String? body,
    NetLensMockBodyEncoding? bodyEncoding,
    Duration? delay,
  }) => NetLensMockResponse(
    status: status ?? this.status,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    bodyEncoding: bodyEncoding ?? this.bodyEncoding,
    delay: delay ?? this.delay,
  );

  @override
  List<Object?> get props => [status, headers, body, bodyEncoding, delay];
}

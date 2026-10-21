import 'dart:convert' show jsonDecode;

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:netlens/mock/domain/netlens_mock.dart';
import 'package:netlens/mock/domain/netlens_mock_request.dart';

/// Decides whether a mock answers a request.
abstract interface class NetLensMockMatcher {
  bool matches(NetLensMock mock, NetLensMockRequest request);
}

/// Matcher which compares method, host, path and query parameters, and
/// optionally the body.
class NetLensDefaultMockMatcher implements NetLensMockMatcher {
  const NetLensDefaultMockMatcher({
    this.matchHost = true,
    this.matchQuery = true,
    this.matchBody = false,
    this.ignoredQueryParameters = const {},
  });

  /// Wildcard path segment which matches any segment.
  static const String wildcard = '*';

  static const DeepCollectionEquality _equality = DeepCollectionEquality();

  /// Whether the scheme, host and port must be the same. A request without a
  /// host, as received by [NetLensMockServer], matches any host.
  final bool matchHost;

  /// Whether the query parameters must be the same, in any order.
  final bool matchQuery;

  /// Whether the request body must be the same. JSON bodies are compared by
  /// value, so formatting and the order of keys don't matter.
  final bool matchBody;

  /// Query parameters which are never compared, for example cache busters.
  final Set<String> ignoredQueryParameters;

  @override
  bool matches(NetLensMock mock, NetLensMockRequest request) =>
      mock.enabled &&
      mock.method == request.method.toUpperCase() &&
      _matchesHost(mock.url, request.uri) &&
      _matchesPath(mock.url, request.uri) &&
      (!matchQuery || _matchesQuery(mock.url, request.uri)) &&
      (!matchBody || _matchesBody(mock.requestBody, request.body));

  bool _matchesHost(Uri mockUrl, Uri requestUrl) {
    if (!matchHost || !requestUrl.hasAuthority || !mockUrl.hasAuthority) {
      return true;
    }
    return mockUrl.scheme == requestUrl.scheme &&
        mockUrl.host.toLowerCase() == requestUrl.host.toLowerCase() &&
        mockUrl.port == requestUrl.port;
  }

  bool _matchesPath(Uri mockUrl, Uri requestUrl) {
    final List<String> mockSegments = _segments(mockUrl);
    final List<String> requestSegments = _segments(requestUrl);
    if (mockSegments.length != requestSegments.length) {
      return false;
    }
    for (int index = 0; index < mockSegments.length; index++) {
      final String segment = mockSegments[index];
      if (segment != wildcard && segment != requestSegments[index]) {
        return false;
      }
    }
    return true;
  }

  /// Returns path segments without empty ones, so `/users/` matches `/users`.
  List<String> _segments(Uri url) =>
      url.pathSegments.where((String segment) => segment.isNotEmpty).toList();

  bool _matchesQuery(Uri mockUrl, Uri requestUrl) =>
      _equality.equals(_query(mockUrl), _query(requestUrl));

  Map<String, Set<String>> _query(Uri url) => {
    for (final MapEntry<String, List<String>> parameter
        in url.queryParametersAll.entries)
      if (!ignoredQueryParameters.contains(parameter.key))
        parameter.key: parameter.value.toSet(),
  };

  bool _matchesBody(String? mockBody, String? requestBody) {
    final String expected = mockBody ?? '';
    final String actual = requestBody ?? '';
    if (expected == actual) {
      return true;
    }
    final Object? expectedJson = _tryDecodeJson(expected);
    final Object? actualJson = _tryDecodeJson(actual);
    return expectedJson != null && _equality.equals(expectedJson, actualJson);
  }

  Object? _tryDecodeJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

/// Cleans up response headers before they are saved in a mock.
class NetLensMockHeaders {
  /// Headers which describe how the original body was sent. The mock body is
  /// saved decoded and whole, so these headers would be wrong.
  static const Set<String> _transportHeaders = {
    'connection',
    'content-encoding',
    'content-length',
    'keep-alive',
    'transfer-encoding',
  };

  /// Returns [headers] with lower case names and without transport headers.
  /// Values which adapters saved as a list, like `[application/json]`, are
  /// unwrapped.
  static Map<String, String> normalize(Map<String, String>? headers) => {
    for (final MapEntry<String, String> header
        in headers?.entries ?? <MapEntry<String, String>>[])
      if (!_transportHeaders.contains(header.key.toLowerCase()))
        header.key.toLowerCase(): _unwrapList(header.value),
  };

  static String _unwrapList(String value) {
    final String trimmed = value.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('[') &&
        trimmed.endsWith(']')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return value;
  }
}

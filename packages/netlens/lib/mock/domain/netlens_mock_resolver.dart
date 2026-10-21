import 'package:netlens/mock/domain/netlens_mock_request.dart';
import 'package:netlens/mock/domain/netlens_mock_response.dart';

/// Finds the response which answers a request. HTTP client adapters depend on
/// this interface only, so they can be tested and used without the rest of
/// NetLens.
abstract interface class NetLensMockResolver {
  /// Returns the response for [request], or null when the request should be
  /// sent to the network.
  Future<NetLensMockResponse?> resolve(NetLensMockRequest request);
}

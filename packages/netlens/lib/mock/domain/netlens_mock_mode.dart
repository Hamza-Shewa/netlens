/// What NetLens does with mocks.
enum NetLensMockMode {
  /// Calls go to the network and aren't recorded.
  off,

  /// Every finished call is saved as a mock.
  record,

  /// Matching calls are answered by mocks instead of the network.
  replay,
}

/// What happens in [NetLensMockMode.replay] when no mock matches a request.
enum NetLensMockFallback {
  /// The request is sent to the network.
  network,

  /// The request is answered with 404, so nothing reaches the network.
  notFound,
}

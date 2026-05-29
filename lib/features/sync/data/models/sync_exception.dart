/// Thrown when the server returns 401 Unauthorized (invalid token or PIN).
class SyncAuthException implements Exception {
  const SyncAuthException();

  @override
  String toString() => 'SyncAuthException: invalid token or PIN';
}

/// Thrown on a network-level failure (socket error or request timeout).
class SyncNetworkException implements Exception {
  final String message;

  const SyncNetworkException(this.message);

  @override
  String toString() => 'SyncNetworkException: $message';
}

/// Thrown when the server returns a 4xx/5xx status other than 401.
class SyncServerException implements Exception {
  final int statusCode;

  const SyncServerException(this.statusCode);

  @override
  String toString() => 'SyncServerException: $statusCode';
}

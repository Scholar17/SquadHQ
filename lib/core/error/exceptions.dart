/// Thrown by data sources; caught by repositories and mapped to a [Failure].
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class ServerException implements Exception {
  const ServerException(this.message);

  final String message;
}

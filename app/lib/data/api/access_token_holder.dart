/// In-memory mutable holder for the current access token.
///
/// Lives below Riverpod's reach because dio interceptors are constructed
/// once and shouldn't take a Ref. The auth repository writes to this when
/// it mints/refreshes a token; the Riverpod accessTokenProvider mirrors
/// it for UI consumers.
class AccessTokenHolder {
  String? _token;

  String? get current => _token;

  // ignore: use_setters_to_change_properties
  void setToken(String? token) {
    _token = token;
  }

  /// Non-nullable convenience alias used by interceptors.
  void set(String token) => setToken(token);

  void clear() => setToken(null);
}

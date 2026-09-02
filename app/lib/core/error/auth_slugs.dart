/// Slug strings the backend returns in `application/problem+json` bodies.
/// Centralised so call sites compare against constants, not bare literals.
///
/// These are the AUTH-path slugs only, and each value must match the backend
/// verbatim — a typo here is silent, because a mismatched comparison just
/// falls through to the generic branch. Sources:
/// `api/src/jobify_api/auth/{dependencies,service}.py`.
abstract final class AuthSlugs {
  // --- Access-token path (`current_user`) ---

  /// The ONE recoverable 401: the access token is expired/invalid, so a
  /// refresh may fix it. `RefreshOn401Interceptor` refreshes on this and only
  /// this; every other slug below means the session is structurally broken.
  static const invalidAccessToken = 'invalid_access_token';
  static const missingBearerToken = 'missing_bearer_token';
  static const userNotFound = 'user_not_found';

  /// Admin suspended the account. Distinct from [userNotFound] so the UI can
  /// explain WHY the session ended rather than showing a generic sign-out.
  static const userSuspended = 'user_suspended';

  // --- Refresh path (`POST /v1/auth/refresh`) ---
  // This file used to declare `invalidRefreshToken` as
  // 'invalid_refresh_token', which the backend never emits — the real slug is
  // `invalid_refresh`. It was unreferenced, so nothing broke, but it would
  // have silently failed to match the first time anyone used it.

  static const invalidRefresh = 'invalid_refresh';
  static const expiredRefresh = 'expired_refresh';

  /// Refresh-token reuse detected — the whole token family is revoked
  /// server-side, so this is terminal for the session.
  static const tokenReused = 'token_reused';

  // --- Client-side only (never emitted by the backend) ---

  /// No refresh token in storage, so there is nothing to rotate.
  static const noRefreshToken = 'no_refresh_token';

  /// Fallback when a 401 arrives with no usable `detail`.
  static const unauthorized = 'unauthorized';
}

/// Slugs emitted by the client-side Google sign-in flow.
abstract final class GoogleSignInSlugs {
  static const cancelled = 'google_sign_in_cancelled';
  static const idTokenMissing = 'google_id_token_missing';
  static const failed = 'google_sign_in_failed';
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/core/error/auth_slugs.dart';

/// Slugs the BACKEND emits — each must appear verbatim in the API source.
/// Client-only slugs (`no_refresh_token`, `unauthorized`) are excluded on
/// purpose; listing one here would pass vacuously and hide the real check.
const _backendEmitted = <String>[
  AuthSlugs.invalidAccessToken,
  AuthSlugs.missingBearerToken,
  AuthSlugs.userNotFound,
  AuthSlugs.userSuspended,
  AuthSlugs.invalidRefresh,
  AuthSlugs.expiredRefresh,
  AuthSlugs.tokenReused,
];

void main() {
  // A slug typo is SILENT: a mismatched comparison falls through to the
  // generic branch, so nothing errors and the intended behaviour quietly never
  // happens. `invalidRefreshToken = 'invalid_refresh_token'` shipped that way
  // (the backend emits `invalid_refresh`) and survived only because it was
  // never referenced. Reads the sibling api/ package so it can't drift again.
  // CWD is the package root under `flutter test` — same relative-path
  // convention as recruiter_openapi_contract_test.dart.
  test('every backend-emitted AuthSlug exists verbatim in the API source', () {
    final authDir = Directory('../api/src/jobify_api/auth');
    expect(
      authDir.existsSync(),
      isTrue,
      reason: 'expected the sibling api/ package at ../api',
    );

    final source = authDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.py'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    expect(source, isNotEmpty);

    for (final slug in _backendEmitted) {
      expect(
        source.contains('"$slug"'),
        isTrue,
        reason:
            '"$slug" is emitted nowhere in api/src/jobify_api/auth — '
            'the backend renamed it, or the constant is a typo',
      );
    }
  });

  test('the removed invalid_refresh_token typo has not come back', () {
    expect(_backendEmitted, isNot(contains('invalid_refresh_token')));
    expect(AuthSlugs.invalidRefresh, 'invalid_refresh');
  });
}

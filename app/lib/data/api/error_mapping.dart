import 'package:dio/dio.dart';
import 'package:jobify_app/core/error/auth_slugs.dart';
import 'package:jobify_app/core/error/exceptions.dart';

/// Map a [DioException] into a typed [JobifyException].
///
/// Call from dio's `onError` interceptor (or inside each repo's catch
/// block). 401 + slug `invalid_access_token` → [AuthException] so the
/// refresh-on-401 interceptor can be selective; other 4xx/5xx →
/// [ApiException]; transport errors → [NetworkException].
JobifyException mapDioException(DioException e) {
  final response = e.response;
  final requestId = response?.headers.value('x-request-id');

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return NetworkException(message: e.message, cause: e);

    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      // Unknown / cancel — bucket into NetworkException so the UI shows a
      // recoverable error rather than a 500-style message.
      if (response == null) {
        return NetworkException(message: e.message, cause: e);
      }
      // fall through to badResponse handling
      return _mapResponse(response, requestId, e);

    case DioExceptionType.badResponse:
      if (response == null) {
        return ApiException(statusCode: 0, cause: e);
      }
      return _mapResponse(response, requestId, e);
  }
}

/// Render a problem `detail` as one display string, tolerating BOTH shapes the
/// backend can emit. Mirrors `frontend/src/shared/api/transport.ts`'s
/// `formatDetail` — keep the two in step.
///
/// * `HTTPException` (every hand-raised 4xx/5xx) → `detail` is already the
///   slug string, and the caller compares it against [AuthSlugs].
/// * **422 validation** → the backend registers handlers only for
///   `HTTPException` and `Exception`, so FastAPI's own `RequestValidationError`
///   handler wins and returns `{"detail": [{loc, msg, type}, ...]}`. Casting
///   that list to `String?` used to throw a `TypeError` from inside the error
///   mapper, so a 422 surfaced as an unhandled crash instead of an
///   [ApiException] — reachable on web via a malformed `#/feed/jobs/<id>`
///   path param, which has no client-side UUID check.
///
/// Anything else (a number, a nested object, null) returns null so the caller
/// falls back to a status-derived message rather than throwing.
String? formatProblemDetail(Object? detail) {
  if (detail is String) return detail;
  if (detail is List) {
    final parts = <String>[];
    for (final item in detail) {
      if (item is Map && item['msg'] != null) {
        final rawLoc = item['loc'];
        // Drop the "body" segment the way the React client does — it is
        // structural noise, not information the user can act on.
        final loc =
            rawLoc is List ? rawLoc.where((s) => s != 'body').join('.') : '';
        final msg = item['msg'].toString();
        parts.add(loc.isEmpty ? msg : '$loc: $msg');
      } else {
        parts.add(item.toString());
      }
    }
    return parts.isEmpty ? null : parts.join('; ');
  }
  return null;
}

JobifyException _mapResponse(
  Response<dynamic> response,
  String? requestId,
  DioException cause,
) {
  // Backend emits RFC 7807 problem+json (`{detail, type, title, status,
  // request_id}`) via middleware/error_handler.py for every HTTPException.
  // The "slug" value lives in `detail`; `AuthSlugs` constants name the string
  // values on the Dart side. There is no separate `slug` wire field.
  //
  // 422 is the documented exception — `detail` is a LIST there. Route it
  // through [formatProblemDetail] so a validation error can never throw a
  // cast error out of the mapper. Slug comparisons below only ever match the
  // string form, which is exactly right: a 422 has no slug.
  final body = response.data;
  final detail = body is Map ? formatProblemDetail(body['detail']) : null;
  final status = response.statusCode ?? 0;

  if (status == 401 && detail == AuthSlugs.invalidAccessToken) {
    return AuthException(
      slug: detail!,
      detail: detail,
      requestId: requestId,
      cause: cause,
    );
  }
  if (status == 401) {
    // Other 401 details (missing_bearer_token, user_not_found) are also
    // auth-y.
    return AuthException(
      slug: detail ?? AuthSlugs.unauthorized,
      detail: detail,
      requestId: requestId,
      cause: cause,
    );
  }
  return ApiException(
    statusCode: status,
    slug: detail,
    detail: detail,
    requestId: requestId,
    cause: cause,
  );
}

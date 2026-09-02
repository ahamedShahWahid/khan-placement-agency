import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/core/error/exceptions.dart';
import 'package:jobify_app/data/api/error_mapping.dart';

DioException _dioErrWithResponse({
  required int status,
  required Map<String, dynamic> body,
  String? requestId,
}) {
  final requestOptions = RequestOptions(path: '/v1/feed');
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: status,
      data: body,
      headers:
          requestId == null
              ? Headers()
              : Headers.fromMap({
                'x-request-id': [requestId],
              }),
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  // Real backend wire shape — RFC 7807 problem+json from
  // middleware/error_handler.py. There is NO `slug` field; the slug value
  // lives in `detail`. These tests pin that contract.
  //
  // BUT 422 is the exception: the backend registers exception handlers only
  // for HTTPException and Exception, so FastAPI's own RequestValidationError
  // handler wins and returns `{"detail": [{loc, msg, type}, ...]}` — an ARRAY,
  // plain application/json, not problem+json. Reachable in the wild: on
  // Flutter web `#/feed/jobs/<anything>` goes straight to
  // GET /v1/jobs/<anything> with no client-side UUID check, and a malformed
  // path param is a 422. The 422 group below pins that shape.
  group('mapDioException', () {
    test('401 with detail=invalid_access_token → AuthException', () {
      final e = _dioErrWithResponse(
        status: 401,
        body: {
          'type': 'about:blank',
          'title': 'Unauthorized',
          'status': 401,
          'detail': 'invalid_access_token',
          'request_id': 'test-req-id',
        },
        requestId: 'req-1',
      );
      final mapped = mapDioException(e);
      expect(mapped, isA<AuthException>());
      expect((mapped as AuthException).slug, equals('invalid_access_token'));
      expect(mapped.requestId, equals('req-1'));
    });

    test('403 with detail=not_an_applicant → ApiException', () {
      final e = _dioErrWithResponse(
        status: 403,
        body: {'status': 403, 'detail': 'not_an_applicant'},
      );
      final mapped = mapDioException(e);
      expect(mapped, isA<ApiException>());
      expect((mapped as ApiException).statusCode, equals(403));
      expect(mapped.slug, equals('not_an_applicant'));
    });

    test('500 with empty body → ApiException with status only', () {
      final e = _dioErrWithResponse(status: 500, body: {});
      final mapped = mapDioException(e);
      expect(mapped, isA<ApiException>());
      expect((mapped as ApiException).slug, isNull);
    });

    test('connection error → NetworkException', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/v1/feed'),
        type: DioExceptionType.connectionError,
        message: 'connection refused',
      );
      final mapped = mapDioException(e);
      expect(mapped, isA<NetworkException>());
    });

    test('connection timeout → NetworkException', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/v1/feed'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(mapDioException(e), isA<NetworkException>());
    });

    // --- 422: FastAPI's default validation shape (detail is a LIST) ---

    DioException validation422(List<Object> detail) {
      final requestOptions = RequestOptions(path: '/v1/jobs/not-a-uuid');
      return DioException(
        requestOptions: requestOptions,
        response: Response<Map<String, dynamic>>(
          requestOptions: requestOptions,
          statusCode: 422,
          data: {'detail': detail},
        ),
        type: DioExceptionType.badResponse,
      );
    }

    test('422 with a LIST detail maps to ApiException, never throws', () {
      final e = validation422([
        {
          'loc': ['path', 'job_id'],
          'msg': 'Input should be a valid UUID',
          'type': 'uuid_parsing',
        },
      ]);
      final mapped = mapDioException(e);
      expect(mapped, isA<ApiException>());
      final api = mapped as ApiException;
      expect(api.statusCode, 422);
      // Flattened to `loc: msg`, mirroring the React transport's formatDetail.
      expect(api.detail, 'path.job_id: Input should be a valid UUID');
    });

    test('422 with multiple validation errors joins them', () {
      final mapped =
          mapDioException(
                validation422([
                  {
                    'loc': ['body', 'language'],
                    'msg': "Input should be 'en' or 'hi'",
                    'type': 'literal_error',
                  },
                  {
                    'loc': ['query', 'min_years'],
                    'msg': 'Input should be less than or equal to 80',
                    'type': 'less_than_equal',
                  },
                ]),
              )
              as ApiException;
      // The structural 'body' segment is dropped (mirrors the React client);
      // 'query' is kept because it is not 'body'.
      expect(mapped.detail, contains('language: '));
      expect(mapped.detail, isNot(contains('body.language')));
      expect(mapped.detail, contains('query.min_years: '));
      expect(mapped.detail, contains('; '));
    });

    test('422 with an unparseable detail still yields ApiException', () {
      final mapped = mapDioException(validation422([42])) as ApiException;
      expect(mapped.statusCode, 422);
      expect(mapped.detail, isNotNull);
    });

    test('a non-string, non-list detail does not throw', () {
      final requestOptions = RequestOptions(path: '/v1/feed');
      final e = DioException(
        requestOptions: requestOptions,
        response: Response<Map<String, dynamic>>(
          requestOptions: requestOptions,
          statusCode: 500,
          data: const {'detail': 7},
        ),
        type: DioExceptionType.badResponse,
      );
      final mapped = mapDioException(e) as ApiException;
      expect(mapped.statusCode, 500);
    });

    test(
      '401 with a LIST detail is not mistaken for a refreshable session',
      () {
        final requestOptions = RequestOptions(path: '/v1/feed');
        final e = DioException(
          requestOptions: requestOptions,
          response: Response<Map<String, dynamic>>(
            requestOptions: requestOptions,
            statusCode: 401,
            data: const {
              'detail': [
                {
                  'loc': ['header'],
                  'msg': 'boom',
                  'type': 'x',
                },
              ],
            },
          ),
          type: DioExceptionType.badResponse,
        );
        final mapped = mapDioException(e) as AuthException;
        // Not `invalid_access_token`, so the refresh ladder must not engage.
        expect(mapped.slug, isNot('invalid_access_token'));
      },
    );
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpa_app/data/me/me_api.dart';
import 'package:kpa_app/data/me/me_repository_impl.dart';

class _MockInterceptor extends Interceptor {
  final Map<String, _ScriptedResponse> _routes = {};

  void on(
    String method,
    String path,
    int status,
    Map<String, dynamic>? body,
  ) {
    _routes['$method:$path'] = _ScriptedResponse(status, body);
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final key = '${options.method}:${options.path}';
    final r = _routes[key];
    if (r == null) {
      handler.reject(
        DioException(requestOptions: options, error: 'no mock for $key'),
      );
      return;
    }
    if (r.status >= 400) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: r.status,
            data: r.body,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
    } else {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: r.status,
          data: r.body,
        ),
      );
    }
  }
}

class _ScriptedResponse {
  _ScriptedResponse(this.status, this.body);
  final int status;
  final Map<String, dynamic>? body;
}

void main() {
  test('fetch: 200 → MeDto', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    final mock = _MockInterceptor();
    dio.interceptors.add(mock);
    mock.on('GET', '/v1/me', 200, {
      'user': {
        'id': 'u1',
        'email': 'u@e.com',
        'display_name': 'U',
        'role': 'applicant',
        'created_at': '2026-05-21T12:00:00Z',
      },
      'applicant': {'id': 'a1', 'user_id': 'u1'},
    });
    final repo = MeRepositoryImpl(MeApi(dio));
    final me = await repo.fetch();
    expect(me.user.email, 'u@e.com');
    expect(me.applicant?.id, 'a1');
  });
}

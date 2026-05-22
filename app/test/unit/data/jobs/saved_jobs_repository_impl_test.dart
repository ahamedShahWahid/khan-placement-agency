import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpa_app/data/jobs/saved_jobs_api.dart';
import 'package:kpa_app/data/jobs/saved_jobs_repository_impl.dart';

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
  test('fetchPage: 200 → SavedJobsPageDto', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    final mock = _MockInterceptor();
    dio.interceptors.add(mock);
    mock.on('GET', '/v1/saved', 200, {
      'items': [
        {
          'saved': {
            'id': 's1',
            'applicant_id': 'ap1',
            'job_id': 'j1',
            'created_at': '2026-05-21T12:00:00Z',
          },
          'job': {
            'id': 'j1',
            'title': 'Eng',
            'location': 'BLR',
            'status': 'open',
            'posted_at': '2026-05-18T00:00:00Z',
          },
          'employer': {'id': 'e1', 'name': 'Acme'},
          'match': null,
        }
      ],
      'next_cursor': null,
    });
    final repo = SavedJobsRepositoryImpl(SavedJobsApi(dio));
    final page = await repo.fetchPage();
    expect(page.items.single.saved.id, 's1');
  });
}

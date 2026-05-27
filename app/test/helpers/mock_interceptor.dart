import 'package:dio/dio.dart';

/// Shared mock interceptor for unit tests. Route by `(method, path)` to a
/// scripted response; 4xx/5xx responses are rejected as DioException so
/// the repo's `try/on DioException` path runs.
class MockInterceptor extends Interceptor {
  final Map<String, _ScriptedResponse> _routes = {};

  /// Every request seen, in order — lets tests assert the request body/keys
  /// (the response mock alone can't catch a wrong request-body contract).
  final List<RequestOptions> requests = [];

  /// The most recent request data for a given `(method, path)`, or null.
  Object? lastDataFor(String method, String path) {
    for (final r in requests.reversed) {
      if (r.method == method && r.path == path) return r.data;
    }
    return null;
  }

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
    requests.add(options);
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

import 'package:dio/dio.dart';

import '../events/events.dart';
import '../log/log.dart';
import 'errors.dart';

/// Runs before each request and after each response or error of an [Http] connection. Override only
/// what you need; there are no handlers to call.
abstract class HttpInterceptor {
  const HttpInterceptor();

  /// Change the request before it is sent (headers, query).
  Future<void> onRequest(RequestOptions request) async {}

  Future<void> onResponse(Response<Object?> response) async {}

  Future<void> onError(HttpError error) async {}
}

/// Logs each request and response with [Log] (nothing in release builds; tokens are masked).
class HttpLogInterceptor extends HttpInterceptor {
  const HttpLogInterceptor();

  @override
  Future<void> onRequest(RequestOptions request) async =>
      Log.d('→ ${request.method} ${request.uri}', data: {'headers': request.headers}, at: 'dragonfly › http');

  @override
  Future<void> onResponse(Response<Object?> response) async =>
      Log.d('← ${response.statusCode} ${response.requestOptions.uri}', at: 'dragonfly › http');

  @override
  Future<void> onError(HttpError error) async =>
      Log.w('✕ ${error.statusCode ?? '-'} ${error.message}', at: 'dragonfly › http');
}

/// Lets the backend publish global events: a response (or an error response) with the header [header]
/// publishes the event its value names in [events] (`x-app-event: force_logout` →
/// `events['force_logout']()`). Unknown names are ignored.
class EventInterceptor extends HttpInterceptor {
  const EventInterceptor({this.header = 'x-app-event', required this.events});

  final String header;
  final Map<String, AppEvent Function()> events;

  void _publish(String? name) {
    final event = name == null ? null : events[name];
    if (event != null) Events.publish(event());
  }

  @override
  Future<void> onResponse(Response<Object?> response) async => _publish(response.headers.value(header));

  @override
  Future<void> onError(HttpError error) async => _publish(error.headers[header.toLowerCase()]?.first);
}

/// Adapts an [HttpInterceptor] to dio.
class DioInterceptorAdapter extends Interceptor {
  DioInterceptorAdapter(this.inner);

  final HttpInterceptor inner;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    await inner.onRequest(options);
    handler.next(options);
  }

  @override
  Future<void> onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) async {
    await inner.onResponse(response);
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    await inner.onError(HttpError.from(err));
    handler.next(err);
  }
}

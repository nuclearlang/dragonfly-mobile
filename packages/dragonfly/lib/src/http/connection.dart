import 'dart:async';
import 'dart:io' as io;

import 'package:dio/dio.dart';

import 'interceptor.dart';

/// A named connection of the project config: [Http] or [WebSocket].
abstract class Connection {
  /// `connectionName`; `''` is the default connection.
  String get name;
}

/// An HTTP connection: a dio client with the options of the project config.
class Http implements Connection {
  Http({
    String connectionName = '',
    required this.baseUrl,
    this.connectTimeout,
    this.receiveTimeout,
    this.sendTimeout,
    this.headers = const {},
    this.queryParameters = const {},
    this.contentType,
    this.responseType = ResponseType.json,
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.persistentConnection = true,
    this.validateStatus,
    this.interceptors = const [],
  }) : name = connectionName;

  @override
  final String name;
  final String baseUrl;
  final Duration? connectTimeout;
  final Duration? receiveTimeout;
  final Duration? sendTimeout;
  final Map<String, String> headers;
  final Map<String, Object?> queryParameters;

  /// Content type of the requests with a body. By default dio's: JSON for maps and lists. Never a default for
  /// every request: a GET with `Content-Type` makes the browser send a CORS preflight first (and dio warns).
  final String? contentType;
  final ResponseType responseType;
  final bool followRedirects;
  final int maxRedirects;
  final bool persistentConnection;
  final bool Function(int? status)? validateStatus;
  final List<HttpInterceptor> interceptors;

  /// The dio client, created the first time it is used. Tests can replace it.
  late Dio dio = _build();

  Dio _build() {
    final d = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: headers,
        queryParameters: queryParameters,
        contentType: contentType,
        responseType: responseType,
        followRedirects: followRedirects,
        maxRedirects: maxRedirects,
        persistentConnection: persistentConnection,
        validateStatus: validateStatus,
      ),
    );
    d.interceptors.addAll(interceptors.map(DioInterceptorAdapter.new));
    return d;
  }
}

/// A WebSocket connection of the project config. Use `wss://` outside development: `ws://` is not
/// encrypted.
class WebSocket implements Connection {
  WebSocket({
    String connectionName = '',
    required this.uri,
    this.headers = const {},
    this.protocols,
    this.pingInterval,
    this.interceptors = const [],
  }) : name = connectionName;

  @override
  final String name;
  final String uri;
  final Map<String, String> headers;
  final List<String>? protocols;
  final Duration? pingInterval;

  /// Called with each message before it is delivered (decode, log, filter).
  final List<Object? Function(Object? message)> interceptors;

  io.WebSocket? _socket;

  /// Opens the socket (once) and returns its messages, after the interceptors.
  Future<Stream<Object?>> connect() async {
    final s = _socket ??= await io.WebSocket.connect(uri, headers: headers, protocols: protocols);
    s.pingInterval = pingInterval;
    return s.map((m) => interceptors.fold<Object?>(m, (value, f) => f(value)));
  }

  void send(Object? message) {
    final s = _socket;
    if (s == null) throw StateError('WebSocket "$name" is not connected; call connect() first');
    s.add(message);
  }

  Future<void> close() async {
    await _socket?.close();
    _socket = null;
  }
}

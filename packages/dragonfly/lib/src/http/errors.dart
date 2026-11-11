import 'package:dio/dio.dart';

/// A failure a repository turns into the `Err` of a method that returns `Result<E, T>`
/// (`E(message: error.message)`); in any other method it is thrown. [HttpError] and the local
/// database's `NotFound` are the two.
abstract interface class RepositoryError implements Exception {
  String get message;
}

/// A failed request.
class HttpError implements RepositoryError {
  const HttpError(
    this.message, {
    this.statusCode,
    this.data,
    this.headers = const {},
    this.timeout = false,
    this.offline = false,
  });

  factory HttpError.from(DioException e) {
    final status = e.response?.statusCode;
    final timeout =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    final offline = e.type == DioExceptionType.connectionError;
    final message = switch (e.type) {
      _ when timeout => 'The server took too long to answer',
      _ when offline => 'No connection to the server',
      DioExceptionType.badResponse => 'The server answered $status',
      DioExceptionType.cancel => 'The request was cancelled',
      _ => e.message ?? 'The request failed',
    };
    return HttpError(
      message,
      statusCode: status,
      data: e.response?.data,
      headers: e.response?.headers.map ?? const {},
      timeout: timeout,
      offline: offline,
    );
  }

  @override
  final String message;
  final int? statusCode;
  final Object? data;

  /// Headers of the error response (lowercase names).
  final Map<String, List<String>> headers;
  final bool timeout;
  final bool offline;

  /// A temporary failure that another attempt may fix (timeouts, no connection, 5xx).
  bool get transient => timeout || offline || (statusCode != null && statusCode! >= 500);

  @override
  String toString() => 'HttpError($message${statusCode == null ? '' : ', $statusCode'})';
}

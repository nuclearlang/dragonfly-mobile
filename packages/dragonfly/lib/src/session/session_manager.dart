import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../core.dart';
import '../events/events.dart';
import '../http/errors.dart';
import '../http/interceptor.dart';

/// The current session: the data given to [SessionManager.start], the token for the backend, the roles
/// and permissions for the ACL, and the values saved with [SessionManager.set].
@immutable
class Session {
  const Session({
    this.data,
    this.token = '',
    this.roles = const [],
    this.permissions = const [],
    this.expiresAt,
    this.values = const {},
  });

  final Object? data;
  final String token;
  final List<String> roles;
  final List<String> permissions;
  final DateTime? expiresAt;
  final Map<String, Object?> values;

  bool get expired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Session copyWith({Map<String, Object?>? values}) => Session(
    data: data,
    token: token,
    roles: roles,
    permissions: permissions,
    expiresAt: expiresAt,
    values: values ?? this.values,
  );
}

/// Creates, keeps and ends the session. It is saved in secure storage (Keychain on iOS and macOS,
/// Keystore-encrypted on Android, libsecret on Linux), ends after [timeout] without activity, and on
/// [destroy] clears the response cache and publishes [SessionEnded] ([start] publishes
/// [SessionStarted]).
class SessionManager extends Global {
  SessionManager({this.timeout, FlutterSecureStorage? storage, this.key = 'dragonfly.session'})
    : _storage = storage ?? const FlutterSecureStorage();

  /// How to read back the data of a session saved by a previous run: type name → `fromJson`. The
  /// generated code registers every model (`SessionManager.decoder<Auth>(Auth.fromJson)`).
  static final Map<String, Object Function(Map<String, dynamic> json)> _decoders = {};

  static void decoder<T extends Object>(T Function(Map<String, dynamic> json) fromJson) =>
      _decoders[T.toString()] = fromJson;

  /// Inactivity that ends the session (null: only `expiresAt`).
  final Duration? timeout;
  final String key;
  final FlutterSecureStorage _storage;
  final ValueNotifier<Session?> current = ValueNotifier(null);
  Timer? _timer;

  Session? get session => current.value;

  bool get active => current.value != null && !current.value!.expired;

  /// The data given to [start].
  T get<T>() {
    final data = current.value?.data;
    if (data is T) return data;
    throw StateError('the session has no ${T.toString()} (active: $active)');
  }

  /// Starts the session with [data] (a model, a string...). [token] goes in the `Authorization` header
  /// of each request (with `SessionInterceptor`); [roles] and [permissions] are what the ACL checks.
  Future<void> start<T extends Object>(
    T data, {
    String token = '',
    List<String> roles = const [],
    List<String> permissions = const [],
    DateTime? expiresAt,
  }) async {
    final s = Session(data: data, token: token, roles: roles, permissions: permissions, expiresAt: expiresAt);
    await _save(s);
    current.value = s;
    touch();
    Events.publish(SessionStarted<T>(data));
  }

  /// Ends the session: deletes it from the device, clears the response cache and publishes
  /// [SessionEnded].
  Future<void> destroy({bool expired = false}) async {
    _timer?.cancel();
    if (current.value == null) return;
    current.value = null;
    await _storage.delete(key: key);
    Dragonfly.cache.clear();
    Events.publish(SessionEnded(expired: expired));
  }

  /// Saves a value in the session (JSON: text, numbers, lists, maps); it ends with the session.
  Future<void> set(String name, Object? value) async {
    final s = current.value;
    if (s == null) throw StateError('no active session: call start first');
    final next = s.copyWith(values: {...s.values, name: value});
    await _save(next);
    current.value = next;
  }

  T? value<T>(String name) => current.value?.values[name] as T?;

  Future<void> remove(String name) async {
    final s = current.value;
    if (s == null || !s.values.containsKey(name)) return;
    final next = s.copyWith(values: {...s.values}..remove(name));
    await _save(next);
    current.value = next;
  }

  Future<void> _save(Session s) {
    final data = s.data;
    return _storage.write(
      key: key,
      value: jsonEncode({
        'type': data?.runtimeType.toString(),
        // a model is saved with its toJson (json_serializable), anything else as it is
        'data': data is String || data is num || data is bool || data == null ? data : (data as dynamic).toJson(),
        'token': s.token,
        'roles': s.roles,
        'permissions': s.permissions,
        'expiresAt': s.expiresAt?.toIso8601String(),
        'values': s.values,
      }),
    );
  }

  @override
  void register(GetIt di) => di.registerSingleton<SessionManager>(this);

  /// Restores the session of the previous run, unless it expired.
  @override
  Future<void> init() async {
    final saved = await _storage.read(key: key);
    if (saved == null) return;
    final j = jsonDecode(saved) as Map<String, dynamic>;
    final expiresAt = j['expiresAt'] == null ? null : DateTime.parse(j['expiresAt'] as String);
    final raw = j['data'];
    final decode = _decoders[j['type']];
    if ((expiresAt != null && DateTime.now().isAfter(expiresAt)) || (raw is Map && decode == null)) {
      await _storage.delete(key: key);
      return;
    }
    current.value = Session(
      data: raw is Map ? decode!(raw.cast<String, dynamic>()) : raw,
      token: j['token'] as String? ?? '',
      roles: (j['roles'] as List? ?? const []).cast<String>(),
      permissions: (j['permissions'] as List? ?? const []).cast<String>(),
      expiresAt: expiresAt,
      values: (j['values'] as Map?)?.cast<String, Object?>() ?? const {},
    );
    touch();
  }

  @override
  Future<void> dispose() async => _timer?.cancel();

  /// Activity: restarts the inactivity timer.
  void touch() {
    final t = timeout;
    if (t == null || current.value == null) return;
    _timer?.cancel();
    _timer = Timer(t, () => destroy(expired: true));
  }
}

/// Adds `Authorization: Bearer <token>` to each request and ends the session on a 401.
class SessionInterceptor extends HttpInterceptor {
  const SessionInterceptor({this.header = 'Authorization', this.scheme = 'Bearer'});

  final String header;
  final String scheme;

  @override
  Future<void> onRequest(RequestOptions request) async {
    final sessions = inject<SessionManager>();
    final s = sessions.session;
    if (s == null) return;
    if (s.expired) return sessions.destroy(expired: true); // an expired token never leaves the device
    if (s.token.isNotEmpty) request.headers[header] = '$scheme ${s.token}';
    sessions.touch();
  }

  @override
  Future<void> onError(HttpError error) async {
    if (error.statusCode == 401) await inject<SessionManager>().destroy(expired: true);
  }
}

/// Shows [sessionStarted] with the session data ([T], what [SessionManager.start] received) while a
/// session is active, and [sessionEnded] otherwise. [onSessionEnded] runs once each time the session
/// ends (navigate, show a popup). Like every event widget, it changes only while its screen is visible.
class GlobalEvents<T> extends StatefulWidget {
  const GlobalEvents({super.key, required this.sessionStarted, this.sessionEnded, this.onSessionEnded});

  final Widget Function(T data) sessionStarted;

  /// The event is null when no session ended yet (the app started without one).
  final Widget Function(SessionEnded? event)? sessionEnded;
  final void Function(SessionEnded event)? onSessionEnded;

  @override
  State<GlobalEvents<T>> createState() => _GlobalEventsState<T>();
}

class _GlobalEventsState<T> extends State<GlobalEvents<T>> with EventsOnDemand {
  SessionEnded? _ended;

  @override
  void initState() {
    super.initState();
    onEvent<SessionStarted>((_) => setState(() {}));
    onEvent<SessionEnded>((e) {
      setState(() => _ended = e);
      widget.onSessionEnded?.call(e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = inject<SessionManager>();
    return sessions.active
        ? widget.sessionStarted(sessions.get<T>())
        : widget.sessionEnded?.call(_ended) ?? const SizedBox.shrink();
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../core.dart';
import '../events/events.dart';
import '../network/network_manager.dart';
import '../session/session_manager.dart';

/// A custom access check (like NestJS's `CanActivate`): the `guard` kind writes one. It is registered in
/// the injector, so it receives its dependencies (the session, a repository...).
abstract class Guard {
  const Guard();

  /// `true` lets the session in. It can wait (`Future<bool>`: ask the server); then the router and
  /// [AclBuilder] wait for it, and the sync [Acl.can] / [Guards.check] cannot use it.
  FutureOr<bool> canActivate();
}

/// What a screen or a use case asks of the session: one of [roles] (when given), all of [permissions],
/// and every guard (types of [Guard] registered in the injector).
@immutable
class AclRule {
  const AclRule({this.roles = const [], this.permissions = const [], this.guards = const []});

  final List<String> roles;
  final List<String> permissions;
  final List<Type> guards;

  bool get open => roles.isEmpty && permissions.isEmpty && guards.isEmpty;
}

/// Access control list. Like Phalcon's ACL, a role can inherit others ([inherits]: `admin` inherits
/// `editor`) and receive permissions ([permissions]: `editor` → `invoices.edit`); the session's roles and
/// permissions come from `SessionManager.start`. Everything not allowed is denied. It is a global
/// service of the project config (`Acl(inherits = {...}, permissions = {...})`); without it, roles do
/// not inherit and only the session's own permissions count.
class Acl extends Global {
  Acl({this.inherits = const {}, this.permissions = const {}});

  final Map<String, List<String>> inherits;
  final Map<String, List<String>> permissions;

  /// The rule of each screen (the generated router registers them).
  static final Map<Type, AclRule> screens = {};

  static Session? _for;
  static Set<String> _roles = {};
  static Set<String> _permissions = {};
  static final Map<Type, bool> _access = {};
  static Acl? _forAcl;

  @override
  void register(GetIt di) => di.registerSingleton<Acl>(this);

  static Session? get _session {
    final di = GetIt.instance;
    final s = di.isRegistered<SessionManager>() ? inject<SessionManager>().session : null;
    return s == null || s.expired ? null : s;
  }

  /// Roles (with the inherited ones) and permissions of the session, computed once per session.
  static void _refresh(Session? s) {
    final acl = GetIt.instance.isRegistered<Acl>() ? inject<Acl>() : null;
    if (identical(s, _for) && identical(acl, _forAcl)) return;
    _for = s;
    _forAcl = acl;
    _access.clear();
    final roles = <String>{};
    void add(String r) {
      if (roles.add(r)) acl?.inherits[r]?.forEach(add);
    }

    s?.roles.forEach(add);
    _roles = roles;
    _permissions = {...?s?.permissions, for (final r in roles) ...?acl?.permissions[r]};
  }

  /// The session has one of [roles] (or a role that inherits it), all [permissions], and every guard
  /// allows it. Without a session only an open rule passes.
  static bool can({List<String> roles = const [], List<String> permissions = const [], List<Type> guards = const []}) =>
      allows(AclRule(roles: roles, permissions: permissions, guards: guards));

  static bool allows(AclRule rule) {
    final r = _allows(rule);
    if (r is bool) return r;
    throw StateError('an async guard (${rule.guards}) cannot be checked synchronously: use Acl.check or AclBuilder');
  }

  /// The same as [can], waiting for the guards whose `canActivate` is async.
  static Future<bool> check({List<String> roles = const [], List<String> permissions = const [], List<Type> guards = const []}) async =>
      _allows(AclRule(roles: roles, permissions: permissions, guards: guards));

  /// Roles and permissions first (sync); a guard runs only when they pass, and the rule stays sync while
  /// every guard answers a `bool`.
  static FutureOr<bool> _allows(AclRule rule) {
    final s = _session;
    _refresh(s);
    if (s == null && (rule.roles.isNotEmpty || rule.permissions.isNotEmpty)) return false;
    if (rule.roles.isNotEmpty && !rule.roles.any(_roles.contains)) return false;
    if (!rule.permissions.every(_permissions.contains)) return false;
    return _guards(rule.guards, 0);
  }

  static FutureOr<bool> _guards(List<Type> guards, int from) {
    for (var i = from; i < guards.length; i++) {
      final r = GetIt.instance.get<Guard>(type: guards[i]).canActivate();
      if (r is Future<bool>) return r.then((ok) => ok ? _guards(guards, i + 1) : false);
      if (!r) return false;
    }
    return true;
  }

  /// [canOpen] for the router and [AclBuilder]: async when a guard of the rule is.
  static FutureOr<bool> canOpenAsync(Type screen) {
    final rule = screens[screen];
    if (rule == null) return true;
    _refresh(_session);
    if (rule.guards.isNotEmpty) return _allows(rule);
    return _access.putIfAbsent(screen, () => allows(rule));
  }

  /// Whether the session can open [screen] (a type with a rule in [screens]); the answers for roles and
  /// permissions are kept until the session changes. Use it to hide buttons to screens it cannot open.
  static bool canOpen(Type screen) {
    final rule = screens[screen];
    if (rule == null) return true;
    _refresh(_session);
    if (rule.guards.isNotEmpty) return allows(rule);
    return _access.putIfAbsent(screen, () => allows(rule));
  }
}

/// Shows [child] when the session passes the rule ([roles], [permissions], [guards]; or the rule of
/// [screen]), otherwise [fallback]. It changes with the session while its screen is visible.
class AclBuilder extends StatefulWidget {
  const AclBuilder({
    super.key,
    this.roles = const [],
    this.permissions = const [],
    this.guards = const [],
    this.screen,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final List<String> roles;
  final List<String> permissions;
  final List<Type> guards;
  final Type? screen;
  final Widget child;
  final Widget fallback;

  @override
  State<AclBuilder> createState() => _AclBuilderState();
}

class _AclBuilderState extends State<AclBuilder> with EventsOnDemand {
  FutureOr<bool> _ok = false;

  @override
  void initState() {
    super.initState();
    _ok = _check();
    onEvent<SessionStarted>((_) => setState(() => _ok = _check()));
    onEvent<SessionEnded>((_) => setState(() => _ok = _check()));
  }

  @override
  void didUpdateWidget(AclBuilder old) {
    super.didUpdateWidget(old);
    _ok = _check();
  }

  FutureOr<bool> _check() {
    final w = widget;
    return w.screen != null
        ? Acl.canOpenAsync(w.screen!)
        : Acl._allows(AclRule(roles: w.roles, permissions: w.permissions, guards: w.guards));
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ok;
    if (ok is bool) return ok ? widget.child : widget.fallback;
    // an async guard: the fallback until it answers
    return FutureBuilder<bool>(
      future: ok,
      builder: (context, s) => s.data == true ? widget.child : widget.fallback,
    );
  }
}

/// Checks of the decorators of a use case (`@requires(internet = true, session = true)`,
/// `@acl(roles = [...], permissions = [...], guards = [...])`). Returns the message of the first check
/// that fails, or null.
abstract final class Guards {
  static String? check({
    bool internet = false,
    bool session = false,
    List<String> roles = const [],
    List<String> permissions = const [],
    List<Type> guards = const [],
  }) {
    final denied = _requires(internet, session || roles.isNotEmpty || permissions.isNotEmpty);
    if (denied != null) return denied;
    if (!Acl.can(roles: roles, permissions: permissions, guards: guards)) return 'Access denied';
    return null;
  }

  /// [check] for an async use case: it waits for the guards whose `canActivate` is async.
  static Future<String?> verify({
    bool internet = false,
    bool session = false,
    List<String> roles = const [],
    List<String> permissions = const [],
    List<Type> guards = const [],
  }) async {
    final denied = _requires(internet, session || roles.isNotEmpty || permissions.isNotEmpty);
    if (denied != null) return denied;
    if (!await Acl.check(roles: roles, permissions: permissions, guards: guards)) return 'Access denied';
    return null;
  }

  static String? _requires(bool internet, bool session) {
    final di = GetIt.instance;
    if (internet && di.isRegistered<NetworkManager>() && !inject<NetworkManager>().online) {
      return 'No internet connection';
    }
    if (session && !(di.isRegistered<SessionManager>() && inject<SessionManager>().active)) {
      return 'The session is not active';
    }
    return null;
  }
}

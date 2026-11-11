import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../acl/acl.dart';
import '../core.dart';
import '../session/session_manager.dart';

/// A screen of the app (`@screen` of the dialect): where it is, how it is built from a URL, and who can
/// open it.
class AppRoute<W extends Widget> {
  const AppRoute({
    this.path,
    required this.build,
    this.args,
    this.loggedIn,
    this.acl = const AclRule(),
    this.denied,
    this.shell,
    this.shellBuilder,
    this.tab = 0,
    this.notFound = false,
    this.transition,
  });

  /// `/characters/:id`; null for a screen that is only the [notFound] page.
  final String? path;

  /// Builds the screen from a URL: `(state) => CharacterScreen(id: state.arg('id'))`. A screen opened with
  /// `context.goTo(CharacterScreen(id: 1))` is that same object.
  final W Function(GoRouterState state) build;

  /// The screen's parameters, for its URL: the ones named in [path] go there, the others to the query.
  final Map<String, Object?> Function(W screen)? args;

  /// Without an active session, the router goes to this screen.
  final Type? loggedIn;

  /// What the session needs to open this screen; when it does not pass, the router goes to [denied]
  /// (or to [loggedIn] when there is no session).
  final AclRule acl;
  final Type? denied;

  /// A screen with a shell (tabs, a bottom bar) is the branch [tab] of [shell]; [shellBuilder] builds
  /// the shell around the navigator of its branches.
  final Type? shell;
  final Widget Function(StatefulNavigationShell navigator)? shellBuilder;
  final int tab;

  /// The page of a location that no route has.
  final bool notFound;

  /// How the screen comes in; null is the platform's (Material / Cupertino).
  final ScreenTransition? transition;

  Type get screen => W;

  String get _name => W.toString();

  Widget _page(GoRouterState state) {
    final extra = state.extra;
    return extra is W ? extra : build(state);
  }

  /// The URL that opens [screen].
  String location(Widget screen) {
    final values = args?.call(screen as W) ?? const {};
    final query = <String, String>{};
    var p = path!;
    values.forEach((k, v) {
      if (p.contains(':$k')) {
        p = p.replaceAll(':$k', Uri.encodeComponent('$v'));
      } else if (v is String || v is num || v is bool) {
        query[k] = '$v';
      }
    });
    return Uri(path: p, queryParameters: query.isEmpty ? null : query).toString();
  }
}

/// How a screen comes in (`@screen(transition = ScreenTransition.fade)`).
enum ScreenTransition {
  fade,

  /// From the right, like a pushed page.
  slide,

  /// From the bottom, like a sheet.
  up,
  scale,
  none;

  Page<void> _page(LocalKey key, Widget child) {
    if (this == none) return NoTransitionPage<void>(key: key, child: child);
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        Animation<Offset> from(Offset o) => Tween(begin: o, end: Offset.zero).animate(curved);
        return switch (this) {
          fade => FadeTransition(opacity: curved, child: child),
          slide => SlideTransition(position: from(const Offset(1, 0)), child: child),
          up => SlideTransition(position: from(const Offset(0, 1)), child: child),
          scale => ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          ),
          none => child,
        };
      },
    );
  }
}

/// Values of a URL for [AppRoute.build].
extension RouteArgs on GoRouterState {
  /// The path or query parameter [name] as [T] (text, int, double or bool; inferred from where it goes).
  T arg<T>(String name) {
    final raw = pathParameters[name] ?? uri.queryParameters[name];
    if (raw == null) {
      if (null is T) return null as T;
      throw ArgumentError('the URL $uri has no parameter "$name"');
    }
    if ('' is T) return raw as T;
    if (true is T) return (raw == 'true') as T;
    if (0.5 is T) return double.parse(raw) as T;
    if (0 is T) return int.parse(raw) as T;
    throw ArgumentError('the parameter "$name" cannot come from a URL: open the screen with context.goTo');
  }
}

final Map<Type, AppRoute> _routes = {};

/// Navigation by screen, not by URL. Only views navigate: they are the ones with a context.
extension DragonflyNavigation on BuildContext {
  /// Shows [screen] instead of the current stack (its URL comes from its route).
  void goTo(Widget screen) => GoRouter.of(this).go(_location(screen), extra: screen);

  /// Shows [screen] on top of the current one; the result is what the screen returns with [goBack].
  Future<T?> pushTo<T extends Object?>(Widget screen) => GoRouter.of(this).push<T>(_location(screen), extra: screen);

  /// Closes the current screen, returning [result] to [pushTo].
  void goBack<T extends Object?>([T? result]) => GoRouter.of(this).pop(result);
}

String _location(Widget screen) {
  final r = _routes[screen.runtimeType];
  if (r == null || r.path == null) {
    throw ArgumentError('${screen.runtimeType} has no route: give it @screen(route = "...")');
  }
  return r.location(screen);
}

/// Builds the go_router of the app from its screens. A screen with `loggedIn` sends to that screen
/// without an active session; one with an ACL rule sends to `denied` when the session does not pass it.
/// It refreshes when the session changes. [observers] see every navigation (analytics).
GoRouter dragonflyRouter(List<AppRoute> routes, {String initial = '/', List<NavigatorObserver> observers = const []}) {
  _routes.clear();
  Acl.screens.clear();
  for (final r in routes) {
    _routes[r.screen] = r;
    if (!r.acl.open) Acl.screens[r.screen] = r.acl;
  }
  String forward(Type t) {
    final r = _routes[t];
    if (r?.path == null || r!.path!.contains(':')) {
      throw ArgumentError('$t is a forward screen: it needs @screen(route = "...") without parameters');
    }
    return r.path!;
  }

  for (final r in routes) {
    if (r.loggedIn != null) forward(r.loggedIn!);
    if (!r.acl.open && r.denied == null) {
      throw ArgumentError('${r.screen} has an ACL rule without a screen to go when it is denied (forward)');
    }
    if (r.denied != null) forward(r.denied!);
  }
  final di = GetIt.instance;
  final sessions = di.isRegistered<SessionManager>() ? inject<SessionManager>() : null;
  // A route is nested in the route with the longest path that starts its own (`/characters/:id` in
  // `/characters`, never in `/`): going to it stacks its parent below, so back returns there. Inside a
  // shell tab it stays in that tab.
  final paths = routes.where((r) => r.path != null).toList();
  AppRoute? parentOf(AppRoute r) {
    if (r.shell != null) return null;
    AppRoute? best;
    for (final p in paths) {
      final pp = p.path!;
      if (pp != '/' && r.path!.startsWith('$pp/') && (best == null || pp.length > best.path!.length)) best = p;
    }
    return best;
  }

  final children = <AppRoute, List<AppRoute>>{};
  final roots = <AppRoute>[];
  for (final r in paths) {
    final parent = parentOf(r);
    parent == null ? roots.add(r) : children.putIfAbsent(parent, () => []).add(r);
  }
  GoRoute page(AppRoute r, String path) => GoRoute(
    path: path,
    name: r._name,
    builder: r.transition == null ? (c, s) => r._page(s) : null,
    pageBuilder: r.transition == null ? null : (c, s) => r.transition!._page(s.pageKey, r._page(s)),
    routes: [for (final c in children[r] ?? const <AppRoute>[]) page(c, c.path!.substring(r.path!.length + 1))],
  );

  final shells = <Type, List<AppRoute>>{};
  final top = <RouteBase>[];
  for (final r in roots) {
    if (r.shell == null) {
      top.add(page(r, r.path!));
    } else {
      shells.putIfAbsent(r.shell!, () => []).add(r);
    }
  }
  for (final tabs in shells.values) {
    tabs.sort((a, b) => a.tab.compareTo(b.tab));
    top.add(
      StatefulShellRoute.indexedStack(
        builder: (c, s, navigator) => tabs.first.shellBuilder!(navigator),
        branches: [
          for (final r in tabs) StatefulShellBranch(routes: [page(r, r.path!)]),
        ],
      ),
    );
  }
  final notFound = routes.where((r) => r.notFound).firstOrNull;
  return GoRouter(
    initialLocation: initial,
    observers: observers,
    refreshListenable: sessions?.current,
    routes: top,
    errorBuilder: notFound == null ? null : (c, s) => notFound._page(s),
    redirect: (context, state) {
      final route = routes.where((r) => r._name == state.topRoute?.name).firstOrNull;
      if (route == null) return null;
      String? go(String to) => to == state.matchedLocation ? null : to;
      if (route.loggedIn != null && !(sessions?.active ?? false)) return go(forward(route.loggedIn!));
      if (route.acl.open) return null;
      String? decide(bool ok) => ok ? null : go(forward(route.denied!));
      // stays sync unless a guard of the rule is async
      final ok = Acl.canOpenAsync(route.screen);
      return ok is bool ? decide(ok) : ok.then(decide);
    },
  );
}

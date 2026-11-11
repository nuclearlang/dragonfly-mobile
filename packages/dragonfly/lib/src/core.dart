import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import 'device/probe.dart';
import 'http/cache.dart';
import 'http/connection.dart';
import 'local/local.dart';
import 'log/log.dart';

/// A service that lives for the whole app (SessionManager, NetworkManager, Events...). It is listed in
/// `globals` of the project config, registered in the injector and started by [Dragonfly.start].
abstract class Global {
  const Global();

  /// Registers this object in the injector under its own type (`di.registerSingleton<Self>(this)`).
  void register(GetIt di);

  Future<void> init() async {}

  Future<void> dispose() async {}
}

/// The project configuration (`appConfig` kind): connections and global services.
abstract class AppConfig {
  const AppConfig();

  List<Connection> get connections => const [];

  List<Global> get globals => const [];

  /// How the local database is kept (encryption); in a component's config, for the tables of its models.
  LocalDatabase? get local => null;
}

/// The configuration of one component (`config` kind): its own connections and services.
abstract class ComponentConfig extends AppConfig {
  const ComponentConfig();

  /// The color of the component's logs; without it, one is chosen by the component's name.
  LogColor? get logColor => null;
}

/// The object registered in the injector for type [T].
T inject<T extends Object>() => GetIt.instance<T>();

/// Entry point of the runtime: the injector, the connections and the response cache.
abstract final class Dragonfly {
  static GetIt get di => GetIt.instance;

  static final MemoryCache cache = MemoryCache();

  static final Map<String, Connection> _connections = {};

  static final List<Global> _globals = [];

  /// [start] ran in this isolate (false in background isolates).
  static bool started = false;

  /// Registers the project config, its connections and its global services, and starts them.
  static Future<void> start(AppConfig config) async {
    WidgetsFlutterBinding.ensureInitialized();
    installDeviceProbe();
    started = true;
    di.registerSingleton<AppConfig>(config);
    Local.configure(config.local);
    await _add(config);
  }

  /// Adds the connections and services of a component's config, and the color of its logs.
  static Future<void> addConfig(ComponentConfig config, {String? component}) {
    final color = config.logColor;
    if (component != null && color != null) Log.componentColors[component] = color;
    Local.configure(config.local, component: component ?? '');
    return _add(config);
  }

  static Future<void> _add(AppConfig config) async {
    for (final c in config.connections) {
      if (_connections.containsKey(c.name)) {
        throw StateError('two connections are named "${c.name}"; each connectionName is used once');
      }
      _connections[c.name] = c;
    }
    for (final g in config.globals) {
      g.register(di);
      _globals.add(g);
      await g.init();
    }
  }

  /// Every connection of the project config and the components' configs.
  static Iterable<Connection> get connections => _connections.values;

  /// The connection named [name] (`''` = the connection without `connectionName`).
  static T connection<T extends Connection>([String name = '']) {
    final c = _connections[name];
    if (c is T) return c;
    final known = _connections.keys.map((k) => k.isEmpty ? '(default)' : k).join(', ');
    throw StateError('no ${T.toString()} connection named "$name" in the project config (known: $known)');
  }

  /// Stops the global services and empties the injector, the connections, the cache and the local
  /// database (tests).
  static Future<void> reset() async {
    await Local.reset();
    for (final g in _globals.reversed) {
      await g.dispose();
    }
    _globals.clear();
    _connections.clear();
    started = false;
    cache.clear();
    await di.reset();
  }
}

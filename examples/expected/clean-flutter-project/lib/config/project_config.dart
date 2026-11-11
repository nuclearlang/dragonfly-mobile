import 'package:clean_flutter_project/shared/events/force_logout.dart';
import 'package:dragonfly/dragonfly.dart';

/// Global configuration: connections and services of the whole app, and how the local database is kept
/// (encrypted = true is the default; a component's config may set `local` for the tables of its own models).
class ProjectConfig extends AppConfig {
  @override
  final LocalDatabase local = LocalDatabase(encrypted: true);
  @override
  final List<Connection> connections = [
    Http(
      baseUrl: 'https://rickandmortyapi.com/api/',
      connectTimeout: Duration(seconds: 5),
      receiveTimeout: Duration(seconds: 3),
      interceptors: [
        SessionInterceptor(),
        EventInterceptor(events: {'force_logout': () => ForceLogout()}),
        HttpLogInterceptor(),
      ],
    ),
    WebSocket(connectionName: 'live', uri: 'wss://example.com/live'),
  ];
  @override
  final List<Global> globals = [
    Events(),
    SessionManager(timeout: Duration(minutes: 30)),
    Acl(inherits: {'admin': ['fan']}),
    NetworkManager(),
    Translations(locales: ['en', 'es'], fallback: 'en'),
  ];
}

// assets/i18n/<locale>/<component>.json; with remote = RemoteDictionaries(url = "https://...") the
// dictionaries are downloaded by version and win over the app's

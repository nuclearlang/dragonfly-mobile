import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';

import '../core.dart';
import '../log/log.dart';
import 'builtin.dart';
import 'store.dart';

export 'store.dart' show DictionaryStore;

/// Dictionaries served by a backend, so texts change without publishing the app. [url] has
/// `manifest.json` (`{"version": "7", "locales": {"es": ["characters", "shared"]}}`) and one file per
/// locale and dictionary: `<url>/7/es/characters.json`. A new version is downloaded whole, saved in its
/// own folder and used from then on (also offline, on the next start).
class RemoteDictionaries {
  const RemoteDictionaries({required this.url, this.headers = const {}, this.client});

  final String url;
  final Map<String, String> headers;

  /// The http client (null: a new one; tests give their own).
  final Dio? client;
}

/// The app's languages. Each locale has one JSON dictionary per component in `assets/i18n/<locale>/`
/// (`characters.json`, `shared.json`...); the file name is the first part of the key:
/// `'characters.home.header.welcomeTitle'.tr()` reads `home.header.welcomeTitle` of `characters.json`.
/// Only the current locale and the fallback are in memory. With [remote], the downloaded dictionaries
/// win over the bundled ones.
class Translations extends Global {
  Translations({
    this.locales = const ['en'],
    String? fallback,
    this.path = 'assets/i18n',
    this.remote,
    this.bundle,
    DictionaryStore? store,
  }) : assert(locales.isNotEmpty, 'Translations needs at least one locale'),
       fallback = fallback ?? locales.first,
       _store = store ?? DictionaryStore();

  final List<String> locales;
  final String fallback;
  final String path;
  final RemoteDictionaries? remote;

  /// Where the bundled dictionaries are read (rootBundle; tests give their own).
  final AssetBundle? bundle;
  final DictionaryStore _store;

  static Translations? _active;
  late String _locale = fallback;
  Map<String, String> _words = const {};
  Map<String, String> _fallbackWords = const {};

  @override
  void register(GetIt di) => di.registerSingleton<Translations>(this);

  @override
  Future<void> init() async {
    _active = this;
    _locale = _pick(await _read('locale') ?? PlatformDispatcher.instance.locale.toLanguageTag());
    await _load();
    if (remote != null) unawaited(_refreshOnce());
  }

  @override
  Future<void> dispose() async {
    if (identical(_active, this)) _active = null;
  }

  /// The current locale (for `MaterialApp(locale: ...)`).
  static Locale get locale => _toLocale(_active?._locale ?? 'en');

  static List<Locale> get supportedLocales => [
    for (final l in _active?.locales ?? const ['en']) _toLocale(l),
  ];

  /// The translations of Flutter's own widgets (date pickers, text selection...).
  static const List<LocalizationsDelegate<dynamic>> delegates = GlobalMaterialLocalizations.delegates;

  /// Changes the language, remembers it for the next start and rebuilds the app with the new texts.
  static Future<void> use(String locale) async {
    final t = _active;
    if (t == null) throw StateError('Translations is not in the globals of the project config');
    if (!t.locales.contains(locale)) throw ArgumentError('"$locale" is not one of ${t.locales}');
    t._locale = locale;
    await t._load();
    try {
      await t._store.write('locale', locale);
    } on Object catch (e) {
      Log.w('the locale could not be saved', data: e.toString(), at: 'dragonfly › translations');
    }
    _rebuildAll();
  }

  /// The text of [key] in the current locale, then in the fallback; the key itself when it has none.
  /// `{name}` is replaced by `args['name']`.
  static String tr(String key, [Map<String, Object?>? args]) {
    final t = _active;
    final lang = (t?._locale ?? 'en').split(RegExp('[-_]')).first;
    final text =
        t?._words[key] ?? t?._fallbackWords[key] ?? builtinWords[lang]?[key] ?? builtinWords['en']![key] ?? key;
    if (args == null || args.isEmpty) return text;
    return text.replaceAllMapped(_placeholder, (m) => args.containsKey(m[1]) ? '${args[m[1]]}' : m[0]!);
  }

  static final _placeholder = RegExp(r'\{(\w+)\}');

  /// Downloads the remote dictionaries when the server has a new version; true if they changed.
  static Future<bool> refresh() async => await _active?._refreshOnce() ?? false;

  Future<bool>? _refreshing;

  /// One download at a time: a second call waits for the running one.
  Future<bool> _refreshOnce() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  /// A configured locale for [tag] ('es-MX' → 'es_MX', else 'es'), else the fallback.
  String _pick(String tag) {
    final norm = tag.replaceAll('-', '_');
    if (locales.contains(norm)) return norm;
    final lang = norm.split('_').first;
    return locales.contains(lang) ? lang : fallback;
  }

  Future<void> _load() async {
    _words = await _dictionaries(_locale);
    _fallbackWords = _locale == fallback ? const {} : await _dictionaries(fallback);
  }

  /// Every dictionary of [locale]: the bundled ones, then the downloaded ones on top.
  Future<Map<String, String>> _dictionaries(String locale) async {
    final words = <String, String>{};
    final bundle = this.bundle ?? rootBundle;
    final dir = '$path/$locale/';
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      for (final asset in manifest.listAssets().where((a) => a.startsWith(dir) && a.endsWith('.json'))) {
        _flatten(_name(asset), jsonDecode(await bundle.loadString(asset)), words);
      }
    } on Object catch (e) {
      // an app without assets (tests) has no asset manifest
      Log.d('no bundled dictionaries for $locale', data: e.toString(), at: 'dragonfly › translations');
    }
    final version = remote == null ? null : await _read('current');
    final files = version == null ? null : await _read('$version/manifest.json');
    if (files != null) {
      final names = (jsonDecode(files) as Map<String, dynamic>)['locales']?[locale] as List<dynamic>? ?? const [];
      for (final n in names) {
        final text = await _read('$version/$locale/$n.json');
        if (text != null) _flatten('$n', jsonDecode(text), words);
      }
    }
    return words;
  }

  Future<bool> _refresh() async {
    final r = remote!;
    final dio = r.client ?? Dio(BaseOptions(headers: r.headers));
    try {
      final plain = Options(responseType: ResponseType.plain);
      final raw = (await dio.get<String>('${r.url}/manifest.json', options: plain)).data!;
      final manifest = jsonDecode(raw) as Map<String, dynamic>;
      final version = '${manifest['version']}';
      final byLocale = (manifest['locales'] as Map<String, dynamic>?) ?? const {};
      // the names become folders: nothing from the server may climb out of the store
      final names = [
        version,
        ...byLocale.keys,
        for (final l in byLocale.values) ...(l as List<dynamic>).map((n) => '$n'),
      ];
      if (names.any((n) => !_safe.hasMatch(n))) throw FormatException('unsafe name in $names');
      if (version == await _store.read('current')) return false;
      for (final MapEntry(key: locale, value: files) in byLocale.entries) {
        if (!locales.contains(locale)) continue;
        for (final n in files as List<dynamic>) {
          final text = (await dio.get<String>('${r.url}/$version/$locale/$n.json', options: plain)).data!;
          jsonDecode(text); // a broken file stops the update before it is used
          await _store.write('$version/$locale/$n.json', text);
        }
      }
      await _store.write('$version/manifest.json', raw);
      await _store.write('current', version);
      await _store.prune(version);
      await _load();
      _rebuildAll();
      return true;
    } on Object catch (e) {
      Log.w('the remote dictionaries could not be updated', data: e.toString(), at: 'dragonfly › translations');
      return false;
    } finally {
      if (r.client == null) dio.close(); // its sockets do not outlive the download
    }
  }

  /// A stored file, or null when there is none or the platform has no storage (tests).
  Future<String?> _read(String path) async {
    try {
      return await _store.read(path);
    } on Object {
      return null;
    }
  }

  static final _safe = RegExp(r'^[A-Za-z0-9_.-]+$');

  static String _name(String asset) => asset.substring(asset.lastIndexOf('/') + 1, asset.length - '.json'.length);

  static void _flatten(String prefix, Object? node, Map<String, String> into) {
    if (node is Map) {
      node.forEach((k, v) => _flatten('$prefix.$k', v, into));
    } else if (node != null && node is! List) {
      into[prefix] = '$node';
    }
  }

  static Locale _toLocale(String tag) {
    final p = tag.split(RegExp('[-_]'));
    return Locale(p.first, p.length > 1 ? p[1] : null);
  }

  /// Every widget builds again (keeping its state), so each `tr` reads the new texts.
  static void _rebuildAll() {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  }
}

/// `'characters.home.title'.tr()` and `'cart.items'.tr({'n': 3})`.
extension DragonflyTranslate on String {
  String tr([Map<String, Object?>? args]) => Translations.tr(this, args);
}

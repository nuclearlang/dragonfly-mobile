import 'package:web/web.dart' as web;

/// Downloaded dictionaries in the browser's localStorage, one key per file:
/// `dragonfly.i18n/<version>/<locale>/<file>.json`; the active version in `dragonfly.i18n/current`.
class DictionaryStore {
  static const _prefix = 'dragonfly.i18n/';

  Future<String?> read(String path) async => web.window.localStorage.getItem('$_prefix$path');

  Future<void> write(String path, String text) async => web.window.localStorage.setItem('$_prefix$path', text);

  /// Removes every version except [keep].
  Future<void> prune(String keep) async {
    final storage = web.window.localStorage;
    final old = [
      for (var i = 0; i < storage.length; i++)
        if (storage.key(i) case final k?
            when k.startsWith(_prefix) && !k.startsWith('$_prefix$keep/') && k.contains('/', _prefix.length))
          k,
    ];
    for (final k in old) {
      storage.removeItem(k);
    }
  }
}

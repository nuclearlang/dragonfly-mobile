import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Downloaded dictionaries in `<app support>/dragonfly/i18n/<version>/<locale>/<file>.json`; the active
/// version is in `current` (written last, so a download cut in half is never used).
class DictionaryStore {
  Future<Directory> _root() async => Directory('${(await getApplicationSupportDirectory()).path}/dragonfly/i18n');

  Future<String?> read(String path) async {
    final f = File('${(await _root()).path}/$path');
    return await f.exists() ? f.readAsString() : null;
  }

  Future<void> write(String path, String text) async {
    final f = File('${(await _root()).path}/$path');
    await f.parent.create(recursive: true);
    await f.writeAsString(text, flush: true);
  }

  /// Removes every version folder except [keep].
  Future<void> prune(String keep) async {
    final root = await _root();
    if (!await root.exists()) return;
    await for (final e in root.list()) {
      if (e is Directory && e.uri.pathSegments.where((s) => s.isNotEmpty).last != keep) {
        await e.delete(recursive: true);
      }
    }
  }
}

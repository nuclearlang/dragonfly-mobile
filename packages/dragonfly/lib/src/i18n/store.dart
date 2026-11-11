// Where downloaded dictionaries are saved: files on Android, iOS, macOS, Linux and Windows, the
// browser's localStorage on the web. Both use the same layout: `<version>/<locale>/<file>.json`.
export 'store_io.dart' if (dart.library.js_interop) 'store_web.dart';

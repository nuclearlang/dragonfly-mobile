/// How a repository method caches its responses (`@get(cache = true, cacheKey = "x", ttl = ...)`).
class Cache {
  const Cache({this.key, this.ttl = const Duration(minutes: 5)});

  /// Prefix of the entries; by default `Repository.method`. Every set of arguments is its own entry.
  final String? key;

  final Duration ttl;
}

/// In-memory cache of decoded responses. Entries expire after their TTL; past [maxEntries] the expired
/// ones are dropped, then the oldest.
class MemoryCache {
  MemoryCache({this.maxEntries = 256});

  final int maxEntries;
  final Map<String, ({Object? value, DateTime expires})> _entries = {};

  /// The cached value of [key], or null when it is missing or expired.
  ({Object? value})? read(String key) {
    final e = _entries[key];
    if (e == null) return null;
    if (DateTime.now().isAfter(e.expires)) {
      _entries.remove(key);
      return null;
    }
    return (value: e.value);
  }

  void write(String key, Object? value, Duration ttl) {
    final now = DateTime.now();
    _entries.remove(key); // re-inserted last: the map keeps insertion order, oldest first
    if (_entries.length >= maxEntries) _entries.removeWhere((_, e) => now.isAfter(e.expires));
    while (_entries.length >= maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = (value: value, expires: now.add(ttl));
  }

  /// Removes every entry whose key starts with [prefix] (all the pages of `Repo.getAll`).
  void purge(String prefix) => _entries.removeWhere((k, _) => k == prefix || k.startsWith('$prefix|'));

  void clear() => _entries.clear();

  int get length => _entries.length;
}

class _Entry {
  final dynamic data;
  final DateTime time;
  const _Entry(this.data, this.time);
}

/// In-memory cache untuk data halaman utama.
/// Data otomatis dianggap stale setelah [maxAge] dan dibersihkan saat logout.
class PageCache {
  static const maxAge = Duration(minutes: 2);
  static final _store = <String, _Entry>{};

  static T? get<T>(String key) {
    final e = _store[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.time) > maxAge) {
      _store.remove(key);
      return null;
    }
    return e.data as T?;
  }

  static void set(String key, dynamic data) {
    _store[key] = _Entry(data, DateTime.now());
  }

  static void remove(String key) => _store.remove(key);

  static void clearAll() => _store.clear();
}

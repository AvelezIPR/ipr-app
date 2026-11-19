import 'dart:convert';

import 'package:hive_ce/hive.dart';

/// Frescura de un valor guardado según su política.
enum CacheFreshness { fresh, stale, expired }

/// Política de caché por recurso (`flutter_app_architecture.md` §7.4).
final class CachePolicy {
  const new({required this.fresh, required this.stale});

  /// Tiempo durante el que el dato se considera vigente.
  final Duration fresh;

  /// Tiempo máximo de uso como dato obsoleto (con aviso).
  final Duration stale;

  static const config = CachePolicy(
    fresh: Duration(minutes: 5),
    stale: Duration(days: 30),
  );
  static const taxonomy = CachePolicy(
    fresh: Duration(hours: 1),
    stale: Duration(days: 7),
  );
  static const listing = CachePolicy(
    fresh: Duration(minutes: 5),
    stale: Duration(hours: 24),
  );
  static const stores = CachePolicy(
    fresh: Duration(hours: 24),
    stale: Duration(days: 30),
  );
}

/// Valor leído de la caché junto con su frescura.
final class CacheRead {
  const new({
    required this.value,
    required this.storedAt,
    required this.freshness,
  });

  final String value;
  final DateTime storedAt;
  final CacheFreshness freshness;

  bool get isStale => freshness != CacheFreshness.fresh;
}

/// Caché pública local: catálogo, sedes, configuración. **Cero PII**
/// (CR-065); el perfil, las direcciones y los pedidos solo viven en memoria.
abstract interface class CacheStore {
  Future<CacheRead?> read(String key, CachePolicy policy);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Future<void> clear();
  int get length;
}

/// Implementación con `hive_ce` y expulsión LRU acotada.
final class HiveCacheStore implements CacheStore {
  new(this._box, {this.maxEntries = 300, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Box<String> _box;
  final int maxEntries;
  final DateTime Function() _now;

  @override
  int get length => _box.length;

  @override
  Future<CacheRead?> read(String key, CachePolicy policy) async {
    final raw = _box.get(key);
    if (raw == null) return null;
    final entry = _decode(raw);
    if (entry == null) {
      await _box.delete(key);
      return null;
    }
    final age = _now().difference(entry.storedAt);
    final freshness = age <= policy.fresh
        ? CacheFreshness.fresh
        : age <= policy.stale
        ? CacheFreshness.stale
        : CacheFreshness.expired;
    if (freshness == CacheFreshness.expired) {
      await _box.delete(key);
      return null;
    }
    // Acceso reciente: se mueve al final para la expulsión LRU.
    await _box.put(key, _encode(entry.value, entry.storedAt, _now()));
    return CacheRead(
      value: entry.value,
      storedAt: entry.storedAt,
      freshness: freshness,
    );
  }

  @override
  Future<void> write(String key, String value) async {
    await _box.put(key, _encode(value, _now(), _now()));
    await _evict();
  }

  @override
  Future<void> remove(String key) => _box.delete(key);

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  Future<void> _evict() async {
    if (_box.length <= maxEntries) return;
    final accessed = <String, int>{};
    for (final key in _box.keys.cast<String>()) {
      final entry = _decode(_box.get(key)!);
      accessed[key] = entry?.accessedAtMs ?? 0;
    }
    final byOldest = accessed.keys.toList()
      ..sort((a, b) => accessed[a]!.compareTo(accessed[b]!));
    final excess = _box.length - maxEntries;
    await _box.deleteAll(byOldest.take(excess));
  }

  String _encode(String value, DateTime storedAt, DateTime accessedAt) =>
      jsonEncode({
        'v': value,
        't': storedAt.millisecondsSinceEpoch,
        'a': accessedAt.millisecondsSinceEpoch,
      });

  _Entry? _decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _Entry(
        value: map['v'] as String,
        storedAt: DateTime.fromMillisecondsSinceEpoch(map['t'] as int),
        accessedAtMs: map['a'] as int,
      );
    } on Object {
      return null;
    }
  }
}

final class _Entry {
  const new({
    required this.value,
    required this.storedAt,
    required this.accessedAtMs,
  });

  final String value;
  final DateTime storedAt;
  final int accessedAtMs;
}

/// Implementación en memoria (pruebas y arranque sin disco).
final class MemoryCacheStore implements CacheStore {
  new({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, (String, DateTime)> _data = {};

  @override
  int get length => _data.length;

  @override
  Future<CacheRead?> read(String key, CachePolicy policy) async {
    final item = _data[key];
    if (item == null) return null;
    final age = _now().difference(item.$2);
    if (age > policy.stale) {
      _data.remove(key);
      return null;
    }
    return CacheRead(
      value: item.$1,
      storedAt: item.$2,
      freshness: age <= policy.fresh
          ? CacheFreshness.fresh
          : CacheFreshness.stale,
    );
  }

  @override
  Future<void> write(String key, String value) async {
    _data[key] = (value, _now());
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}

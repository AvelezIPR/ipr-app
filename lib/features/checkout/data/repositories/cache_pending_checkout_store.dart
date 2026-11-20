import 'dart:convert';

import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/pending_checkout.dart';
import 'package:ipr_mobile/features/checkout/domain/repositories/pending_checkout_store.dart';

/// Guarda `{checkoutRef, attemptId, marca de tiempo}` en la caché local. **Sin
/// PII**: ni el ticket, ni la URL, ni importes, ni datos del usuario.
///
/// Caduca a los [ttl] (corto: si el usuario no volvió en ese tiempo, el
/// intento ya no se reanuda).
final class CachePendingCheckoutStore implements PendingCheckoutStore {
  new(
    this._cache, {
    this.ttl = const Duration(minutes: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const key = 'checkout.pending';

  final CacheStore _cache;
  final Duration ttl;
  final DateTime Function() _now;

  CachePolicy get _policy => CachePolicy(fresh: ttl, stale: ttl);

  @override
  Future<void> save(PendingCheckout pending) => _cache.write(
    key,
    jsonEncode({
      'ref': pending.checkoutRef,
      'attempt': pending.attemptId,
      'at': pending.startedAt.millisecondsSinceEpoch,
    }),
  );

  @override
  Future<PendingCheckout?> load() async {
    final read = await _cache.read(key, _policy);
    if (read == null) return null;
    final pending = _decode(read.value);
    if (pending == null || _now().difference(pending.startedAt) > ttl) {
      await _cache.remove(key);
      return null;
    }
    return pending;
  }

  @override
  Future<void> clear() => _cache.remove(key);

  static PendingCheckout? _decode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final ref = map['ref'];
      final attempt = map['attempt'];
      final at = map['at'];
      if (ref is! String || !isUuidV4(ref)) return null;
      if (attempt is! String || attempt.isEmpty || attempt.length > 64) {
        return null;
      }
      if (at is! int) return null;
      return PendingCheckout(
        checkoutRef: ref,
        attemptId: attempt,
        startedAt: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      );
    } on FormatException {
      return null;
    }
  }
}

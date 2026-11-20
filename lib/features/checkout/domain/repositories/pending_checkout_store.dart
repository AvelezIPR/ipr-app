import 'package:ipr_mobile/features/checkout/domain/entities/pending_checkout.dart';

/// Registro sin PII del intento en curso (`awaitingResult`) para reanudar en
/// `verifying` si el sistema mata la app. Caduca en poco tiempo.
abstract interface class PendingCheckoutStore {
  Future<void> save(PendingCheckout pending);

  /// El registro vigente, o `null` si no hay, caducó o está dañado.
  Future<PendingCheckout?> load();

  Future<void> clear();
}

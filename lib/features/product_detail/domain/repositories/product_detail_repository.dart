import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';

/// Acceso a la ficha de producto (`getProduct`). Devuelve [Result]:
/// `Err(NotFound())` (404 definitivo) es distinto de `Err(ServiceUnavailable())`
/// (caída del origen), RF-009 / TC-104.
abstract interface class ProductDetailRepository {
  /// Carga la ficha de [slug] con caché SWR (5 min vigente / 24 h obsoleta).
  /// [forceRefresh] ignora la caché vigente (reintento manual).
  Future<Result<ProductDetailLoad>> load(
    String slug, {
    bool forceRefresh = false,
    RequestCancellation? cancellation,
  });
}

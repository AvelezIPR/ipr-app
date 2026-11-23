import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_city.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';

/// Lectura de los bloques del inicio. Cada bloque falla por separado: un
/// `Err` en uno no afecta a los demás (AC-003-4).
///
/// Con `forceRefresh` se ignora la caché vigente y se pide al servidor
/// (pull-to-refresh y "Reintentar"). Un fallo de red con caché disponible
/// devuelve la caché marcada `stale`; sin caché, el `Err` (nunca una lista
/// vacía fingida).
abstract interface class HomeRepository {
  /// Categorías raíz publicadas por `/mobile/v1` (RF-002).
  Future<Result<SectionData<List<HomeCategory>>>> categories({
    bool forceRefresh = false,
  });

  /// Directorio de marcas con página propia (RF-004).
  Future<Result<SectionData<List<HomeBrand>>>> brands({
    bool forceRefresh = false,
  });

  /// Productos del bloque "más vendidos" (RF-003).
  Future<Result<SectionData<List<ProductSummary>>>> featuredProducts({
    bool forceRefresh = false,
  });

  /// Ciudades con sedes (resumen del bloque "Nuestras sedes").
  Future<Result<SectionData<List<HomeCity>>>> cities({
    bool forceRefresh = false,
  });
}

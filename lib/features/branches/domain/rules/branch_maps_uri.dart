import 'package:ipr_mobile/features/branches/domain/entities/branch.dart';

/// Construye el enlace seguro de búsqueda por dirección para "Cómo llegar"
/// (`https://www.google.com/maps/search/?api=1&query=…`, AC-075-1..4).
///
/// Usa búsqueda por texto (sin coordenadas D-09 ni permisos de ubicación) y cae
/// dentro de la lista blanca de `ExternalUrlPolicy` (`www.google.com/maps…`).
Uri? buildBranchMapsUri(Branch branch) {
  final query = branch.effectiveMapsQuery;
  if (query == null || query.isEmpty) return null;
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
}

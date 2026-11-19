import 'package:meta/meta.dart';

/// Marca del directorio (`openapi.yaml` → `Brand`).
@immutable
final class Brand {
  const new({
    required this.slug,
    required this.name,
    this.logoUrl,
    this.hasLanding = false,
  });

  final String slug;
  final String name;

  /// Logotipo; solo se muestra con `ProductImage` (lista blanca de hosts).
  final String? logoUrl;

  /// El servidor indica si la marca tiene landing editorial. El contenido
  /// editorial es de fase 2 (RF-017): la app solo guarda el dato.
  final bool hasLanding;

  @override
  bool operator ==(Object other) =>
      other is Brand &&
      other.slug == slug &&
      other.name == name &&
      other.logoUrl == logoUrl &&
      other.hasLanding == hasLanding;

  @override
  int get hashCode => Object.hash(slug, name, logoUrl, hasLanding);
}

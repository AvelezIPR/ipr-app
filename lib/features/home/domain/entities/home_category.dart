import 'package:meta/meta.dart';

/// Categoría raíz que el inicio muestra como acceso (`openapi.yaml` →
/// `Category`). Los hijos no se usan en el inicio: el listado de la categoría
/// los resuelve (RF-010).
@immutable
final class HomeCategory {
  const new({required this.id, required this.slug, required this.name});

  final int id;
  final String slug;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is HomeCategory &&
      other.id == id &&
      other.slug == slug &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, slug, name);
}

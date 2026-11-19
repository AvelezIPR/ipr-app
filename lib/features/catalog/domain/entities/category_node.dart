import 'package:meta/meta.dart';

/// Nodo del árbol de categorías (`openapi.yaml` → `Category`). El orden y la
/// jerarquía son los que entrega el servidor: la app no reordena ni
/// reclasifica (AC-010-5).
@immutable
final class CategoryNode {
  const new({
    required this.id,
    required this.slug,
    required this.name,
    this.parentId,
    this.children = const [],
  });

  final int id;
  final String slug;
  final String name;
  final int? parentId;
  final List<CategoryNode> children;

  /// Una categoría hoja lista productos; una con hijos lista subcategorías.
  bool get isLeaf => children.isEmpty;

  /// Busca por slug en este nodo y en todos sus descendientes.
  CategoryNode? find(String slug) {
    if (this.slug == slug) return this;
    for (final child in children) {
      final found = child.find(slug);
      if (found != null) return found;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is CategoryNode &&
      other.id == id &&
      other.slug == slug &&
      other.name == name &&
      other.parentId == parentId &&
      _sameChildren(other.children);

  bool _sameChildren(List<CategoryNode> other) {
    if (other.length != children.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i] != children[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, slug, name, parentId, children.length);
}

/// Busca [slug] en un bosque de categorías (raíces con hijos anidados).
CategoryNode? findCategory(List<CategoryNode> roots, String slug) {
  for (final root in roots) {
    final found = root.find(slug);
    if (found != null) return found;
  }
  return null;
}

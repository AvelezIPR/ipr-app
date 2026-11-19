import 'package:meta/meta.dart';

/// Marca del directorio (`openapi.yaml` → `Brand`).
@immutable
final class HomeBrand {
  const new({required this.slug, required this.name});

  final String slug;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is HomeBrand && other.slug == slug && other.name == name;

  @override
  int get hashCode => Object.hash(slug, name);
}

import 'package:meta/meta.dart';

/// Ciudad con sedes de IPR, resumida para el inicio (`openapi.yaml` → `Store`
/// agrupado por `city`). Solo cuenta sedes: el detalle vive en la feature de
/// sedes.
@immutable
final class HomeCity {
  const new({
    required this.name,
    required this.branchCount,
    required this.upcoming,
  });

  final String name;

  /// Sedes abiertas en la ciudad (las `upcoming` no cuentan).
  final int branchCount;

  /// `true` si la ciudad solo tiene sedes por abrir.
  final bool upcoming;

  @override
  bool operator ==(Object other) =>
      other is HomeCity &&
      other.name == name &&
      other.branchCount == branchCount &&
      other.upcoming == upcoming;

  @override
  int get hashCode => Object.hash(name, branchCount, upcoming);
}

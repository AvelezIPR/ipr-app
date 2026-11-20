import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Conteo de unidades en el carrito para la insignia superior de Inicio
/// (`H1-03`). Por defecto vale `0` para que `home` no dependa de `cart` (D3);
/// `app/providers.dart` lo enlaza con `cartUnitCountProvider`.
final homeCartCountProvider = Provider<int>((ref) => 0);

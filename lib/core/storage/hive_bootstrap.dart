import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

/// Nombres de las cajas de Hive. Ambas sin PII (CR-065).
abstract final class HiveBoxes {
  static const cache = 'cache';
  static const cart = 'cart';
}

/// Inicializa Hive en el directorio de soporte de la app y abre la caja de
/// caché. La caja `cart` se abre con [openCartBox].
Future<Box<String>> openCacheBox() async {
  final dir = await getApplicationSupportDirectory();
  Hive.init(dir.path);
  final box = await Hive.openBox<String>(HiveBoxes.cache);
  return box;
}

/// Abre la caja `cart` (carrito local, sin PII). Debe llamarse después de
/// [openCacheBox], que inicializa Hive.
Future<Box<String>> openCartBox() => Hive.openBox<String>(HiveBoxes.cart);

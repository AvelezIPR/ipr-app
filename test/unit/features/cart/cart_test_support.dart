import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/features/cart/cart_providers.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_validation_mapper.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/features/cart/domain/repositories/cart_repositories.dart';
import 'package:ipr_mobile/features/cart/presentation/controllers/cart_controller.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import '../../../mocks/test_providers.dart';

export 'package:ipr_mobile/features/cart/cart_providers.dart';
export 'package:ipr_mobile/features/cart/presentation/controllers/cart_controller.dart';

/// Respuesta completa (`{data: ...}`) de un fixture de `cart`.
Map<String, dynamic> cartFixtureBody(String file) =>
    jsonDecode(File('test/fixtures/cart/$file').readAsStringSync())
        as Map<String, dynamic>;

/// Entidad construida con el mismo mapeador de producción.
CartValidation cartFixture(String file) =>
    mapCartValidation(cartFixtureBody(file));

/// Producto sintético para instantáneas y respuestas.
ProductSummary productOf({
  int id = 4521,
  String name = 'Compresor scroll 24.000 BTU',
  String sku = 'QA-0001',
  String? brand = 'Copeland',
  PriceStatus price = const Priced(Money(100000)),
  StockStatus stock = StockStatus.inStock,
  String? imageUrl,
}) => ProductSummary(
  id: id,
  slug: 'producto-$id',
  name: name,
  sku: sku,
  brandName: brand,
  price: price,
  availability: stock,
  image: imageUrl == null ? null : ImageRef(url: imageUrl, alt: name),
);

/// Línea con instantánea.
CartLine lineOf(
  int id,
  int quantity, {
  int price = 100000,
  String? name,
  StockStatus stock = StockStatus.inStock,
}) => CartLine(
  productId: id,
  quantity: quantity,
  snapshot: CartLineSnapshot.fromProduct(
    productOf(
      id: id,
      name: name ?? 'Producto $id',
      sku: 'SKU-$id',
      price: price == 0 ? const OnRequest() : Priced(Money(price)),
      stock: stock,
    ),
  ),
);

/// Validación del servidor armada a mano.
CartValidation validationOf(
  List<ValidatedCartLine> lines, {
  bool checkoutAllowed = true,
  int? subtotal,
}) => CartValidation(
  checkoutAllowed: checkoutAllowed,
  lines: lines,
  informativeSubtotal: Money(
    subtotal ??
        lines.fold(0, (sum, line) => sum + (line.lineSubtotal?.pesos ?? 0)),
  ),
);

/// Línea validada disponible, con precio unitario [price].
ValidatedCartLine availableLine(int id, int quantity, {int price = 100000}) =>
    ValidatedCartLine(
      id: id,
      quantity: quantity,
      status: CartLineStatus.available,
      product: productOf(
        id: id,
        name: 'Producto $id',
        sku: 'SKU-$id',
        price: Priced(Money(price)),
      ),
      lineSubtotal: Money(price * quantity),
    );

/// Repositorio de revalidación guionado: cada llamada consume el siguiente
/// resultado (el último se repite) y registra el carrito recibido.
final class FakeCartValidationRepository implements CartValidationRepository {
  new(this.results);

  final List<Result<CartValidation>> results;
  final List<Cart> calls = [];

  /// Si no es nulo, la siguiente llamada espera a que se complete.
  Completer<void>? gate;

  @override
  Future<Result<CartValidation>> validate(
    Cart cart, {
    RequestCancellation? cancellation,
  }) async {
    calls.add(cart);
    final wait = gate;
    if (wait != null) await wait.future;
    final index = calls.length - 1;
    return results[index < results.length ? index : results.length - 1];
  }
}

/// Almacén duradero que falla en lectura o escritura.
final class BrokenDurableStore implements DurableStore {
  const new({this.failRead = false, this.failWrite = false});

  final bool failRead;
  final bool failWrite;

  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('disco ilegible (prueba)');
    return null;
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('disco lleno (prueba)');
  }

  @override
  Future<void> remove(String key) async {
    if (failWrite) throw StateError('disco lleno (prueba)');
  }
}

/// Overrides de la feature: almacén duradero, revalidación y `/config`.
List<Override> cartOverrides({
  FakeExternalLauncher? launcher,
  DurableStore? durable,
  CartValidationRepository? validation,
  bool checkoutEnabled = true,
  List<Override> extra = const [],
}) => testOverrides(
  launcher: launcher,
  durable: durable,
  extra: [
    if (validation != null)
      cartValidationRepositoryProvider.overrideWithValue(validation),
    remoteConfigProvider.overrideWithBuild(
      (ref, notifier) => RemoteConfigState(
        config: RemoteConfig(checkoutEnabled: checkoutEnabled),
        source: RemoteConfigSource.network,
      ),
    ),
    ...extra,
  ],
);

/// Contenedor con la feature cableada; el carrito se lee de [durable].
ProviderContainer cartContainer({
  DurableStore? durable,
  CartValidationRepository? validation,
  bool checkoutEnabled = true,
}) => ProviderContainer(
  overrides: cartOverrides(
    durable: durable,
    validation: validation,
    checkoutEnabled: checkoutEnabled,
  ),
);

/// Espera a que el carrito termine de leer el almacén.
Future<CartController> loadedCart(ProviderContainer container) async {
  final notifier = container.read(cartProvider.notifier);
  while (!container.read(cartProvider).loaded) {
    await Future<void>.delayed(Duration.zero);
  }
  return notifier;
}

const failureOffline = Err<CartValidation>(NoConnection());
const failureUnavailable = Err<CartValidation>(ServiceUnavailable());

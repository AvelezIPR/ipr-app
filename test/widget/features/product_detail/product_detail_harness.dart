import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' show RichText, TextSpan;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_variant.dart';
import 'package:ipr_mobile/features/product_detail/domain/repositories/product_detail_repository.dart';
import 'package:ipr_mobile/features/product_detail/domain/usecases/add_to_cart_action.dart';
import 'package:ipr_mobile/features/product_detail/presentation/controllers/add_to_cart_provider.dart';
import 'package:ipr_mobile/features/product_detail/product_detail.dart';
import 'package:ipr_mobile/features/product_detail/product_detail_providers.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:material_ui/material_ui.dart' show IconButton;

import '../../../mocks/pump_app.dart';
import '../../../mocks/test_providers.dart';
import '../../../unit/features/product_detail/product_detail_test_support.dart';

export 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart'
    show ProductDetail, ProductDetailLoad;

export '../../../mocks/pump_app.dart';
export '../../../mocks/test_providers.dart';
export '../../../unit/features/product_detail/product_detail_test_support.dart';

const kSlug = 'compresor-scroll-24000-btu';

/// Espía de la costura del carrito.
final class FakeAddToCart implements AddToCartAction {
  new({this.result = const Ok(AddToCartOutcome())});

  Result<AddToCartOutcome> result;
  final List<({int productId, int quantity})> calls = [];

  /// Productos (instantáneas) tal como los vio la persona al añadir.
  final List<ProductSummary?> snapshots = [];

  @override
  Future<Result<AddToCartOutcome>> add({
    required int productId,
    required int quantity,
    ProductSummary? snapshot,
  }) async {
    calls.add((productId: productId, quantity: quantity));
    snapshots.add(snapshot);
    return result;
  }
}

/// Repositorio que no responde hasta que la prueba lo decide (estado de
/// carga).
final class PendingProductDetailRepository implements ProductDetailRepository {
  final Completer<Result<ProductDetailLoad>> completer = Completer();

  @override
  Future<Result<ProductDetailLoad>> load(
    String slug, {
    bool forceRefresh = false,
    RequestCancellation? cancellation,
  }) => completer.future;
}

ProductDetailLoad loadOf(String fixture, {bool stale = false}) =>
    ProductDetailLoad(product: fixtureProduct(fixture), stale: stale);

/// Producto construido a mano para casos puntuales (nombre, SKU, precio...).
ProductDetail customProduct({
  int id = 77,
  String name = 'Producto de prueba',
  String sku = 'SKU-1',
  PriceStatus price = const Priced(Money(10000)),
  StockStatus availability = StockStatus.inStock,
  List<String> galleryUrls = const [],
  String shortDescription = '',
  String descriptionHtml = '',
  bool serverPurchasable = true,
  QuantityRange quantityRange = QuantityRange.standard,
  List<ProductVariantAxis> variantAxes = const [],
  List<ProductVariant> variants = const [],
}) => ProductDetail(
  summary: ProductSummary(
    id: id,
    slug: 'producto-de-prueba',
    name: name,
    sku: sku,
    price: price,
    availability: availability,
    quantityRange: quantityRange,
  ),
  shortDescription: shortDescription,
  descriptionHtml: descriptionHtml,
  serverPurchasable: serverPurchasable,
  variantAxes: variantAxes,
  variants: variants,
  gallery: [for (final url in galleryUrls) ImageRef(url: url, alt: '')],
);

/// Overrides de la ficha: repositorio falso, avisos de `/config` y costura
/// del carrito.
List<Override> productOverrides({
  required ProductDetailRepository repository,
  FakeExternalLauncher? launcher,
  FakeAddToCart? addToCart,
  RemoteConfig? config,
  Map<int, int> cartQuantities = const {},
}) => testOverrides(
  launcher: launcher,
  extra: [
    productDetailRepositoryProvider.overrideWithValue(repository),
    if (addToCart != null) addToCartActionProvider.overrideWithValue(addToCart),
    if (cartQuantities.isNotEmpty)
      cartQuantityForProductProvider.overrideWith(
        (ref, productId) => cartQuantities[productId] ?? 0,
      ),
    if (config != null)
      remoteConfigProvider.overrideWithBuild(
        (ref, notifier) => RemoteConfigState(
          config: config,
          source: RemoteConfigSource.network,
        ),
      ),
  ],
);

/// Monta la ficha y deja que cargue.
Future<void> pumpProduct(
  WidgetTester tester, {
  required ProductDetailRepository repository,
  FakeExternalLauncher? launcher,
  FakeAddToCart? addToCart,
  RemoteConfig? config,
  Map<int, int> cartQuantities = const {},
  double textScale = 1,
  String slug = kSlug,
  Size size = const Size(360, 800),
}) async {
  await pumpApp(
    tester,
    ProductDetailScreen(slug: slug),
    textScale: textScale,
    size: size,
    overrides: productOverrides(
      repository: repository,
      launcher: launcher,
      addToCart: addToCart,
      config: config,
      cartQuantities: cartQuantities,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

FakeProductDetailRepository repoWith(String fixture, {bool stale = false}) =>
    FakeProductDetailRepository([Ok(loadOf(fixture, stale: stale))]);

/// Activa el enlace cuyo texto contiene [text] dentro del HTML renderizado.
void tapHtmlLink(WidgetTester tester, String text) {
  final finder = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
  final rich = tester.widget<RichText>(finder.first);
  var fired = false;
  rich.text.visitChildren((span) {
    if (span is TextSpan &&
        span.recognizer is TapGestureRecognizer &&
        span.toPlainText().contains(text)) {
      (span.recognizer! as TapGestureRecognizer).onTap!();
      fired = true;
      return false;
    }
    return true;
  });
  expect(fired, isTrue, reason: 'no hay un enlace con "$text"');
}

/// El `IconButton` que lleva el [tooltip] (`find.byTooltip` devuelve el
/// `Tooltip` interno, no el botón).
Finder iconButtonWith(String tooltip) => find.ancestor(
  of: find.byTooltip(tooltip),
  matching: find.byType(IconButton),
);

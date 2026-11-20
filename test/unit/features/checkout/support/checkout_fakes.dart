import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/external/secure_browser.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/checkout/checkout_providers.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/cart_review.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_ticket.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/repositories/checkout_cart.dart';
import 'package:ipr_mobile/features/checkout/domain/repositories/checkout_repository.dart';

import '../../../../mocks/test_clients.dart';

/// UUID v4 sintéticos y estables.
const refA = '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b';
const refB = '7c9e6679-7425-40de-944b-e07fc1f90ae7';

/// Valor inventado: un ticket sintético de 32 caracteres. Las pruebas
/// comprueban que NUNCA aparece en estado, `toString`, caché ni registros.
const ticketSecret = 'AbCdEfGhIjKlMnOpQrStUvWxYz012345';

Uri ticketUrl({String host = 'staging.invalid'}) =>
    Uri.parse('https://$host/?ipr_ticket=$ticketSecret');

CheckoutTicket makeTicket({
  String ref = refA,
  Uri? url,
  Set<String> allowedHosts = const {'staging.invalid'},
}) => CheckoutTicket(
  checkoutRef: ref,
  checkoutUrl: url ?? ticketUrl(),
  allowedHosts: allowedHosts,
);

CheckoutStatus awaitingStatus({String ref = refA}) =>
    CheckoutStatus(checkoutRef: ref);

CheckoutStatus orderStatus(PaymentState state, {String ref = refA}) =>
    CheckoutStatus(
      checkoutRef: ref,
      order: VerifiedOrder(
        id: 1001,
        number: '1001',
        statusLabel: 'Etiqueta ${state.name}',
        paymentState: state,
      ),
    );

const twoLines = [
  CheckoutLine(productId: 1201, quantity: 2, name: 'Filtro de aire'),
  CheckoutLine(productId: 988, quantity: 1, name: 'Compresor 12.000 BTU'),
];

/// Carrito falso del checkout.
final class FakeCheckoutCart implements CheckoutCart {
  new({List<CheckoutLine> lines = twoLines, List<Result<CartReview>>? reviews})
    : lines = List.of(lines) {
    if (reviews != null) {
      this.reviews
        ..clear()
        ..addAll(reviews);
    }
  }

  @override
  List<CheckoutLine> lines;

  /// Respuestas de `revalidate` (la última se repite).
  final List<Result<CartReview>> reviews = [
    const Ok(CartReview(checkoutAllowed: true)),
  ];
  int revalidateCalls = 0;
  int clearCalls = 0;

  /// Si no es nulo, `revalidate` espera a este futuro.
  Completer<void>? revalidateGate;

  /// `clear` lanza.
  bool clearThrows = false;

  @override
  Future<Result<CartReview>> revalidate() async {
    revalidateCalls++;
    await revalidateGate?.future;
    return reviews.length > 1 ? reviews.removeAt(0) : reviews.first;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    if (clearThrows) throw StateError('no se pudo vaciar');
    lines = [];
  }
}

/// Llamada registrada a `createCheckout`.
final class CreateCall {
  const new({required this.lines, required this.idempotencyKey});
  final List<CheckoutLine> lines;
  final String idempotencyKey;
}

/// Repositorio falso con colas de respuestas.
final class FakeCheckoutRepository implements CheckoutRepository {
  /// Respuestas de `createCheckout` (la última se repite).
  final List<Result<CheckoutTicket>> createResults = [];

  /// Respuestas de `status` (la última se repite).
  final List<Result<CheckoutStatus>> statusResults = [];

  final List<CreateCall> createCalls = [];
  final List<String> statusCalls = [];

  /// Si no es nulo, `createCheckout` espera a este futuro.
  Completer<void>? createGate;

  @override
  Future<Result<CheckoutTicket>> createCheckout({
    required List<CheckoutLine> lines,
    required String idempotencyKey,
    RequestCancellation? cancellation,
  }) async {
    createCalls.add(
      CreateCall(lines: List.of(lines), idempotencyKey: idempotencyKey),
    );
    await createGate?.future;
    return createResults.length > 1
        ? createResults.removeAt(0)
        : createResults.first;
  }

  @override
  Future<Result<CheckoutStatus>> status(
    String checkoutRef, {
    RequestCancellation? cancellation,
  }) async {
    statusCalls.add(checkoutRef);
    return statusResults.length > 1
        ? statusResults.removeAt(0)
        : statusResults.first;
  }
}

/// Navegador seguro falso: registra las URL (solo para comprobar que NO se
/// abrió nada indebido).
final class FakeSecureBrowser implements SecureBrowser {
  final List<Uri> opened = [];
  final List<bool> results = [];
  bool throwsOnOpen = false;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    if (throwsOnOpen) throw StateError('sin navegador');
    return results.isEmpty || results.removeAt(0);
  }
}

/// Sesión de prueba: estado inicial fijo y cambiable.
final class FakeSessionController extends SessionController {
  new(this.initial);

  final SessionState initial;

  @override
  SessionState build() => initial;

  // Un método (no un setter) para que se lea como una acción de la prueba.
  // ignore: use_setters_to_change_properties
  void set(SessionState next) => state = next;
}

/// Configuración remota fija (sin red).
final class FakeRemoteConfigController extends RemoteConfigController {
  new(this._config);

  RemoteConfig _config;

  @override
  RemoteConfigState build() =>
      RemoteConfigState(config: _config, source: RemoteConfigSource.network);

  void update(RemoteConfig next) {
    _config = next;
    state = state.copyWith(config: next);
  }
}

const checkoutOn = RemoteConfig(
  checkoutEnabled: true,
  checkoutAllowedHosts: {'staging.invalid'},
);

/// Reloj manual: `sleep` solo avanza el reloj (sin esperar de verdad).
final class ManualClock {
  new() : _now = DateTime.utc(2026, 11, 20, 15);

  DateTime _now;
  final List<Duration> sleeps = [];

  DateTime now() => _now;

  Future<void> sleep(Duration duration) async {
    sleeps.add(duration);
    _now = _now.add(duration);
  }

  void advance(Duration duration) => _now = _now.add(duration);
}

/// Generador de UUID v4 deterministas (válidos).
final class SequentialUuids {
  int _n = 0;
  final List<String> issued = [];

  String next() {
    _n++;
    final id = '00000000-0000-4000-8000-${_n.toString().padLeft(12, '0')}';
    issued.add(id);
    return id;
  }
}

/// Overrides que sustituyen red, navegador, disco, reloj, sesión y carrito
/// por dobles. Las pruebas de widgets los usan con un `ProviderScope`.
List<Override> checkoutTestOverrides({
  required FakeCheckoutCart cart,
  required CheckoutRepository repo,
  required FakeSecureBrowser browser,
  required CacheStore cache,
  required ManualClock clock,
  required SequentialUuids uuids,
  required FakeSessionController session,
  required FakeRemoteConfigController remoteConfig,
  Future<void> Function(Duration)? sleep,
}) => [
  appConfigProvider.overrideWithValue(testConfig),
  checkoutCartProvider.overrideWithValue(cart),
  checkoutRepositoryProvider.overrideWithValue(repo),
  secureBrowserProvider.overrideWithValue(browser),
  cacheStoreProvider.overrideWithValue(cache),
  checkoutNowProvider.overrideWithValue(clock.now),
  checkoutSleepProvider.overrideWithValue(sleep ?? clock.sleep),
  checkoutUuidProvider.overrideWithValue(uuids.next),
  sessionControllerProvider.overrideWith(() => session),
  remoteConfigProvider.overrideWith(() => remoteConfig),
];

/// Dobles y overrides para ejercitar el controlador sin red.
final class CheckoutHarness {
  new({
    FakeCheckoutCart? cart,
    FakeCheckoutRepository? repo,
    FakeSecureBrowser? browser,
    SessionState session = const SessionAuthenticated(userId: 4821),
    RemoteConfig config = checkoutOn,
    MemoryCacheStore? cache,
    ManualClock? clock,
    Future<void> Function(Duration)? sleep,
    List<Override> extra = const [],
  }) : cart = cart ?? FakeCheckoutCart(),
       repo = repo ?? FakeCheckoutRepository(),
       browser = browser ?? FakeSecureBrowser(),
       cache = cache ?? MemoryCacheStore(),
       clock = clock ?? ManualClock(),
       uuids = SequentialUuids(),
       sessionController = FakeSessionController(session),
       remoteConfig = FakeRemoteConfigController(config) {
    container = ProviderContainer(
      overrides: [
        ...checkoutTestOverrides(
          cart: this.cart,
          repo: this.repo,
          browser: this.browser,
          cache: this.cache,
          clock: this.clock,
          uuids: uuids,
          session: sessionController,
          remoteConfig: remoteConfig,
          sleep: sleep,
        ),
        ...extra,
      ],
    );
  }

  final FakeCheckoutCart cart;
  final FakeCheckoutRepository repo;
  final FakeSecureBrowser browser;
  final MemoryCacheStore cache;
  final ManualClock clock;
  final SequentialUuids uuids;
  final FakeSessionController sessionController;
  final FakeRemoteConfigController remoteConfig;
  late final ProviderContainer container;

  void dispose() => container.dispose();
}

/// Error de red de prueba.
const noNetwork = Err<Never>(NoConnection());

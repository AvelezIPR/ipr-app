import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_storage_codec.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/features/cart/domain/rules/cart_retention_policy.dart';
import 'package:ipr_mobile/features/cart/domain/rules/checkout_gate.dart';
import 'package:ipr_mobile/features/cart/presentation/controllers/cart_session_hook.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';
import 'cart_test_support.dart';

/// Contenido persistido, decodificado.
Cart _stored(MemoryDurableStore store) =>
    CartStorageCodec.decode(store.data[CartStorageCodec.storageKey]);

ProviderContainer _container({
  MemoryDurableStore? store,
  FakeCartValidationRepository? validation,
  bool checkoutEnabled = true,
}) {
  final container = cartContainer(
    durable: store,
    validation: validation,
    checkoutEnabled: checkoutEnabled,
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('TC-036 · AC-029-7 · AC-049-8 · armar el carrito sin sesión', () {
    test('añadir funciona sin ninguna sesión ni red', () async {
      final store = MemoryDurableStore();
      final container = _container(store: store);
      final cart = await loadedCart(container);

      final result = await cart.add(4521, 3, snapshot: productOf());
      expect(result, isA<Ok<void>>());

      final state = container.read(cartProvider);
      expect(state.lines.single.productId, 4521);
      expect(state.lines.single.quantity, 3);
      expect(state.unitCount, 3);
      expect(state.isEmpty, isFalse);
      expect(_stored(store).lines.single.quantity, 3);
    });

    test('el estado inicial no está cargado y luego queda vacío', () async {
      final container = _container();
      expect(container.read(cartProvider).loaded, isFalse);
      await loadedCart(container);
      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(container.read(cartProvider).loaded, isTrue);
    });

    test(
      'una operación lanzada antes de terminar la lectura espera a que acabe',
      () async {
        final store = MemoryDurableStore();
        await store.write(
          CartStorageCodec.storageKey,
          CartStorageCodec.encode(Cart([lineOf(1, 2)])),
        );
        final container = _container(store: store);
        // Sin esperar a que cargue: la suma debe verse con lo guardado.
        final cart = container.read(cartProvider.notifier);
        await cart.addLine(1, 3);
        expect(container.read(cartProvider).lines.single.quantity, 5);
      },
    );
  });

  group('TC-037/TC-038/TC-039 · reglas aplicadas por el controlador', () {
    test(
      'AC-029-5 · añadir otra vez suma y se acota a 99 informándolo',
      () async {
        final container = _container();
        final cart = await loadedCart(container);
        await cart.addLine(1, 98);
        final result = await cart.addLine(1, 5);
        expect(result, isA<CartAdded>());
        final added = result as CartAdded;
        expect(added.merged, isTrue);
        expect(added.clamped, isTrue);
        expect(container.read(cartProvider).lines, hasLength(1));
        expect(container.read(cartProvider).lines.single.quantity, 99);
      },
    );

    test('AC-029-6 · la línea 101 se rechaza con el código del tope', () async {
      final store = MemoryDurableStore();
      final container = _container(store: store);
      final cart = await loadedCart(container);
      for (var i = 1; i <= 100; i++) {
        await cart.addLine(i, 1);
      }
      final result = await cart.add(500, 1);
      expect(result, isA<Err<void>>());
      expect((result.failureOrNull! as Validation).code, 'cart_line_limit');
      expect(container.read(cartProvider).lines, hasLength(100));
      expect(_stored(store).lineCount, 100);
    });

    test(
      'rechazos: cantidad inválida, id inválido y producto no comprable',
      () async {
        final container = _container();
        final cart = await loadedCart(container);
        final zero = await cart.add(1, 0);
        expect(
          (zero.failureOrNull! as Validation).code,
          'cart_invalid_quantity',
        );
        final badId = await cart.add(0, 1);
        expect(
          (badId.failureOrNull! as Validation).code,
          'cart_invalid_product',
        );
        final backorder = await cart.add(
          3,
          1,
          snapshot: productOf(id: 3, stock: StockStatus.onBackorder),
        );
        expect(
          (backorder.failureOrNull! as Validation).code,
          'cart_not_purchasable',
        );
        final noPrice = await cart.add(
          4,
          1,
          snapshot: productOf(id: 4, price: const OnRequest()),
        );
        expect(
          (noPrice.failureOrNull! as Validation).code,
          'cart_not_purchasable',
        );
        expect(container.read(cartProvider).isEmpty, isTrue);
      },
    );

    test('cartRejectionCode cubre todos los motivos', () {
      expect(
        {for (final r in CartRejection.values) r: cartRejectionCode(r)},
        {
          CartRejection.invalidProduct: 'cart_invalid_product',
          CartRejection.invalidQuantity: 'cart_invalid_quantity',
          CartRejection.lineLimit: 'cart_line_limit',
          CartRejection.notPurchasable: 'cart_not_purchasable',
        },
      );
    });

    test(
      'AC-049-2 · bajar a 0 o subir a 100 se corrige; la línea no se quita',
      () async {
        final container = _container();
        final cart = await loadedCart(container);
        await cart.addLine(1, 1);
        await cart.setQuantity(1, 0);
        expect(container.read(cartProvider).lines.single.quantity, 1);
        await cart.setQuantity(1, 100);
        expect(container.read(cartProvider).lines.single.quantity, 99);
        await cart.setQuantity(1, 7);
        expect(container.read(cartProvider).lines.single.quantity, 7);
      },
    );
  });

  group('TC-040 · AC-049-4 · persistencia', () {
    test(
      'al reabrir (otro contenedor) las 3 líneas siguen idénticas',
      () async {
        final store = MemoryDurableStore();
        final first = _container(store: store);
        final cart = await loadedCart(first);
        await cart.addLine(1, 2, snapshot: productOf(id: 1, name: 'Uno'));
        await cart.addLine(2, 5, snapshot: productOf(id: 2, name: 'Dos'));
        await cart.addLine(3, 99, snapshot: productOf(id: 3, name: 'Tres'));
        final before = first.read(cartProvider).lines;

        final second = _container(store: store);
        await loadedCart(second);
        expect(second.read(cartProvider).lines, before);
        expect(second.read(cartProvider).validation, isNull);
      },
    );

    test('se guarda tras cada cambio', () async {
      final store = MemoryDurableStore();
      final container = _container(store: store);
      final cart = await loadedCart(container);
      await cart.addLine(1, 1);
      expect(_stored(store).lineCount, 1);
      await cart.setQuantity(1, 4);
      expect(_stored(store).lines.single.quantity, 4);
      await cart.addLine(2, 1);
      await cart.remove(1);
      expect([for (final l in _stored(store).lines) l.productId], [2]);
      final removed = lineOf(9, 2);
      await cart.restoreLine(removed, 0);
      expect(_stored(store).lines.first.productId, 9);
      await cart.clear();
      expect(store.data, isEmpty);
    });

    test(
      'datos corruptos en disco → carrito vacío y sigue funcionando',
      () async {
        final store = MemoryDurableStore({
          CartStorageCodec.storageKey: '{"v":1,"lines":[{"productId":',
        });
        final container = _container(store: store);
        final cart = await loadedCart(container);
        expect(container.read(cartProvider).isEmpty, isTrue);
        await cart.addLine(1, 1);
        expect(_stored(store).lineCount, 1);
      },
    );

    test('un disco que falla al leer o escribir no tumba el carrito', () async {
      final broken = ProviderContainer(
        overrides: cartOverrides(
          durable: const BrokenDurableStore(failRead: true, failWrite: true),
        ),
      );
      addTearDown(broken.dispose);
      final cart = await loadedCart(broken);
      expect(broken.read(cartProvider).isEmpty, isTrue);
      await cart.addLine(1, 2);
      expect(broken.read(cartProvider).lines.single.quantity, 2);
    });
  });

  group('TC-041 · AC-049-5 · quitar y deshacer', () {
    test(
      'quitar baja la insignia (cartUnitCountProvider) y el contador',
      () async {
        final container = _container();
        final cart = await loadedCart(container);
        await cart.addLine(1, 2);
        await cart.addLine(2, 3);
        expect(container.read(cartUnitCountProvider), 5);
        await cart.remove(1);
        expect(container.read(cartUnitCountProvider), 3);
        expect(container.read(cartProvider).lines.single.productId, 2);
        await cart.remove(99);
        expect(container.read(cartUnitCountProvider), 3);
      },
    );

    test('restoreLine devuelve la línea a su sitio', () async {
      final container = _container();
      final cart = await loadedCart(container);
      await cart.addLine(1, 2);
      await cart.addLine(2, 3);
      await cart.addLine(3, 1);
      final line = container.read(cartProvider).lines[1];
      await cart.remove(2);
      await cart.restoreLine(line, 1);
      expect(
        [for (final l in container.read(cartProvider).lines) l.productId],
        [1, 2, 3],
      );
      // Restaurar dos veces no duplica.
      await cart.restoreLine(line, 1);
      expect(container.read(cartProvider).lines, hasLength(3));
    });

    test('clear() vacía todo (lo usa checkout al confirmar paid)', () async {
      final validation = FakeCartValidationRepository([
        Ok(cartFixture('CartValidation.all-available.json')),
      ]);
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      await cart.addLine(4521, 1);
      await cart.revalidate();
      expect(container.read(cartProvider).validation, isNotNull);
      await cart.clear();
      final state = container.read(cartProvider);
      expect(state.isEmpty, isTrue);
      expect(state.validation, isNull);
      expect(state.changes, isEmpty);
      expect(state.validationFailure, isNull);
    });
  });

  group('TC-043 · AC-049-9 · el carrito no se sincroniza con el servidor', () {
    test('añadir, cambiar, quitar, vaciar y cerrar sesión no emiten ninguna petición', () async {
      final adapter = FakeHttpAdapter();
      final client = buildTestClient(adapter: adapter).client;
      final container = ProviderContainer(
        overrides: cartOverrides(
          extra: [apiClientProvider.overrideWithValue(client)],
        ),
      );
      addTearDown(container.dispose);
      final cart = await loadedCart(container);
      await cart.addLine(1, 2);
      await cart.addLine(2, 1);
      await cart.setQuantity(1, 3);
      await cart.remove(2);
      await container.read(cartSessionHookProvider).onLogout();
      expect(container.read(cartProvider).lines.single.quantity, 3);
      await cart.clear();
      expect(adapter.requests, isEmpty);
    });
  });

  group(
    'DN-10 · H-07 · CR-040 · cerrar sesión, expirar y eliminar la cuenta',
    () {
      test('cerrar sesión CONSERVA el carrito (H-07 pendiente)', () async {
        final store = MemoryDurableStore();
        final container = _container(store: store);
        final cart = await loadedCart(container);
        await cart.addLine(1, 2);
        await container.read(cartSessionHookProvider).onLogout();
        expect(container.read(cartProvider).lines.single.quantity, 2);
        expect(_stored(store).lineCount, 1);
      });

      test('eliminar la cuenta BORRA el carrito (CR-040)', () async {
        final store = MemoryDurableStore();
        final container = _container(store: store);
        final cart = await loadedCart(container);
        await cart.addLine(1, 2);
        await container.read(cartSessionHookProvider).onAccountDeleted();
        expect(container.read(cartProvider).isEmpty, isTrue);
        expect(store.data, isEmpty);
      });

      test(
        'el gancho obedece a la política (único punto de decisión)',
        () async {
          var clears = 0;
          Future<void> clear() async => clears++;
          const keepAll = CartRetentionPolicy(clearOnAccountDeleted: false);
          const dropAll = CartRetentionPolicy(clearOnLogout: true);

          await CartSessionHook(clear: clear).onLogout();
          expect(clears, 0);
          await CartSessionHook(clear: clear).onAccountDeleted();
          expect(clears, 1);
          await CartSessionHook(
            clear: clear,
            policy: keepAll,
          ).onAccountDeleted();
          expect(clears, 1);
          await CartSessionHook(clear: clear, policy: dropAll).onLogout();
          expect(clears, 2);
        },
      );

      test('el gancho es un SessionHook listo para sessionHooksProvider', () {
        final container = _container();
        expect(container.read(cartSessionHookProvider), isA<SessionHook>());
      });
    },
  );

  group('TC-044/TC-045 · AC-050-1/AC-050-2 · revalidación', () {
    test(
      'envía el carrito, guarda la validación y reemplaza las instantáneas',
      () async {
        final validation = FakeCartValidationRepository([
          Ok(cartFixture('CartValidation.all-available.json')),
        ]);
        final store = MemoryDurableStore();
        final container = _container(store: store, validation: validation);
        final cart = await loadedCart(container);
        await cart.addLine(4521, 1, snapshot: productOf(name: 'Nombre viejo'));
        await cart.addLine(4522, 1, snapshot: productOf(id: 4522, name: 'X'));

        final result = await cart.revalidate();

        expect(result, isA<Ok<CartValidation>>());
        expect(validation.calls, hasLength(1));
        expect(
          [for (final l in validation.calls.single.lines) l.productId],
          [4521, 4522],
        );
        final state = container.read(cartProvider);
        expect(state.validation!.checkoutAllowed, isTrue);
        expect(state.revalidating, isFalse);
        expect(state.validationFailure, isNull);
        // La instantánea ahora es la del servidor (y se guardó).
        expect(
          state.lines.first.snapshot!.name,
          'Compresor scroll 24.000 BTU R410A',
        );
        expect(
          _stored(store).lines.first.snapshot!.name,
          'Compresor scroll 24.000 BTU R410A',
        );
      },
    );

    test(
      'AC-050-2 · informa precio anterior y nuevo; hay que aceptar para pagar',
      () async {
        final validation = FakeCartValidationRepository([
          Ok(cartFixture('CartValidation.price-changed.json')),
          Ok(cartFixture('CartValidation.price-changed.json')),
        ]);
        final container = _container(validation: validation);
        final cart = await loadedCart(container);
        await cart.addLine(4521, 1, snapshot: productOf(name: 'Compresor'));

        await cart.revalidate();
        var change = container.read(cartProvider).changes[4521]!;
        expect(change.previousPrice, const Priced(Money(100000)));
        expect(change.currentPrice, const Priced(Money(110000)));
        expect(
          container.read(cartReadinessProvider),
          CartReadiness.pendingChanges,
        );

        // Otra revalidación (previa al pago) no borra el aviso sin aceptar.
        await cart.revalidate();
        change = container.read(cartProvider).changes[4521]!;
        expect(change.previousPrice, const Priced(Money(100000)));

        cart.acceptChanges();
        expect(container.read(cartProvider).changes, isEmpty);
        expect(container.read(cartReadinessProvider), CartReadiness.ready);
      },
    );

    test('acceptChanges(id) acepta solo esa línea', () async {
      final validation = FakeCartValidationRepository([
        Ok(
          validationOf([
            availableLine(1, 1, price: 200000),
            availableLine(2, 1, price: 300000),
          ]),
        ),
      ]);
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      await cart.addLine(1, 1, snapshot: productOf(id: 1));
      await cart.addLine(2, 1, snapshot: productOf(id: 2));
      await cart.revalidate();
      expect(container.read(cartProvider).changes.keys, [1, 2]);
      expect(container.read(cartOverviewProvider).pendingAcknowledgements, [
        1,
        2,
      ]);
      cart.acceptChanges(1);
      expect(container.read(cartProvider).changes.keys, [2]);
      cart.acceptChanges();
      expect(container.read(cartProvider).changes, isEmpty);
    });

    test(
      'AC-050-8 · lo que se muestra viene del servidor, no de lo guardado',
      () async {
        final validation = FakeCartValidationRepository([
          Ok(cartFixture('CartValidation.price-changed.json')),
        ]);
        final container = _container(validation: validation);
        final cart = await loadedCart(container);
        await cart.addLine(
          4521,
          1,
          snapshot: productOf(price: const Priced(Money(1))),
        );
        await cart.revalidate();
        final view = container.read(cartOverviewProvider).lines.single;
        expect(view.unitPrice, const Priced(Money(110000)));
        expect(
          container.read(cartOverviewProvider).subtotal.amount,
          const Money(110000),
        );
      },
    );

    test('revalidar un carrito vacío no genera petición', () async {
      final validation = FakeCartValidationRepository([failureOffline]);
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      final result = await cart.revalidate();
      expect(result, isA<Ok<CartValidation>>());
      expect(validation.calls, isEmpty);
      expect(container.read(cartProvider).validation, isNull);
    });

    test(
      'dos revalidaciones simultáneas comparten una sola petición',
      () async {
        final validation = FakeCartValidationRepository([
          Ok(cartFixture('CartValidation.all-available.json')),
        ])..gate = Completer<void>();
        final container = _container(validation: validation);
        final cart = await loadedCart(container);
        await cart.addLine(4521, 1);
        final a = cart.revalidate();
        final b = cart.revalidate();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(cartProvider).revalidating, isTrue);
        validation.gate!.complete();
        await Future.wait([a, b]);
        expect(validation.calls, hasLength(1));
        expect(container.read(cartProvider).revalidating, isFalse);
      },
    );

    test(
      'lo que cambió durante la espera no se pierde ni se resucita',
      () async {
        final validation = FakeCartValidationRepository([
          Ok(cartFixture('CartValidation.all-available.json')),
        ])..gate = Completer<void>();
        final container = _container(validation: validation);
        final cart = await loadedCart(container);
        await cart.addLine(4521, 1);
        await cart.addLine(4522, 1);
        final pending = cart.revalidate();
        await Future<void>.delayed(Duration.zero);

        await cart.remove(4522);
        await cart.setQuantity(4521, 5);
        validation.gate!.complete();
        await pending;

        final state = container.read(cartProvider);
        expect([for (final l in state.lines) l.productId], [4521]);
        expect(state.lines.single.quantity, 5);
        // La cantidad cambió después de validar: hay que volver a verificar.
        expect(container.read(cartReadinessProvider), CartReadiness.unverified);
      },
    );

    test('una respuesta anterior a clear() no resucita datos', () async {
      final validation = FakeCartValidationRepository([
        Ok(cartFixture('CartValidation.all-available.json')),
      ])..gate = Completer<void>();
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      await cart.addLine(4521, 1);
      final pending = cart.revalidate();
      await Future<void>.delayed(Duration.zero);
      await cart.clear();
      validation.gate!.complete();
      await pending;
      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(container.read(cartProvider).validation, isNull);
    });
  });

  group('TC-046..TC-048 · AC-050-3..6 · líneas no disponibles', () {
    Future<(ProviderContainer, CartController, FakeCartValidationRepository)>
    setUpMixed() async {
      final validation = FakeCartValidationRepository([
        Ok(cartFixture('CartValidation.mixed.json')),
        Ok(validationOf([availableLine(4521, 2)], subtotal: 200000)),
      ]);
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      await cart.addLine(4521, 2, snapshot: productOf(name: 'Compresor'));
      await cart.addLine(
        4533,
        1,
        snapshot: productOf(
          id: 4533,
          name: 'Cap',
          price: const Priced(Money(89900)),
        ),
      );
      await cart.addLine(
        4540,
        1,
        snapshot: productOf(
          id: 4540,
          name: 'Val',
          price: const Priced(Money(350000)),
        ),
      );
      await cart.addLine(
        4551,
        3,
        snapshot: productOf(
          id: 4551,
          name: 'Tar',
          price: const Priced(Money(20000)),
        ),
      );
      await cart.addLine(9999, 1);
      return (container, cart, validation);
    }

    test('las 5 situaciones: ninguna línea se borra sola y "Pagar" queda bloqueado', () async {
      final (container, cart, _) = await setUpMixed();
      await cart.revalidate();
      final overview = container.read(cartOverviewProvider);
      expect(overview.lines, hasLength(5));
      expect(overview.blockingLines.map((v) => v.productId), [
        4533,
        4540,
        4551,
        9999,
      ]);
      expect(container.read(cartReadinessProvider), CartReadiness.blockedLines);
      expect(container.read(cartProvider).lines, hasLength(5));
    });

    test('AC-050-4 · quitar las no disponibles habilita "Pagar" tras volver a verificar', () async {
      final (container, cart, validation) = await setUpMixed();
      await cart.revalidate();
      await cart.removeUnavailable();
      expect(
        [for (final l in container.read(cartProvider).lines) l.productId],
        [4521],
      );
      // El "no" viejo del servidor pudo deberse a lo quitado: se vuelve a
      // preguntar (segunda petición) y entonces se habilita.
      await Future<void>.delayed(Duration.zero);
      expect(validation.calls, hasLength(2));
      expect(container.read(cartReadinessProvider), CartReadiness.ready);
    });

    test(
      'quitar una sola línea bloqueante también refresca el permiso',
      () async {
        final (container, cart, validation) = await setUpMixed();
        await cart.revalidate();
        await cart.remove(4533);
        await Future<void>.delayed(Duration.zero);
        expect(validation.calls, hasLength(2));
        expect(container.read(cartProvider).lines, hasLength(4));
      },
    );

    test('removeUnavailable sin líneas bloqueantes no hace nada', () async {
      final validation = FakeCartValidationRepository([
        Ok(cartFixture('CartValidation.all-available.json')),
      ]);
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      await cart.addLine(4521, 1);
      await cart.addLine(4522, 1);
      await cart.revalidate();
      await cart.removeUnavailable();
      expect(container.read(cartProvider).lines, hasLength(2));
      expect(validation.calls, hasLength(1));
    });

    test('CR-017 · una línea "bajo pedido" no es comprable', () async {
      final (container, cart, _) = await setUpMixed();
      await cart.revalidate();
      final view = container
          .read(cartOverviewProvider)
          .lines
          .firstWhere((v) => v.productId == 4540);
      expect(view.status, CartLineStatus.onBackorder);
      expect(view.isBlocking, isTrue);
      expect(view.lineSubtotal, isNull);
    });

    test(
      'AC-050-5 · precio 0 / sin precio: nunca "cero pesos" en la línea',
      () async {
        final (container, cart, _) = await setUpMixed();
        await cart.revalidate();
        final view = container
            .read(cartOverviewProvider)
            .lines
            .firstWhere((v) => v.productId == 4551);
        expect(view.status, CartLineStatus.priceOnRequest);
        expect(view.unitPrice, isA<OnRequest>());
        expect(view.lineSubtotal, isNull);
      },
    );

    test('AC-050-6 · not_found conserva la línea', () async {
      final (container, cart, _) = await setUpMixed();
      await cart.revalidate();
      expect(
        container.read(cartProvider).lines.any((l) => l.productId == 9999),
        isTrue,
      );
    });
  });

  group('TC-049 · AC-050-7 · falla la revalidación', () {
    final failures = <String, Err<CartValidation>>{
      'sin red': failureOffline,
      '503': failureUnavailable,
      'tiempo agotado': const Err(RequestTimeout()),
      '500': const Err(ServerFailure()),
      'contrato': const Err(ContractFailure()),
    };
    for (final entry in failures.entries) {
      test(
        '${entry.key}: conserva las líneas, no marca cambios y bloquea el pago',
        () async {
          final store = MemoryDurableStore();
          final validation = FakeCartValidationRepository([entry.value]);
          final container = _container(store: store, validation: validation);
          final cart = await loadedCart(container);
          await cart.addLine(1, 2, snapshot: productOf(id: 1));
          await cart.addLine(2, 3, snapshot: productOf(id: 2));
          final before = container.read(cartProvider).lines;

          final result = await cart.revalidate();

          expect(result, isA<Err<CartValidation>>());
          final state = container.read(cartProvider);
          expect(state.lines, before);
          expect(state.validation, isNull);
          expect(state.changes, isEmpty);
          expect(state.validationFailure, entry.value.failure);
          expect(state.revalidating, isFalse);
          expect(_stored(store).lines, before);
          expect(
            container.read(cartReadinessProvider),
            CartReadiness.unverified,
          );
          expect(
            await cart.attemptCheckout(),
            CartCheckoutAttempt.verificationFailed,
          );
        },
      );
    }

    test('tras un éxito, un fallo posterior conserva la validación pero ya no autoriza', () async {
      final validation = FakeCartValidationRepository([
        Ok(cartFixture('CartValidation.all-available.json')),
        failureOffline,
        Ok(cartFixture('CartValidation.all-available.json')),
      ]);
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      await cart.addLine(4521, 1);
      await cart.addLine(4522, 1);
      await cart.revalidate();
      expect(container.read(cartReadinessProvider), CartReadiness.ready);

      await cart.revalidate();
      var state = container.read(cartProvider);
      expect(state.validation, isNotNull);
      expect(state.validationFailure, isA<NoConnection>());
      expect(container.read(cartReadinessProvider), CartReadiness.unverified);
      expect(state.changes, isEmpty);

      // "Reintentar" con la red restablecida: se recupera.
      await cart.revalidate();
      state = container.read(cartProvider);
      expect(state.validationFailure, isNull);
      expect(container.read(cartReadinessProvider), CartReadiness.ready);
    });

    test('los cambios pendientes sobreviven a un fallo', () async {
      final validation = FakeCartValidationRepository([
        Ok(cartFixture('CartValidation.price-changed.json')),
        failureUnavailable,
      ]);
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      await cart.addLine(4521, 1, snapshot: productOf(name: 'C'));
      await cart.revalidate();
      await cart.revalidate();
      expect(container.read(cartProvider).changes[4521], isNotNull);
    });
  });

  group('RF-050 · RF-052 · attemptCheckout ("Pagar")', () {
    test('todo verificado → proceed, y siempre revalida primero', () async {
      final validation = FakeCartValidationRepository([
        Ok(cartFixture('CartValidation.all-available.json')),
      ]);
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      await cart.addLine(4521, 1);
      await cart.addLine(4522, 1);
      expect(await cart.attemptCheckout(), CartCheckoutAttempt.proceed);
      expect(validation.calls, hasLength(1));
    });

    test('hay líneas no disponibles → blocked', () async {
      final validation = FakeCartValidationRepository([
        Ok(cartFixture('CartValidation.mixed.json')),
      ]);
      final container = _container(validation: validation);
      final cart = await loadedCart(container);
      await cart.addLine(4521, 2);
      await cart.addLine(4533, 1);
      expect(await cart.attemptCheckout(), CartCheckoutAttempt.blocked);
    });

    test(
      'checkoutEnabled apagado → blocked aunque todo esté bien (falla cerrado)',
      () async {
        final validation = FakeCartValidationRepository([
          Ok(cartFixture('CartValidation.all-available.json')),
        ]);
        final container = _container(
          validation: validation,
          checkoutEnabled: false,
        );
        final cart = await loadedCart(container);
        await cart.addLine(4521, 1);
        await cart.addLine(4522, 1);
        expect(
          container.read(cartReadinessProvider),
          CartReadiness.checkoutDisabled,
        );
        expect(await cart.attemptCheckout(), CartCheckoutAttempt.blocked);
      },
    );

    test('carrito vacío → blocked', () async {
      final container = _container(
        validation: FakeCartValidationRepository([failureOffline]),
      );
      final cart = await loadedCart(container);
      expect(container.read(cartReadinessProvider), CartReadiness.empty);
      expect(await cart.attemptCheckout(), CartCheckoutAttempt.blocked);
    });

    test(
      'un cambio de precio en la revalidación previa al pago bloquea',
      () async {
        final validation = FakeCartValidationRepository([
          Ok(cartFixture('CartValidation.price-changed.json')),
        ]);
        final container = _container(validation: validation);
        final cart = await loadedCart(container);
        await cart.addLine(4521, 1, snapshot: productOf());
        expect(await cart.attemptCheckout(), CartCheckoutAttempt.blocked);
        expect(
          container.read(cartReadinessProvider),
          CartReadiness.pendingChanges,
        );
      },
    );
  });

  group('CartState', () {
    test('valores por defecto y derivados', () {
      const state = CartState();
      expect(state.isEmpty, isTrue);
      expect(state.unitCount, 0);
      expect(state.loaded, isTrue);
      expect(state.cart.isEmpty, isTrue);
    });

    test('copyWith conserva lo no indicado y permite limpiar', () {
      final state = CartState(
        lines: [lineOf(1, 2)],
        validation: validationOf([availableLine(1, 2)]),
        validationFailure: const NoConnection(),
        validatedFor: const {1: 2},
      );
      expect(state.copyWith(revalidating: true).validation, isNotNull);
      expect(state.copyWith(revalidating: true).lines, state.lines);
      final cleared = state.copyWith(clearValidation: true, clearFailure: true);
      expect(cleared.validation, isNull);
      expect(cleared.validatedFor, isNull);
      expect(cleared.validationFailure, isNull);
      expect(state.unitCount, 2);
    });
  });
}

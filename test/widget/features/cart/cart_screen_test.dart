import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'cart_harness.dart';

FakeCartValidationRepository _repo(List<Result<CartValidation>> results) =>
    FakeCartValidationRepository(results);

Result<CartValidation> _ok(String fixture) => Ok(cartFixture(fixture));

void main() {
  group('TC-041 · AC-049-6 · estado vacío y carga', () {
    testWidgets(
      'carrito vacío: explica, ofrece "Explorar catálogo" y no hay "Pagar"',
      (tester) async {
        final validation = _repo([failureOffline]);
        await pumpCart(tester, validation: validation);
        expect(find.text('Carrito'), findsOneWidget);
        expect(find.text('Tu carrito está vacío'), findsOneWidget);
        expect(find.text('Explorar catálogo'), findsOneWidget);
        expect(payButton, findsNothing);
        expect(find.text('Subtotal informativo (IVA incluido)'), findsNothing);
        // Nada que revalidar.
        expect(validation.calls, isEmpty);
      },
    );

    testWidgets('"Explorar catálogo" lleva al catálogo', (tester) async {
      final env = await pumpCart(tester, validation: _repo([failureOffline]));
      await tester.tap(find.text('Explorar catálogo'));
      await tester.pumpAndSettle();
      expect(destination('/catalog'), findsOneWidget);
      expect(env.location, '/catalog');
    });

    testWidgets('mientras se lee el almacén muestra "Cargando"', (
      tester,
    ) async {
      final gated = GatedDurableStore(MemoryDurableStore());
      await pumpCart(
        tester,
        durable: gated,
        validation: _repo([failureOffline]),
        settle: false,
      );
      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.text('Tu carrito está vacío'), findsNothing);
      gated.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LoadingState), findsNothing);
      expect(find.text('Tu carrito está vacío'), findsOneWidget);
    });
  });

  group('TC-036 · AC-049-1 · AC-029-7 · las líneas del carrito', () {
    testWidgets(
      'muestra nombre, SKU, cantidad y los controles de cantidad y quitar',
      (tester) async {
        await pumpCart(
          tester,
          lines: [lineOf(1, 3, name: 'Compresor')],
          validation: _repo([failureOffline]),
        );
        expect(find.text('Compresor'), findsOneWidget);
        expect(find.text('SKU SKU-1'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(
          find.byTooltip('Aumentar cantidad de Compresor'),
          findsOneWidget,
        );
        expect(
          find.byTooltip('Disminuir cantidad de Compresor'),
          findsOneWidget,
        );
        expect(find.byTooltip('Quitar Compresor del carrito'), findsOneWidget);
      },
    );

    testWidgets(
      'un invitado (sin ninguna sesión) ve el carrito y su resumen completo',
      (tester) async {
        await pumpCart(
          tester,
          lines: [lineOf(1, 1)],
          validation: _repo([_ok('CartValidation.all-available.json')]),
        );
        expect(
          find.text('Subtotal informativo (IVA incluido)'),
          findsOneWidget,
        );
        expect(payButton, findsOneWidget);
        expect(find.text('Iniciar sesión'), findsNothing);
      },
    );

    testWidgets('una línea sin nombre guardado se muestra por referencia', (
      tester,
    ) async {
      await pumpCart(
        tester,
        lines: const [CartLine(productId: 77, quantity: 1)],
        validation: _repo([failureOffline]),
      );
      expect(find.text('Producto (ref. 77)'), findsOneWidget);
    });
  });

  group('RF-049 · cantidad y quitar', () {
    testWidgets('+ y − cambian la cantidad y el subtotal; se guarda en disco', (
      tester,
    ) async {
      final env = await pumpCart(
        tester,
        lines: [lineOf(1, 2)],
        validation: _repo([
          Ok(validationOf([availableLine(1, 2)])),
        ]),
      );
      expect(find.text(r'$ 200.000'), findsWidgets);
      await tester.tap(find.byTooltip('Aumentar cantidad de Producto 1'));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(env.state.lines.single.quantity, 3);
      expect(env.stored.lines.single.quantity, 3);
      // Subtotal recalculado con el precio del servidor.
      expect(find.text(r'$ 300.000'), findsWidgets);

      await tester.tap(find.byTooltip('Disminuir cantidad de Producto 1'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('AC-049-2 · en 1 no se puede bajar y la línea no desaparece', (
      tester,
    ) async {
      final env = await pumpCart(
        tester,
        lines: [lineOf(1, 1)],
        validation: _repo([failureOffline]),
      );
      final minus = find.ancestor(
        of: find.byTooltip('Disminuir cantidad de Producto 1'),
        matching: find.bySubtype<IconButton>(),
      );
      expect(tester.widget<IconButton>(minus).onPressed, isNull);
      expect(env.state.lines, hasLength(1));
    });

    testWidgets('AC-049-2 · en 99 no se puede subir y avisa del máximo', (
      tester,
    ) async {
      await pumpCart(
        tester,
        lines: [lineOf(1, 99)],
        validation: _repo([failureOffline]),
      );
      final plus = find.ancestor(
        of: find.byTooltip('Aumentar cantidad de Producto 1'),
        matching: find.bySubtype<IconButton>(),
      );
      expect(tester.widget<IconButton>(plus).onPressed, isNull);
      expect(
        find.text(
          'Máximo 99 unidades por producto. Para más, habla con un asesor.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('el cambio de cantidad se anuncia (región viva con etiqueta)', (
      tester,
    ) async {
      final handle = ensureSemantics(tester);
      await pumpCart(
        tester,
        lines: [lineOf(1, 4)],
        validation: _repo([failureOffline]),
      );
      expect(
        find.bySemanticsLabel('Cantidad de Producto 1: 4'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Aumentar cantidad de Producto 1'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Cantidad de Producto 1: 5'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'AC-049-5 · quitar la línea la elimina, baja la insignia y actualiza el subtotal',
      (tester) async {
        final env = await pumpCart(
          tester,
          lines: [lineOf(1, 2), lineOf(2, 1, price: 50000)],
          validation: _repo([
            Ok(
              validationOf([
                availableLine(1, 2),
                availableLine(2, 1, price: 50000),
              ]),
            ),
          ]),
        );
        expect(env.state.unitCount, 3);
        expect(find.text(r'$ 250.000'), findsWidgets);

        await tester.tap(find.byTooltip('Quitar Producto 1 del carrito'));
        await tester.pumpAndSettle();

        expect(find.text('Producto 1'), findsNothing);
        expect(env.state.unitCount, 1);
        expect(env.stored.lineCount, 1);
        expect(find.text(r'$ 50.000'), findsWidgets);
        expect(find.text(r'$ 250.000'), findsNothing);
      },
    );

    testWidgets(
      'quitar muestra un aviso breve con "Deshacer" que devuelve la línea a su sitio',
      (tester) async {
        final env = await pumpCart(
          tester,
          lines: [lineOf(1, 2), lineOf(2, 1), lineOf(3, 4)],
          validation: _repo([failureOffline]),
        );
        await tester.tap(find.byTooltip('Quitar Producto 2 del carrito'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));
        expect(find.text('Quitaste Producto 2 del carrito'), findsOneWidget);
        expect(find.text('Deshacer'), findsOneWidget);
        expect(env.state.lines.map((l) => l.productId), [1, 3]);

        await tester.tap(find.text('Deshacer'));
        await tester.pumpAndSettle();
        expect(env.state.lines.map((l) => l.productId), [1, 2, 3]);
        expect(env.state.lines[1].quantity, 1);
        expect(env.stored.lineCount, 3);
      },
    );

    testWidgets(
      'al quitar la última línea aparece el estado vacío sin "Pagar"',
      (tester) async {
        await pumpCart(
          tester,
          lines: [lineOf(1, 1)],
          validation: _repo([failureOffline]),
        );
        await tester.tap(find.byTooltip('Quitar Producto 1 del carrito'));
        await tester.pumpAndSettle();
        expect(find.text('Tu carrito está vacío'), findsOneWidget);
        expect(payButton, findsNothing);
      },
    );
  });

  group('TC-044 · AC-050-1 · revalidación al abrir', () {
    testWidgets(
      'al abrir consulta al servidor y muestra un indicador mientras tanto',
      (tester) async {
        final validation = _repo([_ok('CartValidation.all-available.json')])
          ..gate = Completer<void>();
        await pumpCart(
          tester,
          lines: [lineOf(4521, 1), lineOf(4522, 1, price: 50000)],
          validation: validation,
          settle: false,
        );
        await tester.pump();
        await tester.pump();
        expect(validation.calls, hasLength(1));
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('Verificando…'), findsOneWidget);

        validation.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.text('Pagar'), findsOneWidget);
      },
    );

    testWidgets('al volver a activarse la pestaña vuelve a revalidar', (
      tester,
    ) async {
      final validation = _repo([_ok('CartValidation.all-available.json')]);
      final active = ValueNotifier<bool>(false);
      addTearDown(active.dispose);
      await pumpCart(
        tester,
        lines: [lineOf(4521, 1)],
        validation: validation,
        tabActive: active,
      );
      // Pestaña inactiva (pila indexada): no consulta.
      expect(validation.calls, isEmpty);
      active.value = true;
      await tester.pumpAndSettle();
      expect(validation.calls, hasLength(1));
      // Sigue activa: reconstruir no repite la consulta.
      await tester.pumpAndSettle();
      expect(validation.calls, hasLength(1));
      active.value = false;
      await tester.pumpAndSettle();
      active.value = true;
      await tester.pumpAndSettle();
      expect(validation.calls, hasLength(2));
    });
  });

  group('TC-050 · AC-051-1/2/3/5 · resumen y subtotal informativo', () {
    testWidgets(
      'subtotal 150.000 rotulado "informativo" e "IVA incluido", con el aviso del pago',
      (tester) async {
        await pumpCart(
          tester,
          lines: [lineOf(4521, 1), lineOf(4522, 1, price: 50000)],
          validation: _repo([_ok('CartValidation.all-available.json')]),
        );
        expect(
          find.text('Subtotal informativo (IVA incluido)'),
          findsOneWidget,
        );
        expect(find.text(r'$ 150.000'), findsOneWidget);
        expect(
          find.text(
            'Los impuestos, el envío (lo eliges en el pago según la transportadora) y el total final se confirman en el pago.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('no presenta "Total a pagar" ni un envío calculado', (
      tester,
    ) async {
      await pumpCart(
        tester,
        lines: [lineOf(4521, 1), lineOf(4522, 1, price: 50000)],
        validation: _repo([_ok('CartValidation.all-available.json')]),
      );
      final text = allText(tester).toLowerCase();
      expect(text.contains('total a pagar'), isFalse);
      expect(text.contains('costo de envío'), isFalse);
      expect(text.contains('flete'), isFalse);
      expect(text.contains('iva:'), isFalse);
    });

    testWidgets(r'el ítem sin precio no suma ni se muestra como "$ 0"', (
      tester,
    ) async {
      await pumpCart(
        tester,
        lines: [
          lineOf(4521, 1),
          lineOf(4522, 1, price: 50000),
          lineOf(4551, 3, price: 0),
        ],
        validation: _repo([
          Ok(
            validationOf([
              availableLine(4521, 1),
              availableLine(4522, 1, price: 50000),
              const ValidatedCartLine(
                id: 4551,
                quantity: 3,
                status: CartLineStatus.priceOnRequest,
              ),
            ], subtotal: 150000),
          ),
        ]),
      );
      expect(find.text(r'$ 150.000'), findsOneWidget);
      expect(find.textContaining(r'$ 0'), findsNothing);
      expect(
        find.text('No incluye 1 producto sin precio o no disponible.'),
        findsOneWidget,
      );
    });

    testWidgets(
      r'sin ningún producto con precio dice "Sin subtotal", nunca "$ 0"',
      (tester) async {
        await pumpCart(
          tester,
          lines: [lineOf(1, 1, price: 0)],
          validation: _repo([failureOffline]),
        );
        expect(find.text('Sin subtotal'), findsOneWidget);
        expect(find.textContaining(r'$ 0'), findsNothing);
      },
    );

    testWidgets('datos sin verificar se rotulan como tales', (tester) async {
      await pumpCart(
        tester,
        lines: [lineOf(1, 1)],
        validation: _repo([failureOffline]),
      );
      expect(
        find.text('Precios sin verificar: se confirmarán antes de pagar.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'con datos verificados no aparece el rótulo de "sin verificar"',
      (tester) async {
        await pumpCart(
          tester,
          lines: [lineOf(4521, 1), lineOf(4522, 1, price: 50000)],
          validation: _repo([_ok('CartValidation.all-available.json')]),
        );
        expect(find.textContaining('sin verificar'), findsNothing);
      },
    );
  });

  group('TC-045 · AC-050-2 · cambio de precio', () {
    testWidgets(
      'muestra precio anterior y nuevo, bloquea "Pagar" hasta "Ajustar"',
      (tester) async {
        await pumpCart(
          tester,
          lines: [lineOf(4521, 1)],
          validation: _repo([_ok('CartValidation.price-changed.json')]),
        );
        expect(find.text('El precio de 1 producto cambió'), findsOneWidget);
        expect(
          find.text(r'Precio actualizado: antes $ 100.000, ahora $ 110.000'),
          findsOneWidget,
        );
        expect(isEnabled(tester, payButton), isFalse);
        expect(
          find.text('Acepta los cambios de precio (Ajustar) para continuar.'),
          findsOneWidget,
        );
        // El precio vigente es el del servidor.
        expect(find.text(r'$ 110.000'), findsWidgets);

        await tester.tap(find.text('Ajustar'));
        await tester.pumpAndSettle();
        expect(find.text('El precio de 1 producto cambió'), findsNothing);
        expect(isEnabled(tester, payButton), isTrue);
      },
    );
  });

  group('TC-046 · AC-050-3/4 · agotado bloquea el pago', () {
    Future<CartEnv> pumpWithOutOfStock(WidgetTester tester) => pumpCart(
      tester,
      lines: [lineOf(4521, 1), lineOf(4533, 1, price: 89900)],
      validation: _repo([
        Ok(
          validationOf([
            availableLine(4521, 1),
            ValidatedCartLine(
              id: 4533,
              quantity: 1,
              status: CartLineStatus.outOfStock,
              product: productOf(
                id: 4533,
                name: 'Capacitor',
                stock: StockStatus.outOfStock,
                price: const Priced(Money(89900)),
              ),
            ),
          ], checkoutAllowed: false),
        ),
        Ok(validationOf([availableLine(4521, 1)])),
      ]),
    );

    testWidgets(
      'marca "Agotado", deshabilita "Pagar" y no emite ninguna petición al tocarlo',
      (tester) async {
        final env = await pumpWithOutOfStock(tester);
        expect(find.text('Agotado: quítalo para poder pagar'), findsOneWidget);
        expect(
          find.text('Hay 1 producto que no se puede comprar'),
          findsOneWidget,
        );
        expect(isEnabled(tester, payButton), isFalse);
        expect(
          find.text(
            'Quita los productos que no se pueden comprar para continuar.',
          ),
          findsOneWidget,
        );
        await tester.tap(payButton, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(env.validation!.calls, hasLength(1));
        expect(destination('/checkout'), findsNothing);
      },
    );

    testWidgets('quitar la agotada (banner "Quitar") habilita "Pagar"', (
      tester,
    ) async {
      final env = await pumpWithOutOfStock(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Quitar'));
      await tester.pumpAndSettle();
      expect(env.state.lines.map((l) => l.productId), [4521]);
      expect(find.text('Hay 1 producto que no se puede comprar'), findsNothing);
      expect(isEnabled(tester, payButton), isTrue);
      expect(env.validation!.calls, hasLength(2));
    });

    testWidgets(
      'quitar la agotada con su propio botón también habilita "Pagar"',
      (tester) async {
        await pumpWithOutOfStock(tester);
        await tester.tap(find.byTooltip('Quitar Capacitor del carrito'));
        await tester.pumpAndSettle();
        expect(isEnabled(tester, payButton), isTrue);
      },
    );
  });

  group('TC-047/TC-048 · AC-050-5/6 · sin precio y no encontrado', () {
    testWidgets(
      'sin precio: marca, ofrece "Más información" y bloquea el pago',
      (tester) async {
        await pumpCart(
          tester,
          lines: [
            lineOf(4521, 1),
            lineOf(4551, 3, price: 0, name: 'Tarjeta'),
          ],
          validation: _repo([_ok('CartValidation.mixed.json')]),
        );
        expect(
          find.text('Sin precio: no se puede comprar en la app'),
          findsOneWidget,
        );
        expect(find.text('Más información'), findsOneWidget);
        expect(find.textContaining(r'$ 0'), findsNothing);
        expect(isEnabled(tester, payButton), isFalse);
      },
    );

    testWidgets('"Más información" abre WhatsApp con el nombre y el SKU', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      final validation = _repo([
        Ok(
          validationOf([
            ValidatedCartLine(
              id: 4551,
              quantity: 1,
              status: CartLineStatus.priceOnRequest,
              product: productOf(
                id: 4551,
                name: 'Tarjeta',
                sku: 'QA-0009',
                price: const OnRequest(),
              ),
            ),
          ]),
        ),
      ]);
      await pumpCart(
        tester,
        launcher: launcher,
        validation: validation,
        lines: [lineOf(4551, 1, price: 0, name: 'Tarjeta')],
      );
      await tester.tap(find.text('Más información'));
      await tester.pump();
      expect(launcher.opened.single.host, 'wa.me');
      expect(
        launcher.opened.single.queryParameters['text'],
        contains('Tarjeta'),
      );
      expect(
        launcher.opened.single.queryParameters['text'],
        contains('QA-0009'),
      );
    });

    testWidgets(
      'no encontrado: la línea se conserva y se marca no disponible',
      (tester) async {
        final env = await pumpCart(
          tester,
          lines: [
            lineOf(4521, 2),
            lineOf(9999, 1, name: 'Fantasma'),
          ],
          validation: _repo([_ok('CartValidation.mixed.json')]),
        );
        expect(find.text('Fantasma'), findsOneWidget);
        expect(find.text('Ya no está disponible'), findsOneWidget);
        expect(env.state.lines.any((l) => l.productId == 9999), isTrue);
        expect(isEnabled(tester, payButton), isFalse);
      },
    );

    testWidgets('CR-017 · bajo pedido no se puede comprar', (tester) async {
      await pumpCart(
        tester,
        lines: [
          lineOf(4521, 2),
          lineOf(4540, 1, name: 'Válvula'),
        ],
        validation: _repo([_ok('CartValidation.mixed.json')]),
      );
      expect(
        find.text('Bajo pedido: no se puede comprar en la app'),
        findsOneWidget,
      );
      expect(isEnabled(tester, payButton), isFalse);
    });
  });

  group(
    'TC-049 · TC-040 · AC-050-7 · fallo de la revalidación y sin conexión',
    () {
      testWidgets(
        'sin red: conserva y deja editar el carrito; el pago exige conexión y lo dice',
        (tester) async {
          final env = await pumpCart(
            tester,
            lines: [lineOf(1, 2), lineOf(2, 3)],
            validation: _repo([failureOffline]),
          );
          expect(find.text('Producto 1'), findsOneWidget);
          expect(find.text('Producto 2'), findsOneWidget);
          expect(
            find.textContaining('Para pagar necesitamos verificar precios'),
            findsOneWidget,
          );
          expect(
            find.text(
              'Mostrando información guardada; puede no estar actualizada.',
            ),
            findsOneWidget,
          );
          // Se puede editar sin conexión.
          await tester.tap(find.byTooltip('Aumentar cantidad de Producto 1'));
          await tester.pumpAndSettle();
          expect(env.state.lines.first.quantity, 3);

          // "Pagar" revalida; sin red avisa y no navega.
          await tester.tap(payButton);
          await tester.pumpAndSettle();
          expect(
            find.text('Para pagar necesitas conexión a internet.'),
            findsOneWidget,
          );
          expect(destination('/checkout'), findsNothing);
        },
      );

      testWidgets(
        '503: avisa "No pudimos verificar", conserva las líneas y ofrece "Reintentar"',
        (tester) async {
          final env = await pumpCart(
            tester,
            lines: [lineOf(4521, 1), lineOf(4522, 1, price: 50000)],
            validation: _repo([
              failureUnavailable,
              _ok('CartValidation.all-available.json'),
            ]),
          );
          expect(
            find.textContaining(
              'No pudimos verificar precios ni disponibilidad',
            ),
            findsOneWidget,
          );
          expect(env.state.lines, hasLength(2));
          expect(env.state.changes, isEmpty);
          expect(isEnabled(tester, payButton), isTrue); // se verifica al tocar

          await tester.tap(find.text('Reintentar'));
          await tester.pumpAndSettle();
          expect(find.textContaining('No pudimos verificar'), findsNothing);
          expect(find.text('Reintentar'), findsNothing);
          expect(
            find.text('Subtotal informativo (IVA incluido)'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'si el fallo no se puede reintentar no se ofrece "Reintentar"',
        (tester) async {
          await pumpCart(
            tester,
            lines: [lineOf(1, 1)],
            validation: _repo([const Err(ContractFailure())]),
          );
          expect(find.text('Reintentar'), findsNothing);
          expect(find.textContaining('No pudimos verificar'), findsOneWidget);
        },
      );

      testWidgets(
        '"Pagar" con fallo de servidor muestra el aviso general y no navega',
        (tester) async {
          await pumpCart(
            tester,
            lines: [lineOf(1, 1)],
            validation: _repo([failureUnavailable]),
          );
          await tester.tap(payButton);
          await tester.pumpAndSettle();
          expect(
            find.text('No pudimos verificar tu carrito. Intenta de nuevo.'),
            findsOneWidget,
          );
          expect(destination('/checkout'), findsNothing);
        },
      );

      testWidgets('recuperada la red, "Pagar" avanza al checkout', (
        tester,
      ) async {
        final validation = _repo([
          failureOffline,
          _ok('CartValidation.all-available.json'),
        ]);
        await pumpCart(
          tester,
          lines: [lineOf(4521, 1), lineOf(4522, 1, price: 50000)],
          validation: validation,
        );
        await tester.tap(payButton);
        await tester.pumpAndSettle();
        expect(destination('/checkout'), findsOneWidget);
        expect(validation.calls, hasLength(2));
      });
    },
  );

  group('RF-050 · RF-052 · botón "Pagar"', () {
    testWidgets(
      'todo verificado: revalida antes de ir y navega con push a /checkout',
      (tester) async {
        final validation = _repo([
          _ok('CartValidation.all-available.json'),
          _ok('CartValidation.all-available.json'),
        ]);
        final env = await pumpCart(
          tester,
          lines: [lineOf(4521, 1), lineOf(4522, 1, price: 50000)],
          validation: validation,
        );
        expect(isEnabled(tester, payButton), isTrue);
        await tester.tap(payButton);
        await tester.pumpAndSettle();
        expect(validation.calls, hasLength(2));
        expect(destination('/checkout'), findsOneWidget);
        // Con push, volver regresa al carrito (con sus líneas).
        env.router.pop();
        await tester.pumpAndSettle();
        expect(
          find.text('Subtotal informativo (IVA incluido)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'interruptor checkoutEnabled apagado: deshabilitado, con explicación (falla cerrado)',
      (tester) async {
        final validation = _repo([_ok('CartValidation.all-available.json')]);
        await pumpCart(
          tester,
          lines: [lineOf(4521, 1), lineOf(4522, 1, price: 50000)],
          validation: validation,
          checkoutEnabled: false,
        );
        expect(isEnabled(tester, payButton), isFalse);
        expect(
          find.text(
            'El pago en la app no está disponible por ahora. Inténtalo más tarde.',
          ),
          findsOneWidget,
        );
        await tester.tap(payButton, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(destination('/checkout'), findsNothing);
        expect(validation.calls, hasLength(1));
      },
    );

    testWidgets(
      'el servidor dice checkoutAllowed=false: "Pagar" queda bloqueado',
      (tester) async {
        await pumpCart(
          tester,
          lines: [lineOf(4521, 1)],
          validation: _repo([
            Ok(validationOf([availableLine(4521, 1)], checkoutAllowed: false)),
          ]),
        );
        expect(isEnabled(tester, payButton), isFalse);
        expect(
          find.textContaining('Por ahora no podemos continuar con el pago'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'una cantidad cambiada tras validar pide verificar de nuevo al tocar "Pagar"',
      (tester) async {
        final validation = _repo([
          Ok(validationOf([availableLine(4521, 1)])),
          Ok(validationOf([availableLine(4521, 2)])),
        ]);
        await pumpCart(
          tester,
          lines: [lineOf(4521, 1)],
          validation: validation,
        );
        await tester.tap(find.byTooltip('Aumentar cantidad de Producto 4521'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Antes de pagar verificaremos precios'),
          findsOneWidget,
        );
        await tester.tap(payButton);
        await tester.pumpAndSettle();
        expect(validation.calls, hasLength(2));
        expect(validation.calls.last.lines.single.quantity, 2);
        expect(destination('/checkout'), findsOneWidget);
      },
    );

    testWidgets(
      'un precio que cambió en la revalidación previa al pago bloquea y avisa',
      (tester) async {
        final validation = _repo([
          Ok(validationOf([availableLine(4521, 1)])),
          _ok('CartValidation.price-changed.json'),
        ]);
        await pumpCart(
          tester,
          lines: [lineOf(4521, 1)],
          validation: validation,
        );
        await tester.tap(payButton);
        await tester.pumpAndSettle();
        expect(destination('/checkout'), findsNothing);
        expect(
          find.text('Hay cambios en tu carrito. Revísalos antes de pagar.'),
          findsOneWidget,
        );
        expect(find.text('El precio de 1 producto cambió'), findsOneWidget);
      },
    );

    testWidgets('mientras verifica, "Pagar" queda ocupado y deshabilitado', (
      tester,
    ) async {
      final validation = _repo([
        Ok(validationOf([availableLine(4521, 1)])),
        Ok(validationOf([availableLine(4521, 1)])),
      ]);
      await pumpCart(tester, lines: [lineOf(4521, 1)], validation: validation);
      validation.gate = Completer<void>();
      await tester.tap(payButton);
      await tester.pump();
      await tester.pump();
      // Mientras verifica el botón está ocupado y deshabilitado.
      expect(find.text('Verificando…'), findsOneWidget);
      expect(isEnabled(tester, payButton), isFalse);
      validation.gate!.complete();
      await tester.pumpAndSettle();
      expect(validation.calls, hasLength(2));
      expect(destination('/checkout'), findsOneWidget);
    });
  });

  group('RF-049 · persistencia visible', () {
    testWidgets(
      'AC-049-4 · tras reabrir la app (otro árbol) las líneas siguen idénticas',
      (tester) async {
        final first = await pumpCart(
          tester,
          lines: [
            lineOf(1, 2, name: 'Uno'),
            lineOf(2, 5, name: 'Dos'),
            lineOf(3, 7, name: 'Tres'),
          ],
          validation: _repo([failureOffline]),
        );
        await tester.tap(find.byTooltip('Aumentar cantidad de Uno'));
        await tester.pumpAndSettle();
        final store = first.store;

        await tester.pumpWidget(const SizedBox());
        await pumpCart(
          tester,
          seed: store,
          validation: _repo([failureOffline]),
        );
        expect(find.text('Uno'), findsOneWidget);
        expect(find.text('Dos'), findsOneWidget);
        expect(find.text('Tres'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
      },
    );
  });
}

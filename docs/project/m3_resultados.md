# M3 — Carrito y compra · resultados

Fecha: 2026-11-20 · Rebanada PT-16: carrito local, revalidación, subtotal informativo, traspaso al
checkout seguro, retorno por enlace y resultado verificado (RF-029, RF-049..058).

Construida por 2 agentes en paralelo (`cart`, `checkout`); el orquestador añadió el almacén duradero
de `core`, conectó la ficha de producto, la insignia del carrito, las rutas y los ganchos de sesión.

## Evidencia ejecutada (Windows, Flutter 3.50.0)

| Puerta | Resultado |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | 351 archivos, 0 cambios |
| `flutter analyze --fatal-infos` | sin problemas |
| `dart run ci/check_layer_rules.dart` | 0 violaciones (D1–D6) |
| `dart run ci/check_public_config.dart` | OK |
| `dart run ci/check_openapi_fixtures.dart` | OK · 91 fixtures · 44 esquemas |
| `dart run tool/merge_arb.dart --check` | al día · 384 textos |
| `flutter test --coverage` | **1878 pruebas pasan**, 0 fallos (confirmado: sin pruebas en error) |
| `dart run ci/check_coverage.dart` | OK · global 97,2 % · core/session 95,6 % · core/network 98,4 % · **features/cart/domain 99,6 %** · **features/checkout/domain 100 %** · shared/formatting 100 % |

Cobertura de módulo (lcov de cada agente): cart 99,2 % · checkout 97,9 %.
Pendiente de código (umbral ≥ 90 % se exigirá en M5): `features/technical_tools/domain`.

## Qué se construyó

* **cart**: dominio puro (1–99 por producto, ≤ 100 líneas, suma al duplicar, «bajo pedido» y precio
  0 no comprables, subtotal informativo con `Money` entero COP); persistencia en el almacén duradero
  (datos corruptos → carrito vacío, sin PII); revalidación `POST /cart/validate` al abrir y antes de
  pagar, sin borrar líneas por error de red; `CartScreen` con stepper accesible, deshacer al quitar,
  aviso de cambios/no disponibles y «Pagar» solo si el servidor lo permite y el checkout está
  habilitado en `/config` (falla cerrado). Un invitado puede armar el carrito.
* **checkout**: máquina de estados pura (14 fases, tabla exhaustiva); `POST /checkout` con
  `Idempotency-Key` por intento; la URL del pago solo se abre si pasa la intersección
  flavor ∩ `/config` ∩ respuesta y se abre de inmediato en el navegador seguro (nunca WebView ni
  precarga); el ticket no se guarda, registra ni imprime; resultado verificado por
  `GET /checkout/{ref}` con sondeo 2/4/8/16 s y luego cada 15 s hasta 120 s; el carrito se vacía
  **solo** con `paid`; el intento en curso (sin PII) se reanuda tras un cierre forzado; mientras hay
  un intento en verificación no se crea otro ticket.
* **core** (orquestador): `DurableStore` (+ caja Hive `cart`, sin PII) cableado en el arranque;
  `RequestCancellation`; avisos legales de `/config`.
* **app** (orquestador): rutas del carrito y del pago (probadas, incluida la guarda de sesión),
  insignia de unidades en la pestaña Carrito con etiqueta accesible, y `integrationOverrides()`
  (ganchos de sesión del carrito y del pago + ficha→carrito real), separados de `coreOverrides`
  para que las pruebas de cada feature sigan registrando sus dobles. Costura de la ficha ampliada:
  ahora informa cuando la cantidad se acotó a 99 (AC-029-5).

## Decisiones pendientes que condicionan este código

| Decisión | Tratamiento en M3 |
|---|---|
| D-02 / PA-12 (pasarela y medios de pago) | La app no muestra ni promete ningún medio de pago. |
| PA-11 (doble pago ante pedido pendiente en WooCommerce) | Solo se advierte; no se bloquea más allá de «un intento a la vez». |
| H-07 (carrito al cerrar sesión) | `CartRetentionPolicy` en un solo punto: conserva al cerrar sesión, borra al eliminar la cuenta (CR-040). |
| H-10 (sin compra de invitado) | El pago exige sesión (guarda del router a `/login?from=`). |
| AC-029-5 y AC-050-2 [A VALIDAR] | Suma con tope 99; un cambio de precio exige «Ajustar» antes de pagar (falla cerrado). |

## Hallazgos abiertos

| ID | Hallazgo |
|---|---|
| H3-01 | `UrlLauncherSecureBrowser` no es `ASWebAuthenticationSession` efímera en iOS (CR-004): brecha conocida hasta SPK-01. |
| H3-02 | Códigos de «ticket vencido» del BFF no definidos en el contrato: aislados en `TicketFailureCodes`; confirmar con PT-07/PT-08. |
| H3-03 | Detección del cierre del navegador en iOS no verificada: por eso existe «Continuar verificando». |
| H3-04 | App Links / Universal Links de `/app/pedido` y `.well-known`: PENDIENTES de alojar (PT-11); el retorno hoy se prueba solo con el enlace simulado. |
| H3-05 | Las pruebas del adaptador del pago importan internos de `cart`; si se renombran, ajustarlas. |
| H3-06 | `EmptyState` tiene el ícono de búsqueda fijo; sería mejor que aceptara un ícono (cambio en `shared/`). |
| H3-07 | Los dos agentes ejecutaron `flutter test --coverage` en paralelo y pudieron pisar `coverage/lcov.info`; las cifras por módulo son de cada agente, las globales las midió el orquestador sobre la suite completa. |
| H3-08 | El mock del BFF devuelve datos sintéticos («ejemplo»); no se probó el flujo contra WooCommerce/Wompi reales. |

## No verificado en esta máquina

Dispositivo/emulador (el emulador de Android no cabe en la RAM del equipo), pago real con Wompi
sandbox (NL-02, QG-R02/R03: 0 duplicados), `ASWebAuthenticationSession`, App Links reales,
rendimiento (apertura ≤ 5 s), ST-077/081..089/124..127 (E2E contra staging). El backend de M3
(PT-08, PT-11) no existe aún (`x-status: proposed`): todo se probó con dobles y `FakeHttpAdapter`.

## Siguiente

M4 (perfil, pedidos y eliminación de cuenta: RF-104..111) y M5 (sedes, soporte/PQRS, calculadora BTU
si D-08 lo permite). **Pendiente de tu visto bueno**; no se inicia sin él.

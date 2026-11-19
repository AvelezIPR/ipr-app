# M1 — Descubrimiento de producto · resultados

Fecha: 2026-11-19 · Rebanada: Inicio, Catálogo, Búsqueda y Ficha de producto
(RF-001..005, 007, 009..016, 018, 019 parcial, 020..023, 026..028, 030..032, 037, 062..064).

Construida por 4 agentes en paralelo (home, catalog, search, product_detail) con el
orquestador integrando. Guía usada: `docs/project/guia_agentes_implementacion.md`.

## Evidencia ejecutada (Windows, Flutter 3.50.0)

| Puerta | Resultado |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | 224 archivos, 0 cambios |
| `flutter analyze --fatal-infos` | sin problemas |
| `dart run ci/check_layer_rules.dart` | 0 violaciones (D1–D6) |
| `dart run ci/check_public_config.dart` | OK |
| `dart run ci/check_openapi_fixtures.dart` | OK · 51 fixtures · 44 esquemas |
| `dart run tool/merge_arb.dart --check` | al día · 169 textos |
| `flutter test --coverage` | 783 pruebas pasan (+9 de cableado de rutas, ejecutadas aparte: 792) |
| `dart run ci/check_coverage.dart` | OK · global 95,8 % · core/session 95,6 % · core/network 98,4 % · shared/formatting 100 % |

Cobertura por módulo (medida por cada agente sobre su lcov): home 98,6 % · catalog
98,1 % · search 99,3 % · product_detail 96,8 %.
`features/cart/domain`, `features/checkout/domain` y `features/technical_tools/domain`
siguen «pendiente (aún sin código)»: sus umbrales del 90 % se exigirán en M3/M4/M5.

## Cambios del orquestador en `core/`

* `lib/core/network/request_cancellation.dart` + `ApiClient.send/sendDecoded(cancellation:)`:
  las features no pueden importar `dio` (D6); ahora cancelan la petición por esta clase
  y se aborta la conexión. Probado (`test/unit/core/network/request_cancellation_test.dart`).
* Rutas reales de las 4 features en `lib/app/router/app_router.dart` (probadas en
  `test/widget/app_router_m1_test.dart`).
* `RemoteConfig`: avisos de envío/garantía/precio bajo consulta (RF-032).

## Decisiones y desviaciones relevantes

* **Más vendidos (home)**: `listProducts?sort=popularity&perPage=12`; criterio real PA-05 DESCONOCIDO.
* **Historial de búsqueda (RF-025)**: no implementado (Could, fase 2, depende de D-12). Sin
  persistencia en disco ni logs del texto buscado.
* **Mínimo de 2 caracteres** para buscar/sugerir porque el contrato lo declara (`minLength: 2`).
* **Ficha**: HTML de la descripción sanitizado con lista blanca propia (≈50 cargas hostiles
  probadas), imágenes solo https de `mediaHosts`, enlaces solo https mediante
  `ExternalLauncher`; sin webview. Avisos de envío/garantía vienen de `/config` y se omiten si
  son nulos (texto legal D-12 no inventado).
* **Costura de carrito**: `addToCartActionProvider` vale `null` en M1 → el botón «Agregar al
  carrito» no se muestra; M3 lo sobreescribe. Tope de cantidad 99 (el contrato no da existencias).
* **Listados**: tamaño de página 24 (defecto del contrato; D-05 sin decidir); un 200 vacío es
  `UiData` con lista vacía para conservar «Limpiar filtros» (AC-013-4).
* **Duplicación consciente** entre features (p. ej. cada una tiene su datasource de
  categorías/marcas/búsqueda): la regla D3 prohíbe importar entre features. Candidato a
  extraer a `shared/` si crece (hallazgo H1-02).
* Patrón `<feature>_providers.dart` en la raíz de cada feature para cablear el repositorio
  concreto (D4 impide que `presentation/` importe `data/`).

## Hallazgos abiertos (para decidir antes o durante M2/M3)

| ID | Hallazgo |
|---|---|
| H1-01 | `ExternalUrlPolicy` solo abre wa.me, mapas y el host del flavor: un enlace https a otro dominio dentro de la descripción muestra «No se pudo abrir el enlace». Decidir si se amplía la lista (cambio en `core`). |
| H1-02 | Duplicación entre features (ver arriba): decidir si se mueve el acceso a taxonomía/búsqueda a `shared/`. |
| H1-03 | RF-006 (acceso a calculadora BTU, apagado por `btuCalculatorEnabled`) y la barra superior de Inicio (Ayuda y Carrito con insignia) no están: dependen de M3/M5. |
| H1-04 | RF-089 (filtro de capacidad desde la calculadora): `ProductListScreen` solo recibe `categorySlug`; añadir parámetro inicial en M5. |
| H1-05 | Marcas sin landing (`hasLanding=false`) no se muestran en Inicio; qué abrir para ellas es DESCONOCIDO. |
| H1-06 | El contrato no declara 404 para `listProducts`/`listFilters`/marca; la UI maneja `NotFound` pero no está verificado contra un BFF real. |
| H1-07 | Mensajes de WhatsApp (D-04) y textos propios de estado sin validar con Comercial; tolerancia a tildes/SKU y ranking del SKU exacto (AC-020-5, AC-022-1/3/4) dependen del BFF. |
| H1-08 | `dart format test` fue ejecutado una vez por un agente sobre todo `test/`; el formato global quedó sin cambios (verificado). |

## No verificado en esta máquina

Android/iOS nativo, ejecución en dispositivo o emulador, `integration_test`/patrol, TC-108 y
TC-110 (requieren staging), rendimiento (RNF), el workflow de CI en GitHub Actions y
cualquier comportamiento contra un BFF real (solo `FakeHttpAdapter` y el mock `tool/mock_bff`).

## Siguiente

M2 (cuenta y sesión: registro, login, recuperación, perfil, direcciones, eliminación) queda
**pendiente de tu visto bueno**. No se inicia sin él.

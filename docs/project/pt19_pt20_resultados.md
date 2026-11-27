# PT-19 + PT-20 — Auditoría local de calidad, trazabilidad, accesibilidad, E2E simulado y controles de seguridad · resultados

Fecha: 2026-11-23 · Rebanada `PT-19 + PT-20` (cierre local automatizado M0–M5; **ciclo `CIC-001` en ejecución — pendiente cierre QA, CI remoto, *staging* y dispositivos reales**).
Estado base verificado por [`verifier`](file:///c:/Users/empr16/ipr-app/docs/08_quality/test_results.md): `HEAD d5a2d8a` + cambios locales de código/herramientas/pruebas (`6 files changed, 72 insertions(+), 26 deletions(-)` + `7` suites nuevas en `test/`, sin incluir este informe ni la actualización documental de [test_results.md](file:///c:/Users/empr16/ipr-app/docs/08_quality/test_results.md)). `pubspec.yaml`, `pubspec.lock` y `.env*` intactos / ausentes.

---

## 1. Evidencia ejecutada — 9 puertas oficiales (Windows 11, Flutter 3.50.0 / Dart 3.14)

Ventana secuencial *fail-fast* ejecutada por el verificador (`#21`, zona `America/Bogota`, `2026-11-23 10:19:27 -05:00` → `10:25:53 -05:00`):

| # | Puerta | Hora (`-05:00`) | Resultado |
|---|---|---|---|
| 1 | `dart format --output=none --set-exit-if-changed .` | `10:19:30` | **exit 0** · `Formatted 434 files (0 changed) in 1.75 seconds.` |
| 2 | `flutter analyze --fatal-infos` | `10:19:38` | **exit 0** · `No issues found! (ran in 5.3s)` |
| 3 | `dart run ci/check_layer_rules.dart` | `10:19:40` | **exit 0** · `0 violaciones (D1–D6, features del MVP, paquetes prohibidos)` |
| 4 | `dart run ci/check_public_config.dart` | `10:19:41` | **exit 0** · `OK (config/{dev,staging,prod}.json y contrato fijado)` |
| 5 | `dart run ci/check_openapi_fixtures.dart` | `10:19:43` | **exit 0** · `Fixtures comprobados: 121 · esquemas sintetizados: 44 · OK` |
| 6 | `dart run tool/merge_arb.dart --check` | `10:19:44` | **exit 0** · `l10n/app_es.arb está al día (609 textos)` |
| 7 | `dart run ci/gen_coverage_helper.dart` | `10:19:45` | **exit 0** · `coverage_helper_test.dart: 297 archivos de lib/ importados` |
| 8 | `flutter test --coverage` | `10:19:45` → `10:25:50` (`365.3s`) | **exit 0** · **`2159` pasadas, `0` fallidas, `0` omitidas** (`96` suites = `2158` en `95` `*_test.dart` + `1` en `coverage_helper_test.dart`) |
| 9 | `dart run ci/check_coverage.dart` | `10:25:53` | **exit 0** · `check_coverage: OK` |

### Cobertura medida sobre `coverage/lcov.info` (`#21`)

* **Global (regla CI: excluye `*.g.dart`, `*.freezed.dart` y `lib/l10n/app_localizations*`)**: **`95.6 %`** (`95.61 %`, `9843 / 10295` líneas, `267` archivos presentes en `lcov.info` de `297` no generados).
  *(Excluyendo únicamente `*.g.dart` y `*.freezed.dart`, con `app_localizations*` [`669 / 742`, `90.16 %`] incluido: `95.24 %`, `10512 / 11037`).*
* **Módulos críticos CI (`>= 90 %`)**:
  * `lib/core/session`: **`95.6 %`** (`151 / 158`)
  * `lib/core/network`: **`100.0 %`** (`244 / 244`)
  * `lib/features/cart/domain`: **`99.6 %`** (`244 / 245`)
  * `lib/features/checkout/domain`: **`100.0 %`** (`336 / 336`)
  * `lib/shared/formatting`: **`100.0 %`** (`21 / 21`)
  * `lib/features/technical_tools/domain`: **`97.4 %`** (`75 / 77`)
* **Desglose por módulo (`lib/`, excluyendo generados)**:

| Módulo | Cobertura | Líneas cubiertas / totales | Archivos en `lcov` |
|---|---|---|---|
| `core` | **93.28 %** | `833 / 893` | 41 |
| `shared` | **96.49 %** | `495 / 513` | 21 |
| `authentication` | **99.06 %** | `735 / 742` | 21 |
| `catalog` | **98.53 %** | `1076 / 1092` | 22 |
| `cart` | **99.30 %** | `849 / 855` | 20 |
| `checkout` | **98.27 %** | `1139 / 1159` | 22 |
| `search` | **99.27 %** | `407 / 410` | 13 |
| `branches` | **86.52 %** | `276 / 319` | 10 |
| `orders` | **95.47 %** | `506 / 530` | 12 |
| `profile` | **91.03 %** | `1207 / 1326` | 22 |
| `support` | **92.48 %** | `603 / 652` | 15 |
| `technical_tools` | **99.25 %** | `266 / 268` | 4 |
| `technical_tools/domain` *(subconjunto)* | **97.40 %** | `75 / 77` | 2 |
| `home` | **99.34 %** | `450 / 453` | 14 |
| `product_detail` | **97.70 %** | `806 / 825` | 20 |
| `app` | **76.47 %** | `195 / 255` | 7 |
| Raíz `lib/*.dart` | **0.00 %** | `0 / 3` | 3 |
| `tool/` | **No instrumentado** | `0` entradas `SF:tool/...` | `flutter test --coverage` solo instrumenta `lib/` |

### Inventario físico del repositorio (`#21`)

* `lib/`: **301** `.dart` totales (`297` no generados importados en `coverage_helper_test.dart` + `4` generados: `remote_config.freezed.dart`, `remote_config_dto.g.dart`, `app_localizations.dart`, `app_localizations_es.dart`).
* `test/`: **254** archivos totales (`135` en `test/fixtures/` + `119` `.dart` incluyendo `coverage_helper_test.dart`; excluyendo este último: **`118` `.dart`** = **`95` suites `*_test.dart`** + **`23` helpers/harnesses**).
* `l10n/parts/`: **14** archivos `.arb` (**609** textos) · `dart format`: **434** archivos formateados.

---

## 2. Qué construyó y verificó cada frente de trabajo

* **Accesibilidad M4–M5 (`a11y`, `#10`, `148 / 148` pruebas nuevas en `TC-157 · RNF-067..076`)**:
  * Suites creadas con texto al `200 %` en `360x800` y `320x568`, las 4 guías automáticas (`androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`), verificación de objetivos `>= 48 dp` y comunicación no dependiente solo de color:
    * [orders_accessibility_test.dart](file:///c:/Users/empr16/ipr-app/test/widget/features/orders/orders_accessibility_test.dart) (`23/23`: `OrdersScreen`, `OrderDetailScreen`)
    * [profile_accessibility_test.dart](file:///c:/Users/empr16/ipr-app/test/widget/features/profile/profile_accessibility_test.dart) (`46/46`: `AccountScreen`, `ProfileScreen`, `ChangePasswordScreen` incl. `autofillHints`, `AddressesScreen`, `DeleteAccountScreen`, `DataRightsScreen`)
    * [branches_accessibility_test.dart](file:///c:/Users/empr16/ipr-app/test/widget/features/branches/branches_accessibility_test.dart) (`23/23`: `BranchesScreen`, `BranchDetailScreen`)
    * [support_accessibility_test.dart](file:///c:/Users/empr16/ipr-app/test/widget/features/support/support_accessibility_test.dart) (`39/39`: `HelpScreen`, `EngineeringScreen`, `PqrsScreen`, `LegalScreen`)
    * [btu_accessibility_test.dart](file:///c:/Users/empr16/ipr-app/test/widget/features/technical_tools/btu_accessibility_test.dart) (`17/17`: `BtuCalculatorScreen` habilitado y deshabilitado)
  * Correcciones en [pqrs_screen.dart](file:///c:/Users/empr16/ipr-app/lib/features/support/presentation/screens/pqrs_screen.dart) y [btu_calculator_screen.dart](file:///c:/Users/empr16/ipr-app/lib/features/technical_tools/presentation/screens/btu_calculator_screen.dart); `0` fallos en `core/`, `shared/` y `l10n/`. Suites de carpeta completas tras edición: `support` (`72/72`), `technical_tools` (`21/21`).
* **E2E simulado sobre `mock_bff` y arranque *preview* (`e2e`, `#6`, `#17`, `7 / 7` pruebas)**:
  * [tool/preview/main.dart](file:///c:/Users/empr16/ipr-app/tool/preview/main.dart): `Future<void> main() async`, exposición de `MemoryPrefs`, `MemorySecure`, `createPreviewContainer` y `bootstrapPreviewContainer` (`restore()`, `loadCached()`, `unawaited(remote.refreshIfStale())`).
  * [mock_bff_e2e_flows_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/tool/mock_bff_e2e_flows_test.dart) (`7/7` HTTP real contra `startMockBff()` sin `FakeHttpAdapter`): flujos públicos `M1/M5` sin `Authorization` aún con sesión activa (`TC-144`), rutas privadas `401` sin `Bearer` y login → `/me` + `/orders` + `/orders/1` con `Bearer` y `X-Device-Id` UUID v4 (`TC-144`), `Idempotency-Key` obligatoria con `POST /checkout`, `/me/deletion`, `/pqrs` y rechazo `400 validation_failed` sin clave (`ST-087`), escenarios `error:426`, `error:429`, `error:503` (con reintentos) y `html403` (`ST-072`/`ST-073`), y *smoke* de arranque `PT-19` (`SessionUnknown -> SessionAnonymous`).
  * [tool/merge_arb.dart](file:///c:/Users/empr16/ipr-app/tool/merge_arb.dart#L86-L87): normalización de `\r\n` → `\n` en `--check` para Windows (`core.autocrlf=true`) sin alterar `l10n/app_es.arb`.
* **Controles cliente de seguridad (`security`, `#7`, `#12`, `17 / 17` pruebas + `43 / 43` con regresión)**:
  * [client_security_controls_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/security/client_security_controls_test.dart) (`17/17`, verificada junto con `router_policy_test.dart` `15/15` y `external_test.dart` `11/11` = `43/43`): cubre en alcance estático/cliente/simulado `20` controles oficiales `ST-*` (`ST-001`, `ST-002` con `checkLayerRules`, `ST-021`, `ST-022`, `ST-088`, `ST-102`, `ST-103`, `ST-108`, `ST-109`, `ST-110`, `ST-111`, `ST-120`, `ST-121(a)`, `ST-122`, `ST-124`, `ST-125` estático, `ST-127`, `ST-130`, `ST-170`, `ST-171`) con valores canario de [security_testing.md](file:///c:/Users/empr16/ipr-app/docs/06_security/security_testing.md#L18) y sin modificar `pubspec.*` ni `.env*`.
  * Correcciones aplicadas en [deep_link_policy.dart](file:///c:/Users/empr16/ipr-app/lib/app/router/deep_link_policy.dart#L49-L50) y [external_url_policy.dart](file:///c:/Users/empr16/ipr-app/lib/core/external/external_url_policy.dart#L24-L33).
* **Auditoría documental y trazabilidad (`traceability`)**:
  * Inventario completo de `test/` contrastado contra [test_cases.md](file:///c:/Users/empr16/ipr-app/docs/08_quality/test_cases.md) (`160` TC), [acceptance_criteria.md](file:///c:/Users/empr16/ipr-app/docs/02_requirements/acceptance_criteria.md) (`490` AC) y [security_testing.md](file:///c:/Users/empr16/ipr-app/docs/06_security/security_testing.md) (`140` ST).
  * Registro del ciclo `CIC-001` (**En ejecución — pendiente cierre QA, CI y staging**) en [test_results.md](file:///c:/Users/empr16/ipr-app/docs/08_quality/test_results.md).

---

## 3. Trazabilidad `TC` / `AC` / `ST` y métricas del ciclo `CIC-001`

### 3.1 Inventario en código de `test/` (post-`#21`)

| Concepto | En especificación | Referenciados en `test/` | Observación exacta |
|---|---|---|---|
| Casos funcionales (`TC-001..TC-160`) | **160** (`test_cases.md`) | **105** exactos (**106** con `TC-099/100`) + cobertura funcional sin etiqueta `TC-054` (`AC-012-5`) y parcial `TC-105` (`StaleBanner`/golden) | `54` TCs sin referencia en `test/` (E2E, *staging*, WordPress `ipr/v1/m`, BFF Node, rendimiento, compatibilidad y revisión manual) |
| Criterios de aceptación (`AC-*`) | **490** (`acceptance_criteria.md`) | **237** literales exactos (**270** expandiendo notación compacta `a/b` y `a..b`) | Incluye regresiones funcionales de AC de seguridad |
| Pruebas de seguridad (`ST-001..ST-174`) | **140** (`security_testing.md`) | **24** identificadores válidos (`ST-001, 002, 021, 022, 066, 072, 073, 087, 088, 102, 103, 108..111, 120..122, 124, 125, 127, 130, 170, 171`) | `ST-016` huérfano corregido a `ST-066` en [contract_and_mock_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/tool/contract_and_mock_test.dart#L33) (`DEF-006` cerrado) |

### 3.2 Resumen honesto de `CIC-001` según reglas de `test_results.md §2, §4 y §5`

| Estado en `CIC-001` | Cantidad | P1 / P2 / P3 | Regla aplicada (`test_results.md §2, §4`) |
|---|---|---|---|
| **Aprobado** | **32** (`20.0 %`) | 20 / 11 / 1 | Solo casos **sin** `[A VALIDAR]`, **sin** dependencia de *staging*, dispositivo físico, Wompi sandbox ni BFF real, y con el 100 % de sus pasos locales cubiertos y verificados (`#21`). **Tasa aprobación P1 (§5):** `20 / 90 = 22.2 %` (QG-R01 exige `100 %`). **Tasa aprobación sobre completos (§5):** `32 / 32 = 100.0 %`. |
| **Aprobado parcial** | **20** (`12.5 %`) | 5 / 9 / 6 | Exclusivamente casos **`[A VALIDAR]`** cuyo alcance determinista local pasó (`#21`), citando explícitamente `PA-xx`, `D-xx` o `ADR-001`. Excluidos de la tasa de aprobación (§5). |
| **Fallido** | **0** | 0 / 0 / 0 | Las `2159/2159` pruebas automatizadas pasaron en `#21` tras corregir `DEF-001..DEF-004`. |
| **Bloqueado** | **108** (`67.5 %`) | 65 / 34 / 9 | Exigen `C2 staging`, `BFF /mobile/v1`, `Wompi sandbox`, `WordPress ipr/v1/m`, dispositivos físicos / matriz `RNF-082`, `integration_test/` en emulador, revisión manual humana, o tienen brechas locales concretas (`TC-033`, `TC-044`, `TC-050`, `TC-053`, `TC-057`, `TC-078`, `TC-079`, `TC-085`, `TC-091`, `TC-100`, `TC-101`, `TC-102`, `TC-105`, `TC-115`, `TC-119`, `TC-122`, `TC-125`). |
| **Total planificado** | **160** | **90 / 54 / 16** | **AC con resultado en `CIC-001`:** `150 de 490` · **AC verificados (§5: todos sus `TC` en `Aprobado`, sin `[A VALIDAR]` ni `Seguridad`):** **`75 de 490 (15.3 %)`**. |

### 3.3 Cobertura de `ST-*` en alcance local vs cierre en `06_security/security_testing.md`

En apego a [test_results.md §4.11](file:///c:/Users/empr16/ipr-app/docs/08_quality/test_results.md#L87) y [security_testing.md §0](file:///c:/Users/empr16/ipr-app/docs/06_security/security_testing.md#L22), **ninguno** de los `140` casos `ST-*` se declara cerrado como `Aprobado` global en `CIC-001` porque [security_testing.md](file:///c:/Users/empr16/ipr-app/docs/06_security/security_testing.md#L299) sigue en `NO EJECUTADO / Pendiente` para F2/F3/F4 reales:
* **Alcance F2 de código cliente verificado localmente (`3` IDs):** `ST-001` (`flutter analyze --fatal-infos` + `pubspec.yaml`/`lib/` en [client_security_controls_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/security/client_security_controls_test.dart#L237); falta `custom_lint`/gate PR en GitHub), `ST-002` (`ci/check_layer_rules.dart` = `0` violaciones D1–D6; falta prueba de PR sembrado en CI), `ST-110` (`500` `uuidV4()` + ausencia de APIs de IDs de hardware en `lib/`; falta captura dinámica F3).
* **Controles cliente/estático/manifiesto/`mock_bff` de pruebas F2/F3/F4 verificados localmente (`20` IDs, pendientes de cierre con `gitleaks`/binario release/MobSF/Burp/mitmproxy/staging/dispositivos):** `ST-021`, `ST-022`, `ST-072`, `ST-073`, `ST-087`, `ST-088`, `ST-102`, `ST-103`, `ST-108`, `ST-109`, `ST-111`, `ST-120`, `ST-121` (`(a)` cliente; falta `(b)/(c)` APK/IPA), `ST-122`, `ST-124`, `ST-125` (estructura estática; `REEMPLAZAR_*` pendiente `D-14`), `ST-127`, `ST-130`, `ST-170`, `ST-171`.
* **Restantes (`117` de `140`):** exclusivamente servidor BFF, WordPress, Cloudflare, WAF, k6, pentest `ST-160` o revisión de binarios/operación (`F3`/`F4`), sin cobertura ejecutable en este repositorio.

---

## 4. Hallazgos resueltos vs abiertos (`DEF-001..DEF-008`)

### Resueltos y verificados en esta sesión
* **`DEF-001` (S2 · `ST-124`/`TC-077` · `#7` → `#12`)**: [deep_link_policy.dart](file:///c:/Users/empr16/ipr-app/lib/app/router/deep_link_policy.dart#L49-L50) omitía `uri.hasScheme` en `isDeepLink`, devolviendo `null` en `computeRedirect` para `javascript:alert(1)`, `data:text/html,/app/pedido` y `file:///orders`. Corregido con `uri.hasScheme || uri.host.isNotEmpty || uri.path.startsWith('/app')` y cubierto en [client_security_controls_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/security/client_security_controls_test.dart#L479) (`43/43` en `#12`, `2159/2159` en `#21`).
* **`DEF-002` (S3 · `ST-122`/`TC-125` · `#7` → `#12`)**: [external_url_policy.dart](file:///c:/Users/empr16/ipr-app/lib/core/external/external_url_policy.dart#L24-L33) aceptaba `/maps-evil` o rutas con `..`/`%2e` en `www.google.com/maps` y comparaba `extraHttpsHosts` sensible a mayúsculas. Endurecido con rechazo explícito de `..`/`%2e`/`%2E`, `normalizePath()` + `/maps` o `/maps/`, y comparación case-insensitive (`43/43` en `#12`, `2159/2159` en `#21`).
* **`DEF-003` (S2 · `TC-157` · `#10`)**: `DropdownButtonFormField` sin `isExpanded: true` y campos sin `errorMaxLines: 4` desbordaban al `200 %` en [pqrs_screen.dart](file:///c:/Users/empr16/ipr-app/lib/features/support/presentation/screens/pqrs_screen.dart#L184) (`50`–`90 px`) y [btu_calculator_screen.dart](file:///c:/Users/empr16/ipr-app/lib/features/technical_tools/presentation/screens/btu_calculator_screen.dart#L129) (`25 px` + `Semantics(container: true)` en resultado). Corregidos y verificados (`148/148` a11y en `#10`, `2159/2159` en `#21`).
* **`DEF-004` (S3 · Puerta 6 CI · `#15` → `#17`)**: [tool/merge_arb.dart](file:///c:/Users/empr16/ipr-app/tool/merge_arb.dart#L86-L87) fallaba `--check` en Windows por `\r\n` (`core.autocrlf = true`) sobre `l10n/app_es.arb`. Corregido normalizando `\r\n` a `\n` (`609 textos`, `exit 0` en `#17` y `#21`).
* **`DEF-005` (`Cerrado` · S4 · `ST-108`/`ST-109` · `#7`/`#11`)**: [pii_scrubber.dart](file:///c:/Users/empr16/ipr-app/lib/core/observability/pii_scrubber.dart#L27-L28) ajustado de `{5,}` a `{4,}` para depurar documentos y números de `6` o más dígitos; aserción explícita agregada en [client_security_controls_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/security/client_security_controls_test.dart#L1220-L1224). *(Cadenas libres sin formato como `Calle Canario 99` o `Canario-Pass-0001` siguen dependiendo de `toString()` redactado o `?query`.)*
* **`DEF-006` (`Cerrado` · S4 · Trazabilidad `QG-M08` · `PT-19`/`PT-20`)**: [contract_and_mock_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/tool/contract_and_mock_test.dart#L33) actualizado de `ST-016` (inexistente) al identificador oficial `ST-066 · QG-M06 · validador de contrato`.
* **Cierre de brechas simuladas en `mock_bff`**: `TC-033`, `TC-044` (paso 4), `TC-088` y `TC-091` cubiertos y validados contra `openapi.yaml` en [mock_bff_e2e_flows_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/tool/mock_bff_e2e_flows_test.dart).
* *(Mejora `PT-19` sin defecto previo)*: [tool/preview/main.dart](file:///c:/Users/empr16/ipr-app/tool/preview/main.dart) refactorizado con `Future<void> main() async`, `createPreviewContainer` y `bootstrapPreviewContainer` verificados en [mock_bff_e2e_flows_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/tool/mock_bff_e2e_flows_test.dart#L586).

### Menores y abiertos (pendientes de cierre / refactor posterior)
* **`DEF-007` (S3 · Esquema `openapi.yaml` / `mock_bff` · `#6`)**: En `mock_bff` (`startMockBff()`), `GET /filters` sintetiza `key: "ejemplo"` (por lo que `mapFilters` lo descarta vía `!FilterKeys.isSupported` devolviendo `[]`) y `GET /orders` / `GET /orders/1` sintetizan `currency: "ejemplo"` por ausencia de `const: COP` en el esquema `OrderSummary`.
* **`DEF-008` (S2 · Config/seguridad pendiente · `#7`)**: [assetlinks.json](file:///c:/Users/empr16/ipr-app/deploy/well-known/assetlinks.json#L6-L7) y [apple-app-site-association](file:///c:/Users/empr16/ipr-app/deploy/well-known/apple-app-site-association#L5) conservan marcadores `REEMPLAZAR_*` (`D-14` para `ST-125`/`TC-082`), y [secure_browser.dart](file:///c:/Users/empr16/ipr-app/lib/core/external/secure_browser.dart#L36-L37) documenta la brecha `SPK-01` (`LaunchMode.inAppBrowserView` sin sesión efímera `ASWebAuthenticationSession` en iOS para `ST-085`).
* **Brechas de cobertura automatizada local**: ausencia total de `integration_test/` (`TC-028`, `TC-040`); falta de goldens fuera de los 4 componentes de [design_system_golden_test.dart](file:///c:/Users/empr16/ipr-app/test/golden/design_system_golden_test.dart) (`TC-050`, `TC-053`, `TC-079`, `TC-085`, `TC-115`, `TC-119`, `TC-122`); casos simulados puntuales pendientes (`TC-053` `OnRequest` en marca y Liquidaciones, `TC-057` fallo `tel:` sin telefonía, `TC-078` pedido de `CLI-02`, `TC-100` matriz 4×3 en `BranchesScreen`, `TC-101` 3.ª página con 60 ítems, `TC-102` secuencia unificada de 6 fallos, `TC-105` encadenado `stale` → carrito, `TC-125` fallback sin app de mapas). *(Nota: `TC-033`, `TC-044` paso 4, `TC-088` y `TC-091` ya están cubiertos en [mock_bff_e2e_flows_test.dart](file:///c:/Users/empr16/ipr-app/test/unit/tool/mock_bff_e2e_flows_test.dart).)*

---

## 5. Verificado en local vs NO verificado

### VERIFICADO en local (máquina de desarrollo Windows 11)
* Compilación estática, formato (`434` archivos), análisis (`--fatal-infos`, `0` issues), arquitectura D1–D6, configuración pública (`dev`/`staging`/`prod`), contratos/fixtures (`121` fixtures / `44` esquemas), ARB (`609` textos), **`2159/2159`** pruebas unitarias/widget/contrato/a11y/`mock_bff` y cobertura global CI **`95.6 %`** (`check_coverage.dart` en verde).
* Comportamiento determinista de **32 TCs** (`Aprobado` en alcance local) y parte determinista de **20 TCs `[A VALIDAR]`** (`Aprobado parcial`), más **148/148** pruebas nuevas de accesibilidad `TC-157`, **7/7** de HTTP real contra `mock_bff` y **17/17** de controles de seguridad cliente con canarios.

### NO VERIFICADO (bloquea `QG-R01..QG-R15` y cierre de `PT-19` / `PT-20`)
* **Entorno *staging* (`C2`) y backend real**: no existe ni fue probado BFF Node/TypeScript `/mobile/v1`, *plugin* WordPress `ipr/v1/m/*`, WooCommerce real ni Wompi *sandbox*.
* **Dispositivos físicos, compilación nativa y emuladores**: `0` ejecuciones en Android/iOS físicos, sin matriz `RNF-082` (`>= 8` dispositivos, `TC-159`), sin `integration_test/` (`TC-028`, `TC-040`), sin TalkBack/VoiceOver reales (`TC-158`), sin perfiles de red ni trazas *profile/release* (`TC-107`, `TC-154..TC-156`) y sin `flutter build apk/ipa`.
* **Seguridad de fase F2-CI / F3 / F4**: sin `gitleaks` sobre historial Git ni *hook* pre-commit, sin `npm audit`/OSV/SBOM, sin inspección de APK/IPA *release* (MobSF/`jadx`/`bmgr`), sin Burp/`mitmproxy`/k6 en *staging*, sin prueba de penetración independiente (`ST-160`, `CH-21`) y sin documentos firmados de aceptación de riesgo (`CH-22`, `ST-116`).
* **Pipeline remoto y decisiones de negocio pendientes**: sin ejecución en GitHub Actions remoto (`QG-M01..M12`, `QG-B01..B07`), sin `D-02`, `D-04`, `D-05`, `D-07`, `D-08`, `D-09`, `D-10`, `D-12`, `D-14`, `D-15`, `D-16`, `PA-01..PA-12`, `DN-01..DN-10`, `MED-01..MED-15` ni cierre formal de QA sobre [test_results.md §9](file:///c:/Users/empr16/ipr-app/docs/08_quality/test_results.md#L558).

# Rebanada M0 (Fundación) — resultados y hallazgos

| | |
|---|---|
| **Fecha** | 2026-11-19 |
| **Alcance** | `PT-13`: proyecto, flavors, configuración pública, l10n, `core/`, `shared/`, `app/router`, scripts de CI, BFF simulado, endurecimiento nativo |
| **Entorno de ejecución** | Windows 11, Flutter 3.50.0 / Dart 3.14.0 (clonado del repositorio oficial, etiqueta `3.50.0`). **Sin JDK, sin Android SDK, sin macOS/Xcode.** |
| **Estado** | Terminada y detenida, a la espera de revisión (como se pidió) |

## 1. Evidencia de ejecución real

Corrida de las puertas de calidad el 2026-11-19 (códigos de salida reales):

| Puerta | Orden | Resultado |
|---|---|---|
| QG-M01 | `dart format --output=none --set-exit-if-changed .` | exit 0 · 103 archivos, 0 cambios |
| QG-M02 | `flutter analyze --fatal-infos` | exit 0 · **No issues found** (reglas `very_good_analysis` 11) |
| QG-M03 | `dart run ci/check_layer_rules.dart` | exit 0 · 0 violaciones D1–D6, features, paquetes prohibidos |
| SC-038 | `dart run ci/check_public_config.dart` | exit 0 · `config/*.json` públicos, contrato fijado con huella correcta |
| QG-M06 | `dart run ci/check_openapi_fixtures.dart` | exit 0 · 14 fixtures y 44 esquemas sintetizados válidos |
| QG-M04 | `flutter test --coverage` | exit 0 · **269 pruebas pasan** (15 archivos + auxiliar de cobertura) |
| QG-M05 | `dart run ci/check_coverage.dart` | exit 0 · global **86,2 %** (≥ 70) · `core/session` **95,6 %** · `core/network` **93,4 %** · `shared/formatting` **100 %** (≥ 90) |

La cobertura **excluye código generado** (`*.g.dart`, `*.freezed.dart`, `lib/l10n`)
y se mide con un auxiliar (`test/coverage_helper_test.dart`, generado por
`ci/gen_coverage_helper.dart`) que importa todo `lib/`: sin él Flutter solo
instrumenta lo que alguna prueba importa y el porcentaje saldría inflado. Los
módulos críticos `features/cart/domain`, `features/checkout/domain` y
`features/technical_tools/domain` figuran como "pendiente (aún sin código)" y
pasan a exigirse cuando existan (M3 y M5).

Pruebas de los propios verificadores: `test/unit/ci/` comprueba que cada regla
D1–D6, la lista de features y los paquetes prohibidos **detectan** una
violación sintética, y que los umbrales de cobertura y la configuración pública
fallan cuando deben.

Guías de accesibilidad automáticas (`androidTapTargetGuideline`,
`iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`)
pasan sobre los componentes de `shared/widgets`. Goldens con `alchemist` a
escala de texto 1,0 y 2,0 (modo CI, independiente de plataforma: el texto se
dibuja como bloques).

## 2. Lo que NO se pudo verificar en esta máquina (no se afirma)

| Elemento | Estado |
|---|---|
| Compilación de **Android** (APK/AAB, flavors `dev/staging/prod`, `build.gradle.kts`, manifiesto, `network_security_config`, App Links) | **Escrito, NO compilado ni probado** (sin JDK ni Android SDK) |
| `FLAG_SECURE` (`MainActivity.kt`) | Escrito, no compilado |
| **iOS** (`AppDelegate.swift`, `SceneDelegate.swift`, `Info.plist`) | Escrito, no compilado; **flavors, esquemas y Associated Domains sin crear** (requiere Xcode; ver `ios/FLAVORS.md`) |
| `integration_test/` en dispositivo/emulador | **No existe**; las pruebas de integración ligeras corren con `flutter test` y un servidor `shelf` real en loopback |
| `patrol` | No se añadió (condicionado a SPK-01) |
| `.github/workflows/ci.yml` | **Nunca ejecutado**; acciones sin fijar por SHA; etapas 9–14 ausentes |
| Retorno del pago por App Link / SPK-01 / SPK-02 / SPK-03 | Sin spikes (requieren dispositivos) |
| Rendimiento, memoria, tamaño de la app | Sin medición |

## 3. Hallazgos de M0 que contradicen o completan la documentación

| # | Hallazgo | Evidencia | Acción |
|---|---|---|---|
| H0-01 | En **Flutter 3.50** `package:flutter/material.dart` está **deprecado** y la plantilla usa el paquete `material_ui`. Los documentos de arquitectura no lo mencionan. | `flutter create` y `packages/flutter/lib/material.dart` (anotación `@Deprecated`) | Se usa `material_ui` (`^1.1.0`). Actualizar `flutter_app_architecture.md` §1/§17. |
| H0-02 | Los delegados que genera `gen-l10n` (`AppLocalizations.localizationsDelegates`) **no sirven** a `material_ui`: Material avisa que no encuentra su `MaterialLocalizations`. | Fallo reproducido en pruebas de widgets; README de `material_ui` | `iprLocalizationsDelegates` usa `GlobalMaterialLocalizations.delegates` de `material_ui`. |
| H0-03 | `Timeout` choca con la clase `Timeout` de `flutter_test`. | Error de compilación en pruebas | La clase se llama **`RequestTimeout`** (difiere del nombre de `flutter_app_architecture.md` §7.3). |
| H0-04 | `openapi.yaml` declara `Idempotency-Key` **opcional**; **CR-005** la hace **obligatoria** en `/checkout`, `/me/deletion` y `/pqrs`. | `openapi.yaml` `IdempotencyKey.required: false` | El cliente la exige (`ApiRequest.requiresIdempotency`) y el BFF simulado la rechaza si falta. **Falta corregir el YAML** (CR-005, cambio exacto). |
| H0-05 | `/pqrs` declara `security: [{}, {bearerAuth: []}]` (autenticación **opcional**). | `openapi.yaml` | El simulado la trata como pública con Bearer opcional. |
| H0-06 | **CR-004** pide `ASWebAuthenticationSession` efímera en iOS; `url_launcher` no la ofrece y `flutter_web_auth_2` no está en la lista. | `SecureBrowser` | Interfaz + `url_launcher` (Custom Tabs / SFSafariViewController). Decisión en SPK-01. |
| H0-07 | Las **versiones de paquetes** de la tabla §17.1 resuelven todas juntas con `flutter pub get` sobre Flutter 3.50.0 (125 dependencias). | `pubspec.lock` | Sube de "verificado en pub.dev" a "resuelve en este SDK". La compatibilidad en dispositivo sigue sin probarse. |
| H0-08 | Dependencias **no listadas** que fue necesario añadir: `path_provider` (directorio de Hive), `meta` (`@immutable`), y de desarrollo `yaml` (leer `openapi.yaml`) y `crypto` (huella SHA-256 del contrato). | `pubspec.yaml` | Justificadas en comentarios; aprobar o sustituir. |
| H0-09 | Una prueba de texto al 200 % destapó un **defecto real**: `StockBadge` y los estados vacío/error desbordaban. | Pruebas y golden | Corregido (texto flexible y contenido desplazable) con pruebas de regresión. |
| H0-10 | `dart fix` con `very_good_analysis` 11 reescribe los constructores con la sintaxis nueva de Dart 3.14 (`new(...)`, `const factory`). | Código de `lib/` | Es válido en el SDK fijado; menos familiar para quien venga de Dart anterior. |
| H0-11 | `docs/` y la app comparten raíz (`ipr-app/`); **no hay repositorio git**. Una copia de seguridad que creé dentro del proyecto desapareció; hay otra fuera, en `ipr-docs-backup`. | `_backup/` ausente | Inicializar git (decisión del usuario). |

Discrepancias de cifras entre documentos detectadas por el agente del informe
técnico (sin resolver): trazabilidad dice 114 RNF; roadmap cita 72 SC, 62 TM,
22 P0 y 9 NLS; plan y mantenimiento 22 P0; plan y roadmap ST-001..ST-160; el
resumen ejecutivo cita 21 impactos de seguridad (son 24); `RF-114` citado y no
existe. Ver `docs/project/informe_tecnico.md`.

## 4. Decisiones pendientes aisladas (no se inventó ningún dato)

| Pendiente | Aislamiento |
|---|---|
| DN-02 reporte de fallos | `CrashReporter`/`AnalyticsSink` con `NoOp`; `ScrubbingCrashReporter` + `PiiScrubber` (falla cerrado) |
| D-08 fórmula BTU | `features.btuCalculatorEnabled` en `RemoteConfig`, **apagado** por defecto (sin `/config` válido todo queda apagado) |
| D-12 textos legales y retención | Llegan por `/config` (`legal`); nada incrustado |
| D-14 `applicationId`/bundle y cuentas | `co.ipr.app` provisional; plantillas `deploy/` con `REEMPLAZAR_*` |
| DN-01/SPK-02 mínimos de SO | Se hereda lo de Flutter |
| H-01..H-12 (aprobaciones) | Siguen **pendientes**; el código no depende de ninguna aprobada además de ADR-001/002 |
| PA-12 "bajo pedido" | `StockStatus.onBackorder` **no comprable** (CR-017 como supuesto) |
| APR-01 verde oficial | `#5BA628` solo decorativo (3,03:1); texto con derivados **propuestos** |

## 5. Siguiente paso

M1 (`PT-14`): catálogo, búsqueda, ficha y contacto (30 RF). Requiere confirmar,
antes de empezar, las correcciones H0-04 (YAML) y la decisión sobre H0-08.

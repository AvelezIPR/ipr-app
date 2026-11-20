# M5 — Sedes, ayuda, PQRS y calculadora BTU · resultados

Fecha: 2026-11-20 · Rebanada `PT-18+`: directorio y ficha de sedes (`branches`, `GET /stores`),
pantalla de ayuda y contacto, asesoría técnica e ingeniería, formulario PQRS (`POST /pqrs` con
`Idempotency-Key`), calculadora BTU (`technical_tools`, tras `btuCalculatorEnabled` / `D-08`) con
filtro directo al catálogo (`RF-089`), barra superior de Inicio con Ayuda y Carrito con insignia
(`H1-03`) y medición agregada de «Más información» (`RF-065`, tras `NoOpAnalyticsSink`).

## Evidencia ejecutada (Windows 11, Flutter 3.50.0 / Dart 3.14)

| Puerta | Resultado |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | **exit 0** · 427 archivos, 0 cambios |
| `flutter analyze --fatal-infos` | **exit 0** · `No issues found!` |
| `dart run ci/check_layer_rules.dart` | **exit 0** · 0 violaciones (D1–D6, features MVP, paquetes prohibidos) |
| `dart run ci/check_public_config.dart` | **exit 0** · OK (`config/{dev,staging,prod}.json` y contrato) |
| `dart run ci/check_openapi_fixtures.dart` | **exit 0** · 121 fixtures (7 nuevos de `branches` y `support`), 44 esquemas |
| `dart run tool/merge_arb.dart --check` | **exit 0** · al día · 609 textos (14 partes) |
| `dart run ci/gen_coverage_helper.dart` | **exit 0** · 297 archivos de `lib/` importados |
| `flutter test --coverage` | **exit 0** · **1987 pruebas pasan**, 0 fallos (confirmado: sin pruebas en error) |
| `dart run ci/check_coverage.dart` | **exit 0** · global **95.0 %** · `core/session` **95.6 %** · `core/network` **98.4 %** · `features/cart/domain` **99.6 %** · `features/checkout/domain` **100.0 %** · `shared/formatting` **100.0 %** · `features/technical_tools/domain` **97.4 %** |

Cobertura por módulo de M5 (medida sobre `coverage/lcov.info` sin código generado):
* `lib/features/branches`: **84.3 %** (269 / 319 líneas)
* `lib/features/support`: **90.0 %** (587 / 652 líneas)
* `lib/features/technical_tools`: **97.3 %** (257 / 264 líneas)
* `lib/features/technical_tools/domain`: **97.4 %** (75 / 77 líneas)

## Qué se construyó

* **`core/config`** ([remote_config.dart](file:///c:/Users/empr16/ipr-app/lib/core/config/remote_config.dart), [remote_config_dto.dart](file:///c:/Users/empr16/ipr-app/lib/core/config/remote_config_dto.dart)):
  * Amplía `RemoteConfig` y `ContactDto` con `salesEmail`, `pqrsEmail` y `contact.engineering.{whatsapp,email}`, manteniendo tolerancia ante campos nulos y todos los interruptores apagados por defecto.
* **`branches`** (`lib/features/branches/`, `RF-072..076`):
  * Entidades puras (`Branch`, `BranchPhone`, `BranchPhoneType` incluyendo `mobile_secondary` de CR-057, `CityBranchGroup`, `groupBranchesByCity`), constructor seguro de enlace por dirección (`buildBranchMapsUri`, codificando acentos/`#`/`&`/`,` para `www.google.com/maps/search/?api=1&query=...` sin permisos de ubicación).
  * `ApiBranchesRepository` sobre `GET /stores` con caché SWR (`CachePolicy.stores`: 24 h fresca, 30 d obsoleta) y mapeo tolerante (`AC-076-4`: omite teléfonos, WhatsApp o imagen inválidos sin romper la sede).
  * `BranchesScreen` y `BranchDetailScreen`: accesibles sin sesión, agrupación por ciudad sin grupos vacíos, etiqueta «Próximamente» sin botones de acción, teléfonos corporativos (`tel:`), WhatsApp de sede específica (`openWhatsApp(phoneOverride:)` con alternativa `AC-063-1`), marcador cuando no hay imagen (`SC-043`) y «Cómo llegar».
* **`support` ampliado** (`lib/features/support/`, `RF-079, 080, 094..097`):
  * `HelpScreen` (`/support`): canales corporativos (WhatsApp asesoría, Cotizar por WhatsApp, teléfono `tel:`, correo de ventas con copia al portapapeles si no hay cliente de correo, PQRS, Ingeniería, Sedes e Información legal) sin prometer SLA y sin sesión.
  * `EngineeringScreen` (`/support/engineering`): servicios corporativos de aire acondicionado y refrigeración (sin nombres ni contactos personales de ingenieros, `AC-080-2`), WhatsApp corporativo (`engineeringWhatsapp` con respaldo al WhatsApp general `PA-06`), PBX y correo corporativo con alternativa de copiado (`AC-080-3`).
  * `PqrsScreen` (`/support/pqrs`): detrás de `pqrsEnabled` (falla cerrado), accesible sin sesión, validación exacta de `PqrsRequest` (nombre 3–120, correo ≤ 254, celular 7–20 según contrato vigente, pedido opcional ≤ 60, mensaje 1–1000 bloqueado en 1001 con contador y casilla + enlace a política de datos), `POST /pqrs` con `Idempotency-Key` (`ApiTimeouts.pqrs`), bloqueo de doble envío, limpieza tras HTTP 202, preservación ante offline/429/500 y **cero almacenamiento local o logs con PII** (`PqrsSubmission.toString` redactado).
* **`technical_tools`** (`lib/features/technical_tools/`, `RF-006, 085..089`) *(tras `btuCalculatorEnabled`)*:
  * Reglas puras (`BtuCalculator`) con la fórmula vigente de referencia (`COD §6`), validación de rangos y enteros estrictos, equivalencia coma/punto decimal, casos `T1..T10`, monotonía, 20 vectores con semilla fija (`RNF-092`) y construcción del slug `attr[pa_capacidad-btu]`.
  * `BtuCalculatorScreen` (`/tools/btu`): detrás de `btuCalculatorEnabled` (apagado por defecto hasta cierre de `D-08`), funciona sin sesión ni red, muestra siempre el aviso provisional de estimación, caso `> 36.000 BTU` con mensaje de exceso y contacto por WhatsApp prellenado, y botón «Ver equipos» hacia el catálogo filtrado (`Routes.btuCatalogList`).
* **Integración en `home`, `catalog`, `product_detail`, `shared` y `app`**:
  * `HomeScreen`: barra superior (`H1-03`) con acceso a Ayuda (`/support`) y Carrito con insignia (`homeCartCountProvider` conectado a `cartUnitCountProvider` en `lib/app/providers.dart` respetando D3); acceso a Calculadora BTU condicionado a `btuCalculatorEnabled` (`RF-006`).
  * `ProductListScreen` y `ListScope` (`RF-089`, `H1-04`): parámetro `btuSlug` (`?btu=9-000-btu..36-000-btu`) para precargar `FilterChoice(key: 'attr[pa_capacidad-btu]', ...)` como chip visible y removible.
  * `PurchaseBox` (`RF-065`): al tocar «Más información» en productos sin precio, envía `{product_id, timestamp}` (cero PII) al `analyticsSinkProvider` sin bloquear ni retrasar WhatsApp ante fallo.
  * Rutas reales registradas en [app_router.dart](file:///c:/Users/empr16/ipr-app/lib/app/router/app_router.dart).

## Decisiones pendientes que condicionan este código

| Decisión | Tratamiento en M5 |
|---|---|
| **D-08** fórmula BTU, rangos y texto de estimación | `BtuCalculatorScreen` y su acceso en `HomeScreen` están apagados por defecto (`btuCalculatorEnabled = false` hasta respuesta de `/config`). La fórmula usa `COD §6` con aviso provisional en `l10n`. |
| **CR-055** teléfono en `POST /pqrs` | Se mantiene obligatorio (7–20 caracteres) conforme al esquema `PqrsRequest` de `contract/openapi.yaml`. |
| **PA-08 / D-12** analítica en `RF-065` | Aislado tras `AnalyticsSink` (`NoOpAnalyticsSink` en producción mientras no se adopte herramienta ni flujo de consentimiento). |
| **PA-06 / ADR-001** contenido y canal de ingeniería | Servicios generales en `l10n` sin endpoint dedicado; canales leídos de `contact.engineering` en `/config` con respaldo al WhatsApp general. |
| **D-09 / RF-077** coordenadas y horarios de sedes | No implementados en el MVP; «Cómo llegar» busca por dirección textual. |

## Hallazgos abiertos

| ID | Hallazgo |
|---|---|
| H5-01 | `ExternalUrlPolicy` continúa bloqueando `mailto:` (`H1-01` / `H2-01`): `HelpScreen` y `EngineeringScreen` llaman a `ExternalLauncher.open(mailto:)` (verificable con doble) y en producción caen al copiado en portapapeles con confirmación visual hasta que `core` habilite `mailto:` o defina política alternativa. |
| H5-02 | En `ProductListScreen`, el filtro inicial `RF-089` asume los slugs `9-000-btu`..`36-000-btu` para `attr[pa_capacidad-btu]` según `FilterDimension.btu.json` y `AC-089-1`; la disponibilidad real del atributo en WooCommerce depende de `D-10` / `RF-014`. |
| H5-03 | El servidor de vista previa (`tool/preview/main.dart`) sigue abierto en segundo plano y las sedes/PQRS en esa vista usan respuestas sintéticas de `tool/mock_bff`; los cambios de M5 no han sido commiteados en Git. |

## Lo que NO se pudo verificar en esta máquina

* Ejecución en dispositivo Android/iOS real ni emulador.
* Entrega real de correos PQRS en buzón corporativo y contador compartido de `429` entre instancias del BFF (`TC-131`, `TC-153`), URLs reales de mapas de las 31/32 sedes (`AC-075-5`) y disponibilidad real del atributo `pa_capacidad-btu` contra WooCommerce de staging (`D-10`).
* Validación oficial de Ingeniería (`D-08`), definición de `PA-06`, `PA-07`, `PA-08` y textos finales aprobados (`TC-143`).

## Siguiente

Con M0–M5 completados y verificados en entorno local: revisar los cambios acumulados (M2–M5 + `android/`) para proponer commit si lo apruebas, y validar contra el BFF real en staging.

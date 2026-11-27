# IPR Partes y Repuestos — app móvil (Flutter)

App de Android e iOS de IPR Partes y Repuestos (Inverprimos S.A.S.). Consume
**solo** el BFF versionado `/mobile/v1` (ADR-001): nunca WooCommerce (`wc/v3`),
WordPress (`wp/v2`) ni las rutas `/api/*` del sitio.

**Estado: rebanada M0 (Fundación).** Está construido el núcleo (`core/`,
`shared/`, `app/`), las herramientas de calidad y el BFF simulado. **Aún no hay
ninguna feature de negocio** (catálogo, carrito, checkout...): las pantallas son
marcadores de posición hasta M1–M5. Ver `docs/project/implementation_plan.md`.

Toda la documentación está en [`docs/`](docs/README.md). Las únicas decisiones
**aprobadas** son ADR-001 y ADR-002 (más D-03, D-04 y D-06); el resto son
propuestas. En caso de contradicción entre documentos, manda
`docs/project/resolucion_inconsistencias.md`.

## Requisitos

* Flutter **3.50.0** / Dart 3.14 (fijado en `.flutter-version` y `.fvmrc`).
* Para compilar Android: JDK 17 y Android SDK (no necesarios para analizar y probar).
* Para compilar iOS: macOS y Xcode (ver `ios/FLAVORS.md`).

## Primeros pasos

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs   # freezed, json_serializable
```

Ejecutar con la configuración pública del flavor (ADR-009, nunca secretos):

```bash
# BFF simulado local (contrato de contract/openapi.yaml)
dart run tool/mock_bff/main.dart            # http://127.0.0.1:8787/mobile/v1
dart run tool/mock_bff/main.dart --demo     # + catálogo, marcas y sedes parecidos a los reales

flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json
```

## Puertas de calidad (QG-M01..M12)

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
dart run ci/check_layer_rules.dart          # D1–D6, features del MVP, paquetes prohibidos
dart run ci/check_public_config.dart        # config/*.json públicos y contrato fijado
dart run ci/check_openapi_fixtures.dart     # fixtures frente a contract/openapi.yaml
dart run ci/gen_coverage_helper.dart && flutter test --coverage
dart run ci/check_coverage.dart             # ≥ 70 % global, ≥ 90 % en módulos críticos
```

## Estructura

```
lib/
  main_{dev,staging,prod}.dart   un punto de entrada por flavor
  app/        bootstrap, app, router (StatefulShellRoute + guardas + deep_link_policy)
  core/       config, network (Dio + 5 interceptores), session, storage, errors,
              external, observability, lifecycle   — sin UI de negocio
  shared/     design_system, widgets, domain (Money, PriceStatus...), formatting
  features/   (vacío hasta M1) solo las 12 del MVP; sin favorites/notifications/quotes/content
config/       dev|staging|prod.json — configuración PÚBLICA por flavor
contract/     copia fijada de openapi.yaml + su huella SHA-256
ci/           verificadores (capas, cobertura, configuración, fixtures)
tool/         BFF simulado (shelf) y validador/sintetizador del contrato
deploy/       plantillas .well-known para App Links / Universal Links (van en el dominio web)
docs/         documentación de arquitectura, requisitos, seguridad, calidad, DevOps
```

## Lo que M0 NO resuelve (decisiones y datos pendientes)

Aislado detrás de interfaces, interruptores remotos o configuración pública; no
se inventó ningún dato. Detalle en `docs/project/decisiones_pendientes.md`.

| Pendiente | Cómo está aislado |
|---|---|
| Proveedor de reporte de fallos (DN-02) | `CrashReporter`/`AnalyticsSink` con adaptador `NoOp`; `PiiScrubber` obligatorio |
| Calculadora BTU / fórmula (D-08) | `features.btuCalculatorEnabled` remoto, apagado por defecto |
| Textos legales y retención (D-12) | Llegan por `/config` (`legal`); nada incrustado |
| `applicationId`/bundle definitivo y cuentas de tienda (D-14) | `co.ipr.app` provisional en `build.gradle.kts`; plantillas `deploy/` con `REEMPLAZAR_*` |
| Mínimos de Android/iOS (DN-01, SPK-02) | Se hereda lo que fija Flutter |
| Navegador seguro en iOS (CR-004, SPK-01) | Interfaz `SecureBrowser`; hoy `url_launcher` |
| Verde oficial de la marca (APR-01) | `#5BA628` solo decorativo; texto con derivados propuestos |
| Staging y Wompi sandbox (C2) | `staging.json` con host de pruebas `.invalid` |

# Guía para agentes que implementan una feature de la app

> Documento de trabajo del **orquestador** para repartir una rebanada (M1..M5) entre
> varios agentes en paralelo sin que se pisen. Aplica a cualquier rebanada.
> Jerarquía de fuentes: `docs/03_architecture/architecture_decisions.md` (solo
> ADR-001 y ADR-002 están aprobadas) → `docs/project/resolucion_inconsistencias.md`
> (CR-001..089 prevalecen sobre cualquier otro documento) → `docs/05_api/` →
> `docs/06_security/` → `docs/03_architecture/flutter_app_architecture.md` y
> `docs/04_database/` → `docs/07_ux_ui/` → `docs/08_quality/`, `docs/09_devops/`.
> El estado real de lo ya construido está en `docs/project/m0_resultados.md` y en el
> código.

## 1. Reglas duras

1. **No inventes** secretos, endpoints, campos de API, fórmulas (D-08), textos legales
   (D-12) ni reglas de negocio. Lo que falte: `DESCONOCIDO` en el informe y aislado
   detrás de una interfaz, un interruptor de `RemoteConfig` o la configuración pública.
2. La app **solo** consume `/mobile/v1` (ADR-001) mediante `ApiClient`
   (`apiClientProvider`). Nunca `wc/v3`, `wp/v2` ni `/api/*` del sitio.
3. **Cero dependencias nuevas.** No toques `pubspec.yaml`. Paquetes prohibidos: ver
   `ci/src/layer_rules.dart` (`prohibitedPackages`).
4. Nada de datos personales en disco, logs, caché ni mensajes de error. Los textos
   escritos por el usuario (p. ej. el término de búsqueda) no se registran.
5. Precio y disponibilidad son **informativos**: el servidor decide. Sin precio =
   "Más información" y **nunca "$0"**. "Bajo pedido" **no** es comprable (CR-017).
6. Ningún texto de interfaz incrustado: todo por l10n (`AppLocalizations`).
7. Reglas de capas D1–D6: `dart run ci/check_layer_rules.dart` debe dar 0 violaciones
   en TU carpeta.

## 2. Propiedad de archivos (para trabajar en paralelo)

| Puedes crear/editar | No toques (pide el cambio en tu informe) |
|---|---|
| `lib/features/<tu_feature>/**` | `pubspec.yaml`, `pubspec.lock` |
| `test/unit/features/<tu_feature>/**` | `lib/core/**`, `lib/shared/**`, `lib/app/**` |
| `test/widget/features/<tu_feature>/**` | `test/mocks/**` (léelos y úsalos) |
| `test/fixtures/<tu_feature>/**` | `ci/**`, `tool/**`, `config/**`, `contract/**` |
| `l10n/parts/<NN>_<tuFeatureEnCamelCase>.arb` (p. ej. `50_productDetail.arb`) | `l10n/parts/00_core.arb`, `l10n/parts/10_shared.arb`, `l10n/app_es.arb` |
| | `docs/**` (el informe va en tu mensaje final) |

Si necesitas un cambio en algo de la columna derecha (un widget compartido, una ruta,
una clave de `RemoteConfig`, un mock), **no lo edites**: descríbelo con precisión en
tu informe (archivo, qué, por qué) y trabaja con una solución local provisional.

## 3. Estructura de una feature

```
lib/features/<f>/
├── <f>.dart                  API pública: SOLO las pantallas de nivel de ruta (`export` de los
│                             `*Screen` con constructor `const` y parámetros simples, p. ej.
│                             `ProductDetailScreen(slug: ...)`). El orquestador declara los
│                             `GoRoute` en `lib/app/router/app_router.dart` y los lee de aquí.
├── presentation/{screens,widgets,controllers}/
├── domain/{entities,repositories,usecases}/   repositories = `abstract interface class`;
│                                              usecases solo si orquestan >1 repo o tienen reglas
└── data/{dtos,mappers,datasources,repositories}/
```

* `domain/` **no** importa Flutter, Riverpod, Dio, Hive ni `dtos/` (D2).
* Los widgets no llaman a repositorios ni a `ApiClient`; solo observan controladores
  (`Notifier`/`AsyncNotifier` Riverpod, **sin** `riverpod_generator`) (D4).
* Los DTO no salen de `data/` (D5). La UI trabaja con entidades.
* Ninguna feature importa SDK de terceros (`dio`, `hive_ce`, `url_launcher`,
  `shared_preferences`...): pasa por `core/` o `shared/` (D6). `ApiClient`,
  `CacheStore`, `ExternalLauncher` y compañía se obtienen de `core/providers.dart`.
* Una feature **no** importa archivos de otra (D3). Comparten por `shared/` y `core/`.
* Navegación: constantes y constructores de `shared/navigation/routes.dart` (`Routes`,
  `Routes.product(slug)`, `Routes.categoryList(slug)`...). `go_router` se puede
  importar. Nada de cadenas de ruta sueltas.

### Patrones obligatorios

* **Repositorios** devuelven `Result<T>` (`core/network/result.dart`) y `AppFailure`;
  ninguna excepción de red llega a la UI. `Err(NotFound())` ≠ `Err(ServiceUnavailable())`
  (RF-009, TC-104).
* **Mapeo tolerante**: campos ausentes o valores nuevos no rompen (`StockStatus.fromContract`,
  `PriceStatus.fromContract`, `ImageRef.tryFromJson`). Precio 0/nulo → `OnRequest`.
* **Estado de UI cerrado**: `UiState<T>` (`UiLoading`, `UiData(stale)`, `UiEmpty`,
  `UiFailure`) y los widgets `AsyncView`, `ErrorState`, `EmptyState`, `StaleBanner`.
  `UiEmpty` solo cuando el servidor respondió 200 con lista vacía.
* **Paginación infinita**: un error al cargar la página N **no** borra las anteriores.
* **Caché SWR** con `CacheStore` + `CachePolicy` (taxonomía 1 h/7 d; listados y fichas
  5 min/24 h): dato guardado marcado `stale` + `StaleBanner`; si la red falla y hay
  caché, se muestra la caché; sin caché, `ErrorState` con "Reintentar". Un fallo de red
  **nunca** borra la caché.
* **Cancelación**: `CancelToken` al salir de pantalla y en sugerencias (debounce 300 ms).
* **DTO** con `json_serializable` (`@JsonSerializable(createToJson: false)`) o, si es
  más simple, `fromJson` manual tolerante. Genera con `dart run tool/codegen.dart`.
* **Accesibilidad** (WCAG 2.2 AA): objetivos ≥ 48 dp, texto hasta 200 % sin desbordar
  (contenido desplazable), `Semantics` en español, texto + ícono (nunca solo color),
  `MediaQuery.disableAnimations`. Reutiliza `shared/widgets` (`ProductCard`, `PriceText`,
  `StockBadge`, `WhatsAppButton`, `ProductImage`) y los tokens de `shared/design_system`.
  Color verde `#5BA628`: solo decorativo (nunca texto).
* Imágenes **solo** con `ProductImage` (lista blanca `mediaHosts`, SC-043).
* WhatsApp **solo** con `WhatsAppButton`/`openWhatsApp` y los mensajes
  `sharedWhatsappMsg*` del l10n compartido (con alternativa si falla, RF-063).

## 4. Textos (l10n)

Escribe SOLO en `l10n/parts/<NN>_<feature>.arb`; **toda clave empieza por el nombre de
la feature en camelCase** (`catalogFilterTitle`, `searchEmptyTitle`...). Con
marcadores `{x}` declara `@clave` con `placeholders`. Reutiliza las claves de
`00_core.arb` (`actionRetry`, `stateEmptyTitle`, `priceConsult`...) y `10_shared.arb`.
Tras editar: `dart run tool/codegen.dart` (fusiona, genera l10n y código; **con
candado**: si otro agente genera, espera y reintenta solo).

## 5. Pruebas

* Nombre: `TC-nnn · AC-xxx-n · descripción` cuando exista el caso en
  `docs/08_quality/test_cases.md` / criterio en `docs/02_requirements/acceptance_criteria.md`
  (búscalos por RF); si no existe: `M1 · RF-xxx · descripción`.
* Herramientas ya disponibles (léelas en `test/mocks/`): `FakeHttpAdapter` (cola de
  respuestas), `buildTestClient`, `pumpApp` (con `overrides` y `textScale`),
  `testOverrides` + `FakeExternalLauncher`, `InMemory*`.
* Repositorios y controladores se prueban con `FakeHttpAdapter` o dobles de la
  interfaz de `domain`. Los widgets, con `overrides` de los repositorios.
* Casos mínimos por pantalla: carga, datos, vacío (200 vacío), error de red (con
  "Reintentar"), error 404 vs 503, datos obsoletos con aviso, texto al 200 % sin
  desbordar y las guías `androidTapTargetGuideline`, `iOSTapTargetGuideline`,
  `labeledTapTargetGuideline`, `textContrastGuideline`.
* Fixtures de contrato en `test/fixtures/<feature>/` con un `manifest.json`
  (`{"fixtures":[{"file","schema","path"?,"valid"}]}`) que
  `dart run ci/check_openapi_fixtures.dart` valida contra `contract/openapi.yaml`.
* Cobertura de tu módulo ≥ 80 % (global ≥ 70 %).

## 6. Comandos (siempre con Flutter en el PATH)

```bash
export PATH="/c/Users/empr16/tools/flutter/bin:$PATH"; cd /c/Users/empr16/ipr-app
dart run tool/codegen.dart                       # textos + código generado (serializado)
dart format lib/features/<f> test/unit/features/<f> test/widget/features/<f> test/fixtures/<f>
dart fix --apply lib/features/<f>                # solo tu carpeta
flutter analyze --fatal-infos lib/features/<f> test/unit/features/<f> test/widget/features/<f>
flutter test test/unit/features/<f> test/widget/features/<f>
dart run ci/check_layer_rules.dart               # atiende solo lo que sea tuyo
dart run ci/check_openapi_fixtures.dart
```

**No ejecutes** `flutter test` completo ni `dart format .` ni `dart fix --apply` sobre
todo el árbol (hay otros agentes con trabajo a medias), ni `build_runner` directo, ni
`flutter pub get`. El orquestador corre las puertas completas al integrar.

## 7. Informe final (máx. 250 palabras)

Archivos creados, nº de pruebas y cobertura de tu módulo, RF/AC/TC cubiertos,
decisiones y desviaciones (con evidencia), **lo que necesitas del orquestador**
(rutas, claves de l10n compartidas, cambios en `core/`/`shared/`/mocks), `DESCONOCIDO`
y preguntas abiertas. No declares cumplido nada que no hayas ejecutado.

# Arquitectura detallada de la app Flutter — IPR

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Tercera entrega: Arquitectura. **No se programa la app.** Los fragmentos de código son ilustrativos de contratos internos, no implementación. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para aprobación. Las ADR citadas (ADR-003 a ADR-012) están en estado **Propuesta** en [`architecture_overview.md`](architecture_overview.md) §9. |
| **Base** | ADR-001 y ADR-002 (Aprobadas) · RF y RNF de `docs/02_requirements/` · discovery en `docs/00_discovery/` |
| **Fuera de alcance** | Diseño de endpoints `/mobile/v1` y de la autenticación del servidor: **en elaboración** en `docs/05_api/`. Aquí solo se define el lado cliente. |

**Convenciones:** HECHO / SUPUESTO / PROPUESTA / PENDIENTE / RIESGO / DESCONOCIDO, como en `architecture_overview.md`. Abreviaturas: `COD`, `INV`, `WCA`, `ADR`, `DP`, `RF`, `RNF`, `FE:` (ruta en `ipr-frontend`), `N-xx`/`T-xx` (necesidades de API, overview §7), `RA-xx` (riesgos, overview §8), `SPK-xx` (spikes técnicos, §19).

---

## 1. Plataforma base

| Elemento | Valor propuesto | Estado | Evidencia / nota |
|---|---|---|---|
| Flutter | **3.50.0** (estable, 2026-11-11) | Verificado | Manifiesto oficial de versiones de Flutter (`releases_windows.json`, `current_release.stable`), consultado 2026-11-18. Se fija la versión en el repositorio (p. ej. FVM o `.flutter-version`) — RNF-094. |
| Dart | **3.14** (incluido en Flutter 3.50) | Verificado | Mismo manifiesto. Varios paquetes exigen Dart ≥ 3.12 y Flutter ≥ 3.44 (Riverpod 3.x, go_router 18, Firebase, cached_network_image); freezed 4.0.3 y very_good_analysis 11 exigen Dart ≥ 3.13. |
| Android mínimo | Propuesta DN-01: **API 26 (Android 8.0)** | **PENDIENTE** | El mínimo real lo impone Flutter 3.50 + plugins: **NO VERIFICADO** → SPK-02. |
| iOS mínimo | Propuesta DN-01: **iOS 15.0** | **PENDIENTE** | Ídem. Nota: el *callback* https de `ASWebAuthenticationSession` requiere iOS 17.4 (ADR-008). |
| Orientación | Vertical optimizada; horizontal y tablet "usables" | PENDIENTE DN-11 | RNF-081. |
| Idioma | es-CO único en el MVP | PROPUESTA | RNF-084. |

---

## 2. Estructura de carpetas (Feature-First)

### 2.1 Árbol propuesto

```
ipr_app/
├── android/  ios/                      → proyectos nativos (flavors, App Links, Universal Links, backup)
├── config/
│   ├── dev.json  staging.json  prod.json   → configuración PÚBLICA por flavor (--dart-define-from-file)
├── l10n/
│   └── app_es.arb  (es-CO)              → textos externalizados (gen-l10n)
├── assets/  (logos, ilustraciones de estados vacíos, fuentes con licencia verificada)
├── lib/
│   ├── main_dev.dart  main_staging.dart  main_prod.dart   → un punto de entrada por flavor
│   ├── app/
│   │   ├── bootstrap.dart              → inicializa almacenamiento, observabilidad, ProviderScope
│   │   ├── app.dart                    → MaterialApp.router, tema, localización
│   │   ├── router/
│   │   │   ├── app_router.dart         → GoRouter, StatefulShellRoute, redirect de sesión
│   │   │   ├── routes.dart             → nombres/paths de rutas (única fuente)
│   │   │   └── deep_link_policy.dart   → lista cerrada de rutas aceptadas desde enlaces
│   │   └── flavor.dart                 → enum Flavor + AppConfig (leído de dart-define)
│   ├── core/                           → infraestructura, SIN UI de negocio, SIN importar features
│   │   ├── config/                     → AppConfig, RemoteConfig (N-01), versión mínima, interruptores
│   │   ├── network/                    → ApiClient (Dio), interceptores, mapeo de errores, Result
│   │   ├── session/                    → SessionController, TokenStore, AuthInterceptor, InstallationId
│   │   ├── storage/                    → SecureKeyValue, CacheStore, PreferencesStore (interfaces + impl.)
│   │   ├── errors/                     → AppFailure (sealed), mensajes es-CO por código
│   │   ├── external/                   → SecureBrowser (navegador seguro), ExternalLauncher (wa.me/tel/mapas)
│   │   ├── observability/              → CrashReporter, AnalyticsSink, PiiScrubber, logger de depuración
│   │   └── lifecycle/                  → AppLifecycleObserver (primer plano/segundo plano)
│   ├── shared/                         → reutilizable por varias features
│   │   ├── design_system/              → tokens (color, tipografía, espaciado), tema, componentes
│   │   ├── widgets/                    → AsyncView, EmptyState, ErrorState, StaleBanner, PriceText, ProductCard…
│   │   ├── domain/                     → tipos de valor transversales: Money (COP), ProductRef, PriceStatus, StockStatus
│   │   └── formatting/                 → formato COP, fechas dd/MM/aaaa, America/Bogota
│   └── features/
│       ├── authentication/   → login, registro, recuperar contraseña, consentimiento (UI); usa core/session
│       ├── home/             → inicio: buscador, categorías raíz, destacados, accesos
│       ├── catalog/          → categorías, listados con filtros/orden, marcas, liquidaciones
│       ├── search/           → búsqueda, sugerencias, estado sin resultados
│       ├── product_detail/   → ficha, galería, atributos, "Añadir al carrito" / "Más información"
│       ├── cart/             → carrito local, revalidación de precio/stock
│       ├── checkout/         → orquestación del traspaso, espera y verificación del resultado
│       ├── orders/           → historial y detalle de pedidos
│       ├── branches/         → sedes por ciudad, ficha de sede, llamar/WhatsApp/cómo llegar
│       ├── technical_tools/  → calculadora BTU (lógica local pura)
│       ├── support/          → ayuda/contacto, PQRS, legales, asesoría técnica (módulo J)
│       └── profile/          → perfil, contraseña, direcciones, eliminar cuenta, derechos del titular
└── test/  integration_test/  (espejo de lib/; ver §15)
```

Cada feature sigue la misma forma interna:

```
features/<feature>/
├── <feature>.dart            → API pública de la feature (solo rutas y lo que otra capa pueda necesitar)
├── presentation/
│   ├── screens/              → pantallas (widgets de ruta)
│   ├── widgets/              → widgets propios de la feature
│   └── controllers/          → Notifier/AsyncNotifier (estado de pantalla)
├── domain/
│   ├── entities/             → modelos inmutables del negocio (Freezed)
│   ├── repositories/         → interfaces (abstract interface class)
│   └── usecases/             → SOLO si orquestan >1 repositorio o contienen reglas (ADR-003)
└── data/
    ├── dtos/                 → modelos del contrato /mobile/v1 (json_serializable)
    ├── mappers/              → DTO → entidad (tolerantes a nulos y valores desconocidos)
    ├── datasources/          → remotos (ApiClient) y locales (CacheStore)
    └── repositories/         → implementación de la interfaz de domain
```

### 2.2 Ajustes respecto al árbol del prompt maestro (y por qué)

| Ajuste | Razón técnica | Requisito |
|---|---|---|
| **Sesión en `core/session`**, no en `features/authentication` | El interceptor HTTP (core) necesita los tokens y el estado de sesión; si vivieran en una feature, `core` dependería de una feature (viola la regla de dependencia). `authentication` queda con la UI y los casos de uso de login/registro. | RNF-028, RNF-034 |
| **Marcas y liquidaciones dentro de `catalog`** | Son listados de productos con el mismo DTO, paginación y filtros; separarlos duplicaría capa de datos. Tienen sus propias pantallas dentro de la feature. | RF-016, RF-018 |
| **Asesoría técnica (módulo J) y legales dentro de `support`** | En el MVP son contenido + canales corporativos (RF-079, RF-080, RF-099); no justifican una feature con capa de datos propia. Se separa si llega el formulario de ingeniería (RF-081, fase 2). | RF-079, 080, 095, 099 |
| **`orders` separada de `profile`** | Tiene contrato, estados y relación directa con `checkout` (resultado del pago); `profile` es edición de datos personales. | RF-107, RF-108 |
| **`branches` (sedes)** con nombre en inglés | Convención de nombres de carpetas en inglés en todo el código; los textos de UI en es-CO. | RNF-084 |
| **Features de fase 2 NO se crean** (`favorites`, `notifications`, `quotes`, `content`/blog) | P3 (proporcionalidad). La estructura admite añadirlas sin tocar las demás. | ADR-002; RF módulos G, H, L |
| `shared/domain` con tipos de valor | `Money`, `PriceStatus`, `StockStatus`, `ProductRef` se usan en catálogo, ficha, carrito y pedidos; definirlos una vez evita conversiones y reglas divergentes ("nunca $0"). | RF-012, RNF-107 |

---

## 3. Reglas de dependencia entre capas y features

### 3.1 Reglas

| # | Regla | Cómo se verifica |
|---|---|---|
| D1 | `features → shared → core`. `core` no importa `shared` ni `features`; `shared` no importa `features`. | Script de CI que analiza `import` (o regla de análisis personalizada); falla el PR. |
| D2 | Dentro de una feature: `presentation → domain ← data`. `domain` **no** importa Flutter (`package:flutter`), Dio, Hive ni DTOs. | Mismo script: `domain/` solo puede importar `dart:*`, `shared/domain`, `core/errors` y anotaciones de Freezed. |
| D3 | Una feature **no** importa archivos internos de otra; solo su archivo público `<feature>.dart` (rutas y, excepcionalmente, un tipo). | Script de CI: import a `features/x/(presentation|domain|data)/` desde `features/y/` = error. |
| D4 | Los widgets no llaman a repositorios ni a `ApiClient`; solo leen/observan controladores (providers). | Revisión de código + script (import de `data/` desde `presentation/` = error). |
| D5 | Los DTO nunca salen de `data/`; la UI trabaja con entidades. | Script (import de `dtos/` fuera de `data/`). |
| D6 | Ninguna feature llama a SDK de terceros directamente (Firebase/Sentry, url_launcher, secure storage): siempre a través de interfaces de `core`. | Script (lista de paquetes permitidos por carpeta). |

### 3.2 Comunicación entre features (sin importarse)

| Necesidad | Mecanismo | Ejemplo |
|---|---|---|
| Navegar a otra feature | Ruta con nombre (`routes.dart`) | Resultado BTU → listado de catálogo filtrado por capacidad (`RF-089`). |
| Estado transversal | Provider de `core` | `sessionStateProvider` (autenticado/anónimo/expirado) lo leen checkout, orders, profile y el router. |
| Añadir al carrito desde la ficha | `product_detail` depende de la **API pública** de `cart` (`cart.dart` exporta `CartActions`) | Dependencia explícita y única entre features, aceptada por D3. |
| Vaciar carrito tras pago confirmado | `checkout` usa la API pública de `cart` | Solo cuando el servidor confirma (RF-057). |
| Datos de producto en el carrito | `cart` tiene **su propio** datasource para la consulta por lote (N-05) | No reutiliza `catalog/data`: contrato distinto y ciclo de vida distinto. |

---

## 4. Responsabilidades por capa

| Capa | Contiene | No contiene | Pruebas |
|---|---|---|---|
| **presentation** | Pantallas, widgets, controladores (Notifier) que convierten `Result` en estados de UI; textos vía `AppLocalizations`; semántica de accesibilidad. | Lógica de negocio, parsing JSON, llamadas HTTP. | Widget + golden. |
| **domain** | Entidades inmutables, interfaces de repositorio, casos de uso con reglas (límites del carrito 1–99 y 100 líneas; elegibilidad de compra; fórmula BTU; máquina de estados del checkout). | Flutter, Dio, Hive, DTOs. | Unitarias puras (rápidas). |
| **data** | DTOs (json_serializable), mapeadores tolerantes, datasources remotos/locales, implementación de repositorios, política de caché por recurso. | Widgets, textos de UI. | Unitarias con *fixtures* JSON del contrato + datasources simulados. |
| **core** | Red, sesión, almacenamiento, errores, configuración, observabilidad, navegador seguro, ciclo de vida. | Conocimiento de productos, carrito, etc. | Unitarias e integración. |
| **shared** | Design system, widgets genéricos, tipos de valor y formato. | Llamadas a red. | Golden y unitarias. |

---

## 5. Gestión de estado e inyección de dependencias (ADR-004)

### 5.1 Convenciones

| Tipo de estado | Herramienta | Ejemplos | Ciclo de vida |
|---|---|---|---|
| Dependencias (servicios, repositorios) | `Provider` | `apiClientProvider`, `catalogRepositoryProvider` | Vive con la app; se sustituye con `overrides` en pruebas. |
| Estado global mutable | `NotifierProvider` (`keepAlive`) | `sessionControllerProvider`, `cartControllerProvider`, `remoteConfigProvider` | Toda la sesión de la app. |
| Datos de pantalla asíncronos | `AsyncNotifierProvider.autoDispose` (con `family` por parámetro) | Listado por filtros, ficha por slug, pedido por número | Se libera al salir de la pantalla; caché de datos la gestiona el repositorio, no el provider. |
| Estado efímero de formulario | Controlador local o `Notifier.autoDispose` | Login, PQRS, calculadora BTU | Solo en memoria (nunca persistido: PQRS contiene PII). |

### 5.2 Reglas

- Un controlador expone un **estado de UI cerrado** (`sealed`): `Loading`, `Data`, `Empty`, `Failure(AppFailure)`, y cuando aplica `Data(stale: true)`.
- La paginación infinita se modela en el controlador (`items`, `page`, `hasMore`, `isLoadingMore`, `loadMoreFailure`) para que un error al cargar la página N no borre las páginas anteriores.
- **Sin `riverpod_generator` en el MVP** (ADR-004): menos dependencia de `build_runner` en la capa de estado; se reevalúa.
- El `ProviderScope` raíz se crea en `bootstrap.dart` con los *overrides* del flavor (p. ej. `AppConfig`).

---

## 6. Navegación y deep links (ADR-005, ADR-008)

### 6.1 Mapa de rutas (PROPUESTA; la estructura de pestañas se valida con UX)

| Ruta | Pantalla | Feature | Requiere sesión | Deep link | RF |
|---|---|---|---|---|---|
| `/` (pestaña Inicio) | Inicio | home | No | No | A |
| `/catalog` (pestaña Catálogo) | Árbol de categorías | catalog | No | No | RF-010 |
| `/catalog/list?category=&brand=&attr…` | Listado filtrado | catalog | No | No | RF-011–015 |
| `/catalog/brands`, `/catalog/brands/:slug` | Marcas | catalog | No | No | RF-016 |
| `/catalog/sale` | Liquidaciones | catalog | No | No | RF-018 |
| `/search?q=` | Búsqueda | search | No | No | C |
| `/product/:slug` | Ficha | product_detail | No | **Fase 2** (`/producto/{slug}`, RF-036) | D |
| `/branches` (pestaña Sedes), `/branches/:slug` | Sedes | branches | No | No | I |
| `/cart` (pestaña Carrito) | Carrito | cart | No | No | RF-049–051 |
| `/checkout` | Orquestador del pago | checkout | **Sí** | No | RF-052–058 |
| `/checkout/result` | Resultado verificado | checkout | **Sí** | Destino interno del enlace `/pedido-confirmado` | RF-055, RF-056 |
| `/account` (pestaña Cuenta) | Cuenta o acceso (según sesión) | profile / authentication | No | No | E, N |
| `/login`, `/register`, `/password-recovery` | Autenticación | authentication | No | No | RF-038–042 |
| `/orders`, `/orders/:number` | Pedidos | orders | **Sí** | No | RF-107, RF-108 |
| `/account/profile`, `/account/addresses`, `/account/delete` | Perfil | profile | **Sí** | No | RF-104–111 |
| `/tools/btu` | Calculadora BTU | technical_tools | No | No | K |
| `/support`, `/support/pqrs`, `/support/legal`, `/support/engineering` | Ayuda | support | No | No | J, M |
| `/update-required` | Versión mínima | core/config | No | No | RNF-029 |

- **Guardas (`redirect`)**: si la ruta exige sesión y el estado es anónimo/expirado → `/login?from=<ruta>`; al iniciar sesión se vuelve a `from` (lista cerrada de rutas internas, nunca URLs externas). El carrito no se toca (RF-044).
- **Pila por pestaña** con `StatefulShellRoute.indexedStack` (cada pestaña conserva su historial).

### 6.2 Deep links

| Aspecto | Decisión | Estado |
|---|---|---|
| Mecanismo | Manejador por defecto de Flutter + go_router; **sin** `app_links` (evita el conflicto documentado por Flutter). | PROPUESTA (ADR-005) |
| Rutas declaradas en `assetlinks.json` / `apple-app-site-association` | MVP: **solo** `/pedido-confirmado`. Fase 2: `/producto/*`. Nunca comodines globales (el sitio web seguiría abriéndose en la app para cualquier ruta). | PROPUESTA; alojamiento PENDIENTE (DA-03, COD §8.3) |
| Política de entrada (`deep_link_policy.dart`) | Se aceptan solo los hosts del flavor y las rutas listadas; los parámetros se validan (`order` numérico, `status` dentro de un conjunto conocido) y se tratan como **pista**. Cualquier otro enlace → Inicio. | PROPUESTA (RNF-046) |
| `/pedido-confirmado` con la app en mitad del checkout | La ruta **no** muestra el resultado directamente: notifica al `CheckoutController`, que consulta N-12 y navega a `/checkout/result`. | PROPUESTA (ADR-008) |
| `/pedido-confirmado` sin checkout en curso (p. ej. enlace antiguo) | Abre "Mis pedidos" (si hay sesión) o Inicio; nunca muestra "pago exitoso". | PROPUESTA |
| Dominio por flavor | dev/staging usan sus propios dominios y archivos `.well-known`; DESCONOCIDO si existen dominios de staging (COD §8.2). | PENDIENTE |

### 6.3 Flujo del checkout (máquina de estados del `CheckoutController`)

| Estado | Entrada | Acción | Salida |
|---|---|---|---|
| `idle` | Toque en "Pagar" (botón se deshabilita) | Verificar sesión | `revalidating` / `/login` |
| `revalidating` | — | N-05: precio y disponibilidad de cada línea | `needsReview` (cambios, ítems no disponibles: RF-050) / `requestingTicket` |
| `requestingTicket` | — | N-11 con clave de idempotencia del intento (generada una vez por intento; timeout 20 s, RNF-021; **sin** reintento automático) | `openingBrowser` / `failure` |
| `openingBrowser` | URL recibida | Validar que la URL sea `https` y de un host permitido (RNF-045c); abrir **inmediatamente** el navegador seguro (RNF-013) | `awaitingResult` |
| `awaitingResult` | Enlace `/pedido-confirmado` **o** app vuelve a primer plano **o** se cierra el navegador | Consultar N-12 | `verifying` |
| `verifying` | — | Consultar N-12 con espera creciente hasta ≈ 2 min (RNF-025) | `paid` / `pending` / `failed` / `cancelled` / `noOrder` |
| `paid` | — | Vaciar carrito (RF-057); mostrar número y estado | Fin |
| `pending` | — | Conservar carrito; mensaje "pago en verificación" + acceso a Mis pedidos | Fin |
| `failed` / `cancelled` / `noOrder` | — | Conservar carrito; permitir reintentar (nuevo intento, nueva clave) | `idle` |
| `ticketExpired` | Error tipado de ticket vencido/inválido | **Un** reintento automático de ticket (RNF-026) | `requestingTicket` / `failure` |

- El estado `awaitingResult` + identificador del intento se guarda en `CacheStore` (sin PII) para sobrevivir a que el SO mate la app mientras el usuario paga; al relanzar, se reanuda en `verifying`.
- Navegador seguro: `SecureBrowser` (core/external) con implementación elegida en **SPK-01**: (a) `url_launcher` `LaunchMode.inAppBrowserView` (Custom Tabs / SFSafariViewController según su documentación), o (b) `flutter_web_auth_2` con *callback* https en iOS ≥ 17.4. Respaldo al navegador predeterminado si no hay Custom Tabs (RNF-086). **Nunca** WebView propio (RNF-045d).

---

## 7. Capa de red (ADR-006)

### 7.1 Configuración

| Parámetro | Valor propuesto | Justificación |
|---|---|---|
| Base URL | Por flavor (`config/<flavor>.json`) | ADR-009. |
| Timeout de conexión | 10 s | RNF-021 (lectura 10 s). |
| Timeout de recepción (lecturas) | 10 s | RNF-021. |
| Timeout ticket de checkout | 20 s | RNF-021. |
| Timeout de envío (PQRS) | 15 s | PROPUESTA; texto ≤ 1.000 caracteres. |
| Compresión | `Accept-Encoding: gzip` (por defecto en el cliente HTTP de la plataforma; verificar en SPK-02) | RNF-011. |
| Cabeceras propias | `X-App-Version`, `X-App-Platform`, `X-Request-Id` (UUID por petición), `Accept-Language: es-CO` | T-01, T-08, RNF-099. Nunca PII. |
| Cancelación | `CancelToken` al salir de pantalla y en sugerencias (debounce 300 ms) | RA-09. |

### 7.2 Interceptores (orden)

| # | Interceptor | Responsabilidad |
|---|---|---|
| 1 | `AppHeadersInterceptor` | Cabeceras de §7.1. |
| 2 | `AuthInterceptor` | Añade `Authorization: Bearer` **solo** a rutas privadas. Ante 401 de token expirado: **un único refresh en vuelo** (los demás 401 esperan el mismo `Future`), reintenta la petición original una vez; si el refresh falla → `SessionController.expire()` (RNF-028). Nunca pone tokens en la URL (RNF-041). |
| 3 | `RetryInterceptor` | Solo métodos idempotentes (GET/HEAD) y solo ante: sin conexión/timeout, 502/503/504, 429. Máximo **2 reintentos**, espera exponencial con *jitter* (p. ej. 400 ms → 1,2 s), respetando `Retry-After` si ≤ 10 s; si es mayor, se devuelve el fallo con ese valor. **POST nunca se reintenta automáticamente** (RNF-021, RNF-024). |
| 4 | `ErrorMappingInterceptor` | Convierte `DioException`/respuestas en `AppFailure` (§7.3). |
| 5 | (Solo dev/staging) `DebugLogInterceptor` | Registro de método, ruta y estado; **sin** cuerpos ni cabeceras de autenticación. Inexistente en prod (RNF-047, RNF-051). |

### 7.3 Taxonomía de fallos (`AppFailure`, `sealed`)

| Fallo | Origen | Mensaje UI (es-CO, borrador) | Acción en UI | ¿Reintentable? |
|---|---|---|---|---|
| `NoConnection` | Sin red / DNS / socket | "No tienes conexión. Revisa tu internet." | Reintentar; mostrar caché si existe | Sí |
| `Timeout` | Timeout de conexión/recepción | "La respuesta está tardando. Intenta de nuevo." | Reintentar | Sí |
| `NotFound` | **404** | "Este producto ya no está disponible." | Volver; en carrito: marcar línea "no disponible" (no borrarla sola) | No |
| `ServiceUnavailable(retryAfter)` | **503** (breaker abierto, índice no listo) | "La tienda no está disponible en este momento." | Reintentar tras `retryAfter`; mostrar caché marcada "posiblemente desactualizada" | Sí |
| `RateLimited(retryAfter)` | 429 | "Demasiados intentos. Espera un momento." | Deshabilitar acción el tiempo indicado | Más tarde |
| `Unauthorized` | 401 tras refresh fallido | "Tu sesión terminó. Inicia sesión de nuevo." | Ir a login preservando carrito | No |
| `Forbidden` | 403 del BFF | "No tienes permiso para esta acción." | — | No |
| `BlockedByEdge` | 403/HTML de Cloudflare (respuesta no JSON con firma del WAF) | "No pudimos verificar la conexión. Intenta más tarde." | Reportar como no fatal (RA-06) | Más tarde |
| `Validation(fields)` | 400/422 con detalle | Mensaje por campo | Marcar campos | No |
| `Conflict(code)` | 409 (p. ej. carrito cambió, ticket usado) | Según código | Flujo específico (checkout) | Según código |
| `UpgradeRequired` | Código dedicado de versión obsoleta (T-09) | "Actualiza la app para continuar." | Ir a `/update-required` | No |
| `Server` | 500 genérico | "Algo salió mal. Intenta de nuevo." | Reintentar | Sí |
| `Contract` | JSON inesperado / mapeo fallido | "Algo salió mal." | Reporte no fatal con ruta y versión (sin cuerpo) | No |
| `Unknown` | Resto | "Algo salió mal." | Reintentar | Sí |

- Los códigos de error de negocio (p. ej. ticket vencido) los define el contrato (**en elaboración**); el mapa código → mensaje vive en `core/errors` y los textos en ARB.
- Los repositorios devuelven `Result<T, AppFailure>`; **ninguna** excepción de red llega a `presentation`.
- Regla de oro (P4): **ningún** `NoConnection`, `Timeout`, `ServiceUnavailable` o `Server` provoca borrado de datos locales (carrito, favoritos futuros).

### 7.4 Caché de red

| Recurso | Dónde | Política (PROPUESTA; ajustar con PA-04) | Offline |
|---|---|---|---|
| Configuración remota (N-01) | Memoria + `CacheStore` | Refresco al arrancar y al volver a primer plano si tiene > 5 min (RNF-029: efecto ≤ 5 min) | Último valor conocido |
| Árbol de categorías, marcas | `CacheStore` | Fresco 1 h; obsoleto utilizable hasta 7 días | Sí |
| Listados (primeras páginas visitadas) | `CacheStore` (LRU) | Fresco 5 min; obsoleto hasta 24 h (alineado con el SWR del servidor, WCA §5.1) | Sí, con aviso |
| Ficha de producto visitada | `CacheStore` (LRU, tope p. ej. 200 fichas) | Fresco 5 min; obsoleto hasta 24 h | Sí, con aviso; **compra deshabilitada sin red** |
| Sedes | `CacheStore` | Fresco 24 h; obsoleto hasta 30 días | Sí |
| Búsqueda y sugerencias | Solo memoria (sesión) | — | No |
| Precios/stock para pagar (N-05) | **Nunca** de caché | Siempre red | No |
| Perfil, direcciones, pedidos | Solo memoria; se borra al cerrar sesión | — | No (RNF-062) |
| Imágenes | Caché de `cached_network_image` (disco con tope) | Tope documentado (RNF-010) | Sí |

Patrón: **stale-while-revalidate en el repositorio**: se emite el dato en caché (marcado `stale` si venció) y se refresca en segundo plano; si la red falla, se conserva el dato con `StaleBanner`. Si el servidor envía `ETag`, el datasource lo guarda y revalida con `If-None-Match` (mejora opcional, T-07).

---

## 8. Almacenamiento local (ADR-007)

| Dato | Almacén | Protección | Al cerrar sesión | Al eliminar cuenta | Requisito |
|---|---|---|---|---|---|
| *Refresh token* | `flutter_secure_storage` (Keychain iOS con accesibilidad "after first unlock, this device only"; Keystore/EncryptedSharedPreferences en Android según el paquete) | Cifrado por el SO; excluido de copias | Se borra | Se borra | RNF-034, RNF-035 |
| *Access token* | Memoria (y secure storage solo si SPK-03 muestra que el arranque lo necesita) | — | Se borra | Se borra | RNF-039 |
| Identificador de instalación (aleatorio, `Random.secure`, sin datos de hardware) | `flutter_secure_storage` | — | Se conserva | Se regenera | T-11 |
| Carrito (`productId`, cantidad, instantánea de nombre/imagen/precio solo para mostrar) | `hive_ce` caja `cart` | Sin PII | Se conserva (PROPUESTA; DN-10) | Se conserva | RF-049, RNF-031 |
| Caché pública de catálogo y sedes | `hive_ce` caja `cache` (LRU, tope de tamaño) | Sin PII | Se conserva | Se conserva | RNF-020, DN-10 |
| Intento de checkout en curso | `hive_ce` caja `cache` | Sin PII (solo id de intento y marca de tiempo) | Se borra | Se borra | ADR-008 |
| Preferencias no sensibles (aviso visto, última pestaña) | `shared_preferences` | — | Se conserva | Se borra | — |
| Perfil, direcciones, pedidos | **Solo memoria** | — | — | — | RNF-062 |

Controles de plataforma: Android `android:allowBackup="false"` o reglas de exclusión (`dataExtractionRules`) para las cajas y el secure storage; iOS sin claves sincronizables con iCloud; capturas del selector de apps ocultas en cuenta, pedidos y checkout (Should, RNF-035). Las cajas Hive no se cifran porque **no contienen PII**; si algún día la contienen, se cifran con clave en secure storage o se mueven.

**Primera ejecución tras reinstalar en iOS:** el Keychain puede conservar datos de una instalación anterior; en el primer arranque (marca ausente en `shared_preferences`) se limpia el secure storage. (Comportamiento de iOS conocido; verificar en SPK-03.)

---

## 9. Estrategia offline (solo donde se justifica)

| Funcionalidad | ¿Offline? | Justificación |
|---|---|---|
| Inicio, categorías, listados y fichas **ya visitados** | **Sí, lectura** con aviso de desactualización | RNF-020; DN-10. Usuarios en 4G irregular (S-NF-01). |
| Sedes | **Sí** | Datos estables; útil sin red ("llamar", "cómo llegar" usan apps del SO). |
| Carrito | **Sí** (fuente local de verdad hasta el checkout) | RF-049; RNF-031. |
| Calculadora BTU | **Sí, completa** (lógica local pura); el enlace al catálogo requiere red | RF-085–088. |
| Búsqueda | No (índice en servidor) | Replicar el índice (~10.000 productos) en el dispositivo no tiene requisito. |
| Login, registro, perfil, pedidos, PQRS | No | Requieren servidor; PQRS no se encola (contiene PII y riesgo de duplicado). |
| Revalidación de precio y checkout | **Nunca** | Autoridad del servidor (P1); RNF-020 "el pago exige conexión y lo indica". |

No se adopta *offline-first* general ni sincronización bidireccional: no hay datos editables offline que sincronizar (P3).

---

## 10. Estados de UI y manejo de errores

| Estado | Componente compartido | Regla |
|---|---|---|
| Cargando | `SkeletonList` / `SkeletonDetail` | Visible ≤ 100 ms tras la navegación (RNF-003); anunciado a lectores de pantalla. |
| Vacío | `EmptyState` (ilustración + texto + acción) | Búsqueda sin resultados → botón WhatsApp con el término (RF-023). Solo cuando el servidor respondió 200 con lista vacía. |
| Error | `ErrorState(AppFailure)` | Mensaje es-CO + acción (reintentar/contactar) para el 100 % de los fallos (RNF-027). |
| Datos obsoletos | `StaleBanner` | "Mostrando información guardada; puede no estar actualizada." (RNF-022). |
| Error al cargar más | Pie de lista con reintento | No borra lo ya cargado. |
| Sin conexión global | Aviso no bloqueante | Aparece ≤ 3 s tras detectar fallos de red (RNF-020); no se usa `connectivity_plus` (§18). |

Manejo global: `FlutterError.onError` y `PlatformDispatcher.instance.onError` envían a `CrashReporter` (con depuración de PII) y nunca muestran trazas al usuario; en release, `ErrorWidget.builder` muestra un estado genérico (RNF-027).

---

## 11. Modelo de dominio clave y reglas en la app

| Entidad / valor | Campos relevantes | Reglas locales (siempre subordinadas al servidor) |
|---|---|---|
| `Money` | Entero en COP | Formato `$ 1.234.567` sin decimales, "IVA incluido" (RNF-084). Nunca `double`. |
| `PriceStatus` | `withPrice(Money)` / `consult` | `consult` → "Más información" y nunca "$0" (RF-012). Si el DTO trae precio 0 sin estado explícito, se trata como `consult` (defensa en profundidad). |
| `StockStatus` | `inStock` / `outOfStock` / `onBackorder` / `unknown` | Solo `inStock` + `withPrice` permite añadir (RF-029/031). `onBackorder`: PENDIENTE PA-12 (se trata como no comprable hasta decidir, igual que la web, WCA §6). `unknown` = no comprable. |
| `ProductSummary` / `ProductDetail` | id, slug, nombre, marca, sku, precio, stock, imágenes, categorías, atributos, descripción saneada | Sin `stockQuantity` (WCA §4.1). Imagen vacía → *placeholder*. |
| `Cart` / `CartLine` | productId, cantidad, instantánea de visualización | Cantidad 1–99; ≤ 100 líneas (`FE:src/lib/checkout-schema.ts`; RF-049). El subtotal es "informativo". La instantánea se reemplaza tras cada revalidación (N-05). |
| `CheckoutAttempt` | id del intento, clave de idempotencia, creado, estado | Máquina de estados §6.3. |
| `Order` | número, fecha, estado, total, ítems | Estado mostrado con etiqueta del servidor; estados desconocidos → "En proceso" genérico. |
| `BtuInput` / `BtuResult` | largo, ancho, alto, ocupantes, equipos, clima | Fórmula de COD §6 implementada **solo tras validación de Ingeniería (D-08)**; vectores de prueba ≥ 30 (RNF-092); `> 36.000` → sin sugerencia + contacto (RF-088). |

---

## 12. Internacionalización (es-CO)

| Aspecto | Decisión |
|---|---|
| Mecanismo | `flutter_localizations` (SDK) + `gen-l10n` con `l10n/app_es.arb`; `intl` 0.20.3 para formatos. Ningún texto incrustado (RNF-084). |
| Locale | `es_CO` para formatos numéricos y de fecha; textos de Material con *fallback* a `es` (los locales regionales soportados por `GlobalMaterialLocalizations`: **NO VERIFICADO** para `es_CO`). |
| Moneda | `NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)`; verificar separadores con pruebas (RNF-084). |
| Fechas y zona | `dd/MM/aaaa`; zona America/Bogota (UTC−5, sin horario de verano). Las fechas del servidor se interpretan en UTC y se muestran en hora de Colombia. |
| Lectores de pantalla | Precios con etiqueta semántica legible ("1.234.567 pesos") (RNF-070). |
| Preparado para otros idiomas | Sí por estructura (ARB), sin traducciones en el MVP. |

---

## 13. Tema y design tokens

### 13.1 Paleta observada y contraste (cálculo WCAG 2.x hecho para este documento)

| Color | Origen | Contraste sobre blanco `#ffffff` | Contraste sobre fondo oscuro web `#0a1320` | Uso propuesto |
|---|---|---|---|---|
| `#07628e` (azul primario) | `FE:src/app/globals.css` L59-61 ("Manual de Marca, P 117-8 C") | **6,67:1** ✔ AA texto | 2,79:1 ✘ | Primario en tema claro (botones, enlaces, texto destacado). |
| `#0a3651` (azul oscuro) | `FE:docs/documentacion-proyecto.md` L445 | **12,66:1** ✔ | 1,47:1 ✘ | Encabezados, barras, texto sobre fondos claros. |
| `#0b4970` (azul) | Ídem | **9,54:1** ✔ | 1,95:1 ✘ | Estados presionados / variante. |
| `#5ba628` (verde de marca) | Ídem | **3,03:1** ✘ texto normal (solo ≥ 3:1 para texto grande e iconos) | 6,15:1 ✔ | **Solo** decorativo, iconos ≥ 3:1, o fondo con **texto oscuro** (`#151a21` sobre verde = 5,77:1 ✔). **Nunca texto blanco sobre verde ni texto verde normal sobre blanco.** |
| `#3d7519` (verde oscurecido, PROPUESTA) | Derivado para accesibilidad | **5,59:1** ✔ | 3,33:1 | Texto verde (p. ej. "En stock", "Oferta") en tema claro. Requiere aprobación de Marca (D-13). |
| `#439be4` (primario modo oscuro web) | `FE:src/app/globals.css` L94 | 2,98:1 ✘ | **6,25:1** ✔ | Primario del tema oscuro (fase 2, RF-113). |
| `#d64045` (destructivo) | INV §9 | **4,49:1** ✘ por 0,01 | 4,15:1 ✘ | Ajustar a un rojo más oscuro para texto (p. ej. validar `#c2373c`); MED-12. |
| `#151a21` (texto) | INV §9 | 17,48:1 ✔ | — | Texto principal. |

> Los cálculos son propios (fórmula de luminancia relativa WCAG). Deben confirmarse con una herramienta y con la **paleta oficial** del manual de marca (MED-12, D-13).

### 13.2 Estructura de tokens

- `shared/design_system/tokens/`: `ColorTokens` (semánticos: `primary`, `onPrimary`, `success`, `successText`, `danger`, `surface`, `textPrimary`…), `TypographyTokens`, `SpacingTokens` (escala 4 dp), `RadiusTokens`, `ElevationTokens`.
- Tema Material 3 construido desde tokens (`ThemeData` con `ColorScheme` explícito, **no** `fromSeed`, para garantizar los contrastes medidos).
- Tipografía: Poppins (web) — **licencia y empaquetado a confirmar (D-13)**; se empaqueta como *asset* (no descarga en tiempo de ejecución, por privacidad y offline). JetBrains Mono para SKU/códigos si se aprueba.
- Modo oscuro: tokens preparados, tema oscuro en **fase 2** (RF-113 Could).
- Componentes base: `IprButton` (primario/secundario/texto, mínimo 48 dp), `PriceText`, `StockBadge` (texto + ícono, nunca solo color, RNF-076), `ProductCard`, `IprTextField` (etiqueta visible, autocompletado), `WhatsAppButton`.

---

## 14. Accesibilidad

| Requisito | Medida en la arquitectura | Verificación |
|---|---|---|
| RNF-068 texto 200 % | No se limita `TextScaler`; diseños con `Flexible`/scroll; goldens a escala 1,0 y 2,0 | Golden (Alchemist) + manual |
| RNF-069 contraste | Tokens de §13 (sin verde para texto normal) | Prueba `textContrastGuideline` + MED-12 |
| RNF-070 lectores de pantalla | `Semantics` en tarjetas (nombre, precio, stock), imágenes con alternativa = nombre del producto, anuncios de cambios (carrito, errores) | `labeledTapTargetGuideline` + TalkBack/VoiceOver manual |
| RNF-071 objetivos táctiles | Componentes base con mínimo 48 dp | `androidTapTargetGuideline`, `iOSTapTargetGuideline` en pruebas de widget |
| RNF-072 gestos | Galería con botones anterior/siguiente; borrar del carrito con botón (no solo deslizar) | Revisión |
| RNF-073 formularios | Etiqueta visible, `autofillHints`, pegado permitido, errores asociados | Widget tests |
| RNF-074 movimiento | Respetar `MediaQuery.disableAnimations` | Revisión |
| RNF-077 checkout externo | Fuera del control de la app; se prueba y se reportan hallazgos al equipo web | Manual |

---

## 15. Estrategia de pruebas (ADR-012)

| Nivel | Qué cubre | Herramientas | Dónde corre | RNF |
|---|---|---|---|---|
| Unitarias de dominio | Reglas del carrito, elegibilidad de compra, máquina de estados del checkout, `Money`/formato, BTU (≥ 30 vectores validados) | `flutter_test`, `mocktail` | CI en cada PR | 089 (≥ 90 % en críticos), 092 |
| Unitarias de datos | Mapeadores DTO→entidad con *fixtures* JSON (casos: campos faltantes, enumeraciones nuevas, precio 0, imagen vacía), mapeo de errores (404 vs 503 vs 429 vs HTML de Cloudflare), *refresh* de vuelo único con 401 concurrentes | `flutter_test`, `mocktail`, adaptador HTTP simulado de Dio | CI | 021, 022, 027, 028 |
| Contrato (lado app) | Los *fixtures* se generan/validan contra los ejemplos del OpenAPI de `/mobile/v1` (**en elaboración**); si el contrato cambia de forma incompatible, fallan | Script de CI | CI | 085, 090 |
| Widget | Pantallas con repositorios falsos vía `overrides`; estados carga/vacío/error/obsoleto; guías de accesibilidad | `flutter_test` | CI | 027, 068–073 |
| Golden | Componentes del design system y pantallas clave en escala 1,0/2,0 y estados | `alchemist` 0.15.0 (golden de CI independientes de plataforma) | CI | 068, 069 |
| Integración | Flujos en app real con BFF simulado: navegación, guardas, carrito persistente tras reinicio, modo avión | `integration_test` (SDK) | CI (emulador) | 020, 031 |
| E2E | Compra completa contra **staging** con Wompi sandbox: aprobado, rechazado, cancelado, abandono, ticket vencido, doble toque | `patrol` 4.11.0 (interacción con UI nativa; **confirmar en SPK-01** que maneja Custom Tabs/SFSafariViewController) | Pre-release, dispositivos reales | 024–026, 091 |
| Seguridad | Escaneo de secretos, dependencias (OSV), análisis de binario, MASVS L1 | Herramientas de CI + MASTG | CI / F4 | 033, 036, 048, 049 |
| Rendimiento | Arranque, fluidez, memoria en *profile* | DevTools, trazas de plataforma | F2 (SPK-02), F3 | 001–008 |

Umbral de cobertura en CI: ≥ 70 % global, ≥ 90 % en `core/session`, `core/network`, `features/cart/domain`, `features/checkout/domain`, `shared/formatting`, `features/technical_tools/domain` (RNF-089).

---

## 16. Flavors, configuración y CI/CD (ADR-009)

| Flavor | Id. de app (PROPUESTA) | BFF | Reporte de fallos | Uso |
|---|---|---|---|---|
| `dev` | `co.ipr.app.dev` | Local o dev (DESCONOCIDO) | Desactivado o proyecto dev | Desarrollo |
| `staging` | `co.ipr.app.staging` | Staging (C2 de ADR-001; **existencia DESCONOCIDA**, COD §8.2) | Proyecto staging | QA, E2E con Wompi sandbox |
| `prod` | `co.ipr.app` (**PENDIENTE**: identificador definitivo y titular de cuentas, D-14) | Producción | Proyecto prod | Tiendas |

- Configuración pública en `config/<flavor>.json`: `apiBaseUrl`, `environment`, `deepLinkHost`, `checkoutAllowedHosts`, `supportWhatsApp` (dato público, `FE:src/lib/contact-links.ts`). **Ningún secreto** (RNF-036).
- Pipeline (RNF-087, 093): formato → `flutter analyze` (very_good_analysis) → verificación de reglas de dependencia (§3) → pruebas + cobertura → escaneo de secretos/dependencias → *build* firmado desde CI con secretos del gestor → ofuscación de Dart con símbolos archivados (RNF-051) → SBOM.
- Versionado semántico; la versión y el *build number* se envían en `X-App-Version` (N-01/T-09).

---

## 17. Tabla de dependencias

Datos de pub.dev consultados el **2026-11-18** mediante la API pública de pub.dev (`/api/packages/<nombre>`, `/score`), que alimenta las páginas del sitio. "Pts" = pub points sobre 160. "Descargas" = últimos 30 días.

### 17.1 Dependencias propuestas para el MVP

| Paquete | Versión | Para qué | Alternativa | Justificación | Licencia | Mantenimiento / compatibilidad | Verificación |
|---|---|---|---|---|---|---|---|
| `flutter_riverpod` | 3.5.0 (2026-11-06) | Estado + DI | flutter_bloc | ADR-004 | MIT | dash-overflow.net; 140 pts; 2.919 likes; 4,34 M desc.; Dart ^3.12, Flutter ≥ 3.0 | Verificado |
| `go_router` | 18.1.4 (2026-11-09) | Navegación, guardas, deep links | auto_route, Navigator 2.0 | ADR-005; mantenido por Flutter | BSD-3 | flutter.dev; 150 pts; 5.801 likes; Flutter ≥ 3.44 | Verificado |
| `dio` | 5.11.1 (2026-09-04) | Cliente HTTP con interceptores | `http` | ADR-006 | MIT | flutter.cn; 160 pts; 8.373 likes | Verificado |
| `freezed` (dev) + `freezed_annotation` | 4.0.3 (2026-10-17) / 3.1.0 (2025-07-02) | Entidades inmutables, `copyWith`, igualdad, uniones | `equatable` + código manual; *sealed classes* nativas de Dart 3 | Reduce errores en estados y entidades; para jerarquías simples (`AppFailure`) se usan *sealed classes* nativas sin Freezed | MIT | dash-overflow.net; 160/150 pts; freezed exige Dart ≥ 3.13 | Verificado |
| `json_serializable` (dev) + `json_annotation` | 6.15.2 (2026-10-20) / 4.12.0 (2026-05-15) | DTOs del contrato | Parseo manual; cliente generado de OpenAPI | Código generado, revisable, sin reflexión | BSD-3 | google.dev; 160/150 pts | Verificado |
| `build_runner` (dev) | 2.17.1 (2026-10-14) | Generación de código | — | Requerido por Freezed/json_serializable | BSD-3 | tools.dart.dev; 160 pts | Verificado |
| `flutter_secure_storage` | 11.2.0 (2026-09-16) | Tokens e id. de instalación en Keychain/Keystore | Implementación nativa propia | RNF-034; estándar de facto | BSD-3 | steenbakker.dev; 160 pts; 4.512 likes; Flutter ≥ 3.19 | Verificado. Opciones de accesibilidad Keychain y backend Android: **verificar en SPK-03** |
| `hive_ce` | 2.23.3 (2026-11-09) | Carrito y caché pública (cajas con tope) | Drift/sqflite; archivos JSON propios | ADR-007; sin esquema SQL | Apache-2.0 y BSD-3 | iodesignteam.com; 160 pts; 576 likes; 1,31 M desc. Fork comunitario de Hive → encapsulado tras `CacheStore`/`CartStore` | Verificado. Paquete de integración Flutter (`hive_ce_flutter`) y `path_provider`: **NO VERIFICADO** |
| `shared_preferences` | 2.5.6 (2026-10-05) | Preferencias no sensibles | — | Simple; mantenido por Flutter | BSD-3 | flutter.dev; 160 pts | Verificado |
| `cached_network_image` | 4.0.7 (2026-11-11) | Imágenes con caché en disco y tamaño en memoria | `Image.network` + caché propia | RNF-009/010 | MIT | baseflow.com; 150 pts; 6.989 likes; Flutter ≥ 3.44 | Verificado |
| `intl` + `flutter_localizations` (SDK) | 0.20.3 (2026-06-25) | Formato COP/fechas; i18n | — | RNF-084 | BSD-3 | dart.dev; 160 pts | Verificado |
| `url_launcher` | 6.3.3 (2026-10-02) | `tel:`, `wa.me`, mapas; navegador seguro (`inAppBrowserView` = Custom Tabs / SFSafariViewController según su documentación) | `flutter_custom_tabs` | Publicador flutter.dev; cubre contacto y checkout | BSD-3 | flutter.dev; 160 pts; 8.192 likes | Verificado (API). Comportamiento con App Links tras 302: **NO VERIFICADO** → SPK-01 |
| `flutter_widget_from_html_core` | 0.17.4 (2026-09-08) | Descripción HTML (ya saneada en el servidor) sin WebView | `flutter_html` (90 pts, sin versión en ~20 meses); texto plano | RF-027; sin JavaScript (RNF-052). Uso condicionado a la respuesta de WCA §7.3 pregunta 9 | MIT | daohoangson.com; 160 pts; 527 likes | Verificado |
| `package_info_plus` | 10.2.2 (2026-10-01) | Versión de la app (cabecera, versión mínima) | Inyectar versión por `dart-define` | RNF-029 | BSD-3 | fluttercommunity.dev; 150 pts | Verificado |
| Reporte de fallos: `firebase_crashlytics` + `firebase_core` **o** `sentry_flutter` | 6.1.0 + 5.2.0 (2026-11-16) / 10.5.0 (2026-11-17) | Crashes y no fatales simbolizados | El otro | ADR-010; **elección PENDIENTE DN-02** | BSD-3 / MIT | firebase.google.com 160 pts / sentry.io 140 pts | Verificado |
| `very_good_analysis` (dev) | 11.0.0 (2026-09-03) | Reglas de análisis estrictas | `flutter_lints` 6.0.0 | RNF-087 pide reglas estrictas; se desactivan reglas puntuales justificadas | MIT | verygood.ventures; 160 pts; Dart ^3.13 | Verificado |
| `mocktail` (dev) | 1.0.5 (2026-04-10) | Dobles de prueba sin generación | `mockito` | Sin `build_runner` para mocks | MIT | felangel.dev; 160 pts | Verificado |
| `alchemist` (dev) | 0.15.0 (2026-11-17) | Golden tests | `golden_toolkit` (**descontinuado**) | ADR-012 | MIT | betterment.dev; 160 pts; 227 likes | Verificado |
| `integration_test` (dev, SDK) | Incluido en Flutter | Pruebas de integración | — | Se declara `sdk: flutter`; el paquete de pub.dev está descontinuado por haberse movido al SDK | BSD-3 | flutter.dev | Verificado |
| `patrol` (dev) | 4.11.0 (2026-11-02) | E2E con UI nativa (navegador seguro, permisos) | Appium; pruebas manuales | RNF-091; **adopción condicionada a SPK-01** | Apache-2.0 | leancode.co; 150 pts; 732 likes | Verificado |
| `flutter_launcher_icons`, `flutter_native_splash` (dev) | 0.14.4 / 2.4.8 | Íconos y splash por flavor | Configuración nativa manual | Opcionales, solo herramientas de *build* | MIT | fluttercommunity.dev / jonhanson.net; 150 pts | Verificado |

### 17.2 Evaluadas y NO adoptadas (todavía)

| Paquete | Versión verificada | Motivo de no adopción | Se reevalúa si… |
|---|---|---|---|
| `riverpod_generator` / `riverpod_annotation` | 4.0.10 / 4.0.8 | ADR-004: menos generación de código al inicio | El equipo prefiere la sintaxis generada tras el primer trimestre. |
| `app_links` | 7.2.2 | Conflicto con el manejador por defecto de Flutter; go_router basta | Se necesita el flujo crudo de enlaces. |
| `flutter_web_auth_2` | 5.1.0 (prerelease 6.0.0-alpha.11) | Solo si SPK-01 demuestra ventaja con *callback* https en iOS ≥ 17.4 | SPK-01. |
| `flutter_custom_tabs` | 2.6.0 | Sin publicador verificado; `url_launcher` cubre el caso | Se necesita personalizar Custom Tabs. |
| `drift` / `sqflite` | 2.35.4 / 2.4.6 | ADR-007: sin caso relacional | Favoritos sincronizados, historial con consultas, catálogo offline con búsqueda. |
| `dio_cache_interceptor` (+ stores) | 4.0.7 (stores 5.1.1 / 7.0.1) | Stores persistentes con adopción muy baja (6 y 3 likes) | El BFF expone `ETag`/`Cache-Control` estables y se quiere caché HTTP pura. |
| `connectivity_plus` | 7.3.2 | "Tener red" ≠ "llegar al BFF"; se usan los fallos reales de las peticiones | Se necesita reaccionar a cambios de red en segundo plano. |
| `http_certificate_pinning` | 3.0.2 | ADR-011; 125 pts, ~32 K desc. | Plan de rotación aprobado (DN-05). |
| `firebase_messaging` | 17.1.0 | Push = fase 2 (módulo L Could/Won't; RF-090–093) | Se aprueba D-11 y el registro de dispositivos (N-14). |
| `firebase_analytics` | 13.1.0 | Analítica PENDIENTE PA-08 y consentimiento (RNF-103) | Jurídico aprueba herramienta y finalidades. |
| `envied` / `flutter_dotenv` | 1.3.10 / 6.0.2 | ADR-009: no hay secretos de cliente; `.env` empaquetado es legible | — |
| `webview_flutter` | 4.14.1 | RNF-045d y RNF-052: checkout nunca en WebView propio | Contenido editorial que lo requiera (fase 2, con JS deshabilitado). |
| `local_auth` | 3.0.2 | Sin requisito de biometría | Requisito nuevo. |
| `flutter_html` | 3.0.0 | 90 pts; sin publicación desde 2025-03 | — |
| `golden_toolkit` | 0.15.0 | **Descontinuado** | — |

---

## 18. Qué se evalúa y NO se adopta todavía (decisiones explícitas)

| Tema | Decisión MVP | Razonamiento | Condición para reabrir |
|---|---|---|---|
| *Certificate pinning* | No | ADR-011: rotación de certificados de Cloudflare; apagón total ante un *pin* viejo; MASVS L1 no lo exige | DN-05 con clave de respaldo + interruptor remoto |
| Detección de root/jailbreak | No | RNF-054 (Could); el servidor es la autoridad, la app no guarda nada valioso que proteger con eso | Modelo de amenazas que lo justifique |
| Drift/SQLite | No | Sin consultas relacionales ni búsqueda offline (ADR-007) | Ver §17.2 |
| Push (FCM/APNs) | No (fase 2) | RF-090–093 son Could/Won't fase 2; D-11 y D-12 abiertas | Aprobación de D-11 + consentimiento + N-14 |
| Analítica de producto | Arquitectura lista, SDK no | PA-08, R-NF-09, RNF-061 | Decisión de Jurídico |
| Favoritos | No (fase 2) | Módulo H Could fase 2 | Aprobación de fase 2 |
| Cliente generado desde OpenAPI | No por ahora | Contrato en elaboración; DTOs a mano + pruebas de contrato | OpenAPI estable de `/mobile/v1` |
| Modo oscuro | Tokens preparados, tema no | RF-113 Could; D-13 | Fase 2 |
| Tablet optimizada | No | DN-11 | Datos de MED-01 |
| Ofuscación de secretos | No aplica | No hay secretos en cliente | — |

---

## 19. Spikes técnicos previos al desarrollo (F2)

| ID | Pregunta | Resultado esperado | Bloquea |
|---|---|---|---|
| SPK-01 | Retorno del pago: ¿la redirección 302 a `/pedido-confirmado` dentro de Custom Tabs (Android) y SFSafariViewController/ASWebAuthenticationSession (iOS) abre la app vía App/Universal Link? ¿`flutter_web_auth_2` con *callback* https en iOS ≥ 17.4 es más fiable? ¿`patrol` puede automatizarlo? | Elección del componente de `SecureBrowser` y matriz por versión de SO | ADR-008, RNF-025, RNF-091 |
| SPK-02 | Mínimos reales de Android/iOS con Flutter 3.50 + plugins elegidos; arranque y tamaño en dispositivo de referencia | Datos para DN-01 y RNF-001/008 | DN-01 |
| SPK-03 | `flutter_secure_storage` 11: accesibilidad de Keychain, comportamiento tras reinstalar, backend de Android y exclusión de copias | Configuración documentada | RNF-034, RNF-035 |
| SPK-04 | Renderizado de descripciones reales saneadas con `flutter_widget_from_html_core` (tablas, imágenes, iframes) | Decidir HTML nativo vs. texto plano | RF-027 |

---

## 20. Matriz de trazabilidad (módulos RF → features)

| Módulo RF | Requisitos MVP principales | Feature(s) Flutter | Capacidades de API (overview §7) | Notas |
|---|---|---|---|---|
| A. Inicio | RF-001–007, RF-009 | `home` (+ rutas a catalog, search, technical_tools, support) | N-02, N-03 | RF-003 "más vendidos": criterio DESCONOCIDO (PA-05). |
| B. Catálogo | RF-010–016, RF-018, RF-019 | `catalog` (categorías, listados, marcas, liquidaciones) | N-02, N-03, N-07 | RF-019 es del servidor; la app respeta frescura (§7.4). |
| C. Búsqueda | RF-020–023 | `search` | N-06 | Debounce + cancelación (RA-09). |
| D. Detalle | RF-026–032 | `product_detail` | N-04 | RF-036 (deep link de producto) fase 2. |
| E. Autenticación | RF-037–045, RF-048 | `authentication` + `core/session` | N-09 | RF-048 (bloquear admin) es del servidor. |
| F. Carrito y compras | RF-049–058 | `cart`, `checkout` | N-05, N-11, N-12 | ADR-008. |
| G. Cotizaciones | RF-062–065 | `product_detail` ("Más información"), `support` (WhatsApp general) + `core/external` | — | RF-065 requiere PA-08. Sin feature `quotes` en MVP. |
| H. Favoritos | — (fase 2) | (futura `favorites`) | — | No se crea. |
| I. Sedes | RF-072–076 | `branches` | N-08 | RF-077/078 fase 2 (coordenadas, ubicación). |
| J. Asesoría técnica | RF-079, RF-080 | `support` (sección ingeniería) | N-01 o contenido estático | PA-06. |
| K. Herramientas técnicas | RF-085–089 | `technical_tools` | — (local) + N-03 para RF-089 | Condicionado a D-08. |
| L. Notificaciones | — (fase 2) | (futura `notifications`) | N-14 | No se crea. |
| M. Atención al cliente | RF-094–097, RF-099 | `support` | N-13, N-01 (URLs legales) | — |
| N. Perfil y cuenta | RF-104–108, RF-110, RF-111 | `profile`, `orders` | N-09, N-10 | RF-112 (sesiones activas) fase 2. |
| Transversal | RF-009 | `core/network`, `shared/widgets` | T-01…T-11 | — |

---

## 21. Decisiones que requieren aprobación humana

| ID | Decisión | Opciones | Recomendación | Quién decide | Bloquea |
|---|---|---|---|---|---|
| DA-01 | Aprobar ADR-003 a ADR-012 (overview §9) | Aprobar / ajustar / rechazar cada una | Aprobar | Solicitante + responsable técnico | Inicio de F2 |
| DA-02 | El BFF provee identificador de intento + clave de idempotencia (N-11) y consulta del resultado (N-12) | Sí / solo "pedidos recientes" como alternativa | Sí | Arquitecto API (`docs/05_api/`, en elaboración) + equipo web | ADR-008, RF-055–057 |
| DA-03 | Alojar `.well-known/assetlinks.json` y `apple-app-site-association` (solo `/pedido-confirmado` en MVP) | Sí / no (solo verificación al volver) | Sí | Equipo web (COD §8.3) | RF-055 (acelerador) |
| DA-04 | Proveedor de reporte de fallos (DN-02) | Crashlytics / Sentry | Decidir con Jurídico (país de tratamiento) | Jurídico + TI | RNF-097, NL-09 |
| DA-05 | Versiones mínimas Android/iOS (DN-01) | API 26 / iOS 15 u otras tras SPK-02 | Tras SPK-02 | Gerencia + TI | Compatibilidad |
| DA-06 | Tratamiento de "bajo pedido" (`onbackorder`) en la app (PA-12) | Comprable / no comprable | No comprable hasta decidir (igual que la web) | Comercial | RF-031 |
| DA-07 | Verde accesible `#3d7519` (o el que defina Marca) para texto; verde original solo decorativo | Aprobar / proponer otro | Aprobar | Marketing/diseño (D-13) | RNF-069 |
| DA-08 | Licencia y empaquetado de Poppins / JetBrains Mono en la app | Empaquetar / fuente del sistema | Empaquetar si la licencia lo permite | Marketing (D-13) | Diseño |
| DA-09 | Conservar el carrito local al cerrar sesión | Conservar / vaciar | Conservar (sin PII) | Producto (DN-10) | RNF-062 |
| DA-10 | Alcance y plazos de la caché offline (§7.4) | Tabla propuesta / otra | Tabla propuesta; ajustar con PA-04 | Producto + TI (DN-10, PA-04) | RNF-020 |
| DA-11 | Estructura de pestañas (Inicio, Catálogo, Sedes, Carrito, Cuenta) | Propuesta / variante de UX | Validar con UX | Producto + diseño | Navegación |
| DA-12 | Identificadores de app por flavor y titularidad de cuentas (D-14) | `co.ipr.app[.dev|.staging]` u otros | Definir antes de F2 (el id. de producción no se puede cambiar tras publicar) | Gerencia + TI | Publicación |
| DA-13 | Existencia y dominios de staging (C2) con Wompi sandbox | — | Imprescindible | Equipo web | E2E, NL-02 |
| DA-14 | Renderizar descripciones como HTML nativo o texto plano (WCA §7.3 pregunta 9) | HTML nativo sin JS / texto | HTML nativo, tras SPK-04 | Producto + equipo web | RF-027 |
| DA-15 | Aceptar por escrito el riesgo residual de no usar *pinning* ni detección de root en el MVP (NL-C7) | Aceptar / exigir | Aceptar | Seguridad + Gerencia (DN-05) | Lanzamiento |

*Fin del documento.*

# Informe técnico para el equipo de desarrollo — App móvil IPR Partes y Repuestos

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fecha del informe y del recuento** | 2026-11-19 |
| **Estado** | **BORRADOR.** Resume y enlaza la documentación de `docs/`; no aprueba nada, no inventa nada y no afirma que algo esté construido, probado o conforme a norma alguna. |
| **Destinatarios** | Ingeniería: móvil (Flutter), web/BFF (Next.js), WordPress, seguridad, QA, DevOps. Lectura no técnica: [resumen_ejecutivo.md](resumen_ejecutivo.md). |
| **Índice de toda la documentación** | [../README.md](../README.md) |

> **Aviso central.** (1) **Solo constan como aprobadas por el solicitante (2026-11-18): ADR-001 (= D-01), ADR-002, D-03, D-04 y D-06.** Todo lo demás es propuesta, pendiente o abierto. (2) Los documentos están **pendientes de aprobación humana** y de la **resolución de 89 contradicciones (CR)**: no se ha editado ningún documento para aplicarlas ([resolucion_inconsistencias.md](resolucion_inconsistencias.md)). (3) **Ninguna prueba se ha ejecutado** (160 TC + 140 ST en "NO EJECUTADO"); ningún umbral está medido. (4) Las cifras de este informe salen de un **recuento por script** (§17), no de las que declaran los documentos; donde difieren se señala.

**Convención de etiquetas** (la misma de `docs/`): **HECHO** comprobado (documento o código) · **SUPUESTO** · **PROPUESTA** · **PENDIENTE** (decisión humana abierta) · **RIESGO** · **DESCONOCIDO** (sin evidencia) · **NO VERIFICADO**. `SUP-H` = supuesto basado en una recomendación H-xx aún no aprobada.

---

## 1. Estado y alcance

### 1.1 Estado de la implementación

| Aspecto | Estado | Etiqueta |
|---|---|---|
| Implementación de la app Flutter | **Iniciada, M0 en curso**, por orden del usuario (rebanadas M0..M5) en la raíz `C:\Users\empr16\ipr-app` (carpetas `lib/`, `ci/`, `config/` junto a `docs/`). **No se afirma que nada esté construido ni probado.** | PENDIENTE de verificación. En el recuento de hoy (2026-11-19) el árbol de `ipr-app` solo contenía `docs/`; el código puede haberse creado después. |
| Cambios en `ipr-frontend` y WordPress | No hay evidencia de ninguno (hoy no existen `src/app/mobile/` ni `public/.well-known/`; ver §14.1). | HECHO (verificado en solo lectura) |
| Gate G1 (aprobaciones previas a implementar, [implementation_plan §3.1](implementation_plan.md)) | 21 casillas, **todas sin marcar** en el plan. Empezar M0 sin ellas es una decisión del solicitante que **no consta como aprobación de G1**. | RIESGO (RK-001, RK-002, RK-003, RK-004) |
| Pruebas | 0 ejecutadas. `test_results.md` es una plantilla. | HECHO |

### 1.2 Qué está aprobado y qué no

| Elemento | Estado | Fuente |
|---|---|---|
| **ADR-001** (BFF `/mobile/v1` dentro del Next.js existente; `ipr/v1` se amplía solo donde falte; la app nunca llama a `wc/v3`, `wp/v2` ni `/api/*`) | **APROBADA** (2026-11-18). Condiciones C1..C4 **abiertas** (conformidad del responsable técnico, staging, Cloudflare, piloto de carga). Una enmienda (CR-038) y una aclaración (CR-002) están **propuestas, no aprobadas**. | [architecture_decisions.md](../03_architecture/architecture_decisions.md); [decisions_log §2](decisions_log.md) |
| **ADR-002** (MVP con compra completa, sin B2B, cotización solo por WhatsApp) | **APROBADA** | ídem |
| **D-06** (compra completa en el MVP), **D-03** (sin B2B), **D-04** (producto sin precio: solo WhatsApp) | **APROBADAS** | [decisiones_pendientes.md](decisiones_pendientes.md) |
| ADR-003..ADR-022 (20) | **PROPUESTA** (ADR-017 con retiro propuesto: se fusionaría en ADR-008) | [decisions_log §3](decisions_log.md) |
| D-02, D-05, D-07..D-16 | **Abiertas** (D-02 solo parcial: pasarela = Wompi vía WooCommerce; faltan webhook y doble pago) | decisiones_pendientes |
| H-01..H-12 | **PENDIENTES**; los documentos las usan como `SUP-H` | [§15.3](#153-decisiones-h-01h-12-pendientes) |
| OpenAPI `1.0.0-draft`, 27 operaciones `x-status: proposed` | **PROPUESTA** | [openapi.yaml](../05_api/openapi.yaml) |

### 1.3 Alcance del MVP (resumen)

76 de 113 RF entran al MVP (47 *Must* + 29 *Should*); 32 son fase 2 y 5 quedan fuera ([scope.md](../01_business/scope.md), [functional_requirements.md](../02_requirements/functional_requirements.md)). Incluye catálogo, búsqueda, ficha, cuenta, carrito local, checkout (ticket de un solo uso → checkout de WooCommerce con Wompi en navegador seguro), pedidos, sedes, PQRS, calculadora BTU (**condicionada a D-08**), eliminación de cuenta. **No incluye**: B2B/precios por rol, cotización estructurada, favoritos, push, seguimiento de envío, compra de invitado (supuesto S-02, H-10 pendiente).

---

## 2. Arquitectura en una página

```
App Flutter (Android/iOS)
   │  HTTPS, solo /mobile/v1  (Authorization: Bearer, sin secretos en el binario)
   ▼
Cloudflare (CDN/WAF; reglas para la app = condición C3, PENDIENTE)
   ▼
Next.js existente  ── BFF  /mobile/v1/*  (rutas NUEVAS: src/app/mobile/v1/**, lib/mobile/**)
   │   reutiliza lib/woocommerce.ts y lib/wc/*  (caché SWR, breaker, cola de 4, índice en RAM)
   ├── wc/v3 (clave de servidor; propuesta: solo lectura, SC-073) ──► WooCommerce
   └── ipr/v1/m/* (secreto del BFF + access token)               ──► WordPress (sesiones, cuenta, pedidos, handoff)
                                                                      │ checkout nativo
Navegador seguro del SO (Custom Tabs / ASWebAuthenticationSession) ───┴──► WooCommerce + Wompi
   └── retorno: /app/pedido (pista, nunca prueba) → la app consulta GET /mobile/v1/checkout/{checkoutRef}
```

| Componente | Responsabilidad | Estado hoy | Fuente |
|---|---|---|---|
| App Flutter | Presentación, carrito local, orquestar el traspaso al checkout. **Nunca decide** precio, impuestos, envío, stock ni estado del pago. | Por crear (M0 "en curso", §1.1) | [architecture_overview §2, §4](../03_architecture/architecture_overview.md) |
| BFF `/mobile/v1` | Contrato versionado, DTO por lista blanca, errores RFC 9457, caché/ETag, rate limit, ticket de checkout, proxy de auth hacia `ipr/v1`. | Por crear | [api_architecture](../05_api/api_architecture.md) |
| Capa de datos Next.js | Acceso a WooCommerce con timeout, reintentos, breaker. | **Existe**, se reutiliza con variantes sin cambiar firmas | [analisis_capa_woocommerce](../00_discovery/analisis_capa_woocommerce.md) |
| WordPress/WooCommerce | Fuente de verdad de catálogo, clientes, pedidos; `ipr/v1` heredado (un token por usuario, 30 días, sin refresh, `permission_callback = __return_true`). | **Existe**; `ipr/v1/m/*` por crear | [informe_codigo_frontend §5](../00_discovery/informe_codigo_frontend.md) |
| Wompi | Pasarela dentro del checkout de WooCommerce (la app no maneja datos de tarjeta). Webhook y doble pago: **DESCONOCIDO** (D-02, PA-11, TM-027). | Existe | ídem |
| Cloudflare | CDN/WAF delante del sitio; ¿delante de WordPress?: **DESCONOCIDO** (CR-075). | Existe | [deployment_architecture §12a](../03_architecture/deployment_architecture.md) |

**Restricción estructural (RIESGO).** BFF, web, caché, índice, breaker y limitador comparten **un solo proceso Node**; una degradación móvil puede degradar la web (RK-019, SLO-04). El número de procesos en producción es **DESCONOCIDO** (CR-035); si hay más de uno, Redis pasa a P0.

**Diagramas** (43 bloques Mermaid, todos con sintaxis válida según [mermaid_validation.md](../03_architecture/mermaid_validation.md); eso no garantiza legibilidad):

| Qué | Dónde |
|---|---|
| Arquitectura general, C4 nivel 1 y 2 (3 diagramas) | [c4_diagrams.md](../03_architecture/c4_diagrams.md) |
| Capas y features de la app (2a), feature interna (2b), red e interceptores (2c); app/BFF/WordPress (5a), módulos del BFF (5b), rutas de WordPress (5c), sesiones (5d), estados de sesión (5e) | [component_diagrams.md](../03_architecture/component_diagrams.md) |
| Login, refresh, reutilización, logout, cambio de contraseña (§6); catálogo (§7); carrito, **checkout y retorno** (§8, 8a-8d); WhatsApp (§9); integraciones (§10) — 21 diagramas | [data_flow.md](../03_architecture/data_flow.md) |
| Despliegue actual y propuesto, CI/CD, entornos y *flavors* (12a-12e) | [deployment_architecture.md](../03_architecture/deployment_architecture.md) |
| Entidad-relación (diagrama obligatorio nº 11 y parciales) | [entity_relationship.md](../04_database/entity_relationship.md) |

---

## 3. Stack y dependencias propuestas

Todo es **PROPUESTA** (ADR-003..ADR-012 en estado Propuesta). Versiones consultadas en pub.dev el 2026-11-18 según [flutter_app_architecture §17](../03_architecture/flutter_app_architecture.md); **ninguna se ha instalado ni probado en este proyecto**.

| Área | Propuesta | ADR | Marca |
|---|---|---|---|
| Plataforma | Flutter 3.50 / Dart 3.14; Android/iOS; mínimos reales por plataforma | — | Mínimos de plataforma: **NO VERIFICADO** (SPK-02, DN-01) |
| Arquitectura | *Feature-first*, capas presentation/domain/data, dominio ligero | ADR-003 | Propuesta |
| Estado/DI | `flutter_riverpod` 3.5.0 (sin generador) | ADR-004 | Verificado en pub.dev |
| Navegación | `go_router` 18.1.4; deep links nativos | ADR-005, ADR-008 | Verificado |
| Red | `dio` 5.11.1, taxonomía de fallos tipada, reintentos acotados | ADR-006 | Verificado; mapear por `code` (CR-073) |
| Persistencia | `flutter_secure_storage` 11.2.0 (tokens, id. de instalación); `hive_ce` 2.23.3 (carrito y caché pública); `shared_preferences` 2.5.6 | ADR-007 | `flutter_secure_storage`: comportamiento Keychain/Keystore **a verificar en SPK-03**; `hive_ce_flutter` y `path_provider`: **NO VERIFICADO** |
| Modelos | `freezed` 4.0.3 + `json_serializable` 6.15.2 + `build_runner` 2.17.1 | — | Verificado |
| UI | `cached_network_image` 4.0.7; `flutter_widget_from_html_core` 0.17.4 (HTML ya saneado, sin WebView); `intl` 0.20.3 | ADR-019 | Uso del HTML condicionado a SPK-04 |
| Navegador seguro | `url_launcher` 6.3.3 (`inAppBrowserView`) **o** `flutter_web_auth_2`; **no** `webview_flutter` | ADR-008 | Comportamiento de App Links tras 302: **NO VERIFICADO** (SPK-01); elección PENDIENTE (CR-004) |
| Fallos | `firebase_crashlytics` o `sentry_flutter` | ADR-010 | **PENDIENTE DN-02** y Jurídico (J-12) |
| Calidad | `very_good_analysis`, `mocktail`, `alchemist` 0.15.0, `integration_test` (SDK), `patrol` 4.11.0 | ADR-012 | `patrol` condicionado a SPK-01 |
| Excluidas por ahora | `riverpod_generator`, `app_links`, `drift`/`sqflite`, `connectivity_plus`, `http_certificate_pinning`, `firebase_messaging`, `firebase_analytics`, `envied`/`flutter_dotenv`, `webview_flutter`, `local_auth`, `flutter_html`, `golden_toolkit` (descontinuado) | — | Justificación en §17.2 de la fuente |
| Configuración | *Flavors* dev/staging/prod con `--dart-define-from-file`; **cero secretos en el binario** | ADR-009 | Identificadores por *flavor*: PENDIENTE DA-12/D-14 (no cambian tras publicar) |
| Seguridad de transporte | Sin *pinning* ni detección de root en el MVP (MASVS L1) | ADR-011 | Exige aceptación firmada (DA-15, CH-22) |

**Spikes previos (PT-12):** SPK-01 retorno del pago por plataforma; SPK-02 mínimos reales y tamaño; SPK-03 almacenamiento seguro; SPK-04 renderizado de descripciones saneadas. **Lado servidor (existente, verificado hoy en solo lectura):** Next.js 16.3.4 y React 19.2.8 (`ipr-frontend/package.json:16,18`); `package.json` solo define `dev`, `build`, `start`, `lint` (L5-9): no hay ejecutor de pruebas. Versión de Node de producción: **DESCONOCIDA**.

---

## 4. Contrato de API: 27 endpoints propuestos

Base propuesta: `https://iprpartesyrepuestos.com/mobile/v1`. **Ningún endpoint existe.** Detalle por endpoint: [api_contracts.md §3](../05_api/api_contracts.md); convenciones, caché, errores, límites: [api_architecture](../05_api/api_architecture.md).

| ID | Método y ruta | Auth | RF principales | Nota |
|---|---|---|---|---|
| EP-01 | `GET /config` | No | RF-005, 062, 094, 095, 099, 111 | Versión mínima, interruptores, contactos, `allowedHosts`, versiones legales |
| EP-02 | `POST /auth/register` | No | RF-038, 039 | Aceptación de políticas con versión; H-03 pendiente |
| EP-03 | `POST /auth/login` | No | RF-040, 043, 045, 048 | Sesión por dispositivo (`X-Device-Id`) |
| EP-04 | `POST /auth/refresh` | Refresh en cuerpo | RF-044 | Rotativo con detección de reutilización |
| EP-05 | `POST /auth/logout` | Sí | RF-041 | `scope`: `current` / `all` |
| EP-06 | `POST /auth/password/forgot` | No | RF-042, 045 | `202` uniforme (ADR-021) |
| EP-07 | `GET /me` | Sí | RF-104, 106 | Sin `roles` ni `username` |
| EP-08 | `PATCH /me` | Sí | RF-104 | |
| EP-09 | `POST /me/email` | Sí | RF-104 | Revoca las demás sesiones |
| EP-10 | `POST /me/password` | Sí | RF-105 | ídem |
| EP-11 | `PUT /me/addresses/{type}` | Sí | RF-106 | Depende de CR-045 (migración de direcciones) |
| EP-12 | `POST /me/deletion` | Sí | RF-110 | Dos tiempos (ADR-022); plazos tras Jurídico |
| EP-13 | `GET /categories` | No | RF-002, 010 | Público, 1 h |
| EP-14 | `GET /products` | No | RF-003, 011-015, 019 | Público, 5 min; tamaños de página {12, 24, 48} (ADR-020) |
| EP-15 | `GET /products/{slug}` | No | RF-026..032 | 404 ≠ 503; HTML saneado |
| EP-16 | `GET /filters` | No | RF-014, 089 | Público, 1 h |
| EP-17 | `GET /search` | No | RF-016, 020, 022, 023 | "Índice en construcción" ≠ "sin resultados" |
| EP-18 | `GET /search/suggestions` | No | RF-021, 022 | *Debounce* en la app |
| EP-19 | `GET /brands` | No | RF-004, 016 | Fuente canónica PENDIENTE (AP-05) |
| EP-20 | `GET /liquidaciones` | No | RF-007, 018 | |
| EP-21 | `POST /cart/validate` | No | RF-049, 050, 051 | ≤ 100 ids; nunca borra por error de red |
| EP-22 | `GET /stores` | No | RF-072..076 | Fuente en WordPress con respaldo empaquetado (ADR-018) |
| EP-23 | `POST /checkout` | Sí | RF-052, 053, 054, 058 | `Idempotency-Key` (obligatoria según CR-005 propuesta) |
| EP-24 | `GET /checkout/{checkoutRef}` | Sí | RF-055, 056, 057 | **Fuente de verdad del resultado del pago** |
| EP-25 | `GET /orders` | Sí | RF-107 | Paginado, control de propiedad |
| EP-26 | `GET /orders/{orderId}` | Sí | RF-056, 108 | `OrderDetail` (H-08 pendiente) |
| EP-27 | `POST /pqrs` | Opcional | RF-096, 097 | Límite persistente y compartido (CH-18) |

**Cómo leer `openapi.yaml`** (OpenAPI 3.1.0, `version: 1.0.0-draft`, 26 *paths*, 27 operaciones):
- Cada operación lleva `x-status: proposed`, `x-requirements` (RF/RNF que cubre) y `x-reuses` (código existente que reutiliza). Quitar `x-status: proposed` es parte de PT-01/G2-01, no antes.
- `tags`: config, auth, account, catalog, search, cart, checkout, orders, stores, support. `components` contiene `securitySchemes`, `parameters`, `headers`, `responses` y `schemas`.
- Éxito `{ "data": … }` (+ `meta` en listas); errores `application/problem+json` (RFC 9457) con `code` estable; el cliente **mapea por `code`**, no por texto (CR-073).
- Cabeceras: `X-App-Version` y `X-App-Platform` obligatorias; `X-Device-Id` en auth, cuenta, checkout, pedidos, PQRS y validación de carrito; `Authorization: Bearer` solo en cabecera (token en URL → `400 token_in_url_forbidden`).
- Si el YAML y `api_contracts.md` difieren, se corrige el que esté mal **en el mismo PR**.
- El YAML tiene **errores conocidos pendientes** (p. ej. importes: flotante frente a entero COP, CR-047; `paymentState`, `OrderDetail`): están en el Bloque D de la resolución. Antes de generar cliente o pruebas de contrato, **aplicar o descartar las CR del Bloque D**.

---

## 5. Autenticación y sesiones por dispositivo (PROPUESTA, ADR-013)

Hoy (HECHO): un token por usuario, 30 días fijos, sin refresh ni revocación por dispositivo, token aceptado por query/cuerpo/cabecera, `permission_callback = __return_true` en las rutas de `ipr/v1` (verificado hoy: `wp-snippets/ipr-auth-rest.php:378-408`). La web usa cookie `ipr_session` `httpOnly`.

| Parámetro | Valor propuesto | Estado |
|---|---|---|
| Access token | Opaco `ipra_…` 256 bits, **15 min**; solo hash SHA-256 en servidor | Valores PENDIENTES (H-04, AP-02, DN-04) |
| Refresh token | Opaco `iprr_…`, un solo uso, rota en cada uso; **30 días de inactividad / 90 días absolutos** | ídem |
| Reutilización | Revoca la sesión y responde `401 refresh_token_reused`; ventana de gracia de 30 s con el mismo `deviceId` | Propuesta |
| Sesiones por usuario | Máx. 10 (se revoca la más antigua) | Propuesta |
| Transporte | Access solo en `Authorization`; refresh solo en el cuerpo de `POST /auth/refresh` | Propuesta (SC-003) |
| Almacenamiento en la app | Access en memoria; refresh e id. de instalación en Keychain/Keystore; renovación de **vuelo único** (AC-044-6); fallo de red no borra tokens (AC-044-7) | Propuesta |
| Cierre de sesión | `current` o `all` (cierra también la web); lista de dispositivos en fase 2 | H-05 PENDIENTE |
| Roles | Solo `customer`/`subscriber` sin capacidades administrativas; denegar también en el *handoff* | H-09 PENDIENTE (requiere recuento de roles, DESCONOCIDO) |
| Anti fuerza bruta | Por cuenta 5/15 min con bloqueo progresivo y por IP 20/15 min, en BD de WordPress, **en el filtro `authenticate`** (todas las vías, XML-RPC bloqueado); fuente de IP del cliente definida (SC-077) | Propuesta; CH-02, NLS-12 |
| Tablas nuevas en WordPress | `ipr_auth_sessions`, `ipr_auth_events`, `ipr_auth_throttle`, `ipr_consents` | [authentication.md §8](../05_api/authentication.md) |

Flujos: [data_flow §6a-6e](../03_architecture/data_flow.md); componentes: [component_diagrams 5d/5e](../03_architecture/component_diagrams.md). Casos mínimos de prueba antes del piloto: [authentication §15](../05_api/authentication.md).

---

## 6. Checkout y retorno del pago

| Paso | Diseño (PROPUESTA) | Fuente |
|---|---|---|
| 1 | La app envía solo `items[{id, quantity}]` (1-100 líneas, cantidad 1-99) + `Idempotency-Key`. **Sin** precios, facturación ni URL de retorno. | [api_architecture §13](../05_api/api_architecture.md) |
| 2 | El BFF genera `checkoutRef` (UUID) y pide a WordPress un ticket de un solo uso (60 s); WordPress guarda `user_id` (no el token), `checkoutRef`, `channel=app`. | WP-06 |
| 3 | La app abre la URL **solo si el host ∈ `allowedHosts`**, en Custom Tabs (Android) o `ASWebAuthenticationSession` efímera (iOS). **Nunca WebView propio.** | CR-004: componente exacto PENDIENTE (SPK-01) |
| 4 | WooCommerce recalcula precio, impuestos, envío y stock; Wompi cobra. Cookie de WordPress no persistente para `app`; cierre de la sesión de WordPress en servidor al volver. | CH-05 |
| 5 | Retorno por `/app/pedido` (la web conserva `/pedido-confirmado`); **App Link/Universal Link = acelerador**, no mecanismo principal: WordPress **no redirige** en `failed`/`cancelled`/`pending`. | ADR-008 (absorbería ADR-017); H-02 PENDIENTE; CR-001..004 |
| 6 | La app consulta `GET /checkout/{checkoutRef}` (autenticado); los parámetros del enlace **nunca se creen**. El carrito se vacía **solo** con `paymentState = paid`. | RF-056, RF-057 |

Mapeo de estados WooCommerce → `paymentState`: `processing`/`completed` → `paid`; `pending` y `on-hold` → `pending` (el segundo es SUPUESTO, PA-12); `failed`, `cancelled`, `refunded`; otros → `unknown`. Estados reales que produce Wompi y **doble pago/webhook: DESCONOCIDO**; TM-027 los declara "no aceptables sin cerrar" (D-02, PA-11, CH-16, NLS-06). Diagramas: [data_flow 8a-8d](../03_architecture/data_flow.md).

**Hasta que existan staging y Wompi sandbox no se puede probar nada de este flujo** (RK-003, NLS-08).

---

## 7. Modelo de datos (resumen)

[data_model.md](../04_database/data_model.md) (conceptual), [data_dictionary.md](../04_database/data_dictionary.md) (41 entidades E01..E41, campo a campo, clasificación y retención), [entity_relationship.md](../04_database/entity_relationship.md) (6 diagramas ER).

| Grupo | Entidades | Estado |
|---|---|---|
| Existentes (WordPress/WooCommerce) | Usuario, dirección, token web heredado, producto, atributo, categoría, marca, etiqueta, imagen, pedido y línea, ticket de *handoff*, sedes y teléfonos, PQRS (solo correo) | `EXISTENTE`; la clave de usermeta de la cédula/NIT es **DESCONOCIDA** (CR-044) |
| Nuevas en WordPress | `ipr_auth_sessions`, `ipr_auth_events`, `ipr_auth_throttle`, `ipr_consents`, solicitud de eliminación, intento de checkout (`_ipr_checkout_ref`), configuración remota, documento legal versionado | `PROPUESTO` |
| En el BFF | Registro de idempotencia (en memoria), contador de rate limit, log técnico sin PII, caché e índice | Mixto |
| En el dispositivo | Tokens, carrito (`hive_ce`), caché pública con tope, intento de checkout local, preferencias | `PROPUESTO`; **sin PII persistente** (perfil, direcciones y pedidos solo en memoria) |
| Existentes y **fuera del MVP** | Directorio de asesores (no viaja a la app, RNF-065 = 0), boletín, ruleta, raspa y gana | Documentadas porque ya tratan datos personales |

Decisiones de datos pendientes: DM-01..DM-09 (p. ej. DM-02 cédula/NIT en el perfil, DM-03 unificar direcciones, DM-05 importes enteros COP, DM-09 fuente de marcas).

---

## 8. Seguridad

Documentos: [security_architecture](../06_security/security_architecture.md), [threat_model](../06_security/threat_model.md) (78 TM), [security_controls](../06_security/security_controls.md) (77 SC, 41 CH, NL/NLS), [security_testing](../06_security/security_testing.md) (140 ST), [security_review](../06_security/security_review.md). **Nada está verificado ni se afirma cumplimiento**: ningún control es eficaz sin su ST aprobada (hoy 0).

### 8.1 Veredicto del revisor independiente y sus correcciones

- **Veredicto:** "NO está listo para aprobarse tal cual; se puede aprobar **con condiciones**" (C-01..C-12, cambios de documento, no de código). De 41 citas a código comprobadas: 33 correctas, 8 parcialmente correctas, 0 falsas. Amenazas nuevas halladas: 16 (2 Alto, 9 Medio, 5 Bajo) = TM-063..TM-078.
- **Correcciones C-01..C-09 (P0): aplicadas** a los cuatro documentos de `06_security` el 2026-11-18 (SC §5.1; ninguna rechazada). Efecto: 78 TM, 77 SC (SC-073..SC-077 nuevos), ST hasta ST-174 (140 definidas), CH-38..CH-41, NLS-10..NLS-13.
- **C-10..C-16 (P1/P2): aplicadas solo en lo necesario**; el resto queda abierto.
- **No propagado:** el revisor lista **24 impactos** (I-01..I-24, §9 de la revisión) en otros documentos; **ninguno está aplicado**. Por eso roadmap, plan e informes siguen citando cifras anteriores (§17.2).
- **SC-073 (claves `wc/v3` de solo lectura y lista cerrada de parámetros) y SC-074 (2FA y cuentas privilegiadas) son PROPUESTAS que cambian la configuración de la plataforma y requieren aprobación humana.**
- Hallazgos que el diseño debe respetar: el *handoff* aplica el ticket a una sesión de WordPress ya abierta (confusión de sesión) y un ticket ajeno es un enlace legítimo (fijación); la cookie "no persistente" no basta en Android (INFERENCIA); faltan límites en "Mi cuenta" de WooCommerce y `lost-password`; `xmlrpc.php` con `system.multicall`; qué IP ve WordPress detrás de Cloudflare.

### 8.2 Cambios obligatorios previos a producción — P0 (23)

Ninguno está hecho (estado "Abierto"). Detalle y criterio de cierre: [security_controls §3.1](../06_security/security_controls.md); paquete: [implementation_plan §6.2](implementation_plan.md).

| CH | Cambio | Dónde | Paquete |
|---|---|---|---|
| CH-01 | Sesiones por dispositivo, rotación, reutilización, revocación (WP-01/02/12) | WordPress | PT-07 |
| CH-02 | Anti fuerza bruta persistente en el filtro `authenticate`, XML-RPC bloqueado, IP real, reglas de Cloudflare | WordPress, Cloudflare | PT-07, PT-11 |
| CH-03 | Token solo por cabecera (también el logout de la web, que hoy lo envía además en el cuerpo) | WP, BFF | PT-07 |
| CH-04 | Revocación global ante cambios sensibles; 5 fallos/h sobre `current_password` también en la ruta heredada | WordPress | PT-07 |
| CH-05 | *Handoff* seguro: `user_id`, ticket sin facturación ni identificación, cookie no persistente, cierre de sesión en servidor, **denegar roles administrativos** | WordPress | PT-08 |
| CH-06 | Autorización por objeto en pedidos y `checkoutRef` | WP, BFF | PT-08 |
| CH-07 | Visibilidad del catálogo (`catalog_visibility`, contraseña) y DTO por lista blanca | BFF, WP | PT-04, 05, 09 |
| CH-08 | HTML saneado en servidor + batería XSS en CI | BFF | PT-05 |
| CH-09 | Validación estricta, límites y RFC 9457; BFF sin cookies ni `Set-Cookie` de WordPress | BFF | PT-05, 06 |
| CH-10 | Limitador LRU y cola de `wcGet` acotada (**solo después de CH-11**) | BFF | PT-04 |
| CH-11 | Origen restringido a Cloudflare; Cloudflare delante de WordPress; IP de origen fuera de archivos versionados | Firewall, CF, CI | PT-11 |
| CH-12 | Puertas de CI en `ipr-frontend` + `npm audit`/OSV inicial | CI | PT-03, 20 |
| CH-13 | Escaneo de secretos del historial; rotación si aparece alguno | Repos | PT-03, 20 |
| CH-14 | App: almacenamiento seguro, sin backups, TLS estricto, *release* endurecido (MASVS L1) | App | PT-13..18, 20 |
| CH-15 | Checkout de la app: `allowedHosts`, navegador efímero, EP-24 como verdad, `.well-known`, idempotencia obligatoria | App, BFF, Next | PT-06, 11, 16 |
| CH-16 | Doble cobro: mecanismo de Wompi, firma de eventos, 0 duplicados en 100 interrupciones | WC, Wompi | PT-02, 08, 16 |
| CH-17 | Eliminación de cuenta, consentimiento y retención (dictamen de Jurídico archivado) | WP, App | PT-09, 21 |
| CH-18 | PQRS con límite compartido y persistente | CF o WP, BFF | PT-06, 11 |
| CH-19 | Logs sin PII y auditoría con alertas mínimas | App, BFF, WP | PT-22 |
| CH-20 | Custodia de firmas, titularidad de tiendas (D-14); 2FA en cuentas privilegiadas (SC-074, PROPUESTA) | Gobierno | PT-24 |
| CH-21 | Prueba de penetración independiente con reprueba | Tercero | PT-20 |
| CH-22 | Aceptación escrita: sin *pinning*, root, atestación, verificación de correo (si no se incluye) | Gobierno | PT-20 |
| CH-38 | Claves `wc/v3` del BFF de solo lectura y lista cerrada de parámetros (SC-073, PROPUESTA) | WC, BFF, CF | (no figura en la tabla §6.2 del plan; ver §17.2) |

P1: CH-23..CH-31, CH-39..CH-41 (12). P2: CH-32..CH-37 (6). Total 41.

### 8.3 Criterios de no-lanzamiento

| Familia | IDs | Resumen |
|---|---|---|
| NL (requisitos no funcionales) | NL-01..NL-14 (14) | Vulnerabilidades críticas/altas; fallo de compra o duplicado en staging; secretos en binario; tokens inseguros o en URL; sesiones por dispositivo; autorización; eliminación de cuenta y consentimiento sin revisar por Jurídico (D-12); logs con PII; sin monitoreo; MASVS L1; titularidad de tiendas (D-14); condiciones C1..C4; precios incorrectos; accesibilidad de flujos críticos ([NFR §5.1](../02_requirements/non_functional_requirements.md)) |
| NLS absolutos | NLS-01..NLS-08, NLS-10..NLS-13 (12; NLS-09 fusionado en NLS-02, ID no reutilizado) | Todo P0 sin cierre evidenciado; riesgo residual Alto/Crítico; `npm audit`/OSV sin ejecutar; rol administrativo con sesión; pedido o cobro duplicado; respuesta privada cacheada; sin staging; claves `wc/v3` con escritura; cuentas privilegiadas sin 2FA; vía de login sin límite persistente; sesión de WordPress persistente tras el pago |
| NLS condicionales | NLS-C1..NLS-C4 (4) | Residual Medio sin plan; P1 abiertos al piloto; origen no restringido; dependencias medias sin parche (requieren aceptación formal, plan y fecha) |

---

## 9. Privacidad: qué obliga a implementar

[privacy_assessment.md](../06_security/privacy_assessment.md) es un análisis técnico, **no un dictamen legal ni afirma cumplimiento de la Ley 1581**; la revisión jurídica (D-12) está **sin hacer** (las políticas y términos de IPR no se han leído). Lo siguiente son **requisitos de diseño** que el equipo debe implementar o dejar listos, sujetos a validación jurídica:

| # | Obligación de diseño | Fuente |
|---|---|---|
| 1 | Registro con **aceptación explícita** y prueba: versión de la política, fecha y canal (tabla `ipr_consents`); políticas accesibles **antes** de registrarse (RF-099, RF-039). | RNF-056; AUT §8.4 |
| 2 | **Eliminación de cuenta iniciable dentro de la app** y con enlace web (exigencia de las tiendas, S-05 **NO VERIFICADO**); qué se conserva y por cuánto lo fija Jurídico (H-11, J-04/05/17); ningún plazo del repositorio es legal. | RF-110; NL-07 |
| 3 | **Permisos mínimos**: solo Internet. Sin ubicación, push, cámara, contactos, IDFA/ATT ni biometría en el MVP. No recoger identificadores de hardware ni nombre del dispositivo. | AC-SEC-10; RNF-060 |
| 4 | **Sin PII en logs, reportes de fallos, analítica ni URLs** (valores canario en pruebas); sin PII persistente en el dispositivo. | RNF-047, RNF-062; AC-SEC-4/5 |
| 5 | Cédula/NIT es el dato de mayor riesgo del flujo de compra: minimizar en el ticket (CR-012) y no persistir en perfil sin decisión (DM-02). | PA §3 F-04 |
| 6 | Fichas de privacidad de Apple y Google **coherentes con el tráfico real** (incluidos SDKs); borradores A VALIDAR. | PA §8; NL-07 |
| 7 | Proveedor de fallos y Cloudflare implican probable **transmisión internacional**; hosting y SMTP: país **DESCONOCIDO**. Elegir proveedor condicionado a Jurídico (ADR-010, J-12). | PA §6 |
| 8 | Evaluar RNBD (umbral de activos DESCONOCIDO): bases nuevas en los dos meses siguientes a su creación, si aplica. | PA §2.3 |
| 9 | No llevar a la app datos de empleados (directorio de asesores, RF-102 *Won't*). | RNF-065 |
| 10 | Antes de publicar: **J-01..J-13 (P0) respondidas** y dictamen archivado (CH-17, G4-01). 36 preguntas en total (J-01..J-36). | PA §10 |

---

## 10. Calidad

| Aspecto | Estado | Fuente |
|---|---|---|
| Estrategia | Pirámide: unitaria (dominio y datos), widget, golden (`alchemist`), integración ligera (BFF simulado), integración en emulador, contrato (lado app y lado BFF), E2E en staging con Wompi sandbox (`patrol`, condicionado a SPK-01), rendimiento, accesibilidad, matriz de ≥ 8 dispositivos físicos, red lenta/sin conexión, regresión, manual. Seguridad: la define `security_testing.md`. | [testing_strategy §3](../08_quality/testing_strategy.md) |
| Casos | **160 TC**: P1 90 / P2 54 / P3 16; 151 automatizables y 9 no. **160 en "NO EJECUTADO"**. | [test_cases.md](../08_quality/test_cases.md) (recontado, §17) |
| Puertas de CI | QG-M01..M12 (app), QG-B01..B07 (BFF), QG-R01..R15 (release) = 34; pruebas del backend BE-01..BE-21 (BE-01..12 en CI web, BE-13..19 contra WordPress de staging, BE-20 carga, BE-21 Cloudflare/`.well-known`). | testing_strategy §7, §10 |
| Resultados | Ciclos ejecutados: **0**. `test_results.md` es plantilla con reglas que impiden aprobar sin evidencia. | [test_results.md](../08_quality/test_results.md) |
| Métricas | Todos los umbrales son **objetivos propuestos** (provienen de los RNF); la medición actual es "sin medición" y las 18 mediciones MED-01..MED-18 no existen. | [quality_metrics.md](../08_quality/quality_metrics.md) |
| `[A VALIDAR]` | 107 AC dependen de una decisión abierta: se registran como **decisión pendiente, no como defecto**; un AC `[A VALIDAR]` no se implementa por suposición (E-8 del plan). | testing_strategy §8.2 |
| Entorno | Sin staging con Wompi sandbox (C2) no pueden ejecutarse E2E, contrato contra staging ni pruebas de seguridad de auth/checkout/carga (NLS-08). Fixtures `QA-*` y cuentas `CLI-*` por crear. | testing_strategy §5 |

---

## 11. DevOps

| Tema | Propuesta | Fuente |
|---|---|---|
| Repositorios | `ipr-frontend` (web + BFF + `openapi.yaml` + `.well-known` + `/app/pedido` + `wp-snippets/`); **repositorio propio para la app** (DO-01, PROPUESTA); documentación versionada aparte (DO-02) | [git_strategy §2](../09_devops/git_strategy.md) |
| Ramas | **Trunk-based** con ramas cortas (≤ 2 días), `main` siempre desplegable/publicable, *squash*, Conventional Commits, `release/X.Y` solo para parches de una versión ya publicada; funcionalidad incompleta tras interruptor | git_strategy §3 |
| Protección | `main` protegida, revisión obligatoria (CODEOWNERS), commits firmados (DO-06), plantilla de PR con lista de seguridad | git_strategy §5, §7 |
| CI web (HECHO hoy) | Un único workflow que **despliega en cada push a `main`** (verificado: `deploy.yml:3-5`) sin `tsc`, lint, SCA ni pruebas. Propuesta: puertas QG-B01..B07 antes de desplegar, acciones por SHA, mínimo privilegio, aprobación del entorno `production`; con staging, `main` → staging y producción por tag. | [ci_cd §1, §4](../09_devops/ci_cd.md) |
| CI app | Etapas alineadas con QG-M01..M12, incluido ejecutor para iOS. Los YAML del documento son **ilustrativos, no probados**. | ci_cd §6 |
| Firma | Android: **Play App Signing** (Google custodia la clave de firma; clave de subida en gestor de secretos, ≥ 2 custodios, 2FA); huellas SHA-256 al `assetlinks.json`. iOS: preferida firma administrada por Apple con clave de API de App Store Connect (DO-12). **Sin claves ni certificados en repositorios o binarios.** Cuentas de tienda a nombre de Inverprimos S.A.S. (D-14, **sin confirmar**). | [deployment_guide §4](../09_devops/deployment_guide.md) |
| Entornos | dev / staging / prod; staging **no existe** y su dominio es DESCONOCIDO (CR-076); sin secretos en la app. | [environments.md](../09_devops/environments.md) |
| Lanzamiento | Pistas de prueba, despliegue escalonado, versión mínima forzada con cautela, reversa del BFF ≤ 15 min ensayada en staging (RNF-030). Requisitos de tiendas: re-verificar en fuente primaria antes de decidir. | deployment_guide §8-9 |

---

## 12. Operación

Todo es **PROPUESTA**: nada está montado ni ensayado ([monitoring](../10_operations/monitoring.md), [incident_response](../10_operations/incident_response.md), [logging](../10_operations/logging.md), [maintenance](../10_operations/maintenance.md)).

| Tema | Resumen |
|---|---|
| SLO propuestos (16, ninguno medido) | Disponibilidad del BFF ≥ 99,5 % mensual; latencia p95 (catálogo con caché ≤ 300 ms, sugerencias ≤ 150 ms, fallo de caché ≤ 2,5 s, login/refresh ≤ 1,5 s, ticket ≤ 2,0 s); 5xx < 1 %; degradación de la web por tráfico móvil ≤ 10 %; **0** pedidos o cobros duplicados; 0 respuestas 200 vacías por fallo ascendente; estado correcto del pedido ≤ 5 s tras volver; crash-free ≥ 99,5 %; ANR ≤ 0,3 %; índice de catálogo ≤ 15 min; reversa del BFF ≤ 15 min. Se calibran con MED-01..MED-18 y el piloto. |
| Alertas | 40 alertas en 6 familias (plataforma/BFF, WordPress, pagos, autenticación y abuso, app, borde). `GET /api/health` no consulta WooCommerce: hace falta monitoreo sintético funcional (RNF-102). |
| Severidades | SEV1 a SEV4; todo incidente con datos personales es **mínimo SEV2**. Cobertura (horario, guardia) PENDIENTE (DN-06). |
| Playbooks (10) | PB-01 caída de WooCommerce/WordPress/BFF · PB-02 degradación por carga móvil · PB-03 fuga o robo de tokens (revocación global) · PB-04 doble cobro o pagos sin confirmar · PB-05 administrador o secretos comprometidos · PB-06 *release* defectuoso (halt, interruptor, versión mínima) · PB-07 vulnerabilidad crítica en dependencia · PB-08 datos personales (Jurídico, SIC: formato real **NO VERIFICADO**) · PB-09 fuerza bruta · PB-10 abuso de PQRS. |
| Palancas | Interruptores remotos (`checkoutEnabled`, `pqrsEnabled`), revocación global, versión mínima, halt de despliegue: **son propuestas de diseño** (SC-052, SC-066, RNF-029); hasta que existan y se ensayen en staging (CH-29, ST-156, ST-128) cada playbook indica la alternativa manual. |
| Logs | Una línea JSON por solicitud con `requestId`, `userRef`/`deviceRef`; **nunca** tokens, contraseñas, correo, teléfono, dirección, cédula/NIT ni texto de búsqueda completo; prueba con valores canario. Retención A VALIDAR con Jurídico. |
| Mantenimiento | Calendario de dependencias, compatibilidad de Android/iOS/Flutter, rotación de secretos y certificados, respaldo y restauración, revisión trimestral del modelo de amenazas. |

---

## 13. Orden de construcción recomendado

Fuente: [implementation_plan.md](implementation_plan.md) (24 paquetes PT-01..PT-24, 4 puertas) y [roadmap.md §5](roadmap.md). **Todo es PROPUESTA**; no hay fechas, duraciones ni dotación (D-15).

**Principios:** el backend y WordPress van **un paso por delante** de la app (la app avanza contra un BFF simulado conforme al OpenAPI); nada toca producción antes de existir staging (C2) ni sin PR revisado (C1); los cambios en `lib/woocommerce.ts` **no cambian firmas** (se añaden variantes) y van en PR propio; los cambios en snippets compartidos con la web llevan regresión de la web; sin pruebas intrusivas fuera de staging (D-16); no se lee ni versiona `.env`.

### 13.1 Rebanadas de la app (76 RF)

| Rebanada | Contenido | RF | Paquete app (backend) | Aprobación mínima |
|---|---|---|---|---|
| **M0 Fundación** (*en curso, §1.1*) | Repositorio, *flavors*, CI de la app, red, sesión, almacenamiento, errores tipados, design system, BFF simulado | 0 (habilitadora) | PT-13 (+ PT-12) | G1-10, G1-11 |
| **M1 Catálogo y búsqueda sin sesión** | Inicio, categorías, listados, filtros, búsqueda, ficha, "Más información" → WhatsApp | 30 | PT-14 (PT-04, 05, 10) | H-06 |
| **M2 Cuenta** | Registro, login, logout, recuperación, sesión por dispositivo, páginas legales | 10 | PT-15 (PT-06, 07, 09) | H-03, H-04, H-05, H-07, H-09 |
| **M3 Carrito y compra** | Carrito local, revalidación, checkout, retorno y resultado | 11 | PT-16 (PT-06, 08, 11, 12) | H-02, H-10; D-02 (Wompi) |
| **M4 Perfil, pedidos y eliminación de cuenta** | Perfil, contraseña, direcciones, pedidos, eliminación | 7 | PT-17 (PT-09, 21) | H-08, H-11; Jurídico |
| **M5 Sedes, atención, asesoría y herramientas** | Sedes, ayuda, PQRS, asesoría, calculadora BTU | 18 | PT-18 (PT-10, 23) | D-08, D-09 |

30 + 10 + 11 + 7 + 18 = 76. **Una rebanada no se publica por separado**: el lanzamiento exige M0..M5 (eliminación de cuenta y política de privacidad son requisitos de tienda, S-05 NO VERIFICADO).

### 13.2 Paquetes de trabajo

| PT | Nombre | Etapa | Rebanada | Esf. | Depende de |
|---|---|---|---|---|---|
| PT-01 | Gobierno de decisiones y cierre del contrato | 1 | — | M | Decisores humanos; PT-02 |
| PT-02 | Staging, entornos y datos de prueba (C2) | 2 | — | M | G1 |
| PT-03 | CI/CD y puertas de calidad del repositorio web | 2 | — | M | PT-02 |
| PT-04 | Endurecimiento de la capa de datos compartida | 2 | B1 | L | PT-03 |
| PT-05 | BFF: infraestructura y catálogo público | 3 | B1 | L | PT-04 |
| PT-06 | BFF: cuenta, checkout, pedidos y PQRS | 3 | B2-B5 | L | PT-05, 07, 08, 09 |
| PT-07 | WordPress: sesiones por dispositivo y anti fuerza bruta | 2 | B2 | XL | PT-02; H-01, H-04, H-09 |
| PT-08 | WordPress: *handoff* seguro, checkout móvil y pedidos | 2-3 | B3 | L | PT-02, 07, 09 (CR-045) |
| PT-09 | WordPress: registro, cuenta, recuperación y eliminación | 3 | B2, B4 | L | PT-02, 07; D-12, H-03, H-11 |
| PT-10 | Configuración remota, sedes y marcas administrables | 3 | B1, B5 | M | PT-05; H-01; D-09 |
| PT-11 | Borde y dominio: Cloudflare, origen, App Links | 2 | B3 | M | PT-02; H-02; D-14 |
| PT-12 | Spikes técnicos y selección de herramientas | 2 | M0 | M | PT-02 (SPK-01) |
| PT-13 | App Flutter: fundación | 2 | M0 | L | PT-12; DA-01; DA-12 |
| PT-14 | App: catálogo, búsqueda, ficha y contacto | 3 | M1 | L | PT-13, 05, 10 |
| PT-15 | App: cuenta | 3 | M2 | L | PT-13, 06, 07, 09 |
| PT-16 | App: carrito y compra | 3 | M3 | XL | PT-14, 15, 08, 11, 12 |
| PT-17 | App: perfil, pedidos y eliminación de cuenta | 3 | M4 | M | PT-15, 09, 08, 21 |
| PT-18 | App: sedes, atención, asesoría y herramientas | 3 | M5 | L | PT-13, 10, 06, 23 |
| PT-19 | Pruebas: contrato, BFF, E2E, matriz, accesibilidad, carga | 2-5 | Todas | L | Continuo desde PT-03 |
| PT-20 | Seguridad: SAST, SCA, secretos, MASVS, pentest, aceptaciones | 2-5 | Todas | L | Continuo; pentest tras M5 |
| PT-21 | Privacidad y revisión jurídica (D-12) | 2-5 | M2, M4 | M | Documentos de IPR |
| PT-22 | Observabilidad y operación | 3-6 | Todas | M | PT-05; DN-02 |
| PT-23 | Datos de catálogo y contenido de IPR | 2-4 | M1, M5 | M | D-07..D-10, D-13 |
| PT-24 | Lanzamiento: tiendas, piloto y producción | 6 | — | M | Gate G4 |

**Puertas:** G1 (21 casillas: inicio de implementación), G2 (6 condiciones por rebanada: "listo para integrar"), G3 (5: verificación formal), G4 (8: piloto y lanzamiento). **Todas sin marcar.** El plan nombra "Los 22 cambios P0" en G3-03; el recuento da 23 (§17.2).

**Ruta crítica (RC-1..RC-7):** conformidad del responsable técnico (C1) y enmienda de ADR-001 (H-01); staging con Wompi sandbox y autorización D-16/H-12; cambios P0 compartidos en `ipr-frontend` con regresión de la web; sesiones por dispositivo (WP-01..05, WP-12); Wompi (estados, webhook, doble pago); revisión jurídica (J-01..J-13); App Links/Universal Links y Cloudflare.

---

## 14. Cambios obligatorios en `ipr-frontend` y WordPress ANTES de la app

El BFF vive en `ipr-frontend` y WordPress es su backend; **la app no puede cerrar M2, M3 ni M4 sin estos cambios**. Todo requiere PR revisado por el responsable técnico (C1) y regresión de la web. Fuente: [api_architecture §16](../05_api/api_architecture.md) (18 FE + 16 WP).

### 14.1 Estado verificado hoy (solo lectura; el repositorio recibe commits, las líneas pueden moverse)

| Verificación (2026-11-19) | Resultado |
|---|---|
| `src/app/mobile/` | **No existe** |
| `public/.well-known/` | **No existe** |
| `wp-snippets/` | 5 archivos: `ipr-auth-rest.php`, `ipr-cart-handoff.php`, `ipr-front-redirect.php`, `ipr-raspa-y-gana-samsung.php`, `ipr-ruleta-midea.php` |
| `.github/workflows/` | Solo `deploy.yml`, disparado en `push` a `main` (L3-5) |
| `package.json` | Scripts `dev`, `build`, `start`, `lint` (L5-9); sin ejecutor de pruebas |
| `ipr-auth-rest.php` | `permission_callback => '__return_true'` en las rutas de `ipr/v1` (L378-408) |

### 14.2 `ipr-frontend` (Next.js) — prioridad P0

| ID | Cambio | Paquete |
|---|---|---|
| FE-01 | `status=publish`, excluir `catalog_visibility = hidden` y productos con contraseña en ficha, listados, búsqueda e índice | PT-04 |
| FE-02 | Variantes con resultado discriminado `ok`/`not_found`/`unavailable` **sin cambiar firmas** | PT-04 |
| FE-03 | DTO por lista blanca: sin `stockQuantity`, precio `null` si es 0, HTML saneado en servidor | PT-05 |
| FE-04 | Rutas `src/app/mobile/v1/**` + `lib/mobile/*`: RFC 9457, Zod `strict`, request id, `426`, rechazo de token en URL | PT-05, 06 |
| FE-05 | Limitador LRU por clase e IP desde `CF-Connecting-IP` (**solo tras CH-11**) | PT-04 |
| FE-06 | Cola de `wcGet` con tope y espera ≤ 3 s → 503 | PT-04 |
| FE-07 | Índice: señal "en construcción", verificación del módulo, alerta si `totalPages > 100` | PT-04 |
| FE-08 | Disponibilidad por ids con caché por id (≤ 100) | PT-04, 05 |
| FE-09 | Checkout móvil: `POST /mobile/v1/checkout`, `GET /mobile/v1/checkout/{ref}` | PT-06 |
| FE-10 | `.well-known/assetlinks.json` y `apple-app-site-association`, página `/app/pedido` (`noindex`), `robots.txt` con `Disallow: /mobile/` | PT-11 |
| FE-11 | CI: `tsc --noEmit`, ESLint, `npm audit`/OSV, secretos, pruebas de contrato; el despliegue depende de ellas | PT-03 |

P1: FE-12..FE-17 (métricas `origin=mobile`, `/api/revalidate` solo HMAC, `getBrands()`, `/stores` y `/config`, `lib/pqrs.ts`, timeouts en `auth.ts`). P2: FE-18 (sesión web a la tabla de sesiones).

### 14.3 WordPress — prioridad P0

| ID | Cambio | Paquete |
|---|---|---|
| WP-01 | Tabla `ipr_auth_sessions` + `ipr/v1/m/sessions*` (login, refresh rotativo, revocación) | PT-07 |
| WP-02 | `permission_callback` real: `X-IPR-BFF-Secret` (`hash_equals`) + access token | PT-07 |
| WP-03 | Anti fuerza bruta por cuenta e IP en BD | PT-07 |
| WP-04 | Token **solo** por `Authorization` | PT-07 |
| WP-05 | Revocación global ante cambio de credenciales, restablecimiento, `wp-admin`, `delete_user` | PT-07 |
| WP-06 | `handoff-ticket`: access token de sesión móvil, `user_id`, `checkoutRef`, `channel`, cookie no persistente | PT-08 |
| WP-07 | `ipr/v1/m/orders` paginado con control de propiedad | PT-08 |
| WP-08 | `ipr/v1/m/me*` con lista blanca de campos | PT-09 |
| WP-09 | Eliminación de cuenta (revocación inmediata + anonimización programada) | PT-09 |
| WP-10 | Recuperación de contraseña por API, `202` uniforme | PT-09 |
| WP-11 | Registro móvil con aceptación de términos y política registrada | PT-09 |
| WP-12 | Tabla de auditoría `ipr_auth_events` y limpieza programada | PT-07 |

P1: WP-13 (sedes y `ipr_mobile_config`), WP-14 (`__return_true` en rutas heredadas), WP-15 (paginar `/orders` heredado). P2: WP-16 (rotación de secretos con doble valor; adelantado por CH-26).

### 14.4 Tres cambios en snippets **compartidos con la web** (regresión de la web obligatoria)

1. **CR-010:** cookie del *handoff* no persistente y con filtro de rol (hoy persistente y sin comprobar el rol).
2. **CR-012:** nuevo formato del ticket (sin facturación ni identificación).
3. **CR-045:** migración de direcciones a `WC_Customer` con respaldo del meta heredado (hoy se guardan en un meta que WooCommerce no lee); **debe entregarse primero dentro de PT-09**, porque quitar la facturación del ticket sin migrar rompe el prellenado.

### 14.5 Infraestructura previa

Staging con Wompi sandbox (C2) y dominio propio; Cloudflare delante de WordPress y origen restringido (CH-11); reglas de Cloudflare sin desafíos para `/mobile/v1/*` y `/.well-known/*` (C3); 2FA en cuentas privilegiadas (SC-074, PROPUESTA).

---

## 15. Deuda y puntos abiertos

### 15.1 Contradicciones CR sin resolver

**89 contradicciones (CR-001..CR-089), ninguna aplicada ni descartada:** 74 técnicas, 10 de producto (CR-013, 017, 027, 030, 040, 049, 053, 055, 078, 089) y 5 legales (CR-056, 061, 081, 082, 083). Cada una trae opciones, recomendación y "cambio exacto" en [resolucion_inconsistencias.md](resolucion_inconsistencias.md). Las que bloquean el diseño:

| # | CR | Por qué importa |
|---|---|---|
| 1 | CR-010 | El *handoff* crea una cookie persistente sin comprobar el rol |
| 2 | CR-038 | `ipr/v1/m` excede el "únicamente" de ADR-001 §2; sin enmienda, riesgo BOLA |
| 3 | CR-030 | Enumeración de cuentas en el registro; cambia el alcance (verificación de correo) |
| 4 | CR-001/002/003 | Ruta y mecanismo de retorno del pago; ADR-008 y ADR-017 duplicadas |
| 5 | CR-045 + CR-012 | Direcciones y ticket: afecta a la web |
| 6 | CR-035 | Límites en memoria por proceso; IP falsificable; sin el dato de procesos Node puede no haber protección |
| 7 | CR-028 | Sin filtro de rol, cuentas administrativas podrían entrar |
| 8 | CR-047 | Importes en flotante frente a entero COP |
| 9 | CR-005 / CR-009 | `Idempotency-Key` opcional u obligatoria; respuesta ambigua ante referencia ajena |
| 10 | CR-020 / CR-019 | Manejo del refresh y del almacenamiento del access |

Además, **TM-027 (doble pago y webhook de Wompi)** es "no aceptable" sin cerrar D-02/PA-11.

### 15.2 DESCONOCIDOS (resolver en PT-02, requieren H-12/D-16)

| Dato | CR | Cómo obtenerlo |
|---|---|---|
| N.º de procesos Node en producción | CR-035 | Unidad systemd/PM2 (lectura) |
| ¿Cloudflare delante de WordPress? ¿Origen restringido? | CR-075 | Cabeceras, DNS, reglas del firewall |
| Estados que produce Wompi; doble pago | CR-018 | Transacciones sandbox en staging |
| Roles existentes de clientes | CR-028 | Recuento por rol en staging |
| Zona horaria del sitio | CR-052 | `timezone_string` |
| Longitud de `user_email` | CR-060 | `DESCRIBE wp_users` |
| Versiones de PHP, WordPress y Node | CR-079 | Site Health; `node -v` |
| Caché de objetos persistente | CR-011 | `wp cache type` / Site Health |
| Clave de usermeta de la cédula/NIT | CR-044 | Cliente de prueba en staging |
| Dominio de staging | CR-076 | Decisión de infraestructura (C2) |

Otros DESCONOCIDOS: plan de Cloudflare, configuración de Wordfence, destino de logs, plan de GitHub, equipo y presupuesto (D-15), titularidad de las cuentas de tienda (D-14), rol de cada tercero en la Ley 1581 y país de hosting y SMTP.

### 15.3 Decisiones H-01..H-12 pendientes

Recomendaciones del revisor, **no aprobadas** ([decisiones_pendientes §E](decisiones_pendientes.md)):

| H | Pregunta | Recomendación | CR |
|---|---|---|---|
| H-01 | Enmienda de ADR-001 §2: `ipr/v1/m/*` incluye registro, perfil, direcciones, pedidos, consentimientos, config y sedes | Sí | 038 |
| H-02 | Retorno por `/app/pedido`; resultado siempre consultando al servidor; fusionar ADR-017 en ADR-008 | Sí | 001-003 |
| H-03 | Registro con correo existente: respuesta uniforme + verificación de correo, o `409` con riesgo firmado | Uniforme + verificación | 030 |
| H-04 | Access 15 min; refresh 30 d de inactividad / 90 d absolutos | Sí | 022, 025 |
| H-05 | MVP solo con "cerrar todas" (incluida la web) | Solo cerrar todas | 027 |
| H-06 | "Bajo pedido": ¿comprable en la app? | No (WhatsApp) | 017 |
| H-07 | Carrito: conservar al cerrar sesión, borrar al eliminar la cuenta | Conservar y borrar | 040 |
| H-08 | Detalle de pedido con envío, descuento e impuestos (cambia AC-108-2) | Sí | 053 |
| H-09 | Solo `customer` y `subscriber` sin capacidades administrativas | Sí, tras contar roles | 028 |
| H-10 | Sin compra como invitado | Sin invitado | 013 |
| H-11 | (Jurídico) Eliminación sin periodo de gracia, supresión ≤ 15 días hábiles, retención contable por Jurídico | Sin gracia | 081, 083 |
| H-12 | Autorizar staging con Wompi sandbox y lectura de solo lectura del servidor | Sí | 018, 035, 075, 079… |

Siguen abiertas sin recomendación cerrada: D-02 (webhook/doble pago), D-05 (stock por sede), D-08 (fórmula BTU), D-12 (Ley 1581), C1..C4 de ADR-001, DN-01..DN-14, DM-01..DM-09, DA-01..DA-15, AP-01..AP-10, PA-01..PA-12, J-01..J-36.

### 15.4 Otra deuda documental

- Los documentos no incorporan las 89 CR: **ADR-003..022 no se han copiado** a `architecture_decisions.md` (solo contiene ADR-001 y ADR-002).
- **RF-114 (B2B "Won't/fase 2") se menciona y no existe** (CR-089).
- La matriz de trazabilidad tiene recuentos de RNF erróneos (CR-087, §17.2).
- Cifras antiguas en roadmap, plan de implementación y mantenimiento (§17.2).
- Los 24 impactos de la revisión de seguridad no se han propagado a los demás documentos.

---

## 16. Cómo contribuir a esta documentación

| Regla | Detalle |
|---|---|
| **IDs estables** | RF, RNF, US, AC, TC, TM, SC, ST, CH, CR, RK, EP, FE, WP, PT, ADR, D, H, DN, DM, DA, AP, PA, J **no se renumeran ni se reutilizan**. Lo retirado se marca (ejemplos: NLS-09 "fusionado"; ADR-017 "retiro propuesto"; los huecos de numeración de ST son históricos). |
| Formato de IDs | `RF-nnn`; `US-nnn` = `RF-nnn` (US-0xx ↔ RF-0xx); `AC-nnn-k` y `AC-SEC-k`; `TC-nnn`; `ST-nnn`; `PT-nn` (**no** `WP-nn`: `WP-01..16` ya son cambios de WordPress); `FE-nn`/`WP-nn` cambios; `CH-nn` cambios obligatorios de seguridad. |
| Etiquetas | Toda afirmación lleva HECHO / SUPUESTO / PROPUESTA / PENDIENTE / RIESGO / DESCONOCIDO / NO VERIFICADO. HECHO exige cita `archivo:línea` o sección. **No** usar lenguaje de cumplimiento ("cumple", "es seguro", "conforme") para nada no verificado; un objetivo nunca se redacta en pasado. |
| Estados | Borrador / Propuesta / Aprobada. **Solo un humano aprueba** y se registra en `architecture_decisions.md` y `decisiones_pendientes.md`; cambiar un estado a "Aprobada" sin esa constancia es un error. |
| Cifras | No copiar cifras de otro documento: recontarlas por script (§17) y citar la fuente y la fecha. |
| Contrato | `api_contracts.md` y `openapi.yaml` se corrigen **en el mismo PR**. |
| Pruebas | Un caso no pasa a "Aprobado" sin evidencia, fecha, versión, entorno y dispositivo ([test_results.md](../08_quality/test_results.md)). |
| Seguridad y privacidad | **Sin secretos, IP de origen, datos personales reales ni valores de `.env`** en ningún documento; no abrir `.env`. |
| **Qué no tocar** | `architecture_decisions.md` (solo ADR aprobadas, por decisión humana); las filas de aprobación de `decisions_log.md` y `decisiones_pendientes.md`; `ipr-frontend` (solo lectura para la documentación); la numeración de IDs. Aplicar una CR solo con su aprobación y registrando quién la aprobó. |
| Diagramas | Mermaid validado con `mermaid.parse()`; un diagrama nuevo se valida y se añade a [mermaid_validation.md](../03_architecture/mermaid_validation.md). |
| Fechas | ISO `AAAA-MM-DD`; el orden dentro de un mismo día no se inventa. |

---

## 17. Tabla de verdad

**Fecha del recuento: 2026-11-19.** Método: script de Python (expresiones regulares sobre las filas o encabezados que **definen** cada ID, IDs únicos), ejecutado sobre `docs/` (56 archivos al recontar: 55 `.md` + `openapi.yaml`, antes de crear este informe y el README). No se copió ninguna cifra de los informes. Detalle en el anexo.

### 17.1 Cifras recontadas

| Concepto | Recuento | Fuente donde se define | Declarado por los documentos | ¿Coincide? |
|---|---|---|---|---|
| RF | **113** (MVP sí 76 · fase 2 32 · no 5; *Must* 47 · *Should* 31 · *Could* 25 · *Won't* 10) | [functional_requirements §1](../02_requirements/functional_requirements.md) | 113 / 76 (scope, FR, TR) | Sí |
| RNF | **116** (prioridad base: *Must* 77 · *Should* 36 · *Could* 3; RNF-066 y RNF-089 con prioridad condicional) | [non_functional_requirements §4](../02_requirements/non_functional_requirements.md) | NFR §0.3: 116 (77/36/3). **TR §4: 77/35/2 = 114** | NFR sí; **TR no** (CR-087) |
| US | **76** (US-xxx ↔ RF-xxx) | [user_stories §1](../02_requirements/user_stories.md) | 76 | Sí |
| AC | **490** (477 en historias + 13 `AC-SEC`); con `[A VALIDAR]`: 107; por tipo: Integración 198 · Widget 109 · Seguridad 95 · Unitaria 34 · E2E 34 · Manual 20 | [acceptance_criteria §1, §3](../02_requirements/acceptance_criteria.md) | 490 / 107 / 477 / 13 | Sí |
| TC | **160** (P1 90 · P2 54 · P3 16; 151 automatizables; 160 "NO EJECUTADO") | [test_cases §6](../08_quality/test_cases.md) | 160 | Sí |
| TM | **78** | [threat_model §2](../06_security/threat_model.md) | 78 (TM, SA); roadmap y mantenimiento: **62** | TM sí; **roadmap/maintenance no** |
| SC | **77** | [security_controls §1](../06_security/security_controls.md) | 77; roadmap: **72** | SC sí; **roadmap no** |
| ST | **140 definidas** (identificadores ST-001..ST-174 con huecos; 140 "NO EJECUTADO") | [security_testing](../06_security/security_testing.md) | 140; plan y roadmap citan "ST-001..ST-160" | Sí con security_testing; **plan no** |
| CH (cambios de seguridad) | **41** (P0 23 · P1 12 · P2 6) | [security_controls §3.4](../06_security/security_controls.md) | 41 / 23; **roadmap, plan y mantenimiento: 22 P0** (mantenimiento: 9 P1) | SC sí; **otros no** |
| NL / NLS / NLS-C | **14 / 13 IDs (12 activos; NLS-09 fusionado) / 4** | NFR §5.1; security_controls §4 | security_controls: 12 y 4; **roadmap: 9 NLS** | SC sí; **roadmap no** |
| Endpoints `/mobile/v1` | **27 operaciones en 26 *paths*** (EP-01..EP-27) | [openapi.yaml](../05_api/openapi.yaml); [api_contracts §2](../05_api/api_contracts.md) | 27 | Sí |
| ADR | **22** (ADR-001..ADR-022): 2 aprobadas, 20 propuestas (ADR-017 con retiro propuesto). ADR-023 y ADR-024 son candidatas y **no existen**. | architecture_decisions; architecture_overview §9; api_architecture §18 | 22 (decisions_log) | Sí |
| CR | **89 identificadores** (88 filas de tabla + la ficha de CR-053, que el propio documento ubica fuera del bloque C): 74 técnicas · 10 producto · 5 legales | [resolucion_inconsistencias](resolucion_inconsistencias.md) | 89 | Sí (el recuento por filas da 88; ver nota) |
| RK | **59** (37 Alto · 22 Medio; ninguno Crítico ni Bajo) | [risks §2-§6](risks.md) | 59 | Sí |
| D | **16** (D-01..D-16); aprobadas: D-01 (≡ ADR-001), D-03, D-04, D-06 | decisiones_pendientes | decisions_log: 4 aprobadas | Sí |
| H | **12** (H-01..H-12), todas pendientes | decisiones_pendientes §E | 12 | Sí |
| PT (paquetes) | **24** | [implementation_plan §2](implementation_plan.md) | 24 | Sí |
| FE / WP (cambios) | **18 / 16** | [api_architecture §16](../05_api/api_architecture.md) | 18 / 16 | Sí |
| Entidades de datos | **41** (E01..E41) | [data_dictionary](../04_database/data_dictionary.md) | — | n/a |
| SLO / alertas / playbooks | **16 / 40 / 10** | monitoring §4, §11; incident_response §6 | 40 alertas; 10 playbooks | Sí |
| Puertas de calidad | **34** (QG-M 12 · QG-B 7 · QG-R 15); **BE 21** | testing_strategy §7, §10 | — | n/a |
| MED | **18** (MED-01..MED-18), ninguna ejecutada | NFR §6 | 18 | Sí |
| Diagramas Mermaid | **43** en 5 archivos (c4 3 · componentes 8 · flujos 21 · despliegue 5 · ER 6) | [mermaid_validation](../03_architecture/mermaid_validation.md) | 43 | Sí |
| Preguntas jurídicas J | **36** (J-01..J-36) | privacy_assessment §10 | 36 | Sí (IDs referenciados) |
| DN / DM / DA / PA | **14 / 9 / 15 / 12** | decisions_log §1.1 | 14 / 9 / 15 / 12 | Sí (IDs referenciados) |
| AP | **11 IDs distintos** (AP-01..AP-11) | api_architecture §17.3; authentication §16 | **10** (decisions_log: AP-01..AP-10) | **No**: AP-11 aparece en authentication §16 y se equipara a H-05 |

> Nota CR: el recuento de filas `| CR-nnn |` da 88 porque CR-053 tiene ficha propia justo después de [§4.1 de la resolución](resolucion_inconsistencias.md); contando identificadores definidos son 89, como declara el documento.

### 17.2 Discrepancias entre lo declarado y el recuento

| # | Documento | Declara | Recuento | Efecto |
|---|---|---|---|---|
| 1 | [requirements_traceability §4](../02_requirements/requirements_traceability.md) | RNF: 77 *Must* / 35 *Should* / 2 *Could* (= 114) y "Inconsistencias 0" | 116 (77/36/3 con prioridad base) | Ya registrada como CR-087 (sin aplicar) |
| 2 | [roadmap.md](roadmap.md) (Etapa 1) | 72 controles, 62 amenazas | **77 SC, 78 TM** | Cifra anterior a las correcciones C-01..C-09 |
| 3 | roadmap (Etapa 5), [implementation_plan G3-03](implementation_plan.md), [maintenance §10](../10_operations/maintenance.md) | 22 cambios P0 (mantenimiento además: 9 P1) | **23 P0** (CH-01..CH-22 + CH-38), **12 P1** | Un cambio P0 (CH-38) queda fuera de las tablas del plan |
| 4 | roadmap (Etapa 5) | "9 criterios absolutos NLS-01..NLS-09" | **12 activos** (NLS-01..08 y NLS-10..13) | NLS-10..NLS-13 nuevos |
| 5 | implementation_plan (PT-20) y roadmap | `ST-001..ST-160` | IDs hasta **ST-174** (140 definidas) | ST-161..ST-174 no cubiertas por PT-20 |
| 6 | [maintenance §9](../10_operations/maintenance.md) | Modelo de amenazas con 62 amenazas | 78 | Cifra anterior |
| 7 | [security_review.md](../06_security/security_review.md) (cabecera) | 62 TM, 72 SC, 126 ST | 78 / 77 / 140 | Es una **instantánea previa** a las correcciones; no es un error en sí |
| 8 | [resumen_ejecutivo.md](resumen_ejecutivo.md) | "lista de 21 impactos" (revisión de seguridad §9) | **24** (I-01..I-24) | Cifra incorrecta en el resumen |
| 9 | decisions_log §1.1 | AP-01..AP-10 (10) | 11 IDs (AP-11 existe) | Ver §17.1 |
| 10 | resolucion_inconsistencias §4.1 frente a Anexo B | 8 CR dependen de un DESCONOCIDO (CR-018, 028, 035, 052, 060, 075, 076, 079) | El Anexo B lista **10** datos (añade CR-011 y CR-044) | Incoherencia interna menor |
| 11 | resolucion (CR-089), scope, decisions_log | RF-114 "propuesto" | **No existe** en `functional_requirements.md` | Pendiente de CR-089 |

No recontadas (declaradas por los documentos; **no verificadas**): "75 AC delegados a seguridad" y "26 AC no-seguridad sin caso de prueba" (roadmap, plan); "17 amenazas con residual Medio" (security_controls §4.2).

### Anexo. Método de recuento (reproducible)

- **RF, RNF, US:** filas de tabla que empiezan por `| RF-nnn |`, `| RNF-nnn |`, `| US-nnn |` en su documento definidor (el documento de RF tiene además filas de otra tabla con IDs repetidos: se cuentan IDs únicos y la tabla principal para MoSCoW y MVP).
- **AC:** líneas `- **AC-…-k**` de `acceptance_criteria.md` (tipo en el primer campo entre acentos graves; `[A VALIDAR]` por línea).
- **TC:** encabezados `#### TC-nnn`; prioridad y capa del campo "Prioridad · Capa · Automatizable".
- **TM, SC, ST, CR, RK, CH:** filas `| XX-nnn |` de su documento definidor (CR-053 se añade por su ficha).
- **ADR:** encabezados `## ADR-nnn` / `### ADR-nnn` en los tres documentos que las contienen, contrastados con la tabla de `decisions_log.md`.
- **Endpoints:** en `openapi.yaml`, claves de segundo nivel de `paths:` (26) y operaciones `get|post|put|patch|delete` de tercer nivel (27).
- **Familias secundarias (NL, NLS, MED, DN, DM, DA, PA, J, AP, EP, FE, WP, BE, QG):** IDs únicos mencionados en todo `docs/`; no prueban por sí solos que estén definidos.
- Los IDs de prueba de seguridad **no son contiguos** (huecos de numeración históricos): el número de pruebas es el de filas definidas, no el último ID.

*Fin del documento. BORRADOR: ninguna decisión aprobada salvo ADR-001, ADR-002, D-03, D-04 y D-06; ninguna prueba ejecutada; nada se afirma construido.*

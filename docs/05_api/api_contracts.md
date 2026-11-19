# Contratos de la API móvil `/mobile/v1` (MVP)

| | |
|---|---|
| **Fase** | Tercera entrega — Arquitectura. **No se programa nada.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. **Ningún endpoint `/mobile/v1` existe hoy: los 27 son PROPUESTOS.** Para cada uno se cita el código existente que reutiliza. Los endpoints que **sí** existen (rutas `/api/*` del sitio e `ipr/v1` de WordPress) se listan en el Anexo A solo como base de implementación: la app **no** los consume (ADR-001). |
| **Especificación formal** | [openapi.yaml](openapi.yaml) (OpenAPI 3.1, `x-status: proposed` en cada operación). Si este documento y el YAML difieren, se corrige el que esté mal en el mismo PR. |
| **Relacionado** | [api_architecture.md](api_architecture.md) (convenciones, caché, errores, rate limiting, flujos) · [authentication.md](authentication.md) (sesiones) |
| **Alcance** | Solo requisitos con `¿MVP? = sí` de [functional_requirements.md](../02_requirements/functional_requirements.md). Fuera: cotización estructurada (RF-066/067), B2B, push (RF-090–093), favoritos (RF-068–071), relacionados (RF-034), blog/capacitaciones (RF-082/084), tracking (RF-109), sesiones listables (RF-112) → **fase 2** (§5). |

Base URL de producción (PROPUESTA): `https://iprpartesyrepuestos.com/mobile/v1`. Staging: **DESCONOCIDO** (condición C2 de ADR-001).

---

## 1. Convenciones comunes

### 1.1 Cabeceras de solicitud

| Cabecera | Obligatoria | Formato | Uso |
|---|---|---|---|
| `X-App-Version` | Sí | SemVer `MAJOR.MINOR.PATCH` | Versión mínima (`426`), métricas. |
| `X-App-Platform` | Sí | `android` · `ios` | Métricas, `client_type` de la sesión. |
| `X-Device-Id` | Sí en `/auth/*`, `/me*`, `/checkout*`, `/orders*`, `/pqrs`, `/cart/validate`; recomendada en el resto | UUID v4 | Sesión por dispositivo y límites ([authentication.md](authentication.md) §4). |
| `Authorization` | En endpoints privados | `Bearer ipra_…` | **Única** vía de transporte del access token. |
| `X-Request-Id` | No | UUID v4 | Correlación; el servidor genera uno si falta. |
| `Idempotency-Key` | Opcional en `POST /checkout` y `POST /me/deletion`; recomendada en `POST /pqrs` | UUID v4 | §1.6. |
| `If-None-Match` | No | ETag | `304` en endpoints públicos. |
| `Accept-Language` | No | `es-CO` | Textos de `detail`. |
| `Content-Type` | En cuerpos | `application/json` | Otro tipo → `415`. |

### 1.2 Cabeceras de respuesta
`X-Request-Id` (siempre) · `Cache-Control` (siempre) · `ETag` (públicos) · `Retry-After` (`429`, `503`) · `X-IPR-Data-State: fresh|stale` (catálogo) · `Deprecation`/`Sunset` (cuando aplique).

### 1.3 Envoltura y tipos
- Éxito: `{ "data": … }` y, en listas, `"meta": { "page", "perPage", "total", "totalPages", "hasMore" }`.
- Error: `application/problem+json` (RFC 9457) con `type`, `title`, `status`, `detail`, `instance`, `code`, `requestId` y opcionales `retryAfter`, `errors[]`. Catálogo de `code` en [api_architecture.md](api_architecture.md) §6.3.
- Fechas ISO 8601 con zona; importes en COP con IVA incluido (`number`), `null` = sin precio.

### 1.4 Errores comunes a todos los endpoints (no se repiten abajo)
`400 validation_failed` · `400 token_in_url_forbidden` · `413 payload_too_large` · `415 unsupported_media_type` · `426 app_version_unsupported` · `429 rate_limited` · `500 internal_error`. Endpoints privados además: `401 unauthorized` y `403 account_locked`.

### 1.5 Modelos principales (definición completa en `openapi.yaml` → `components.schemas`)

| Modelo | Campos | Notas |
|---|---|---|
| `Price` | `status` (`priced`·`on_request`), `amount` (number\|null), `regularAmount` (number\|null), `onSale` (bool), `discountPercent` (int\|null), `currency` (`COP`), `taxIncluded` (`true`) | `on_request` ⇔ precio 0 en WooCommerce (`wc.ts:258`); nunca `0` ni texto formateado (RF-012). `onSale` con la regla de `wc.ts:260`. |
| `Availability` | `in_stock` · `out_of_stock` · `on_backorder` | Sin cantidades (S-01, no exponer `stockQuantity`, `wc.ts:1083`). |
| `ProductSummary` | `id`, `slug`, `name`, `sku`, `brand {name, slug\|null}\|null`, `price`, `availability`, `purchasable`, `image ImageRef\|null`, `categorySlugs[]` | `purchasable = price.status == priced && availability == in_stock` (y `on_backorder` según AP-04). |
| `ProductDetail` | `ProductSummary` + `shortDescription` (texto plano), `descriptionHtml` (HTML saneado, ADR-019), `gallery[]`, `attributes[{name, slug, options[]}]`, `categories[{id, slug, name}]`, `webUrl` | — |
| `ImageRef` | `url`, `alt`, `width\|null`, `height\|null` | Hoy solo hay URL original (`wc.ts:229`, `261`); variantes ligeras pendientes de DN-03 (§6). |
| `Category` | `id`, `slug`, `name`, `parentId\|null`, `children[]` | Sin URLs web (`wc.ts:96-101`). |
| `UserProfile` | `id`, `email`, `firstName`, `lastName`, `displayName`, `billing Address\|null`, `shipping Address\|null` | Sin `roles` ni `username` (A-08). |
| `Address` | `firstName`, `lastName`, `company`, `nationalId`, `address1`, `address2`, `department`, `city`, `postcode`, `phone` (solo facturación) | Reglas de `checkout-schema.ts:47-67`; país fijo `CO`. |
| `Session` | `accessToken`, `accessTokenExpiresIn` (s), `refreshToken`, `refreshTokenExpiresAt`, `tokenType` (`Bearer`), `sessionId` | — |
| `OrderSummary` / `OrderDetail` | ver §3 (EP-25/26) | `paymentState` según [api_architecture.md](api_architecture.md) §13.2. |

### 1.6 Idempotencia
`Idempotency-Key` (UUID v4): el BFF guarda `(usuario o dispositivo, ruta, clave) → respuesta` (60 s en `/checkout`, 24 h en `/pqrs`) en memoria del proceso; misma clave con cuerpo distinto → `409 idempotency_conflict`. En `/me/deletion` la idempotencia la garantiza WordPress (`requestId` estable).

---

## 2. Índice de endpoints

| ID | Método y ruta | RF | Auth | Estado | Caché | Rate limit (BFF/WP) |
|---|---|---|---|---|---|---|
| EP-01 | `GET /config` | RF-005, 062, 094, 095, 099, 111 (+ RNF-029) | No | PROPUESTO | público 60 s | catálogo |
| EP-02 | `POST /auth/register` | RF-038, 039 | No | PROPUESTO | no-store | 5/h IP · 3/h disp. |
| EP-03 | `POST /auth/login` | RF-040, 043, 045, 048 | No | PROPUESTO | no-store | WP por cuenta e IP |
| EP-04 | `POST /auth/refresh` | RF-044 | Refresh en cuerpo | PROPUESTO | no-store | 30/h por sesión |
| EP-05 | `POST /auth/logout` | RF-041 | Sí | PROPUESTO | no-store | — |
| EP-06 | `POST /auth/password/forgot` | RF-042, 045 | No | PROPUESTO | no-store | 3/h correo · 10/h IP |
| EP-07 | `GET /me` | RF-104, 106 | Sí | PROPUESTO | no-store | 60/min usuario |
| EP-08 | `PATCH /me` | RF-104 | Sí | PROPUESTO | no-store | 20/h usuario |
| EP-09 | `POST /me/email` | RF-104 | Sí | PROPUESTO | no-store | 5 fallos/h |
| EP-10 | `POST /me/password` | RF-105 | Sí | PROPUESTO | no-store | 5 fallos/h |
| EP-11 | `PUT /me/addresses/{type}` | RF-106 | Sí | PROPUESTO | no-store | 20/h usuario |
| EP-12 | `POST /me/deletion` | RF-110 | Sí | PROPUESTO | no-store | 5 fallos/h |
| EP-13 | `GET /categories` | RF-002, 010 | No | PROPUESTO | público 1 h | catálogo |
| EP-14 | `GET /products` | RF-003, 011–015, 019, 089 | No | PROPUESTO | público 5 min | catálogo |
| EP-15 | `GET /products/{slug}` | RF-026–032 | No | PROPUESTO | público 5 min | catálogo |
| EP-16 | `GET /filters` | RF-014, 089 | No | PROPUESTO | público 1 h | catálogo |
| EP-17 | `GET /search` | RF-016, 020, 022, 023 | No | PROPUESTO | público 2 min | 30/min disp. |
| EP-18 | `GET /search/suggestions` | RF-021, 022 | No | PROPUESTO | público 1 min | 60/min disp. |
| EP-19 | `GET /brands` | RF-004, 016 | No | PROPUESTO | público 1 h | catálogo |
| EP-20 | `GET /liquidaciones` | RF-007, 018 | No | PROPUESTO | público 5 min | catálogo |
| EP-21 | `POST /cart/validate` | RF-049, 050, 051 | No | PROPUESTO | no-store | 30/min disp. |
| EP-22 | `GET /stores` | RF-072–076 | No | PROPUESTO | público 1 h | catálogo |
| EP-23 | `POST /checkout` | RF-052, 053, 054, 058 | Sí | PROPUESTO | no-store | 10/10 min usuario |
| EP-24 | `GET /checkout/{checkoutRef}` | RF-055, 056, 057 | Sí | PROPUESTO | no-store | 30/min usuario |
| EP-25 | `GET /orders` | RF-107 | Sí | PROPUESTO | no-store | 60/min usuario |
| EP-26 | `GET /orders/{orderId}` | RF-056, 108 | Sí | PROPUESTO | no-store | 60/min usuario |
| EP-27 | `POST /pqrs` | RF-096, 097 | Opcional | PROPUESTO | no-store | 5/10 min IP y disp. (compartido) |

Requisitos MVP **sin endpoint propio** (resueltos en la app o con datos de EP-01): RF-001 (buscador), RF-006/085–089 (calculadora BTU local; enlace al catálogo con `attr[pa_capacidad-btu]`), RF-009 (manejo de errores), RF-062–065 (WhatsApp con datos de EP-01 y de la ficha), RF-079/080 (contenido de ingeniería y canal corporativo en EP-01), RF-037 (acceso sin sesión: todos los públicos).

---

## 3. Contratos por endpoint

### EP-01 · `GET /config` — Configuración remota y versión mínima

| | |
|---|---|
| **Propósito** | Versión mínima, interruptores de funciones, canales corporativos de contacto, documentos legales vigentes y textos de avisos. |
| **Estado** | PROPUESTO. Reutiliza: `src/lib/contact-links.ts:6-29` (WhatsApp, teléfono, correo de ventas); fuente administrable en WordPress (ADR-018, WP-13) con respaldo empaquetado. |
| **Parámetros** | Ninguno. |
| **Respuesta 200** | `data`: `minSupportedVersion {android, ios}` (por debajo → `426`), `recommendedVersion {android, ios}`, `features {checkoutEnabled, pqrsEnabled, btuCalculatorEnabled}`, `contact {whatsapp {number, defaultMessage}, phone {display, dial}, salesEmail, pqrsEmail, engineering {whatsapp\|null, email\|null}}`, `legal {terms {version, url}, privacyPolicy {version, url}, dataRightsChannel {url\|null, email\|null}, accountDeletionNotice}`, `notices {shipping, warranty, priceOnRequest}`, `checkout {allowedHosts[], returnPathPrefix}`, `catalog {pageSizes [12,24,48], maxPage 50}`. |
| **Códigos** | `200`, `304`, `503 upstream_unavailable` (solo si no hay ni fuente ni respaldo). |
| **Validaciones** | — |
| **Permisos** | Público; no incluye datos personales de empleados (RF-080, RNF-065). |
| **Pendiente** | Textos legales y de garantía (D-12), canal de ingeniería (PA-06), canal de derechos del titular (RF-111, D-12). |

### EP-02 · `POST /auth/register` — Registro

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza `wc_create_new_customer` (`auth-rest.php:198`) vía nueva `ipr/v1/m/register` ([authentication.md](authentication.md) §10). |
| **Cuerpo** | `{ "email": string ≤120, "firstName": string 1–60, "lastName": string 1–60, "password": string 8–128, "acceptance": { "termsVersion": string, "privacyPolicyVersion": string, "accepted": true } }` — `additionalProperties: false`. |
| **Respuesta 201** | `{ "data": { "session": Session, "user": UserProfile } }` |
| **Códigos** | `201`, `400 validation_failed` (incluye versión de documentos no vigente), `409 email_in_use`, `429`, `502/503/504`. |
| **Validaciones** | Correo válido; contraseña ≠ correo; `accepted` debe ser `true`; versiones = las de EP-01. |
| **Permisos** | Público; crea rol `customer` únicamente (nunca acepta rol del cliente). |
| **Notas** | Revela si el correo existe (RA-11, aceptado). No se reintenta automáticamente. |

### EP-03 · `POST /auth/login` — Inicio de sesión por dispositivo

| | |
|---|---|
| **Estado** | PROPUESTO. Base: `ipr_auth_handle_login` (`auth-rest.php:158-178`) → nueva `ipr/v1/m/sessions`. |
| **Cuerpo** | `{ "login": string 1–120 (correo o usuario), "password": string 1–128 }` |
| **Respuesta 200** | `{ "data": { "session": Session, "user": UserProfile } }` |
| **Códigos** | `200`, `400`, `401 invalid_credentials` (incluye cuenta inexistente, en eliminación o con rol denegado), `429 rate_limited` (+ `Retry-After`), `502/503/504`. |
| **Validaciones** | Cabeceras `X-Device-Id` y `X-App-Platform` obligatorias. |
| **Permisos** | Público. Revoca la sesión previa del mismo `deviceId`; máx. 10 sesiones. |

### EP-04 · `POST /auth/refresh` — Rotación de tokens

| | |
|---|---|
| **Estado** | PROPUESTO (no existe refresh hoy, H-02). |
| **Cuerpo** | `{ "refreshToken": "iprr_…" }` (nunca en URL). Sin `Authorization` (el access puede estar vencido). |
| **Respuesta 200** | `{ "data": { "session": Session } }` |
| **Códigos** | `200`, `400`, `401 unauthorized` (inválido/vencido/revocado), `401 refresh_token_reused` (sesión revocada), `409 refresh_in_progress`, `429`, `502/503/504`. |
| **Reglas** | Algoritmo en [authentication.md](authentication.md) §3.4 (gracia 30 s, mismo `X-Device-Id`). |

### EP-05 · `POST /auth/logout` — Cierre de sesión

| | |
|---|---|
| **Estado** | PROPUESTO. Base: `ipr_auth_handle_logout` (`auth-rest.php:225-233`). |
| **Cuerpo** | `{ "scope": "current" \| "all" }` (por defecto `current`). |
| **Respuesta** | `204` sin cuerpo. |
| **Códigos** | `204`, `400`, `401`. |
| **Notas** | `all` revoca también la sesión web heredada. La app borra tokens aunque la llamada falle por red (cierre local), y reintenta la revocación al recuperar conexión. |

### EP-06 · `POST /auth/password/forgot` — Solicitud de recuperación

| | |
|---|---|
| **Estado** | PROPUESTO (H-08). Usa `retrieve_password()` de WordPress (ADR-021). |
| **Cuerpo** | `{ "email": string ≤120 }` |
| **Respuesta** | `202 { "data": { "status": "accepted" } }` **siempre** (exista o no la cuenta). |
| **Códigos** | `202`, `400` (formato), `429`. |
| **Notas** | El restablecimiento se completa en la página de WordPress desde el enlace del correo; al completarlo se revocan todas las sesiones. |

### EP-07 · `GET /me` — Perfil y direcciones

| | |
|---|---|
| **Estado** | PROPUESTO. Base: `ipr_auth_handle_me` + `ipr_auth_public_user` (`auth-rest.php:104-120`, `215-223`) con lista blanca nueva. |
| **Respuesta 200** | `{ "data": UserProfile }` |
| **Códigos** | `200`, `401`, `403 account_locked`, `502/503/504`. |
| **Permisos** | Solo el usuario del token (sin parámetro de id: elimina BOLA). |

### EP-08 · `PATCH /me` — Nombre y apellido

| | |
|---|---|
| **Estado** | PROPUESTO. Base: `auth-rest.php:280-288`. |
| **Cuerpo** | `{ "firstName"?: string 1–60, "lastName"?: string 1–60 }` (al menos uno; `additionalProperties: false`: `email`, `password`, `roles` → `400`). |
| **Respuesta 200** | `{ "data": UserProfile }` |
| **Códigos** | `200`, `400`, `401`, `502/503/504`. |

### EP-09 · `POST /me/email` — Cambio de correo

| | |
|---|---|
| **Estado** | PROPUESTO. Base: `auth-rest.php:290-303`, `313-332`. |
| **Cuerpo** | `{ "newEmail": string ≤120, "currentPassword": string 1–128 }` |
| **Respuesta 200** | `{ "data": { "session": Session, "user": UserProfile } }` (sesión actual rotada; las demás y la web, revocadas). |
| **Códigos** | `200`, `400`, `401`, `403 current_password_invalid`, `409 email_in_use`, `429`, `502/503/504`. |

### EP-10 · `POST /me/password` — Cambio de contraseña

| | |
|---|---|
| **Estado** | PROPUESTO. Base: `auth-rest.php:305-332`. |
| **Cuerpo** | `{ "currentPassword": string 1–128, "newPassword": string 8–128 }` |
| **Respuesta 200** | `{ "data": { "session": Session } }` |
| **Códigos** | `200`, `400` (débil, igual a la actual o al correo), `401`, `403 current_password_invalid`, `429`, `502/503/504`. |

### EP-11 · `PUT /me/addresses/{type}` — Dirección de facturación o envío

| | |
|---|---|
| **Estado** | PROPUESTO. Base: lista blanca de `auth-rest.php:334-360`; reglas de `checkout-schema.ts:47-67`. |
| **Parámetros** | `type` ∈ `billing` · `shipping`. |
| **Cuerpo** | `Address` completo (reemplazo): `nationalId` 3–30 `[\d.\-]`, `firstName`/`lastName` 1–60, `company` ≤120, `address1` 1–200, `address2` ≤200, `department` (código de departamento válido, `colombia.ts`), `city` 1–80, `postcode` ≤20, `phone` 7–20 `[\d\s+\-().]` (obligatorio en `billing`, ignorado en `shipping`). |
| **Respuesta 200** | `{ "data": UserProfile }` |
| **Códigos** | `200`, `400`, `401`, `404` (tipo inválido), `502/503/504`. |
| **Pendiente** | Clave real de meta de la cédula/NIT en el perfil: **DESCONOCIDA** (hoy el checkout la inyecta como `billing_national_id`, `handoff.php:322-324`). Si no se puede guardar en el perfil, `nationalId` se omite del contrato del MVP. |

### EP-12 · `POST /me/deletion` — Eliminación de cuenta

| | |
|---|---|
| **Estado** | PROPUESTO (H-08). Flujo en [authentication.md](authentication.md) §12. |
| **Cuerpo** | `{ "currentPassword": string 1–128, "confirm": true }` — sin id de cuenta (AC-110-13). |
| **Respuesta** | `202 { "data": { "requestId": uuid, "status": "scheduled", "completeBy": date-time } }` |
| **Códigos** | `202`, `400`, `401`, `403 current_password_invalid`, `429`, `502/503/504`. |
| **Idempotencia** | Una solicitud pendiente devuelve el mismo `requestId`. |
| **Pendiente** | Retención y pedidos en curso (D-12, PA-09). |

### EP-13 · `GET /categories` — Árbol de categorías

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza `getCategories()` (`meta.ts:239-246`) y `buildCategoryTree` (`wc.ts:103-132`) con mapeador nuevo. |
| **Parámetros** | Ninguno. |
| **Respuesta 200** | `{ "data": Category[] }` (raíces con `children` anidados). |
| **Códigos** | `200`, `304`, `503 upstream_unavailable`. |
| **Reglas** | Excluir slugs vacíos/numéricos, nombre "-", `uncategorized`/`sin-categorizar` (como `wc.ts:1049-1055`, `search-facets.ts:48-50`). Sin `count` ni imagen en el MVP (no se piden hoy, `meta.ts:158`). El agrupado web aire/refri/vent (`wc.ts:139-152`) **no** se replica: la app recibe el árbol real (evita enlaces rotos, RNF-113). |

### EP-14 · `GET /products` — Listado con filtros, orden y paginación

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza `fetchCatalogProducts` (`wc.ts:411-503`) en variante discriminada (FE-02) y `validateFilters` (`meta.ts:307-324`). |
| **Parámetros (query)** | `category` (slug, 1), `brand` (slugs separados por coma, ≤5), `tag` (slugs, ≤5), `onSale` (`true`), `attr[<pa_slug>]` (términos separados por coma; ≤5 atributos; p. ej. `attr[pa_capacidad-btu]=12-000-btu`), `sort` (`latest`·`popularity`·`price-asc`·`price-desc`·`name`; defecto `latest`), `page` (1–50, defecto 1), `perPage` (12·24·48, defecto 24; otros se ajustan). |
| **Respuesta 200** | `{ "data": ProductSummary[], "meta": PageMeta }` |
| **Códigos** | `200`, `304`, `400 validation_failed` (filtro inexistente o parámetro inválido), `503 upstream_unavailable` (+ `Retry-After`), `504 upstream_timeout`. **Nunca** `200` con lista vacía causada por fallo. |
| **Notas** | "Más vendidos" (RF-003): `sort=popularity` es la propuesta provisional; criterio real **DESCONOCIDO** (PA-05). Orden por precio con productos sin precio: AP-06. |

### EP-15 · `GET /products/{slug}` — Ficha de producto

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza `fetchProductBySlug` + `normalizeProductDetail` (`wc.ts:1104-1136`, `1042-1086`) **después** de corregir SEC-07 (FE-01). |
| **Parámetros** | `slug`: `^[a-z0-9][a-z0-9._%-]{0,199}$` (mismo patrón que `wc.ts:1115`). |
| **Respuesta 200** | `{ "data": ProductDetail }` |
| **Códigos** | `200`, `304`, `400` (slug con formato inválido), `404 not_found` (solo con respuesta definitiva: no existe, no publicado, oculto o con contraseña), `503`, `504`. |
| **Reglas** | Sin `stockQuantity`; `descriptionHtml` saneado en servidor (sin `script`, `style`, `iframe`, `on*`, esquemas no permitidos); `shortDescription` como texto plano. Avisos de envío/garantía: `GET /config` (`notices`). |

### EP-16 · `GET /filters` — Dimensiones de filtro de una categoría

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza `getContextualDimensions(categoryPath)` / `getProductosDimensions()` (`filter-context.ts:229-250`, `325-341`). |
| **Parámetros** | `category` (slug, opcional; sin él, dimensiones generales). |
| **Respuesta 200** | `{ "data": [ { "key": "attr[pa_capacidad-btu]" \| "brand" \| "onSale" …, "label": string, "type": "multi" \| "boolean", "options": [ { "value": string, "label": string } ] } ] }` |
| **Códigos** | `200`, `304`, `400` (categoría inexistente), `503`. |
| **Limitación (HECHO)** | Las opciones salen de menús web estáticos y no traen conteo (`filter-context.ts:252-253`): una opción puede devolver 0 productos. Facetas con conteo: fase 2. |

### EP-17 · `GET /search` — Búsqueda por texto, marca o referencia/SKU

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza `searchProducts` (`wc.ts:1035-1040`) y `searchBrandProducts` (`wc.ts:1023-1029`); validación `searchSchema` (`searchSchema.ts:24-36`). |
| **Parámetros** | `q` (1–120, sin etiquetas HTML ni caracteres de control), `brand` (slug opcional: búsqueda interna de marca, RF-016), `page` (1–50), `perPage` (12·24·48). |
| **Respuesta 200** | `{ "data": ProductSummary[], "meta": PageMeta & { "query": string } }`. Lista vacía = **sin coincidencias reales** (RF-023: la app ofrece WhatsApp con el término). |
| **Códigos** | `200`, `304`, `400`, `503 catalog_index_warming` (+ `Retry-After: 5`), `503 upstream_unavailable`. |
| **Reglas** | SKU exacto primero (`wc.ts:919-923`, `951-962`; RF-022 por verificar en staging, RNF-110). Paginación en memoria sobre ≤ 5.000 coincidencias. |

### EP-18 · `GET /search/suggestions` — Autocompletado

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza la lógica de `src/app/api/search/suggestions/route.ts:21-40` (`searchProducts(q, 6)`). |
| **Parámetros** | `q` (2–120). |
| **Respuesta 200** | `{ "data": { "query": string, "total": int, "items": [ { "id", "slug", "name", "sku", "brandName\|null", "price": Price, "availability", "image": ImageRef\|null } ] } }` (máx. 6). |
| **Códigos** | `200`, `400`, `503 catalog_index_warming`. |
| **Cliente** | *Debounce* ≥ 300 ms; cancelar la solicitud anterior. |

### EP-19 · `GET /brands` — Directorio de marcas

| | |
|---|---|
| **Estado** | PROPUESTO. Requiere exportar `getBrands()` (carga privada en `meta.ts:166-168`) y `getBrandLogo` (`brands.ts:137-141`) con URL absoluta. Fuente canónica: AP-05. |
| **Respuesta 200** | `{ "data": [ { "slug", "name", "logoUrl\|null", "hasLanding": bool } ] }` ordenado por nombre. |
| **Códigos** | `200`, `304`, `503`. |
| **Uso** | Productos de una marca: `GET /products?brand=<slug>`; búsqueda interna: `GET /search?q=…&brand=<slug>`. |

### EP-20 · `GET /liquidaciones` — Productos en liquidación

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza `fetchLiquidationProducts` (`liquidaciones.ts:30-50`) y `discountPercent` (`liquidaciones-shared.ts:24-35`); modelo de ruta `src/app/api/liquidaciones/productos/route.ts:31-55`. |
| **Parámetros** | `sort`, `page` (1–50, la ruta web no tiene tope: `route.ts:33`), `perPage` (12·24·48). |
| **Respuesta 200** | `{ "data": ProductSummary[] (con price.discountPercent), "meta": PageMeta }` |
| **Códigos** | `200`, `304`, `400`, `503`, `504`. |

### EP-21 · `POST /cart/validate` — Revalidación de precio y disponibilidad del carrito

| | |
|---|---|
| **Estado** | PROPUESTO. Requiere función de disponibilidad por ids con caché por id (FE-08), basada en `fetchProductsByIds` (`wc.ts:521-561`, `status=publish`). |
| **Cuerpo** | `{ "items": [ { "id": int > 0, "quantity": int 1–99 } ] }` 1–100 líneas, ids sin duplicar (mismas reglas que `checkout-schema.ts:78-93`). |
| **Respuesta 200** | `{ "data": { "lines": [ { "id", "quantity", "status": "available" \| "out_of_stock" \| "on_backorder" \| "price_on_request" \| "not_found", "product": ProductSummary\|null, "lineSubtotal": number\|null } ], "informativeSubtotal": { "amount", "currency": "COP", "taxIncluded": true }, "checkoutAllowed": bool } }` |
| **Códigos** | `200`, `400` (>100 líneas, cantidades fuera de rango, ids duplicados: AC-050-10), `503`, `504`. |
| **Reglas** | El servidor no recibe precios del cliente (AC-050-8); la app compara con lo que mostraba para avisar cambios (AC-050-2). `not_found` solo con respuesta definitiva; si WooCommerce no responde → `503` y la app bloquea el pago (AC-050-7). El subtotal es **informativo** (RF-051, AC-051-4: lo entrega el BFF como suma de precios vigentes; IVA, envío y total los fija WooCommerce). |

### EP-22 · `GET /stores` — Sedes

| | |
|---|---|
| **Estado** | PROPUESTO. Datos actuales en `src/lib/sedes-data.ts` (tipo `Sede`, compilado); fuente administrable en WordPress (ADR-018, RF-076). |
| **Respuesta 200** | `{ "data": [ { "slug", "city", "name", "address", "upcoming": bool, "phones": [ { "type": "landline" \| "sales_parts" \| "sales_ac" \| "mobile", "display", "dial" } ], "whatsapp": { "number" } \| null, "imageUrl\|null", "mapsQuery": string, "coordinates": null, "openingHours": null } ] }` |
| **Códigos** | `200`, `304`, `503`. |
| **Reglas** | Sedes `upcoming = true` sin teléfonos ni `mapsQuery` (RF-072). Solo canales corporativos (D-09, RNF-065). `coordinates`/`openingHours` siempre `null` en MVP (RF-077 fase 2; D-09). |

### EP-23 · `POST /checkout` — Crear ticket y URL de checkout

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza `src/app/api/checkout/route.ts:85-166` (llamada a `handoff-ticket` con `X-IPR-Secret`, timeout 8 s, validación del ticket `^[A-Za-z0-9]{32}$`) y `checkoutPayloadSchema.items` (`checkout-schema.ts:77-93`); requiere WP-06. |
| **Cuerpo** | `{ "items": [ { "id": int > 0, "quantity": int 1–99 } ] }` 1–100 líneas. **Nada más**: precio, total, correo, facturación o URL de retorno → `400` (AC-052-2/5). |
| **Respuesta 201** | `{ "data": { "checkoutRef": uuid, "checkoutUrl": "https://<host WP>/?ipr_ticket=<32>", "expiresAt": date-time, "expiresIn": 60, "allowedHosts": [..], "returnUrlPrefix": "https://iprpartesyrepuestos.com/app/pedido" } }` |
| **Códigos** | `201`, `400`, `401`, `429`, `502 upstream_bad_response` (ticket inválido o rechazo de WordPress), `503 feature_disabled` / `upstream_unavailable`, `504`. |
| **Reglas** | La app abre la URL en ≤ 5 s, en navegador seguro, tras verificar el host (AC-052-13); no la guarda ni la registra (AC-052-4). Un ticket vencido se reemplaza pidiendo otro (RNF-026). |

### EP-24 · `GET /checkout/{checkoutRef}` — Estado del intento de pago

| | |
|---|---|
| **Estado** | PROPUESTO (ADR-017). Requiere WP-06 (`_ipr_checkout_ref`) y WP-07 (filtro por ref). |
| **Parámetros** | `checkoutRef` (UUID v4). |
| **Respuesta 200** | `{ "data": { "checkoutRef", "state": "awaiting_order" \| "order_created", "order": OrderSummary\|null } }` |
| **Códigos** | `200`, `400`, `401`, `502/503/504`. |
| **Permisos** | Solo busca entre los pedidos del usuario autenticado; un `checkoutRef` ajeno devuelve `awaiting_order` (no filtra información). |
| **Cliente** | Consultar al volver del navegador o al recibir el App Link; *backoff* 2, 4, 8, 16 s… hasta ~2 min; vaciar el carrito solo con `order.paymentState = paid`. |

### EP-25 · `GET /orders` — Historial de pedidos

| | |
|---|---|
| **Estado** | PROPUESTO. Base: `ipr_auth_handle_orders` (`auth-rest.php:235-272`) → `ipr/v1/m/orders` paginado (hoy `limit -1`). |
| **Parámetros** | `page` (1–100), `perPage` (10·20). |
| **Respuesta 200** | `{ "data": OrderSummary[], "meta": PageMeta }` con `OrderSummary = { id, number, status, statusLabel, paymentState, createdAt, currency, total, itemCount }` orden descendente por fecha. |
| **Códigos** | `200`, `400`, `401`, `502/503/504`. |

### EP-26 · `GET /orders/{orderId}` — Detalle de pedido

| | |
|---|---|
| **Estado** | PROPUESTO. Mapeo base en `auth-rest.php:245-266`, ampliado. |
| **Parámetros** | `orderId` (entero > 0). |
| **Respuesta 200** | `{ "data": OrderDetail }` = `OrderSummary` + `subtotal`, `shippingTotal`, `discountTotal`, `taxTotal`, `paymentMethodTitle`, `items[{ productId\|null, name, sku\|null, quantity, total, imageUrl\|null }]`. **No** incluye dirección, IP, agente de usuario, notas internas, id de transacción ni datos de pago. |
| **Códigos** | `200`, `401`, `404 not_found` (no existe **o** no es del usuario: AC-056-10), `502/503/504`. |

### EP-27 · `POST /pqrs` — Petición, queja, reclamo o sugerencia

| | |
|---|---|
| **Estado** | PROPUESTO. Reutiliza esquema y envío de `src/app/api/pqrs/route.ts:22-129` extraídos a `lib/pqrs.ts` (FE-16). |
| **Cuerpo** | `{ "type": "peticion" \| "queja" \| "reclamo" \| "sugerencia", "name": 3–120, "email": ≤254, "phone": 7–20, "orderReference"?: ≤60, "message": 1–1000, "acceptsDataPolicy": true }` |
| **Respuesta** | `202 { "data": { "status": "received", "receivedAt": date-time } }` (sin número de radicado: RF-098 fase 2). |
| **Códigos** | `202`, `400`, `409 idempotency_conflict`, `429` (+ `Retry-After`), `502 upstream_bad_response` (fallo SMTP), `503 feature_disabled`. |
| **Reglas** | Límite compartido por IP (Cloudflare o contador en WordPress, RF-097) además del de memoria; `Idempotency-Key` recomendada; con sesión, la app puede prellenar nombre y correo, pero el servidor no asocia la PQRS a la cuenta en el MVP. El correo se arma con `escapeHtml` y cabeceras saneadas como hoy (`pqrs/route.ts:17`, `108-116`). `acceptsDataPolicy`: texto de autorización a validar por Jurídico (D-12). |

---

## 4. Matriz de requisitos MVP → endpoints

| Requisito | Endpoint(s) |
|---|---|
| RF-002, RF-010 | EP-13 |
| RF-003, RF-011, RF-012, RF-013, RF-015, RF-019 | EP-14 (RF-019 vía caché ≤ 10 min, §8 de arquitectura) |
| RF-014, RF-089 | EP-14 (`attr[…]`), EP-16 |
| RF-016 | EP-19, EP-14 (`brand`), EP-17 (`brand`) |
| RF-018, RF-007 | EP-20 |
| RF-020, RF-022, RF-023 | EP-17 |
| RF-021 | EP-18 |
| RF-026 a RF-032 | EP-15 (+ EP-01 avisos) |
| RF-038, RF-039 | EP-02 (+ EP-01 versiones legales) |
| RF-040, RF-043, RF-045, RF-048 | EP-03 |
| RF-041 | EP-05 |
| RF-042 | EP-06 |
| RF-044 | EP-04 (+ todos los privados por `Authorization`) |
| RF-049, RF-050, RF-051 | EP-21 |
| RF-052, RF-053, RF-054, RF-058 | EP-23 |
| RF-055, RF-056, RF-057 | EP-24, EP-26 |
| RF-062 a RF-065, RF-094, RF-095, RF-099, RF-111 | EP-01 |
| RF-072 a RF-076 | EP-22 |
| RF-096, RF-097 | EP-27 |
| RF-104 | EP-07, EP-08, EP-09 |
| RF-105 | EP-10 |
| RF-106 | EP-07, EP-11 |
| RF-107 | EP-25 |
| RF-108 | EP-26 |
| RF-110 | EP-12 |

---

## 5. Fuera del MVP (fase 2, sin contrato aquí)

| Funcionalidad | Requisito | Endpoint candidato (no diseñado) |
|---|---|---|
| Cotización estructurada y su seguimiento | RF-066, RF-067 | `POST /quotes`, `GET /quotes/{id}` |
| Precios y roles B2B | D-03 | — (cambiaría la política de caché pública: los precios dejarían de ser iguales para todos) |
| Notificaciones push y registro de dispositivos | RF-090–093 | `PUT /me/devices/{deviceId}/push` |
| Favoritos sincronizados | RF-070 | `GET/PUT /me/favorites` |
| Productos relacionados | RF-034 | `GET /products/{slug}/related` (lógica hoy *inline* en `producto/[slug]/page.tsx:72-83`) |
| Lista y cierre de sesiones por dispositivo | RF-112 | `GET /me/sessions`, `DELETE /me/sessions/{sessionId}` |
| Tracking de envío | RF-109 | — |
| Blog, capacitaciones | RF-082, RF-084 | `GET /content/*` |
| Radicado y estado de PQRS | RF-098 | `GET /pqrs/{id}` |
| Enlaces de producto que abren la app | RF-036 | (sin endpoint; `.well-known` con `/producto/*`) |

---

## 6. Puntos abiertos del contrato

| Tema | Estado | Cómo se cierra |
|---|---|---|
| Variantes de imagen (`ImageRef`) | **DESCONOCIDO** si WordPress genera tamaños intermedios utilizables (MED-07). Opciones: (a) URL original (hoy); (b) tamaños de WordPress; (c) Cloudflare Images/Resizing (costo); (d) optimizador de Next (`/_next/image`), **desaconsejado** porque consume CPU del único proceso. | DN-03 (TI web). El contrato ya admite `width`/`height` y no cambia. |
| `on_backorder` comprable | Pendiente AP-04 / PA-12. | Cambia solo `purchasable`. |
| `nationalId` en el perfil | Clave de meta **DESCONOCIDA**. | Verificar en staging. |
| Estado `on-hold` → `pending` | SUPUESTO (PA-12). | Prueba con Wompi sandbox. |
| Criterio de "más vendidos" | **DESCONOCIDO** (PA-05). | Equipo web / Marketing. |

---

## Anexo A. Endpoints EXISTENTES (no consumibles por la app; base de implementación)

### A.1 WordPress `ipr/v1` (HECHO, `wp-snippets/ipr-auth-rest.php` y `ipr-cart-handoff.php`)

| Método y ruta | Archivo:línea | Auth actual | Reutilización |
|---|---|---|---|
| `GET /ipr/v1/auth/ping` | `auth-rest.php:375-379` | Ninguna | Monitoreo interno. |
| `POST /ipr/v1/auth/login` | `auth-rest.php:158-178`, `380-384` | Ninguna | Base de EP-03 (la web la sigue usando). |
| `POST /ipr/v1/auth/register` | `auth-rest.php:180-213`, `385-389` | Ninguna | Base de EP-02. |
| `GET /ipr/v1/auth/me` | `auth-rest.php:215-223`, `390-394` | Token (query/cuerpo/cabecera) | Base de EP-07. |
| `POST /ipr/v1/auth/logout` | `auth-rest.php:225-233`, `395-399` | Token | Base de EP-05. |
| `GET /ipr/v1/orders` | `auth-rest.php:235-272`, `400-404` | Token | Base de EP-25/26. |
| `POST /ipr/v1/auth/update` | `auth-rest.php:274-368`, `405-409` | Token + `current_password` en cambios sensibles | Base de EP-08 a EP-11. |
| `POST /ipr/v1/handoff-ticket` | `handoff.php:193-258` | `X-IPR-Secret` | Base de EP-23 (se extiende, WP-06). |
| `GET /?ipr_ticket=…` (no REST) | `handoff.php:369-437` | Ticket de un solo uso | Se reutiliza tal cual. |
| `/wp-json/ipr/v1/raspa-samsung/*` | Snippet de campaña (no revisado); expuesto por *rewrite* en `next.config.ts:327-330` | DESCONOCIDO | Fuera del MVP (RF-103); inventariar (API9). |

### A.2 Rutas `/api/*` del sitio Next.js (HECHO)

| Método y ruta | Archivo | Auth | Relación con `/mobile/v1` |
|---|---|---|---|
| `POST /api/auth/login`, `/register`, `/logout`; `GET /api/auth/me`, `/orders`; `POST /api/auth/update` | `src/app/api/auth/*/route.ts` | Cookie `ipr_session` | Modelo de EP-02 a EP-11 y EP-25; no consumibles (cookie y `Origin`, R-01). |
| `POST /api/checkout` | `src/app/api/checkout/route.ts` | Cookie opcional | Modelo de EP-23. |
| `GET /api/search/suggestions` | `src/app/api/search/suggestions/route.ts` | Pública | Modelo de EP-18. |
| `GET /api/marcas/[slug]/productos` | `src/app/api/marcas/[slug]/productos/route.ts` | Pública | Modelo de tamaños de página y búsqueda por marca (EP-14, EP-17). |
| `GET /api/liquidaciones/productos` | `src/app/api/liquidaciones/productos/route.ts` | Pública | Modelo de EP-20. |
| `POST /api/pqrs` | `src/app/api/pqrs/route.ts` | Pública + límite en memoria | Modelo de EP-27. |
| `POST /api/newsletter` | `src/app/api/newsletter/route.ts` | Pública + límite en memoria | Fase 2 (RF-101). |
| `POST/GET /api/revalidate` | `src/app/api/revalidate/route.ts` | HMAC o secreto (también `?secret=`) | Mantiene frescas las cachés que usa el BFF. |
| `GET /api/health` | `src/app/api/health/route.ts` | Pública | Monitoreo sintético del proceso (RNF-102). |

## Anexo B. Rutas nuevas de WordPress que consume el BFF (PROPUESTAS)
Listado completo y permisos en [authentication.md](authentication.md) §9. Todas exigen `X-IPR-BFF-Secret` y no son parte del contrato público de la app.

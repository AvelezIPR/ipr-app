# Entrega 1.2 — Análisis de la capa de acceso a WooCommerce de `ipr-frontend` para el BFF móvil `/mobile/v1`

| | |
|---|---|
| **Fecha** | 2026-11-18 |
| **Fuente** | Repositorio local `C:\Users\empr16\ipr-frontend` (solo lectura). No se modificó nada, no se ejecutó build/install/audit y **no se abrió `.env`**. |
| **Complementa** | `informe_codigo_frontend.md` (Entrega 1.1) y `03_architecture/architecture_decisions.md` (ADR-001, ADR-002). |
| **Convención** | **HECHO** = comprobado en el código, con cita `archivo:línea`. **INFERENCIA** = deducción razonada, no comprobada en ejecución. **DESCONOCIDO** = no se puede determinar leyendo el código. Las rutas `/mobile/v1/*` de este documento son **PROPUESTAS**: hoy no existe ninguna. |

Rutas abreviadas: `wc.ts` = `src/lib/woocommerce.ts`; `client.ts`, `swr-cache.ts`, `meta.ts`, `metrics.ts` = `src/lib/wc/*`.

**Archivos leídos:** `CLAUDE.md`; `src/lib/woocommerce.ts` (completo, 1.154 líneas); `src/lib/wc/{client,swr-cache,meta,metrics}.ts`; `src/instrumentation.ts`; `src/lib/{catalog-meta,catalog-sort,search-facets,filter-context,brand-products,liquidaciones,liquidaciones-shared,brands,brand-landing-server}.ts`; `src/lib/security/sanitize.ts`; `src/lib/utils/price.ts`; `src/lib/blog.ts` (firmas y `requestWpPosts`); `src/schema/searchSchema.ts`; `src/features/search/search-types.ts`; rutas `src/app/api/{marcas/[slug]/productos,search/suggestions,liquidaciones/productos,revalidate,health}/route.ts`; páginas `src/app/{producto/[slug],productos,buscar}/page.tsx`; `ProductBuyBox.tsx`/`ProductTabs.tsx`; `.github/workflows/deploy.yml`; hallazgo SEC-07 extraído del PDF `docs/auditoria-seguridad-y-arquitectura.pdf`.

---

## 0. Resumen ejecutivo

1. **La capa es reutilizable casi tal cual desde un Route Handler.** No usa `cookies()`, `headers()`, `unstable_cache` ni `"use cache"` (HECHO: la única aparición de `cookies()` en `src/` está en `src/lib/session.ts:8,14,26`). El acoplamiento a Next se limita a `fetch(..., { next: { revalidate, tags } })` (`client.ts:295`) y a `React.cache` en la ficha (`wc.ts:1104`), y ninguno impide llamarla desde `/mobile/v1/*`.
2. **SEC-07 sigue abierto.** `fetchProductBySlug` consulta `products?slug=…` **sin `status=publish`** (`wc.ts:1117-1121`), con credenciales de servidor. Un BFF móvil que reutilice esa función expondría productos en borrador, pendientes o privados. Es **bloqueante** para el detalle móvil.
3. **Los errores se convierten en "vacío" o "no existe".** `fetchCatalogProducts` devuelve `[]` si WooCommerce falla y no hay caché (`wc.ts:497-502`), y `fetchProductBySlug` devuelve `null` (`wc.ts:1133-1135`). La web lo traduce en "sin resultados" o 404. Una app necesita distinguir `404` de `503` para no mostrar "producto no existe" ni borrarlo de favoritos o del carrito por una caída.
4. **Todo el estado de resiliencia es por proceso y en memoria.** Esto incluye el breaker, la compuerta de 4 conexiones, las cachés SWR y el índice de búsqueda de hasta 10.000 productos. La cola de concurrencia **no tiene tope ni tiempo máximo de espera** (`client.ts:214-221`). Con tráfico móvil sumado al web, la latencia puede crecer sin límite antes de que empiece a contar el timeout de 8 s.
5. **El modelo expone más de lo que la app necesita:** `stockQuantity` exacto (`wc.ts:1083`), `description`/`shortDescription` en **HTML sin sanear** (`wc.ts:1075-1076`; la web sanea solo al pintar, en el navegador, `ProductTabs.tsx:27`) y `formattedPrice` = "$ 0" en productos sin precio. Hace falta un **DTO móvil propio**.

---

## 1. Inventario de funciones exportadas relevantes

### 1.1 `src/lib/woocommerce.ts`

| Función / símbolo | Archivo:línea | Firma resumida | Qué hace | Llamadas WooCommerce | Caché |
|---|---|---|---|---|---|
| `CATALOG_CACHE_TAG`, `BRAND_TERMS_CACHE_TAG`, `CATALOG_META_TAG` | `wc.ts:41-43` | constantes | Tags de la caché de datos de Next | — | — |
| `buildCategoryTree` | `wc.ts:103-132` | `(categories: WcCategory[]) => MenuItem[]` | Arma el árbol padre→hijos. **Devuelve `MenuItem` con URL web** `/productos?cat=…` (`wc.ts:96-101`) | Ninguna (es pura) | — |
| `fetchMenuCategories` | `wc.ts:157-175` | `() => Promise<{aire,refri,vent}>` | Árbol agrupado por "división", según palabras clave del nombre (`wc.ts:90-94`, `139-152`). **Descarta las raíces que no encajan** | Indirecta: `getCategories()` | `meta` (1 h) + memo de módulo `menuMemo` (`wc.ts:155`) |
| `resolveTagIds` | `wc.ts:332-337` | `(slugs: string[]) => Promise<string\|null>` | Slugs o IDs de etiqueta → `"id1,id2"` | Ninguna (mapa de meta) | `meta` |
| `fetchBrandTermId` | `wc.ts:339-347` | `(brandSlug) => Promise<number\|null>` | Slug de marca → ID del término `product_brand` | Ninguna (mapa de meta) | `meta` |
| `fetchAttributeTermSlugs` | `wc.ts:350-355` | `(dimSlug) => Promise<Map<slug,nombre>>` | Términos de un atributo `pa_*` | Ninguna (mapa de meta) | `meta-terms` |
| `CATALOG_SORT_KEYS`, `CatalogSortKey` | `wc.ts:184-185` (de `catalog-sort.ts:6-19`) | `latest\|popularity\|price-asc\|price-desc\|name` | Orden admitido | — | — |
| `CatalogProductFilters` / `CatalogResult` | `wc.ts:187-204` | `{categorySlug, brandId, onSale, tagSlugs, attributes, search, sort, page, perPage}` → `{products,total,page,perPage}` | Contrato de listado | — | — |
| **`fetchCatalogProducts`** | `wc.ts:411-503` | `(filters) => Promise<CatalogResult>` | Listado paginado con filtros y orden. `perPage` entre 1 y 100 (`wc.ts:414`); `page` ≤ 200 (`wc.ts:32,424`); siempre `status=publish` (`wc.ts:429`) y `_fields` (`wc.ts:430`). Traduce cada filtro a ID **solo desde meta**: si el filtro no existe o no se puede comprobar, devuelve vacío sin llamar a WooCommerce (`wc.ts:445-449`, `476-485`) | `GET wc/v3/products?…` (`wc.ts:495`) | `listings` SWR 5 min, 24 h stale, 400 claves (`wc.ts:382-390`) + caché de datos de Next 300 s y tag `catalog` (`wc.ts:397-400`) |
| `fetchProductsByIds` | `wc.ts:521-561` | `(ids: number[]) => Promise<Product[]>` | Lista corta curada, en el orden pedido. `status=publish` (`wc.ts:536`) | `GET wc/v3/products?include=…` | `by-ids` SWR 5 min, 50 claves (`wc.ts:513-519`) |
| `CategoryGroup` / `fetchProductsByCategories` | `wc.ts:599-666` | `(groups, {perPage, limit}) => Promise<Product[]>` | Varias categorías combinadas en round-robin (`wc.ts:577-596`) | Una `fetchCatalogProducts` por grupo | `listings` |
| `invalidateCatalogIndex` | `wc.ts:739-741` | `() => void` | Marca el índice como inválido | — | índice |
| `warmCatalogIndex` | `wc.ts:744-746` | `() => void` | Precalienta el índice sin bloquear | Ver índice | índice |
| `listCatalogProductSlugs` | `wc.ts:1017-1020` | `() => Promise<string[]>` | Slugs para el sitemap (espera hasta 30 s) | Ver índice | índice |
| **`searchBrandProducts`** | `wc.ts:1023-1029` | `(brandIds: number[], query) => Promise<{products,total}>` | Búsqueda en el índice limitada a esas marcas, **sin límite de resultados** | Ver índice | índice |
| **`searchProducts`** | `wc.ts:1035-1040` | `(query, limit) => Promise<{products,total}>` | Búsqueda multicampo y tolerante (nombre, SKU, marca, categorías, etiquetas, atributos, descripción corta) con puntuación (`wc.ts:912-1008`) | Ver índice | índice |
| `ProductDetail` / `ProductDetailAttribute` | `wc.ts:233-248` | tipo | Modelo de ficha | — | — |
| `productCacheTag` | `wc.ts:1097` | `(slug) => "product-{slug}"` | Tag por producto | — | — |
| **`fetchProductBySlug`** | `wc.ts:1104-1136` | `(slug) => Promise<ProductDetail\|null>` (envuelta en `React.cache`) | Ficha por slug. Valida el patrón del slug (`wc.ts:1115`). **No filtra por `status`** (`wc.ts:1117-1121`) | `GET wc/v3/products?slug=…&per_page=1&_fields=…` | `detail` SWR 5 min, 24 h stale, 600 claves (`wc.ts:1088-1094`) + caché de Next 300 s con tags `catalog` y `product-{slug}` (`wc.ts:1125-1128`) |
| `invalidateProductDetail` | `wc.ts:1139-1142` | `(slug) => void` | Marca como vieja una ficha | — | `detail` |
| `invalidateCatalogListings` | `wc.ts:1149-1154` | `() => void` | Marca como viejos los listados, by-ids, fichas e índice | — | todas |

**Índice de búsqueda (privado, pero es la base de dos funciones exportadas):** descarga `wc/v3/products?per_page=100&page=N&status=publish&_fields=…+tags,short_description` (`wc.ts:753`, `82`), con un máximo de **100 páginas = 10.000 productos** (`wc.ts:686`, `695`, `790`), de 4 en 4 (`wc.ts:697`, `791-800`) y con un timeout de 20 s por página (`wc.ts:757`). Dura 5 min con stale-while-revalidate (`wc.ts:694`, `852-880`). Si una reconstrucción falla, reintenta a los 30 s (`wc.ts:699`, `865`). Una consulta espera como máximo 4 s a que se construya (`wc.ts:706`, `877-879`).

### 1.2 `src/lib/wc/*`

| Función | Archivo:línea | Qué hace | Notas para el BFF |
|---|---|---|---|
| `wcConfigured()` | `client.ts:61-63` | Comprueba que hay credenciales | — |
| `WcError` (`status`, `circuitOpen`) | `client.ts:71-81` | Error tipado | Permitiría distinguir 503 de 404 **si las funciones de alto nivel no se lo tragaran** |
| `wcCircuitOpen()` | `client.ts:136-139` | Estado del breaker | Útil para responder `503` + `Retry-After` |
| **`wcGet(path, {revalidate, tags, timeoutMs?, retries?})`** | `client.ts:388-400` | Único GET: deduplica peticiones en vuelo (`171-175`, `391-398`), limita la concurrencia (`208-228`), reintenta (`348-381`), aplica el breaker (`104-133`) y usa una ruta interna opcional (`246-288`) | Solo `GET`. La autenticación es Basic con consumer key/secret (`client.ts:65-68`) |
| `SwrCache` / `sharedCache(opts)` | `swr-cache.ts:43-182`, `189-197` | Caché SWR con single-flight y "un error nunca se guarda". El registro vive en `globalThis` | Sirve también para cachés móviles nuevas |
| `resolveAttributeTerm`, `resolveCategory`, `resolveBrandTerm`, `resolveTag` | `meta.ts:210-268` | Slug → `Resolution` (`ok`/`not-found`/`unavailable`, `meta.ts:192-195`) | **Bien diseñado**: sí distingue "no existe" de "no pude saberlo" |
| `getCategories()` | `meta.ts:239-246` | `WcCategory[]` (`id,name,slug,parent`), o `null` si no hay datos | Base del árbol móvil. **No trae `count`, `image` ni `menu_order`** (`_fields`, `meta.ts:158`) e incluye categorías vacías (`hide_empty=false`) |
| `getAttributeTermNames(slug)` | `meta.ts:220-229` | slug→nombre de los términos | — |
| `validateFilters({categorySlug, attributes})` | `meta.ts:307-324` | `ok`/`invalid`/`unavailable` | Reutilizable para responder `400` ante un filtro inexistente |
| `invalidateCatalogMeta`, `warmCatalogMeta` | `meta.ts:271-297` | Invalidación y precalentamiento | — |
| (privado) carga de marcas | `meta.ts:166-168` | `wp/v2/product_brand?_fields=id,name,slug` | **No hay función exportada que liste las marcas**: solo `resolveBrandTerm` |
| `getWcStats()` | `metrics.ts:130-139` | Contadores del minuto en curso | Base para medir el impacto móvil (condición C4 del ADR-001) |

### 1.3 Otros módulos

| Símbolo | Archivo:línea | Qué hace | Reutilizable para móvil |
|---|---|---|---|
| `register()` | `src/instrumentation.ts:11-23` | Al arrancar en `nodejs`: `warmCatalogMeta()` y `warmCatalogIndex()` | Sí: ya beneficia a cualquier ruta |
| `categoryLabelForSlug`, `buildCategoryBreadcrumbs` | `catalog-meta.ts:78-80`, `112-127` | Etiquetas **estáticas** por slug y migas con URL web | Etiquetas sí; migas no (las URLs son web) |
| `SEARCH_PARAM`, `readSearchSelection`, `applySearchFilters`, `buildSearchDimensions` | `search-facets.ts:14-19`, `59-181` | Facetas calculadas sobre los resultados de búsqueda (marca, categoría, stock, rango de precio) | Sí: son funciones puras sobre `Product[]` |
| `FilterDimension`, `getProductosDimensions`, `getContextualDimensions(categoryPath)` | `filter-context.ts:16-23`, `229-250`, `325-341` | Dimensiones de filtro según la categoría, con reglas regex (`123-223`). **Las opciones salen de los menús estáticos** `menu-data` (`252-253`) | Parcial: las opciones dependen del menú web y no traen `count` |
| `BRAND_PRODUCTS_PAGE_SIZE` / `_MAX_` | `brand-products.ts:8,11` | 12 / 48 | — |
| `parseBrandIds`, `resolveBrandTermId`, `loadBrandLandingProducts` | `brand-landing-server.ts:19-49` | Marca → IDs de término | Sí |
| `LIQUIDATION_TAG_SLUG`, `fetchLiquidationProducts` | `liquidaciones.ts:14`, `30-50` | Productos con la etiqueta `liquidacion` | Sí |
| `discountPercent`, `discountAmount` | `liquidaciones-shared.ts:24-42` | Cálculo del descuento | Sí |
| `resolveBrand`, `getBrandLogo` | `brands.ts:72-92`, `137-141` | Marca a mostrar; logo como **ruta relativa** `/logos/marcas-recortadas/…` | Sí, convirtiendo el logo a URL absoluta |
| `sanitizeHtml`, `sanitizeText` | `security/sanitize.ts:185-238`, `6-12` | Saneado por lista blanca | Sí, **en el servidor** |
| Blog: `fetchBlogPosts`, `fetchBlogPostBySlug`, `fetchRseEntries`, `fetchCapacitacionesEntries` | `blog.ts:522`, `535`, `493`, `502` | WP `wp/v2/posts` | Ojo: **no pasan por `wcGet`** sino por `fetch` directo (`blog.ts:465-475`). Por tanto no tienen breaker, límite de concurrencia ni SWR en memoria. Contradice "TODA llamada pasa por `wcGet`" (`client.ts:13-15`) |

### 1.4 Rutas `/api/*` existentes (las que sirven de modelo)

| Ruta | Archivo:línea | Función usada | Validación / límites |
|---|---|---|---|
| `GET /api/marcas/[slug]/productos` | `route.ts:47-124` | `fetchCatalogProducts` o `searchBrandProducts` | Marca solo desde el registro `BRAND_LANDINGS` (`52-56`); `perPage` ajustado a 12/24/48 (`39-45`, `60-65`) **para no multiplicar las claves de caché**; página ≤ 50 (`40`, `59`); `q` ≤ 60 caracteres (`41`, `73-77`). Si hay `q`, la respuesta lleva `page: 1` y el total sin paginar (`93-104`) |
| `GET /api/search/suggestions?q=` | `route.ts:21-40` | `searchProducts(query, 6)` | Zod (`searchSchema.ts:24-36`, máx. 120 caracteres). Devuelve `SearchSuggestion` (`search-types.ts:8-35`) |
| `GET /api/liquidaciones/productos` | `route.ts:31-55` | `fetchLiquidationProducts` | `perPage` ≤ 48. **`page` sin tope en la ruta** (`33`), aunque `fetchCatalogProducts` corta en 200 (`wc.ts:424`) |
| `POST/GET /api/revalidate` | `route.ts:69-148` | `invalidateCatalogListings`, `invalidateProductDetail`, `invalidateCatalogMeta` | HMAC (`85-89`) **o secreto por `?secret=`** (`80-82`, H-10). Purga Next como máximo 1 vez cada 30 s, con un estado de módulo `lastNextPurgeAt` (`44-45`, `126-132`) |
| `GET /api/health` | `route.ts:14-19` | — | A propósito no consulta WooCommerce (`5-11`) |

---

## 2. Acoplamiento a Next.js y viabilidad desde `/mobile/v1/*`

| Mecanismo | Dónde | ¿Bloquea su uso en un Route Handler? | Comentario |
|---|---|---|---|
| `fetch(..., { next: { revalidate, tags } })` | `client.ts:291-296` | **No** (INFERENCIA) | La caché de datos de Next también aplica a `fetch` dentro de Route Handlers. Es una capa inferior "de regalo". **Solo existe en la ruta pública**: la ruta interna usa `node:http(s)` sin la caché de Next (`client.ts:246-288`, `313-320`). Si en producción está `WOOCOMMERCE_INTERNAL_URL`, la única caché real es la de memoria. Que esté configurada: **DESCONOCIDO** |
| `React.cache` (`reactCache`) | `wc.ts:17`, `1104` | **No** (INFERENCIA) | Fuera del render RSC se comporta como una llamada directa. La deduplicación real la hacen `detailCache` y el `inflight` de `wcGet` |
| `revalidateTag` / `revalidatePath` | `api/revalidate/route.ts:2`, `108`, `120`, `130-131` | No aplica | Solo los usa el webhook. `/mobile/v1` no los necesita |
| `cookies()` / `headers()` | Solo `session.ts:8,14,26` | **No** | La capa WooCommerce no depende de sesión ni de la petición |
| `unstable_cache`, `"use cache"`, `cacheHandler` | No aparecen en `src/` ni en `next.config.ts` (HECHO, búsqueda) | — | — |
| `node:http`/`node:https`, `Buffer` | `client.ts:1-2`, `67` | Exige **runtime `nodejs`** | Un Route Handler en runtime Edge rompería. `/mobile/v1` debe declarar o heredar `nodejs` (el valor por defecto; la instrumentación ya lo asume, `instrumentation.ts:12-14`) |
| `import pkg from package.json` | `client.ts:4` | No | — |
| Tipos `MenuItem` con URLs web | `wc.ts:96-101`, `catalog-meta.ts:112-127` | No bloquea, pero **no sirve como contrato** | Hay que mapear a un DTO móvil |

### ¿La caché y el índice en memoria funcionan igual desde `/mobile/v1`?

- **Cachés SWR, breaker, compuerta, inflight y métricas: sí, se comparten** dentro del mismo proceso, porque viven en `globalThis` (HECHO: `swr-cache.ts:184-196`, `client.ts:91-95`, `171-175`, `208-212`, `metrics.ts:43-52`). El propio código advierte que "Next puede cargar este módulo varias veces" (`swr-cache.ts:185-188`).
- **El índice de búsqueda NO está en `globalThis`.** Vive en variables de módulo `let indexEntries`, `indexBuiltAt`, `indexInvalidatedAt`, `indexBuild` (`wc.ts:726-731`), igual que `menuMemo` (`wc.ts:155`) y `lastNextPurgeAt` (`api/revalidate/route.ts:45`). **INFERENCIA / riesgo:** si Next instancia `woocommerce.ts` más de una vez (instrumentación, páginas, rutas), podría haber **varios índices de ~10.000 productos en el mismo proceso**. En ese caso el índice que precalienta `instrumentation.ts` no sería el que usa una ruta `/mobile/v1`, y `invalidateCatalogIndex()` llamada desde `/api/revalidate` no invalidaría el índice de otra instancia. Que esto ocurra en Next 16.3.4: **DESCONOCIDO**. Hay que verificarlo con un log de identidad del módulo en staging antes de depender de ello.
- **Entre procesos o réplicas no se comparte nada.** Cuántos procesos Node corren en producción es **DESCONOCIDO**: el despliegue ejecuta un comando remoto por SSH que no está en el repo (`deploy.yml:93-106`), y `health/route.ts:6-7` menciona Docker `HEALTHCHECK`.

**Conclusión:** invocar `fetchCatalogProducts`, `fetchProductsByIds`, `searchProducts`, `getCategories`, `fetchLiquidationProducts`, etc. desde un Route Handler `/mobile/v1/*` es **técnicamente directo** (esfuerzo de integración S). Los problemas no son de acoplamiento, sino de **semántica de errores (§5), exposición de datos (§4) y capacidad (§5)**.

---

## 3. Mapa PROPUESTO de endpoints móviles → funciones reutilizables

> Ninguno de estos endpoints existe hoy. Esfuerzo: **S** = adaptar o envolver código existente; **M** = lógica nueva moderada o un cambio en la capa compartida; **L** = diseño nuevo o dependencia de WordPress.
> Hay un trabajo transversal (DTO móvil, validación Zod, errores tipados, cabeceras de caché, rate limit, pruebas de contrato) que se estima aparte en §3.9.

| # | Endpoint propuesto | Qué ya existe | Qué falta | Esfuerzo |
|---|---|---|---|---|
| 3.1 | `GET /mobile/v1/products?category=&brand=&attr[x]=&tag=&onSale=&sort=&page=&perPage=` | `fetchCatalogProducts` (`wc.ts:411-503`) con filtros por categoría, marcas (≤5), etiquetas, atributos (≤5), `onSale`, orden y paginación. `validateFilters` (`meta.ts:307-324`) para responder 400 | (a) Ajustar `perPage` a pocos valores, como hace la ruta de marcas (`marcas/.../route.ts:39-45`), para no multiplicar las claves de `listings` (400 máx.). (b) **Distinguir error de vacío**: hoy el `catch` devuelve vacío (`wc.ts:497-502`) y los filtros con estado `unavailable` también (`wc.ts:447`, `484`). (c) Solo admite **una** categoría por consulta (`wc.ts:448`, comentario en `wc.ts:613-616`). (d) `search=` usa el `search` de WooCommerce, que el propio código considera "ruido" (`marcas/.../route.ts:91-92`): para móvil conviene redirigir la búsqueda a 3.5 | **M** (por el cambio de semántica de errores en la capa compartida) |
| 3.2 | `GET /mobile/v1/products/{slug}` | `fetchProductBySlug` (`wc.ts:1104-1136`) + `normalizeProductDetail` (`wc.ts:1042-1086`) | (a) **Corregir SEC-07**: añadir `status: "publish"` (`wc.ts:1117-1121`). Beneficia también a la web. (b) Distinguir `null` = no existe de `null` = WooCommerce caído (`wc.ts:1133-1135`). (c) DTO sin `stockQuantity` exacto y con HTML saneado en el servidor (§4) | **S** si solo se corrige SEC-07 y se hace el DTO; **M** con la distinción de errores |
| 3.3 | `GET /mobile/v1/products/by-id/{id}` (o `?ids=`) | `fetchProductsByIds` (`wc.ts:521-561`): lista, campos de listado y `status=publish` | **No existe ficha por ID.** Hace falta una variante de `fetchProductBySlug` con `include=` o `/products/{id}`, filtrando por estado (con `/products/{id}`, WooCommerce devuelve el producto aunque sea borrador: hay que comprobar `status` en la respuesta, INFERENCIA). Útil para revalidar el carrito local y favoritos. Para `?ids=`, poner un tope de IDs y vigilar `byIdsCache` (solo 50 claves, `wc.ts:518`) | **S-M** |
| 3.4 | `GET /mobile/v1/categories` (árbol) | `getCategories()` (`meta.ts:239-246`) + `buildCategoryTree` (`wc.ts:103-132`) + `categoryLabelForSlug` (`catalog-meta.ts:78-80`) | (a) Un mapeador a un DTO `{id, slug, name, parentId, children[]}` sin URL web (`toMenuItem` fija `/productos?cat=`, `wc.ts:99`). (b) `count` e imagen no se piden (`meta.ts:158`); añadirlos cambia `_fields` y la caché compartida. (c) Entran categorías vacías (`hide_empty=false`) y slugs numéricos o "-", que la ficha sí filtra (`wc.ts:1049-1055`). (d) El agrupado aire/refri/vent descarta raíces que no encajan (`wc.ts:139-152`): decidir si la app lo replica | **S** (sin `count`/imagen) · **M** (con `count`/imagen) |
| 3.5 | `GET /mobile/v1/search?q=&page=&perPage=&brand=&category=&stock=&price=` | `searchProducts(q, limit)` (`wc.ts:1035-1040`), con prioridad por SKU y código de parte (`wc.ts:919-923`, `951-962`) y tolerancia a una errata (`wc.ts:885-900`, `932-935`). Facetas: `buildSearchDimensions`/`applySearchFilters` (`search-facets.ts:75-181`). La web ya pagina en memoria sobre 5.000 coincidencias (`buscar/page.tsx:24`, `95-114`). Validación `searchSchema` (`searchSchema.ts:24-36`) | (a) Paginar en el BFF igual que `/buscar`. (b) Devolver un estado "índice en construcción" en vez de vacío: hoy `searchIndex` devuelve vacío si no hay índice tras 4 s (`wc.ts:982-983`). (c) La búsqueda por "referencia" = SKU está cubierta; una **referencia de fabricante distinta del SKU** solo se encuentra si figura en el nombre, los atributos, las etiquetas o la descripción corta (`wc.ts:836-842`). Si existe un meta propio de referencia: **DESCONOCIDO** | **S** |
| 3.6 | `GET /mobile/v1/search/suggest?q=` | `/api/search/suggestions` (`route.ts:21-40`) + `toSuggestions` (`search-types.ts:22-35`) | Copiarlo bajo `/mobile/v1` con un DTO propio (quitar `formattedPrice` si el precio es 0) | **S** |
| 3.7 | `GET /mobile/v1/products/{slug}/related` | Lógica **inline** en la página: última categoría de la ficha, `sort: "latest"`, 4 productos, quitando el propio (`producto/[slug]/page.tsx:14`, `72-83`) | Extraerla a `lib`. Depende de que el orden de `categories` refleje la jerarquía, algo que el código **supone** (`page.tsx:72-74`) pero no garantiza (§6). Devuelve como mucho 3-4 productos | **S** |
| 3.8 | `GET /mobile/v1/brands` y `GET /mobile/v1/brands/{slug}/products` | Registro `BRAND_LANDINGS` con `brandTermId`/`brandSlug` (`brand-landing-data.ts:32`, `64`; `brand-landing-server.ts:12-39`); `resolveBrandTerm` (`meta.ts:248-261`); `getBrandLogo` (`brands.ts:137-141`). Productos por marca: la misma lógica que `/api/marcas/[slug]/productos` | (a) **No hay función exportada que liste las marcas** de la taxonomía (la carga es privada, `meta.ts:166-168`, `183-184`): hay que exportar `getBrands()`. (b) Decidir la fuente de la lista: taxonomía `product_brand`, registro de landings (~26-28 marcas con config) o lista de alias `BRANDS` (`brands.ts:8-39`); no coinciden entre sí. (c) Convertir los logos relativos en URL absoluta | **S** (endpoint) · **M** si hay que conciliar las tres fuentes |
| 3.9 | `GET /mobile/v1/liquidaciones?page=&perPage=&sort=` | `fetchLiquidationProducts` (`liquidaciones.ts:30-50`) + `discountPercent` (`liquidaciones-shared.ts:24-35`) + modelo de ruta (`api/liquidaciones/productos/route.ts:31-55`) | Poner tope a `page` y devolver `discountPercent` ya calculado | **S** |
| 3.10 | `GET /mobile/v1/filters?category=` (atributos de filtro) | `getContextualDimensions(categoryPath)` (`filter-context.ts:325-341`), `getProductosDimensions()` (`229-250`) y `FilterDimension` (`16-23`) | (a) **Las opciones salen de los menús web estáticos** (`filter-context.ts:252-253`, `54-88`), no de lo que hay en la categoría: una opción puede no tener productos y faltar valores reales. (b) Sin `count` por opción. (c) La marca usa IDs del menú y el comentario dice "Sin taxonomía de marca en la tienda" (`filter-context.ts:272`), lo que contradice `meta.ts:166-168`. (d) Las reglas por regex dependen de la **ruta de categoría** (`categoryPath`), no del ID. (e) `paramKey` usa la convención web `filter_*`. Para un contrato estable hace falta un DTO propio y, si se quieren filtros "con conteo", un cálculo nuevo | **M** (reempaquetar) · **L** (facetas dinámicas con conteo por categoría) |
| 3.11 | **Transversal**: DTO móvil (`MobileProductSummary`, `MobileProductDetail`), errores tipados (`404`/`400`/`503` + `Retry-After`), `Cache-Control`/`ETag` hacia Cloudflare, rate limit, versión de contrato, OpenAPI y pruebas | `WcError`/`wcCircuitOpen` (`client.ts:71-81`, `136-139`); `Resolution` (`meta.ts:192-195`); `getWcStats` (`metrics.ts:130-139`) | Todo lo demás. Hoy **no hay pruebas** (`CLAUDE.md:35`) | **M-L** |

---

## 4. Datos que expone hoy el modelo y qué no conviene exponer a la app

### 4.1 Campos

| Campo | Origen | Exponer a la app | Motivo |
|---|---|---|---|
| `id`, `slug`, `name`, `sku` | `wc.ts:263-271` | Sí | — |
| `brand` | `resolveBrand(...)` (`wc.ts:266-270`) | Sí, con salvedades | Heurística con falsos positivos posibles (§6) |
| `price` (número, COP con IVA) | `Number(raw.price ?? "0")` (`wc.ts:258`) | Sí | `0` = "sin precio" (§6) |
| `formattedPrice` | `formatCOP(price)` (`wc.ts:273`, `utils/price.ts:8-10`) | **No** (o `null` si `price == 0`) | Da "$ 0" en productos sin precio. Conviene que la app formatee con su configuración regional |
| `category` | **primera** categoría (`wc.ts:274`) | Mejor `categories[]` | No es necesariamente la más específica (§6) |
| `categorySlugs[]` | `wc.ts:275` | Sí | — |
| `imageUrl` / `gallery[]` | `images[0].src` / todas (`wc.ts:261`, `1047`, `1078`) | Sí | Solo la URL original (`_fields` pide `images` y se usa `src`, `wc.ts:229`). **No hay miniaturas**: puede pesar mucho en móvil (INFERENCIA) |
| `inStock` (bool) | `stock_status === "instock"` (`wc.ts:277`) | Sí | `onbackorder` cuenta como no disponible (§6) |
| `onSale`, `regularPrice` | `wc.ts:260`, `278-279`; ficha `1081-1082` | Sí | — |
| `description`, `shortDescription` | **HTML crudo** de WordPress (`wc.ts:1075-1076`) | **Solo saneado en el servidor** (`sanitizeHtml`) o como texto plano | Hoy la web sanea en el cliente al pintar (`ProductTabs.tsx:27`, `72`) y la descripción corta se limpia con un regex (`ProductBuyBox.tsx:163-171`). La app no debe recibir HTML sin sanear (vale para WebView o para un renderizador HTML nativo) |
| `attributes[]` (`name`, `slug`, `options`) | `wc.ts:1057-1071` | Sí | Ya se deduplican por nombre |
| `categories[]` (`id`, `name`, `slug`) | `wc.ts:1049-1055` | Sí | — |
| **`stockQuantity`** | `raw.stock_quantity ?? null` (`wc.ts:1083`) | **No** | Información comercial sensible (inventario exacto) que la web **no muestra** (`ProductBuyBox.tsx:38-43` solo usa `stockStatus`). Si se necesita, exponer un rango ("pocas unidades") con una decisión de negocio |
| `stockStatus` | `wc.ts:1084` | Sí (enum) | — |

**INFERENCIA importante:** la web ya filtra hoy `stockQuantity` y el HTML crudo al navegador. `ProductBuyBox` es un Client Component (`ProductBuyBox.tsx:1`) que recibe el `ProductDetail` completo (`ProductBuyBox.tsx:27`), y React serializa esas props en el payload RSC. Conviene confirmarlo inspeccionando el HTML de una ficha. Si se confirma, es un hallazgo para la web además de para la app.

### 4.2 Estado real de SEC-07 (borradores o privados)

| Aspecto | Estado verificado hoy |
|---|---|
| Hallazgo (PDF, apartado SEC-07) | "fetchProductBySlug consulta products?slug=... con credenciales administrativas sin incluir status: publish", y propone añadir `status: "publish"` |
| Código actual | **SIGUE ABIERTO.** El `URLSearchParams` de la ficha solo lleva `slug`, `per_page` y `_fields` (`wc.ts:1117-1121`). El PDF citaba `L1158-L1162`; el archivo ha cambiado de tamaño, pero la omisión es la misma |
| Resto de consultas | Sí filtran: listado (`wc.ts:429`), por IDs (`wc.ts:536`) e índice (`wc.ts:753`) |
| `catalog_visibility` ("oculto del catálogo") | **No se filtra en ninguna consulta** (HECHO, búsqueda sin coincidencias en `src/`). INFERENCIA: un producto publicado pero marcado como "oculto" aparece en los listados, la búsqueda y el sitemap. Si se usa esa opción en la tienda: **DESCONOCIDO** |
| Productos protegidos con contraseña | No se tratan en ninguna parte. Si existen: **DESCONOCIDO** |
| Riesgo añadido por la app | El slug lo elige quien llama: una API JSON pública facilita enumerar slugs más que la web. Además `detailCache` **guarda** el borrador servido durante 5 min y 24 h stale (`wc.ts:1088-1094`) |

### 4.3 Estado real de la sanitización de descripciones

| Aspecto | HECHO |
|---|---|
| Sanitizador | `sanitizeHtml`: tokenizador propio con lista blanca de etiquetas (`sanitize.ts:22-27`), descarta `script/style/svg/form…` con su contenido (`33-36`), atributos por etiqueta y nunca `on*`, `style` ni `srcset` (`39-45`), esquemas de URL permitidos tras decodificar entidades y caracteres de control (`47-48`, `86-94`), `iframe` solo de YouTube/Vimeo (`50-54`, `96-104`), y "falla cerrando" (`177-184`) |
| Dónde se aplica | **Solo en `ProductTabs.tsx:27`**, en el cliente (`"use client"`). La descripción corta se limpia con un regex de etiquetas (`ProductBuyBox.tsx:167`) y se pinta como texto (seguro, porque React escapa) |
| Dónde NO se aplica | En la capa de datos (`wc.ts:1075-1076`), así que cualquier consumidor nuevo (el BFF) recibe HTML crudo. Los bloques de marca usan `dangerouslySetInnerHTML` sin sanear (`TextBlock.tsx:20,40,60`), aunque su contenido son configs locales (fuera del alcance móvil) |
| Observación | Los `iframe` permitidos llevan `sandbox="allow-scripts allow-same-origin …"` (`sanitize.ts:169`). Esa combinación debilita el sandbox. Está acotado a hosts de vídeo, pero conviene revisarlo si la app pinta HTML en WebView |
| Robustez | **No verificada con pruebas** (no existen). Las expresiones regulares (`sanitize.ts:106-109`) parecen razonables, pero un sanitizador propio sin batería de pruebas de XSS no permite afirmar que sea robusto: queda como **DESCONOCIDO** |

---

## 5. Comportamiento ante fallos, límites y efecto del tráfico móvil

### 5.1 Mecanismos (HECHO)

| Mecanismo | Valor | Cita |
|---|---|---|
| Timeout por intento | 8 s por defecto; 15 s en meta; 20 s en páginas del índice | `client.ts:50`; `meta.ts:32`; `wc.ts:757` |
| Reintentos | 2 (3 intentos), solo ante 5xx, 429 o falta de respuesta; backoff de 300 ms a 2 s con jitter | `client.ts:51-53`, `153-164`, `355-378` |
| Peor caso de una llamada sin caché | 3 × 8 s + ~1,5 s de backoff ≈ **25 s**, más la espera en la cola | Cálculo a partir de lo anterior (INFERENCIA). Supera `maxDuration = 15` de la ruta de marcas (`marcas/.../route.ts:27`); que `maxDuration` tenga efecto en un servidor Node propio es **DESCONOCIDO** |
| Circuit breaker | Se abre con 5 fallos seguidos durante 30 s; en semiabierto deja pasar **una** prueba; los 4xx no cuentan | `client.ts:56-58`, `104-133`, `368-371` |
| Concurrencia hacia WordPress | **4** a la vez **por proceso**; el resto espera en una cola **sin tope ni tiempo máximo** | `client.ts:48`, `214-228` |
| El timeout empieza **después** de la cola | `acquire()` va antes del `fetch` con `AbortSignal.timeout` | `client.ts:310` vs. `294` |
| Deduplicación | Peticiones idénticas en vuelo comparten la llamada | `client.ts:388-399` |
| SWR | Dato fresco → hit; vencido → se sirve y se refresca en segundo plano; sin dato → se espera; **un error nunca se guarda**; enfriamiento de 10 s a 120 s por clave tras un fallo | `swr-cache.ts:8-17`, `40-41`, `66-86`, `137-173` |
| Vida "stale" máxima | Listados, fichas y by-ids: 24 h; meta: 7 días | `wc.ts:385`, `515`, `1091`; `meta.ts:70` |
| Freno a tormentas de webhooks | Como mucho un refresco por clave cada 30 s (60 s en meta); purga de Next como mucho cada 30 s | `wc.ts:388`, `517`, `1092`; `meta.ts:72`; `revalidate/route.ts:44`, `126-132` |
| Precalentamiento al arrancar | Meta + índice, sin bloquear | `instrumentation.ts:14-22`; `meta.ts:280-297` |

### 5.2 Qué pasa si WooCommerce se cae

| Situación | Respuesta actual (HECHO) | Consecuencia para la app |
|---|---|---|
| Con dato en caché de hace menos de 24 h | Se sirve el dato viejo | Correcto. Conviene informarlo (por ejemplo, cabecera `X-Data-Stale`) |
| Listado sin caché | Vacío `{products: [], total: 0}` (`wc.ts:497-502`) | La app mostraría "sin productos" en vez de "reintentar" |
| Ficha sin caché | `null` → la web hace `notFound()` (`page.tsx:70`) | **404 falso**: la app podría borrar el producto del carrito o de favoritos |
| Filtro con meta no disponible | Vacío (`wc.ts:447`, `484`) | Igual que arriba |
| Búsqueda sin índice (arranque en frío o reconstrucción tras webhook) | Vacío tras esperar hasta 4 s (`wc.ts:706`, `876-879`, `982-983`) | "Sin resultados" durante minutos tras cada despliegue si WordPress va lento |
| Breaker abierto | `WcError(circuitOpen)` (`client.ts:356-358`), que las funciones de alto nivel convierten en vacío o `null` | La información está, pero se pierde por el camino |
| Webhook de producto | Listados y fichas se marcan como viejos y el índice se invalida (`wc.ts:1149-1154`). **Las búsquedas siguientes esperan hasta 4 s** cada una hasta que termine la reconstrucción (`wc.ts:857`, `876-879`) | Latencia de búsqueda irregular en horas de sincronización masiva |

### 5.3 Límites de memoria y tamaño

| Elemento | HECHO | INFERENCIA / DESCONOCIDO |
|---|---|---|
| Índice | Máx. 100 páginas × 100 = **10.000 productos** (`wc.ts:686`, `695`, `790`). Si `totalPages > 100`, se trunca **sin avisar** y la reconstrucción se marca como `complete` | Con más de 10.000 productos publicados, la búsqueda y el sitemap pierden productos en silencio. **Tamaño real del catálogo: DESCONOCIDO** |
| RAM del índice | Cada entrada guarda el `Product` normalizado más ~9 cadenas normalizadas, entre ellas la descripción corta, hasta 400 caracteres (`wc.ts:709-723`, `820-844`) | Estimación de ~1-3 KB por entrada → **~10-30 MB** con 10.000 productos. Durante una reconstrucción conviven el índice viejo y las páginas crudas del nuevo (pico ~2×). Si el módulo se duplica (§2), se multiplica |
| Cachés SWR | `listings` 400 claves (hasta 100 productos cada una), `detail` 600 (con HTML de descripción), `by-ids` 50, `meta` 10, `meta-terms` 200 (`wc.ts:389`, `1093`, `518`; `meta.ts:75-77`) | Del orden de **decenas de MB** en el peor caso (INFERENCIA). Sin medición |
| Caché de datos de Next | Rechaza entradas de más de 2 MB: por eso `_fields` es obligatorio (`wc.ts:45-52`, `CLAUDE.md:106`) | La ficha incluye `description`. Una descripción enorme podría acercarse al límite (poco probable). Configuración de memoria o disco de Next en producción: **DESCONOCIDO** |
| Memoria del proceso Node | — | Límite (`--max-old-space-size`, tamaño del droplet o contenedor): **DESCONOCIDO** |
| Procesos o réplicas | — | **DESCONOCIDO**. Con N procesos hay N índices, N breakers y N rebuilds contra WordPress |

### 5.4 Qué implica multiplicar el tráfico con la app (INFERENCIA)

1. **La carga sobre WordPress no crece en proporción a las peticiones** mientras las consultas móviles reutilicen las **mismas claves** que la web (mismos `perPage`, orden y filtros). Las cachés absorben la repetición. Si la app usa otros `perPage` u otras combinaciones, cada una es una clave nueva en `listings` (400 máx.) y se pierde el beneficio: habrá más expulsiones y más llamadas a WordPress. **Recomendación:** fijar en `/mobile/v1` los mismos tamaños de página que la web.
2. **El cuello de botella es la compuerta de 4 conexiones por proceso** (`client.ts:48`). La comparten la web, la app, la reconstrucción del índice (que usa 4 páginas a la vez, `wc.ts:697`) y el precalentamiento de meta. Mientras se reconstruye el índice, la compuerta está llena y cualquier fallo de caché web o móvil hace cola **sin límite de tiempo** (`client.ts:220`).
3. **La búsqueda y las sugerencias no tocan WordPress** (van contra el índice en memoria), pero cuestan CPU: cada consulta recorre las hasta 10.000 entradas, y una segunda vez con tolerancia a errata si no hubo coincidencias (`wc.ts:988-999`). Con sugerencias "mientras se escribe" desde la app, el CPU del proceso Node puede ser el límite (sin medición).
4. **El rate limit actual es en memoria y por proceso** (Entrega 1.1, H-04) y no cubre catálogo. Una API JSON pública es más fácil de raspar que la web: conviene limitarla por IP o dispositivo en Cloudflare y en el servidor.
5. **Escalar a más procesos no es gratis:** cada uno reconstruiría su propio índice (~100 llamadas cada 5 min si el catálogo ronda los 10.000) y tendría su propio breaker. Solo uno recibiría cada webhook si este no se reparte (INFERENCIA).
6. `metrics.ts` ya registra llamadas por minuto, aciertos de caché y estado del breaker (`metrics.ts:54-84`), con el objetivo declarado de "< ~30 llamadas por minuto" (`metrics.ts:4-6`). Es la base para la condición C4 del ADR-001. Conviene añadir una dimensión "origen = mobile".

---

## 6. Calidad de datos observable en el código

| Tema | HECHO | Implicación (INFERENCIA salvo que se indique) |
|---|---|---|
| **Resolución de marca** | Orden: (1) atributo cuyo slug o nombre contenga `brand` o `marca`, canonizado (`wc.ts:250-255`; `brands.ts:77-80`); (2) **marca deducida del nombre** del producto (`brands.ts:81-82`); (3) taxonomía `product_brand`, salvo el término "generic" (`brands.ts:84-90`) | La taxonomía tiene **menos prioridad que el nombre**. La coincidencia es por **subcadena** sobre texto sin espacios (`brands.ts:41-56`), así que alias cortos como `electron`, `alfa`, `ipr`, `gree`, `weg` pueden dar falsos positivos (p. ej. "control **electrón**ico" → "Electron", si ninguna marca anterior de la lista coincide). Hay que validarlo con datos reales |
| Marca: búsqueda frente a filtro | El filtro de listados usa **IDs de taxonomía** (`wc.ts:458-461`) y el índice guarda `brandIds` de la taxonomía (`wc.ts:826`), pero la faceta de búsqueda filtra por el **nombre heurístico** (`search-facets.ts:85`, `120-125`) | Pueden darse resultados distintos para "la misma marca" según la pantalla |
| Typos y alias en datos | Lista de correcciones: "ZIEHL-ABEEG", "Emerson" → "Copeland", "Fiberglass Isover" (`brands.ts:10`, `17-18`, `23-24`); entidades `&amp;` en términos (`brands.ts:85-86`) | Hay datos de marca inconsistentes en WooCommerce |
| Fuentes de marca no alineadas | `BRANDS` (28 alias, `brands.ts:8-39`), `BRAND_LOGOS` (`brands.ts:101-131`), `BRAND_LANDINGS` (`brand-landing-data.ts:32`) y la taxonomía `product_brand` (`meta.ts:166-168`) | Marcas con landing como Danfoss, Chint, Embraco o Honeywell no están en `BRANDS` |
| **Categorías** | `category` = **primera** de la lista (`wc.ts:274`); la ficha toma como principal la **última** (`page.tsx:72-74`), suponiendo un orden jerárquico que WooCommerce no garantiza | La categoría "principal" puede no coincidir entre listado y ficha |
| Categorías sucias | La ficha descarta slugs vacíos o numéricos y nombre "-" (`wc.ts:1049-1055`); las facetas descartan "uncategorized" o "sin-categorizar" (`search-facets.ts:48-50`) | Existen categorías basura en la tienda. El árbol de `getCategories` **no** las filtra |
| Etiquetas de categoría | Mapa estático de ~55 slugs (`catalog-meta.ts:7-66`); el resto se "humaniza" (`catalog-meta.ts:69-75`) | Los nombres que ve la web no siempre son el `name` de WooCommerce. La app debería usar `name` o el mismo mapa |
| **Productos sin precio** | `Number(raw.price ?? "0")`: `""` → `0` (`wc.ts:258`). En la web, sin precio solo hay botón "Más información" → WhatsApp y no hay carrito (`ProductBuyBox.tsx:30-32`, `150-159`) | Coincide con ADR-002. La app debe tratar `price == 0` como "consultar" y **nunca** permitir añadirlo al carrito |
| `price == 0` en orden y facetas | `/buscar` manda los productos a precio 0 al final al ordenar por precio (`buscar/page.tsx:99-106`); el rango de precio mínimo empieza en 1, así que los de precio 0 no entran en ninguna faceta de precio (`search-facets.ts:34`, `52-56`). En el **listado** el orden lo hace WooCommerce (`orderby=price`, `wc.ts:361-364`) | INFERENCIA: en `price-asc` del listado, los productos de precio 0 saldrán **primero**. La app heredará ese comportamiento |
| Comparador inconsistente | `byPrice` devuelve `1` cuando **ambos** precios son 0 (`buscar/page.tsx:104`) | Orden no determinista entre productos sin precio (menor) |
| `onSale` | Solo si `on_sale` y `price > 0` y `regular > price` (`wc.ts:260`) | Robusto frente a datos incoherentes |
| Stock | `inStock` solo si `instock` (`wc.ts:277`); en la ficha, `onbackorder` se pinta como "Agotado" (`ProductBuyBox.tsx:38-44`) aunque exista la etiqueta "Disponible bajo pedido" (`ProductBuyBox.tsx:19`) | Productos "bajo pedido" se ven como agotados y no se pueden comprar. Es una decisión de negocio pendiente para la app |
| Stock por sede | No existe en el modelo | Confirmado (Entrega 1.1, D-05) |
| Atributos repetidos | Se deduplican por nombre (`wc.ts:1065-1071`); hay slugs de términos "pegados" (`12-0-hp` frente a `120hp`) tolerados con `byLoose` (`meta.ts:55-56`, `132-136`; `filter-context.ts:256-266`) | Los términos de atributos tienen inconsistencias de captura |
| Imágenes | Sin imagen → `imageUrl = ""` y galería vacía (`wc.ts:261`, `1077-1078`) | La app necesita un placeholder |

---

## 7. Riesgos técnicos, recomendaciones y preguntas abiertas

### 7.1 Riesgos

| ID | Riesgo | Evidencia | Probabilidad / impacto | Mitigación propuesta |
|---|---|---|---|---|
| RB-01 | Exposición de borradores, pendientes o privados por slug (SEC-07) | `wc.ts:1117-1121` | Alta / Media-Alta | `status: "publish"` en la ficha (cambio de 1 línea que también beneficia a la web) + prueba de contrato |
| RB-02 | Errores convertidos en "vacío" o "404" | `wc.ts:497-502`, `1133-1135`; `meta.ts` sí distingue (`192-207`) | Alta / Alta para la app | Añadir variantes que devuelvan un resultado discriminado (`ok`/`not-found`/`unavailable`) **sin cambiar las firmas actuales** (regla `CLAUDE.md:124`), y mapear a 404 o 503 |
| RB-03 | Cola de concurrencia sin tope ni tiempo máximo; el timeout empieza después de la cola | `client.ts:214-228`, `310` vs `294` | Media / Alta con picos | Tope de cola y timeout de espera; prioridad baja para la reconstrucción del índice; medir con `getWcStats` |
| RB-04 | El índice está en variables de módulo, no en `globalThis` | `wc.ts:726-731` frente a `swr-cache.ts:189-196` | DESCONOCIDA / Media (RAM ×N, invalidación que no llega) | Verificar en staging; si se duplica, moverlo a `globalThis` como las cachés |
| RB-05 | Datos sensibles en el modelo (`stockQuantity`, HTML crudo) | `wc.ts:1075-1076`, `1083` | Alta / Media | DTO móvil explícito por lista blanca; `sanitizeHtml` en el servidor |
| RB-06 | Truncamiento silencioso del índice por encima de 10.000 productos | `wc.ts:695`, `790` | DESCONOCIDA / Media | Registrar `totalPages` y avisar si supera 100 |
| RB-07 | Facetas de filtro basadas en menús web estáticos | `filter-context.ts:252-253` | Media / Media (filtros vacíos o incompletos en la app) | Contrato de filtros propio; a medio plazo, facetas desde meta y conteos |
| RB-08 | Heurística de marca con falsos positivos | `brands.ts:49-57`, `81-82` | Media / Baja-Media | Dar prioridad a la taxonomía; coincidencia por palabra o alias exacto; limpieza de datos en WooCommerce |
| RB-09 | Despliegue acoplado web y BFF, sin pruebas | `CLAUDE.md:35`; ADR-001 "Consecuencias" | Alta / Media | Pruebas de contrato de `/mobile/v1` y una prueba mínima de humo de `woocommerce.ts` con WooCommerce simulado |
| RB-10 | El blog no pasa por `wcGet` (sin breaker ni concurrencia) | `blog.ts:465-475` | Baja / Baja (solo si la app consume el blog) | Si se expone en la app, pasarlo por `wcGet` o una caché SWR |
| RB-11 | El webhook acepta el secreto por `?secret=` (H-10) | `revalidate/route.ts:80-82` | Media / Baja-Media | Solo cabecera o HMAC |
| RB-12 | Imágenes a tamaño original | `wc.ts:229`, `261` | Media / Media (datos móviles y rendimiento) | Pedir los tamaños de WordPress o usar el optimizador de Next o Cloudflare; decidir en el diseño del DTO |

### 7.2 Recomendaciones (orden sugerido)

1. **Antes de escribir `/mobile/v1`:** corregir SEC-07 (RB-01) y añadir variantes "con resultado discriminado" de `fetchCatalogProducts`, `fetchProductBySlug` y `searchProducts`. Hay que respetar la regla de no cambiar firmas (`CLAUDE.md:124`) y que el archivo es "neurálgico" (`CLAUDE.md:106`), así que van en un PR propio revisado por el responsable del repo.
2. **Capa `src/lib/mobile/`** (propuesta) con DTOs por lista blanca, mapeadores (`toMobileProductSummary`, `toMobileProductDetail` con `sanitizeHtml` en el servidor, sin `stockQuantity` ni `formattedPrice` cuando el precio es 0), validación Zod de parámetros y valores fijos de `perPage` (12/24/48, como `marcas/.../route.ts:39`).
3. **Rutas finas** `src/app/mobile/v1/**/route.ts` (runtime `nodejs`) que solo validen, llamen a `lib`, mapeen y pongan `Cache-Control` (`s-maxage` + `stale-while-revalidate`) para que **Cloudflare absorba la carga de lectura del catálogo** antes de llegar a Node.
4. **Observabilidad:** etiquetar en `metrics.ts` las llamadas originadas por `/mobile/v1` y medir en staging (condición C4). Verificar RB-04 con un log de identidad del módulo.
5. **Capacidad:** acotar la cola de `wcGet` (RB-03) y hacer una prueba de carga con el perfil acordado antes del piloto.
6. **Calidad de datos:** dar prioridad a la taxonomía de marca y revisar los alias cortos. Limpiar las categorías basura en WooCommerce. Decidir qué hacer con `onbackorder`.

### 7.3 Preguntas abiertas para el equipo

**Críticas (bloquean el diseño del BFF):**
1. ¿Cuántos **productos publicados** hay hoy y cuántos se esperan? (El índice se corta en 10.000, `wc.ts:695`.)
2. ¿Cuántos **procesos o réplicas de Node** corren en producción, con cuánta RAM, y está configurada `WOOCOMMERCE_INTERNAL_URL`? (Determina si existe la caché de datos de Next, `client.ts:313-320`.)
3. ¿Aceptan corregir **SEC-07** ya (afecta también a la web) y añadir variantes de funciones con errores discriminados en `woocommerce.ts`?
4. ¿Se puede mostrar a la app el **stock exacto** o solo disponible/no disponible? ¿Y qué hacer con "**bajo pedido**" (`onbackorder`): ¿se puede comprar?
5. ¿Cuál es la **fuente oficial de marcas** para la app: la taxonomía `product_brand`, el registro de landings o la lista de alias?

**Importantes:**
6. ¿Se usa en WooCommerce la visibilidad "**oculto del catálogo**" o productos con contraseña? (Hoy no se filtran.)
7. ¿Existe un campo de **referencia de fabricante** distinto del SKU (meta o atributo) que la búsqueda móvil deba cubrir?
8. ¿Los filtros de la app deben salir de los menús actuales (como la web) o hace falta un sistema de **facetas con conteo** por categoría?
9. ¿Cómo se debe mostrar la descripción en la app: HTML en WebView, HTML en un renderizador nativo o texto plano? (Afecta al saneado y a los `iframe`.)
10. ¿Hay presupuesto de **tamaño de imagen** para móvil? ¿Se pueden usar los tamaños generados por WordPress o un servicio de imágenes de Cloudflare?
11. ¿Hay **horas de sincronización masiva** (ERP → WooCommerce) que disparen ráfagas de webhooks? (Cada una invalida el índice y frena las búsquedas hasta 4 s.)
12. ¿Se acepta que el orden "precio ascendente" del listado muestre primero los productos sin precio, o se corrige en el BFF?

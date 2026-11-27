# Plan de paridad con la web — App móvil IPR (Fase W)

| | |
|---|---|
| **Proyecto** | App móvil Flutter de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fecha** | 2026-11-26 |
| **Estado** | **PROPUESTA a aprobar.** No cambia el alcance aprobado hasta que un humano decida (ver §7). Complementa a [roadmap.md](roadmap.md) y [implementation_plan.md](implementation_plan.md); no los sustituye. |
| **Fuentes** | Web `ipr-frontend` (solo lectura): `docs/documentacion-proyecto.md` (oct-2026), `docs/estructura-de-categorias.md` (18-nov-2026), `docs/productos-variables.md`, `docs/landings-de-marca.md`, rutas de `src/app`, `src/features/home`, `wp-snippets/`. App: M0–M5 ([m5_resultados.md](m5_resultados.md), [pt19_pt20_resultados.md](pt19_pt20_resultados.md)) y el contrato `contract/openapi.yaml`. |

**Convención de certeza** (igual que el roadmap): **HECHO** (comprobado en código o documento citado) · **SUPUESTO** · **PROPUESTA** · **PENDIENTE** · **RIESGO** · **DESCONOCIDO**. Esfuerzo relativo S/M/L/XL; **sin fechas ni duraciones** (D-15).

---

## 1. Resumen

1. **HECHO** — La app ya cubre el núcleo transaccional de la web: Inicio, árbol de categorías desplegable, listados con filtros, búsqueda, ficha, carrito, checkout con ticket, cuenta, pedidos, sedes, PQRS, liquidaciones y calculadora BTU (apagada por D-08). Visualmente se acercó a la web (tokens, hero, banda de cifras, tarjetas).
2. **HECHO** — La web, en cambio, tiene piezas que la app **no tiene**: productos variables, carrusel de campañas, landings de marca ricas, contenido editorial (blog, RSE, capacitaciones, quiénes somos), directorio comercial y mapa de sedes.
3. **HECHO** — El BFF `/mobile/v1` **no existe todavía** en `ipr-frontend` (sin coincidencias de `mobile/v1` en `src/` ni `wp-snippets/`). Todo lo de este plan que necesite datos nuevos es un cambio de contrato antes que de pantalla (ADR-001: la app solo habla con `/mobile/v1`).
4. **PROPUESTA** — Cuatro olas, ordenadas por impacto en ventas y por dependencia: **Ola 1** compra y catálogo (variables, orden de categorías, enlaces profundos), **Ola 2** portada y campañas, **Ola 3** marcas y ayuda técnica, **Ola 4** contenido editorial (fase 2).
5. **PROPUESTA** — Para lo editorial y las mecánicas de campaña (ruleta, raspa), **abrir la web en navegador seguro primero** y volver nativo solo lo que se use de verdad.

---

## 2. Punto de partida

### 2.1 App (HECHO)

| Área | Estado |
|---|---|
| Rebanadas M0–M5 | Construidas y probadas **en local** contra el BFF simulado; 2.205 pruebas, cobertura ≈ 95 %. |
| Visual | Revisión de tokens y de Inicio (2026-11-26): [design_system.md §6.4](../07_ux_ui/design_system.md). Árbol de categorías desplegable en el Catálogo. |
| Pendiente de cierre | CI remoto, staging, Wompi sandbox, dispositivos reales, pentest ([pt19_pt20_resultados.md](pt19_pt20_resultados.md)). Prueba `ST-127` en rojo por `mediaHosts` en `config/dev.json` (decisión del equipo: dejarlo). |

### 2.2 Web (HECHO)

Next.js headless sobre WordPress/WooCommerce. Rutas principales (`src/app`): `/`, `/productos`, `/categoria-producto/[…slug]`, `/producto/[slug]`, `/buscar`, `/carrito`, `/checkout`, `/pedido-confirmado`, `/login`, `/registro`, `/mi-cuenta`, `/liquidaciones`, `/marcas`, `/marcas/[slug]`, 12 landings de marca dedicadas, campañas (`/jugada-samsung`, `/parche-midea`, `/actividades-promocionales`), `/donde-estamos`, `/contacto`, `/ingenieria`, `/pqrs`, `/calculadora`, `/blog`, `/responsabilidad-social`, `/capacitaciones`, `/quienes-somos`, `/ipr`.

Hechos recientes de la web que condicionan este plan:

* **18-nov-2026** — el menú sale 100 % del árbol `product_cat` (sin listas fijas), con orden jerárquico fijo (`menu-order.ts`) y ocultando categorías con `count = 0`.
* **Productos variables** — piloto con un solo grupo (VAR0416, desincrustante Alfa Coil Cleaner); la línea del carrito usa el **id de la variación**.
* **Campañas** — las mecánicas viven en WordPress (`ipr-raspa-samsung.php`, `ipr-ruleta-midea.php`), no en el front.

---

## 3. Principios

| # | Principio | Efecto |
|---|---|---|
| P1 | **La web es la referencia de contenido y marca; el BFF es la única puerta.** | Nada de leer WooCommerce (`wc/v3`), WordPress (`wp/v2`) ni `/api/*` del sitio desde la app (ADR-001). |
| P2 | **Primero lo que vende.** | Variables, categorías y enlaces profundos antes que lo editorial. |
| P3 | **El servidor manda en datos y cifras.** | Cifras institucionales, banners y contactos llegan por el BFF; la app no fija «+30 años» ni teléfonos (D-07). |
| P4 | **Nativo solo donde aporta.** | Compra, cuenta y catálogo son nativos. Editorial y mecánicas de campaña, en navegador seguro hasta que haya demanda. |
| P5 | **Accesible por defecto.** | Carruseles sin autoavance > 5 s con controles (WCAG 2.2.2); nada de Ken Burns ni destellos (ver [design_system §6.5](../07_ux_ui/design_system.md)). |

---

## 4. Inventario web y cobertura en la app

| Pieza de la web | Estado en la app | Qué falta |
|---|---|---|
| Home (portada, cifras, más vendidos, categorías, sedes, marcas, BTU) | **Parcial** | Carrusel de campañas, cifras institucionales, bloque de ingeniería y de formación. |
| Menú de categorías (mega menú / menú móvil) | **Hecho** (árbol desplegable) | Orden fijo y ocultar vacías **en el BFF**; logos de marcas por división. |
| Catálogo y filtros (`/productos`, `/categoria-producto`) | **Hecho** | Verificar paridad de filtros con `fetchCategoryFacets` (solo lo que tienen los productos de la categoría). |
| Ficha de producto | **Parcial** | **Productos variables** (selector, «Desde $», «Ver opciones»). |
| Búsqueda y sugerencias | **Hecho** | SKU de una variación debe llevar al producto padre. |
| Carrito | **Hecho** (local + revalidación) | Línea por variación; verificar avisos de disponibilidad y cantidad máxima. |
| Checkout y confirmación | **Hecho** (ticket + navegador seguro) | `variationId` en el ticket (requiere actualizar `ipr-cart-handoff.php`). |
| Login, registro, mi cuenta, pedidos | **Hecho** | — |
| Liquidaciones | **Hecho** | — |
| Marcas y página de marca | **Parcial** | Landing rica por marca (hero, familias, destacados, FAQ, productos). |
| 12 landings dedicadas (Daikin, Midea, Samsung, Gree, Hisense, Trane, Rowa, Danfoss, Aspen, Full Gauge, Elitech, IPR) | **Falta** | Plantilla común con acento por marca. |
| Campañas (Jugada Samsung, Parche Midea, Actividades promocionales) | **Falta** | Entrada desde el carrusel; mecánica en navegador seguro. |
| Sedes (`/donde-estamos`) | **Hecho** (lista y ficha) | Mapa de Colombia. |
| Contacto | **Parcial** | Directorio comercial por ciudad y área. |
| Ingeniería | **Parcial** (un canal) | Equipo por especialidad con WhatsApp propio. |
| PQRS | **Hecho** | — |
| Calculadora BTU | **Hecho** (apagada, D-08) | Contrastar la fórmula con `BtuCalculator.tsx` de la web. |
| Blog, RSE, Capacitaciones, Quiénes somos, `/ipr` | **Falta** (fuera del MVP) | Decisión de alcance (§7). |
| Newsletter | **Falta** | Consentimiento (D-12). |
| Sitemap, JSON-LD, robots, redirecciones 301 | **No aplica** | Son SEO; solo importa el mapeo de enlaces (W1-03). |

---

## 5. Brechas priorizadas por ola

### Ola 1 — Compra y catálogo (máximo impacto en ventas)

| ID | Trabajo | Web de referencia | Esfuerzo | Depende de |
|---|---|---|---|---|
| **W1-01** | **Productos variables**: selector por atributo, «Desde $X» y «Ver opciones» en tarjetas, opciones inexistentes deshabilitadas, variación sin precio → «Más información» (WhatsApp). Carrito y ticket con `variationId`. | `productos-variables.md`, `VariantSelector`, `useCartStore` | **XL** | Cambio de contrato (§6.1), `ipr-cart-handoff.php`, más grupos convertidos por Marketing |
| **W1-02** | **Categorías del BFF**: aplicar el orden de `menu-order.ts` y ocultar `count = 0` en el servidor, para que el árbol de la app coincida con la web (la app **no reordena**, AC-010-5). | `menu-tree.ts`, `estructura-de-categorias.md` | **M** | BFF |
| **W1-03** | **Enlaces profundos web ↔ app**: mapear `/producto/{slug}`, `/categoria-producto/{cadena}`, `/marcas/{slug}`, `/liquidaciones`, `/donde-estamos/{slug}` a rutas de la app (la web usa la **cadena completa de slugs**). | `categoryUrl`, `next.config.ts` | **M** | D-14 (dominio/App Links), `deploy/.well-known` |
| **W1-04** | Paridad de **filtros por categoría** y de **búsqueda** (SKU de variación → padre; código de grupo no visible). | `filter-context.ts`, `buildCatalogIndex` | **S** | W1-01 |
| **W1-05** | Paridad de **avisos del carrito** (disponibilidad, cantidad máxima). | `CartLineNotices`, `MaxQuantityNotice` | **S** | — |

#### Estado de la Ola 1 (2026-11-26)

| ID | Estado | Detalle |
|---|---|---|
| **W1-01** | **Hecho en la app y el BFF simulado; pendiente de backend real** | Contrato ampliado (campos **opcionales**, compatibles hacia atrás): `ProductSummary.hasVariants/priceFrom/variantLabel`, `ProductDetail.variantAxes/variants`, esquemas `ProductVariantAxis` y `ProductVariant`. La app: selector por eje con opciones deshabilitadas, tocar la elegida la quita, «Desde $X» y «Selecciona una opción», compra con el **id de la variación** y su opción en el nombre, tarjetas con «Desde» y «Ver opciones», líneas del carrito con la opción. El BFF demo sirve el producto real del piloto (Alfa Coil Cleaner: 500 cc \$8.200, 1 L \$12.500, 1 galón \$31.000; ids de variación de demostración). Falta: implementar el contrato en el BFF real y actualizar `ipr-cart-handoff.php` (hoy solo lee `id` y `quantity`; funciona igual porque WooCommerce convierte el id de variación). |
| **W1-02** | **Documentado en el contrato; pendiente de backend** | `GET /categories` ahora **exige** orden jerárquico y depuración en el servidor (como `menu-tree.ts`). La app no cambia (no reordena). El BFF demo ya usa el orden de la web en las tres divisiones. |
| **W1-03** | **En pausa: requiere decisión de seguridad** | La política de enlaces profundos (CR-001, SC-067) es un control **aprobado**: solo `/app/pedido`, «nunca comodines», y una prueba (ST-124/`router_policy_test`) exige rechazar `/producto/x`. Además el manifiesto de Android solo declara esa ruta y D-14 (dominio y huellas de firma) sigue abierta. Ampliarla es una decisión de Seguridad, no un cambio de código. Ver D-W07. |
| **W1-04** | **Cumple por contrato** | `/filters` ya se pide por categoría y las facetas se calculan en el servidor (lo que de verdad tienen los productos). Sin cambios en la app. |
| **W1-05** | **Brecha encontrada → W1-06 (hecho en la app)** | La web usa **límites de cantidad por producto** que define WordPress (`ipr_disponibilidad`: `min_compra`, `max_compra`, estado «asesor») y avisa «Máximo N unidades por producto. Para más, habla con un asesor» con WhatsApp. La app usa un tope global de 99 y solo tiene `purchasable`. |

**W1-06 — Límites de cantidad por producto y variación: hecho en la app y el BFF simulado; pendiente de backend real.** Contrato ampliado (campos **opcionales**): `minQuantity`/`maxQuantity` (1–99) en `ProductSummary` (también en las líneas de `/cart/validate`) y en `ProductVariant`. En la app (`QuantityRange`): el selector de la ficha y del carrito respetan el rango (se recorta al añadir, sumar, cambiar, restaurar y **al revalidar**, porque el carrito vive días en el teléfono), la variación elegida aporta sus propios límites, el rango se guarda en el carrito local (los carritos anteriores se leen con 1–99) y al llegar al tope aparece «Máximo N unidades por producto. Para más, habla con un asesor.» con WhatsApp prellenado (producto, opción y SKU), como `MaxQuantityNotice` de la web. Un rango incoherente (máximo < mínimo) se ignora. El estado «asesor» ya se cubre con `purchasable: false` y el estado de cada línea. Falta que el BFF real exponga `ipr_disponibilidad` (snippet #70 de WordPress) en esos campos; los límites del BFF demo (galón: máximo 3) son de demostración.

**Condición de salida:** un producto variable se compra de punta a punta (ficha → carrito → ticket → checkout de WooCommerce con la variación correcta); el árbol de categorías coincide con la web en orden y contenido; un enlace de la web abre la pantalla equivalente.

> **Mientras W1-01 no exista**, el BFF debe entregar los productos variables como **no comprables** («Más información» por WhatsApp) para que la app nunca arme un carrito con un padre sin variación.

### Ola 2 — Portada y campañas

| ID | Trabajo | Web de referencia | Esfuerzo | Depende de |
|---|---|---|---|---|
| **W2-01** | **Carrusel de campañas** desde el servidor: imagen móvil vertical, destino interno o externo, sin autoavance rápido y con controles. | `slides.ts`, `MainSlider.tsx` | **M** | Contrato (§6.2) |
| **W2-02** | **Cifras institucionales** por el BFF (años, sedes, referencias): cierra D-07. | `home-content.ts` | **S** | Marketing fija la fuente |
| **W2-03** | **Campañas**: abrir en navegador seguro (ruleta y raspa son de WordPress). Versión nativa solo si D-W02 lo decide. | `ipr-raspa-samsung.php`, `ipr-ruleta-midea.php` | **S** (enlace) / **L** (nativo) | D-W02, `SecureBrowser` |
| **W2-04** | Bloques de **ingeniería** y **formación** en Inicio, con los textos del servidor. | `HomeEngineering`, `HomeSupport` | **S** | W3-02 |
| **W2-05** | Pulido visual restante: botón flotante de asesoría (si AC-005 lo permite), modo oscuro (tokens de la web ya existen). | `globals.css` `.dark` | **M** | APR-03 |

#### Estado de la Ola 2 (2026-11-26)

Todo el contenido de portada llega por **`GET /config` → `home`** (campo **opcional** del contrato: `banners`, `stats`, `highlights` y el esquema `HomeTarget`); la app no fija textos ni cifras (D-07).

| ID | Estado | Detalle |
|---|---|---|
| **W2-01** | **Hecho en la app y el BFF simulado** | Carrusel de campañas (imagen 4:3 como las de móvil de la web). **Sin avance automático** (WCAG 2.2.2), botones «anterior/siguiente» de 48 dp como alternativa al gesto (WCAG 2.5.1), posición «Campaña 2 de 5» anunciada y vuelta al inicio. El BFF demo sirve las 5 campañas reales de la web. |
| **W2-02** | **Hecho (cierra D-07 del lado de la app)** | Banda de cifras con las que entrega el servidor («+30 años», sedes, «+10.000», «Líder del sector HVAC-R*»). Con cifras del servidor ya no se muestran las calculadas; sin ellas, se mantienen. Falta que Marketing/BFF fijen la fuente oficial (D-W06). |
| **W2-03** | **Hecho** | Destino `web`: se abre en el navegador del sistema **solo** si la política de enlaces externos lo permite (https y el dominio de IPR). La ruleta de Midea y el raspa de Samsung siguen siendo de WordPress. Un destino con URL no https, con credenciales o de otro tipo se descarta al leer. |
| **W2-04** | **Hecho** | Bloques destacados (ingeniería y formación) con los textos del servidor; la imagen solo se pinta si su host está permitido. |
| **W2-05** | **Aplazado** | El botón flotante de WhatsApp choca con AC-005 (el botón en línea debe verse sin desplazar) y el modo oscuro espera APR-03/D-W05. |

Seguridad de los destinos: solo existen 10 tipos (`category`, `product`, `brand`, `sale`, `branches`, `engineering`, `support`, `calculator`, `web`, `whatsapp`); slugs validados con `^[a-z0-9][a-z0-9._-]{0,199}$`; la calculadora se oculta si el interruptor del servidor está apagado (D-08); un `kind` desconocido descarta el banner entero.

### Ola 3 — Marcas y ayuda técnica

| ID | Trabajo | Web de referencia | Esfuerzo | Depende de |
|---|---|---|---|---|
| **W3-01** | **Landing de marca nativa por bloques**: hero, familias, destacados, FAQ, productos. Una plantilla con acento por marca; empezar por Daikin, Samsung y Midea. | `landings-de-marca.md`, `BrandPageRenderer` | **L** | Contrato (§6.3), D-W04 |
| **W3-02** | **Contacto comercial** (directorio por ciudad y área) y **ingeniería por especialidad** con WhatsApp propio. | `contacto-data.ts`, `engineering-team-data.ts` | **M** | Contrato (§6.4) |
| **W3-03** | **Mapa de sedes** (Colombia) con las sedes de `/stores`; «Cómo llegar» ya existe. | `ColombiaSedesMap.tsx` | **M** | — |
| **W3-04** | **Calculadora BTU**: usar la fórmula de `BtuCalculator.tsx` como candidata para que Ingeniería **valide** y cierre D-08; paridad de campos (medidas, ocupantes, equipos, clima). | `features/calculadora` | **S** | D-08 (validación humana) |

#### Estado de la Ola 3 (2026-11-26)

| ID | Estado | Detalle |
|---|---|---|
| **W3-01** | **Hecho en la app y el BFF simulado** | Landing de marca por bloques con una **plantilla única** (D-W04): portada con el color de la marca, texto, destacados, preguntas frecuentes (acordeón) y llamado a la acción, arriba de los productos. Contrato nuevo `GET /brands/{slug}` (404 = marca sin contenido; la app muestra solo sus productos). Texto plano (sin HTML), destinos solo los de `HomeTarget`, y el color de marca **solo si el texto blanco se lee sobre él** (contraste ≥ 4,5:1): el azul de Midea (#0098D1) se descarta y se usa el de IPR. El demo sirve Daikin, Samsung y Midea con los textos reales de la web. |
| **W3-02** | **Hecho para ingeniería; el directorio comercial no se replica** | `contact.engineering.specialties` (opcional): equipo por especialidad y ciudad con WhatsApp, teléfono con extensión y correo corporativos. Cada botón mide ≥ 48 dp y dice la ciudad. **Solo canales corporativos** (AC-080-2): el servidor decide qué publica y la app valida cada canal. El directorio comercial de la web (`/contacto`) son tarjetas con foto y nombre **sin ningún canal de contacto estructurado**, y publicaría datos de personas: no se replica; las sedes ya traen teléfonos y WhatsApp. |
| **W3-03** | **Hecho** | Mapa de Colombia nativo (32 departamentos y 10 ciudades, de la geometría del DANE de la web, 31 KB como asset; sin SDK de mapas ni permisos). Los botones de ciudad son el control accesible; el mapa elige el pin más cercano al tocar (radio de 28 dp, para Medellín/Rionegro) y filtra la lista. Sin el asset, la pantalla funciona solo con su lista. |
| **W3-04** | **Verificado: la fórmula ya coincide con la web** | `calcular()` de la web (`btu-fields.tsx`) y la app dan lo mismo en 10.800 combinaciones (prueba de paridad). **Dos hallazgos para Ingeniería/D-08:** (1) el texto «¿Cómo calculamos?» de la web (230 × m³ + 476 × (ocupantes + equipos), cuatro climas) **no corresponde** a lo que la web calcula (600 BTU/m², recargo por altura, tres climas); (2) en el límite exacto de una capacidad (p. ej. 9.000,000000000001) la web, por coma flotante, sugiere la capacidad siguiente y la app, que redondea primero, la exacta. La validación oficial sigue pendiente: la calculadora permanece tras `btuCalculatorEnabled`. |

### Ola 4 — Contenido editorial (fase 2; requiere decisión de alcance)

| ID | Trabajo | Esfuerzo | Depende de |
|---|---|---|---|
| **W4-01** | **Blog**: lista y detalle con HTML saneado y render nativo seguro. | **L** | D-W03, contrato (§6.5) |
| **W4-02** | **RSE, Quiénes somos, Capacitaciones, IPR**: primero como enlaces a la web; nativo si hay uso. | **S** → **M** | D-W03 |
| **W4-03** | **Newsletter** con consentimiento explícito. | **S** | D-12 |

#### Revisión de la Ola 4 (2026-11-26) — **DECIDIDO: queda fuera del alcance (opción A)**

> **Decisión (2026-11-26):** no se hace la Ola 4 ahora. Lo editorial sigue como enlaces `web` publicados por el servidor en `/config` → `home.highlights`. D-W03 queda resuelta como «fuera»; D-W08..D-W10 quedan abiertas solo para una eventual revisión futura.

**Qué hay en la web hoy (medido el 2026-11-26):** 23 artículos de blog, unas 10 capacitaciones, unas 6 notas de RSE y páginas estáticas largas (Quiénes somos, RSE con ODS y alianzas). Todo el contenido dinámico son **entradas de WordPress** (`wp/v2/posts` por categoría) que la web normaliza con bastante lógica propia.

| Pieza | Hallazgo | Consecuencia para la app |
|---|---|---|
| **Blog (W4-01)** | La web sanea el HTML (`sanitizeWpHtml`) y **reescribe los enlaces del backend** al dominio público (`rewriteBackendLinks`). La app ya tiene saneador y renderizador seguro de HTML (RF-027, ficha de producto), así que el costo de pintar un artículo es bajo. | BFF: `GET /content/posts` y `/content/posts/{slug}` con el HTML ya saneado. App: lista y detalle reutilizando el renderizador de la ficha. Esfuerzo **L** (BFF M + app M). Valor bajo-medio: el SEO del blog es de la web. |
| **Capacitaciones (W4-02)** | **Frágil:** WordPress no tiene campos de evento. La web saca la **fecha del título** («… – 10 Noviembre 2026») y el **enlace de inscripción de un párrafo del cuerpo** con expresiones regulares; sin fecha, la capacitación se considera vigente. | No conviene copiar esa lógica a un BFF nuevo. Mejor **corregir en origen** (campos de fecha y de enlace de inscripción en WordPress) o seguir enlazando a la web. RF-083 (inscripción en la app) está en *Won't*. |
| **Quiénes somos, RSE, IPR** | Contenido **editorial estático** (la RSE son ~300 líneas de datos). | Pueden expresarse con los **bloques de la landing de marca (W3-01)**: portada, texto, destacados, preguntas, botón. Es **una pantalla genérica «Acerca de IPR»** sin renderizar HTML. Esfuerzo **S** en la app. |
| **Newsletter (W4-03)** | La web **no tiene plataforma de correo**: cada alta (nombre + correo + consentimiento) se **reenvía por SMTP a un buzón** de Mercadeo; no hay registro propio, baja ni retención definidos. | Replicarlo en la app **multiplicaría la captura de datos personales sin sistema de registro** (Ley 1581). **Bloqueado** hasta elegir plataforma y cerrar D-12. |

**Ya está resuelto sin código nuevo:** desde la Ola 2, el servidor puede publicar bloques destacados con destino `web` (p. ej. Capacitaciones, RSE, Blog) en `/config` → `home.highlights`. Se abren en el navegador del sistema solo si el host es el de IPR (SC-036).

**Opciones**

| Opción | Qué incluye | Esfuerzo | Riesgo |
|---|---|---|---|
| **A. Dejar la Ola 4 fuera** | Nada nuevo; lo editorial sigue como enlaces desde Inicio. | 0 | Ninguno; la app no cubre lo editorial. |
| **B. «Acerca de IPR» (recomendada)** | Pantalla que reutiliza los bloques de W3-01 para Quiénes somos, RSE y un resumen de Capacitaciones, más enlaces a la web (blog, capacitaciones). Contrato: `GET /pages/{slug}` con la misma forma de `BrandLanding`. | **S** app + **S** BFF | Bajo: sin HTML, sin datos personales. |
| **C. Blog nativo** | Lista y detalle con el HTML saneado. | **L** | Medio: HTML de editores (iframes, shortcodes), mantenimiento paralelo a la web. Solo si hay demanda medida. |
| **D. Newsletter** | Formulario con consentimiento. | **S** | **Alto** hasta que D-12 y la plataforma estén resueltos. |

**Recomendación:** B si Marketing quiere presencia editorial en la app; C solo con evidencia de uso (se mide con los toques en los enlaces de Inicio); D bloqueada; capacitaciones, arreglar el origen de los datos antes de cualquier versión nativa.

---

## 6. Cambios de contrato en el BFF (PROPUESTA; todos `x-status: proposed`)

| # | Endpoint | Cambio | Ola |
|---|---|---|---|
| 6.1 | `GET /products/{slug}`, `GET /products`, `GET /search`, `POST /cart/validate`, `POST /checkout` | `variants[]` y ejes de atributos; `hasVariants` y `priceFrom` en las tarjetas; líneas con `variationId`, `productId`, `attributes`; SKU de variación resuelve al padre. Mientras tanto, `purchasable: false` para variables. | 1 |
| 6.1b | `GET /categories` | Orden jerárquico fijo y ocultar categorías vacías, como `menu-tree.ts`. | 1 |
| 6.2 | `GET /config` o `GET /home` (nuevo) | `banners[]` (imagen de escritorio y móvil, `alt`, destino tipado) y `stats[]` institucionales. | 2 |
| 6.3 | `GET /brands/{slug}` | Bloques de landing (hero, familias, FAQ, destacados). | 3 |
| 6.4 | `GET /contact/directory`, `GET /contact/engineering` (nuevos) | Directorio comercial y equipo por especialidad. | 3 |
| 6.5 | `GET /content/posts`, `GET /content/pages/{slug}` (nuevos) | Entradas saneadas del lado del servidor. | 4 |
| 6.6 | Enlaces profundos | Tabla de equivalencias URL web ↔ ruta de la app (W1-03). | 1 |

Los cambios viven en el repositorio `ipr-frontend` y en WordPress (C1: conformidad del responsable técnico y PR revisado).

---

## 7. Decisiones que necesita (PENDIENTE)

| ID | Decisión | Quién | Opciones | Recomendación |
|---|---|---|---|---|
| **D-W01** | ¿Productos variables en el MVP? | Gerencia + Marketing | Antes del lanzamiento / después con fallback «Más información» | **Después**, con el fallback de §5, mientras haya un solo grupo convertido. Si Marketing convierte más grupos, sube a antes del lanzamiento. |
| **D-W02** | Campañas: ¿web o nativo? | Marketing | Navegador seguro / pantallas nativas | **Navegador seguro** (la mecánica es de WordPress). |
| **D-W03** | ¿Contenido editorial dentro de la app? | Gerencia | Fuera / enlaces a la web / nativo | **Enlaces a la web** primero; nativo según uso. |
| **D-W04** | ¿Cuántas landings de marca y con qué plantilla? | Marketing | 3 / 12 / todas | **Plantilla única + 3 marcas** (Daikin, Samsung, Midea). |
| **D-W05** | Modo oscuro | Marketing | Sí / no | Ya aplazado en APR-03; decidir con W2-05. |
| **D-W06** | Fuente oficial de cifras institucionales (D-07) | Marketing | `/config` / panel de WordPress | **`/config`**, mantenido por Marketing. |

| **D-W07** | **Enlaces profundos de la web a la app** (amplía CR-001): ¿se permiten `/producto/{slug}`, `/categoria-producto/{cadena}`, `/marcas/{slug}`, `/liquidaciones`, `/donde-estamos/{slug}`? | Seguridad + responsable técnico del sitio | Mantener solo `/app/pedido` / lista cerrada de rutas con slugs validados | **Lista cerrada** con validación estricta de slugs (`^[a-z0-9][a-z0-9._-]{0,199}$`), tras fijar D-14. Exige actualizar la política, su batería de pruebas hostiles, el manifiesto de Android y los `.well-known`. |

| **D-W08** | ¿«Acerca de IPR» como pantalla de bloques (opción B)? | Marketing | Sí / no | **Sí**, si se quiere lo editorial en la app: es el camino más barato y seguro. |
| **D-W09** | Capacitaciones: ¿se agregan campos de **fecha del evento** y **enlace de inscripción** en WordPress? | Marketing + equipo web | Sí / seguir leyendo del título y del cuerpo | **Sí**, antes de cualquier versión nativa o del BFF. |
| **D-W10** | Newsletter: ¿qué plataforma de correo y qué política de consentimiento y baja? | Marketing + Jurídico | Elegir plataforma (cierra D-12) / no ofrecerlo en la app | **No ofrecerlo en la app** hasta tener plataforma. |

Cualquier cambio de alcance (D-W01..W03) modifica [scope.md](../01_business/scope.md) y debe aprobarlo un humano; este plan no lo hace por sí mismo.

---

## 8. Orden de ejecución y puertas

1. **Ola 0 (ya)** — Consolidar lo hecho: commit del trabajo visual y del árbol, y decidir `config/dev.json`/`ST-127`.
2. **Gate G1** del plan vigente sigue mandando para empezar a integrar con backend real; las olas 1–4 se **diseñan** sin esperar, pero **no se integran** sin staging (C2).
3. **Ola 1** → **Ola 2** → **Ola 3**; la Ola 4 solo si D-W03 la aprueba. W2-02 y W3-04 pueden adelantarse porque son pequeñas y cierran decisiones abiertas (D-07 y D-08).
4. Cada ola cierra con las puertas QG-M01..M12 en verde, pruebas de contrato (`check_openapi_fixtures`) y revisión de accesibilidad (RNF-067..077).

---

## 9. Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| RK-W1 | El BFF no existe: toda la fase W depende de PT-05/06 y de staging. | Diseñar contra el BFF simulado y fijar el contrato primero. |
| RK-W2 | **Variables**: cambian carrito, ticket y pedidos (id de variación) y la web aún pilota un grupo. | Fallback no comprable (§5); contract tests; esperar más grupos convertidos. |
| RK-W3 | **Deriva web ↔ app** (la web cambia rápido: reestructuración del 18-nov). | Orden y reglas en el servidor, no en la app; pruebas de contrato. |
| RK-W4 | **Alcance**: 12 landings y editorial pueden desbordar al equipo. | Plantilla única; enlaces a la web primero (D-W03/W04). |
| RK-W5 | Cifras institucionales inconsistentes entre documentos y datos (sedes activas). | Una sola fuente en `/config` (D-W06). |
| RK-W6 | Mecánicas de campaña (ruleta, raspa) atadas a WordPress. | No portarlas: navegador seguro. |

---

## 10. Lo que no se replica

* **SEO**: sitemap, JSON-LD, robots, metadatos y redirecciones 301 (solo el mapeo de enlaces, W1-03).
* **Animaciones** de la web que la guía de accesibilidad prohíbe (marquesinas, destello, Ken Burns).
* **Landings con chrome propio** (`BARE_ROUTES`): en la app comparten la navegación de la aplicación.

---

## 11. Cómo se verifica

* Puertas QG-M01..M12 (formato, análisis, capas, configuración pública, fixtures, l10n, pruebas y cobertura ≥ 70 % global, ≥ 90 % en módulos críticos).
* Por cada endpoint nuevo: fixtures validados contra `contract/openapi.yaml`.
* Paridad visual: comparar con la web en vista móvil (tokens de [design_system.md](../07_ux_ui/design_system.md)).
* Accesibilidad: guías de objetivo táctil, etiquetas y contraste, y texto al 200 % en cada pantalla nueva.

# Requisitos funcionales — App móvil IPR (MVP y fase 2)

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Requisitos (Segunda entrega). No se programa nada. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para validación de IPR. IDs estables: no se renumeran; los requisitos retirados se marcan, no se borran. |
| **Documentos relacionados** | [Visión](../01_business/vision.md) · [Alcance](../01_business/scope.md) · [Stakeholders](../01_business/stakeholders.md) · [Perfiles de usuario](../01_business/user_personas.md) · [Informe de investigación](../00_discovery/informe_investigacion.md) · [Informe del código frontend](../00_discovery/informe_codigo_frontend.md) · [ADR](../03_architecture/architecture_decisions.md) · [Decisiones pendientes](../project/decisiones_pendientes.md) |

---

## 0. Cómo leer este documento

### 0.1 Decisiones ya tomadas que condicionan los requisitos (no se reabren)

| Decisión | Efecto en los requisitos |
|---|---|
| **ADR-001** (aprobada): BFF móvil `/mobile/v1` en el Next.js existente; `ipr/v1` se amplía solo donde falte. | La app no llama a `wc/v3`, `wp/v2`, ni a las rutas `/api/*` del sitio. Todo requisito de datos se entiende servido por `/mobile/v1`. |
| **ADR-002** (aprobada): MVP con compra completa, sin B2B, cotización solo por WhatsApp. | Carrito local + checkout Wompi (vía WooCommerce) en navegador seguro. Un solo perfil con precio público IVA incluido. Productos sin precio: solo "Más información" → WhatsApp. |
| **D-05 sigue ABIERTA** | **SUPUESTO S-01:** el MVP muestra disponibilidad genérica (en stock / agotado). No se muestra stock por sede ni cantidades. |

### 0.2 Convenciones

- **MoSCoW:** Must / Should / Could / Won't (por ahora).
- **¿MVP?:** `sí` = entra en el MVP · `fase 2` = candidato a fase 2 · `no` = descartado por ahora o sin evidencia suficiente.
- **Tipo:** `Hecho existente` = la web actual lo hace (evidencia en informes o código; la app lo adapta a móvil) · `Propuesto nuevo` = la web hoy NO lo tiene o requiere backend nuevo.
- **Actor:** Visitante, Cliente registrado, Asesor comercial, Administrador (ver [perfiles](../01_business/user_personas.md)).
- **Fuente / evidencia:** `INV` = [informe_investigacion.md](../00_discovery/informe_investigacion.md) (F# = fila del inventario §3) · `COD` = [informe_codigo_frontend.md](../00_discovery/informe_codigo_frontend.md) (H-## = hallazgo §5.1) · `src/...` = archivo del repositorio web `ipr-frontend` (solo lectura). Donde INV y COD difieren, prevalece COD.
- **Dependencias:** `D-xx` = [decisiones pendientes](../project/decisiones_pendientes.md) · `ADR-00x` · `S-xx` = supuesto (sección 3) · `PA-xx` = pregunta abierta nueva (sección 5) · `RF-xxx` = otro requisito.
- **DESCONOCIDO** = no hay evidencia; se indica cómo obtenerlo.
- Los criterios de aceptación se redactan después (Cuarta entrega); los IDs de este documento son la clave de trazabilidad.

### 0.3 Resumen MoSCoW por módulo

| Módulo | Must | Should | Could | Won't | Total | En MVP (sí) |
|---|---|---|---|---|---|---|
| A. Inicio | 3 | 5 | 1 | 0 | 9 | 8 |
| B. Catálogo | 5 | 4 | 1 | 0 | 10 | 9 |
| C. Búsqueda | 2 | 2 | 2 | 0 | 6 | 4 |
| D. Detalle de producto | 5 | 2 | 3 | 1 | 11 | 7 |
| E. Usuarios y autenticación | 9 | 2 | 1 | 0 | 12 | 10 |
| F. Carrito y compras | 8 | 2 | 0 | 3 | 13 | 10 |
| G. Cotizaciones | 1 | 3 | 1 | 1 | 6 | 4 |
| H. Favoritos | 0 | 0 | 3 | 1 | 4 | 0 |
| I. Sedes | 4 | 2 | 1 | 0 | 7 | 5 |
| J. Asesoría técnica | 0 | 2 | 3 | 1 | 6 | 2 |
| K. Herramientas técnicas (calculadora BTU) | 2 | 3 | 0 | 0 | 5 | 5 |
| L. Notificaciones | 0 | 0 | 3 | 1 | 4 | 0 |
| M. Atención al cliente | 4 | 1 | 3 | 2 | 10 | 5 |
| N. Perfil y cuenta | 4 | 3 | 3 | 0 | 10 | 7 |
| **Total** | **47** | **31** | **25** | **10** | **113** | **76** |

Por valor de ¿MVP?: sí = 76, fase 2 = 32, no = 5.

---

## 1. Requisitos por módulo

### A. Inicio

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-001 | La pantalla de inicio da acceso directo al buscador. | Must | sí | Visitante, Cliente registrado | INV F1, F7 | RF-020 | Hecho existente |
| RF-002 | El inicio muestra como accesos las 8 categorías raíz (Aire Acondicionado, Refrigeración, Eléctricos, Materiales y Consumibles, Herramientas, Tableros y Controles, Ventilación, Refrigerantes). | Must | sí | Visitante, Cliente registrado | INV F1, F3 | RF-010 | Hecho existente |
| RF-003 | El inicio muestra un bloque de productos "más vendidos" (nombre, SKU, precio o "Más información", estado de stock). | Should | sí | Visitante, Cliente registrado | INV F1 (8 tarjetas) | PA-05 (criterio de "más vendidos": DESCONOCIDO), RF-011 | Hecho existente |
| RF-004 | El inicio da acceso al directorio de marcas. | Should | sí | Visitante, Cliente registrado | INV F1, F4 | RF-016 | Hecho existente |
| RF-005 | El inicio muestra un botón visible de WhatsApp de asesoría. | Must | sí | Visitante, Cliente registrado | INV F1, F24; `src/lib/contact-links.ts` | RF-094 | Hecho existente |
| RF-006 | El inicio da acceso a la calculadora BTU. | Should | sí | Visitante, Cliente registrado | INV F1, F18 | RF-085, D-08 | Hecho existente |
| RF-007 | El inicio da acceso a Liquidaciones (productos con precio especial). | Should | sí | Visitante, Cliente registrado | INV F19 | RF-018 | Hecho existente |
| RF-008 | El inicio puede mostrar contenido institucional y promocional (cifras, red nacional, formación). | Could | fase 2 | Visitante | INV F1, §8 (cifras que no concuerdan) | D-07 (fuente de verdad de cifras) | Hecho existente |
| RF-009 | Si no hay conexión o el servidor falla, las pantallas de contenido muestran un mensaje claro y permiten reintentar sin perder el carrito. | Should | sí | Visitante, Cliente registrado | COD §2 (circuit breaker del servidor) | ADR-001 | Propuesto nuevo |

### B. Catálogo

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-010 | El usuario navega categorías jerárquicas (8 raíces y sus subcategorías; ~216 URLs de categoría en la web). | Must | sí | Visitante, Cliente registrado | INV F3, §3 | D-10 (calidad de categorías, p. ej. ficha mal categorizada), ADR-001 | Hecho existente |
| RF-011 | El listado de productos se pagina con carga progresiva y muestra imagen, nombre, marca, SKU, precio IVA incluido y estado de stock. | Must | sí | Visitante, Cliente registrado | INV F2; COD §3 (modelo Producto) | S-01, D-05, ADR-001. Tamaño de página en la app: DESCONOCIDO (la web usa 12) | Hecho existente |
| RF-012 | Un producto sin precio (price = 0) se lista sin cifra de precio y con indicación "Más información"; nunca se muestra "$0". | Must | sí | Visitante, Cliente registrado | INV F6; COD §1 (Cotizaciones); `src/components/product/ProductCard.tsx` | ADR-002, D-04 | Hecho existente |
| RF-013 | El usuario filtra productos por marca y por categoría. | Must | sí | Visitante, Cliente registrado | INV F4, F8; COD §4 | ADR-001 | Hecho existente |
| RF-014 | El usuario filtra por atributos técnicos disponibles (p. ej. capacidad BTU). | Should | sí | Visitante, Cliente registrado | INV F8; COD §6 (`filter_capacidad-btu`) | DESCONOCIDO: lista de atributos filtrables (revisar `src/lib/search-facets.ts` y `src/lib/filter-context.ts`), D-10 | Hecho existente |
| RF-015 | El usuario ordena los listados. | Should | sí | Visitante, Cliente registrado | INV F8 (`orderby`/`sort` en robots.txt), F19 | DESCONOCIDO: criterios de orden disponibles | Hecho existente |
| RF-016 | El usuario ve el directorio de marcas (~27) y los productos de una marca con búsqueda interna. | Should | sí | Visitante, Cliente registrado | INV F4 | ADR-001 | Hecho existente |
| RF-017 | La app puede mostrar el contenido editorial de las landings de marca y campañas. | Could | fase 2 | Visitante | INV F4; COD §4 | `docs/landings-de-marca.md` del repo web no leído (COD §0) | Hecho existente |
| RF-018 | Liquidaciones: listado de productos en oferta con precio regular y precio especial, orden y carga progresiva. | Should | sí | Visitante, Cliente registrado | INV F19; COD §3 (`onSale`, `regularPrice`) | ADR-001 | Hecho existente |
| RF-019 | Los cambios de catálogo hechos en WooCommerce (producto, precio, estado de stock) se reflejan en la app dentro de un plazo definido. Hoy la web usa revalidación por webhook y refresco del índice de búsqueda cada 5 min. | Must | sí | Administrador | COD §2, §4 (webhook `/api/revalidate`) | PA-04 (plazo aceptable: DESCONOCIDO), ADR-001 condición C4 | Hecho existente |

### C. Búsqueda

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-020 | Búsqueda por texto (nombre, marca, referencia) con resultados paginados. | Must | sí | Visitante, Cliente registrado | INV F7 | ADR-001 | Hecho existente |
| RF-021 | Sugerencias de autocompletado mientras el usuario escribe. | Should | sí | Visitante, Cliente registrado | INV F7, §4.1; COD §2 (índice en RAM, ~10.000 productos) | ADR-001. Riesgo: el índice vive en memoria de un solo proceso (ADR-001, consecuencias) | Hecho existente |
| RF-022 | Una búsqueda por SKU/referencia exacta devuelve ese producto en las primeras posiciones. | Must | sí | Visitante, Cliente registrado | INV F7 (placeholder "por marca o referencia"), §5 (por garantizar) | DESCONOCIDO: ranking y tolerancia a errores actuales; verificar en staging | Hecho existente (por verificar) |
| RF-023 | Si no hay resultados, la app muestra un mensaje y un botón de WhatsApp con el término buscado. | Should | sí | Visitante, Cliente registrado | — (no existe en la web; INV F7 no describe estado vacío) | RF-094 | Propuesto nuevo |
| RF-024 | Filtros y orden aplicables a los resultados de búsqueda. | Could | fase 2 | Visitante, Cliente registrado | INV F8 | RF-014, RF-015 | Hecho existente |
| RF-025 | Historial de búsquedas recientes, local en el dispositivo y borrable por el usuario. | Could | fase 2 | Visitante, Cliente registrado | INV §3 (no existe en la web) | D-12 (tratamiento de datos) | Propuesto nuevo |

### D. Detalle de producto

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-026 | La ficha muestra galería de imágenes (hasta 4 en la muestra revisada), nombre, marca, SKU, precio IVA incluido por unidad y estado de stock. | Must | sí | Visitante, Cliente registrado | INV F5; COD §3 (`ProductDetail`); `src/components/product/detail/ProductBuyBox.tsx` | S-01 | Hecho existente |
| RF-027 | La ficha muestra la descripción del producto (HTML de WordPress) y la descripción corta, saneadas: la app no ejecuta scripts ni contenido activo. | Must | sí | Visitante, Cliente registrado | COD §3, §5.2 (SEC-04, sanitizador por regex no auditado) | ADR-001 | Hecho existente |
| RF-028 | La ficha muestra los atributos técnicos de WooCommerce cuando existan. | Should | sí | Visitante, Cliente registrado | COD §3 (`attributes[]`); INV F5 (no se vieron estructurados en la muestra) | D-10 | Hecho existente |
| RF-029 | Para un producto con precio y disponible, la ficha ofrece selector de cantidad (1–99) y "Añadir al carrito". | Must | sí | Visitante, Cliente registrado | INV F5; `src/lib/checkout-schema.ts` (límite 1–99) | RF-049 | Hecho existente |
| RF-030 | Para un producto sin precio, la ficha reemplaza "Añadir al carrito" por "Más información". | Must | sí | Visitante, Cliente registrado | INV F6; COD §1; `ProductBuyBox.tsx` | ADR-002, RF-062 | Hecho existente |
| RF-031 | Si el producto está agotado, la ficha lo indica ("Agotado") y no permite añadirlo al carrito. La web distingue además "Disponible bajo pedido" (`onbackorder`): su tratamiento en la app queda por decidir. | Must | sí | Visitante, Cliente registrado | `ProductBuyBox.tsx` (estados `instock`/`outofstock`/`onbackorder`); COD §5.4 (punto 5) | S-01, D-05, PA-12 | Hecho existente |
| RF-032 | La ficha muestra los avisos de envío nacional ("valor según transportadora") y de garantía. | Should | sí | Visitante, Cliente registrado | INV F5, §7; `ProductBuyBox.tsx` | Texto de garantía vigente: DESCONOCIDO, validar con Jurídico (D-12) | Hecho existente |
| RF-033 | El usuario puede compartir el enlace de un producto. | Could | fase 2 | Visitante, Cliente registrado | — | RF-036 | Propuesto nuevo |
| RF-034 | La ficha muestra productos relacionados o compatibilidades. | Could | fase 2 | Visitante, Cliente registrado | INV F5 (no observado en las 8 fichas de la muestra) | D-10 (datos no confirmados) | Propuesto nuevo |
| RF-035 | La ficha ofrece fichas técnicas descargables (PDF). | Won't | fase 2 | Visitante, Cliente registrado | INV F5, §4.3 (no observado) | D-10; condicionado a que existan los documentos | Propuesto nuevo |
| RF-036 | Los enlaces web de producto (`/producto/{slug}`) abren la ficha en la app (App Links / Universal Links). | Could | fase 2 | Visitante, Cliente registrado | ADR-001 §4 (App Links ya requeridos para `/pedido-confirmado`) | ADR-001, C1 | Propuesto nuevo |

### E. Usuarios y autenticación

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-037 | Catálogo, búsqueda, fichas, precio público, sedes y canales de contacto son accesibles sin iniciar sesión. | Must | sí | Visitante | INV F2, F5, F15 (páginas públicas) | — | Hecho existente |
| RF-038 | Registro con correo, nombre, apellido y contraseña de al menos 8 caracteres. | Must | sí | Visitante | INV F11; COD H-06 | ADR-001 (endpoint en `ipr/v1`) | Hecho existente |
| RF-039 | En el registro, el usuario ve y acepta los términos y la política de tratamiento de datos, y la aceptación queda registrada. | Must | sí | Visitante | INV F25, §10 (P-12); R-07 | D-12, PA-10 (si la web ya lo hace: DESCONOCIDO) | Propuesto nuevo |
| RF-040 | Inicio de sesión con usuario o correo y contraseña. | Must | sí | Visitante | INV F11; COD §1 | ADR-001 | Hecho existente |
| RF-041 | El cierre de sesión revoca en el servidor la sesión del dispositivo. | Must | sí | Cliente registrado | INV F11 (logout); COD H-01, §5.3 | ADR-001 | Hecho existente |
| RF-042 | El usuario puede recuperar su contraseña. Hoy la web envía a la página de WordPress (`lost-password`); no hay endpoint de API. El mecanismo en la app (API o navegador seguro hacia WordPress) se define en arquitectura. | Must | sí | Visitante, Cliente registrado | INV F11; `src/components/auth/LoginForm.tsx`; COD H-08 | ADR-001 §2 | Hecho existente |
| RF-043 | Iniciar sesión en la web o en otro dispositivo no cierra la sesión de la app; cada dispositivo tiene sesión independiente. | Must | sí | Cliente registrado | COD H-01; ADR-001 §2; ADR-002 (verificación) | ADR-001 (sesiones por dispositivo en `ipr/v1`) | Propuesto nuevo |
| RF-044 | La sesión usa token de acceso de vida corta y token de refresco rotativo, guardados en Keystore/Keychain; los tokens viajan solo por cabecera `Authorization` (nunca en la URL); al expirar, la app pide reautenticación sin perder el carrito. Duraciones: DESCONOCIDAS (el informe propone 15 min para el acceso). | Must | sí | Cliente registrado | COD H-02, H-03, §5.3 | ADR-001 §2 | Propuesto nuevo |
| RF-045 | Límite de intentos y bloqueo progresivo en login, registro y recuperación, con mensajes que no revelan si una cuenta existe. | Must | sí | Visitante, Cliente registrado | COD H-04, §5.3 (punto 3) | ADR-001 §2, R-02 (Cloudflare), DESCONOCIDO: reglas de Wordfence en WordPress (COD §8.5) | Propuesto nuevo |
| RF-046 | Verificación de correo (en el registro o antes de la primera compra). | Should | fase 2 | Visitante | COD H-06, §5.3 (punto 4) | PA-02 (decisión de IPR) | Propuesto nuevo |
| RF-047 | Compra como invitado (sin cuenta). Supuesto S-02: el MVP exige sesión para comprar. | Could | fase 2 | Visitante | INV §10 (pregunta 11); `src/lib/checkout-schema.ts` (el traspaso web solo exige `items`) | PA-01, D-06 | Propuesto nuevo |
| RF-048 | La app no permite iniciar sesión a usuarios con rol administrativo de WordPress (a validar). | Should | sí | Administrador | COD §5.1 H-10 (SEC-09: roles administrador permitidos en API de clientes) | PA-03 | Propuesto nuevo |

### F. Carrito y compras

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-049 | Carrito local persistente en el dispositivo: agregar, quitar y cambiar cantidad (1–99 por producto, máximo 100 líneas). | Must | sí | Visitante, Cliente registrado | INV F9; `src/lib/checkout-schema.ts` | ADR-002 | Hecho existente |
| RF-050 | Al abrir el carrito y antes del checkout, la app consulta precio vigente y disponibilidad de cada ítem, informa los cambios y no permite pagar con ítems no disponibles hasta que el usuario los ajuste o retire. | Must | sí | Cliente registrado | COD §5.4 (punto 5: la validación ocurre al checkout); INV F9 | ADR-001 (endpoint móvil de consulta por id), S-01 | Propuesto nuevo |
| RF-051 | El resumen del carrito muestra subtotal informativo (precio público IVA incluido) y avisa que impuestos, envío (el cliente lo elige en el checkout según transportadora) y total final se confirman en el checkout. | Must | sí | Visitante, Cliente registrado | INV F9, F10; COD §1 (Flete) | — | Hecho existente |
| RF-052 | Para pagar se requiere sesión iniciada. La app envía solo `{id, cantidad}` al BFF (`/mobile/v1/checkout`), obtiene una URL con ticket de un solo uso (vigencia aprox. 60 s) y la abre en el navegador seguro del sistema (Custom Tabs / ASWebAuthenticationSession o SFSafariViewController). | Must | sí | Cliente registrado | ADR-001 §4; COD §5.4; `src/app/api/checkout/route.ts` | ADR-001, ADR-002, S-02 | Hecho existente |
| RF-053 | La app no captura, procesa ni almacena datos de tarjeta ni de pago; el pago ocurre en el checkout de WooCommerce con Wompi. Medios de pago habilitados: DESCONOCIDOS. | Must | sí | Cliente registrado | COD §1 (Pasarela), §4; ADR-002 | D-02, PA-12 | Hecho existente |
| RF-054 | El checkout se prellena con correo y datos de facturación de la cuenta cuando existan; lo faltante se completa en el checkout de WooCommerce. | Should | sí | Cliente registrado | `src/lib/checkout-schema.ts`; `src/app/api/checkout/route.ts` | RF-106 | Hecho existente |
| RF-055 | Tras pagar, el usuario vuelve a la app mediante App Links / Universal Links sobre `/pedido-confirmado`; si no es posible, al cerrar el navegador la app consulta el estado del pedido. | Must | sí | Cliente registrado | ADR-001 §4; COD §5.4 (punto 4) | ADR-001 C1 y C2 (staging); DESCONOCIDO: si se puede alojar `assetlinks.json` y `apple-app-site-association` en `.well-known` (COD §8.3) | Propuesto nuevo |
| RF-056 | La pantalla de resultado muestra número y estado del pedido verificados en el servidor (no solo por parámetros de URL): pagado, pendiente, fallido o cancelado. Estados reales de WooCommerce: DESCONOCIDOS. | Must | sí | Cliente registrado | COD §3 (`AuthOrder.status`, `statusLabel`), §5.4 | D-02, PA-12 | Propuesto nuevo |
| RF-057 | El carrito se vacía solo cuando el pedido se confirma; si el pago falla o se abandona, el carrito se conserva. La app evita el doble pago (comportamiento de WooCommerce ante pedido pendiente: DESCONOCIDO). | Must | sí | Cliente registrado | COD §7 (D-02: "cómo se evita el doble pago") | D-02, PA-11 | Propuesto nuevo |
| RF-058 | Ante errores del traspaso al checkout (carrito inválido, tienda no disponible, ticket inválido), la app muestra un mensaje legible y permite reintentar. | Should | sí | Cliente registrado | `src/app/api/checkout/route.ts` (códigos de error) | RF-052 | Hecho existente |
| RF-059 | Carrito sincronizado entre dispositivos (en servidor). | Won't | fase 2 | Cliente registrado | INV §5 (falta) | ADR-001 | Propuesto nuevo |
| RF-060 | Pagar después con Addi u otros medios diferidos. Hoy Addi aparece solo como texto en un enlace de WhatsApp, no integrado. | Won't | no | Cliente registrado | INV F24 | D-02 | Hecho existente (solo texto) |
| RF-061 | Solicitud de factura electrónica o venta por volumen desde la app. La web la menciona en una FAQ sin flujo visible. | Won't | fase 2 | Cliente registrado | INV F26 | DESCONOCIDO: cómo se solicita hoy (preguntar a Dirección comercial/Finanzas) | Propuesto nuevo |

### G. Cotizaciones

> Por ADR-002 el MVP no tiene flujo de cotización propio. La "cotización" del MVP es el contacto por WhatsApp.

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-062 | "Más información" abre WhatsApp (línea nacional) con un mensaje prellenado que identifica el producto (en la web: nombre y SKU). | Must | sí | Visitante, Cliente registrado | INV F6, F24; COD §1; `ProductBuyBox.tsx` | ADR-002, D-04 | Hecho existente |
| RF-063 | Si WhatsApp no está instalado o falla, la app ofrece una alternativa (enlace web de WhatsApp o teléfono de la línea de atención). | Should | sí | Visitante, Cliente registrado | `src/lib/contact-links.ts` (línea de atención y `wa.me`) | RF-062 | Propuesto nuevo |
| RF-064 | Botón general "Cotizar por WhatsApp" (proyecto o volumen) accesible desde inicio y ayuda. | Should | sí | Visitante, Cliente registrado | INV F1, F24 | RF-094 | Hecho existente |
| RF-065 | Medición agregada de toques en "Más información" para estimar la demanda que hoy no puede comprarse en línea (riesgo comercial de ADR-002). | Should | sí | Administrador | ADR-002 (consecuencias) | PA-08 (herramienta y consentimiento: DESCONOCIDOS; la web no tiene analítica de terceros, INV §2.1), D-12, R-07 | Propuesto nuevo |
| RF-066 | Solicitud de cotización estructurada (productos, cantidades, contacto) enviada a un asesor. | Could | fase 2 | Visitante, Cliente registrado, Asesor comercial | INV F14; D-04 (opción b) | D-04, ADR-002; requiere backend nuevo | Propuesto nuevo |
| RF-067 | Estados y seguimiento de cotización dentro de la app. | Won't | fase 2 | Cliente registrado, Asesor comercial | D-04 | D-04, RF-066 | Propuesto nuevo |

### H. Favoritos

> La web no tiene favoritos (búsqueda de `favorit`/`wishlist` en `src/`: sin resultados; INV F13). Todo el módulo es **Propuesto nuevo**. ADR-002 ubica los favoritos sincronizados en fase 2.

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-068 | Marcar y desmarcar un producto como favorito, local en el dispositivo y sin sesión. | Could | fase 2 | Visitante, Cliente registrado | INV F13 | ADR-002 | Propuesto nuevo |
| RF-069 | Lista de favoritos con precio y estado de stock actualizados. | Could | fase 2 | Visitante, Cliente registrado | INV F13 | RF-068 | Propuesto nuevo |
| RF-070 | Favoritos sincronizados por cuenta entre dispositivos. | Could | fase 2 | Cliente registrado | INV F13; COD H-08 (no hay endpoints) | ADR-001, ADR-002 | Propuesto nuevo |
| RF-071 | Avisos sobre favoritos (baja de precio, disponibilidad). | Won't | no | Cliente registrado | — | D-11, D-12, RF-090 | Propuesto nuevo |

### I. Sedes

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-072 | Listado de sedes agrupado por ciudad (31 sedes en 9 ciudades según la web; Cartagena "próximamente"); las sedes próximas se distinguen y no ofrecen acciones de contacto. | Must | sí | Visitante, Cliente registrado | INV F15; COD §3 (`Sede.upcoming`) | D-07 (cifras 31/32 sedes), D-09 | Hecho existente |
| RF-073 | La ficha de sede muestra nombre, dirección, teléfonos (fijo/PBX, ventas de repuestos, ventas de aire acondicionado), WhatsApp e imagen. | Must | sí | Visitante, Cliente registrado | INV F15; COD §3 (`Sede`) | D-09 (confirmar que son canales corporativos y no personales) | Hecho existente |
| RF-074 | Desde la ficha de sede el usuario puede llamar y escribir por WhatsApp a la sede. | Must | sí | Visitante, Cliente registrado | INV F15 | RF-073 | Hecho existente |
| RF-075 | "Cómo llegar" abre la app de mapas del dispositivo buscando la dirección de la sede (la web usa búsqueda de Google Maps por texto de dirección). | Should | sí | Visitante, Cliente registrado | INV F15; `src/features/local/LocalLanding.tsx` | RF-073. Precisión por dirección textual: sin coordenadas | Hecho existente |
| RF-076 | Los datos de sedes se sirven desde una fuente consumible por el BFF y mantenible por un administrador sin recompilar (hoy están en archivos `.ts`). | Must | sí | Administrador | COD §3, §4 (última fila) | D-09, ADR-001. DESCONOCIDO: mecanismo (decisión de arquitectura) | Propuesto nuevo |
| RF-077 | Coordenadas y horarios por sede, y mapa con ubicaciones. | Should | fase 2 | Visitante, Cliente registrado | INV F15; COD §1 (el tipo `Sede` no los tiene) | D-09 (condicional: pasa a MVP solo si Operaciones entrega la hoja maestra a tiempo) | Propuesto nuevo |
| RF-078 | Sede más cercana según la ubicación del dispositivo (con permiso). | Could | fase 2 | Visitante, Cliente registrado | — | RF-077, D-12, R-07 (tratamiento de ubicación) | Propuesto nuevo |

### J. Asesoría técnica

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-079 | Contenido informativo de los servicios de ingeniería (aire acondicionado y refrigeración). | Should | sí | Visitante, Cliente registrado | INV F17 | ADR-001. DESCONOCIDO: fuente del contenido (la web lo tiene en el repositorio) | Hecho existente |
| RF-080 | El usuario contacta a ingeniería por un canal corporativo (WhatsApp de asesoría, PBX o correo), sin exponer datos personales de ingenieros individuales. | Should | sí | Visitante, Cliente registrado | INV F16, F17, F24 (la web publica nombres y celulares de ingenieros) | D-12, PA-06 (canal corporativo de ingeniería: DESCONOCIDO) | Hecho existente |
| RF-081 | Formulario de solicitud de servicio de ingeniería. | Could | fase 2 | Visitante, Cliente registrado, Asesor comercial | INV F17 (no hay formulario hoy) | PA-06 | Propuesto nuevo |
| RF-082 | Listado de capacitaciones (marca, fecha, estado "Finalizada"/próxima). | Could | fase 2 | Visitante, Cliente registrado | INV F21; COD §1 (`wp/v2`) | ADR-001 | Hecho existente |
| RF-083 | Inscripción o recordatorio de una capacitación. | Won't | no | Cliente registrado | INV F21 | DESCONOCIDO: cómo se inscribe hoy el cliente (preguntar a Marketing) | Propuesto nuevo |
| RF-084 | Lectura de los artículos del blog (23 en la web). | Could | fase 2 | Visitante | INV F22; COD §1 (`wp/v2`) | ADR-001, RF-027 (saneo de HTML) | Hecho existente |

### K. Herramientas técnicas (calculadora BTU)

> La fórmula está en COD §6 y es **solo para validación técnica**: no se publica en la app sin aprobación de Ingeniería IPR (D-08). Si D-08 no se cierra, el módulo K sale del MVP.

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-085 | La calculadora pide largo, ancho, alto, ocupantes, equipos y clima (frío/templado/cálido) y valida rangos: largo y ancho 1–15 m, alto 2–4 m, ocupantes 1–10, equipos 0–10. | Should | sí | Visitante, Cliente registrado | INV F18; COD §6 | D-08 | Hecho existente |
| RF-086 | El resultado coincide con la fórmula vigente (COD §6) y sugiere la menor capacidad comercial ≥ requerida entre 9.000, 12.000, 18.000, 24.000 y 36.000 BTU. Verificable con una tabla de casos de prueba. | Should | sí | Visitante, Cliente registrado | COD §6 | D-08 | Hecho existente |
| RF-087 | El resultado incluye el aviso de que es una estimación (texto exacto: validar con Ingeniería). | Must | sí | Visitante, Cliente registrado | INV F18 | D-08; Must condicionado a RF-085 | Hecho existente |
| RF-088 | Si el requerido supera 36.000 BTU no hay capacidad sugerida: la app lo informa y ofrece contactar a un asesor. | Must | sí | Visitante, Cliente registrado | COD §6 ("la app debe manejarlo") | D-08, RF-080; Must condicionado a RF-085 | Propuesto nuevo |
| RF-089 | El resultado enlaza al catálogo filtrado por la capacidad sugerida. | Should | sí | Visitante, Cliente registrado | INV F18 (resultado con equipos y ofertas); COD §6 (`filter_capacidad-btu`) | RF-014, D-08 | Hecho existente |

### L. Notificaciones

> La web no tiene push; no existen endpoints de dispositivos ni de push (COD H-08). Todo el módulo es **Propuesto nuevo** y queda fuera del MVP.

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-090 | Notificación push transaccional de cambio de estado de un pedido. | Could | fase 2 | Cliente registrado | INV §5; COD H-08 | D-11, D-12, ADR-001 (registro de dispositivos) | Propuesto nuevo |
| RF-091 | Registro de dispositivo y preferencias de notificación con consentimiento por categoría. | Could | fase 2 | Cliente registrado | COD H-08 | D-11, D-12 | Propuesto nuevo |
| RF-092 | Notificaciones promocionales con consentimiento previo. | Won't | no | Cliente registrado | — | D-11 (qué promociones se autorizan), D-12 | Propuesto nuevo |
| RF-093 | El permiso de notificaciones se solicita en contexto, no al abrir la app. | Could | fase 2 | Cliente registrado | — | RF-090, RF-091 | Propuesto nuevo |

### M. Atención al cliente

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-094 | Acceso a WhatsApp de atención (línea nacional) desde menú o ayuda, con mensaje prellenado. | Must | sí | Visitante, Cliente registrado | INV F24; `src/lib/contact-links.ts` | PA-07 (SLA y responsables de respuesta: DESCONOCIDOS) | Hecho existente |
| RF-095 | Pantalla de Ayuda/Contacto que agrupa los canales corporativos (WhatsApp, PQRS, teléfono de atención, correo de ventas institucional, sedes), sin datos personales de empleados. | Should | sí | Visitante, Cliente registrado | INV F16, F24; `src/lib/contact-links.ts` | D-12 | Hecho existente |
| RF-096 | Formulario PQRS: tipo (petición, queja, reclamo, sugerencia), nombre, correo, celular, pedido/factura (opcional), mensaje de hasta 1.000 caracteres; validación, control anti-spam y confirmación de envío. | Must | sí | Visitante, Cliente registrado | INV F23; `src/app/api/pqrs/route.ts` | ADR-001 (endpoint móvil equivalente) | Hecho existente |
| RF-097 | La PQRS enviada llega al buzón corporativo de PQRS (hoy por SMTP) y el límite de envíos por IP no depende de memoria de un solo proceso. | Must | sí | Asesor comercial, Administrador | INV F23; COD §2, §4 | ADR-001 (almacén compartido para rate limit) | Hecho existente |
| RF-098 | Número de radicado, estado de la PQRS y adjuntos. | Could | fase 2 | Visitante, Cliente registrado | INV §5 (falta) | RF-096 | Propuesto nuevo |
| RF-099 | Las páginas legales (términos y condiciones, política de tratamiento de datos personales y las demás publicadas) son accesibles desde la app, antes del registro y desde el menú. | Must | sí | Visitante, Cliente registrado | INV F25, §10 (P-12: PDF no leídos) | D-12, R-07. Supuesto S-05: las tiendas exigen política de privacidad (verificar) | Hecho existente |
| RF-100 | Preguntas frecuentes (envíos, garantía, facturación). | Could | fase 2 | Visitante, Cliente registrado | INV F26 (FAQ en el código) | D-12 (contenido legal) | Hecho existente |
| RF-101 | Suscripción al boletín. | Could | fase 2 | Visitante, Cliente registrado | COD §4 (`/api/newsletter`) | D-12 (consentimiento, Ley 1581) | Hecho existente |
| RF-102 | Directorio de asesores y puntos de venta por ciudad (59 contactos en la web). | Won't | no | Visitante | INV F16 (contiene nombres, correos y celulares de empleados) | D-12, RF-095 (se usan canales corporativos en su lugar) | Hecho existente |
| RF-103 | Campañas promocionales (ruleta Midea, raspa Samsung) y actividades promocionales. | Won't | fase 2 | Visitante, Cliente registrado | INV F20; COD §4, §8 (pregunta 7) | DESCONOCIDO: si entran a la app, dónde se guardan los datos y por cuánto tiempo (COD §8) | Hecho existente |

### N. Perfil y cuenta

| ID | Requisito | MoSCoW | ¿MVP? | Actor | Fuente / evidencia | Dependencias | Tipo |
|---|---|---|---|---|---|---|---|
| RF-104 | El usuario ve y edita nombre, apellido y correo. Cambiar el correo invalida el token anterior y la app reemite la sesión. | Must | sí | Cliente registrado | INV F12; COD H-02 | RF-043, RF-044 | Hecho existente |
| RF-105 | Cambio de contraseña exigiendo la contraseña actual. | Must | sí | Cliente registrado | INV F12; COD §5.2 (SEC-03 corregido) | — | Hecho existente |
| RF-106 | Gestión de una dirección de facturación y una de envío (cédula/NIT, nombre, dirección, departamento, ciudad, teléfono; solo Colombia). | Should | sí | Cliente registrado | INV F12; `src/lib/checkout-schema.ts` | Direcciones múltiples: INV §5 (falta), fuera del MVP | Hecho existente |
| RF-107 | Historial de pedidos (número, fecha, estado, total). | Must | sí | Cliente registrado | INV F12; COD §3 (`AuthOrder`) | ADR-001 | Hecho existente |
| RF-108 | Detalle de pedido: productos con cantidad y total, subtotal, método de pago. El pedido actual no trae imagen, envío, tracking ni dirección. | Should | sí | Cliente registrado | COD §3, H-08 | ADR-001 | Hecho existente |
| RF-109 | Seguimiento de envío (tracking) y dirección del pedido. | Could | fase 2 | Cliente registrado | COD §3, H-08 | DESCONOCIDO: fuente de datos de transportadora | Propuesto nuevo |
| RF-110 | Eliminación de cuenta desde la app, con confirmación e información de qué datos se conservan. | Must | sí | Cliente registrado | COD H-08, §5.3 (punto 5); INV §5 | D-12, PA-09 (retención de datos y pedidos: DESCONOCIDA). Supuesto S-05: requisito de las tiendas para apps con registro (verificar vigencia) | Propuesto nuevo |
| RF-111 | Canal para ejercer derechos del titular (consulta, rectificación, supresión) accesible desde el perfil. | Should | sí | Cliente registrado | INV §10 (pregunta 13), R-07 | D-12 (canal vigente: DESCONOCIDO) | Propuesto nuevo |
| RF-112 | Ver sesiones activas y cerrar sesión en todos los dispositivos. | Could | fase 2 | Cliente registrado | ADR-001 §2 ("revocación por dispositivo y cerrar todas") | RF-043 | Propuesto nuevo |
| RF-113 | Preferencia de tema claro/oscuro (la web ya tiene modo oscuro). | Could | fase 2 | Visitante, Cliente registrado | INV §9 | D-13 | Hecho existente |

---

## 2. Requisitos que dependen de trabajo de backend nuevo (visibilidad para planificación)

Estos requisitos del MVP **no existen hoy** en `ipr/v1` ni en el sitio; se listan porque concentran el riesgo del MVP (ADR-002, consecuencias).

| Requisito | Qué falta hoy | Fuente |
|---|---|---|
| RF-041, RF-043, RF-044, RF-112 | Sesiones por dispositivo, refresco rotativo, revocación (hoy: un token por usuario, 30 días fijos, login web cierra la app) | COD H-01, H-02 |
| RF-045 | Rate limiting en login/registro/recuperación con almacén compartido | COD H-04 |
| RF-042 | Recuperación de contraseña por API (hoy vive en WordPress) | COD H-08 |
| RF-110 | Endpoint de eliminación de cuenta | COD H-08 |
| RF-055 | App Links / Universal Links y archivos `.well-known` en el dominio | COD §5.4, §8 |
| RF-050 | Endpoint de consulta de precio y disponibilidad por id | COD §5.4 |
| RF-076 | Fuente consumible de sedes | COD §3 |
| RF-056, RF-057 | Confirmación de estado de pedido y manejo de pago abandonado/doble pago | COD §7 (D-02) |

---

## 3. Supuestos

| ID | Supuesto | Impacto si es falso | Cómo se valida |
|---|---|---|---|
| S-01 | Disponibilidad genérica (en stock / agotado) en el MVP; no hay stock por sede (D-05 abierta). La web ya tiene además "Disponible bajo pedido". | Rediseño de ficha, listados y carrito | TI/Operaciones (D-05) |
| S-02 | El MVP exige sesión para comprar (alineado con el checkout móvil con `Authorization: Bearer`, COD §5.4). La web permite iniciar el traspaso sin sesión. | Hay que soportar compra de invitado | PA-01 con Gerencia; configuración de WooCommerce (DESCONOCIDA) |
| S-03 | Todo contrato de datos de la app se expone en `/mobile/v1` (ADR-001). | Cambia el alcance de backend | Condiciones C1–C4 de ADR-001 |
| S-04 | Un solo perfil con precio público IVA incluido; ningún precio ni rol B2B llega a la app (ADR-002). | Riesgo de fuga de tarifas | Prueba de seguridad definida en ADR-002 |
| S-05 | Las tiendas de aplicaciones exigen política de privacidad y eliminación de cuenta desde la app para apps con registro. Es conocimiento general, no se verificó en esta fase. | Rechazo de la publicación | Revisar guías vigentes de Apple y Google antes de la Cuarta entrega |
| S-06 | Los datos de sedes y de contacto corporativo son publicables (ya lo son en la web); los datos personales de empleados no se replican en la app. | Incumplimiento de Ley 1581 | Jurídico (D-12) |

## 4. Riesgos que afectan a los requisitos

| ID | Riesgo | Requisitos afectados | Referencia |
|---|---|---|---|
| R-01 | Usar `/api/*` del sitio como contrato móvil | Todos los de datos | INV §6; ADR-001 |
| R-02 | Cloudflare WAF/Bot Fight bloquea tráfico de la app | RF-040, RF-045, RF-052 | INV §6; ADR-001 C3 |
| R-03 | Sesión por cookie / token único no sirve para móvil | RF-041, RF-043, RF-044 | COD H-01, H-02 |
| R-04 | Pasarela y retorno a la app (App Links) | RF-052, RF-055, RF-056, RF-057 | COD §5.4 |
| R-05 | Calidad de datos de catálogo (categorías, especificaciones, precios faltantes) | RF-010, RF-014, RF-028 | INV §6, D-10 |
| R-06 | Fuga de precios B2B | RF-011, RF-026 | ADR-002 |
| R-07 | Tratamiento de datos personales (Ley 1581) en la app | RF-025, RF-039, RF-065, RF-078, RF-110, RF-111 | INV §6; D-12 |
| R-11 (nuevo) | Pérdida de ventas por productos sin precio que dependen de WhatsApp | RF-062, RF-065 | ADR-002 |
| R-12 (nuevo) | Rendimiento del Next.js (caché y rate limit en memoria) bajo carga móvil | RF-019, RF-021, RF-097 | ADR-001 consecuencias, C4 |

## 5. Preguntas abiertas nuevas (candidatas a `decisiones_pendientes.md`)

| ID | Pregunta | Quién responde | Cómo se obtiene |
|---|---|---|---|
| PA-01 | ¿Se permite comprar como invitado en la app? ¿Está habilitada la compra de invitado en el checkout de WooCommerce? | Gerencia, equipo web | Configuración de WooCommerce en staging |
| PA-02 | ¿Se verifica el correo en el registro o antes de la primera compra? | Gerencia, equipo web | Decisión de negocio; COD H-06 |
| PA-03 | ¿Pueden usuarios con rol administrativo iniciar sesión en la app? | Equipo web | COD H-10 (SEC-09) |
| PA-04 | ¿Qué plazo máximo es aceptable para que cambios de catálogo, precio y stock se vean en la app? | Dirección comercial, TI | Reunión de requisitos no funcionales |
| PA-05 | ¿Cuál es el criterio de "más vendidos"/destacados (manual, ventas, etiqueta de WooCommerce)? | Marketing, equipo web | Revisar `src/lib/woocommerce.ts` (no leído) |
| PA-06 | ¿Existe un canal corporativo de ingeniería (WhatsApp, correo) que no sea de una persona? | Ingeniería IPR | Entrevista |
| PA-07 | ¿Quién atiende el WhatsApp y los PQRS, y en cuánto tiempo (SLA)? | Dirección comercial, Atención al cliente | Entrevista |
| PA-08 | ¿Qué herramienta de analítica usará la app, qué mide y con qué consentimiento? | Gerencia, Jurídico | D-12 |
| PA-09 | ¿Qué datos y pedidos se conservan al eliminar una cuenta y por cuánto tiempo? | Jurídico, Finanzas | D-12 |
| PA-10 | ¿La web exige hoy aceptar términos y política de datos al registrarse? ¿Qué versión rige? | Equipo web, Jurídico | Revisar `src/components/auth/` y los PDF legales |
| PA-11 | ¿Cómo trata WooCommerce un pedido pendiente tras pago fallido o abandonado y cómo evita el doble pago? | Equipo web | Staging con Wompi sandbox (D-02) |
| PA-12 | ¿Qué medios de pago de Wompi y qué estados de pedido de WooCommerce están habilitados? ¿Se usa "bajo pedido"? | Equipo web, Finanzas | Configuración del plugin de pagos |

## 6. Clasificación del contenido de este documento

| Tipo | Dónde |
|---|---|
| Hechos comprobados | Filas con tipo `Hecho existente` y su evidencia |
| Supuestos | Sección 3 |
| Requisitos propuestos | Filas con tipo `Propuesto nuevo` |
| Decisiones pendientes | Columna Dependencias (D-xx, PA-xx) y sección 5 |
| Riesgos | Sección 4 |

# Visión general de la arquitectura — App móvil IPR

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Tercera entrega: Arquitectura. **No se programa la app.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para aprobación de IPR. Las ADR de la §9 están en estado **Propuesta**. |
| **Documento hermano** | [`flutter_app_architecture.md`](flutter_app_architecture.md) (arquitectura detallada de la app) |
| **Decisiones vigentes (no se reabren)** | [ADR-001 y ADR-002](architecture_decisions.md), ambas **Aprobadas** |
| **En paralelo** | El diseño de los contratos `/mobile/v1` y de la autenticación del lado servidor está **en elaboración** en `docs/05_api/` (otro arquitecto). Este documento **no** define endpoints ni el diseño del servidor: solo lo que la app **necesita** de la API (§7). |

**Convención de clasificación** (se usa en todas las tablas):
**HECHO** = verificado en documentos de discovery o en el código de `ipr-frontend`, con ruta · **SUPUESTO** = se asume para avanzar, con forma de validarlo · **PROPUESTA** = recomendación de este documento, requiere aprobación · **PENDIENTE** = decisión humana abierta (D-xx, DN-xx, PA-xx, o nuevas DA-xx de este documento) · **RIESGO** · **DESCONOCIDO** = sin evidencia; se indica cómo obtenerla.

Abreviaturas de fuentes: `COD` = `docs/00_discovery/informe_codigo_frontend.md` (prevalece sobre `INV`) · `INV` = `docs/00_discovery/informe_investigacion.md` · `WCA` = `docs/00_discovery/analisis_capa_woocommerce.md` · `ADR` = `docs/03_architecture/architecture_decisions.md` · `DP` = `docs/project/decisiones_pendientes.md` · `RF` / `RNF` = `docs/02_requirements/functional_requirements.md` / `non_functional_requirements.md` · `FE:` = archivo del repositorio `C:\Users\empr16\ipr-frontend` (solo lectura).

---

## 1. Resumen ejecutivo

1. **La app es un cliente de presentación**, no un motor comercial. Precio final, impuestos, envío, stock y autorización de compra los decide siempre el servidor (WooCommerce detrás del BFF). La app muestra, guarda un carrito local y orquesta el traspaso al checkout. (HECHO: `FE:src/app/api/checkout/route.ts` solo envía `{id, quantity}`; COD §1 "Precios".)
2. **Un único punto de integración:** la app solo habla con el BFF `/mobile/v1` (ADR-001). No llama a `wc/v3`, `wp/v2`, `ipr/v1` directo ni a `/api/*` del sitio.
3. **El pago ocurre fuera de la app**, en el checkout de WooCommerce con Wompi abierto en el navegador seguro del sistema (ADR-001 §4, ADR-002). La app **no** maneja datos de tarjeta.
4. **Hallazgo nuevo que cambia el diseño del retorno del pago (HECHO):** WordPress solo redirige a `/pedido-confirmado?order=…&status=…` cuando el pedido **no** está `failed`, `cancelled` ni `pending` (`FE:wp-snippets/ipr-cart-handoff.php` L462-466). En pagos fallidos, pendientes o abandonados **no hay redirección**, así que el App Link / Universal Link **no puede ser el mecanismo principal**. Se propone (ADR-008) que la **verificación del resultado en el servidor al volver a la app** sea el mecanismo primario y el enlace verificado un acelerador.
5. **Arquitectura proporcional:** Feature-First con capas `presentation / domain / data`, pero con **dominio ligero** (casos de uso solo donde hay reglas reales: carrito, checkout, sesión, calculadora BTU). Sin base de datos SQL, sin *pinning*, sin push en el MVP; cada exclusión está justificada y es reversible (§9, ADR-007, ADR-012).
6. **Stack propuesto (versiones verificadas en pub.dev el 2026-11-18):** Flutter 3.50 / Dart 3.14, Riverpod 3.5, go_router 18.1, Dio 5.11, Freezed 4.0 + json_serializable 6.15, flutter_secure_storage 11.2, hive_ce 2.23 (caché y carrito). Detalle y licencias en `flutter_app_architecture.md` §17.

---

## 2. Contexto del sistema

### 2.1 Componentes

| Componente | Responsabilidad | Quién lo opera | Estado | Evidencia |
|---|---|---|---|---|
| **App móvil IPR** (Flutter, Android/iOS) | Presentar catálogo, búsqueda, ficha, sedes, calculadora BTU, contacto; cuenta del cliente; carrito local; iniciar checkout y mostrar el resultado verificado. | Equipo móvil (por definir, D-15) | **Por crear** | ADR-002; RF |
| **BFF `/mobile/v1`** (rutas nuevas dentro del Next.js existente) | Contrato móvil versionado; DTO por lista blanca; validación; errores tipados; caché; rate limit; emisión del ticket de checkout; proxy de autenticación hacia `ipr/v1`. | Equipo web | **Por crear** (contrato **en elaboración** en `docs/05_api/`) | ADR-001; WCA §3 |
| **Capa de datos Next.js** (`lib/woocommerce.ts`, `lib/wc/*`) | Acceso a WooCommerce con timeout, reintentos, *circuit breaker*, concurrencia 4, SWR en memoria, índice de búsqueda en RAM. | Equipo web | **Existe, se reutiliza** | WCA §1, §5 |
| **WordPress + WooCommerce** (`wc/v3`, `wp/v2`, `ipr/v1`) | Fuente de verdad de catálogo, clientes, pedidos, precios, stock; checkout nativo; identidad (`ipr/v1`). | Equipo web / hosting Plesk | **Existe; `ipr/v1` se amplía** (sesiones por dispositivo, eliminar cuenta, etc.) | COD §2, §5.3; ADR-001 §2 |
| **Wompi** | Pasarela de pago dentro del checkout de WooCommerce. | Proveedor | **Existe** | COD §1 |
| **Cloudflare** | CDN/WAF delante del sitio, del BFF y de WordPress. | Equipo web | **Existe**; faltan reglas para la app (C3) | INV §2.1, R-02; ADR-001 C3 |
| **Navegador seguro del sistema** (Custom Tabs / SFSafariViewController o ASWebAuthenticationSession) | Ejecuta el checkout web y el pago. | Sistema operativo | Existe en el SO | ADR-001 §4 |
| **WhatsApp / teléfono / mapas** | Canales de "Más información", contacto y "Cómo llegar". | Terceros / SO | Existe | RF-062, RF-074, RF-075 |
| **Proveedor de reporte de fallos** | Crashes y errores no fatales sin PII. | Por elegir | **PENDIENTE DN-02** | RNF-097 |

### 2.2 Flujos principales (descripción textual; el diagramador generará los diagramas)

| Flujo | Recorrido | Autoridad de la decisión |
|---|---|---|
| **Lectura de catálogo** | App → Cloudflare → BFF `/mobile/v1` → (caché SWR / índice) → `wc/v3`. La app guarda en caché local solo respuestas públicas. | Servidor (precio, stock, visibilidad). |
| **Autenticación** | App → BFF → `ipr/v1` (sesión por dispositivo, *access* corto + *refresh* rotativo, PENDIENTE DN-04). Tokens en Keychain/Keystore. | Servidor (credenciales, emisión, revocación). |
| **Checkout** | App revalida carrito con el BFF → solicita ticket (BFF ↔ WordPress con `X-IPR-Secret`, solo servidor) → abre URL en navegador seguro → WooCommerce + Wompi → (si el pedido queda pagado/en proceso) 302 a `/pedido-confirmado` → App Link/Universal Link **o** cierre del navegador → la app consulta el resultado al BFF. | Servidor (precio, impuestos, envío, stock, cobro, estado del pedido). |
| **Contacto** | App → `wa.me`/`tel:`/mapas del SO. PQRS → BFF → buzón corporativo. | — |

### 2.3 Fronteras de confianza

| Frontera | Qué la cruza | Regla |
|---|---|---|
| Dispositivo ↔ Internet | Todas las llamadas de la app | Solo HTTPS (RNF-037); el dispositivo se considera **no confiable**: cualquier dato de la app puede ser manipulado. |
| App ↔ BFF | Token de acceso por cabecera `Authorization` (nunca en URL, RNF-041) | El BFF valida todo (RNF-044); la app nunca envía precios ni totales que el servidor deba creer. |
| BFF ↔ WordPress | Claves de WooCommerce, `X-IPR-Secret` | **Nunca** salen del servidor (RNF-036; COD §0). |
| Navegador seguro ↔ App | URL de checkout (ticket de un solo uso, 60 s) y URL de retorno | Los parámetros del enlace de retorno **no prueban el pago** (RNF-045e). |

---

## 3. Principios de arquitectura

| # | Principio | Consecuencia concreta | Fuente |
|---|---|---|---|
| P1 | **El servidor es la autoridad comercial.** | La app no calcula precio final, impuestos, envío, descuentos ni disponibilidad; el subtotal del carrito se rotula "informativo". | COD §1; RF-051; RNF-045 |
| P2 | **Un solo contrato: `/mobile/v1`.** | Ningún cliente HTTP de la app apunta a otro host que no sea el BFF, salvo las URLs abiertas en el navegador seguro (lista cerrada) y los esquemas `tel:`/`wa.me`/mapas. | ADR-001 §3 |
| P3 | **Proporcionalidad.** | Cada capa, paquete o mecanismo debe responder a un requisito con ID. Lo que no tiene requisito MVP no se construye (push, favoritos, B2B, base SQL). | Prompt maestro; ADR-002 |
| P4 | **Fallar de forma honesta.** | "No existe" (404), "no disponible" (503) y "sin resultados" (200 vacío) son estados distintos en la app; nunca se borra un ítem del carrito por un error de red. | WCA §5.2; RNF-022, RNF-023 |
| P5 | **Nada sensible en el dispositivo salvo lo imprescindible, y cifrado.** | Solo tokens y un identificador de instalación en Keychain/Keystore; la caché persistente no contiene PII. | RNF-034, RNF-062 |
| P6 | **Sin secretos en el binario.** | La configuración por entorno solo contiene valores públicos (URL base, nombre de entorno). | RNF-036; ADR-001 |
| P7 | **Compatibilidad hacia adelante.** | La app ignora campos desconocidos y tolera enumeraciones nuevas; soporta versión mínima forzable e interruptores remotos. | RNF-085, RNF-029 |
| P8 | **Accesible y en es-CO por diseño.** | Tokens de color que cumplen contraste; textos externalizados; pruebas automáticas de guías de accesibilidad. | RNF-067 a 077, RNF-084 |
| P9 | **Observabilidad sin PII.** | Reporte de fallos y analítica detrás de interfaces propias, con depuración de PII y consentimiento. | RNF-047, RNF-097, RNF-103 |

---

## 4. Límites de responsabilidad: lo que la app NUNCA decide

| Decisión | Quién decide | Qué hace la app | Evidencia |
|---|---|---|---|
| **Precio final** (unitario, total, impuestos, descuentos, envío) | WooCommerce (vía BFF y checkout) | Muestra el precio público recibido; subtotal "informativo"; formatea en COP. Nunca envía precios al servidor. | COD §1; `FE:src/lib/checkout-schema.ts` (solo `items`) ; RF-051 |
| **Si un producto se puede comprar** (precio = 0 → "Más información") | Servidor (estado explícito de precio en el DTO, ver §7) | Oculta "Añadir al carrito" según el estado recibido. Como defensa en profundidad, también lo oculta si el precio es 0. | WCA §6 ("Productos sin precio"); RF-012, RF-030 |
| **Stock / disponibilidad** | WooCommerce | Muestra el estado recibido (en stock / agotado / bajo pedido: PENDIENTE PA-12); no muestra cantidades (WCA §4.1). | RF-031; S-01 |
| **Autorización de compra y del pedido** | BFF + WordPress | Pide sesión para iniciar checkout (S-02); el servidor valida token, carrito y ticket. | RF-052; RNF-043 |
| **Estado del pago y del pedido** | WooCommerce/Wompi | Muestra el estado **consultado al servidor**, nunca el de la URL de retorno. | RF-056; RNF-025, RNF-045 |
| **Vida y revocación de la sesión** | `ipr/v1` | Guarda y renueva tokens; si el servidor los rechaza, pide login. | RNF-039, RNF-040 |
| **Visibilidad de productos** (publicado, oculto, borrador) | BFF | Muestra lo que llega. (RIESGO SEC-07 abierto en el servidor, WCA §4.2.) | WCA §4.2 |
| **Contenido HTML seguro** | BFF (saneado en servidor) | Renderiza con un widget nativo sin JavaScript; vuelve a filtrar etiquetas como defensa en profundidad. | WCA §4.3; RF-027 |
| **Precios B2B / roles** | Fuera del MVP | La app no tiene ningún concepto de rol ni lista de precios. | ADR-002 |
| **Fórmula BTU** | Ingeniería IPR (D-08) | Implementa la fórmula **validada** como lógica local pura; si D-08 no se cierra, el módulo sale del MVP. | COD §6; RF-085–089 |

---

## 5. Qué se reutiliza y qué se crea

| Elemento | Reutiliza | Crea | Dónde | Evidencia |
|---|---|---|---|---|
| Acceso a WooCommerce, caché, índice de búsqueda | ✔ (`lib/woocommerce.ts`, `lib/wc/*`) | Variantes con error discriminado; DTO móvil | BFF (fuera de este documento) | WCA §3, §7.2 |
| Checkout con ticket + Wompi | ✔ (`handoff-ticket`, snippet de traspaso, checkout nativo) | Ruta `/mobile/v1` equivalente; consulta del resultado; archivos `.well-known` | BFF / WordPress / dominio | COD §5.4; `FE:wp-snippets/ipr-cart-handoff.php` |
| Autenticación `ipr/v1` | Parcial (login, registro, perfil, pedidos con `Bearer`) | Sesiones por dispositivo, refresh, revocación, eliminar cuenta, recuperación por API | WordPress (fuera de este documento) | COD §5.1, §5.3 |
| Reglas de negocio de la web | ✔ como **especificación**: límites del carrito (1–99, 100 líneas), fórmula BTU, mensajes de WhatsApp, formato COP | Reimplementación en Dart con pruebas | App | `FE:src/lib/checkout-schema.ts`; COD §6; `FE:src/lib/contact-links.ts` |
| Datos de sedes y contactos corporativos | Contenido (hoy `FE:src/lib/sedes-data.ts`) | Fuente consumible por el BFF (RF-076) | BFF/servidor | COD §3 |
| Identidad visual | Tokens observados (`FE:src/app/globals.css` L59-61; `FE:docs/documentacion-proyecto.md` L445) | Design tokens Flutter con ajuste de contraste | App | INV §9 |
| Código de UI web (React) | ✘ (no portable) | Toda la UI en Flutter | App | — |
| Pruebas | ✘ (la web no tiene pruebas, COD §2) | Suite completa de la app | App | RNF-089 |

---

## 6. Vista lógica de la app (resumen)

La estructura completa está en `flutter_app_architecture.md` §2–§4. En resumen:

```
lib/
├── app/        → arranque, flavors, router, tema, inyección raíz
├── core/       → infraestructura sin UI de negocio: red, sesión, almacenamiento, errores, config remota, observabilidad
├── shared/     → design system (widgets, tokens), tipos transversales (Money, AsyncView), utilidades de formato
└── features/   → authentication, home, catalog, search, product_detail, cart, checkout, orders,
                  branches, technical_tools, support, profile   (cada una: presentation / domain / data)
```

Regla de oro: `features → shared → core`; nunca al revés, y **una feature no importa el interior de otra** (se comunican por rutas y por la API pública de `core`).

---

## 7. Necesidades de la app respecto a la API (lado cliente)

> Esto **no** es el diseño de los endpoints (en elaboración en `docs/05_api/`). Son capacidades y propiedades que la app necesita para cumplir los RF/RNF. Los nombres son descriptivos, no rutas.

### 7.1 Capacidades

| # | Capacidad que la app necesita | Requisitos | Prioridad MVP | Observación |
|---|---|---|---|---|
| N-01 | Configuración remota: versión mínima soportada, interruptores (p. ej. checkout), URLs legales vigentes | RNF-029, RF-099 | Sí | Leída al arrancar y al volver a primer plano, con caché corta. |
| N-02 | Árbol de categorías | RF-002, RF-010 | Sí | Sin URLs web (WCA §3.4). |
| N-03 | Listado paginado con filtros (categoría, marca, atributos, oferta) y orden | RF-011, 013–015, 018 | Sí | Tamaños de página **fijos** acordados (WCA §5.4 punto 1). |
| N-04 | Ficha por slug | RF-026–032 | Sí | Descripción saneada en servidor. |
| N-05 | **Consulta por lote de precio y disponibilidad por id** (≤ 100 ids) | RF-050, RNF-031 | Sí | Base de la revalidación del carrito. Debe distinguir "no existe/no publicado" de "no disponible ahora". |
| N-06 | Búsqueda paginada y sugerencias | RF-020–023 | Sí | Estado explícito "índice en construcción" ≠ "sin resultados" (WCA §3.5). |
| N-07 | Marcas y productos por marca; liquidaciones | RF-016, RF-018 | Sí | — |
| N-08 | Sedes | RF-072–076 | Sí | — |
| N-09 | Sesión: registro (con versión de política aceptada), login, refresh, logout del dispositivo, perfil, cambio de contraseña, direcciones, eliminación de cuenta, recuperación de contraseña | RF-038–045, RF-104–106, RF-110 | Sí | Diseño servidor: `docs/05_api/` (en elaboración); DN-04. |
| N-10 | Pedidos: historial y detalle | RF-107, RF-108 | Sí | — |
| N-11 | **Iniciar checkout**: recibe `{id, cantidad}` + clave de idempotencia; devuelve URL de un solo uso, vencimiento y un **identificador del intento** | RF-052, RNF-024 | Sí | El identificador permite N-12. |
| N-12 | **Consultar el resultado de un intento de checkout** (pedido creado o no, número, estado) | RF-055–057, RNF-025 | Sí | **Imprescindible** porque WordPress no redirige en `failed/pending/cancelled` (§1 punto 4). Alternativa mínima: pedidos recientes del usuario. |
| N-13 | Envío de PQRS | RF-096, RF-097 | Sí | Rate limit en servidor. |
| N-14 | Registro de dispositivo para push | RF-090, RF-091 | **Fase 2** | No se implementa en MVP. |

### 7.2 Propiedades transversales del contrato que la app necesita

| # | Propiedad | Por qué (requisito) |
|---|---|---|
| T-01 | Sobre de error estable con **código máquina** (no solo mensaje) y `X-Request-Id` | Mapear errores a mensajes es-CO (RNF-027) y correlacionar (RNF-099). |
| T-02 | Semántica HTTP honesta: **404** = no existe; **503 + `Retry-After`** = no disponible; **429 + `Retry-After`**; nunca 200 vacío por fallo ascendente | WCA §5.2; RNF-022, RNF-023. |
| T-03 | Indicador de dato obsoleto (servido desde caché vieja) | RNF-022 ("datos posiblemente desactualizados"). |
| T-04 | Importes como **enteros en COP** (o decimal en texto), nunca `float`; precio con **estado explícito** (con precio / consultar) | RF-012; RNF-107. |
| T-05 | Estado de stock como enumeración extensible (`instock`, `outofstock`, `onbackorder`, desconocido) | RF-031; PA-12. |
| T-06 | Imágenes en variantes por ancho (miniatura / ficha) | RNF-009; DN-03. |
| T-07 | `Cache-Control`/`ETag` en recursos públicos | RNF-011; permite revalidación barata. |
| T-08 | Cabeceras de la app aceptadas por el WAF (versión de app, plataforma) | RNF-032; C3. |
| T-09 | Señal de versión obsoleta/obligatoria (p. ej. código de error dedicado) | RNF-029, DN-14. |
| T-10 | Ningún token en query string; tokens solo por `Authorization` | RNF-041; COD H-03. |
| T-11 | Identificador de instalación (aleatorio, sin datos de hardware) aceptado en el login para la sesión por dispositivo | RNF-039; RF-043. |

---

## 8. Mapa de riesgos arquitectónicos (vista de la app)

| ID | Riesgo | Prob. | Impacto | Mitigación en la arquitectura de la app | Dueño de la mitigación |
|---|---|---|---|---|---|
| RA-01 | **Retorno del pago no llega a la app** (sin redirección en `failed/pending/cancelled`; App/Universal Links por redirección 302 dentro de Custom Tabs/SFSafariViewController no garantizados — NO VERIFICADO) | Alta | Alto | Verificación del resultado en servidor al volver a primer plano (ADR-008); spike técnico SPK-01 por plataforma; N-11/N-12. | App + BFF |
| RA-02 | **Contrato `/mobile/v1` inestable o tardío** (en elaboración, sin OpenAPI aún) | Media | Alto | Capa `data` aislada por feature; DTO separados de entidades; pruebas de contrato con *fixtures* del OpenAPI; tolerancia a campos desconocidos. | App + BFF |
| RA-03 | **Doble pago / doble pedido** | Media | Alto | Botón de pago con bloqueo; clave de idempotencia por intento; sin reintento automático de POST; carrito se vacía solo con confirmación del servidor (RF-057). D-02/PA-11 pendientes. | App + BFF + WooCommerce |
| RA-04 | **Ticket de 60 s vence** en red lenta o con la app en segundo plano | Media | Alto | Abrir el navegador inmediatamente tras recibir la URL; un reintento automático de ticket (RNF-026). | App |
| RA-05 | **Falsos 404/vacíos del backend** borran ítems o muestran "sin resultados" | Alta (hoy) | Alto | Taxonomía de fallos tipada; el carrito nunca elimina por error de red; T-02. | App + BFF |
| RA-06 | **Cloudflare desafía a la app** (CAPTCHA/403) | Media | Alto | Error específico "bloqueado por seguridad" en el mapeo; cabeceras T-08; prueba en staging (MED-15). | BFF/Cloudflare |
| RA-07 | **Fuga de PII** en caché, logs o reportes | Media | Alto | Caché persistente solo de recursos públicos; depuración de PII en el reportero; pruebas con valores canario (RNF-047). | App |
| RA-08 | **Dependencias de terceros abandonadas** en una app de años | Media | Medio | Preferir publicadores verificados (flutter.dev, google.dev, dart.dev); envolver cada paquete detrás de una interfaz de `core`; revisión mensual (RNF-094). | App |
| RA-09 | **Sobrecarga del BFF** por patrones de la app (búsqueda en cada tecla, `perPage` variable) | Media | Alto | *Debounce* de sugerencias (300 ms propuesto) + cancelación de peticiones; tamaños de página fijos; caché local. | App |
| RA-10 | **Requisitos de plataforma** (mínimos de Flutter 3.50 y plugins pueden superar Android 8 / iOS 15) | Media | Medio | Spike SPK-02 en F2; DN-01. | App |
| RA-11 | **Contraste de marca** (verde `#5ba628` = 3,03:1 sobre blanco) | Alta | Medio | Tokens con variante oscura del verde para texto; verde original solo decorativo o con texto oscuro. | Diseño |
| RA-12 | **Calidad de datos del catálogo** (marcas heurísticas, categorías sucias, sin imagen) | Alta | Medio | Placeholders, tolerancia a nulos, ocultar secciones vacías; la corrección es del servidor (D-10). | Catálogo/BFF |

---

## 9. ADR propuestas

> Formato del registro: contexto → decisión → alternativas descartadas → consecuencias → evidencia. **Estado: Propuesta.** Se trasladan a `architecture_decisions.md` solo cuando IPR las apruebe (este documento **no** edita ese archivo).

### ADR-003 — Arquitectura Feature-First con capas y "dominio ligero"

| | |
|---|---|
| **Estado** | Propuesta |
| **Contexto** | App de comercio de tamaño medio (12 features MVP, 76 RF en MVP), de larga vida y con un contrato de API aún en elaboración. Hay reglas reales en pocos sitios (carrito, checkout, sesión, BTU) y mucha pantalla de solo lectura (sedes, legales, contacto). |
| **Decisión** | Estructura `app/ core/ shared/ features/<f>/{presentation,domain,data}`. Las entidades y la interfaz del repositorio viven en `domain`; **los casos de uso solo se crean cuando orquestan más de un repositorio o contienen una regla de negocio**; si no, el controlador de estado llama al repositorio. Reglas de dependencia verificadas en CI (`flutter_app_architecture.md` §3). |
| **Alternativas descartadas** | (a) *Layer-first* (`lib/data`, `lib/ui`…): dispersa cada funcionalidad en carpetas lejanas; peor para equipos y para borrar features. (b) Clean Architecture "completa" con un caso de uso por operación: decenas de clases sin lógica para pantallas de solo lectura; costo sin beneficio. (c) Sin capas (widgets que llaman a HTTP): imposible de probar y acoplado al contrato que aún cambia (RA-02). |
| **Consecuencias** | (+) Cambios del contrato quedan confinados a `data/` (DTO + mapeador). (+) Pruebas por capa. (−) Requiere disciplina y una verificación automática de importaciones. |
| **Evidencia** | RF §0.3 (tamaño); RNF-087, RNF-089; WCA §3 (contrato por definir); RA-02. |

### ADR-004 — Riverpod 3 para estado e inyección de dependencias (sin generador en el MVP)

| | |
|---|---|
| **Estado** | Propuesta |
| **Contexto** | Hace falta estado global (sesión, carrito, configuración remota), estado por pantalla asíncrono (listados, ficha) e inyección sustituible en pruebas (RNF-089). |
| **Decisión** | `flutter_riverpod` 3.5.0 (MIT, publicador verificado dash-overflow.net, 2026-11-06) como única solución de estado y DI. Se usan `Notifier`/`AsyncNotifier` escritos a mano; **no** se adopta `riverpod_generator` en el MVP (se reevalúa tras el primer trimestre). Sin `get_it`. |
| **Alternativas descartadas** | `flutter_bloc` (sólido, pero más ceremonia por pantalla y DI aparte); `provider` (superado por Riverpod del mismo autor); GetX (acopla navegación/estado/DI, prácticas difíciles de probar); `setState`/`ValueNotifier` solos (insuficiente para estado transversal). |
| **Consecuencias** | (+) DI y estado con el mismo mecanismo; *overrides* en pruebas. (−) Curva de aprendizaje de Riverpod 3; requiere convenciones (§5 del documento detallado). |
| **Evidencia** | pub.dev (verificado 2026-11-18): flutter_riverpod 3.5.0, 140 pts, 2.919 likes. RNF-028 (refresh único), RNF-031 (carrito). |

### ADR-005 — Navegación con go_router y manejo de deep links nativo de Flutter

| | |
|---|---|
| **Estado** | Propuesta |
| **Contexto** | Pestañas con pila propia, guardas de sesión (checkout, pedidos, perfil) y deep links verificados (`/pedido-confirmado` en MVP; `/producto/{slug}` en fase 2, RF-036). |
| **Decisión** | `go_router` 18.1.4 (BSD-3, flutter.dev) con `StatefulShellRoute` y `redirect` basado en el estado de sesión. Deep links con el **manejador por defecto de Flutter** (activo por defecto desde 3.27); **no** se añade `app_links`. |
| **Alternativas descartadas** | `app_links` (exige desactivar el manejador por defecto de Flutter; solo se justificaría si hiciera falta el flujo crudo de enlaces); Navigator 2.0 a mano (mucho código); `auto_route` (generación de código adicional sin necesidad). |
| **Consecuencias** | (+) Paquete mantenido por el equipo de Flutter. (−) Si un enlace llega con la app abierta en mitad del checkout, la ruta debe delegar en el orquestador del checkout (no navegar "a ciegas"). |
| **Evidencia** | docs.flutter.dev `set-up-app-links` y `set-up-universal-links` (actualizadas 2026-11-10): "If you use a third-party plugin to handle deep links, such as app_links, Flutter's default deeplink handler will break these plugins." |

### ADR-006 — Cliente HTTP Dio con taxonomía de fallos tipada y reintentos acotados

| | |
|---|---|
| **Estado** | Propuesta |
| **Contexto** | RNF-021 (timeouts, ≤ 2 reintentos solo en GET, `Retry-After`), RNF-022/023 (distinguir 404 de 503), RNF-028 (un solo refresh ante 401 concurrentes), RA-05. |
| **Decisión** | `dio` 5.11.1 con interceptores propios: cabeceras de app, autenticación con *refresh* de vuelo único, reintento de GET idempotentes, mapeo a una jerarquía `sealed` de fallos (`AppFailure`). Los repositorios devuelven `Result<T, AppFailure>`; las excepciones no cruzan la capa `data`. |
| **Alternativas descartadas** | `http` (habría que construir a mano interceptores, cancelación y timeouts por petición); generar el cliente desde OpenAPI (útil cuando el contrato esté estable; hoy está en elaboración y el código generado es pesado; se reevalúa). |
| **Consecuencias** | (+) Un único lugar para políticas de red. (−) Dependencia de un paquete de publicador verificado no-Google (flutter.cn); se envuelve detrás de `ApiClient` para poder sustituirlo. |
| **Evidencia** | pub.dev: dio 5.11.1 (2026-09-04, MIT, 160 pts). WCA §5.2. |

### ADR-007 — Persistencia local mínima y sin base de datos SQL

| | |
|---|---|
| **Estado** | Propuesta |
| **Contexto** | Persisten: tokens (sensible), carrito (≤ 100 líneas, sin PII), caché de catálogo visitado y sedes (DN-10), preferencias simples. No hay consultas relacionales ni búsqueda offline. |
| **Decisión** | Tokens e identificador de instalación en `flutter_secure_storage` 11.2.0 (Keychain/Keystore). Carrito y caché pública en `hive_ce` 2.23.3 (cajas separadas, con tope y expiración). Preferencias no sensibles en `shared_preferences` 2.5.6. **No** se adopta Drift/sqflite. |
| **Alternativas descartadas** | Drift/SQLite (potente pero añade esquema, migraciones y binarios nativos sin un caso de uso relacional); `dio_cache_interceptor` + store persistente (las *stores* persistentes tienen adopción muy baja: http_cache_hive_store 6 likes, http_cache_drift_store 3 likes); guardar todo en `shared_preferences` (no apto para blobs de fichas de ~150 KB). |
| **Consecuencias** | (+) Pocas piezas, sin migraciones SQL. (−) `hive_ce` es un *fork* comunitario de Hive: se encapsula tras `CacheStore`/`CartStore` para poder cambiarlo. Si en fase 2 llegan favoritos sincronizados o historial con consultas, se reevalúa Drift. |
| **Evidencia** | RNF-010, RNF-020, RNF-031, RNF-034, RNF-062; DN-10; pub.dev (verificado 2026-11-18). |

### ADR-008 — Resultado del pago verificado en servidor; App Links/Universal Links como acelerador

| | |
|---|---|
| **Estado** | Propuesta (sustituye en la práctica el "retorno por App Links" de ADR-001 §4 como mecanismo **único**; no lo contradice) |
| **Contexto** | ADR-001 §4 prevé retorno por App/Universal Links y RF-055 admite consultar el estado al cerrar el navegador. HECHO: el snippet solo redirige a `/pedido-confirmado` si el pedido no está `failed/cancelled/pending` (`FE:wp-snippets/ipr-cart-handoff.php` L462-466) y la URL de retorno solo admite `http(s)` y hosts de una lista cerrada (L121-148): no admite esquemas propios. Que una redirección 302 dentro de Custom Tabs/SFSafariViewController active el enlace verificado: **NO VERIFICADO**. `ASWebAuthenticationSession` con *callback* `https` existe solo desde **iOS 17.4** (documentación de Apple). |
| **Decisión** | 1) La app abre el checkout en el navegador seguro y queda en estado "esperando resultado". 2) Al recibir el enlace `/pedido-confirmado` **o** al volver a primer plano / cerrar el navegador, consulta al BFF el resultado del intento (N-12) y muestra **solo** lo que diga el servidor. 3) Los parámetros `order`/`status` del enlace se usan como pista, nunca como prueba. 4) El componente concreto (url_launcher `inAppBrowserView` vs. `flutter_web_auth_2` con *callback* https en iOS ≥ 17.4) se elige con el spike SPK-01. |
| **Alternativas descartadas** | Depender solo del App Link (falla en pagos no exitosos); WebView propio (prohibido por RNF-045d y RNF-052; rompe la confianza en la pasarela); esquema propio `ipr://` (WordPress lo rechaza y es secuestrable, RNF-046); SDK móvil de Wompi (cambia D-02 y el alcance PCI). |
| **Consecuencias** | (+) Funciona en todos los estados de pago y aunque el enlace falle. (−) Requiere N-11/N-12 en el BFF (**en elaboración**) y un spike en dispositivos reales. |
| **Evidencia** | COD §5.4; RF-055–057; RNF-024–026, RNF-045, RNF-046; respuestas de pub.dev y documentación de Apple/Flutter consultadas el 2026-11-18. |

### ADR-009 — Configuración por *flavors* y cero secretos en el binario

| | |
|---|---|
| **Estado** | Propuesta |
| **Contexto** | Se necesitan entornos dev/staging/prod (C2 de ADR-001) y la app no debe contener secretos (RNF-036, NL-03). |
| **Decisión** | Tres *flavors* (Android `productFlavors`, iOS *schemes*/configuraciones) con identificadores de app distintos y configuración pública por `--dart-define-from-file=config/<flavor>.json` (URL base del BFF, nombre de entorno, dominio de enlaces). No se usan `.env` empaquetados (`flutter_dotenv`) ni ofuscación de secretos (`envied`): **no hay secretos de cliente que proteger**. |
| **Alternativas descartadas** | `flutter_dotenv` (empaqueta el `.env` como *asset* legible); `envied` (ofusca, pero un secreto en el binario sigue siendo extraíble); un solo binario con selector de entorno (riesgo de apuntar a producción desde pruebas). |
| **Consecuencias** | (+) Dev/staging instalables junto a prod. (−) Archivos `.well-known` por dominio de cada entorno. |
| **Evidencia** | RNF-036, RNF-051, RNF-093; ADR-001 C2. |

### ADR-010 — Observabilidad detrás de interfaces; proveedor según DN-02

| | |
|---|---|
| **Estado** | Propuesta |
| **Contexto** | RNF-097/098 exigen reporte de fallos simbolizado y sin PII; DN-02 (proveedor y país de tratamiento) y PA-08 (analítica) siguen abiertas. |
| **Decisión** | `core/observability` define `CrashReporter` y `AnalyticsSink`. El MVP incluye **un** proveedor de fallos (Firebase Crashlytics 6.1.0 o Sentry 10.5.0, ambos verificados) elegido por Jurídico+TI; la analítica queda apagada hasta PA-08 y consentimiento. Depuración de PII obligatoria antes de enviar. |
| **Alternativas descartadas** | Llamar al SDK del proveedor desde las features (acopla y dificulta cumplir RNF-047); no tener reporte de fallos (viola NL-09). |
| **Consecuencias** | (+) Cambiar de proveedor no toca features. (−) Transferencia internacional de datos a evaluar (R-NF-09). |
| **Evidencia** | RNF-047, 061, 097, 103; NL-08, NL-09. |

### ADR-011 — Sin *certificate pinning* ni detección de root en el MVP

| | |
|---|---|
| **Estado** | Propuesta (formaliza DN-05 y RNF-054) |
| **Contexto** | El BFF está detrás de Cloudflare, que gestiona y rota los certificados de borde; un *pin* desactualizado deja **todas** las apps instaladas sin servicio hasta publicar una versión nueva. El paquete evaluado (`http_certificate_pinning` 3.0.2) tiene 125 pts y ~32 K descargas/30 días. |
| **Decisión** | MVP sin *pinning* y sin detección de root/jailbreak (MASVS L1, RNF-033). TLS ≥ 1.2, sin CA de usuario en release, sin excepciones de tráfico en claro (RNF-037). Se reevalúa con: plan de rotación con clave de respaldo, interruptor remoto (N-01) y propiedad clara del certificado. |
| **Alternativas descartadas** | *Pinning* de hoja (rompe en cada rotación); *pinning* de CA de Cloudflare (Cloudflare puede cambiar de CA). |
| **Consecuencias** | (+) Sin riesgo de apagón por rotación. (−) Menor defensa ante MITM con CA comprometida (riesgo residual aceptable para L1; aceptarlo por escrito, NL-C7). |
| **Evidencia** | RNF-038, RNF-054; DN-05; pub.dev (verificado 2026-11-18). |

### ADR-012 — Estrategia de pruebas: pirámide con pruebas de contrato y golden con Alchemist

| | |
|---|---|
| **Estado** | Propuesta |
| **Contexto** | RNF-089 (≥ 70 % global, ≥ 90 % en críticos), RNF-091 (E2E de compra), RNF-068/070/071 (accesibilidad verificable). `golden_toolkit` está **descontinuado** en pub.dev. |
| **Decisión** | Unitarias + widget (con *overrides* de Riverpod y `mocktail` 1.0.5) + golden (`alchemist` 0.15.0) + integración (`integration_test` del SDK) + E2E de compra con `patrol` 4.11.0 (interactúa con el navegador nativo; **a confirmar en SPK-01**). Pruebas de contrato del lado app con *fixtures* JSON del OpenAPI. |
| **Alternativas descartadas** | `golden_toolkit` (descontinuado); solo pruebas manuales del checkout (no repetibles por versión). |
| **Consecuencias** | (+) Cobertura alineada con RNF. (−) E2E de pago requiere staging con Wompi sandbox (C2). |
| **Evidencia** | pub.dev (verificado 2026-11-18); RNF-089–092. |

---

## 10. Decisiones que requieren aprobación humana (resumen)

La lista completa y detallada está en `flutter_app_architecture.md` §21. Las de mayor impacto:

| ID | Decisión | Recomendación | Quién |
|---|---|---|---|
| DA-01 | Aprobar ADR-003 a ADR-012 | Aprobar | Solicitante + responsable técnico |
| DA-02 | Que el BFF provea N-11 (identificador de intento + idempotencia) y N-12 (consulta del resultado) | Sí: sin esto el retorno del pago no es confiable | Arquitecto API (`docs/05_api/`) + equipo web |
| DA-03 | Alojar `assetlinks.json` y `apple-app-site-association` en `iprpartesyrepuestos.com/.well-known/` (solo ruta `/pedido-confirmado` en MVP) | Sí | Equipo web (COD §8.3) |
| DA-04 | Proveedor de reporte de fallos (DN-02) | Decidir con Jurídico | Jurídico + TI |
| DA-05 | Versiones mínimas Android/iOS (DN-01) tras el spike SPK-02 | Android 8.0 / iOS 15.0 si los plugins lo permiten | Gerencia + TI |

*Fin del documento.*

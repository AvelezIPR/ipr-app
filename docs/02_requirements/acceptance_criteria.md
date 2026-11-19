# Criterios de aceptación — App móvil IPR (MVP)

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Requisitos (Cuarta entrega). No se programa nada. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para validación de IPR |
| **Historias** | [user_stories.md](user_stories.md) (US-xxx ↔ RF-xxx) |
| **Fuente** | [Requisitos funcionales](functional_requirements.md) · [ADR](../03_architecture/architecture_decisions.md) · [Informe del código frontend](../00_discovery/informe_codigo_frontend.md) (COD) · [Decisiones pendientes](../project/decisiones_pendientes.md) |

---

## 0. Convenciones

### 0.1 Formato

Cada criterio tiene la forma:

> **AC-xxx-n** · `Tipo de prueba` · **Dado** (contexto) **cuando** (acción) **entonces** (resultado observable).

- **xxx** = número del requisito/historia (AC-052-3 es el tercer criterio de US-052 / RF-052).
- **Tipos de prueba sugeridos:** `Unitaria` (lógica pura, formateo, validadores) · `Widget` (pantalla o componente Flutter aislado) · `Integración` (app o BFF contra contrato `/mobile/v1`, con servidor simulado o staging) · `E2E` (flujo completo en dispositivo/emulador contra staging) · `Seguridad` (inspección, intercepción de tráfico, análisis estático, pruebas de abuso) · `Manual` (revisión humana: contenido, dispositivos reales, tiendas).
- Los criterios de seguridad de las historias críticas (autenticación, carrito y checkout, pedidos, eliminación de cuenta, privacidad/consentimiento) están marcados con `Seguridad` y agrupados al final de cada historia crítica. Los transversales están en la sección 3 (AC-SEC-n).
- Un criterio es **verificable** si su resultado se puede observar o medir (texto en pantalla, número de solicitudes, código de respuesta, contenido de almacenamiento, ausencia de cadenas en logs o binario).

### 0.2 Etiqueta [A VALIDAR]

Cuando el comportamiento o el umbral no está definido, el criterio se redacta de todos modos y se marca **[A VALIDAR — PA-xx / D-xx]** con la pregunta abierta que lo bloquea. Un criterio con esa etiqueta **no puede darse por aprobado** hasta cerrar la pregunta; se prueba la parte determinista y se deja pendiente el umbral o el texto. Cuando la pregunta no existe todavía en el registro, se escribe **[A VALIDAR — propuesta de PA nueva]**.

### 0.3 Entornos y datos de prueba

- Los criterios de `E2E`, `Integración` contra servidor y `Seguridad` de pago se ejecutan en **staging** (frontend + WooCommerce + **Wompi sandbox**, ADR-001 C2). No se prueban pagos en producción.
- Los criterios de contenido (sedes, textos legales, canales de contacto) usan los datos entregados por IPR; no se inventan valores.
- Cuando un criterio cita cifras (8 categorías, 31 sedes, 99 unidades, 100 líneas, 1.000 caracteres, 60 s), son las de los requisitos o del código del frontend existente (COD) y se señalan como tales.

### 0.4 Criterios que se asumen en toda pantalla de contenido remoto

Toda pantalla que cargue datos de `/mobile/v1` cumple **AC-009-1 a AC-009-5** (sin red, error de servidor, reintento, carrito intacto). Para no repetirlos, las historias solo los referencian cuando agregan un caso propio.

---

## 1. Criterios por historia

### Épica A — Inicio

#### US-001 · RF-001 · Acceso al buscador desde el inicio (Must)

- **AC-001-1** · `Widget` · **Dado** un usuario en la pantalla de inicio, con o sin sesión, **cuando** la pantalla termina de renderizar, **entonces** el acceso al buscador es visible sin desplazamiento vertical y tiene etiqueta accesible (lector de pantalla lo anuncia como búsqueda).
- **AC-001-2** · `Widget` · **Dado** el inicio visible, **cuando** el usuario toca el acceso al buscador, **entonces** se abre la pantalla de búsqueda (RF-020) con el campo de texto enfocado y el teclado visible.
- **AC-001-3** · `Integración` · **Dado** una instalación nueva sin sesión, **cuando** se abre el inicio y se toca el buscador, **entonces** no se solicita iniciar sesión (RF-037).

#### US-002 · RF-002 · Categorías raíz en el inicio (Must)

- **AC-002-1** · `Integración` · **Dado** conexión disponible, **cuando** carga el inicio, **entonces** se muestran como accesos las categorías raíz publicadas por `/mobile/v1` (a la fecha 8: Aire Acondicionado, Refrigeración, Eléctricos, Materiales y Consumibles, Herramientas, Tableros y Controles, Ventilación, Refrigerantes) y el número de accesos mostrados es igual al número de categorías raíz devueltas.
- **AC-002-2** · `Widget` · **Dado** el inicio con categorías cargadas, **cuando** el usuario toca una categoría, **entonces** navega al listado de esa categoría (RF-010) y el título de la pantalla es el nombre de la categoría tocada.
- **AC-002-3** · `Integración` · **Dado** que la carga de categorías falla, **cuando** se muestra el inicio, **entonces** se aplica AC-009-1/2 y no se muestra una cuadrícula vacía sin mensaje.
- **AC-002-4** · `Integración` · **Dado** que el administrador agrega o retira una categoría raíz en WooCommerce, **cuando** vence el plazo de refresco (PA-04) y el usuario recarga el inicio, **entonces** el número de accesos coincide con el nuevo total, sin publicar versión de la app. **[A VALIDAR — PA-04]** (plazo).

#### US-003 · RF-003 · Bloque "más vendidos" (Should)

- **AC-003-1** · `Integración` · **Dado** que `/mobile/v1` devuelve el bloque de más vendidos, **cuando** carga el inicio, **entonces** cada tarjeta muestra nombre, SKU, estado de stock y precio con formato COP IVA incluido, o "Más información" si no tiene precio. **[A VALIDAR — PA-05]** el criterio de selección y el número de productos del bloque no están definidos; la prueba solo valida que se renderiza lo que entrega el servidor.
- **AC-003-2** · `Widget` · **Dado** un producto del bloque con precio 0, **cuando** se renderiza la tarjeta, **entonces** muestra "Más información" y no contiene el texto "$0" ni "0" como precio (RF-012).
- **AC-003-3** · `Widget` · **Dado** un producto del bloque agotado, **cuando** se renderiza, **entonces** muestra "Agotado" y no ofrece acción de añadir al carrito desde la tarjeta.
- **AC-003-4** · `Integración` · **Dado** que solo falla la carga del bloque de más vendidos, **cuando** se muestra el inicio, **entonces** el resto del inicio (buscador, categorías, WhatsApp) sigue operativo y el bloque ofrece reintentar (AC-009-3).
- **AC-003-5** · `Widget` · **Dado** una tarjeta del bloque, **cuando** el usuario la toca, **entonces** abre la ficha de ese producto (RF-026).

#### US-004 · RF-004 · Acceso al directorio de marcas (Should)

- **AC-004-1** · `Widget` · **Dado** el inicio, **cuando** el usuario toca el acceso a marcas, **entonces** se abre el directorio de marcas (RF-016).
- **AC-004-2** · `Widget` · **Dado** el inicio con sesión cerrada, **cuando** se toca el acceso a marcas, **entonces** funciona sin solicitar inicio de sesión.

#### US-005 · RF-005 · Botón visible de WhatsApp de asesoría (Must)

- **AC-005-1** · `Widget` · **Dado** el inicio, **cuando** la pantalla renderiza, **entonces** el botón de WhatsApp es visible sin desplazamiento y tiene etiqueta accesible.
- **AC-005-2** · `Integración` · **Dado** un dispositivo con WhatsApp instalado, **cuando** el usuario toca el botón, **entonces** se abre WhatsApp con la línea nacional de atención de IPR y un mensaje prellenado no vacío (el de la web: "¡Hola IPR! Deseo recibir atención por WhatsApp."). **[A VALIDAR — PA-07]** número vigente y texto final; el SLA no se promete en pantalla.
- **AC-005-3** · `Integración` · **Dado** un dispositivo sin WhatsApp, **cuando** el usuario toca el botón, **entonces** se ofrece la alternativa de RF-063 (AC-063-1) y la app no se cierra ni muestra error técnico.
- **AC-005-4** · `Widget` · **Dado** un usuario sin sesión, **cuando** toca el botón, **entonces** funciona sin pedir login.

#### US-006 · RF-006 · Acceso a la calculadora BTU (Should)

- **AC-006-1** · `Widget` · **Dado** que D-08 está cerrada y el módulo K está habilitado, **cuando** se muestra el inicio, **entonces** existe un acceso visible a la calculadora que la abre al tocarlo.
- **AC-006-2** · `Manual` · **Dado** que D-08 no se ha cerrado, **cuando** se prepara la versión, **entonces** el acceso a la calculadora no aparece en el inicio. **[A VALIDAR — D-08]** (si no se valida la fórmula, el módulo K sale del MVP).

#### US-007 · RF-007 · Acceso a Liquidaciones (Should)

- **AC-007-1** · `Widget` · **Dado** el inicio, **cuando** el usuario toca el acceso a Liquidaciones, **entonces** se abre el listado de Liquidaciones (RF-018).
- **AC-007-2** · `Widget` · **Dado** un usuario sin sesión, **cuando** toca el acceso, **entonces** funciona sin pedir login.

#### US-009 · RF-009 · Sin conexión o falla del servidor (Should)

- **AC-009-1** · `Integración` · **Dado** un dispositivo sin red, **cuando** el usuario abre cualquier pantalla de contenido remoto (inicio, listado, ficha, sedes), **entonces** se muestra un mensaje que indica el problema en lenguaje no técnico (sin códigos HTTP, trazas ni nombres de servidor) y un botón "Reintentar".
- **AC-009-2** · `Integración` · **Dado** que el servidor responde con error 5xx, agota el tiempo de espera o el circuit breaker del servidor está abierto, **cuando** se carga una pantalla de contenido, **entonces** se muestra el mismo tipo de mensaje y botón de AC-009-1, y la app no se cierra.
- **AC-009-3** · `Integración` · **Dado** el mensaje de error visible, **cuando** se restablece la red y el usuario toca "Reintentar", **entonces** el contenido carga sin reiniciar la app y desaparece el mensaje.
- **AC-009-4** · `Integración` · **Dado** un carrito con N líneas con cantidades conocidas, **cuando** ocurre cualquier error de red o de servidor y luego se reintenta, **entonces** el carrito conserva exactamente las mismas N líneas y cantidades.
- **AC-009-5** · `Integración` · **Dado** un listado paginado con 2 páginas ya cargadas, **cuando** falla la carga de la tercera, **entonces** los productos ya cargados permanecen visibles y se ofrece reintentar solo esa página, sin duplicar ni perder ítems.
- **AC-009-6** · `Integración` · **Dado** un dispositivo sin red, **cuando** el usuario abre el carrito (local), **entonces** puede ver sus líneas y cantidades, y al tocar "Pagar" recibe un mensaje de que se requiere conexión sin abrir el navegador (ver AC-052-8).
- **AC-009-7** · `Integración` · **Dado** una búsqueda o un filtro que falla por red, **cuando** se muestra el error, **entonces** no se presenta el estado de "sin resultados" (error y vacío son estados distintos; ver AC-023-5).

---

### Épica B — Catálogo

#### US-010 · RF-010 · Navegación de categorías jerárquicas (Must)

- **AC-010-1** · `Integración` · **Dado** una categoría raíz con subcategorías, **cuando** el usuario la toca, **entonces** se listan sus subcategorías directas; **cuando** toca una categoría hoja, **entonces** se listan sus productos (RF-011).
- **AC-010-2** · `Widget` · **Dado** que el usuario navegó 3 niveles, **cuando** presiona atrás, **entonces** vuelve al nivel anterior conservando la posición de desplazamiento.
- **AC-010-3** · `Integración` · **Dado** una categoría sin productos, **cuando** se abre, **entonces** se muestra un mensaje de que no hay productos en la categoría (no pantalla en blanco) y un acceso a la búsqueda.
- **AC-010-4** · `Integración` · **Dado** un usuario sin sesión, **cuando** navega las categorías, **entonces** todas las solicitudes se resuelven sin cabecera `Authorization` y con éxito (RF-037).
- **AC-010-5** · `Manual` · **Dado** una muestra de categorías de staging, **cuando** se revisan, **entonces** la app muestra la jerarquía que entrega el catálogo sin reordenar ni reclasificar (la calidad de la categorización, p. ej. fichas mal clasificadas, es del catálogo). **[A VALIDAR — D-10]**.
- **AC-010-6** · `Integración` · **Dado** un fallo de carga de categorías, **cuando** se muestra el error, **entonces** se aplica AC-009-1 a AC-009-3.

#### US-011 · RF-011 · Listado paginado con carga progresiva (Must)

- **AC-011-1** · `Widget` · **Dado** un listado cargado, **cuando** se renderiza una tarjeta, **entonces** muestra imagen, nombre, marca, SKU, precio en COP con formato de miles y etiqueta de IVA incluido, y estado de stock (en stock o agotado).
- **AC-011-2** · `Integración` · **Dado** un listado con más productos que el tamaño de página, **cuando** el usuario llega al final del desplazamiento, **entonces** la app solicita la página siguiente una sola vez y añade los productos sin repetir ningún ID. **[A VALIDAR — D-05/ADR-001]** el tamaño de página en la app (la web usa 12) no está definido.
- **AC-011-3** · `Integración` · **Dado** que ya se cargó la última página, **cuando** el usuario sigue desplazando, **entonces** no se emiten más solicitudes y se indica el fin del listado.
- **AC-011-4** · `Widget` · **Dado** un producto sin imagen, **cuando** se renderiza la tarjeta, **entonces** se muestra una imagen de marcador de posición sin romper el diseño.
- **AC-011-5** · `Unitaria` · **Dado** un precio entregado por el servidor (p. ej. 1234567), **cuando** se formatea, **entonces** el texto mostrado corresponde exactamente a ese valor (misma cifra, sin redondeos ni recálculo de IVA en el cliente).
- **AC-011-6** · `Integración` · **Dado** que falla la carga de una página intermedia, **cuando** se muestra el error, **entonces** se aplica AC-009-5.
- **AC-011-7** · `Widget` · **Dado** un nombre de producto largo, **cuando** se renderiza la tarjeta, **entonces** el texto se recorta con puntos suspensivos sin desbordar la tarjeta en pantallas de 360 dp de ancho.
- **AC-011-8** · `Integración` · **Dado** un listado con una página vacía final o un ID repetido devuelto por el servidor, **cuando** se paginan los resultados, **entonces** la lista no muestra tarjetas duplicadas.

#### US-012 · RF-012 · Producto sin precio (Must)

- **AC-012-1** · `Unitaria` · **Dado** un producto con precio 0, **cuando** se calcula el texto de precio, **entonces** el resultado es el indicador "Más información" y nunca contiene "$0", "$ 0", "0,00" ni "0" como cifra.
- **AC-012-2** · `Widget` · **Dado** un producto sin precio en cualquier lista (inicio, categoría, búsqueda, marca, Liquidaciones, carrito), **cuando** se renderiza, **entonces** no se muestra cifra de precio y no se ofrece "Añadir al carrito" en la tarjeta.
- **AC-012-3** · `Widget` · **Dado** una tarjeta de producto sin precio, **cuando** el usuario la toca, **entonces** se abre su ficha con "Más información" (RF-030).
- **AC-012-4** · `Unitaria` · **Dado** un producto cuyo precio llega ausente (null) o no numérico, **cuando** se renderiza, **entonces** se trata como producto sin precio y no se muestra "$0", "NaN" ni "null". **[A VALIDAR — propuesta de PA nueva]**: ADR-002/D-04 definen solo `price = 0`; confirmar con el equipo web si otros valores son posibles.
- **AC-012-5** · `Integración` · **Dado** el listado de una categoría con 10 productos de los cuales 3 no tienen precio, **cuando** se carga, **entonces** exactamente 3 tarjetas muestran "Más información" y 7 muestran cifra (conteo verificable contra la respuesta del servidor).

#### US-013 · RF-013 · Filtros por marca y categoría (Must)

- **AC-013-1** · `Integración` · **Dado** un listado, **cuando** el usuario aplica la marca "X", **entonces** todos los productos mostrados tienen marca "X" y el contador de resultados coincide con el devuelto por el servidor.
- **AC-013-2** · `Integración` · **Dado** una marca y una categoría aplicadas a la vez, **cuando** se recarga el listado, **entonces** los productos cumplen ambas condiciones (intersección).
- **AC-013-3** · `Widget` · **Dado** uno o más filtros aplicados, **cuando** se muestra el listado, **entonces** los filtros activos son visibles y cada uno puede quitarse individualmente; **cuando** se pulsa "Limpiar filtros", **entonces** se restaura el listado sin filtros.
- **AC-013-4** · `Integración` · **Dado** una combinación de filtros sin productos, **cuando** se aplica, **entonces** se muestra un mensaje de "sin resultados" con acción de limpiar filtros.
- **AC-013-5** · `Integración` · **Dado** que falla la carga al aplicar un filtro, **cuando** se muestra el error, **entonces** se conserva el listado y los filtros previos y se aplica AC-009-7.
- **AC-013-6** · `Integración` · **Dado** un filtro aplicado, **cuando** el usuario avanza de página, **entonces** las páginas siguientes respetan el mismo filtro.

#### US-014 · RF-014 · Filtros por atributos técnicos (Should)

- **AC-014-1** · `Integración` · **Dado** una categoría con atributo filtrable "capacidad BTU", **cuando** el usuario selecciona un valor, **entonces** todos los productos mostrados tienen ese valor de atributo. **[A VALIDAR — D-10]** la lista de atributos filtrables (`search-facets`, `filter-context` de la web) no está confirmada; la prueba se limita a los atributos que entregue `/mobile/v1`.
- **AC-014-2** · `Widget` · **Dado** una categoría sin atributos filtrables, **cuando** se abre el panel de filtros, **entonces** no se muestra la sección de atributos (no aparece una sección vacía).
- **AC-014-3** · `Integración` · **Dado** un atributo y una marca aplicados juntos, **cuando** se recarga, **entonces** los resultados cumplen ambos filtros.
- **AC-014-4** · `Integración` · **Dado** las opciones de atributo mostradas, **cuando** se comparan con la respuesta del servidor, **entonces** corresponden uno a uno (la app no genera ni oculta opciones por su cuenta).

#### US-015 · RF-015 · Orden de listados (Should)

- **AC-015-1** · `Widget` · **Dado** un listado, **cuando** el usuario abre las opciones de orden, **entonces** se muestran las opciones entregadas por el servidor. **[A VALIDAR — D-10/RF-015]** los criterios de orden disponibles son DESCONOCIDOS (la web usa `orderby`/`sort`).
- **AC-015-2** · `Integración` · **Dado** un listado con filtros aplicados, **cuando** el usuario cambia el orden, **entonces** el listado se recarga desde la primera página, conserva los filtros y el orden elegido queda indicado.
- **AC-015-3** · `Integración` · **Dado** un orden elegido, **cuando** se cargan páginas siguientes, **entonces** no se reordenan los productos ya mostrados.
- **AC-015-4** · `Integración` · **Dado** un orden por precio, **cuando** el listado incluye productos sin precio, **entonces** su posición es determinista y documentada. **[A VALIDAR — propuesta de PA nueva]** (dónde se ubican los productos sin precio).

#### US-016 · RF-016 · Directorio de marcas y productos por marca (Should)

- **AC-016-1** · `Integración` · **Dado** el directorio de marcas, **cuando** carga, **entonces** se listan todas las marcas devueltas por el servidor (a la fecha ~27) y el número listado coincide con el devuelto.
- **AC-016-2** · `Widget` · **Dado** el directorio, **cuando** el usuario toca una marca, **entonces** se abre el listado de productos de esa marca con paginación (AC-011-2).
- **AC-016-3** · `Integración` · **Dado** el listado de una marca, **cuando** el usuario escribe un término en la búsqueda interna, **entonces** todos los resultados pertenecen a esa marca.
- **AC-016-4** · `Integración` · **Dado** una marca sin productos, **cuando** se abre, **entonces** se muestra mensaje de sin productos.
- **AC-016-5** · `Integración` · **Dado** un usuario sin sesión, **cuando** navega marcas, **entonces** funciona sin autenticación.

#### US-018 · RF-018 · Liquidaciones (Should)

- **AC-018-1** · `Widget` · **Dado** un producto en oferta, **cuando** se renderiza en Liquidaciones, **entonces** se muestran el precio regular y el precio especial como dos valores distintos, visualmente diferenciables.
- **AC-018-2** · `Integración` · **Dado** el listado de Liquidaciones, **cuando** se compara con la respuesta del servidor, **entonces** solo aparecen productos marcados en oferta y ninguno sin esa marca.
- **AC-018-3** · `Integración` · **Dado** más productos en oferta que el tamaño de página, **cuando** el usuario desplaza al final, **entonces** se aplica la carga progresiva de AC-011-2/3.
- **AC-018-4** · `Integración` · **Dado** un orden elegido en Liquidaciones, **cuando** se cambia, **entonces** se aplica AC-015-2.
- **AC-018-5** · `Integración` · **Dado** un producto en oferta que se añade al carrito, **cuando** se abre el carrito, **entonces** el precio vigente lo entrega el servidor (RF-050) y la app no usa el precio especial leído antes como autoridad.
- **AC-018-6** · `Integración` · **Dado** que no hay productos en oferta, **cuando** se abre Liquidaciones, **entonces** se muestra un mensaje de que no hay liquidaciones vigentes.

#### US-019 · RF-019 · Frescura de catálogo (Must)

- **AC-019-1** · `E2E` · **Dado** un producto en staging, **cuando** el administrador cambia su precio en WooCommerce, **entonces** la app muestra el nuevo precio dentro del plazo acordado. **[A VALIDAR — PA-04]** el plazo máximo aceptable es DESCONOCIDO; medir y registrar el tiempo real (web actual: revalidación por webhook y refresco del índice de búsqueda cada 5 min).
- **AC-019-2** · `E2E` · **Dado** un producto en stock, **cuando** el administrador lo marca agotado en WooCommerce, **entonces** dentro del plazo de AC-019-1 la ficha muestra "Agotado" y no permite añadirlo (RF-031). **[A VALIDAR — PA-04]**.
- **AC-019-3** · `Integración` · **Dado** que WooCommerce emite el webhook de revalidación firmado, **cuando** el BFF lo recibe, **entonces** invalida la caché de ese producto y la siguiente consulta móvil devuelve el dato nuevo; un webhook con firma inválida se rechaza y no invalida caché.
- **AC-019-4** · `Integración` · **Dado** que el webhook falla o no llega, **cuando** transcurre el plazo máximo de la caché, **entonces** el dato se actualiza igualmente (la frescura no depende exclusivamente del webhook). **[A VALIDAR — PA-04]**.
- **AC-019-5** · `E2E` · **Dado** un producto cuyo precio cambió en WooCommerce y que sigue visible en la app con el valor anterior, **cuando** el usuario lo añade y paga, **entonces** el monto del checkout es el precio vigente de WooCommerce (la frescura de la lista no afecta el cobro; ver AC-052-5).
- **AC-019-6** · `Integración` · **Dado** una carga móvil acordada en el piloto, **cuando** se mide la web actual y el BFF, **entonces** no se degrada la latencia ni la tasa de errores de la web (ADR-001 C4). **[A VALIDAR — ADR-001 C4]** perfil de tráfico y umbral.

---

### Épica C — Búsqueda

#### US-020 · RF-020 · Búsqueda por texto (Must)

- **AC-020-1** · `Integración` · **Dado** un término por nombre, marca o referencia, **cuando** el usuario envía la búsqueda, **entonces** se muestran resultados paginados relevantes y cada resultado cumple AC-011-1.
- **AC-020-2** · `Integración` · **Dado** más resultados que el tamaño de página, **cuando** se desplaza al final, **entonces** se aplica AC-011-2/3.
- **AC-020-3** · `Widget` · **Dado** un campo de búsqueda vacío o solo con espacios, **cuando** el usuario envía, **entonces** no se emite solicitud y se mantiene el foco en el campo.
- **AC-020-4** · `Seguridad` · **Dado** un término con caracteres especiales (`' " < > % & #` y tildes), **cuando** se envía, **entonces** la solicitud lo codifica, el servidor responde sin error y ningún carácter se interpreta como código o marcado en la pantalla de resultados.
- **AC-020-5** · `Integración` · **Dado** un término con y sin tildes (p. ej. "válvula" y "valvula"), **cuando** se busca, **entonces** el comportamiento de equivalencia queda documentado. **[A VALIDAR — propuesta de PA nueva]** (tolerancia a tildes y errores: DESCONOCIDA, ver RF-022).
- **AC-020-6** · `Integración` · **Dado** que la búsqueda falla por red o servidor, **cuando** se muestra el estado, **entonces** se aplica AC-009-7.
- **AC-020-7** · `Integración` · **Dado** un usuario sin sesión, **cuando** busca, **entonces** funciona sin autenticación.

#### US-021 · RF-021 · Sugerencias de autocompletado (Should)

- **AC-021-1** · `Integración` · **Dado** que el usuario escribe un término, **cuando** el servidor devuelve sugerencias, **entonces** se muestran bajo el campo mientras escribe y se actualizan con cada cambio relevante del texto. **[A VALIDAR — propuesta de PA nueva]** número mínimo de caracteres y retraso de envío (debounce).
- **AC-021-2** · `Unitaria` · **Dado** que el usuario escribe "ab" y luego "abc" y la respuesta de "ab" llega después que la de "abc", **cuando** se procesan las respuestas, **entonces** solo se muestran las sugerencias del último término (no hay resultados desordenados).
- **AC-021-3** · `Widget` · **Dado** una sugerencia visible, **cuando** el usuario la toca, **entonces** se abre su resultado (ficha o resultados de búsqueda). **[A VALIDAR — propuesta de PA nueva]** (destino al tocar la sugerencia no definido).
- **AC-021-4** · `Integración` · **Dado** que el servicio de sugerencias falla o no está disponible, **cuando** el usuario escribe y envía la búsqueda, **entonces** la búsqueda por texto sigue funcionando y no aparece un error bloqueante por las sugerencias.
- **AC-021-5** · `Integración` · **Dado** el borrado del texto, **cuando** el campo queda vacío, **entonces** desaparecen las sugerencias.

#### US-022 · RF-022 · Búsqueda por SKU / referencia exacta (Must)

- **AC-022-1** · `Integración` · **Dado** el SKU exacto de un producto existente en staging, **cuando** se busca, **entonces** ese producto aparece en la primera posición de resultados. **[A VALIDAR — RF-022]** "primeras posiciones" no está cuantificado y el ranking actual es DESCONOCIDO; el criterio propone posición 1 y se confirma al verificar en staging.
- **AC-022-2** · `Integración` · **Dado** el mismo SKU escrito en minúsculas, mayúsculas o con espacios al inicio y final, **cuando** se busca, **entonces** se obtiene el mismo resultado de AC-022-1.
- **AC-022-3** · `Integración` · **Dado** un SKU con guiones o espacios internos distintos del registrado, **cuando** se busca, **entonces** el resultado es determinista y documentado. **[A VALIDAR — propuesta de PA nueva]** (tolerancia a variaciones de formato).
- **AC-022-4** · `Manual` · **Dado** una muestra de SKUs reales entregada por IPR (cantidad a acordar), **cuando** se buscan uno a uno en staging, **entonces** el 100 % devuelve su producto en la posición definida en AC-022-1. **[A VALIDAR — RF-022]** tamaño de la muestra.
- **AC-022-5** · `Integración` · **Dado** un SKU inexistente, **cuando** se busca, **entonces** se muestra el estado vacío de RF-023.

#### US-023 · RF-023 · Sin resultados con WhatsApp (Should)

- **AC-023-1** · `Widget` · **Dado** una búsqueda sin resultados, **cuando** se muestra el estado vacío, **entonces** aparece un mensaje de que no se encontraron productos y un botón de WhatsApp.
- **AC-023-2** · `Unitaria` · **Dado** el término "válvula 1/4 & tubo #3", **cuando** se construye el enlace de WhatsApp, **entonces** el texto va codificado en URL y, al decodificarlo, contiene el término exacto buscado.
- **AC-023-3** · `Integración` · **Dado** el botón de WhatsApp en el estado vacío, **cuando** el usuario lo toca con WhatsApp instalado, **entonces** se abre la línea nacional con el mensaje prellenado que incluye el término buscado. **[A VALIDAR — propuesta de PA nueva]** texto del mensaje (no existe en la web, que no describe estado vacío).
- **AC-023-4** · `Integración` · **Dado** un dispositivo sin WhatsApp, **cuando** se toca el botón, **entonces** se aplica la alternativa de AC-063-1.
- **AC-023-5** · `Integración` · **Dado** que la búsqueda falló por red o servidor, **cuando** se muestra la pantalla, **entonces** NO se muestra "sin resultados" ni el botón de WhatsApp con el término, sino el error con "Reintentar" (AC-009-1).
- **AC-023-6** · `Widget` · **Dado** un usuario sin sesión, **cuando** llega al estado vacío, **entonces** el botón funciona sin autenticación.

---

### Épica D — Detalle de producto

#### US-026 · RF-026 · Ficha de producto (Must)

- **AC-026-1** · `Widget` · **Dado** una ficha cargada, **cuando** se renderiza, **entonces** muestra galería, nombre, marca, SKU, precio IVA incluido por unidad (con rótulo "IVA incluido") y estado de stock.
- **AC-026-2** · `Widget` · **Dado** una galería con varias imágenes (hasta 4 en la muestra revisada), **cuando** el usuario desliza horizontalmente, **entonces** navega entre todas las imágenes entregadas por el servidor y el indicador de posición refleja la imagen actual.
- **AC-026-3** · `Widget` · **Dado** un producto sin imágenes, **cuando** se abre la ficha, **entonces** se muestra un marcador de posición sin error.
- **AC-026-4** · `Widget` · **Dado** la disponibilidad del producto, **cuando** se muestra en la ficha, **entonces** solo aparece "En stock" o "Agotado"; no se muestran cantidades ni stock por sede (S-01).
- **AC-026-5** · `Unitaria` · **Dado** un precio del servidor, **cuando** se muestra en la ficha, **entonces** coincide exactamente con el valor recibido (sin cálculo de IVA ni recargo en el cliente).
- **AC-026-6** · `Integración` · **Dado** un producto eliminado o despublicado (respuesta 404), **cuando** se abre su ficha, **entonces** se muestra "Producto no disponible" con acción de volver, sin error técnico.
- **AC-026-7** · `Integración` · **Dado** un fallo de red al abrir la ficha, **cuando** se muestra el error, **entonces** se aplica AC-009-1 a AC-009-3.

#### US-027 · RF-027 · Descripción saneada (Must)

- **AC-027-1** · `Seguridad` · **Dado** una descripción cuyo HTML contiene `<script>`, atributos `onerror=`/`onclick=`, enlaces `javascript:`, `<iframe>`, `<object>` y `<form>`, **cuando** se muestra en la ficha, **entonces** ningún script se ejecuta, no se dispara ninguna solicitud derivada de esos vectores y el contenido activo no se renderiza (prueba con un corpus de payloads XSS acordado; en el hallazgo SEC-04 el saneador de la web es por expresiones regulares y no está auditado). **[A VALIDAR — SEC-04]** tamaño y fuente del corpus.
- **AC-027-2** · `Seguridad` · **Dado** el mismo corpus, **cuando** se evalúa el saneado, **entonces** el resultado no depende únicamente del saneador de la web (la app o el BFF aplican su propia defensa verificable).
- **AC-027-3** · `Widget` · **Dado** una descripción con HTML legítimo (párrafos, listas, negritas, tablas), **cuando** se muestra, **entonces** el formato básico se conserva y es legible.
- **AC-027-4** · `Seguridad` · **Dado** una descripción con imágenes o enlaces, **cuando** se muestran, **entonces** los recursos externos se cargan solo por HTTPS y los enlaces con esquemas distintos de http, https, tel y mailto no se activan.
- **AC-027-5** · `Widget` · **Dado** un producto sin descripción ni descripción corta, **cuando** se abre la ficha, **entonces** esa sección se omite sin dejar encabezados vacíos.
- **AC-027-6** · `Widget` · **Dado** una descripción corta y una larga, **cuando** se renderiza la ficha, **entonces** se muestran ambas en secciones distintas.

#### US-028 · RF-028 · Atributos técnicos (Should)

- **AC-028-1** · `Widget` · **Dado** un producto con atributos de WooCommerce, **cuando** se abre la ficha, **entonces** se listan como pares nombre-valor tal como los entrega el servidor. **[A VALIDAR — D-10]** en la muestra revisada no se vieron atributos estructurados; la cobertura real depende de la calidad del catálogo.
- **AC-028-2** · `Widget` · **Dado** un producto sin atributos, **cuando** se abre la ficha, **entonces** la sección de atributos no se muestra.
- **AC-028-3** · `Seguridad` · **Dado** un valor de atributo con marcado HTML, **cuando** se muestra, **entonces** se presenta como texto, sin interpretarlo.

#### US-029 · RF-029 · Cantidad y "Añadir al carrito" (Must)

- **AC-029-1** · `Widget` · **Dado** un producto con precio y en stock, **cuando** se abre la ficha, **entonces** se muestran el selector de cantidad con valor inicial 1 y el botón "Añadir al carrito".
- **AC-029-2** · `Unitaria` · **Dado** el selector de cantidad, **cuando** se intenta bajar de 1 o subir de 99, **entonces** el valor se mantiene en 1 y en 99 respectivamente.
- **AC-029-3** · `Unitaria` · **Dado** una cantidad escrita a mano con los valores `0`, `100`, `-1`, `1.5`, vacío y `abc`, **cuando** se confirma, **entonces** se rechaza o corrige al rango válido 1–99 con mensaje y no se añade ninguna línea con un valor inválido.
- **AC-029-4** · `Integración` · **Dado** una cantidad válida N, **cuando** el usuario pulsa "Añadir al carrito", **entonces** el carrito contiene una línea con ese producto y cantidad N, se muestra confirmación visible y el contador del carrito se actualiza.
- **AC-029-5** · `Integración` · **Dado** un producto que ya está en el carrito, **cuando** se vuelve a añadir, **entonces** no se crean líneas duplicadas del mismo producto y la cantidad final no supera 99 (se informa si se limitó). **[A VALIDAR — propuesta de PA nueva]** regla de fusión: sumar o reemplazar (no definida en RF-049).
- **AC-029-6** · `Integración` · **Dado** un carrito con 100 líneas, **cuando** se intenta añadir un producto nuevo, **entonces** no se añade y se muestra un mensaje del límite de 100 líneas.
- **AC-029-7** · `Integración` · **Dado** un visitante sin sesión, **cuando** añade al carrito, **entonces** la línea se guarda localmente sin pedir login (el login se exige solo al pagar, RF-052).
- **AC-029-8** · `Unitaria` · **Dado** una línea añadida al carrito, **cuando** se inspecciona lo que se almacena, **entonces** contiene identificador de producto y cantidad; el precio mostrado después se refresca desde el servidor (RF-050) y no se toma de lo guardado como autoridad.

#### US-030 · RF-030 · Producto sin precio: "Más información" (Must)

- **AC-030-1** · `Widget` · **Dado** una ficha de producto con precio 0, **cuando** se renderiza, **entonces** se muestra "Más información" y no se muestran el botón "Añadir al carrito" ni el selector de cantidad.
- **AC-030-2** · `Widget` · **Dado** la misma ficha, **cuando** se busca texto de precio, **entonces** no aparece "$0" ni cifra alguna.
- **AC-030-3** · `Integración` · **Dado** la ficha sin precio, **cuando** el usuario toca "Más información", **entonces** se abre WhatsApp según US-062.
- **AC-030-4** · `Integración` · **Dado** un producto que pasó de tener precio a precio 0 estando en el carrito, **cuando** se abre el carrito, **entonces** la línea se marca sin precio, no es pagable y se ofrece "Más información" (AC-050-5).
- **AC-030-5** · `Widget` · **Dado** un visitante sin sesión, **cuando** abre la ficha sin precio, **entonces** "Más información" funciona sin autenticación.

#### US-031 · RF-031 · Producto agotado (Must)

- **AC-031-1** · `Widget` · **Dado** un producto agotado, **cuando** se abre la ficha, **entonces** se muestra "Agotado" y el botón "Añadir al carrito" está ausente o deshabilitado (no responde al toque).
- **AC-031-2** · `Integración` · **Dado** un producto agotado, **cuando** se intenta añadir por cualquier camino (ficha, tarjeta de listado, repetir compra), **entonces** no se agrega ninguna línea al carrito.
- **AC-031-3** · `Integración` · **Dado** una ficha abierta de un producto que estaba en stock y se agotó antes de añadirlo, **cuando** el usuario lo añade y luego abre el carrito, **entonces** la línea aparece marcada "Agotado" y el pago queda bloqueado (AC-050-3).
- **AC-031-4** · `Integración` · **Dado** un producto en estado "Disponible bajo pedido" (`onbackorder`), **cuando** se muestra, **entonces** se aplica el tratamiento que defina IPR. **[A VALIDAR — PA-12]** (la web distingue `instock`, `outofstock` y `onbackorder`; el tratamiento en la app está por decidir). Hasta entonces no se habilita la compra de estos productos.
- **AC-031-5** · `Widget` · **Dado** un producto agotado en un listado, **cuando** se renderiza la tarjeta, **entonces** muestra "Agotado" (consistente con la ficha).

#### US-032 · RF-032 · Avisos de envío y garantía (Should)

- **AC-032-1** · `Widget` · **Dado** la ficha de un producto con precio, **cuando** se renderiza, **entonces** se muestra el aviso de envío nacional con el texto "valor según transportadora" (o el texto aprobado por IPR).
- **AC-032-2** · `Manual` · **Dado** el aviso de garantía de la ficha, **cuando** se revisa, **entonces** el texto coincide literalmente con el aprobado por Jurídico. **[A VALIDAR — D-12]** el texto de garantía vigente es DESCONOCIDO.
- **AC-032-3** · `Widget` · **Dado** una ficha sin precio, **cuando** se renderiza, **entonces** el aviso de envío y garantía se muestra o se omite según la decisión de diseño. **[A VALIDAR — propuesta de PA nueva]** (el requisito no precisa si aplica a productos sin precio).

---

### Épica E — Usuarios y autenticación (historias críticas)

#### US-037 · RF-037 · Acceso sin iniciar sesión (Must)

- **AC-037-1** · `E2E` · **Dado** una instalación nueva sin sesión, **cuando** se abre la app, **entonces** el usuario llega al inicio sin pantalla de login y puede abrir catálogo, búsqueda, fichas, sedes y canales de contacto.
- **AC-037-2** · `Integración` · **Dado** las solicitudes públicas a `/mobile/v1` (catálogo, búsqueda, ficha, sedes, contacto), **cuando** se envían sin cabecera `Authorization`, **entonces** responden con éxito.
- **AC-037-3** · `Integración` · **Dado** un visitante, **cuando** intenta una acción que requiere sesión (pagar, perfil, pedidos, eliminar cuenta), **entonces** se le pide iniciar sesión o registrarse y su carrito local se conserva.
- **AC-037-4** · `Seguridad` · **Dado** las respuestas públicas de `/mobile/v1`, **cuando** se inspeccionan, **entonces** no contienen datos de otros usuarios ni campos de precio por rol (S-04).

#### US-038 · RF-038 · Registro (Must)

- **AC-038-1** · `Widget` · **Dado** la pantalla de registro, **cuando** se muestra, **entonces** pide correo, nombre, apellido y contraseña, con la contraseña enmascarada y una opción para mostrarla.
- **AC-038-2** · `Unitaria` · **Dado** contraseñas de 7 y de 8 caracteres, **cuando** se validan, **entonces** la de 7 se rechaza con mensaje y la de 8 se acepta.
- **AC-038-3** · `Unitaria` · **Dado** un correo con formato inválido (`a@`, `a@b`, sin `@`) o un campo obligatorio vacío, **cuando** el usuario intenta registrarse, **entonces** se muestra el error en el campo correspondiente y no se envía ninguna solicitud.
- **AC-038-4** · `Integración` · **Dado** un registro válido con aceptación de políticas (RF-039), **cuando** se envía, **entonces** el servidor crea la cuenta y la app muestra el resultado. **[A VALIDAR — propuesta de PA nueva]** si tras registrarse se inicia sesión automáticamente o se pide iniciar sesión.
- **AC-038-5** · `Integración` · **Dado** un correo ya registrado, **cuando** se intenta registrar, **entonces** el mensaje no revela de forma distinguible si la cuenta existe (RF-045). **[A VALIDAR — PA-02]** tensión entre RF-045 (no revelar existencia) y la usabilidad cuando no hay verificación de correo (RF-046 está en fase 2); definir el mensaje.
- **AC-038-6** · `Widget` · **Dado** una solicitud de registro en curso, **cuando** el usuario toca dos veces "Registrarme", **entonces** se emite exactamente una solicitud y el botón queda deshabilitado hasta recibir respuesta.
- **AC-038-7** · `Integración` · **Dado** un dispositivo sin red, **cuando** se envía el registro, **entonces** se muestra mensaje de falta de conexión y los campos de nombre, apellido y correo conservan lo escrito.
- **AC-038-8** · `Seguridad` · **Dado** el flujo de registro, **cuando** se inspeccionan logs, almacenamiento local y tráfico, **entonces** la contraseña viaja solo en el cuerpo de la solicitud por HTTPS y no aparece en logs, almacenamiento local, reportes de fallos ni en la URL.

#### US-039 · RF-039 · Aceptación de términos y política de datos (Must)

- **AC-039-1** · `Widget` · **Dado** la pantalla de registro, **cuando** se muestra, **entonces** existe una casilla de aceptación sin marcar por defecto, con enlaces visibles a los términos y a la política de tratamiento de datos que abren los documentos (AC-099-1).
- **AC-039-2** · `Widget` · **Dado** la casilla sin marcar, **cuando** el usuario intenta registrarse, **entonces** el registro no se envía y se indica que debe aceptar para continuar.
- **AC-039-3** · `Integración` · **Dado** un registro con aceptación, **cuando** se completa, **entonces** el servidor guarda la aceptación con fecha-hora y versión del documento aceptada, y es consultable por IPR. **[A VALIDAR — D-12, PA-10]** qué versión rige y qué datos exactos se registran (la web podría no registrar nada hoy).
- **AC-039-4** · `Seguridad` · **Dado** una solicitud de registro manipulada que omite o niega la aceptación, **cuando** llega al servidor, **entonces** se rechaza y no se crea la cuenta (la aceptación no depende solo de la interfaz).
- **AC-039-5** · `Integración` · **Dado** que los documentos legales no cargan (sin red o error), **cuando** el usuario intenta leerlos antes de registrarse, **entonces** se muestra el error con "Reintentar" y el registro no puede aceptar documentos que el usuario no pudo ver. **[A VALIDAR — D-12]** si se permite aceptar sin haberlos abierto.
- **AC-039-6** · `Seguridad` · **Dado** la aceptación registrada, **cuando** se consulta el registro, **entonces** no almacena más datos personales que los necesarios para acreditar el consentimiento. **[A VALIDAR — D-12]**.
- **AC-039-7** · `Manual` · **Dado** que cambia la versión de los términos, **cuando** un usuario ya registrado vuelve a la app, **entonces** el comportamiento (pedir nueva aceptación o no) sigue lo definido por Jurídico. **[A VALIDAR — D-12]**.

#### US-040 · RF-040 · Inicio de sesión (Must)

- **AC-040-1** · `E2E` · **Dado** una cuenta válida, **cuando** el usuario inicia sesión con su correo (y en otro intento con su usuario) y su contraseña, **entonces** accede a su cuenta y queda en la pantalla desde la que inició el flujo.
- **AC-040-2** · `Integración` · **Dado** un usuario inexistente y un usuario existente con contraseña incorrecta, **cuando** se intenta iniciar sesión, **entonces** el código de respuesta y el mensaje mostrado son idénticos (no distinguibles).
- **AC-040-3** · `Unitaria` · **Dado** el campo de usuario o de contraseña vacío, **cuando** el usuario toca "Iniciar sesión", **entonces** se muestra el error en el campo y no se emite solicitud.
- **AC-040-4** · `Widget` · **Dado** una solicitud de login en curso, **cuando** el usuario toca dos veces "Iniciar sesión", **entonces** se emite exactamente una solicitud.
- **AC-040-5** · `Integración` · **Dado** un dispositivo sin red, **cuando** el usuario intenta iniciar sesión, **entonces** se muestra mensaje de falta de conexión y se conserva el usuario escrito (la contraseña puede limpiarse).
- **AC-040-6** · `Seguridad` · **Dado** un inicio de sesión exitoso, **cuando** se inspecciona el dispositivo, **entonces** los tokens están solo en Keystore/Keychain (AC-044-1) y la contraseña no se almacena en ningún lugar del dispositivo.
- **AC-040-7** · `Seguridad` · **Dado** el flujo de login, **cuando** se inspecciona el tráfico y los logs, **entonces** la contraseña va únicamente en el cuerpo por HTTPS y ni la contraseña ni los tokens aparecen en la URL ni en logs.
- **AC-040-8** · `Widget` · **Dado** la contraseña enmascarada, **cuando** el usuario activa "mostrar", **entonces** se revela y al volver a tocarlo se oculta; al ir a segundo plano vuelve a enmascararse.
- **AC-040-9** · `Integración` · **Dado** un usuario con rol administrativo, **cuando** intenta iniciar sesión, **entonces** se aplica AC-048-1.

#### US-041 · RF-041 · Cierre de sesión con revocación (Must)

- **AC-041-1** · `Integración` · **Dado** una sesión activa, **cuando** el usuario cierra sesión, **entonces** la app emite la solicitud de revocación al servidor con el token de ese dispositivo.
- **AC-041-2** · `Seguridad` · **Dado** un token de acceso y un token de refresco copiados antes de cerrar sesión, **cuando** se reutilizan después, **entonces** el servidor responde 401 en ambos casos.
- **AC-041-3** · `Seguridad` · **Dado** el cierre de sesión completado, **cuando** se inspecciona Keystore/Keychain, **entonces** no quedan tokens de ese usuario.
- **AC-041-4** · `Seguridad` · **Dado** el cierre de sesión completado, **cuando** se inspecciona el almacenamiento de la app, **entonces** no quedan datos de perfil (correo, cédula/NIT, teléfono, direcciones) ni pedidos en caché sin cifrar (lección SEC-08 del `localStorage` de la web).
- **AC-041-5** · `E2E` · **Dado** la misma cuenta con sesión en el dispositivo A y en el B, **cuando** se cierra sesión en A, **entonces** la sesión de B sigue válida (RF-043).
- **AC-041-6** · `Integración` · **Dado** un dispositivo sin red, **cuando** el usuario cierra sesión, **entonces** se define si se cierra solo localmente y se reintenta la revocación al recuperar red. **[A VALIDAR — ADR-001 §2]** comportamiento sin red no definido; el criterio mínimo es que el usuario no quede con la sesión abierta en pantalla sin saberlo.
- **AC-041-7** · `Integración` · **Dado** el cierre de sesión, **cuando** el usuario vuelve al inicio, **entonces** la app queda en modo visitante. **[A VALIDAR — propuesta de PA nueva]** si el carrito local se conserva o se vacía al cerrar sesión explícitamente (RF-044 solo garantiza conservarlo al expirar).
- **AC-041-8** · `Widget` · **Dado** el botón "Cerrar sesión", **cuando** el usuario lo toca dos veces, **entonces** se emite una sola solicitud de revocación.

#### US-042 · RF-042 · Recuperación de contraseña (Must)

- **AC-042-1** · `Widget` · **Dado** la pantalla de login, **cuando** se muestra, **entonces** hay un acceso "¿Olvidaste tu contraseña?" visible.
- **AC-042-2** · `E2E` · **Dado** el flujo de recuperación, **cuando** el usuario lo completa en staging, **entonces** puede iniciar sesión con la nueva contraseña. **[A VALIDAR — ADR-001 §2]** el mecanismo (API propia o navegador seguro hacia la página `lost-password` de WordPress) lo define arquitectura; si es navegador, aplica AC-042-3.
- **AC-042-3** · `Seguridad` · **Dado** que la recuperación se hace en WordPress, **cuando** el usuario la inicia, **entonces** se abre en el navegador seguro del sistema (Custom Tabs / ASWebAuthenticationSession o SFSafariViewController) y no en un WebView propio de la app.
- **AC-042-4** · `Integración` · **Dado** un correo registrado y uno no registrado, **cuando** se solicita la recuperación, **entonces** el mensaje, el código de respuesta y la pantalla resultante son iguales (no revela si la cuenta existe; RF-045).
- **AC-042-5** · `Seguridad` · **Dado** repetidas solicitudes de recuperación desde el mismo origen, **cuando** se supera el umbral, **entonces** se aplica el límite de AC-045-3. **[A VALIDAR — R-02, COD §8.5]** umbral.
- **AC-042-6** · `Integración` · **Dado** un restablecimiento de contraseña completado, **cuando** el usuario tenía sesión en otros dispositivos, **entonces** se aplica la política definida (cerrar o conservar esas sesiones). **[A VALIDAR — propuesta de PA nueva]** (hoy el token solo cambia al cambiar correo o contraseña, COD H-02).
- **AC-042-7** · `Seguridad` · **Dado** el enlace de restablecimiento, **cuando** se reutiliza tras usarse o tras expirar, **entonces** es rechazado. **[A VALIDAR — ADR-001 §2]** vigencia definida por WordPress; verificar su configuración en staging.
- **AC-042-8** · `Integración` · **Dado** un dispositivo sin red, **cuando** el usuario solicita recuperar la contraseña, **entonces** se muestra mensaje de falta de conexión.

#### US-043 · RF-043 · Sesiones independientes por dispositivo (Must)

- **AC-043-1** · `E2E` · **Dado** una sesión activa en la app (dispositivo A), **cuando** el mismo usuario inicia sesión en la web, **entonces** la app A sigue autenticada: una solicitud autenticada posterior responde 200.
- **AC-043-2** · `E2E` · **Dado** sesión en la web, **cuando** el usuario inicia sesión en la app, **entonces** la sesión web sigue válida (COD H-01: hoy un solo token por usuario cierra la otra sesión; este criterio debe pasar tras ampliar `ipr/v1`).
- **AC-043-3** · `E2E` · **Dado** sesiones en dos dispositivos móviles A y B, **cuando** el usuario cierra sesión en B o inicia sesión de nuevo en B, **entonces** A permanece autenticado.
- **AC-043-4** · `Integración` · **Dado** una sesión cerrada o revocada desde la web (o por revocación en el servidor), **cuando** la app usa su token de acceso o de refresco, **entonces** el servidor responde 401, la app trata el caso como sesión expirada (AC-044-5), pide reautenticación y conserva el carrito, sin bucles de reintento.
- **AC-043-5** · `Seguridad` · **Dado** sesiones simultáneas, **cuando** se inspeccionan los tokens, **entonces** cada dispositivo tiene un identificador de dispositivo y un token de refresco distintos; ninguno es válido en otro dispositivo.
- **AC-043-6** · `Integración` · **Dado** un cambio de contraseña o de correo en un dispositivo, **cuando** el otro dispositivo usa su sesión, **entonces** se aplica la política definida. **[A VALIDAR — propuesta de PA nueva]** (RF-104 exige que cambiar el correo invalide el token anterior; falta definir el efecto sobre las demás sesiones).

#### US-044 · RF-044 · Tokens de corta vida, refresco rotativo y almacenamiento seguro (Must)

- **AC-044-1** · `Seguridad` · **Dado** un inicio de sesión exitoso, **cuando** se inspeccionan preferencias compartidas, archivos, bases de datos locales y `NSUserDefaults` del dispositivo, **entonces** no hay tokens en ellos; los tokens residen solo en Android Keystore / iOS Keychain.
- **AC-044-2** · `Seguridad` · **Dado** el tráfico de la app capturado con un proxy durante una sesión completa, **cuando** se buscan los tokens, **entonces** viajan únicamente en la cabecera `Authorization` y hay 0 ocurrencias de `token=` o de un token en cualquier URL.
- **AC-044-3** · `Integración` · **Dado** un token de acceso expirado y un token de refresco válido, **cuando** la app realiza una solicitud autenticada, **entonces** renueva el acceso sin interacción del usuario y reintenta la solicitud original una sola vez con éxito. **[A VALIDAR — ADR-001 §2]** vigencias (el informe propone 15 min para el acceso; la del refresco es DESCONOCIDA).
- **AC-044-4** · `Seguridad` · **Dado** un token de refresco ya usado, **cuando** se presenta de nuevo (reutilización), **entonces** el servidor lo rechaza con 401. **[A VALIDAR — propuesta de PA nueva]** si la reutilización además revoca la sesión de ese dispositivo.
- **AC-044-5** · `Integración` · **Dado** un token de refresco expirado, revocado o inválido, **cuando** la app intenta renovar, **entonces** muestra la pantalla de inicio de sesión con el mensaje de sesión expirada, y el carrito conserva las mismas líneas y cantidades que antes.
- **AC-044-6** · `Unitaria` · **Dado** 5 solicitudes simultáneas con el acceso expirado, **cuando** se procesan, **entonces** se ejecuta una sola renovación y las 5 se reintentan con el token nuevo (no se consume dos veces el refresco rotativo).
- **AC-044-7** · `Integración` · **Dado** que no hay red al intentar renovar, **cuando** falla la renovación, **entonces** la app no cierra la sesión ni borra los tokens y reintenta al recuperar la conexión.
- **AC-044-8** · `Seguridad` · **Dado** un token manipulado, de otra cuenta o expirado, **cuando** se envía a `/mobile/v1`, **entonces** la respuesta es 401 sin revelar el motivo en detalle (ADR-001, verificación).
- **AC-044-9** · `Seguridad` · **Dado** una sesión completa ejecutada en compilación de depuración y de producción, **cuando** se revisan los logs del sistema (logcat / consola de Xcode), los reportes de fallos y la analítica, **entonces** no aparece ningún token, ticket ni contraseña.
- **AC-044-10** · `Seguridad` · **Dado** un respaldo del dispositivo (copia de seguridad de Android o iCloud), **cuando** se inspecciona su contenido, **entonces** no incluye tokens ni datos de perfil.
- **AC-044-11** · `E2E` · **Dado** el carrito con líneas y la sesión expirada al intentar pagar, **cuando** el usuario se reautentica, **entonces** regresa al carrito con las mismas líneas y puede continuar con el pago.

#### US-045 · RF-045 · Límite de intentos y bloqueo progresivo (Must)

- **AC-045-1** · `Seguridad` · **Dado** intentos de login fallidos consecutivos sobre una cuenta o desde un origen, **cuando** se alcanza el umbral, **entonces** el servidor responde 429 con `Retry-After` y la app muestra un mensaje de espera, con el botón deshabilitado durante ese tiempo. **[A VALIDAR — R-02, COD §8.5]** umbral, ventana, y si es por cuenta, por IP o ambos (reglas de Wordfence y Cloudflare DESCONOCIDAS).
- **AC-045-2** · `Seguridad` · **Dado** bloqueos sucesivos, **cuando** se repite el abuso, **entonces** la espera aumenta de forma progresiva. **[A VALIDAR — propuesta de PA nueva]** política de progresión.
- **AC-045-3** · `Seguridad` · **Dado** que el límite aplica a login, registro y recuperación de contraseña, **cuando** se supera el umbral en cada uno, **entonces** los tres devuelven 429 (se prueban los tres flujos).
- **AC-045-4** · `Integración` · **Dado** dos instancias del BFF en ejecución, **cuando** se hacen intentos alternados entre ambas, **entonces** el contador es compartido y el bloqueo se activa con el total de intentos; reiniciar un proceso no reinicia el contador (no depende de memoria de un solo proceso; COD H-04).
- **AC-045-5** · `Seguridad` · **Dado** un usuario inexistente y uno existente con contraseña incorrecta, **cuando** se compara la respuesta de login, **entonces** cuerpo, código de estado y mensaje son idénticos; igual para recuperación de contraseña con correo existente e inexistente.
- **AC-045-6** · `E2E` · **Dado** el tráfico legítimo de la app (login, registro, checkout) desde dispositivos y redes distintas, **cuando** pasa por Cloudflare en staging, **entonces** no recibe desafío ni bloqueo del WAF/Bot Fight (R-02, ADR-001 C3).
- **AC-045-7** · `Widget` · **Dado** el mensaje de bloqueo, **cuando** se muestra, **entonces** informa cuánto esperar sin indicar si la cuenta existe.
- **AC-045-8** · `Seguridad` · **Dado** un bloqueo activo, **cuando** pasa el tiempo indicado por `Retry-After`, **entonces** el usuario legítimo puede volver a intentar y se restablece el contador al iniciar sesión correctamente.

#### US-048 · RF-048 · Bloqueo de roles administrativos en la app (Should)

- **AC-048-1** · `Seguridad` · **Dado** una cuenta con rol administrativo de WordPress, **cuando** intenta iniciar sesión en la app con credenciales correctas, **entonces** el servidor no emite token y la app muestra el mismo mensaje genérico de credenciales no válidas. **[A VALIDAR — PA-03]** decisión de IPR y lista exacta de roles considerados administrativos.
- **AC-048-2** · `Seguridad` · **Dado** una cuenta con rol de cliente, **cuando** inicia sesión, **entonces** se emite la sesión con normalidad.
- **AC-048-3** · `Seguridad` · **Dado** que el bloqueo se verifica en el servidor, **cuando** se intenta saltar la validación manipulando la app o la solicitud, **entonces** el servidor sigue rechazando al rol administrativo (no se aplica solo en el cliente).
- **AC-048-4** · `Seguridad` · **Dado** una cuenta con varios roles (cliente y administrativo), **cuando** inicia sesión, **entonces** se aplica la regla definida. **[A VALIDAR — PA-03]**.
- **AC-048-5** · `Seguridad` · **Dado** un rol administrativo con un token emitido antes de aplicar el bloqueo, **cuando** lo presenta a `/mobile/v1`, **entonces** se rechaza con 401.

---

### Épica F — Carrito y compras (historias críticas)

#### US-049 · RF-049 · Carrito local persistente (Must)

- **AC-049-1** · `Integración` · **Dado** un carrito vacío, **cuando** el usuario añade un producto, **entonces** la línea aparece con nombre, cantidad y controles para cambiar cantidad y quitar.
- **AC-049-2** · `Unitaria` · **Dado** una línea con cantidad 1, **cuando** el usuario intenta bajar a 0 o subir a 100, **entonces** la cantidad se mantiene en 1 o 99 respectivamente; quitar la línea solo ocurre mediante la acción explícita de quitar.
- **AC-049-3** · `Integración` · **Dado** un carrito con 100 líneas, **cuando** el usuario intenta añadir la línea 101, **entonces** se rechaza con mensaje del límite y el carrito sigue en 100 líneas.
- **AC-049-4** · `Integración` · **Dado** un carrito con 3 líneas y cantidades conocidas, **cuando** se cierra la app por completo (proceso terminado) y se vuelve a abrir, **entonces** las 3 líneas y cantidades siguen idénticas, sin sesión iniciada.
- **AC-049-5** · `Widget` · **Dado** el carrito con líneas, **cuando** el usuario quita una línea, **entonces** desaparece, el contador del carrito disminuye y el subtotal informativo se actualiza.
- **AC-049-6** · `Widget` · **Dado** un carrito vacío, **cuando** se abre, **entonces** se muestra un estado vacío con una acción para ir al catálogo y el botón "Pagar" no está disponible.
- **AC-049-7** · `Seguridad` · **Dado** el almacenamiento local del carrito, **cuando** se inspecciona, **entonces** no contiene tokens, datos de perfil ni totales cobrables; solo identificadores de producto, cantidades y datos de presentación.
- **AC-049-8** · `Integración` · **Dado** un visitante sin sesión, **cuando** arma el carrito, **entonces** todas las operaciones funcionan sin autenticación y sin conexión (el carrito es local).
- **AC-049-9** · `Integración` · **Dado** una cuenta con sesión, **cuando** el usuario cierra y abre sesión, **entonces** el carrito local no se sincroniza con el servidor (RF-059 está en fase 2).

#### US-050 · RF-050 · Revalidación de precio y disponibilidad (Must)

- **AC-050-1** · `Integración` · **Dado** un carrito con N ítems, **cuando** el usuario abre el carrito, **entonces** la app consulta al endpoint móvil el precio vigente y la disponibilidad de cada uno de los N ítems (por ID) y muestra un indicador de carga mientras tanto.
- **AC-050-2** · `Integración` · **Dado** un ítem cuyo precio cambió en WooCommerce, **cuando** termina la consulta, **entonces** la línea muestra el precio nuevo y un aviso visible del cambio (precio anterior y nuevo). **[A VALIDAR — propuesta de PA nueva]** si el usuario debe confirmar explícitamente el cambio antes de poder pagar.
- **AC-050-3** · `Integración` · **Dado** un ítem agotado, **cuando** termina la consulta, **entonces** la línea se marca "Agotado" y el botón "Pagar" queda deshabilitado mientras exista ese ítem en el carrito.
- **AC-050-4** · `Integración` · **Dado** un carrito con un ítem agotado y otros disponibles, **cuando** el usuario quita el ítem agotado (o ajusta lo necesario), **entonces** el botón "Pagar" se habilita.
- **AC-050-5** · `Integración` · **Dado** un ítem que ahora tiene precio 0, **cuando** termina la consulta, **entonces** la línea se marca como producto sin precio, no es pagable, ofrece "Más información" y bloquea el pago hasta quitarla.
- **AC-050-6** · `Integración` · **Dado** un ítem despublicado o inexistente (404 en la consulta), **cuando** termina la consulta, **entonces** se trata como no disponible con el mismo bloqueo de AC-050-3.
- **AC-050-7** · `Integración` · **Dado** que la consulta de revalidación falla (sin red, 5xx o tiempo agotado), **cuando** el usuario intenta pagar, **entonces** el pago queda bloqueado con un mensaje y "Reintentar" (no se paga con datos sin verificar).
- **AC-050-8** · `Seguridad` · **Dado** el flujo de revalidación, **cuando** se inspecciona lo que la app envía y usa, **entonces** la app solo envía identificadores de producto, y el precio que muestra proviene siempre de la respuesta del servidor; no se usa el precio guardado localmente como autoridad.
- **AC-050-9** · `Integración` · **Dado** un cambio de precio entre la revalidación y el pago, **cuando** el usuario llega al checkout, **entonces** el monto final lo determina WooCommerce (ver AC-052-5) y el carrito de la app no se presenta como total definitivo (AC-051-2).
- **AC-050-10** · `Integración` · **Dado** que el endpoint móvil de consulta por ID aún no existe (RF §2: backend nuevo), **cuando** se define su contrato, **entonces** devuelve para cada ID el precio, el estado de stock y la indicación de sin precio, y rechaza más de 100 IDs.

#### US-051 · RF-051 · Resumen del carrito con subtotal informativo (Must)

- **AC-051-1** · `Widget` · **Dado** un carrito con ítems con precio, **cuando** se muestra el resumen, **entonces** presenta el subtotal con el rótulo "informativo" e "IVA incluido", en COP con formato de miles.
- **AC-051-2** · `Widget` · **Dado** el resumen del carrito, **cuando** se revisa el texto, **entonces** incluye un aviso de que impuestos, envío (que el cliente elige en el checkout según transportadora) y total final se confirman en el checkout, y no presenta ninguna cifra rotulada "Total a pagar" ni un envío calculado.
- **AC-051-3** · `Unitaria` · **Dado** un carrito con un ítem sin precio, **cuando** se calcula el subtotal informativo, **entonces** ese ítem no suma (ni se muestra "$0").
- **AC-051-4** · `Seguridad` · **Dado** el subtotal informativo, **cuando** se inspecciona el código y el tráfico, **entonces** no se envía a ningún servidor como monto a cobrar ni se persiste como valor autoritativo. **[A VALIDAR — decisión de arquitectura]** si el subtotal lo entrega el BFF o es la suma local de precios unitarios entregados por el servidor; en cualquier caso no se calcula IVA, envío ni descuentos en el cliente.
- **AC-051-5** · `Widget` · **Dado** un visitante sin sesión, **cuando** abre el carrito, **entonces** ve el resumen completo (el login se pide solo al pagar).

#### US-052 · RF-052 · Pago con sesión y ticket de un solo uso (Must)

- **AC-052-1** · `Widget` · **Dado** un visitante sin sesión con carrito válido, **cuando** toca "Pagar", **entonces** se le pide iniciar sesión o registrarse y el carrito se conserva; tras autenticarse puede continuar con el pago. **[A VALIDAR — PA-01]** si se permitirá compra de invitado (hoy S-02: exige sesión).
- **AC-052-2** · `Seguridad` · **Dado** un cliente con sesión y carrito válido, **cuando** toca "Pagar", **entonces** la app emite exactamente una solicitud `POST /mobile/v1/checkout` con cabecera `Authorization: Bearer`, cuyo cuerpo contiene solo la lista de `{id, cantidad}` y ningún campo de precio, total, impuesto, descuento, envío ni URL de retorno (verificado con proxy).
- **AC-052-3** · `E2E` · **Dado** la respuesta del BFF con la URL con ticket, **cuando** la app la procesa, **entonces** abre la URL en el navegador seguro del sistema (Custom Tabs en Android; ASWebAuthenticationSession o SFSafariViewController en iOS) y no en un WebView incrustado.
- **AC-052-4** · `Seguridad` · **Dado** un ticket de un solo uso con vigencia aproximada de 60 s, **cuando** la URL se abre una segunda vez, o se abre pasados 60 s, **entonces** WooCommerce la rechaza y la app permite reintentar generando un ticket nuevo (AC-058-4). La app no guarda ni registra la URL ni el ticket en logs ni en almacenamiento.
- **AC-052-5** · `Seguridad` · **Dado** una solicitud de checkout manipulada con campos `price`, `total` o `discount` añadidos, **cuando** llega a `/mobile/v1/checkout`, **entonces** esos campos se ignoran o se rechazan; y en un E2E con Wompi sandbox, el monto del checkout coincide con el precio vigente de WooCommerce y no con ningún valor enviado por la app.
- **AC-052-6** · `Widget` · **Dado** una solicitud de checkout en curso, **cuando** el usuario toca dos veces "Pagar" (o toca de nuevo antes de que abra el navegador), **entonces** se emite exactamente una solicitud a `/mobile/v1/checkout` (contada en el proxy) y el botón queda deshabilitado con indicador de progreso hasta recibir respuesta.
- **AC-052-7** · `Integración` · **Dado** un carrito con ítems no disponibles o sin precio, **cuando** el usuario intenta pagar, **entonces** el botón está deshabilitado y no se emite ninguna solicitud (AC-050-3).
- **AC-052-8** · `Integración` · **Dado** un dispositivo sin red, **cuando** el usuario toca "Pagar", **entonces** se muestra el mensaje de falta de conexión, no se abre el navegador y el carrito queda intacto.
- **AC-052-9** · `Integración` · **Dado** un token de acceso expirado al tocar "Pagar", **cuando** se procesa, **entonces** se renueva transparentemente (AC-044-3); si la renovación falla se pide reautenticación y el carrito se conserva (AC-044-5).
- **AC-052-10** · `Integración` · **Dado** una sesión revocada desde la web, **cuando** el usuario toca "Pagar", **entonces** el servidor responde 401, no se genera ticket y la app pide iniciar sesión conservando el carrito (AC-043-4).
- **AC-052-11** · `Integración` · **Dado** un cuerpo con cantidad 0, 100, un ID no numérico, lista vacía o más de 100 líneas, **cuando** llega a `/mobile/v1/checkout`, **entonces** el servidor responde 400 con mensaje legible y no genera ticket.
- **AC-052-12** · `Seguridad` · **Dado** el binario de la app descompilado, **cuando** se busca `HANDOFF_SECRET`, `X-IPR-Secret`, claves de WooCommerce (`ck_`, `cs_`) y credenciales SMTP, **entonces** hay 0 coincidencias; la app no envía `X-IPR-Secret` en ninguna solicitud.
- **AC-052-13** · `Seguridad` · **Dado** la URL de checkout devuelta por el BFF, **cuando** la app la va a abrir, **entonces** valida que el host pertenezca a la lista cerrada de dominios de la tienda y, si no, no la abre y muestra error (previene redirección abierta). **[A VALIDAR — propuesta de PA nueva]** lista de dominios permitidos.
- **AC-052-14** · `Seguridad` · **Dado** el checkout de la app, **cuando** se inspecciona la solicitud, **entonces** el token de sesión viaja solo en `Authorization` (nunca en la URL ni en el ticket) y la URL de retorno la fija el servidor, no la app.
- **AC-052-15** · `E2E` · **Dado** staging (frontend, WooCommerce y Wompi sandbox) y un carrito válido, **cuando** el cliente completa el flujo de pago con una tarjeta de prueba aprobada, **entonces** se crea el pedido en WooCommerce y la app llega a la pantalla de resultado (US-055/US-056). Es el criterio de salida del MVP (ADR-002).
- **AC-052-16** · `Integración` · **Dado** que WordPress no responde dentro del tiempo límite del BFF, **cuando** el usuario toca "Pagar", **entonces** la app muestra el error de US-058 en un tiempo acotado y no queda bloqueada con el indicador de progreso. **[A VALIDAR — propuesta de PA nueva]** umbral de tiempo en la app (en la web el BFF espera 8 s a WordPress).

#### US-053 · RF-053 · La app no maneja datos de pago (Must)

- **AC-053-1** · `Seguridad` · **Dado** el código y los recursos de la app, **cuando** se revisan, **entonces** no existe ningún campo de captura de número de tarjeta, vencimiento o CVV, ni SDK de pasarela de pago.
- **AC-053-2** · `Seguridad` · **Dado** una compra completa en staging con proxy, **cuando** se listan los hosts contactados por la app, **entonces** ninguna solicitud de la app va al dominio de Wompi; el pago ocurre solo en el navegador seguro.
- **AC-053-3** · `Seguridad` · **Dado** una compra completa, **cuando** se inspeccionan logs, almacenamiento y reportes de fallos de la app, **entonces** no hay datos de tarjeta ni de pago.
- **AC-053-4** · `E2E` · **Dado** el checkout abierto en staging, **cuando** se revisan los medios de pago ofrecidos, **entonces** coinciden con los habilitados en WooCommerce/Wompi. **[A VALIDAR — D-02, PA-12]** lista de medios habilitados.
- **AC-053-5** · `Manual` · **Dado** el flujo de pago en el navegador seguro, **cuando** el usuario lo observa, **entonces** ve la barra de dirección/dominio de la tienda (no queda oculta por la app).
- **AC-053-6** · `Seguridad` · **Dado** las capturas de pantalla y la vista previa de la app en segundo plano, **cuando** el usuario está en las pantallas del carrito y pedidos, **entonces** no se exponen datos de pago (la app no tiene ninguno).

#### US-054 · RF-054 · Prellenado del checkout (Should)

- **AC-054-1** · `E2E` · **Dado** un cliente con correo y datos de facturación guardados, **cuando** el checkout de WooCommerce se abre desde la app, **entonces** esos campos aparecen prellenados con los valores de su cuenta.
- **AC-054-2** · `E2E` · **Dado** un cliente sin facturación guardada, **cuando** se abre el checkout, **entonces** los campos faltantes están vacíos y el usuario puede completarlos en el checkout.
- **AC-054-3** · `Seguridad` · **Dado** la URL abierta en el navegador seguro, **cuando** se inspecciona, **entonces** contiene solo el ticket opaco (32 caracteres alfanuméricos) y ningún dato de facturación, correo ni token en la URL.
- **AC-054-4** · `E2E` · **Dado** que el cliente editó su dirección en el perfil (RF-106), **cuando** inicia una nueva compra, **entonces** el checkout se prellena con los datos actualizados.
- **AC-054-5** · `Seguridad` · **Dado** el flujo de prellenado, **cuando** se inspeccionan logs y tráfico de la app, **entonces** la cédula/NIT, el teléfono y la dirección no aparecen en logs.

#### US-055 · RF-055 · Retorno a la app tras pagar (Must)

- **AC-055-1** · `E2E` · **Dado** un pago completado en staging, **cuando** WooCommerce redirige a `/pedido-confirmado`, **entonces** el enlace abre la app (App Links en Android; Universal Links en iOS) en la pantalla de resultado del pedido, con la app en segundo plano y con la app cerrada.
- **AC-055-2** · `Manual` · **Dado** el dominio de la tienda, **cuando** se consultan `/.well-known/assetlinks.json` y `/.well-known/apple-app-site-association`, **entonces** responden 200 con los identificadores de la app y la verificación de enlaces del sistema queda en estado verificado. **[A VALIDAR — ADR-001 C1/C2]** si se pueden alojar esos archivos en el dominio (COD §8, pregunta 3).
- **AC-055-3** · `E2E` · **Dado** que el enlace no abre la app o el usuario cierra el navegador seguro sin retornar, **cuando** la app vuelve a primer plano tras iniciar un pago, **entonces** consulta al servidor el estado del pedido y muestra la pantalla de resultado correspondiente. **[A VALIDAR — ADR-001 C1/C2]** cómo se identifica el pedido en este camino alterno (COD §5.4).
- **AC-055-4** · `Seguridad` · **Dado** un enlace manipulado `/pedido-confirmado?order=…&status=completed` abierto en la app, **cuando** la app lo recibe, **entonces** no toma el estado de los parámetros de la URL como verdad: consulta al servidor con la sesión del usuario (AC-056-1).
- **AC-055-5** · `Seguridad` · **Dado** un enlace de retorno con un número de pedido de otro usuario, **cuando** se abre en la app, **entonces** el servidor responde sin datos (403/404) y la app muestra un error genérico sin revelar la existencia del pedido.
- **AC-055-6** · `Integración` · **Dado** un enlace de retorno recibido sin sesión activa, **cuando** se abre la app, **entonces** se pide iniciar sesión y, tras autenticarse, se muestra el resultado.
- **AC-055-7** · `Integración` · **Dado** el retorno con la app cerrada (arranque en frío), **cuando** se abre desde el enlace, **entonces** la app abre directamente en la pantalla de resultado y el botón atrás lleva al inicio.

#### US-056 · RF-056 · Resultado de pedido verificado en servidor (Must)

- **AC-056-1** · `Integración` · **Dado** la pantalla de resultado, **cuando** se carga, **entonces** número y estado del pedido provienen de una consulta autenticada al servidor y no de los parámetros de la URL de retorno.
- **AC-056-2** · `E2E` · **Dado** un pago aprobado en Wompi sandbox, **cuando** se muestra el resultado, **entonces** el estado es "pagado" y el número coincide con el del pedido en WooCommerce.
- **AC-056-3** · `E2E` · **Dado** un pago rechazado en Wompi sandbox, **cuando** se muestra el resultado, **entonces** el estado es "fallido" con opción de reintentar.
- **AC-056-4** · `E2E` · **Dado** un pago cancelado por el usuario en el checkout, **cuando** vuelve a la app, **entonces** el estado es "cancelado" y el carrito sigue intacto (AC-057-2).
- **AC-056-5** · `E2E` · **Dado** un pago pendiente de confirmación, **cuando** se muestra el resultado, **entonces** el estado es "pendiente" con explicación de que aún no se confirma, y no se presenta como pagado; al confirmarse, se actualiza al recargar la pantalla sin cerrar sesión.
- **AC-056-6** · `Seguridad` · **Dado** un pedido en estado pendiente y un enlace con `status=completed` falsificado, **cuando** se abre, **entonces** la app muestra "pendiente" (el del servidor).
- **AC-056-7** · `Integración` · **Dado** que el servidor no responde al consultar el pedido, **cuando** se muestra la pantalla, **entonces** se informa que no fue posible confirmar el estado, con "Reintentar", y no se afirma éxito ni fallo.
- **AC-056-8** · `Integración` · **Dado** un estado de pedido no mapeado por la app, **cuando** se muestra, **entonces** se presenta la etiqueta que entrega el servidor (`statusLabel`) sin ocultar el pedido. **[A VALIDAR — PA-12]** lista de estados reales de WooCommerce.
- **AC-056-9** · `Widget` · **Dado** cada estado (pagado, pendiente, fallido, cancelado), **cuando** se renderiza la pantalla, **entonces** el texto, el ícono y las acciones disponibles (ver pedido, seguir comprando, reintentar) corresponden al estado y no se mezclan.
- **AC-056-10** · `Seguridad` · **Dado** una consulta de pedido con un número de otro usuario, **cuando** llega al servidor, **entonces** se rechaza (403/404) y no devuelve datos.

#### US-057 · RF-057 · Vaciado de carrito y prevención de doble pago (Must)

- **AC-057-1** · `E2E` · **Dado** un pedido confirmado como pagado por el servidor, **cuando** la app lo recibe, **entonces** el carrito local queda vacío (0 líneas).
- **AC-057-2** · `E2E` · **Dado** un pago fallido, cancelado o abandonado (se cierra el navegador sin pagar), **cuando** el usuario vuelve a la app, **entonces** el carrito conserva las mismas líneas y cantidades.
- **AC-057-3** · `E2E` · **Dado** un pago pendiente, **cuando** el usuario vuelve a la app, **entonces** el carrito no se vacía hasta que el servidor confirme el pedido. **[A VALIDAR — PA-11, D-02]** tratamiento exacto del carrito mientras el pedido está pendiente.
- **AC-057-4** · `E2E` · **Dado** un pago que terminó bien mientras la app no tenía red, **cuando** se recupera la conexión, **entonces** la app consulta el estado y vacía el carrito solo tras la confirmación del servidor.
- **AC-057-5** · `E2E` · **Dado** un pago abandonado y un segundo intento sobre el mismo carrito, **cuando** el usuario completa el pago en el segundo intento, **entonces** existe exactamente 1 pedido pagado y 0 pedidos duplicados pagados en WooCommerce. **[A VALIDAR — PA-11]** el comportamiento de WooCommerce ante un pedido pendiente previo es DESCONOCIDO; probar con Wompi sandbox.
- **AC-057-6** · `Widget` · **Dado** un pedido pendiente reciente del mismo carrito, **cuando** el usuario toca "Pagar" otra vez, **entonces** la app informa que hay un pedido pendiente antes de generar otro ticket. **[A VALIDAR — PA-11, D-02]** si se bloquea, se advierte o se permite.
- **AC-057-7** · `Integración` · **Dado** el doble toque en "Pagar" (AC-052-6), **cuando** se completa el flujo, **entonces** no se genera más de un ticket por intención de pago.
- **AC-057-8** · `Integración` · **Dado** que la app se cierra por la fuerza durante el pago, **cuando** el usuario la reabre, **entonces** el carrito no se vacía por sí solo y el usuario puede ver el estado de su pedido más reciente en el historial (US-107).
- **AC-057-9** · `Seguridad` · **Dado** la decisión de vaciar el carrito, **cuando** se inspecciona su origen, **entonces** nunca se basa solo en los parámetros de la URL de retorno ni en el cierre del navegador, sino en el estado confirmado por el servidor.

#### US-058 · RF-058 · Errores del traspaso al checkout (Should)

- **AC-058-1** · `Integración` · **Dado** que la tienda rechaza el carrito (400), **cuando** se muestra el error, **entonces** el mensaje es legible en español ("el carrito no es válido" o equivalente), sin códigos ni texto técnico, con botón "Reintentar" y el carrito intacto.
- **AC-058-2** · `Integración` · **Dado** que la tienda no está disponible (tiempo agotado, 5xx, 502), **cuando** el usuario toca "Pagar", **entonces** se muestra "No se pudo conectar con la tienda, inténtalo de nuevo" y se puede reintentar.
- **AC-058-3** · `Integración` · **Dado** que el BFF devuelve una respuesta sin ticket válido, **cuando** la app la procesa, **entonces** no abre ninguna URL, muestra un mensaje de reintento y no guarda nada.
- **AC-058-4** · `Integración` · **Dado** un ticket expirado o ya usado al abrir el checkout, **cuando** el usuario vuelve a la app y toca "Pagar" otra vez, **entonces** se genera un ticket nuevo y el flujo continúa.
- **AC-058-5** · `Seguridad` · **Dado** errores 401/403 en el traspaso con la tienda, **cuando** se muestra el error, **entonces** el mensaje no expone configuración interna ni nombres de variables (la web actual muestra "Revisa la configuración del servidor": no debe replicarse).
- **AC-058-6** · `Seguridad` · **Dado** cualquier error del traspaso, **cuando** se muestra, **entonces** no aparece HTML crudo, stack trace, URL interna ni mensajes sin traducir del servidor.
- **AC-058-7** · `Integración` · **Dado** un error cualquiera, **cuando** el usuario reintenta rápidamente varias veces, **entonces** se emite una solicitud a la vez (no solicitudes simultáneas).
- **AC-058-8** · `Integración` · **Dado** que WooCommerce no puede agregar un ítem al abrir el checkout (por ejemplo, se agotó), **cuando** el cliente llega al carrito de WooCommerce, **entonces** el comportamiento al regresar a la app queda definido. **[A VALIDAR — propuesta de PA nueva]** (COD §5.4 punto 5: los agotados hacen que la operación falle y WooCommerce muestre el carrito).
- **AC-058-9** · `Integración` · **Dado** cualquiera de los errores, **cuando** ocurre, **entonces** el carrito conserva las mismas líneas y cantidades (AC-009-4).

---

### Épica G — Cotizaciones (WhatsApp)

#### US-062 · RF-062 · "Más información" abre WhatsApp con el producto (Must)

- **AC-062-1** · `Integración` · **Dado** la ficha de un producto sin precio y WhatsApp instalado, **cuando** el usuario toca "Más información", **entonces** se abre WhatsApp con la línea nacional de atención y un mensaje prellenado que contiene el nombre y el SKU del producto. **[A VALIDAR — D-04]** texto exacto del mensaje (la web usa nombre y SKU; confirmar redacción con Comercial).
- **AC-062-2** · `Unitaria` · **Dado** un producto con nombre "Válvula 1/4\" & tubo #3" y SKU "ABC-123", **cuando** se construye el enlace, **entonces** el texto está codificado en URL y, al decodificarlo, nombre y SKU son idénticos a los originales.
- **AC-062-3** · `Integración` · **Dado** un visitante sin sesión, **cuando** toca "Más información", **entonces** funciona sin autenticación y sin recopilar datos personales.
- **AC-062-4** · `Integración` · **Dado** un dispositivo sin WhatsApp, **cuando** se toca el botón, **entonces** se aplica AC-063-1.
- **AC-062-5** · `Unitaria` · **Dado** un producto sin SKU, **cuando** se construye el mensaje, **entonces** el mensaje incluye el nombre y no contiene "undefined", "null" ni un SKU vacío.
- **AC-062-6** · `Integración` · **Dado** un dispositivo sin red, **cuando** se toca "Más información", **entonces** se intenta abrir WhatsApp igualmente (no requiere red del BFF).

#### US-063 · RF-063 · Alternativa si WhatsApp no está disponible (Should)

- **AC-063-1** · `Integración` · **Dado** un dispositivo sin WhatsApp instalado o con fallo al abrirlo, **cuando** el usuario toca un botón de WhatsApp, **entonces** la app ofrece dos alternativas: abrir el enlace web de WhatsApp (`wa.me`) en el navegador y llamar a la línea de atención.
- **AC-063-2** · `Integración` · **Dado** la alternativa de llamar, **cuando** el usuario la elige, **entonces** se abre el marcador del dispositivo con el número de atención ya escrito, sin marcar automáticamente.
- **AC-063-3** · `Integración` · **Dado** la alternativa web, **cuando** se elige, **entonces** el mensaje prellenado (producto o término buscado) se conserva en el enlace.
- **AC-063-4** · `Manual` · **Dado** Android 11 o superior e iOS, **cuando** WhatsApp está instalado, **entonces** la app lo detecta correctamente (sin falsos negativos por restricciones de visibilidad de paquetes o esquemas) y no ofrece la alternativa sin necesidad.
- **AC-063-5** · `Integración` · **Dado** un dispositivo sin telefonía (por ejemplo, tableta), **cuando** se elige llamar, **entonces** se muestra mensaje claro y la app no falla.

#### US-064 · RF-064 · Botón general "Cotizar por WhatsApp" (Should)

- **AC-064-1** · `Widget` · **Dado** el inicio y la pantalla de ayuda, **cuando** se renderizan, **entonces** ambas muestran un botón "Cotizar por WhatsApp".
- **AC-064-2** · `Integración` · **Dado** el botón, **cuando** se toca con WhatsApp instalado, **entonces** se abre la línea nacional con un mensaje prellenado de solicitud de cotización de proyecto o volumen. **[A VALIDAR — propuesta de PA nueva]** texto del mensaje.
- **AC-064-3** · `Integración` · **Dado** un dispositivo sin WhatsApp, **cuando** se toca, **entonces** se aplica AC-063-1.
- **AC-064-4** · `Widget` · **Dado** un visitante sin sesión, **cuando** toca el botón, **entonces** funciona sin autenticación.

#### US-065 · RF-065 · Medición agregada de "Más información" (Should)

- **AC-065-1** · `Integración` · **Dado** una ficha sin precio, **cuando** el usuario toca "Más información", **entonces** se registra exactamente 1 evento agregado con el identificador del producto y la fecha-hora. **[A VALIDAR — PA-08]** herramienta de analítica y definición del evento.
- **AC-065-2** · `Seguridad` · **Dado** el evento registrado, **cuando** se inspecciona su contenido y el tráfico, **entonces** no incluye correo, nombre, teléfono, identificador de cuenta ni identificador publicitario del dispositivo.
- **AC-065-3** · `Integración` · **Dado** que el usuario no ha dado el consentimiento exigido, **cuando** toca "Más información", **entonces** WhatsApp se abre igualmente y no se envía el evento. **[A VALIDAR — D-12, R-07]** si el consentimiento es requerido y cómo se solicita.
- **AC-065-4** · `Integración` · **Dado** que el envío del evento falla, **cuando** el usuario toca "Más información", **entonces** WhatsApp se abre sin demora ni error visible.
- **AC-065-5** · `Manual` · **Dado** el período de un mes en staging con toques de prueba conocidos, **cuando** el administrador consulta el reporte agregado, **entonces** el conteo por producto coincide con los toques realizados. **[A VALIDAR — PA-08]** formato y herramienta del reporte.
- **AC-065-6** · `Integración` · **Dado** un dispositivo sin red al tocar "Más información", **cuando** se registra el evento, **entonces** el comportamiento (descartar o encolar) está definido. **[A VALIDAR — PA-08]**.

---

### Épica I — Sedes

#### US-072 · RF-072 · Listado de sedes por ciudad (Must)

- **AC-072-1** · `Integración` · **Dado** el listado de sedes, **cuando** carga, **entonces** las sedes aparecen agrupadas por ciudad y el número total de sedes mostradas coincide con el de la fuente de datos (a la fecha, 31 sedes en 9 ciudades según la web). **[A VALIDAR — D-07, D-09]** las cifras 31/32 sedes no concuerdan entre fuentes; se valida contra la fuente oficial que entregue IPR.
- **AC-072-2** · `Widget` · **Dado** una sede marcada "próximamente" (p. ej. Cartagena), **cuando** se renderiza, **entonces** muestra una etiqueta "Próximamente" visualmente distinta y no muestra botones de llamar, WhatsApp ni "Cómo llegar".
- **AC-072-3** · `Widget` · **Dado** una sede en operación, **cuando** el usuario la toca, **entonces** abre su ficha (US-073).
- **AC-072-4** · `Integración` · **Dado** un usuario sin sesión, **cuando** abre sedes, **entonces** funciona sin autenticación.
- **AC-072-5** · `Integración` · **Dado** que falla la carga de sedes, **cuando** se muestra el estado, **entonces** se aplica AC-009-1 a AC-009-3.
- **AC-072-6** · `Integración` · **Dado** una ciudad sin sedes en la fuente, **cuando** se carga el listado, **entonces** no aparece un grupo vacío para esa ciudad.

#### US-073 · RF-073 · Ficha de sede (Must)

- **AC-073-1** · `Widget` · **Dado** una sede con todos sus datos, **cuando** se abre su ficha, **entonces** muestra nombre, dirección, teléfonos (fijo/PBX, ventas de repuestos, ventas de aire acondicionado), WhatsApp e imagen.
- **AC-073-2** · `Widget` · **Dado** una sede sin alguno de los teléfonos, **cuando** se abre su ficha, **entonces** omite ese teléfono sin mostrar etiquetas vacías ni "null".
- **AC-073-3** · `Widget` · **Dado** una sede sin imagen, **cuando** se abre su ficha, **entonces** se muestra un marcador de posición.
- **AC-073-4** · `Manual` · **Dado** los datos de todas las sedes, **cuando** se revisan, **entonces** ningún dato corresponde a una persona (nombres de empleados, celulares personales, correos personales); solo canales corporativos (S-06). **[A VALIDAR — D-09, D-12]** confirmación de IPR de que los celulares publicados son canales corporativos.

#### US-074 · RF-074 · Llamar y escribir por WhatsApp a la sede (Must)

- **AC-074-1** · `Integración` · **Dado** la ficha de una sede en operación, **cuando** el usuario toca "Llamar", **entonces** se abre el marcador del dispositivo con el número de esa sede, sin marcar automáticamente.
- **AC-074-2** · `Integración` · **Dado** la ficha de una sede en operación, **cuando** el usuario toca "WhatsApp", **entonces** se abre WhatsApp con el número de WhatsApp de esa sede.
- **AC-074-3** · `Integración` · **Dado** un dispositivo sin WhatsApp, **cuando** se toca "WhatsApp", **entonces** se aplica AC-063-1 con el número de la sede.
- **AC-074-4** · `Widget` · **Dado** una sede sin número de WhatsApp en la fuente, **cuando** se renderiza su ficha, **entonces** no se muestra el botón de WhatsApp.
- **AC-074-5** · `Widget` · **Dado** una sede "próximamente", **cuando** se renderiza, **entonces** no se muestran los botones de llamar ni de WhatsApp (AC-072-2).

#### US-075 · RF-075 · "Cómo llegar" (Should)

- **AC-075-1** · `Integración` · **Dado** la ficha de una sede, **cuando** el usuario toca "Cómo llegar", **entonces** se abre la aplicación de mapas del dispositivo con una búsqueda por el texto de la dirección de esa sede (la web usa búsqueda de Google Maps por texto).
- **AC-075-2** · `Unitaria` · **Dado** una dirección con tildes, `#`, `&` y comas, **cuando** se construye el enlace, **entonces** va codificada y se decodifica a la dirección original.
- **AC-075-3** · `Integración` · **Dado** un dispositivo sin aplicación de mapas, **cuando** se toca "Cómo llegar", **entonces** se abre el mapa en el navegador y no se produce error.
- **AC-075-4** · `Seguridad` · **Dado** el uso de "Cómo llegar", **cuando** se revisan los permisos de la app, **entonces** no solicita permiso de ubicación (la sede cercana es fase 2, RF-078).
- **AC-075-5** · `Manual` · **Dado** una muestra de direcciones de sedes, **cuando** se abren en mapas, **entonces** se verifica a mano que el resultado ubica la sede correcta; se documenta la limitación de precisión por no haber coordenadas (RF-077 en fase 2).

#### US-076 · RF-076 · Fuente de sedes mantenible sin recompilar (Must)

- **AC-076-1** · `E2E` · **Dado** una sede nueva (o modificada) cargada por el administrador en la fuente definida, **cuando** transcurre el plazo de actualización, **entonces** la app la muestra sin haber publicado una nueva versión. **[A VALIDAR — D-09, PA-04]** mecanismo de la fuente (DESCONOCIDO) y plazo.
- **AC-076-2** · `Seguridad` · **Dado** el paquete de la app descompilado, **cuando** se busca una lista fija de sedes (direcciones, teléfonos), **entonces** no existe (los datos vienen del BFF).
- **AC-076-3** · `Integración` · **Dado** una sede marcada como próxima por el administrador, **cuando** llega a la app, **entonces** se muestra como "próximamente" (AC-072-2).
- **AC-076-4** · `Integración` · **Dado** una sede con un campo faltante o con formato inválido en la fuente, **cuando** el BFF la entrega, **entonces** la app la muestra sin fallar y omite solo el campo ausente.
- **AC-076-5** · `Integración` · **Dado** que la fuente de sedes no está disponible, **cuando** el usuario abre sedes, **entonces** se aplica AC-009-1 a AC-009-3.
- **AC-076-6** · `Integración` · **Dado** un cambio en la fuente, **cuando** el BFF lo entrega, **entonces** el contrato `/mobile/v1` de sedes no cambia de forma incompatible (pruebas de contrato de ADR-001).

---

### Épica J — Asesoría técnica

#### US-079 · RF-079 · Contenido de servicios de ingeniería (Should)

- **AC-079-1** · `Widget` · **Dado** la sección de asesoría técnica, **cuando** se abre, **entonces** muestra el contenido de los servicios de ingeniería de aire acondicionado y de refrigeración. **[A VALIDAR — ADR-001]** fuente del contenido (hoy está en el repositorio web; no hay API).
- **AC-079-2** · `Seguridad` · **Dado** contenido recibido como HTML, **cuando** se muestra, **entonces** cumple AC-027-1 (sin contenido activo).
- **AC-079-3** · `Widget` · **Dado** el contenido, **cuando** se muestra, **entonces** ofrece una acción de contacto (US-080).
- **AC-079-4** · `Widget` · **Dado** un usuario sin sesión, **cuando** abre la sección, **entonces** funciona sin autenticación.
- **AC-079-5** · `Manual` · **Dado** el contenido publicado, **cuando** se revisa, **entonces** no incluye nombres ni contactos personales de ingenieros (RF-080).

#### US-080 · RF-080 · Contacto de ingeniería por canal corporativo (Should)

- **AC-080-1** · `Widget` · **Dado** la sección de asesoría o ayuda, **cuando** se renderiza, **entonces** ofrece contacto por WhatsApp de asesoría, PBX o correo corporativo. **[A VALIDAR — PA-06]** si existe un canal corporativo propio de ingeniería; mientras no se confirme, se usa el WhatsApp de asesoría general (RF-094).
- **AC-080-2** · `Manual` · **Dado** todas las pantallas de la app, **cuando** se revisan, **entonces** no aparecen nombres, celulares ni correos de ingenieros individuales (la web actual los publica; no se replican, D-12).
- **AC-080-3** · `Integración` · **Dado** el canal de correo, **cuando** el usuario lo toca, **entonces** se abre el cliente de correo con el destinatario corporativo prellenado; si no hay cliente de correo, se muestra mensaje y se ofrece copiar la dirección. **[A VALIDAR — propuesta de PA nueva]** comportamiento sin cliente de correo.
- **AC-080-4** · `Integración` · **Dado** el canal de teléfono (PBX), **cuando** se toca, **entonces** se abre el marcador con el número sin marcar automáticamente.

---

### Épica K — Herramientas técnicas (calculadora BTU)

> **[A VALIDAR — D-08]** Toda la épica está condicionada a que Ingeniería IPR valide la fórmula, rangos y texto de descargo. Los valores esperados de abajo se derivan de la fórmula del informe de código (COD §6) y **no se publican** sin aprobación de Ingeniería. Si D-08 no se cierra, el módulo sale del MVP y estos criterios se difieren.

#### US-085 · RF-085 · Entradas y validación de rangos (Should)

- **AC-085-1** · `Widget` · **Dado** la calculadora, **cuando** se abre, **entonces** pide largo, ancho, alto, número de ocupantes, número de equipos y clima (frío, templado, cálido).
- **AC-085-2** · `Unitaria` · **Dado** los valores límite, **cuando** se validan, **entonces** se aceptan: largo 1 y 15 m, ancho 1 y 15 m, alto 2 y 4 m, ocupantes 1 y 10, equipos 0 y 10; y se rechazan: largo o ancho 0,9 y 15,1; alto 1,9 y 4,1; ocupantes 0 y 11; equipos -1 y 11.
- **AC-085-3** · `Unitaria` · **Dado** un campo vacío o con texto no numérico, **cuando** el usuario pulsa "Calcular", **entonces** se muestra el error en ese campo y no se calcula.
- **AC-085-4** · `Unitaria` · **Dado** valores decimales para ocupantes o equipos (p. ej. 2,5), **cuando** se validan, **entonces** se rechazan como no enteros. **[A VALIDAR — D-08]** confirmar que ocupantes y equipos son enteros.
- **AC-085-5** · `Unitaria` · **Dado** el valor de alto "2,5" y "2.5", **cuando** se validan, **entonces** el comportamiento ante coma y punto decimal es el mismo y documentado. **[A VALIDAR — propuesta de PA nueva]** formato decimal (configuración regional es-CO).
- **AC-085-6** · `Widget` · **Dado** los campos de entrada, **cuando** se abre la calculadora, **entonces** el clima tiene un valor inicial definido. **[A VALIDAR — D-08]** valor por defecto y valores iniciales de los demás campos.
- **AC-085-7** · `Widget` · **Dado** un usuario sin sesión, **cuando** usa la calculadora, **entonces** funciona sin autenticación y sin red (el cálculo es local; la fórmula no requiere servidor). **[A VALIDAR — propuesta de PA nueva]** si la fórmula debe vivir en el cliente o en el BFF.

#### US-086 · RF-086 · Resultado según la fórmula vigente (Should)

Fórmula de referencia (COD §6): `area = largo × ancho`; `requerido = area × 600`; si `alto > 2,5`: `requerido ×= 1 + ceil((alto − 2,5) / 0,5) × 0,10`; `requerido += max(0, ocupantes − 2) × 600`; `requerido ×= factor_clima` (frío 1,00 · templado 1,05 · cálido 1,15); `requerido += equipos × 600`; `sugerido` = menor capacidad ≥ requerido entre 9.000, 12.000, 18.000, 24.000 y 36.000 BTU.

- **AC-086-1** · `Unitaria` · **Dado** cada caso de la tabla siguiente, **cuando** se calcula, **entonces** el requerido y el sugerido coinciden con los esperados (el requerido con tolerancia de ±1 BTU por redondeo de punto flotante). **[A VALIDAR — D-08]** valores validados por Ingeniería.

| Caso | Largo × Ancho × Alto (m) | Ocupantes | Equipos | Clima | Requerido esperado (BTU) | Sugerido esperado |
|---|---|---|---|---|---|---|
| T1 | 3 × 4 × 2,5 | 2 | 0 | Frío | 7.200 | 9.000 |
| T2 | 3 × 5 × 2,5 | 2 | 0 | Frío | 9.000 (igual a una capacidad) | 9.000 |
| T3 | 4 × 5 × 2,5 | 2 | 0 | Templado | 12.600 | 18.000 |
| T4 | 5 × 5 × 3,0 | 4 | 2 | Cálido | 21.555 | 24.000 |
| T5 | 3 × 4 × 3,2 | 2 | 0 | Frío | 8.640 | 9.000 |
| T6 | 3 × 4 × 4,0 | 2 | 0 | Frío | 9.360 | 12.000 |
| T7 | 3 × 4 × 2,5 | 1 | 0 | Frío | 7.200 (ocupantes < 2 no restan) | 9.000 |
| T8 | 12 × 5 × 2,5 | 2 | 0 | Frío | 36.000 (igual al máximo) | 36.000 |
| T9 | 12 × 5 × 2,5 | 2 | 1 | Frío | 36.600 | Sin sugerencia (AC-088-1) |
| T10 | 15 × 15 × 4,0 | 10 | 10 | Cálido | Muy superior a 36.000 | Sin sugerencia (AC-088-1) |

- **AC-086-2** · `Unitaria` · **Dado** un requerido exactamente igual a una capacidad comercial (T2, T8), **cuando** se elige la sugerida, **entonces** se sugiere esa misma capacidad (criterio ≥, no >).
- **AC-086-3** · `Unitaria` · **Dado** dos entradas idénticas salvo un área mayor, **cuando** se calculan, **entonces** la capacidad sugerida de la mayor nunca es menor (monotonía).
- **AC-086-4** · `Unitaria` · **Dado** un alto de exactamente 2,5 m, **cuando** se calcula, **entonces** no se aplica el recargo por altura; con 2,51 m se aplica `ceil(0,01/0,5) × 0,10 = 0,10`.
- **AC-086-5** · `Unitaria` · **Dado** los mismos datos de entrada en la web y en la app, **cuando** se comparan 20 combinaciones aleatorias con semilla fija, **entonces** los resultados son idénticos. **[A VALIDAR — D-08]** si la web actual sigue siendo la referencia.

#### US-087 · RF-087 · Aviso de estimación (Must)

- **AC-087-1** · `Widget` · **Dado** un resultado calculado, **cuando** se muestra, **entonces** el aviso de que es una estimación está visible en la misma pantalla del resultado, sin acción adicional del usuario. **[A VALIDAR — D-08]** texto exacto aprobado por Ingeniería.
- **AC-087-2** · `Widget` · **Dado** un resultado sin capacidad sugerida (superior a 36.000 BTU), **cuando** se muestra, **entonces** el aviso de estimación también aparece.
- **AC-087-3** · `Manual` · **Dado** el texto del aviso, **cuando** se revisa, **entonces** coincide literalmente con el aprobado.

#### US-088 · RF-088 · Más de 36.000 BTU (Must)

- **AC-088-1** · `Widget` · **Dado** un requerido mayor que 36.000 BTU (T9, T10), **cuando** se muestra el resultado, **entonces** la app informa que supera la capacidad máxima sugerible (36.000 BTU) y ofrece contactar a un asesor; no muestra "0 BTU", valor vacío ni "undefined".
- **AC-088-2** · `Integración` · **Dado** esa pantalla, **cuando** el usuario toca "Contactar a un asesor", **entonces** se abre el canal de US-080 (o WhatsApp de asesoría, RF-094) con mensaje prellenado que incluye el requerido calculado. **[A VALIDAR — propuesta de PA nueva]** si el mensaje debe incluir el valor.
- **AC-088-3** · `Widget` · **Dado** el caso sin sugerencia, **cuando** se muestra, **entonces** no aparece el enlace al catálogo filtrado (AC-089-4).
- **AC-088-4** · `Unitaria` · **Dado** un requerido de 36.000 BTU exactos (T8), **cuando** se muestra, **entonces** se sugiere 36.000 BTU y no el mensaje de exceso.

#### US-089 · RF-089 · Enlace al catálogo filtrado por la capacidad sugerida (Should)

- **AC-089-1** · `Integración` · **Dado** una capacidad sugerida (p. ej. 12.000 BTU), **cuando** el usuario toca "Ver equipos", **entonces** se abre el listado de productos filtrado por el atributo "capacidad BTU = 12.000" (en la web, `filter_capacidad-btu=<n>-000-btu`).
- **AC-089-2** · `Integración` · **Dado** el listado abierto desde la calculadora, **cuando** se revisa, **entonces** todos los productos mostrados tienen esa capacidad y el filtro aplicado es visible y removible (AC-013-3).
- **AC-089-3** · `Integración` · **Dado** que no hay productos con esa capacidad, **cuando** se abre el listado, **entonces** se muestra el estado vacío con la opción de WhatsApp (AC-023-1).
- **AC-089-4** · `Widget` · **Dado** un resultado sin capacidad sugerida, **cuando** se muestra, **entonces** el enlace al catálogo no se ofrece.
- **AC-089-5** · `Integración` · **Dado** una capacidad sugerida para cada una de las cinco capacidades comerciales (9.000, 12.000, 18.000, 24.000, 36.000), **cuando** se sigue el enlace, **entonces** el filtro se construye con el valor correcto en cada caso. **[A VALIDAR — D-10, RF-014]** disponibilidad del atributo en el catálogo.

---

### Épica M — Atención al cliente

#### US-094 · RF-094 · WhatsApp de atención desde menú o ayuda (Must)

- **AC-094-1** · `Widget` · **Dado** el menú y la pantalla de Ayuda, **cuando** se renderizan, **entonces** ambos incluyen un acceso a WhatsApp de atención.
- **AC-094-2** · `Integración` · **Dado** WhatsApp instalado, **cuando** el usuario toca el acceso, **entonces** se abre la línea nacional con el mensaje prellenado institucional. **[A VALIDAR — PA-07]** número y texto vigentes.
- **AC-094-3** · `Integración` · **Dado** un dispositivo sin WhatsApp, **cuando** se toca, **entonces** se aplica AC-063-1.
- **AC-094-4** · `Manual` · **Dado** las pantallas de la app, **cuando** se revisan, **entonces** no se promete un tiempo de respuesta. **[A VALIDAR — PA-07]** hasta que se defina el SLA y los responsables.
- **AC-094-5** · `Widget` · **Dado** un visitante sin sesión, **cuando** toca el acceso, **entonces** funciona sin autenticación.

#### US-095 · RF-095 · Pantalla de Ayuda y contacto (Should)

- **AC-095-1** · `Widget` · **Dado** la pantalla de Ayuda, **cuando** se abre, **entonces** agrupa: WhatsApp, PQRS, teléfono de atención, correo de ventas institucional y sedes.
- **AC-095-2** · `Integración` · **Dado** cada acceso, **cuando** se toca, **entonces** realiza su acción: WhatsApp (AC-094-2), PQRS (abre el formulario), teléfono (marcador sin marcar automáticamente), correo (`mailto:` al correo institucional) y sedes (abre el listado).
- **AC-095-3** · `Manual` · **Dado** la pantalla de Ayuda, **cuando** se revisa, **entonces** no contiene nombres, celulares ni correos de personas (S-06, D-12).
- **AC-095-4** · `Widget` · **Dado** un visitante sin sesión, **cuando** abre Ayuda, **entonces** funciona sin autenticación.

#### US-096 · RF-096 · Formulario PQRS (Must)

- **AC-096-1** · `Widget` · **Dado** el formulario, **cuando** se abre, **entonces** ofrece tipo (Petición, Queja, Reclamo, Sugerencia), nombre, correo, celular, pedido/factura (opcional) y mensaje, con contador de caracteres del mensaje.
- **AC-096-2** · `Unitaria` · **Dado** los límites del contrato de la web, **cuando** se validan, **entonces**: nombre de 2 caracteres se rechaza y de 3 a 120 se acepta; correo inválido o de más de 254 caracteres se rechaza; celular fuera de 7–20 caracteres o con letras se rechaza; pedido/factura de 61 caracteres se rechaza; mensaje vacío o de 1.001 caracteres se rechaza y de 1 a 1.000 se acepta.
- **AC-096-3** · `Widget` · **Dado** un mensaje de exactamente 1.000 caracteres, **cuando** el usuario intenta escribir el 1.001, **entonces** no se admite el carácter y el contador muestra 1.000/1.000.
- **AC-096-4** · `Integración` · **Dado** un formulario válido, **cuando** el usuario toca "Enviar", **entonces** se emite una solicitud y se muestra la confirmación de envío ("Su solicitud fue enviada correctamente…" o texto aprobado), y el formulario se limpia.
- **AC-096-5** · `Widget` · **Dado** una solicitud en curso, **cuando** el usuario toca dos veces "Enviar", **entonces** se emite exactamente una solicitud y llega una sola PQRS al buzón.
- **AC-096-6** · `Seguridad` · **Dado** más envíos que el límite por origen en la ventana (en la web actual: 5 por IP cada 10 min), **cuando** se supera, **entonces** el servidor responde 429 con `Retry-After` y la app muestra "Demasiadas solicitudes, inténtelo de nuevo en unos minutos". **[A VALIDAR — propuesta de PA nueva]** valor del límite y controles anti-spam adicionales en la app (captcha o equivalente) más allá del límite por IP.
- **AC-096-7** · `Integración` · **Dado** un dispositivo sin red, **cuando** se envía, **entonces** se muestra mensaje de falta de conexión y todos los campos conservan lo escrito; no se presenta como enviado.
- **AC-096-8** · `Integración` · **Dado** que el servicio de correo falla (500), **cuando** se envía, **entonces** se muestra "No se pudo enviar, intente más tarde", los datos se conservan y no se presenta como enviado.
- **AC-096-9** · `Seguridad` · **Dado** un nombre con saltos de línea y comillas (p. ej. `Ana\r\nBcc: x@y.com`) y un mensaje con HTML (`<script>`), **cuando** se envía, **entonces** el correo recibido no tiene cabeceras inyectadas ni ejecuta HTML (todo escapado).
- **AC-096-10** · `Widget` · **Dado** un usuario sin sesión, **cuando** envía una PQRS, **entonces** funciona sin autenticación.
- **AC-096-11** · `Widget` · **Dado** el formulario, **cuando** se muestra, **entonces** incluye un aviso o enlace a la política de tratamiento de datos antes del envío. **[A VALIDAR — D-12]** si Jurídico exige aviso o aceptación en este formulario (el formulario recoge nombre, correo y teléfono).
- **AC-096-12** · `Seguridad` · **Dado** el envío, **cuando** se inspeccionan logs y almacenamiento de la app, **entonces** nombre, correo, teléfono y mensaje no quedan guardados tras el envío ni aparecen en logs.

#### US-097 · RF-097 · PQRS llega al buzón corporativo; límite en almacén compartido (Must)

- **AC-097-1** · `E2E` · **Dado** una PQRS enviada en staging, **cuando** se revisa el buzón corporativo de PQRS, **entonces** llega un correo con asunto `[PQRS] <tipo> — <nombre>` que contiene tipo, nombre, correo, teléfono, pedido/factura, mensaje y fecha-hora (zona America/Bogota).
- **AC-097-2** · `E2E` · **Dado** el correo recibido, **cuando** el asesor responde, **entonces** la respuesta va al correo del solicitante (Reply-To).
- **AC-097-3** · `Integración` · **Dado** dos instancias del BFF, **cuando** se envían 6 PQRS alternadas desde el mismo origen con límite de 5, **entonces** la sexta se rechaza con 429 (contador compartido).
- **AC-097-4** · `Integración` · **Dado** el límite alcanzado, **cuando** se reinicia el proceso del BFF, **entonces** el contador no se reinicia (no depende de la memoria de un solo proceso).
- **AC-097-5** · `Integración` · **Dado** el BFF detrás de un proxy, **cuando** se aplica el límite, **entonces** se identifica la IP real del cliente móvil y no la del proxy ni la de Cloudflare. **[A VALIDAR — propuesta de PA nueva]** cabecera de confianza.
- **AC-097-6** · `Manual` · **Dado** el buzón destino, **cuando** se revisa la configuración, **entonces** es el buzón corporativo de PQRS definido por IPR (configurable, no fijo en la app). **[A VALIDAR — PA-07]** responsables y SLA de atención.

#### US-099 · RF-099 · Páginas legales accesibles (Must)

- **AC-099-1** · `Widget` · **Dado** la pantalla de registro, **cuando** se muestra, **entonces** los términos y condiciones y la política de tratamiento de datos son accesibles por enlace antes de registrarse, sin iniciar sesión.
- **AC-099-2** · `Widget` · **Dado** el menú de la app, **cuando** se abre, **entonces** incluye acceso a términos, política de datos y las demás páginas legales publicadas.
- **AC-099-3** · `Integración` · **Dado** cada enlace legal, **cuando** se abre, **entonces** el documento carga y es legible (HTTP 200, contenido no vacío); una prueba automática verifica todos los enlaces.
- **AC-099-4** · `Manual` · **Dado** el documento legal mostrado, **cuando** se compara con la versión publicada por IPR, **entonces** coincide con la versión vigente. **[A VALIDAR — D-12]** versión vigente y fuente (los PDF legales no han sido leídos).
- **AC-099-5** · `Integración` · **Dado** que el documento no carga (sin red), **cuando** el usuario lo abre, **entonces** se muestra el error con "Reintentar" (AC-009-1).
- **AC-099-6** · `Manual` · **Dado** la publicación en tiendas, **cuando** se prepara la ficha, **entonces** existe una URL pública de política de privacidad válida (S-05). **[A VALIDAR — S-05]** verificar las guías vigentes de Apple y Google.
- **AC-099-7** · `Seguridad` · **Dado** un documento legal abierto, **cuando** se inspecciona, **entonces** se abre en visor seguro o navegador del sistema, no en un WebView con JavaScript habilitado y acceso a la app.

---

### Épica N — Perfil y cuenta (historias críticas)

#### US-104 · RF-104 · Ver y editar nombre, apellido y correo (Must)

- **AC-104-1** · `Integración` · **Dado** un cliente con sesión, **cuando** abre su perfil, **entonces** ve nombre, apellido y correo tal como están en el servidor.
- **AC-104-2** · `Integración` · **Dado** un cambio de nombre o apellido, **cuando** guarda, **entonces** el servidor lo almacena y el perfil muestra los nuevos valores tras recargar.
- **AC-104-3** · `Seguridad` · **Dado** un cambio de correo, **cuando** el usuario intenta guardar sin contraseña actual, **entonces** el formulario no lo permite y no se emite la solicitud; con la contraseña actual incorrecta, el servidor rechaza el cambio, el correo no cambia y se muestra mensaje genérico.
- **AC-104-4** · `Seguridad` · **Dado** un cambio de correo con contraseña actual correcta, **cuando** se completa, **entonces** el token anterior queda invalidado (usarlo devuelve 401), el servidor emite una sesión nueva, la app reemplaza el token en Keystore/Keychain y el usuario sigue autenticado sin volver a iniciar sesión.
- **AC-104-5** · `Unitaria` · **Dado** un correo nuevo con formato inválido, **cuando** se intenta guardar, **entonces** se muestra el error y no se emite solicitud.
- **AC-104-6** · `Integración` · **Dado** un correo nuevo que ya pertenece a otra cuenta, **cuando** se guarda, **entonces** se rechaza con un mensaje definido. **[A VALIDAR — PA-02]** equilibrio entre no revelar existencia de cuentas (RF-045) y claridad para el usuario.
- **AC-104-7** · `Seguridad` · **Dado** el cambio de correo, **cuando** se inspeccionan logs, almacenamiento y tráfico, **entonces** la contraseña actual viaja solo en el cuerpo por HTTPS y no queda en logs ni almacenamiento.
- **AC-104-8** · `Widget` · **Dado** una actualización en curso, **cuando** el usuario toca dos veces "Guardar", **entonces** se emite una sola solicitud.
- **AC-104-9** · `Integración` · **Dado** un dispositivo sin red, **cuando** guarda cambios, **entonces** se muestra mensaje de falta de conexión y los cambios escritos se conservan en pantalla sin aplicarse.
- **AC-104-10** · `Integración` · **Dado** un cambio de correo, **cuando** otro dispositivo con sesión usa su token, **entonces** se aplica la política definida. **[A VALIDAR — propuesta de PA nueva]** (ver AC-043-6).

#### US-105 · RF-105 · Cambio de contraseña exigiendo la actual (Must)

- **AC-105-1** · `Widget` · **Dado** el formulario, **cuando** se abre, **entonces** pide contraseña actual, contraseña nueva y confirmación de la nueva, todas enmascaradas.
- **AC-105-2** · `Seguridad` · **Dado** una contraseña actual incorrecta, **cuando** se envía, **entonces** el servidor rechaza el cambio, la contraseña no cambia y el mensaje no revela detalles internos.
- **AC-105-3** · `Seguridad` · **Dado** una solicitud de cambio sin el campo de contraseña actual (manipulada), **cuando** llega al servidor, **entonces** se rechaza (el requisito vive en el servidor, SEC-03).
- **AC-105-4** · `Unitaria` · **Dado** una contraseña nueva de 7 caracteres, o una confirmación distinta, **cuando** se intenta guardar, **entonces** se rechaza con mensaje y no se emite solicitud; con 8 caracteres y confirmación igual se acepta.
- **AC-105-5** · `Seguridad` · **Dado** un cambio exitoso, **cuando** se completa, **entonces** el servidor emite un token nuevo, la app lo guarda en Keystore/Keychain y sigue autenticada, y el token anterior devuelve 401.
- **AC-105-6** · `Seguridad` · **Dado** intentos repetidos de contraseña actual incorrecta, **cuando** se supera el umbral, **entonces** se aplica el límite de RF-045 (429). **[A VALIDAR — R-02]** umbral.
- **AC-105-7** · `Seguridad` · **Dado** el flujo, **cuando** se inspeccionan logs, almacenamiento, reportes de fallos y tráfico, **entonces** ninguna contraseña (actual ni nueva) aparece fuera del cuerpo de la solicitud HTTPS.
- **AC-105-8** · `Widget` · **Dado** una solicitud en curso, **cuando** el usuario toca dos veces "Guardar", **entonces** se emite una sola solicitud.
- **AC-105-9** · `Integración` · **Dado** una contraseña nueva idéntica a la actual, **cuando** se envía, **entonces** el comportamiento está definido. **[A VALIDAR — propuesta de PA nueva]**.
- **AC-105-10** · `Integración` · **Dado** otros dispositivos con sesión, **cuando** se cambia la contraseña, **entonces** se aplica la política definida. **[A VALIDAR — propuesta de PA nueva]** (ver AC-043-6).

#### US-106 · RF-106 · Direcciones de facturación y envío (Should)

- **AC-106-1** · `Widget` · **Dado** el perfil, **cuando** se abre la gestión de direcciones, **entonces** hay una dirección de facturación y una de envío con cédula/NIT, nombre, apellidos, dirección, departamento, ciudad y teléfono.
- **AC-106-2** · `Unitaria` · **Dado** las reglas del contrato de dirección existente (`checkout-schema`), **cuando** se validan, **entonces**: cédula/NIT de 3 a 30 caracteres con solo dígitos, guiones o puntos; nombre y apellidos máximo 60; dirección máximo 200; departamento de la lista oficial; ciudad máximo 80; teléfono de 7 a 20 con el patrón válido. **[A VALIDAR — propuesta de PA nueva]** qué campos son obligatorios en el perfil (el contrato web marca como opcionales empresa, dirección 2 y código postal).
- **AC-106-3** · `Widget` · **Dado** el selector de ubicación, **cuando** se usa, **entonces** solo permite Colombia y la ciudad depende del departamento elegido.
- **AC-106-4** · `Integración` · **Dado** una dirección guardada, **cuando** el cliente inicia una compra, **entonces** el checkout se prellena con ella (AC-054-1).
- **AC-106-5** · `Seguridad` · **Dado** datos de cédula/NIT, teléfono y dirección, **cuando** se inspeccionan almacenamiento local, logs y reportes de fallos, **entonces** no hay copias sin cifrar (lección SEC-08 del `localStorage` de la web).
- **AC-106-6** · `Seguridad` · **Dado** un token de otro usuario o un identificador manipulado, **cuando** se solicita o modifica una dirección, **entonces** el servidor solo opera sobre la cuenta del token y rechaza el resto (403/404).
- **AC-106-7** · `Widget` · **Dado** una solicitud de guardado en curso, **cuando** el usuario toca dos veces "Guardar", **entonces** se emite una sola solicitud.
- **AC-106-8** · `Integración` · **Dado** un dispositivo sin red, **cuando** guarda, **entonces** se muestra mensaje de falta de conexión y se conservan los datos escritos.

#### US-107 · RF-107 · Historial de pedidos (Must)

- **AC-107-1** · `Integración` · **Dado** un cliente con pedidos, **cuando** abre el historial, **entonces** cada pedido muestra número, fecha, estado (etiqueta del servidor) y total en COP.
- **AC-107-2** · `Seguridad` · **Dado** un token del usuario A, **cuando** consulta el historial, **entonces** la respuesta contiene solo pedidos de A; con el identificador de un pedido de B, el servidor responde 403/404 y no devuelve datos.
- **AC-107-3** · `Widget` · **Dado** un cliente sin pedidos, **cuando** abre el historial, **entonces** se muestra un estado vacío con acción hacia el catálogo.
- **AC-107-4** · `E2E` · **Dado** un pedido recién pagado en staging, **cuando** el cliente abre el historial, **entonces** aparece con el número y estado correctos.
- **AC-107-5** · `Integración` · **Dado** un visitante sin sesión, **cuando** intenta abrir el historial, **entonces** se le pide iniciar sesión.
- **AC-107-6** · `Integración` · **Dado** un token expirado, **cuando** abre el historial, **entonces** se renueva (AC-044-3) o se pide reautenticación (AC-044-5) sin perder el carrito.
- **AC-107-7** · `Integración` · **Dado** un cliente con muchos pedidos, **cuando** abre el historial, **entonces** se muestran en orden definido y con paginación. **[A VALIDAR — propuesta de PA nueva]** orden y tamaño de página (no definidos).
- **AC-107-8** · `Unitaria` · **Dado** el total de un pedido del servidor, **cuando** se muestra, **entonces** coincide exactamente con el valor recibido (la app no lo recalcula).
- **AC-107-9** · `Integración` · **Dado** que falla la carga, **cuando** se muestra el estado, **entonces** se aplica AC-009-1 a AC-009-3.

#### US-108 · RF-108 · Detalle de pedido (Should)

- **AC-108-1** · `Integración` · **Dado** un pedido del cliente, **cuando** abre su detalle, **entonces** muestra los productos con nombre, cantidad y total por línea, subtotal, total y método de pago.
- **AC-108-2** · `Widget` · **Dado** el detalle, **cuando** se renderiza, **entonces** no muestra imagen de producto, costo de envío, tracking ni dirección (el pedido actual no trae esos datos; RF-109 es fase 2) y no muestra campos vacíos ni ceros por ellos.
- **AC-108-3** · `Seguridad` · **Dado** el identificador de un pedido de otro usuario, **cuando** se consulta el detalle, **entonces** el servidor responde 403/404 sin datos ni indicios de que exista.
- **AC-108-4** · `Unitaria` · **Dado** subtotal y total del servidor, **cuando** se muestran, **entonces** coinciden con los recibidos y con los del pedido en WooCommerce.
- **AC-108-5** · `Widget` · **Dado** un producto con nombre largo, **cuando** se renderiza la línea, **entonces** el texto se ajusta sin desbordar en pantallas de 360 dp de ancho.
- **AC-108-6** · `Integración` · **Dado** un estado de pedido, **cuando** se muestra, **entonces** usa la etiqueta del servidor (`statusLabel`). **[A VALIDAR — PA-12]** estados reales.

#### US-110 · RF-110 · Eliminación de cuenta (Must, crítica)

- **AC-110-1** · `Widget` · **Dado** un cliente con sesión, **cuando** abre su perfil, **entonces** encuentra la opción "Eliminar cuenta" accesible desde su perfil, sin pasos ocultos.
- **AC-110-2** · `Widget` · **Dado** que toca "Eliminar cuenta", **cuando** se muestra la confirmación, **entonces** informa qué datos se eliminan y cuáles se conservan y por cuánto tiempo, y exige una confirmación explícita (no se elimina con un solo toque). **[A VALIDAR — PA-09, D-12]** texto, datos conservados (pedidos y soporte tributario) y plazos (DESCONOCIDOS).
- **AC-110-3** · `Seguridad` · **Dado** la confirmación de eliminación, **cuando** el usuario la acepta, **entonces** se le pide su contraseña actual y sin ella la solicitud no se emite. **[A VALIDAR — propuesta de PA nueva]** reautenticación exigida para esta acción.
- **AC-110-4** · `E2E` · **Dado** una eliminación confirmada en staging, **cuando** el servidor responde éxito, **entonces** la cuenta queda eliminada o anonimizada según la política, las sesiones de todos los dispositivos quedan revocadas (los tokens devuelven 401), los tokens y datos locales del dispositivo se borran, y la app vuelve a modo visitante. **[A VALIDAR — PA-09]** eliminación inmediata o diferida.
- **AC-110-5** · `Integración` · **Dado** una cuenta eliminada, **cuando** se intenta iniciar sesión con sus credenciales anteriores, **entonces** falla con el mismo mensaje genérico de credenciales inválidas.
- **AC-110-6** · `Integración` · **Dado** una cuenta eliminada, **cuando** se intenta registrar de nuevo con el mismo correo, **entonces** el comportamiento queda definido. **[A VALIDAR — PA-09]**.
- **AC-110-7** · `Integración` · **Dado** un cliente con pedidos, **cuando** elimina su cuenta, **entonces** los pedidos se conservan, anonimizan o eliminan conforme a la política. **[A VALIDAR — PA-09]** (Finanzas/Jurídico).
- **AC-110-8** · `Integración` · **Dado** un cliente con un pedido pendiente de pago o en curso, **cuando** intenta eliminar la cuenta, **entonces** se aplica la regla definida (bloquear, advertir o permitir). **[A VALIDAR — PA-09]**.
- **AC-110-9** · `Integración` · **Dado** un dispositivo sin red o un error del servidor, **cuando** se confirma la eliminación, **entonces** se informa que no se completó, la cuenta sigue activa y el usuario puede reintentar; la app no queda en un estado ambiguo.
- **AC-110-10** · `Widget` · **Dado** una eliminación en curso, **cuando** el usuario toca dos veces el botón final, **entonces** se emite exactamente una solicitud.
- **AC-110-11** · `Integración` · **Dado** el diálogo de confirmación, **cuando** el usuario cancela, **entonces** no se emite solicitud y la cuenta no cambia.
- **AC-110-12** · `Seguridad` · **Dado** el endpoint de eliminación, **cuando** se llama sin token o con token inválido o expirado, **entonces** responde 401 y no elimina nada.
- **AC-110-13** · `Seguridad` · **Dado** la solicitud de eliminación, **cuando** se inspecciona, **entonces** no contiene identificador de cuenta controlable por el cliente: el servidor elimina únicamente la cuenta dueña del token (no se puede borrar la cuenta de otro usuario).
- **AC-110-14** · `Seguridad` · **Dado** intentos repetidos de eliminación con contraseña incorrecta, **cuando** se supera el umbral, **entonces** se aplica el límite de RF-045. **[A VALIDAR — R-02]** umbral.
- **AC-110-15** · `Seguridad` · **Dado** la eliminación completada, **cuando** se inspeccionan logs y analítica, **entonces** no hay datos personales de la cuenta eliminada, salvo el registro mínimo de auditoría que defina Jurídico. **[A VALIDAR — D-12]**.
- **AC-110-16** · `Manual` · **Dado** el envío a tiendas, **cuando** se revisan las guías vigentes de Apple y Google, **entonces** se confirma que el flujo cumple el requisito de eliminación de cuenta dentro de la app (S-05). **[A VALIDAR — S-05]** vigencia.

#### US-111 · RF-111 · Canal para derechos del titular (Should)

- **AC-111-1** · `Widget` · **Dado** el perfil de un cliente con sesión, **cuando** se abre, **entonces** existe un acceso "Derechos sobre mis datos" que lleva al canal definido para consulta, rectificación y supresión.
- **AC-111-2** · `Integración` · **Dado** el canal definido (correo, formulario o PQRS), **cuando** el usuario lo usa, **entonces** la solicitud llega al destinatario corporativo con el tipo de derecho elegido y se muestra confirmación. **[A VALIDAR — D-12]** canal vigente (DESCONOCIDO).
- **AC-111-3** · `Widget` · **Dado** la pantalla del canal, **cuando** se muestra, **entonces** informa que la supresión de la cuenta puede hacerse directamente desde la app (US-110).
- **AC-111-4** · `Seguridad` · **Dado** la solicitud de derechos, **cuando** se envía, **entonces** solo solicita los datos personales necesarios para atenderla y no los guarda en el dispositivo tras el envío.
- **AC-111-5** · `Integración` · **Dado** un dispositivo sin red, **cuando** se envía la solicitud, **entonces** se muestra mensaje de falta de conexión y se conserva lo escrito.

---

## 2. Criterios transversales de seguridad y privacidad (AC-SEC)

Aplican a toda la app. Se verifican en cada versión candidata y antes de la salida del MVP (ver [alcance](../01_business/scope.md) §8).

- **AC-SEC-1** · `Seguridad` · **Dado** el binario empaquetado (APK/AAB e IPA) descompilado, **cuando** se buscan claves de WooCommerce (`ck_`, `cs_`), `HANDOFF_SECRET`, `X-IPR-Secret`, credenciales SMTP, claves de Wompi privadas o archivos `.env`, **entonces** hay 0 coincidencias (ADR-001 verificación; RF-052, RF-053).
- **AC-SEC-2** · `Seguridad` · **Dado** una sesión de uso completa capturada con proxy, **cuando** se listan los hosts y rutas, **entonces** la app solo llama a `/mobile/v1` (y a los servicios del sistema: WhatsApp, mapas, teléfono, navegador seguro); no hay llamadas a `wc/v3`, `wp/v2` ni a las rutas `/api/*` del sitio (ADR-001).
- **AC-SEC-3** · `Seguridad` · **Dado** la configuración de red de la app, **cuando** se intenta una conexión HTTP sin cifrar, **entonces** el sistema la bloquea (Android Network Security Config; iOS App Transport Security) y todo el tráfico es HTTPS. **[A VALIDAR — propuesta de PA nueva]** si se exige fijación de certificado (certificate pinning).
- **AC-SEC-4** · `Seguridad` · **Dado** compilaciones de depuración y de producción, **cuando** se revisan logs del sistema, reportes de fallos y analítica durante registro, login, checkout y perfil, **entonces** no aparecen tokens, contraseñas, tickets, datos de pago ni datos personales (cédula/NIT, teléfono, dirección).
- **AC-SEC-5** · `Seguridad` · **Dado** cualquier solicitud autenticada, **cuando** se inspecciona, **entonces** el token va únicamente en `Authorization` (nunca en la URL ni en el cuerpo de una URL de redirección) y se almacena solo en Keystore/Keychain.
- **AC-SEC-6** · `Seguridad` · **Dado** el carrito, el checkout y los pedidos, **cuando** se inspeccionan las solicitudes y el almacenamiento, **entonces** ningún precio, total, impuesto, envío o descuento calculado en el cliente se envía al servidor ni se usa como autoridad de cobro; los importes los calcula WooCommerce (RF-050, RF-052).
- **AC-SEC-7** · `Seguridad` · **Dado** el mismo producto consultado por un visitante y por un cliente registrado, **cuando** se comparan las respuestas de `/mobile/v1`, **entonces** el precio es idéntico y no existen campos de precio por rol ni rol B2B (ADR-002 verificación; S-04).
- **AC-SEC-8** · `Seguridad` · **Dado** los endpoints de perfil, direcciones, pedidos y eliminación de cuenta, **cuando** se intenta acceder con el identificador de un recurso de otro usuario, **entonces** el servidor responde 403/404 sin datos (control de acceso a nivel de objeto).
- **AC-SEC-9** · `Seguridad` · **Dado** un token inválido, manipulado, de otra cuenta o expirado, **cuando** se presenta a cualquier ruta autenticada de `/mobile/v1`, **entonces** la respuesta es 401 (ADR-001 verificación).
- **AC-SEC-10** · `Seguridad` · **Dado** el manifiesto de permisos de la app en el MVP, **cuando** se revisa, **entonces** no solicita ubicación, contactos, cámara, micrófono ni notificaciones push (todo ello es fase 2).
- **AC-SEC-11** · `Seguridad` · **Dado** una cuenta cuya sesión se cierra o se elimina, **cuando** se inspecciona el dispositivo, **entonces** no quedan datos personales ni tokens (AC-041-3/4, AC-110-4).
- **AC-SEC-12** · `Seguridad` · **Dado** cualquier contenido HTML recibido (descripciones, contenido de ingeniería), **cuando** se muestra, **entonces** no ejecuta scripts ni contenido activo (AC-027-1).
- **AC-SEC-13** · `Seguridad` · **Dado** el flujo completo de pago, **cuando** se revisa, **entonces** la app abre el checkout solo en el navegador seguro del sistema y nunca en un WebView propio con acceso a tokens (AC-052-3).

---

## 3. Trazabilidad RF → US → AC (MVP)

La tabla se genera a partir de los encabezados de este documento: cada historia `US-xxx` tiene su RF-xxx y sus criterios `AC-xxx-n`. La verificación automática de cobertura (cada RF marcado MVP tiene su US y su sección de AC) se documenta en el informe de entrega.

| Épica | Historias | Criterios |
|---|---|---|
| A. Inicio | US-001 a US-007, US-009 | AC-001-n a AC-007-n, AC-009-n |
| B. Catálogo | US-010 a US-016, US-018, US-019 | AC-010-n a AC-016-n, AC-018-n, AC-019-n |
| C. Búsqueda | US-020 a US-023 | AC-020-n a AC-023-n |
| D. Detalle | US-026 a US-032 | AC-026-n a AC-032-n |
| E. Autenticación | US-037 a US-045, US-048 | AC-037-n a AC-045-n, AC-048-n |
| F. Carrito y compras | US-049 a US-058 | AC-049-n a AC-058-n |
| G. Cotizaciones | US-062 a US-065 | AC-062-n a AC-065-n |
| I. Sedes | US-072 a US-076 | AC-072-n a AC-076-n |
| J. Asesoría | US-079, US-080 | AC-079-n, AC-080-n |
| K. Herramientas | US-085 a US-089 | AC-085-n a AC-089-n |
| M. Atención | US-094 a US-097, US-099 | AC-094-n a AC-097-n, AC-099-n |
| N. Perfil y cuenta | US-104 a US-108, US-110, US-111 | AC-104-n a AC-108-n, AC-110-n, AC-111-n |
| Transversales | — | AC-SEC-1 a AC-SEC-13 |

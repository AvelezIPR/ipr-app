# Historias de usuario — App móvil IPR (MVP)

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Requisitos (Cuarta entrega). No se programa nada. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para validación de IPR |
| **Fuente principal** | [Requisitos funcionales](functional_requirements.md) (RF-001 a RF-113) |
| **Documentos relacionados** | [Criterios de aceptación](acceptance_criteria.md) · [Perfiles de usuario](../01_business/user_personas.md) · [Alcance](../01_business/scope.md) · [ADR](../03_architecture/architecture_decisions.md) · [Informe del código frontend](../00_discovery/informe_codigo_frontend.md) · [Decisiones pendientes](../project/decisiones_pendientes.md) |

---

## 0. Cómo leer este documento

### 0.1 Reglas de construcción

- **Una historia por requisito MVP** (los 76 marcados `sí` en la columna ¿MVP? de los requisitos funcionales). El ID de la historia replica el número del requisito: **US-0xx ↔ RF-0xx**. Así la trazabilidad es directa y estable.
- **Prioridad MoSCoW heredada** del requisito. No se reprioriza aquí.
- **Épica = módulo A–N** de los requisitos funcionales.
- Los requisitos de **fase 2** están en la sección 3 como backlog de una línea (sin desarrollar). Los **Won't** no se desarrollan (sección 4).
- Las historias no inventan reglas de negocio. Donde el requisito depende de una decisión abierta, la columna *Dependencias* cita la pregunta (PA-xx / D-xx) y los criterios de aceptación llevan la etiqueta **[A VALIDAR]**.

### 0.2 Decisiones aprobadas que se respetan en todas las historias

| Decisión | Efecto |
|---|---|
| **ADR-001** | La app solo habla con el BFF `/mobile/v1`. Nunca con `wc/v3`, `wp/v2` ni las rutas `/api/*` del sitio. No hay claves de WooCommerce en la app. |
| **ADR-002** | Compra completa en el MVP (carrito local + checkout de WooCommerce con Wompi en navegador seguro). Sin B2B: un solo perfil con precio público IVA incluido. Producto sin precio: solo "Más información" hacia WhatsApp. |
| **S-01** (D-05 abierta) | Disponibilidad genérica (en stock / agotado). Sin stock por sede ni cantidades. |
| **S-02** (PA-01 abierta) | El MVP exige sesión para pagar. |

### 0.3 Personas (ver [perfiles](../01_business/user_personas.md))

**Visitante** (sin sesión) · **Cliente registrado** (con sesión) · **Asesor comercial** (no usa la app; recibe consultas) · **Administrador** (no usa la app; sus cambios en WooCommerce/WordPress se reflejan en ella). Las historias de Asesor y Administrador describen resultados observables en sistemas de IPR, no pantallas de la app.

### 0.4 Resumen por épica

| Épica | Módulo | Historias MVP | Must | Should | Could |
|---|---|---|---|---|---|
| A | Inicio | 8 | 3 | 5 | 0 |
| B | Catálogo | 9 | 5 | 4 | 0 |
| C | Búsqueda | 4 | 2 | 2 | 0 |
| D | Detalle de producto | 7 | 5 | 2 | 0 |
| E | Usuarios y autenticación | 10 | 9 | 1 | 0 |
| F | Carrito y compras | 10 | 8 | 2 | 0 |
| G | Cotizaciones (WhatsApp) | 4 | 1 | 3 | 0 |
| I | Sedes | 5 | 4 | 1 | 0 |
| J | Asesoría técnica | 2 | 0 | 2 | 0 |
| K | Herramientas técnicas | 5 | 2 | 3 | 0 |
| M | Atención al cliente | 5 | 4 | 1 | 0 |
| N | Perfil y cuenta | 7 | 4 | 3 | 0 |
| **Total** | | **76** | **47** | **29** | **0** |

> Las épicas H (Favoritos) y L (Notificaciones) no tienen historias MVP: todos sus requisitos son fase 2 o descartados.

---

## 1. Historias MVP por épica

### Épica A — Inicio

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-001 | RF-001 | Como visitante o cliente registrado quiero llegar al buscador desde la pantalla de inicio con un solo toque para encontrar un repuesto por nombre, marca o referencia sin recorrer menús. | Must | RF-020 |
| US-002 | RF-002 | Como visitante o cliente registrado quiero ver en el inicio las 8 categorías raíz como accesos directos para explorar el catálogo por tipo de producto. | Must | RF-010 |
| US-003 | RF-003 | Como visitante o cliente registrado quiero ver un bloque de productos "más vendidos" (nombre, SKU, precio o "Más información", estado de stock) para descubrir referencias populares. | Should | PA-05 (criterio de "más vendidos"), RF-011 |
| US-004 | RF-004 | Como visitante o cliente registrado quiero acceder al directorio de marcas desde el inicio para buscar productos de la marca que necesito. | Should | RF-016 |
| US-005 | RF-005 | Como visitante o cliente registrado quiero un botón visible de WhatsApp de asesoría en el inicio para hablar con IPR sin buscar el contacto. | Must | RF-094 |
| US-006 | RF-006 | Como visitante o cliente registrado quiero acceder a la calculadora BTU desde el inicio para estimar la capacidad de equipo que necesito. | Should | RF-085, D-08 |
| US-007 | RF-007 | Como visitante o cliente registrado quiero acceder a Liquidaciones desde el inicio para aprovechar productos con precio especial. | Should | RF-018 |
| US-009 | RF-009 | Como visitante o cliente registrado quiero que, si no hay conexión o el servidor falla, la app me muestre un mensaje claro y me deje reintentar sin perder mi carrito para no abandonar la compra. | Should | ADR-001 |

### Épica B — Catálogo

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-010 | RF-010 | Como visitante o cliente registrado quiero navegar categorías jerárquicas (8 raíces y sus subcategorías) para llegar al tipo de repuesto exacto. | Must | D-10 |
| US-011 | RF-011 | Como visitante o cliente registrado quiero un listado de productos con carga progresiva que muestre imagen, nombre, marca, SKU, precio IVA incluido y estado de stock para comparar opciones sin esperar a que cargue todo el catálogo. | Must | S-01, D-05 (tamaño de página: DESCONOCIDO) |
| US-012 | RF-012 | Como visitante o cliente registrado quiero que un producto sin precio se muestre sin cifra y con "Más información" (nunca "$0") para no confundirme sobre su valor. | Must | ADR-002, D-04 |
| US-013 | RF-013 | Como visitante o cliente registrado quiero filtrar productos por marca y por categoría para reducir el listado a lo que necesito. | Must | — |
| US-014 | RF-014 | Como visitante o cliente registrado quiero filtrar por atributos técnicos disponibles (p. ej. capacidad BTU) para encontrar el repuesto compatible. | Should | D-10 (lista de atributos: DESCONOCIDA) |
| US-015 | RF-015 | Como visitante o cliente registrado quiero ordenar los listados para ver primero lo que me interesa. | Should | (criterios de orden: DESCONOCIDOS) |
| US-016 | RF-016 | Como visitante o cliente registrado quiero ver el directorio de marcas (~27) y los productos de una marca con búsqueda interna para encontrar una referencia dentro de la marca. | Should | — |
| US-018 | RF-018 | Como visitante o cliente registrado quiero un listado de Liquidaciones con precio regular y precio especial, orden y carga progresiva para identificar el ahorro. | Should | — |
| US-019 | RF-019 | Como administrador quiero que los cambios de producto, precio y estado de stock hechos en WooCommerce se reflejen en la app dentro de un plazo definido para que los clientes vean información vigente. | Must | PA-04 (plazo), ADR-001 C4 |

### Épica C — Búsqueda

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-020 | RF-020 | Como visitante o cliente registrado quiero buscar por texto (nombre, marca, referencia) con resultados paginados para encontrar un repuesto sin navegar categorías. | Must | — |
| US-021 | RF-021 | Como visitante o cliente registrado quiero ver sugerencias mientras escribo para llegar más rápido al producto. | Should | Riesgo: índice en memoria de un solo proceso (ADR-001) |
| US-022 | RF-022 | Como visitante o cliente registrado quiero que una búsqueda por SKU o referencia exacta me devuelva ese producto entre los primeros resultados para ubicar el repuesto exacto. | Must | (ranking actual: DESCONOCIDO; verificar en staging) |
| US-023 | RF-023 | Como visitante o cliente registrado quiero que, si mi búsqueda no tiene resultados, la app me ofrezca escribir por WhatsApp con el término buscado para que un asesor me ayude a conseguirlo. | Should | RF-094 |

### Épica D — Detalle de producto

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-026 | RF-026 | Como visitante o cliente registrado quiero ver en la ficha la galería, nombre, marca, SKU, precio IVA incluido por unidad y estado de stock para decidir la compra. | Must | S-01 |
| US-027 | RF-027 | Como visitante o cliente registrado quiero leer la descripción y la descripción corta del producto sin riesgo de contenido activo para informarme con seguridad. | Must | SEC-04 (COD §5.2) |
| US-028 | RF-028 | Como visitante o cliente registrado quiero ver los atributos técnicos del producto cuando existan para verificar compatibilidad. | Should | D-10 |
| US-029 | RF-029 | Como visitante o cliente registrado quiero elegir cantidad (1–99) y pulsar "Añadir al carrito" en un producto con precio y disponible para iniciar la compra. | Must | RF-049 |
| US-030 | RF-030 | Como visitante o cliente registrado quiero que un producto sin precio me ofrezca "Más información" en lugar de "Añadir al carrito" para consultar su valor con un asesor. | Must | ADR-002, RF-062 |
| US-031 | RF-031 | Como visitante o cliente registrado quiero que la ficha indique "Agotado" y no me deje añadir el producto al carrito para no comprar algo sin existencias. | Must | S-01, D-05, PA-12 ("bajo pedido") |
| US-032 | RF-032 | Como visitante o cliente registrado quiero ver los avisos de envío nacional y de garantía en la ficha para conocer condiciones antes de comprar. | Should | D-12 (texto de garantía) |

### Épica E — Usuarios y autenticación

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-037 | RF-037 | Como visitante quiero acceder a catálogo, búsqueda, fichas, precio público, sedes y canales de contacto sin iniciar sesión para explorar sin fricción. | Must | — |
| US-038 | RF-038 | Como visitante quiero registrarme con correo, nombre, apellido y una contraseña de al menos 8 caracteres para poder comprar y ver mis pedidos. | Must | ADR-001 |
| US-039 | RF-039 | Como visitante quiero ver y aceptar los términos y la política de tratamiento de datos al registrarme, y que mi aceptación quede registrada, para que IPR trate mis datos con mi consentimiento. | Must | D-12, PA-10 |
| US-040 | RF-040 | Como visitante quiero iniciar sesión con mi usuario o correo y mi contraseña para acceder a mi cuenta. | Must | ADR-001 |
| US-041 | RF-041 | Como cliente registrado quiero que cerrar sesión revoque en el servidor la sesión de este dispositivo para que nadie pueda reutilizarla. | Must | ADR-001 |
| US-042 | RF-042 | Como visitante o cliente registrado quiero recuperar mi contraseña para volver a entrar si la olvido. | Must | ADR-001 §2 (mecanismo por definir) |
| US-043 | RF-043 | Como cliente registrado quiero que iniciar sesión en la web o en otro dispositivo no cierre la sesión de la app para no tener que autenticarme de nuevo. | Must | ADR-001 (sesiones por dispositivo) |
| US-044 | RF-044 | Como cliente registrado quiero que mi sesión use un token de acceso de vida corta y un token de refresco rotativo guardados de forma segura, y que al expirar la app me pida reautenticarme sin perder mi carrito, para proteger mi cuenta sin perder mi compra. | Must | ADR-001 §2 (duraciones: DESCONOCIDAS) |
| US-045 | RF-045 | Como visitante o cliente registrado quiero que login, registro y recuperación tengan límite de intentos y bloqueo progresivo, con mensajes que no revelen si una cuenta existe, para proteger las cuentas contra fuerza bruta. | Must | R-02, COD §8.5 (reglas de Wordfence: DESCONOCIDAS) |
| US-048 | RF-048 | Como administrador quiero que la app no permita iniciar sesión a usuarios con rol administrativo de WordPress para reducir el riesgo de cuentas privilegiadas en un canal móvil. | Should | PA-03 (a validar) |

### Épica F — Carrito y compras

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-049 | RF-049 | Como visitante o cliente registrado quiero un carrito persistente en el dispositivo donde pueda agregar, quitar y cambiar cantidades (1–99 por producto, máximo 100 líneas) para armar mi compra a mi ritmo. | Must | ADR-002 |
| US-050 | RF-050 | Como cliente registrado quiero que al abrir el carrito la app consulte el precio vigente y la disponibilidad de cada ítem, me informe los cambios y no me deje pagar con ítems no disponibles hasta que los ajuste o retire, para no pagar algo que ya cambió. | Must | S-01; endpoint móvil de consulta por id (nuevo) |
| US-051 | RF-051 | Como visitante o cliente registrado quiero ver en el carrito un subtotal informativo (precio público IVA incluido) y un aviso de que impuestos, envío y total final se confirman en el checkout para entender el costo antes de pagar. | Must | — |
| US-052 | RF-052 | Como cliente registrado quiero pagar con sesión iniciada, enviando solo producto y cantidad, y que el checkout se abra en el navegador seguro del sistema con un ticket de un solo uso para que el cobro lo calcule y proteja la tienda. | Must | ADR-001, ADR-002, S-02, PA-01 |
| US-053 | RF-053 | Como cliente registrado quiero que la app no capture ni guarde mis datos de tarjeta o pago, y que el pago ocurra en el checkout de WooCommerce con Wompi, para pagar con seguridad. | Must | D-02, PA-12 (medios de pago: DESCONOCIDOS) |
| US-054 | RF-054 | Como cliente registrado quiero que el checkout venga prellenado con mi correo y mis datos de facturación cuando existan para no escribirlos de nuevo. | Should | RF-106 |
| US-055 | RF-055 | Como cliente registrado quiero volver a la app automáticamente tras pagar (App Links / Universal Links) o, si no es posible, que la app consulte el estado del pedido al cerrar el navegador, para saber cómo terminó mi compra. | Must | ADR-001 C1 y C2; `.well-known` (DESCONOCIDO) |
| US-056 | RF-056 | Como cliente registrado quiero ver el número y el estado de mi pedido (pagado, pendiente, fallido o cancelado) verificados en el servidor para confiar en el resultado de mi pago. | Must | D-02, PA-12 (estados reales: DESCONOCIDOS) |
| US-057 | RF-057 | Como cliente registrado quiero que mi carrito se vacíe solo cuando el pedido se confirme y se conserve si el pago falla o lo abandono, sin riesgo de pagar dos veces, para reintentar sin rehacer la compra. | Must | D-02, PA-11 |
| US-058 | RF-058 | Como cliente registrado quiero que, ante errores del traspaso al checkout (carrito inválido, tienda no disponible, ticket inválido), la app muestre un mensaje legible y me deje reintentar para no quedar bloqueado. | Should | RF-052 |

### Épica G — Cotizaciones (WhatsApp)

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-062 | RF-062 | Como visitante o cliente registrado quiero que "Más información" abra WhatsApp con un mensaje que identifique el producto para consultar a un asesor sin repetir qué producto me interesa. | Must | ADR-002, D-04 |
| US-063 | RF-063 | Como visitante o cliente registrado quiero una alternativa (enlace web de WhatsApp o teléfono de atención) si WhatsApp no está instalado o falla para poder contactar igual a IPR. | Should | RF-062 |
| US-064 | RF-064 | Como visitante o cliente registrado quiero un botón general "Cotizar por WhatsApp" en inicio y ayuda para pedir cotización de un proyecto o volumen. | Should | RF-094 |
| US-065 | RF-065 | Como administrador quiero medir de forma agregada los toques en "Más información" para estimar la demanda que hoy no puede comprarse en línea. | Should | PA-08, D-12, R-07 |

### Épica I — Sedes

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-072 | RF-072 | Como visitante o cliente registrado quiero ver las sedes agrupadas por ciudad, distinguiendo las "próximamente" (sin acciones de contacto), para encontrar la más conveniente. | Must | D-07 (31/32 sedes), D-09 |
| US-073 | RF-073 | Como visitante o cliente registrado quiero ver en la ficha de sede nombre, dirección, teléfonos, WhatsApp e imagen para saber cómo contactarla. | Must | D-09 |
| US-074 | RF-074 | Como visitante o cliente registrado quiero llamar y escribir por WhatsApp a una sede desde su ficha para consultar disponibilidad directamente. | Must | RF-073 |
| US-075 | RF-075 | Como visitante o cliente registrado quiero que "Cómo llegar" abra la app de mapas con la dirección de la sede para ir hasta ella. | Should | RF-073 |
| US-076 | RF-076 | Como administrador quiero que los datos de sedes se sirvan desde una fuente que pueda mantener sin recompilar la app para que los cambios lleguen a los clientes sin publicar una versión nueva. | Must | D-09, ADR-001 (mecanismo: DESCONOCIDO) |

### Épica J — Asesoría técnica

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-079 | RF-079 | Como visitante o cliente registrado quiero leer el contenido informativo de los servicios de ingeniería (aire acondicionado y refrigeración) para saber qué ofrece IPR. | Should | ADR-001 (fuente del contenido: DESCONOCIDA) |
| US-080 | RF-080 | Como visitante o cliente registrado quiero contactar a ingeniería por un canal corporativo (WhatsApp de asesoría, PBX o correo) para recibir asesoría técnica sin exponer datos personales de ingenieros. | Should | D-12, PA-06 |

### Épica K — Herramientas técnicas (calculadora BTU)

> Condicionada a **D-08**: si Ingeniería IPR no valida la fórmula, el módulo K sale del MVP (ver [alcance](../01_business/scope.md) §7).

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-085 | RF-085 | Como visitante o cliente registrado quiero ingresar largo, ancho, alto, ocupantes, equipos y clima, con validación de rangos, para obtener una estimación fiable. | Should | D-08 |
| US-086 | RF-086 | Como visitante o cliente registrado quiero que el resultado siga la fórmula vigente y sugiera la menor capacidad comercial mayor o igual a la requerida (9.000, 12.000, 18.000, 24.000 o 36.000 BTU) para saber qué equipo buscar. | Should | D-08 |
| US-087 | RF-087 | Como visitante o cliente registrado quiero que el resultado incluya el aviso de que es una estimación para no tomarlo como un dimensionamiento definitivo. | Must | D-08 (Must condicionado a RF-085) |
| US-088 | RF-088 | Como visitante o cliente registrado quiero que, si el requerido supera 36.000 BTU, la app me lo informe y me ofrezca contactar a un asesor para recibir una solución a la medida. | Must | D-08, RF-080 (Must condicionado a RF-085) |
| US-089 | RF-089 | Como visitante o cliente registrado quiero que el resultado me lleve al catálogo filtrado por la capacidad sugerida para ver los equipos que me sirven. | Should | RF-014, D-08 |

### Épica M — Atención al cliente

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-094 | RF-094 | Como visitante o cliente registrado quiero abrir WhatsApp de atención (línea nacional) desde el menú o la ayuda con un mensaje prellenado para consultar a IPR rápidamente. | Must | PA-07 (SLA: DESCONOCIDO) |
| US-095 | RF-095 | Como visitante o cliente registrado quiero una pantalla de Ayuda/Contacto que agrupe los canales corporativos para elegir cómo contactar a IPR sin ver datos personales de empleados. | Should | D-12 |
| US-096 | RF-096 | Como visitante o cliente registrado quiero enviar un PQRS (petición, queja, reclamo o sugerencia) con validación, control anti-spam y confirmación de envío para dejar constancia de mi caso. | Must | ADR-001 (endpoint móvil equivalente) |
| US-097 | RF-097 | Como asesor comercial o administrador quiero que cada PQRS enviada llegue al buzón corporativo de PQRS y que el límite de envíos no dependa de la memoria de un solo proceso para atender los casos sin pérdida ni abuso. | Must | ADR-001 (almacén compartido), PA-07 |
| US-099 | RF-099 | Como visitante o cliente registrado quiero acceder a las páginas legales (términos, política de datos y demás publicadas) antes de registrarme y desde el menú para conocer las condiciones del servicio. | Must | D-12, R-07, S-05 |

### Épica N — Perfil y cuenta

| US | RF | Historia | MoSCoW | Dependencias |
|---|---|---|---|---|
| US-104 | RF-104 | Como cliente registrado quiero ver y editar mi nombre, apellido y correo, y que cambiar el correo reemita mi sesión, para mantener mis datos al día sin perder el acceso. | Must | RF-043, RF-044 |
| US-105 | RF-105 | Como cliente registrado quiero cambiar mi contraseña confirmando la actual para proteger mi cuenta. | Must | — |
| US-106 | RF-106 | Como cliente registrado quiero gestionar una dirección de facturación y una de envío (cédula/NIT, nombre, dirección, departamento, ciudad, teléfono; solo Colombia) para agilizar mis compras. | Should | (direcciones múltiples: fuera del MVP) |
| US-107 | RF-107 | Como cliente registrado quiero ver el historial de mis pedidos (número, fecha, estado, total) para hacer seguimiento a mis compras. | Must | ADR-001 |
| US-108 | RF-108 | Como cliente registrado quiero ver el detalle de un pedido (productos con cantidad y total, subtotal, método de pago) para verificar lo que compré. | Should | ADR-001 |
| US-110 | RF-110 | Como cliente registrado quiero eliminar mi cuenta desde la app, con confirmación e información de qué datos se conservan, para ejercer control sobre mis datos. | Must | D-12, PA-09, S-05 |
| US-111 | RF-111 | Como cliente registrado quiero un canal accesible desde mi perfil para ejercer mis derechos de titular (consulta, rectificación, supresión) para que IPR atienda mis solicitudes sobre mis datos. | Should | D-12 (canal vigente: DESCONOCIDO) |

---

## 2. Historias que dependen de decisiones abiertas (resumen)

| Historia(s) | Decisión que las condiciona | Efecto |
|---|---|---|
| US-085 a US-089, US-006 | **D-08** (validación de Ingeniería de la fórmula BTU) | Si no se cierra, el módulo K sale del MVP |
| US-039, US-065, US-095, US-099, US-110, US-111 | **D-12** (Ley 1581), PA-08, PA-09, PA-10 | Textos legales, versión aceptada, retención y canal de derechos |
| US-056, US-057 | **D-02**, PA-11, PA-12 | Estados de pedido, doble pago, medios de pago |
| US-055 | ADR-001 C1/C2 (`.well-known`, staging) | App Links / Universal Links o alternativa de consulta |
| US-019, US-076 | PA-04 (plazo de refresco), D-09 (sedes) | Umbrales de frescura de datos |
| US-003 | PA-05 | Criterio de "más vendidos" |
| US-031 | PA-12 | Tratamiento de "Disponible bajo pedido" |
| US-048 | PA-03 | Bloqueo de roles administrativos |
| US-052 | PA-01 (compra de invitado) | Hoy la compra exige sesión (S-02) |
| US-045 | R-02, COD §8.5 | Umbrales de bloqueo y reglas de Cloudflare/Wordfence |
| US-080 | PA-06 | Canal corporativo de ingeniería |
| US-094, US-097 | PA-07 | SLA y responsables de respuesta |

---

## 3. Backlog de fase 2 (una línea por requisito, sin desarrollar)

| RF | MoSCoW | Backlog (sin historia desarrollada) |
|---|---|---|
| RF-008 | Could | Contenido institucional y promocional en el inicio (cifras, red nacional, formación). Depende de D-07. |
| RF-017 | Could | Contenido editorial de landings de marca y campañas. |
| RF-024 | Could | Filtros y orden aplicables a los resultados de búsqueda. |
| RF-025 | Could | Historial de búsquedas recientes local y borrable (D-12). |
| RF-033 | Could | Compartir el enlace de un producto. |
| RF-034 | Could | Productos relacionados o compatibilidades en la ficha (D-10). |
| RF-035 | Won't (fase 2) | Fichas técnicas descargables en PDF (D-10). No se desarrolla. |
| RF-036 | Could | App Links / Universal Links para `/producto/{slug}`. |
| RF-046 | Should | Verificación de correo en el registro o antes de la primera compra (PA-02). |
| RF-047 | Could | Compra como invitado (PA-01, D-06). |
| RF-059 | Won't (fase 2) | Carrito sincronizado entre dispositivos en servidor. No se desarrolla. |
| RF-061 | Won't (fase 2) | Solicitud de factura electrónica o venta por volumen desde la app. No se desarrolla. |
| RF-066 | Could | Solicitud de cotización estructurada enviada a un asesor (D-04, requiere backend). |
| RF-067 | Won't (fase 2) | Estados y seguimiento de cotización en la app. No se desarrolla. |
| RF-068 | Could | Marcar y desmarcar favoritos, local y sin sesión. |
| RF-069 | Could | Lista de favoritos con precio y stock actualizados. |
| RF-070 | Could | Favoritos sincronizados por cuenta entre dispositivos. |
| RF-077 | Should | Coordenadas, horarios por sede y mapa (D-09; pasa a MVP solo si Operaciones entrega la hoja maestra a tiempo). |
| RF-078 | Could | Sede más cercana según ubicación del dispositivo (D-12, R-07). |
| RF-081 | Could | Formulario de solicitud de servicio de ingeniería (PA-06). |
| RF-082 | Could | Listado de capacitaciones. |
| RF-084 | Could | Lectura de artículos del blog (23 en la web). |
| RF-090 | Could | Notificación push transaccional de cambio de estado de pedido (D-11, D-12). |
| RF-091 | Could | Registro de dispositivo y preferencias de notificación con consentimiento por categoría. |
| RF-093 | Could | Solicitar el permiso de notificaciones en contexto, no al abrir la app. |
| RF-098 | Could | Número de radicado, estado y adjuntos de PQRS. |
| RF-100 | Could | Preguntas frecuentes (envíos, garantía, facturación) (D-12). |
| RF-101 | Could | Suscripción al boletín con consentimiento (Ley 1581). |
| RF-103 | Won't (fase 2) | Campañas promocionales (ruleta Midea, raspa Samsung). No se desarrolla. |
| RF-109 | Could | Seguimiento de envío (tracking) y dirección del pedido. |
| RF-112 | Could | Ver sesiones activas y cerrar sesión en todos los dispositivos. |
| RF-113 | Could | Preferencia de tema claro/oscuro (D-13). |

Total fase 2: 32 requisitos.

---

## 4. Requisitos descartados por ahora (Won't / `no`): no se desarrollan

| RF | Tema | Motivo (fuente: requisitos funcionales) |
|---|---|---|
| RF-060 | Pagos diferidos (Addi) | Solo texto en un enlace de WhatsApp; no integrado (D-02). |
| RF-071 | Avisos sobre favoritos (baja de precio, disponibilidad) | Depende de favoritos y push (D-11, D-12). |
| RF-083 | Inscripción o recordatorio de capacitaciones | Se desconoce el mecanismo actual. |
| RF-092 | Notificaciones promocionales | D-11 y D-12 sin resolver. |
| RF-102 | Directorio de asesores y puntos de venta por ciudad | Contiene datos personales de empleados; se usan canales corporativos (RF-095). |

Total descartados: 5 requisitos. 76 (MVP) + 32 (fase 2) + 5 (descartados) = 113.

# Alcance del MVP y de la fase 2

| | |
|---|---|
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para validación de IPR |
| **Relacionado** | [Visión](vision.md) · [Stakeholders](stakeholders.md) · [Perfiles](user_personas.md) · [Requisitos funcionales](../02_requirements/functional_requirements.md) · [ADR](../03_architecture/architecture_decisions.md) · [Decisiones pendientes](../project/decisiones_pendientes.md) |

Este documento resume el alcance. El detalle y los IDs están en los [requisitos funcionales](../02_requirements/functional_requirements.md) (113 requisitos; 76 en MVP).

## 1. Decisiones de alcance ya tomadas (no se reabren)

| Decisión | Resumen | Fuente |
|---|---|---|
| Compra completa en el MVP | Carrito local + checkout de WooCommerce con Wompi en navegador seguro | ADR-002, D-06 |
| Sin B2B en el MVP | Un solo perfil con precio público IVA incluido | ADR-002, D-03 |
| Productos sin precio | Solo "Más información" → WhatsApp con el producto; sin formulario ni estados | ADR-002, D-04 |
| Arquitectura | BFF móvil `/mobile/v1` en el Next.js existente; `ipr/v1` se amplía solo donde falte | ADR-001, D-01 |
| Stock (D-05 ABIERTA) | **Supuesto S-01:** disponibilidad genérica (en stock / agotado), sin stock por sede | Requisitos §3 |

## 2. Dentro del MVP

| Módulo | Qué incluye | Requisitos | Justificación |
|---|---|---|---|
| A. Inicio | Buscador, categorías raíz, más vendidos, marcas, WhatsApp, accesos a calculadora y liquidaciones, manejo de error y sin conexión | RF-001 a RF-007, RF-009 | Puerta de entrada; ya existe en la web y reutiliza datos del BFF |
| B. Catálogo | Categorías, listados paginados, productos sin precio sin "$0", filtros por marca/categoría/atributos, orden, marcas, liquidaciones, frescura de datos | RF-010 a RF-016, RF-018, RF-019 | Núcleo de valor; existe en la web |
| C. Búsqueda | Texto, sugerencias, SKU/referencia exacta, estado vacío con WhatsApp | RF-020 a RF-023 | El cliente HVAC-R busca por referencia (placeholder de la web) |
| D. Detalle | Galería, precio, stock, descripción saneada, atributos, cantidad, "Añadir al carrito" o "Más información", agotado, avisos de envío y garantía | RF-026 a RF-032 | Imprescindible para comprar |
| E. Auth | Navegar sin cuenta, registro con aceptación de políticas, login, logout, recuperación, sesión por dispositivo, tokens seguros, protección de fuerza bruta, bloqueo de roles administrativos (a validar) | RF-037 a RF-045, RF-048 | Requisito de ADR-002 (compra) y de seguridad (COD H-01 a H-04) |
| F. Carrito y compras | Carrito local, revalidación, resumen, checkout con ticket, sin datos de pago en la app, prellenado, retorno por App Links, resultado verificado, manejo de pago fallido, errores legibles | RF-049 a RF-058 | Decisión D-06 / ADR-002 |
| G. Cotizaciones | WhatsApp con producto, alternativa si no hay WhatsApp, "Cotizar por WhatsApp", medición agregada | RF-062 a RF-065 | ADR-002: sin backend de cotizaciones |
| I. Sedes | Listado por ciudad, ficha, llamar/WhatsApp, "Cómo llegar" por dirección, fuente de datos mantenible | RF-072 a RF-076 | Existe en la web; la fuente hoy es código compilado |
| J. Asesoría técnica | Contenido de ingeniería, contacto por canal corporativo | RF-079, RF-080 | Servicio existente de IPR; bajo costo |
| K. Herramientas | Calculadora BTU con descargo y manejo de >36.000 BTU | RF-085 a RF-089 | **Condicionada a D-08** (validación de Ingeniería) |
| M. Atención | WhatsApp de atención, pantalla de Ayuda, PQRS, páginas legales | RF-094 a RF-097, RF-099 | PQRS existe en la web; páginas legales son necesarias para el registro (D-12) |
| N. Perfil y cuenta | Datos, contraseña, direcciones, pedidos y detalle, eliminación de cuenta, derechos del titular | RF-104 a RF-108, RF-110, RF-111 | Eliminación de cuenta es un hueco actual (COD H-08) y requisito de tiendas (supuesto S-05) |

## 3. Trabajo de backend que el MVP exige (no es opcional)

Por ADR-002, el MVP **sí** depende de lo más exigente de ADR-001. Ver [requisitos §2](../02_requirements/functional_requirements.md).

1. Sesiones por dispositivo con token de acceso corto y refresco rotativo (COD H-01, H-02).
2. Rate limiting en autenticación y recuperación (COD H-04).
3. Recuperación de contraseña y eliminación de cuenta por API (COD H-08).
4. App Links / Universal Links y archivos `.well-known` en el dominio (COD §5.4).
5. Endpoint de consulta de precio y disponibilidad por id (RF-050).
6. Fuente consumible de sedes (RF-076).
7. Staging de frontend + WooCommerce + Wompi sandbox (ADR-001 C2) y pruebas de contrato en `/mobile/v1`.

## 4. Fuera del MVP

| Elemento | Requisitos | Justificación | ¿Cuándo se revisa? |
|---|---|---|---|
| Compra de invitado | RF-047 | Supuesto S-02: el checkout móvil usa sesión; abrir invitado cambia flujo y riesgo | PA-01 |
| Verificación de correo | RF-046 | Decisión de negocio pendiente; riesgo medio (COD H-06) | PA-02 |
| Pagos diferidos (Addi) | RF-060 | Hoy solo es texto en un enlace de WhatsApp; no está integrado | D-02 |
| Directorio de asesores por ciudad | RF-102 | Contiene datos personales de empleados; se usan canales corporativos | D-12 |
| Promociones push | RF-092 | D-11 y D-12 sin resolver | D-11 |
| Avisos sobre favoritos | RF-071 | Depende de favoritos y push | Fase 2 |
| Inscripción a capacitaciones | RF-083 | Se desconoce el mecanismo actual | Preguntar a Marketing |

## 5. Fase 2 (candidatos)

| Elemento | Requisitos | Justificación para no entrar al MVP |
|---|---|---|
| Cotización estructurada y estados | RF-066, RF-067 | ADR-002: evita backend/CRM nuevo en el MVP |
| Precios B2B por rol / perfil mayorista | (ver user_personas) | ADR-002, D-03: decisión de negocio sin definir; riesgo de fuga de tarifas (R-06) |
| Favoritos (local y sincronizados) | RF-068 a RF-070 | La web no los tiene; la sincronización exige endpoints nuevos (COD H-08) |
| Notificaciones push transaccionales | RF-090, RF-091, RF-093 | Sin endpoints de dispositivos ni definición de eventos (D-11, D-12) |
| Sedes: coordenadas, horarios, mapa, cercanía | RF-077, RF-078 | Los datos no existen (D-09); la cercanía requiere permiso de ubicación (D-12). RF-077 pasa a MVP si Operaciones entrega la hoja maestra a tiempo |
| Contenido editorial: landings de marca, blog, capacitaciones | RF-017, RF-082, RF-084 | Valor secundario frente al costo de contenido y saneo de HTML |
| Productos relacionados, fichas técnicas, compartir, enlaces web | RF-033 a RF-036 | Datos no confirmados (D-10) |
| Búsqueda: filtros sobre resultados, historial | RF-024, RF-025 | Mejoras sobre una búsqueda ya cubierta |
| Seguimiento de envío | RF-109 | Fuente de transportadora DESCONOCIDA |
| Radicado de PQRS, FAQ, boletín, campañas | RF-098, RF-100, RF-101, RF-103 | Valor secundario; implican datos personales (Ley 1581) |
| Carrito en servidor, sesiones activas, tema oscuro | RF-059, RF-112, RF-113 | No bloquean la compra |
| Solicitud de servicio de ingeniería, factura electrónica por volumen | RF-081, RF-061 | La web no tiene flujo; requiere definición de proceso |

## 6. Supuestos de alcance

Ver [requisitos §3](../02_requirements/functional_requirements.md): S-01 (stock genérico), S-02 (compra con sesión), S-03 (todo por `/mobile/v1`), S-04 (un solo perfil), S-05 (exigencias de tiendas), S-06 (datos publicables).

## 7. Decisiones pendientes que pueden mover el alcance

| Decisión | Efecto posible |
|---|---|
| D-05 (stock) | Si hay stock por sede confiable, cambia ficha, listados y carrito |
| D-08 (calculadora) | Si Ingeniería no valida la fórmula, el módulo K sale del MVP |
| D-09 (sedes) | Si llega la hoja maestra, RF-077 entra al MVP |
| D-12 (Ley 1581) | Condiciona RF-039, RF-065, RF-099, RF-110, RF-111 y todo el módulo L |
| D-02 (webhooks/doble pago) | Condiciona RF-056 y RF-057 |
| PA-01, PA-02 | Compra de invitado y verificación de correo |

Preguntas abiertas completas: [requisitos §5](../02_requirements/functional_requirements.md).

## 8. Criterios de salida del MVP (propuestos, sin metas numéricas)

1. Compra extremo a extremo en staging: añadir, pagar con Wompi sandbox, volver a la app y ver el pedido (ADR-002).
2. Ningún precio ni rol B2B llega a la app (ADR-002).
3. La app empaquetada no contiene claves; `/mobile/v1` rechaza tokens inválidos o expirados; sesiones de dispositivos independientes (ADR-001).
4. Las condiciones C1 a C4 de ADR-001 están cumplidas o con plan.
5. Páginas legales, aceptación de políticas y eliminación de cuenta operativas (D-12).

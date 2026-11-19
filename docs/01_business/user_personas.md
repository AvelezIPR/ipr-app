# Perfiles de usuario

| | |
|---|---|
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para validación de IPR |
| **Relacionado** | [Visión](vision.md) · [Alcance](scope.md) · [Stakeholders](stakeholders.md) · [Requisitos funcionales](../02_requirements/functional_requirements.md) · [Informe del código frontend](../00_discovery/informe_codigo_frontend.md) |

> **No hay investigación de usuarios.** No existen entrevistas, analítica de uso ni datos demográficos (la web no tiene analítica de terceros, INV §2.1). Los perfiles se construyen con lo que el código y la web permiten **comprobar** (permisos, flujos) y con **hipótesis** marcadas como "a validar con IPR". No se inventan permisos ni diferencias comerciales.
> Leyenda: **Hecho** = comprobado en código/informes · **Hipótesis** = a validar · **A validar con IPR** = no hay evidencia.

## Resumen

| Perfil | En el MVP | Existe en el código | Cómo se identifica |
|---|---|---|---|
| Visitante | Sí | Sí (web pública) | Sin sesión |
| Cliente registrado | Sí | Sí | Cuenta de WooCommerce con sesión |
| Asesor comercial | **No usa la app**; recibe consultas por WhatsApp/PQRS | No hay rol de asesor en el código del frontend | A validar con IPR |
| Administrador | **No usa la app** | Sí: `roles[]` en el usuario; administración en WordPress | Rol de WordPress |
| Cliente B2B / mayorista | **No (perfil futuro)** | No: el enlace "B2B" lleva al registro común | A validar con IPR |

---

## 1. Visitante

| Aspecto | Contenido |
|---|---|
| **Descripción** | Persona que usa la app sin cuenta. |
| **Quién es (hipótesis)** | Técnico, instalador, taller o comprador de una empresa que busca un repuesto o una sede. Perfil real y frecuencia de uso: **DESCONOCIDOS** (a validar con IPR). |
| **Objetivos** | Encontrar un repuesto por marca o referencia; ver precio público con IVA incluido; saber dónde hay una sede; hablar con un asesor; calcular capacidad BTU. |
| **Qué puede hacer (hecho)** | Navegar catálogo, buscar, ver fichas y precios públicos, agregar al carrito (el carrito es local en la web), ver sedes, usar la calculadora, enviar PQRS, abrir WhatsApp (INV F2, F5, F7, F15, F18, F23). |
| **Qué no puede (propuesto para el MVP)** | Pagar (el MVP exige sesión: supuesto S-02; PA-01 puede cambiarlo). |
| **Puntos de dolor (hechos)** | Productos sin precio: solo puede escribir por WhatsApp (INV F6). Flete no visible hasta el checkout (INV §7). |
| **Permisos** | Solo lectura pública. Precio público IVA incluido. |
| **Requisitos principales** | RF-001 a RF-007, RF-010 a RF-016, RF-020 a RF-023, RF-026 a RF-032, RF-037 a RF-040, RF-062 a RF-064, RF-072 a RF-075, RF-085 a RF-089, RF-094 a RF-096, RF-099 |

## 2. Cliente registrado

| Aspecto | Contenido |
|---|---|
| **Descripción** | Persona con cuenta de WooCommerce que inició sesión en la app. |
| **Quién es (hipótesis)** | Visitante que decidió comprar o consultar sus pedidos. Si es persona natural, empresa o NIT: la cuenta guarda cédula/NIT en facturación (hecho: `src/lib/checkout-schema.ts`), pero la proporción por tipo es **DESCONOCIDA**. |
| **Objetivos** | Comprar con pago seguro; ver el historial y detalle de sus pedidos; guardar datos de facturación y envío; mantener su cuenta y borrarla si lo desea. |
| **Qué puede hacer (hecho en la web)** | Todo lo del visitante, más: pagar en el checkout de WooCommerce con Wompi y elegir envío allí; ver pedidos; editar perfil, contraseña y direcciones (INV F10, F12; COD §1, §3). |
| **Qué se añade en el MVP (propuesto)** | Sesión independiente por dispositivo (login web no cierra la app), eliminación de cuenta, canal de derechos del titular, resultado de pedido verificado en servidor (COD H-01, H-08). |
| **Puntos de dolor (hechos)** | Hoy un solo token por usuario: iniciar sesión en la web cierra la sesión de otro dispositivo (COD H-01). Pedido sin imagen, envío ni tracking (COD §3). |
| **Permisos** | Lee y modifica **sus** datos y pedidos. Mismo precio público que el visitante (ADR-002). Rol de WordPress de cliente (`roles[]` existe; sin precios por rol, COD §1). |
| **Requisitos principales** | RF-029, RF-041 a RF-045, RF-049 a RF-058, RF-104 a RF-108, RF-110, RF-111, más los del visitante |

## 3. Asesor comercial

| Aspecto | Contenido |
|---|---|
| **Descripción** | Empleado de IPR que atiende a clientes por WhatsApp, teléfono y PQRS. |
| **Relación con la app** | **No es usuario de la app en el MVP.** Es el destinatario de las consultas que la app genera ("Más información", "Cotizar por WhatsApp", PQRS). |
| **Hechos** | La atención comercial real ocurre por WhatsApp y teléfono (INV §7). El mensaje de "Más información" identifica el producto por nombre y SKU (`ProductBuyBox.tsx`). Las PQRS llegan al buzón corporativo por SMTP (COD §2). |
| **Necesidades (hipótesis)** | Recibir consultas con contexto de producto; no perder consultas por productos sin precio. A validar con IPR. |
| **Permisos en la app** | Ninguno. **A validar con IPR** si se querrá una herramienta móvil para asesores (cotizaciones con estado: fase 2, RF-066/RF-067). |
| **DESCONOCIDO** | SLA de respuesta, cantidad de asesores, herramienta de gestión (CRM o solo WhatsApp). Se obtiene con PA-07 (Dirección comercial). |
| **Requisitos relacionados** | RF-062, RF-064, RF-066, RF-067, RF-081, RF-097 |

> Los directorios de la web (59 contactos y 8 ingenieros con nombre, correo y celular) son datos personales de empleados y no se replican (INV F16; RF-102; D-12).

## 4. Administrador

| Aspecto | Contenido |
|---|---|
| **Descripción** | Persona de IPR que mantiene catálogo y contenido en WooCommerce/WordPress y opera el frontend. |
| **Relación con la app** | **No usa la app** ni hay back-office móvil en el MVP. Sus acciones se reflejan en la app (catálogo, precio, estado de stock, sedes). |
| **Hechos** | WordPress mantiene catálogo, clientes y pedidos; un webhook revalida la caché del frontend (COD §2, §4). Los usuarios tienen `roles[]`; la auditoría interna señala que los roles de administrador son aceptados en la API de clientes (COD H-10, SEC-09). |
| **Necesidades (hipótesis)** | Que un cambio de precio o stock se vea en la app en un plazo acotado (RF-019, PA-04); poder actualizar sedes sin recompilar (RF-076); medir uso de "Más información" (RF-065). |
| **Permisos en la app** | Ninguno propuesto; se propone impedir el acceso con rol administrativo (RF-048, a validar en PA-03). **A validar con IPR** qué otros roles existen. |
| **Requisitos relacionados** | RF-019, RF-048, RF-065, RF-076, RF-097 |

## 5. Cliente B2B / mayorista (perfil FUTURO, fuera del MVP)

| Aspecto | Contenido |
|---|---|
| **Estado** | **Fuera del MVP** (ADR-002, D-03). Se documenta para no perder la intención de negocio. |
| **Hechos** | La web enlaza "¿B2B o comprador mayorista? Crea tu cuenta aquí", pero **lleva al mismo registro** (COD §1). No hay rol, flujo ni precio B2B en el código del frontend. Los textos de la web hablan de lista de precios B2B, cupo comercial y facturación electrónica como atención de asesores (INV §1 #7, F26). |
| **Hipótesis** | Compradores recurrentes (talleres, instaladores, empresas) que hoy se atienden con asesores. |
| **Permisos y diferencias comerciales** | **A validar con IPR:** qué precios ven, si hay cupo, aprobación de cuenta, condiciones de pago y factura. Nada de esto se asume. |
| **Riesgos** | Fuga de tarifas si el servidor no decide el precio por rol (R-06). Pérdida de ventas mientras dependan de asesores (R-11). |
| **Cómo obtener la información** | Entrevista con Dirección comercial (D-03); confirmar si existe un rol de WordPress o un plugin de precios por rol (COD §8, pregunta 4). |
| **Requisitos relacionados** | Ninguno en esta versión. Entrará como nuevos RF cuando se cierre D-03 en fase 2. |

---

## 6. Matriz perfil × capacidad (MVP)

| Capacidad | Visitante | Cliente registrado | Asesor | Administrador | B2B (futuro) |
|---|---|---|---|---|---|
| Ver catálogo, buscar, ver precio público | Sí | Sí | n/a (no usa la app) | n/a | A validar con IPR |
| Añadir al carrito (local) | Sí | Sí | n/a | n/a | A validar |
| Pagar | No (supuesto S-02) | Sí | n/a | n/a | A validar |
| Ver y gestionar pedidos y perfil | No | Sí | n/a | n/a | A validar |
| Contactar por WhatsApp / PQRS | Sí | Sí | Recibe | n/a | A validar |
| Eliminar cuenta | No | Sí | n/a | n/a | A validar |
| Ver precios por rol | No existe | No existe | n/a | n/a | A validar con IPR |

# Visión del producto — App móvil IPR Partes y Repuestos

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Requisitos (Segunda entrega) |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para validación de IPR |
| **Relacionado** | [Alcance](scope.md) · [Stakeholders](stakeholders.md) · [Perfiles](user_personas.md) · [Requisitos funcionales](../02_requirements/functional_requirements.md) · [ADR](../03_architecture/architecture_decisions.md) · [Decisiones pendientes](../project/decisiones_pendientes.md) |

> Convención: **Hecho** = comprobado en los informes o en el código; **Supuesto** = razonable pero sin validar; **Propuesto** = idea del equipo de proyecto; **DESCONOCIDO** = sin evidencia (se indica cómo obtenerlo).

---

## 1. Contexto (hechos)

- IPR Partes y Repuestos es una tienda de repuestos HVAC-R en Colombia, con red de sedes (31 según la web; cifra por conciliar, D-07) y una web propia en Next.js sobre WooCommerce (informe de investigación §1, §2).
- La web ya permite catálogo (885 productos publicados, ~216 categorías), búsqueda, cuenta, carrito local y pago con Wompi a través del checkout de WooCommerce (informe de código §1, §2).
- Parte del catálogo no tiene precio y se atiende por WhatsApp con un asesor (3 de 7 fichas de la muestra aleatoria; informe de investigación F6).
- La atención comercial real hoy ocurre por WhatsApp y teléfono; la app debe integrarse con ellos, no reemplazarlos (informe de investigación §7).

## 2. Problema que se quiere resolver

| # | Problema | Tipo | Evidencia |
|---|---|---|---|
| P1 | El cliente técnico (instalador, taller, técnico de mantenimiento) consulta y compra repuestos desde el celular, pero hoy solo tiene la web. | **Supuesto** (perfil y uso en móvil: DESCONOCIDO, a validar con IPR) | La web se sirve con el mismo HTML en móvil y escritorio; no se hicieron pruebas visuales en dispositivos (INV F27) |
| P2 | Los productos sin precio dependen de un asesor por WhatsApp; no hay trazabilidad ni medición de esa demanda. | **Hecho** | INV F6; código: botón "Más información" con WhatsApp |
| P3 | No hay canal de reenganche (notificaciones, favoritos) ni acceso rápido de recompra desde el dispositivo. | **Hecho** (no existen en la web) / **Supuesto** (valor para el cliente) | INV F13, §5 |
| P4 | La sesión actual y los contratos de API de la web no sirven para una app (un solo token por usuario, sin refresh, cookie). | **Hecho** | COD H-01, H-02, H-04 |

## 3. Visión

> Que un cliente de IPR encuentre el repuesto correcto, vea su precio público con IVA incluido, lo compre con pago seguro o llegue en un toque a un asesor de IPR, todo desde su celular y con los mismos datos y reglas comerciales de la web.

(Propuesta de redacción para validar con la Gerencia.)

## 4. Objetivos del producto

Las metas numéricas son **DESCONOCIDAS**: IPR no ha definido indicadores ni líneas base (no hay analítica de terceros en la web, INV §2.1). Se proponen los objetivos y se pide definir metas.

| ID | Objetivo (propuesto) | Indicador candidato | Meta |
|---|---|---|---|
| O-1 | Permitir la compra completa desde la app con pago seguro. | Pedidos completados desde la app; tasa de pago exitoso | DESCONOCIDA (definir con Gerencia y Finanzas) |
| O-2 | Acercar el catálogo y la búsqueda por referencia al cliente en móvil. | Búsquedas con resultado; fichas vistas | DESCONOCIDA |
| O-3 | Derivar a asesores las consultas de productos sin precio con un solo toque. | Toques en "Más información" y "Cotizar por WhatsApp" | DESCONOCIDA. Requiere RF-065 y PA-08 |
| O-4 | Ofrecer acceso móvil a sedes, atención y PQRS. | Uso de sedes y PQRS desde la app | DESCONOCIDA |
| O-5 | Operar la app sin comprometer la seguridad de la web ni los datos personales (Ley 1581). | Pruebas de seguridad y de contrato superadas (ver ADR-001, ADR-002) | Criterio de salida, no numérico |

## 5. Propuesta de valor (propuesta)

| Para | Valor |
|---|---|
| Visitante y cliente registrado | Catálogo, búsqueda por marca o referencia, precio público IVA incluido, compra con Wompi en navegador seguro, historial de pedidos, sedes, calculadora BTU. |
| Asesor comercial | Consultas ya contextualizadas (el mensaje de WhatsApp identifica el producto: nombre y SKU). |
| Gerencia / Administrador | Un solo catálogo y una sola cuenta de cliente (WooCommerce) para web y app; sin duplicar reglas comerciales. |

## 6. Principios rectores

1. **Un solo origen de verdad.** Precio, impuestos, stock y estado de pedido los calcula el servidor (WooCommerce); la app solo muestra (hecho: el checkout web envía solo `{id, quantity}`).
2. **Sin claves en la app.** La app consume solo `/mobile/v1` (ADR-001).
3. **No reemplazar al asesor.** WhatsApp y teléfono siguen siendo el canal para productos sin precio y asesoría (INV §7; ADR-002).
4. **Sin datos personales de empleados.** Se usan canales corporativos, no directorios individuales (INV F16; D-12).
5. **No inventar.** Todo lo desconocido queda marcado y con dueño para resolverlo.

## 7. Restricciones conocidas (hechos)

- Arquitectura: BFF móvil `/mobile/v1` en el Next.js existente, ampliando `ipr/v1` solo donde falte (ADR-001, aprobada). Condiciones C1–C4 pendientes.
- Pago: Wompi vía checkout de WooCommerce en navegador seguro; la app no es PCI (COD §1, ADR-001).
- Precios publicados son por unidad e incluyen IVA; el flete lo elige el cliente en el checkout de WooCommerce (INV §7, COD §1).
- Las imágenes provienen de `iprpartesyrepuestos.com` y `ipr.iprpartesyrepuestos.com` (INV §7).
- El frontend web no tiene pruebas automáticas (COD §2): hay que añadirlas al menos para `/mobile/v1` (ADR-001).

## 8. Supuestos de la visión

| ID | Supuesto | Validación |
|---|---|---|
| V-1 | Existe demanda de compra móvil suficiente para justificar la app (no hay datos de uso móvil de la web). | Pedir a IPR métricas del servidor/hosting; no hay analítica de terceros |
| V-2 | Los clientes aceptan abrir el pago en un navegador seguro del sistema y volver a la app. | Prueba en staging con Wompi sandbox |
| V-3 | WhatsApp con mensaje prellenado es suficiente para el MVP en productos sin precio. | Medición posterior (RF-065) |
| V-4 | Las cuentas de Google Play y Apple Developer estarán a nombre de Inverprimos S.A.S. | D-14 |

## 9. Fuera de la visión del MVP

B2B/mayorista con precios y cupos por rol, cotización estructurada, favoritos sincronizados, notificaciones push, stock por sede, mapa con coordenadas y horarios, campañas promocionales. Ver [scope.md](scope.md) para la justificación de cada uno.

## 10. Riesgos de negocio (resumen)

| Riesgo | Referencia |
|---|---|
| Pérdida de ventas por productos sin precio y clientes B2B atendidos solo por asesores | ADR-002, R-11 en [requisitos](../02_requirements/functional_requirements.md) |
| Cifras institucionales que no concuerdan entre páginas (referencias, sedes, ciudades) | INV §8; D-07 |
| Calidad de datos del catálogo (categorías, especificaciones, precios faltantes), que la app expone más que la web | INV R-05; D-10 |
| Tratamiento de datos personales con nuevos usos (cuenta, dispositivo, push, ubicación) | INV R-07; D-12 |
| Dependencia de terceros (Wompi, Cloudflare, tiendas de aplicaciones) | COD §2; INV R-02 |

# Stakeholders (por rol)

| | |
|---|---|
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. Se documentan **roles**, no personas. Los responsables nominales los asigna IPR (D-15). |
| **Relacionado** | [Visión](vision.md) · [Alcance](scope.md) · [Perfiles](user_personas.md) · [Requisitos funcionales](../02_requirements/functional_requirements.md) · [Decisiones pendientes](../project/decisiones_pendientes.md) |

> Los niveles de influencia/interés son una **propuesta del equipo de proyecto**, a validar con IPR. Los directorios de contacto de la web contienen datos personales de empleados; no se copian aquí.

## 1. Internos de IPR

| Rol | Interés en el proyecto | Qué aporta o decide | Decisiones / requisitos vinculados | Influencia / interés (propuesto) |
|---|---|---|---|---|
| Solicitante / patrocinador del proyecto | Alcance, costo y resultado de negocio | Aprobó ADR-001 y ADR-002; prioriza el MVP | ADR-001, ADR-002, D-06, D-15 | Alta / Alto |
| Gerencia general | Estrategia, presupuesto, titularidad de cuentas de tienda | Presupuesto y equipo; cuentas de Google Play / Apple | D-14, D-15, PA-01, PA-02 | Alta / Alto |
| Dirección comercial | Ventas, precios, cotizaciones, perfil B2B | Define cómo se atiende lo que no tiene precio; SLA; futura política B2B | D-03, D-04, PA-04, PA-07 | Alta / Alto |
| Asesores comerciales (rol) | Reciben consultas por WhatsApp y teléfono | Atienden "Más información" y cotizaciones; validan el mensaje prellenado | RF-062, RF-064, RF-066 | Media / Alto |
| Atención al cliente / PQRS (rol) | Reciben y responden PQRS | Buzón corporativo, tiempos de respuesta | RF-096, RF-097, PA-07 | Media / Medio |
| Ingeniería IPR (rol) | Imagen técnica y exactitud de la calculadora | Valida la fórmula BTU y el texto de descargo; canal de asesoría técnica | D-08, RF-080, RF-085 a RF-089, PA-06 | Media / Alto |
| Marketing | Marca, cifras institucionales, contenido, campañas | Fuente de verdad de cifras, manual de marca, contenido de capacitaciones | D-07, D-13, RF-008, RF-082, RF-103 | Media / Medio |
| Catálogo / comercial (rol) | Calidad de datos de productos | Reglas mínimas de categoría, descripción, imágenes, precio | D-10, RF-010, RF-014, RF-028 | Media / Alto |
| Operaciones | Sedes | Hoja maestra de sedes (coordenadas, horarios, teléfonos) | D-09, RF-072 a RF-078 | Media / Medio |
| TI / equipo web (mantenedor de `ipr-frontend` y WordPress) | Estabilidad de la web y del backend; carga adicional | Aceptar el BFF móvil por PR, staging, Cloudflare, `.well-known`, endpoints de `ipr/v1` | ADR-001 (C1 a C4), D-01, D-05, D-16, RF-019, RF-043 a RF-045, RF-055 | **Alta / Alto** |
| Finanzas | Conciliación de pagos, medios de pago, facturación | Configuración de Wompi, medios habilitados, retención de pedidos | D-02, PA-09, PA-12, RF-053, RF-061 | Media / Medio |
| Jurídico / protección de datos | Ley 1581, términos, política de datos | Política vigente, finalidades de la app, derechos del titular, eliminación de cuenta, registro de bases ante la SIC | D-12, RF-039, RF-099, RF-110, RF-111, PA-08, PA-09 | Alta / Alto |
| Administrador de la tienda (rol) | Mantiene catálogo y contenido en WooCommerce/WordPress | Datos de producto y sedes; usuarios con rol administrativo | RF-019, RF-076, RF-048 | Media / Medio |

## 2. Usuarios finales

| Rol | Interés | Ver |
|---|---|---|
| Visitante | Consultar catálogo, precio y contacto sin registrarse | [user_personas.md](user_personas.md) |
| Cliente registrado | Comprar, ver pedidos, gestionar su cuenta | [user_personas.md](user_personas.md) |
| Cliente B2B / mayorista (futuro, fuera del MVP) | Precios y condiciones comerciales especiales (a validar con IPR) | [user_personas.md](user_personas.md) |

## 3. Terceros y externos

| Rol | Interés | Dependencia / riesgo | Referencia |
|---|---|---|---|
| Wompi (pasarela) | Procesar el pago | Disponibilidad y sandbox para staging; retorno a la app | COD §1; D-02; R-04 |
| Cloudflare (CDN/WAF) | Protección de la web | Puede bloquear o desafiar tráfico de la app | INV R-02; ADR-001 C3 |
| Transportadoras aliadas | Entrega nacional | El cliente elige el envío en el checkout; seguimiento DESCONOCIDO | COD §1; RF-109 |
| Google Play y Apple App Store | Publicar la app | Políticas de privacidad y eliminación de cuenta (supuesto S-05) | D-14 |
| WhatsApp (Meta) | Canal de atención | Canal ya usado por IPR; la app solo abre enlaces | INV F24 |
| Proveedores de hosting (servidor propio del frontend y hosting de WordPress) | Operación | Carga adicional por la app | COD §2; ADR-001 C4 |
| Superintendencia de Industria y Comercio (SIC) | Registro de bases de datos y supervisión de la Ley 1581 | Cumplimiento por parte de IPR | INV R-07; D-12 |
| Marcas aliadas (Danfoss, Midea, Samsung y otras) | Imagen de marca y capacitaciones | Contenido de landings y campañas fuera del MVP | INV F4, F21 |

## 4. Equipo del proyecto de la app

| Rol | Responsabilidad en esta fase |
|---|---|
| Analista de negocio | Requisitos, alcance, perfiles (este conjunto de documentos) |
| Arquitecto | ADR, contratos `/mobile/v1`, seguridad |
| Desarrollo Flutter y backend | Implementación (fases posteriores) |
| QA / seguridad | Criterios de aceptación, pruebas de contrato, `npm audit` y auditoría repetida (COD §5.2) |

## 5. Preguntas abiertas sobre stakeholders

| # | Pregunta | Cómo se obtiene |
|---|---|---|
| 1 | ¿Quién mantiene hoy `ipr-frontend` y `ipr/v1`, y acepta el BFF móvil en ese repositorio? | Condición C1 de ADR-001; entrevista con TI |
| 2 | ¿Hay un responsable por área para D-05, D-07, D-09, D-10? | Gerencia (D-15) |
| 3 | ¿Quién atiende el WhatsApp corporativo y en qué horario? | PA-07 |
| 4 | ¿Existe un oficial de protección de datos designado? | Jurídico (D-12) |

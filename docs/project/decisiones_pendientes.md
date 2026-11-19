# Decisiones pendientes que requieren aprobación humana

> Origen: `docs/00_discovery/informe_investigacion.md` (Entrega 1). Fecha: 2026-11-17.
> **Regla del proyecto:** no se avanza a una etapa si hay decisiones críticas abiertas que puedan cambiar la arquitectura.
> **Bloqueante** = cambia arquitectura o alcance del MVP. **Importante** = cambia diseño o plan, no la arquitectura.

> **Actualización 2026-11-18 (código del frontend leído, ver `docs/00_discovery/informe_codigo_frontend.md` §7):**
> D-01 → **APROBADA el 2026-11-18** por el solicitante: BFF móvil `/mobile/v1` en el proyecto Next.js + ampliar `ipr/v1` (ver ADR-001 en `docs/03_architecture/architecture_decisions.md`). Condiciones C1–C4 pendientes (conformidad del responsable técnico, staging, Cloudflare, piloto de carga).
> **Decisiones de alcance del MVP (aprobadas por el solicitante el 2026-11-18):**
> D-06 → **MVP con compra completa** (carrito + checkout Wompi en navegador seguro).
> D-03 → **Sin B2B en el MVP**: un solo perfil con precio público (IVA incluido); B2B a fase 2.
> D-04 → **Productos sin precio: solo WhatsApp** (igual que la web hoy); sin formulario ni estados de cotización en el MVP. Cotización estructurada → fase 2.
> Consecuencia: el módulo G (Cotizaciones) del prompt maestro baja a *Should/Could* y el MVP no necesita backend de cotizaciones ni CRM.
> D-02 → pasarela = Wompi vía WooCommerce; resta confirmar webhooks/doble pago.
> D-03 → el código no distingue B2B; es decisión de negocio.
> D-09 → confirmado que no hay coordenadas ni horarios.
> D-08 → fórmula conocida; falta validación de Ingeniería.

## A. Decisiones bloqueantes (responder antes de la Tercera Entrega: Arquitectura)

| ID | Decisión / pregunta | Por qué importa | Opciones | Recomendación inicial | Quién decide / aporta | Cómo se obtiene el dato |
|---|---|---|---|---|---|---|
| **D-01** (P-01, P-02, P-03) | **¿Cómo hablará la app con el backend?** ¿Se puede acceder al código/entorno de WooCommerce y del Next.js, y qué API existe de verdad (WC REST, Store API, GraphQL)? | Define si se reutiliza algo o se construye una capa móvil nueva. Sin esto la arquitectura de integración es hipótesis. | (a) Consumir la API de WooCommerce directamente. (b) **BFF móvil dedicado `/v1`** que traduce a WooCommerce. (c) Endpoints móviles nuevos dentro del Next.js actual. | **(b) o (c)**, nunca consumir `/api/*` actuales ni llegar directo a la base de datos. Decidir con acceso al código. | Líder técnico web de IPR + arquitecto | Acceso de lectura al repo / reunión técnica de 1 h con el equipo web. |
| **D-02** (P-04) | **Pasarela de pago:** ¿cuál es, qué medios habilita y cómo confirma pagos (webhooks)? ¿Se pagará en la app (SDK/checkout seguro) o se abrirá la página de pago en navegador seguro? | Define PCI, deep links de retorno, idempotencia y esfuerzo del checkout. | (a) Navegador seguro con la página de pago actual. (b) SDK móvil del proveedor. (c) MVP sin pago en línea: solo cotización/pedido por asesor. | Evaluar tras conocer la pasarela; **(a) es la ruta más barata y segura para el MVP**. | Gerencia + finanzas + equipo web | Pregunta directa + revisión del plugin de pagos de WooCommerce. |
| **D-03** (P-05, P-08) | **Perfiles y precios B2B/mayorista:** ¿qué perfiles existen y qué ve cada uno (precios, cupo, aprobación)? | Define modelo de permisos, qué precio mostrar y riesgos de fuga de tarifas. | (a) Un solo perfil en MVP (público con IVA). (b) Cliente registrado + B2B con precios por rol entregados por el servidor. | (a) para MVP salvo que el negocio exija B2B; (b) en fase 2. | Dirección comercial | Entrevista con comercial; revisar cómo se crea la cuenta "B2B". |
| **D-04** (P-09) | **Cotizaciones:** ¿se gestionan en la app y quién las responde (CRM, correo, WhatsApp)? | Hoy 3 de 7 productos de la muestra no tienen precio. Es el flujo comercial más importante que la web no resuelve. | (a) Formulario + envío a asesor (correo/CRM). (b) Cotización con estado y seguimiento en la app (requiere backend nuevo). | **(a) en MVP; (b) en fase 2.** | Dirección comercial + TI | Confirmar canal, SLA y responsables. |
| **D-05** (P-06) | **Stock y precio en tiempo real:** ¿qué sistema es la fuente (ERP/WooCommerce)? ¿Hay stock por sede? ¿Con qué frecuencia sincroniza? | Define si se muestra "En stock" genérico o disponibilidad por sede, y qué se puede cachear. | (a) Estado genérico "en stock / consultar". (b) Disponibilidad por sede. | (a) en MVP salvo que exista dato confiable por sede. | TI / operaciones | Reunión con TI; dependiente de D-01. |
| **D-06** (P-10, P-11) | **Compra en la app en el MVP:** ¿carrito + checkout, o catálogo + cotización/WhatsApp primero? ¿Invitado permitido? ¿Flete automático? | Cambia el tamaño y el riesgo del MVP (pagos, seguridad, QA). | (a) MVP con compra completa. (b) MVP catálogo + cotización + cuenta; compra en fase 2. | Decidir después de D-01/D-02. Si el pago o el flete no están listos, **(b)**. | Gerencia | Taller de priorización (Segunda Entrega). |

## B. Decisiones importantes (no bloquean la arquitectura)

| ID | Decisión / pregunta | Responsable | Dato necesario |
|---|---|---|---|
| **D-07** | **Fuente de verdad de cifras institucionales** (referencias, sedes, ciudades). | Marketing | Cifras oficiales y quién las mantiene. |
| **D-08** | **Calculadora BTU:** fórmula, factores, rangos, responsable técnico y texto de descargo. | Ingeniería IPR | Documento técnico de la fórmula actual. |
| **D-09** | **Datos de sedes:** coordenadas, horarios, teléfonos por área. | Operaciones | Hoja maestra de sedes. |
| **D-10** | **Calidad del catálogo:** reglas mínimas (categoría correcta, descripción, imágenes, precio) y especificaciones técnicas estructuradas / fichas PDF por producto. | Catálogo / comercial | Auditoría de datos (muestra amplia). |
| **D-11** | **Notificaciones push:** qué eventos y qué promociones autorizadas; consentimiento. | Comercial + legal | Lista de eventos. |
| **D-12** (P-12) | **Revisión legal (Ley 1581):** política de datos vigente, finalidades para la app (push, ubicación, favoritos), derechos del titular, eliminación de cuenta, registro de bases ante la SIC. | Jurídico de IPR | PDF de política y términos (requiere su autorización para descargarlos o que los entreguen). |
| **D-13** | **Manual de marca** y activos (logo vectorial, paleta oficial, fuentes y licencias). ¿Modo oscuro en la app? | Marketing / diseño | Manual de marca. |
| **D-14** | **Cuentas de tienda:** Google Play Console y Apple Developer a nombre de Inverprimos S.A.S.; responsable de firmas y claves. | Gerencia / TI | Confirmar titularidad. |
| **D-15** | **Presupuesto y equipo disponibles** (para estimar esfuerzo sin inventar fechas). | Gerencia | Recursos asignados. |
| **D-16** | **Autorización para contactar** (solo lectura) al equipo web y para sondear en *staging* los endpoints de WooCommerce y del BFF. No se hizo en producción. | Líder técnico web | Autorización explícita. |

## C. Lo que haré sin necesidad de decisión adicional

- Segunda Entrega (requisitos, perfiles, MoSCoW, MVP **provisional**) con los supuestos explícitos de arriba.
- Marcar toda dependencia de D-01..D-06 como **supuesto** hasta que se resuelva.

## D. Qué necesito de ti ahora

1. **Confirmar si sigo con la Segunda Entrega** con supuestos provisionales, o si prefieres esperar respuestas de D-01 a D-06.
2. **Compartir lo que tengas disponible:** repositorios, documentación, accesos de solo lectura, manual de marca, política de datos.
3. **Indicar si autorizas que descargue y lea los PDF legales públicos** del sitio (términos, política de datos, código de ética, política ambiental).

---

## E. Decisiones humanas propuestas por el Revisor de Consistencia (2026-11-18) — **PENDIENTES, NO APROBADAS**

> Origen: `docs/project/resolucion_inconsistencias.md` §4.3 (89 contradicciones CR-001..CR-089). Las recomendaciones **no están aprobadas**: mientras tanto los documentos de la oleada 5 las tratan como **supuestos marcados `SUP-H`**. Las decisiones D-xx de arriba siguen vigentes.

| # | Pregunta | Recomendación del revisor | Estado |
|---|---|---|---|
| H-01 | Enmienda de ADR-001 §2: `ipr/v1/m/*` incluye registro, perfil, direcciones, pedidos, consentimientos, config y sedes (CR-038) | Sí | **Pendiente** |
| H-02 | Retorno del pago por `/app/pedido` y resultado confirmado siempre consultando al servidor; fusionar ADR-017 en ADR-008 (CR-001..003) | Sí | **Pendiente** |
| H-03 | Registro con correo existente: respuesta uniforme + verificación de correo en el MVP, o 409 con riesgo firmado (CR-030) | Uniforme + verificación | **Pendiente** |
| H-04 | Vidas de token: access 15 min; refresh 30 d de inactividad / 90 d absolutos (CR-022, 025) | Sí | **Pendiente** |
| H-05 | MVP solo con "cerrar todas las sesiones" (incluida la web); lista de dispositivos en fase 2 (CR-027) | Solo cerrar todas | **Pendiente** |
| H-06 | Productos "bajo pedido": ¿comprables en la app? (CR-017) | No (WhatsApp) | **Pendiente** |
| H-07 | Carrito: se conserva al cerrar sesión y se borra al eliminar la cuenta (CR-040) | Conservar y borrar | **Pendiente** |
| H-08 | Detalle de pedido con envío, descuento e impuestos (cambia AC-108-2) (CR-053) | Sí | **Pendiente** |
| H-09 | Solo `customer` y `subscriber` sin capacidades administrativas pueden iniciar sesión (CR-028) | Sí, tras contar roles | **Pendiente** |
| H-10 | Sin compra como invitado en el MVP (CR-013) | Sin invitado | **Pendiente** |
| H-11 | (Jurídico) Eliminación de cuenta sin periodo de gracia, supresión ≤ 15 días hábiles, retención contable fijada por Jurídico (CR-081, 083) | Sin gracia | **Pendiente (jurídico)** |
| H-12 | Autorizar staging con Wompi sandbox y acceso de solo lectura al servidor para resolver los 8 DESCONOCIDOS (CR-018, 035, 075, 079…) | Sí | **Pendiente** |

**Siguen abiertas sin decisión humana:** doble pago y webhook de Wompi (TM-027, D-02/PA-11), D-05 (stock por sede), D-08 (fórmula BTU), D-12 (retención y Ley 1581), conformidad del responsable técnico (ADR-001 C1) y existencia de staging (C2).

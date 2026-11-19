# Registro maestro de decisiones — App móvil IPR

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fecha** | 2026-11-18 |
| **Estado** | **BORRADOR de consolidación.** Registra el estado de cada decisión **según la documentación existente**; no aprueba nada. |
| **Relacionado** | [roadmap.md](roadmap.md) · [risks.md](risks.md) · [implementation_plan.md](implementation_plan.md) · [architecture_decisions.md](../03_architecture/architecture_decisions.md) · [decisiones_pendientes.md](decisiones_pendientes.md) · [resolucion_inconsistencias.md](resolucion_inconsistencias.md) |

> **Aviso central.** **Lo que el humano ya aprobó es solo esto:** **ADR-001** (BFF móvil `/mobile/v1`, equivalente a **D-01**), **ADR-002** (alcance del MVP) y las decisiones de alcance **D-06** (compra completa), **D-03** (sin B2B) y **D-04** (productos sin precio solo por WhatsApp), todas el 2026-11-18 por el solicitante. **Todo lo demás es propuesta, pendiente o abierto**, incluidas las recomendaciones H-01..H-12, que en los documentos de la oleada 5 se tratan como supuestos marcados **`SUP-H`**.

## 1. Convenciones

| Estado | Significado en este registro |
|---|---|
| **Aprobada** | Decidida por un humano y registrada así en [decisiones_pendientes.md](decisiones_pendientes.md) o [architecture_decisions.md](../03_architecture/architecture_decisions.md). |
| **Propuesta** | Decisión redactada (p. ej. una ADR) o recomendación del equipo de proyecto, **a la espera de aprobación**. |
| **Pendiente** | Pregunta cerrada, con recomendación, que requiere respuesta humana. |
| **Abierta** | Decisión o dato sin resolver; puede no tener recomendación cerrada o depender de información externa. |

**Fechas:** las decisiones D-01..D-16 se plantean el 2026-11-17 ([decisiones_pendientes.md](decisiones_pendientes.md), cabecera). Todo lo demás se registró el 2026-11-18. **El orden dentro de ese día no consta en los documentos**, por lo que no se inventa una hora ni una secuencia más fina.

### 1.1 Recuento

| Familia | Total | Aprobada | Propuesta | Pendiente | Abierta |
|---|---|---|---|---|---|
| ADR-001..022 | 22 | **2** (ADR-001, ADR-002) | 20 (incluye ADR-017, cuya fusión en ADR-008 se propone) | — | — |
| D-01..D-16 | 16 | **4** (D-01, D-03, D-04, D-06) | — | — | 12 (D-02 parcial; D-05, 07..16) |
| H-01..H-12 (`SUP-H`) | 12 | 0 | — | 12 | — |
| DN-01..DN-14 | 14 | 0 | — | 14 | — |
| DM-01..DM-09 | 9 | 0 | — | 9 | — |
| DA-01..DA-15 | 15 | 0 | — | 15 | — |
| AP-01..AP-10 | 10 | 0 | — | 10 | — |
| PA-01..PA-12 | 12 | 0 | — | — | 12 |
| Condiciones C1..C4 de ADR-001 | 4 | 0 | — | — | 4 |
| Preguntas legales J-01..J-36 | 36 | 0 | — | — | 36 |

---

## 2. Lo que el humano YA aprobó

| ID | Decisión | Fecha | Quién aprobó | Documentos afectados | Qué desbloquea | Condiciones o límites |
|---|---|---|---|---|---|---|
| **ADR-001** (= **D-01**) | La app consume un **BFF móvil `/mobile/v1`** dentro del Next.js existente; `ipr/v1` se amplía solo donde falte; la app nunca llama a `wc/v3`, `wp/v2`, `/api/*`; el pago se abre en navegador seguro; contratos en OpenAPI versionado | 2026-11-18 | Solicitante del proyecto | architecture_decisions; FR §0.1; scope §1; OV; api_architecture; todo `05_api/` | Toda la arquitectura de integración | **Condiciones abiertas:** C1 (conformidad del responsable técnico), C2 (staging), C3 (Cloudflare), C4 (piloto de carga). **Dos textos propuestos por el revisor (no aprobados):** aclaración de §4 (CR-002) y enmienda de §2 (CR-038) → H-01, H-02 |
| **ADR-002** | **MVP con compra completa**, sin B2B, cotización solo por WhatsApp | 2026-11-18 | Solicitante | scope; FR; vision; ADR | Alcance del MVP (76 RF) | Obliga a sesiones por dispositivo, rate limiting, App Links y staging con Wompi sandbox |
| **D-06** | Compra en la app en el MVP: carrito + checkout con Wompi en navegador seguro | 2026-11-18 | Solicitante | scope §1; FR S-02; ADR-002 | M3 | La opción (b) "compra en fase 2" solo si los DESCONOCIDOS de Wompi no se resuelven: **sería una decisión nueva** |
| **D-03** | Sin B2B en el MVP: un solo perfil con precio público IVA incluido | 2026-11-18 | Solicitante | scope; FR S-04; ADR-002 | Sin modelo de permisos por rol; caché pública única | B2B pasa a fase 2; RF-114 propuesto (CR-089) |
| **D-04** | Productos sin precio: solo "Más información" → WhatsApp; sin formulario ni estados de cotización | 2026-11-18 | Solicitante | scope; FR RF-012, 030, 062; ADR-002 | Módulo G reducido; sin backend de cotizaciones | Cotización estructurada a fase 2 |

---

## 3. ADR-001 a ADR-022

Decisor propuesto: para ADR-003..012, "Solicitante + responsable técnico" (DA-01); para ADR-013..022, "responsable técnico web + seguridad" (AP-01). Recomendación del revisor: [resolución §3](resolucion_inconsistencias.md).

| ADR | Decisión (resumen) | Estado | Fecha | Documentos afectados | Qué desbloquea / observación |
|---|---|---|---|---|---|
| ADR-001 | BFF `/mobile/v1` + ampliación acotada de `ipr/v1` | **Aprobada** | 2026-11-18 | ver §2 | Ver §2. Enmienda CR-038 y aclaración CR-002 **propuestas** |
| ADR-002 | MVP con compra, sin B2B, cotización por WhatsApp | **Aprobada** | 2026-11-18 | ver §2 | Ver §2 |
| ADR-003 | Arquitectura *feature-first* con dominio ligero | Propuesta | 2026-11-18 | OV §9; FA §2-4 | Estructura del repositorio de la app (PT-13). Revisor: aprobar |
| ADR-004 | Riverpod 3 sin generador en el MVP | Propuesta | 2026-11-18 | OV §9; FA §5 | Estado e inyección de dependencias. Revisor: aprobar |
| ADR-005 | go_router y manejo de deep links nativo | Propuesta | 2026-11-18 | OV §9; FA §6 | Navegación y guardas. Revisor: aprobar citando CR-001 (`/app/pedido`) |
| ADR-006 | Dio con taxonomía de fallos tipada | Propuesta | 2026-11-18 | OV §9; FA §7 | Capa de red. Revisor: aprobar tras CR-073 (mapear por `code`) y CR-062 |
| ADR-007 | Persistencia local mínima, sin SQL | Propuesta | 2026-11-18 | OV §9; FA §8 | Almacenamiento. Revisor: aprobar como **única** ADR de almacenamiento en el dispositivo (CR-019, CR-065) |
| ADR-008 | Resultado del pago verificado en el servidor; enlaces como acelerador | Propuesta | 2026-11-18 | OV §9; FA §6.3; RF-055 | Checkout fiable (PT-16). Revisor: aprobar **absorbiendo ADR-017** (CR-001..004; H-02) |
| ADR-009 | *Flavors* y cero secretos en el binario | Propuesta | 2026-11-18 | OV §9; FA §16 | Entornos dev/staging/prod. Revisor: aprobar; corregir cita en TS §5.1 (CR-084) |
| ADR-010 | Observabilidad detrás de interfaces; proveedor según DN-02 | Propuesta | 2026-11-18 | OV §9; PA §6 | Reporte de fallos. Revisor: aprobar **condicionada a Jurídico** (J-12) |
| ADR-011 | Sin *pinning* ni detección de root en el MVP | Propuesta | 2026-11-18 | OV §9; SA §7.3 | Revisor: aprobar **con aceptación firmada** (DA-15, CH-22) |
| ADR-012 | Estrategia de pruebas con Alchemist y `patrol` (condicionada a SPK-01) | Propuesta | 2026-11-18 | OV §9; TS | Revisor: aprobar; corregir citas (CR-084) |
| ADR-013 | Sesiones por dispositivo con tokens opacos validados en WordPress | Propuesta | 2026-11-18 | ARQ §18; AUT §3 | **Ruta crítica** (PT-07). Revisor: aprobar con los valores de CR-022 (15 min / 30 d de inactividad / 90 d absolutos) |
| ADR-014 | `ipr/v1/m/*` solo accesible por el BFF con secreto propio | Propuesta | 2026-11-18 | ARQ §18; SA | Revisor: aprobar **junto con la enmienda CR-038 (H-01)** |
| ADR-015 | Rate limiting en tres capas sin Redis | Propuesta | 2026-11-18 | ARQ §18 | Revisor: aprobar **condicionada** a verificar SA-01 (un solo proceso Node); si hay más, Redis pasa a P0 (CR-035) |
| ADR-016 | Errores RFC 9457 y semántica 404/502/503/504 | Propuesta | 2026-11-18 | ARQ §18 | Revisor: aprobar (CR-029, CR-069) |
| ADR-017 | Resultado del pago con `checkoutRef`; `/app/*` | Propuesta (**retiro propuesto: fusionada en ADR-008**, CR-003; el número no se reutiliza) | 2026-11-18 | ARQ §18; más de 30 citas | Su contenido de servidor pasa a ADR-008 |
| ADR-018 | Sedes y configuración remota administrables en WordPress | Propuesta | 2026-11-18 | ARQ §18 | Revisor: aprobar tras la enmienda de ADR-001 |
| ADR-019 | Descripción de producto como HTML saneado en servidor, sin contenido activo | Propuesta | 2026-11-18 | ARQ §18; FA | Revisor: aprobar; AP-10, DA-14, SPK-04 |
| ADR-020 | Paginación por offset con tamaños fijos {12, 24, 48} | Propuesta | 2026-11-18 | ARQ §18 | Revisor: aprobar; ajustar RF-011, RNF-011, AC-011-2 (CR-077) |
| ADR-021 | Recuperación de contraseña: solicitud por API, restablecimiento en WordPress | Propuesta | 2026-11-18 | ARQ §18 | Revisor: aprobar; ajustar RF-042 y AC-042-2 (CR-031) |
| ADR-022 | Eliminación de cuenta en dos tiempos | Propuesta | 2026-11-18 | ARQ §18; AUT §12 | Revisor: aprobar la parte técnica; **plazos y retención tras Jurídico** (CR-083, H-11) |
| ADR-023 (candidata) | Registro sin enumeración y verificación de correo | **No existe aún**; se crearía si se aprueba H-03(b) (CR-030) | — | resolución §3 | — |
| ADR-024 (candidata) | Evidencia de la autorización en PQRS | **No existe aún**; tras Jurídico (CR-056, DM-04) | — | resolución §3 | — |

**Observación de gobierno (CR §3):** hoy `architecture_decisions.md` solo contiene ADR-001 y ADR-002; ADR-003..012 viven en `architecture_overview.md §9` y ADR-013..022 en `api_architecture.md §18`. Se propone copiarlas al registro único cuando se aprueben y mantener ADR-017 como "Retirada — fusionada en ADR-008".

---

## 4. D-01 a D-16 (decisiones del informe de investigación)

| ID | Decisión | Estado | Fecha | Quién decide | Documentos afectados | Qué desbloquea / observación |
|---|---|---|---|---|---|---|
| D-01 | Cómo habla la app con el backend | **Aprobada** (= ADR-001) | 2026-11-17 planteada; 2026-11-18 aprobada | Solicitante | ADR-001 | Arquitectura de integración. Enmienda → H-01 |
| D-02 | Pasarela: **hecho** (Wompi vía checkout de WooCommerce); **abierto:** webhooks, estados y doble pago | **Abierta (parcial)** | 2026-11-17; actualizada 2026-11-18 | Equipo web + Finanzas (+ Gerencia) | COD §7; ARQ §9.2, §13; RF-053, 056, 057; TM-027 | Checkout liberable (RF-056/057); NL-02. Se resuelve con staging (PA-11, PA-12) |
| D-03 | Sin B2B en el MVP | **Aprobada** | 2026-11-18 | Solicitante | scope; ADR-002 | Ver §2 |
| D-04 | Productos sin precio solo por WhatsApp | **Aprobada** | 2026-11-18 | Solicitante | scope; ADR-002 | Ver §2 |
| D-05 | Fuente y granularidad de stock | **Abierta** (supuesto S-01: genérico, sin stock por sede) | 2026-11-17 | TI / Operaciones | RF-011, 026, 031, 050; scope §7 | Si hay stock por sede confiable, cambia ficha, listados y carrito |
| D-06 | Compra completa en el MVP | **Aprobada** | 2026-11-18 | Solicitante | scope; ADR-002 | Ver §2 |
| D-07 | Fuente de verdad de cifras institucionales | **Abierta** | 2026-11-17 | Marketing | RF-008, 072; INV §8 | Textos del inicio y de sedes |
| D-08 | Calculadora BTU: validación de la fórmula, factores, descargo | **Abierta** (fórmula conocida; falta validación de Ingeniería) | 2026-11-17; actualizada 2026-11-18 | Ingeniería IPR | RF-085..089; COD §6 | Módulo K en el MVP; si no se cierra, sale |
| D-09 | Datos de sedes: coordenadas, horarios, teléfonos | **Abierta** (confirmado que hoy no existen) | 2026-11-17; actualizada 2026-11-18 | Operaciones | RF-072..078; ADR-018 | RF-077 pasa al MVP solo si llega la hoja maestra a tiempo |
| D-10 | Calidad del catálogo y especificaciones | **Abierta** | 2026-11-17 | Catálogo / comercial | RF-010, 014, 028; RNF-106..116; MED-06 | NL-13, QG-R09 |
| D-11 | Push: eventos y consentimiento | **Abierta** (fase 2) | 2026-11-17 | Comercial + Jurídico | RF-090..093; J-28 | Fase 2 |
| D-12 | Revisión legal (Ley 1581) | **Abierta** | 2026-11-17 | Jurídico de IPR | RF-039, 065, 099, 110, 111; RNF-056..066; NL-07; PA §10 (36 preguntas) | M2, M4, tiendas, lanzamiento |
| D-13 | Manual de marca, paleta, fuentes, modo oscuro | **Abierta** | 2026-11-17 | Marketing / diseño | RF-113; RNF-069; DA-07, DA-08 | Design system (PT-13) |
| D-14 | Cuentas de Google Play y Apple a nombre de Inverprimos S.A.S.; firmas | **Abierta** | 2026-11-17 | Gerencia / TI | NL-11; SC-040; DA-12 | Identificadores de app, `.well-known`, lanzamiento |
| D-15 | Presupuesto y equipo | **Abierta** | 2026-11-17 | Gerencia | Todo el plan; DN-13 | Estimación real; pentest; herramientas |
| D-16 | Autorización para sondear staging y contactar al equipo web (solo lectura) | **Abierta** (forma parte de H-12) | 2026-11-17 | Líder técnico web | MED-xx; DESCONOCIDOS | Etapa 0; pruebas de seguridad y carga |

---

## 5. H-01 a H-12 (recomendaciones del revisor de consistencia, `SUP-H`)

> Origen: [resolución §4.3](resolucion_inconsistencias.md) y [decisiones_pendientes §E](decisiones_pendientes.md). **Ninguna está aprobada.** Mientras tanto, los documentos las tratan como `SUP-H`. Decisor propuesto: el solicitante, salvo H-11 (Jurídico).

| ID | Pregunta | Recomendación del revisor | Estado | Fecha | Documentos afectados | Qué desbloquea |
|---|---|---|---|---|---|---|
| H-01 | Enmendar ADR-001 §2: `ipr/v1/m/*` incluye registro, perfil, direcciones, pedidos, consentimientos, config y sedes (CR-038) | Sí | **Pendiente** | 2026-11-18 | ADR-001; OV §2.1; decisiones_pendientes | **Gate G1:** alcance de PT-07/08/09/10; ADR-014, ADR-018 |
| H-02 | Retorno del pago por `/app/pedido`; resultado siempre consultado al servidor; fusionar ADR-017 en ADR-008 (CR-001..003) | Sí | **Pendiente** | 2026-11-18 | RF-055; AC-055; FA §6; OV; ARQ; CON; DF; SA | PT-11 (`.well-known`), PT-06 (EP-24), PT-16 |
| H-03 | Registro con correo existente: respuesta uniforme + verificación de correo en el MVP, o `409` con riesgo firmado (CR-030) | Uniforme + verificación | **Pendiente** | 2026-11-18 | RF-046; AC-038-5; ARQ §6.3; YAML; TC-007, TC-098 | M2 y PT-09; **cambia el alcance** (RF-046 pasa a Must/MVP) |
| H-04 | Vidas de token: access 15 min; refresh 30 d de inactividad / 90 d absolutos; revocación inmediata (CR-022, 025) | Sí | **Pendiente** | 2026-11-18 | RNF-039/040; RF-044; AC-044-3; TC-020; ADR-013 | **Gate G1:** PT-07 (equivale a AP-02 / DN-04) |
| H-05 | MVP solo con "cerrar todas las sesiones" (incluida la web); lista de dispositivos en fase 2 (CR-027) | Solo cerrar todas | **Pendiente** | 2026-11-18 | RNF-040; RF-112; AUT §16 | PT-07, M2 (equivale a AP-11) |
| H-06 | Productos "bajo pedido": ¿comprables en la app? (CR-017) | No (WhatsApp) | **Pendiente** | 2026-11-18 | RF-031; CON `ProductSummary`; PA-12 | M1/M3 (`purchasable`) (equivale a AP-04 / DA-06) |
| H-07 | Carrito: se conserva al cerrar sesión y se borra al eliminar la cuenta (CR-040) | Conservar y borrar | **Pendiente** | 2026-11-18 | FA §8; DM §5.3; AC-041-7; RNF-062 | M2, M4 (equivale a DA-09 / DN-10 en parte) |
| H-08 | Detalle de pedido con envío, descuento e impuestos (cambia AC-108-2) (CR-053) | Sí | **Pendiente** | 2026-11-18 | AC-108-2; OpenAPI `OrderDetail`; TC-085 | PT-08 (WP-07), M4 |
| H-09 | Solo `customer` y `subscriber` sin capacidades administrativas pueden iniciar sesión, tras contar roles (CR-028) | Sí | **Pendiente** | 2026-11-18 | RF-048; ARQ AP-03; AUT §3.7; SC-011 | PT-07 y PT-08 (equivale a AP-03 / PA-03); requiere el recuento de roles en staging |
| H-10 | Sin compra como invitado en el MVP (CR-013) | Sin invitado | **Pendiente** | 2026-11-18 | FR S-02, PA-01; RF-047; TC-061 | M3 (cierra PA-01) |
| H-11 | (Jurídico) Eliminación de cuenta sin periodo de gracia, supresión ≤ 15 días hábiles, retención fijada por Jurídico (CR-081, 083) | Sin gracia | **Pendiente (jurídico)** | 2026-11-18 | ADR-022; AUT §12; CON EP-12; PA J-04, J-05, J-17 | PT-09 final y M4; **Gate G4** |
| H-12 | Autorizar staging con Wompi sandbox y acceso de solo lectura al servidor para resolver los 8 DESCONOCIDOS (CR-018, 035, 075, 079…) | Sí | **Pendiente** | 2026-11-18 | Anexo B de la resolución; D-16; C2 | **Gate G1:** Etapa 0 y PT-02 |

**Siguen abiertas sin decisión humana** (decisiones_pendientes §E): doble pago y webhook de Wompi (TM-027, D-02, PA-11), D-05, D-08, D-12, conformidad del responsable técnico (C1) y existencia de staging (C2).

---

## 6. Condiciones de ADR-001 (C1 a C4)

| ID | Condición | Estado | Quién | Qué desbloquea |
|---|---|---|---|---|
| C1 | El responsable técnico de `ipr-frontend` y WordPress acepta el cambio y la revisión por PR | **Abierta** | TI / equipo web | **Gate G1**; NL-12 |
| C2 | Existe staging (frontend + WooCommerce + Wompi sandbox) antes de tocar producción | **Abierta** (existencia DESCONOCIDA) | TI / equipo web | **Gate G1**; E2E; NLS-08 |
| C3 | Cloudflare permite el tráfico de la app con reglas propias, sin desactivar la protección general | **Abierta** | TI | PT-11; QG-R05; RK-021 |
| C4 | Un piloto demuestra que la carga móvil no degrada la web | **Abierta** | TI + Web | Lanzamiento (G4); RK-019 |

---

## 7. DN-01 a DN-14 (decisiones propuestas por los requisitos no funcionales)

Fuente: [NFR §3](../02_requirements/non_functional_requirements.md). Todas **Pendiente**, 2026-11-18.

| ID | Decisión | Recomendación inicial | Quién decide | Qué desbloquea |
|---|---|---|---|---|
| DN-01 | Versiones mínimas de Android e iOS | Android 8.0 (API 26) e iOS 15.0, tras MED-01 y SPK-02 | Gerencia + TI | Compatibilidad (RNF-078/079); matriz de dispositivos |
| DN-02 | Proveedor de reporte de fallos y analítica; país de tratamiento | Decidir con Jurídico antes de elegir SDK | Jurídico + TI | ADR-010; NL-09; RK-051 |
| DN-03 | Variantes optimizadas de imagen | Variantes WebP a ancho fijo servidas por BFF/CDN | TI web | RNF-009; RK-026 |
| DN-04 | Política de sesión: vidas, rotación, máx. dispositivos | Access 15 min; refresh rotativo con detección de reutilización | TI web + seguridad | PT-07 (= H-04 / AP-02) |
| DN-05 | *Certificate pinning* | No en el MVP | Seguridad + TI | ADR-011; DA-15 |
| DN-06 | Disponibilidad y soporte (horario, canal, incidentes) | 99,5 % mensual; soporte en horario comercial | Gerencia + TI | RK-008; PT-22 |
| DN-07 | Perfil de carga esperado | Definir con MED-01 y Comercial | Comercial + TI | RNF-014; prueba de carga |
| DN-08 | Retención de datos y logs; qué se conserva al eliminar la cuenta | Definir con Jurídico/Finanzas (PA-09) | Jurídico + Finanzas | WP-09; M4 |
| DN-09 | Almacén compartido (Redis) para límites y sesiones | Sí si hay más de un proceso o si MED-04 lo exige | TI web | ADR-015; RK-020 |
| DN-10 | Alcance de la lectura sin conexión | Catálogo visitado + sedes + carrito; sin PII en caché persistente | Producto + TI | RNF-020; DA-10 |
| DN-11 | Orientación y tablets | Teléfonos en vertical; horizontal/tablet "usable" | Producto | RNF-081 |
| DN-12 | Verificación de correo antes de la primera compra | Sí | Producto + seguridad | RF-046; = H-03 / PA-02 |
| DN-13 | Pruebas de penetración independientes | Sí, antes del lanzamiento | Gerencia (D-15) | CH-21; Etapa 5 |
| DN-14 | Política de versión mínima y soporte de `/mobile/v1` | `v1` ≥ 12 meses tras publicar `v2`; versión mínima forzable | TI + Producto | RNF-029; RK-047 |

---

## 8. Decisiones técnicas propuestas en los documentos de datos, API y arquitectura

### 8.1 DM-01 a DM-09 ([data_model §9.4](../04_database/data_model.md)) — todas **Pendiente**, 2026-11-18

| ID | Decisión | Recomendación | Quién decide | Qué desbloquea |
|---|---|---|---|---|
| DM-01 | ¿`UserProfile.id` viaja a la app? | No; usar id opaco si hace falta | Arq API + Móvil | Contrato `/me` |
| DM-02 | ¿Cédula/NIT en el perfil? | No persistirla en el perfil del MVP | Equipo web + Jurídico | RK-053; WP-08 |
| DM-03 | Unificar el almacenamiento de direcciones (`billing_*` nativas) antes de WP-08 | Claves nativas de WooCommerce | Equipo web | CR-045; PT-09 |
| DM-04 | Autorización de visitantes (PQRS, boletín) | Opción A (`user_id` nulo + `subject_hash`) o B (persistir PQRS mínima); decidir con Jurídico | Jurídico + Arq | RK-054; EP-27 |
| DM-05 | Importes en el contrato | Entero COP, `null` sin precio (CR-047) | Arq API | OpenAPI `1.0.0` |
| DM-06 | Identificador de pedido en la app | `id` en rutas, `number` para mostrar (CR-054) | API + Móvil | FA §6.1 |
| DM-07 | Ruta de retorno del pago | `/app/pedido` (CR-001) | API + Móvil | = H-02 |
| DM-08 | Derechos del titular: revocación de consentimiento y exportación | Definir canal con radicado | Jurídico + API | RF-111 |
| DM-09 | Fuente canónica del `slug` de marca | Taxonomía `product_brand` (= AP-05) | Catálogo + equipo web | RF-016 |

### 8.2 AP-01 a AP-10 ([api_architecture §17.3](../05_api/api_architecture.md)) — todas **Pendiente**, 2026-11-18

| ID | Decisión | Recomendación | Quién decide |
|---|---|---|---|
| AP-01 | Aprobar ADR-013..022 | Aprobar | Responsable técnico web + seguridad |
| AP-02 | Vidas de tokens; máx. 10 sesiones por usuario | Aprobar (= DN-04 = H-04) | TI + seguridad |
| AP-03 | Roles que pueden iniciar sesión | `customer` y `subscriber` (= H-09 = PA-03) | Equipo web |
| AP-04 | `on_backorder` comprable | No en el MVP (= H-06 = DA-06) | Comercial |
| AP-05 | Fuente canónica de marcas | Taxonomía con logos del registro (= DM-09) | Catálogo + equipo web |
| AP-06 | Orden por precio con productos sin precio | Aceptar el comportamiento de WooCommerce y documentarlo | Producto |
| AP-07 | Fuente administrable de sedes y configuración (ADR-018) | WordPress | Operaciones + equipo web |
| AP-08 | Plan de Cloudflare: reglas de caché y rate limit para `/mobile/v1` | Verificar y configurar en staging | TI |
| AP-09 | Atestación de app (Play Integrity / App Attest) | Fase 2 | Seguridad |
| AP-10 | Descripción como HTML saneado sin `iframe` | Aprobar | Producto + Móvil |

### 8.3 DA-01 a DA-15 ([flutter_app_architecture §21](../03_architecture/flutter_app_architecture.md)) — todas **Pendiente**, 2026-11-18

| ID | Decisión | Recomendación | Quién decide | Bloquea |
|---|---|---|---|---|
| DA-01 | Aprobar ADR-003..012 | Aprobar | Solicitante + responsable técnico | Inicio de la fundación de la app |
| DA-02 | El BFF provee identificador de intento + `Idempotency-Key` (N-11) y consulta del resultado (N-12) | Sí (ya diseñado como EP-23/EP-24) | Arq API + equipo web | ADR-008; RF-055..057 |
| DA-03 | Alojar `assetlinks.json` y `apple-app-site-association` (solo `/app/*` según CR-001) | Sí | Equipo web | RF-055 (acelerador) |
| DA-04 | Proveedor de reporte de fallos (= DN-02) | Decidir con Jurídico | Jurídico + TI | NL-09 |
| DA-05 | Versiones mínimas Android/iOS (= DN-01) | Tras SPK-02 | Gerencia + TI | Compatibilidad |
| DA-06 | Tratamiento de "bajo pedido" (= H-06) | No comprable hasta decidir | Comercial | RF-031 |
| DA-07 | Verde accesible `#3d7519` para texto | Aprobar | Marketing/diseño (D-13) | RNF-069 |
| DA-08 | Licencia y empaquetado de Poppins / JetBrains Mono | Empaquetar si la licencia lo permite | Marketing (D-13) | Diseño |
| DA-09 | Conservar el carrito al cerrar sesión (parte de H-07) | Conservar | Producto | RNF-062 |
| DA-10 | Alcance y plazos de la caché offline | Tabla propuesta; ajustar con PA-04 | Producto + TI | RNF-020 |
| DA-11 | Estructura de pestañas | Validar con UX | Producto + diseño | Navegación |
| DA-12 | Identificadores de app por *flavor* y titularidad de cuentas (D-14) | `co.ipr.app[.dev\|.staging]` u otros; **definir antes de la fundación** | Gerencia + TI | Publicación; `.well-known` |
| DA-13 | Existencia y dominios de staging (C2) con Wompi sandbox | Imprescindible | Equipo web | E2E; NL-02 |
| DA-14 | Descripciones como HTML nativo o texto plano | HTML nativo tras SPK-04 | Producto + equipo web | RF-027 |
| DA-15 | Aceptar por escrito el riesgo residual sin *pinning* ni root (NL-C7) | Aceptar | Seguridad + Gerencia | Lanzamiento (CH-22) |

---

## 9. Preguntas abiertas y decisiones derivadas

### 9.1 PA-01 a PA-12 ([FR §5](../02_requirements/functional_requirements.md)) — todas **Abierta**

| ID | Pregunta | Quién | Estado de la recomendación |
|---|---|---|---|
| PA-01 | ¿Compra como invitado? | Gerencia + equipo web | Cerrada **solo si se aprueba H-10** (sin invitado) |
| PA-02 | ¿Verificación de correo en el registro o antes de comprar? | Gerencia + equipo web | = H-03 / DN-12 |
| PA-03 | ¿Roles administrativos pueden iniciar sesión? | Equipo web | = H-09 / AP-03 |
| PA-04 | Plazo aceptable de frescura de catálogo | Comercial + TI | Sin recomendación; hoy ≤ 10 min en el diseño (RNF-111) |
| PA-05 | Criterio de "más vendidos" | Marketing + equipo web | Sin recomendación |
| PA-06 | Canal corporativo de ingeniería | Ingeniería | Sin recomendación |
| PA-07 | Quién atiende WhatsApp y PQRS y en cuánto tiempo | Comercial + Atención | Sin recomendación |
| PA-08 | Herramienta y consentimiento de analítica | Gerencia + Jurídico | Apagada hasta decidir (ADR-010) |
| PA-09 | Qué se conserva al eliminar la cuenta y por cuánto | Jurídico + Finanzas | = H-11 / DN-08 |
| PA-10 | ¿La web exige hoy aceptar términos al registrarse? ¿Qué versión rige? | Equipo web + Jurídico | Verificar en `src/components/auth/` |
| PA-11 | Pedido pendiente y doble pago en WooCommerce/Wompi | Equipo web | Staging con Wompi sandbox |
| PA-12 | Medios de pago de Wompi y estados de pedido; ¿se usa "bajo pedido"? | Equipo web + Finanzas | Staging |

### 9.2 Decisiones de producto o legales derivadas de las CR que no tienen H propio

| CR | Decisión | Tipo | Recomendación del revisor | Estado |
|---|---|---|---|---|
| CR-049 | Fuente canónica de la marca (AP-05) | Producto (Catálogo) | Taxonomía primero | Pendiente |
| CR-055 | Teléfono opcional u obligatorio en PQRS | Producto | Opcional (minimización) | Pendiente |
| CR-078 | Sin red: con caché, contenido + aviso; sin caché, error con "Reintentar" | Producto | Sí | Pendiente (cambia AC-009-1) |
| CR-089 | Crear RF-114 (B2B "Won't/fase 2") y convención de "Won't" | Producto | Sí | Pendiente |
| CR-056 | Guardar evidencia de la autorización en PQRS | Legal | Registrar (versión, fecha, canal) sin el cuerpo | Pendiente (J-10) |
| CR-061 | Finalidades del consentimiento | Legal | Mínimo `terms`, `privacy_policy`, `pqrs` | Pendiente (D-12) |
| CR-081 | Retención de pedidos y cuentas | Legal | No adoptar cifra hasta que Jurídico la confirme | Pendiente (J-04, J-05) |
| CR-082 | IP completa en eventos de seguridad ≤ 90 días | Legal | IP truncada salvo eventos de seguridad | Pendiente (J-01) |
| CR-083 | Eliminación: sin gracia, ≤ 15 días hábiles; enum `completed` | Legal/Técnica | Sin gracia (= H-11) | Pendiente |

### 9.3 Preguntas para Jurídico J-01..J-36 ([privacy_assessment §10](../06_security/privacy_assessment.md)) — todas **Abierta**

| Prioridad | Preguntas | Resumen | Bloquea |
|---|---|---|---|
| **P0** (13) | J-01..J-13 | Autorización por finalidad; política vigente y su cobertura de la app; RNBD y umbral de 100.000 UVT; retención en la eliminación de cuenta (J-04, J-05); contratos con encargados; rol de Wompi; cuentas web existentes sin prueba de aceptación; prueba de la autorización; PQRS; área designada de derechos; fallos y datos de dispositivo; aprobación del inventario de datos | Publicación (G4); M2 y M4 |
| **P1** (14) | J-14..J-27 | Ubicación (fase 2); menores; verificación de identidad; supresión y pedidos en curso; exportación; transferencias; etiquetas de tiendas (J-20); retención por flujo; cédula/NIT; aviso del checkout web; cambios de política; WhatsApp; incidentes; proveedores tecnológicos (CE 002/2025) | Lanzamiento |
| **P2** (9) | J-28..J-36 | Push; analítica; campañas; Ley 1266; directorio de asesores; biometría; reforma de la Ley 1581; evaluación de impacto; verificación de correo | Fase 2 |

---

## 10. Orden sugerido de aprobación y qué desbloquea (PROPUESTA)

Orden basado en [resolución §3](resolucion_inconsistencias.md) y en la ruta crítica ([roadmap §3](roadmap.md)). Es una propuesta; el humano puede decidir otro orden.

| Paso | Decisiones | Por qué en este orden | Desbloquea |
|---|---|---|---|
| 0 | **D-15**, **C1**, **H-12/D-16**, **C2** | Sin equipo, conformidad del responsable técnico y staging no se puede implementar ni probar | Gate G1; Etapa 0 y PT-02 |
| 1 | **H-01** (enmienda ADR-001) | Fija el alcance real de WordPress | PT-07/08/09/10 |
| 2 | **ADR-013, ADR-014, ADR-008 (fusión de ADR-017; H-02), H-04** | Sesiones por dispositivo y retorno del pago son la ruta crítica | PT-07, PT-06, PT-11, PT-16 |
| 3 | **ADR-016, ADR-006, H-09, H-05** | Errores y reglas de acceso del BFF y de WordPress | PT-04, PT-05, PT-07 |
| 4 | **ADR-015** con el dato de SA-01 (n.º de procesos) | Define si Redis pasa a P0 | PT-04, PT-07 |
| 5 | **ADR-003, 004, 005, 007, 009, 012, 018, 019, 020, 021, 022; DA-01..DA-15** | Resto de la arquitectura | PT-13 y rebanadas M1..M5 |
| 6 | **H-03, H-06, H-07, H-08, H-10; AP-05, AP-06; DM-xx** | Producto: cambian ACs concretos | M2, M3, M4 |
| 7 | **D-12 (J-01..J-13), H-11, DM-02, DM-04, DM-08; ADR-010; DA-04** | Legal | M2, M4, G4 |
| 8 | **D-02 (PA-11, PA-12), D-05, D-08, D-09, D-10, D-13, D-14, DA-15** | Datos externos y aceptación de riesgos | M3, M5, G4 |

---

## 11. Cronología

| Fecha | Hecho (según los documentos) |
|---|---|
| 2026-11-17 | Informe de investigación (Entrega 1). Se plantean D-01..D-16 con recomendaciones iniciales ([decisiones_pendientes.md](decisiones_pendientes.md)). |
| 2026-11-18 | Se lee el código de `ipr-frontend` (informes 1.1 y 1.2). **El solicitante aprueba ADR-001 (D-01) y las decisiones de alcance D-06, D-03, D-04 (ADR-002).** Se redactan requisitos (113 RF, 76 en MVP), perfiles y alcance. Se proponen ADR-003..012 (arquitectura Flutter) y ADR-013..022 (API y autenticación), DN-01..DN-14, DM-01..DM-09, DA-01..DA-15 y AP-01..AP-10. Se redactan el modelo de datos, la seguridad (72 controles, 62 amenazas, 22 cambios P0), la privacidad (36 preguntas jurídicas) y la estrategia de pruebas (160 casos, sin ejecutar). El revisor de consistencia publica 89 CR y propone H-01..H-12 (**sin aprobar**). Este consolidado (roadmap, riesgos, decisiones, plan). |
| Después del 2026-11-18 | **Ningún dato.** No hay en los documentos ninguna aprobación posterior. |

---

## 12. Cómo registrar una decisión nueva (propuesta)

Cada decisión debe tener: ID estable (no se renumera), enunciado, estado (§1), fecha, **quién decide y quién decidió (rol)**, documentos que cambian (con sección), qué desbloquea y, si cambia el alcance, el RF o la ADR afectada. Una recomendación **no** pasa a "Aprobada" sin constancia del decisor en este registro y en el documento fuente.

*Fin del documento. BORRADOR: solo ADR-001, ADR-002, D-01, D-03, D-04 y D-06 constan como aprobadas.*

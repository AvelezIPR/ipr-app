# Logging — esquema, correlación, privacidad, auditoría y verificación

| | |
|---|---|
| **Fase** | OPERACIÓN (documentación). **No se programa ni se configura nada.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. El esquema de este documento es una **propuesta**; ninguno de sus elementos está implementado. Plazos de retención y acceso: **A VALIDAR con el Jurídico** (D-12, DN-08). |
| **Relacionado** | [monitoring.md](monitoring.md) · [incident_response.md](incident_response.md) · [maintenance.md](maintenance.md) · `../06_security/security_architecture.md` §8.4 · `../06_security/privacy_assessment.md` |
| **Fuentes** | `AA` = `05_api/api_architecture.md` §12; `AU` = `05_api/authentication.md` §8; `SC`/`TM` = `06_security/`; `RNF` = `02_requirements/non_functional_requirements.md`; `PRIV` = `06_security/privacy_assessment.md`; `FA` = `03_architecture/flutter_app_architecture.md`; `COD` = `00_discovery/informe_codigo_frontend.md` |

Etiquetas: **HECHO** (con cita) · **SUPUESTO** (los `SUP-H` son H-01..H-12 de `decisiones_pendientes.md` §E, **no aprobadas**) · **PROPUESTA** · **DECISIÓN PENDIENTE** (`DOP-xx`) · **RIESGO** (`ROP-xx`) · **DESCONOCIDO** · **NO VERIFICADO**.

---

## 1. Principios

| # | Principio | Origen |
|---|---|---|
| L-01 | **Registrar lo mínimo para operar, depurar e investigar; nada más.** Un log es un tratamiento de datos: debe tener finalidad, retención y acceso definidos. | Ley 1581, principios de finalidad y minimización (PRIV §1.1; RNF-047, RNF-063) |
| L-02 | **Cero PII y cero secretos** en logs, reportes de fallos y analítica (valores "canario" en pruebas). | RNF-047; SC-045; TM-045 |
| L-03 | **Una línea JSON por solicitud**, estable y con campos fijos; texto libre solo en `msg` y sin datos del usuario. | RNF-099; AA §12 |
| L-04 | **Identificadores seudonimizados** (HMAC con secreto del servidor) en lugar de identificadores directos. | AA §12; AU §8.2 (`subject_hash`) |
| L-05 | **Correlación de punta a punta** con un `requestId` que viaja App → BFF → WordPress. | RNF-099; AA §12 |
| L-06 | Los logs de **auditoría de seguridad** son distintos de los logs técnicos: otro almacén, otra retención, otro acceso. | RNF-105; SC-046 |
| L-07 | Lo que no se registra no se puede filtrar: ante la duda, **no registrar** y medir con contadores. | TM-045 |

---

## 2. Estado actual (HECHO)

| Hecho | Evidencia | Consecuencia |
|---|---|---|
| El código web registra con `console.error`/`console.info` y prefijos `[wc]`, `[woocommerce]`, `[PQRS]`, `[auth]`; una línea de contadores por minuto hacia WooCommerce. | `ipr-frontend/src/lib/wc/metrics.ts`, `src/lib/wc/client.ts`, `src/lib/woocommerce.ts` | Es texto libre sin `requestId` ni formato estructurado. |
| Hay registros de **objetos de error completos** (`console.error("[PQRS] Email send failed:", err)`; `console.error("[auth] Error de red…", error)`). | `src/app/api/pqrs/route.ts:118`; `src/lib/auth.ts:95` (citados en SC-045, `security_architecture.md` §8.4) | Su contenido real es **DESCONOCIDO** (podría incluir cuerpos o datos de respuesta). Hay que verificarlo con canarios (ST-108) antes de reutilizar el patrón en `/mobile/v1`. |
| El token de sesión se acepta hoy por *query string* en `ipr/v1`. | `wp-snippets/ipr-auth-rest.php` (H-03 de `COD`; TM-004) | Quedó/queda en logs de servidor, proxies y Cloudflare. Mientras exista, **los logs de acceso históricos pueden contener tokens vigentes**. |
| El ticket de checkout viaja en la query `ipr_ticket`. | `COD` §5.4; SC-072; TM-023 | No debe registrarse en logs de hosting ni de Cloudflare. Configuración actual: **DESCONOCIDA** (DES-13). |
| `/api/revalidate` acepta el secreto por `?secret=` y por `GET`. | `COD` H-10; SC-060; TM-053 | El secreto puede estar en logs de acceso. Rotarlo si se detecta (PB-05). |
| Los snippets de WordPress **no** escriben logs propios. | Revisión de `wp-snippets/*.php` (sin llamadas de registro) | No hay auditoría de login, cambios de datos ni emisión de tickets (TM-058). |
| Destino, retención y acceso de los logs del servidor Node y de WordPress/Plesk. | — | **DESCONOCIDOS** (DES-02, DES-10). |

---

## 3. Esquema de log estructurado del BFF (PROPUESTA)

Formato: JSON, **una línea por solicitud** terminada, UTF-8, tiempos en **UTC** (ISO 8601, ms), emitido a la salida estándar del proceso para que el recolector (DES-01) lo tome. Base: `AA` §12; RNF-099.

| Campo | Tipo | Ejemplo (sintético) | Regla | Origen |
|---|---|---|---|---|
| `ts` | string ISO 8601 UTC | `2026-11-18T15:04:05.123Z` | Obligatorio | AA §12 |
| `level` | enum | `info` | Ver §6 | — |
| `requestId` | UUID v4 | `6f1c2a7e-0b7d-4c43-9d0e-5f3c1f6f2a11` | Obligatorio. Lo envía la app (`X-Request-Id`) o lo genera el BFF si falta o no es UUID. | AA §12 |
| `route` | string | `/mobile/v1/products/:slug` | **Plantilla de ruta**, nunca la URL real (evita slugs, IDs y query). | AA §12 |
| `method` | enum | `GET` | — | — |
| `status` | int | `200` | Código HTTP final | — |
| `code` | string | `upstream_unavailable` | Código estable RFC 9457 si hay error | AA §6.3 |
| `durationMs` | int | `182` | Latencia total en el BFF | RNF-012 |
| `cache` | enum | `hit` / `miss` / `stale` / `edge` | Estado de caché | AA §12 |
| `upstreamCalls` | int | `1` | Llamadas a WooCommerce/WordPress | AA §12 |
| `upstreamMs` | int | `140` | Tiempo agregado aguas arriba | AA §12 |
| `queueWaitMs` | int | `12` | Espera en la cola de `wcGet` (a construir, FE-06) | RNF-018 |
| `rateLimited` | bool | `false` | Si el limitador intervino | RNF-042 |
| `appVersion` | string | `1.0.0+12` | De `X-App-Version` (validada contra patrón) | AA §5 |
| `platform` | enum | `android` / `ios` / `web` | De `X-App-Platform` (lista cerrada) | AA §5 |
| `userRef` | string(16 hex) | `a3f9…` (HMAC-SHA256 del `user_id`, truncado) | Seudónimo; sin correo ni `user_id` | AA §12; SC-045 |
| `deviceRef` | string(16 hex) | `7c1e…` (HMAC del `deviceId`, truncado) | `deviceId` no es secreto pero es identificador de instalación | AA §10.4 |
| `ipPrefix` | string | `203.0.113.0/24` (IPv4 /24; IPv6 /48) | **Nunca la IP completa** en logs técnicos | AA §12 |
| `queryLen` | int | `8` | Solo para búsqueda: longitud del texto y, si fue SKU, `isSku:true`. **Nunca el texto.** | AA §12 |
| `msg` | string | `catalog list served from stale cache` | Texto corto **fijo** (sin interpolar datos del usuario) | — |
| `err` | objeto | `{ "kind": "WcError", "status": 503, "circuitOpen": true }` | **Solo** `kind`, `status`, `circuitOpen`, código; **nunca** el objeto de error crudo, cuerpo ni cabeceras | SC-045 |

El HMAC de `userRef`/`deviceRef` usa un secreto distinto de cualquier otro (rotación en [maintenance.md](maintenance.md) §6); rotarlo rompe la correlación histórica, por eso se rota **ante incidente** y no por calendario corto.

Ejemplo de línea (valores inventados):

```json
{"ts":"2026-11-18T15:04:05.123Z","level":"info","requestId":"6f1c2a7e-0b7d-4c43-9d0e-5f3c1f6f2a11","route":"/mobile/v1/products/:slug","method":"GET","status":200,"durationMs":182,"cache":"stale","upstreamCalls":0,"rateLimited":false,"appVersion":"1.0.0+12","platform":"android","userRef":"a3f9c2d41b7e08aa","ipPrefix":"203.0.113.0/24","msg":"served stale"}
```

---

## 4. Request id y correlación App → BFF → WordPress

| Tramo | Cabecera / campo | Quién genera | Dónde queda | Estado |
|---|---|---|---|---|
| App → BFF | `X-Request-Id` (UUID v4, opcional) | La app (interceptor de red) | Respuesta (`X-Request-Id`) y `requestId` de los errores RFC 9457; log del BFF | PROPUESTO (AA §12; FA interceptor) |
| BFF → WordPress | `X-IPR-Request-Id` | BFF (reenvía el mismo valor) | `ipr_auth_events.request_id` y `ipr_consents.request_id`; log de WordPress si existe | PROPUESTO (AU §8.2, §8.4) |
| BFF → WordPress | `X-IPR-Client-IP` (solo junto a `X-IPR-BFF-Secret` válido) | BFF | `ipr_auth_events.ip_address` (**única** parte donde se guarda IP completa, con retención limitada) | PROPUESTO (AA §10.3, SC-009) |
| Cloudflare | `CF-Ray` | Cloudflare | Analítica/log de Cloudflare (según plan, DES-04) | HECHO (Cloudflare existe); disponibilidad en plan: DESCONOCIDA |
| Checkout / pago | `checkoutRef` (UUID) en el pedido (`_ipr_checkout_ref`) y en el ticket | WordPress / BFF | Pedido de WooCommerce | PROPUESTO (ADR-017; AU §8.5) |
| Wompi | Referencia de la transacción (formato propio de Wompi) | Wompi / plugin | Pedido de WooCommerce | **DESCONOCIDO** (DES-08, D-02) |

**Cómo se usa para investigar (PROPUESTA).**
1. El usuario ve en un error de la app el `requestId` (RFC 9457; la app lo muestra en "Detalles técnicos" y lo incluye en el mensaje a Soporte si el usuario lo pide).
2. Soporte pasa el `requestId` a Web, que lo busca en los logs del BFF y obtiene ruta, estado, latencia, versión de la app.
3. Con el mismo valor en `ipr_auth_events.request_id`, WP correlaciona el evento de autenticación sin tocar datos personales.
4. Para pagos, la unión es `checkoutRef` ↔ pedido ↔ transacción de Wompi (a confirmar, D-02).

**Límites.** El `requestId` no cruza WooCommerce REST (`wc/v3`) salvo que el cliente `wcGet` lo agregue como cabecera (DESCONOCIDO si WooCommerce lo registra). La correlación con Wompi depende del plugin. Los relojes de BFF y WordPress deben estar sincronizados (DES-14).

**Validación del `requestId` entrante (PROPUESTA).** Aceptar solo UUID v4; cualquier otro valor se descarta y se genera uno nuevo (evita inyección de líneas o datos en logs; TM-045).

---

## 5. Qué NUNCA se registra

Aplica a: logs del BFF, logs de WordPress/hosting/Cloudflare (en lo que IPR controle), logs de la app, reportes de fallos, analítica, mensajes de alertas y capturas de soporte.

| Dato | Por qué no | Qué se registra en su lugar | Origen |
|---|---|---|---|
| Cabecera `Authorization`, *access token*, *refresh token* (prefijos `ipra_`, `iprr_`), cookies | Suplantación de sesión | Nada; en WP, `session_uuid` | RNF-047; SC-045; TM-004, TM-045 |
| Contraseñas (actual, nueva, de restablecimiento) | Credenciales | `reason_code` (p. ej. `current_password_invalid`) | RNF-047; SC-013 |
| Cuerpos de `/auth/*`, `/me/*` y `/pqrs` | Contienen credenciales y PII | `route`, `status`, `code` | AA §12 |
| Ticket de checkout y `checkoutUrl` (query `ipr_ticket`) | Un solo uso, 60 s, pero permite iniciar sesión | `checkoutRef` | SC-072; TM-023 |
| Datos de tarjeta, CVV, datos de pago | La app y el BFF **nunca** los ven (checkout externo); no deben aparecer por error | — | ADR-001/002; PCI fuera de alcance |
| Correo, teléfono, cédula/NIT, nombres, direcciones, fechas de nacimiento | PII (algunos datos de facturación pueden ser sensibles según el caso; A VALIDAR por Jurídico) | `userRef` (HMAC); en fallos de login, `subject_hash` | RNF-047; PRIV |
| IP completa en logs técnicos | Dato personal | `ipPrefix`; IP completa **solo** en `ipr_auth_events` con retención limitada | AA §12 |
| Texto de búsqueda | Puede contener datos personales | `queryLen`, `isSku` | AA §12 |
| Texto libre de PQRS (asunto, mensaje, correo) | PII y contenido sensible | `status`, `idempotency` (hash), longitud | AA §12; TM-039 |
| URLs reales con parámetros (slugs, IDs, `?token=`, `?secret=`) | Pueden incluir secretos o datos | `route` plantilla; en el borde, desactivar el registro de la query de rutas sensibles | SC-072; TM-053 |
| Secretos del servidor (`HANDOFF_SECRET`, `IPR_BFF_SECRET`, `REVALIDATE_SECRET`, claves de WooCommerce, SMTP), claves de firma de la app | Compromiso del sistema | Nada | RNF-036; SC-039; TM-042, TM-060 |
| Objetos de error completos (`err`, `error.response`, `error.config`) | Pueden arrastrar cabeceras, cuerpos o URLs con secretos | `err.kind`, `err.status`, `err.code` | SC-045; hechos de §2 |
| Cuerpos de respuesta de WooCommerce/WordPress | Datos de clientes y pedidos | `status`, `upstreamMs` | TM-015, TM-031 |
| `deviceId` / `userId` / correo en claro en reportes de fallos | Identificación directa | `userRef` / `deviceRef` seudónimos | RNF-097; ADR-010 |
| Contenido del portapapeles, capturas de pantalla, datos de ubicación precisa | Excede la finalidad | — | RNF-035, RNF-060 |

**Datos "con cuidado" (permitidos solo con la forma indicada):** versión de la app, plataforma, modelo/SO **como atributos agregados del reporte de fallos**, `appVersion`, `status`, `route` plantilla, `cache`, latencias.

---

## 6. Niveles de log

| Nivel | Cuándo | Ejemplo | Producción | Alerta |
|---|---|---|---|---|
| `error` | Fallo que impide completar la solicitud o el *breaker* se abre | `breaker opened`; 5xx; fallo del SMTP | Siempre | Alimenta AL-03, AL-04 |
| `warn` | Degradación manejada: sirvió `stale`, rate limit, reintento, 4xx de seguridad (`token_in_url_forbidden`, `refresh_token_reused`) | `served stale`; `rate limited` | Siempre | AL-27, AL-32 |
| `info` | Una línea por solicitud terminada y eventos de ciclo de vida (arranque, índice listo, despliegue) | solicitud `200` | Siempre, con **muestreo** posible para `200` de catálogo si el volumen lo exige (DOP-02) | — |
| `debug` | Diagnóstico detallado | — | **Apagado en producción**; solo en *staging*/*dev* con datos sintéticos | — |
| Auditoría | Eventos de seguridad (§9) | `login_failed` | Siempre, en almacén aparte | AL-26..AL-30 |

Reglas: `debug` nunca se activa en producción con tráfico real (si se necesita, durante un incidente: por ventana corta, con aprobación del IC y registro, [incident_response.md](incident_response.md) §4). En la app, el *build* release **no** escribe logs de depuración y no incluye `DebugLogInterceptor` (RNF-047; SC-041).

---

## 7. Retención y acceso (A VALIDAR con el Jurídico)

> **Todos los plazos de esta sección son propuestas técnicas. La retención de logs que contengan datos personales, y de los registros de auditoría y consentimiento, la fija el Jurídico (DN-08, D-12, PA-09). Mientras no la fije, se aplica el valor inicial propuesto por RNF-063 / SC-071 y se marca "A VALIDAR".**

| Registro | Contenido | Retención propuesta | Acceso (roles) | Origen | Estado |
|---|---|---|---|---|---|
| Log técnico del BFF | Sin PII directa (seudónimos, prefijo de IP) | **≤ 90 días** | Web, TI (lectura); Seg (lectura en incidente) | RNF-063; SC-071 | PROPUESTO; **A VALIDAR (Jur)** |
| Auditoría de seguridad (`ipr_auth_events`) | Incluye IP completa y `user_id` | **≤ 90 días**; el registro mínimo de eliminación de cuenta (`deletion_requested/completed`, sin PII salvo `user_id`) **según defina Jurídico** | Seg, WP (lectura); Jur (bajo solicitud); **no** acceso general | AU §8.2; SC-071 | PROPUESTO; **A VALIDAR (Jur)** |
| Contadores anti fuerza bruta (`ipr_auth_throttle`) | HMAC de sujetos | Limpieza a las 24 h sin bloqueo | WP | AU §8.3 | PROPUESTO |
| Sesiones revocadas/vencidas (`ipr_auth_sessions`) | Hashes de tokens, `device_id` | Borrado a los 30 días | WP | AU §8.1; SC-071 | PROPUESTO |
| Consentimientos (`ipr_consents`) | Prueba de autorización | Mientras exista el tratamiento + plazo post-supresión **que defina Jurídico** | WP, Jur | AU §8.4 | PROPUESTO; **A VALIDAR (Jur)** |
| Reportes de fallos (proveedor DN-02) | Trazas, modelo/SO, `userRef` | Según proveedor (Crashlytics: 90 días, **VERIFICADO** en PRIV §1.1); **A VALIDAR** transferencia internacional | Móvil (lectura) | RNF-061; ADR-010 | PENDIENTE (DN-02) |
| Logs del origen (nginx/Plesk) y de Cloudflare | IP completa, URL con query | DESCONOCIDA; **recomendado**: sin query en rutas sensibles y retención ≤ 90 días | TI | SC-072; DES-13 | DESCONOCIDO |
| Copias de seguridad que contengan logs o tablas de auditoría | — | Alineada con los plazos de supresión | TI, WP | [maintenance.md](maintenance.md) §8 | A VALIDAR (Jur) |
| Evidencias de incidentes (capturas, extractos de logs) | Pueden contener PII | Mínimo necesario; se destruyen al cerrar el post-mortem salvo obligación legal | IC, Seg, Jur | [incident_response.md](incident_response.md) §4 | A VALIDAR (Jur) |

**Principios de acceso (PROPUESTA).** (1) Acceso por **rol y necesidad**, nunca por cuenta compartida; (2) lectura solo; ningún rol operativo puede editar logs; (3) acceso a auditoría con IP completa **registrado** (quién, cuándo, para qué); (4) revisión trimestral de quién tiene acceso (Seg + TI); (5) las exportaciones a hojas de cálculo o chats están prohibidas (un incidente se investiga en la herramienta de logs); (6) acceso del Jurídico a la auditoría cuando atienda una solicitud de un titular o un incidente.

**Solicitudes de titulares.** Los logs técnicos sin PII directa no requieren búsqueda por titular; la auditoría sí contiene su `user_id` e IP: el procedimiento de consulta/supresión sobre ella lo define el Jurídico (J-xx de PRIV).

---

## 8. Enmascaramiento y seudonimización

| Técnica | Dónde | Detalle |
|---|---|---|
| **HMAC con secreto del servidor** (`userRef`, `deviceRef`, `subject_hash`) | BFF, WordPress | HMAC-SHA256 truncado a 16 hex en el BFF; completo (64 hex) en auditoría. El secreto vive en el gestor de secretos, distinto del de *handoff*. Un hash simple (SHA-256 sin clave) **no** basta: se puede recorrer el espacio de correos. |
| **Truncado de IP** | BFF | /24 (IPv4), /48 (IPv6). |
| **Plantilla de ruta** | BFF | Se registra `/mobile/v1/products/:slug`, no el slug real. |
| **Longitud en lugar de contenido** | BFF | Búsqueda y PQRS. |
| **Lista cerrada de campos** (*allow-list*) | BFF, app | El logger **solo** acepta los campos del §3; un campo desconocido se descarta (no se hace *deny-list* de "campos sensibles"). |
| **Depurador de PII** (`PiiScrubber`) | App | Se aplica **antes** de entregar al `CrashReporter`: elimina correos, teléfonos, números largos (cédula/NIT), tokens (`ipra_`, `iprr_`), URLs con query. Debe fallar cerrado: ante duda, borra el campo. (ADR-010; SC-045) |
| **Eliminación de la query** de rutas sensibles en el borde | Cloudflare / nginx | `ipr_ticket`, `token`, `secret`: no registrar o enmascarar (SC-072; TM-023, TM-053). Si hoy se registran: DESCONOCIDO (DES-13). |
| **Sin cuerpos** en logs de fallo de terceros | BFF | Solo `status` y tipo de error de WooCommerce/WordPress. |

---

## 9. Auditoría de acciones sensibles

Base: RNF-105 ("100 % de los eventos, con fecha, usuario, dispositivo e IP según DN-08; sin secretos"), SC-046, `AU` §8.2. **Hoy no existe ningún registro de estos eventos** (TM-058). Almacén propuesto: tabla `ipr_auth_events` en WordPress (separada de los logs técnicos).

| Acción sensible | `event_type` | Qué se guarda | Qué **no** se guarda | Alerta asociada | Origen |
|---|---|---|---|---|---|
| Inicio de sesión (éxito) | `login_succeeded` | `user_id`, `session_uuid`, `client_type`, IP, `request_id` | contraseña | AL-30 (indirecta) | RNF-105; SC-046 |
| Inicio de sesión (fallo) | `login_failed` | `subject_hash` (HMAC del login), IP, `reason_code` | contraseña, correo en claro | AL-26 | TM-001, TM-057 |
| Rol no permitido | `login_denied_role` | `user_id`, IP | — | AL-28 | SC-011; TM-010 (SUP-H H-09) |
| Bloqueo por límite | `login_throttled` | `subject_hash`, `lock_level` | — | AL-26 | SC-004 |
| Registro | `registered` | `user_id`, IP, `client_type` | contraseña, datos de perfil | AL-30 | TM-056 |
| Renovación reutilizada / revocación | `refresh_reused`, `session_revoked`, `logout_all` | `user_id`, `session_uuid`, `revoked_reason` | tokens | AL-27 | SC-002, SC-012; TM-006 |
| **Cambio de correo** | `email_changed` | `user_id`, IP, `request_id` | correo anterior y nuevo | AL-29 | SC-013; TM-033 |
| **Cambio de contraseña** / restablecimiento | `password_changed`, `password_reset_requested`, `password_reset_completed` | `user_id`, IP | contraseñas | AL-29 | SC-012, SC-013 |
| **Solicitud y ejecución de eliminación de cuenta** | `deletion_requested`, `deletion_completed` | `user_id`, `_ipr_deletion_request_id`, fecha | datos eliminados | revisión semanal | SC-057; RNF-058; H-11 (SUP-H) |
| **Emisión de ticket de checkout** | `checkout_ticket_issued` | `user_id`, `checkoutRef`, `channel`, IP | contenido del carrito, ticket | AL-24 | SC-029; TM-029 |
| Cambio de configuración remota (WhatsApp, `allowedHosts`, versiones mínimas) | auditoría de WordPress (por definir) | quién, qué clave, fecha, valor anterior/nuevo (sin PII de empleados) | datos personales de empleados | AL-18 | SC-044; TM-040 |
| Cambio de rol / alta de administrador | auditoría de WordPress (hooks) | `user_id`, rol anterior/nuevo | — | AL-28 | TM-010; SC-012 |
| Acceso del personal a la auditoría con IP completa | registro de acceso de la herramienta | quién, cuándo, motivo | — | revisión trimestral | §7 |

**Propiedades requeridas (PROPUESTA).** Inmutabilidad práctica (el usuario de la aplicación solo inserta), hora UTC, retención según §7, y que **ningún** campo permita texto libre del usuario.

---

## 10. Logs de la app y reportes de fallos sin PII

| Tema | Regla (PROPUESTA) | Origen |
|---|---|---|
| Logs de depuración en `release` | Prohibidos; solo `dev`/`staging`. Revisar el binario antes de publicar. | RNF-047, RNF-051; SC-041 |
| Interceptores de red | El de registro de depuración **solo** en `dev`/`staging`; el de `requestId` siempre. | FA §7.2 |
| Proveedor de fallos | Detrás de la interfaz `CrashReporter`; **un** proveedor (Crashlytics o Sentry) decidido por Jurídico + TI (DN-02); un proyecto por *flavor* (`dev`, `staging`, `prod`). | ADR-010; SC-047 |
| Datos que acompañan un fallo | Versión de la app, plataforma, versión del SO, modelo, `userRef` (nunca correo), pantalla/ruta plantilla, `requestId` de la última llamada, estado de red. | RNF-097 |
| Migas de pan (*breadcrumbs*) | Solo eventos de navegación por **nombre de ruta**; nunca valores de campos, URLs con query, texto de búsqueda, respuestas de red. | RNF-047; TM-045 |
| Identificador de usuario del proveedor | `userRef` (HMAC); **no** `user_id` real ni correo. `deviceId` solo seudónimo. | AA §12 |
| Excepciones de red | Se reportan `tipo`, `status`, `code`; **no** el cuerpo, cabeceras ni URL completa. | SC-045 |
| Símbolos de ofuscación (mapas Dart/R8, dSYM) | Archivados por versión y subidos al proveedor desde CI; acceso restringido (Móvil, TI). | SC-041; RNF-097 |
| Consentimiento | La analítica no esencial queda **apagada** hasta PA-08 y consentimiento; el reporte de fallos requiere base legal definida (DN-02, D-12). | ADR-010; RNF-103 |
| Transferencia internacional | Crashlytics procesa "en cualquier centro de datos de Google" y retiene 90 días (**VERIFICADO**, PRIV §1.1); Sentry: región **NO VERIFICADO**. **A VALIDAR con Jurídico** antes de elegir (art. 26 Ley 1581; RNF-061). | PRIV §1.1, §6 |
| Fichas de tienda | *Data Safety* (Google) y *Privacy Details* (Apple) deben coincidir con los datos que realmente envía el reporte de fallos. | RNF-061; PRIV |
| Acceso a la consola del proveedor | Móvil y Seg; 2FA obligatorio; revisión trimestral. | RNF-055 (analogía) |
| Revisión mensual de muestra | Revisar una muestra de reportes en busca de PII (§12). | RNF-047 |

---

## 11. Logs de WordPress, hosting y borde

| Fuente | Qué vigilar | Acción propuesta | Estado |
|---|---|---|---|
| Registro de acceso de nginx/Plesk | Query `ipr_ticket`, `token`, `secret` en URLs | Excluir o enmascarar la query en estas rutas (SC-072) | DESCONOCIDO (DES-13) |
| `debug.log` de WordPress / `WP_DEBUG` | No debe estar activo en producción; puede volcar datos de usuarios | Verificar que esté apagado | DESCONOCIDO |
| Registros de WooCommerce (WC → Estado → Registros) | Los plugins de pago pueden registrar solicitudes y respuestas con datos del pagador | Revisar qué registra el plugin de Wompi y su retención; configurar el nivel mínimo | **DESCONOCIDO** (DES-08) |
| Wordfence | Eventos de login; puede registrar IPs y nombres de usuario intentados | Conocer retención y acceso | DESCONOCIDO (MED-10) |
| Cloudflare | IP, URL, agente de usuario, Ray ID | Retención según plan; no exportar a herramientas sin base legal | DESCONOCIDO (DES-04) |
| Correo SMTP (PQRS) | Contenido de PQRS en buzones; registros del servidor SMTP | Acceso restringido; retención definida por Jurídico (PQRS) | DESCONOCIDO |
| Registros históricos con tokens por query | Tokens de 30 días emitidos antes de SC-003 | Tras activar SC-003 y la revocación global (WP-05), **invalidar** sesiones previas para neutralizar tokens que hayan quedado en logs | PROPUESTO (PB-03) |

---

## 12. Cómo se verifica que los logs no filtran datos (prueba con canarios)

**Objetivo.** Demostrar RNF-047 ("0 apariciones de tokens, contraseñas, correo, teléfono, dirección, NIT/cédula en logs de la app, reportes de fallos, analítica y BFF") y SC-045 / ST-108 / ST-109. **Solo en *staging* o con cuentas sintéticas y autorización** (DES-06, D-16).

### 12.1 Valores canario (sintéticos, únicos por corrida)

| Tipo | Forma del canario (no son datos reales) |
|---|---|
| Correo | `canario.<id-corrida>@example.invalid` |
| Contraseña | `CNR-<id-corrida>-Pwd!` |
| Teléfono | número de 10 dígitos reservado de pruebas, con sufijo `<id-corrida>` incorporado en un campo de texto |
| Cédula/NIT | cadena numérica de prueba con prefijo reconocible |
| Dirección | `Calle CANARIO <id-corrida>` |
| Texto de búsqueda | `canario<id-corrida>` |
| Texto de PQRS | `CANARIO-PQRS-<id-corrida>` |
| Token | el valor real emitido a la cuenta de prueba durante la corrida (se extrae del cliente de pruebas y se busca tal cual) |

### 12.2 Procedimiento

1. Crear una cuenta sintética con los canarios (registro, perfil, dirección).
2. Ejecutar un recorrido automatizado que cubra: registro, login correcto e incorrecto, refresh, `GET /me`, cambio de correo y contraseña, restablecimiento, búsqueda, PQRS, carrito, `POST /checkout` (ticket), retorno del pago, cierre de sesión, eliminación de cuenta, **y** errores provocados (token en query → `400`, 401, 429, 503 con WooCommerce bloqueado, 504).
3. Provocar un **fallo fatal y uno no fatal** en la app con los canarios en pantalla.
4. Recolectar: logs del BFF, tabla de auditoría, logs del origen y de Cloudflare (si accesibles), reportes del proveedor de fallos, eventos de analítica, salida de `logcat`/consola de un *build* release.
5. **Buscar** (búsqueda exacta y por patrón) cada canario y el token en todas las fuentes.
6. Buscar patrones: correo (`@`), secuencias de ≥ 7 dígitos, prefijos `ipra_`/`iprr_`, `Bearer `, `ipr_ticket=`, `?token=`, `?secret=`.
7. Resultado esperado: **0 apariciones** de canarios y tokens; los patrones solo aparecen en campos permitidos (p. ej. `ipPrefix`).
8. Archivar evidencia (fecha, versión, fuentes revisadas, comandos de búsqueda, resultado) en el registro de pruebas (`08_quality/test_results.md`).

### 12.3 Criterios y frecuencia

| Criterio | Umbral | Frecuencia | Responsable | Origen |
|---|---|---|---|---|
| Aparición de canario o token en cualquier log, reporte o analítica | **0** (cualquier aparición es defecto bloqueante; si ocurre en producción, ver PB-08) | Cada candidato a versión; tras cambios al logger/`PiiScrubber`; **mensual** en producción con cuentas sintéticas | QA + Web + Móvil | RNF-047; SC-045; AL-37 |
| El esquema cumple §3 (solo campos permitidos) | 100 % de líneas de la muestra | Mensual (muestra de 1.000 líneas o el total si es menor — cifra propuesta) | Web | RNF-099 |
| `route` siempre plantilla | 100 % | Mensual | Web | AA §12 |
| Reporte de fallos sin PII | 0 en la muestra mensual de reportes | Mensual | Móvil | RNF-097 |
| Auditoría sin contraseñas, tokens ni correos | 0 | Trimestral | WP + Seg | AU §8.2 |
| Prueba negativa de `?token=`: `400 token_in_url_forbidden` y **ausencia** del valor en logs | 100 % | Cada candidato | Web | RNF-041; SC-003 |

### 12.4 Detección continua (PROPUESTA)
- Un **escáner de patrones** programado sobre los logs recientes (correo, dígitos largos, prefijos de token, `Bearer`, `ipr_ticket=`) que genera AL-37 al primer hallazgo. Debe ejecutarse **sin copiar los logs** fuera de la herramienta.
- En CI del BFF: prueba que falla si el *logger* acepta campos fuera de la lista (*allow-list*) o si un test de integración imprime un canario.
- En CI de la app: análisis estático que prohíbe `print`/`debugPrint` en código de producción y prueba del `PiiScrubber` con vectores (RNF-087).

---

## 13. Hechos, supuestos, riesgos y decisiones pendientes

### 13.1 Supuestos

| ID | Supuesto | Si es falso |
|---|---|---|
| SL-01 | El proceso Node puede emitir logs JSON por salida estándar y alguien los recoge (DES-02). | Sin recolector, el esquema no tiene valor operativo; se decide DOP-02. |
| SL-02 | WordPress puede crear `ipr_auth_events` con `dbDelta` y reenviar el `X-IPR-Request-Id` (AU §8, RS-02). | La auditoría de §9 no existe; TM-058 sigue abierta. |
| SL-03 | La retención inicial de 90 días es aceptable hasta que el Jurídico la fije (RNF-063). | Ajustar §7. |
| SL-04 | Existe *staging* para las pruebas de canarios (C2). | La prueba solo con cuentas sintéticas en producción y con autorización expresa. |

### 13.2 Riesgos

| ID | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| ROP-L1 | Logs de acceso históricos contienen tokens de sesión (por `?token=`) o el secreto de `/api/revalidate` | Media | Alto | Revocación global tras activar SC-003 (PB-03); rotar `REVALIDATE_SECRET` (PB-05); revisar retención (DES-13). |
| ROP-L2 | El plugin de pago registra datos del pagador en los logs de WooCommerce | Media | Alto | Revisar y limitar el registro (§11); PB-08 si se confirma. |
| ROP-L3 | Un SDK de fallos/analítica envía PII o datos a destinos no declarados | Media | Alto | `PiiScrubber`, captura de tráfico con proxy en staging (RNF-061), ficha de tienda. |
| ROP-L4 | Retención excesiva de la auditoría con IP completa | Media | Medio | §7 + dictamen de Jurídico (DN-08). |
| ROP-L5 | Pérdida de correlación al rotar el secreto del HMAC | Baja | Bajo | Rotar solo ante incidente; documentar la fecha de corte en el post-mortem. |

### 13.3 Decisiones pendientes

| ID | Decisión | Recomendación inicial | Quién decide |
|---|---|---|---|
| DN-02 / DN-08 | Proveedor de fallos, país de tratamiento y plazos de retención de logs y de datos | Ver RNF §3; retención técnica ≤ 90 días mientras tanto | Jurídico + TI + Finanzas |
| DOP-02 | Herramienta de logs y su ubicación (tratamiento de datos) | Servicio con región conocida y retención configurable; sin exportaciones a terceros sin base legal | TI + Jurídico |
| DOP-05 | Quién puede acceder a la auditoría con IP completa y con qué registro | Roles Seg y WP; Jurídico bajo solicitud; registro de accesos | Seg + Gerencia |
| DOP-06 | Si el registro de acceso del origen y de Cloudflare enmascara la query en rutas sensibles | Sí (SC-072) | TI |

*Fin del documento. BORRADOR sujeto a validación del Jurídico y del responsable técnico de `ipr-frontend` y WordPress.*

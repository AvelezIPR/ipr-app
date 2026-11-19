# Diccionario de datos — App IPR (app Flutter + BFF `/mobile/v1` + WordPress/WooCommerce)

| | |
|---|---|
| **Proyecto** | App móvil Flutter de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Arquitectura (modelo de datos). **No se programa nada.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para revisión del arquitecto, del responsable técnico de `ipr-frontend`/WordPress y de Jurídico (D-12). |
| **Relacionado** | [data_model.md](data_model.md) (visión por sistema, ciclo de vida, reglas de integridad, inconsistencias) · [entity_relationship.md](entity_relationship.md) (diagramas ER) |
| **Insumos** | [authentication.md](../05_api/authentication.md) §8 (esquema de sesiones, importado sin cambios) · [api_contracts.md](../05_api/api_contracts.md) · [openapi.yaml](../05_api/openapi.yaml) · [flutter_app_architecture.md](../03_architecture/flutter_app_architecture.md) · [informe_codigo_frontend.md](../00_discovery/informe_codigo_frontend.md) · [analisis_capa_woocommerce.md](../00_discovery/analisis_capa_woocommerce.md) · código de solo lectura de `ipr-frontend` |

> **No se abrió ni se leyó `.env`.** Todos los ejemplos son **sintéticos** (dominio `.test`, rangos de documentación). No hay datos reales de clientes ni de empleados. Nombres de variables de entorno aparecen solo como nombre, nunca con valor.

---

## 0. Cómo leer este diccionario

### 0.1 Columnas

| Columna | Significado |
|---|---|
| **Campo** | Nombre canónico del campo. Si el campo existe con otro nombre en el código o en WordPress, la equivalencia está en la descripción y en el anexo A. |
| **Tipo** | Tipo lógico. En las tablas de WordPress de `authentication.md` §8 el tipo SQL, la nulabilidad, el defecto y el índice se copian **sin cambios**. |
| **Oblig.** | Sí / No / Cond. (condicional, se explica). |
| **Origen** | Sistema que **crea o es dueño** del valor: `WP` (WordPress/WooCommerce), `BFF` (Next.js `/mobile/v1`), `APP` (Flutter), `DER` (derivado/calculado). |
| **Ejemplo** | Valor **sintético**. |
| **Clasif.** | Ver §0.2. |
| **App** | `Viaja` = el campo aparece en alguna respuesta/solicitud de `/mobile/v1`; `Persiste` = dónde se guarda en el dispositivo (`Memoria`, `Secure storage`, `Hive cart`, `Hive cache`, `Prefs`, `No`). |
| **Ret.** | Código de retención (§0.3). |
| **Evidencia** | Archivo (y línea o sección). `PROPUESTO` = no existe hoy; se justifica en la misma celda. `SUPUESTO` / `DESCONOCIDO` se explican. |

### 0.2 Clasificación (Ley 1581 de 2012 y política interna)

| Etiqueta | Criterio aplicado | Ejemplos |
|---|---|---|
| `PÚBLICO` | Información ya publicada o publicable sin restricción. | Nombre y precio de producto, sedes corporativas. |
| `INTERNO` | No es personal, pero no debe publicarse ni llegar a la app sin necesidad (operativo, comercial, técnico). | `stock_quantity`, roles, contadores. |
| `PERSONAL` | Dato personal (art. 3 Ley 1581): identifica o hace identificable a una persona natural, incluidos identificadores indirectos y seudónimos. | Correo, nombre, teléfono, dirección, `user_id`, `device_id`, IP. |
| `PERSONAL-ALTO` | Dato personal de **riesgo alto** por daño potencial si se filtra: número de identificación nacional (cédula/NIT), copias de facturación con identificación, texto libre que puede contener datos sensibles. El historial de compra enlazado a una persona es `PERSONAL`. **No** implica por sí mismo "dato sensible" en el sentido del art. 5 de la Ley 1581 (salud, orientación política, biometría, etc.): esa calificación jurídica queda en **D-12**. | Cédula/NIT, copia de facturación del pedido, notas de pedido, mensaje de PQRS. |
| `SECRETO` | Credencial o derivado de credencial: su revelación permite actuar como el titular o el sistema. | Contraseña (hash), tokens, hashes de tokens, ticket de checkout, secretos del servidor. |

Los **seudónimos** (HMAC de correo/IP/usuario) se clasifican como `PERSONAL`: siguen siendo datos personales mientras exista la clave que permite correlacionarlos (la anonimización irreversible es otro tratamiento, D-12).

### 0.3 Códigos de retención (detalle y marcas D-12 en [data_model.md](data_model.md) §7)

| Código | Regla |
|---|---|
| `RET-01` | Mientras exista la cuenta; supresión o anonimización ≤ 15 días hábiles tras la solicitud de eliminación (RNF-058). Excepciones: **DECISIÓN PENDIENTE D-12**. |
| `RET-02` | Soporte contable y fiscal del pedido: se conserva; plazo y anonimización parcial = **DECISIÓN PENDIENTE D-12** (Jurídico + Finanzas). |
| `RET-03` | Sesiones: borrar a los 30 días de revocadas o vencidas (`authentication.md` §3.5, §8.1). |
| `RET-04` | Auditoría de seguridad: 90 días (`authentication.md` §8.2, RNF-063); evento de eliminación: **D-12**. |
| `RET-05` | Contadores anti fuerza bruta: limpiar filas sin bloqueo con `updated_at` > 24 h (`authentication.md` §8.3). |
| `RET-06` | Consentimientos: mientras haya tratamiento más el plazo que defina Jurídico (**D-12**). |
| `RET-07` | Logs técnicos del BFF: ≤ 90 días (RNF-063; DN-08 pendiente). |
| `RET-08` | Efímero con TTL propio (ticket 60 s, idempotencia 60 s o 24 h, cachés por TTL). |
| `RET-09` | En el dispositivo: hasta el cierre de sesión o la eliminación de cuenta (borrado inmediato, RNF-062). |
| `RET-10` | En el dispositivo, sin PII: persistente con tope/LRU hasta que el usuario limpie datos o desinstale (DN-10 para el carrito). |
| `RET-11` | Contenido editorial o público: sin plazo especial; lo gobierna su responsable. |
| `RET-12` | Buzón de correo corporativo (PQRS, boletín): política del buzón **DESCONOCIDA** → **D-12**. |
| `RET-13` | Datos de campañas: sin política en el código → **DESCONOCIDA**, **D-12** (RF-103 fuera del MVP). |
| `RET-14` | Mientras exista la instalación; se regenera tras eliminar la cuenta (`flutter_app_architecture.md` §8). |
| `RET-15` | Registro mínimo de la solicitud de eliminación: plazo que defina Jurídico (**D-12**, `authentication.md` §8.2). |

### 0.4 Abreviaturas de evidencia

Rutas de `ipr-frontend` (solo lectura): `AR` = `wp-snippets/ipr-auth-rest.php` · `HO` = `wp-snippets/ipr-cart-handoff.php` · `RM` = `wp-snippets/ipr-ruleta-midea.php` · `RS` = `wp-snippets/ipr-raspa-y-gana-samsung.php` · `WC` = `src/lib/woocommerce.ts` · `MD` = `src/lib/mock-data.ts` · `AU` = `src/lib/auth.ts` · `SS` = `src/lib/session.ts` · `CS` = `src/lib/checkout-schema.ts` · `SE` = `src/lib/sedes-data.ts` · `CL` = `src/lib/contact-links.ts` · `CD` = `src/lib/contacto-data.ts` · `PQ` = `src/app/api/pqrs/route.ts` · `NL` = `src/app/api/newsletter/route.ts` · `RL` = `src/lib/rate-limit.ts` · `BR` = `src/lib/brands.ts`.
Documentos de `ipr-app/docs`: `AUTH` = `05_api/authentication.md` · `APIA` = `05_api/api_architecture.md` · `APIC` = `05_api/api_contracts.md` · `OAS` = `05_api/openapi.yaml` · `FLU` = `03_architecture/flutter_app_architecture.md` · `OV` = `03_architecture/architecture_overview.md` · `COD` = `00_discovery/informe_codigo_frontend.md` · `WCA` = `00_discovery/analisis_capa_woocommerce.md` · `RF`/`RNF` = `02_requirements/`.

### 0.5 Alcance y límites

- **Entidades:** 41, agrupadas por sistema de registro (WordPress/WooCommerce E01–E30, BFF E31–E34, App E35–E41). Estado por entidad: `EXISTENTE`, `PROPUESTO` o `MIXTO`.
- **Campos que no se conocen** (p. ej. columnas completas de `users`/`usermeta`, metadatos de pedido de plugins, claves de Checkout Field Editor) llevan `DESCONOCIDO` y, en la sección **A.3**, cómo obtenerlos (consulta en *staging*, nunca en producción sin autorización, D-16).
- Los datos **de pago** (tarjeta, cuenta bancaria) **no se modelan**: no pasan por IPR ni por la app (RF-053). El pago ocurre en Wompi dentro del checkout de WooCommerce.

---

# PARTE I — WordPress / WooCommerce (sistema de registro)

## E01 · USUARIO (cliente) — `EXISTENTE`

Tablas nativas de WordPress (`users`, `usermeta`) y cliente de WooCommerce. El contrato móvil (`UserProfile`) es una **lista blanca PROPUESTA** sobre este modelo (sin `roles` ni `username`, `AUTH` A-08).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | Sí | Identificador de usuario (`users.ID`). Hoy se expone como `id`. | WP | `1042` | PERSONAL | Viaja (`UserProfile.id`, ver DM-01) · Memoria | RET-01 | `AR:110`; `OAS` UserProfile |
| `email` | string ≤ 120 en contrato (`user_email`; SUPUESTO ≤ 100 en el esquema estándar de WP, ver INC-24) | Sí | Correo; sirve de login y de contacto. Único por cuenta. | WP | `cliente.demo@ejemplo.test` | PERSONAL | Viaja · Memoria | RET-01 | `AR:111,181-206`; `OAS` RegisterRequest |
| `username` | string (`user_login`, SUPUESTO ≤ 60) | Sí | Nombre de usuario. Con `wc_create_new_customer($email,'',…)` WooCommerce lo genera (SUPUESTO: a partir del correo). **No** va a la app. | WP | `cliente.demo` | PERSONAL | No · No | RET-01 | `AR:112,198`; `AUTH` A-08 |
| `firstName` | string 1–60 (`first_name`, usermeta) | Cond. (contrato: Sí; código actual: opcional) | Nombre de pila. | WP | `Ana` | PERSONAL | Viaja · Memoria | RET-01 | `AR:113,208`; `OAS` RegisterRequest |
| `lastName` | string 1–60 (`last_name`, usermeta) | Cond. (ídem) | Apellido(s). | WP | `Ejemplo` | PERSONAL | Viaja · Memoria | RET-01 | `AR:114,209` |
| `displayName` | string (`display_name`) | Sí | `nombre + apellido` al registrar; si falta, el login. Puede reflejar el correo (riesgo de exposición). | WP | `Ana Ejemplo` | PERSONAL | Viaja · Memoria | RET-01 | `AR:115,210` |
| `roles` | string[] | Sí | Roles de WordPress (p. ej. `customer`). Base de la regla RF-048. **No** va a la app. | WP | `["customer"]` | INTERNO | No · No | RET-01 | `AR:116`; `AUTH` §3.7 |
| `user_pass` | hash (phpass/bcrypt de WP) | Sí | Hash de la contraseña. Se verifica con `wp_check_password`; nunca se expone ni se registra. | WP | (hash; no se muestra) | SECRETO | No · No | RET-01 | `AR:318` |
| `persistent_cart` | meta de WooCommerce (`_woocommerce_persistent_cart_*`) | No | Carrito persistente del usuario en WooCommerce; se borra al solicitar eliminación. Clave exacta: SUPUESTO. | WP | (serializado) | PERSONAL | No · No | RET-01 | `AUTH` §12.1 paso 4, §12.2 |
| `payment_tokens` | tokens de pago de WooCommerce | No | Medios de pago tokenizados si el plugin de Wompi los guarda. Uso: **DESCONOCIDO** (cómo saberlo: revisar el plugin en *staging*). | WP | — | SECRETO | No · No | RET-01 | `AUTH` §12.2 (DESCONOCIDO) |

## E02 · DIRECCION (facturación y envío) — `EXISTENTE` (almacenamiento por verificar, INC-05)

Una dirección de facturación y una de envío por usuario en el MVP (RF-106). El código guarda cada bloque como **arreglo** en los metadatos `billing` y `shipping` (`AR:106-107, 340-359`); WooCommerce estándar usa `billing_*`/`shipping_*`. Los nombres de abajo son los del contrato (`OAS` Address); la clave de WordPress va entre paréntesis.

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `addressType` | enum `billing`/`shipping` | Sí | Tipo de bloque (parámetro de ruta `PUT /me/addresses/{type}`). | DER | `billing` | INTERNO | Viaja · No | RET-01 | `APIC` EP-11; `AR:335-336` |
| `firstName` (`first_name`) | string 1–60 | Sí | Nombre del destinatario o titular de facturación. | WP | `Ana` | PERSONAL | Viaja · Memoria | RET-01 | `AR:335`; `CS:47-67` |
| `lastName` (`last_name`) | string 1–60 | Sí | Apellido(s). | WP | `Ejemplo` | PERSONAL | Viaja · Memoria | RET-01 | `AR:335`; `CS:47-67` |
| `company` (`company`) | string ≤ 120 | No | Razón social o empresa. | WP | `Taller Demo S.A.S.` | PERSONAL | Viaja · Memoria | RET-01 | `AR:335`; `CS:47-67` |
| `nationalId` | string 3–30 `[0-9.-]` | Cond. (obligatoria en facturación según `addressSchema`) | Cédula o NIT. En el checkout nativo los campos son `billing_national_id` y `cedula_nit_ship` (Checkout Field Editor). **No** está en la lista blanca de `AR:335`, así que hoy el perfil **no** la persiste; clave de metadato **DESCONOCIDA**. | WP | `123456789` | PERSONAL-ALTO | Viaja (`Address.nationalId`) · Memoria | RET-01 | `CS:25-31,47`; `HO:322-323,340-341`; `AUTH` §12.2 (DESCONOCIDO) |
| `address1` (`address_1`) | string 1–200 | Sí | Línea principal de la dirección. | WP | `Calle 1 # 2-3` | PERSONAL | Viaja · Memoria | RET-01 | `AR:335`; `CS:47-67` |
| `address2` (`address_2`) | string ≤ 200 | No | Complemento (apartamento, bodega). | WP | `Bodega 4` | PERSONAL | Viaja · Memoria | RET-01 | `AR:335` |
| `department` (`state`) | string ≤ 3 (código de departamento WooCommerce) | Sí | Código de departamento válido (`colombia.ts`). | WP | `ANT` | PERSONAL | Viaja · Memoria | RET-01 | `AR:335`; `CS:47-67` (`isDepartmentCode`) |
| `city` (`city`) | string 1–80 | Sí | Ciudad o municipio. | WP | `Medellín` | PERSONAL | Viaja · Memoria | RET-01 | `AR:335`; `CS:47-67` |
| `postcode` (`postcode`) | string ≤ 20 | No | Código postal. | WP | `050001` | PERSONAL | Viaja · Memoria | RET-01 | `AR:335`; `CS:47-67` |
| `country` (`country`) | string(2) | Sí | País; fijo `CO` en el MVP. | WP | `CO` | INTERNO | No (fijo) · No | RET-01 | `AR:335`; `HO:312,333` |
| `phone` (`phone`) | string 7–20 `[0-9 +\-().]` | Cond. (obligatorio solo en facturación) | Teléfono de contacto. | WP | `300 000 0000` | PERSONAL | Viaja (solo facturación) · Memoria | RET-01 | `AR:335`; `CS:47-67`; `APIC` EP-11 |
| `billingEmail` (`email`) | string ≤ 120 | No | Correo de facturación (puede diferir del de la cuenta). Está en la lista blanca pero **no** en `OAS` Address (INC-04). | WP | `facturacion.demo@ejemplo.test` | PERSONAL | No (hoy) · No | RET-01 | `AR:335`; `HO:319` |

## E03 · TOKEN_WEB_HEREDADO — `EXISTENTE`

Sesión web actual (un solo token por usuario). La app **no** lo usa (usa E04); se conserva para la web y se borra en revocación global y eliminación (`AUTH` §7, §8.5).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `_ipr_auth_token_hash` | CHAR(64) (usermeta, SHA-256 hex) | Cond. (si hay sesión web) | Hash del token vigente de la web; búsqueda por `get_users(meta_value)` (H-07). | WP | (64 hex) | SECRETO | No · No | RET-01 | `AR:47,80-90` |
| `_ipr_auth_token_exp` | integer epoch UTC (usermeta) | Cond. | Vencimiento (emisión + 30 días). | WP | `1795000000` | INTERNO | No · No | RET-01 | `AR:37,48,91` |
| `ipr_session` (cookie web) | string 40 (token en claro) | Cond. (solo web) | Cookie `httpOnly`, `sameSite=lax`, `secure` en producción, 30 días. **No** existe en la app. | BFF (web) | (40 caracteres) | SECRETO | No · No | RET-08 | `SS:3-4,13-22` |

## E04 · SESION_DISPOSITIVO (`{prefix}ipr_auth_sessions`) — `PROPUESTO` (ADR-013)

Esquema **importado sin cambios** de `AUTH` §8.1 (tipo, nulabilidad, defecto e índice en la columna Tipo; descripción abreviada; clasificación traducida: PII → `PERSONAL`, SEC → `SECRETO`, "—" → `INTERNO`). Reglas: una sesión activa por (`user_id`, `device_id`); máx. 10 activas por usuario; no se guarda IP aquí; filas revocadas o vencidas se borran a los 30 días (`RET-03`).

| Campo | Tipo (SQL · nulo · defecto · índice) | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | `BIGINT UNSIGNED AUTO_INCREMENT` · No · — · PK | Sí | Clave interna. | WP | `5001` | INTERNO | No · No | RET-03 | `AUTH` §8.1 (PROPUESTO) |
| `session_uuid` | `CHAR(36)` · No · — · `UNIQUE uq_session_uuid` | Sí | Identificador público de la sesión (logs, auditoría, futura lista de dispositivos). UUID v4. Viaja como `sessionId`. | WP | `00000000-0000-4000-8000-0000000000a1` | INTERNO | Viaja (`Session.sessionId`) · Memoria | RET-03 | `AUTH` §8.1; `OAS` Session |
| `user_id` | `BIGINT UNSIGNED` · No · — · `idx_user_revoked (user_id, revoked_at)`; `idx_user_device (user_id, device_id)` | Sí | Dueño de la sesión (`users.ID`). | WP | `1042` | PERSONAL | No · No | RET-03 | `AUTH` §8.1 |
| `device_id` | `CHAR(36)` · No · — · ver `idx_user_device` | Sí | UUID v4 de la instalación (`AUTH` §4). No es secreto ni prueba de identidad. | APP→WP | `00000000-0000-4000-8000-0000000000d1` | PERSONAL | Viaja (cabecera `X-Device-Id`) · Secure storage | RET-03 | `AUTH` §8.1, §4 |
| `client_type` | `VARCHAR(16)` · No · — · — | Sí | `app_android` · `app_ios` · `web` (CHECK en aplicación). | BFF | `app_android` | INTERNO | Viaja (cabecera `X-App-Platform`) · No | RET-03 | `AUTH` §8.1 |
| `device_label` | `VARCHAR(80)` · Sí · `NULL` · — | No | Plataforma y versión de SO; sin modelo ni nombre del equipo. | APP→WP | `Android 14` | INTERNO | No · No | RET-03 | `AUTH` §8.1, §4 |
| `app_version` | `VARCHAR(20)` · Sí · `NULL` · — | No | Versión de la app al emitir o rotar. | APP→WP | `1.0.0` | INTERNO | Viaja (cabecera `X-App-Version`) · No | RET-03 | `AUTH` §8.1 |
| `access_token_hash` | `CHAR(64)` · No · — · `UNIQUE uq_access_hash` | Sí | SHA-256 hex del access token vigente. | WP | (64 hex) | SECRETO | No · No | RET-03 | `AUTH` §8.1, §3.2 |
| `access_expires_at` | `DATETIME` · No · — · — | Sí | Vencimiento del access (emisión + 15 min). UTC. | WP | `2026-11-18 15:15:00` | INTERNO | Viaja (como `accessTokenExpiresIn`, segundos) · Memoria | RET-03 | `AUTH` §8.1; `OAS` Session |
| `refresh_token_hash` | `CHAR(64)` · No · — · `UNIQUE uq_refresh_hash` | Sí | SHA-256 hex del refresh vigente. | WP | (64 hex) | SECRETO | No · No | RET-03 | `AUTH` §8.1 |
| `prev_refresh_token_hash` | `CHAR(64)` · Sí · `NULL` · `idx_prev_refresh` | No | Hash del refresh anterior (detección de reutilización y gracia de 30 s). | WP | (64 hex) | SECRETO | No · No | RET-03 | `AUTH` §8.1, §3.4 |
| `rotated_at` | `DATETIME` · Sí · `NULL` · — | No | Momento de la última rotación. | WP | `2026-11-18 15:00:00` | INTERNO | No · No | RET-03 | `AUTH` §8.1 |
| `rotation_counter` | `INT UNSIGNED` · No · `0` · — | Sí | Número de rotaciones (diagnóstico). | WP | `4` | INTERNO | No · No | RET-03 | `AUTH` §8.1 |
| `idle_expires_at` | `DATETIME` · No · — · — | Sí | Vencimiento por inactividad del refresh (30 d, acotado por la absoluta). Viaja como `refreshTokenExpiresAt`. | WP | `2026-12-18 15:00:00` | INTERNO | Viaja · Memoria | RET-03 | `AUTH` §8.1; `OAS` Session |
| `absolute_expires_at` | `DATETIME` · No · — · `idx_abs_exp` (limpieza) | Sí | Vencimiento absoluto (login + 90 d). | WP | `2027-02-16 15:00:00` | INTERNO | No · No | RET-03 | `AUTH` §8.1 |
| `created_at` | `DATETIME` · No · — · — | Sí | Emisión (login o registro). | WP | `2026-11-18 15:00:00` | INTERNO | No · No | RET-03 | `AUTH` §8.1 |
| `last_used_at` | `DATETIME` · No · — · — | Sí | Último uso (escrito como máx. cada 5 min). | WP | `2026-11-18 15:05:00` | INTERNO | No · No | RET-03 | `AUTH` §8.1, §3.3 |
| `revoked_at` | `DATETIME` · Sí · `NULL` · ver `idx_user_revoked` | No | Momento de revocación; `NULL` = activa. | WP | `NULL` | INTERNO | No · No | RET-03 | `AUTH` §8.1 |
| `revoked_reason` | `VARCHAR(32)` · Sí · `NULL` · — | No | `logout` · `logout_all` · `replaced` · `session_limit` · `password_change` · `email_change` · `password_reset` · `reuse_detected` · `device_mismatch` · `account_deletion` · `admin` · `role_denied`. | WP | `logout` | INTERNO | No · No | RET-03 | `AUTH` §8.1 |

## E05 · EVENTO_AUDITORIA (`{prefix}ipr_auth_events`) — `PROPUESTO` (RNF-105)

Esquema importado sin cambios de `AUTH` §8.2. Retención **90 días** (`RET-04`); el registro mínimo de eliminación se conserva el plazo de **D-12**.

| Campo | Tipo (SQL · nulo · defecto · índice) | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | `BIGINT UNSIGNED AUTO_INCREMENT` · No · — · PK | Sí | Clave interna. | WP | `90001` | INTERNO | No · No | RET-04 | `AUTH` §8.2 |
| `occurred_at` | `DATETIME(3)` · No · — · `idx_occurred (occurred_at)` | Sí | Momento del evento (UTC, ms). | WP | `2026-11-18 15:00:00.123` | INTERNO | No · No | RET-04 | `AUTH` §8.2 |
| `event_type` | `VARCHAR(40)` · No · — · `idx_type_time (event_type, occurred_at)` | Sí | `login_succeeded`, `login_failed`, `login_denied_role`, `login_throttled`, `registered`, `refresh_reused`, `session_revoked`, `logout_all`, `password_changed`, `email_changed`, `password_reset_requested`, `password_reset_completed`, `deletion_requested`, `deletion_completed`, `checkout_ticket_issued`. | WP | `login_failed` | INTERNO | No · No | RET-04 | `AUTH` §8.2 |
| `outcome` | `VARCHAR(10)` · No · — · — | Sí | `success` · `failure`. | WP | `failure` | INTERNO | No · No | RET-04 | `AUTH` §8.2 |
| `user_id` | `BIGINT UNSIGNED` · Sí · `NULL` · `idx_user_time (user_id, occurred_at)` | No | Usuario si se conoce (`NULL` en login de cuenta inexistente). | WP | `1042` | PERSONAL | No · No | RET-04 | `AUTH` §8.2 |
| `session_uuid` | `CHAR(36)` · Sí · `NULL` · — | No | Sesión implicada. | WP | `00000000-0000-4000-8000-0000000000a1` | INTERNO | No · No | RET-04 | `AUTH` §8.2 |
| `subject_hash` | `CHAR(64)` · Sí · `NULL` · — | No | HMAC-SHA256 (secreto del servidor) del login o correo normalizado en intentos fallidos. Seudónimo. | WP | (64 hex) | PERSONAL | No · No | RET-04 | `AUTH` §8.2 (PSEUDO) |
| `ip_address` | `VARBINARY(16)` · Sí · `NULL` · — | No | IP del cliente (`INET6_ATON`), recibida del BFF en `X-IPR-Client-IP`. | BFF→WP | `203.0.113.10` | PERSONAL | No · No | RET-04 | `AUTH` §8.2 |
| `client_type` | `VARCHAR(16)` · Sí · `NULL` · — | No | Canal. | BFF | `app_ios` | INTERNO | No · No | RET-04 | `AUTH` §8.2 |
| `request_id` | `CHAR(36)` · Sí · `NULL` · — | No | `X-IPR-Request-Id` para correlacionar con logs del BFF. | BFF | `00000000-0000-4000-8000-0000000000b1` | INTERNO | Viaja (cabecera `X-Request-Id`) · No | RET-04 | `AUTH` §8.2 |
| `reason_code` | `VARCHAR(40)` · Sí · `NULL` · — | No | Motivo (p. ej. `reuse_detected`). Nunca contraseñas, tokens ni correos. | WP | `reuse_detected` | INTERNO | No · No | RET-04 | `AUTH` §8.2 |

## E06 · CONTADOR_THROTTLE (`{prefix}ipr_auth_throttle`) — `PROPUESTO` (RNF-042)

Esquema importado sin cambios de `AUTH` §8.3. Operación atómica `INSERT … ON DUPLICATE KEY UPDATE`; un login exitoso borra el contador `login_account` del sujeto.

| Campo | Tipo (SQL · nulo · defecto · índice) | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | `BIGINT UNSIGNED AUTO_INCREMENT` · No · — · PK | Sí | Clave interna. | WP | `7001` | INTERNO | No · No | RET-05 | `AUTH` §8.3 |
| `scope` | `VARCHAR(24)` · No · — · `UNIQUE uq_scope_subject (scope, subject_hash)` | Sí | `login_account`, `login_ip`, `register_ip`, `forgot_email`, `forgot_ip`, `sensitive_account`, `refresh_session`, `pqrs_ip` (si no hay regla en Cloudflare). | WP | `login_account` | INTERNO | No · No | RET-05 | `AUTH` §8.3 |
| `subject_hash` | `CHAR(64)` · No · — · ver arriba | Sí | HMAC-SHA256 del sujeto (login normalizado, correo, IP, `session_uuid`). No se guarda el valor en claro. | WP | (64 hex) | PERSONAL | No · No | RET-05 | `AUTH` §8.3 (PSEUDO) |
| `failures` | `INT UNSIGNED` · No · `0` · — | Sí | Intentos (fallidos o totales según el `scope`) en la ventana. | WP | `3` | INTERNO | No · No | RET-05 | `AUTH` §8.3 |
| `window_started_at` | `DATETIME` · No · — · — | Sí | Inicio de la ventana. | WP | `2026-11-18 15:00:00` | INTERNO | No · No | RET-05 | `AUTH` §8.3 |
| `locked_until` | `DATETIME` · Sí · `NULL` · — | No | Bloqueo vigente hasta. | WP | `NULL` | INTERNO | No · No | RET-05 | `AUTH` §8.3 |
| `lock_level` | `TINYINT UNSIGNED` · No · `0` · — | Sí | Escalón del bloqueo progresivo (0..4). | WP | `0` | INTERNO | No · No | RET-05 | `AUTH` §8.3 |
| `updated_at` | `DATETIME` · No · — · `idx_updated` (limpieza) | Sí | Último cambio. | WP | `2026-11-18 15:00:05` | INTERNO | No · No | RET-05 | `AUTH` §8.3 |

## E07 · CONSENTIMIENTO (`{prefix}ipr_consents`) — `PROPUESTO` (Ley 1581, RF-039, RNF-056)

Esquema importado sin cambios de `AUTH` §8.4. Prueba de autorización previa, expresa e informada. Retención: mientras exista el tratamiento más el plazo de **D-12** (`RET-06`). Limitación: `user_id` es obligatorio, por lo que no cubre autorizaciones de visitantes (PQRS anónima, boletín): ver DM-04.

| Campo | Tipo (SQL · nulo · defecto · índice) | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | `BIGINT UNSIGNED AUTO_INCREMENT` · No · — · PK | Sí | Clave interna. | WP | `3001` | INTERNO | No · No | RET-06 | `AUTH` §8.4 |
| `user_id` | `BIGINT UNSIGNED` · No · — · `idx_user_doc (user_id, document)` | Sí | Titular. | WP | `1042` | PERSONAL | No · No | RET-06 | `AUTH` §8.4 |
| `document` | `VARCHAR(32)` · No · — · ver arriba | Sí | `terms` · `privacy_policy` (fase 2: `marketing`, `push`). | WP | `privacy_policy` | INTERNO | No · No | RET-06 | `AUTH` §8.4 |
| `document_version` | `VARCHAR(20)` · No · — · — | Sí | Versión aceptada (la publica `GET /config`). | WP | `2026-11-01` | INTERNO | Viaja (`acceptance.termsVersion`/`privacyPolicyVersion`) · No | RET-06 | `AUTH` §8.4; `OAS` RegisterRequest |
| `action` | `VARCHAR(10)` · No · — · — | Sí | `accepted` · `revoked`. | WP | `accepted` | INTERNO | No · No | RET-06 | `AUTH` §8.4 |
| `occurred_at` | `DATETIME` · No · — · — | Sí | Momento (UTC). | WP | `2026-11-18 15:00:00` | INTERNO | No · No | RET-06 | `AUTH` §8.4 |
| `client_type` | `VARCHAR(16)` · No · — · — | Sí | Canal (`app_android`, `app_ios`, `web`). | BFF | `app_android` | INTERNO | No · No | RET-06 | `AUTH` §8.4 |
| `app_version` | `VARCHAR(20)` · Sí · `NULL` · — | No | Versión de la app. | APP→WP | `1.0.0` | INTERNO | No · No | RET-06 | `AUTH` §8.4 |
| `request_id` | `CHAR(36)` · Sí · `NULL` · — | No | Correlación. | BFF | `00000000-0000-4000-8000-0000000000b2` | INTERNO | No · No | RET-06 | `AUTH` §8.4 |

## E08 · SOLICITUD_ELIMINACION (estado de cuenta) — `PROPUESTO` (ADR-022)

Metadatos nuevos de usuario (`AUTH` §8.5) más la solicitud de privacidad nativa de WordPress (`wp_create_user_request`, `AUTH` §12.1 paso 5). Detalle del flujo y de lo que se borra o conserva: [data_model.md](data_model.md) §7.

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `_ipr_account_state` | enum (`active`, `pending_deletion`, `deleted`; ausente = `active`) | No | Bloquea login y validación de tokens si no es `active`. | WP | `pending_deletion` | INTERNO | No · No | RET-15 | `AUTH` §8.5 |
| `_ipr_deletion_requested_at` | integer epoch UTC | Cond. | Inicio de la solicitud de eliminación. | WP | `1795000000` | INTERNO | No · No | RET-15 | `AUTH` §8.5 |
| `_ipr_deletion_request_id` (`requestId`) | UUID | Cond. | Id devuelto a la app (idempotencia) y enlazado a la solicitud de privacidad. | WP | `00000000-0000-4000-8000-0000000000c1` | INTERNO | Viaja (`AccountDeletionStatus.requestId`) · No | RET-15 | `AUTH` §8.5; `OAS` AccountDeletionStatus |
| `status` | enum `scheduled`/`completed` | Sí | Estado de la anonimización programada (WP-Cron). | WP | `scheduled` | INTERNO | Viaja · No | RET-15 | `OAS` AccountDeletionStatus |
| `completeBy` | datetime ISO 8601 con zona | Sí | Fecha límite de cumplimiento (máx. 15 días hábiles propuestos; **D-12** puede fijar periodo de arrepentimiento). | WP | `2026-12-09T23:59:59-05:00` | INTERNO | Viaja · No | RET-15 | `OAS` AccountDeletionStatus; `AUTH` §12.1 paso 6 |
| `privacy_request_email` | string (correo del titular guardado por la solicitud de privacidad de WP) | Sí | La solicitud nativa se crea con el correo del titular. Comportamiento de WP core: SUPUESTO; verificar en *staging*. | WP | `cliente.demo@ejemplo.test` | PERSONAL | No · No | RET-15 | `AUTH` §12.1 paso 5 (SUPUESTO sobre el almacenamiento) |

## E09 · PRODUCTO — `EXISTENTE` (WooCommerce `wc/v3`; DTO móvil `PROPUESTO`)

Fuente de verdad: WooCommerce. La app recibe un DTO por lista blanca (`ProductSummary`, `ProductDetail`); **nunca** `stockQuantity` ni HTML sin sanear. Campos de WooCommerce solicitados con `_fields` (`WC:54-81`).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | integer en WooCommerce (el código lo convierte a string, INC-06) | Sí | Identificador del producto. | WP | `18345` | PÚBLICO | Viaja (`id` integer) · Hive cart / Hive cache | RET-11 | `WC:214,263`; `MD:2`; `OAS` ProductSummary |
| `slug` | string `^[a-z0-9][a-z0-9._-]{0,199}$` | Sí | Identificador legible; clave de la ficha. | WP | `valvula-demo-3-4` | PÚBLICO | Viaja · Hive cache | RET-11 | `WC:216`; `OAS` Slug; INC-23 |
| `name` | string | Sí | Nombre comercial. | WP | `Válvula de expansión demo` | PÚBLICO | Viaja · Hive cache / cart (instantánea) | RET-11 | `WC:215` |
| `sku` | string (puede ser vacío) | Sí en contrato | Referencia. Búsqueda por SKU exacto prioritaria. `raw.sku ?? ""`. | WP | `100-0001` | PÚBLICO | Viaja · Hive cache | RET-11 | `WC:221,271`; `RNF-110` |
| `price` | string decimal en WooCommerce; número COP IVA incluido en código (`0` = sin precio) | Sí | Precio vigente. **La app nunca lo decide.** | WP | `1289500` | PÚBLICO | Viaja como `price.amount` (null si `on_request`) · Hive cache / cart (solo mostrar) | RET-11 | `WC:217,258`; `OAS` Price |
| `regular_price` | string decimal | No | Precio regular antes de la oferta; solo se usa si `onSale`. | WP | `1450000` | PÚBLICO | Viaja (`price.regularAmount`) · Hive cache | RET-11 | `WC:218,259-260` |
| `sale_price` | string decimal | No | Precio de oferta. Se solicita en `_fields` pero **no** se mapea hoy. | WP | `1289500` | PÚBLICO | No · No | RET-11 | `WC:219` |
| `on_sale` | boolean | No | Indicador de WooCommerce; el código lo combina con `price > 0` y `regular > price`. | WP | `true` | PÚBLICO | Viaja (`price.onSale`) · Hive cache | RET-11 | `WC:220,260` |
| `price.status` | enum `priced`/`on_request` | Sí | Derivado: `on_request` ⇔ precio 0. Nunca `$0`. | DER (BFF) | `priced` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` Price; RF-012; `RNF-107` |
| `price.discountPercent` | integer 0–100 o null | Sí | Porcentaje de descuento calculado (`discountPercent`). | DER (BFF) | `11` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` Price; `liquidaciones-shared.ts:24-35` (vía `WCA` §1.3) |
| `stock_status` | enum WooCommerce `instock`/`outofstock`/`onbackorder` | Sí | Estado de existencias. | WP | `instock` | PÚBLICO | Viaja como `availability` · Hive cache | RET-11 | `WC:222,277` |
| `availability` | enum `in_stock`/`out_of_stock`/`on_backorder` | Sí | Derivado de `stock_status`. Nunca cantidades. | DER (BFF) | `in_stock` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` Availability |
| `purchasable` | boolean | Sí | Derivado: precio con valor y disponible (`on_backorder` según AP-04). Defensa en profundidad: la app también oculta "Añadir" si precio 0. | DER (BFF) | `true` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` ProductSummary; `APIC` §1.5 |
| `stock_quantity` | integer o null | No | Inventario exacto. **No se expone a la app** (S-01). | WP | `12` | INTERNO | No · No | RET-11 | `WC:223,1083` (vía `WCA` §4.1) |
| `description` | HTML crudo | Cond. (ficha) | Descripción larga. A la app solo como `descriptionHtml` **saneado en servidor**. | WP | `<p>Descripción demo</p>` | PÚBLICO | Viaja saneado (`descriptionHtml`) · Hive cache (ficha) | RET-11 | `WC:224`; `OAS` ProductDetail; ADR-019 |
| `short_description` | HTML crudo | Cond. (ficha) | Descripción corta. A la app como texto plano (`shortDescription`). | WP | `Descripción corta demo` | PÚBLICO | Viaja (texto plano) · Hive cache | RET-11 | `WC:225`; `OAS` ProductDetail |
| `status` | enum WooCommerce (`publish`, `draft`, `pending`, `private`) | Sí | Estado editorial. Solo `publish` es visible. SEC-07 abierto en la ficha (`wc.ts:1117-1121`). | WP | `publish` | INTERNO | No · No | RET-11 | `WC:429,536,753`; `WCA` §4.2 |
| `catalog_visibility` | enum WooCommerce (`visible`, `catalog`, `search`, `hidden`) | No | **PROPUESTO** leerlo (FE-01): hoy no se filtra y un producto "oculto" aparece en listados. | WP | `visible` | INTERNO | No · No | RET-11 | PROPUESTO: `APIA` FE-01; `WCA` §4.2 (no se filtra hoy) |
| `categorySlugs` | string[] | Sí | Slugs de **todas** las categorías (el campo `category` del código es solo la primera, INC-11). | DER | `["compresores"]` | PÚBLICO | Viaja · Hive cache | RET-11 | `WC:274-275`; `OAS` ProductSummary |
| `webUrl` | URI | Sí (solo ficha) | URL de la ficha web del producto (para compartir). | DER (BFF) | `https://ejemplo.test/producto/valvula-demo` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` ProductDetail |

## E10 · ATRIBUTO_PRODUCTO — `EXISTENTE`

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | integer (opcional) | No | Id del atributo global de WooCommerce (`pa_*`). | WP | `7` | PÚBLICO | No · No | RET-11 | `WC:207` |
| `name` | string | Sí | Nombre visible (p. ej. "Capacidad BTU"). | WP | `Capacidad BTU` | PÚBLICO | Viaja · Hive cache | RET-11 | `WC:208`; `OAS` ProductAttribute |
| `slug` | string (`pa_…`) | Sí | Slug del atributo; clave de filtro `attr[<pa_slug>]`. | WP | `pa_capacidad-btu` | PÚBLICO | Viaja · Hive cache | RET-11 | `WC:209`; `APIC` EP-14 |
| `options` | string[] | Sí | Términos del producto. Hay slugs inconsistentes (`12-0-hp` vs `120hp`). | WP | `["12.000 BTU"]` | PÚBLICO | Viaja · Hive cache | RET-11 | `WC:210`; `WCA` §6 |

## E11 · CATEGORIA — `EXISTENTE`

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | integer | Sí | Identificador de la categoría. | WP | `55` | PÚBLICO | Viaja · Hive cache | RET-11 | `WC:226`; `meta.ts` (`WcCategory`, vía `WCA` §1.2) |
| `name` | string | Sí | Nombre. Algunas categorías basura: `-`, slugs numéricos, `uncategorized` (se excluyen en el DTO). | WP | `Compresores` | PÚBLICO | Viaja · Hive cache | RET-11 | `WCA` §1.2, §6 |
| `slug` | string | Sí | Clave de filtro `category`. | WP | `compresores` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` Category |
| `parentId` (`parent`) | integer o null | Sí | Categoría padre (0 → null). | WP | `null` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` Category; `WCA` §1.2 |
| `children` | Category[] | Sí | Hijos anidados; derivado por `buildCategoryTree`. | DER (BFF) | `[]` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` Category; `WC:103-132` |

## E12 · MARCA — `EXISTENTE` (fuente canónica: **DECISIÓN PENDIENTE AP-05**)

Hoy hay **cuatro fuentes no alineadas**: taxonomía `product_brand` (WordPress), registro de landings `BRAND_LANDINGS`, lista de alias `BRANDS` y mapa de logos `BRAND_LOGOS` (`WCA` §6). La marca de un producto se resuelve por heurística (atributo → nombre → taxonomía).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `termId` | integer | Cond. | Id del término `product_brand` (`brands[].id`); base del filtro por marca. | WP | `31` | PÚBLICO | No · No | RET-11 | `WC:227`; `WCA` §1.1 |
| `name` | string | Sí | Nombre canónico (corrige alias y entidades `&amp;`). | WP/DER | `Marca Demo` | PÚBLICO | Viaja (`BrandRef.name`) · Hive cache | RET-11 | `BR:60-92`; `OAS` BrandRef |
| `slug` | string o null | Sí | Slug de marca; **null cuando la marca salió de la heurística** y no de la taxonomía. | WP/DER | `marca-demo` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` BrandRef (nullable); INC-10 |
| `logoUrl` | URI o null | Sí | Hoy ruta relativa `/logos/marcas-recortadas/…`; el contrato exige URL absoluta. | DER (BFF) | `https://ejemplo.test/logos/marca-demo.webp` | PÚBLICO | Viaja · Hive cache | RET-11 | `BR:130-141`; `OAS` Brand |
| `hasLanding` | boolean | Sí | Existe landing en el registro `BRAND_LANDINGS` (~27 marcas). | DER | `true` | PÚBLICO | Viaja · Hive cache | RET-11 | `brand-landing-data.ts:32`; `OAS` Brand |
| `aliases` | string[] (estático) | No | Alias para deducir marca desde el nombre del producto (28). Solo servidor. | BFF | `["marca demo"]` | INTERNO | No · No | RET-11 | `BR:8-39` (vía `WCA` §6) |

## E13 · ETIQUETA (tag de producto) — `EXISTENTE`

Se usa para liquidaciones (`liquidacion`) y para búsqueda.

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | integer | Sí | Id de la etiqueta. | WP | `9` | PÚBLICO | No · No | RET-11 | `WC:230` |
| `name` | string | Sí | Nombre. | WP | `Liquidación` | PÚBLICO | No · No | RET-11 | `WC:230` |
| `slug` | string | Sí | Slug (`liquidacion` para EP-20; filtro `tag`). | WP | `liquidacion` | PÚBLICO | Viaja (filtro `tag`) · No | RET-11 | `WC:230`; `liquidaciones.ts:14` (vía `WCA` §1.3) |

## E14 · IMAGEN — `EXISTENTE` (variantes por ancho: DN-03 pendiente)

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `url` (`src`) | URI | Sí | URL de la imagen **original** (sin miniaturas). Sin imagen: `""` hoy; el DTO debe devolver `null`. | WP | `https://ejemplo.test/uploads/valvula-demo.jpg` | PÚBLICO | Viaja · caché de imágenes de `cached_network_image` | RET-10 | `WC:228,261`; `OAS` ImageRef |
| `alt` | string | Sí en contrato | Texto alternativo (RNF-108: = nombre). **No se lee hoy** de WooCommerce; origen **DESCONOCIDO** (cómo: ampliar `_fields` con `alt`, afecta la caché compartida). | WP/BFF | `Válvula de expansión demo` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` ImageRef; `WC:228` (solo `src`); INC-12 |
| `width` | integer o null | No | Ancho en px. **DESCONOCIDO** (MED-07). | WP | `1200` | PÚBLICO | Viaja · No | RET-11 | `OAS` ImageRef; `APIC` §6 |
| `height` | integer o null | No | Alto en px. **DESCONOCIDO** (MED-07). | WP | `1200` | PÚBLICO | Viaja · No | RET-11 | `OAS` ImageRef; `APIC` §6 |

## E15 · PEDIDO (`WC_Order`) — `EXISTENTE` (DTO móvil y metadatos nuevos `PROPUESTOS`)

Fuente de verdad: WooCommerce (+ Wompi para el estado de pago, webhook **DESCONOCIDO**, D-02). El pedido copia datos de facturación y envío del momento de la compra (`AUTH` §12.2). Autorización por objeto: `customer_id` del pedido = usuario autenticado, si no `404`.

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | integer | Sí | Id interno del pedido. | WP | `98001` | PERSONAL | Viaja (`OrderSummary.id`) · Memoria | RET-02 | `AR:256`; `OAS` OrderSummary |
| `number` (`orderNumber`) | string | Sí | Número visible; puede diferir del id si hay plugin de numeración (SA-07). | WP | `98001` | PERSONAL | Viaja · Memoria | RET-02 | `AR:257`; `OAS` OrderSummary; INC-16 |
| `status` | string WooCommerce sin prefijo `wc-` | Sí | `processing`, `completed`, `on-hold`, `cancelled`, `refunded`, `failed`, `pending` y estados de plugins. | WP | `processing` | PERSONAL | Viaja · Memoria | RET-02 | `AR:258,136-148` |
| `statusLabel` | string | Sí | Etiqueta en español del servidor; estados desconocidos: `ucfirst`. | WP | `En proceso` | PERSONAL | Viaja · Memoria | RET-02 | `AR:259,136-148` |
| `paymentState` | enum `paid`/`pending`/`failed`/`cancelled`/`refunded`/`unknown` | Sí | Derivado del estado WooCommerce (`on-hold` → `pending` es SUPUESTO PA-12). | DER (BFF) | `paid` | PERSONAL | Viaja · Memoria | RET-02 | `APIA` §13.2; `OAS` PaymentState |
| `createdAt` (`date`) | datetime ISO 8601 con zona | Sí | Hoy `Y-m-d H:i:s` **sin zona** (INC-13). | WP | `2026-11-18T10:15:00-05:00` | PERSONAL | Viaja · Memoria | RET-02 | `AR:260`; `OAS` OrderSummary |
| `currency` | string(3) | Sí | `COP`. | WP | `COP` | INTERNO | Viaja · Memoria | RET-02 | `AR:261` |
| `subtotal` | number | Sí (detalle) | Subtotal de líneas. | WP | `1289500` | PERSONAL | Viaja · Memoria | RET-02 | `AR:262`; `OAS` OrderDetail |
| `shippingTotal` | number | Sí (detalle) | Envío elegido en el checkout de WooCommerce. No existe en el mapeo actual. | WP | `25000` | PERSONAL | Viaja · Memoria | RET-02 | `OAS` OrderDetail; `AR:245-266` (ausente hoy) |
| `discountTotal` | number | Sí (detalle) | Descuentos. | WP | `0` | PERSONAL | Viaja · Memoria | RET-02 | `OAS` OrderDetail |
| `taxTotal` | number | Sí (detalle) | Impuestos. | WP | `205900` | PERSONAL | Viaja · Memoria | RET-02 | `OAS` OrderDetail |
| `total` | number | Sí | Total del pedido. | WP | `1520400` | PERSONAL | Viaja · Memoria | RET-02 | `AR:263`; `OAS` OrderSummary |
| `paymentMethodTitle` | string | Sí (detalle) | Título del medio de pago (p. ej. Wompi). **No** incluye datos de pago. | WP | `Wompi` | PERSONAL | Viaja · Memoria | RET-02 | `AR:264`; `OAS` OrderDetail |
| `itemCount` | integer ≥ 0 | Sí | Derivado: suma de cantidades o número de líneas (criterio por definir en el contrato). | DER (BFF) | `2` | PERSONAL | Viaja · Memoria | RET-02 | `OAS` OrderSummary |
| `customer_id` | BIGINT UNSIGNED o 0 | Sí | Dueño del pedido; base de la autorización por objeto; se desvincula al eliminar la cuenta (D-12). | WP | `1042` | PERSONAL | No · No | RET-02 | `AR:242`; `AUTH` §14 API1, §12.2 |
| `billing_snapshot` | composite (nombre, empresa, cédula/NIT, dirección, teléfono, correo) | Sí | Copia de facturación al comprar. **No** viaja a la app (`EP-26`). | WP | (compuesto) | PERSONAL-ALTO | No · No | RET-02 | `AUTH` §12.2; `APIC` EP-26 |
| `shipping_snapshot` | composite (nombre, empresa, dirección) | Cond. | Copia de envío. No viaja. | WP | (compuesto) | PERSONAL | No · No | RET-02 | `AUTH` §12.2; `APIC` EP-26 |
| `customer_note` (`order_comments`) | string (texto libre) | No | Notas del cliente en el checkout; pueden contener cualquier dato personal. | WP | `Entregar en portería` | PERSONAL-ALTO | No · No | RET-02 | `HO:221-223,349-351`; `AUTH` §12.2 (notas) |
| `customer_ip_address` | string IP | No | IP del comprador que registra WooCommerce. No viaja (EP-26). Existencia: confirmada por el contrato que la excluye. | WP | `203.0.113.10` | PERSONAL | No · No | RET-02 | `APIC` EP-26 |
| `customer_user_agent` | string | No | Agente de usuario registrado por WooCommerce. No viaja. | WP | `Mozilla/5.0 (demo)` | PERSONAL | No · No | RET-02 | `APIC` EP-26 |
| `transaction_id` | string | No | Id de transacción de la pasarela. No viaja. | WP | `demo-tx-0001` | INTERNO | No · No | RET-02 | `APIC` EP-26 |
| `internal_notes` | string[] | No | Notas internas del pedido (staff). No viajan. | WP | (no aplica) | INTERNO | No · No | RET-02 | `APIC` EP-26; `AUTH` §14 API3 |
| `_ipr_checkout_ref` | UUID (meta del pedido, compatible con HPOS) | No | Correlación con el intento de checkout de la app (ADR-017). | WP | `00000000-0000-4000-8000-0000000000e1` | PERSONAL | Viaja (`CheckoutStatus.checkoutRef`) · Hive cache (intento) | RET-02 | `AUTH` §8.5 (PROPUESTO) |
| `_ipr_channel` | enum `app`/`web` (meta del pedido) | No | Canal de origen (métricas, ADR-002). | WP | `app` | INTERNO | No · No | RET-02 | `AUTH` §8.5 (PROPUESTO) |

## E16 · LINEA_PEDIDO — `EXISTENTE` (campos adicionales del DTO `PROPUESTOS`)

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `productId` | integer o null | Sí | Producto referenciado; null si el producto fue eliminado. **No existe** en el mapeo actual (`AuthOrderItem` solo trae nombre, cantidad y total). | WP | `18345` | PERSONAL | Viaja · Memoria | RET-02 | `OAS` OrderDetail.items; `AR:248-253` (ausente); INC-13 |
| `name` | string | Sí | Nombre del producto **al momento de la compra**. | WP | `Válvula de expansión demo` | PERSONAL | Viaja · Memoria | RET-02 | `AR:250`; `AU` `AuthOrderItem` |
| `sku` | string o null | Sí | Referencia. Ausente en el mapeo actual. | WP | `100-0001` | PERSONAL | Viaja · Memoria | RET-02 | `OAS` OrderDetail.items |
| `quantity` (`qty`) | integer | Sí | Cantidad (1–99 por línea). | WP | `2` | PERSONAL | Viaja · Memoria | RET-02 | `AR:251`; `OAS` OrderDetail.items; INC-13 |
| `total` | number | Sí | Total de la línea. | WP | `1289500` | PERSONAL | Viaja · Memoria | RET-02 | `AR:252` |
| `imageUrl` | URI o null | Sí | Imagen del producto. PROPUESTO: el pedido actual no la trae (RF-108). | DER (BFF) | `https://ejemplo.test/uploads/valvula-demo.jpg` | PERSONAL | Viaja · Memoria | RET-02 | `OAS` OrderDetail.items; `RF-108` |

## E17 · INTENTO_CHECKOUT (`checkoutRef`) — `PROPUESTO` (ADR-017)

Concepto: un intento de pago iniciado por la app. **No tiene tabla propia**: el BFF genera el `checkoutRef`; WordPress lo guarda en la sesión de WooCommerce y, al crear el pedido, en `_ipr_checkout_ref`; la app lo guarda localmente (E40). Antes de que exista el pedido, el intento solo vive en el ticket (E18) y en la memoria del BFF (E31). La fuente de verdad del **resultado** es `GET /checkout/{checkoutRef}`, no el deep link.

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `checkoutRef` | UUID v4 | Sí | Identificador del intento; generado por el BFF. | BFF | `00000000-0000-4000-8000-0000000000e1` | PERSONAL | Viaja · Hive cache (`CheckoutAttemptLocal`) | RET-02 (en el pedido) / RET-08 | `APIC` EP-23; `AUTH` §8.5 |
| `userId` | BIGINT UNSIGNED | Sí | Usuario autenticado dueño del intento (nunca viene del cliente). | WP | `1042` | PERSONAL | No · No | RET-08 | `APIA` §13.1 (identidad en el ticket) |
| `items` | `[{id, quantity}]` 1–100 líneas, cantidad 1–99 | Sí | Carrito enviado. Sin precios. | APP | `[{"id":18345,"quantity":2}]` | INTERNO | Viaja (solicitud) · Hive cart | RET-08 | `APIC` EP-23; `CS:77-93` |
| `channel` | enum `app`/`web` | Sí | Canal; se copia a `_ipr_channel`. | BFF | `app` | INTERNO | No · No | RET-08 | `AUTH` §8.5 |
| `expiresAt` / `expiresIn` | datetime ISO 8601; integer (60) | Sí | Vencimiento del ticket (60 s). | BFF | `2026-11-18T10:16:00-05:00` | INTERNO | Viaja · No | RET-08 | `OAS` CheckoutSession |
| `state` | enum `awaiting_order`/`order_created` | Sí | Derivado: ¿existe pedido del usuario con ese `_ipr_checkout_ref`? Un `checkoutRef` ajeno devuelve `awaiting_order`. | DER (WP/BFF) | `order_created` | INTERNO | Viaja · Hive cache | RET-08 | `APIC` EP-24 |
| `orderId` | integer o null | No | Pedido resultante (relación 0..1; doble pedido por reintentos: DESCONOCIDO, PA-11). | DER | `98001` | PERSONAL | Viaja (dentro de `order`) · Memoria | RET-02 | `APIC` EP-24; `PA-11` |
| `checkoutUrl` | URI `https://<host WP>/?ipr_ticket=<32>` | Sí | URL con el ticket. **No se guarda ni se registra.** | BFF | `https://ejemplo.test/?ipr_ticket=<32 caracteres>` | SECRETO | Viaja · No (solo abrir) | RET-08 | `OAS` CheckoutSession; AC-052-4 |
| `allowedHosts` | string[] | Sí | Lista cerrada de hosts válidos para `checkoutUrl`. | BFF | `["ejemplo.test"]` | PÚBLICO | Viaja · Hive cache (config) | RET-11 | `OAS` CheckoutSession; `APIA` §13.1 |

## E18 · TICKET_HANDOFF (transient `ipr_handoff_<ticket>`) — `EXISTENTE` (cambios `PROPUESTOS` WP-06)

Almacén temporal de WordPress, **60 s**, de un solo uso (se borra antes de usarse). Hoy contiene datos personales y el token de sesión del cliente (A-12); la propuesta es guardar `user_id` y **no** el token.

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `ticket` | string 32 `[A-Za-z0-9]` | Sí | Clave del ticket (`wp_generate_password(32)`); viaja en la URL. | WP | `<32 caracteres>` | SECRETO | Viaja (dentro de `checkoutUrl`) · No | RET-08 | `HO:234-235,380-384` |
| `iat` | integer epoch | Sí | Emisión; el ticket vence a los 60 s (+30 s de tolerancia). | WP | `1795000000` | INTERNO | No · No | RET-08 | `HO:215,392-393` |
| `items` | `[{id, quantity}]` | Sí | Carrito limpiado (máx. 100, cantidad 1–99). | WP | `[{"id":18345,"quantity":2}]` | INTERNO | No · No | RET-08 | `HO:152-173,216` |
| `email` | string | No | Correo para prellenar `billing_email`. En el flujo de la app: PROPUESTO no enviarlo. | WP | `cliente.demo@ejemplo.test` | PERSONAL | No · No | RET-08 | `HO:217`; `APIA` §13.1 |
| `billing` | composite (firstName, lastName, company, nationalId, address1, address2, department, city, postcode, phone) | No | Prellenado de facturación. En el flujo de la app: PROPUESTO no enviarlo (WooCommerce prellena desde la cuenta, RF-054; ver INC-05). | WP | (compuesto) | PERSONAL-ALTO | No · No | RET-08 | `HO:218,302-325` |
| `shipToDifferentAddress` | boolean | No | Envío a otra dirección. | WP | `false` | INTERNO | No · No | RET-08 | `HO:212,219` |
| `shipping` | composite (firstName, lastName, company, nationalId, address1, address2, department, city) | No | Dirección de envío independiente. | WP | (compuesto) | PERSONAL-ALTO | No · No | RET-08 | `HO:211,220,328-343` |
| `orderNotes` | string (texto libre) | No | Notas del pedido (`order_comments`). | WP | `Entregar en portería` | PERSONAL-ALTO | No · No | RET-08 | `HO:221-223,349-351` |
| `returnUrl` | URL http(s) de host en lista cerrada | No | A dónde volver tras crear el pedido. En la app la fija el servidor (`/app/pedido`, INC-15). | WP | `https://ejemplo.test/app/pedido` | INTERNO | No · No | RET-08 | `HO:122-149,224-226`; `APIA` §13.1 |
| `authToken` | string `[A-Za-z0-9_-]` | No | Token de sesión del cliente (hoy se guarda en el transient 60 s). **Se elimina en la propuesta** (se sustituye por `user_id`). | WP | `<token>` | SECRETO | No · No | RET-08 | `HO:229-231,263-273`; `AUTH` A-12 |
| `user_id` | BIGINT UNSIGNED | Sí (propuesto) | Usuario validado al emitir el ticket (sustituye a `authToken`). | WP | `1042` | PERSONAL | No · No | RET-08 | PROPUESTO: `APIA` §13.1, WP-06 (evita guardar tokens en BD temporal) |
| `checkoutRef` / `channel` | UUID / enum | Sí (propuesto) | Correlación y canal; se llevan a la sesión de WooCommerce y a los metadatos del pedido. | BFF | `…e1` / `app` | PERSONAL / INTERNO | No · No | RET-08 | PROPUESTO: `APIA` WP-06; `AUTH` §8.5 |

## E19 · SEDE — `EXISTENTE` (archivo compilado; fuente administrable `PROPUESTA`, ADR-018/WP-13)

32 entradas en `SE` (31 operativas + 1 "próximamente"), 10 ciudades. Son canales **corporativos** (RF-073, S-06); confirmar que ningún teléfono sea personal es **D-09** (si lo fuera, pasaría a `PERSONAL`, RNF-065). Sin coordenadas ni horarios (D-09, RF-077 fase 2).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `slug` | string | Sí | Identificador de la sede (ruta de la landing web). | WP (hoy `.ts`) | `ciudad-demo-sede-central` | PÚBLICO | Viaja · Hive cache | RET-11 | `SE:4`; `OAS` Store |
| `city` | string | Sí | Ciudad; agrupa el listado (RF-072). | WP | `Ciudad Demo` | PÚBLICO | Viaja · Hive cache | RET-11 | `SE:6` |
| `name` | string | Sí | Nombre propio de la sede. | WP | `Sede Central Demo` | PÚBLICO | Viaja · Hive cache | RET-11 | `SE:8` |
| `address` | string | Sí | Dirección del establecimiento (no es domicilio de una persona). | WP | `Calle 1 # 2-3` | PÚBLICO | Viaja · Hive cache | RET-11 | `SE:10` |
| `whatsapp` | string (dígitos nacionales) o null | Sí | WhatsApp corporativo (el mismo en todas las sedes hoy). | WP | `570000000000` | PÚBLICO | Viaja (`whatsapp.number`) · Hive cache | RET-11 | `SE:32`; `OAS` Store |
| `imageUrl` (`image`) | URI o null | Sí | Hoy ruta relativa `/sedes/…`; el contrato exige URL absoluta. | WP/DER | `https://ejemplo.test/sedes/central.jpg` | PÚBLICO | Viaja · caché de imágenes | RET-11 | `SE:34`; `OAS` Store; INC-20 |
| `upcoming` | boolean | Sí | Sede que aún no abre; sin teléfonos ni "Cómo llegar" (RF-072). | WP | `false` | PÚBLICO | Viaja · Hive cache | RET-11 | `SE:36` |
| `mapsQuery` | string o null | Sí | Texto de búsqueda de mapas derivado de la dirección (no es campo del código). | DER (BFF) | `Calle 1 # 2-3 Ciudad Demo` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` Store; `RF-075` |
| `coordinates` | siempre `null` en MVP | Sí | Fase 2 (RF-077). **DESCONOCIDO** el dato real (D-09: hoja maestra de Operaciones). | WP | `null` | PÚBLICO | Viaja · No | RET-11 | `OAS` Store; D-09 |
| `openingHours` | siempre `null` en MVP | Sí | Fase 2 (RF-077). **DESCONOCIDO** (D-09). | WP | `null` | PÚBLICO | Viaja · No | RET-11 | `OAS` Store; D-09 |

## E20 · TELEFONO_SEDE — `EXISTENTE` (columnas planas del código → lista tipada en el contrato)

En el código cada sede tiene columnas planas (`phone`, `celular`, `celularSecundario`, `ventaRepuestos`, `ventaAire`, cada una con su `…Tel`). El contrato las agrupa en `phones[]` (INC-20).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `type` | enum `landline`/`sales_parts`/`sales_ac`/`mobile` | Sí | `phone`→`landline`; `ventaRepuestos`→`sales_parts`; `ventaAire`→`sales_ac`; `celular` y `celularSecundario`→`mobile` (dos celulares colapsan en el mismo tipo). | DER (BFF) | `sales_parts` | PÚBLICO | Viaja · Hive cache | RET-11 | `SE:12-30`; `OAS` Store.phones |
| `display` | string | Sí | Teléfono en formato de visualización. | WP | `(600) 000 0000` | PÚBLICO (D-09) | Viaja · Hive cache | RET-11 | `SE:12-30`; `OAS` Store.phones |
| `dial` | string `^\+?\d{7,15}$` | Sí | Formato de marcación `tel:`. | WP | `+576000000000` | PÚBLICO (D-09) | Viaja · Hive cache | RET-11 | `SE:12-30`; `OAS` Store.phones |

## E21 · DIRECTORIO_CONTACTO (asesores y puntos de venta) — `EXISTENTE` en la web; **NO viaja a la app** (RF-102 Won't, RNF-065 = 0)

Datos personales de **empleados** publicados en la web (59 contactos según RF-102). Se documenta para dejar explícito qué **no** se replica; en la app se usan solo canales corporativos (E22, RF-095). No se reproduce ningún valor real.

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `name` | string | Sí | Nombre de la persona **o** del punto de venta. | WEB (`CD`) | `Persona Demo` | PERSONAL | No · No | RET-11 | `CD:1-5`; `RF-102` |
| `image` | ruta de imagen (foto/tarjeta con datos de contacto) | Sí | Foto o tarjeta del contacto; según INV F16 contiene correos y celulares de empleados. Contenido exacto de las imágenes: **DESCONOCIDO** (revisión manual). | WEB (`CD`) | `/directorio/persona-demo.jpg` | PERSONAL | No · No | RET-11 | `CD:1-5`; `RF-102` |
| `city` | string | Sí | Ciudad del directorio. | WEB (`CD`) | `Ciudad Demo` | PÚBLICO | No · No | RET-11 | `CD:8-16` |
| `banner` | ruta de imagen | Sí | Banner de la ciudad. | WEB (`CD`) | `/directorio/ciudad-demo.png` | PÚBLICO | No · No | RET-11 | `CD:8-16` |

## E22 · CONFIG_REMOTA_APP (`GET /config`) — `PROPUESTO` (ADR-018, WP-13; opción `ipr_mobile_config` en WordPress con respaldo empaquetado)

Efecto de un cambio ≤ 5 min (RNF-029). **Ningún dato personal de empleados** (RNF-065). Fuente parcialmente existente: `contact-links.ts` (WhatsApp, teléfono, correo de ventas).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `minSupportedVersion.android` / `.ios` | SemVer `^\d+\.\d+\.\d+$` | Sí | Por debajo → `426 app_version_unsupported`. | WP | `1.0.0` | INTERNO | Viaja · Hive cache | RET-10 | `OAS` AppConfig, PlatformVersions; RNF-029 |
| `recommendedVersion.android` / `.ios` | SemVer | Sí | Aviso suave de actualización. | WP | `1.2.0` | INTERNO | Viaja · Hive cache | RET-10 | `OAS` AppConfig |
| `features.checkoutEnabled` | boolean | Sí | Interruptor remoto del checkout (`503 feature_disabled`). | WP | `true` | INTERNO | Viaja · Hive cache | RET-10 | `OAS` AppConfig; RNF-029 |
| `features.pqrsEnabled` | boolean | Sí | Interruptor remoto de PQRS. | WP | `true` | INTERNO | Viaja · Hive cache | RET-10 | `OAS` AppConfig |
| `features.btuCalculatorEnabled` | boolean | Sí | Interruptor de la calculadora BTU (D-08). | WP | `true` | INTERNO | Viaja · Hive cache | RET-10 | `OAS` AppConfig |
| `contact.whatsapp.number` | string | Sí | Número corporativo de WhatsApp (`IPR_WHATSAPP`). | WP | `570000000000` | PÚBLICO | Viaja · Hive cache | RET-10 | `CL:6-8`; `OAS` AppConfig |
| `contact.whatsapp.defaultMessage` | string | Sí | Mensaje prellenado. | WP | `Hola, deseo atención` | PÚBLICO | Viaja · Hive cache | RET-10 | `CL:9-10`; `OAS` AppConfig |
| `contact.phone.display` / `.dial` | string | Sí | Línea única de atención. | WP | `(600) 000 0000` / `+576000000000` | PÚBLICO | Viaja · Hive cache | RET-10 | `CL:25-26`; `OAS` AppConfig |
| `contact.salesEmail` | email | Sí | Correo de ventas **institucional**. | WP | `ventas@ejemplo.test` | PÚBLICO | Viaja · Hive cache | RET-10 | `CL:29`; `OAS` AppConfig |
| `contact.pqrsEmail` | email | Sí | Buzón corporativo de PQRS (en el código viene de la variable de entorno `PQRS_EMAIL`; el valor no se copia aquí). | WP | `pqrs@ejemplo.test` | PÚBLICO | Viaja · Hive cache | RET-10 | `PQ:6`; `OAS` AppConfig |
| `contact.engineering.whatsapp` / `.email` | string o null | Sí | Canal corporativo de ingeniería. **DESCONOCIDO** si existe (PA-06). Nunca de una persona (RF-080). | WP | `null` | PÚBLICO | Viaja · Hive cache | RET-10 | `OAS` AppConfig; PA-06 |
| `legal.dataRightsChannel.url` / `.email` | URI/email o null | Sí | Canal para ejercer derechos del titular (RF-111). Canal vigente: **DESCONOCIDO** (D-12). | WP | `null` | PÚBLICO | Viaja · Hive cache | RET-10 | `OAS` AppConfig; RF-111 |
| `legal.accountDeletionNotice` | string | Sí | Qué se elimina y qué se conserva. Texto **pendiente de D-12**. | WP | `(texto aprobado por Jurídico)` | PÚBLICO | Viaja · Hive cache | RET-10 | `OAS` AppConfig; `APIA` §15.D paso 1 |
| `notices.shipping` / `.warranty` / `.priceOnRequest` | string | Sí | Avisos de envío, garantía y "precio por consultar" (textos legales: D-12). | WP | `(texto demo)` | PÚBLICO | Viaja · Hive cache | RET-10 | `OAS` AppConfig |
| `checkout.allowedHosts` | string[] | Sí | Hosts permitidos para `checkoutUrl`. | WP | `["ejemplo.test"]` | PÚBLICO | Viaja · Hive cache | RET-10 | `OAS` AppConfig; AC-052-13 |
| `checkout.returnPathPrefix` | string | Sí | Prefijo de la ruta de retorno (`/app/pedido` vs `/pedido-confirmado`, INC-15). | WP | `/app/pedido` | PÚBLICO | Viaja · Hive cache | RET-10 | `OAS` AppConfig |
| `catalog.pageSizes` | integer[] | Sí | `[12, 24, 48]`. | WP/BFF | `[12,24,48]` | PÚBLICO | Viaja · Hive cache | RET-10 | `OAS` AppConfig; `APIA` §7 |
| `catalog.maxPage` | integer | Sí | `50`. | WP/BFF | `50` | PÚBLICO | Viaja · Hive cache | RET-10 | `OAS` AppConfig |

## E23 · DOCUMENTO_LEGAL (términos y política de datos) — `PROPUESTO` como registro versionado

Texto de los documentos: **D-12** (PDF no leídos en discovery). La versión vigente es la que debe coincidir con `acceptance` en el registro (si no, `400 validation_failed`).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `document` | enum `terms`/`privacy_policy` | Sí | Clave del documento (coincide con `ipr_consents.document`). | WP | `privacy_policy` | PÚBLICO | Viaja (`legal.terms`, `legal.privacyPolicy`) · Hive cache | RET-11 | `OAS` AppConfig.legal; `AUTH` §8.4 |
| `version` | string ≤ 20 | Sí | Versión vigente. | WP | `2026-11-01` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` LegalDocument |
| `url` | URI | Sí | Enlace al documento completo (RNF-056: se abre completo). | WP | `https://ejemplo.test/legal/politica-datos.pdf` | PÚBLICO | Viaja · Hive cache | RET-11 | `OAS` LegalDocument |

## E24 · PQRS — `EXISTENTE` en la web (solo correo); contrato móvil `PROPUESTO`

**No se persiste en ninguna base**: se arma un correo HTML y se envía por SMTP al buzón corporativo (`PQ`). Tampoco se persiste ni se encola en la app (contiene PII, `FLU` §5.1, §9). Retención = la del buzón (**D-12**).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `type` (`tipo`) | enum `peticion`/`queja`/`reclamo`/`sugerencia` (en el código: "Petición", "Queja", …) | Sí | Tipo de solicitud. | APP | `reclamo` | INTERNO | Viaja · No | RET-12 | `PQ:23-25`; `OAS` PqrsRequest; INC-17 |
| `name` (`nombre`) | string 3–120 | Sí | Nombre del solicitante. | APP | `Ana Ejemplo` | PERSONAL | Viaja · No (formulario en memoria) | RET-12 | `PQ:26-28`; `OAS` PqrsRequest |
| `email` (`correo`) | email ≤ 254 | Sí | Correo para responder. | APP | `cliente.demo@ejemplo.test` | PERSONAL | Viaja · No | RET-12 | `PQ:29-31`; `OAS` PqrsRequest |
| `phone` (`telefono`) | string `^[\d\s+\-().]{7,20}$` | Sí en el esquema (la plantilla de correo lo trata como opcional) | Teléfono de contacto. | APP | `300 000 0000` | PERSONAL | Viaja · No | RET-12 | `PQ:32,58`; `OAS` PqrsRequest; INC-17 |
| `orderReference` (`pedido`) | string ≤ 60 | No | Número de pedido o factura (texto libre; no es clave foránea). | APP | `98001` | PERSONAL | Viaja · No | RET-12 | `PQ:33`; `OAS` PqrsRequest |
| `message` (`mensaje`) | string 1–1000 | Sí | Texto libre; puede contener cualquier dato personal. | APP | `Mensaje de prueba` | PERSONAL-ALTO | Viaja · No | RET-12 | `PQ:34-37`; `OAS` PqrsRequest |
| `acceptsDataPolicy` | boolean `true` | Sí (contrato) | Aceptación del tratamiento. **No existe en el código actual** y **no se persiste** (solo viaja): sin evidencia posterior de autorización (INC-18, DM-04). Texto a validar por Jurídico (D-12). | APP | `true` | INTERNO | Viaja · No | RET-12 | `OAS` PqrsRequest; `APIC` EP-27 (PROPUESTO) |
| `receivedAt` | datetime ISO 8601 con zona | Sí | Marca de tiempo de recepción (en el correo; respuesta `202`). | BFF | `2026-11-18T10:15:00-05:00` | INTERNO | Viaja · No | RET-12 | `PQ:98`; `APIC` EP-27 |
| `Idempotency-Key` | UUID v4 (cabecera) | No (recomendada) | Evita duplicados; el BFF la guarda 24 h en memoria. | APP | `00000000-0000-4000-8000-0000000000f1` | INTERNO | Viaja · No | RET-08 | `APIC` §1.6, EP-27 |

## E25 · SUSCRIPCION_NEWSLETTER — `EXISTENTE` en la web; **fuera del MVP** (RF-101 fase 2)

Igual que PQRS: no se persiste; cada alta se reenvía por SMTP al buzón corporativo para que Mercadeo la cargue (`NL`).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `email` | email ≤ 254 | Sí | Correo suscrito. | WEB | `cliente.demo@ejemplo.test` | PERSONAL | No · No | RET-12 | `NL:20-24` |
| `name` | string 1–120 | Sí | Nombre. | WEB | `Ana Ejemplo` | PERSONAL | No · No | RET-12 | `NL:25-29` |
| `consent` | boolean `true` | Sí | Aceptación de la política (solo se valida; no se guarda como prueba). | WEB | `true` | INTERNO | No · No | RET-12 | `NL:30` |

## E26 · RULETA_JUGADA (`{prefix}ipr_ruleta_jugadas`) — `EXISTENTE`; **fuera del MVP** (RF-103 Won't, RNF-065)

Campaña "Parche Midea X IPR". Tabla real con datos personales. Si la campaña entrara a la app, exige autorización y retención propias **antes** (RNF-065). Retención actual: **DESCONOCIDA** (`RET-13`, D-12).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | `bigint(20) unsigned` AUTO_INCREMENT · PK | Sí | Clave interna. | WP | `1` | INTERNO | No · No | RET-13 | `RM:118` |
| `factura` | `varchar(64)` | Sí | Número de factura tal como lo escribió la persona. | WP | `F-0001` | PERSONAL | No · No | RET-13 | `RM:119` |
| `factura_norm` | `varchar(64)` · UNIQUE | Sí | Factura normalizada (sin mayúsculas, espacios ni guiones): una jugada por factura. | WP | `F0001` | PERSONAL | No · No | RET-13 | `RM:120,130`; cabecera `RM:22-23` |
| `nombre` | `varchar(120)` | Sí | Nombre del participante. | WP | `Ana Ejemplo` | PERSONAL | No · No | RET-13 | `RM:121` |
| `documento` | `varchar(20)` | Sí | Documento de identidad. | WP | `123456789` | PERSONAL-ALTO | No · No | RET-13 | `RM:122` |
| `correo` | `varchar(120)` | Sí | Correo. | WP | `cliente.demo@ejemplo.test` | PERSONAL | No · No | RET-13 | `RM:123` |
| `celular` | `varchar(24)` | Sí | Celular. | WP | `300 000 0000` | PERSONAL | No · No | RET-13 | `RM:124` |
| `ciudad` | `varchar(80)` | Sí | Ciudad. | WP | `Ciudad Demo` | PERSONAL | No · No | RET-13 | `RM:125` |
| `resultado` | `varchar(10)` · defecto `perdio` | Sí | Resultado del sorteo (decide siempre el servidor). | WP | `perdio` | PERSONAL | No · No | RET-13 | `RM:126`; cabecera `RM:24` |
| `premio_id` | `bigint(20) unsigned` · nulo · KEY | No | Premio semanal asignado (E27). | WP | `NULL` | PERSONAL | No · No | RET-13 | `RM:127` |
| `creado` | `datetime` · defecto `CURRENT_TIMESTAMP` | Sí | Momento de la jugada. | WP | `2026-11-18 10:00:00` | PERSONAL | No · No | RET-13 | `RM:128` |

## E27 · RULETA_PREMIO_SEMANA (`{prefix}ipr_ruleta_premios`) — `EXISTENTE`; fuera del MVP

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | `bigint(20) unsigned` AUTO_INCREMENT · PK | Sí | Clave interna. | WP | `1` | INTERNO | No · No | RET-13 | `RM:108` |
| `semana_inicio` | `date` · UNIQUE | Sí | Lunes de la semana (zona del sitio). | WP | `2026-11-16` | INTERNO | No · No | RET-13 | `RM:109` |
| `cupos` | `smallint(5) unsigned` · defecto 3 | Sí | Cupos de premio de la semana. | WP | `3` | INTERNO | No · No | RET-13 | `RM:110` |
| `usados` | `smallint(5) unsigned` · defecto 0 | Sí | Cupos entregados (UPDATE atómico). | WP | `1` | INTERNO | No · No | RET-13 | `RM:111` |
| `creado` | `datetime` · defecto `CURRENT_TIMESTAMP` | Sí | Alta del registro. | WP | `2026-11-16 08:00:00` | INTERNO | No · No | RET-13 | `RM:112` |

## E28 · RASPA_PARTICIPACION (`{prefix}ipr_raspa_samsung_participaciones`) — `EXISTENTE` (solo si `IPR_RASPA_SAMSUNG_GUARDAR`); fuera del MVP

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | `bigint(20) unsigned` AUTO_INCREMENT · PK | Sí | Una fila = una oportunidad de raspar. | WP | `1` | INTERNO | No · No | RET-13 | `RS:154` |
| `documento` | `varchar(20)` · KEY `documento_usada` | Sí | Documento al que se liga la oportunidad. | WP | `123456789` | PERSONAL-ALTO | No · No | RET-13 | `RS:155` |
| `marca` | `varchar(40)` · defecto `Samsung` | Sí | Marca de la campaña. | WP | `Samsung` | INTERNO | No · No | RET-13 | `RS:156` |
| `usada` | `tinyint(1) unsigned` · defecto 0 | Sí | Oportunidad consumida. | WP | `0` | INTERNO | No · No | RET-13 | `RS:157` |
| `creado` | `datetime` · defecto `CURRENT_TIMESTAMP` | Sí | Alta. | WP | `2026-11-18 10:00:00` | INTERNO | No · No | RET-13 | `RS:158` |

## E29 · RASPA_PREMIO (`{prefix}ipr_raspa_samsung_premios`) — `EXISTENTE`; fuera del MVP

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | `bigint(20) unsigned` AUTO_INCREMENT · PK | Sí | Una fila = una unidad física de premio. | WP | `1` | INTERNO | No · No | RET-13 | `RS:165` |
| `marca` | `varchar(40)` · defecto `Samsung` | Sí | Marca. | WP | `Samsung` | INTERNO | No · No | RET-13 | `RS:166` |
| `codigo` | `varchar(40)` | Sí | Código del premio. | WP | `PREMIO-0001` | INTERNO | No · No | RET-13 | `RS:167` |
| `nombre_premio` | `varchar(120)` | Sí | Nombre del premio. | WP | `Premio demo` | INTERNO | No · No | RET-13 | `RS:168` |
| `probabilidad` | `smallint(5) unsigned` · defecto 1 | Sí | Peso del sorteo. | WP | `1` | INTERNO | No · No | RET-13 | `RS:169` |
| `asignado` | `tinyint(1) unsigned` · defecto 0 | Sí | Unidad ya asignada. | WP | `0` | INTERNO | No · No | RET-13 | `RS:170` |
| `creado` | `datetime` · defecto `CURRENT_TIMESTAMP` | Sí | Alta. | WP | `2026-11-18 10:00:00` | INTERNO | No · No | RET-13 | `RS:171` |

## E30 · RASPA_JUGADA (`{prefix}ipr_raspa_samsung_jugadas`) — `EXISTENTE`; fuera del MVP

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `id` | `bigint(20) unsigned` AUTO_INCREMENT · PK | Sí | Clave interna. | WP | `1` | INTERNO | No · No | RET-13 | `RS:177` |
| `participacion_id` | `bigint(20) unsigned` | Sí | Participación consumida (E28). | WP | `1` | INTERNO | No · No | RET-13 | `RS:178` |
| `documento` | `varchar(20)` · KEY | Sí | Documento de identidad. | WP | `123456789` | PERSONAL-ALTO | No · No | RET-13 | `RS:179` |
| `nombre` | `varchar(120)` | Sí | Nombre. | WP | `Ana Ejemplo` | PERSONAL | No · No | RET-13 | `RS:180` |
| `correo` | `varchar(120)` | Sí | Correo. | WP | `cliente.demo@ejemplo.test` | PERSONAL | No · No | RET-13 | `RS:181` |
| `celular` | `varchar(24)` | Sí | Celular. | WP | `300 000 0000` | PERSONAL | No · No | RET-13 | `RS:182` |
| `marca` | `varchar(40)` · defecto `Samsung` | Sí | Marca. | WP | `Samsung` | INTERNO | No · No | RET-13 | `RS:183` |
| `resultado` | `varchar(10)` · defecto `pierde` · KEY | Sí | Resultado del raspado. | WP | `pierde` | PERSONAL | No · No | RET-13 | `RS:184` |
| `premio_codigo` | `varchar(40)` · nulo | No | Código del premio ganado. | WP | `NULL` | PERSONAL | No · No | RET-13 | `RS:185` |
| `premio_nombre` | `varchar(120)` · nulo | No | Nombre del premio ganado. | WP | `NULL` | PERSONAL | No · No | RET-13 | `RS:186` |
| `creado` | `datetime` · defecto `CURRENT_TIMESTAMP` | Sí | Momento de la jugada. | WP | `2026-11-18 10:00:00` | PERSONAL | No · No | RET-13 | `RS:187` |

---

# PARTE II — BFF Next.js `/mobile/v1`

El BFF **no tiene base de datos propia ni persiste datos personales** (`APIA` §3.2 "No hace"). Solo mantiene estado efímero en memoria del proceso (un proceso Node, SA-01).

## E31 · REGISTRO_IDEMPOTENCIA — `PROPUESTO` (en memoria)

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `idempotencyKey` | UUID v4 | Sí | Clave enviada por la app (`Idempotency-Key`). | APP | `00000000-0000-4000-8000-0000000000f2` | INTERNO | Viaja (cabecera) · No | RET-08 | `APIC` §1.6 |
| `scopeRef` | string (usuario o dispositivo) + ruta | Sí | Ámbito de la clave: (usuario o dispositivo, ruta). | BFF | `user:1042 POST /checkout` | PERSONAL | No · No | RET-08 | `APIC` §1.6 |
| `requestFingerprint` | hash del cuerpo | Sí | Detecta "misma clave con cuerpo distinto" (`409 idempotency_conflict`). | BFF | (hash) | INTERNO | No · No | RET-08 | PROPUESTO: necesario para cumplir `APIC` §1.6 (409 por cuerpo distinto) |
| `responseSnapshot` | JSON | Sí | Respuesta guardada: 60 s en `/checkout` (incluye `checkoutUrl` con ticket), 24 h en `/pqrs`. | BFF | (JSON) | SECRETO (en `/checkout`) | No · No | RET-08 | `APIC` §1.6; `APIA` §9.2 |
| `expiresAt` | datetime | Sí | Vencimiento (60 s / 24 h). | BFF | `2026-11-18T10:16:00-05:00` | INTERNO | No · No | RET-08 | `APIC` §1.6 |

## E32 · CONTADOR_RATE_LIMIT_BFF — `EXISTENTE` (web) / `PROPUESTO` (LRU por clase, FE-05)

`Map` en memoria por proceso (`Bucket {count, resetAt}`); hoy se vacía entero al superar 5.000 claves (`RL:16-17,33-38`). La clave incluye la **IP en claro** (p. ej. `newsletter:<ip>`, `NL`).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `key` | string (`<ámbito>:<ip>` o `<ámbito>:<deviceId>`) | Sí | Clave de la ventana (IP real desde `CF-Connecting-IP` en la propuesta). | BFF | `pqrs:203.0.113.10` | PERSONAL | No · No | RET-08 | `RL:11-26`; `NL` (`rateLimit(\`newsletter:${clientIp}\`)`); `APIA` §10.3 |
| `count` | integer | Sí | Peticiones contadas en la ventana. | BFF | `3` | INTERNO | No · No | RET-08 | `RL:11-14` |
| `resetAt` | integer epoch ms | Sí | Fin de la ventana (fija). | BFF | `1795000600000` | INTERNO | No · No | RET-08 | `RL:11-14` |

## E33 · LOG_TECNICO_BFF — `PROPUESTO` (una línea JSON por solicitud, RNF-099)

Nunca se registra: `Authorization`, tokens, tickets, `checkoutUrl`, contraseñas, cuerpos de `/auth/*`, `/me/*` y `/pqrs`, correo, teléfono, cédula/NIT, direcciones, IP completa, texto de búsqueda completo (`APIA` §12). Prueba con valores canario (RNF-047).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `ts` | datetime ISO 8601 | Sí | Momento. | BFF | `2026-11-18T15:00:00Z` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `level` | enum | Sí | Nivel del log. | BFF | `info` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `requestId` | UUID v4 | Sí | `X-Request-Id`. | APP/BFF | `00000000-0000-4000-8000-0000000000b3` | INTERNO | Viaja (cabecera) · No | RET-07 | `APIA` §12 |
| `route` | string (plantilla, no URL real) | Sí | p. ej. `/mobile/v1/products/:slug`. | BFF | `/mobile/v1/products/:slug` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `method` | string | Sí | Método HTTP. | BFF | `GET` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `status` | integer | Sí | Código de respuesta. | BFF | `200` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `durationMs` | integer | Sí | Duración. | BFF | `42` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `cache` | enum `hit`/`miss`/`stale`/`edge` | Sí | Resultado de caché. | BFF | `hit` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `upstreamCalls` | integer | Sí | Llamadas a WordPress/WooCommerce. | BFF | `1` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `upstreamMs` | integer | Sí | Tiempo aguas arriba. | BFF | `30` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `rateLimited` | boolean | Sí | Si se limitó. | BFF | `false` | INTERNO | No · No | RET-07 | `APIA` §12 |
| `appVersion` | SemVer | Sí | `X-App-Version`. | APP | `1.0.0` | INTERNO | Viaja (cabecera) · No | RET-07 | `APIA` §12 |
| `platform` | enum `android`/`ios` | Sí | `X-App-Platform`. | APP | `android` | INTERNO | Viaja (cabecera) · No | RET-07 | `APIA` §12 |
| `userRef` | hex(16) = HMAC-SHA256(`user_id`) truncado | No | Seudónimo del usuario. | BFF | `a1b2c3d4e5f60718` | PERSONAL | No · No | RET-07 | `APIA` §12 |
| `deviceRef` | hex(16) = HMAC(`device_id`) truncado | No | Seudónimo del dispositivo. | BFF | `0f1e2d3c4b5a6978` | PERSONAL | No · No | RET-07 | `APIA` §12 |
| `ipPrefix` | string (/24 IPv4, /48 IPv6) | No | IP truncada. Se trata como `PERSONAL` por prudencia. | BFF | `203.0.113.0/24` | PERSONAL | No · No | RET-07 | `APIA` §12 |

## E34 · CACHE_CATALOGO_BFF (cachés SWR e índice de búsqueda en RAM) — `EXISTENTE`

Cachés `listings` (400 claves), `detail` (600), `by-ids` (50), `meta` (10), `meta-terms` (200) e **índice de hasta 10.000 productos** (renovado cada 5 min o por webhook). Solo contienen datos públicos del catálogo. Estado por proceso (`WCA` §5).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `cacheKey` | string | Sí | Clave por consulta (filtros, orden, página). Misma clave que la web si se usan los mismos `perPage`. | BFF | `listings:compresores:latest:1:24` | PÚBLICO | No · No | RET-08 | `WCA` §1.1, §5.4 |
| `value` | JSON (producto, lista, ficha, meta) | Sí | Dato normalizado de WooCommerce. Un error **nunca** se guarda. | BFF | (JSON) | PÚBLICO | No · No | RET-08 | `swr-cache.ts` (vía `WCA` §5.1) |
| `freshUntil` | epoch ms | Sí | Fin de frescura (5 min listados y fichas). | BFF | `1795000300000` | INTERNO | No · No | RET-08 | `WC:382-390`; `WCA` §5.1 |
| `staleUntil` | epoch ms | Sí | Vida máxima "stale" (24 h; 7 días meta). Un dato vencido se sirve con `X-IPR-Data-State: stale`. | BFF | `1795086400000` | INTERNO | No · No | RET-08 | `WCA` §5.1; `APIA` §6.3 |
| `errorCooldownUntil` | epoch ms | No | Enfriamiento por clave tras un fallo (10–120 s). | BFF | `1795000010000` | INTERNO | No · No | RET-08 | `WCA` §5.1 |
| `indexEntry` | Product normalizado + ~9 cadenas normalizadas (nombre, SKU, marca, categorías, etiquetas, atributos, descripción corta) | Sí | Entrada del índice de búsqueda. | BFF | (objeto) | PÚBLICO | No · No | RET-08 | `WCA` §1.1, §5.3 |
| `indexBuiltAt` | epoch ms | Sí | Momento de construcción; alerta si > 15 min (RNF-101). | BFF | `1795000000000` | INTERNO | No · No | RET-08 | `WCA` §1.1; `APIA` §12 |

---

# PARTE III — App móvil Flutter (todo `PROPUESTO`: la app no existe)

Reglas generales (`FLU` §8): tokens solo en Keystore/Keychain y memoria; **ninguna PII en preferencias, archivos o bases sin cifrar**; las cajas Hive no se cifran porque **no contienen PII**; perfil, direcciones y pedidos **solo memoria**; Android `allowBackup=false` o reglas de exclusión; iOS sin claves sincronizables con iCloud (RNF-035). Borrado al cerrar sesión y al eliminar cuenta: RNF-062.

## E35 · INSTALACION_APP — `PROPUESTO`

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `deviceId` | UUID v4 (`Random.secure`, sin datos de hardware) | Sí | Identifica la instalación; clave de la sesión por dispositivo. Se conserva al cerrar sesión; se regenera al eliminar cuenta y en reinstalación. | APP | `00000000-0000-4000-8000-0000000000d1` | PERSONAL | Viaja (`X-Device-Id`) · Secure storage | RET-14 | `AUTH` §4; `FLU` §8; `OV` T-11 |
| `appVersion` | SemVer | Sí | Versión instalada. | APP | `1.0.0` | INTERNO | Viaja (`X-App-Version`) · No (se lee del paquete) | RET-14 | `APIC` §1.1 |
| `platform` | enum `android`/`ios` | Sí | Plataforma. | APP | `android` | INTERNO | Viaja (`X-App-Platform`) · No | RET-14 | `APIC` §1.1 |
| `requestId` | UUID v4 | No | Generado por cada petición (`X-Request-Id`); no se guarda. | APP | `00000000-0000-4000-8000-0000000000b4` | INTERNO | Viaja · No | RET-08 | `APIC` §1.1; `FLU` §7.1 |

## E36 · TOKENS_LOCALES — `PROPUESTO`

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `accessToken` | `ipra_` + base64url(32 bytes) (48 caracteres) | Cond. (sesión activa) | Credencial de 15 min; solo cabecera `Authorization`. Memoria (secure storage solo si SPK-03 lo exige). | WP→APP | `ipra_<43 caracteres>` | SECRETO | Viaja (respuesta de login/refresh) · Memoria | RET-09 | `AUTH` §3.2, §5; `FLU` §8 |
| `accessTokenExpiresIn` | integer segundos (propuesto 900) | Cond. | Vida del access. | WP→APP | `900` | INTERNO | Viaja · Memoria | RET-09 | `OAS` Session |
| `refreshToken` | `iprr_` + base64url(32 bytes) | Cond. | Credencial rotativa de un solo uso; solo en cuerpo de `POST /auth/refresh`. | WP→APP | `iprr_<43 caracteres>` | SECRETO | Viaja · Secure storage (Keystore/Keychain) | RET-09 | `AUTH` §3.2, §5; `FLU` §8 |
| `refreshTokenExpiresAt` | datetime ISO 8601 | Cond. | Vencimiento por inactividad (acotado por la absoluta). | WP→APP | `2026-12-18T15:00:00Z` | INTERNO | Viaja · Memoria | RET-09 | `OAS` Session |
| `sessionId` | UUID v4 | Cond. | `session_uuid` (E04). | WP→APP | `00000000-0000-4000-8000-0000000000a1` | INTERNO | Viaja · Memoria | RET-09 | `OAS` Session |

## E37 · LINEA_CARRITO (carrito local, caja `cart`) — `PROPUESTO`

Fuente local de verdad **hasta el checkout**; límites 1–99 por línea y ≤ 100 líneas (`CS:77-93`, RF-049). La instantánea es solo visual y se reemplaza tras cada revalidación (N-05). Se conserva al cerrar sesión (PROPUESTA, DN-10/DA-09: sin PII). Precio y totales los decide el servidor.

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `productId` | integer > 0 | Sí | Producto (clave; no duplicado en el carrito). | APP | `18345` | PÚBLICO | Viaja (`CartItem.id`) · Hive cart | RET-10 | `FLU` §8, §11; `OAS` CartItem |
| `quantity` | integer 1–99 | Sí | Cantidad. | APP | `2` | PÚBLICO | Viaja · Hive cart | RET-10 | `FLU` §11; `CS:84-90` |
| `nameSnapshot` | string | No | Nombre mostrado (instantánea). | DER | `Válvula de expansión demo` | PÚBLICO | No · Hive cart | RET-10 | `FLU` §8 |
| `imageSnapshot` | URI o null | No | Imagen mostrada (instantánea). | DER | `https://ejemplo.test/uploads/valvula-demo.jpg` | PÚBLICO | No · Hive cart | RET-10 | `FLU` §8 |
| `priceSnapshot` | integer COP (`Money`) o null | No | Precio mostrado; **solo informativo**, nunca se envía al servidor. | DER | `1289500` | PÚBLICO | No · Hive cart | RET-10 | `FLU` §8, §11; `OV` §4 |

## E38 · CACHE_LOCAL (caja `cache`, LRU con tope) — `PROPUESTO`

Sin PII. Políticas (`FLU` §7.4): configuración remota (refresco > 5 min), categorías y marcas (fresco 1 h; stale hasta 7 d), listados (5 min; 24 h), fichas visitadas (tope ~200; 5 min; 24 h), sedes (24 h; 30 d). **Nunca** de caché: precios/stock para pagar; búsqueda y sugerencias solo memoria.

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `cacheKey` | string | Sí | Clave del recurso (ruta + parámetros canónicos). | APP | `GET /products?category=compresores&page=1&perPage=24` | PÚBLICO | No · Hive cache | RET-10 | `FLU` §7.4 |
| `payload` | JSON | Sí | Respuesta pública (DTO). Nunca respuestas `private, no-store`. | BFF→APP | (JSON) | PÚBLICO | Viaja · Hive cache | RET-10 | `FLU` §7.4; `APIA` §8.2 |
| `fetchedAt` | datetime | Sí | Momento de obtención; decide fresco/obsoleto. | APP | `2026-11-18T10:15:00-05:00` | INTERNO | No · Hive cache | RET-10 | `FLU` §7.4 |
| `etag` | string | No | `ETag` débil para `If-None-Match` (mejora opcional T-07). | BFF→APP | `W/"abc123"` | INTERNO | Viaja (cabecera) · Hive cache | RET-10 | `FLU` §7.4; `APIA` §8.1 |

## E39 · INTENTO_CHECKOUT_LOCAL (caja `cache`) — `PROPUESTO`

Sobrevive a que el SO mate la app mientras el usuario paga; al relanzar se reanuda en `verifying`. **Sin PII y sin la URL** (`FLU` §6.3, §8). Dos identificadores distintos: la clave de idempotencia (generada por la app, una por intento) y el `checkoutRef` (generado por el BFF, INC-22).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `attemptId` (= `checkoutRef`) | UUID v4 | Cond. (tras `201`) | Identificador del intento devuelto por el BFF. | BFF→APP | `00000000-0000-4000-8000-0000000000e1` | PERSONAL | Viaja · Hive cache | RET-09 | `FLU` §6.3, §8; `APIC` EP-23 |
| `idempotencyKey` | UUID v4 | Sí | Clave del intento (cabecera `Idempotency-Key`); intento nuevo = clave nueva. | APP | `00000000-0000-4000-8000-0000000000f3` | INTERNO | Viaja (cabecera) · Hive cache | RET-09 | `FLU` §6.3, §11 |
| `createdAt` | datetime | Sí | Marca de tiempo del intento. | APP | `2026-11-18T10:15:00-05:00` | INTERNO | No · Hive cache | RET-09 | `FLU` §8 |
| `state` | enum (`idle`, `revalidating`, `requestingTicket`, `openingBrowser`, `awaitingResult`, `verifying`, `paid`, `pending`, `failed`, `cancelled`, `noOrder`, `ticketExpired`) | Sí | Máquina de estados del `CheckoutController`. | APP | `awaitingResult` | INTERNO | No · Hive cache | RET-09 | `FLU` §6.3 |

## E40 · PREFERENCIAS_LOCALES (`shared_preferences`) — `PROPUESTO`

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `noticeSeen` | boolean o conjunto de ids | No | Avisos ya vistos. | APP | `true` | INTERNO | No · Prefs | RET-10 | `FLU` §8 |
| `lastTab` | string | No | Última pestaña abierta. | APP | `catalog` | INTERNO | No · Prefs | RET-10 | `FLU` §8 |
| `firstRunMarker` | boolean | Sí | Marca de primer arranque: si falta tras reinstalar en iOS, se limpia el secure storage antes de crear un `deviceId`. | APP | `true` | INTERNO | No · Prefs | RET-10 | `FLU` §8 (última línea); `AUTH` §4 |

## E41 · DATOS_PERSONALES_EN_MEMORIA (perfil, direcciones, pedidos) — `PROPUESTO`

No es una entidad de almacenamiento: son los DTO privados (`private, no-store`) que la app mantiene **solo en memoria** mientras hay sesión, y que borra al cerrar sesión o eliminar la cuenta (RNF-062, AC-044-9). Se ocultan en el selector de apps (Should, RNF-035).

| Campo | Tipo | Oblig. | Descripción | Origen | Ejemplo | Clasif. | App | Ret. | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| `profile` | `UserProfile` (E01 con `billing`/`shipping`) | Cond. | Perfil del usuario autenticado. | WP | (objeto) | PERSONAL | Viaja · Memoria | RET-09 | `FLU` §8; `OAS` UserProfile |
| `addresses` | `Address` ×2 (E02, incluye `nationalId`) | Cond. | Facturación y envío. | WP | (objeto) | PERSONAL-ALTO | Viaja · Memoria | RET-09 | `FLU` §8; `OAS` Address |
| `orders` | `OrderSummary[]` / `OrderDetail` (E15–E16) | Cond. | Historial y detalle. | WP | (lista) | PERSONAL | Viaja · Memoria | RET-09 | `FLU` §8; `OAS` OrderSummary |

---

# ANEXOS

## A.1 Equivalencias nombre del código ↔ nombre del contrato (base de los mapeadores)

Los mapeadores del BFF (`lib/mobile/dto.ts`, PROPUESTO) y de la app (`data/mappers/`) deben cubrir estas diferencias. Las diferencias de **significado** (no solo de nombre) están en `data_model.md` §11.

| Entidad | Nombre en el código / WordPress (HECHO) | Nombre en el contrato `/mobile/v1` | Observación | Evidencia |
|---|---|---|---|---|
| Login | `username` | `login` | Mismo contenido (correo o usuario). | `AU:119-123`; `OAS` LoginRequest (INC-01) |
| Registro | `first_name`, `last_name` | `firstName`, `lastName` | Además `acceptance` (nuevo). | `AU:125-134`; `OAS` RegisterRequest (INC-02) |
| Sesión | `{ token, user }` | `{ session{accessToken, refreshToken, …}, user }` | El contrato añade refresh y expiraciones. | `AR:130-132`; `OAS` AuthSessionResponse (INC-03) |
| Actualizar perfil | `first_name`, `last_name`, `current_password`, `billing{}`, `shipping{}` | `firstName`, `lastName`, `currentPassword`, `PUT /me/addresses/{type}` | El contrato separa correo, contraseña y direcciones en rutas propias. | `AR:274-368`; `OAS` UpdateProfileRequest |
| Dirección | `first_name`, `last_name`, `address_1`, `address_2`, `state`, `postcode`, `country`, `phone`, `email` | `firstName`, `lastName`, `address1`, `address2`, `department`, `postcode`, (país fijo), `phone`, — | `nationalId` solo en el contrato; `email` y `country` solo en WordPress. | `AR:335-336`; `HO:309-342`; `OAS` Address (INC-04) |
| Producto | `id: string`, `brand: string`, `category`, `imageUrl`, `inStock`, `formattedPrice`, `regularPrice` | `id: integer`, `brand{name,slug}`, `categorySlugs[]`, `image{url,alt,…}`, `availability`, `price{…}` | `formattedPrice` no viaja. | `MD:1-28`; `OAS` ProductSummary (INC-06…12) |
| Ficha | `description`, `shortDescription`, `gallery: string[]`, `stockQuantity`, `stockStatus` | `descriptionHtml`, `shortDescription`, `gallery: ImageRef[]`, — , `availability` | `stockQuantity` no viaja; HTML saneado. | `WC:239-248`; `OAS` ProductDetail |
| Pedido | `orderNumber`, `date`, `items[].qty` | `number`, `createdAt`, `items[].quantity` | El contrato añade `paymentState`, `itemCount`, totales y `productId`, `sku`, `imageUrl`. | `AR:255-266`; `OAS` OrderDetail (INC-13) |
| PQRS | `tipo`, `nombre`, `correo`, `telefono`, `pedido`, `mensaje` | `type`, `name`, `email`, `phone`, `orderReference`, `message` | Valores de `tipo`: "Petición" → `peticion`. `acceptsDataPolicy` nuevo. | `PQ:22-37`; `OAS` PqrsRequest (INC-17) |
| Sede | `phone`, `celular`, `celularSecundario`, `ventaRepuestos`, `ventaAire`, `image` | `phones[]{type,display,dial}`, `imageUrl` | Dos celulares → mismo tipo `mobile`. | `SE:2-37`; `OAS` Store (INC-20) |
| Marca | cadena canónica | `{ name, slug\|null }` | `slug` no lo produce `resolveBrand`. | `BR:60-92`; `OAS` BrandRef (INC-10) |

## A.2 Campos DESCONOCIDOS y cómo obtenerlos

| # | Dato desconocido | Entidad | Cómo obtenerlo | Quién |
|---|---|---|---|---|
| 1 | Columnas completas de `users`/`usermeta` y metadatos de WooCommerce usados por plugins | E01, E02 | Exportar esquema y lista de claves de `usermeta` desde *staging* (`SHOW COLUMNS`, `SELECT DISTINCT meta_key`); sin copiar valores. | Equipo web (D-16) |
| 2 | Clave de metadato de la cédula/NIT en el perfil (`billing_national_id` en checkout) y de `cedula_nit_ship` | E02 | Revisar la configuración de Checkout Field Editor y un pedido de prueba en *staging*. | Equipo web |
| 3 | Si las direcciones del perfil viven como `billing_*` (WooCommerce) o como el arreglo `billing` del snippet, o ambos | E02 | Crear un cliente de prueba en *staging*, guardar dirección por el snippet y por WooCommerce, y comparar `usermeta`. | Equipo web |
| 4 | Si el plugin de Wompi guarda tokens de medios de pago | E01 | Revisar el plugin y su documentación en *staging*. | Equipo web + Finanzas |
| 5 | Estados de pedido de plugins y estado tras fallo de pago; doble pedido por reintentos | E15, E17 | Pruebas con Wompi sandbox (D-02, PA-11, PA-12). | Equipo web |
| 6 | `alt`, `width`, `height` de imágenes y tamaños intermedios de WordPress | E14 | Ampliar `_fields` en *staging* y medir el efecto en la caché (DN-03, MED-07). | Equipo web |
| 7 | Número real de productos publicados y cuántos tienen precio 0 | E09 | Auditoría de catálogo (MED-06; RNF-106, 107, 110, 112). | Catálogo |
| 8 | Contenido de las imágenes del directorio (¿incluyen correo y celular?) | E21 | Revisión manual por Jurídico/Mercadeo. | Jurídico |
| 9 | Retención del buzón de PQRS y boletín; retención de datos de campañas | E24, E25, E26–E30 | Pregunta a Atención al cliente y a Mercadeo; política D-12. | Jurídico |
| 10 | Si `catalog_visibility` y productos con contraseña se usan en la tienda | E09 | Consulta en *staging* (`WCA` §4.2). | Catálogo |
| 11 | Canal corporativo de ingeniería y canal vigente de derechos del titular | E22 | PA-06; D-12. | Ingeniería, Jurídico |
| 12 | Coordenadas y horarios de sedes | E19 | Hoja maestra de Operaciones (D-09). | Operaciones |

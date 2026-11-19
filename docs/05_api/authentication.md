# Autenticación, sesiones por dispositivo y seguridad de cuenta — `/mobile/v1` + `ipr/v1`

| | |
|---|---|
| **Fase** | Tercera entrega — Arquitectura (lado servidor). **No se programa nada.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. Todo lo que no se marca HECHO es **PROPUESTA**. Las cifras (vidas de token, umbrales) son **objetivos propuestos** a aprobar (AP-02, DN-04). |
| **Relacionado** | [api_architecture.md](api_architecture.md) (§10 rate limiting, §15 flujos, ADR-013/011/012/018/019) · [api_contracts.md](api_contracts.md) · [openapi.yaml](openapi.yaml) |
| **Para el modelador de datos** | El esquema a nivel de campos está en **§8** (tablas `ipr_auth_sessions`, `ipr_auth_events`, `ipr_auth_throttle`, `ipr_consents` y metadatos nuevos). |

Abreviaturas: `auth-rest.php` = `ipr-frontend/wp-snippets/ipr-auth-rest.php`; `handoff.php` = `ipr-frontend/wp-snippets/ipr-cart-handoff.php`. Prefijo de tablas de WordPress: `{prefix}` (normalmente `wp_`; el real es **DESCONOCIDO** y no importa al diseño).

---

## 1. Estado actual (HECHOS)

| ID | Hecho | Evidencia | Problema para la app |
|---|---|---|---|
| A-01 | Un solo token por usuario: `ipr_auth_issue_token` sobrescribe `_ipr_auth_token_hash` y `_ipr_auth_token_exp`. | `auth-rest.php:45-50` | Login web cierra la app y viceversa; no hay multi-dispositivo (H-01). |
| A-02 | Vida fija de 30 días, sin refresh ni rotación. | `auth-rest.php:37`; `src/lib/session.ts:4` | Token largo expuesto; no hay renovación (H-02). |
| A-03 | El token se acepta por query `?token=`, por cuerpo o por `Authorization`. | `auth-rest.php:53-68` | Tokens en logs y proxies (H-03). |
| A-04 | Token de 40 caracteres de `wp_generate_password`, guardado como SHA-256; búsqueda por `get_users(meta_value)` sin índice propio. | `auth-rest.php:46-47`, `80-86` | Rendimiento con muchos usuarios (H-07). |
| A-05 | `permission_callback => '__return_true'` en todas las rutas; la autorización ocurre dentro del handler. | `auth-rest.php:372-411` | Un handler nuevo descuidado queda abierto (H-05). |
| A-06 | Login con `wp_signon` (respeta Wordfence), mensaje genérico "Usuario o contraseña incorrectos." | `auth-rest.php:168-175` | Correcto en el mensaje; sin límite propio (H-04). |
| A-07 | Registro con `wc_create_new_customer`, contraseña ≥ 8, sin verificación de correo, sin registro de aceptación de términos; revela si el correo existe. | `auth-rest.php:180-213`, `194`, `202-204` | H-06; RF-039 sin cubrir. |
| A-08 | El perfil devuelto incluye `roles`, `username` y **todos** los metadatos `billing`/`shipping`. | `auth-rest.php:104-120` | Exposición excesiva (API3). |
| A-09 | Cambio de correo o contraseña exige `current_password` y emite token nuevo (revoca el anterior). | `auth-rest.php:313-332` | Correcto (SEC-03 corregido), pero con token único "cierra todo" por accidente. |
| A-10 | Direcciones con lista blanca de campos por tipo. | `auth-rest.php:334-360` | Correcto; se reutiliza. |
| A-11 | Pedidos: `wc_get_orders(['customer_id' => $user->ID, 'limit' => -1])`. | `auth-rest.php:241-243` | Sin paginación; filtra por dueño (bien). |
| A-12 | El checkout lleva el token de sesión al transient del ticket y, al consumirlo, inicia sesión en WordPress con cookie persistente. | `handoff.php:229-235`, `263-273` | Token en BD temporal; cookie persistente en el navegador del sistema. |
| A-13 | La web guarda el token en cookie `httpOnly`, `sameSite=lax`, `secure` en producción. | `src/lib/session.ts:13-22` | Correcto para web; no aplica a móvil. |
| A-14 | No existen endpoints de refresh, revocación por dispositivo, recuperación de contraseña por API ni eliminación de cuenta. | Rutas de `auth-rest.php:372-411` | H-08. |

---

## 2. Requisitos que este diseño cubre

| Requisito | Cómo |
|---|---|
| RF-040, RF-038 | Login y registro móviles (§3, §10). |
| RF-041, RNF-040 | Revocación en servidor por sesión y global (§3.5). |
| RF-043, RNF-039 | Sesiones independientes por dispositivo y por canal (§3, §7). |
| RF-044, RNF-028 | Access corto + refresh rotativo; solo por `Authorization`; almacenamiento seguro (§3, §5). |
| RF-045, RNF-042 | Anti fuerza bruta compartido y persistente (§13). |
| RF-042 | Recuperación de contraseña (§11). |
| RF-048 | Bloqueo de roles administrativos en servidor (§3.7). |
| RF-104, RF-105 | Cambio de correo/contraseña con revocación (§6). |
| RF-110, RNF-058 | Eliminación de cuenta (§12). |
| RF-039, RNF-056 | Registro de aceptación de términos y política (§8.4, §10). |
| RNF-043 | Autorización por objeto (§14). |
| RNF-105 | Auditoría de eventos sensibles (§8.2). |

---

## 3. Modelo de sesión (PROPUESTA, ADR-013)

### 3.1 Conceptos

| Concepto | Definición |
|---|---|
| **Sesión** | Una fila de `ipr_auth_sessions`: un usuario en un dispositivo (o canal). Equivale a la "familia" de refresh tokens. |
| **Access token** | Credencial opaca de vida corta que la app envía en `Authorization: Bearer`. Una sola vigente por sesión. |
| **Refresh token** | Credencial opaca de un solo uso que permite obtener un nuevo par. Rota en cada uso. |
| **`deviceId`** | UUID v4 generado por la app en la instalación (§4). Identifica la instalación, **no** autentica. |
| **Canal** | `app_android`, `app_ios` o `web` (la web migraría en fase posterior, FE-18). |

### 3.2 Formato y generación de tokens

| Token | Formato | Entropía | Almacenamiento en servidor |
|---|---|---|---|
| Access | `ipra_` + base64url(32 bytes) (48 caracteres) | 256 bits de `random_bytes()` (CSPRNG de PHP) | `access_token_hash` = SHA-256 hex del token completo |
| Refresh | `iprr_` + base64url(32 bytes) | 256 bits | `refresh_token_hash` = SHA-256 hex |

- Los prefijos permiten que los escáneres de secretos los detecten en logs o repositorios y que el servidor rechace rápido un token del tipo equivocado.
- SHA-256 sin sal es adecuado porque el token tiene 256 bits aleatorios (no es atacable por diccionario) y permite búsqueda por índice único. Comparación final con `hash_equals`.
- Los tokens en claro solo existen en la respuesta de emisión y en el almacén seguro del dispositivo; nunca en BD, logs ni transients (corrige A-12).

### 3.3 Vidas (DECISIÓN PENDIENTE AP-02 / DN-04)

| Parámetro | Valor propuesto | Justificación |
|---|---|---|
| Vida del access token | **15 min** | Propuesto en COD §5.3 y RNF-039; acota el daño de un token robado y el retraso de una revocación "suave". |
| Inactividad máxima del refresh (`idle_expires_at`) | **30 días** desde la última renovación | Igual a la vida actual (no empeora la experiencia: quien abre la app al menos una vez al mes no vuelve a iniciar sesión). |
| Vida absoluta de la sesión (`absolute_expires_at`) | **90 días** desde el login | Obliga a reautenticar periódicamente; limita el valor de un refresh robado y no detectado. |
| Ventana de gracia de reintento de refresh | **30 s**, mismo `deviceId` | Cubre la pérdida de la respuesta del refresh por red móvil (§3.4). |
| Sesiones activas por usuario | **10** (se revoca la de uso más antiguo) | Evita crecimiento sin control; holgado para uso personal. |
| Escritura de `last_used_at` | Como máximo cada 5 min | Reduce escrituras en cada solicitud. |

### 3.4 Rotación del refresh y detección de reutilización

Algoritmo en `POST ipr/v1/m/sessions/refresh` (transacción InnoDB, `SELECT … FOR UPDATE` sobre la fila):

1. `h = sha256(refresh)`. Buscar sesión con `refresh_token_hash = h`.
2. **Encontrada:** verificar `revoked_at IS NULL`, `idle_expires_at > ahora`, `absolute_expires_at > ahora`, cuenta activa (§12) y rol permitido (§3.7). Verificar que `X-Device-Id` coincide con `device_id`; si no coincide → revocar la sesión (`reason = device_mismatch`), auditar y responder `401 refresh_token_reused`. Si todo está bien: generar par nuevo; `prev_refresh_token_hash = h`; `rotated_at = ahora`; `rotation_counter + 1`; `idle_expires_at = min(ahora + 30 d, absolute_expires_at)`; reemplazar `access_token_hash` y `access_expires_at`. Responder el par nuevo.
3. **No encontrada como vigente, pero `prev_refresh_token_hash = h`:**
   - Si `ahora − rotated_at ≤ 30 s` **y** el `deviceId` coincide → reintento legítimo (la respuesta anterior se perdió): emitir otro par nuevo (el par emitido en el paso 2 queda inválido) y mantener `prev_refresh_token_hash = h`.
   - En otro caso → **reutilización**: revocar la sesión (`reason = reuse_detected`), auditar con severidad alta, responder `401 refresh_token_reused`. La app borra sus tokens y pide login.
4. **No coincide con nada** → `401 unauthorized` sin revocar nada (evita que alguien que solo conoce un `session_uuid` pueda cerrar sesiones ajenas).

Requisito para el cliente (coordinación con el arquitecto Flutter): **una sola renovación en vuelo por sesión** (AC-044-6); si la renovación falla por red, no borrar tokens y reintentar con el mismo refresh (AC-044-7), lo que cae en la ventana de gracia.

### 3.5 Revocación

| Acción | Efecto | Dónde |
|---|---|---|
| Cerrar sesión (`scope = current`) | `revoked_at`, `reason = logout` en la sesión del access token presentado. | `POST /mobile/v1/auth/logout` |
| Cerrar todas (`scope = all`) | Revoca todas las sesiones del usuario **y** borra el token web heredado (`_ipr_auth_token_hash`). La web queda cerrada también: se informa en la app. | Mismo endpoint (RNF-040). Listar y cerrar dispositivos individualmente: fase 2 (RF-112). |
| Login en el mismo `deviceId` | Revoca la sesión anterior de ese dispositivo (`reason = replaced`). | Login |
| Superar 10 sesiones | Revoca la de `last_used_at` más antiguo (`reason = session_limit`). | Login |
| Cambio de contraseña o correo | Revoca **las demás** sesiones y el token web; rota la sesión actual (§6). | `/me/password`, `/me/email`, y `/auth/update` heredado (WP-05) |
| Restablecer contraseña (correo) o cambio desde wp-admin | Revoca **todas** las sesiones y el token web. | Hooks `after_password_reset`, `profile_update` (si cambió `user_pass`) |
| Eliminación de cuenta | Revoca todas; bloquea emisión de nuevas. | §12 |
| `delete_user` | Borra las filas de sesiones del usuario. | Hook |
| Rol pasa a administrativo | Las sesiones se rechazan en la siguiente validación (§3.7). | Validación |
| Limpieza | Tarea diaria (WP-Cron) borra sesiones con `absolute_expires_at` o `revoked_at` de hace > 30 días. | Cron |

Efecto: la revocación es **inmediata** porque cada solicitud autenticada valida el access token contra la tabla (ventaja de ADR-013 frente a JWT).

### 3.6 Validación de un access token (en `permission_callback` de `ipr/v1/m/*`)

1. Verificar `X-IPR-BFF-Secret` con `hash_equals` (ADR-014). Si falla → `401` (no se distingue del token inválido).
2. Extraer el token **solo** de `Authorization: Bearer` (nunca query ni cuerpo).
3. `SELECT` por `access_token_hash`; exigir `revoked_at IS NULL`, `access_expires_at > ahora`, `absolute_expires_at > ahora`.
4. Cargar el usuario; exigir cuenta activa (§12) y rol permitido (§3.7).
5. `wp_set_current_user($user_id)`; guardar `session_uuid` en el contexto de la petición para auditoría.
6. Cualquier fallo → `401` con `code = unauthorized` y el mismo mensaje (AC-044-8).

### 3.7 Roles permitidos (RF-048, DECISIÓN PENDIENTE AP-03 / PA-03)
Propuesta: denegar emisión y validación si el usuario tiene la capacidad `edit_posts` o `manage_woocommerce` (cubre administrador, editor, gestor de tienda, autor, y cuentas con varios roles, AC-048-4), con el mismo mensaje genérico de credenciales inválidas (AC-048-1). Lista configurable por filtro `ipr_mobile_denied_caps`. Basarse en capacidades y no en nombres de rol evita olvidar roles creados por plugins.

---

## 4. `deviceId`

| Aspecto | PROPUESTA |
|---|---|
| Generación | UUID v4 aleatorio en la primera ejecución. **No** se usa Android ID, IDFA/IDFV, IMEI ni huellas del hardware (minimización, RNF-060). |
| Almacenamiento | En el almacén seguro junto a los tokens. |
| Reinstalación | Nuevo `deviceId` (en iOS el Llavero sobrevive a la desinstalación: la app debe detectar la primera ejecución y borrar sus elementos del Llavero antes de crear un `deviceId` nuevo). |
| Transporte | Cabecera `X-Device-Id` en todas las solicitudes a `/mobile/v1`. |
| Uso | Clave de sesión por dispositivo, límites por dispositivo, correlación pseudonimizada en logs (HMAC). **No** es secreto ni prueba de identidad. |
| Etiqueta visible | `device_label` solo con plataforma y versión de SO (p. ej. "Android 14"), sin modelo ni nombre del dispositivo (el nombre suele contener el nombre de la persona). |

---

## 5. Almacenamiento en la app (requisitos para el arquitecto Flutter)

| Requisito | Detalle | Referencia |
|---|---|---|
| Almacén | Access, refresh y `deviceId` solo en Android Keystore (cifrado respaldado por hardware cuando exista) / iOS Keychain con accesibilidad "después del primer desbloqueo, solo este dispositivo". | RNF-034, AC-044-1 |
| Copias de seguridad | Excluidos de copias de seguridad de Android e iCloud. | RNF-035, AC-044-10 |
| Memoria | El access token puede mantenerse en memoria mientras la app está activa; nunca en preferencias, archivos, bases locales ni logs. | AC-044-9 |
| Cierre de sesión / eliminación | Borrar tokens, perfil, direcciones, pedidos en caché; conservar carrito según AC-041-7 (pendiente). | RNF-062 |
| Transporte | Solo `Authorization: Bearer`; refresh solo en el cuerpo de `POST /auth/refresh`. | RNF-041 |

---

## 6. Cambio de correo y de contraseña

| Paso | Cambio de contraseña (`POST /me/password`) | Cambio de correo (`POST /me/email`) |
|---|---|---|
| 1 | Access token válido. | Igual. |
| 2 | `currentPassword` verificada con `wp_check_password`; fallos cuentan en `sensitive_account` (5/h → `429`). | Igual. |
| 3 | `newPassword`: 8–128 caracteres, distinta de la actual y del correo. | `newEmail` válida, ≤ 120, no usada por otra cuenta (`409 email_in_use`). |
| 4 | `wp_update_user` (reutiliza `auth-rest.php:305-328`). | `wp_update_user`; WordPress notifica al correo **anterior** (comportamiento por defecto de `send_email_change_email`; confirmar que no esté desactivado). |
| 5 | Revocar **todas las demás** sesiones y el token web heredado; rotar la sesión actual. | Igual. |
| 6 | Responder `{session, user}` con el par nuevo. | Igual. |
| 7 | Auditar `password_changed`. | Auditar `email_changed` (sin guardar los correos en claro en el evento). |

Si el cambio se hace en la **web** (ruta heredada `/auth/update`, `auth-rest.php:313-332`), WP-05 añade la revocación de las sesiones de la app. Si se restablece por correo o desde wp-admin, se revocan **todas** (§3.5).

---

## 7. Convivencia web + app sin cierres mutuos

| Situación | Hoy (HECHO) | Propuesto |
|---|---|---|
| Login en la web | Sobrescribe el único token: cierra la app (A-01). | La web sigue usando `_ipr_auth_token_hash` (sin cambios de contrato); la app usa `ipr_auth_sessions`. Son almacenes distintos: **no se cierran mutuamente** (RF-043). |
| Login en la app | — | Crea sesión por dispositivo; no toca el token web. |
| Login en dos teléfonos | Imposible. | Dos sesiones (dos `deviceId`). |
| Cambio de contraseña en cualquiera | Emite token web nuevo y revoca el anterior. | Revoca las demás sesiones de app **y** el token web; la sesión donde se hizo el cambio sigue viva (rotada). |
| Validación de tokens | `ipr_auth_user_from_token` (meta). | Rutas heredadas: igual. Rutas `ipr/v1/m/*`: solo tabla de sesiones. El *handoff* acepta ambos (web: token heredado; app: access token). |
| Migración futura | — | FE-18 (P2): la web pasa a la tabla con canal `web`, cerrando H-01 también en la web. |

---

## 8. Esquema de datos en WordPress (para el modelador de datos)

Convenciones: motor InnoDB, `utf8mb4`, fechas `DATETIME` en **UTC**, creación con `dbDelta` desde el plugin/snippet, versión de esquema en la opción `ipr_auth_schema_version`. No se usan claves foráneas físicas (WordPress no las usa); la integridad con `{prefix}users` se mantiene con el hook `delete_user`. Clasificación de datos: **PII** = dato personal (Ley 1581); **SEC** = secreto o derivado de secreto; **PSEUDO** = pseudonimizado.

### 8.1 `{prefix}ipr_auth_sessions` — sesiones por dispositivo

| Campo | Tipo | Nulo | Defecto | Descripción | Índice | Clasif. |
|---|---|---|---|---|---|---|
| `id` | `BIGINT UNSIGNED AUTO_INCREMENT` | No | — | Clave interna. | PK | — |
| `session_uuid` | `CHAR(36)` | No | — | Identificador público de la sesión (logs, auditoría, futura lista de dispositivos). UUID v4. | `UNIQUE uq_session_uuid` | — |
| `user_id` | `BIGINT UNSIGNED` | No | — | Dueño de la sesión (`{prefix}users.ID`). | `idx_user_revoked (user_id, revoked_at)`; `idx_user_device (user_id, device_id)` | PII (indirecto) |
| `device_id` | `CHAR(36)` | No | — | UUID v4 de la instalación (§4). | ver `idx_user_device` | PII (indirecto) |
| `client_type` | `VARCHAR(16)` | No | — | `app_android` · `app_ios` · `web` (CHECK en aplicación). | — | — |
| `device_label` | `VARCHAR(80)` | Sí | `NULL` | Plataforma y versión de SO; sin modelo ni nombre del equipo. | — | — |
| `app_version` | `VARCHAR(20)` | Sí | `NULL` | Versión de la app al emitir/rotar. | — | — |
| `access_token_hash` | `CHAR(64)` | No | — | SHA-256 hex del access vigente. | `UNIQUE uq_access_hash` | SEC |
| `access_expires_at` | `DATETIME` | No | — | Vencimiento del access (emisión + 15 min). | — | — |
| `refresh_token_hash` | `CHAR(64)` | No | — | SHA-256 hex del refresh vigente. | `UNIQUE uq_refresh_hash` | SEC |
| `prev_refresh_token_hash` | `CHAR(64)` | Sí | `NULL` | Hash del refresh anterior (detección de reutilización y gracia). | `idx_prev_refresh` | SEC |
| `rotated_at` | `DATETIME` | Sí | `NULL` | Momento de la última rotación. | — | — |
| `rotation_counter` | `INT UNSIGNED` | No | `0` | Número de rotaciones (diagnóstico). | — | — |
| `idle_expires_at` | `DATETIME` | No | — | Vencimiento por inactividad del refresh (30 d, acotado por la absoluta). | — | — |
| `absolute_expires_at` | `DATETIME` | No | — | Vencimiento absoluto de la sesión (login + 90 d). | `idx_abs_exp` (limpieza) | — |
| `created_at` | `DATETIME` | No | — | Emisión (login o registro). | — | — |
| `last_used_at` | `DATETIME` | No | — | Último uso (escrito como máx. cada 5 min). | — | — |
| `revoked_at` | `DATETIME` | Sí | `NULL` | Momento de revocación; `NULL` = activa. | ver `idx_user_revoked` | — |
| `revoked_reason` | `VARCHAR(32)` | Sí | `NULL` | `logout` · `logout_all` · `replaced` · `session_limit` · `password_change` · `email_change` · `password_reset` · `reuse_detected` · `device_mismatch` · `account_deletion` · `admin` · `role_denied`. | — | — |

Reglas: una sesión activa por (`user_id`, `device_id`); máx. 10 activas por `user_id`; no se guarda IP en esta tabla (va a la auditoría con retención limitada). Retención: filas revocadas o vencidas se borran a los 30 días.

### 8.2 `{prefix}ipr_auth_events` — auditoría de seguridad (RNF-105)

| Campo | Tipo | Nulo | Defecto | Descripción | Índice | Clasif. |
|---|---|---|---|---|---|---|
| `id` | `BIGINT UNSIGNED AUTO_INCREMENT` | No | — | Clave interna. | PK | — |
| `occurred_at` | `DATETIME(3)` | No | — | Momento del evento (UTC, ms). | `idx_occurred (occurred_at)` | — |
| `event_type` | `VARCHAR(40)` | No | — | `login_succeeded`, `login_failed`, `login_denied_role`, `login_throttled`, `registered`, `refresh_reused`, `session_revoked`, `logout_all`, `password_changed`, `email_changed`, `password_reset_requested`, `password_reset_completed`, `deletion_requested`, `deletion_completed`, `checkout_ticket_issued`. | `idx_type_time (event_type, occurred_at)` | — |
| `outcome` | `VARCHAR(10)` | No | — | `success` · `failure`. | — | — |
| `user_id` | `BIGINT UNSIGNED` | Sí | `NULL` | Usuario si se conoce (`NULL` en login de cuenta inexistente). | `idx_user_time (user_id, occurred_at)` | PII (indirecto) |
| `session_uuid` | `CHAR(36)` | Sí | `NULL` | Sesión implicada. | — | — |
| `subject_hash` | `CHAR(64)` | Sí | `NULL` | HMAC-SHA256 (con secreto del servidor) del login/correo normalizado en intentos fallidos; permite correlacionar sin guardar el correo. | — | PSEUDO |
| `ip_address` | `VARBINARY(16)` | Sí | `NULL` | IP del cliente (`INET6_ATON`), recibida del BFF en `X-IPR-Client-IP`. | — | PII |
| `client_type` | `VARCHAR(16)` | Sí | `NULL` | Canal. | — | — |
| `request_id` | `CHAR(36)` | Sí | `NULL` | `X-IPR-Request-Id` para correlacionar con logs del BFF. | — | — |
| `reason_code` | `VARCHAR(40)` | Sí | `NULL` | Código de motivo (p. ej. `reuse_detected`). Nunca contraseñas, tokens ni correos. | — | — |

Retención propuesta: **90 días** (RNF-063); el registro mínimo de la eliminación de cuenta (`deletion_requested`/`deletion_completed`, sin PII salvo `user_id`) se conserva el tiempo que defina Jurídico (D-12).

### 8.3 `{prefix}ipr_auth_throttle` — contadores anti fuerza bruta (compartidos y persistentes)

| Campo | Tipo | Nulo | Defecto | Descripción | Índice | Clasif. |
|---|---|---|---|---|---|---|
| `id` | `BIGINT UNSIGNED AUTO_INCREMENT` | No | — | Clave interna. | PK | — |
| `scope` | `VARCHAR(24)` | No | — | `login_account`, `login_ip`, `register_ip`, `forgot_email`, `forgot_ip`, `sensitive_account`, `refresh_session`, `pqrs_ip` (si no hay regla en Cloudflare). | `UNIQUE uq_scope_subject (scope, subject_hash)` | — |
| `subject_hash` | `CHAR(64)` | No | — | HMAC-SHA256 del sujeto (login normalizado, correo, IP, `session_uuid`). No se guarda el valor en claro. | ver arriba | PSEUDO |
| `failures` | `INT UNSIGNED` | No | `0` | Intentos (fallidos o totales, según el `scope`) en la ventana. | — | — |
| `window_started_at` | `DATETIME` | No | — | Inicio de la ventana. | — | — |
| `locked_until` | `DATETIME` | Sí | `NULL` | Bloqueo vigente hasta. | — | — |
| `lock_level` | `TINYINT UNSIGNED` | No | `0` | Escalón del bloqueo progresivo (0..4). | — | — |
| `updated_at` | `DATETIME` | No | — | Último cambio. | `idx_updated` (limpieza) | — |

Operación atómica con `INSERT … ON DUPLICATE KEY UPDATE`. Limpieza: filas sin bloqueo y con `updated_at` > 24 h. Un login exitoso borra el contador `login_account` del sujeto (AC-045-8).

### 8.4 `{prefix}ipr_consents` — prueba de autorización (Ley 1581, RF-039, RNF-056)

| Campo | Tipo | Nulo | Defecto | Descripción | Índice | Clasif. |
|---|---|---|---|---|---|---|
| `id` | `BIGINT UNSIGNED AUTO_INCREMENT` | No | — | Clave interna. | PK | — |
| `user_id` | `BIGINT UNSIGNED` | No | — | Titular. | `idx_user_doc (user_id, document)` | PII (indirecto) |
| `document` | `VARCHAR(32)` | No | — | `terms` · `privacy_policy` (en fase 2: `marketing`, `push`). | ver arriba | — |
| `document_version` | `VARCHAR(20)` | No | — | Versión aceptada (la publica `GET /config`). | — | — |
| `action` | `VARCHAR(10)` | No | — | `accepted` · `revoked`. | — | — |
| `occurred_at` | `DATETIME` | No | — | Momento. | — | — |
| `client_type` | `VARCHAR(16)` | No | — | Canal (`app_android`, `app_ios`, `web`). | — | — |
| `app_version` | `VARCHAR(20)` | Sí | `NULL` | Versión de la app. | — | — |
| `request_id` | `CHAR(36)` | Sí | `NULL` | Correlación. | — | — |

Retención: mientras exista el tratamiento y el plazo que defina Jurídico tras la supresión (D-12). Se escribe en la misma transacción lógica que el alta.

### 8.5 Metadatos nuevos

| Entidad | Clave | Tipo de valor | Descripción |
|---|---|---|---|
| Usuario (`usermeta`) | `_ipr_account_state` | `active` · `pending_deletion` · `deleted` (ausente = `active`) | Bloquea login y validación si no es `active`. |
| Usuario | `_ipr_deletion_requested_at` | entero (epoch UTC) | Inicio de la solicitud de eliminación. |
| Usuario | `_ipr_deletion_request_id` | UUID | Id devuelto a la app (idempotencia) y enlazado a la solicitud de privacidad de WordPress. |
| Pedido (meta de WooCommerce, compatible con HPOS) | `_ipr_checkout_ref` | UUID | Correlación del intento de checkout de la app (ADR-017). |
| Pedido | `_ipr_channel` | `app` · `web` | Canal de origen (métricas, ADR-002). |
| Heredados que se mantienen | `_ipr_auth_token_hash`, `_ipr_auth_token_exp` | — | Sesión web actual (`auth-rest.php:47-48`). Se borran en revocación global y eliminación. |

---

## 9. Cambios en `ipr/v1` (WordPress) — rutas nuevas y modificadas

Todas las rutas nuevas viven bajo `ipr/v1/m/` y tienen `permission_callback` real (`ipr_m_permission_bff` para públicas del BFF; `ipr_m_permission_user` = secreto del BFF + access token, §3.6). Ninguna usa `__return_true`.

| Método y ruta (PROPUESTA) | Permiso | Reutiliza | Propósito |
|---|---|---|---|
| `POST ipr/v1/m/register` | BFF | `wc_create_new_customer` (`auth-rest.php:198`) | Alta + consentimientos + sesión. |
| `POST ipr/v1/m/sessions` | BFF | `wp_authenticate` (en lugar de `wp_signon`, para no crear cookies de WordPress en una llamada servidor-a-servidor) | Login → sesión por dispositivo. |
| `POST ipr/v1/m/sessions/refresh` | BFF | — | Rotación (§3.4). |
| `POST ipr/v1/m/sessions/revoke` | Usuario | — | `scope = current | all`. |
| `POST ipr/v1/m/password/forgot` | BFF | `retrieve_password()` | §11. |
| `GET ipr/v1/m/me` | Usuario | `ipr_auth_public_user` (con lista blanca nueva) | Perfil + direcciones. |
| `POST ipr/v1/m/me` | Usuario | `auth-rest.php:280-288` | Nombre y apellido. |
| `POST ipr/v1/m/me/email` | Usuario | `auth-rest.php:290-303`, `313-324` | §6. |
| `POST ipr/v1/m/me/password` | Usuario | `auth-rest.php:305-324` | §6. |
| `PUT ipr/v1/m/me/addresses/(?P<type>billing|shipping)` | Usuario | `auth-rest.php:334-360` | Dirección con lista blanca. |
| `POST ipr/v1/m/me/deletion` | Usuario | Herramientas de privacidad de WordPress | §12. |
| `GET ipr/v1/m/orders` | Usuario | `wc_get_orders` (`auth-rest.php:241-243`) con `paginate => true`, `limit` ≤ 20 y `checkout_ref` opcional | Lista paginada solo del usuario. |
| `GET ipr/v1/m/orders/(?P<id>\d+)` | Usuario | Mapeo de `auth-rest.php:245-266` | Detalle con control de propiedad (404 si no es suyo). |
| `POST ipr/v1/handoff-ticket` (modificada) | `X-IPR-Secret` (existente) | `handoff.php:193-241` | Acepta `accessToken` (app) además de `authToken` (web); guarda `user_id`, `checkoutRef`, `channel`; nunca el token. |
| `GET ipr/v1/m/stores`, `GET ipr/v1/m/config` | BFF | — | ADR-018 (P1). |
| Modificación de `ipr_auth_extract_token` | — | `auth-rest.php:53-68` | Solo cabecera `Authorization` (WP-04). |
| Modificación de `ipr_auth_handle_update` | — | `auth-rest.php:330-332` | Revocar sesiones de app ante cambio sensible (WP-05). |

Secreto del BFF: `IPR_BFF_SECRET` en `wp-config.php` (mismo patrón que `IPR_HANDOFF_SECRET`, `handoff.php:64-71`), distinto del de *handoff*, con soporte de dos valores durante la rotación (WP-16).

---

## 10. Registro

1. App → `POST /mobile/v1/auth/register` con `email`, `firstName`, `lastName`, `password` y `acceptance { termsVersion, privacyPolicyVersion, accepted: true }`. Las versiones deben coincidir con las vigentes de `GET /config`; si no, `400 validation_failed` (la app debe mostrar la versión vigente).
2. BFF: Zod `strict` (correo ≤ 120, nombres ≤ 60, contraseña 8–128), límite por IP y dispositivo.
3. WordPress: límite `register_ip`; `wc_create_new_customer` (rol `customer`); nombres; filas en `ipr_consents`; sesión por dispositivo; evento `registered`.
4. `201` con `{session, user}`.
5. Correo existente → `409 email_in_use` (riesgo RA-11 aceptado: el MVP no verifica correo; RF-046 en fase 2 permitiría una respuesta uniforme).
6. Verificación de correo antes de la primera compra: **DECISIÓN PENDIENTE** DN-12/PA-02 (fuera del MVP según RF-046).

---

## 11. Recuperación de contraseña (ADR-021)

1. App → `POST /mobile/v1/auth/password/forgot` con `{email}`.
2. BFF: límite por IP/dispositivo; reenvía a `ipr/v1/m/password/forgot`.
3. WordPress: límites `forgot_email` (3/h) y `forgot_ip` (10/h); si el usuario existe y está activo, `retrieve_password()` envía el correo estándar con el enlace a la página de restablecimiento de WordPress (accesible, no la redirige `ipr-front-redirect.php`, COD §2). Para evitar enumeración por tiempo de respuesta, el envío se programa como tarea asíncrona (`wp_schedule_single_event`) y la respuesta es siempre igual.
4. Respuesta **siempre** `202` con el mismo cuerpo (AC-045-5).
5. El usuario abre el enlace del correo en su navegador y restablece en WordPress. Hook `after_password_reset` → revoca **todas** las sesiones y el token web.
6. La app, al recibir `401` en su siguiente uso, pide login.

---

## 12. Eliminación de cuenta (Ley 1581, ADR-022)

> Insumo técnico, **no** asesoría jurídica. Qué se borra, qué se retiene, plazos y si los pedidos se anonimizan es **DECISIÓN PENDIENTE D-12 / PA-09 / DN-08** (Jurídico + Finanzas).

### 12.1 Flujo
1. `POST /mobile/v1/me/deletion` con `{currentPassword, confirm: true}`, `Authorization` e `Idempotency-Key`. Sin identificador de cuenta en el cuerpo (AC-110-13).
2. WordPress verifica la contraseña (cuenta en `sensitive_account`), y si ya existe una solicitud pendiente devuelve `202` con la misma `requestId`.
3. Marca `_ipr_account_state = pending_deletion` → login y validación de tokens fallan con mensajes genéricos (AC-110-5).
4. Revoca todas las sesiones y el token web; borra el carrito persistente de WooCommerce del usuario.
5. Crea la solicitud de privacidad de WordPress (`wp_create_user_request($email, 'remove_personal_data')`) marcada como confirmada, para trazabilidad en "Herramientas → Borrar datos personales".
6. Programa la anonimización (WP-Cron). Plazo propuesto: inmediata, y como máximo **15 días hábiles** (RNF-058). Si Jurídico prefiere un periodo de arrepentimiento, se fija aquí.
7. Correo de confirmación al titular; evento `deletion_requested`.
8. La app recibe `202 {requestId, status: "scheduled", completeBy}`, borra todo lo local y vuelve a modo visitante.

### 12.2 Qué se borra y qué se retiene (propuesta para validar)

| Dato | Dónde vive (HECHO/SUPUESTO) | Acción propuesta | Motivo / pendiente |
|---|---|---|---|
| Usuario, contraseña (hash), correo, nombre | `{prefix}users`, `usermeta` | **Eliminar** el usuario (`wp_delete_user` sin reasignar contenido) tras anonimizar lo vinculado. | Supresión (Ley 1581). |
| Direcciones de facturación y envío del perfil | `usermeta` `billing_*`/`shipping_*` | **Eliminar**. | — |
| Cédula/NIT guardada en el perfil | Meta del campo personalizado (clave exacta **DESCONOCIDA**, p. ej. `billing_national_id`) | **Eliminar**. | Confirmar clave en staging. |
| Sesiones y tokens | `ipr_auth_sessions`, metas `_ipr_auth_token_*` | **Eliminar**. | — |
| Contadores anti fuerza bruta | `ipr_auth_throttle` (pseudonimizados) | Caducan solos (≤ 24 h). | — |
| Carrito persistente / sesión de WooCommerce | `usermeta` `_woocommerce_persistent_cart_*`, tabla de sesiones de WC | **Eliminar**. | — |
| Medios de pago tokenizados (si Wompi los guarda) | Tokens de pago de WooCommerce | **Eliminar**. | Uso de tokenización: **DESCONOCIDO**. |
| **Pedidos** (productos, importes, fechas, datos de facturación y envío copiados en el pedido) | Pedidos de WooCommerce | **Conservar** por obligación contable y tributaria, **anonimizando lo que no sea exigible** (p. ej. teléfono, notas) y desvinculando el `customer_id`. Herramienta: el borrador de datos personales de WooCommerce (opción "eliminar datos personales de pedidos" en solicitudes de borrado). | **D-12**: plazo de conservación (referencias a validar por Jurídico: deber de conservar libros y papeles del comerciante y soportes de facturación; plazos de 5 a 10 años según la norma aplicable). Si la factura electrónica se emite fuera de WooCommerce: **DESCONOCIDO**. |
| Pedidos en curso (pendientes, en proceso) | Pedidos | Permitir la solicitud; el pedido se completa con sus datos; la anonimización del perfil procede. | **PA-09 / AC-110-8**: alternativa bloquear hasta cierre. |
| Consentimientos | `ipr_consents` | **Conservar** el registro mínimo como prueba de la autorización durante el plazo legal; luego eliminar. | D-12. |
| Auditoría de seguridad | `ipr_auth_events` | Conservar ≤ 90 días; el evento de supresión, lo que defina Jurídico. | RNF-063, AC-110-15. |
| PQRS enviadas | Buzón de correo corporativo (SMTP, `pqrs/route.ts:107-116`) | Fuera del sistema: aplicar la política de retención del buzón. | D-12. |
| Logs técnicos del BFF | Servidor Next | Solo contienen identificadores pseudonimizados; caducan a los 90 días. | RNF-047. |
| Datos locales del dispositivo | App | Borrado inmediato. | RNF-062. |
| Reutilizar el mismo correo para una cuenta nueva | — | Permitido tras completar la eliminación. | AC-110-6 pendiente. |

Comportamiento de WooCommerce con pedidos de un usuario eliminado (pasan a "invitado"): **SUPUESTO** a verificar en staging.

Para las tiendas: además del flujo en la app, Google Play exige un enlace web para solicitar la eliminación (S-05, verificar vigencia). Propuesta: página web que remite al canal de derechos del titular (RF-111) — no forma parte de `/mobile/v1`.

---

## 13. Anti fuerza bruta (RF-045, RNF-042)

| Superficie | Regla propuesta (punto de partida, calibrar con MED-10) | Capa |
|---|---|---|
| Login por cuenta | 5 fallos en 15 min → bloqueo progresivo de 1, 5, 15 y 60 min (escalones `lock_level`); éxito reinicia. | WordPress (`login_account`) |
| Login por IP | 20 fallos en 15 min → bloqueo 15 min. | WordPress (`login_ip`) + Cloudflare |
| Registro | 5 por IP por hora; 3 por dispositivo por hora. | WordPress + BFF |
| Recuperación | 3 por correo por hora; 10 por IP por hora; respuesta siempre `202`. | WordPress |
| Refresh | 30 por sesión por hora. | WordPress |
| Contraseña actual en cambios sensibles y eliminación | 5 fallos por hora por cuenta → `429`. | WordPress |
| Volumen general `/mobile/v1/auth/*` | 60/min por IP. | Cloudflare (si el plan lo permite) |

Reglas de respuesta:
- Credenciales incorrectas, cuenta inexistente, cuenta en eliminación y rol denegado → mismo `401 invalid_credentials`, mismo cuerpo y tiempo similar (AC-045-5, AC-048-1, AC-110-5). Para cuentas inexistentes se ejecuta igualmente una verificación de hash ficticia para igualar tiempos.
- Bloqueo → `429 rate_limited` con `Retry-After`; el mensaje no dice si la cuenta existe (AC-045-7). El bloqueo por cuenta se aplica también a cuentas inexistentes (por `subject_hash`), para no revelar existencia.
- Wordfence: seguirá actuando sobre `wp_authenticate`. Sus bloqueos pueden devolver errores propios: el endpoint los traduce a `429`/`401` uniformes. Configuración actual: **DESCONOCIDA** (MED-10).
- Sin CAPTCHA en el MVP (no hay forma estándar en app sin terceros); atestación de app en fase 2 (AP-09).

---

## 14. OWASP API Security Top 10 (2023) — aplicación a `/mobile/v1` y `ipr/v1/m/*`

| Riesgo | Dónde aplica | Controles (PROPUESTOS) | Prueba de verificación |
|---|---|---|---|
| **API1 BOLA / IDOR** | `/orders/{id}`, `/checkout/{ref}`, `/me*`, eliminación. | El servidor **nunca** acepta ids de usuario del cliente; `/me*` usa el usuario del token. Pedidos: `customer_id` del pedido = usuario autenticado, si no → `404` (no `403`, para no confirmar existencia). `checkoutRef` se busca **dentro** de los pedidos del usuario. | Matriz con dos cuentas de prueba: cada id/ref de A consultado con token de B → `404` (AC-055-5, AC-056-10). |
| **API2 Autenticación rota** | Login, refresh, tokens. | §3 y §13: tokens de 256 bits, hash en BD, rotación con detección de reutilización, solo cabecera, límites persistentes, mensajes uniformes, revocación inmediata. | Pruebas de AC-044, AC-045; tokens en URL → `400`. |
| **API3 Autorización a nivel de propiedad (exposición excesiva + mass assignment)** | Perfil, direcciones, productos, pedidos. | **Salida:** DTO por lista blanca — sin `roles`, `username`, metadatos crudos (`auth-rest.php:104-120`), `stockQuantity` (`wc.ts:1083`), IP del cliente o notas internas de pedidos. **Entrada:** esquemas Zod `strict` (rechazan campos extra: `role`, `user_id`, `price`, `customer_id`), y en WordPress listas blancas por campo (como `auth-rest.php:335-336`); correo/contraseña solo por sus endpoints con `currentPassword`. | Respuestas comparadas contra `openapi.yaml` (sin campos adicionales); envío de campos extra → `400`. |
| **API4 Consumo de recursos sin restricción** | Catálogo, búsqueda, sugerencias, pedidos, cuerpos. | Rate limit en tres capas; `perPage` fijo y `page ≤ 50`; `q` ≤ 120; carrito ≤ 100 líneas; cuerpo ≤ 32 KB; pedidos paginados (hoy `limit -1`, `auth-rest.php:242`); cola de `wcGet` acotada. | Pruebas de límites y de carga (RNF-014). |
| **API5 Autorización a nivel de función** | Rutas administrativas; webhook; *handoff*. | La app no tiene funciones administrativas; roles con `edit_posts`/`manage_woocommerce` no inician sesión en la app (§3.7). `handoff-ticket` y `ipr/v1/m/*` exigen secretos de servidor. `/api/revalidate` solo HMAC (FE-13). | Intento de llamar `ipr/v1/m/*` sin secreto → `401`; cuenta administrativa → `401`. |
| **API6 Acceso sin restricción a flujos de negocio sensibles** | Registro masivo, PQRS (spam al buzón), tickets de checkout, enumeración del catálogo. | Límites por IP/dispositivo/cuenta; `Idempotency-Key` en PQRS; ticket de un solo uso y 60 s; tope de páginas. Atestación de app (fase 2). | Simulación de abuso en staging. |
| **API7 SSRF** | Ninguna entrada del cliente se usa como URL de salida. La URL de retorno del checkout la fija el servidor (`checkout/route.ts:111`) y WordPress la valida (`handoff.php:131-149`). | Si en el futuro se añade proxy de imágenes, solo hacia hosts de una lista cerrada. | Revisión de código. |
| **API8 Configuración insegura** | Cabeceras, CORS, secretos en URL. | Sin CORS en `/mobile/v1`; cookies ignoradas; HSTS ya activo (`next.config.ts:374-382`); errores sin detalles internos; eliminar `?secret=` (`revalidate/route.ts:80-82`) y `?token=` (`auth-rest.php:54`); Cloudflare sin desafíos interactivos en `/mobile/v1` pero con WAF. | Escaneo de configuración; pruebas negativas. |
| **API9 Gestión de inventario inadecuada** | Versiones y superficies paralelas. | Versionado `/mobile/v1` con OpenAPI en CI; inventario de rutas `ipr/v1` heredadas, `ipr/v1/m/*`, y el *rewrite* público de `raspa-samsung` (`next.config.ts:321-335`); `robots.txt` excluye `/mobile/`; política de retiro de versiones (DN-14). | Revisión por versión (RNF-096). |
| **API10 Consumo inseguro de APIs** | Respuestas de WooCommerce/WordPress; Wompi. | Validar forma de las respuestas de `wc/v3` e `ipr/v1` antes de mapear (hoy `checkout/route.ts:157` valida el formato del ticket: replicar el patrón); timeouts en todas las llamadas (falta en `auth.ts:71-76`); no confiar en `status` de la URL de retorno; el estado del pago lo fija el plugin de Wompi en WooCommerce (verificar firma de su webhook: **DESCONOCIDO**, D-02). | Pruebas con respuestas malformadas (deben dar `502`, no `500` ni datos corruptos). |

---

## 15. Pruebas de seguridad mínimas antes del piloto

| # | Prueba | Resultado esperado |
|---|---|---|
| 1 | Login en web y luego en app (y al revés), y en dos teléfonos. | Ninguna sesión se cierra (RF-043). |
| 2 | Reutilizar un refresh ya rotado (fuera de 30 s). | `401 refresh_token_reused` y sesión revocada; evento auditado. |
| 3 | Perder la respuesta de un refresh y reintentar con el mismo token en < 30 s. | Nuevo par; sesión sigue viva. |
| 4 | Cambiar la contraseña en la app. | Las demás sesiones y la web reciben `401`; la actual sigue. |
| 5 | Restablecer contraseña por correo. | Todas las sesiones reciben `401`. |
| 6 | Token en `?token=` o `?access_token=`. | `400` en BFF; ignorado/rechazado en WordPress. |
| 7 | 6 contraseñas erróneas sobre una cuenta (existente e inexistente), alternando dos procesos o reiniciando el servidor. | `429` con `Retry-After` idéntico en ambos casos; el contador sobrevive al reinicio. |
| 8 | IDOR de pedidos y `checkoutRef` entre dos cuentas. | `404`. |
| 9 | Campos extra (`role`, `price`, `user_id`) en registro, perfil y checkout. | `400 validation_failed`. |
| 10 | Cuenta con rol administrativo. | `401 invalid_credentials`. |
| 11 | Eliminar cuenta y reutilizar sus tokens y credenciales. | `401` en todo. |
| 12 | Valores canario (correo, cédula, contraseña) en todos los flujos; revisar logs del BFF y WordPress. | 0 apariciones (RNF-047). |
| 13 | Llamar `ipr/v1/m/*` directamente sin `X-IPR-BFF-Secret`. | `401`. |

---

## 16. Decisiones pendientes y riesgos de este documento

| ID | Tema | Recomendación | Decide |
|---|---|---|---|
| AP-02 / DN-04 | Vidas de tokens, gracia, máx. sesiones (§3.3). | Aprobar valores propuestos. | TI + seguridad |
| AP-03 / PA-03 | Roles denegados (§3.7). | Denegar por capacidad `edit_posts`/`manage_woocommerce`. | Equipo web |
| D-12 / PA-09 / DN-08 | Tabla §12.2 (retención, pedidos en curso, reutilización de correo, periodo de arrepentimiento). | Validar con Jurídico y Finanzas. | Jurídico + Finanzas |
| DN-12 / PA-02 | Verificación de correo antes de comprar. | Fase 2 (RF-046). | Producto + seguridad |
| AC-041-7 | ¿El carrito se conserva al cerrar sesión explícitamente? | Conservar (no tiene PII). | Producto |
| AP-11 | Opción "cerrar todas" también cierra la web. | Sí, informándolo en la app. | Producto |

| ID | Riesgo | Mitigación |
|---|---|---|
| RS-01 | La ventana de gracia de 30 s permitiría usar un refresh robado durante ese intervalo si el atacante también envía el `deviceId` (no es secreto). | Ventana corta; auditoría de reintentos de gracia; reevaluar con atestación de app (fase 2). |
| RS-02 | Crear tablas en WordPress requiere acceso al hosting y un procedimiento de migración que no existe. | Plugin propio (`mu-plugin`) con `dbDelta` versionado y prueba en staging (C2). |
| RS-03 | Wordfence puede interferir con `wp_authenticate` llamado desde el servidor del BFF (todas las peticiones con la misma IP de origen). | Que WordPress use `X-IPR-Client-IP` (solo con secreto válido) para sus límites; revisar si Wordfence permite lista de confianza para la IP del BFF (MED-10). |
| RS-04 | Revelación de existencia de cuenta en el registro (RA-11). | Límites; verificación de correo en fase 2. |

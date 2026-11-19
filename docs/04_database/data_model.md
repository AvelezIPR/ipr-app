# Modelo de datos conceptual — App IPR (app Flutter + BFF `/mobile/v1` + WordPress/WooCommerce)

| | |
|---|---|
| **Proyecto** | App móvil Flutter de IPR Partes y Repuestos (Inverprimos S.A.S.), tienda HVAC-R en Colombia |
| **Fase** | Arquitectura (modelo de datos). **No se programa nada.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para revisión del arquitecto, del responsable técnico de `ipr-frontend`/WordPress y de Jurídico. Lo que depende de asesoría jurídica está marcado **DECISIÓN PENDIENTE D-12**. Este documento es insumo técnico, **no asesoría jurídica**. |
| **Documentos hermanos** | [data_dictionary.md](data_dictionary.md) (campo a campo, clasificación, retención) · [entity_relationship.md](entity_relationship.md) (diagrama ER nº 11 y parciales) |
| **Insumos** | [authentication.md](../05_api/authentication.md) (§8 importado sin cambios) · [api_architecture.md](../05_api/api_architecture.md) · [api_contracts.md](../05_api/api_contracts.md) · [openapi.yaml](../05_api/openapi.yaml) · [flutter_app_architecture.md](../03_architecture/flutter_app_architecture.md) · [architecture_overview.md](../03_architecture/architecture_overview.md) · [informe_codigo_frontend.md](../00_discovery/informe_codigo_frontend.md) · [analisis_capa_woocommerce.md](../00_discovery/analisis_capa_woocommerce.md) · RF/RNF · [architecture_decisions.md](../03_architecture/architecture_decisions.md) · [decisiones_pendientes.md](../project/decisiones_pendientes.md) · código de solo lectura de `ipr-frontend` |

> **No se abrió ni se leyó `.env`.** Ningún valor secreto aparece aquí. No hay datos personales reales (de clientes ni de empleados); los ejemplos del diccionario son sintéticos. El único dato de empleados mencionado es la **existencia** del directorio de contactos de la web, para dejar explícito que no se replica.

---

## 1. Propósito, convenciones y alcance

### 1.1 Etiquetas

| Etiqueta | Significado |
|---|---|
| **HECHO** | Comprobado en código o documento, con cita (`archivo:línea` o sección). |
| **EXISTENTE** | La entidad o el campo ya existe hoy (en WordPress/WooCommerce, en el sitio web o en el código de `ipr-frontend`). |
| **PROPUESTO** | No existe hoy; lo define un documento de arquitectura (`authentication.md`, `api_*`, `flutter_app_architecture.md`) o este documento, con justificación. |
| **SUPUESTO** | Premisa razonable no verificada; se indica cómo validarla. |
| **DECISIÓN PENDIENTE** | Requiere aprobación humana. `D-12` = revisión legal (Ley 1581); `DM-xx` = decisiones nuevas de este documento (§9.4). |
| **RIESGO** | Identificado con `RM-xx` (§9.5). |
| **DESCONOCIDO** | Sin evidencia; el diccionario (anexo A.2) dice cómo obtenerlo. |

Abreviaturas de evidencia: las del [diccionario §0.4](data_dictionary.md). Convenciones de datos heredadas de `authentication.md` §8: InnoDB, `utf8mb4`, fechas `DATETIME` en **UTC**, sin claves foráneas físicas (la integridad con `{prefix}users` se mantiene con el hook `delete_user`), esquema creado con `dbDelta` y versión en la opción `ipr_auth_schema_version`.

### 1.2 Alcance

- **Dentro:** las entidades del MVP (catálogo, cuenta, carrito local, checkout, pedidos, sedes, contacto, PQRS, configuración remota) y los datos técnicos que las soportan (sesiones, auditoría, anti fuerza bruta, consentimientos, cachés).
- **Documentado pero fuera del MVP:** directorio de contactos de empleados (RF-102 Won't), boletín (RF-101), campañas ruleta/raspa (RF-103). Se incluyen porque **ya almacenan o manejan datos personales** en el ecosistema.
- **Fuera:** favoritos, cotizaciones, B2B, notificaciones push (fase 2); datos de pago (no pasan por IPR ni por la app, RF-053; el cobro ocurre en Wompi dentro del checkout de WooCommerce).

---

## 2. Resumen ejecutivo

1. **Tres sistemas, una fuente de verdad por dato.** WordPress/WooCommerce es el sistema de registro de identidad, sesiones, direcciones, catálogo, precio, stock, pedido y consentimientos. El BFF **no persiste datos personales** (solo estado efímero en memoria). La app guarda lo mínimo: tokens y `deviceId` en almacén seguro, carrito y caché pública **sin PII** en Hive, y todo lo demás solo en memoria.
2. **41 entidades** (E01–E41): 30 en WordPress/WooCommerce y sitio web, 4 en el BFF y 7 en la app. 320 filas de diccionario (≈ 329 campos contando los agrupados). De ellas, **98 filas son datos personales** (87 `PERSONAL` y 11 `PERSONAL-ALTO`; una fila es mixta) y 13 son `SECRETO`.
3. **Lo nuevo es poco y está acotado:** 4 tablas de WordPress (`ipr_auth_sessions`, `ipr_auth_events`, `ipr_auth_throttle`, `ipr_consents`, esquema importado sin cambios de `authentication.md` §8), 5 metadatos (`_ipr_account_state`, `_ipr_deletion_requested_at`, `_ipr_deletion_request_id`, `_ipr_checkout_ref`, `_ipr_channel`) y el registro de configuración remota. Todo lo demás reutiliza modelos existentes con un DTO por lista blanca.
4. **El precio nunca lo decide la app** ni el BFF: WooCommerce calcula precio, impuestos, envío, stock y total; la app solo envía `{id, quantity}` y el estado del pago se consulta al servidor por `checkoutRef` (§8).
5. **Datos personales de riesgo alto** hoy: cédula/NIT (no se persiste en el perfil, pero se copia al pedido y viaja en el ticket de 60 s), copia de facturación del pedido, notas de pedido, texto libre de PQRS, y documento/correo/celular de las campañas.
6. **Retención:** definida solo para sesiones (30 días tras revocar), auditoría (90 días), contadores (24 h) y logs (≤ 90 días). **Todo lo demás depende de D-12**: pedidos y soportes fiscales, consentimientos, PQRS/boletín/campañas y registro de eliminación.
7. **28 inconsistencias** entre documentos y código (§11). Las que más afectan el diseño: almacenamiento de direcciones (`billing` como arreglo frente a `billing_*`), ruta de retorno del pago (`/app/pedido` frente a `/pedido-confirmado`), forma de pedido y producto entre código y contrato, consentimiento de PQRS inexistente en el código, y regla de roles bloqueados.

---

## 3. Sistemas de registro y fuente de verdad

### 3.1 Mapa de dominios de datos

| Dominio de datos | Sistema de registro (fuente de verdad) | Réplicas y vistas derivadas | Quién escribe | Estado |
|---|---|---|---|---|
| Identidad, credenciales, perfil | **WordPress** (`users`, `usermeta`) | DTO `UserProfile` solo en memoria de la app | WordPress vía `ipr/v1` | EXISTENTE (DTO PROPUESTO) |
| Direcciones de facturación y envío | **WordPress** (metadatos de usuario) | Memoria de la app | WordPress | EXISTENTE (almacenamiento por verificar, INC-05) |
| Sesiones por dispositivo | **WordPress** (`ipr_auth_sessions`) | Tokens en la app (secure storage + memoria) | WordPress | PROPUESTO |
| Sesión web heredada | **WordPress** (`usermeta` `_ipr_auth_token_*`) | Cookie `ipr_session` (solo web) | WordPress | EXISTENTE |
| Auditoría, anti fuerza bruta, consentimientos | **WordPress** (tablas nuevas) | — | WordPress | PROPUESTO |
| Catálogo: producto, categoría, marca, etiqueta, atributo, imagen | **WooCommerce** (`wc/v3`, `wp/v2/product_brand`) | Cachés SWR e índice de búsqueda del BFF; caché Hive de la app | Personal de catálogo en WordPress | EXISTENTE |
| Precio, impuestos, envío, descuentos, stock, cobro | **WooCommerce** (+ **Wompi** para el cobro) | `price`/`availability` derivados en el DTO | WooCommerce | EXISTENTE |
| Pedido y líneas | **WooCommerce** | DTO `OrderSummary`/`OrderDetail` en memoria de la app | WooCommerce al crear el pedido | EXISTENTE (metadatos PROPUESTOS) |
| Estado del pago | **Wompi → WooCommerce** (mecanismo de confirmación, p. ej. webhook, **DESCONOCIDO**, D-02) | `paymentState` derivado | Plugin de Wompi | EXISTENTE (detalle DESCONOCIDO) |
| Intento de checkout (`checkoutRef`) | **BFF genera**; **WordPress guarda** en sesión de WooCommerce y en `_ipr_checkout_ref` del pedido | Estado local en la app (sin PII) | BFF / WordPress | PROPUESTO |
| Carrito | **App** (hasta el checkout); luego WooCommerce toma `items` del ticket | Carrito persistente de WooCommerce (solo si la sesión web lo usa) | App | EXISTENTE (web) / PROPUESTO (app) |
| Sedes | Hoy archivo compilado `sedes-data.ts` en `ipr-frontend`; **PROPUESTO**: WordPress | Caché del BFF (1 h), caché Hive (24 h) | Desarrollo (hoy) / Operaciones (propuesto) | EXISTENTE → PROPUESTO |
| Canales corporativos de contacto | Hoy `contact-links.ts`; **PROPUESTO**: opción en WordPress | Idem | Idem | EXISTENTE → PROPUESTO |
| Configuración remota (versión mínima, interruptores, textos legales) | **PROPUESTO**: opción `ipr_mobile_config` en WordPress con respaldo empaquetado | BFF 60 s; app cada 5 min | Operaciones/TI | PROPUESTO |
| PQRS | **Buzón de correo corporativo** (SMTP); no hay base de datos | — | BFF (envío) | EXISTENTE (web) |
| Boletín | Buzón de correo (Mercadeo carga la lista a mano) | — | Sitio web | EXISTENTE; fuera del MVP |
| Directorio de asesores | Archivo compilado `contacto-data.ts` + imágenes | — | Desarrollo | EXISTENTE; **no va a la app** |
| Campañas (ruleta Midea, raspa Samsung) | **WordPress** (tablas propias de cada snippet) | — | Snippets de campaña | EXISTENTE; fuera del MVP |
| `deviceId` | **App** (lo genera); WordPress lo guarda en la sesión | — | App | PROPUESTO |
| Idempotencia, rate limit de lectura, logs técnicos | **BFF** (memoria del proceso / logs) | — | BFF | PROPUESTO (rate limit web: EXISTENTE) |

### 3.2 Principios de datos aplicados

| # | Principio | Consecuencia en el modelo | Fuente |
|---|---|---|---|
| P1 | El servidor es la autoridad comercial. | Ningún campo de precio, total, impuesto o disponibilidad nace en la app; los de la app son `priceSnapshot` solo visual. | `OV` P1, §4 |
| P5 | Nada sensible en el dispositivo salvo lo imprescindible, y cifrado. | Solo `refreshToken` y `deviceId` en secure storage; `accessToken`, perfil, direcciones y pedidos solo en memoria; cajas Hive sin PII. | `OV` P5; `FLU` §8 |
| P7 | Compatibilidad hacia adelante. | La app ignora campos desconocidos; enums de contrato extensibles. | `OV` P7; `APIA` §5 |
| P9 | Observabilidad sin PII. | Logs con `userRef`/`deviceRef` seudónimos e IP truncada; nunca tokens, correos ni cédulas. | `OV` P9; `APIA` §12 |
| M1 | Una sola fuente de verdad por dato; todo lo demás es caché con TTL. | Cada entidad del §4 declara su fuente; las cachés (E34, E38) son derivadas y desechables. | Este documento |
| M2 | Minimización: el DTO móvil es lista blanca, no un espejo de WordPress/WooCommerce. | Sin `roles`, `username`, `stockQuantity`, metadatos crudos, IP, notas internas, datos de pago. | `AUTH` §14 API3; RNF-060 |

---

## 4. Inventario de entidades

Estado: `EX` = EXISTENTE · `PR` = PROPUESTO · `MX` = mixto. `DP` = contiene datos personales (`S` sí, `N` no). Detalle campo a campo en el [diccionario](data_dictionary.md).

| ID | Entidad | Sistema de registro | Ubicación física | Estado | DP | Viaja a la app | Persiste en la app | Evidencia principal |
|---|---|---|---|---|---|---|---|---|
| E01 | Usuario / Cliente | WordPress | `users`, `usermeta`, cliente WooCommerce | EX | S | Sí (DTO sin `roles` ni `username`) | Memoria | `AR:105-120` |
| E02 | Dirección (facturación, envío) | WordPress | Metadatos `billing`/`shipping` (arreglo) y/o `billing_*` (INC-05) | EX | S | Sí | Memoria | `AR:106-107,335-360` |
| E03 | Token web heredado | WordPress | `usermeta` `_ipr_auth_token_*`; cookie `ipr_session` | EX | S | No | No | `AR:45-50`; `SS` |
| E04 | Sesión de dispositivo | WordPress | `{prefix}ipr_auth_sessions` | PR | S | Parcial (`sessionId`, expiraciones) | Memoria / secure storage | `AUTH` §8.1 |
| E05 | Evento de auditoría | WordPress | `{prefix}ipr_auth_events` | PR | S | No | No | `AUTH` §8.2 |
| E06 | Contador anti fuerza bruta | WordPress | `{prefix}ipr_auth_throttle` | PR | S (seudónimo) | No | No | `AUTH` §8.3 |
| E07 | Consentimiento | WordPress | `{prefix}ipr_consents` | PR | S | Solo versiones al registrar | No | `AUTH` §8.4 |
| E08 | Solicitud de eliminación | WordPress | `usermeta` + solicitud de privacidad de WP | PR | S | `requestId`, `status`, `completeBy` | No | `AUTH` §8.5, §12 |
| E09 | Producto | WooCommerce | `wc/v3/products` | EX | N | Sí (DTO) | Hive cache; instantánea en carrito | `WC:213-231` |
| E10 | Atributo de producto | WooCommerce | `wc/v3` (atributos `pa_*`) | EX | N | Sí | Hive cache | `WC:206-211` |
| E11 | Categoría | WooCommerce | `wc/v3/products/categories` | EX | N | Sí (árbol) | Hive cache | `OAS` Category |
| E12 | Marca | WooCommerce + registros del sitio | `product_brand`; `BRAND_LANDINGS`; `BRANDS`; `BRAND_LOGOS` | EX | N | Sí | Hive cache | `BR`; `WCA` §6 |
| E13 | Etiqueta | WooCommerce | `wc/v3` (tags) | EX | N | Parcial (filtro) | No | `WC:230` |
| E14 | Imagen | WooCommerce / medios de WordPress | `images[].src` | EX | N | Sí | Caché de imágenes | `WC:228` |
| E15 | Pedido | WooCommerce | `WC_Order` (HPOS compatible) | EX (metas PR) | S | Sí (DTO) | Memoria | `AR:235-272` |
| E16 | Línea de pedido | WooCommerce | Ítems del pedido | EX | S | Sí | Memoria | `AR:248-253` |
| E17 | Intento de checkout (`checkoutRef`) | BFF genera / WordPress guarda | Sesión de WooCommerce + `_ipr_checkout_ref` | PR | S (indirecto) | Sí | Hive cache (id y estado) | `APIC` EP-23/24 |
| E18 | Ticket de handoff | WordPress | transient `ipr_handoff_<ticket>` (60 s) | EX (cambios PR) | S | Solo dentro de `checkoutUrl` | No | `HO:193-258` |
| E19 | Sede | Hoy archivo `.ts`; PROPUESTO WordPress | `sedes-data.ts` → tipo de contenido (WP-13) | EX→PR | N | Sí | Hive cache | `SE:2-37` |
| E20 | Teléfono de sede | Ídem | Columnas planas → `phones[]` | EX | N (D-09) | Sí | Hive cache | `SE:12-30` |
| E21 | Directorio de contactos | Sitio web | `contacto-data.ts` + `/public/directorio` | EX | **S (empleados)** | **No** | No | `CD`; RF-102 |
| E22 | Configuración remota | PROPUESTO WordPress | Opción `ipr_mobile_config` | PR | N | Sí | Hive cache | `OAS` AppConfig |
| E23 | Documento legal | PROPUESTO WordPress | Dentro de `ipr_mobile_config` | PR | N | Sí | Hive cache | `OAS` LegalDocument |
| E24 | PQRS | Buzón corporativo | Correo SMTP (sin BD) | EX (web) | S | Solo envío | No | `PQ` |
| E25 | Suscripción a boletín | Buzón corporativo | Correo SMTP (sin BD) | EX (web) | S | No | No | `NL` |
| E26 | Jugada de ruleta | WordPress | `{prefix}ipr_ruleta_jugadas` | EX | S | No | No | `RM:117-131` |
| E27 | Premio semanal de ruleta | WordPress | `{prefix}ipr_ruleta_premios` | EX | N | No | No | `RM:107-115` |
| E28 | Participación de raspa | WordPress | `{prefix}ipr_raspa_samsung_participaciones` | EX | S | No | No | `RS:153-161` |
| E29 | Premio de raspa | WordPress | `{prefix}ipr_raspa_samsung_premios` | EX | N | No | No | `RS:164-174` |
| E30 | Jugada de raspa | WordPress | `{prefix}ipr_raspa_samsung_jugadas` | EX | S | No | No | `RS:176-191` |
| E31 | Registro de idempotencia | BFF | Memoria del proceso | PR | S (seudónimo) | Cabecera | No | `APIC` §1.6 |
| E32 | Contador de rate limit del BFF | BFF | `Map` en memoria | EX (web) / PR (LRU) | S (IP en clave) | No | No | `RL` |
| E33 | Log técnico del BFF | BFF | Logs JSON | PR | S (seudónimos) | No | No | `APIA` §12 |
| E34 | Caché del catálogo e índice de búsqueda | BFF | Memoria del proceso | EX | N | No | No | `WCA` §5 |
| E35 | Instalación de la app (`deviceId`) | App | Secure storage | PR | S | `X-Device-Id` | Secure storage | `AUTH` §4; `FLU` §8 |
| E36 | Tokens locales | App | Memoria (access) y secure storage (refresh) | PR | S (secreto) | Respuesta de login/refresh | Memoria / secure storage | `AUTH` §5 |
| E37 | Línea de carrito local | App | Hive `cart` | PR | N | `items` en solicitudes | Hive cart | `FLU` §8, §11 |
| E38 | Caché local | App | Hive `cache` | PR | N | Respuestas públicas | Hive cache | `FLU` §7.4 |
| E39 | Intento de checkout local | App | Hive `cache` | PR | S (indirecto) | `checkoutRef` | Hive cache | `FLU` §6.3, §8 |
| E40 | Preferencias locales | App | `shared_preferences` | PR | N | No | Prefs | `FLU` §8 |
| E41 | Datos personales en memoria | App | RAM | PR | S | Sí | Solo memoria | `FLU` §8 |

---

## 5. Qué vive en cada sistema

### 5.1 WordPress / WooCommerce (fuente de verdad de casi todo)

| Grupo | Entidades | EXISTENTE | PROPUESTO |
|---|---|---|---|
| Identidad y cuenta | E01, E02, E03 | Usuarios, direcciones por metadatos, token web único de 30 días | Estado de cuenta y solicitud de eliminación (E08) |
| Sesiones y seguridad | E04, E05, E06, E07 | — (hoy: un token por usuario, sin auditoría ni consentimiento registrado) | 4 tablas con `dbDelta` (`authentication.md` §8); hooks `delete_user`, `after_password_reset`, `profile_update`; limpieza diaria por WP-Cron |
| Catálogo | E09–E14 | Todo (productos, categorías, marcas, etiquetas, atributos, imágenes) | Lectura de `catalog_visibility` y filtro `status=publish` en la ficha (FE-01) |
| Compra | E15, E16, E17, E18 | Pedido, líneas, ticket de handoff de 60 s | Metadatos `_ipr_checkout_ref` y `_ipr_channel`; ticket con `user_id` en lugar del token; cookie no persistente para el canal app (WP-06) |
| Contenido operativo | E19, E20, E22, E23 | — (hoy en archivos del repositorio) | Fuente administrable de sedes y de configuración (WP-13, ADR-018) |
| Fuera del MVP | E21, E24–E30 | Directorio, PQRS, boletín y campañas ya existen en la web / WordPress | Nada |

### 5.2 BFF Next.js `/mobile/v1` (sin persistencia propia)

| Entidad | Naturaleza | Estado |
|---|---|---|
| E31 Registro de idempotencia | Memoria; 60 s (`/checkout`) y 24 h (`/pqrs`) | PROPUESTO |
| E32 Contador de rate limit | `Map` en memoria; se vacía al superar 5.000 claves (`RL:16-17,33-38`); la propuesta lo cambia por LRU acotado por clase (FE-05) | EXISTENTE / PROPUESTO |
| E33 Log técnico | Una línea JSON por solicitud, sin PII directa | PROPUESTO |
| E34 Caché del catálogo e índice | Cachés SWR (`listings` 400, `detail` 600, `by-ids` 50, `meta` 10, `meta-terms` 200) e índice de hasta 10.000 productos | EXISTENTE |

El BFF **nunca** guarda sesiones, tokens, contraseñas ni datos personales (`APIA` §3.2). Todo lo que pierda al reiniciar (contadores, idempotencia) es aceptable por diseño, salvo la autenticación, cuyos contadores viven en WordPress (E06).

### 5.3 App móvil Flutter (todo PROPUESTO)

| Dónde | Qué | Entidades | Protección | Al cerrar sesión | Al eliminar cuenta |
|---|---|---|---|---|---|
| Android Keystore / iOS Keychain (`flutter_secure_storage`) | `refreshToken`, `deviceId` | E36, E35 | Cifrado del SO; excluido de copias; iOS "después del primer desbloqueo, solo este dispositivo" | Se borra el refresh; `deviceId` se conserva | Se borran ambos; `deviceId` se regenera |
| Memoria | `accessToken`, perfil, direcciones, pedidos | E36, E41 | RAM del proceso | Se borra | Se borra |
| Hive `cart` | Líneas del carrito (con instantánea visual) | E37 | Sin PII; sin cifrar | Se conserva (PROPUESTA, DN-10) | Se conserva |
| Hive `cache` | Catálogo, sedes y configuración públicos; intento de checkout en curso | E38, E39 | Sin PII; tope y LRU | Se conserva (el intento se borra) | Se conserva (el intento se borra) |
| `shared_preferences` | Avisos vistos, última pestaña, marca de primer arranque | E40 | Sin PII | Se conserva | Se borra |
| Caché de imágenes | Imágenes de catálogo | E14 | Disco con tope (RNF-010) | Se conserva | Se conserva |

Controles de plataforma (RNF-035): Android `allowBackup=false` o reglas de exclusión; iOS sin claves sincronizables con iCloud; capturas de pantalla ocultas en cuenta, pedidos y checkout (Should).

---

## 6. Inventario de datos personales en tránsito y en reposo

| Dato | Origen | Tránsito | Reposo (sistema, entidad) | Destinatarios y terceros | Notas |
|---|---|---|---|---|---|
| Contraseña | App (formulario) | App → BFF → WordPress por TLS; solo en cuerpo de `/auth/*` y `/me/*` | **No se guarda en claro**: hash en `users.user_pass` (E01) | — | Nunca en logs ni en caché (RNF-047). Se verifica con `wp_check_password`. |
| Correo, nombre, apellido | App (registro, perfil) | App → BFF → WordPress | WordPress (E01); memoria de la app (E41) | Wordfence (login, configuración **DESCONOCIDA**, MED-10); SMTP de WooCommerce | El correo también viaja al checkout para prellenar facturación. |
| Cédula/NIT | App (dirección) o checkout nativo | App → BFF → WordPress; ticket de 60 s en el flujo web actual | **Pedido** (copia de facturación, E15); perfil: clave **DESCONOCIDA**, hoy no se persiste (E02) | Wompi puede recibirla a través de WooCommerce (**DESCONOCIDO**) | Dato `PERSONAL-ALTO`; mínimo posible (DM-02). |
| Dirección y teléfono | App o checkout | Ídem | WordPress (E02) y copia en el pedido (E15) | Transportadora (**DESCONOCIDA**) | La app los mantiene solo en memoria. |
| Historial de pedidos | WooCommerce | WordPress → BFF → app | WooCommerce (E15/E16); memoria de la app | Contabilidad / facturación electrónica (si está fuera de WooCommerce: **DESCONOCIDO**) | Se conserva por obligación contable (**D-12**). |
| IP del cliente | Cloudflare / BFF | Cloudflare → BFF (`CF-Connecting-IP`) → WordPress (`X-IPR-Client-IP`, solo con secreto del BFF) | Auditoría de WordPress 90 d (E05); clave de rate limit en memoria del BFF (E32); `ipPrefix` truncada en logs (E33) | Cloudflare (proveedor de borde) | Retención de la IP completa a validar (RNF-063, **D-12**). |
| `deviceId` | App | Cabecera `X-Device-Id` | Sesión (E04); secure storage (E35); `deviceRef` HMAC en logs (E33) | — | No es secreto ni prueba de identidad; sin datos de hardware (RNF-060). |
| Tokens (access, refresh) | WordPress | WordPress → BFF → app (respuesta de login/refresh); app → BFF por `Authorization` | Solo hash SHA-256 en WordPress (E04); Keystore/Keychain y memoria en la app | — | Nunca en URL, logs ni transients (corrige A-03, A-12). |
| Mensaje de PQRS (texto libre) | App | App → BFF → SMTP | Buzón corporativo (E24); no se guarda en la app | Proveedor SMTP y del buzón (**DESCONOCIDOS**) | Puede contener cualquier dato personal; retención **D-12**. |
| Documento, correo, celular, ciudad, factura (campañas) | Formularios de campaña | Navegador → WordPress (iframe) | Tablas de campaña (E26, E28, E30) | reCAPTCHA de Google en raspa Samsung (`RS`) | Fuera del MVP; retención **DESCONOCIDA** (D-12). |
| Datos de pago (tarjeta, banco) | Cliente en el checkout web | Navegador → Wompi | **No se guardan en IPR ni en la app** | Wompi | RF-053. Tokenización de medios de pago por el plugin: **DESCONOCIDA**. |
| Reporte de fallos y analítica | App | — | **No existen aún**; proveedor y consentimiento pendientes (DN-02, PA-08, RNF-061, RNF-103) | Firebase o Sentry (**DECISIÓN PENDIENTE**, país de tratamiento) | Deben pasar por `PiiScrubber`; sin PII. |
| Ubicación, token de push | — | — | **No se recogen en el MVP** (RF-078, RF-090 fase 2) | — | Si se añaden: nuevas bases, consentimiento propio y registro ante la SIC (RNF-064, RNF-066). |

---

## 7. Ciclo de vida, retención y eliminación

> **Insumo técnico, no asesoría jurídica.** Todo plazo marcado `D-12` lo define Jurídico (y Finanzas para soportes contables). Los plazos de 15 días hábiles (reclamos, art. 15 Ley 1581) y de 10 días hábiles (consultas) son los de los requisitos RNF-058/059 y deben validarse.

### 7.1 Códigos de retención

| Código | Regla | Origen del valor | Estado |
|---|---|---|---|
| `RET-01` | Mientras exista la cuenta; supresión o anonimización ≤ 15 días hábiles tras la solicitud de eliminación. | RNF-058; `AUTH` §12 | Plazo: PROPUESTO. Excepciones: **D-12** |
| `RET-02` | Pedidos y soportes contables/fiscales: se conservan; plazo y alcance de la anonimización parcial. | `AUTH` §12.2 | **DECISIÓN PENDIENTE D-12 / PA-09 / DN-08** (Jurídico + Finanzas) |
| `RET-03` | Sesiones revocadas o vencidas: borrar a los 30 días. | `AUTH` §3.5, §8.1 | PROPUESTO |
| `RET-04` | Auditoría de seguridad: 90 días; evento mínimo de eliminación (sin PII salvo `user_id`): plazo de Jurídico. | `AUTH` §8.2; RNF-063 | 90 d: PROPUESTO. Evento de eliminación: **D-12** |
| `RET-05` | Contadores anti fuerza bruta: limpiar filas sin bloqueo con `updated_at` > 24 h. | `AUTH` §8.3 | PROPUESTO |
| `RET-06` | Consentimientos: mientras haya tratamiento y el plazo posterior a la supresión. | `AUTH` §8.4 | **D-12** |
| `RET-07` | Logs técnicos del BFF: ≤ 90 días. | RNF-063; `APIA` §12 | PROPUESTO; DN-08 pendiente |
| `RET-08` | Efímero con TTL propio: ticket 60 s; idempotencia 60 s (`/checkout`) y 24 h (`/pqrs`); cachés por TTL. | `HO:92`; `APIC` §1.6; `WCA` §5.1 | HECHO (ticket, cachés) / PROPUESTO |
| `RET-09` | En el dispositivo hasta cerrar sesión o eliminar cuenta (borrado inmediato). | RNF-062 | PROPUESTO |
| `RET-10` | En el dispositivo, sin PII: persistente con tope/LRU (carrito: DN-10). | `FLU` §8 | PROPUESTO; DN-10 pendiente |
| `RET-11` | Contenido editorial o público: sin plazo especial. | — | — |
| `RET-12` | Buzón de correo corporativo (PQRS, boletín). | — | **DESCONOCIDA** → **D-12** |
| `RET-13` | Datos de campañas. | — | **DESCONOCIDA** → **D-12** |
| `RET-14` | `deviceId`: mientras exista la instalación; se regenera tras eliminar la cuenta. | `FLU` §8 | PROPUESTO |
| `RET-15` | Registro mínimo de la solicitud de eliminación. | `AUTH` §8.2 | **D-12** |

### 7.2 Entidades con datos personales: ciclo de vida

| Entidad | Creación | Actualización | Retención | Eliminación o anonimización | Depende de D-12 |
|---|---|---|---|---|---|
| E01 Usuario | Registro (`wc_create_new_customer`, rol `customer`) con aceptación registrada | Perfil (nombre) por `PATCH /me`; correo y contraseña con contraseña actual y revocación de otras sesiones | `RET-01` | `wp_delete_user` sin reasignar contenido, **después** de anonimizar lo vinculado (programado por WP-Cron) | Plazo máximo y periodo de arrepentimiento; reutilización del correo (AC-110-6) |
| E02 Dirección | Primera edición de perfil o checkout | `PUT /me/addresses/{type}` (reemplazo completo, lista blanca) | `RET-01` | Se eliminan con el usuario | Cédula/NIT: conservar solo en el pedido (si se exige) |
| E03 Token web | Login web | Se sobrescribe en cada login web o cambio sensible | Hasta 30 días o revocación | Se borra en revocación global y eliminación | — |
| E04 Sesión | Login o registro desde la app; una por (`user_id`, `device_id`); máx. 10 | Rotación del refresh, `last_used_at` (máx. cada 5 min) | `RET-03` | Revocación (`revoked_reason`) y borrado a 30 días; hook `delete_user` borra las filas del usuario | — |
| E05 Evento | Cada evento sensible (login, cambio, revocación, ticket) | Inmutable (append-only) | `RET-04` | Borrado por antigüedad (> 90 d) | Evento de eliminación; conservación de la IP |
| E06 Contador | Primer intento fallido o limitado del sujeto | `INSERT … ON DUPLICATE KEY UPDATE`; un login exitoso borra `login_account` | `RET-05` | Caducan solos | — |
| E07 Consentimiento | En el registro (misma transacción lógica); `revoked` en fase 2 | Inmutable (append-only: `accepted`/`revoked`) | `RET-06` | Se conserva el registro mínimo como prueba; luego se elimina | **Plazo posterior a la supresión** |
| E08 Solicitud de eliminación | `POST /me/deletion` con contraseña actual e `Idempotency-Key` | `status`: `scheduled` → `completed` | `RET-15` | Registro mínimo | **Plazo del registro** (D-12) |
| E15/E16 Pedido y líneas | Al pagar o iniciar el pago en el checkout de WooCommerce | WooCommerce y Wompi (estado); la app nunca los edita | `RET-02` | **Se conservan** por obligación contable y tributaria, **anonimizando lo que no sea exigible** (teléfono, notas) y desvinculando `customer_id`, con el borrador de datos personales de WooCommerce | **Plazo, alcance de la anonimización y pedidos en curso (PA-09)** |
| E17 Intento de checkout | `POST /checkout` | Estado derivado por consulta | `checkoutRef` vive en el pedido (`RET-02`) y en memoria del BFF (`RET-08`) | Con el pedido | Con el pedido |
| E18 Ticket | `POST ipr/v1/handoff-ticket` | Un solo uso | `RET-08` (60 s) | Se borra **antes** de usarse | — |
| E21 Directorio | Edición de archivo en el repositorio | Edición manual | `RET-11` (sin plazo hoy) | Retirar entradas y fotos | **Autorización de los empleados y retención (D-12)**; fuera de la app |
| E24 PQRS | `POST /pqrs` → correo | No aplica | `RET-12` | Política del buzón | **Sí**; sin evidencia de autorización (DM-04) |
| E25 Boletín | Formulario web → correo | No aplica | `RET-12` | Política del buzón / lista de Mercadeo | **Sí**; fuera del MVP |
| E26–E30 Campañas | Participación en la campaña | No aplica | `RET-13` | Sin proceso definido | **Sí**; fuera del MVP |
| E31 Idempotencia | `POST /checkout`, `POST /pqrs` con `Idempotency-Key` | — | `RET-08` | Expira | — |
| E32 Rate limit BFF | Cada solicitud | Ventana fija | `RET-08` | Expira o se purga por tope | — |
| E33 Log técnico | Cada solicitud | Inmutable | `RET-07` | Rotación a 90 d | Plazo (DN-08) |
| E35 `deviceId` | Primera ejecución (tras limpiar el Keychain si es reinstalación en iOS) | No cambia | `RET-14` | Se regenera al eliminar cuenta o reinstalar | — |
| E36 Tokens | Login, registro o refresh | Cada refresh reemplaza el par | `RET-09` | Cierre de sesión, eliminación, `401` irrecuperable | — |
| E37 Carrito | Al añadir un producto | Cantidades; reemplazo de instantánea tras cada revalidación | `RET-10` | Se vacía solo cuando `paymentState = paid` (RF-057) o por el usuario | Conservarlo al cerrar sesión (DN-10) |
| E39 Intento local | Respuesta `201` de `/checkout` | Máquina de estados | `RET-09` | Fin del flujo o cierre de sesión | — |
| E41 Datos en memoria | Tras login o consulta | Cada petición | `RET-09` | Cierre de sesión o eliminación | — |

### 7.3 Qué ocurre con cada dato al eliminar la cuenta (propuesta para validar)

Base: `AUTH` §12.2, ampliada con BFF y app. Flujo: revocación inmediata de acceso → anonimización programada (≤ 15 días hábiles propuestos) → confirmación al titular.

| Dato | Dónde | Acción propuesta | Estado |
|---|---|---|---|
| Usuario, contraseña (hash), correo, nombre | E01 | **Eliminar** el usuario tras anonimizar lo vinculado | PROPUESTA |
| Direcciones | E02 | **Eliminar** (ambos formatos si coexisten, INC-05) | PROPUESTA; verificar formato en *staging* |
| Cédula/NIT guardada en el perfil | E02 | **Eliminar** (clave **DESCONOCIDA**) | PROPUESTA |
| Sesiones y token web | E03, E04 | **Eliminar** y bloquear emisión nueva (`_ipr_account_state`) | PROPUESTA |
| Contadores | E06 | Caducan solos (≤ 24 h) | PROPUESTA |
| Carrito persistente de WooCommerce y sesión de WC | E01 | **Eliminar** | PROPUESTA |
| Medios de pago tokenizados | E01 | **Eliminar** si existen | **DESCONOCIDO** (usa Wompi tokenización) |
| **Pedidos** y líneas | E15, E16 | **Conservar** por obligación contable, anonimizando lo no exigible y desvinculando `customer_id` | **D-12 / PA-09 / DN-08** |
| Pedidos en curso | E15 | Permitir la solicitud y completar el pedido; o bloquear hasta cierre | **PA-09 / AC-110-8** |
| Consentimientos | E07 | **Conservar** el registro mínimo; luego eliminar | **D-12** |
| Auditoría | E05 | Conservar ≤ 90 d; evento de eliminación según Jurídico | **D-12** |
| Solicitud de eliminación | E08 | Registro mínimo (sin PII salvo `user_id`) | **D-12** |
| PQRS, boletín, campañas | E24, E25, E26–E30 | Fuera de la cuenta: política de retención del buzón y de las tablas | **D-12** (retención DESCONOCIDA) |
| Logs del BFF | E33 | Seudónimos; caducan a los 90 d | PROPUESTA |
| Datos locales del dispositivo | E35–E41 | Borrado inmediato (carrito y caché pública se conservan; `deviceId` se regenera) | PROPUESTA (RNF-062) |
| Reutilizar el correo para una cuenta nueva | E01 | Permitido tras completar la eliminación | **AC-110-6 pendiente** |
| Datos en Wompi o en la pasarela | externo | Fuera del alcance de IPR para borrar; conservación del encargado | **DESCONOCIDO** |
| Comportamiento de WooCommerce con pedidos de un usuario eliminado ("invitado") | E15 | A verificar | **SUPUESTO** (`AUTH` §12.2) |

### 7.4 Entidades sin datos personales: ciclo de vida

| Entidad | Cómo cambia | Frescura máxima esperada | Invalidación | Eliminación |
|---|---|---|---|---|
| E09–E14 Catálogo | Edición en WordPress | ≤ 10 min (RNF-111, RNF-112): 5 min de SWR interno + 5 min de borde | Webhook HMAC de WooCommerce (`/api/revalidate`) o renovación de 5 min; el índice se invalida y se reconstruye | Producto despublicado: desaparece de listados y ficha (`404` solo con respuesta definitiva) |
| E19–E20 Sedes | Hoy despliegue; propuesto: edición en WordPress | 1 h (borde), 24 h (Hive); stale hasta 30 d | Edición en WordPress | Sede cerrada: se retira del origen |
| E22–E23 Configuración y documentos legales | Edición en WordPress | ≤ 5 min (RNF-029) | TTL | Versión nueva sustituye a la anterior; el consentimiento conserva la versión aceptada (E07) |
| E34, E38 Cachés | Derivadas | Por TTL | Por clave; LRU | Desechables en cualquier momento |

---

## 8. Reglas de integridad

Cada regla indica **dónde se aplica** y su evidencia. "Servidor" = BFF y/o WordPress. Una regla marcada PROPUESTA aún no existe en el código.

| ID | Regla | Dónde se aplica | Evidencia |
|---|---|---|---|
| IR-01 | **El precio, impuestos, envío, descuentos, stock y total los decide siempre WooCommerce.** La app y el BFF no envían ni aceptan precios: `POST /cart/validate` y `POST /checkout` solo reciben `{id, quantity}`; los esquemas `strict` rechazan `price`, `total`, `customer_id`, `role`. | Servidor (Zod `strict` + checkout nativo) | `OV` §4; `CS:77-93`; RNF-045(a); AC-050-8; AC-052-2 |
| IR-02 | Precio `0` o vacío significa **`price.status = on_request`**, nunca `$0`; `purchasable` exige precio con valor **y** disponibilidad `in_stock`; la app oculta "Añadir al carrito" también si recibe precio 0 (defensa en profundidad). | BFF (DTO) y app | `WC:258`; `OAS` Price; RF-012; RNF-107 |
| IR-03 | **Nunca se expone el stock exacto**: solo `availability` (`in_stock`, `out_of_stock`, `on_backorder`). `on_backorder` no es comprable en el MVP (AP-04). | BFF (DTO) | `WC:223`; S-01; `APIA` AP-04 |
| IR-04 | Identificadores y límites del carrito: `productId` entero > 0 sin duplicados; cantidad 1–99; 1–100 líneas. | App (domain), BFF (Zod) y WordPress (`ipr_cart_clean_items`) | `CS:77-93`; `HO:152-173`; RF-049; RNF-031 |
| IR-05 | `onSale = on_sale ∧ price > 0 ∧ regular_price > price`; en el DTO, `regularAmount ≥ amount`; sin ofertas con precio mayor al regular. | BFF (mapeo); verificación diaria (RNF-107) | `WC:260`; RNF-107 |
| IR-06 | **Visibilidad:** solo productos `status = publish` (y no `hidden` ni con contraseña). `404` solo con respuesta definitiva; caídas → `503`/`502`/`504`; dato vencido (≤ 24 h) se sirve con `X-IPR-Data-State: stale`. | BFF y capa de datos | `APIA` §6.3, FE-01, FE-02; RNF-112 |
| IR-07 | **Una sesión activa por (`user_id`, `device_id`); máx. 10 activas por usuario;** `access_token_hash` y `refresh_token_hash` únicos (`UNIQUE`). | WordPress (índices y lógica) | `AUTH` §3.3, §8.1 |
| IR-08 | **Los tokens solo existen en claro** en la respuesta de emisión y en el almacén seguro del dispositivo; en servidor solo su SHA-256; nunca en BD, logs, transients ni URL. | WordPress, BFF, app | `AUTH` §3.2; RNF-041 |
| IR-09 | El refresh es de **un solo uso**: reutilizarlo fuera de la ventana de gracia (30 s, mismo `deviceId`) revoca la sesión (`reuse_detected`). | WordPress (transacción con `SELECT … FOR UPDATE`) | `AUTH` §3.4 |
| IR-10 | **Integridad referencial lógica** (sin claves foráneas físicas): el hook `delete_user` borra las sesiones; `ipr_auth_events` y `ipr_consents` pueden conservar `user_id` huérfano por retención (D-12); `order.customer_id` pasa a `0` al anonimizar. | WordPress (hooks y trabajos programados) | `AUTH` §8, §12.2 |
| IR-11 | **Autorización por objeto:** nunca se acepta un id de usuario del cliente; el pedido se devuelve solo si `customer_id` = usuario autenticado (si no, `404`); `checkoutRef` se busca **dentro** de los pedidos del usuario (uno ajeno devuelve `awaiting_order`). | WordPress (`ipr/v1/m/*`) | `AUTH` §14 API1; AC-055-5; AC-056-10 |
| IR-12 | Una cuenta con `_ipr_account_state ≠ active` no inicia sesión ni valida tokens, con el mismo mensaje genérico de credenciales inválidas. | WordPress | `AUTH` §8.5, §13 |
| IR-13 | Solo roles permitidos obtienen sesión en la app (RF-048). Regla exacta **DECISIÓN PENDIENTE AP-03/PA-03** (INC-19). | WordPress | `AUTH` §3.7; `APIA` AP-03 |
| IR-14 | **No existe el alta sin `accepted = true` ni con versiones distintas a las vigentes** (`GET /config`); el consentimiento se escribe en la misma transacción lógica que el alta y es **append-only**. | BFF (validación) y WordPress | `APIC` EP-02; `AUTH` §8.4, §10 |
| IR-15 | **Checkout:** ticket de un solo uso, 60 s, borrado antes de usarse; `checkoutRef` UUID v4 generado por el BFF y **un intento ↔ máximo un pedido** (a verificar, PA-11); `returnUrl` la fija el servidor y su host debe estar en la lista cerrada; los parámetros del enlace de retorno **no prueban el pago**. | BFF y WordPress | `HO:92-98,122-149,386-397`; RNF-045; ADR-017 |
| IR-16 | `paymentState` se deriva solo del estado de WooCommerce con la tabla de §13.2 de `api_architecture.md`; estados desconocidos → `unknown`. **El carrito local solo se vacía con `paymentState = paid`.** | BFF y app | `APIA` §13.2; RF-057 |
| IR-17 | **Fechas:** `DATETIME` en UTC en las tablas nuevas; API en ISO 8601 con zona; presentación en America/Bogota. | WordPress, BFF, app | `AUTH` §8; `APIA` §6.1; `FLU` §12 |
| IR-18 | **Importes:** COP con IVA incluido; `null` cuando no hay precio; la app usa `Money` entero y no `double`. Representación en el contrato: **DM-05**. | BFF y app | `APIA` §6.1; `FLU` §11; INC-07 |
| IR-19 | **Direcciones:** país fijo `CO`; `department` ∈ códigos válidos de `colombia.ts`; `nationalId` `[0-9.-]` 3–30; `phone` `^[\d\s+\-().]{7,20}$`; lista blanca de campos por bloque (sin mass assignment). | BFF (Zod) y WordPress (lista blanca) | `CS:47-67`; `AR:335-336` |
| IR-20 | **DTO por lista blanca:** la app ignora campos desconocidos y tolera valores nuevos de enums abiertos. | BFF y app | `OV` P7; `APIA` §5 |
| IR-21 | **Sin PII** en la caché persistente de la app, en logs, en analítica, en deep links, en preferencias ni en copias de seguridad; PQRS no se encola ni se persiste en la app. | App, BFF | `FLU` §8, §9; RNF-034, 035, 047, 062 |
| IR-22 | **Idempotencia:** `POST /checkout` (60 s, memoria del BFF), `POST /pqrs` (24 h) y `POST /me/deletion` (WordPress, `requestId` estable); misma clave con cuerpo distinto → `409`. | BFF y WordPress | `APIC` §1.6 |
| IR-23 | Los sujetos de los contadores y de la auditoría se guardan como **HMAC** (no en claro) en WordPress. En la memoria del BFF la clave de rate limit sí contiene la IP, de forma efímera. | WordPress; BFF | `AUTH` §8.2-8.3; `RL` |
| IR-24 | Sedes `upcoming = true` sin teléfonos ni `mapsQuery`; `coordinates` y `openingHours` son `null` en el MVP. | BFF (DTO) | RF-072; RF-077; D-09 |
| IR-25 | La marca de un producto se resuelve por prioridad **atributo → nombre → taxonomía** hoy (`WCA` §6); **DECISIÓN PENDIENTE AP-05** (fuente canónica; propuesta: taxonomía primero). `BrandRef.slug` admite `null`. | BFF | `BR:60-92`; `APIA` AP-05 |
| IR-26 | Una versión de app por debajo de `minSupportedVersion` recibe `426`; `checkoutUrl` solo se abre si su host está en `allowedHosts`. | BFF y app | `APIA` §5; RNF-029; AC-052-13 |
| IR-27 | **Purgas programadas:** sesiones vencidas o revocadas > 30 d; eventos > 90 d; contadores sin bloqueo > 24 h (WP-Cron diario). | WordPress | `AUTH` §3.5, §8.2-8.3; WP-12 |
| IR-28 | **Calidad de datos de catálogo (objetivos):** SKU único y no vacío; categoría válida; imagen presente y utilizable; ficha sin scripts tras sanear. Estado actual **DESCONOCIDO** (MED-06). | Verificación automática y proceso de calidad | RNF-106, 108, 109, 110, 116 |

---

## 9. Hechos clave, supuestos, propuestas, decisiones pendientes y riesgos

### 9.1 Hechos (verificados en código o documento)

| ID | Hecho | Evidencia |
|---|---|---|
| H-M01 | El perfil devuelto hoy incluye `roles`, `username` y **todos** los metadatos `billing`/`shipping`. | `AR:105-120` |
| H-M02 | Las direcciones se guardan como **arreglo** bajo los metadatos `billing` y `shipping`, con lista blanca de campos. La lista blanca **no** incluye la cédula/NIT. | `AR:106-107,335-360` |
| H-M03 | El checkout nativo usa campos personalizados `billing_national_id` y `cedula_nit_ship` y el campo `order_comments` para las notas. | `HO:322-323,340-341,349-351` |
| H-M04 | El ticket de handoff guarda 60 s correo, facturación, envío, notas **y el token de sesión** del cliente en un *transient*. | `HO:214-235` |
| H-M05 | El pedido existente expone `id`, `orderNumber`, `status`, `statusLabel`, `date` (sin zona), `currency`, `subtotal`, `total`, `paymentMethodTitle` e ítems `{name, qty, total}`; **no** incluye id de producto, imagen, envío, tracking ni dirección. | `AR:245-266`; `COD` §3 |
| H-M06 | PQRS y boletín **no se guardan** en ninguna base: se envían por SMTP a un buzón corporativo. | `PQ`; `NL` |
| H-M07 | El limitador de frecuencia actual es un `Map` en memoria que se vacía al superar 5.000 claves; la clave incluye la IP. | `RL:16-17,33-38` |
| H-M08 | El tipo `Sede` no tiene coordenadas ni horarios; hay 32 entradas (31 operativas y 1 "próximamente") en 10 ciudades. | `SE:2-37`; `COD` §3 |
| H-M09 | `lib/woocommerce.ts` mapea el producto con `id` como **string**, `brand` como cadena y `price` como número (0 = sin precio); `stock_quantity` existe en la ficha pero la web no lo muestra. | `WC:257-281`; `MD:1-28` |
| H-M10 | Las tablas de campañas guardan documento, nombre, correo, celular y (ruleta) factura y ciudad, sin política de retención visible en el código. | `RM:117-131`; `RS:176-191` |
| H-M11 | La web guarda el perfil completo en `localStorage` (`ipr-auth`); la app **no** debe replicarlo. | `COD` §1; RNF-034 |

### 9.2 Supuestos

| ID | Supuesto | Cómo validarlo |
|---|---|---|
| SM-01 | Producción corre **un** proceso Node (los contadores y la idempotencia del BFF son por proceso). | Pregunta al equipo web; MED-04 (`SA-01`). |
| SM-02 | WordPress permite crear tablas propias con `dbDelta` en InnoDB. | Revisión del hosting (`SA-02`). |
| SM-03 | `wc_create_new_customer($email, '', …)` genera `user_login` a partir del correo. | Registro de prueba en *staging*. |
| SM-04 | La columna `user_email` de WordPress admite 100 caracteres (esquema estándar), menos que los 120 del contrato (INC-24). | `SHOW COLUMNS` en *staging*. |
| SM-05 | La solicitud de privacidad nativa de WordPress guarda el correo del titular. | Prueba en *staging* (`AUTH` §12.1 paso 5). |
| SM-06 | Los pedidos de un usuario eliminado pasan a "invitado" en WooCommerce. | Prueba en *staging* (`AUTH` §12.2). |
| SM-07 | `on-hold` equivale a "pago pendiente de confirmación". | Wompi sandbox (PA-12). |
| SM-08 | El número de pedido coincide con el id (no hay plugin de numeración). | Revisión de plugins (`SA-07`). |
| SM-09 | Los teléfonos de las sedes son canales corporativos y no personales. | D-09 / S-06. |
| SM-10 | `_ipr_checkout_ref` y `_ipr_channel` son compatibles con el almacenamiento HPOS de pedidos. | Prueba en *staging* (`AUTH` §8.5). |

### 9.3 Propuestas del modelador (PM) — ya reflejadas en este modelo

| ID | Propuesta | Justificación |
|---|---|---|
| PM-01 | Un solo inventario de entidades con identificador estable (E01–E41) y un código de retención por campo. | Trazabilidad entre diccionario, ER y requisitos; base del inventario de datos que exige RNF-060. |
| PM-02 | Clasificar los seudónimos (HMAC de usuario, correo, IP, dispositivo) como `PERSONAL`. | Mientras se pueda correlacionar con la clave del servidor siguen siendo datos personales. |
| PM-03 | Definir `PERSONAL-ALTO` (cédula/NIT, copia de facturación, texto libre) como categoría interna de riesgo. | Permite priorizar controles sin pronunciarse sobre "dato sensible" (art. 5), que queda en D-12. |
| PM-04 | Modelar el intento de checkout como entidad **sin tabla propia** (el `checkoutRef` vive en el pedido y en la app). | Cumple ADR-017 sin crear un almacén nuevo; evita guardar PII fuera del pedido. |
| PM-05 | Documentar explícitamente los campos "solo contrato" (sin origen hoy): `alt`, `width`, `height`, `paymentState`, `itemCount`, `productId` de líneas, `mapsQuery`. | Evita que el BFF prometa datos que WooCommerce no entrega hoy. |

### 9.4 Decisiones pendientes

| ID | Decisión | Recomendación | Quién decide |
|---|---|---|---|
| **D-12** | Todo lo marcado `D-12`: plazos de conservación (pedidos, soportes fiscales, consentimientos, auditoría de eliminación, PQRS, boletín, campañas), anonimización de pedidos, periodo de arrepentimiento, política de datos vigente y finalidades, registro de bases ante la SIC, calificación de datos sensibles, textos legales (`accountDeletionNotice`, `acceptsDataPolicy`, avisos). | Validar la tabla §7.3 con Jurídico y Finanzas antes de la fase de construcción. | Jurídico + Finanzas |
| **DM-01** | ¿`UserProfile.id` (ID interno de WordPress) debe viajar a la app? | **No**: la app no lo usa; reduce un identificador persistente (RNF-060). Si hace falta, usar un id opaco. | Arquitecto de API + Flutter |
| **DM-02** | ¿Se guarda la cédula/NIT en el perfil (clave de metadato, whitelist) o solo se captura en el checkout? | Mínimo: no persistirla en el perfil del MVP (`APIC` EP-11 ya admite omitir `nationalId`); el pedido la copia de todas formas. | Equipo web + Jurídico |
| **DM-03** | Unificar el almacenamiento de direcciones (`billing_*` de WooCommerce frente al arreglo `billing` del snippet) **antes** de WP-08 y de la eliminación de cuenta. | Usar solo las claves nativas de WooCommerce (permite prellenado nativo y la herramienta de datos personales de WooCommerce). | Equipo web |
| **DM-04** | ¿Cómo se prueba la autorización de **visitantes** (PQRS, boletín) si `ipr_consents.user_id` es obligatorio y PQRS no se persiste? | Opción A: aceptar `user_id` nulo + `subject_hash`; Opción B: persistir PQRS mínima con consentimiento. Decidir con Jurídico. | Jurídico + arquitecto |
| **DM-05** | Representación de importes en el contrato: `number` decimal (hoy) o entero COP (`Money` en la app, `OV` T-04). | Entero en COP (pesos sin decimales), `null` sin precio. | Arquitecto de API |
| **DM-06** | Qué identificador de pedido usa la app: `id` o `number`. | `id` en rutas (`GET /orders/{orderId}`), `number` para mostrar; la ruta de Flutter `/orders/:number` debe pasar a `/orders/:id`. | API + Flutter |
| **DM-07** | Ruta de retorno del pago: `/app/pedido` (`APIA`) o `/pedido-confirmado` (`FLU`, RF-055). | Unificar en `/app/pedido` (ruta dedicada, ADR-017) y corregir RF-055/`FLU` §6.2. | API + Flutter |
| **DM-08** | Derechos del titular: no hay endpoint para registrar `revoked` en `ipr_consents` ni para **exportar** los datos (RNF-059). | Definir el canal con radicado (RF-111) y, si se exige, una exportación. | Jurídico + API |
| **DM-09** | Fuente canónica del `slug` de marca (AP-05) y quién lo mantiene. | Taxonomía `product_brand`; logos del registro. | Catálogo + equipo web |
| AP-02, AP-03, AP-04, AP-05, AP-06 | Vidas de tokens, roles bloqueados, `on_backorder`, marca, orden por precio. | Ver `api_architecture.md` §17.3. | Varios |
| D-02, PA-11, PA-12 | Confirmación de pago, doble pago, estados de pedido. | Pruebas en *staging* con Wompi sandbox. | Equipo web + Finanzas |
| D-09, DN-03, DN-08, DN-10 | Sedes, variantes de imagen, retención de logs y datos, carrito al cerrar sesión. | Ver documentos origen. | Varios |

### 9.5 Riesgos de datos

| ID | Riesgo | Prob. / Impacto | Mitigación |
|---|---|---|---|
| RM-01 | La cédula/NIT se copia al pedido y viaja en el ticket de 60 s aunque no se persista en el perfil; es el dato personal más sensible del flujo. | Alta / Alta | Mínimo necesario (DM-02); ticket con `user_id` y sin facturación en el flujo de la app (WP-06). |
| RM-02 | El *transient* del ticket guarda hoy datos personales y el token de sesión. | Media / Alta | WP-06: guardar `user_id`; no registrar `?ipr_ticket=` en logs (hosting **DESCONOCIDO**). |
| RM-03 | `username` y `displayName` pueden revelar el correo (WooCommerce genera el login desde el correo). | Media / Media | No exponer `username`; `displayName` = nombre y apellido. |
| RM-04 | PQRS sin evidencia de autorización ni retención definida; texto libre `PERSONAL-ALTO`. | Alta / Media | DM-04; `acceptsDataPolicy` validado por Jurídico (D-12). |
| RM-05 | Direcciones en dos formatos → la eliminación puede dejar restos y el prellenado puede no funcionar. | Media / Alta | DM-03; verificación en *staging*. |
| RM-06 | La auditoría guarda la **IP completa** 90 días. | Media / Media | Validar con Jurídico (RNF-063); evaluar truncar la IP a los 7–30 días (a decidir). |
| RM-07 | El directorio web publica datos de empleados (59 contactos) fuera de la app. | Media / Media | Fuera del alcance de la app (RNF-065); sugerir a Jurídico revisar autorización (D-12). |
| RM-08 | Las campañas guardan documento, correo y celular sin retención definida y con endpoints públicos. | Media / Alta | Mantenerlas fuera de la app; política y retención antes de cualquier integración (RNF-065, D-12). |
| RM-09 | Proveedor de reporte de fallos y analítica no definido: posible transferencia internacional. | Media / Media | DN-02, PA-08; `PiiScrubber`; análisis de transferencia (RNF-061). |
| RM-10 | Nuevas bases de datos personales (sesiones y dispositivos, consentimientos, auditoría) sin dictamen ni registro ante la SIC. | Media / Alta | Evaluación de Jurídico antes de publicar (RNF-064). |
| RM-11 | Un producto eliminado deja líneas de pedido con `productId = null`. | Alta / Baja | El DTO admite `null` (`OAS` OrderDetail.items). |
| RM-12 | Tipos y nombres divergentes entre código y contrato (INC-04, 06, 13, 17) causan errores de mapeo silenciosos. | Alta / Media | Anexo A.1 del diccionario; pruebas de contrato (RNF-090). |
| RM-13 | El pago confirmado por webhook de Wompi es **DESCONOCIDO**: el estado del pedido puede no reflejar el pago. | Media / Alta | D-02, PA-11, RNF-024 en *staging*. |
| RM-14 | El `deviceId` persiste entre cierres de sesión (identificador persistente). | Baja / Media | Regenerarlo al eliminar cuenta y en reinstalación; no usar datos de hardware. |

---

## 10. Entregables posteriores y puntos de coordinación

| Rol | Debe tomar de este modelo | Pendiente |
|---|---|---|
| Arquitecto de API | Corregir las diferencias INC-01 a INC-24 en `openapi.yaml` y `api_contracts.md` o documentar los mapeadores; resolver DM-01, DM-05, DM-06, DM-07. | Actualizar RF-055 y `FLU` §6.2 con la ruta de retorno final. |
| Arquitecto Flutter | Mantener los códigos `RET-09`/`RET-10`; entidades E35–E41; ruta `/orders/:id`; ruta de retorno. | SPK-03 (secure storage y reinstalación en iOS). |
| Equipo web / WordPress | Verificar en *staging* los puntos del anexo A.2 del diccionario; crear las 4 tablas con `dbDelta`; resolver DM-03. | Esquema real de `users`/`usermeta` y de pedidos. |
| Jurídico + Finanzas | Cerrar D-12 con la tabla §7.3, DM-02, DM-04, DM-08. | Política de datos, finalidades, registro de bases ante la SIC. |
| QA / Seguridad | Pruebas de integridad (§8) y de valores canario (RNF-047) sobre las entidades con datos personales. | Matriz de dos cuentas (IDOR). |

---

## 11. Inconsistencias detectadas

Hallazgos entre documentos y entre documentos y código. **No se modificó ningún documento ni código**: aquí solo se listan, con su resolución propuesta. Gravedad: **A** = puede producir fallo funcional o fuga; **M** = ambigüedad que exige decisión; **B** = menor.

| ID | Grav. | Tema | Fuente A | Fuente B | Impacto | Resolución propuesta |
|---|---|---|---|---|---|---|
| INC-01 | M | Campo de login | Código: `username` (`AU:119-123`, `AR:159`) | Contrato: `login` (`OAS` LoginRequest; `APIC` EP-03) | Mapeo BFF→WP | El BFF traduce `login`→`username`; documentado en el anexo A.1. |
| INC-02 | M | Registro | Código: `first_name`, `last_name` (`AU:125-134`, `AR:182-183`); sin aceptación | Contrato: `firstName`, `lastName` + `acceptance` (`OAS` RegisterRequest) | Mapeo; el registro de aceptación (WP-11) no existe | Mapeo en BFF; WP-11 crea `ipr_consents`. |
| INC-03 | M | Respuesta de sesión | Código: `{ token, user }` (`AR:130-132`) | Contrato: `{ session{accessToken, refreshToken, …}, user }` (`OAS` AuthSessionResponse) | La web y la app usan modelos distintos (a propósito, `AUTH` §7) | Rutas nuevas `ipr/v1/m/*`; las heredadas no cambian. |
| INC-04 | **A** | Nombres y lista blanca de dirección | `AR:335-336`: `address_1`, `address_2`, `state`, `country`, `email`; **sin** `nationalId`. `HO:309-342`: ticket con `address1`, `department`, `nationalId` | `OAS` Address: `address1`, `address2`, `department`, `nationalId`; **sin** `email` ni `country` | Tres convenciones de nombres; `nationalId` no persiste hoy en el perfil | Mapeadores (anexo A.1); decidir DM-02; ampliar la lista blanca solo si se aprueba. |
| INC-05 | **A** | Almacenamiento de direcciones | Código: arreglo en meta `billing`/`shipping` (`AR:106-107,340-359`) | `AUTH` §12.2: `usermeta` `billing_*`/`shipping_*`; RF-054 y `APIA` §13.1: "WooCommerce prellena desde la cuenta" | Si el snippet escribe el arreglo y WooCommerce lee `billing_*`, el prellenado y la herramienta de borrado de datos personales no ven los mismos datos | DM-03: verificar en *staging* y unificar antes de WP-08. |
| INC-06 | M | Tipo de `id` de producto | Código: `string` (`MD:2`, `WC:262` `String(raw.id)`) | Contrato: `integer` (`OAS` ProductSummary.id) | Mapeo; claves de caché y carrito | El BFF convierte a entero; la app usa entero. |
| INC-07 | M | Representación de importes | Contrato: `number` (`OAS` Price); código: `Number(raw.price)` (flotante) | `OV` T-04: "enteros en COP (o decimal en texto), nunca `float`"; `FLU` §11: `Money` entero | Redondeo y comparación | DM-05: entero COP en el contrato. |
| INC-08 | M | Disponibilidad | Código: `inStock` solo para `instock`; `onbackorder` se muestra como agotado (`WC:277`; `WCA` §6) | Contrato: `Availability` incluye `on_backorder` + `purchasable` (`OAS`); `FLU` §11 lo trata como no comprable hasta PA-12 | Riesgo de permitir comprar `on_backorder` | `purchasable = false` para `on_backorder` en el MVP (AP-04); explícito en el DTO. |
| INC-09 | M | Forma del precio | Código: `price`, `formattedPrice`, `regularPrice` (`undefined` si no hay oferta) (`MD`) | Contrato: `Price{status, amount, regularAmount (null), onSale, discountPercent, currency, taxIncluded}` | `formattedPrice` no debe viajar; `status` es derivado | Mapeo en `dto.ts`; `formattedPrice` se descarta. |
| INC-10 | M | Marca | Código: cadena (`MD`, `BR:60-92`); cuatro fuentes no alineadas (`WCA` §6) | Contrato: `{ name, slug\|null }` (`OAS` BrandRef) | `resolveBrand` no produce `slug`; marca heurística sin slug | AP-05/DM-09: fuente canónica; `slug = null` si es heurística. |
| INC-11 | B | Categoría principal | Listado: **primera** categoría (`WC:274`); ficha: **última** (`WCA` §6) | Contrato: `categorySlugs[]` y `categories[]` sin "principal" | Migas y "relacionados" pueden diferir | El contrato no declara "principal"; la app no la infiere. |
| INC-12 | M | Imágenes | Código: `imageUrl: string` ("" si no hay) y `gallery: string[]`; solo se lee `src` (`WC:228`) | Contrato: `ImageRef{url, alt, width, height}` (`OAS`) | `alt`, `width`, `height` no tienen origen hoy | Ampliar `_fields` (afecta la caché compartida) o dejar `alt = name` y `width/height = null` (DN-03). |
| INC-13 | **A** | Forma del pedido | Código: `orderNumber`, `date` (`Y-m-d H:i:s` sin zona), `items[{name, qty, total}]`; lista = detalle (`AR:245-266`) | Contrato: `number`, `createdAt` (ISO con zona), `items[{productId, name, sku, quantity, total, imageUrl}]`, `shippingTotal`, `discountTotal`, `taxTotal`, `itemCount`, `paymentState`; lista y detalle separados | El mapeo actual no entrega `productId`, `sku`, `imageUrl`, totales de envío/descuento/impuesto ni `paymentState` | WP-07 (`ipr/v1/m/orders`) debe ampliar el mapeo; zona horaria del sitio **DESCONOCIDA**. |
| INC-14 | M | Lista de sesiones por dispositivo | RNF-040 (Must): "el usuario puede ver/cerrar sesiones de dispositivos" | RF-112 (Could, fase 2); `APIC` §5; `AUTH` §3.5 ("fase 2") | El requisito no funcional exige algo que el contrato difiere | Ajustar RNF-040 a "cerrar todas" en el MVP o subir RF-112. |
| INC-15 | **A** | Ruta de retorno del pago | `APIA` §13 y ADR-017: `/app/pedido` (parámetros `ref`, `order`, `status`) | RF-055, `FLU` §6.2, `OV` ADR-005, `COD` §5.4: `/pedido-confirmado`; `HO:471-478`: `?order=<número>&status=<estado de WC>` | App Links y `assetlinks.json` declaran una ruta distinta de la que implementará el servidor | DM-07: unificar en `/app/pedido`; actualizar RF-055 y `FLU`. |
| INC-16 | M | Identificador de pedido | `FLU` §6.1: ruta `/orders/:number` | `OAS`: `GET /orders/{orderId}` (entero); `AR:256-257`: `id` ≠ `orderNumber` posible (SA-07) | La app podría pedir por número y el BFF esperar id | DM-06. |
| INC-17 | M | Campos de PQRS | Código: `tipo` ("Petición", …), `nombre`, `correo`, `telefono`, `pedido`, `mensaje` (`PQ:22-37`); la plantilla trata `telefono` como opcional (`PQ:58`) aunque el esquema lo exige | Contrato: `type` (`peticion`, …), `name`, `email`, `phone`, `orderReference`, `message` (`OAS` PqrsRequest) | Mapeo de enumeración; incoherencia interna del teléfono | Mapeo en BFF; decidir si el teléfono es obligatorio. |
| INC-18 | **A** | Autorización en PQRS | Código: no existe campo de aceptación (`PQ:22-37`); el boletín sí valida `consent` (`NL:30`) | Contrato: `acceptsDataPolicy` obligatorio (`OAS`), pero no se persiste (`APIC` EP-27) | No hay evidencia de autorización de quien envía una PQRS | DM-04 y D-12. |
| INC-19 | M | Roles bloqueados | `APIA` §17.3 AP-03: "solo `customer` y `subscriber` pueden iniciar sesión" | `AUTH` §3.7 y §16: denegar por capacidad `edit_posts`/`manage_woocommerce` | Reglas con efectos distintos (roles de plugins) | Aprobar una sola (propuesta: por capacidad). |
| INC-20 | M | Sedes | Código: `phone`, `celular`, `celularSecundario`, `ventaRepuestos`, `ventaAire`, `image` relativa (`SE:2-37`) | Contrato: `phones[]{type,display,dial}`, `imageUrl` absoluta, `mapsQuery` (`OAS` Store) | Dos celulares colapsan en `mobile`; `mapsQuery` no existe en el código | Mapeo en BFF (anexo A.1). |
| INC-21 | M | Contenido del ticket de handoff | Código: ticket con `email`, `billing`, `shipping`, `orderNotes`, `authToken` (`HO:214-232`) | `APIA` §13.1: la app envía **solo** `items`; el ticket lleva `user_id` y `checkoutRef` | El prellenado del flujo de la app depende de INC-05 | WP-06; verificar el prellenado desde la cuenta en *staging*. |
| INC-22 | B | Identificadores del intento | `FLU` §11: `CheckoutAttempt` con "id del intento" e idempotency key | `APIC` EP-23: `checkoutRef` lo genera el BFF; `Idempotency-Key` la envía la app | Dos identificadores; "id del intento" ambiguo | Documentado (E39): `attemptId` = `checkoutRef`; la clave de idempotencia es aparte. |
| INC-23 | B | Patrón de slug | `OAS` Slug: `^[a-z0-9][a-z0-9._-]{0,199}$` | `APIC` EP-15 y `WC:1115`: `^[a-z0-9][a-z0-9._%-]{0,199}$` | Un slug con `%` pasa en el código y no en el esquema | Alinear el `openapi.yaml` al patrón del código. |
| INC-24 | M | Longitud del correo | Contrato: ≤ 120 (`OAS`); PQRS: ≤ 254 | WordPress estándar: `user_email` ≤ 100 (SUPUESTO, SM-04) | Un correo de 101–120 caracteres puede fallar al crear la cuenta | Fijar el máximo en 100 o verificar la columna. |
| INC-25 | B | Vida del refresh | RNF-039: "vida del refresh ≤ 30 días" | `AUTH` §3.3: 30 d de inactividad **y 90 d absolutos** | Ambigüedad sobre qué se mide | Aclarar RNF-039: 30 d de inactividad, 90 d de vida absoluta (AP-02). |
| INC-26 | B | Dónde se guardan tokens y perfil | `AUTH` §5: access, refresh y `deviceId` en Keystore/Keychain (el access "puede mantenerse en memoria"); "borrar … perfil, direcciones, pedidos en caché" | `FLU` §8: access en memoria; perfil, direcciones y pedidos **solo memoria** | Redacción distinta, efecto equivalente | Alinear `AUTH` §5 a `FLU` §8. |
| INC-27 | M | Granularidad del consentimiento | RNF-057: finalidades **por separado** (compra, soporte, mercadeo, ubicación) | `AUTH` §8.4: `document` ∈ `terms`, `privacy_policy` (y fase 2 `marketing`, `push`) | No hay registro separado de soporte o de ubicación | Ampliar el enum de `document` cuando se definan finalidades (D-12). |
| INC-28 | B | Código de validación | `FLU` §7.3: `Validation(fields)` ante 400 **o 422** | `APIA` §6.2: se usa `400` (no `422`) | La app debe tratar solo `400` como validación | Mantener `400`; ignorar `422`. |

**Verificaciones sin inconsistencia:** el esquema de sesiones (`AUTH` §8.1–8.4) coincide con `api_architecture.md` (§10.1, §12, ADR-013/014) en nombres de tablas, `UNIQUE` y retenciones; los metadatos `_ipr_checkout_ref`/`_ipr_channel` coinciden en `AUTH` §8.5, `APIA` §13.1 y `APIC` EP-24; el recuento de sedes (32 entradas = 31 operativas + 1 "próximamente"; 10 ciudades) es compatible con RF-072 (31 sedes en 9 ciudades más Cartagena), pendiente de la cifra oficial (D-07).

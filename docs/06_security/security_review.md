# Revisión independiente (adversarial) del diseño de seguridad — App móvil IPR

| | |
|---|---|
| **Fase** | SEGURIDAD — revisión independiente. **No se modificó** ningún documento revisado ni el repositorio `ipr-frontend`. |
| **Fecha** | 2026-11-18 |
| **Alcance revisado** | `06_security/security_architecture.md` (SA), `threat_model.md` (TM, 62 amenazas), `security_controls.md` (SC, 72 controles, CH-01..CH-37, NLS), `security_testing.md` (ST, 126 pruebas). Contexto: `05_api/authentication.md` (AU), `api_architecture.md` (AA), `api_contracts.md`; `03_architecture/flutter_app_architecture.md` (FA), `data_flow.md`; `00_discovery/informe_codigo_frontend.md` (COD); `project/resolucion_inconsistencias.md` (CR-001..CR-089). |
| **Código verificado (solo lectura)** | `C:\Users\empr16\ipr-frontend`: `wp-snippets/*.php`, `src/app/api/**`, `src/lib/**`, `next.config.ts`, `.github/workflows/deploy.yml`, `package.json`, `.gitignore`, `src/store/useAuthStore.ts`, `src/components/product/detail/ProductTabs.tsx`. |
| **Lo que NO se hizo** | No se abrió ningún `.env`; no se ejecutó build, `npm audit`, escáner ni prueba; no se contactó ningún sitio de producción ni servicio web. No se reproducen secretos, la IP del origen ni datos personales. |
| **Etiquetas** | **HECHO** = verificado en código con `archivo:línea` · **INFERENCIA** = deducción razonada, no comprobada en ejecución · **NO VERIFICADO** = sin evidencia en esta revisión. |

Abreviaturas de código: `AR` = `wp-snippets/ipr-auth-rest.php`; `HO` = `wp-snippets/ipr-cart-handoff.php`; `RD` = `wp-snippets/ipr-front-redirect.php`; `RU` = `wp-snippets/ipr-ruleta-midea.php`; `RS` = `wp-snippets/ipr-raspa-y-gana-samsung.php`; `CK` = `src/app/api/checkout/route.ts`; `RL` = `src/lib/rate-limit.ts`; `WC` = `src/lib/woocommerce.ts`; `CL` = `src/lib/wc/client.ts`; `DY` = `.github/workflows/deploy.yml`.

---

## 0. Resumen ejecutivo y veredicto

**Veredicto: NO está listo para aprobarse tal cual. Se puede aprobar CON CONDICIONES** si antes de la firma se aplican al diseño las correcciones C-01 a C-12 de la §7 (son cambios de documento, no de código).

Lo que el diseño hace bien (HECHO tras verificar):
- Las citas al código son **exactas en su gran mayoría**: de 41 citas comprobadas, **33 correctas, 8 parcialmente correctas** (imprecisas, incompletas o con alguna exageración) y **0 falsas**. Los cinco hallazgos H-SEC-01..05 son reales.
- La postura general (el servidor decide, la consulta autenticada es la verdad del pago, no hay secretos en la app, no hay WebView, el ticket es de un solo uso) es correcta y coherente con `resolucion_inconsistencias.md` (CR-002, CR-010, CR-016, CR-035, CR-038).

Lo que lo impide aprobar hoy:
1. **Hay huecos de cobertura en autenticación que anulan controles P0.** SC-004 y SC-005 protegen `ipr/v1/auth/*`, `wp-login.php` y `xmlrpc.php`, pero **no** el formulario de inicio de sesión de WooCommerce ("Mi cuenta") ni su página de recuperación de contraseña. Ambas siguen accesibles (`RD:58-61`, `RD:99-104`). Además, limitar `xmlrpc.php` por número de peticiones no detiene `system.multicall`. Por último, no se define **qué IP ve WordPress** detrás de Cloudflare (NT-03, NT-04).
2. **El *handoff* tiene dos defectos que el modelo no recoge:** (a) **confusión de sesión**: si el navegador ya tiene una sesión de WordPress, el ticket se aplica a esa cuenta y no a la del token (`HO:264`); (b) **fijación del checkout**: un ticket generado por un atacante es un enlace legítimo al dominio de IPR (NT-01, NT-02).
3. **La cookie "no persistente" de SC-022 no basta en Android.** Los Custom Tabs comparten el almacén de cookies de Chrome y las cookies de sesión sobreviven mientras dure el proceso del navegador (INFERENCIA). TM-012 sube de residual Bajo a Medio si no se cierra la sesión de WordPress en el servidor al volver.
4. **Faltan controles básicos de gobierno:** 2FA obligatoria en cuentas privilegiadas (wp-admin, Cloudflare, DigitalOcean, GitHub); permisos mínimos (solo lectura) de las claves `wc/v3`; política contra contraseñas comunes.
5. **Hay criterios mal formulados.** NLS-03 bloquea para siempre: exige pruebas aprobadas de controles de fase 2 o P1. ST-103 (`adb backup`) y ST-121 ("ningún WebView en el binario") **no pueden fallar** o **fallarán sin motivo**. ST-115 contradice la descarga de imágenes desde WordPress.

**Amenazas nuevas: 16** (Alto 2 · Medio 9 · Bajo 5), §2.

---

## 1. Tarea 1 — Verificación de citas

Criterio: **C** = línea y comportamiento exactos · **P** = línea correcta pero afirmación incompleta, imprecisa o exagerada · **I** = incorrecta. Se priorizaron las amenazas de riesgo Alto marcadas "EXISTE HOY".

| # | TM / SC | Cita del diseño | ¿Correcta? | Observación (HECHO salvo indicación) |
|---|---|---|---|---|
| 1 | TM-001 | `login/route.ts:6-29`; `rateLimit` solo en `pqrs:68`, `newsletter:34`; `AR:26-27`, `168-169` | C | La búsqueda de `rateLimit(` confirma solo esos dos usos. `AR:168` usa `remember => true` en `wp_signon`. |
| 2 | TM-002 | `AR:380-389`; `RD:26`, `:58`; `DY:31`, `108-114` | C | `RD:26` es un comentario y `RD:58` es el código. La IP también aparece en un comentario y en un mensaje de `DY:77` y `DY:84`; el diseño omite la 84. |
| 3 | TM-003 | `AR:202-204`, `204`, `173` | C | Cita incompleta: hay otro oráculo en `AR:295-298` (`email_exists` antes de comprobar la contraseña actual), ver NT-07. Tampoco recoge la página `lost-password` de WooCommerce. |
| 4 | TM-004 | `AR:53-68`, `15`, `17`; `auth.ts:67` | P | Además de la cabecera, la web envía el token **en el cuerpo** al cerrar sesión (`src/lib/auth.ts:134-139`). CH-03 debe probar el *logout* web, no solo el login. |
| 5 | TM-005 | `AR:37`, `45-50`, `47`; `session.ts:4`, `16` | C | — |
| 6 | TM-009 | `AR:330-332` | C | — |
| 7 | TM-010 | `AR:158-178`, `116`; `HO:263-272`, `388-390`; `CK:127` | P | La escalada es real (`HO:271` sin filtro de rol; coincide con CR-010 y CR-028). Pero decir que el login REST "no pasa por las defensas de `wp-login.php`" exagera: `wp_signon` ejecuta la cadena de filtros `authenticate` (INFERENCIA: aplican los complementos que se enganchan ahí; no aplican los que solo modifican el formulario de `wp-login.php`). |
| 8 | TM-011 | `auth/update/route.ts:42`; `session.ts:17` | P | Las citas son correctas, pero el razonamiento no. `SameSite=lax` impide **enviar** la cookie, no **fijar** una sesión: el CSRF de inicio de sesión sigue posible (NT-11). |
| 9 | TM-012 | `HO:271` | C | Coincide con CR-010. |
| 10 | TM-013 | `HO:229-231`, `235`, `390` | C | — |
| 11 | TM-014 | `wc.ts:1117-1121` | C (ruta abreviada) | El archivo real es `src/lib/woocommerce.ts`. El alias `wc.ts` está definido en AA §0 pero **no** en SA §0. Los listados filtran `status: "publish"` (`WC:429`, `536`, `753`). |
| 12 | TM-015 | `wc.ts:1075-1076`, `1083` | C | `stockQuantity: raw.stock_quantity` (`WC:1083`). |
| 13 | TM-017 | `CL:214-228` | C | La cola `waiting` no tiene tope ni tiempo de espera máximo. La concurrencia es 4 (`CL:48`). |
| 14 | TM-018 | `RL:33-39`, `55-58` | C | Toma el primer valor de `x-forwarded-for` y llama a `clear()` al superar 5.000 claves activas. |
| 15 | TM-019 | `ProductTabs.tsx:27`; `sanitize.ts:169` | P | La ruta real es `src/components/product/detail/ProductTabs.tsx`. El `sandbox` con `allow-scripts allow-same-origin` solo se aplica a iframes de YouTube/Vimeo (`sanitize.ts:167-171`, `180-181`), de origen ajeno: como indicio de XSS en el sitio está sobredimensionado. |
| 16 | TM-021 | `wc.ts:497-502`, `1133-1135` | C | Ante un fallo de WooCommerce devuelven `empty` o `null`. |
| 17 | TM-022 | `CK:110-128`; `HO:152-173` | C | — |
| 18 | TM-023 / SC-021 | `CK:165`; `HO:92`, `98`, `234`, `375-397` | P | Las líneas son correctas. "60 s + 30 s" exagera: el *transient* caduca a los 60 s (`HO:235`) y los 30 s solo afectan a la comprobación de `iat` (`HO:393`). Coincide con CR-011. |
| 19 | TM-025 | `HO:471-477` | C | — |
| 20 | TM-026 | `HO:131-149` | C | La lista de hosts admite ampliación por filtro (`HO:127`): conviene mencionarlo. |
| 21 | TM-028 | `AR:241-243` | C | `limit => -1`. |
| 22 | TM-029 | `CK:85-166`, `127`, `101-108`; `HO:234-235` | C | — |
| 23 | TM-031 | `AR:104-120`; `login/route.ts:28`; `me/route.ts:21` | C | — |
| 24 | TM-032 | `AR:335-336`, `342-346`, `198` | C | — |
| 25 | TM-033 | `AR:313-324` | P | Calificarla de "mitigada" es optimista: no hay límite de intentos sobre `current_password`, así que con un token robado se puede adivinar sin límite. Además, el correo se valida (`AR:295-298`) **antes** de comprobar la contraseña. El valor "5 fallos/h" corresponde a SC-013, no a SC-004 (igual que CR-033). |
| 26 | TM-036 | `pqrs:13-14`, `68`, `22-37` | C | — |
| 27 | TM-037 | `pqrs:55-61`, `17`, `113-114` | C | — |
| 28 | TM-042 | `.gitignore:33-35`; `next.config.ts:19` | C | — |
| 29 | TM-044 | `next.config.ts:374-382` | C | — |
| 30 | TM-045 | `pqrs:118`; `auth.ts:95` | C | — |
| 31 | TM-050 | `package.json:16-17` | C | `next 16.3.4`, `nodemailer ^10.0.3`. |
| 32 | TM-051 | `DY:3-9`, `15-16`, `44`, `48-63`, `103`, `116-124` | C | Omite que la IP usada para abrir el puerto 22 se obtiene de un servicio externo (`DY:54`), ver NT-14. |
| 33 | TM-052 | `DY:31`, `77`, `39-42`, `60-61`, `108-114` | C | La INFERENCIA de que el origen está abierto es sólida: el paso de `DY:108-114` no tiene `continue-on-error`, así que si los despliegues terminan bien, el 443 del origen respondió a un *runner* con IP arbitraria. Además usa `curl -k` (`DY:112`), es decir, no valida el certificado. |
| 34 | TM-053 | `revalidate/route.ts:44`, `47-53`, `70-92`, `126-132`, `146-148` | C | — |
| 35 | TM-054 | `AR:372-411`; `HO:254`; `RU:321-330`; `RS:522-532`; `next.config.ts:311-335`; `health/route.ts:14-18` | P | `RS` registra tres rutas (`RS:519-535`); la cita corta la tercera. El *rewrite* de `raspa-samsung` lleva las cabeceras propias del snippet según `next.config.ts:317-319`, lo que matiza "sin cabeceras de seguridad". `/api/health` sí fija `no-store`. |
| 36 | TM-055 | `RU:22`, `204`, `218-284`, `230-234`, `241-249`, `286-313`, `326-330`, `709`; `RS:206`, `317` | P | `RU:22` es un comentario. `RU:709` es un texto de la interfaz ("Un asesor de IPR validará tu factura"), **no un control**: no debe figurar en "Controles existentes". |
| 37 | TM-058 | `auth.ts:95`; ausencia de auditoría en `AR` | C | — |
| 38 | TM-060 | `HO:64-71`, `69`, `197`, `263-272`; `CK:34` | C | — |
| 39 | TM-062 | `useAuthStore.ts:32-49`; `next.config.ts:27` | C | — |
| 40 | SC-059 | `auth.ts:71-76` sin *timeout*; `CK:50`, `130` sí | C | — |
| 41 | SC-072 | `HO:141` admite `http` | C | — |

**Resultado:** 41 citas · **33 C** · **8 P** (#4, #7, #8, #15, #18, #25, #35, #36) · **0 I**. No hay afirmaciones falsas. Las exageraciones son menores (#7, #15, #18, #36). Las incompletitudes (#3, #4, #25) importan porque ocultan vectores reales (NT-07).

Comprobaciones de conteo (HECHO sobre los documentos): 62 amenazas (34 existentes + 28 nuevas); 14 de riesgo Alto, 43 Medio y 5 Bajo; 13 con residual Medio; 72 controles sin huecos de numeración; 126 pruebas. Los totales cuadran.

---

## 2. Tarea 2 — Amenazas que faltan en el modelo

P × I con el criterio de TM §1. Las severidades son propuestas.

| ID | Amenaza | Evidencia | Por qué importa | P×I | Severidad |
|---|---|---|---|---|---|
| **NT-03** | **IP del cliente en WordPress sin definir.** SC-004 propone 20 fallos/15 min **por IP** en WordPress, pero solo SC-009 dice qué IP usar cuando llama el BFF. Para el tráfico que llega a WordPress a través de Cloudflare (`ipr/v1/auth/*` heredado, `wp-login.php`, formularios de WooCommerce), `REMOTE_ADDR` es una IP de Cloudflare salvo que se restaure la IP real (INFERENCIA; configuración DESCONOCIDA). | SC-004; SC-009; CR-035/CR-075; `RL:55-58` (mismo patrón en Next) | Si WordPress cuenta por IP de Cloudflare, el límite bloquea a usuarios legítimos en masa (auto-DoS). Si lee `X-Forwarded-For`, el límite se evade. | 3×4 = 12 | **Alto** |
| **NT-04** | **Superficies de autenticación que SC-004/SC-005 no cubren:** el formulario de inicio de sesión y la página `lost-password` de WooCommerce ("Mi cuenta"), que siguen en WordPress (`RD:58-61`, `RD:99-104`), y `xmlrpc.php` con `system.multicall` (cientos de contraseñas por petición: un límite por petición no lo frena). | `RD:58-61`, `99-104`; SC-004 ("aplica a la ruta heredada `ipr/v1/auth/*` y a la nueva"); SC-005 | El *credential stuffing* se desplaza a la vía no limitada. La respuesta uniforme de la app (SC-007, CR-030) se anula si `lost-password` revela si la cuenta existe (INFERENCIA sobre el mensaje por defecto de WooCommerce; NO VERIFICADO en staging). | 3×4 = 12 | **Alto** |
| NT-01 | **Confusión de sesión en el *handoff*.** `ipr_cart_login_from_token` no hace nada si ya hay una sesión de WordPress (`HO:264`). El carrito se aplica a esa sesión y, en la web, `ipr_cart_apply_customer` guarda la facturación del ticket en el cliente **de esa cuenta** (`HO:302-320`). En Android, los Custom Tabs heredan la sesión de Chrome. | `HO:264`, `302-320`, `409-417` | El pedido queda a nombre de otra cuenta. El usuario de la app ve datos de esa cuenta en el checkout (fuga de PII). EP-24 devuelve `awaiting_order` para siempre aunque el usuario haya pagado (fraude o confusión en soporte). CR-012 reduce la sobrescritura de datos en el canal app, pero no la atribución del pedido. | 2×4 = 8 | Medio |
| NT-02 | **Fijación del checkout (ticket ajeno).** Un atacante genera en su servidor un ticket con su propia sesión o sin sesión (`CK:127`, el token es opcional) y redirige a la víctima al enlace legítimo `…/?ipr_ticket=` en menos de 60 s. La víctima ve el checkout real de IPR con el carrito y los datos que eligió el atacante, o queda conectada como el atacante. | `HO:193-241`, `375-434`; `CK:127` | Es phishing de pago sobre el dominio legítimo: la víctima paga a un pedido ajeno o deja su PII en la cuenta del atacante. El ticket no está ligado al cliente que lo pidió. | 2×4 = 8 | Medio |
| NT-05 | **Claves `wc/v3` con privilegio excesivo y paso de parámetros (*confused deputy*).** El BFF consulta `wc/v3` con claves de API (A-08, "acceso administrativo"). Ningún control ni prueba verifica que sean **solo lectura**, ni que el BFF use una lista cerrada de parámetros (`status`, `context`, `_fields`, `per_page`, `include`) al traducir filtros de la app. | `CL:291-294`; `WC:486-495`; CR-038 | Un parámetro de la app reenviado sin lista blanca a `wc/v3` con clave de administrador (p. ej. `status=any` o `context=edit`) expone borradores, metadatos o datos ajenos. Si la clave tiene escritura, un fallo del BFF permite modificar la tienda. | 2×5 = 10 | Medio |
| NT-06 | **Posible regla del WAF que permite el tráfico por User-Agent.** El comentario de `CL:39-43` indica autorizar en el WAF el UA `ipr-frontend/<versión>`, que es público en el repositorio. | `CL:39-45` (INFERENCIA: la regla real es DESCONOCIDA) | Si la regla existe, cualquiera que envíe ese UA evade el WAF y los límites del borde contra WordPress. | 2×4 = 8 | Medio |
| NT-07 | **Oráculo de correos y fuerza bruta de la contraseña actual en `auth/update`.** Con un token válido (basta registrar una cuenta propia), `email_exists` responde "Ese correo ya está registrado" **antes** de pedir `current_password` (`AR:290-298`). Con un token robado, `current_password` se puede probar sin límite (`AR:315-323`). | `AR:290-298`, `315-323` | Enumeración masiva y toma de cuenta (cambio de correo) a partir de un token robado. | 3×3 = 9 | Medio |
| NT-08 | **Rotura deliberada de la caché** con parámetros desconocidos o combinatorios (filtros, atributos, orden, parámetros basura en la URL) que generan una clave de caché nueva en el BFF (SWR) y en Cloudflare. | `WC:494-498` (la clave es la ruta completa); SC-055 solo acota `page`, `perPage` y `q` | Cada petición se convierte en un fallo de caché que llega a WooCommerce y agota la cola compartida con la web (TM-017). | 3×3 = 9 | Medio |
| NT-09 | **Sin 2FA obligatoria en cuentas privilegiadas** (administradores de WordPress, Cloudflare, DigitalOcean, GitHub y Code Snippets). SC-040 solo la exige en las tiendas. | SC-040; AT-7; los snippets se instalan desde wp-admin (`AR:6-9`) | Un administrador de WordPress comprometido equivale a ejecución de código (Code Snippets) y a todo A-06/A-07. TM-010 y TM-060 dependen de ello. | 2×5 = 10 | Medio (impacto crítico) |
| NT-10 | **Sin política contra contraseñas comunes o filtradas.** Mínimo de 8 caracteres y ninguna otra comprobación (`AR:194`; `register/route.ts:25`). | `AR:194-196` | Aumenta el éxito del *stuffing* y de la fuerza bruta lenta que no llega a activar los límites. ASVS 5.0 (capítulo de autenticación) pide comprobar contra listas de contraseñas comunes (numeración exacta NO VERIFICADA). | 3×3 = 9 | Medio |
| NT-11 | **CSRF de inicio de sesión en la web.** `/api/auth/login` y `/register` no validan `Origin` y leen el cuerpo con `request.json()` sin exigir `Content-Type` (`login/route.ts:7`, `register/route.ts:7`). Un formulario `text/plain` de otro sitio puede iniciar la sesión del atacante en el navegador de la víctima. | `login/route.ts:7`; `register/route.ts:7`; TM-011 (INFERENCIA sobre el navegador) | La víctima guarda direcciones o cédula en la cuenta del atacante. Solo afecta a la web; la app no (SC-070). | 2×3 = 6 | Medio (bajo) |
| NT-12 | **El ticket se consume antes de tiempo** por precarga (`mayLaunchUrl` o *warm-up* de Custom Tabs), escáneres o vistas previas de enlaces. | `HO:386-390` (borrado en la primera lectura) | Disponibilidad: el pago falla y el usuario llega a un carrito vacío. | 2×2 = 4 | Bajo |
| NT-13 | **Imágenes cargadas desde URL arbitrarias del contenido.** La app descarga `imageUrl` y las imágenes del HTML sin una lista cerrada de hosts que pueda verificarse. SA §8.2 la menciona, pero ningún SC ni ST la recoge. | SA §8.2; FA §17.1 (`cached_network_image`) | Seguimiento e IP del usuario hacia terceros si un editor inserta una URL externa. Contradice AC-SEC-2 y ST-115. | 2×2 = 4 | Bajo |
| NT-14 | **Cadena de confianza del despliegue.** La IP a la que se abre el puerto 22 sale de un servicio externo, validada solo por formato (`DY:54-61`). El token de DigitalOcean con escritura sobre firewalls pasa a una acción referenciada por *tag* (`DY:43-46`). `curl -k` (`DY:112`). | `DY:43-61`, `112` | Un servicio externo comprometido abre el SSH a una IP elegida por el atacante (aún hace falta la clave). Una acción comprometida puede exfiltrar el token de DigitalOcean. | 1×5 = 5 | Bajo |
| NT-15 | **El BFF no debe reenviar `Set-Cookie` de WordPress.** El login REST usa `wp_signon` con `remember => true` (`AR:168-169`), que emite cookies de autenticación de WordPress en la respuesta al servidor. | `AR:168-169` (INFERENCIA sobre el comportamiento de `wp_signon`) | Si un proxy del BFF reenvía cabeceras, la app o el navegador recibirían una sesión de WordPress de 14 días. | 1×4 = 4 | Bajo |
| NT-16 | **La respuesta idempotente guarda la `checkoutUrl` con el ticket**, que es un secreto efímero, en el almacén de idempotencia (memoria o Redis). | SC-027; CR-005 | Exposición del ticket durante la ventana de idempotencia y reenvío de un ticket ya consumido. | 1×2 = 2 | Bajo |

**Revisión de los ejemplos del encargo que ya estaban cubiertos:**

| Tema | ¿Cubierto? | Comentario |
|---|---|---|
| Enumeración en login, registro y recuperación | Parcial (TM-003) | Falta la vía WooCommerce/`wp-login` (NT-04) y el oráculo de `auth/update` (NT-07). |
| *Bypass* del límite con `X-Forwarded-For` | Sí, en la web (TM-018) | **Falta:** `CF-Connecting-IP` es igual de falsificable si el origen no está restringido. SC-006/CH-10 dependen de CH-11 y no lo dicen (coincide con CR-035). |
| *Replay* del ticket | Sí (TM-023, un solo uso) | Falta la fijación (NT-02) y la precarga (NT-12). |
| Manipulación de `checkoutRef` o del estado del pago | Sí (TM-025, TM-028) | Lo genera el BFF y se busca solo entre los pedidos del usuario; coherente con CR-009. |
| Intercepción del retorno por otra app | Sí (TM-026) | — |
| WebView, Custom Tabs y phishing | Parcial (TM-024, TM-012) | Falta NT-01 y la debilidad de la cookie en Android (§3). |
| *Scraping* o DoS del origen | Sí (TM-016, TM-017) | Falta NT-08. |
| Inyección en parámetros hacia `wc/v3` | No | NT-05. El código actual codifica con `URLSearchParams` (`WC:1117`), lo que limita la inyección sintáctica pero no el abuso de parámetros. |
| SSRF por descarga de imágenes | No aplica en el MVP (no hay *proxy*) | Variante en el cliente: NT-13. |
| *Mass assignment* | Sí (TM-032) | `ipr_cart_clean_address` acepta claves arbitrarias (`HO:103-114`), pero solo aplica las conocidas: riesgo bajo. |
| Cadena de suministro | Sí (TM-050, TM-051) | Falta NT-14 y el control de 2FA (NT-09). |
| Caché local, copias de seguridad, capturas | Sí (TM-046, TM-047) | Una prueba no es válida: ST-103 (§5). |
| Token en logs o reportes de fallos | Sí (TM-045) | Falta mencionar que las excepciones de Dio contienen `requestOptions.headers` (con `Authorization`): `PiiScrubber` debe probarlo (INFERENCIA). |
| Evasión de Cloudflare hacia el origen | Sí (TM-052) | Falta NT-06. |

---

## 3. Tarea 3 — Controles: realismo, ubicación, contradicciones, priorización y NLS

| # | Control / criterio | Problema | Tipo | Cambio propuesto |
|---|---|---|---|---|
| R-01 | SC-004 | Está pensado por ruta (`ipr/v1/auth/*` y la nueva). Deja fuera los formularios de WooCommerce, `wp-login.php` y XML-RPC (NT-04). | Incompleto | Implementarlo en el filtro `authenticate` de WordPress, que es común a todas las vías, y definir la fuente de la IP (NT-03). |
| R-02 | SC-005 | Limitar `xmlrpc.php` por petición no detiene `system.multicall`. | Ineficaz | **Bloquear `xmlrpc.php`** en Cloudflare y en WordPress, salvo que haya una dependencia justificada. |
| R-03 | SC-006 / CH-10 | La IP se toma de `CF-Connecting-IP`, que solo es fiable si CH-11 está cerrado; no se declara la dependencia. | Dependencia oculta | Criterio de cierre de CH-10: "solo después de CH-11 aprobado"; ST-062 debe falsificar también `CF-Connecting-IP` directamente contra el origen de staging. Igual que CR-035. |
| R-04 | SC-022 / CH-05 | Una cookie "no persistente" en Android **no se borra** al cerrar el Custom Tab (Chrome mantiene las cookies de sesión mientras dura su proceso; INFERENCIA, se confirma con ST-084). | Insuficiente | Para `channel=app`: cerrar la sesión de WordPress en el servidor al llegar a "pedido recibido" y al caducar (`wp_destroy_current_session` + `wp_clear_auth_cookie`), y acortar la vida de la cookie con el filtro `auth_cookie_expiration`. Valorar *Ephemeral Custom Tabs* si la versión de Chrome lo permite (NO VERIFICADO). Además, si ya hay una sesión de **otro** usuario, cerrarla antes de iniciar la nueva (NT-01). |
| R-05 | SC-011 | Usa una lista de bloqueo por capacidad. CR-028 recomienda permitir solo roles `customer`/`subscriber` **y** bloquear por capacidad. | Menos restrictivo | Adoptar CR-028 (c). |
| R-06 | SC-007 / TM-003 | Acepta RA-11 (409 en el registro) mientras CR-030 recomienda una respuesta uniforme con verificación de correo. Ninguno de los dos cubre la vía WooCommerce/`wp-login` (NT-04). | Contradicción con CR-030 | Alinear con la decisión H-03 de CR-030. Si se elige (b), CH-33 pasa de P2 a P0. En cualquier caso, normalizar los mensajes de `lost-password` de WooCommerce y de `wp-login`, o aceptarlo por escrito. |
| R-07 | SC-013 / TM-033 / TM-034 | "5 fallos/h" se atribuye a SC-004 (CR-033). No hay límite hoy en la ruta heredada `auth/update`. | Ubicación incorrecta | Corregir la referencia y añadir el límite de `current_password` también en la ruta heredada (P0, NT-07). |
| R-08 | SC-023 | No prohíbe la precarga ni el *warm-up* de la URL con ticket (NT-12). | Incompleto | Añadir: "nunca `mayLaunchUrl` ni precarga con la URL del ticket". Usar la intersección de las listas de hosts local y del servidor (CR-016). |
| R-09 | SC-027 | Guarda la respuesta con el ticket (NT-16). | Incompleto | La respuesta idempotente debe reemitir un ticket o devolver `409` si ya se consumió, y no guardar la URL. |
| R-10 | SC-055 / SC-015 | `strict` solo se aplica a los cuerpos; los parámetros de consulta no están en lista cerrada (NT-05, NT-08). | Incompleto | Validar la consulta con Zod `strict`; rechazar parámetros desconocidos con 400; normalizar la clave de caché (también en la *Cache Rule* de Cloudflare). |
| R-11 | Falta un control | Claves `wc/v3` de solo lectura, distintas de las de la web si es posible, y rotación (NT-05). | Ausente | Nuevo control **SC-073** (P0) con su prueba **ST-025**: revisar en staging el permiso de la clave (`read`) y llamar con escritura desde el BFF esperando 401/403. |
| R-12 | Falta un control | 2FA obligatoria en todas las cuentas privilegiadas y `DISALLOW_FILE_EDIT` (NT-09). | Ausente | Nuevo control **SC-074** (P0) con su prueba **ST-157** (revisión documental y de configuración). |
| R-13 | Falta un control | Lista de contraseñas comunes o filtradas en el registro y el cambio de contraseña (NT-10). | Ausente | Nuevo control **SC-075** (P1) con su prueba **ST-049**. |
| R-14 | Falta un control | Lista de hosts de imágenes en la app (NT-13). | Ausente | Ampliar SC-043 a la carga de imágenes; ajustar ST-115 a "host del *flavor* + hosts de medios declarados". |
| R-15 | Falta un control | El *handoff* no se liga al cliente que lo pidió (NT-02). | Ausente | Para `channel=app`, exigir sesión (CR-013) y no prellenar envío ni facturación desde el ticket (CR-012). En la web, evaluar exigir sesión y mostrar en el checkout "Estás comprando como <cuenta>". |
| R-16 | Falta un control | Lista cerrada de UA del WAF (NT-06). | Ausente | Que ninguna regla del WAF permita tráfico por User-Agent; si hace falta una excepción, que sea por IP del servidor o por mTLS. Añadirlo a ST-151. |
| R-17 | SC-053 | No contempla que Bot Fight Mode (plan gratuito) **no se puede excluir por ruta** con reglas (NO VERIFICADO) y podría desafiar a `/mobile/v1/*`. | Viabilidad | Confirmar el plan (AP-08) antes de cerrar CH-11; documentar la alternativa si el plan no permite excepciones. |
| R-18 | CH-14 | Agrupa más de 10 controles de la app en un único P0: el cierre es difícil de auditar. | Granularidad | Separar en criterios por control, con la ST correspondiente. |
| R-19 | P2 (CH-32..CH-37) | No tienen criterio de cierre ni fecha, aunque §3 dice "con fecha comprometida". | Falta criterio verificable | Añadir fecha y prueba. |
| R-20 | CH-31 / SC-062 | SC-062 figura "fuera del MVP" pero CH-31 es P1 para la web. | Contradicción menor | Aclarar que SC-062 es obligatorio en la web por CH-31. |

**Priorización — cambios recomendados:**

| Elemento | Prioridad actual | Propuesta | Motivo |
|---|---|---|---|
| R-01, R-02, NT-03 (SC-004 global, XML-RPC, IP real) | Parcialmente en CH-02 (P0) | **P0** explícito dentro de CH-02 | Si no, CH-02 se puede cerrar con la vía principal de *stuffing* abierta. |
| R-04 + NT-01 (cerrar la sesión de WordPress al volver; cerrar la sesión ajena) | Parcial en CH-05 | **P0** | Afecta a la app y a la web (CR-010). |
| SC-073 claves de solo lectura; SC-074 2FA | Inexistentes | **P0** | Su impacto es crítico y su coste, bajo. |
| R-07 límite de `current_password` en la ruta heredada | No previsto | **P0** | Toma de cuenta con un token robado. |
| CH-26 (secreto de *handoff* en la BD) | P1 | Mantener P1 | Correcto. |
| CH-33 verificación de correo | P2 | P0 si se elige CR-030 (b) | Coherencia con H-03. |

**Criterios de no lanzamiento (NLS):**

| NLS | Problema | Propuesta |
|---|---|---|
| NLS-03 | "Cualquier amenaza … cuyo control asociado tenga su prueba en estado Pendiente" bloquea para siempre: SC-064 no tiene prueba (fase 2), ST-145 depende de CH-31 (P1), y la regla contradice NLS-C2 (P1 abiertos con aceptación). | Limitarlo a "controles P0 y amenazas con riesgo actual Alto". |
| NLS-02 / NLS-09 | Se solapan: CH-22 ya es P0. | Fusionarlos. |
| Faltan | — | Añadir **NLS-10**: claves `wc/v3` con escritura en el BFF. **NLS-11**: cuentas privilegiadas sin 2FA. **NLS-12**: cualquier vía de autenticación de WordPress sin límite persistente (incluidas WooCommerce y XML-RPC). **NLS-13**: sesión de WordPress que persiste en el navegador del dispositivo tras el pago (ST-084/ST-085 fallidas). |
| NLS-C3 | Permite un origen no restringido "con compensatorio"; pero entonces `CF-Connecting-IP` es falsificable y SC-006 deja de funcionar. | Que el compensatorio incluya una fuente de IP no falsificable en el BFF, o pasarlo a absoluto. |

---

## 4. Tarea 4 — Mapeo MASVS v2 / API Security Top 10 (2023)

**MASVS (HECHO sobre SA §11.2):** las 24 categorías de MASVS v2.1 (STORAGE-1/2, CRYPTO-1/2, AUTH-1/2/3, NETWORK-1/2, PLATFORM-1/2/3, CODE-1..4, RESILIENCE-1..4, PRIVACY-1..4) están todas presentes. La nota de §11.1 sobre los perfiles MAS (L1/L2/R/P) es correcta en el fondo. Observaciones:

| Categoría | Observación | Corrección |
|---|---|---|
| PLATFORM-2 | ST-121 ("ningún WebView en el binario") choca con dependencias que incluyen una actividad WebView (INFERENCIA: `url_launcher_android` incluye `WebViewActivity` para el modo *in-app*). | Reformular: "ningún WebView **usado** para el checkout ni para HTML; actividades WebView de terceros no exportadas y no alcanzables". |
| STORAGE-2 | No cubre la caché del teclado ni el autocompletado en campos de PII (dirección, cédula). | Añadir un caso en ST-104/ST-105. |
| STORAGE-2 | ST-103 no verifica las reglas de copia en la nube (§5). | Cambiar la herramienta. |
| CODE-4 | No hay prueba de respuestas del servidor malformadas en el lado de la app (solo ST-088 para `checkoutUrl`). | Añadir *fuzzing* de JSON en los mapeadores (pruebas unitarias). |
| NETWORK-1 | Las imágenes usan el mismo canal pero desde otros hosts (NT-13). | Incluir los hosts de medios en ST-111/ST-115. |
| AUTH-1 | No contempla la sesión de WordPress creada por el *handoff* en el navegador del dispositivo (TM-012, NT-01). | Mapear SC-022 a AUTH-1 además de API2. |

**API Top 10 (HECHO sobre SA §11.3):** las 10 categorías tienen control y prueba. Problemas:

| Riesgo | Observación | Corrección |
|---|---|---|
| API2 | No incluye las vías de WooCommerce/`wp-login`/XML-RPC (NT-04) ni el oráculo de `auth/update` (NT-07). | Añadirlos. |
| API3 / API8 | Parámetros de consulta sin lista blanca hacia `wc/v3` (NT-05). | Añadir SC-073 y la validación de consulta. |
| API4 | No incluye TM-036 (costo de SMTP) ni la rotura de caché (NT-08). | Añadirlos. |
| API5 | El *handoff* inicia una sesión de WordPress de **cualquier** rol (TM-010); está mapeado, bien. Falta la confusión de sesión (NT-01). | Añadir NT-01. |
| API6 | No incluye la fijación del checkout (NT-02). | Añadirla. |
| API7 | "Sin amenaza activa" es razonable en el MVP. Los *rewrites* de Next hacia WordPress (`next.config.ts:321-331`) usan un destino fijo: sin riesgo de SSRF (HECHO). | Mantener ST-005 y añadir los *rewrites* a su lista. |
| API8 | Falta NT-06 (excepción del WAF por UA) y el uso de `curl -k` del CI. | Añadirlos. |
| API10 | Correcto en esencia; el *webhook* de Wompi lo consume WooCommerce, no el BFF. | — |

---

## 5. Tarea 5 — ¿Las pruebas verifican lo que dicen?

### 5.1 Pruebas que no pueden fallar, que fallarán sin motivo o que no son ejecutables como están escritas

| ST | Problema | Etiqueta | Corrección |
|---|---|---|---|
| ST-103 | `adb backup` no extrae datos de apps con `targetSdk` ≥ 31 (Android 12): la prueba **pasa siempre** y no verifica `dataExtractionRules` (nube y transferencia entre dispositivos). | INFERENCIA fuerte (comportamiento documentado de Android 12) | Usar `adb shell bmgr backupnow <paquete>` con transporte local y revisar el contenido; en iOS, una copia cifrada local. |
| ST-121 | "Ningún WebView en el binario" fallará por dependencias (p. ej. `url_launcher_android`) aunque el diseño se cumpla. | INFERENCIA | Ver §4, PLATFORM-2. |
| ST-115 | "Solo el host del *flavor*" falla por las imágenes servidas desde WordPress (NT-13), o se ignorará. | INFERENCIA | Declarar los hosts de medios. |
| ST-062 | Rotar solo `X-Forwarded-For` contra un staging sin restricción de origen deja sin probar la falsificación de `CF-Connecting-IP`; puede dar un falso "aprobado". | HECHO (diseño de la prueba) | Añadir la falsificación de `CF-Connecting-IP` directa al origen. |
| ST-143 | "Rotando IP … límite compartido intacto" se contradice: un límite por IP **debe** dejar pasar IP distintas. | HECHO | Separar en "falsificar cabeceras de IP" (debe fallar el ataque) y "reiniciar el proceso" (el contador debe sobrevivir). |
| ST-084 | Es una buena prueba que probablemente **fallará** con el control actual (R-04). | INFERENCIA | Mantenerla; corregir el control. |
| ST-043 | "Diferencia de tiempo no significativa" sin umbral ni prueba estadística: no es falsable. Solo prueba la vía de la app. | HECHO | Fijar un umbral (p. ej. diferencia de medianas < 20 ms con 200 muestras e intervalo de confianza) e incluir `lost-password` de WooCommerce, `wp-login` y `ipr/v1/auth/register` heredado. |
| ST-140, ST-156 | Criterios sin umbral ("costo medido documentado", "en el tiempo objetivo"). | HECHO | Definir umbrales (peticiones/min aceptadas, RTO por procedimiento). |
| ST-114 | `testssl.sh` contra el BFF de **staging** no verifica la configuración TLS del borde de producción. | HECHO | Revisar en modo lectura la versión mínima de TLS en el panel de Cloudflare de producción (D-16). |
| ST-022 | jadx y apktool no ven el código Dart AOT (`libapp.so`); solo sirve `strings` o herramientas específicas de Flutter. | INFERENCIA | Añadir el análisis de `libapp.so` (`strings` y una herramienta para Flutter). |
| ST-066 | Depende de que `openapi.yaml` declare `additionalProperties: false` en **todas** las respuestas (hoy hay 14 apariciones, HECHO); si falta en un esquema, la prueba no puede fallar para ese esquema. | HECHO / INFERENCIA | Exigir `additionalProperties: false` en todos los esquemas de respuesta, o comparar con una lista blanca explícita. |
| ST-004 | WPCS no tiene una regla que detecte `permission_callback => '__return_true'` (INFERENCIA). | INFERENCIA | Añadir una regla de Semgrep específica. |
| ST-031 | "Reloj controlado" no aplica a un servidor de staging real. | HECHO | Usar una vida de token configurable en staging o esperar 15 min. |
| Varias (ST-071..ST-074, ST-082, ST-125…) | El criterio "Cumple" repite el resultado esperado. Es aceptable, pero conviene un criterio medible. | HECHO | — |
| Faltan | No hay pruebas para NT-01, NT-02, NT-03, NT-04, NT-05, NT-07, NT-09, NT-10 ni NT-12. | — | Crear ST-025, ST-049, ST-093 (sesión ajena en el *handoff*), ST-094 (ticket ajeno), ST-146 (`xmlrpc multicall` y formulario de WooCommerce), ST-147 (IP que ve WordPress) y ST-157. |

### 5.2 Herramientas citadas

**No se usó búsqueda web en esta revisión.** La existencia de las herramientas se conoce por el conocimiento del revisor; **su mantenimiento actual queda NO VERIFICADO** y debe confirmarse al planificar la ejecución.

| Herramienta | Existe (conocimiento del revisor) | Mantenimiento | Observación |
|---|---|---|---|
| Burp Suite (+ Autorize), mitmproxy, k6, OWASP ZAP, Schemathesis, Semgrep, PHPCS + WPCS, gitleaks, trufflehog, OSV-Scanner, Syft, CycloneDX, MobSF, jadx, apktool, Frida/objection, testssl.sh, zizmor, WPScan, Patrol, `very_good_analysis` | Sí | NO VERIFICADO | Adecuadas para lo que se cita, salvo las observaciones de §5.1. |
| `custom_lint` (ST-001) | Sí | NO VERIFICADO; puede haber sido sustituido por los *plugins* nativos del analizador de Dart | Confirmar antes de basar reglas SAST en él. |
| Keychain-dumper (ST-101) | Sí | NO VERIFICADO; proyecto antiguo | Preferir `objection` o Frida para leer atributos del Keychain. |
| `adb backup` (ST-103) | Sí | Obsoleto para este uso | Ver §5.1. |
| "Validador de AASA" (ST-125) | Genérico | NO VERIFICADO | Nombrar la herramienta concreta o usar `swcutil` en macOS. |

---

## 6. Tarea 6 — Supuestos SUP-SEC: ¿son los más seguros y viables?

| SUP | ¿El más seguro? | ¿Viable? | Comentario y relación con CR |
|---|---|---|---|
| SUP-SEC-01 (`/app/*`) | Sí | Sí | Hace falta una página web en `/app/pedido` como respaldo si la app no está instalada o el enlace no se verifica (si no, 404). Coincide con CR-001. |
| SUP-SEC-02 (consulta = verdad) | Sí | Sí | Coincide con CR-002. |
| SUP-SEC-03 | Sí (gobierno) | Sí | CR-003 fusiona ADR-017 en ADR-008: actualizar las citas. |
| SUP-SEC-04 (iOS efímera, Android Custom Tabs + cookie no persistente) | **iOS sí; Android no** | iOS con reservas | Android: ver R-04. Hay que añadir el cierre de la sesión en el servidor. iOS: hay que probar que los flujos PSE y Nequi (salir a otra app y volver) funcionan dentro de una `ASWebAuthenticationSession` (NO VERIFICADO); en iOS < 17.4 el retorno es manual. Coincide con CR-004 y lo completa. |
| SUP-SEC-05 (`Idempotency-Key` obligatoria) | Sí | Sí | Añadir R-09 (no guardar el ticket). Coincide con CR-005. |
| SUP-SEC-06 (`X-Device-Id`) | Sí | Sí | Coincide con CR-021. |
| SUP-SEC-07 (access en memoria) | Sí | Sí | Coincide con CR-019. |
| SUP-SEC-08 (reintento dentro de la gracia) | Equilibrado: eliminar la gracia sería más seguro pero rompe la disponibilidad | Sí | Aceptable con TM-007. Coincide con CR-020 y CR-024. |
| SUP-SEC-10 (WhatsApp remoto con validación) | **No del todo** | Sí | Si la lista de números permitidos vive en WordPress, un administrador comprometido la cambia junto con el número. Lo más seguro es **lista empaquetada en la app** (y en el BFF) más el valor remoto restringido a esa lista, el mismo patrón que la intersección de CR-016. |
| SUP-SEC-11 (Cloudflare delante de WordPress) | Sí | Depende del plan (AP-08) y de CR-075 | Añadir NT-03 (restaurar la IP real en WordPress) y NT-06. |
| SUP-SEC-13 (todo lo que no es `paid` = no pagado) | Sí | Sí | Coincide con CR-007. |
| SUP-SEC-15 (sin Redis si hay un solo proceso) | Sí, condicionado | Sí | Coincide con CR-035. |
| SUP-SEC-16 (dominios por entorno) | Sí | Sí | — |

**Relación con `resolucion_inconsistencias.md`:**

- **Coincide:** CR-010 (handoff con cookie persistente y sin filtro de rol), CR-011 (vida real del ticket), CR-012 (ticket mínimo), CR-016 (intersección de hosts), CR-028 (regla de roles), CR-033 (atribución SC-004/SC-013), CR-035 (IP y procesos) y CR-038 (riesgo de la clave de administrador de `wc/v3`, aquí NT-05).
- **Completa:** CR-010 (la cookie de sesión no basta en Android; hay que cerrar la sesión en el servidor y evitar la sesión ajena, NT-01) y CR-030 (la respuesta uniforme no protege si WooCommerce o `wp-login` revelan la existencia de la cuenta, NT-04).
- **Contradice al diseño revisado, no a CR:** TM-003/SC-007 aceptan RA-11, mientras CR-030 recomienda verificación de correo en el MVP. Esta revisión apoya CR-030 (b) por el riesgo de *stuffing* (TM-001).

---

## 7. Correcciones concretas al diseño (priorizadas)

| # | Prioridad | Documento | Sección | Cambio propuesto |
|---|---|---|---|---|
| C-01 | P0 | `security_controls.md` | SC-004, SC-005, CH-02 | Aplicar SC-004 en el filtro `authenticate` (todas las vías: REST, `wp-login`, Mi cuenta de WooCommerce, XML-RPC). Bloquear `xmlrpc.php`. Añadir a CH-02 el criterio "ST-146 aprobada". |
| C-02 | P0 | `security_controls.md` / `security_architecture.md` | SC-004, SC-009, §5.4 | Definir la fuente de la IP del cliente en WordPress: IP real restaurada solo desde los rangos de Cloudflare, `X-IPR-Client-IP` solo con el secreto del BFF. Nueva prueba ST-147 (NT-03). |
| C-03 | P0 | `security_controls.md` | SC-022, CH-05 | Para `channel=app`: cerrar la sesión de WordPress en el servidor al volver o caducar; vida corta de la cookie; si hay una sesión de otro usuario, cerrarla antes. Nuevas pruebas ST-093 y ST-094 (NT-01, NT-02, R-04). |
| C-04 | P0 | `security_controls.md` | Nuevos SC-073 y SC-074, CH-12 / CH-20 | Claves `wc/v3` de solo lectura y validación de parámetros de consulta en lista cerrada; 2FA obligatoria en wp-admin, Cloudflare, DigitalOcean y GitHub, y `DISALLOW_FILE_EDIT` (NT-05, NT-09). Añadir NLS-10 y NLS-11. |
| C-05 | P0 | `threat_model.md` | §2 | Añadir NT-01..NT-16 con su riesgo. Corregir TM-011 (CSRF de inicio de sesión), TM-033 (no está mitigada: no hay límite sobre `current_password`; SC-013 en lugar de SC-004), TM-055 (quitar `RU:709` como control) y TM-012 (residual Medio hasta C-03). |
| C-06 | P0 | `security_controls.md` | §4.1 NLS-03 | Limitarlo a controles P0 y amenazas de riesgo actual Alto; fusionar NLS-02 y NLS-09; añadir NLS-12 y NLS-13. |
| C-07 | P0 | `security_testing.md` | ST-103, ST-121, ST-115, ST-062, ST-143, ST-043 | Reescribirlas según §5.1 (`bmgr`, WebView no usado, hosts de medios, falsificar `CF-Connecting-IP`, separar los casos de IP y fijar un umbral de tiempo). |
| C-08 | P0 | `security_controls.md` | SC-013, CH-04 | Límite de 5 fallos/h sobre `current_password` también en la ruta heredada `ipr/v1/auth/update`, y mover la comprobación de `email_exists` después de la reautenticación (NT-07). |
| C-09 | P0 | `security_controls.md` | SC-006 / CH-10 | El cierre depende de CH-11; si NLS-C3 se aplica con compensatorio, el BFF necesita una fuente de IP no falsificable (R-03). |
| C-10 | P1 | `security_architecture.md` | §3 SUP-SEC-10 | Lista de números de WhatsApp permitidos empaquetada en la app y en el BFF; el valor remoto se limita a esa lista. |
| C-11 | P1 | `security_controls.md` | SC-015, SC-055, SC-027, SC-023, SC-043 | Validación `strict` de los parámetros de consulta y clave de caché normalizada (NT-08); no guardar el ticket en la respuesta idempotente (NT-16); prohibir la precarga de la URL con ticket (NT-12); lista de hosts de imágenes (NT-13). |
| C-12 | P1 | `security_controls.md` | Nuevo SC-075 | Lista de contraseñas comunes o filtradas en el registro y el cambio de contraseña (NT-10). Alinear CH-33 con la decisión H-03 de CR-030. |
| C-13 | P1 | `security_controls.md` | SC-050 / CH-12 | En el CI: obtener la IP del *runner* de una fuente fiable o por contexto de GitHub, fijar `digitalocean/action-doctl` por SHA, restringir el alcance del token y quitar `-k` (NT-14). |
| C-14 | P1 | `security_controls.md` | SC-005 / ST-151 | Prohibir excepciones del WAF por User-Agent (NT-06); confirmar la compatibilidad de Bot Fight Mode con `/mobile/v1` (R-17). |
| C-15 | P2 | `security_architecture.md` | §0 | Añadir los alias `wc.ts` → `src/lib/woocommerce.ts` y `client.ts` → `src/lib/wc/client.ts`; corregir la ruta de `ProductTabs.tsx`; añadir `DY:84` a las apariciones de la IP. |
| C-16 | P2 | `security_controls.md` | SC-070 / CH-37 | Web: validar `Origin` y exigir `Content-Type: application/json` en `/api/auth/login` y `/register` (NT-11). Indicar en SC-070 que el BFF nunca reenvía `Set-Cookie` de WordPress (NT-15). |

---

## 8. Hechos, inferencias y no verificados de esta revisión

| Tipo | Contenido |
|---|---|
| **HECHO** | Las 41 citas de la §1; NT-01 (`HO:264`, `302-320`), NT-02 (`HO:193-241`, `CK:127`), NT-04 (rutas que conserva `RD`), NT-07 (`AR:290-323`), NT-08 (claves de caché en `WC`), NT-14 (`DY:43-61`, `112`), los 14 `additionalProperties: false` de `openapi.yaml`, y las contradicciones de NLS-03 y ST-143. |
| **INFERENCIA** | NT-03 (IP que ve WordPress detrás de Cloudflare), NT-06 (regla del WAF por UA), NT-11 (comportamiento del navegador), NT-15 (cookies de `wp_signon`), R-04 (persistencia de las cookies de sesión de Chrome en Android), `WebViewActivity` en `url_launcher_android`, ineficacia de `adb backup` con `targetSdk` ≥ 31, mensajes de `lost-password` de WooCommerce. |
| **NO VERIFICADO** | Mantenimiento actual de las herramientas citadas; *Ephemeral Custom Tabs*; exclusión de Bot Fight Mode por ruta; flujos PSE/Nequi dentro de `ASWebAuthenticationSession`; numeración exacta de ASVS 5.0; configuración real de Cloudflare, Wordfence, del firewall del origen y de los permisos de las claves `wc/v3`. |

---

## 9. Impactos en otros documentos

> Añadido el 2026-11-18 por el autor del diseño de seguridad al aplicar C-01..C-09 (y lo imprescindible de C-11..C-16) en `security_architecture.md`, `threat_model.md`, `security_controls.md` y `security_testing.md`. **Ninguno de los documentos de esta lista se ha modificado.** Es una lista de cambios recomendados para sus responsables. Correspondencia de identificadores: NT-01..NT-16 = TM-063..TM-078; controles nuevos SC-073 (claves `wc/v3` de solo lectura y lista cerrada de parámetros), SC-074 (2FA y cuentas privilegiadas), SC-075 (contraseñas comunes), SC-076 (vías de autenticación heredadas, XML-RPC bloqueado), SC-077 (IP real del cliente en WordPress); cambios CH-38 (P0), CH-39..CH-41 (P1); pruebas ST-161..ST-174 (los ST que proponía esta revisión se renumeraron, ver `security_controls.md` §5.2); NLS-10..NLS-13.

| # | Documento | Sección o elemento | Cambio recomendado | Origen | Prioridad |
|---|---|---|---|---|---|
| I-01 | `05_api/authentication.md` | §13 (anti fuerza bruta) | Implementar los contadores en el filtro `authenticate` (todas las vías: REST, `wp-login.php`, "Mi cuenta", XML-RPC); bloqueo por IP de 15 min (CR-033); definir la fuente de la IP del cliente (SC-077); bloquear XML-RPC; `lost-password` con límite y mensaje uniforme. | C-01, C-02 | P0 |
| I-02 | `05_api/authentication.md` | §3.7 (roles), §10/§11 (cambio de correo y contraseña) | Límite de 5 fallos/h sobre `current_password` también en `ipr/v1/auth/update` y `email_exists` después de reautenticar; lista de contraseñas comunes en registro, cambio y restablecimiento (SC-075). | C-08, C-12 | P0 / P1 |
| I-03 | `05_api/authentication.md` | Riesgos RS-xx | Añadir el reenvío de `Set-Cookie` de `wp_signon` (TM-077) y la 2FA de cuentas privilegiadas (TM-071). | NT-09, NT-15 | P1 |
| I-04 | `05_api/api_architecture.md` | §10.3 (IP del cliente, `X-IPR-Client-IP`) | Precedencia de la IP: `X-IPR-Client-IP` solo con secreto BFF; `CF-Connecting-IP` solo desde rangos de Cloudflare y solo con el origen restringido (CH-11); nunca `X-Forwarded-For`. | C-02, C-09 | P0 |
| I-05 | `05_api/api_architecture.md` | §13.1 (*handoff*), §16 (WP-06) | Para `channel=app`: cerrar la sesión de WordPress en el servidor al llegar a "pedido recibido" y al caducar; vida corta de la cookie (`auth_cookie_expiration`); cerrar la sesión de otro usuario antes de iniciar la del token; aviso "Estás comprando como <cuenta>"; nunca precargar la URL del ticket. | C-03, C-11 | P0 |
| I-06 | `05_api/api_architecture.md` | §9.2 (idempotencia), §8.1 (caché), §16 (FE-xx), §17 (RA-xx) | El almacén de idempotencia no guarda la `checkoutUrl` (reemitir o `409`); lista cerrada de parámetros de consulta y clave de caché normalizada; nuevo FE/WP para claves `wc/v3` de solo lectura (SC-073); RA nuevo para la fijación del checkout en la web (TM-064). | C-04, C-11 | P0 / P1 |
| I-07 | `05_api/api_contracts.md` y `05_api/openapi.yaml` | Parámetros de consulta de EP de catálogo y búsqueda; EP-23 (`POST /checkout`) | Declarar la lista cerrada de parámetros y `400` ante desconocidos; describir la repetición idempotente de EP-23 (ticket nuevo o `409`); exigir `additionalProperties: false` en **todos** los esquemas de respuesta (ST-066). | C-04, C-11, §5.1 | P0 / P1 |
| I-08 | `03_architecture/flutter_app_architecture.md` | §16 (configuración por *flavor*), §17.1 (`cached_network_image`), navegador seguro | Hosts de medios declarados por *flavor* y carga de imágenes solo desde ellos; intersección de hosts de checkout (CR-016); prohibir `mayLaunchUrl`/precarga con la URL del ticket; ninguna actividad WebView de dependencias exportada. | C-07, C-11 | P1 |
| I-09 | `03_architecture/data_flow.md` | Flujos 6 (autenticación) y 8a–8d (checkout) | Dibujar el cierre de la sesión de WordPress al volver o caducar y el cierre de una sesión ajena; dibujar la restauración de la IP real en WordPress. | C-02, C-03 | P1 |
| I-10 | `03_architecture/deployment_architecture.md` y `09_devops/environments.md` | Borde y origen | Restauración de la IP real en WordPress desde rangos de Cloudflare; XML-RPC bloqueado; ninguna regla del WAF por User-Agent; dependencia de SC-006 respecto de CH-11. | C-02, C-09, C-14 | P0 |
| I-11 | `03_architecture/architecture_decisions.md` | ADR-001 (enmienda CR-038), ADR-014 | Al aprobar CR-038, añadir que la clave `wc/v3` del BFF es de solo lectura (SC-073) y que los parámetros hacia `wc/v3` se fijan en servidor. | C-04 | P0 (aprobación humana) |
| I-12 | `02_requirements/non_functional_requirements.md` | RNF-042, NL-05, §5.1 (NL-xx) | RNF-042: límites en todas las vías de WordPress (incluidas WooCommerce y XML-RPC) con la IP real; nuevos criterios equivalentes a NLS-10..NLS-13; RNF de 2FA obligatoria en cuentas privilegiadas y de contraseñas comunes. | C-01, C-04, C-06, C-12 | P0 |
| I-13 | `02_requirements/acceptance_criteria.md` | AC-SEC-2, AC-045-1, AC-038-5, AC-052-x | AC-SEC-2: admitir los hosts de medios declarados; AC-045-1: límites por cuenta e IP en todas las vías (CR-033); AC-038-5: decidir CR-030; nuevos AC: sin sesión de WordPress en el navegador tras pagar y pedido siempre a nombre del usuario de la app. | C-03, C-07, NT-13 | P0 / P1 |
| I-14 | `02_requirements/functional_requirements.md` | RF-045, RF-048, RF-052 | RF-045: alcance a las vías de WordPress; RF-052: cierre de sesión tras el pago para `channel=app`; RF-048: denegación de roles también en el *handoff* (ya en CR-010/CR-028). | C-01, C-03 | P0 |
| I-15 | `02_requirements/requirements_traceability.md` | Matriz | Añadir TM-063..TM-078, SC-073..SC-077, ST-161..ST-174 y CH-38..CH-41. | Trazabilidad | P1 |
| I-16 | `08_quality/test_cases.md`, `08_quality/testing_strategy.md` | TC de autenticación (TC-031, TC-149), checkout, almacenamiento | Reflejar ST-043 (umbral de 20 ms con 200 muestras), ST-062 (falsificación directa al origen), ST-103 (`bmgr`), ST-121 (WebView usado), ST-143 (casos separados) y ST-161..ST-174. | C-07 | P1 |
| I-17 | `09_devops/ci_cd.md` | Pipeline web | IP del *runner* de fuente fiable, acción `digitalocean/action-doctl` por SHA, token de alcance mínimo, sin `curl -k`; protección de cuentas de GitHub con 2FA. | C-13, C-04 | P1 |
| I-18 | `10_operations/incident_response.md`, `monitoring.md`, `logging.md` | Manuales y alertas | Rotación de claves `wc/v3`; revocación de cuentas privilegiadas; alertas por intentos en `wp-login.php`/XML-RPC/"Mi cuenta"; registro de la IP real (no la de Cloudflare). | C-01, C-02, C-04 | P1 |
| I-19 | `06_security/privacy_assessment.md` | Minimización y terceros | Ticket de la app sin facturación ni identificación (CR-012); confusión de sesión como posible fuga de PII (TM-063); imágenes de terceros como transferencia de IP (TM-075). | C-03, NT-01, NT-13 | P1 |
| I-20 | `project/risks.md` | Registro de riesgos | Añadir los riesgos de TM-065 y TM-066 (Alto), TM-064 y TM-072 (residual Medio) y la dependencia de la aprobación de SC-073/SC-074. | C-05 | P1 |
| I-21 | `project/decisiones_pendientes.md` y `project/decisions_log.md` | Decisiones | Nuevas decisiones humanas: aprobar SC-073 (claves de solo lectura) y SC-074 (2FA obligatoria); dependencias de XML-RPC antes de bloquearlo; si la web exige sesión para el *handoff* (CR-013 para la web); CR-030 (a/b) por coherencia con SC-076. | C-04, C-01, NT-02 | P0 (bloquea NLS-10/NLS-11) |
| I-22 | `project/resolucion_inconsistencias.md` | CR-010, CR-011, CR-016, CR-033, CR-035 | Marcar como aplicadas en `06_security` las partes de esos CR que afectan a SC-021, SC-022, SC-023, TM-033/TM-034 y SC-006 (sin cambiar su resolución). | Trazabilidad | P2 |
| I-23 | `project/implementation_plan.md` y `project/roadmap.md` | Fases y estimación | Incluir CH-38 (P0) y el trabajo adicional de CH-02, CH-04, CH-05 y CH-10 (filtro `authenticate`, IP real, cierre de sesión, límite de `current_password`). | C-01..C-09 | P1 |
| I-24 | `00_discovery/informe_codigo_frontend.md` y `analisis_capa_woocommerce.md` | Citas de `next.config.ts`, `src/lib/woocommerce.ts` y `src/lib/wc/client.ts` | Esos archivos se modificaron el 2026-11-18; volver a verificar las citas de línea (en `06_security` ya se corrigieron). | Trazabilidad | P2 |

*Fin del documento.*

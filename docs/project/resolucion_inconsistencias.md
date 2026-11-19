# Resolución de inconsistencias entre documentos de arquitectura

| | |
|---|---|
| **Fecha** | 2026-11-18 |
| **Rol** | Revisor de consistencia global (arquitecto principal) |
| **Estado** | **PROPUESTA para aprobación humana.** No se editó ningún documento existente. Todos los cambios de este informe están pendientes de aprobación. |
| **Alcance leído** | `03_architecture/*` (7), `05_api/*` (4), `04_database/*` (3), `06_security/*` (5), `08_quality/testing_strategy.md`, `test_cases.md` (y `quality_metrics.md` solo para umbrales), `02_requirements/*` (4), `project/decisiones_pendientes.md`, `00_discovery/informe_codigo_frontend.md`. |
| **Código consultado (solo lectura)** | `ipr-frontend/wp-snippets/ipr-auth-rest.php`, `ipr-cart-handoff.php`; `src/app/api/{checkout,auth/*,pqrs,newsletter,revalidate}/route.ts`; `src/lib/{rate-limit,checkout-schema,session}.ts`. **No se abrió `.env`.** |
| **Regla de prevalencia** | (1) Seguridad. (2) Simplicidad. (3) Coherencia con ADR-001 y ADR-002 (aprobadas) y con el código real. Si un documento contradice al código, prevalece el código como evidencia del estado actual (`informe_codigo_frontend.md`, cabecera). |

**Abreviaturas de documentos**

| Abreviatura | Documento | Abreviatura | Documento |
|---|---|---|---|
| ADR | `03_architecture/architecture_decisions.md` | OV | `architecture_overview.md` |
| FA | `flutter_app_architecture.md` | C4 | `c4_diagrams.md` |
| CD | `component_diagrams.md` | DF | `data_flow.md` |
| DEP | `deployment_architecture.md` | ARQ | `05_api/api_architecture.md` |
| AUT | `authentication.md` | CON | `api_contracts.md` |
| YAML | `openapi.yaml` | DM | `04_database/data_model.md` |
| ER | `entity_relationship.md` | DD | `data_dictionary.md` |
| SA | `06_security/security_architecture.md` | TM | `threat_model.md` |
| SC | `security_controls.md` | ST | `security_testing.md` |
| PA | `privacy_assessment.md` | TS | `08_quality/testing_strategy.md` |
| TC | `test_cases.md` | FR | `02_requirements/functional_requirements.md` |
| NFR | `non_functional_requirements.md` | AC | `acceptance_criteria.md` |
| TR | `requirements_traceability.md` | COD | `00_discovery/informe_codigo_frontend.md` |

**Abreviaturas del código**

| Abreviatura | Archivo |
|---|---|
| `AR` | `wp-snippets/ipr-auth-rest.php` |
| `HO` | `wp-snippets/ipr-cart-handoff.php` |
| `CK` | `src/app/api/checkout/route.ts` |
| `RL` | `src/lib/rate-limit.ts` |
| `CS` | `src/lib/checkout-schema.ts` |

**Tipos de decisión**

- **T (TÉCNICA):** se resuelve por criterio de arquitectura. Si toca una ADR, la aprobación sigue siendo humana.
- **P (PRODUCTO/NEGOCIO):** la decide el humano.
- **L (LEGAL):** la valida Jurídico.

> **Notas de método.**
> 1. Los seis bloques de documentos se leyeron completos. Las citas textuales son cortas.
> 2. En la columna "Cambio exacto", el texto entre «» es el que hay que **insertar** o el **valor** que hay que **sustituir**. Antes de editar, el responsable debe localizar el pasaje con la cadena de búsqueda indicada, porque varios documentos repiten el mismo valor en más de un lugar.
> 3. **Correcciones a las premisas del encargo:**
>    - Los supuestos SUP-SEC no están definidos en `security_testing.md`, sino en **SA §3**. ST solo cita SUP-SEC-01, 03, 05, 08, 13, 15 y 16.
>    - **IN-14 no existe** en ningún documento.
>    - **SUP-SEC-09, 12 y 14 no existen.**
>    - OV y FA no tienen sección "Inconsistencias detectadas". Las IN-xx están en C4, CD, DF y DEP.

---

## 1 y 2. Inventario consolidado, opciones, recomendación y cambio exacto

Cada bloque tiene dos tablas:

- **Tabla (a):** inventario. Qué dice cada documento y la evidencia del código.
- **Tabla (b):** resolución. Opciones, recomendación, tipo y cambio exacto.

Las equivalencias con los IDs originales están en el **Anexo A**.

### Bloque A — Checkout, pago y retorno

#### A(a) Inventario

| CR | Tema | Origen | Qué dice cada documento (cita corta) | Evidencia en código |
|---|---|---|---|---|
| CR-001 | Ruta de retorno del pago | IN-01, INC-15, SUP-SEC-01, PA §7.1 | **Dicen `/pedido-confirmado`:** RF-055, FA §6.2, OV §1.4/§2.2/§10 (DA-03), COD §5.4, PA §7.1 («El enlace /pedido-confirmado…»). FA §6.1 lo envía a `/checkout/result`. **Dicen `/app/pedido?ref=&order=&status=`, con `.well-known` limitado a `/app/*`:** ARQ §13.1/§13.3, ADR-017, CON EP-23 (`returnUrlPrefix`), C4, CD, DF, DEP, SA, SC-026 y ST. DF 8c usa las dos rutas en el mismo diagrama. | La web fija `returnUrl = …/pedido-confirmado` (`CK` L111). WordPress valida **solo el host**, no la ruta (`HO` L131-149, `ipr_cart_valid_return_url`). Por eso `/app/pedido` funciona **sin cambiar** el snippet. |
| CR-002 | Mecanismo principal del retorno | IN-02, SUP-SEC-02 | ADR-001 §4 y RF-055 dicen «retorno por App Links / Universal Links». ADR-008 (OV) y ADR-017 (ARQ) dicen que la consulta al servidor es la fuente de verdad y el enlace es «pista, nunca prueba». | `HO` L471-477 añade `order` y `status` a la URL sin firmar, así que se pueden falsificar. |
| CR-003 | ADR duplicada para el resultado del pago | IN-03, SUP-SEC-03 | ADR-008 (OV §9) y ADR-017 (ARQ §18) toman la misma decisión con dos números. | — |
| CR-004 | Navegador seguro en iOS | IN-04, SUP-SEC-04 | **ADR-001 §4:** «Custom Tabs / ASWebAuthenticationSession». **ARQ §13.1:** ASWebAuthenticationSession efímera (callback https desde iOS 17.4). **OV ADR-008 y FA §6.3:** dejan la elección a SPK-01 (`url_launcher inAppBrowserView`, que es SFSafariViewController, o `flutter_web_auth_2`). **PA §7.2:** «Custom Tabs, SFSafariViewController». | — |
| CR-005 | `Idempotency-Key` | IN-05, SUP-SEC-05, SC-027 | **Opcional:** CON §1.1, CON EP-23, ARQ §9.2. **Obligatoria:** OV N-11, FA §6.3, SC-027 y SUP-SEC-05, en `/checkout`, `/me/deletion` y `/pqrs`. **ARQ §9.2** no la menciona en `/me/deletion`; CON, AUT §12.1 y YAML sí. **Alcance:** ARQ dice (usuario, clave) / (dispositivo, clave); CON §1.6 dice (usuario o dispositivo, ruta, clave). | — |
| CR-006 | Duración del sondeo (polling) | DF 8c | DF 8c dice «2, 4, 8 y 16 s» (≈30 s) y también «hasta cerca de 2 min». FA §6.3 y RNF-025 dicen «≈2 min». AC-056-5 dice «al recargar». | — |
| CR-007 | Enum `paymentState` en la app | IN-13, SUP-SEC-13 | **ARQ §13.2 y YAML:** paid, pending, failed, cancelled, refunded, unknown. **FA §6.3:** solo paid, pending, failed, cancelled, noOrder. **FA §11:** lo desconocido se muestra como «En proceso». **ARQ §5** exige `x-extensible-enum`, pero `PaymentState` no lo lleva. | — |
| CR-008 | Ubicación de `paymentState` | — (nueva) | ARQ §15, flujo C: `{state, order, paymentState}` en el nivel superior. YAML `CheckoutStatus`: solo dentro de `order`. | — |
| CR-009 | `checkoutRef` o pedido ajeno | — (nueva) | **CON EP-24 y YAML:** «una referencia ajena devuelve `awaiting_order`» (200). **AUT §14 API1 y AUT §15 prueba 8:** 404. **TC-086:** 404 en `/orders/{id}` y `awaiting_order` en `/checkout/{ref}`. **TC-150:** vacío. **TC-078:** error genérico. | — |
| CR-010 | La cookie de WordPress del handoff es persistente y no se comprueba el rol | H-SEC-01, RA-09, CH-05 frente a SC-022, SUP-SEC-04 y ARQ §13.1 | El diseño dice «cookie de WordPress no persistente para `channel=app`» y que se deniegan los roles administrativos en el handoff (SC-011). | **El código lo contradice:** `wp_set_auth_cookie($user->ID, true)` (`HO` L271), es decir, cookie «recordarme» persistente, y `ipr_cart_login_from_token` no comprueba el rol (`HO` L263-273). |
| CR-011 | Vida del ticket | DD E18, SC-021 frente a DM y ER | **DM y ER:** 60 s. **DD E18:** «+30 s de tolerancia», es decir 90 s efectivos. **SC-021:** «60 s +30 s de desfase». **RF-052 y AC-052-4:** «aprox. 60 s». | `IPR_HANDOFF_TTL = 60` (`HO` L92) es la expiración del transient. `IPR_HANDOFF_CLOCK_SKEW = 30` (`HO` L98) solo amplía la comprobación de `iat` (`HO` L393). Como el transient caduca a los 60 s, **la vida efectiva es 60 s**, salvo una caché de objetos que no respete el TTL (DESCONOCIDO). |
| CR-012 | Contenido del ticket | INC-21, PA R-P09/R-P17 frente a SC-022 y CH-05 | **ARQ §13.1:** la app envía solo `items`; el ticket lleva `user_id`, `checkoutRef` y `channel`. **PA:** «ticket sin facturación en el flujo de la app». **SC-022 y CH-05** no excluyen la facturación ni la cédula/NIT. | El ticket actual guarda `email`, `billing` (con `nationalId`), `shipping`, `orderNotes` y `authToken` (`HO` L214-232). |
| CR-013 | Compra como invitado | PA-01 (TC-061) frente a S-02 y RF-047 | **FR S-02:** el MVP exige sesión para comprar. **RF-047:** Could / fase 2. **TC-061:** lo deja abierto. **ADR-002:** incluye «cuenta». | `CK` L127: el token es opcional, de modo que hoy la web permite el handoff sin sesión (H-SEC-02). |
| CR-014 | Tiempos de espera App→BFF y BFF→WordPress | IN-09; DF 7b; ST-117 | **App→BFF:** FA §7.1 dice lectura de 10 s; ARQ §9.1 dice conexión 10 s y respuesta 15 s; RNF-021 dice 10 s de lectura y 20 s para el ticket. **BFF:** DF 7b fija un presupuesto de 6 s por endpoint, menor que `wcGet` (8 s) y que el handoff (8 s); ST-117 pide ≤ 8 s. | `WP_TIMEOUT_MS = 8000` (`CK` L50). |
| CR-015 | Estados que hacen redirigir a WordPress | — (nueva) | **OV §1:** failed, cancelled y pending no redirigen. **C4, diagrama 1:** «si no es fallido ni pendiente» (omite cancelled). **DEP 12b:** dibuja el 302 directo a la app (en realidad va al navegador). | `HO` L464: `['failed','cancelled','pending']` no redirigen. |
| CR-016 | Hosts permitidos y prefijo de retorno | — (nueva) | **FA §16:** `checkoutAllowedHosts` en la configuración local. **CON EP-23 y DF 8b:** `allowedHosts` llega del servidor. **YAML:** `AppConfig.checkout.returnPathPrefix` (ruta) frente a `CheckoutSession.returnUrlPrefix` (URI). | `HO` L122-128: lista cerrada `iprpartesyrepuestos.com` y `www.`. |
| CR-017 | ¿`on_backorder` se puede comprar? | INC-08, AP-04 | **ARQ AP-04:** «No» en el MVP. **CON `ProductSummary`:** «según AP-04». **RF-031:** «por decidir». **FA §11:** no comprable hasta PA-12. | `woocommerce.ts`:277 (según DM): `onbackorder` se muestra como agotado en la web. |
| CR-018 | `on-hold` se mapea a `pending` | SA-06, SM-07, PA-12, TC-151 | Todos lo marcan como SUPUESTO. | `HO` L464: `on-hold` **sí** redirige a la URL de retorno. **DESCONOCIDO** qué estados produce realmente el plugin de Wompi. |

#### A(b) Resolución

| CR | Opciones | Recomendación y justificación | Tipo | Cambio exacto |
|---|---|---|---|---|
| CR-001 | (a) `/pedido-confirmado` para la web y la app. (b) `/app/pedido` solo para la app; la web conserva la suya. | **(b).** Limita los App Links y Universal Links a `/app/*`, de modo que la web nunca se abre por error en la app. No exige cambiar WordPress (el código valida solo el host). Coincide con 9 de 13 documentos. | T | **FR RF-055:** sustituir «`/pedido-confirmado`» por «`https://iprpartesyrepuestos.com/app/pedido` (solo `channel=app`; la web conserva `/pedido-confirmado`)». **AC (US-055) y FR §deep links:** el mismo reemplazo. **FA §6.1 y §6.2:** la ruta interna `/checkout/result` atiende el enlace «`/app/pedido`», y en `.well-known` va «paths: `/app/*`». **OV §1.4, §2.2 y §10 (DA-03):** sustituir la ruta por «`/app/pedido`». **PA §7.1:** «El enlace `/app/pedido` solo lleva `ref`, `order` y `status`». **DF 8c, nota final:** sustituir «Enlace de /pedido-confirmado sin checkout» por «Enlace de `/app/pedido` sin `checkoutRef` conocido». **DM §11 INC-15** y **SA SUP-SEC-01:** añadir «RESUELTA por CR-001». |
| CR-002 | (a) El App Link es el mecanismo único. (b) La consulta autenticada (EP-24) es la fuente de verdad y el enlace solo la acelera. | **(b).** Los parámetros `order` y `status` no van firmados y se pueden falsificar. Además, RA-04 indica que los App Links pueden no dispararse tras una redirección. **No reabre ADR-001:** la aclara. Se propone **añadir una nota de aclaración** a ADR-001 §4, que requiere aprobación humana. | T (toca texto de ADR-001; **aprobación humana**) | **ADR, ADR-001 §Decisión punto 4:** añadir al final «**Aclaración (pendiente de aprobación, CR-002):** el App Link / Universal Link solo dispara la consulta autenticada `GET /mobile/v1/checkout/{checkoutRef}`, que es la única fuente de verdad del resultado; si el enlace no llega, la app consulta al volver a primer plano». **FR RF-055:** añadir la misma frase. |
| CR-003 | (a) Mantener las dos. (b) Fusionarlas en ADR-008 y retirar ADR-017 sin reutilizar el número. (c) Fusionarlas en ADR-017. | **(b)** (ver §3). ADR-008 es anterior y la citan FA, OV y TS. El contenido de servidor de ADR-017 (`checkoutRef`, `/app/*`, descarte de `ipr://`) se incorpora a ADR-008. | T | **ARQ §18, ADR-017:** cambiar el estado a «**Retirada — fusionada en ADR-008** (CR-003)» y dejar solo un enlace. **OV §9, ADR-008:** añadir los puntos de servidor de ADR-017. **Todas las citas** «ADR-017» en ARQ, CD, C4, DF, DM y SA pasan a «ADR-008». |
| CR-004 | (a) SFSafariViewController (`url_launcher`). (b) ASWebAuthenticationSession efímera. | **(b).** Es la que nombra ADR-001. La sesión efímera no deja cookies de WordPress en Safari (RA-09) y en iOS ≥ 17.4 recibe el callback https. En iOS < 17.4: cierre manual y consulta (CR-002). SPK-01 solo confirma el plugin (`flutter_web_auth_2` u otro), no el componente. | T | **FA §6.3 y OV ADR-008:** sustituir «`url_launcher inAppBrowserView` o `flutter_web_auth_2` según SPK-01» por «iOS: **ASWebAuthenticationSession con `prefersEphemeralWebBrowserSession`**; Android: Custom Tabs. SPK-01 elige solo el paquete». **PA §7.2:** sustituir «Custom Tabs, SFSafariViewController» por «Custom Tabs (Android) y ASWebAuthenticationSession efímera (iOS)». **DF (IN-04):** «RESUELTA por CR-004». |
| CR-005 | (a) Opcional. (b) Obligatoria en `POST /checkout`, `POST /me/deletion` y `POST /pqrs` desde la app. | **(b).** La app es el único cliente de `/mobile/v1`, así que no hay compatibilidad que romper. Evita tickets y solicitudes duplicadas. Sin la cabecera: `400 validation_failed`. Alcance único: **(usuario o, si no hay sesión, dispositivo) + ruta + clave**, como en CON §1.6. | T | **CON §1.1:** en `Idempotency-Key` sustituir «opcional» por «**obligatoria** en `POST /checkout`, `POST /me/deletion` y `POST /pqrs`». **CON EP-23, EP-12 y EP-27:** el mismo cambio. **YAML:** en el parámetro `IdempotencyKey`, `required: true` en esas tres operaciones. **ARQ §9.2:** sustituir el alcance por «(usuario, o dispositivo si no hay sesión, ruta, clave)» y añadir `/me/deletion`. **DF (IN-05):** «RESUELTA por CR-005». |
| CR-006 | (a) Solo 2, 4, 8 y 16 s. (b) 2, 4, 8 y 16 s, y luego cada 15 s hasta 120 s en total. | **(b).** Cumple RNF-025 (≈ 2 min) y define qué pasa después de 16 s. Además se consulta al volver a primer plano o al recibir el enlace. A los 120 s se muestra «pendiente» con acceso a Mis pedidos. | T | **DF 8c y CON EP-24:** sustituir «2, 4, 8 y 16 s hasta cerca de 2 min» por «2, 4, 8 y 16 s y luego cada 15 s hasta **120 s** en total; además, una consulta inmediata al volver a primer plano o al recibir el enlace». **AC-056-5:** sustituir «al recargar» por «al volver a la app y por sondeo hasta 120 s». |
| CR-007 | — | La app modela los 6 valores y **todo lo distinto de `paid` cuenta como no pagado** (SUP-SEC-13). `unknown` muestra `statusLabel`. Se añade `x-extensible-enum` a `PaymentState`. | T | **FA §6.3:** añadir los estados `refunded` y `unknown` a la máquina de estados. **FA §11:** sustituir «En proceso» por «`statusLabel` del servidor». **YAML `PaymentState`:** añadir `x-extensible-enum: true`. |
| CR-008 | (a) En el nivel superior. (b) Solo en `order`. | **(b),** como el YAML. Si no hay pedido, no hay estado de pago. | T | **ARQ §15, flujo C:** sustituir «`{state, order, paymentState}`» por «`{checkoutRef, state, order}` (con `order.paymentState`)». |
| CR-009 | (a) 404 para la referencia ajena. (b) `200 awaiting_order` con `order: null`, igual que una referencia desconocida. | **(b).** Con el diseño actual el BFF no puede distinguir «propia sin pedido» de «ajena» antes de que exista el pedido (DD E17: el intento vive solo en el ticket y en la memoria del BFF). Una respuesta idéntica para ajena y desconocida no revela nada. `/orders/{id}` ajeno sigue respondiendo **404** (BOLA). | T | **AUT §14 API1 y AUT §15, prueba 8:** sustituir «404» por «`200` con `state: awaiting_order` y `order: null`, idéntico a una referencia inexistente». **TC-086:** añadir la nota «`/orders/{id}` ajeno → 404; `/checkout/{ref}` ajeno → `awaiting_order` (CR-009)». **TC-150 y TC-078:** aclarar que son respuestas de WordPress y de la web, respectivamente. |
| CR-010 | — | **Cambio obligatorio en el código (P0).** Para `channel=app`: `wp_set_auth_cookie($id, false)` (cookie de sesión) y denegar roles con `edit_posts` o `manage_woocommerce` (CR-028) **antes** de iniciar la sesión. **Afecta también a la web:** hay que probarlo. | T | **SC-022 y CH-05:** añadir «Evidencia: `ipr-cart-handoff.php` L271 usa `remember=true`; L263-273 sin comprobación de rol». **ARQ §16 WP-06:** añadir «cambiar `remember` a `false` para `channel=app` y comprobar el rol». **TC/ST:** añadir el caso «el handoff con un usuario administrativo no crea sesión». |
| CR-011 | — | La vida del ticket es **60 s**. La tolerancia de 30 s solo cubre el desfase de reloj en la comprobación de `iat` y no alarga la vida. Hay que verificar si hay caché de objetos persistente: **DESCONOCIDO**; se obtiene con `wp cache type` o Site Health en staging. | T | **DD E18:** sustituir «+30 s de tolerancia» por «vida 60 s (transient); la comprobación de `iat` admite 30 s de desfase de reloj sin alargar la vida (`HO` L92, L98, L393)». **SC-021:** el mismo texto. |
| CR-012 | — | Para `channel=app`, el ticket lleva solo `items`, `user_id`, `checkoutRef`, `channel` y `returnUrl`. **Nunca** `authToken`, cédula/NIT ni facturación (minimización, Ley 1581). El prellenado sale de la cuenta en WooCommerce, lo que depende de CR-045. | T | **SC-022:** añadir «el ticket de la app no contiene `email`, `billing`, `shipping`, `nationalId`, `orderNotes` ni `authToken`». **CH-05:** el mismo texto. **DM §11 INC-21:** «RESUELTA por CR-012, condicionada a CR-045». |
| CR-013 | (a) Invitado en el MVP. (b) Compra solo con sesión. | **(b).** Coincide con S-02 y RF-047 (fase 2), y con la sesión que exigen ADR-001 y TC-062. Simplifica BOLA y la idempotencia. | P (confirmar) | **FR §5 PA-01:** marcar «CERRADA: sin invitado en el MVP (CR-013)». **TC-061:** sustituir el pendiente por «la app exige sesión; sin sesión, `401` y se lleva al login». |
| CR-014 | — | **App:** conexión 10 s y respuesta 15 s en general; 20 s en `POST /checkout`; 15 s en PQRS. **BFF:** presupuesto de 6 s en catálogo; **10 s en checkout**, con 8 s para el handoff sin reintento. `wcGet` dentro del presupuesto de 6 s: hay que bajar su timeout efectivo a ≤ 5 s en las rutas móviles, o documentar que el presupuesto corta antes. | T | **FA §7.1:** sustituir «recepción 10 s» por «recepción 15 s (20 s en `/checkout`)». **DF 7b:** añadir «el checkout tiene un presupuesto de 10 s (handoff 8 s)». **ST-117:** sustituir «timeout ≤ 8 s» por «handoff ≤ 8 s dentro de un presupuesto de 10 s; catálogo ≤ 6 s». **RNF-021:** alinear «lectura 15 s». |
| CR-015 | — | Manda el código. | T | **C4, diagrama 1:** sustituir «si no es fallido ni pendiente» por «si no es fallido, cancelado ni pendiente». **DEP 12b:** el 302 va «al navegador seguro, que abre el App Link». |
| CR-016 | (a) Lista solo local. (b) Lista solo del servidor. (c) Lista local por flavor **y además** la del servidor, usando la intersección. | **(c).** Un servidor comprometido no puede añadir hosts. Se unifica el nombre: `returnUrlPrefix` (URI absoluta) en ambos esquemas. | T | **FA §16:** añadir «la app usa la intersección de `checkoutAllowedHosts` (local) y `allowedHosts` (servidor)». **YAML `AppConfig.checkout`:** renombrar `returnPathPrefix` a «`returnUrlPrefix` (format: uri)». |
| CR-017 | (a) Se puede comprar. (b) No se puede comprar en el MVP. | **(b).** Es lo que hace hoy la web y es lo más simple. Que se reabra depende de negocio (PA-12). | P | **CON `ProductSummary`:** sustituir «según AP-04» por «`purchasable=false` para `on_backorder` en el MVP». **FR RF-031:** sustituir «por decidir» por «se muestra "Disponible bajo pedido" y no se puede comprar en el MVP; "Más información" lleva a WhatsApp». |
| CR-018 | — | Se mantiene como SUPUESTO hasta comprobarlo. **DESCONOCIDO:** qué estados produce Wompi (aprobado, pendiente, rechazado). **Cómo obtenerlo:** transacciones de prueba en el sandbox de Wompi, en staging (C2/D-16), registrando el `status` de WooCommerce de cada caso. | T (dato) | **ARQ §17.1 SA-06:** añadir «verificación: MED en staging, responsable QA (CR-018)». |

### Bloque B — Autenticación, sesiones y límites

#### B(a) Inventario

| CR | Tema | Origen | Qué dice cada documento (cita corta) | Evidencia en código |
|---|---|---|---|---|
| CR-019 | Dónde se guarda el access token | IN-07, INC-26, SUP-SEC-07 | **FA §8:** en memoria. **AUT §5:** «access, refresh y deviceId solo en Keystore/Keychain» (admite memoria). **OV §2.2:** «Tokens en Keychain/Keystore». | — |
| CR-020 | Qué hacer si falla el refresh | IN-08, SUP-SEC-08 | **FA §7.2:** `expire()` ante cualquier fallo. **AUT §3.4 y AC-044-7:** no borrar ante un fallo de red; reintentar con el mismo refresh dentro de la gracia. | — |
| CR-021 | Obligatoriedad de `X-Device-Id` | IN-06, SUP-SEC-06 | **CON §1.1 y YAML:** obligatoria en `/auth/*`, `/me*`, `/checkout*`, `/orders*`, `/pqrs` y `/cart/validate`. **AUT §4:** «en todas las solicitudes». **FA §7.1:** no la envía. | — |
| CR-022 | Vida de los tokens | INC-25 | **RNF-039:** access ≤ 15 min, refresh «≤ 30 días». **AUT §3.3, SA §6.1, DD:** 15 min / 30 d de inactividad / 90 d absolutos. **RF-044, AC-044-3, TC-020:** «DESCONOCIDA». | Hoy: un único token por usuario de 30 d (`AR` L37). |
| CR-023 | Reutilización del refresh | — (nueva) | **RNF-039:** «revoca la familia». **AC-044-4:** [A VALIDAR]. **AUT §3.4 y SC-002:** revoca la sesión (familia = sesión). | — |
| CR-024 | `409 refresh_in_progress` | — (nueva) | Está en **ARQ §6.3, CON EP-04, YAML y SC-002** (`SELECT…FOR UPDATE`). El algoritmo de **AUT §3.4** no tiene esa rama. | — |
| CR-025 | Plazo de la revocación | — (nueva) | **RNF-040:** «≤ 15 min (≤ vida del access)». **AC-041-2, AC-110-4 y RNF-058:** inmediata. | — |
| CR-026 | Sesiones al cambiar credenciales | — (nueva) | **RNF-040:** revoca las demás sesiones. **AC-042-6, AC-043-6, AC-104-10 y AC-105-10:** [A VALIDAR]. **CD 5d y AUT:** revoca las demás y el token web. | Hoy, un cambio sensible emite un token nuevo y cierra los demás dispositivos (`AR` L330-332). |
| CR-027 | Lista de sesiones | INC-14, AP-11 | **RNF-040 (Must):** «ver/cerrar sesiones de dispositivos y "cerrar todas"». **RF-112:** Could / fase 2. **CON §5:** `/me/sessions` en fase 2. **AUT §16 AP-11:** pregunta si «cerrar todas» cierra también la web. | — |
| CR-028 | Roles que pueden iniciar sesión | INC-19 | **ARQ §17.3 AP-03:** «Solo `customer` y `subscriber`» (lista de permitidos). **AUT §3.7 y SC-011:** denegar por capacidad `edit_posts` o `manage_woocommerce` (lista de bloqueo). | **Hoy no hay ningún filtro de rol** y `roles[]` se devuelve al cliente (`AR` L116). |
| CR-029 | Cuenta en eliminación: ¿401 o 403? | — (nueva) | **ARQ §6.3:** `403 account_locked`. **AUT §3.6, §12.1 y §13:** `401 invalid_credentials` genérico. **CON §1.4 y YAML:** mantienen 403. | — |
| CR-030 | Enumeración de cuentas en el registro y el cambio de correo | **TC-007, TC-098**, AC-038-5, AC-104-6, SC-007 frente a RA-11, ST-043, PA R-P10 | **AC-038-5 y RF-045:** «no revela de forma distinguible si la cuenta existe». **ARQ §6.3 y YAML:** `409 email_in_use`. **RA-11:** riesgo aceptado, «pendiente de firma». **SC-007:** respuestas uniformes. **RNF-053 y DN-12:** verificar el correo «antes de comprar». **RF-046:** Should / fase 2. | No hay verificación de correo (H-06). |
| CR-031 | Mecanismo de recuperación de contraseña | — (nueva) | **ADR-001 §2:** «recuperación de contraseña por API». **ADR-021:** solicitud por API (siempre 202) y restablecimiento en la página de WordPress. **RF-042, AC-042-2 y TC-027:** «API o navegador seguro». **AC-042-3:** navegador hacia `lost-password`. | `lost-password` existe en WordPress (COD §2: se conserva mi-cuenta/recuperar). |
| CR-032 | La recuperación puede devolver 429 | — (nueva) | **ARQ §10.2 y AUT §13:** «respuesta siempre 202». **CON EP-06 y YAML:** listan 429, lo que podría revelar la existencia de la cuenta con el límite por correo. | — |
| CR-033 | Umbral y alcance del bloqueo del login | TC-031, TC-149, BE-14, AC-045-1, TM-033/034 | **RNF-042:** 5 en 15 min con espera progresiva. **SC-004 y ARQ:** por cuenta 5 en 15 min (bloqueo 1-5-15-60 min); por IP 20 en 15 min. **AUT:** añade «bloqueo 15 min» por IP. **TC-031:** sin alcance; **TC-149:** «por cuenta»; **BE-14:** «por cuenta e IP». **AC-045-1:** [A VALIDAR]. **TM-033/034** atribuyen «5 fallos/h» a SC-004, pero ese valor es de SC-013. | Hoy no hay límite en las rutas de autenticación (H-04). |
| CR-034 | Límites dispersos | — (nueva) | **Solo en CON:** EP-07, 08, 11, 24, 25 y 26. **Solo en AUT §13:** `/auth/*` 60/min. **`/checkout`:** ARQ dice «dispositivo y cuenta», CON dice «usuario». **RF-045 frente a RNF-042:** RNF incluye el refresh. **AC-105-6 y AC-110-14:** lo amplían. | — |
| CR-035 | Límites en memoria frente a Redis | IN-15, SUP-SEC-15, NL-05 | **ADR-001 (Consecuencias):** «puede requerir almacén compartido (Redis)». **ARQ §3.3 y ADR-015:** sin Redis en el MVP. **NL-05:** declara absoluto el «rate limit… solo en memoria». **TS §10.1 y TC-153:** el límite del BFF va en memoria. **Supuesto SA-01 / SM-01:** un solo proceso Node. | `RL` L5-8: «Es por proceso». L38: el `Map` se vacía al llegar a 5.000 claves. L55-58: la IP sale de `x-forwarded-for`, **no** de `CF-Connecting-IP` (RA-05). |
| CR-036 | Nombre de la cabecera del secreto entre el BFF y WordPress | — (nueva) | **OV §2.2 y §2.3:** solo `X-IPR-Secret`. **C4, CD, DEP, SC-009, ST-058 y ADR-014:** `X-IPR-BFF-Secret` para `ipr/v1/m/*`. **ST-022:** busca `X-IPR-Secret`. | El handoff usa `X-IPR-Secret` (`HO` L195; `CK` L119). |
| CR-037 | ¿El BFF consume `ipr/v1` heredado? | — (nueva) | **OV §5 y §2.1:** reutiliza `ipr/v1` («proxy de autenticación hacia `ipr/v1`»). **C4 §4.1:** «el BFF usa solo `ipr/v1/m/*`» (más el handoff). **RF-038:** «ADR-001 (endpoint en `ipr/v1`)». | Las rutas heredadas devuelven `{token, user}` con un único token por usuario (`AR` L130-132, L45-50). |
| CR-038 | **Alcance de `ipr/v1/m` frente al «únicamente» de ADR-001** | — (nueva; **toca ADR-001**) | **ADR-001 §2:** ampliar `ipr/v1` «únicamente» para sesiones, revocación, eliminación de cuenta y recuperación. **CD 5c y AUT §9** añaden: register, `me`, `me/email`, `me/password`, `me/addresses`, `orders`, `orders/{id}`, `stores` y `config`, y modifican `handoff-ticket`. **ADR-018:** configuración y sedes en WordPress. **DD:** consentimientos (WP-11). **OV §2.1:** los pedidos van a `wc/v3`. | Las rutas heredadas no sirven con sesiones por dispositivo (`AR` L45-50). |
| CR-039 | Cierre de sesión sin red | — (nueva) | **DF 6d:** «borra los tokens igualmente y reintenta la revocación», lo cual es imposible sin credencial. **AC-041-6:** [A VALIDAR]. **TC-015:** «no definido». | — |
| CR-040 | Carrito al cerrar sesión y al eliminar la cuenta | AC-041-7, DN-10 | **FA §8 y DM §5.3:** se conserva en los dos casos. **RNF-062:** borrado inmediato al eliminar la cuenta. **AUT §16:** pendiente. | La web guarda el carrito en el navegador (COD §5.4). |

#### B(b) Resolución

| CR | Opciones | Recomendación y justificación | Tipo | Cambio exacto |
|---|---|---|---|---|
| CR-019 | — | El access va **solo en memoria**. El refresh y el `deviceId` van en Keychain (`AfterFirstUnlockThisDeviceOnly`) o en Keystore. Si SPK-03 obliga a persistir el access, va al mismo almacén. ADR-007 es la referencia. | T | **AUT §5:** sustituir «access, refresh y deviceId solo en Keystore/Keychain» por «refresh y `deviceId` en Keystore/Keychain; **access solo en memoria** (ADR-007, CR-019)». **OV §2.2:** sustituir «Tokens en Keychain/Keystore» por «refresh en Keychain/Keystore; access en memoria». |
| CR-020 | — | Se adopta SUP-SEC-08. **Error de red sin respuesta:** un reintento con el mismo refresh y el mismo `deviceId` dentro de 30 s, sin borrar nada. **Cualquier 401** (`unauthorized`, `refresh_token_reused`): borrar los tokens, intentar revocar sin bloquear e ir al login. **409 `refresh_in_progress`:** esperar y reintentar una vez. | T | **FA §7.2:** sustituir «`expire()`» por el texto anterior. **CD y DF (IN-08):** «RESUELTA por CR-020». |
| CR-021 | — | La app la envía **siempre**. El BFF la exige en las rutas privadas de la lista de CON. En las públicas es opcional y no forma parte de la clave de caché. **No es un secreto.** | T | **FA §7.1, interceptor 1:** añadir «`X-Device-Id` (UUID v4) en todas las solicitudes». **AUT §4:** sustituir «en todas las solicitudes» por «la app la envía siempre; el servidor la exige en las rutas listadas en CON §1.1». |
| CR-022 | — | Access de **15 min**, refresh con **30 d de inactividad y 90 d absolutos**, gracia de 30 s y rotación en cada uso. Es lo más seguro de lo propuesto y es coherente en 6 documentos. Requiere aprobar ADR-013 (AP-02/DN-04). | T (aprobación de ADR-013) | **NFR RNF-039:** sustituir «≤ 30 días» por «30 días de inactividad y 90 días de vida absoluta». **FR RF-044:** sustituir «DESCONOCIDAS (el informe propone 15 min)» por «access 15 min; refresh 30 d de inactividad / 90 d absolutos (ADR-013)». **AC-044-3 y TC-020:** sustituir «DESCONOCIDA» por esos valores. |
| CR-023 | — | Revoca **la sesión del dispositivo** (familia = sesión), registra `refresh_reused` y responde 401. | T | **AC-044-4:** quitar [A VALIDAR] y escribir «la reutilización fuera de la gracia revoca la sesión de ese dispositivo y responde `401 refresh_token_reused`». **NFR RNF-039:** sustituir «familia» por «sesión del dispositivo (familia)». |
| CR-024 | — | Se mantiene el 409 cuando el bloqueo de fila está tomado (un refresh en vuelo), y se añade esa rama a AUT §3.4. | T | **AUT §3.4:** añadir el paso «si la fila de la sesión está bloqueada por otro refresh en curso → `409 refresh_in_progress` (el cliente reintenta una vez tras 1 s)». |
| CR-025 | — | **Inmediata.** Los tokens opacos se validan contra la tabla en cada petición (ADR-013), así que es posible y es lo más seguro. | T | **NFR RNF-040:** sustituir «≤ 15 min (≤ vida del access)» por «inmediata (la siguiente petición con ese token recibe 401)». |
| CR-026 | — | Cambiar la contraseña o el correo, restablecer la contraseña y eliminar la cuenta revocan **las demás sesiones y el token web**. La sesión actual se rota (salvo al eliminar la cuenta). | T | **AC-042-6, AC-043-6, AC-104-10 y AC-105-10:** quitar [A VALIDAR] y escribir «revoca todas las demás sesiones (app y web); la sesión actual se rota». |
| CR-027 | (a) Lista y cierre por dispositivo en el MVP (subir RF-112). (b) En el MVP solo «cerrar todas», que también cierra la web; la lista queda para fase 2. | **(b).** Es lo más simple, ya está en el contrato (`logout scope=all`) y cubre el caso de seguridad (dispositivo perdido). | P | **NFR RNF-040:** sustituir «ver/cerrar sesiones de dispositivos y "cerrar todas"» por «"cerrar todas las sesiones" (app y web) en el MVP; ver y cerrar por dispositivo en fase 2 (RF-112)». **AUT §16 AP-11:** «CERRADA: sí cierra la web». **DM §11 INC-14:** «RESUELTA por CR-027». |
| CR-028 | (a) Lista de permitidos. (b) Lista de bloqueo por capacidad. (c) Las dos. | **(c).** Se permite solo si el rol ∈ {`customer`, `subscriber`} **y** no tiene `edit_posts` ni `manage_woocommerce`. Cualquier otro rol se deniega con `401` genérico y se registra `login_denied_role`. Se aplica en el login, en la validación del token y en el handoff. Es la regla más restrictiva. **DESCONOCIDO:** si hay clientes con roles de plugin (p. ej. mayoristas). Se obtiene con un recuento de usuarios por rol en staging (COD §8, pregunta 4). | T (dato) | **ARQ §17.3 AP-03 y AUT §3.7:** sustituir los dos textos por la regla (c). **SC-011:** añadir «lista de permitidos `customer` y `subscriber`, más bloqueo por capacidad». **FR RF-048 y PA-03:** «CERRADA por CR-028, pendiente de verificar roles existentes». |
| CR-029 | (a) `403 account_locked`. (b) `401` genérico. | **(b).** Un 403 específico revela el estado de la cuenta (enumeración). Las sesiones se revocan al solicitar la eliminación, así que lo natural es `401 unauthorized`. Se retira `account_locked` del catálogo del MVP. | T | **ARQ §6.3:** eliminar la fila «403 `account_locked`». **YAML `Problem.code`:** quitar `account_locked`. **CON §1.4:** sustituir «403 cuenta en eliminación» por «401 `unauthorized`». |
| CR-030 | (a) `409 email_in_use` con el riesgo RA-11 firmado y límites (registro 5/h por IP y 3/h por dispositivo). (b) Respuesta uniforme (`202` «Revisa tu correo»), sin inicio de sesión automático, y correo fuera de banda («ya tienes cuenta, recupera tu contraseña» o «activa tu cuenta»). Esto **introduce la verificación de correo en el MVP** (RF-046 pasa a Must). | **(b).** Prioriza la seguridad: el *credential stuffing* (TM-001, riesgo 16) es la amenaza principal, y la enumeración lo facilita. También cumple RNF-053 y DN-12 (verificar antes de comprar). Mismo patrón en el cambio de correo (AC-104-6): `202` y confirmación en el correo nuevo. **Coste:** WordPress tiene que enviar correo, y hay un paso más para el usuario. **Si se elige (a)**, hace falta firmar RA-11 y cambiar AC-038-5. | **P** (producto y seguridad) | **Si (b):** **AC-038-5:** quitar [A VALIDAR] y escribir «la respuesta es idéntica exista o no la cuenta (`202`); el aviso llega por correo». **ARQ §6.3 y YAML:** quitar `409 email_in_use` de `/auth/register` y `/me/email`, y añadir `202` con `{status: "pending_verification"}`. **FR RF-046:** sustituir «Should / fase 2» por «**Must / MVP**». **TC-007 y TC-098:** sustituir la nota de conflicto por la regla. **ARQ RA-11:** «MITIGADO por CR-030». **Si (a):** **AC-038-5:** sustituir el texto por «responde `409 email_in_use`; riesgo RA-11 aceptado por escrito (fecha, responsable)». |
| CR-031 | (a) API más página de WordPress (ADR-021). (b) Solo navegador hacia `lost-password`. | **(a).** Es lo que exige ADR-001 §2 («por API») y no hay que construir una pantalla de restablecimiento propia. **(b) contradice ADR-001.** | T | **FR RF-042 y AC-042-2:** sustituir «API o navegador seguro» por «solicitud por `POST /mobile/v1/auth/password/forgot` (siempre `202`); el restablecimiento se hace en la página de WordPress en el navegador seguro (ADR-021)». **AC-042-3:** limitarlo al paso de restablecimiento. **TC-027:** quitar «mecanismo abierto». |
| CR-032 | — | `429` solo por IP o por dispositivo. El límite por correo descarta en silencio y sigue respondiendo `202`. | T | **CON EP-06:** añadir «el 429 solo se emite por límite de IP o dispositivo; el límite por correo no cambia la respuesta». **YAML `/auth/password/forgot`, descripción del 429:** el mismo texto. |
| CR-033 | — | Valores de SC-004 / ARQ: **por cuenta, 5 fallos en 15 min** con bloqueo progresivo de 1, 5, 15 y 60 min; **por IP, 20 en 15 min** con bloqueo de 15 min. Se aplican **los dos alcances** y la respuesta es `429` con `Retry-After`. El valor de «5 fallos/h» corresponde a SC-013. | T | **AC-045-1:** quitar [A VALIDAR] e incluir los valores. **TC-031 y TC-149:** escribir «por cuenta **y** por IP». **ARQ §10.2:** añadir «bloqueo por IP 15 min». **TM-033/TM-034:** sustituir «SC-004» por «SC-013». **NFR RNF-042:** añadir el umbral por IP. |
| CR-034 | — | **Una sola tabla de límites**, en ARQ §10.2, con valor, ventana, alcance y almacén para cada endpoint (incluidos EP-07, 08, 11, 24, 25 y 26 y `/auth/*` en Cloudflare). CON y AUT remiten a ella. `/checkout`: 10 en 10 min **por dispositivo y por cuenta**. | T | **ARQ §10.2:** añadir las filas EP-07 60/min por usuario, EP-08 y EP-11 20/h por usuario, EP-24 30/min, EP-25 y EP-26 60/min (almacén: memoria del BFF), y `/auth/*` 60/min por IP (Cloudflare). **CON §2, columna de límites:** sustituirla por «ver ARQ §10.2». **FR RF-045:** añadir «refresh, cambio de contraseña y eliminación también están limitados (ARQ §10.2)». |
| CR-035 | (a) Redis ahora. (b) Sin Redis: los contadores de autenticación van en la base de datos de WordPress (compartida) y el resto en memoria del BFF, **solo** si se verifica un único proceso Node. | **(b) condicionada** (SUP-SEC-15). **No reabre ADR-001:** ADR-001 dice «puede requerir». **DESCONOCIDO:** el número de procesos. Se obtiene revisando la configuración del servicio en el servidor de DigitalOcean (systemd o PM2, modo clúster). Si hay más de uno, Redis pasa a P0. **Corrección obligatoria del código:** usar `CF-Connecting-IP` (solo si el origen está restringido a Cloudflare, CR-075) y LRU en lugar de `clear()`. | T (dato) | **TS NL-05:** sustituir «rate limit… solo en memoria» por «límites de **autenticación** solo en memoria del BFF (deben estar en la BD de WordPress)». **ARQ ADR-015:** añadir la condición «verificar SA-01; si hay más de un proceso, Redis pasa a P0». **ARQ RA-05:** añadir «Evidencia: `rate-limit.ts` L38 y L55-58». **DEP (IN-15):** «RESUELTA por CR-035». |
| CR-036 | — | **Dos secretos distintos:** `X-IPR-Secret` (handoff, existente) y `X-IPR-BFF-Secret` (`ipr/v1/m/*`, nuevo, ADR-014). | T | **OV §2.2 y §2.3:** añadir «y `X-IPR-BFF-Secret` para `ipr/v1/m/*` (ADR-014)». **ST-022:** sustituir «`X-IPR-Secret`» por «`X-IPR-BFF-Secret` (y `X-IPR-Secret` solo en el handoff)». |
| CR-037 | — | El BFF usa solo `ipr/v1/m/*` y `ipr/v1/handoff-ticket`. **No** usa `ipr/v1/auth/*` heredado (un único token y `?token=`, H-01 y H-03). | T | **OV §5:** sustituir «reutiliza parcialmente la autenticación de `ipr/v1`» por «la autenticación móvil usa las rutas nuevas `ipr/v1/m/*`; las heredadas siguen solo para la web». **OV §2.1:** sustituir «proxy de autenticación hacia `ipr/v1`» por «proxy hacia `ipr/v1/m/*`». **FR RF-038:** sustituir «(endpoint en `ipr/v1`)» por «(BFF → `ipr/v1/m/register`)». |
| CR-038 | (a) Enmendar ADR-001 §2 para incluir registro, perfil, direcciones, pedidos, consentimientos, configuración y sedes. (b) Mantener ADR-001 y que el BFF lea pedidos y clientes con la clave de `wc/v3`, filtrando por `customer_id`. | **(a). REABRE ADR-001 (enmienda acotada; lo justifica la seguridad).** Con (b) el BFF usaría una clave con privilegios de administrador sobre todos los pedidos y la autorización dependería de un filtro del BFF: riesgo BOLA (TM-028, riesgo 12). Con (a), WordPress valida la sesión y el dueño. Las rutas heredadas no sirven con sesiones por dispositivo. El principio de ADR-001 (BFF en Next.js, la app nunca toca WordPress) **no cambia**. | **T con aprobación humana obligatoria (enmienda de una ADR aprobada)** | **ADR, ADR-001 §Decisión punto 2:** añadir «**Enmienda propuesta (CR-038, pendiente de aprobación):** la ampliación se hace bajo `ipr/v1/m/*`, accesible solo para el BFF (ADR-014), e incluye además registro con consentimiento, perfil, correo, contraseña, direcciones, pedidos del usuario, configuración remota y sedes (ADR-018), porque requieren validar la sesión por dispositivo en WordPress». **OV §2.1:** sustituir «pedidos → `wc/v3`» por «pedidos → `ipr/v1/m/orders`». **`decisiones_pendientes.md`:** añadir la entrada «D-01 enmienda (CR-038)». |
| CR-039 | (a) Borrar todo y perder la revocación. (b) Borrar el access, guardar el refresh en un espacio seguro «pendiente de revocación» y llamar a `POST /auth/logout` con el refresh en el cuerpo al volver la red. | **(b).** Mientras tanto la app ya está desconectada localmente. Requiere que EP-05 acepte el refresh en el cuerpo como credencial alternativa. | T | **DF 6d:** sustituir «borra los tokens igualmente y reintenta la revocación» por «borra el access y el perfil, mueve el refresh a `pendingRevocation` (almacén seguro) y llama a `POST /auth/logout` con `{refreshToken}` al recuperar la red». **CON EP-05 y YAML:** añadir el cuerpo opcional `{refreshToken}`. **AC-041-6 y TC-015:** el mismo comportamiento. |
| CR-040 | Al cerrar sesión: conservar o borrar. Al eliminar la cuenta: conservar o borrar. | **Cerrar sesión: conservar** (no hay PII y es lo que hace la web). **Eliminar la cuenta: borrar** (RNF-062; es lo que espera el titular y es más simple de explicar). | P | **FA §8 y DM §5.3:** sustituir «carrito… se conservan» (eliminación de cuenta) por «al eliminar la cuenta se borran el carrito y la caché personal; la caché pública se conserva». **AC-041-7:** quitar [A VALIDAR] y escribir «el carrito se conserva». |

### Bloque C — Modelo de datos y nombres de campos (las 28 INC y otras nuevas)

> **Regla general recomendada (T):** el contrato público (`/mobile/v1`) usa **camelCase**. El BFF traduce desde los nombres de WordPress y de WooCommerce. Los nombres heredados no cambian. Todos los mapeos van en DM, anexo A.1. Es la resolución que el propio DM propone para la mayoría de las INC.

#### C(a) Inventario y resolución de las 28 INC

| CR | INC | Conflicto (resumido, con fuente) | Evidencia en código | Recomendación | Tipo | Cambio exacto |
|---|---|---|---|---|---|---|
| CR-041 | INC-01 | Código: `username`. Contrato: `login` (YAML `LoginRequest`, CON EP-03). | `AR` L159 | El BFF traduce `login` a `username`. | T | **DM §11 INC-01:** «RESUELTA (CR-041); mapeo en el anexo A.1». |
| CR-042 | INC-02 | Código: `first_name`/`last_name`, sin aceptación. Contrato: `firstName`/`lastName` + `acceptance`. | `AR` L182-183 | Mapeo en el BFF. WP-11 escribe `ipr_consents` al dar de alta. | T | **DM INC-02:** «RESUELTA (CR-042)». |
| CR-043 | INC-03 | Código: `{token, user}`. Contrato: `{session{…}, user}`. | `AR` L130-132 | Rutas nuevas `ipr/v1/m/*`; las heredadas no cambian (CR-037). | T | **DM INC-03:** «RESUELTA (CR-037/043)». |
| CR-044 | INC-04 | Tres convenciones para la dirección: `address_1`/`state`/`country`/`email` (perfil); `address1`/`department`/`nationalId` (ticket); YAML sin `email` ni `country`. | `AR` L335-336; `HO` L309-341. **El checkout de WooCommerce usa los campos `billing_national_id` y `cedula_nit_ship`** (`HO` L323, L341). | Contrato camelCase (`address1`, `department`, `nationalId`). `country` es fijo `CO` y no viaja. **Pista para la clave DESCONOCIDA de la cédula:** `billing_national_id` (facturación) y `cedula_nit_ship` (envío). Hay que confirmar en staging si se persisten en usermeta. | T | **DM INC-04 y DD E02:** sustituir «clave de meta DESCONOCIDA» por «candidatas `billing_national_id` / `cedula_nit_ship` (campos del Checkout Field Editor, `HO` L323/L341); persistencia en usermeta por verificar». |
| CR-045 | INC-05 | **AUT §12.2:** `usermeta` `billing_*`/`shipping_*`. **Código:** un arreglo en el meta `billing`/`shipping`. **RF-054 y ARQ §13.1:** «WooCommerce prellena desde la cuenta». | `AR` L106-107 y L340-359 guardan `get/update_user_meta($id,'billing')`, un **meta propio**, no las claves `billing_first_name`… que lee WooCommerce. Por eso hoy la web manda la facturación en el ticket. | **Alto impacto.** WP-08 debe escribir con los setters de `WC_Customer` (`billing_*`), leer el meta `billing` heredado como respaldo y migrarlo. Sin esto, CR-012 (ticket sin facturación) rompe el prellenado. | T | **AUT §12.2:** añadir «Hoy el perfil se guarda en el meta propio `billing`/`shipping` (arreglo; `AR` L340-359), que WooCommerce no lee; WP-08 migra a `WC_Customer` (CR-045)». **DM INC-05:** «RESUELTA (CR-045)». |
| CR-046 | INC-06 | Código: `id: string`. Contrato: `integer`. | `woocommerce.ts`:262 (según DM) | Entero en el contrato. | T | **DM INC-06:** «RESUELTA». |
| CR-047 | INC-07 y DD-D8 | YAML `Price.amount: number`. Código: `Number()` (flotante). OV T-04 y FA §11: entero. ER: `decimal`. DD: `number`. `price_snapshot`: `int`. | — | **Entero de pesos colombianos (COP)** en el contrato (`type: integer`) y `Money` entero en la app. El ER y el DD se alinean (DM-05). Evita errores de redondeo en los importes. | T | **YAML `Price.amount`, `regularAmount` y los totales de `Order*`:** sustituir `type: number` por `type: integer` con la descripción «COP, IVA incluido, sin decimales». **ER:** sustituir `decimal` por `int` en precio y totales. **DD E15/E16:** sustituir `number` por «entero COP». |
| CR-017 | INC-08 | Ver el bloque A. | | | | |
| CR-048 | INC-09 | Código: `price`, `formattedPrice`, `regularPrice`. Contrato: un objeto `Price`. | MD | Mapeo en `dto.ts`; `formattedPrice` se descarta (la app da formato con `intl`). | T | **DM INC-09:** «RESUELTA». |
| CR-049 | INC-10 | Marca como cadena con cuatro fuentes no alineadas (WCA §6) frente a `{name, slug\|null}`. | `brands.ts`:60-92 (según DM) | `slug = null` si la marca sale de una heurística. **Negocio** decide la fuente canónica (AP-05/DM-09). | P (catálogo) | **CON §6:** añadir «AP-05: fuente canónica de la marca, responsable Catálogo (CR-049)». |
| CR-050 | INC-11 | El listado usa la primera categoría y la ficha la última. El contrato no tiene «principal». | `woocommerce.ts`:274 | El contrato no declara categoría principal y la app no la infiere. | T | **DM INC-11:** «RESUELTA». |
| CR-051 | INC-12 | Código: `imageUrl` string (`""`). Contrato: `ImageRef{url, alt, width, height}`. | `woocommerce.ts`:228 | `alt = name`, `width`/`height = null` en el MVP. Sin imagen: `image = null`, nunca `""`. DN-03 para variantes. | T | **YAML `ImageRef`:** `width` y `height` `nullable`. **DD E14:** «sin imagen → `null`». |
| CR-052 | INC-13 | Código: `orderNumber`, `date` sin zona, `items{name, qty, total}`. Contrato: `number`, `createdAt` ISO con zona, `productId`, `sku`, `imageUrl` y totales. | `AR` L245-266 | WP-07 (`ipr/v1/m/orders`) amplía el mapeo. Zona horaria del sitio: **DESCONOCIDO**; se obtiene con `wp option get timezone_string` en staging. | T (dato) | **DM INC-13:** añadir «Zona: verificar `timezone_string` (CR-052)». |
| CR-027 | INC-14 | Ver el bloque B. | | | | |
| CR-001 | INC-15 | Ver el bloque A. | | | | |
| CR-054 | INC-16 | FA §6.1: `/orders/:number`. YAML: `/orders/{orderId}` (entero). `id` puede ser distinto de `number`. | `HO` L473 usa `get_order_number()` (puede diferir del id con plugins) | **`id` en rutas y API; `number` solo para mostrar.** El enlace de retorno lleva `order=<number>`, así que la app nunca lo usa como clave: usa `checkoutRef` (CR-002). | T | **FA §6.1:** sustituir «`/orders/:number`» por «`/orders/:id`». **DM INC-16:** «RESUELTA». |
| CR-055 | INC-17 | Campos de PQRS en español en el código y en inglés en el contrato. El teléfono es obligatorio en el esquema pero opcional en la plantilla. | `pqrs/route.ts`:22-37, :58 | Mapeo en el BFF. **Negocio** decide si el teléfono es obligatorio (se recomienda opcional: minimización). | P | **CON EP-27 y YAML `PqrsRequest`:** `phone` opcional si se aprueba. |
| CR-056 | INC-18 | `acceptsDataPolicy` es obligatorio en el contrato pero no se persiste; el código de PQRS no tiene aceptación (el boletín sí, `consent`). | `pqrs/route.ts`; `newsletter/route.ts`:30 | Guardar la evidencia de la autorización (fecha, versión de la política, canal) en `ipr_consents` o en un registro equivalente **sin el cuerpo del mensaje**. Requiere `user_id` nulo para visitantes (DM-04). | **L** | **CON EP-27:** sustituir «no se persiste» por «se registra la evidencia de la autorización (versión, fecha, canal) — pendiente de validación jurídica (J-10)». **DD E07:** `user_id` nulo para PQRS de visitantes. |
| CR-028 | INC-19 | Ver el bloque B. | | | | |
| CR-057 | INC-20 | Sedes: `phone`, `celular`, `celularSecundario`… frente a `phones[]{type, display, dial}`; `mapsQuery` no existe. | `sedes-data.ts`:2-37 (según DM) | Mapeo en el BFF; `mapsQuery` se compone con dirección y ciudad. **Añadir el tipo `mobile_secondary`** para no perder el segundo celular. | T | **YAML, enum de teléfono de `Store`:** añadir «`mobile_secondary`». **DM INC-20:** «RESUELTA». |
| CR-012 | INC-21 | Ver el bloque A. | | | | |
| CR-058 | INC-22 | FA: `CheckoutAttempt` con «id del intento». CON: `checkoutRef`. | — | `attemptId = checkoutRef`; `Idempotency-Key` es un valor aparte. | T | **FA §11:** sustituir «id del intento» por «`checkoutRef` (generado por el BFF)». |
| CR-059 | INC-23 | YAML `Slug` sin `%`. CON EP-15 y el código con `%`. El YAML es incoherente consigo mismo (la ruta admite `%`). | `woocommerce.ts`:1115 | Alinear el esquema `Slug` con el código (`[a-z0-9._%-]`), porque WooCommerce codifica las tildes con porcentaje. | T | **YAML `components.schemas.Slug.pattern`:** sustituir por «`^[a-z0-9][a-z0-9._%-]{0,199}$`». |
| CR-060 | INC-24 | Correo ≤ 120 (contrato); ≤ 100 en `wp_users.user_email` (SUPUESTO SM-04); PQRS ≤ 254. | `CS` L101: `.max(120)` en el correo del checkout | **100** para el correo de la cuenta (registro y cambio). 254 en PQRS. Hay que verificar la columna con `DESCRIBE wp_users` en staging. | T (dato) | **YAML `RegisterRequest.email` y `/me/email`:** `maxLength: 100`. **DD E01:** «verificar con `DESCRIBE` (CR-060)». |
| CR-022 | INC-25 | Ver el bloque B. | | | | |
| CR-019 | INC-26 | Ver el bloque B. | | | | |
| CR-061 | INC-27 | RNF-057: finalidades por separado (compra, soporte, mercadeo, ubicación). AUT §8.4: `document` ∈ `terms`, `privacy_policy`. | — | Ampliar el enum con las finalidades que defina Jurídico (D-12). En el MVP como mínimo `terms`, `privacy_policy` y `pqrs`. | **L** | **AUT §8.4 y DD E07:** añadir «enum sujeto a D-12/J-01; valor `pqrs` propuesto (CR-056/061)». |
| CR-062 | INC-28 | FA §7.3: `Validation` ante 400 o 422. ARQ §6.2: solo 400. | — | Solo 400; el 422 nunca se emite. | T | **FA §7.3:** sustituir «400/422» por «400». |

#### C(b) Otras contradicciones del modelo de datos (nuevas)

| CR | Tema | Conflicto | Recomendación | Tipo | Cambio exacto |
|---|---|---|---|---|---|
| CR-063 | Nombres de los estados de stock | OV T-05: `instock`/`outofstock`/`onbackorder`. Contrato: `in_stock`/`out_of_stock`/`on_backorder`, y en la línea del carrito también `price_on_request` y `not_found`. | Añadir una tabla de equivalencias WooCommerce → contrato. | T | **ARQ §13 (o CON §6):** añadir la tabla «`instock`→`in_stock`; `outofstock`→`out_of_stock`; `onbackorder`→`on_backorder`; precio 0 → `price.status=on_request`». |
| CR-064 | Erratas del modelo | DD E17 remite a «E40» (debería ser **E39**). ER usa `refresh_expires_at` y también `refresh_token_expires_at`. `refreshTokenExpiresAt` está «en memoria» (DD E36), pero el refresh persiste. La tabla aparece como `wp_ipr_auth_sessions` (ARQ) y como `{prefix}ipr_auth_sessions` (AUT, DM). El ejemplo `completeBy` no descuenta el festivo del 8 de diciembre. | Corregir las erratas. `refreshTokenExpiresAt` se persiste junto al refresh. Se usa `{prefix}`. | T | **DD E17:** sustituir «E40» por «E39». **ER, diagrama 1:** sustituir `refresh_expires_at` por `refresh_token_expires_at`. **DD E36:** sustituir «Memoria» por «flutter_secure_storage (junto al refresh)». **ARQ:** sustituir `wp_ipr_` por `{prefix}ipr_`. **DD, ejemplo de `completeBy`:** «2026-12-10T23:59:59-05:00». |
| CR-065 | PII en una caja Hive sin cifrar | DM §5.3, ER §5 y DD (Parte III): las cajas Hive no tienen PII. Pero E39 (`checkoutRef` y el intento) está clasificado como «S (indirecto)» y es personal. | Guardar el intento de checkout en `flutter_secure_storage` (es pequeño). Hive queda sin PII. | T | **DM §5.3 y DD E39:** sustituir «Hive `cache`» por «flutter_secure_storage» para el intento de checkout. |
| CR-066 | Seudónimo en la idempotencia | DM §4 y ER: «seudónimo». DD E31, ejemplo: `user:1042`. | Usar `userRef` (HMAC-SHA256 truncado). | T | **DD E31, ejemplo:** sustituir «`user:1042 POST /checkout`» por «`u:<userRef> POST /checkout`». |
| CR-067 | Dónde vive el intento antes de que exista el pedido | DD E17: en el ticket y en la memoria del BFF. DM §3.1 y ER §1.1: en la sesión de WooCommerce. | Describir la secuencia: memoria del BFF y ticket → sesión de WooCommerce (tras consumir el ticket) → meta `_ipr_checkout_ref` del pedido. | T | **DD E17:** añadir esa secuencia. |

### Bloque D — Contrato de API y cliente

| CR | Tema | Conflicto (fuentes) | Recomendación | Tipo | Cambio exacto |
|---|---|---|---|---|---|
| CR-068 | `minSupportedVersion` y 426 | **ARQ §5:** `minSupportedVersion` es un «aviso suave» y el 426 queda para un «mínimo duro» distinto. **CON EP-01:** por debajo del mínimo → 426; `recommendedVersion` es el aviso. **ARQ §8.1:** el BFF ignora las cabeceras en los endpoints públicos cacheables. **YAML:** exige `X-App-Version` y el 426 también en ellos. | Semántica de CON: `minSupportedVersion` → bloqueo (426 o pantalla `/update-required`); `recommendedVersion` → aviso. El 426 **solo** en endpoints no cacheables (`/auth/*`, `/me*`, `/checkout*`, `/orders*`, `/cart/validate`, `/pqrs`). En los públicos, la app se bloquea sola al leer `/config`. | T | **ARQ §5:** sustituir «(aviso suave)» por «(por debajo → bloqueo; `recommendedVersion` = aviso)». **YAML:** quitar `426` y `X-App-Version required` de las operaciones públicas cacheables. |
| CR-069 | El YAML no lleva los errores comunes | **CON §1.4:** son comunes a todos los endpoints. **YAML:** 413 y 415 solo en register; 500 solo en register y login; 426 parcial; 429 falta en logout y `/orders`. EP-23: CON sin 403 ni 409. EP-11: 404 frente a 400 para un tipo inválido. `Accept-Language`, `Deprecation` y `Sunset` no están en el YAML. | **El YAML es la especificación formal** (contra él se hacen las pruebas de contrato): añadir respuestas comunes reutilizables (`components.responses`) en todas las operaciones. EP-11 con tipo inválido → 400. | T | **YAML:** crear `components.responses.{BadRequest, PayloadTooLarge, UnsupportedMediaType, TooManyRequests, Internal, BadGateway, ServiceUnavailable, GatewayTimeout}` y referenciarlas en las 27 operaciones. Añadir las cabeceras `Accept-Language`, `Deprecation` y `Sunset`. **CON EP-23:** añadir 403 y 409. **CON EP-11:** sustituir 404 por 400. |
| CR-070 | Campos obligatorios de `Address` | **CON EP-11:** «`Address` completo» y teléfono obligatorio en facturación. **YAML `AddressInput`:** 5 obligatorios. **`Address` de salida:** exige `company`, `address2` y `postcode` no nulos. | `AddressInput` + regla «`phone` obligatorio si `type=billing`» (en la descripción y validada en el BFF). En la salida, los campos opcionales pueden ser una cadena vacía. | T | **YAML `AddressInput`:** añadir la descripción de la regla condicional. **YAML `Address`:** `company`, `address2` y `postcode` no obligatorios. |
| CR-071 | `webUrl` obligatoria | **ARQ §4:** «las URLs web no son contrato». **YAML:** `ProductDetail.webUrl` obligatoria. | `webUrl` opcional e informativa (solo para compartir). | T | **YAML `ProductDetail.required`:** quitar `webUrl`. |
| CR-072 | La caché de idempotencia guarda `checkoutUrl` | **ARQ §3.2:** el BFF «no guarda tokens». **ARQ §12:** nunca se registra `checkoutUrl`. La caché de 60 s guarda la respuesta con el ticket. | Se permite en memoria durante ≤ 60 s y nunca en logs. Se aclara el texto. | T | **ARQ §3.2:** añadir «excepto la respuesta de `/checkout` en la caché de idempotencia (memoria, ≤ 60 s, nunca en logs)». |
| CR-073 | Taxonomía de errores de la app | **IN-12:** no hay tipo para 502 ni 504. **FA §7.3:** cualquier 403 → «No tienes permiso», pero `/me/password` devuelve `403 current_password_invalid`. Los 401 no se distinguen (`invalid_credentials` frente a `refresh_token_reused`). | La app mapea por **`Problem.code`** y no solo por el HTTP. Se añaden `UpstreamBadResponse` y `UpstreamTimeout`, o se agrupan en `ServiceUnavailable` con reintento. | T | **FA §7.3:** añadir «el mapeo usa `code` (RFC 9457); 502/504 → `ServiceUnavailable` reintentable; `current_password_invalid` → `Validation(currentPassword)`; `refresh_token_reused` → cierre de sesión forzado». |
| CR-074 | Origen del número de WhatsApp | **IN-10:** FA §16 lo pone en la configuración local; CON lo da remoto (EP-01, EP-22). | Remoto con validación de formato y lista permitida en el BFF, más un número nacional empaquetado como respaldo (SUP-SEC-10). | T | **FA §16:** sustituir «`supportWhatsApp` en `config/<flavor>.json`» por «respaldo empaquetado; la fuente es `contact.whatsapp` de `GET /config`». |
| CR-075 | ¿Hay Cloudflare delante de WordPress? | **IN-11.** PA §1 y §2.2 lo dan como hecho. SA lo trata como supuesto (SUP-SEC-11). H-SEC-03: hay indicios de que el origen está abierto. | **DESCONOCIDO.** Cómo obtenerlo (con autorización D-16): cabeceras `cf-ray` y `server` en una petición a `wp-json`, resolución DNS, y revisar si el firewall del origen solo admite rangos de Cloudflare. Mientras tanto se aplica la opción segura (SUP-SEC-11). | T (dato) | **PA §1 y §2.2:** sustituir «hecho» por «SUPUESTO (SUP-SEC-11), por verificar (CR-075)». |
| CR-076 | Dominios y `.well-known` de staging | **IN-16.** FA §6.2 da dominios propios a dev y staging; ARQ §13.3 solo describe producción. | Un dominio por entorno; `deep_link_policy` acepta solo el host del flavor (SUP-SEC-16). El dominio de staging es **DESCONOCIDO** (C2). | T (dato) | **ARQ §13.3:** añadir «staging: host propio con su `assetlinks.json` y AASA (CR-076); dominio pendiente de C2». |
| CR-077 | Tamaño de página | **RF-011:** DESCONOCIDO. **RNF-011:** «página de 20». **ADR-020 y CON:** {12, 24, 48}, por defecto 24. **TC-118:** 24. **AC-011-2:** cita «D-05» (que es la decisión de stock). | Por defecto **24** (ADR-020). | T | **FR RF-011:** sustituir «DESCONOCIDO» por «24 por defecto; {12, 24, 48} (ADR-020)». **NFR RNF-011:** sustituir «página de 20 productos» por «página por defecto (24 productos)» y mantener ≤ 50 KB [A VALIDAR MED]. **AC-011-2:** sustituir «D-05» por «ADR-020». |
| CR-078 | Sin conexión | **RNF-020 (Must):** lo ya visto se abre sin red. **AC-009-1:** sin red, cualquier pantalla de contenido muestra error y «Reintentar». **FA §7.4:** caché obsoleta de hasta 24 h o 30 d. | Si hay caché: contenido más un aviso «sin conexión». Si no hay caché: error con «Reintentar». | P (confirmar) | **AC-009-1:** sustituir por «sin red y **sin caché**, la pantalla muestra error y "Reintentar"; con caché, muestra el contenido con un aviso de sin conexión (RNF-020)». |
| CR-079 | Versiones de plataforma | **DEP 12a:** «PHP 8.3». **TS (H-Q3):** versiones de WordPress, PHP y Node de producción DESCONOCIDAS. **C4 y DEP:** «Next.js 16». **COD:** `next 16.3.4`. **NFR S-NF-04:** Flutter «se elige en F1»; FA y TS fijan Flutter 3.50.0 y Dart 3.14. | **DESCONOCIDO** para PHP, WordPress y Node. Se obtienen en WP Site Health y con `node -v` en el servidor. Se fija `next 16.3.4` (evidencia de `package.json`). Flutter: lo decide FA (ADR-004/012); NFR remite a FA. | T (dato) | **DEP 12a:** sustituir «PHP 8.3» por «PHP: DESCONOCIDO (verificar en Site Health; CR-079)». **C4 y DEP:** «Next.js 16.3.4». **NFR S-NF-04:** añadir «fijado en FA: Flutter 3.50.0 / Dart 3.14». |

### Bloque E — Privacidad y aspectos legales

| CR | Tema | Conflicto | Recomendación | Tipo | Cambio exacto |
|---|---|---|---|---|---|
| CR-080 | Retención de logs: «≥ 90» o «≤ 90» días | **PA J-21:** «(≥ 90 días propuesto)». **PA F-11/§5.3, SC-071 y RNF-063:** ≤ 90 días. | **≤ 90 días.** J-21 es una errata. | T | **PA J-21:** sustituir «≥ 90» por «≤ 90». |
| CR-081 | Retención de pedidos y cuentas | **AUT §12.2:** «5 a 10 años». **PA §5.3:** NO VERIFICADO, «no debe adoptarse». **DM RET-02 y RET-06:** D-12. | No adoptar ninguna cifra hasta que Jurídico la confirme (J-04, J-05). | **L** | **AUT §12.2:** sustituir «5 a 10 años» por «plazo legal pendiente de Jurídico (D-12, J-04/J-05; CR-081)». |
| CR-082 | IP completa en la auditoría durante 90 días | **DD E05:** `ip_address` VARBINARY(16) completa. **SA y PA:** los logs usan la IP truncada (P9). **RM-06:** sin decisión. | IP **truncada** (/24 en IPv4, /48 en IPv6) en todos los eventos, salvo `login_failed`, `login_throttled` y `refresh_reused`, que guardan la completa ≤ 90 días con finalidad de seguridad. **Validación jurídica de la base legal:** el art. 10 no incluye el interés legítimo (J-01). | **L** | **DD E05:** añadir «IP completa solo en eventos de seguridad, ≤ 90 d, sujeto a J-01 (CR-082)». |
| CR-083 | Eliminación de cuenta: gracia, inmediata o diferida, y enum | **J-17:** periodo de gracia no definido. **TC-087:** ¿inmediata o diferida? **YAML `AccountDeletionStatus`:** `scheduled` y `completed`; CON y AUT solo mencionan `scheduled`. **SC-057 y ADR-022:** en dos tiempos. | En dos tiempos (ADR-022): revocación inmediata y anonimización ≤ 15 días hábiles. **Sin periodo de gracia en el MVP** (lo más simple; la solicitud es revocable antes de la anonimización solo si Jurídico lo exige). `completed` se mantiene en el enum para consultas futuras. | **L** (plazo y gracia) / T (enum) | **CON EP-12 y AUT §12.1:** añadir «`status` ∈ `scheduled`, `completed`». **PA J-17:** añadir «propuesta técnica: sin gracia; pendiente de Jurídico (CR-083)». |

### Bloque F — Referencias cruzadas, numeración y trazabilidad

| CR | Tema | Conflicto | Recomendación | Tipo | Cambio exacto |
|---|---|---|---|---|---|
| CR-084 | Citas de ADR equivocadas | **OV §1, punto 5:** justifica «sin pinning… sin push» con «ADR-007, ADR-012»; el pinning es ADR-011. **Cabecera de AUT:** cita «ADR-013/011/012/018/019»; 011 y 012 son del cliente Flutter (pinning y pruebas). **TS §5.1:** ADR-009 para el entorno local, frente a **TC §2:** ADR-012. **TC-027:** cita ADR-021, que existe (ARQ §18). | Corregir las citas. | T | **OV §1, punto 5:** sustituir «ADR-007, ADR-012» por «ADR-011 (pinning) y ADR-002 (push en fase 2)». **Cabecera de AUT:** sustituir «ADR-013/011/012/018/019» por «ADR-013, ADR-014, ADR-018, ADR-019, ADR-021, ADR-022». **TS §5.1:** sustituir «ADR-009» por «ADR-012 (pruebas) y ADR-009 (flavors)», según el párrafo. |
| CR-085 | Huecos en la numeración | IN-14 no existe. SUP-SEC-09, 12 y 14 no existen. SA §12 dice «SUP-SEC-01..16». El encargo atribuía los SUP-SEC a ST. | Declarar los huecos de forma explícita. | T | **C4, CD, DF y DEP, sección de inconsistencias:** añadir «IN-14: número no utilizado». **SA §3:** añadir «SUP-SEC-09, 12 y 14: no utilizados (IN-09, IN-12 e IN-14 no afectan a la seguridad o no existen)». |
| CR-086 | Estado desfasado | **OV y FA:** autenticación y contratos «en elaboración», RA-02 «sin OpenAPI aún». Ya existen `openapi.yaml`, CON (27 endpoints) y AUT. | Actualizar el estado. | T | **OV RA-02:** sustituir «sin OpenAPI aún» por «OpenAPI 3.1.0 `1.0.0-draft` en `05_api/openapi.yaml`». **OV §7 y §10 (DA-02):** sustituir «en elaboración» por «propuesto en CON (EP-23/EP-24)». |
| CR-087 | Errores de trazabilidad | **TR §4:** 77/35/2 = 114 RNF, frente a **NFR §0.3:** 77/36/3 = 116. TR dice que MED-02, MED-13 y MED-18 no tienen RNF, pero NFR §6 los asigna. TR declara «Inconsistencias 0». | Corregir los recuentos: RNF-066 y RNF-089 tienen prioridad condicional. | T | **TR §4:** sustituir los totales por «77 Must / 36 Should / 3 Could = 116 (RNF-066 y RNF-089 con prioridad condicional)». **TR, MED:** quitar MED-02, 13 y 18 de «sin referencia». Sustituir «Inconsistencias: 0» por «ver `resolucion_inconsistencias.md`». |
| CR-088 | Erratas de QA | **TC-059:** «`P-TC-059`» debería ser `P-BACKORDER`. **TC-148:** «seis de seis» con 4 pasos. **TC-110:** capa Manual pero «Automatizable: Sí». **Pirámide (TS §3):** la fila «Red lenta: 2» se cuenta dos veces. **TC, grupo J:** remite a «TS §9» (debería ser §10). **TC §5.1:** dice `integration_test` con BFF simulado, frente a **TS §3:** `flutter test` por defecto. | Corregir las erratas y alinear TC §5.1 con TS §3. | T | Reemplazos literales en cada ID citado. **TC §5.1:** sustituir «`integration_test` con BFF simulado» por «`flutter test` con BFF simulado; `integration_test` solo para el ciclo de vida real (TS §3)». |
| CR-089 | Requisitos sin RF o ambiguos | **AC-031-2:** «repetir compra» sin RF. **ADR-002:** B2B y cotización con precio en fase 2, sin RF que los registre. **RF-035, 059, 061, 067 y 103:** «Won't» y a la vez «fase 2». **S-05** (requisitos de las tiendas) sigue [A VALIDAR] en AC-099-6 y AC-110-16 después del plazo. | Quitar «repetir compra» del AC (no está en el MVP). Crear un RF de B2B como «Won't (MVP) / fase 2». Convención: «Won't» = no en este lanzamiento, con una columna de fase. Verificar S-05 antes de diseñar la eliminación de cuenta (Apple exige poder iniciarla en la app; COD). | P | **AC-031-2:** quitar «repetir compra». **FR §1:** añadir «RF-114 B2B (precios y roles) — Won't / fase 2 (ADR-002)». **FR, leyenda MoSCoW:** «Won't = fuera de este lanzamiento; la columna "fase" indica cuándo». |

---

## 3. Tabla maestra de ADR

| ADR | Título (resumido) | Documento | Estado | Solapes y conflictos | Propuesta |
|---|---|---|---|---|---|
| ADR-001 | BFF `/mobile/v1` en Next.js y ampliación de `ipr/v1` | ADR | **Aprobada** | **CR-038:** el «únicamente» del punto 2 choca con el alcance real de `ipr/v1/m`. **CR-002:** el punto 4 necesita una aclaración. **CR-035:** Redis «puede requerir» frente a ADR-015. | Mantener. Añadir la **enmienda de CR-038** y la **aclaración de CR-002**, que requieren aprobación humana. |
| ADR-002 | Alcance del MVP: compra completa, sin B2B, cotización por WhatsApp | ADR | **Aprobada** | Sin contradicciones. **CR-030(b)** añadiría la verificación de correo al MVP. TM-027 (doble pago) condiciona el checkout (§5). | Mantener. |
| ADR-003 | App *feature-first* con dominio ligero | OV §9 | Propuesta | — | Aprobar. |
| ADR-004 | Riverpod 3 | OV §9 | Propuesta | — | Aprobar. |
| ADR-005 | go_router y deep links | OV §9 | Propuesta | Complementa ADR-008 (rutas `/app/*`). | Aprobar; citar CR-001. |
| ADR-006 | Dio y `AppFailure` | OV §9 | Propuesta | Se solapa con ADR-016 (cliente frente a servidor). Conflicto CR-073 y CR-062. | Aprobar tras aplicar CR-073; remitir a ADR-016 para los códigos. |
| ADR-007 | Persistencia local | OV §9 | Propuesta | Se solapa con AUT §5 / ADR-013 (almacenamiento de tokens): CR-019. También CR-065. | Aprobar como **única** ADR de almacenamiento en el dispositivo. ADR-013 solo trata el servidor. |
| ADR-008 | Resultado del pago verificado en el servidor | OV §9 | Propuesta | **Duplicada con ADR-017** (CR-003). Conflicto CR-004. | **Fusionar:** ADR-008 absorbe ADR-017. |
| ADR-009 | Flavors y configuración sin secretos | OV §9 | Propuesta | Complementa ADR-018 (configuración remota). Cita equivocada en TS §5.1 (CR-084). | Aprobar. |
| ADR-010 | Observabilidad (fallos y analítica apagada) | OV §9 | Propuesta | Depende de DN-02 y PA-08; tiene aspectos legales (J-12). | Aprobar condicionada a Jurídico. |
| ADR-011 | Sin pinning ni detección de root en el MVP (MASVS L1) | OV §9 | Propuesta | SA la valida con condiciones C-P1..C-P4. Mal citada en OV §1 y en AUT (CR-084). | Aprobar con aceptación de riesgo firmada (DA-15, NL-C7). |
| ADR-012 | Estrategia de pruebas | OV §9 | Propuesta | Se cita con ADR-009 de forma ambigua (CR-084). | Aprobar. |
| ADR-013 | Sesiones por dispositivo con tokens opacos | ARQ §18 | Propuesta | Valores de CR-022 a CR-026. Almacenamiento → ADR-007. | Aprobar con los valores de CR-022. |
| ADR-014 | `ipr/v1/m/*` solo para el BFF, con secreto propio | ARQ §18 | Propuesta | CR-036 y CR-038 (depende de la enmienda de ADR-001). | Aprobar junto con la enmienda CR-038. |
| ADR-015 | Límites en tres capas sin Redis | ARQ §18 | Propuesta | Tensión con ADR-001 («puede requerir») y con NL-05 (CR-035). | Aprobar **condicionada** a verificar SA-01. |
| ADR-016 | Errores RFC 9457 y semántica 404/502/503/504 | ARQ §18 | Propuesta | Se solapa con ADR-006 (cliente). CR-029, CR-069. | Aprobar. |
| ADR-017 | Resultado del pago con `checkoutRef` | ARQ §18 | Propuesta | **Duplicada con ADR-008.** | **Retirar** («fusionada en ADR-008»). El número no se reutiliza. |
| ADR-018 | Sedes y configuración remota en WordPress | ARQ §18 | Propuesta | Amplía `ipr/v1` más allá de ADR-001 (CR-038). | Aprobar tras la enmienda de ADR-001. |
| ADR-019 | HTML saneado en el servidor y renderizado nativo | ARQ §18 | Propuesta | Coherente con FA (`flutter_widget_from_html_core`). | Aprobar. |
| ADR-020 | Paginación por offset {12, 24, 48} | ARQ §18 | Propuesta | Contradice RNF-011 y RF-011 (CR-077). | Aprobar; ajustar los requisitos. |
| ADR-021 | Recuperación de contraseña por API y restablecimiento en WordPress | ARQ §18 | Propuesta | Implementa ADR-001 §2. Contradice RF-042 y AC-042-2 (CR-031). | Aprobar. |
| ADR-022 | Eliminación de cuenta en dos tiempos | ARQ §18 | Propuesta | Plazos y gracia: legales (CR-083). | Aprobar la parte técnica; los plazos, tras Jurídico. |

**Propuesta de consolidación**

1. **Un único registro.** Copiar ADR-003 a ADR-022 a `architecture_decisions.md` con el estado «Propuesta». OV §9 y ARQ §18 pasan a ser resúmenes con enlace. Hoy ARQ declara que «no se editó `architecture_decisions.md`», lo que incumple la regla de su cabecera.
2. **Numeración final.**
   - Se mantienen los números del 001 al 022.
   - **ADR-017 queda como «Retirada — fusionada en ADR-008».** No se renumera, para no romper las más de 30 citas existentes.
   - Las ADR nuevas, si se aprueban, empiezan en **ADR-023**:
     - ADR-023: «Registro sin enumeración y verificación de correo» (CR-030, opción b).
     - ADR-024: «Evidencia de la autorización en PQRS» (CR-056), tras Jurídico.
   - La enmienda CR-038 **no** es una ADR nueva: se registra como «Enmienda 1» dentro de ADR-001.
3. **Reparto de responsabilidades para evitar solapes.**
   - ADR-007: almacenamiento en el dispositivo. ADR-013: sesión en el servidor.
   - ADR-006: taxonomía del cliente. ADR-016: catálogo de errores del servidor.
   - ADR-009: configuración local por flavor. ADR-018: configuración remota.
4. **Orden de aprobación sugerido.**
   1. Enmienda de ADR-001 (CR-038).
   2. ADR-013, ADR-014 y ADR-008 fusionada.
   3. ADR-016 y ADR-006.
   4. ADR-015 (con el dato de SA-01).
   5. El resto.

---

## 4. Resumen

### 4.1 Recuento

| Tipo | N.º de CR | IDs |
|---|---|---|
| **TÉCNICA** | **74** | Todas las no listadas abajo. De ellas, **8 dependen de un dato DESCONOCIDO** (CR-018, 028, 035, 052, 060, 075, 076, 079) y **2 tocan el texto de ADR-001** (CR-002 aclaración y CR-038 enmienda), por lo que su aprobación es humana. |
| **PRODUCTO / NEGOCIO** | **10** | CR-013, 017, 027, 030, 040, 049, 053, 055, 078, 089 |
| **LEGAL** | **5** | CR-056, 061, 081, 082, 083 (CR-083 es mixta: el enum es técnico) |
| **Total** | **89** | CR-001 a CR-089 |

> Nota sobre el recuento: CR-001 a CR-089 son 89 identificadores. La ficha completa de CR-053 está justo debajo de esta nota (no en el bloque C). Cubren las 15 IN existentes (IN-14 no existe), las 28 INC, las 2 de QA (TC-007 → CR-030, TC-085 → CR-053) y 50 contradicciones nuevas.

**CR-053 (AC-108-2 frente a `OrderDetail`, TC-085)**

| Campo | Contenido |
|---|---|
| Conflicto | **AC-108-2:** no mostrar imagen, envío, seguimiento ni dirección. **YAML `OrderDetail`:** incluye `shippingTotal`, `taxTotal` e `imageUrl`. **RF-051 y AC-051-2:** el cliente elige y paga el envío en el checkout, así que el pedido de WooCommerce tiene envío. **AC-108-1/4:** total igual al de WooCommerce. |
| Evidencia | La premisa de AC-108-2 («el pedido actual no trae esos datos») describe el mapeo heredado de `AR` L245-266, no un límite de WooCommerce (COD §3). |
| Recomendación | Mostrar subtotal, **envío**, descuento, impuestos y total. La imagen se muestra si existe `productId`. No se muestran seguimiento ni dirección (RF-109, fase 2). Así el total cuadra y es verificable. |
| Tipo | **P** |
| Cambio | **AC-108-2:** sustituir por «no muestra seguimiento ni dirección (RF-109 fase 2); **sí** muestra envío, descuento e impuestos cuando el pedido los tenga, y la imagen si existe; nunca muestra ceros inventados». **TC-085 y TS R-Q14:** «RESUELTA por CR-053». |

### 4.2 Las 10 más peligrosas si no se resuelven antes de programar

| # | CR | Por qué es peligrosa |
|---|---|---|
| 1 | **CR-010** | El handoff crea una **cookie persistente de WordPress sin comprobar el rol**. Riesgo de escalar a wp-admin y de que la sesión quede abierta en el navegador del dispositivo (código, `HO` L271). |
| 2 | **CR-038** | El alcance de `ipr/v1/m` frente a ADR-001. Si no se enmienda, el equipo puede leer los pedidos con la clave de administrador de `wc/v3`, lo que abre un riesgo BOLA (TM-028). |
| 3 | **CR-030** | Enumeración de cuentas en el registro, con *credential stuffing* como amenaza principal (TM-001). Además cambia el alcance (verificación de correo). |
| 4 | **CR-001 / CR-002 / CR-003** | Ruta y mecanismo de retorno del pago. Si `.well-known` y la ruta no coinciden, el usuario no vuelve a la app. Si se confía en `status` del enlace, se pueden falsificar pagos en la interfaz. |
| 5 | **CR-045 + CR-012** | Las direcciones se guardan en un meta propio que WooCommerce no lee. Si se quita la facturación del ticket sin migrar, se rompe el prellenado del checkout, y el cambio afecta también a la web. |
| 6 | **CR-035** | Límites en memoria por proceso, mapa que se vacía e IP tomada de `x-forwarded-for` (falsificable). Sin el dato SA-01, la protección contra fuerza bruta puede no existir. |
| 7 | **CR-028** | Hoy no hay filtro de rol. Si no se fija una regla, cuentas administrativas pueden iniciar sesión en la app y en el handoff. |
| 8 | **CR-047** | Importes en flotante frente a entero. Provoca errores de redondeo en totales y precios, y rompe el contrato si se cambia después de publicar v1. |
| 9 | **CR-005 / CR-009** | Idempotencia opcional y respuesta ambigua ante una referencia ajena. Provoca tickets duplicados o BOLA, y QA no puede cerrar los casos. |
| 10 | **CR-020 / CR-019** | Manejo del refresh y almacenamiento del access. Puede expulsar a usuarios por fallos de red o dejar el access persistido sin necesidad. |

Fuera del ranking, pero bloqueante del MVP: **doble pago y webhook de Wompi** (TM-027, «no aceptable sin cerrar D-02/PA-11»; ver §5).

### 4.3 Decisiones que el humano debe tomar ahora (12)

| # | Pregunta cerrada | Opciones | Recomendación |
|---|---|---|---|
| H-01 | ¿Se aprueba la **enmienda de ADR-001 §2** para que `ipr/v1/m/*` incluya registro, perfil, direcciones, pedidos, consentimientos, configuración y sedes? (CR-038) | Sí / No (el BFF leería pedidos con la clave de `wc/v3`) | **Sí** |
| H-02 | ¿La app vuelve del pago por **`/app/pedido`** (la web conserva `/pedido-confirmado`) y el resultado se **confirma siempre consultando al servidor**? (CR-001, 002, 003) | Sí / No | **Sí** (y se fusiona ADR-017 en ADR-008) |
| H-03 | Registro con un correo ya existente: ¿**respuesta uniforme más verificación de correo en el MVP**, o **409 `email_in_use` con el riesgo firmado**? (CR-030) | (b) Uniforme + verificación / (a) 409 + riesgo aceptado | **(b)** |
| H-04 | ¿Se aprueban las vidas de los tokens **15 min (access) y 30 d de inactividad / 90 d absolutos (refresh)**, con revocación inmediata? (CR-022, 025) | Sí / Otros valores | **Sí** |
| H-05 | ¿En el MVP solo **«cerrar todas las sesiones» (también la web)** y la lista de dispositivos en fase 2? (CR-027) | Solo cerrar todas / Lista en el MVP | **Solo cerrar todas** |
| H-06 | ¿Los productos **«bajo pedido» (`on_backorder`)** se pueden comprar en la app del MVP? (CR-017) | Sí / No (WhatsApp) | **No** |
| H-07 | ¿El carrito **se conserva al cerrar sesión** y **se borra al eliminar la cuenta**? (CR-040) | Conservar y borrar / Conservar ambos / Borrar ambos | **Conservar y borrar** |
| H-08 | ¿El detalle del pedido muestra **envío, descuento e impuestos** (y la imagen si existe), cambiando AC-108-2? (CR-053) | Sí / No | **Sí** |
| H-09 | ¿Solo pueden iniciar sesión **`customer` y `subscriber` sin capacidades administrativas**, tras contar los roles existentes? (CR-028) | Sí / Ampliar la lista | **Sí** |
| H-10 | ¿Se confirma **sin compra como invitado** en el MVP? (CR-013) | Sin invitado / Con invitado | **Sin invitado** |
| H-11 | (Jurídico) Eliminación de cuenta: ¿**sin periodo de gracia**, con supresión ≤ 15 días hábiles y plazos de retención contable fijados por Jurídico? (CR-081, 083) | Sin gracia / Gracia de N días | **Sin gracia**, pendiente de J-04, J-05 y J-17 |
| H-12 | ¿Se autoriza **staging con Wompi sandbox y acceso de solo lectura al servidor** (D-16, C2) para resolver los DESCONOCIDOS? Son: n.º de procesos Node, Cloudflare delante de WordPress, estados de Wompi, doble pago, roles, zona horaria, PHP y caché de objetos. (CR-018, 035, 075, 079…) | Sí / No | **Sí, ya**. Sin esto, 8 CR quedan abiertos. |

---

## 5. Hallazgos que cambian el alcance del MVP o los requisitos

| # | Hallazgo | Efecto en el alcance o los requisitos | Fuente |
|---|---|---|---|
| 1 | **La verificación de correo entra en el MVP** si se elige CR-030(b). | RF-046 pasa de Should / fase 2 a Must / MVP. WordPress tiene que enviar correos transaccionales nuevos (activación y «ya tienes cuenta»). | CR-030; RNF-053; DN-12 |
| 2 | **La ampliación de WordPress es mayor que la aprobada en ADR-001.** | Hay más trabajo en WordPress: registro, perfil, direcciones, pedidos, configuración, sedes y consentimientos en `ipr/v1/m`. ADR-001 necesita una enmienda. | CR-038 |
| 3 | **Los cambios obligatorios en snippets compartidos afectan a la web.** Son tres: cookie del handoff no persistente y con filtro de rol (CR-010), migración de direcciones a `WC_Customer` (CR-045) y el nuevo formato del ticket (CR-012). | Hacen falta pruebas de regresión de la web y staging (C2) **antes** de la app. ADR-001 C1 y C2 pasan a ser bloqueantes reales. | `HO` L263-273, L214-232; `AR` L340-359 |
| 4 | **El doble pago y el webhook de Wompi siguen DESCONOCIDOS**, y TM-027 los declara «no aceptables» sin resolver. | El checkout del MVP (ADR-002) no se puede liberar sin MED en staging (D-02, PA-11). Si no se resuelven a tiempo, D-06 preveía la opción (b) (compra en fase 2). | TM §5.3; ARQ RA-07; ER (cardinalidad intento-pedido) |
| 5 | **RNF-040 se reduce** a «cerrar todas» en el MVP (CR-027) y la revocación pasa a ser **inmediata** (CR-025). | Cambia el texto de un RNF Must. | CR-025, CR-027 |
| 6 | **AC-108-2 cambia:** el detalle del pedido muestra envío, impuestos y descuento. | WP-07 tiene que mapear más campos. | CR-053 |
| 7 | **PQRS tiene que guardar la evidencia de la autorización.** | Requiere una entidad o columna nueva y una decisión jurídica (J-10). | CR-056 |
| 8 | **B2B no tiene RF**, aunque ADR-002 lo deja para fase 2. | Añadir un RF «Won't / fase 2» para la trazabilidad. | CR-089 |
| 9 | **El límite de autenticación en memoria puede no proteger nada** si hay más de un proceso Node, y la IP se toma de una cabecera falsificable. | Si SA-01 es falso, Redis (o el contador en la BD de WordPress para todo) pasa a P0 en el MVP. | CR-035; `RL` |
| 10 | **Requisito de Apple:** la eliminación de cuenta debe poder iniciarse en la app (S-05 no verificado). | Ya es Must (RF-110). Hay que verificar S-05 antes del diseño final. | CR-089; SA |

---

## Anexo A — Equivalencias de IDs de origen → CR

| Origen | CR | Origen | CR | Origen | CR |
|---|---|---|---|---|---|
| IN-01 | CR-001 | INC-01 | CR-041 | INC-15 | CR-001 |
| IN-02 | CR-002 | INC-02 | CR-042 | INC-16 | CR-054 |
| IN-03 | CR-003 | INC-03 | CR-043 | INC-17 | CR-055 |
| IN-04 | CR-004 | INC-04 | CR-044 | INC-18 | CR-056 |
| IN-05 | CR-005 | INC-05 | CR-045 | INC-19 | CR-028 |
| IN-06 | CR-021 | INC-06 | CR-046 | INC-20 | CR-057 |
| IN-07 | CR-019 | INC-07 | CR-047 | INC-21 | CR-012 |
| IN-08 | CR-020 | INC-08 | CR-017 | INC-22 | CR-058 |
| IN-09 | CR-014 | INC-09 | CR-048 | INC-23 | CR-059 |
| IN-10 | CR-074 | INC-10 | CR-049 | INC-24 | CR-060 |
| IN-11 | CR-075 | INC-11 | CR-050 | INC-25 | CR-022 |
| IN-12 | CR-073 | INC-12 | CR-051 | INC-26 | CR-019 |
| IN-13 | CR-007 | INC-13 | CR-052 | INC-27 | CR-061 |
| IN-14 | CR-085 (no existe) | INC-14 | CR-027 | INC-28 | CR-062 |
| IN-15 | CR-035 | TC-007 | CR-030 | TC-085 | CR-053 |
| IN-16 | CR-076 | | | | |

## Anexo B — DESCONOCIDOS y cómo obtenerlos

| Dato | CR | Cómo obtenerlo | Requiere |
|---|---|---|---|
| N.º de procesos Node en producción | CR-035 | Revisar la unidad systemd o PM2 (modo clúster) del servidor de DigitalOcean | Acceso de lectura (D-16) |
| ¿Cloudflare delante de WordPress? ¿El origen está restringido? | CR-075 | Cabeceras `cf-ray` y `server` en `wp-json`; DNS; reglas del firewall del origen | D-16 |
| Estados de pedido que produce Wompi; doble pago | CR-018, §5-4 | Transacciones en el sandbox de Wompi, en staging | C2, D-16 |
| Roles existentes de los clientes | CR-028 | `wp user list --role=<rol> --format=count` en staging | C2 |
| Zona horaria del sitio | CR-052 | `wp option get timezone_string` | C2 |
| Longitud de `user_email` | CR-060 | `DESCRIBE wp_users` | C2 |
| Versiones de PHP, WordPress y Node | CR-079 | WP Site Health; `node -v` | D-16 |
| Caché de objetos persistente (TTL de los transients) | CR-011 | `wp cache type` / Site Health | C2 |
| Clave de usermeta de la cédula/NIT | CR-044 | Inspeccionar el usermeta de un cliente de prueba tras pagar en staging (candidatas: `billing_national_id` y `cedula_nit_ship`) | C2 |
| Dominio de staging | CR-076 | Decisión de infraestructura (C2) | C2 |

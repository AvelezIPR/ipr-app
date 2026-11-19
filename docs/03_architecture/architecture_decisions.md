# Registro de decisiones arquitectónicas (ADR)

> Formato: contexto → decisión → alternativas → consecuencias → evidencia. Estado: Propuesta / **Aprobada** / Reemplazada.
> Toda decisión se refleja también en `docs/project/decisiones_pendientes.md`.

---

## ADR-001 — La app móvil consumirá un BFF móvil versionado dentro del proyecto Next.js, y `ipr/v1` se amplía solo donde falte

| | |
|---|---|
| **Estado** | **Aprobada** (confirmación del solicitante, 2026-11-18) |
| **Fecha** | 2026-11-18 |
| **Aprobó** | Solicitante del proyecto (usuario de esta sesión). **Pendiente:** conformidad del responsable técnico del repositorio `ipr-frontend` y de WordPress (ver "Condiciones"). |
| **Relacionada con** | D-01, R-01, R-03, R-09 |

### Contexto (hechos verificados en código)
- El catálogo, los menús y el índice de búsqueda se leen desde WooCommerce `wc/v3` con **clave secreta de servidor**; esa clave no puede estar en una app.
- Las rutas `/api/*` actuales autentican con cookie `httpOnly`, validan `Origin` y son internas del sitio.
- `ipr/v1` (WordPress) ya expone login, registro, perfil, pedidos y un ticket de traspaso de pago, con `Authorization: Bearer`, pero con **un solo token por usuario**, 30 días fijos, sin refresh y sin rate limiting.
- `lib/woocommerce.ts` y `lib/wc/*` ya implementan normalización, caché, *circuit breaker* y límite de concurrencia.
- El pago se hace en el checkout nativo de WooCommerce con Wompi (no PCI propio).

### Decisión
1. Crear una **capa de API móvil `/mobile/v1/*`** dentro del proyecto Next.js existente, que **reutiliza** `lib/woocommerce.ts` y `lib/wc/*` (sin duplicar el acceso a WooCommerce).
2. **Ampliar el namespace `ipr/v1` de WordPress** únicamente para lo que no existe: sesiones por dispositivo con *access token* corto y *refresh token* rotativo, revocación, eliminación de cuenta, recuperación de contraseña por API y lo que defina la Segunda Entrega.
3. La app **nunca** llamará a `wc/v3`, `wp/v2` ni a la base de datos, ni usará las rutas `/api/*` del sitio web.
4. El pago se hace abriendo el checkout web de WooCommerce con el ticket de un solo uso en un navegador seguro del sistema (Custom Tabs / ASWebAuthenticationSession), con retorno por App Links / Universal Links.
5. Los contratos de `/mobile/v1` se documentan en OpenAPI y se versionan (`v1` no se rompe; los cambios incompatibles van a `v2`).

### Alternativas descartadas
| Alternativa | Motivo |
|---|---|
| App consume `wc/v3` directo | Exige exponer la clave secreta o crear claves de solo lectura en la app (reversible por ingeniería inversa). Rechazada por seguridad. |
| App consume las rutas `/api/*` actuales | Sin versionado ni garantía de estabilidad; cookie y `Origin` no encajan con móvil (R-01). |
| Servicio BFF independiente (otro repositorio/runtime) | Duplicaría la capa de datos y su caché; más infraestructura sin beneficio demostrado hoy. Se reevaluará si la carga móvil lo exige. |
| Solo plugin de WordPress (`ipr/v1` para todo, incluido catálogo) | Se pierde la caché/índice ya construidos en Next.js y se carga más a WordPress. |

### Consecuencias
**Positivas:** reutilización del activo técnico más valioso; claves solo en servidor; contrato móvil controlado y versionable; el checkout y el pago reutilizan lo ya probado en producción.
**Negativas / costos:**
- Acopla el ciclo de despliegue móvil al de la web (mitigación: rutas aisladas bajo `/mobile/v1`, pruebas de contrato, rama y PR propios).
- El Next.js corre hoy en un solo proceso con caché y rate limit **en memoria**: la carga móvil lo exige a medir; puede requerir almacén compartido (Redis) para rate limit y sesiones.
- Hay que **añadir pruebas** (hoy no existen) al menos para `/mobile/v1`.
- Cambios en WordPress (snippets o plugin) requieren revisión y entorno de staging.

### Condiciones (deben cumplirse para que la decisión siga vigente)
- C1: el responsable técnico de `ipr-frontend` y de WordPress acepta el cambio y la revisión por PR.
- C2: existe un entorno de **staging** (frontend + WooCommerce + Wompi sandbox) antes de tocar producción.
- C3: Cloudflare permite el tráfico de la app (R-02) con reglas propias y sin desactivar la protección general.
- C4: se confirma en un piloto que la carga móvil no degrada la web (métricas de latencia y errores).

### Evidencia
`docs/00_discovery/informe_codigo_frontend.md` §2, §4, §5, §7; `ipr-frontend/CLAUDE.md` §1 y §4.1; `wp-snippets/ipr-auth-rest.php`; `wp-snippets/ipr-cart-handoff.php`; `src/app/api/checkout/route.ts`.

### Verificación (cómo se sabrá que funciona)
- Pruebas de contrato de cada endpoint `/mobile/v1` contra staging.
- Prueba de seguridad: la app empaquetada no contiene claves; `/mobile/v1` rechaza tokens inválidos/expirados; sesiones de dispositivos independientes (login web no cierra la app).
- Prueba de carga básica del BFF con perfil de tráfico acordado.

---

## ADR-002 — Alcance del MVP: compra completa, sin B2B, cotización solo por WhatsApp

| | |
|---|---|
| **Estado** | **Aprobada** (solicitante, 2026-11-18) |
| **Relacionada con** | D-03, D-04, D-06, ADR-001 |

**Decisión.** El MVP incluye catálogo, búsqueda, ficha, cuenta, carrito local y **checkout completo** (ticket de un solo uso → checkout de WooCommerce con Wompi en navegador seguro). **No** incluye precios ni roles B2B. Los productos sin precio muestran únicamente "Más información" → WhatsApp con el producto (como la web actual).

**Consecuencias.**
- (+) Sin backend nuevo de cotizaciones/CRM ni modelo de permisos por rol en el MVP.
- (−) El MVP **sí** depende de lo más exigente de ADR-001: sesiones por dispositivo, rate limiting, App Links/Universal Links y staging con Wompi sandbox.
- (−) Riesgo comercial: clientes B2B y compras sin precio dependen de asesores; medir cuánto del tráfico se pierde.
- Fase 2 candidata: cotización estructurada, precios B2B por rol, favoritos sincronizados, notificaciones push.

**Verificación.** Criterios de aceptación de compra extremo a extremo en staging (agregar, pagar con Wompi sandbox, volver a la app, ver pedido) y prueba de que ningún precio B2B llega a la app.

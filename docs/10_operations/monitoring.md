# Monitoreo — App IPR, BFF `/mobile/v1`, WordPress/WooCommerce y Wompi

| | |
|---|---|
| **Fase** | OPERACIÓN (documentación). **No se programa ni se configura nada.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. **Ningún elemento propuesto de este documento está montado**; la app y `/mobile/v1` no existen. Ningún objetivo (SLO) se declara medido: toda cifra es una **propuesta** tomada de los RNF y se calibra con las mediciones MED-xx. |
| **Relacionado** | [logging.md](logging.md) · [incident_response.md](incident_response.md) · [maintenance.md](maintenance.md) · `../09_devops/environments.md` y `../09_devops/ci_cd.md` (los escribe otro agente en paralelo; **no se duplican aquí**; confirmar enlaces cuando existan) |
| **Fuentes** | `RNF` = `02_requirements/non_functional_requirements.md`; `QM` = `08_quality/quality_metrics.md`; `AA` = `05_api/api_architecture.md`; `AC` = `05_api/api_contracts.md`; `AU` = `05_api/authentication.md`; `SC`/`TM` = `06_security/security_controls.md` y `threat_model.md`; `DEP` = `03_architecture/deployment_architecture.md`; `COD` = `00_discovery/informe_codigo_frontend.md`; `WCA` = `00_discovery/analisis_capa_woocommerce.md`; `PRIV` = `06_security/privacy_assessment.md` |

---

## 0. Cómo leer este documento

| Etiqueta | Significado |
|---|---|
| **HECHO** | Comprobado en código o documento, con cita. Código leído en solo lectura (`ipr-frontend`); no se abrió ningún `.env`. |
| **SUPUESTO** | Premisa razonable no verificada. Los `SUP-H` son las recomendaciones **no aprobadas** H-01..H-12 de `decisiones_pendientes.md` §E, tratadas como supuestos. |
| **PROPUESTA** | Diseño recomendado aquí. **No existe todavía.** Umbrales y severidades son propuestas. |
| **DECISIÓN PENDIENTE** | Requiere aprobación humana (ID `D-xx`, `DN-xx` o `DOP-xx` nuevo de este documento). |
| **RIESGO** | `ROP-xx`. |
| **DESCONOCIDO** | Sin evidencia; se indica cómo obtenerla. |

Solo **ADR-001 y ADR-002** están aprobadas (con condiciones C1–C4 pendientes). Todo lo que depende de ADR-003 en adelante es propuesta.

---

## 1. Resumen ejecutivo

1. **Hoy no hay monitoreo de la app**: no existe. Lo que existe en el código web es poco y está pensado para la web: un `GET /api/health`, una línea de log por minuto con contadores hacia WooCommerce y un mensaje de error cuando el *breaker* se abre (§2). **A dónde van esos logs y quién los lee es DESCONOCIDO.**
2. **`/api/health` no sirve por sí solo para saber si la app funciona**: solo responde si el proceso Node atiende, y **a propósito no consulta WooCommerce** (comentario en `src/app/api/health/route.ts`). Con WordPress caído devolverá `ok` y la app estará inservible. Hace falta un **monitoreo sintético funcional** (catálogo, sugerencias, login de prueba) que sí cruce WooCommerce (RNF-102).
3. **El riesgo operativo principal es estructural**: BFF, web, caché, índice, *breaker*, cola (concurrencia 4) y limitador de frecuencia viven en **un solo proceso** compartido (R-NF-01, R-NF-03, TM-017). Una degradación móvil degrada la web. Por eso el monitoreo prioriza saturación (cola, memoria, bucle de eventos) y la comparación web-con/sin-móvil (RNF-015).
4. **Se proponen 40 alertas** (§11) en 6 familias y 8 paneles (§12). Las alertas mínimas de RNF-101 están incluidas (AL-03, AL-04, AL-05, AL-01, AL-07, AL-09, AL-14).
5. **Para que las alertas existan hay que construir instrumentación** que hoy no está (logs por solicitud, métricas por endpoint, dimensión `origin=mobile`, auditoría en WordPress, reporte de fallos): lista en §14. Es trabajo de las fases de desarrollo, no de este documento.
6. **Lo más desconocido**: herramienta de monitoreo, destino de logs, plan de Cloudflare, topología (procesos, RAM), existencia de *staging*, mecanismo de guardia y canal de alertas (§3).

---

## 2. Qué existe hoy (HECHO, con cita) y qué es propuesto

| ID | Elemento | Estado | Evidencia | Límite para operación |
|---|---|---|---|---|
| EX-01 | `GET /api/health` → `{status:"ok", version, uptime}`; `no-store`; **no** consulta WooCommerce | **EXISTE** | `ipr-frontend/src/app/api/health/route.ts` | Solo prueba vida del proceso. Publica `version` y `uptime` (SC-061 pide quitar la versión pública; el `uptime` sirve para detectar reinicios, AL-11). |
| EX-02 | Contadores por minuto hacia WooCommerce (`calls`, `ok`, `errors`, `retries`, `rejected`, por tipo, aciertos de caché `hit/stale/miss/error`) escritos **una vez por minuto** con `console.info`, **solo si hubo actividad**, e incluyen el estado del *breaker* (`closed`/`OPEN`/`half-open`) | **EXISTE** | `src/lib/wc/metrics.ts` (`flush`, `getWcStats`) | Es un **texto** en la salida estándar del proceso, no una métrica consultable. El estado del *breaker* es una **foto al cierre del minuto**: una apertura de 30 s puede no verse. Sin latencias, sin dimensión de origen (web/móvil), sin cola. |
| EX-03 | Mensaje `[wc] Corte de circuito ABIERTO: N errores seguidos…` con `console.error` al abrir el *breaker* | **EXISTE** | `src/lib/wc/client.ts` (`breakerFailure`) | Es la **mejor señal actual** de WooCommerce caído. No hay mensaje de cierre. Umbral por defecto 5 errores / 30 s (variables `WC_BREAKER_THRESHOLD`, `WC_BREAKER_COOLDOWN_MS`; concurrencia `WC_MAX_CONCURRENCY`, defecto 4). |
| EX-04 | Errores de carga registrados con prefijo `[woocommerce]` y `[wc]` (`console.error`) | **EXISTE** | `src/lib/woocommerce.ts` (varias líneas), `src/lib/wc/swr-cache.ts` | Contenido de los objetos de error: DESCONOCIDO (puede incluir datos de respuesta; ver TM-045, ST-108). |
| EX-05 | Precalentamiento al arrancar (metadatos + índice) sin bloquear | **EXISTE** | `src/instrumentation.ts` | El tiempo de construcción del índice no se registra como métrica (MED-17). |
| EX-06 | Cloudflare (CDN/WAF) delante de la web | **EXISTE** | `INV` §2.1; `COD` §2 | Plan, reglas y analítica disponibles: DESCONOCIDO (AP-08). |
| EX-07 | Wordfence en WordPress (menciona el snippet de auth) | **EXISTE** (según el snippet) | `wp-snippets/ipr-auth-rest.php` (comentario); `AU` §13 | Versión, reglas y registros: DESCONOCIDO (MED-10). Los snippets **no** escriben logs propios (no se halló ninguna llamada de registro en `wp-snippets/*.php`). |
| EX-08 | Webhook HMAC de WooCommerce a `/api/revalidate` y despliegue por GitHub Actions por SSH | **EXISTE** | `COD` §2, §4; `DEP` §12a | El workflow solo despliega (sin `tsc`, lint ni `npm audit`); mecanismo de verificación posterior al despliegue: ver `ci_cd.md` (otro agente). |
| — | Todo lo demás de este documento (alertas, paneles, métricas por endpoint, sintético, auditoría, reporte de fallos, telemetría de versiones) | **PROPUESTO** | RNF-097..105; SC-045..047 | No existe. |

---

## 3. DESCONOCIDOS de la infraestructura de IPR que condicionan el monitoreo

| ID | Qué se desconoce | Por qué importa | Cómo obtenerlo | Bloquea |
|---|---|---|---|---|
| DES-01 | **Herramienta(s) de monitoreo/logs** disponibles en IPR (métricas, agregación de logs, sintético, paneles, guardia/alertas). **No hay ninguna en el repositorio.** | Define cómo se implementan los paneles y las alertas. | Pregunta a TI/Web (H-12). | Todo §11–§13 |
| DES-02 | Destino de `stdout`/`stderr` del proceso Node (¿archivo, `journald`, contenedor?) y su retención. | EX-02/EX-03 solo sirven si alguien los recoge. | Acceso de solo lectura al servidor (H-12, D-16). | AL-03, AL-07 hoy |
| DES-03 | Número de procesos/réplicas, vCPU, RAM, límite de memoria de Node, comando de despliegue y reversa. | Umbrales de memoria y escalado; RNF-016, RNF-030. | MED-04. | AL-09, AL-10 |
| DES-04 | Plan de Cloudflare, reglas WAF, límites, *Bot Fight Mode*, analítica y registros (Logpush es de plan superior: no asumir). | AL-38..40; RNF-032. | MED-15, AP-08. | Familia F |
| DES-05 | Si el origen (Next.js y WordPress) acepta tráfico que no viene de Cloudflare. | AL-39; TM-002, TM-052. | SA-03 / prueba controlada. | AL-39 |
| DES-06 | Existencia de **staging** (frontend + WooCommerce + Wompi sandbox). | Los simulacros de alertas (§15) y el sintético de `checkout` solo en staging (RNF-102). | C2 de ADR-001; H-12. | §13, §15 |
| DES-07 | Mecanismo de **guardia** y canal de alertas (correo, mensajería, teléfono); horario de soporte. Propuesta DN-06: horario comercial. | Define a quién llega una alerta fuera de horario. | DN-06. | Notificación de §11 |
| DES-08 | Cómo confirma Wompi los pagos (webhook, firma, estados intermedios) y si el plugin valida la firma. | AL-20..23; SC-028, TM-027, TM-030. | D-02 / PA-11 / MED-14. | Familia C (pagos) |
| DES-09 | Volumen real de pedidos, tráfico y línea base de errores/latencia de la web (no hay analítica). | Todo umbral relativo ("× línea base") requiere línea base. | MED-01, MED-03, MED-05, MED-18. | AL-12, AL-21, AL-26 |
| DES-10 | Hosting de WordPress (Plesk): métricas de CPU/RAM/disco, PHP-FPM, base de datos, copias de seguridad y quién las administra. | AL-16; [maintenance.md](maintenance.md) §8. | Pregunta al hosting. | AL-16 |
| DES-11 | Proveedor de reporte de fallos (Crashlytics o Sentry) y país de tratamiento (DN-02). | Familia E; RNF-097, RNF-061. | DN-02 con Jurídico. | AL-33..37 |
| DES-12 | Roles de WordPress existentes y cuentas administrativas (para AL-28). | H-09 (SUP-H). | Conteo de roles (H-12). | AL-28 |
| DES-13 | Si existen registros de acceso de nginx/Plesk con la query de la URL (ticket). | TM-023, SC-072; higiene de logs. | Revisión del hosting. | [logging.md](logging.md) §11 |
| DES-14 | Zona horaria y reloj (NTP) de los servidores. | Correlación de eventos entre BFF y WordPress (todo en UTC propuesto). | Revisión de servidores. | Correlación |

---

## 4. Indicadores (SLI) y objetivos (SLO) propuestos

> **Todos los objetivos son propuestas tomadas de los RNF; ninguno está medido** (línea base: "Sin medición" en `QM`). Se activan y se ajustan tras MED-01..MED-18 y el piloto. "Presupuesto de error" = lo que el objetivo tolera.

| ID | SLI (qué se mide) | SLO propuesto | Ventana | Origen | Fuente del dato (propuesta) |
|---|---|---|---|---|---|
| SLO-01 | Disponibilidad del BFF: % de comprobaciones sintéticas exitosas (excluye mantenimiento anunciado) | ≥ 99,5 % mensual (≈ 3,6 h de caída/mes de 30 días) | 30 días | RNF-019; QM-41; DN-06 | Sintético §13 |
| SLO-02 | Latencia p95 del BFF por endpoint | Catálogo con caché ≤ 300 ms; sugerencias ≤ 150 ms; catálogo con fallo de caché ≤ 2,5 s; login/refresh ≤ 1,5 s; pedidos ≤ 2,0 s; ticket ≤ 2,0 s | 30 min de carga / 7 días | RNF-012; QM-29 | Log por solicitud (`durationMs`) |
| SLO-03 | Errores 5xx del BFF | < 1 % (en carga sostenida de 30 min) | 30 min / 7 días | RNF-014; QM-31 | Log por solicitud (`status`) |
| SLO-04 | Degradación de la web por tráfico móvil (p95 web con vs. sin móvil) | ≤ 10 % | piloto y semanal | RNF-015; QM-32; ADR-001 C4 | Métricas web antes/durante piloto |
| SLO-05 | Espera en cola de `wcGet` (p95); si > 3 s responde 503 con `Retry-After` | p95 ≤ 1,0 s | 10 min | RNF-018; QM-34; SC-055 | Métrica de cola (a construir, FE-06) |
| SLO-06 | Respuestas `200` vacías causadas por fallo ascendente o índice no listo | 0 | continuo | RNF-022, RNF-023; QM-42 | Canario de contenido §13 |
| SLO-07 | Solicitud de ticket de checkout (p95) | ≤ 2,0 s | 7 días | RNF-013; QM-30 | Log por solicitud |
| SLO-08 | Pedidos o cobros duplicados | 0 | continuo | RNF-024; QM-38; NL-02 | Detector §7 + conciliación diaria |
| SLO-09 | Estado correcto del pedido tras el retorno del pago (p95) | ≤ 5 s tras volver; pendiente > ≈2 min se muestra "pendiente" | piloto | RNF-025; QM-39 | Log del BFF (`GET /checkout/{ref}`) + telemetría de la app |
| SLO-10 | Solicitudes de la app con desafío o 403 del WAF | ≤ 0,1 % | 7 días | RNF-032; QM-45 | Analítica de Cloudflare (DES-04) |
| SLO-11 | Usuarios sin fallos (crash-free) | ≥ 99,5 % en piloto y primeros 30 días | 24 h / 30 días | RNF-098; QM-35 | Reporte de fallos + consolas de tienda |
| SLO-12 | ANR | ≤ 0,3 % en piloto y primeros 30 días | 24 h / 30 días | RNF-098; QM-36 | Android vitals / consola |
| SLO-13 | Efecto de un interruptor remoto o de la versión mínima | ≤ 5 min | por cambio | RNF-029; QM-44; SC-052 | Prueba en staging; log de `GET /config` |
| SLO-14 | Cobertura de solicitudes `/mobile/v1` con log estructurado y `requestId`; 0 PII | 100 %; 0 apariciones | mensual (muestreo) | RNF-099, RNF-047 | Prueba canario ([logging.md](logging.md) §12) |
| SLO-15 | Antigüedad del índice de catálogo | ≤ 15 min (3× la renovación de 5 min) | continuo | RNF-101; H2 de RNF | Métrica de índice (a construir) |
| SLO-16 | Reversa de un despliegue del BFF | ≤ 15 min, ensayada una vez en staging | por ensayo | RNF-030; QM-43 | Ensayo |

**Política de presupuesto de error (PROPUESTA).** Con SLO-01 ≈ 3,6 h/mes: si se consume > 50 % del presupuesto en la primera mitad del mes, **se congelan** los cambios no urgentes del BFF y se prioriza fiabilidad (decisión del rol Web + TI). Revisión mensual (§16). Nada de esto aplica hasta contar con ≥ 30 días de medición (MED-05).

---

## 5. Salud del BFF y del proceso Node

| Señal | Qué detecta | Fuente hoy | Fuente propuesta | SLO / RNF / TM |
|---|---|---|---|---|
| Disponibilidad de `/api/health` | Proceso caído o no atiende | EX-01 (sin quien lo consulte: DES-01) | Sintético cada ≤ 5 min | SLO-01; RNF-102 |
| Disponibilidad funcional (catálogo, sugerencias, login de prueba) | WooCommerce/WordPress caídos pese a `health` verde; índice no listo | — | Sintético cada ≤ 5 min con cuenta de prueba **dedicada y autorizada**; `checkout` solo en staging | SLO-01, SLO-06; RNF-102 |
| Latencia p50/p95/p99 por endpoint (ruta **plantilla**) | Degradación | — | Log por solicitud (`route`, `durationMs`) agregado | SLO-02; RNF-100, RNF-012 |
| Tasa de errores por `code` (RFC 9457) y por HTTP (5xx, 429, 426) | Fallos propios y ascendentes (502/503/504) | — | Log por solicitud (`status`, `code`) | SLO-03; AA §6.3 |
| Cola de `wcGet` (espera p95, rechazos por tope) | Saturación hacia WooCommerce (cuello de botella de 4 conexiones) | — (cola sin tope ni métrica, `client.ts:214-228`) | Métrica nueva (FE-06) | SLO-05; RNF-018; SC-055; TM-017 |
| Estado y disparos del *breaker* | WooCommerce caído / inestable | EX-02 (foto por minuto) y EX-03 (mensaje al abrir) | Contador de aperturas y gauge de estado, con `origin` | RNF-100, RNF-101; RNF-022 |
| Aciertos de caché (borde, SWR) y *stale served* | Presión sobre WooCommerce; datos viejos | EX-02 (`hit/stale/miss/err` por caché) | Añadir cabecera `X-IPR-Data-State` y contador | RNF-022; AA §6.3 |
| Antigüedad y tamaño del índice; `totalPages` > 100 | Índice viejo, truncado en silencio (tope de 10.000) | — (RB-06 de `WCA`) | Gauge de edad; alerta si `totalPages > 100` | SLO-15; RB-06; AA §14 |
| Respuestas `503 catalog_index_warming` | Arranque en frío / reconstrucción tras webhook | — | Contador | RNF-023; AA §6.3 |
| Memoria RSS y *heap*; retraso del bucle de eventos (p99); CPU | Fuga, saturación, índice duplicado (RB-04) | — | Métricas del proceso | RNF-016; AL-09, AL-10 |
| Reinicios del proceso (caída de `uptime`) | Crash loop, OOM, despliegue | EX-01 (campo `uptime`) | Comparar `uptime` entre sondeos | AL-11 |
| Rechazos por rate limit (429) por clase | Abuso, scraping, límites mal calibrados | — | Contador por clase | RNF-042; SC-006; TM-016 |
| Latencia/errores del tramo BFF → `ipr/v1` por ruta | WordPress lento o caído para cuenta/pedidos | — | Log por solicitud (`upstreamMs`) | RNF-012; SC-059 |
| Degradación de la web con tráfico móvil | Impacto compartido | — | Comparación semanal p95/errores web, con y sin `origin=mobile` | SLO-04; RNF-015 |

---

## 6. WordPress / WooCommerce

| Señal | Qué detecta | Fuente | Estado |
|---|---|---|---|
| Errores y latencia de `wc/v3` desde `wcGet` | WooCommerce caído o lento | EX-02/EX-03 + métrica propuesta | EXISTE (texto) / PROPUESTO |
| Latencia, 5xx y *timeouts* (8 s) de `ipr/v1` y `ipr/v1/m/*` | Cuenta, pedidos y checkout caídos | Log del BFF (`upstreamMs`) | PROPUESTO |
| Recursos del hosting (CPU, RAM, disco, PHP-FPM, BD, espacio libre) | Saturación de WordPress por picos móviles | Panel del hosting | **DESCONOCIDO** (DES-10) |
| Llamadas por minuto hacia WordPress | Verificar criterio "< ~30 llamadas/min" declarado en `metrics.ts`; el `access log` de nginx es la medida final | EX-02 | EXISTE (texto) |
| Webhooks de WooCommerce a `/api/revalidate` rechazados por firma | Intento de falsificación o secreto roto | Log del BFF | PROPUESTO (AL-17; TM-053) |
| Crecimiento de `ipr_auth_sessions`/`ipr_auth_events` y ejecución de la limpieza | Falla del *job* de retención | Consulta de tamaño | PROPUESTO (AL-19; SC-071) |
| Cambios en la configuración remota (`allowedHosts`, contacto/WhatsApp, versiones) | Manipulación (TM-024, TM-040) | Auditoría de cambios en WordPress | PROPUESTO (AL-18; SC-044) |
| Eventos de Wordfence (bloqueos, escaneos) | Ataques a `wp-login.php`, `xmlrpc.php`, `ipr/v1/auth/*` | Wordfence | **DESCONOCIDO** (MED-10) |

---

## 7. Wompi y pagos

**Contexto (HECHO):** el pago ocurre dentro del checkout nativo de WooCommerce con Wompi, en el navegador seguro del sistema; la app nunca ve datos de tarjeta (ADR-001/002; `COD` §1). **Cómo confirma Wompi los pagos y cómo se evita el doble pago es DESCONOCIDO** (D-02, PA-11, SC-028): por eso el monitoreo de pagos se hace **sobre el estado del pedido en WooCommerce** (mapeo `paymentState` de `AA` §13.2) y **sobre la conciliación diaria**, no sobre eventos de Wompi que no se conocen.

| Señal | Definición operativa (PROPUESTA) | Riesgo cubierto | Origen |
|---|---|---|---|
| Tasa de pagos aprobados / fallidos / pendientes | Por hora y por día, pedidos con `_ipr_channel=app`: `paid` (`processing`/`completed`), `failed`, `cancelled`, `pending`, `on-hold`, `refunded` | Fallo de pasarela, regresión de la app, bloqueo del checkout | RNF-025; AA §13.2; AU §8.5 (`_ipr_channel`) |
| Pedidos sin confirmar | Pedidos `pending`/`on-hold` de canal app con antigüedad > 15 min (propuesta; calibrar con MED-14; en Wompi `on-hold` suele ser confirmación asíncrona, SUPUESTO PA-12) | Webhook perdido, pago realizado y pedido sin actualizar | TM-027, TM-030; SC-028 |
| **Riesgo de doble cobro** | (a) un `_ipr_checkout_ref` con > 1 pedido; (b) mismo usuario con ≥ 2 pedidos `paid` con el mismo conjunto de líneas en ≤ 10 min (propuesta); (c) `Idempotency-Key` repetida con cuerpo distinto (`409 idempotency_conflict`) como indicador de fallo de cliente | Doble toque, reintento, regreso desde el navegador, ticket reutilizado | TM-027; SC-027, SC-028; RNF-024; SLO-08 |
| Conciliación diaria | Total y número de pedidos pagados en WooCommerce vs. transacciones aprobadas en el panel de Wompi (acceso de Finanzas; **manual** al inicio) | Pago sin pedido o pedido sin pago | TM-030; SC-028 |
| Emisión de tickets | Tickets emitidos por usuario/dispositivo (límite 10/10 min), picos globales, tickets inválidos/expirados reportados por la app | Inundación (TM-029), TTL de 60 s en redes lentas (R-NF-11) | RNF-013, RNF-026; SC-029 |
| Reembolsos | Conteo de `refunded` (la app solo pinta `paid` como pagado; `refunded` y `unknown` no vacían el carrito) | Manipulación de estados | SC-025 |

**Límite honesto:** hasta que D-02/PA-11 se resuelvan y se pruebe en *staging* con Wompi sandbox (MED-14), **no se puede afirmar** que el detector de doble cobro (b) cubra todos los caminos.

---

## 8. Autenticación y sesiones

Fuente prevista: tabla de auditoría `ipr_auth_events` en WordPress (RNF-105; SC-046; `AU` §8.2) con `event_type`: `login_succeeded`, `login_failed`, `login_denied_role`, `login_throttled`, `registered`, `refresh_reused`, `session_revoked`, `logout_all`, `password_changed`, `email_changed`, `password_reset_requested/completed`, `deletion_requested/completed`, `checkout_ticket_issued`. **Hoy no existe ningún registro de eventos** (TM-058).

| Señal | Interpretación | Alerta | Origen |
|---|---|---|---|
| Intentos de login fallidos y bloqueos (`login_failed`, `login_throttled`, 429 en `/auth/*`) | Fuerza bruta / *credential stuffing* | AL-26 | TM-001, TM-057; SC-004, SC-005, SC-046 |
| Picos de login exitoso y de registro (`registered`) por IP | Cuentas falsas, campañas legítimas (comparar con comercial) | AL-30 | TM-056; SC-068 |
| **Reutilización de refresh tokens** (`refresh_reused`, `401 refresh_token_reused`) | Posible robo de sesión; o falsos positivos por carrera de renovaciones (TM-008) | AL-27 | TM-006, TM-007, TM-008; SC-002 |
| `login_denied_role` | Un administrador intenta entrar por la API de clientes (SUP-H H-09) | AL-28 | TM-010; SC-011 |
| Cambios de correo/contraseña y revocaciones (`password_changed`, `email_changed`, `session_revoked`) | Toma de cuenta; revocación no efectiva | AL-29 | TM-009, TM-033; SC-012, SC-013 |
| `deletion_requested` / `deletion_completed` | Eliminación en dos tiempos; bloqueo de cuentas ajenas; plazos Ley 1581 | revisión semanal (no alerta) | TM-034, TM-035; SC-057; RNF-058 |
| Latencia de login/refresh (p95) | Costo de la búsqueda de token (MED-16) | AL-05 | RNF-012 |

Vidas de token (SUP-H H-04, no aprobadas): access 15 min; refresh 30 d de inactividad y 90 d absolutos (SC-001). Los umbrales de AL-27 (`N` por hora) están **por definir** en SC-046; aquí se proponen valores iniciales **a calibrar** (§11).

---

## 9. App: estabilidad, ANR y adopción de versiones

| Señal | SLO / referencia | Fuente (proveedor DN-02 pendiente) | Origen |
|---|---|---|---|
| Usuarios sin fallos (crash-free) por versión, plataforma y modelo | ≥ 99,5 % (propuesta propia, más estricta que el umbral de "comportamiento deficiente" de Android vitals ≈ 1,09 % de usuarios con fallos; re-verificar) | Crashlytics o Sentry + Play Console + App Store Connect | RNF-097, RNF-098; QM-35 |
| ANR | ≤ 0,3 % (referencia de Google ≈ 0,47 %; re-verificar) | Android vitals | RNF-098; QM-36 |
| Excepciones no controladas con pila simbolizada; **0 PII** en reportes | 100 % simbolizadas | Proveedor; símbolos de ofuscación archivados (SC-041) | RNF-097, RNF-047; QM-37 |
| Nuevas firmas de fallo por versión (regresión de un *release*) | Crash-free de la versión nueva ≥ el de la anterior − 1 punto (propuesta) | Proveedor | RNF-098; TM-061 |
| Adopción de versiones y de SO (distribución agregada y anonimizada) | Disponible desde el piloto; revisión anual de RNF-078/079 | Consolas de tienda; telemetría agregada | RNF-104; R-NF-13; MED-01 |
| Respuestas `426 app_version_unsupported` y consultas a `GET /config` por versión | Verificar efecto de la versión mínima (≤ 5 min) | Log del BFF (`appVersion`, `platform`) | RNF-029; SC-052; AC EP-01 |
| Embudo (abrir, buscar, ver producto, carrito, checkout, retorno, "Más información"/WhatsApp) | 100 % de pasos instrumentados, **con consentimiento y sin PII** | Analítica (apagada hasta PA-08 y consentimiento, ADR-010) | RNF-103 |

---

## 10. Cloudflare

| Señal | Qué detecta | Fuente | Origen |
|---|---|---|---|
| % de solicitudes de la app con desafío o 403 del WAF | La app bloqueada (R-02) | Analítica/eventos de seguridad de Cloudflare (DES-04) | RNF-032; QM-45; MED-15 |
| Eventos del WAF y reglas de límite por IP en `/mobile/v1/auth/*`, `/wp-json/ipr/v1/auth/*`, `wp-login.php`, `xmlrpc.php`, `/api/auth/*`, `/api/checkout`, `/pqrs` | Ataques, reglas mal calibradas | Cloudflare | SC-005; TM-001, TM-002 |
| Picos de tráfico (× línea base) y proporción de respuestas desde caché de borde | DDoS L7, scraping, fallo de la regla de caché | Cloudflare | SC-053; TM-016, TM-020 |
| Tráfico al origen **no** originado en Cloudflare | Evasión del borde, IP de origen expuesta | Access log del origen (DES-05) | SC-010; TM-002, TM-052 |
| Vencimiento de certificados (< 14 días) y certificados nuevos del dominio (Certificate Transparency) | Caducidad; emisión no autorizada | Monitor externo / CT | SC-065; RNF-101; TM-044 |
| Respuestas `Cache-Control` de lo autenticado (`private, no-store`) | Fuga por caché de borde | Verificación periódica (sintético con cuenta de prueba) | SC-054; TM-020 |

---

## 11. Catálogo de alertas

> **Todas las alertas y umbrales son propuestas**; ninguna está montada. Severidad: SEV1 (crítica) a SEV4 (informativa), definida en [incident_response.md](incident_response.md) §2. "Notifica" son **roles** (sin nombres): Web (equipo de `ipr-frontend`/BFF), WP (quien mantiene WordPress y los snippets), Móvil, TI (infraestructura, Cloudflare, servidores, CI), Seg (seguridad), Jur (Jurídico), Fin (Finanzas), Prod (producto/negocio), Soporte (atención al cliente). Canal y guardia: DESCONOCIDOS (DES-07). Los umbrales relativos requieren línea base (DES-09). "Requiere" indica qué debe existir antes de que la alerta funcione.

### Familia A — Plataforma y BFF

| ID | Señal y condición (propuesta) | Ventana | Sev. | Notifica | Origen | Requiere | Playbook |
|---|---|---|---|---|---|---|---|
| AL-01 | Dos fallos consecutivos de `GET /api/health` | 2 sondeos (≤ 10 min) | SEV1 si falla también AL-02; si no, SEV2 | TI, Web | RNF-101, RNF-102; SLO-01 | Sintético (DES-01) | PB-01 |
| AL-02 | Fallo del sintético funcional (catálogo o sugerencias) en 2 sondeos seguidos | ≤ 10 min | SEV2 | Web, WP, TI | RNF-102; SLO-01, SLO-06 | Sintético funcional | PB-01 |
| AL-03 | *Breaker* abierto > 60 s. Con los logs de hoy: ≥ 2 mensajes `Corte de circuito ABIERTO` en 3 min, o `breaker OPEN` en 2 líneas `[wc]` seguidas | 3 min | SEV2; SEV1 si > 5 min y hay respuestas sin dato (503) | Web, WP, TI | RNF-101, RNF-022; EX-02/03 | Recolección de logs (DES-02) | PB-01 |
| AL-04 | 5xx del BFF > 2 % durante 5 min (propuesta de escalado: > 10 % → SEV1) | 5 min | SEV2 / SEV1 | Web, TI | RNF-101; SLO-03 | Log por solicitud | PB-01 / PB-02 |
| AL-05 | p95 de un endpoint > 2× su objetivo (SLO-02) durante 10 min | 10 min | SEV3; SEV2 si es login, refresh, pedidos o ticket | Web | RNF-101, RNF-012 | Log por solicitud | PB-02 |
| AL-06 | Espera en cola de `wcGet` p95 > 1,0 s (10 min) **o** respuestas `503 upstream_unavailable` por saturación > 1 % (5 min) | 5–10 min | SEV3 / SEV2 | Web | RNF-018, SC-055; TM-017 | Métrica de cola (FE-06) | PB-02 |
| AL-07 | Índice con antigüedad > 15 min; **o** `catalog_index_warming` activo > 5 min tras un arranque (calibrar con MED-17) | continuo | SEV3 / SEV2 | Web | RNF-101, RNF-023; SLO-15 | Métrica de índice | PB-01 |
| AL-08 | Canario de contenido: listado o sugerencias conocidos devuelven 0 resultados (200 vacío) | 2 sondeos | SEV2 | Web | RNF-022, RNF-023; SLO-06; TM-021 | Sintético con consulta canario | PB-01 |
| AL-09 | Memoria del proceso > 80 % del límite, **o** crecimiento > 5 %/h sostenido tras 2 h de calentamiento | 15 min / 2 h | SEV3 | Web, TI | RNF-101, RNF-016 | Métricas del proceso; DES-03 | PB-02 |
| AL-10 | Retraso del bucle de eventos p99 > 100 ms (10 min) **o** CPU p95 > 70 % (15 min) | 10–15 min | SEV3 (dispara la revisión de escalado, `AA` §14) | Web, TI | RNF-016; AA §14 | Métricas del proceso | PB-02 |
| AL-11 | Reinicio inesperado del proceso (caída del campo `uptime` fuera de la ventana de despliegue); ≥ 3 en 1 h → SEV2 | 1 h | SEV3 / SEV2 | Web, TI | EX-01; R-NF-02 | Sondeo de `/api/health` | PB-01 |
| AL-12 | p95 o tasa de error de la **web** > línea base + 10 % con tráfico móvil presente | semanal / durante piloto | SEV2 | Web, TI, Prod | RNF-015; SLO-04; ADR-001 C4 | Línea base (MED-03) y dimensión `origin` | PB-02 |
| AL-13 | Verificación posterior a un despliegue falla (health + sintético) en los 10 min siguientes | 10 min | SEV2 | Web, TI | RNF-030; SLO-16 | Ver `ci_cd.md` (otro agente) | PB-06 |
| AL-14 | Certificado por vencer en < 14 días (SEV3); < 3 días (SEV2); certificado nuevo inesperado en CT (SEV2) | diario | SEV3 / SEV2 | TI, Seg | RNF-101, SC-065; TM-044 | Monitor externo | PB-01 |

### Familia B — WordPress / WooCommerce

| ID | Señal y condición (propuesta) | Ventana | Sev. | Notifica | Origen | Requiere | Playbook |
|---|---|---|---|---|---|---|---|
| AL-15 | Errores (5xx/timeout) de llamadas BFF → `ipr/v1` > 5 % durante 5 min, o p95 > 6 s (el timeout es 8 s) | 5 min | SEV2 | WP, Web | RNF-012, SC-059 | Log por solicitud (`upstreamMs`) | PB-01 |
| AL-16 | Recursos del hosting de WordPress: CPU/RAM sostenidos altos o disco < 15 % libre (valores a definir con el hosting) | 15 min | SEV3 | WP, TI | DES-10; R-NF-01 | Monitor del hosting (DESCONOCIDO) | PB-01 / PB-02 |
| AL-17 | `/api/revalidate` rechaza > 5 firmas inválidas en 10 min | 10 min | SEV3 | Web, Seg | TM-053; SC-060 | Log del BFF | PB-05 |
| AL-18 | Cambio en la configuración remota (`allowedHosts`, número de WhatsApp, versiones mínimas) fuera de una ventana de cambio aprobada | por evento | SEV2 | WP, Seg, Web | TM-024, TM-040; SC-044 | Auditoría de cambios (WP-13) | PB-05 |
| AL-19 | La limpieza de sesiones revocadas/vencidas (30 d) o de auditoría (90 d) no se ejecutó en 48 h; tabla de sesiones crece > 3× su mediana | 48 h | SEV4 | WP | SC-071; RNF-063 | Consulta programada | — |

### Familia C — Pagos (Wompi vía WooCommerce)

| ID | Señal y condición (propuesta) | Ventana | Sev. | Notifica | Origen | Requiere | Playbook |
|---|---|---|---|---|---|---|---|
| AL-20 | ≥ 3 pedidos de canal app en `pending`/`on-hold` con antigüedad > 15 min (calibrar con MED-14) | 15 min | SEV2 | WP, Fin, Soporte | RNF-025; TM-027, TM-030 | `_ipr_channel`, `_ipr_checkout_ref` (WP) | PB-04 |
| AL-21 | (`failed` + `cancelled`) / intentos > 2× la línea base de 7 días en 1 h, con ≥ 10 intentos | 1 h | SEV3 | Web, WP, Prod | RNF-025; MED-18 | Línea base (MED-18) | PB-04 |
| AL-22 | **Posible doble cobro**: un `checkoutRef` con > 1 pedido, o ≥ 2 pedidos `paid` del mismo usuario con las mismas líneas en ≤ 10 min | por evento | **SEV1** | WP, Fin, Web, Soporte | TM-027; SC-027, SC-028; RNF-024 | `checkoutRef` en pedidos; consulta programada | PB-04 |
| AL-23 | Conciliación diaria: diferencia ≥ 1 entre pedidos pagados (WooCommerce) y transacciones aprobadas (Wompi) | diaria | SEV2 | Fin, WP | TM-030; SC-028 | Acceso de Finanzas a Wompi | PB-04 |
| AL-24 | Emisión de tickets > 10 en 10 min por usuario/dispositivo, o pico global > 3× la mediana | 10 min | SEV3 | Web, Seg | TM-029; SC-029 | Log por solicitud | PB-09 |
| AL-25 | Tickets inválidos/expirados reportados > 5 % de las aperturas en 1 h | 1 h | SEV3 | Web, Móvil | RNF-013, RNF-026; R-NF-11 | Telemetría de la app / log | PB-02 |

### Familia D — Autenticación y abuso

| ID | Señal y condición (propuesta) | Ventana | Sev. | Notifica | Origen | Requiere | Playbook |
|---|---|---|---|---|---|---|---|
| AL-26 | `login_failed` > 3× la mediana de 7 días y ≥ 100 en 5 min, **o** ≥ 20 cuentas distintas bloqueadas en 15 min | 5–15 min | SEV2 | Seg, WP, TI | TM-001, TM-002, TM-057; SC-046 | `ipr_auth_events` (WP-12) | PB-09 |
| AL-27 | `refresh_token_reused`: ≥ 5/h globales (SEV2) ≥ 20/h (SEV1); un solo evento se registra y se revisa en el día (valores iniciales; SC-046 deja `N` por definir) | 1 h | SEV2 / SEV1 | Seg, WP | TM-006, TM-007, TM-008; SC-002 | `ipr_auth_events` | PB-03 |
| AL-28 | `login_denied_role` ≥ 1 (SEV3); ≥ 5 en 1 h (SEV2) | 1 h | SEV3 / SEV2 | Seg, WP | TM-010; SC-011 (SUP-H H-09) | `ipr_auth_events` | PB-05 |
| AL-29 | `password_changed` + `email_changed` > 3× la mediana, o un cambio sensible seguido de login desde otra IP en < 10 min | 1 h | SEV3 | Seg, WP | TM-009, TM-033; SC-012 | `ipr_auth_events` | PB-03 |
| AL-30 | `registered` > 5/h por IP o > 3× la mediana global | 1 h | SEV3 | Seg, Prod | TM-056; SC-068 | `ipr_auth_events` | PB-09 |
| AL-31 | PQRS: > 5 rechazos por IP en 10 min, o volumen total > 3× la mediana diaria en 1 h, o fallos SMTP > 20 % | 10 min–1 h | SEV3 | Soporte, Web | TM-036, TM-038; SC-056 | Log del BFF | PB-10 |
| AL-32 | Scraping: un dispositivo o IP supera el límite de catálogo sostenidamente 15 min, o 429 de catálogo > 5 % | 15 min | SEV4 (riesgo aceptado con monitoreo, TM-016) | TI, Prod | TM-016; SC-005, SC-006 | Contador de 429 | PB-02 |

### Familia E — App

| ID | Señal y condición (propuesta) | Ventana | Sev. | Notifica | Origen | Requiere | Playbook |
|---|---|---|---|---|---|---|---|
| AL-33 | Crash-free < 99,5 % (24 h, con muestra mínima a definir); ≥ 1,09 % de usuarios con fallos → SEV2 (referencia de Android vitals; re-verificar) | 24 h | SEV3 / SEV2 | Móvil | RNF-098; QM-35 | Reporte de fallos (DN-02) | PB-06 |
| AL-34 | ANR > 0,3 %; ≥ 0,47 % → SEV2 (referencia; re-verificar) | 24 h | SEV3 / SEV2 | Móvil | RNF-098; QM-36 | Android vitals | PB-06 |
| AL-35 | Firma de fallo **nueva** que afecta > 1 % de usuarios de la versión nueva en 24 h, o crash-free de la versión nueva < la anterior − 1 punto | 24 h | SEV2 (evaluar *halt* del despliegue escalonado) | Móvil, Prod | RNF-098; TM-061; SC-052 | Reporte por versión | PB-06 |
| AL-36 | Tras subir la versión mínima: `426` > 1 % de solicitudes sostenido; o > 20 % de usuarios activos por debajo de la versión recomendada 30 días después de publicar la siguiente | 24 h / 30 d | SEV3 / SEV4 | Móvil, Prod | RNF-029, RNF-104; SC-052 | Log (`appVersion`) | PB-06 |
| AL-37 | Canario de PII o patrón de correo/teléfono/documento en reportes de fallos o logs: ≥ 1 | por evento | SEV2 (privacidad) | Seg, Jur, Móvil | RNF-047, RNF-061; TM-045; SC-045 | Escáner de patrones ([logging.md](logging.md) §12) | PB-08 |

### Familia F — Cloudflare y borde

| ID | Señal y condición (propuesta) | Ventana | Sev. | Notifica | Origen | Requiere | Playbook |
|---|---|---|---|---|---|---|---|
| AL-38 | Desafío o 403 del WAF sobre tráfico de la app > 0,1 % (SEV3) y > 1 % (SEV2) | 1 h | SEV3 / SEV2 | TI, Móvil | RNF-032; QM-45 | Analítica de Cloudflare (DES-04) | PB-01 |
| AL-39 | ≥ 1 solicitud al origen sin pasar por Cloudflare (IP fuera de rangos de Cloudflare) | diario | SEV3 | TI, Seg | TM-002, TM-052; SC-010 | Access log del origen (DES-05) | PB-09 |
| AL-40 | Tráfico > 5× la línea base o bloqueos del WAF > 5× la línea base | 15 min | SEV2 | TI, Seg | TM-016, TM-017; SC-053 | Analítica de Cloudflare | PB-02 / PB-09 |

**Conteo: 40 alertas** (14 de plataforma y BFF, 5 de WordPress/WooCommerce, 6 de pagos, 7 de autenticación y abuso, 5 de app, 3 de borde). Mínimo exigido por RNF-101: AL-03 (breaker), AL-04 (5xx), AL-05 (p95), AL-01 (salud), AL-07 (índice), AL-09 (memoria), AL-14 (certificado).

**Reglas de higiene de alertas (PROPUESTA).** (1) Toda alerta tiene dueño (rol) y playbook; (2) las alertas SEV3/SEV4 no despiertan a nadie fuera de horario; (3) si una alerta se dispara > 3 veces/semana sin acción, se recalibra o se elimina (revisión mensual, §16); (4) los valores relativos "× mediana" se activan solo con ≥ 14 días de línea base; (5) ninguna alerta incluye datos personales en su texto (usar `userRef`, no correo).

---

## 12. Paneles sugeridos

| Panel | Contenido | Quién lo mira | Alertas / SLO | Herramienta |
|---|---|---|---|---|
| P-01 Estado general | Semáforo: sintético (health/catálogo/login), SEV abiertos, versión desplegada, último despliegue | TI, Web, Prod | AL-01, AL-02, AL-13; SLO-01 | DESCONOCIDA (DES-01) |
| P-02 BFF y proceso | p50/p95/p99 por endpoint, 5xx/429/426/503 por `code`, memoria, bucle de eventos, CPU, reinicios | Web | AL-04..AL-11; SLO-02, SLO-03 | idem |
| P-03 Aguas arriba | `wcGet`: llamadas/min, errores, reintentos, cola, *breaker*, aciertos de caché, edad del índice; `ipr/v1`: latencia/errores por ruta; recursos del hosting | Web, WP | AL-03, AL-06, AL-07, AL-15, AL-16; SLO-05, SLO-15 | idem |
| P-04 Pagos | Embudo de checkout (ticket → pedido → pagado/fallido/pendiente), pedidos sin confirmar, candidatos a doble cobro, conciliación diaria | WP, Fin, Soporte | AL-20..AL-25; SLO-08, SLO-09 | Reportes de WooCommerce + consulta programada |
| P-05 Autenticación y abuso | Logins fallidos/exitosos, bloqueos, `refresh_reused`, `login_denied_role`, registros, PQRS, 429 | Seg, WP | AL-26..AL-32 | `ipr_auth_events` |
| P-06 App | Crash-free y ANR por versión, nuevas firmas de fallo, distribución de versiones y SO, `426`, embudo | Móvil, Prod | AL-33..AL-37; SLO-11, SLO-12 | Proveedor DN-02 + consolas de tienda |
| P-07 Borde | Solicitudes, caché de borde, WAF (desafíos/403 de la app), reglas de límite, tráfico no-Cloudflare al origen | TI, Seg | AL-38..AL-40; SLO-10 | Cloudflare |
| P-08 SLO y presupuesto de error | Cumplimiento de SLO-01..16 en 30 días; presupuesto de error consumido | Gerencia, TI, Web | §4 | idem |

---

## 13. Monitoreo sintético (PROPUESTA; RNF-102)

| Sondeo | Frecuencia | Qué valida | Ambiente | Restricción |
|---|---|---|---|---|
| `GET /api/health` | ≤ 5 min | Proceso vivo; `uptime` (reinicios) | Producción | Es **solo** vida; no sustituye al funcional (EX-01) |
| `GET /mobile/v1/config` | ≤ 5 min | `minSupportedVersion` y `features` coherentes; respuesta cacheable | Producción | Solo lectura |
| Catálogo (listado + ficha de producto conocido) y sugerencias (consulta canario con resultados garantizados) | ≤ 5 min | Cruza WooCommerce/índice; detecta 200 vacíos (AL-08) | Producción | Producto canario estable y publicado |
| Login con **cuenta de prueba dedicada y autorizada** + `GET /me` + refresh | ≤ 5 min (propuesta: 15 min para no inflar auditoría) | WordPress, sesiones, rotación | Producción | Cuenta de rol `customer` sin pedidos reales; contraseña en gestor de secretos; los eventos de esta cuenta se **excluyen** de AL-26/AL-30 por `userRef` |
| `POST /checkout` (ticket) y pago sandbox | por *release* y diario | Ticket → checkout → retorno | **Solo staging** (RNF-102: no crear actividad real en producción) | Requiere staging (DES-06) |
| Cabecera `Cache-Control: private, no-store` en una ruta autenticada | diario | Evita fuga por caché de borde (TM-020) | Producción | — |
| Expiración de certificados / CT | diario | AL-14 | Producción | — |

Los sondeos deben salir **desde fuera** de la infraestructura de IPR (y, si es posible, desde dos ubicaciones) para que midan también Cloudflare. Herramienta: DESCONOCIDA (DES-01).

---

## 14. Instrumentación que debe existir (NO se programa aquí; insumo para desarrollo)

| # | Qué falta | Dónde | Referencia | Alertas que habilita |
|---|---|---|---|---|
| I-01 | Log JSON por solicitud con `requestId`, ruta plantilla, `status`, `durationMs`, `cache`, `upstreamMs`, `appVersion`, `platform`, `userRef`, `deviceRef`, `ipPrefix` | BFF (`lib/mobile/http.ts`) | AA §12; SC-045; RNF-099 | AL-04, AL-05, AL-15, AL-25, AL-31, AL-36 |
| I-02 | Métricas por endpoint (histogramas), por `code`, y dimensión `origin=web|mobile` en `metrics.ts` | BFF | AA §12; WCA §5.4 punto 6; RNF-100 | AL-04, AL-05, AL-12 |
| I-03 | Métrica y tope de la cola de `wcGet` (espera p95; 503 si > 3 s) | `client.ts` | FE-06; RB-03; SC-055 | AL-06 |
| I-04 | Edad y tamaño del índice; aviso si `totalPages > 100`; `readiness` | `woocommerce.ts` | RB-06; AA §14; RNF-023 | AL-07 |
| I-05 | Métricas del proceso (RSS, *heap*, bucle de eventos, CPU) y endpoint interno protegido | BFF | RNF-016, RNF-100; AA §12 | AL-09, AL-10 |
| I-06 | Cabecera `X-IPR-Data-State` (`fresh`/`stale`) y errores discriminados (503/502/504 en vez de vacío/null) | BFF | RB-02; AA §6.3 | AL-08, SLO-06 |
| I-07 | Tablas `ipr_auth_events`, `ipr_auth_throttle` y propagación de `X-IPR-Request-Id` | WordPress | WP-12; AU §8; SC-046 | AL-26..AL-30 |
| I-08 | `_ipr_checkout_ref` y `_ipr_channel` en pedidos | WordPress | AU §8.5; ADR-017 | AL-20..AL-23 |
| I-09 | Auditoría de cambios de la configuración remota | WordPress | SC-044; WP-13 | AL-18 |
| I-10 | `CrashReporter` con `PiiScrubber`, proyectos por *flavor*, símbolos archivados | App | ADR-010; SC-047; RNF-097 | AL-33..AL-37 |
| I-11 | Registro de acceso del origen con la IP real y sin la query del ticket | nginx/Plesk | SC-072; DES-05, DES-13 | AL-39 |
| I-12 | Quitar `version` de `/api/health` público (conservar `uptime`) | `health/route.ts` | SC-061, CH-25 | EX-01 |

---

## 15. Verificación de las alertas

1. **Simulacro por alerta en staging** (RNF-101 exige simulacro de cada alerta): bloquear `wc/v3` (AL-03, AL-02), forzar 5xx, saturar la cola, retrasar el índice, ficticios `refresh_reused`, pedidos `pending` sintéticos, canario de PII. Resultado archivado (ID, fecha, tiempo hasta notificación, rol que respondió). **Hoy no hay staging confirmado (DES-06)**: sin él, los simulacros intrusivos no se hacen en producción (D-16).
2. **Revisión de alertas** tras cada incidente SEV1/SEV2 (¿se disparó? ¿a tiempo? ¿a quién?).
3. **Prueba de la ruta de notificación** trimestral (que la guardia reciba un aviso de prueba).
4. Evidencia de cierre del criterio QM-46: "alertas operativas activas = al menos las de RNF-101".

---

## 16. Revisión periódica del monitoreo

| Actividad | Frecuencia | Rol | Evidencia |
|---|---|---|---|
| Revisión de SLO y presupuesto de error | Mensual | Web + TI | Panel P-08 y acta |
| Recalibración de umbrales con línea base | Mensual los 3 primeros meses; luego trimestral | Web + WP | Cambios registrados |
| Revisión de alertas ruidosas/mudas | Mensual | TI | Lista de ajustes |
| Conciliación de pagos (Wompi vs. WooCommerce) | Diaria (manual al inicio) | Fin + WP | Registro firmado |
| Revisión de adopción de versiones y SO (ajustar RNF-078/079) | Anual (y tras cada *release* mayor) | Móvil + Prod | RNF-104 |
| Revisión de acceso a paneles y logs | Trimestral | Seg + TI | Lista de accesos |

---

## 17. Hechos, supuestos, riesgos y decisiones pendientes

### 17.1 Supuestos

| ID | Supuesto | Si es falso |
|---|---|---|
| SOP-01 | El BFF corre en el proceso Next.js actual (ADR-001) y comparte recursos con la web; 1 proceso. | Si hay N procesos, las métricas y el *breaker* son por proceso (N índices, N breakers): hay que agregar y alertar por instancia (`WCA` §5.3). |
| SOP-02 | Se podrá añadir una dimensión `origin` y logs estructurados sin romper la web (RNF-099, `WCA` §5.4). | El monitoreo de impacto en la web (SLO-04) se limita a comparaciones indirectas. |
| SOP-03 | SUP-H H-04, H-05, H-09 se aprueban tal como se recomiendan (AL-27, AL-28, PB-03). | Ajustar umbrales y eventos de §8. |
| SOP-04 | La cuenta de prueba del sintético está autorizada por IPR (RNF-102). | Se reduce el sintético a lectura. |

### 17.2 Riesgos

| ID | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| ROP-01 | Se declara "monitoreado" un sistema cuyos logs nadie recoge (DES-02) | Alta | Alto | No dar por activa ninguna alerta hasta el simulacro (§15). |
| ROP-02 | `/api/health` verde con WooCommerce caído da falsa seguridad (EX-01) | Alta | Alto | Sintético funcional (AL-02, AL-08). |
| ROP-03 | Umbrales relativos sin línea base generan ruido o silencio (DES-09) | Alta | Medio | Activar tras 14 días; recalibración mensual. |
| ROP-04 | Alertas con PII en el texto o logs de monitoreo con datos personales (TM-045) | Media | Alto | Reglas de higiene §11; AL-37; [logging.md](logging.md). |
| ROP-05 | Un solo proceso: el propio monitoreo (agente, recolector) consume recursos del servidor compartido | Media | Medio | Preferir monitoreo externo y logs agregados (AA §12). |
| ROP-06 | Sin guardia fuera de horario, un SEV1 nocturno se detecta al día siguiente (DN-06) | Alta | Alto | Decisión de Gerencia sobre cobertura (DOP-01). |
| ROP-07 | El detector de doble cobro depende de campos aún no creados y de D-02 | Alta | Alto | NL-02: no lanzar sin cerrar D-02/PA-11. |

### 17.3 Decisiones pendientes

| ID | Decisión | Recomendación inicial | Quién decide |
|---|---|---|---|
| DOP-01 | Cobertura de guardia y canal de alertas (horario comercial vs. extendido para SEV1) | Horario comercial para SEV3/4; SEV1/SEV2 con guardia acordada en el piloto (DN-06) | Gerencia + TI |
| DOP-02 | Herramienta de monitoreo/logs y su ubicación (propia o servicio externo) y su tratamiento de datos | Servicio externo para sintético (no consume el servidor compartido); logs agregados con retención ≤ 90 días (RNF-063); evaluar transferencia con Jurídico | TI + Jurídico |
| DOP-03 | Quién concilia pagos y con qué frecuencia | Finanzas, diaria, durante el piloto | Gerencia + Finanzas |
| DOP-04 | Muestra mínima y umbrales de calidad en estabilidad (crash-free con pocos usuarios) | Definir en el piloto con datos reales | Móvil + Prod |
| D-02 / PA-11 | Confirmación de pagos y doble cobro (de documentos previos) | Ver `decisiones_pendientes.md` | Equipo web + Finanzas |

*Fin del documento. BORRADOR sujeto a validación de IPR; los umbrales se confirman o ajustan con las mediciones MED-xx y el piloto.*

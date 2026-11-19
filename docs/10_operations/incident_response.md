# Respuesta a incidentes — App IPR, BFF `/mobile/v1`, WordPress/WooCommerce y Wompi

| | |
|---|---|
| **Fase** | OPERACIÓN (documentación). **No se programa ni se configura nada.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. **Nada de lo descrito está montado ni ensayado.** Los playbooks nombran palancas (interruptores, revocación global, versión mínima, *halt* de despliegue) que **son propuestas de diseño** (SC-052, SC-066, RNF-029): hasta que existan y se ensayen en *staging* (CH-29, ST-156, ST-128), el playbook correspondiente indica la alternativa manual y su límite. |
| **Relacionado** | [monitoring.md](monitoring.md) (alertas AL-xx) · [logging.md](logging.md) · [maintenance.md](maintenance.md) · `../06_security/security_controls.md` (SC-066) · `../06_security/privacy_assessment.md` (R-P11, J-26) |
| **Fuentes** | `SC`/`TM` = `06_security/`; `RNF` = `02_requirements/non_functional_requirements.md`; `AA` = `05_api/api_architecture.md`; `AU` = `05_api/authentication.md`; `AC` = `05_api/api_contracts.md`; `PRIV` = `06_security/privacy_assessment.md`; `COD`/`WCA` = `00_discovery/`; `DEP` = `03_architecture/deployment_architecture.md` |

Etiquetas: **HECHO** · **SUPUESTO** (los `SUP-H` son H-01..H-12 de `decisiones_pendientes.md` §E, **no aprobadas**) · **PROPUESTA** · **DECISIÓN PENDIENTE** (`DOP-xx`) · **RIESGO** (`ROP-xx`) · **DESCONOCIDO** · **NO VERIFICADO** · **A VALIDAR (Jur)**.

**Este documento no es asesoría legal.** Las obligaciones legales de §9 se citan con su estado de verificación; las decisiones legales las toma el Jurídico de IPR.

---

## 1. Alcance, principios y limitaciones

| # | Principio |
|---|---|
| R-01 | **Contener primero, entender después**, siempre que la contención sea reversible y de bajo costo. |
| R-02 | **Un solo comandante de incidente (IC)** por incidente; las decisiones de alto impacto (apagar el checkout, comunicar públicamente, notificar a la SIC, mover dinero) se aprueban según §3. |
| R-03 | **Nada de PII ni secretos en canales de incidente** (chat, correo, tickets). Se usan `userRef`, `requestId`, `checkoutRef`, `session_uuid` ([logging.md](logging.md)). |
| R-04 | **Preservar evidencia mínima** antes de reiniciar o limpiar (extractos de logs, hora, estado de configuración). |
| R-05 | **Post-mortem sin culpables**: se analizan sistemas, supuestos y señales, no personas. |
| R-06 | **No se declara resuelto sin verificación** (criterio de cierre por playbook). |
| R-07 | **No se mueve dinero, no se aceptan términos ni se negocia con atacantes** sin aprobación de Gerencia y Jurídico. |

**Limitaciones honestas (HECHO/DESCONOCIDO).**
- La app y `/mobile/v1` no existen: los playbooks son el **diseño operativo** que debe estar listo antes del piloto (criterio de salida de F4/F5: manual ensayado, SC-066).
- Hoy **no hay** monitoreo, auditoría de eventos ni canal de guardia documentados (DES-01, DES-07 de [monitoring.md](monitoring.md); TM-058).
- Se desconocen: topología (procesos, RAM), existencia de *staging*, plan de Cloudflare, acceso a la base de datos de WordPress en emergencia, contratos con proveedores (hosting, Wompi, Cloudflare, DigitalOcean, SMTP), roles de WordPress y existencia de 2FA en administradores.
- Caminos de reversa del BFF no documentados (RNF-030: "DESCONOCIDO").

---

## 2. Clasificación de severidad

> Los tiempos son **propuestas**; la cobertura real (horario, guardia) es la decisión DN-06 / DOP-01 (propuesta DN-06: soporte en horario comercial). Fuera de cobertura, el SEV1 se atiende "al inicio de la cobertura siguiente" salvo acuerdo contrario.

| Sev. | Criterio (basta uno) | Ejemplos | Reconocimiento (propuesta) | Primera contención (propuesta) | Actualizaciones | Quién declara |
|---|---|---|---|---|---|---|
| **SEV1 Crítico** | Servicio principal caído para (casi) todos; **pérdida económica o de datos en curso**; compromiso de cuentas privilegiadas o secretos; fuga o robo **confirmado** de tokens o datos personales; **doble cobro confirmado** | AL-01 + AL-02; AL-22 confirmada; PB-03 global; PB-05; PB-08 con datos accedidos | ≤ 15 min | ≤ 1 h | Cada 30 min al equipo; a Gerencia cada hora | IC (o cualquier miembro, hasta que haya IC) |
| **SEV2 Alto** | Degradación severa o una función crítica caída (checkout, login); *breaker* abierto sin dato servible; *release* con pico de fallos; ataque activo de fuerza bruta; pedidos pagados sin confirmar; **cualquier sospecha de incidente con datos personales** (mínimo SEV2 y se avisa a Jur) | AL-03 sostenida, AL-04, AL-20, AL-26, AL-35, AL-37 | ≤ 1 h | ≤ 4 h | Cada 60 min | IC |
| **SEV3 Medio** | Degradación parcial o riesgo creciente sin impacto amplio; alerta de umbral; abuso moderado | AL-05, AL-06, AL-09, AL-24, AL-29, AL-33 | Mismo día hábil | 1 día hábil | Al cambiar el estado | Web/WP/Móvil de turno |
| **SEV4 Bajo** | Informativo; sin impacto; observación para el mantenimiento | AL-19, AL-32, AL-36 | Semana | Plan en el ciclo de mantenimiento | — | Quien lo detecte |

**Reglas de escalado.** (1) Ante duda, se declara la severidad **más alta** y se baja con evidencia. (2) SEV3 que dura > 24 h o se repite 3 veces pasa a SEV2. (3) Todo incidente que involucre datos personales de titulares se trata como **mínimo SEV2** hasta que el Jurídico determine otra cosa. (4) Una alerta de monitoreo ([monitoring.md](monitoring.md) §11) trae su severidad inicial; el IC puede cambiarla.

---

## 3. Roles y responsabilidades (por rol, sin nombres)

> Equipos tomados de `security_controls.md`: **Web** (equipo de `ipr-frontend`/BFF), **WP** (quien mantiene WordPress y los snippets), **Móvil** (equipo de la app, por definir, D-15), **TI** (infraestructura, Cloudflare, servidores, CI), **Seg**, **Jur**, **Prod**. Añadidos operativos: IC, Fin, Soporte, Comunicaciones, Gerencia, Escriba. **Quién ocupa cada rol y sus suplentes: DESCONOCIDO; debe asignarse antes del piloto (DOP-07).**

| Rol | Responsabilidades en un incidente | Decide / aprueba |
|---|---|---|
| **IC — Comandante de Incidente** (rol rotativo entre Web y TI; no el que está depurando) | Declara y clasifica; asigna roles; coordina; mantiene el canal único; fija cadencia de actualizaciones; decide cuándo bajar/subir severidad y cerrar | Severidad; contención reversible de bajo costo (p. ej. reglas de límite, reinicio justificado) |
| **Web** (BFF/Next) | Diagnóstico de `/mobile/v1`, logs, métricas, *rollback* del BFF, interruptores remotos (`GET /config`) | Rollback del BFF (con IC) |
| **WP** | Diagnóstico y cambios en WordPress/WooCommerce y snippets (`ipr/v1`), revocación de sesiones, estados de pedido, usuarios y roles | Cambios en WordPress de emergencia (con IC) |
| **Móvil** | Datos de estabilidad, *halt* de despliegue escalonado, hotfix, versión mínima, builds firmados | Pausa de despliegue en tiendas (con IC) |
| **TI** | Cloudflare (reglas, límites), servidor, firewall, certificados, rotación de secretos de infraestructura, CI/despliegue, copias de seguridad | Reglas de borde; reinicios de infraestructura |
| **Seg** | Clasificación de seguridad, alcance, evidencia, análisis de causa, recomendación de rotaciones y revocaciones | Declara "incidente de seguridad" (con IC y Jur) |
| **Jur** | Determina si hay incidente con datos personales y las obligaciones (SIC, titulares, contratos); aprueba textos legales; custodia el registro | **Notificaciones a la SIC y a titulares** (con Gerencia) |
| **Fin** | Conciliación de pagos, contacto con Wompi, reembolsos/anulaciones, impacto económico | **Cualquier movimiento de dinero** (con Gerencia) |
| **Soporte** | Atención a clientes, registro de casos, uso de plantillas aprobadas, recolección de `requestId` | — |
| **Comunicaciones / Prod** | Comunicados públicos y de tienda (texto, canales), coordinación comercial (WhatsApp/asesores) | Texto final de comunicados (con Jur si hay datos personales) |
| **Gerencia** | Decisiones de alto impacto: apagar el checkout o la app, comunicado público, notificación a la SIC, presupuesto de remediación/forense externo | Las anteriores |
| **Escriba** | Línea de tiempo en tiempo real (hora UTC, decisión, quién, evidencia) | — |
| **Responsable/área de protección de datos de IPR** | Punto de contacto para el titular y para la SIC (designación DESCONOCIDA; **A VALIDAR por Jurídico**) | — |

**Directorio de contactos de incidentes (DESCONOCIDO).** Debe existir, por **rol** y con suplente, incluyendo contactos de soporte de Cloudflare, DigitalOcean, hosting de WordPress/Plesk, Wompi, SMTP, Google Play y Apple. Se guarda en el gestor de secretos o repositorio privado, **no en este documento**.

---

## 4. Flujo del incidente

| Fase | Objetivo | Acciones (PROPUESTA) | Responsable principal | Salida |
|---|---|---|---|---|
| **0. Preparación** | Estar listos antes | Roles asignados; directorio; paneles ([monitoring.md](monitoring.md)); palancas probadas (§5); plantillas (§8); ensayo semestral | TI + Seg | Manual ensayado (CH-29) |
| **1. Detección** | Saber que ocurre | Alerta AL-xx, reporte de Soporte (con `requestId`), tienda (reseñas, consolas), proveedor, investigador externo | Quien detecta | Registro inicial (hora UTC, fuente) |
| **2. Triage** | Clasificar y decidir | Confirmar con una segunda señal; severidad (§2); ¿datos personales? (si sí → mínimo SEV2 + aviso a Jur y Gerencia); ¿dinero? (aviso a Fin) | Quien detecta → IC | Incidente declarado; IC y Escriba asignados; canal único |
| **3. Contención** | Detener el daño, reversible | Palancas de §5 según playbook; **preservar evidencia mínima antes** (R-04) | IC + dueño técnico | Daño detenido o acotado |
| **4. Erradicación** | Quitar la causa | Corregir el defecto, cerrar el acceso, rotar secretos comprometidos, parchear, revisar persistencia de atacantes | Dueño técnico + Seg | Causa eliminada |
| **5. Recuperación** | Volver a operar con confianza | Restaurar funciones, reactivar interruptores, monitoreo reforzado ≥ 72 h (propuesta), verificación del criterio de cierre | Dueño técnico + IC | Servicio normal verificado |
| **6. Comunicación** (transversal) | Informar con exactitud | §8; un solo portavoz por público (interno, usuarios, tiendas, autoridades); sin PII ni especulación; cadencia por severidad | Comunicaciones/Prod (+ Jur) | Comunicados enviados y registrados |
| **7. Cierre y post-mortem** | Aprender | Reunión **sin culpables** en ≤ 5 días hábiles (propuesta) para SEV1/SEV2; documento (§8.7); acciones con dueño y fecha entran al seguimiento ([maintenance.md](maintenance.md) §10) | IC | Post-mortem aprobado y acciones registradas |

**Reglas del post-mortem sin culpables.** (1) Se describen hechos y decisiones con la información que se tenía en el momento; (2) se preguntan "¿qué lo permitió?" y "¿qué lo habría detectado antes?", no "¿quién falló?"; (3) cada acción es verificable, con dueño (rol) y fecha; (4) el documento no incluye PII ni secretos; (5) se comparte con todo el equipo; (6) para incidentes con datos personales, la versión completa se restringe a Seg, Jur y Gerencia.

---

## 5. Palancas de contención: qué existe y qué es propuesto

| Palanca | Qué hace | Estado | Límites / notas | Origen |
|---|---|---|---|---|
| **Interruptores remotos** (`features.checkoutEnabled`, `pqrsEnabled`, `btuCalculatorEnabled`) en `GET /config` | Apaga funciones sin publicar una versión | **PROPUESTO** (no existe) | Efecto ≤ 5 min (propuesta); la app muestra mensaje de mantenimiento (`503 feature_disabled`). No hay interruptor de catálogo/búsqueda en el contrato actual (**DOP-08**). | RNF-029; SC-052; AC EP-01 |
| **Versión mínima forzada** (`minSupportedVersion` → `426 app_version_unsupported` + pantalla de actualización) y `recommendedVersion` (aviso suave) | Obliga o invita a actualizar | **PROPUESTO** | **Solo subirla cuando la versión corregida ya esté disponible en tienda** (si no, el usuario queda bloqueado frente a una pantalla sin salida). Aviso suave primero. | SC-052; AA §5; TM-061 |
| **Revocación de sesiones** por sesión, por usuario y global | Cierra sesiones de la app y de la web heredada | **PROPUESTO** (SC-012, SC-066; WP-05). Hoy: un token por usuario; sin endpoint de revocación global | Alternativa manual hasta que exista: acción directa sobre la base de datos de WordPress (acceso DESCONOCIDO). `POST ipr/v1/m/sessions/revoke` con `scope=all` solo cubre al propio usuario. | AU §8.1, §10; SC-012 |
| **Rotación de secretos** (HANDOFF, BFF, WooCommerce, `REVALIDATE_SECRET`, SMTP, despliegue) | Anula credenciales comprometidas | **PROPUESTO** (procedimiento en [maintenance.md](maintenance.md) §6); rotación hoy no documentada | Con doble valor en WordPress durante la rotación (WP-16). | SC-039; TM-060 |
| **Reglas de Cloudflare** (bloqueo por IP/ASN/país/ruta, límites, caché de borde) | Corta tráfico abusivo; absorbe lectura | **EXISTE** Cloudflare; **reglas y plan DESCONOCIDOS** (AP-08) | **No usar desafíos interactivos en `/mobile/v1/*`** (la app no los resuelve; R-02). Modo "bajo ataque" afectaría a la app: evaluar. | SC-005, SC-053 |
| **Reversa del BFF** | Vuelve a la versión anterior del despliegue | **PROPUESTO** (≤ 15 min, ensayada una vez en *staging*, RNF-030) | Procedimiento actual **no documentado**; reiniciar **borra** caché SWR, índice y contadores de rate limit. Ver `../09_devops/ci_cd.md` (otro agente). | RNF-030; ADR-001 |
| **Pausa/detención del despliegue escalonado** en las tiendas | Detiene la llegada de una versión defectuosa a más usuarios | **PROPUESTO** (capacidad de Google Play y App Store; requiere cuentas de IPR, D-14) | Los usuarios que ya actualizaron **conservan** la versión: no hay "retroceso" en las tiendas, se publica una **corrección con número de versión mayor** (verificar en la documentación vigente de cada tienda). Detalle en PB-06. | SC-066; RNF-055 |
| **Desactivar snippet/ruta de WordPress** (p. ej. `ipr/v1/m/*` o el *handoff*) | Corta una superficie atacada | **PROPUESTO**; mecanismo de publicación de cambios en WordPress: DESCONOCIDO | El *handoff* también lo usa la web: apagarlo apaga el pago web (decisión de Gerencia). | TM-010; DEP §12c |
| **Bloqueo de cuentas** (`pending_deletion`, cambio de contraseña, rol) | Aísla una cuenta | **PROPUESTO** (SC-057) | — | SC-057 |

---

## 6. Playbooks

Convención: **Disparadores** (alertas de [monitoring.md](monitoring.md) §11); **Sev. inicial**; **Roles**; pasos de **Diagnóstico → Contención → Erradicación → Recuperación**; **Comunicación**; **Cierre**; **Lo que no se sabe**. Los pasos son una guía; el IC puede desviarse con justificación en la línea de tiempo.

### PB-01 — Caída de WooCommerce, WordPress o del BFF

| | |
|---|---|
| **Disparadores** | AL-01, AL-02, AL-03, AL-04, AL-07, AL-08, AL-11, AL-14, AL-15, AL-16, AL-38 |
| **Sev. inicial** | SEV2; **SEV1** si el sintético funcional falla (catálogo + login) o el *breaker* sigue abierto sin datos servibles > 5 min |
| **Roles** | IC, Web, WP, TI; Soporte y Comunicaciones (si dura); Gerencia (SEV1) |
| **Origen** | RNF-019, RNF-022, RNF-023; TM-017, TM-021; SC-047, SC-052 |

**1. Diagnóstico (primeros 15 min): ¿qué componente?**

| Síntoma | Causa probable | Cómo confirmarlo |
|---|---|---|
| `GET /api/health` falla | Proceso Node o servidor caído, o Cloudflare/origen inaccesible | Sondeo desde fuera; panel del servidor (DES-03); estado de Cloudflare |
| `health` OK, catálogo/sugerencias fallan, mensajes `Corte de circuito ABIERTO` | **WooCommerce/WordPress caído o lento** | Logs `[wc]`/`[woocommerce]`; panel del hosting de WordPress; abrir `wp-json` desde fuera |
| `health` OK, catálogo OK, login/pedidos fallan | `ipr/v1` (WordPress PHP/BD) | AL-15; logs del BFF (`upstreamMs`) |
| Búsqueda vacía o `503 catalog_index_warming` tras un reinicio | **Índice no listo** (arranque en frío) | AL-07; tiempo desde el último reinicio (`uptime`) |
| Pico de 403/desafíos | Regla de Cloudflare o WAF bloqueando la app | AL-38; analítica de Cloudflare |
| Todo falla justo después de un despliegue | Cambio defectuoso | AL-13 → **PB-06** (rollback del BFF) |

**2. Contención.**
1. **No reiniciar el proceso Node si el problema es WooCommerce caído.** La caché SWR (dato vencido hasta 24 h) y el índice viven **en memoria**: un reinicio los borra y convierte una degradación en caída total (HECHO: `WCA` §5.1, §5.2). Reiniciar solo si el proceso mismo está colgado o sin memoria.
2. Si WooCommerce/`ipr/v1` no responden: el BFF debe servir catálogo **desde caché** marcado `stale` y responder `503` tipificado (RNF-022). Si el checkout no puede completarse (tickets que no se podrán usar en 60 s), **apagar `checkoutEnabled`** (IC + Gerencia).
3. Si el origen es Cloudflare/regla: revertir la última regla (TI).
4. Si es WordPress: WP/hosting restauran el servicio (reinicio de PHP-FPM/BD, espacio en disco, plugin defectuoso desactivado). Evaluar si la causa es carga móvil → **PB-02**.
5. Si es un 403 del WAF a la app: ajustar la regla con excepción por cabecera/ruta **sin desactivar el WAF general** (SC-053).

**3. Erradicación.** Causa raíz: plugin, actualización, disco, límite de procesos de PHP, pico de tráfico, vencimiento de certificado, cambio de DNS. Corregir y documentar.

**4. Recuperación.** Esperar el cierre del *breaker* (30 s tras una prueba exitosa); verificar el sintético funcional (AL-02/AL-08 en verde), el índice listo y el tiempo de la cola; reactivar `checkoutEnabled` y hacer **una compra de prueba en staging** o, si no hay staging, una verificación de ticket con cuenta de prueba (no crear actividad real, RNF-102).

**5. Comunicación.** Interna (C-1) desde SEV2. A usuarios (C-2) si el impacto > 30 min o afecta checkout: mensaje en la app (el contrato **no** incluye un banner de mantenimiento: la app informa por `503 feature_disabled`, **DOP-08**) y canales de IPR (WhatsApp/redes, Prod). Soporte recibe respuestas aprobadas.

**6. Cierre.** Sintético verde ≥ 30 min; sin 200 vacíos (AL-08); `checkoutEnabled` activo; post-mortem si SEV1/SEV2.

**No se sabe:** quién administra el servidor y WordPress en emergencia y fuera de horario; procedimiento de reinicio/reversa documentado; límites de PHP-FPM y BD; existencia de una página de estado.

---

### PB-02 — Degradación por carga móvil

| | |
|---|---|
| **Disparadores** | AL-05, AL-06, AL-09, AL-10, AL-12, AL-25, AL-32, AL-40 |
| **Sev. inicial** | SEV3; **SEV2** si la **web** se degrada > 10 % (AL-12) o hay 503 por saturación |
| **Roles** | IC, Web, TI, WP; Móvil y Prod (si la causa es la app o una campaña) |
| **Origen** | RNF-014..018; TM-016, TM-017; ADR-001 C4; AA §14 |

**1. Diagnóstico.** Identificar el **origen** de la carga: (a) pico legítimo (campaña, comunicación comercial: preguntar a Prod); (b) *scraping* o abuso (muchas IP/dispositivo, 429); (c) **defecto de la app** (bucle de reintentos, sugerencias sin *debounce*, `perPage` distintos que rompen la caché, polling del estado de pago); (d) cola de `wcGet` llena por reconstrucción del índice tras webhooks masivos (`WCA` §5.4 punto 2); (e) memoria/bucle de eventos del proceso (AL-09/10).
Mirar: razón de aciertos de caché (borde y SWR), espera en cola, 5xx, `appVersion` de las solicitudes más frecuentes, distribución por `route`.

**2. Contención (de menos a más invasiva).**
1. Subir la caché de borde de los endpoints públicos de catálogo (Cache Rule, SC-053) y el TTL de sugerencias (TI).
2. Endurecer límites por IP/dispositivo en Cloudflare y en el BFF (SC-005, SC-006).
3. Bloquear IP/ASN abusivos (TI).
4. Si es defecto de la app: **PB-06** (pausar despliegue; interruptor remoto de la función; hotfix).
5. Si el proceso se satura: reiniciar **solo** si está degradado de forma irrecuperable (recordar PB-01 paso 1: se pierde caché e índice).
6. Último recurso: **proteger la web** limitando el tráfico móvil (p. ej. regla de Cloudflare que devuelva `503` con `Retry-After` a `/mobile/v1/*`) — decisión de IC + Gerencia, **porque deja la app inservible** (DOP-08).

**3. Erradicación y capacidad.** Aplicar los disparadores de `AA` §14 en orden: (1) revisar reglas de caché/TTL; (2) segundo proceso Node **y entonces** almacén compartido (Redis) para rate limit/idempotencia; (3) separar el BFF (alternativa que ADR-001 descartó y se reabre). Verificar RB-04 (índice duplicado) y RB-06 (`totalPages > 100`).

**4. Recuperación.** p95 y 5xx dentro de SLO-02/SLO-03; la **web** vuelve a su línea base (SLO-04); retirar bloqueos temporales.

**5. Comunicación.** Interna; usuarios solo si hubo `503` visibles (C-2). Prod informa si una campaña causó el pico.

**6. Cierre.** Cola p95 ≤ 1 s; AL-12 en verde ≥ 24 h; acción de capacidad registrada en el seguimiento.

**No se sabe:** capacidad real del servidor, perfil de carga (DN-07, MED-01, MED-04); si Cloudflare del plan actual permite las reglas necesarias (DES-04).

---

### PB-03 — Fuga o robo de tokens (revocación global)

| | |
|---|---|
| **Disparadores** | AL-27, AL-29; hallazgo de tokens en logs/repositorios/capturas/terceros; fallo de SC-003; pérdida de un secreto; reporte de un usuario o investigador |
| **Sev. inicial** | SEV2; **SEV1** si hay uso fraudulento confirmado, hay fuga masiva o es global |
| **Roles** | IC, Seg, WP, Web, TI, Móvil; Jur (si se accedió a datos personales → **PB-08**); Soporte, Comunicaciones |
| **Origen** | TM-004, TM-005, TM-006, TM-009, TM-013; SC-001..003, SC-012, SC-033, SC-066; AU §8.1; RNF-040 |

**Contexto técnico (HECHO/PROPUESTA).** Hoy (web) hay **un token por usuario**, 30 días fijos, aceptado por *query string* (`ipr/v1`, H-01/H-02/H-03); el ticket de checkout guarda el token en un *transient* de 60 s (TM-013). La propuesta (SC-001/002; SUP-H H-04, **no aprobada**) usa tokens opacos de 256 bits, access 15 min y refresh rotativo con detección de reutilización (30 d de inactividad / 90 d absolutos), almacenados como SHA-256 en `ipr_auth_sessions`; **una fuga de la base de datos no revela tokens utilizables** (solo hashes), pero un token expuesto en logs o capturas sí. SUP-H H-05: el MVP solo ofrece "cerrar todas las sesiones" (incluida la web).

**1. Diagnóstico y alcance (Seg + WP).**

| Alcance | Cómo se determina | Acción de revocación |
|---|---|---|
| **A. Un dispositivo o usuario** | Reporte del usuario; `refresh_reused` aislado | Revocar la(s) sesión(es): `revoked_reason = admin`; el usuario recibe 401 y la app pide login |
| **B. Un lote** (p. ej. ventana de logs expuesta, versión de la app) | Rango de tiempo / versión / canal | Revocar por filtro (usuario, `client_type`, `app_version`, ventana) |
| **C. Global** | Fuga del almacén de hashes sin certeza, **vulnerabilidad en emisión/rotación**, secreto de emisión comprometido, tokens en logs históricos | **Revocación global** (abajo) |

**2. Contención.**
1. Preservar evidencia mínima (extracto de eventos y logs con `userRef`, no PII).
2. **Revocación (propuesta de procedimiento):**
   - App: marcar como revocadas todas las filas activas de `ipr_auth_sessions` (`revoked_at`, `revoked_reason='admin'`); registrar un evento de auditoría por lote.
   - Web heredada: eliminar `_ipr_auth_token_hash` y `_ipr_auth_token_exp` de los usuarios (HECHO: metadatos actuales, `AU` §8.5).
   - Sesiones de cookie de WordPress ya iniciadas por *handoff*: **destruir sesiones** de WordPress de los usuarios afectados; **cambiar las claves/sales de autenticación de WordPress** invalida todas las cookies (incluidas las de administradores): decisión de WP + Gerencia.
   - **Ejecutar con el rol WP y registro de quién, cuándo y por qué.** Hoy **no existe herramienta ni endpoint** para esto (SC-066); el acceso de emergencia a la BD de WordPress es **DESCONOCIDO** (DOP-09): debe resolverse antes del piloto.
3. Si la causa es un secreto: rotarlo (`maintenance.md` §6).
4. Si el origen es un defecto de la app: **PB-06**.

**Efectos esperados de una revocación global (anticiparlos).**
- Todos los usuarios deben iniciar sesión de nuevo; la app **conserva el carrito local** (SUP-H H-07) pero borra tokens y datos con PII (SC-033).
- Habrá un **pico de logins** y de `invalid_credentials` por contraseñas olvidadas: **no** confundir con AL-26 ni disparar bloqueos masivos; el límite por IP (20/15 min) puede afectar a usuarios tras una misma IP de operador móvil (RNF-042, AA §10.4). Considerar un aumento temporal del límite por IP con aprobación de Seg.
- Los pagos en curso pueden fallar al volver a la app: **apagar `checkoutEnabled` unos minutos antes** (IC + Gerencia) y reactivar después.

**3. Erradicación.** Encontrar y cerrar la causa: URLs con token en logs (SC-003, SC-072), dispositivo comprometido (TM-006), copia de seguridad expuesta (TM-047), SDK de terceros que captura datos (TM-045), repositorio o CI con secretos (TM-042). Verificar con **canarios** ([logging.md](logging.md) §12). Si hubo accesos a datos personales → **PB-08**.

**4. Recuperación.** Verificar: (a) ninguna sesión con fecha de emisión anterior al corte sigue activa; (b) un token revocado devuelve `401`; (c) login normal funciona en web y app; (d) monitoreo reforzado de AL-26/AL-27 ≥ 72 h.

**5. Comunicación.** Usuarios (C-3): "por precaución cerramos tu sesión; vuelve a iniciar sesión; si usas la misma contraseña en otros sitios, cámbiala". Si se confirma acceso a datos de titulares, **PB-08** (Jur decide el contenido y la notificación). Tiendas: no aplica salvo hotfix.

**6. Cierre.** Criterios de §4 cumplidos; causa raíz eliminada y probada; post-mortem; ST-037, ST-038, ST-046 vigentes.

**No se sabe:** si hoy se pueden invalidar sesiones sin acceso a BD; existencia de 2FA en administradores; qué logs históricos contienen tokens (DES-13).

---

### PB-04 — Doble cobro o pagos sin confirmar

| | |
|---|---|
| **Disparadores** | AL-20, AL-21, AL-22, AL-23, AL-25; reclamo de un cliente; diferencia en la conciliación diaria |
| **Sev. inicial** | **SEV1** (doble cobro confirmado); **SEV2** (pagos sin confirmar o candidato a duplicado) |
| **Roles** | IC, WP, Fin, Soporte, Web; Gerencia (dinero, apagado del checkout); Jur (si hay reclamos formales) |
| **Origen** | RNF-024, RNF-025; TM-027, TM-030; SC-025, SC-027, SC-028; NL-02 |

**Contexto (HECHO/DESCONOCIDO).** El pago ocurre en WooCommerce con Wompi (HECHO). **Cómo confirma Wompi los pagos (webhook, firma, estados intermedios) y cómo se evita el doble cobro es DESCONOCIDO** (D-02, PA-11; "NO aceptable sin cerrar D-02/PA-11", `threat_model.md` §5.3). La app **no** marca pagos: pinta el resultado consultando al servidor (`GET /checkout/{checkoutRef}`; `paid` = `processing`/`completed`; `on-hold` se muestra pendiente, SUPUESTO PA-12).

**1. Diagnóstico (WP + Fin, con `checkoutRef` y número de pedido; sin datos de tarjeta).**

| Caso | Cómo se ve | Clasificación |
|---|---|---|
| **a. Doble cobro confirmado** | Dos transacciones **aprobadas** en Wompi para un mismo intento (mismo `checkoutRef`, mismo monto/usuario en minutos) | SEV1 |
| **b. Pago aprobado, pedido sin confirmar** | Transacción aprobada en Wompi; pedido `pending`/`on-hold`/`failed` en WooCommerce | SEV2 (webhook perdido, plugin, red) |
| **c. Dos pedidos para un intento, un solo cobro** | Pedido duplicado sin doble transacción | SEV2/SEV3 (limpieza de pedidos; revisar idempotencia) |
| **d. Pedido pagado, transacción no aprobada** | Posible confirmación no auténtica (TM-030) | **SEV1** + **PB-05/PB-08** según el vector |
| **e. Fallos masivos de pago** | AL-21 | SEV3/SEV2; descartar pasarela caída (estado de Wompi) y regresión de la app |

**2. Contención.**
1. **Caso aislado:** no apagar nada; resolver el caso (paso 3).
2. **Patrón sistémico** (≥ 2 casos con causa común, o confirmación no auténtica): **apagar `checkoutEnabled`** (IC + Gerencia) y el pago web si el origen es el plugin; informar a Wompi.
3. **No marcar manualmente un pedido como pagado** sin verificar la transacción aprobada en el **panel de Wompi** (Fin confirma por una segunda persona); registrar quién y cuándo.
4. Preservar evidencia: identificadores de pedido/transacción y `requestId`; **sin** datos de tarjeta.

**3. Remediación del cliente (Fin + Gerencia).** Anulación o reembolso del cobro duplicado **según lo que permita Wompi y el medio de pago** (DESCONOCIDO); ningún movimiento de dinero sin aprobación de Fin y Gerencia; Soporte informa al cliente con la plantilla (C-2/C-6) sin PII en canales abiertos. Si hay reclamos formales o plazos de reversión del pago aplicables (p. ej. Ley 1480 de 2011) → Jur (**NO VERIFICADO**: no se leyó en esta fase, `PRIV` §1.1).

**4. Erradicación.** Causas posibles: webhook de Wompi no llega o no se valida (D-02), doble toque o reintento sin `Idempotency-Key` (SC-027), ticket reutilizado (SC-021), regreso desde el navegador, estados no mapeados. Corregir y **probar 100 interrupciones por plataforma en *staging* con Wompi sandbox** (RNF-024, ST-086, ST-089) antes de reactivar.

**5. Recuperación.** Reactivar `checkoutEnabled`; vigilar AL-20/22/23 24 h; conciliar el día siguiente.

**6. Comunicación.** Interna (C-1); clientes afectados individualmente (Soporte); comunicado general solo si fue sistémico (Prod + Jur). Si el incidente expusiera datos personales → PB-08.

**7. Cierre.** Todos los casos conciliados y cerrados con el cliente; causa raíz probada; conteo de duplicados = 0 (SLO-08) por ≥ 7 días.

**No se sabe:** estados y firma de eventos de Wompi; posibilidad de anular vs. reembolsar por medio de pago; quién en Finanzas tiene acceso al panel de Wompi; existencia de *sandbox* que simule "pendiente" (R-Q02).

---

### PB-05 — Cuenta de administrador comprometida (por el traspaso o por credenciales) y compromiso de secretos del servidor

| | |
|---|---|
| **Disparadores** | AL-28, AL-18, AL-17, AL-39; alerta de Wordfence; cambios inesperados en WordPress (usuarios, plugins, configuración, WhatsApp); inicio de sesión de administrador desde origen desconocido; secreto expuesto |
| **Sev. inicial** | **SEV1** (acceso confirmado a `wp-admin`) / SEV2 (indicios) |
| **Roles** | IC, Seg, WP, TI, Web; Jur (datos personales → PB-08); Gerencia |
| **Origen** | TM-010, TM-042, TM-053, TM-060; SC-008, SC-011, SC-039; CR-010 y CR-028 de `resolucion_inconsistencias.md`; `COD` H-10 |

**Contexto (HECHO).** Hoy el login por `ipr/v1` **no filtra el rol** y el **traspaso (*handoff*) inicia sesión en WordPress con cookie persistente para cualquier usuario válido, administradores incluidos** (`wp-snippets/ipr-auth-rest.php`; `ipr-cart-handoff.php`; TM-010; CR-010 "cambio obligatorio P0"). Así, un token o credencial robado de una cuenta con rol privilegiado puede convertirse en una sesión de WordPress con esos privilegios. La corrección propuesta (SUP-H H-09, **no aprobada**): solo `customer` y `subscriber` sin capacidades administrativas pueden iniciar sesión (SC-011), cookie no persistente (SC-022). Hasta que se aplique, **este playbook es plausible hoy en la web**.

**1. Diagnóstico (Seg + WP).** ¿Qué cuenta? ¿desde cuándo? ¿qué cambió (usuarios/administradores nuevos, plugins/temas nuevos, archivos modificados, claves de WooCommerce, *webhooks*, configuración remota, número de WhatsApp, correo de envío)? ¿se accedió a datos de clientes/pedidos (→ **PB-08**)? ¿Hay evidencia de uso del *handoff*? Conocer cuántos administradores existen y si tienen 2FA (**DESCONOCIDO**, DES-12).

**2. Contención (en este orden, WP + TI).**
1. Cambiar contraseñas de las cuentas comprometidas y de **todos** los administradores; cerrar todas sus sesiones de WordPress; revocar sus sesiones de la app (PB-03 alcance A).
2. **Rotar** los secretos que esa cuenta o el servidor pudieron exponer: claves de WooCommerce, `HANDOFF_SECRET`/`IPR_HANDOFF_SECRET`, `IPR_BFF_SECRET`, `REVALIDATE_SECRET`, SMTP y claves/sales de WordPress ([maintenance.md](maintenance.md) §6).
3. Si hay indicios de persistencia: desactivar plugins/temas no reconocidos; **apagar el *handoff*** (afecta también el pago web: Gerencia) y `checkoutEnabled`.
4. Revisar y restaurar la **configuración remota** (número de WhatsApp, `allowedHosts`, versiones mínimas): su manipulación redirige a clientes o abre el checkout a dominios maliciosos (TM-024, TM-040).
5. Bloquear en Cloudflare IP origen del acceso malicioso; exigir acceso a `wp-admin` solo desde rutas protegidas si es posible.

**3. Erradicación.** Eliminar puertas traseras; comparar archivos y base de datos contra una copia limpia conocida; **si se restaura una copia**, aplicar el procedimiento de [maintenance.md](maintenance.md) §8 (no resucitar sesiones ni datos suprimidos). Aplicar los cambios P0 pendientes (CH-05: filtro de roles, cookie no persistente), 2FA obligatorio en administradores y reducción de cuentas privilegiadas. Evaluar análisis forense externo (decisión de Gerencia, D-15).

**4. Recuperación.** Reactivar *handoff* y `checkoutEnabled` tras verificar firmas y que `login_denied_role` funciona en staging (ST-044, ST-045); monitoreo reforzado ≥ 7 días.

**5. Comunicación.** Interna (C-1). Si se accedió a datos personales o a pedidos: **PB-08** (Jur). Clientes: solo con aprobación de Jur y Gerencia (C-4).

**6. Cierre.** Todas las credenciales y secretos rotados y verificados; sin cuentas o plugins desconocidos; causa raíz cerrada; CH-05 desplegado o con riesgo aceptado por escrito.

**No se sabe:** número de administradores, 2FA, versión y reglas de Wordfence (MED-10), quién puede restaurar copias y con qué antigüedad (DES-10).

---

### PB-06 — *Release* defectuoso (halt del despliegue escalonado y versión mínima forzada)

| | |
|---|---|
| **Disparadores** | AL-13, AL-33, AL-34, AL-35, AL-36; reseñas/soporte; defecto crítico encontrado en una versión ya publicada; hallazgo de seguridad en la app |
| **Sev. inicial** | SEV2; SEV1 si el defecto causa pérdida de dinero/datos, bloquea el pago a todos, o es una fuga de seguridad |
| **Roles** | IC, Móvil, Web (si la causa es el BFF), Prod, Soporte; Seg y Jur (si es de seguridad o datos personales) |
| **Origen** | RNF-029, RNF-030, RNF-098; TM-061; SC-052, SC-066; `../09_devops/ci_cd.md` (otro agente) |

**Premisa de diseño (PROPUESTA; D-14 y proceso de publicación no definidos).** Cada versión de la app se publica **por etapas** (Google Play: lanzamiento escalonado por porcentaje; App Store: lanzamiento por fases de actualizaciones automáticas — **verificar el esquema y límites vigentes** en la documentación de cada tienda). Fases iniciales propuestas: 1 % → 5 % → 20 % → 50 % → 100 %, con ≥ 24–48 h entre fases y **criterios de avance**: crash-free ≥ 99,5 %, ANR ≤ 0,3 %, 0 SEV1/SEV2 abiertos, tasa de errores del BFF por versión dentro de SLO-03 (valores = RNF-098, propuestos).

**1. Diagnóstico (primeros 30 min).** Confirmar con **dos señales** (reporte de fallos + consola de tienda o tasa de errores por `appVersion`); acotar por versión y plataforma, por dispositivo/SO, y si la causa es **la app** (nueva firma de fallo, regresión) o **el BFF/WordPress** (cambio de contrato, `426` mal calibrado, respuesta de error mal manejada). Ver el **porcentaje del despliegue** y cuántos usuarios ya tienen la versión.

**2. Contención (árbol de decisión).**

| Situación | Acción |
|---|---|
| Defecto en la **app**, el despliegue está en curso | **Detener/pausar el despliegue escalonado** en la(s) tienda(s) (Móvil, aprobado por el IC). Los que ya actualizaron conservan la versión. |
| Una **función** concreta falla y tiene interruptor | Apagarla con `GET /config` (`features.*`; efecto ≤ 5 min). |
| Defecto en el **BFF** (despliegue reciente) | **Reversa del BFF** a la versión anterior (RNF-030; ≤ 15 min como objetivo); verificar contrato. |
| Defecto **grave** (pérdida de dinero/datos, fuga) en versiones ya instaladas | 1) **Publicar la corrección con número de versión mayor** (en las tiendas no hay retroceso; en iOS solicitar revisión acelerada con justificación — verificar proceso); 2) mientras llega, interruptor remoto de la función; 3) **solo cuando la corrección esté disponible en tienda**, subir `minSupportedVersion` por encima de la versión defectuosa (`426`); antes, usar `recommendedVersion` (aviso suave). |
| La versión mínima ya se subió y hay usuarios bloqueados sin salida | Revertir `minSupportedVersion` inmediatamente (efecto ≤ 5 min) y revisar el enlace de actualización (`GET /update-required`). |

**Regla de oro:** **no subir la versión mínima si no hay una versión corregida accesible** (bloquea a todos los usuarios de la versión defectuosa sin remedio).

**3. Erradicación.** Corregir, añadir la prueba de regresión que habría detectado el defecto (pruebas de contrato, E2E, golden), pasar los *gates* de CI (ver `ci_cd.md`) y una nueva ronda de piloto/escalonado empezando de nuevo por el porcentaje inicial.

**4. Recuperación.** La versión corregida llega al X % de los usuarios activos; crash-free y ANR dentro de SLO-11/SLO-12; AL-35/AL-36 en verde; se retiran los interruptores y, si procede, se sube la versión mínima de forma ordenada.

**5. Comunicación.** Notas de versión y mensaje en la app (Prod); tienda (si procede, respuesta a reseñas); Soporte con respuestas aprobadas. Si el defecto es de seguridad o datos personales → **PB-08**.

**6. Cierre.** Versión corregida adoptada por el umbral definido (DOP-10); defectos de proceso (por qué no se detectó antes) en el post-mortem; ajuste de criterios de avance.

**No se sabe:** proveedor de CI y de entrega a tiendas (DEP §12d "DESCONOCIDO"); titularidad de las cuentas (D-14); tiempos de revisión de las tiendas.

---

### PB-07 — Vulnerabilidad crítica en una dependencia

| | |
|---|---|
| **Disparadores** | Salida de `npm audit`/OSV-Scanner (CI o programada); aviso de proveedor o ecosistema (npm, pub.dev, WordPress/plugins, Next.js, Node, Flutter); notificación de un investigador; explotación pública |
| **Sev. inicial** | **SEV1** si hay explotación activa conocida contra componentes expuestos; SEV2 crítica sin explotación; SEV3 alta |
| **Roles** | IC, Seg, Web, WP, Móvil, TI; Gerencia (excepciones) |
| **Origen** | RNF-048, RNF-049; SC-048, SC-050, SC-051; TM-050; `COD` H-09/SEC-05; MED-09 |

**Estado de partida (HECHO/NO VERIFICADO).** La auditoría interna de oct-2026 reportó **17 CVE (2 críticas)** en el frontend; `package.json` fija `next 16.3.4` y `nodemailer ^10.0.3`; **`npm audit` no se ha ejecutado** en esta fase; el CI actual **no** audita (SEC-05/SEC-10; MED-09). **Acción previa a cualquier incidente: ejecutar esa auditoría** y registrar el resultado ([maintenance.md](maintenance.md) §3).

**1. Triage (≤ 4 h hábiles para críticas, propuesta).** ¿El componente está en producción (servidor, app, WordPress) o solo en desarrollo? ¿Es **alcanzable** desde un atacante (ruta, versión, configuración)? ¿Hay explotación pública? ¿Hay parche o mitigación? Registrar la decisión (afecta / no afecta / mitiga) con evidencia.

**2. Contención / mitigación inmediata.** Regla de WAF en Cloudflare, desactivar plugin o ruta vulnerable, apagar la función (interruptor), restringir acceso (`wp-admin`), reducir la superficie; si hay indicios de explotación → **PB-05/PB-08** y rotar secretos del servidor que el componente pudo exponer.

**3. Erradicación.** Actualizar o reemplazar; regenerar `package-lock.json`/`pubspec.lock`; pasar los *gates* de CI (tipos, lint, SCA, escaneo de secretos, contrato); desplegar el BFF (reversa disponible); para la app, nuevo *release* por etapas (**PB-06**); para plugins de WordPress, probar en *staging* antes de producción.

**4. Plazos objetivo (RNF-048, propuestos; ajustar con IPR).** Críticas **≤ 7 días** y altas **≤ 30 días** tras el aviso; si no hay parche en plazo, **excepción por escrito** (Gerencia + Seg) con compensatorios y fecha de revisión. Con explotación activa: mitigación en horas y parche lo antes posible (objetivo propuesto ≤ 72 h).

**5. Recuperación y cierre.** Escaneo posterior en verde (0 críticas/altas abiertas, RNF-048); SBOM actualizado (SC-051); lección registrada (¿por qué el escáner no lo detectó antes?).

**6. Comunicación.** Interna; usuarios solo si la corrección exige actualizar la app (PB-06) o hubo exposición de datos (PB-08).

**No se sabe:** versiones reales de plugins de WordPress y de Node; si el servidor corre en contenedor; resultado de la auditoría actual.

---

### PB-08 — Incidente con datos personales

| | |
|---|---|
| **Disparadores** | AL-37; cualquier PB con acceso o fuga de datos de titulares; reporte externo; hallazgo de PII en logs/capturas/reportes de fallos; pérdida de un dispositivo/copia con datos; error de un proveedor |
| **Sev. inicial** | **Mínimo SEV2**; SEV1 si se confirma acceso no autorizado a datos de titulares |
| **Roles** | IC, **Jur (decide)**, Seg, WP, Web, Gerencia, responsable/área de protección de datos de IPR (designación DESCONOCIDA), Comunicaciones |
| **Origen** | R-P11, J-26 de `PRIV`; RNF-047, RNF-058..064; SC-045, SC-057, SC-066; Ley 1581; Circular Única SIC Título V |

**1. Triage de privacidad (≤ 2 h tras sospecha, propuesta).** (1) **Avisar a Jur y a Gerencia**. (2) **Anotar con exactitud la hora de detección y la hora en que la persona o área encargada de atender el incidente lo conoce**: de ahí corre el plazo de §9. (3) Determinar: qué datos (correo, teléfono, dirección, cédula/NIT, pedidos, tokens), cuántos titulares, de qué bases, desde cuándo, si estaban cifrados/seudonimizados, quién accedió, si hay riesgo para los titulares. (4) Congelar la evidencia mínima necesaria (R-04).

**2. Contención.** Según el vector: PB-03 (tokens), PB-05 (cuenta administrativa/secretos), PB-07 (dependencia), PB-06 (defecto de la app), cierre de la fuente de la fuga (borrar logs con PII **solo después de** preservar lo necesario y con aprobación de Jur), bloquear cuentas afectadas, retirar acceso a un proveedor.

**3. Evaluación legal (Jur).** Aplicar §9: obligación de informar a la SIC, plazos, canal, contenido; evaluación de aviso a titulares; contratos con proveedores (encargados) y sus deberes de notificación (DESCONOCIDOS); otras autoridades (p. ej. denuncia penal por delitos informáticos — **NO VERIFICADO**, A VALIDAR por Jur).

**4. Notificaciones.** SIC (C-5) y titulares (C-4), solo con aprobación de Jur y Gerencia; Soporte con respuestas aprobadas; registro de cada comunicación (fecha, canal, contenido, aprobador).

**5. Erradicación.** Eliminar la causa; revisar minimización y retención ([logging.md](logging.md) §7); si hubo exposición por un SDK/proveedor, revisar contrato y fichas de tienda (RNF-061).

**6. Recuperación.** Controles reforzados; verificación con canarios; monitoreo ≥ 30 días.

**7. Cierre y responsabilidad demostrada.** Expediente del incidente (línea de tiempo, decisiones, evidencias, comunicaciones, notificaciones) conservado según defina Jur; post-mortem restringido; actualización de la evaluación de impacto y del inventario de datos (PRIV, J-35).

**No se sabe:** si IPR está obligada a inscribir bases en el RNBD (activos > 100.000 UVT: DESCONOCIDO); si existe protocolo, responsable o área de protección de datos; contratos con proveedores; versión vigente de la Circular a la fecha del incidente.

---

### PB-09 — Ataque de fuerza bruta / *credential stuffing*

| | |
|---|---|
| **Disparadores** | AL-26, AL-30, AL-39, AL-40, AL-24; muchos 429 en `/auth/*`; reportes de cuentas bloqueadas |
| **Sev. inicial** | SEV2 (activo); SEV1 si hay cuentas tomadas con acceso a datos personales o pagos |
| **Roles** | IC, Seg, WP, TI, Web; Soporte (usuarios bloqueados); Jur si hay acceso a datos |
| **Origen** | TM-001, TM-002, TM-003, TM-056, TM-057; SC-004..SC-007, SC-010, SC-046; RNF-042 |

**1. Diagnóstico.** Confirmar patrón (IP, ASN, país, agentes, tasa, cuentas objetivo, proporción de éxito). Distinguir falsos positivos: operador móvil con NAT, prueba de carga o sintético, campaña, **un defecto de la app que reintenta login en bucle**, revocación global reciente (PB-03). **Ojo:** el atacante puede ir **directo a WordPress** (`/wp-json/ipr/v1/auth/login`, `wp-login.php`, `xmlrpc.php`) y saltarse el BFF y los límites en memoria (TM-002); revisar el registro de acceso de WordPress y Wordfence (DESCONOCIDOS).

**2. Contención.**
1. **Cloudflare:** reglas de límite y bloqueo por IP/ASN/país en `/mobile/v1/auth/*` (60/min propuesto), `/wp-json/ipr/v1/auth/*`, `wp-login.php`, `xmlrpc.php`, `/api/auth/*`; **sin desafíos interactivos en `/mobile/v1/*`** (la app no los resuelve). Bloquear `xmlrpc.php` si no se usa (verificar).
2. **WordPress:** verificar que los límites persistentes (`ipr_auth_throttle`) estén activos; ajustar escalones del bloqueo (SC-004). Hoy: **no existe** límite en `auth/*` (H-04) y Wordfence es DESCONOCIDO.
3. **Origen:** verificar que 80/443 solo aceptan Cloudflare (SC-010).
4. **Cuentas:** identificar cuentas con **login exitoso desde las IP del ataque** → revocar sus sesiones (PB-03 A), forzar restablecimiento de contraseña, avisar al titular (C-3); revisar si cambiaron correo/contraseña o hicieron pedidos (AL-29).
5. **Cuidado con el bloqueo por cuenta**: se puede abusar para dejar fuera a titulares legítimos (TM-057); mantener el bloqueo progresivo con techo y un canal de recuperación.

**3. Erradicación.** Calibrar umbrales (MED-10); activar verificación de correo (DN-12/SC-068) y, en fase 2, atestación (SC-064); revisar contraseñas filtradas conocidas (política de contraseñas, RNF-053).

**4. Recuperación.** Retirar bloqueos temporales de IP legítimas; verificar que `login_failed` volvió a la línea base ≥ 24 h; verificar que usuarios legítimos pueden entrar.

**5. Comunicación.** Titulares con cuenta tomada (C-3); si hubo acceso a datos personales → **PB-08**.

**6. Cierre.** AL-26 en verde ≥ 72 h; ninguna cuenta tomada abierta; reglas permanentes registradas.

**No se sabe:** reglas y plan de Cloudflare (DES-04); configuración de Wordfence; si `xmlrpc.php` está en uso; roles de WordPress.

---

### PB-10 — Abuso de PQRS

| | |
|---|---|
| **Disparadores** | AL-31; cola SMTP anormal; aviso de listas negras; Soporte satura |
| **Sev. inicial** | SEV3; SEV2 si el buzón o el dominio de correo de IPR quedan bloqueados |
| **Roles** | IC (si SEV2), Web, TI, Soporte; Jur (si hay solicitudes de titulares), Prod |
| **Origen** | TM-036, TM-037, TM-038, TM-039; SC-056; RNF-044; RF-096/097 |

**1. Diagnóstico.** ¿Spam automatizado, campaña legítima, un solo remitente, correos con contenido inyectado (TM-037) o suplantación de identidad (TM-038)? Revisar volumen por IP/dispositivo, tasa de rechazo de Cloudflare/BFF, cola y reputación del correo saliente. **No abrir enlaces ni adjuntos** de mensajes sospechosos.

**2. Contención.**
1. Reglas por IP en Cloudflare (5/10 min propuesto) y endurecer el límite del BFF (el de memoria solo no basta; SC-056).
2. Si inunda el buzón: **apagar `pqrsEnabled`** (interruptor remoto) y dirigir a los canales alternos de contacto de `GET /config` (WhatsApp/teléfono/correo).
3. **No borrar masivamente**: una PQRS puede ser una **consulta o reclamo de un titular** (plazos de 10 y 15 días hábiles, Ley 1581, verificados en `PRIV`); filtrar y conservar lo legítimo; Jur define el tratamiento.
4. Verificar la marca de "identidad no verificada": **los asesores no actúan sobre pedidos o datos de terceros con base solo en una PQRS** (TM-038).

**3. Erradicación.** Límite compartido y persistente (Cloudflare o WordPress; SC-056, CH-18); `Idempotency-Key`; revisión del escape de cabeceras/HTML; reputación del dominio (SPF/DKIM/DMARC: **DESCONOCIDO**).

**4. Recuperación.** Reactivar `pqrsEnabled`; vigilar AL-31 ≥ 72 h; atender el rezago legítimo.

**5. Comunicación.** Interna; si la función estuvo apagada, aviso en la app (C-2) con canales alternos.

**6. Cierre.** Cola SMTP normal; correo de IPR no en listas negras; solicitudes legítimas atendidas dentro de plazo.

---

## 7. Resumen de playbooks y alertas

| Playbook | Alertas que lo disparan | Sev. inicial | Palancas clave |
|---|---|---|---|
| PB-01 Caída de WooCommerce/BFF | AL-01..04, 07, 08, 11, 14..16, 38 | SEV2 / SEV1 | Caché stale; `checkoutEnabled`; **no reiniciar** con WooCommerce caído; rollback |
| PB-02 Degradación por carga móvil | AL-05, 06, 09, 10, 12, 25, 32, 40 | SEV3 / SEV2 | Cache Rule; límites; bloqueo; PB-06; decisión de proteger la web |
| PB-03 Fuga/robo de tokens | AL-27, 29 | SEV2 / SEV1 | Revocación (alcances A/B/C); rotación; `checkoutEnabled` |
| PB-04 Doble cobro / pagos sin confirmar | AL-20..23, 25 | SEV1 / SEV2 | `checkoutEnabled`; conciliación con Wompi; Fin |
| PB-05 Admin comprometido / secretos | AL-17, 18, 28, 39 | SEV1 / SEV2 | Rotación; apagar *handoff*; restaurar config |
| PB-06 *Release* defectuoso | AL-13, 33..36 | SEV2 / SEV1 | Halt de despliegue; interruptor; rollback BFF; versión mínima (con precaución) |
| PB-07 Vulnerabilidad crítica | CI/OSV/aviso | SEV1..SEV3 | WAF virtual; parche; plazos 7/30 d |
| PB-08 Datos personales | AL-37 y otros | ≥ SEV2 | Jur; SIC 15 días hábiles; titulares (A VALIDAR) |
| PB-09 Fuerza bruta | AL-24, 26, 30, 39, 40 | SEV2 / SEV1 | Cloudflare; límites WP; revocar cuentas tomadas |
| PB-10 Abuso de PQRS | AL-31 | SEV3 / SEV2 | `pqrsEnabled`; límites; conservar solicitudes legítimas |

**Total: 10 playbooks.**

---

## 8. Plantillas

> Los textos entre `[corchetes]` se completan en el momento. **Ninguna plantilla incluye datos personales ni secretos.** Los textos para titulares y autoridades son **borradores A VALIDAR por el Jurídico**.

### 8.1 Registro de incidente (línea de tiempo)

| Campo | Contenido |
|---|---|
| ID del incidente | `INC-AAAA-MM-DD-NN` |
| Severidad actual (y cambios) | SEVn (hora UTC de cada cambio) |
| IC / Escriba / roles asignados | por rol |
| Detección | Hora UTC, fuente (AL-xx, Soporte, tienda, proveedor) |
| Conocimiento de la persona/área encargada (si hay datos personales) | Hora UTC |
| Línea de tiempo | `[hora UTC] [rol] [acción/decisión] [evidencia: requestId/enlace al panel]` |
| Impacto | Funciones, % de usuarios/solicitudes, dinero, datos (tipo y cantidad, sin PII) |
| Palancas usadas | Interruptores, reglas, rollback, rotaciones |
| Comunicaciones enviadas | Fecha, público, canal, aprobador |
| Estado | Abierto / Contenido / Recuperado / Cerrado |

### 8.2 C-1 — Comunicado interno inicial

> **Asunto:** `[SEVn] Incidente INC-… — [resumen de una línea]`
> **Qué ocurre:** [síntomas observados, sin datos personales].
> **Desde cuándo:** [hora UTC / hora de Colombia].
> **Impacto conocido:** [funciones afectadas, estimación].
> **Qué estamos haciendo:** [acción en curso]. **IC:** [rol]. **Canal único:** [canal].
> **Qué se pide al equipo:** [acciones concretas]; no compartir datos de clientes en este canal; no hablar con prensa o clientes sin pasar por Comunicaciones.
> **Próxima actualización:** [hora].

### 8.3 C-2 — Aviso a usuarios por degradación o mantenimiento (app, web, redes)

> "Estamos presentando [una intermitencia en el catálogo / una dificultad para completar compras]. Tu cuenta y tus datos no se han visto afectados. Estamos trabajando para solucionarlo. Mientras tanto, puedes contactarnos por [WhatsApp / teléfono] para [cotizar / hacer tu pedido con un asesor]. Te avisaremos cuando todo vuelva a la normalidad."

(Usar solo si es verdad que no hay datos afectados; si hay duda, **no** incluir esa frase.)

### 8.4 C-3 — Aviso de seguridad a usuarios (cierre de sesión por precaución)

> "Por seguridad cerramos la sesión de tu cuenta de IPR [en todos tus dispositivos]. Para continuar, inicia sesión de nuevo. Si usas la misma contraseña en otros sitios, te recomendamos cambiarla. Si notas algo extraño en tu cuenta o tus pedidos, escríbenos a [canal de soporte]. No te pediremos tu contraseña por mensaje, correo ni llamada."

### 8.5 C-4 — Comunicación a titulares por incidente con datos personales (**BORRADOR A VALIDAR (Jur)**)

> **Asunto:** Aviso importante sobre tus datos en IPR
> Te escribimos porque, el [fecha], detectamos [descripción breve y clara del incidente]. **Datos involucrados:** [tipos de datos: p. ej. correo, teléfono; indicar si NO se vieron contraseñas ni datos de pago, solo si es cierto y verificado]. **Qué hicimos:** [contención y medidas]. **Qué te recomendamos:** [acciones concretas: cambiar contraseña, estar atento a mensajes sospechosos]. **Cómo contactarnos:** [canal y responsable de datos personales de IPR]. Puedes ejercer tus derechos de conocer, actualizar, rectificar y suprimir tus datos por [canal]. Lamentamos lo ocurrido.
>
> *Nota interna:* si la ley o el criterio de Jurídico exigen contenido adicional (identificación del responsable, finalidad, derechos), se añade antes de enviar. La obligación y el plazo de informar **a los titulares** están **NO VERIFICADOS** (§9).

### 8.6 C-5 — Notificación a la SIC (campos a preparar; el formato real lo define el aplicativo o canal de la SIC — **NO VERIFICADO**)

| Campo | Contenido |
|---|---|
| Responsable del Tratamiento | Inverprimos S.A.S.: identificación, domicilio, contacto (completa Jur) |
| Persona/área que atiende el incidente | Rol designado (A VALIDAR) |
| Fecha y hora de detección y de conocimiento por el área encargada | UTC y hora de Colombia |
| Descripción del incidente | Tipo (violación de códigos de seguridad, pérdida, robo y/o acceso no autorizado), vector, sistemas |
| Bases de datos y categorías de datos afectadas | Clientes, pedidos, sesiones, PQRS…; si hay datos sensibles |
| N.º aproximado de titulares afectados | Cifra o rango |
| Medidas adoptadas y planificadas | Contención, erradicación, mitigación para los titulares |
| ¿Se informó a los titulares? | Sí/No, cuándo y cómo |
| Encargados/proveedores involucrados | Hosting, Wompi, SMTP, reporte de fallos, Cloudflare |
| Contacto | Rol y medio |

### 8.7 C-6 — Comunicado de resolución

> "El incidente que afectó [función] fue resuelto el [fecha, hora]. [Qué ocurrió en una frase.] [Qué cambiamos.] Gracias por tu paciencia. Si aún notas algún problema, escríbenos a [canal]."

### 8.8 Plantilla de post-mortem (sin culpables)

| Sección | Contenido |
|---|---|
| **Resumen** | Una frase de qué ocurrió, severidad máxima, duración, impacto (sin PII). |
| **Línea de tiempo** | Hora UTC y hechos: detección, declaración, decisiones clave, contención, recuperación (del §8.1). |
| **Impacto** | Usuarios/solicitudes, funciones, dinero, datos; SLO consumido (presupuesto de error). |
| **Detección** | ¿Qué alerta saltó? ¿Cuánto tardó? ¿Quién avisó? ¿Qué señal habría detectado antes? |
| **Causa raíz y factores contribuyentes** | Hechos técnicos y de proceso; "¿qué lo permitió?"; **sin nombres ni juicios sobre personas**. |
| **Qué salió bien** | Palancas, alertas, coordinación. |
| **Qué salió mal / qué faltó** | Documentación, acceso, monitoreo, ensayos, suposiciones erróneas. |
| **Suerte** | Dónde pudo ser peor. |
| **Acciones** | Tabla: acción verificable · rol dueño · fecha · prioridad · criterio de cierre · enlace al seguimiento ([maintenance.md](maintenance.md) §10). |
| **Legal y datos personales** | ¿Hubo datos personales? ¿Notificaciones realizadas y fechas? (versión restringida). |
| **Decisiones pendientes** | Para Gerencia/Jurídico. |
| **Aprobación** | IC, Seg (si aplica), Gerencia. Fecha. |

---

## 9. Obligaciones ante la SIC y los titulares (estado de verificación)

> **A VALIDAR por el Jurídico de IPR.** Verificación realizada el 2026-11-18 por este documento y por `PRIV`. Las fuentes oficiales de la SIC se abrieron cuando fue posible; las no abiertas se marcan **NO VERIFICADO**.

| # | Punto | Estado | Fuente |
|---|---|---|---|
| L-1 | **Deber de informar a la autoridad de protección de datos (SIC)** cuando haya violaciones a los códigos de seguridad y existan riesgos en la administración de la información de los titulares: lo exige la Ley 1581 de 2012 a **responsables (art. 17, lit. n)** y a **encargados (art. 18, lit. k)**. | **VERIFICADO** contra la copia del Repositorio Normativo del Archivo General de la Nación (generada 08-11-2022) en `PRIV` §1.1. **NO VERIFICADO** que no existan modificaciones posteriores a esa fecha. | `PRIV` §1.1, §4 (R-P11); Ley 1581 de 2012 |
| L-2 | **Qué es un "incidente de seguridad"** para la SIC: "la violación de los códigos de seguridad o la pérdida, robo y/o acceso no autorizado de información de una base de datos administrada por el Responsable del Tratamiento o por su Encargado". | **VERIFICADO** en el texto de la Circular Única, Título V, versión del 29-09-2022, Capítulo Segundo, numeral 2.1, literal f), (ii), publicado en la sede electrónica de la SIC. | [Título V, versión 29-09-2022 (sede electrónica SIC)](https://sedeelectronica.sic.gov.co/sites/default/files/normatividad/092022/T%C3%ADtulo%20V%20Versi%C3%B3n%2029-09-2022.pdf) |
| L-3 | **Plazo y canal del reporte a la SIC:** dentro de los **quince (15) días hábiles siguientes al momento en que se detecten y sean puestos en conocimiento de la persona o área encargada de atenderlos**. Los responsables **obligados** a inscribir sus bases en el RNBD lo reportan **en el RNBD**; los **no obligados** y los **encargados**, mediante el **aplicativo** dispuesto en el micrositio de la Delegatura para la Protección de Datos Personales de la SIC o por **cualquiera de los canales habilitados** por la entidad, en el mismo plazo. | **VERIFICADO** en el mismo texto (versión 29-09-2022). **NO VERIFICADO** que la versión vigente a nov-2026 conserve este plazo y canal: la SIC publicó el 27-may-2026 un **proyecto de resolución** que modifica el Título V (centrado en hábeas data financiero y otras materias; el resumen consultado **no** menciona cambios al plazo de incidentes) y **no** se pudo comprobar si fue adoptado ni su texto. | Mismo PDF; [resumen del proyecto (CER Latam)](https://www.cerlatam.com/normatividad/sic-proyecto-de-resolucion-27-may-2026/); `PRIV` §1.1 (guías SIC NO VERIFICADO) |
| L-4 | **¿Está IPR obligada a inscribir bases en el RNBD?** Depende de que sus **activos totales superen 100.000 UVT** (Decreto 1074 de 2015, art. 2.2.2.26.1.2; Circular Única, numeral 2.1). Plazo para bases nuevas: dos meses desde su creación (art. 2.2.2.26.3.1). | **VERIFICADO** el criterio (`PRIV` §1.1, §5). **DESCONOCIDO** el monto de activos de Inverprimos y si hay bases inscritas (J-03). Determina el canal de L-3. | `PRIV` §1.1, §5 |
| L-5 | **Notificación a los titulares afectados:** en las fuentes revisadas (art. 17 y 18 de la Ley 1581 y el numeral 2.1 f(ii) de la Circular) **no se encontró** una obligación expresa y con plazo de comunicar el incidente a cada titular. | **NO VERIFICADO / A VALIDAR por Jurídico** (no se buscó específicamente en el Decreto 1074 de 2015 —`PRIV` lo revisó para otros temas— ni se abrieron guías de la SIC sobre incidentes). **Recomendación de buena práctica (no se afirma como obligación):** informar sin demora a los titulares afectados cuando haya riesgo, con lenguaje claro (plantilla C-4). | `PRIV` §1.1 ("Guías de la SIC: NO VERIFICADO") |
| L-6 | **Responsabilidad demostrada** (documentar políticas, medidas y evidencia): principio de los arts. 2.2.2.25.6.1–6.2 del Decreto 1074 y de la CE 002 de 2025. | **VERIFICADO** el principio (`PRIV` §1.1). El expediente del incidente (§6 PB-08) es la evidencia. | `PRIV` §1.1 |
| L-7 | **Derechos de los titulares y plazos de atención:** consultas 10 días hábiles y reclamos 15 días hábiles (Ley 1581, arts. 14 y 15). Relevante para PQRS (PB-10) y para solicitudes posteriores a un incidente. | **VERIFICADO** (`PRIV` §1.1, RNF-059). | Ley 1581 |
| L-8 | **Reglas sobre transferencia/transmisión y proveedores tecnológicos** (CE 002 de 2025: cláusulas de responsabilidad, seguridad, auditoría) y **deberes de notificación en contratos** con hosting, Wompi, Cloudflare, SMTP, proveedor de fallos. | CE 002/2025 **VERIFICADA** (`PRIV`); **contenido de los contratos DESCONOCIDO**. | `PRIV` §1.1; J-27 |
| L-9 | **Otras normas** que podrían aplicar (reversión del pago en compras no presenciales: Ley 1480 de 2011; delitos informáticos: Ley 1273 de 2009; denuncia ante autoridades; notificación a otras superintendencias). | **NO VERIFICADO**; solo se listan para que Jurídico decida. | `PRIV` §1.1 |
| L-10 | **Proyectos de reforma de la Ley 1581** (P.L. 214 y 274 de 2025 Cámara, acumulados; P.L.E. 282 de 2026 Cámara) que podrían cambiar obligaciones. | **NO VERIFICADO** su estado actual. | `PRIV` §1.1 |

**Resumen:** la obligación de **avisar a la SIC** y su **plazo de 15 días hábiles** están **verificados en el texto de la Circular Única (versión de 29-09-2022)** y la base legal en la Ley 1581 (verificada en copia de 2022); **no** está verificado que sigan vigentes sin cambios a nov-2026, **ni** el canal exacto aplicable a IPR (depende de L-4), **ni** la obligación y plazo de avisar a los titulares.

**Acciones para el Jurídico (DOP-11).** Confirmar el texto vigente del Título V en la sede de la SIC; resolver L-4 y L-5; designar al responsable/área de protección de datos; revisar contratos con proveedores; aprobar las plantillas C-4/C-5; fijar la retención del expediente de incidentes y de los registros de auditoría.

---

## 10. Ensayos y mantenimiento de este manual

| Actividad | Frecuencia | Rol | Evidencia | Origen |
|---|---|---|---|---|
| Ensayo (simulacro de mesa) de PB-03, PB-04, PB-06 y PB-08 | Semestral y antes del piloto | IC + Seg + Jur | Acta con tiempos y brechas | CH-29; ST-156 |
| Ensayo técnico en *staging*: revocación masiva, rotación de un secreto, interruptor de checkout, versión mínima y reversa del BFF | Antes del piloto y anual | Web, WP, TI | Registro de tiempos (SLO-13, SLO-16) | ST-156, ST-128; RNF-029, RNF-030 |
| Revisión de roles, suplentes y directorio de contactos | Trimestral | TI + Gerencia | Lista actualizada | §3 |
| Revisión de plantillas y de §9 (cambios normativos) | Semestral y ante cambio normativo | Jur | Acta | R-P18 de `PRIV` |
| Post-mortem de cada SEV1/SEV2 con acciones en el seguimiento | Por incidente | IC | Documento + acciones | §4; [maintenance.md](maintenance.md) §10 |

---

## 11. Hechos, supuestos, riesgos y decisiones pendientes

### 11.1 Supuestos

| ID | Supuesto | Si es falso |
|---|---|---|
| SIR-01 | SUP-H H-04 (vidas de token), H-05 (solo "cerrar todas"), H-07 (carrito se conserva al cerrar sesión), H-09 (filtro de roles) se aprueban como se recomiendan. | Ajustar PB-03, PB-05. |
| SIR-02 | Existirán los interruptores remotos y la versión mínima (SC-052, RNF-029) antes del piloto. | Los playbooks no tienen palanca rápida: contención por reglas de Cloudflare y publicación de versiones. |
| SIR-03 | Se podrá pausar el despliegue escalonado en las tiendas (cuentas a nombre de Inverprimos, D-14). | PB-06 se reduce a hotfix y versión mínima. |
| SIR-04 | Hay acceso de emergencia a la BD de WordPress para la revocación global hasta que exista la herramienta (SC-066). | La revocación global exige reglas de cambio de sales de WordPress (cierra a todos, incluidos administradores). |
| SIR-05 | El Jurídico confirma que el plazo de 15 días hábiles del Título V sigue vigente. | Ajustar PB-08 y C-5. |

### 11.2 Riesgos

| ID | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| ROP-I1 | Incidente sin roles asignados ni guardia (DN-06, DOP-07) | Alta | Alto | Asignar antes del piloto; ensayar. |
| ROP-I2 | Reiniciar el proceso con WooCommerce caído borra caché e índice y agrava la caída (PB-01) | Media | Alto | Regla explícita en PB-01; mejorar con FE-06/RNF-023. |
| ROP-I3 | Subir la versión mínima sin versión corregida bloquea a los usuarios (PB-06) | Media | Alto | Regla de oro de PB-06; aviso suave primero. |
| ROP-I4 | Revocación global sin herramienta, ejecutada a mano sobre la BD | Media | Alto | SC-066 antes del piloto; procedimiento ensayado; registro de quién ejecuta. |
| ROP-I5 | Plazo de 15 días hábiles dejado correr por no registrar la hora en que el área encargada supo del incidente (PB-08) | Media | Alto | Campo obligatorio en §8.1; Jur en la primera hora. |
| ROP-I6 | Doble cobro sin mecanismo conocido de confirmación de Wompi (D-02) | Alta | Alto | NL-02: no lanzar sin cerrarlo; PB-04. |
| ROP-I7 | Una comunicación a usuarios o titulares afirma "no se vieron datos" sin verificación | Media | Alto | Frase condicionada en C-2/C-4; aprobación de Jur. |

### 11.3 Decisiones pendientes

| ID | Decisión | Recomendación inicial | Quién decide |
|---|---|---|---|
| DOP-07 | Asignación de roles (IC, suplentes) y directorio de contactos | Antes del piloto, con suplentes | Gerencia + TI |
| DOP-08 | Interruptor de catálogo/mantenimiento global y banner de mantenimiento en `GET /config` | Añadir (RNF-029: 100 % de funciones críticas con interruptor) | Producto + Web |
| DOP-09 | Acceso de emergencia (y su registro) a la BD de WordPress y a Cloudflare mientras no exista la herramienta de revocación | Cuenta de emergencia con 2FA y registro de uso | TI + WP + Seg |
| DOP-10 | Umbral de adopción de la versión corregida para cerrar PB-06 y retirar versiones | A definir con telemetría del piloto | Móvil + Prod |
| DOP-11 | Acciones del Jurídico de §9 (vigencia del Título V, L-4, L-5, responsable de datos, contratos, retención) | Antes del piloto (R-P11, J-26) | Jur |
| DOP-12 | Contratar análisis forense externo en caso de compromiso | Definir presupuesto y proveedor de antemano (D-15) | Gerencia |
| DN-06 / D-02 / D-14 | Cobertura de soporte; doble pago de Wompi; titularidad de cuentas de tienda | Ver documentos previos | Según `decisiones_pendientes.md` |

*Fin del documento. BORRADOR sujeto a validación de IPR y del Jurídico; los plazos y umbrales son propuestas.*

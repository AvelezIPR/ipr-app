# Plan de mantenimiento — App IPR, BFF `/mobile/v1`, WordPress/WooCommerce y Wompi

| | |
|---|---|
| **Fase** | OPERACIÓN (documentación). **No se programa ni se configura nada.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. Es un **plan propuesto**: ninguna de las actividades está calendarizada, asignada ni ejecutada. Cadencias, plazos y umbrales son **propuestas**; los requisitos de las tiendas se marcan con su estado de verificación y deben re-verificarse en las fuentes primarias **antes de cada decisión**. |
| **Relacionado** | [monitoring.md](monitoring.md) · [logging.md](logging.md) · [incident_response.md](incident_response.md) · `../09_devops/ci_cd.md`, `environments.md` y `git_strategy.md` (otro agente; **no se duplican**: aquí solo se cita lo que el mantenimiento necesita de ellos) |
| **Fuentes** | `RNF` = `02_requirements/non_functional_requirements.md`; `SC`/`TM` = `06_security/`; `AA`/`AU`/`AC` = `05_api/`; `FA`/`DEP` = `03_architecture/`; `COD`/`WCA` = `00_discovery/`; `PRIV` = `06_security/privacy_assessment.md`; `QM` = `08_quality/quality_metrics.md` |

Etiquetas: **HECHO** · **SUPUESTO** (`SUP-H` = H-01..H-12 de `decisiones_pendientes.md` §E, **no aprobadas**) · **PROPUESTA** · **DECISIÓN PENDIENTE** (`DOP-xx`) · **RIESGO** (`ROP-xx`) · **DESCONOCIDO** · **NO VERIFICADO**.

---

## 1. Resumen

1. **El mantenimiento de esta solución tiene cinco fuentes de cambio externo**: dependencias (npm, pub, WordPress/plugins), sistemas operativos y SDK (Android, iOS, Flutter), tiendas (requisitos y políticas), secretos y certificados con vencimiento, y la ley (Ley 1581 y circulares de la SIC). El plan los pone en un **calendario** con **rol responsable** y **evidencia** (§2).
2. **Hoy la base de partida es débil** (HECHO): el CI web solo despliega, sin `tsc`, lint ni `npm audit`; el frontend **no tiene pruebas**; la auditoría interna de oct-2026 reportó **17 CVE (2 críticas)** y su estado actual **no está verificado** (SEC-05, MED-09); la rotación de secretos no está documentada (SC-039). **Antes de cualquier cadencia, hay que fijar la línea base** (§3.4).
3. **Las fechas de las tiendas ya vencieron para esta app nueva** (a 2026-11-18): por el resumen de búsqueda consultado, Google Play exige apuntar a **Android 16 (API 36)** desde el 31-ago-2026 (extensión hasta el 1-nov-2026, también vencida) y Apple exige **Xcode 26 / SDK 26** desde el 28-abr-2026 (§4.3). Estos datos son **VERIFICACIÓN PARCIAL** (no se abrieron las páginas oficiales) y deben confirmarse en F4.
4. **El respaldo y la restauración tienen una trampa de seguridad y privacidad**: restaurar una copia puede **resucitar sesiones revocadas** y **datos que ya se suprimieron**. §8.3 define el procedimiento posterior a una restauración.
5. **Pasarela, hosting y herramientas de IPR son desconocidos** (DES-xx de [monitoring.md](monitoring.md) §3): el plan dice qué hacer y quién, y marca lo que depende de ellos.

---

## 2. Calendario maestro

> Frecuencias propuestas. "Rol" = **Web**, **WP**, **Móvil**, **TI**, **Seg**, **Jur**, **Prod**, **Fin**, **Gerencia** (definidos en [incident_response.md](incident_response.md) §3). Quién ocupa cada rol: DESCONOCIDO (DOP-07).

| ID | Actividad | Frecuencia | Rol | Evidencia | Origen |
|---|---|---|---|---|---|
| M-01 | `npm audit` / OSV-Scanner sobre `package-lock.json` (BFF y web) | En cada PR (gate) + **diaria** programada | Web | Resultado en CI; 0 críticas/altas abiertas | RNF-048, RNF-049; SC-048 |
| M-02 | OSV-Scanner sobre `pubspec.lock` (app) | En cada PR + diaria | Móvil | Resultado en CI | RNF-048; SC-048 |
| M-03 | Revisión de avisos de seguridad de plugins/núcleo de WordPress y WooCommerce | Semanal | WP | Registro de avisos y decisión | SC-048; TM-050 |
| M-04 | Verificación de copias de seguridad (éxito del trabajo, tamaño, antigüedad) | Diaria (automática) / semanal (revisión) | TI + WP | Informe del trabajo; alerta si falta > 24 h | §8 |
| M-05 | Conciliación de pagos Wompi ↔ WooCommerce | Diaria (manual al inicio) | Fin + WP | Registro firmado | [monitoring.md](monitoring.md) §7 (AL-23) |
| M-06 | Actualización de dependencias menores/parches (PR agrupado) | **Mensual** (automatizada) | Web / Móvil | PR aprobado y desplegado con *gates* | RNF-094 |
| M-07 | Revisión de alertas ruidosas/mudas y de SLO/presupuesto de error | Mensual | Web + TI | Acta; cambios de umbral | [monitoring.md](monitoring.md) §16 |
| M-08 | Prueba de canarios (logs, auditoría, reportes de fallos) en producción con cuentas sintéticas | Mensual | QA + Web + Móvil | Informe de prueba | [logging.md](logging.md) §12 |
| M-09 | Revisión de accesos (paneles, logs, consolas de tienda, Cloudflare, WordPress, repositorios, gestor de secretos) y 2FA | Trimestral | Seg + TI | Lista de accesos revisada y bajas aplicadas | RNF-055; SC-040 |
| M-10 | Actualización de dependencias mayores (Next.js, Node LTS, Flutter, paquetes mayores) con pruebas de contrato y E2E | Trimestral (o cuando un aviso lo exija) | Web / Móvil | PR y resultados de pruebas | RNF-090, RNF-091 |
| M-11 | Revisión del modelo de amenazas y de riesgos aceptados | Trimestral + por evento | Seg | `threat_model.md` actualizado con fecha | §9 |
| M-12 | Revisión de privacidad (inventario de datos, retención, SDK, fichas de tienda) | Semestral + en cada versión que cambie datos | Jur + Seg + Móvil | Inventario firmado | RNF-060, RNF-061; §9 |
| M-13 | Ensayo de restauración en entorno aislado | Semestral | TI + WP | Informe con tiempos (RTO) y datos verificados | §8.4 |
| M-14 | Simulacro de incidentes (mesa y técnico) | Semestral | IC + Seg + Jur | Acta | [incident_response.md](incident_response.md) §10 |
| M-15 | Revisión de compatibilidad con nuevas versiones de Android/iOS/Flutter | **Anual** (y a la salida de betas) | Móvil | Informe de compatibilidad | §4 |
| M-16 | Revisión de requisitos y políticas de las tiendas | Trimestral + antes de cada *release* + ante aviso | Móvil + Prod + Jur | Lista de verificación firmada | §5; RNF-080 |
| M-17 | Revisión de versiones mínimas de Android/iOS con telemetría | Anual | Móvil + Prod | Decisión registrada | RNF-078, RNF-079, RNF-104 |
| M-18 | Rotación de secretos y revisión de certificados | Según §6.1 (anual / ante incidente / alertas de vencimiento) | TI + WP + Web | Registro de rotación | SC-039; `security_architecture.md` §8.8 |
| M-19 | Revisión de la política de versionado y retiro de la API | Semestral (y a la publicación de v2) | Web + Prod | Calendario de retiro actualizado | §7; DN-14 |
| M-20 | Prueba de penetración independiente | Antes del lanzamiento y luego anual o tras cambios mayores | Seg + Gerencia | Informe y reprueba | RNF-050; SC-063 |
| M-21 | Revisión de la deuda técnica y de hallazgos abiertos (SEC-xx, CH-xx, RB-xx, RA-xx) | Mensual (P0/P1) y trimestral (resto) | Web + WP + Móvil + Seg | Registro de seguimiento | §10 |
| M-22 | Revisión normativa (Ley 1581, circulares SIC, políticas de tiendas) | Semestral y ante cambio | Jur | Nota de vigencia | PRIV R-P18; [incident_response.md](incident_response.md) §9 |
| M-23 | Revisión de la capacidad (perfil de carga, disparadores de `AA` §14) | Trimestral los primeros 12 meses | Web + TI | Informe de capacidad | RNF-014..018; AA §14 |
| M-24 | Revisión de límites de rate limit y reglas de Cloudflare | Trimestral | TI + Seg | Cambios registrados | SC-005, SC-053 |
| M-25 | Verificación de `assetlinks.json` / `apple-app-site-association` y de enlaces profundos | Por *release* y tras cambio de claves de firma | Móvil + Web | Prueba de enlaces verificados | SC-026; RNF-046 |

---

## 3. Dependencias

### 3.1 Qué se gestiona

| Ecosistema | Archivo de bloqueo | Qué incluye | Estado de partida (HECHO / DESCONOCIDO) |
|---|---|---|---|
| **npm** (frontend + BFF, un solo proyecto) | `package-lock.json` (existe) | `next 16.3.4`, `nodemailer ^10.0.3`, React, Zod, etc. | `next`/`nodemailer` fijados según `package.json`; **`npm audit` no ejecutado** (MED-09); CI sin auditoría (SEC-10) |
| **pub** (app Flutter) | `pubspec.lock` (por versionar) | Flutter 3.50 / Dart 3.14 (propuesta, **NO instalado**), Riverpod, go_router, `dio`, `hive_ce`, Crashlytics o Sentry (DN-02), etc. (`FA` §17.1) | No existe; mínimos reales de Android/iOS con Flutter 3.50 y plugins: **NO VERIFICADO** (SPK-02) |
| **WordPress** | — | Núcleo, WooCommerce, plugin de Wompi, Wordfence, plugins de SEO/otros, snippets propios (`ipr-*.php`) | PHP 8.3 y Plesk (`INV` §2.1); **versiones y lista de plugins: DESCONOCIDAS** |
| **Plataforma del servidor** | — | Node (versión en uso DESCONOCIDA), sistema operativo del *droplet*, nginx | DESCONOCIDOS (DES-03) |
| **CI** | — | Acciones de GitHub, runners | `deploy.yml` despliega sin verificaciones; acciones no fijadas por SHA (SC-050) |

### 3.2 Cadencia y reglas (PROPUESTA)

| Tema | Regla | Origen |
|---|---|---|
| **Auditoría automática** | `npm audit` y OSV-Scanner en cada PR (el pipeline **falla** con vulnerabilidad crítica o alta) y una corrida **diaria** programada (las vulnerabilidades aparecen aunque no haya PR). Igual con `pubspec.lock`. | RNF-049; SC-048 |
| **Plazos de corrección** | Críticas **≤ 7 días**, altas **≤ 30 días** tras el aviso (propuestos; ajustar con IPR); medias ≤ 90 días; bajas en el *backlog*. Con explotación activa: mitigación en horas ([incident_response.md](incident_response.md) PB-07). Excepción solo por escrito (Seg + Gerencia) con compensatorios y fecha. | RNF-048 |
| **Actualizaciones menores y parches** | Un PR agrupado **mensual** automatizado, con pruebas de contrato y de humo. | RNF-094 |
| **Actualizaciones mayores** | Trimestrales o cuando un aviso las exija, **con rama propia, revisión del responsable técnico (C1) y pruebas de contrato de `/mobile/v1`** (el despliegue web y el BFF están acoplados: ADR-001, RB-09). No se mezclan con cambios funcionales. | ADR-001; RNF-090, RNF-095 |
| **Dependencias abandonadas** | Ninguna dependencia crítica sin publicaciones en 24 meses sin excepción aprobada; revisión trimestral con `flutter pub outdated` / `npm outdated`. | RNF-094 |
| **Plugins nativos nuevos (app)** | Requieren nota de decisión (impacto en tamaño, permisos, privacidad, mínimo de SO). | RNF-094; RNF-060 |
| **SBOM y bloqueos** | SBOM por versión; `pubspec.lock` y `package-lock.json` versionados; SDK de Flutter fijado. | SC-051 |
| **Acciones de CI** | Fijadas por SHA; revisión cuando cambian. | SC-050 |
| **WordPress / WooCommerce / plugins** | Inventario con versiones; parches de seguridad evaluados semanalmente; **toda actualización pasa primero por *staging*** (si no hay staging, ventana de bajo tráfico, copia previa y plan de reversa); las actualizaciones de WooCommerce o del plugin de Wompi se prueban con compra completa en sandbox antes de producción. Plugins sin mantenimiento se reemplazan o retiran. | SC-048; TM-050; ADR-001 C2 |
| **Node, Next.js, SO** | Seguir los avisos de seguridad de Next.js y Node; revisión semestral del calendario de fin de soporte (Node LTS, PHP 8.3, Debian/Ubuntu del servidor) — fechas **NO VERIFICADAS** en esta fase. | — |
| **Compatibilidad de contrato** | Todo cambio de dependencia que altere respuestas del BFF pasa la detección de cambios incompatibles del OpenAPI (`v1` no se rompe). | RNF-085; AA §5 |

### 3.3 Procedimiento para actualizar una dependencia

1. El PR automático o manual describe el cambio y enlaza el aviso (si lo hay).
2. CI: tipos, lint, SCA, escaneo de secretos, pruebas de contrato (ver `../09_devops/ci_cd.md`).
3. Revisión por una persona distinta del autor; cambios en `/mobile/v1` o `ipr/v1` revisados por el responsable técnico.
4. Despliegue por el mecanismo vigente, con verificación posterior (`AL-13`) y reversa disponible (RNF-030).
5. Para la app: construcción firmada desde CI, E2E, y lanzamiento escalonado ([incident_response.md](incident_response.md) PB-06).
6. Registro en el historial de mantenimiento (fecha, componente, versión anterior → nueva, riesgo, evidencia).

### 3.4 Acciones inmediatas de línea base (antes de operar)

| # | Acción | Rol | Origen |
|---|---|---|---|
| B-01 | Ejecutar `npm audit`/OSV sobre el frontend actual y registrar el resultado frente a los 17 CVE (2 críticas) reportados en oct-2026 | Web | MED-09; SEC-05; CH-12 |
| B-02 | Inventariar plugins y versiones de WordPress/WooCommerce/Wompi/Wordfence y su estado de soporte | WP | SC-048; MED-10 |
| B-03 | Escaneo de secretos del historial de `ipr-frontend` y rotación si hay hallazgos | Web + Seg | CH-13; ST-020 |
| B-04 | Documentar versión de Node, SO del servidor, comando de despliegue y reversa | TI | DES-03; RNF-030 |
| B-05 | Documentar copias de seguridad existentes del hosting y del servidor (qué, cuándo, dónde, quién) | TI + WP | DES-10; §8 |

---

## 4. Compatibilidad con Android, iOS y Flutter

### 4.1 Calendario de revisión (PROPUESTA)

| Cuándo | Qué se hace | Rol | Origen |
|---|---|---|---|
| **A la salida de cada beta** de una nueva versión mayor de Android o iOS (las fechas dependen de cada fabricante: **no se fijan aquí**) | Instalar la beta en dispositivos de la matriz (RNF-082), ejecutar la suite E2E y las pruebas de enlaces profundos, navegador seguro, Keychain/Keystore y permisos; registrar cambios de comportamiento que afecten (almacenamiento seguro, enlaces, notificaciones, fondo) | Móvil | RNF-078, RNF-079, RNF-082 |
| **A la salida de cada versión estable de Flutter** | Evaluar las notas de versión y los *breaking changes* en ≤ 30 días; adoptar como máximo cada dos versiones estables, **salvo** que un requisito de tienda o una vulnerabilidad obligue | Móvil | RNF-094; FA §1 |
| **Trimestral** | Revisar `flutter pub outdated`, plugins con código nativo, paquetes con avisos y compatibilidad con la versión de Flutter | Móvil | RNF-094 |
| **Anual (antes del plazo de Play, que es a fin de agosto en el ciclo observado)** | Subir `targetSdk`, `compileSdk` y las herramientas (Xcode/SDK de iOS) según los requisitos vigentes; ejecutar toda la regresión; **lanzamiento escalonado** | Móvil | RNF-080; §4.3 |
| **Anual (con telemetría de versiones)** | Revisar los mínimos de Android e iOS: **propuesta** de subir el mínimo cuando la versión más antigua represente < 5 % de los usuarios activos o cuando Flutter/plugins lo exijan (umbral propuesto, decide Gerencia + TI, DN-01) | Móvil + Prod | RNF-104; MED-01 |

### 4.2 Mínimos de la app (estado)

| Tema | Estado | Origen |
|---|---|---|
| Android mínimo | **Propuesta DN-01:** API 26 (Android 8.0); el mínimo real lo impone Flutter 3.50 + plugins: **NO VERIFICADO** | FA §1; RNF-078; SPK-02 |
| iOS mínimo | **Propuesta DN-01:** iOS 15.0; el *callback* https de `ASWebAuthenticationSession` requiere iOS 17.4 (ADR-008) | FA §1; RNF-079 |
| Flutter / Dart | Propuesta: Flutter 3.50 / Dart 3.14 (estado "Verificado" en la arquitectura; **no instalado**) | FA §1; testing_strategy H-Q8 |

### 4.3 Requisitos de las tiendas — qué se averiguó el 2026-11-18

> **VERIFICACIÓN PARCIAL:** provienen de resúmenes de una búsqueda sobre los dominios oficiales; **no se abrieron las páginas completas**. Antes de publicar (F4) y en cada revisión anual, confirmarlas en Play Console y en `developer.apple.com` (RNF-080, S-NF-07).

| Requisito | Qué dice el resumen consultado | Estado a la fecha | Acción | Fuente |
|---|---|---|---|---|
| **Google Play: nivel de API objetivo** | Apps nuevas y actualizaciones deben apuntar a **Android 16 (API 36)** o superior desde el **31-ago-2026**; las apps existentes deben apuntar al menos a API 35 para seguir visibles a usuarios nuevos en versiones recientes; extensión posible hasta el **1-nov-2026** | **Vencido** para esta app nueva (aplica API ≥ 36 al publicar) | Fijar `targetSdk` = 36 (o el vigente al publicar); verificar compatibilidad de Flutter 3.50 y plugins (SPK-02) | [Requisitos de nivel de API objetivo — Play Console Help](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en) |
| **Google Play: próximo nivel** | Se anuncia **API 37 (Android 17) hacia agosto de 2027** | Futuro | Planificar el ciclo anual 2027 | [Android Developers Blog — adaptive quality standards](https://developer.android.com/blog/posts/google-play-adaptive-quality-standards) |
| **Google Play: tamaño de página de 16 KB** | Apps que apuntan a API 35+ deben soportar páginas de 16 KB; las **actualizaciones** que no lo hagan **no podrán publicarse desde el 1-feb-2027** | Futuro cercano | Verificar que el motor de Flutter y **todo plugin con bibliotecas nativas** compilan con 16 KB (SPK-02, prueba en emulador) | [Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes) |
| **Apple: SDK de compilación** | Las cargas deben usar **Xcode 26 o posterior con SDK 26** desde el **28-abr-2026**; a partir de **abril de 2027**, SDK 27 | En vigor; próximo cambio abr-2027 | Fijar Xcode/SDK en el pipeline (macOS runner: DESCONOCIDO, DEP §12d); revisión en febrero de cada año | [Apple — Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) |
| Apple: otra fecha del 9-sep-2026 asociada a un "requisito mínimo de sistema iOS 13" | Se mencionó en el resumen, **sin que se pueda aclarar su alcance** | **NO VERIFICADO** | Leer la página oficial antes de fijar el *deployment target* | misma página |
| Eliminación de cuenta, política de privacidad, *Data Safety*/*Privacy Details* | Obligatorios; los SDK de terceros cuentan (ver §5) | **VERIFICADO** (primaria, `PRIV` §1.1, 2026-11-18) | Revisar en cada *release* | `PRIV` §1.1 |

---

## 5. Políticas de las tiendas (mantenimiento continuo)

| Tema | Qué se revisa | Cuándo | Rol | Origen |
|---|---|---|---|---|
| Ficha *Data Safety* (Google) y *App Privacy Details* (Apple) | Coinciden con **el tráfico real** de la app y con los SDK (reporte de fallos, analítica si se activa); captura de tráfico con proxy en *staging* | Antes de cada *release* que cambie datos o SDK; trimestral | Móvil + Jur | RNF-061; PRIV (Google/Apple filas) |
| Política de privacidad y enlace de eliminación de cuenta (ruta en la app + enlace web) | Vigentes, accesibles y coherentes con RF-110/RNF-058 | Cada *release*; semestral | Prod + Jur | PRIV §1.1; RNF-057, RNF-058 |
| Permisos del manifiesto/Info.plist | 0 permisos fuera de la lista aprobada | Cada *release* | Móvil | RNF-060; SC-042 |
| Cambios de políticas de las tiendas (contenido, pagos, enlaces externos, notificaciones, manifiestos de privacidad de SDK) | Lectura de boletines y comunicados de Play Console y Apple Developer | Trimestral y ante aviso | Prod + Móvil | RNF-080; S-NF-07 |
| Pago en navegador seguro | Que el flujo (checkout web de WooCommerce con Wompi en navegador del sistema) siga cumpliendo las políticas de pagos de cada tienda: **NO VERIFICADO** (no se abrió la política) | Antes de F4; ante cambios | Prod + Jur | ADR-001 decisión 4 |
| Cuentas de tienda | Titularidad a nombre de Inverprimos S.A.S. (D-14), 2FA, ≥ 2 custodios, pagos de membresía vigentes | Trimestral | Gerencia + TI | RNF-055; SC-040 |
| Reseñas y reportes (Play Console, App Store Connect) | Triage semanal; incidentes ([incident_response.md](incident_response.md)) | Semanal | Soporte + Móvil | RNF-098 |

---

## 6. Rotación de certificados y de secretos

### 6.1 Inventario y calendario

> **Ningún valor de secreto aparece en este documento.** "Frecuencia" es la propuesta base de `security_architecture.md` §8.8 ("anual o ante incidente") y de las condiciones de cada elemento. **Toda rotación se ensaya primero en *staging*** (DES-06).

| ID | Secreto o certificado | Dónde vive (propuesta) | Frecuencia | Doble valor / impacto | Rol | Estado (HECHO / PROPUESTA) | Origen |
|---|---|---|---|---|---|---|---|
| RS-01 | **`HANDOFF_SECRET`** (servidor Next) / **`IPR_HANDOFF_SECRET`** (WordPress) — firma del ticket de checkout | Variable de entorno del servidor; constante en `wp-config.php` (**no** opción de BD) | Anual y ante incidente | Con **doble valor** en WordPress (acepta el viejo y el nuevo) la rotación no corta el pago: 1) WP acepta ambos, 2) se despliega Next con el nuevo, 3) WP retira el viejo. Sin doble valor: corte breve del checkout (tickets de 60 s) → ventana de bajo tráfico y `checkoutEnabled` apagado | TI + WP + Web | HECHO: `handoff.php:64-70` admite la opción de BD (CH-26 la retira); rotación no documentada | SC-039, SC-009; TM-060; WP-16 |
| RS-02 | **`IPR_BFF_SECRET`** (`X-IPR-BFF-Secret`) — BFF ↔ WordPress | Idem; **distinto** del de *handoff* | Anual y ante incidente | Doble valor obligatorio (`hash_equals` con dos valores) | TI + WP + Web | PROPUESTO (ADR-014, WP-16) | SC-009 |
| RS-03 | **Claves de WooCommerce** (`consumer key/secret` de `wc/v3`) | Variables de entorno del servidor | Anual y ante incidente | Crear clave nueva → actualizar el servidor → desplegar → **revocar la vieja**; sin corte. Verificar que el permiso sea el mínimo necesario (solo lectura para catálogo: **DESCONOCIDO**) | WP + Web | HECHO que existen (`COD` §2); permisos DESCONOCIDOS | SC-039; TM-042 |
| RS-04 | **`REVALIDATE_SECRET`** (HMAC del *webhook* a `/api/revalidate`) | Variable de entorno + configuración del *webhook* en WooCommerce | Anual y ante exposición en logs | Cambiar ambos lados a la vez; durante el cambio los *webhooks* fallan y las cachés se refrescan por TTL (sin corte funcional) | Web + WP | HECHO: aceptado por `?secret=` y `GET` (CH-23 lo corrige) | SC-060; TM-053 |
| RS-05 | **Credenciales SMTP** (PQRS/boletín) | Variable de entorno | Anual y ante incidente | Cambiar y desplegar; la PQRS falla durante el cambio (usar `pqrsEnabled` apagado si es largo) | TI + Web | HECHO que existen (`COD` §2) | SC-039 |
| RS-06 | **Token de DigitalOcean y clave SSH de despliegue** (GitHub Secrets) | Secretos de GitHub con alcance mínimo; entorno de producción con aprobación | Semestral y ante baja de personal | Cambiar en DigitalOcean y GitHub; el despliegue falla si se olvida un lado | TI | HECHO: usados en `deploy.yml`; alcance del token "escritura sobre firewalls" | TM-051; SC-050 |
| RS-07 | **Clave del HMAC** de `userRef`/`deviceRef`/`subject_hash` | Gestor de secretos del BFF y de WordPress | **Solo ante incidente** (no por calendario corto) | Rotarla rompe la correlación histórica de logs: registrar la fecha de corte | Web + WP + Seg | PROPUESTO | [logging.md](logging.md) §3, §8 |
| RS-08 | **Claves y sales de WordPress** (`AUTH_KEY`… `NONCE_SALT`) | `wp-config.php` | Ante incidente | Invalida **todas** las cookies de WordPress (también administradores): coordinar | WP + TI | HECHO que existen (estándar de WordPress) | [incident_response.md](incident_response.md) PB-03/PB-05 |
| RS-09 | **Claves de Wompi** (llaves públicas/privadas, secreto de eventos, integridad) | Configuración del plugin en WooCommerce (**DESCONOCIDO** dónde y cómo) | Según la guía de Wompi; ante exposición | Rotar con Wompi y actualizar el plugin; verificar la firma de eventos; entorno *sandbox* y producción **separados** | WP + Fin | **DESCONOCIDO** (D-02) | SC-028; TM-030 |
| RS-10 | **Clave de subida de Android y Play App Signing** | Play App Signing (la clave de firma la custodia Google); clave de subida en el gestor de secretos con ≥ 2 custodios y 2FA | Según Play; ante pérdida o compromiso (se puede restablecer la clave de subida con soporte de Play: **verificar el procedimiento vigente**) | Cambia la huella en `assetlinks.json` solo si cambia la clave de **firma** (hay que actualizar el archivo, M-25) | Móvil + TI | PROPUESTO; titularidad DESCONOCIDA (D-14) | RNF-055; SC-040, SC-026 |
| RS-11 | **Certificados y perfiles de Apple** (distribución, aprovisionamiento, claves de la API de App Store Connect) | Gestor de secretos; ≥ 2 custodios; 2FA | **Calendario de vencimiento**: aviso a 60 y 30 días (los certificados y perfiles de Apple tienen vigencia limitada, típicamente de un año: **verificar** fechas en la cuenta) | Un certificado vencido impide firmar y publicar; no afecta a las apps ya instaladas | Móvil + TI | PROPUESTO; titularidad DESCONOCIDA (D-14) | RNF-055; SC-040 |
| RS-12 | **Certificados TLS**: (a) borde de Cloudflare, (b) origen de Next.js, (c) origen de WordPress (Plesk) | (a) gestionado por Cloudflare (**asumir** renovación automática: verificar); (b) y (c) **DESCONOCIDOS** (tipo, emisor, vencimiento) | Monitoreo continuo; renovar con ≥ 14 días de margen | La app **no** usa *certificate pinning* en el MVP (ADR-011, DN-05), así que una rotación **no** deja las apps sin conexión; si se adoptara *pinning*, exigir clave de respaldo y apagado remoto (RNF-038) | TI | Monitoreo de vencimiento y Certificate Transparency PROPUESTO (AL-14) | SC-065; RNF-101; RNF-038 |
| RS-13 | **Cuentas técnicas**: Cloudflare, GitHub, DigitalOcean, hosting de WordPress, consolas de tienda, proveedor de fallos | Gestor de contraseñas con 2FA | Revisión trimestral (M-09); cambio ante baja de personal | — | TI + Seg | PROPUESTO | RNF-055 |
| RS-14 | **Cuenta de prueba del monitoreo sintético** | Gestor de secretos | Semestral | Excluir sus eventos de las alertas de abuso | TI + WP | PROPUESTO | RNF-102; [monitoring.md](monitoring.md) §13 |
| RS-15 | **Archivos `.well-known`** (`assetlinks.json`, `apple-app-site-association`) | `public/.well-known/` del frontend | Al cambiar claves de firma o el identificador de la app | Un archivo incorrecto rompe el retorno del pago (RNF-025, R-NF-12) | Web + Móvil | PROPUESTO; ¿se puede alojar `/.well-known/`? DESCONOCIDO | SC-026; RNF-046 |

### 6.2 Procedimiento general de rotación (PROPUESTA)

1. **Inventario y alcance**: qué sistemas leen el secreto (servidor Next, WordPress, CI, plugin, tienda).
2. **Ventana y aprobación**: horario de bajo tráfico; avisar a los roles; `checkoutEnabled` apagado solo si no hay doble valor.
3. **Generar el nuevo valor** en el gestor de secretos (longitud y aleatoriedad suficientes; nunca compartirlo por chat o correo).
4. **Publicar con doble valor** donde sea posible (acepta viejo y nuevo), desplegar el consumidor con el nuevo valor.
5. **Verificar**: sintético funcional ([monitoring.md](monitoring.md) §13), prueba de ticket y de pago sandbox (staging), ausencia de errores de firma en logs.
6. **Retirar el valor viejo** y verificar que deja de funcionar.
7. **Registrar**: fecha, secreto (ID, nunca el valor), motivo, responsable, verificación. Si fue por incidente: referencia al post-mortem.
8. **Si la causa fue una exposición**: buscar usos del valor viejo (logs) y tratarlo como incidente ([incident_response.md](incident_response.md) PB-05).

---

## 7. Versionado y retiro de versiones (API y app)

### 7.1 Reglas vigentes (propuestas aprobadas solo en parte)

| Regla | Detalle | Estado | Origen |
|---|---|---|---|
| Versión mayor en la URI (`/mobile/v1`); `v1` no se rompe | Solo cambios compatibles (campos opcionales, endpoints nuevos, valores de enum "abiertos"); la app ignora campos desconocidos | ADR-001 decisión 5 (**Aprobada**); detalle en AA §5 (PROPUESTA) | ADR-001; RNF-085 |
| `v2` ante cambios incompatibles; `v1` se mantiene **≥ 12 meses** tras publicar `v2` | Con cabeceras `Deprecation` y `Sunset` y `Link: rel="deprecation"` (RFC 9745 / RFC 8594, citados en AA §5) | PROPUESTO (DN-14) | AA §5; RNF-085; DN-14 |
| Cabeceras `X-App-Version` y `X-App-Platform` obligatorias | Permiten medir adopción y forzar versión | PROPUESTO | AA §5 |
| `minSupportedVersion` (duro → `426`) y `recommendedVersion` (suave) en `GET /config` | Efecto ≤ 5 min | PROPUESTO | RNF-029; SC-052; AC EP-01 |
| `openapi.yaml` + detección de cambios incompatibles en CI | Herramienta a decidir | PROPUESTO | RNF-085; AA §5 |

### 7.2 Calendario de retiro de `v1` (PROPUESTA; los plazos de adopción son propuestos y se confirman con telemetría)

| Hito | Cuándo (T0 = publicación de `v2` en el BFF y de una versión de la app que lo usa) | Acción | Rol |
|---|---|---|---|
| H0 | T0 | Anuncio interno y externo; cabecera `Deprecation` en `v1`; documentación de migración | Web + Prod |
| H1 | T0 + 1 mes | `recommendedVersion` apunta a la versión con `v2` (aviso suave en la app) | Móvil + Prod |
| H2 | T0 + 3 meses | Revisión de adopción: porcentaje de usuarios activos en versiones con `v2` (umbral de decisión **propuesto**: ≥ 90 %; decide Producto, DOP-10) | Móvil + Prod |
| H3 | T0 + 9 meses | Aviso en la app y en la tienda; si la adopción lo permite, subir `minSupportedVersion` por encima de la última versión que solo usa `v1` **con la versión corregida ya en tienda** (regla de [incident_response.md](incident_response.md) PB-06) | Móvil + Prod |
| H4 | **≥ T0 + 12 meses** (DN-14) | Cabecera `Sunset`; el tráfico de `v1` debe ser < umbral **propuesto** (≤ 2 % de las solicitudes) antes de retirarla; si no, se pospone y se informa | Web + Prod |
| H5 | Tras H4 | Retiro de `v1` (respuesta `410`/`426` con instrucciones); eliminar código y pruebas; actualizar OpenAPI, ADR y documentación; archivar | Web |

### 7.3 Política de versión mínima de la app (PROPUESTA)

| Caso | Regla |
|---|---|
| Por **seguridad o defecto grave** | Se puede subir `minSupportedVersion` sin aviso previo largo, **solo con la corrección disponible en tienda** (PB-06). |
| Por **retiro de una versión de API** | Aviso suave ≥ 30 días antes (H1–H3). |
| Por **requisito de las tiendas o del SO** | Se sube cuando la tienda impide publicar sin ello; informar a los usuarios con el SO no soportado qué hacer (no se les bloquea sin explicación). |
| **Usuarios sin posibilidad de actualizar** (SO no soportado) | La pantalla de actualización ofrece canales alternos (WhatsApp/web de IPR); no se les deja sin salida (RNF-027). |
| Registro | Cada cambio de versión mínima queda en el historial con motivo, fecha y efecto (`426` observados, AL-36). |

---

## 8. Respaldo y restauración

### 8.1 Qué se respalda y qué no

| Activo | Contenido | ¿Datos personales? | Respaldo (PROPUESTA) | Estado actual |
|---|---|---|---|---|
| **Base de datos de WordPress/WooCommerce** | Usuarios, pedidos, `usermeta` (incluye `_ipr_*`), **tablas propuestas** `ipr_auth_sessions`, `ipr_auth_events`, `ipr_auth_throttle`, `ipr_consents`, configuración remota, opciones | **Sí (alto)** | **Diario** como mínimo + copia **antes de cada cambio** a WordPress/plugins; copia **fuera del hosting**, **cifrada**; retención inicial 30 días (propuesta; **A VALIDAR (Jur)**, DN-08) | **DESCONOCIDO** (DES-10) |
| **`wp-content`** (cargas de imágenes de producto, plugins, `mu-plugins`, snippets) | Imágenes originales, código de los snippets `ipr-*.php`; **cómo se publican los snippets en WordPress es DESCONOCIDO** (el código fuente está en `ipr-frontend/wp-snippets`) | Poco (imágenes) | Diario o semanal incremental; el código de los snippets debe estar en el repositorio (fuente de verdad) | DESCONOCIDO |
| **`wp-config.php` y archivos de servidor** (constantes secretas, sales) | Secretos | No, pero **críticos** | Copia **cifrada** en el gestor de secretos (nunca en el repositorio ni en la copia general sin cifrar) | DESCONOCIDO |
| **Servidor Next.js** | Sin estado durable propio: caché SWR, índice y contadores viven en **memoria** y se reconstruyen | No | **No se respalda el estado**; se respalda: código (GitHub), variables de entorno (gestor de secretos), configuración del servidor (nginx, servicio/contenedor, firewall) como **documentación o código** | HECHO que el estado es de memoria (`WCA` §5); configuración del servidor DESCONOCIDA |
| **Configuración de Cloudflare** (DNS, reglas WAF, Cache Rules, límites) | Reglas | No | Exportación periódica (trimestral y tras cada cambio) o infraestructura como código | DESCONOCIDO (DES-04) |
| **App móvil** | Repositorio, claves de firma y de subida, certificados de Apple, mapas de ofuscación y símbolos por versión, proyectos del proveedor de fallos | No | Repositorio con respaldo del proveedor; claves en gestor con ≥ 2 custodios; símbolos archivados **por versión** (sin ellos, los fallos no se simbolizan) | PROPUESTO (RNF-055, SC-041) |
| **Registros de Wompi** (transacciones) | Datos de pago | Sí, **del lado de Wompi** | No se respalda (los guarda Wompi); se concilia ([monitoring.md](monitoring.md) §7) | DESCONOCIDO (D-02) |

### 8.2 Objetivos de recuperación

| Objetivo | Estado |
|---|---|
| RPO (cuántos datos se pueden perder) y RTO (cuánto se tarda) de WordPress y del BFF | **DESCONOCIDOS; DECISIÓN PENDIENTE (DOP-13)**. Referencia existente: **reversa del BFF ≤ 15 min** (RNF-030, propuesta). Para WordPress no hay cifra: no se inventa. Con una copia diaria, el RPO máximo sería ≈ 24 h de pedidos y cuentas (**riesgo a evaluar con Finanzas** por la pérdida de pedidos pagados entre la copia y la falla; mitigación: conciliación con Wompi, §8.3 punto 5). |

### 8.3 Tabla de sesiones y datos de WordPress: qué ocurre al restaurar (PROCEDIMIENTO PROPUESTO)

**La tabla `ipr_auth_sessions` es de naturaleza efímera** (access 15 min; refresh con vida limitada; revocadas/vencidas se borran a los 30 días, `AU` §8.1). **Perderla** solo obliga a los usuarios a **volver a iniciar sesión** (la app maneja el `401`, borra tokens y conserva el carrito, SC-033, SUP-H H-07): es una degradación aceptable. **Restaurarla desde una copia** es lo peligroso:

| Riesgo al restaurar | Por qué | Qué hacer |
|---|---|---|
| **Sesiones revocadas que reviven** | Si, después de la copia, se revocó una sesión (robo, cambio de contraseña, `refresh_reused`), la copia las trae como activas | Tras restaurar, **revocar todas las sesiones** (`revoked_reason = 'admin'`, PB-03 alcance C) **o**, si la auditoría sobrevive en otro almacén, reaplicar las revocaciones registradas después de la copia |
| **Tokens robados que vuelven a valer** | Misma causa | Igual; además rotar los secretos si el incidente lo exigía |
| **Datos suprimidos que reaparecen** (Ley 1581: supresión) | Cuentas eliminadas o anonimizadas después de la copia | Mantener el **registro mínimo de eliminaciones** (`deletion_requested/completed`, sin PII) **fuera del alcance de la restauración** y **reaplicar** las eliminaciones posteriores a la copia (retención del registro: A VALIDAR (Jur)); verificar contra el plazo de supresión (H-11 SUP-H) |
| **Consentimientos revocados** | `ipr_consents` revertido | Reaplicar revocaciones registradas; verificar con Jur |
| **Pedidos pagados que faltan o fantasmas** | Brecha entre la copia y la falla | **Conciliar con Wompi** (§8.4); no marcar pagos a ciegas |
| **Contadores anti fuerza bruta (`ipr_auth_throttle`) viejos** | Estado temporal | Limpiar la tabla; el efecto es transitorio |
| **Versión del esquema distinta del código** (`ipr_auth_schema_version`, `dbDelta`) | Restaurar una copia con esquema anterior | Ejecutar migraciones y verificar la versión **antes** de abrir al tráfico |

**Orden recomendado tras una restauración de la BD de WordPress:** (1) restaurar en un entorno aislado y verificar integridad; (2) pasar a producción; (3) **reaplicar eliminaciones y revocaciones** (o revocar todo); (4) verificar esquema y migraciones; (5) **conciliar pagos** con Wompi (AL-23) y pedidos de la ventana; (6) verificar login web/app, refresh, checkout (en staging si no hay riesgo) y el sintético funcional; (7) reactivar `checkoutEnabled`; (8) monitoreo reforzado ≥ 72 h; (9) registrar el incidente y, si hay datos personales afectados, evaluar [incident_response.md](incident_response.md) PB-08.

### 8.4 Ensayo de restauración (semestral, M-13)

1. **Entorno aislado** de restauración con acceso restringido (**no** *staging* general: contiene copia de producción con PII; el *staging* debe usar datos sintéticos, SC-067); destruir al terminar.
2. Restaurar la copia más reciente; medir **tiempo** (RTO real) y **antigüedad** (RPO real).
3. Verificar: integridad de tablas, número de pedidos/usuarios plausible, esquema de `ipr_auth_*`, que **no** funcionen tokens de producción (credenciales y sales del entorno de prueba distintas).
4. Ejecutar el procedimiento de §8.3 (revocar, reaplicar eliminaciones) y cronometrarlo.
5. Documentar brechas; actualizar RPO/RTO y el manual.

### 8.5 Retención de copias y Ley 1581 (A VALIDAR con el Jurídico)

Las copias **contienen datos personales** y la auditoría con IP. La retención de las copias no debe contradecir los plazos de supresión (≤ 15 días hábiles propuestos, H-11 SUP-H; RNF-058) ni de los logs (≤ 90 días, RNF-063): si una copia conserva por 30 días lo que ya se suprimió, el Jurídico debe fijar la regla (p. ej., "la supresión alcanza las copias por expiración dentro de N días" y reaplicar supresiones al restaurar). **DECISIÓN PENDIENTE (DN-08, DOP-14).**

### 8.6 Verificación continua de copias

- Alerta si no hay copia exitosa en > 24 h (AL propuesta dentro de M-04; se agrega al catálogo de [monitoring.md](monitoring.md) cuando se defina el sistema de copias, DES-10).
- Verificación de integridad (suma de verificación) y de descifrado trimestral.
- Quién puede restaurar y cómo: lista de roles (WP + TI) y custodios de claves de cifrado de copias (≥ 2).

---

## 9. Revisión periódica de amenazas y de privacidad

| Revisión | Frecuencia | Disparadores adicionales | Qué se hace | Rol | Origen |
|---|---|---|---|---|---|
| **Modelo de amenazas** (`threat_model.md`, 62 amenazas) | Trimestral (M-11) | Nueva función (p. ej. push, B2B, cotización estructurada, campañas); nuevo proveedor o SDK; incidente SEV1/SEV2; resultado de pentest; cambio mayor de dependencia/SO/arquitectura (p. ej. segundo proceso Node, Redis) | Reevaluar probabilidad/impacto; actualizar controles SC-xx y pruebas ST-xx; registrar nuevas amenazas | Seg + Web + WP + Móvil | TM §1; RNF-050 |
| **Riesgos aceptados** (sin *pinning*, sin detección de root, sin atestación, enumeración residual, *scraping*) | Trimestral | **Criterios de reapertura** de SC-037: certificado propio con plan de rotación, requisito contractual/regulatorio, abuso por MITM detectado, función de mayor valor | Confirmar que sigue vigente la aceptación escrita (DA-15, NL-C7) o reabrir | Seg + Gerencia | SC-037, SC-069, CH-22; `threat_model.md` §5.3 |
| **Pruebas de penetración independientes** | Antes del lanzamiento y luego anual o tras cambios mayores | Cambio de contrato de pago o de autenticación | Reprueba hasta 0 críticos/altos | Seg + Gerencia | RNF-050; SC-063 |
| **Inventario de datos y evaluación de impacto de privacidad** (`privacy_assessment.md`) | Semestral (M-12) y en **cada versión** que cambie datos, permisos o SDK | Reforma de la Ley 1581 y nuevas circulares de la SIC; nuevo tratamiento; transferencia internacional; cambio de proveedor de fallos | Actualizar flujos F-xx, riesgos R-Pxx y preguntas J-xx; confirmar fichas de tienda | Jur + Seg + Móvil | RNF-060, RNF-061; PRIV R-P18, J-35 |
| **Retención y supresión** | Trimestral | Cambio de plazos de Jurídico | Auditar que los logs ≤ 90 días, sesiones a 30 días, auditoría y copias respetan lo definido; medir el plazo real de supresión (≤ 15 días hábiles propuestos) | WP + Web + Jur | RNF-058, RNF-063; SC-071 |
| **Solicitudes de titulares** (consulta, reclamo, supresión) | Mensual (indicador); plazos 10 y 15 días hábiles | — | Registrar y verificar el cumplimiento de plazos | Jur + Soporte | RNF-059; PRIV |
| **Registro de bases ante la SIC (RNBD)** | Antes del piloto y ante cambios de bases | Creación de bases nuevas (plazo de dos meses si hay obligación) | Confirmar la obligación (activos > 100.000 UVT: **DESCONOCIDO**) y las actualizaciones; el plazo de actualización del RNBD está **NO VERIFICADO** (PRIV §1.1) | Jur | RNF-064; PRIV §5 |
| **SDK y destinos de red de la app** | Cada *release* | Nuevo plugin | Captura de tráfico en *staging*; coincidencia con las fichas de tienda | Móvil + Seg | RNF-061 |
| **Calibración de límites y reglas de abuso** | Trimestral | Ataques observados (PB-09/PB-10) | Ajustar límites con datos reales (MED-10) | Seg + TI | RNF-042; SC-005 |

---

## 10. Deuda técnica y cierre de hallazgos (SEC-xx, CH-xx)

### 10.1 Reglas de gestión (PROPUESTA)

| Regla | Detalle |
|---|---|
| **Registro único** | Todo hallazgo (SEC-xx de la auditoría interna, CH-xx de `security_controls.md` §3, RB-xx/RA-xx de los análisis, acciones de post-mortem, resultados de pentest, MED-xx, DOP-xx) tiene una fila con **ID, origen, severidad, dueño (rol), fecha límite, criterio de cierre, evidencia y estado** (abierto, en curso, cerrado, riesgo aceptado). Ubicación del registro: DESCONOCIDA (herramienta de IPR). |
| **Plazos por severidad** (propuestos; alinear con RNF-048 y la clasificación de TM) | **P0/Crítica**: antes del lanzamiento o ≤ 7 días si ya está en producción · **P1/Alta**: antes del piloto o ≤ 30 días · **P2/Media**: ≤ 90 días con fecha comprometida · **Baja**: *backlog* revisado trimestralmente |
| **Cierre** | Solo con la **evidencia del criterio de cierre** (p. ej. la prueba ST-xxx aprobada en *staging*, 'git diff' revisado, informe de escaneo), **verificado por alguien distinto del autor**. "Corregido" sin evidencia = "pendiente de verificar". |
| **Riesgo aceptado** | Por escrito, con motivo, compensatorios, **fecha de revisión** y firma (Gerencia + Seg); aparece en la revisión trimestral (§9). |
| **Excepciones** | No se mueve una fecha sin registrar el motivo y quién lo aprueba. |
| **Deuda técnica** | Cada atajo temporal (p. ej. rate limit en memoria, un solo proceso, índice en variables de módulo, secretos en BD, cola sin tope) se registra con **disparador de pago** (los de `AA` §14: p95 de catálogo, CPU p95 > 70 %, degradación web > 10 %). |
| **Indicadores** | Hallazgos P0/P1 abiertos; antigüedad media; % cerrado en plazo; reincidencias. Se revisan mensualmente (M-21) y alimentan [monitoring.md](monitoring.md) P-08 si procede. |
| **Presupuesto de mantenimiento** | Reservar capacidad fija de cada ciclo para deuda y dependencias (porcentaje a decidir, DOP-15). |

### 10.2 Estado de partida de los hallazgos conocidos (HECHO; fuentes `COD` §5.2 y `security_controls.md`)

| ID | Hallazgo | Estado según `COD` / documentos | Cambio asociado | Prioridad (documentos) |
|---|---|---|---|---|
| SEC-01 | Redirección abierta y `returnUrl` | **Corregido** (se fija desde `PUBLIC_ORIGIN`; PHP valida lista cerrada) | — | Verificar en ST |
| SEC-02 | Límite de 50 usuarios al buscar el token | **Corregido** (consulta por `meta_value` con `number => 1`) | — | MED-16 (costo por `usermeta` sigue por medir) |
| SEC-03 | Cambio de correo/contraseña sin contraseña actual | **Corregido** (exige `current_password`) | SC-013 | Mantener |
| SEC-04 | XSS en descripción de producto | **Parcial** (`sanitizeHtml` en cliente; falta confirmar robustez; CSP `'unsafe-inline'`) | CH-08, CH-36 | P0 / P2 |
| SEC-05 | CVE en `next` y `nodemailer` (17 CVE, 2 críticas) | **No verificado** | CH-12; MED-09; §3.4 B-01 | **P0** |
| SEC-06 | Rate limit en autenticación | **Pendiente** | CH-02; SC-004, SC-005 | **P0** |
| SEC-07 | Ficha por slug sin `status=publish` (borradores) | **Abierto** (`wc.ts:1117-1121`) | CH-07; FE-01 | **P0** |
| SEC-08 | Perfil completo en `localStorage` (web) | Sigue | CH-36 | P2 |
| SEC-09 | Roles administrativos en la API de clientes; secretos por query | Sigue (`ipr-auth-rest.php`, `ipr-cart-handoff.php`, `/api/revalidate`) | CH-05, CH-23, CH-26 | **P0** / P1 |
| SEC-10 | CI sin `tsc`, lint ni `npm audit`; sin pruebas | Sigue | CH-12, FE-11 | **P0** |

**Resumen del registro de seguridad (de `security_controls.md` §3):** 22 cambios P0 (CH-01..CH-22), 9 P1 (CH-23..CH-31), 6 P2 (CH-32..CH-37). Los P0 bloquean el lanzamiento. Operaciones **no** los cierra: los **cierra el equipo responsable** y los verifica Seg; Operaciones los **vigila** en la revisión mensual (M-21).

---

## 11. Responsabilidades por rol

| Rol | Frecuencia | Responsabilidades de mantenimiento |
|---|---|---|
| **Web** | Diaria / semanal / mensual | Dependencias npm y auditoría (M-01, M-06, M-10); BFF, límites, índice y cola; contratos y OpenAPI; versionado y retiro de API (M-19); logs sin PII (M-08); capacidad (M-23); rotación de secretos del servidor (RS-01..RS-05) |
| **WP** | Semanal / mensual | Núcleo, WooCommerce, plugins y snippets (M-03); auditoría y tablas `ipr_auth_*`; copias y restauración de WordPress (M-04, M-13); conciliación (M-05); roles de administradores |
| **Móvil** | Mensual / anual | Dependencias pub (M-02, M-06, M-10); compatibilidad con Android/iOS/Flutter (M-15, M-17); requisitos de tienda (M-16, M-25); firma y certificados (RS-10, RS-11); fichas de privacidad; lanzamientos escalonados |
| **TI** | Diaria / trimestral | Servidor, SO, Node, Cloudflare, certificados (RS-12), copias (M-04), accesos (M-09), reglas de borde (M-24), CI y gestor de secretos, monitoreo |
| **Seg** | Trimestral / anual | Modelo de amenazas (M-11), pentest (M-20), revisión de accesos (M-09), riesgos aceptados, cierre de hallazgos (M-21), simulacros |
| **Jur** | Semestral / por evento | Retención y supresión, RNBD, fichas legales, vigencia normativa (M-22), contratos con proveedores, plantillas de comunicación |
| **Prod** | Trimestral / anual | Política de versión mínima, retiro de `v1`, políticas de tiendas, comunicación a usuarios, telemetría de versiones |
| **Fin** | Diaria | Conciliación de pagos (M-05); acciones sobre Wompi |
| **Gerencia** | Trimestral / anual | Riesgos aceptados, presupuesto (pentest, monitoreo, forense), titularidad de cuentas (D-14), cobertura de guardia |

---

## 12. Hechos, supuestos, riesgos y decisiones pendientes

### 12.1 Supuestos

| ID | Supuesto | Si es falso |
|---|---|---|
| SM-01 | Las cadencias propuestas son viables con el equipo que IPR asigne (D-15 abierta). | Priorizar por riesgo: auditoría diaria, copias, certificados y conciliación primero. |
| SM-02 | Existirá *staging* (C2) para ensayar rotaciones, actualizaciones y restauraciones. | Los ensayos se hacen en un entorno aislado y en ventanas de bajo tráfico; riesgo mayor. |
| SM-03 | Cloudflare gestiona la renovación del certificado del borde. | Añadir el vencimiento a RS-12 con responsable. |
| SM-04 | Se aprueban SUP-H H-04, H-05, H-07, H-09, H-11 como se recomiendan (afectan §8.3 y §10). | Ajustar el procedimiento de restauración y los plazos. |
| SM-05 | Los requisitos de las tiendas de §4.3 se confirman en las fuentes primarias. | Ajustar `targetSdk`, Xcode y plazos. |

### 12.2 Riesgos

| ID | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| ROP-M1 | El **CI actual no audita** ni prueba: una dependencia vulnerable puede llegar a producción (SEC-10, TM-050) | Alta | Alto | §3.4 B-01; CH-12; gate de CI |
| ROP-M2 | Un secreto compartido nunca rotado o filtrado en logs (`?secret=`, `?token=`) | Media | Alto | RS-01..RS-04; CH-23, CH-26; [logging.md](logging.md) |
| ROP-M3 | Vencimiento no detectado de un certificado (origen, Apple) o de una cuenta de tienda | Media | Alto | RS-11, RS-12; alertas de 14 días; 2 custodios |
| ROP-M4 | Restaurar una copia revive sesiones y datos suprimidos | Media | Alto | §8.3 y §8.5 |
| ROP-M5 | Las copias de seguridad no existen, no están probadas o no se sabe quién las restaura (DES-10) | Media | Alto | B-05; ensayo semestral |
| ROP-M6 | Incompatibilidad de Flutter/plugins con el `targetSdk` o con 16 KB de página impide publicar | Media | Alto | Spike SPK-02; revisión anual §4 |
| ROP-M7 | Subir la versión mínima sin versión corregida o sin retiro ordenado deja usuarios bloqueados | Media | Alto | §7.3; PB-06 |
| ROP-M8 | Deriva normativa (Ley 1581, SIC) sin responsable | Media | Medio | M-22; Jur |
| ROP-M9 | Hallazgos "corregidos" sin evidencia | Media | Medio | Regla de cierre §10.1 |

### 12.3 Decisiones pendientes

| ID | Decisión | Recomendación inicial | Quién decide |
|---|---|---|---|
| DOP-13 | RPO y RTO de WordPress y del BFF | Definir tras conocer las copias existentes (B-05) y con Finanzas el costo de perder pedidos | Gerencia + TI + Fin |
| DOP-14 | Retención de copias y alcance de la supresión en copias | Ver §8.5; plazo fijado por Jurídico (DN-08) | Jur + Fin + TI |
| DOP-15 | Presupuesto (capacidad) de mantenimiento por ciclo y herramientas de automatización (Dependabot/Renovate, escáner) | Reservar capacidad fija; herramienta en `ci_cd.md` | Gerencia + Web |
| DOP-10 | Umbrales de adopción para retirar versiones (≥ 90 % para subir la mínima; ≤ 2 % de tráfico en `v1` al retirarla) | Calibrar con telemetría del piloto | Móvil + Prod |
| DN-01 / DN-14 | Mínimos de Android/iOS; política de versión mínima y soporte de `/mobile/v1` | Ver RNF §3 | Gerencia + TI + Prod |
| D-14 / D-15 | Cuentas de tienda; presupuesto y equipo | Ver `decisiones_pendientes.md` | Gerencia |

*Fin del documento. BORRADOR; las cadencias y umbrales son propuestas y los requisitos de las tiendas deben re-verificarse en fuentes primarias antes de cada decisión.*

# Estrategia de Git, repositorios y revisión de código

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.), BFF `/mobile/v1` y ampliación de WordPress |
| **Fase** | DEVSECOPS. **No se programa nada ni se tocan repositorios.** Este documento es estrategia y procedimiento; nada de lo descrito está configurado ni ejecutado. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para aprobación. Sin claves, tokens, certificados, IP ni valores de `.env`. |
| **Relacionados** | [`ci_cd.md`](ci_cd.md) · [`environments.md`](environments.md) · [`deployment_guide.md`](deployment_guide.md) · ADR-001/002 (únicas aprobadas) · `06_security/security_controls.md` (SC-040, SC-050, SC-051; CH-12, CH-13) · `08_quality/testing_strategy.md` §7.1 (QG-M11, QG-M12) |

## 0. Convenciones

Etiquetas (las mismas de `03_architecture/`): **HECHO** (verificado en documento o código leído), **SUPUESTO** (`SUP-DO-xx`), **PROPUESTA**, **DECISIÓN PENDIENTE** (`DO-xx`, requiere aprobación humana), **RIESGO** (`RD-xx`), **DESCONOCIDO**, **NO VERIFICADO**.

`SUP-H-nn` = supuesto basado en la recomendación **H-nn** de `project/decisiones_pendientes.md` §E, que **no está aprobada**. Este documento depende de ellas solo donde se indica.

Roles (sin nombres): **Web** (equipo de `ipr-frontend`/BFF), **WP** (quien mantiene WordPress), **Móvil** (equipo de la app, por definir, D-15), **TI** (infraestructura, Cloudflare, CI), **Seg**, **QA**, **Resp. técnico** (responsable técnico de `ipr-frontend` y WordPress; conformidad pendiente, ADR-001 C1).

---

## 1. Hechos de partida y desconocidos que condicionan la estrategia

| # | Dato | Estado | Fuente |
|---|---|---|---|
| 1 | `ipr-frontend` está en GitHub (121 commits en la lectura del 2026-11-18); el workflow `deploy.yml` se dispara en **cada push a `main`** (salvo `**.md` y `docs/**`) y despliega por SSH a producción. | HECHO | `.github/workflows/deploy.yml` (leído hoy); `00_discovery/informe_codigo_frontend.md` §2 |
| 2 | El código de WordPress que existe son **snippets PHP** en `wp-snippets/` dentro de `ipr-frontend`; se instalan copiando código en wp-admin (no hay despliegue versionado verificable). | HECHO | `informe_codigo_frontend.md`; `security_architecture.md` §8.5 |
| 3 | El BFF vivirá en `ipr-frontend` (`src/app/mobile/v1/**`, `src/lib/mobile/**`), con `openapi.yaml` en el mismo repositorio. | HECHO (ADR-001 aprobada; el responsable técnico aún no ha dado su conformidad, C1) | `architecture_decisions.md`; `api_architecture.md` §4.1, §5 |
| 4 | Tamaño y composición del equipo (web y móvil), política de revisión actual, plan de GitHub (Free/Team/Enterprise) y si el repositorio es de una organización. | **DESCONOCIDO** (D-15; "política de revisión DESCONOCIDA", RNF-095) | `non_functional_requirements.md` RNF-095; `architecture_overview.md` §2.1 |
| 5 | Gestor de incidencias/tablero (ids de ticket para ramas y commits). | DESCONOCIDO | — |
| 6 | No existen pruebas ni `tsc` en CI web; `package.json` solo tiene `dev`, `build`, `start`, `lint`. | HECHO | `package.json` y `deploy.yml` leídos hoy |
| 7 | `.gitignore` de `ipr-frontend` ya excluye `.env*` (con `!.env.example`), `*.pem`, `/node_modules`, `/.next/`, `/coverage`. No excluye `*.p12`, `*.p8`, `*.jks`, `*.keystore`, `*.mobileprovision` (no relevantes hoy porque el repo web no firma apps). | HECHO | `.gitignore` leído hoy |
| 8 | El historial de Git de `ipr-frontend` **no ha sido escaneado** en busca de secretos. | HECHO (ST-020 pendiente) | `security_architecture.md` §8.8 |

---

## 2. Repositorios

### 2.1 Mapa propuesto

| Repositorio | Contenido | Estado | Justificación |
|---|---|---|---|
| **`ipr-frontend`** (existente) | Web Next.js, **BFF `/mobile/v1`**, `openapi.yaml`, `public/.well-known/*`, página `/app/pedido`, `wp-snippets/` y (propuesta) el plugin/mu-plugin de `ipr/v1/m/*`. | HECHO (existe) / PROPUESTA (contenido nuevo) | ADR-001 aprobada: reutiliza `lib/woocommerce.ts` y `lib/wc/*` sin duplicar acceso a WooCommerce. |
| **Repositorio de la app Flutter** (nuevo; nombre por definir, p. ej. `ipr-mobile`) | App Flutter, `config/<flavor>.json` (solo valores públicos), `pubspec.lock`, scripts de CI (reglas de dependencia, cobertura por módulo, trazabilidad), workflows de la app. | **PROPUESTA DO-01** | Ver 2.2. |
| **Documentación** (`docs/` actual, carpeta `ipr-app`) | Documentación de proyecto, ADR, plan de pruebas. | HECHO (existe como carpeta local; si tiene repo: DESCONOCIDO) | Debe versionarse; se propone que viva en un repositorio propio o dentro del repo de la app (decisión de bajo riesgo, DO-02). |

### 2.2 ¿La app Flutter en repositorio propio? (DO-01)

| Criterio | Repo propio (recomendado) | Monorepo con `ipr-frontend` |
|---|---|---|
| Cadena de herramientas | Flutter/Dart, Xcode, Gradle: nada en común con Node/Next. Cachés y runners distintos (macOS para iOS). | Un workflow mezcla Node, Flutter y macOS; matrices complejas. |
| Ritmo de liberación | La app se publica por tiendas con revisión y despliegue escalonado (días); el BFF se despliega en minutos y **hoy cada push a `main` va a producción**. | Acopla el ciclo móvil al de la web (el costo que ADR-001 ya declara como negativo). |
| Superficie de secretos | Claves de subida, certificados de Apple y cuentas de tienda solo en el repo/entornos de la app. | Los secretos de firma conviven con el secreto de despliegue a producción de la web (SSH, token del firewall). Ampliaría el radio de daño (TM-051). |
| Permisos | Equipo móvil con escritura en su repo y solo lectura (o PR) en `ipr-frontend`; Web y WP revisan lo suyo (CODEOWNERS por repo). | Todo el equipo móvil tendría escritura en el repo que despliega producción. |
| Contrato | Se sincroniza el OpenAPI entre repos (costo; ver 2.3). | El OpenAPI y la app cambian en el mismo PR (ventaja real). |
| Equipo muy pequeño (1–2 personas) | Más sobrecarga de administración. | Menos sobrecarga. |

**Recomendación (PROPUESTA):** repositorio propio para la app. El único argumento serio a favor del monorepo (contrato en un PR) se cubre con 2.3. Si el equipo móvil resulta ser una sola persona que además es del equipo web, se puede revisar (DO-01). Decide: solicitante + Resp. técnico.

### 2.3 Sincronización del contrato `openapi.yaml` entre repositorios (PROPUESTA)

| Mecanismo | Detalle | Estado |
|---|---|---|
| Fuente de verdad | `openapi.yaml` en `ipr-frontend` (`api_architecture.md` §5). Hoy es `x-status: proposed`. | HECHO (diseño) |
| Copia en la app | El repo de la app guarda los *fixtures* y una copia **fijada por tag/commit** del OpenAPI (`contract/openapi.yaml` + archivo con el commit de origen). Actualizarla es un PR explícito en el repo de la app. | PROPUESTA |
| Detección de ruptura | `oasdiff` en CI de `ipr-frontend` compara el PR contra `main` y contra el último tag (QG-B05); en la app, el script de contrato valida *fixtures* contra la copia fijada (QG-M06). | PROPUESTA; soporte de OpenAPI 3.1 en `oasdiff`: NO VERIFICADO (`testing_strategy.md` §6) |
| Aviso entre repos | Un PR en `ipr-frontend` que toque `openapi.yaml` o `src/app/mobile/**` debe enlazar el PR/issue correspondiente de la app (campo obligatorio en la plantilla de PR). Automatizar con un evento entre repos queda como mejora (no probada). | PROPUESTA |
| Regla | Nunca cambios incompatibles en `v1` (RNF-085, QM-58): un cambio incompatible exige `/mobile/v2`, anuncio y ≥ 12 meses de convivencia (DN-14). | HECHO (diseño) |

### 2.4 WordPress

| Elemento | Propuesta | Justificación | Estado |
|---|---|---|---|
| Código existente | Sigue en `ipr-frontend/wp-snippets/` (sin moverlo en este proyecto). | No tocar lo que funciona; añadir revisión y análisis estático. | PROPUESTA |
| Código nuevo (`ipr/v1/m/*`, tablas `ipr_auth_*`) | Un **plugin o mu-plugin propio versionado** en un directorio dedicado de `ipr-frontend` (p. ej. `wordpress/ipr-mobile/`), con `dbDelta` versionado y `CODEOWNERS` propio. Alternativa: repositorio separado si el despliegue a Plesk resulta ser distinto y el equipo WP es otro. | RS-02 de `authentication.md` pide plugin propio versionado; un mismo repositorio mantiene un único responsable técnico y evita un cuarto repositorio con equipo desconocido. | **DECISIÓN PENDIENTE DO-03** |
| Cómo llega a WordPress | **DESCONOCIDO** (hoy: copiar en wp-admin; el mecanismo de staging y de Plesk no está documentado). | — | Ver `ci_cd.md` §5 |
| Filtros de ruta en CI | Un cambio solo en `wordpress/**` o `wp-snippets/**` **no** debe disparar el despliegue de Next.js (hoy `paths-ignore` solo excluye `**.md` y `docs/**`, por lo que un cambio de snippet redespliega la web sin necesidad). | Reduce despliegues innecesarios a producción. | PROPUESTA |

---

## 3. Estrategia de ramas

### 3.1 Decisión: trunk-based con ramas cortas (DO-04, SUP-DO-01)

El tamaño del equipo es **DESCONOCIDO** (D-15). Se compararon las dos opciones solicitadas.

| Criterio | Trunk-based con ramas cortas (recomendado) | GitFlow ligero (`develop` + `main` + `release/*`) |
|---|---|---|
| Equipo pequeño (≤ ~6 personas con CI) | Adecuado: pocas ramas, integración continua real. | Sobrecarga: dos ramas largas que mantener sincronizadas. |
| Equipo mediano/grande con QA manual largo por versión | Requiere disciplina de *feature flags* y CI rápida. | Adecuado: `develop` absorbe trabajo mientras `release/*` se estabiliza. |
| Encaje con el diseño existente | Los interruptores remotos (`/mobile/v1/config`, RNF-029) ya permiten fusionar funcionalidad incompleta apagada. La reversa del BFF ≤ 15 min (RNF-030) exige poder redesplegar `main`/un tag rápido. | Dos ramas de integración multiplican los despliegues a staging y retrasan los conflictos. |
| Releases móviles | Se corta una rama `release/X.Y` **solo** cuando hay que corregir una versión ya publicada mientras `main` avanza. | `release/*` es sistemática. |
| Riesgo | Un `main` roto bloquea a todos (se mitiga con puertas obligatorias, 5.1). | Integración tardía: conflictos y sorpresas al fusionar `develop` a `main`. |

**Recomendación:** trunk-based. **Condición de reapertura:** si el equipo móvil supera ~6 personas con ciclos de QA manual de más de una semana, o si no es viable operar con *feature flags*, pasar a GitFlow ligero (solo en el repo de la app; el BFF se queda en trunk porque se despliega continuamente). Decide: solicitante + Resp. técnico + líder móvil cuando exista.

### 3.2 Reglas

| Regla | Valor | Justificación |
|---|---|---|
| Rama principal | `main`, siempre desplegable/publicable | Base del pipeline. |
| Ramas de trabajo | `feat/<alcance>-<resumen>`, `fix/…`, `chore/…`, `docs/…`, `ci/…`, `hotfix/…`; con id de ticket cuando exista un tablero (DESCONOCIDO) | Legibilidad y filtros de CI. |
| Vida de una rama | ≤ 2 días laborables; PR en borrador desde el primer día | Evita divergencia. |
| Tamaño de PR | Objetivo ≤ ~400 líneas de diff (guía, no puerta) | Revisiones efectivas. |
| Método de fusión | **Squash**, historial lineal; el título del PR es el mensaje del commit (Conventional Commits) | Un commit por cambio, changelog automático. |
| Funcionalidad incompleta | Detrás de interruptor (`/mobile/v1/config` o constante de compilación por *flavor*), nunca en una rama larga | Trunk-based. |
| `release/X.Y` | Solo para parches de una versión de tienda ya publicada. Se crea desde el tag `vX.Y.Z`; el arreglo se aplica primero en `main` y se *cherry-pick*; tag `vX.Y.(Z+1)`; la rama se borra al retirar esa línea. | Corregir sin arrastrar trabajo no probado. |
| `hotfix` del BFF | Rama corta desde `main`; mismas puertas; despliegue con aprobación del entorno. No se omiten puertas (los criterios absolutos no tienen excepción, `testing_strategy.md` §7). | Una corrección rápida no justifica un incidente de seguridad. |
| Comportamiento de `main` en `ipr-frontend` mientras no exista staging | **Se conserva** el despliegue a producción al fusionar en `main`, pero **solo después** de que pasen las puertas y con aprobación del entorno `production` (ver `ci_cd.md` §4). | No romper el flujo actual y cerrar RA-08. |
| Con staging (C2) | `main` → staging automático; producción por tag `vX.Y.Z` con aprobación. | Evita que cada merge llegue a producción. |

---

## 4. Convención de commits y versionado

### 4.1 Commits (PROPUESTA)

Formato **Conventional Commits** (`tipo(alcance): resumen en imperativo, ≤ 72 caracteres`), en español o inglés pero **uno solo** por repositorio (DO-05).

| Elemento | Valores |
|---|---|
| Tipos | `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`, `chore`, `revert`, `security` |
| Alcances `ipr-frontend` | `bff`, `web`, `wp`, `contract`, `ci`, `wellknown`, `deps` |
| Alcances app | `app`, `core`, `feature-<nombre>`, `design`, `ci`, `deps`, `release` |
| Cambio incompatible | `!` y pie `BREAKING CHANGE:`. En `/mobile/v1` está **prohibido** (RNF-085): solo se permite en `v2`. CI lo rechaza en `bff`/`contract` salvo etiqueta de `v2`. |
| Referencias | Pie `Refs: <id de ticket o requisito>` (RF/RNF/FE-xx/WP-xx/CH-xx) |
| Prohibido en el mensaje | Secretos, URLs con tokens, correos o datos de clientes, IP de servidores. |
| Verificación | Se valida el **título del PR** (squash) con un script o *linter* en CI; elegir herramienta: NO VERIFICADO (no se evaluó). |
| Atribución de herramientas de IA | Si el equipo usa asistentes que añaden pie de coautoría, se conserva tal cual lo indique la herramienta. |

### 4.2 Versionado semántico

| Artefacto | Esquema | Regla | Dónde se registra |
|---|---|---|---|
| **App** | `MAJOR.MINOR.PATCH+BUILD` (`version:` de `pubspec.yaml`) | MAJOR: sube el mínimo de SO, cambia el modelo local de forma incompatible o rediseño completo. MINOR: funcionalidad. PATCH: correcciones. `BUILD`: entero **creciente** que asigna CI (p. ej. número de ejecución del workflow de release). El mismo `BUILD` no se reutiliza. | Tag `vX.Y.Z` firmado en el repo de la app; cabecera `X-App-Version` (N-01/T-09); changelog. |
| **API `/mobile/v1`** | Versión mayor en la URI; `info.version` del OpenAPI en SemVer (cambios compatibles = MINOR/PATCH) | Cambio incompatible solo con `/mobile/v2` y convivencia ≥ 12 meses (DN-14). | `openapi.yaml`; `Deprecation`/`Sunset` (`api_architecture.md` §5). |
| **Web + BFF (`ipr-frontend`)** | SemVer (hoy `0.1.0` en `package.json`); tag `vX.Y.Z` en cada producción | Define el punto de reversa (RNF-030). | Tag, release notes. |
| **Plugin de WordPress** | SemVer + **versión de esquema** de base de datos separada | El esquema es **solo aditivo** durante un ciclo, para poder volver a la versión anterior del plugin sin migración inversa (ver `deployment_guide.md` §9). | Cabecera del plugin; opción de BD de versión de esquema. |
| **Build number y tiendas** | Android `versionCode` y iOS `CFBundleVersion` derivan de `BUILD` | `versionCode` debe ser mayor que el anterior publicado: no hay "volver a un número menor" (ver `deployment_guide.md` §9). Nunca superar el máximo permitido por la tienda (NO VERIFICADO el valor vigente). | `pubspec.yaml`, artefactos de CI. |

Los cambios de plataforma mínima (DN-01: API 26 / iOS 15 propuestos) se tratan como MAJOR y requieren decisión (DA-05).

---

## 5. Protección de ramas, CODEOWNERS y revisión

### 5.1 Reglas de protección de `main` (PROPUESTA, SC-050, RNF-095, QG-M11)

Capacidades verificadas hoy en la documentación de GitHub (consulta 2026-11-18): revisiones requeridas, aprobación de *code owners*, comprobaciones de estado obligatorias, commits firmados, historial lineal, bloqueo de *force push* y existencia de *rulesets*. La **disponibilidad según el plan** (en repos privados) la documentación consultada no la confirma por completo: **NO VERIFICADO** para el plan de IPR (DESCONOCIDO).

| Regla | Valor | Cubre |
|---|---|---|
| Requerir PR (nada de push directo a `main`, tampoco administradores) | Sí | SC-050 |
| Aprobaciones | ≥ 1, de persona **distinta del autor**; descartar aprobaciones obsoletas al cambiar el diff; "aprobación de alguien distinto al último que empujó" | RNF-095, QM-55 |
| Revisión de *code owners* | Obligatoria | RNF-095 |
| Comprobaciones requeridas | Todas las de `ci_cd.md` §7 (merge) | QG-M01..M12, QG-B01..B07 |
| Rama actualizada con `main` antes de fusionar | Sí (modo estricto) | Evita fusiones verdes sobre base vieja |
| Historial lineal / squash | Sí | 3.2 |
| *Force push* y borrado de `main` | Prohibidos | Integridad |
| Commits firmados | **Requerido** tras la fase de incorporación (ver 5.4) | SC-050 (propuesta), TM-051 |
| Resolución de conversaciones | Obligatoria | Calidad |
| Etiquetas `v*` | Regla de etiquetas: solo el rol de *release* puede crearlas | Reversa y trazabilidad |
| Entorno `production` / `release` | Revisores requeridos del entorno distintos de quien lanzó el flujo | SC-050 ("entorno de producción con aprobación") |

Si el plan de GitHub no permite alguna regla, se registra como **RIESGO RD-01** y se compensa con un *check* propio que falle el flujo o con un cambio de plan (decisión de Gerencia).

**Equipo de una sola persona (hipótesis posible):** la regla "persona distinta del autor" no se puede cumplir. Alternativa mínima (PROPUESTA): el Resp. técnico o una persona designada por IPR revisa los PR que tocan `/mobile/v1`, `ipr/v1`, firma y CI; cualquier excepción es una aceptación de riesgo escrita (como CH-22), no un *bypass* silencioso.

### 5.2 CODEOWNERS (PROPUESTA; los nombres de equipo son marcadores)

Los dos repositorios deben tener `CODEOWNERS`. Rutas y propietarios (roles):

**`ipr-frontend`**

| Ruta | Propietario (rol) | Motivo |
|---|---|---|
| `/.github/workflows/`, `/.github/CODEOWNERS` | TI + Resp. técnico | Un cambio de workflow es un cambio de acceso a producción (recomendación de GitHub de proteger workflows con *code owners*) |
| `/src/app/mobile/`, `/src/lib/mobile/` | Resp. técnico + Web | ADR-001 C1, RNF-095 |
| `/openapi.yaml` | Resp. técnico + Móvil | Contrato |
| `/wp-snippets/`, `/wordpress/` | WP + Resp. técnico + Seg | Superficie `ipr/v1`, autorización |
| `/public/.well-known/`, `/next.config.ts` | Resp. técnico + Móvil | App Links/Universal Links, cabeceras |
| `/src/app/api/revalidate/`, `/src/lib/rate-limit.ts`, `/src/lib/session.ts`, `/src/lib/auth.ts` | Resp. técnico + Seg | Autenticación, límites, secretos |
| `/package.json`, `/package-lock.json` | Web | Cadena de suministro |

**Repo de la app**

| Ruta | Propietario (rol) | Motivo |
|---|---|---|
| `/.github/workflows/`, `/ci/` | TI + líder móvil | Firma y secretos de tienda |
| `/android/`, `/ios/` | Móvil + Seg | Permisos, ATS/`networkSecurityConfig`, *entitlements*, enlaces |
| `/config/` | Móvil + Resp. técnico | Hosts y URL por *flavor* (solo valores públicos) |
| `/pubspec.yaml`, `/pubspec.lock` | Móvil | QG-M12 (plugin nativo nuevo = nota de decisión) |
| `/lib/core/session/`, `/lib/core/network/` | Móvil + Seg | Tokens, Keychain/Keystore |

### 5.3 Revisión de código

| Cambio | Revisión mínima | Evidencia |
|---|---|---|
| Cualquier PR | ≥ 1 aprobación independiente + puertas en verde | Rama protegida |
| `/mobile/v1`, `ipr/v1`, `.well-known`, CI, firma | Aprobación del **Resp. técnico** o de su delegado, **más** revisión de Seg para cambios de autenticación, tokens, checkout, secretos y logs | RNF-095, QG-M11, SC-050 |
| Plugin nativo o dependencia nueva (app) | Nota de decisión en el PR (necesidad, alternativas, publicador verificado, licencia, mantenimiento) | QG-M12, RNF-094 |
| Cambios que alteran el tráfico o datos recolectados | Aviso a Jurídico/Seg para actualizar Data safety y App Privacy **antes** de publicar | NL-07 |
| Cambios de Cloudflare | Exportar la configuración antes/después y adjuntarla al PR o ticket (la configuración de Cloudflare no está en Git: DESCONOCIDO) | C3, CH-11 |

Lista de verificación del revisor: la de la plantilla (sección 7). El revisor no aprueba si la lista tiene casillas sin responder.

### 5.4 Firma de commits (PROPUESTA DO-06)

| Aspecto | Propuesta | Notas |
|---|---|---|
| Qué firmar | Commits y **tags de versión** | Tags firmados identifican quién liberó. |
| Mecanismo | Firma con **clave SSH** (más sencilla de administrar que GPG para un equipo pequeño) o GPG si el equipo ya la usa | Elegir uno; NO VERIFICADO cuál soporta cada herramienta del equipo. |
| Aplicación | Fase 1: recomendada y verificada con alerta; Fase 2: requerida en `main` cuando todo el equipo la tenga | Hacerla obligatoria desde el día 1 bloquea fusiones (la documentación de GitHub advierte de que commits sin firmar en la rama del PR pueden bloquear la fusión, incluida la de squash). |
| Custodia | La clave personal nunca se comparte; se revoca al salir de la persona | Ver `deployment_guide.md` §4 (distinta de las claves de tienda). |

### 5.5 Higiene de secretos y dependencias en Git

| Control | Detalle | Estado |
|---|---|---|
| Escaneo de secretos | `gitleaks` (u otro) en cada PR **incluido el historial** y en *pre-commit* de estaciones (ST-020, ST-021). *Push protection* del proveedor: disponibilidad según plan NO VERIFICADA. | PROPUESTA |
| `.gitignore` de la app (propuesto desde el primer commit) | `*.jks`, `*.keystore`, `key.properties`, `*.p12`, `*.p8`, `*.cer`, `*.mobileprovision`, `*.pem`, `.env*` (excepto un `*.example`), `google-services*` por *flavor* si resultan contener claves de cuenta de servicio (la configuración cliente de Firebase no es secreta, pero no se versiona sin decisión), `/build`, `*.symbols` | PROPUESTA |
| Archivos de bloqueo | `pubspec.lock` y `package-lock.json` versionados; SDK de Flutter fijado (FVM o `.flutter-version`: NO VERIFICADO) | RNF-094, SC-051 |
| Actualizaciones | Dependabot o Renovate (también para acciones de GitHub), cadencia mensual | RNF-094; herramienta a elegir |
| Git LFS / binarios | Sin binarios de firma en ningún caso | — |

---

## 6. Gestión de tareas y registro de cambios

| Tema | Propuesta |
|---|---|
| Changelog | Generado desde Conventional Commits por versión (herramienta por elegir; no evaluada). Cada release de tienda tiene "novedades" redactadas por Producto. |
| Tabla de riesgos y decisiones | Las decisiones DO-xx de este documento y de los otros tres se trasladan a `project/decisiones_pendientes.md` por el responsable de documentación (no se editó aquí). |
| Retención | Los PR y logs de CI se conservan según política de GitHub vigente; evidencia de puertas de release se archiva fuera de Git (ver `ci_cd.md` §8). |

---

## 7. Plantilla de PR con lista de seguridad (PROPUESTA)

Archivo sugerido `.github/pull_request_template.md` (uno por repositorio; la variante de la app omite las casillas del BFF y viceversa).

```markdown
## Qué cambia y por qué
<!-- 2-4 líneas. Enlace a requisito/ticket (RF, RNF, FE-xx, WP-xx, CH-xx). -->

## Tipo
- [ ] feat  - [ ] fix  - [ ] refactor  - [ ] ci/build  - [ ] docs  - [ ] security  - [ ] deps

## Alcance afectado
- [ ] App  - [ ] BFF /mobile/v1  - [ ] Web existente  - [ ] WordPress (ipr/v1, snippets, plugin)  - [ ] Cloudflare/infra
- PR relacionado en el otro repositorio (si cambia contrato): <enlace>

## Pruebas
- [ ] Pruebas añadidas o actualizadas (qué casos TC/ST cubre): ...
- [ ] Las puertas de CI están en verde (no se ha omitido ninguna)
- [ ] Probado en staging / dispositivo (si aplica): <evidencia sin datos reales>

## Lista de seguridad (marcar o escribir "N/A" con motivo)
Secretos y datos
- [ ] No hay claves, tokens, contraseñas, certificados, IP de servidores ni valores de `.env` en el diff, en los commits, en fixtures ni en capturas
- [ ] No se registran en logs: Authorization, tokens, tickets, checkoutUrl, correos, teléfonos, cédula/NIT, direcciones, cuerpos de /auth, /me, /pqrs
- [ ] Los datos de prueba son sintéticos (dominio example.test, prefijo QA-); ninguno proviene de producción
App
- [ ] Sin secretos en `config/<flavor>.json` ni en `--dart-define` (solo valores públicos)
- [ ] Sin cambios en permisos de Android/iOS, componentes exportados, ATS/networkSecurityConfig o Associated Domains (si los hay: descritos y revisados por Seg)
- [ ] Tokens solo en Keychain/Keystore (refresh) y memoria (access); nada en preferencias, Hive ni logs
- [ ] URLs externas y deep links pasan por la lista cerrada (ExternalLauncher / deep_link_policy)
- [ ] Dependencia nueva: nota de decisión (necesidad, publicador, licencia, mantenimiento); plugin nativo nuevo marcado
BFF
- [ ] DTO por lista blanca; sin campos internos (stockQuantity, roles, username, metadatos crudos)
- [ ] Validación estricta (Zod strict), límites de tamaño, sin cookies ni CORS en /mobile/v1
- [ ] Autorización por objeto (pedido/checkoutRef solo del usuario autenticado) y token solo por cabecera
- [ ] Cache-Control explícito; ninguna respuesta privada es cacheable por Cloudflare
- [ ] openapi.yaml actualizado en este PR; sin cambios incompatibles en v1 (si los hay: es v2)
WordPress
- [ ] `permission_callback` real (nunca `__return_true` sin validación), `$wpdb->prepare`, escape de salida, nonces donde aplique
- [ ] Esquema de base de datos solo aditivo; versión de esquema incrementada; plan de reversa descrito
- [ ] Probado en staging antes de producción; copia de seguridad previa indicada
CI/CD e infraestructura
- [ ] Acciones de terceros fijadas por SHA; permisos mínimos del token (`permissions:` explícito)
- [ ] Sin interpolación de datos no confiables (título de PR, ramas) en scripts `run:`
- [ ] Cambios de Cloudflare/firewall: exportación de configuración adjunta

## Privacidad y tiendas
- [ ] No se recolectan datos nuevos, o Data safety / App Privacy / política de datos se actualizarán antes de publicar (avisar a Jurídico)

## Riesgo, despliegue y reversa
- Riesgo (bajo/medio/alto) y por qué: ...
- Interruptor remoto o `feature flag` disponible: sí/no
- Cómo se revierte (tag anterior, apagar flag, versión mínima): ...
```

---

## 8. Decisiones pendientes, supuestos y riesgos de este documento

### 8.1 Decisiones pendientes

| ID | Decisión | Recomendación | Quién decide | Bloquea |
|---|---|---|---|---|
| DO-01 | Repositorio propio para la app Flutter | Sí | Solicitante + Resp. técnico | Inicio de F2 (CI de la app) |
| DO-02 | Dónde se versiona `docs/` | Repo propio o dentro del repo de la app | Solicitante | Trazabilidad de la documentación |
| DO-03 | Plugin de WordPress: directorio en `ipr-frontend` o repo separado | Directorio en `ipr-frontend` | Resp. técnico + WP | Despliegue de `ipr/v1/m/*` |
| DO-04 | Trunk-based frente a GitFlow ligero | Trunk-based (reabrir si el equipo es grande) | Solicitante + líder móvil | Reglas de rama |
| DO-05 | Idioma de los commits | Uno solo por repositorio | Equipo | — |
| DO-06 | Firma de commits obligatoria | Recomendada ahora, obligatoria después | Seg + equipo | Protección de `main` |
| DO-07 | Plan de GitHub y organización | Confirmar que soporta reglas de 5.1 | Gerencia/TI | Rama protegida, entornos con revisores |

### 8.2 Supuestos

| ID | Supuesto | Cómo validarlo |
|---|---|---|
| SUP-DO-01 | Equipo pequeño (≤ ~6). | D-15 |
| SUP-DO-02 | `ipr-frontend` pertenece a una organización de GitHub que permite reglas de protección y entornos con revisores. | Consultar plan (DO-07) |
| SUP-H-12 | Se autoriza staging con Wompi sandbox (H-12) para activar `main` → staging y producción por tag. | H-12 |

### 8.3 Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| RD-01 | El plan de GitHub no permite revisiones obligatorias, *code owners* o entornos con revisores en repos privados. | Verificar antes (DO-07); compensar con *checks* propios o cambiar plan. |
| RD-02 | Equipo de una persona: no hay revisión independiente. | Revisor externo designado por IPR o aceptación de riesgo escrita. |
| RD-03 | Cada merge a `main` de `ipr-frontend` sigue yendo a producción hasta que exista staging (C2). | Puertas + aprobación del entorno; priorizar H-12. |
| RD-04 | Historial de Git con secretos no detectados. | ST-020 antes de abrir el repo al equipo móvil; rotar lo que aparezca. |
| RD-05 | Dependencia de ramas cortas sin *feature flags* maduros. | Interruptores en `/mobile/v1/config` desde el primer endpoint (RNF-029). |

*Fin del documento.*

# Integración y entrega continuas (CI/CD): app, BFF y WordPress

| | |
|---|---|
| **Proyecto** | App Flutter de IPR Partes y Repuestos (Inverprimos S.A.S.), BFF `/mobile/v1` en `ipr-frontend` y ampliación de WordPress |
| **Fase** | DEVSECOPS. **No se programa nada ni se tocan repositorios.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. **Ningún pipeline de este documento ha sido escrito en un repositorio ni ejecutado.** Los YAML son **ILUSTRATIVOS (ejemplo, no probado)**. Sin claves, tokens, certificados, IP ni valores de `.env`. |
| **Relacionados** | [`git_strategy.md`](git_strategy.md) · [`environments.md`](environments.md) · [`deployment_guide.md`](deployment_guide.md) · `03_architecture/deployment_architecture.md` (12c, 12d) · `06_security/security_controls.md` (SC-038..SC-051, CH-12, CH-13, NLS-01..NLS-09) · `06_security/security_testing.md` (ST-001..ST-024, ST-153) · `08_quality/testing_strategy.md` §7 · `08_quality/quality_metrics.md` §5 |

## 0. Convenciones

**HECHO**, **SUPUESTO** (`SUP-DO-xx`), **PROPUESTA**, **DECISIÓN PENDIENTE** (`DO-xx`), **RIESGO** (`RD-xx`), **DESCONOCIDO**, **NO VERIFICADO**. `SUP-H-nn` = supuesto basado en la recomendación H-nn **no aprobada** de `decisiones_pendientes.md` §E.

Regla del documento: **no se afirma que un pipeline funcione**. Todo lo que aquí se describe es diseño hasta que se ejecute y se archive evidencia (ST-006, ST-015, ST-153).

---

## 1. Hechos de partida

### 1.1 CI/CD actual (leído hoy en `.github/workflows/deploy.yml`, `package.json`, `.gitignore`)

| # | Hecho | Consecuencia |
|---|---|---|
| 1 | Un único workflow, `Deploy a producción`, con disparadores `push` a `main` (ignorando `**.md` y `docs/**`) y `workflow_dispatch`. | Cada fusión a `main` que no sea solo documentación va a producción. |
| 2 | **No hay** `tsc`, lint, `npm audit`, pruebas ni *build* de verificación; no hay `actions/checkout` ni `npm` en el archivo. | Sin puerta previa (RA-08, FE-11, QG-B01..B07). |
| 3 | El paso "Desplegar en el servidor" abre SSH como usuario `deploy` **sin comando explícito**: lo que se ejecuta en el servidor lo decide el servidor (por ejemplo un comando forzado de la clave) y **no está en el repositorio**. | DESCONOCIDO: qué hace el servidor (compilar, `npm install` o `npm ci`, reinicio, número de procesos). `deployment_architecture.md` 12a ya lo marca como DESCONOCIDO. |
| 4 | Para llegar al puerto 22 el workflow **abre el Cloud Firewall de DigitalOcean solo para la IP del runner** (obtenida de un servicio externo) y lo cierra al final con `if: always()`. Usa `digitalocean/action-doctl@v2` (por **tag**, no por SHA) y un token con permiso de escritura sobre firewalls. | Acción de tercero sin fijar; token con poder sobre el firewall guardado como secreto de repositorio; superficie de ataque temporal. |
| 5 | La **IP del servidor está escrita en claro en el propio workflow** (variable de comparación del primer paso). | Contradice CH-11 ("IP de origen fuera de archivos versionados"). **No se reproduce aquí.** |
| 6 | La comprobación final usa `curl -k` (no valida el certificado) con `--resolve` hacia el origen. | Verifica que el origen responde, no que el certificado sea válido. |
| 7 | Hay un paso "Diagnóstico de red" que imprime longitudes, resoluciones DNS e IP de salida del runner (`continue-on-error`). | Útil para depurar, pero escribe datos de infraestructura en los logs. |
| 8 | Bien hecho (se conserva): `permissions: contents: read`; `concurrency` sin cancelar despliegues en curso; `timeout-minutes: 30`; `StrictHostKeyChecking=yes` con `known_hosts` como secreto; clave SSH desde secreto; cierre del puerto 22 aunque falle. | Base reutilizable. |
| 9 | `package.json`: scripts `dev`, `build`, `start`, `lint` (`eslint`). **No** hay `typecheck` ni `test`. Existe `package-lock.json` (HECHO, `security_architecture.md` §8.5). | `tsc --noEmit` y las pruebas requieren añadir scripts (cambio de código en `ipr-frontend`, no hecho aquí). |

### 1.2 Sobre `npm install`

El encargo del proyecto menciona `npm install` como problema del flujo actual. **En `deploy.yml` no aparece `npm install` ni ningún comando de Node**; si el servidor ejecuta `npm install` en su comando de despliegue, **no es verificable desde el repositorio** (DESCONOCIDO). Lo correcto es: en CI usar `npm ci` (instala exactamente el *lockfile* y falla si no coincide con `package.json`) y, en el servidor, confirmar el comando real y cambiarlo a `npm ci --omit=dev` o equivalente si hoy usa `npm install` (RD-06). Acción: Web/TI documentan el comando remoto (DO-10).

### 1.3 Problemas del workflow actual y su remedio propuesto

| ID | Problema | Riesgo | Remedio (PROPUESTA) |
|---|---|---|---|
| P-01 | Despliegue sin verificación previa | Un cambio roto llega a producción; web y BFF comparten proceso (RA-08) | Pipeline `verify` obligatorio y `needs:` del despliegue (4.2) |
| P-02 | `digitalocean/action-doctl@v2` por tag | Un tag movible ejecuta código de tercero con el token del firewall (TM-051; ST-006) | Fijar por **SHA** de 40 caracteres verificado contra el repositorio oficial, o reemplazar por la CLI `doctl` descargada con versión y suma de verificación fijadas |
| P-03 | Token de DigitalOcean con escritura de firewalls guardado como secreto de **repositorio** | Quien pueda ejecutar un flujo puede abrir el firewall | Mover a **secretos del entorno** `production` con revisores; alcance mínimo del token (restringido al firewall o con *scopes* personalizados: capacidad NO VERIFICADA) |
| P-04 | Apertura temporal del puerto 22 | Ventana de exposición; depende de un servicio externo para conocer la IP del runner; las reglas tardan segundos en propagarse (`sleep`) | Corto plazo: conservar con endurecimiento (entorno aprobado, SSH solo con la clave y usuario restringidos, comando forzado). Mediano plazo: evaluar despliegue **sin puerto entrante** (DO-11): (a) el servidor *descarga* un artefacto firmado/verificado, (b) acceso SSH mediante un túnel de acceso de Cloudflare (plan: DESCONOCIDO), (c) *runner* efímero dentro de la red del proveedor. Cada una tiene riesgos propios (ver 4.4) |
| P-05 | IP de producción escrita en el repositorio | Facilita ataques directos al origen si no está restringido a Cloudflare (SA-03) | Sacarla del archivo (secreto del entorno o variable del entorno) y **rotar la exposición** restringiendo el firewall del origen a Cloudflare (CH-11). Quitar la comparación literal; validar solo formato |
| P-06 | `curl -k` | No detecta certificado inválido | Verificación TLS completa contra el dominio público (a través de Cloudflare) además de la comprobación directa; usar la CA del origen si es un certificado de origen de Cloudflare (DESCONOCIDO cuál se usa) |
| P-07 | Diagnóstico imprime datos de red | Información de infraestructura en logs | Mantenerlo solo en `workflow_dispatch` con `debug=true`, o quitarlo; nunca imprimir IP completas |
| P-08 | Se despliega en cada push a `main` | Sin pausa humana en producción | Entorno `production` con aprobación (SC-050); con staging, `main` → staging y tag `vX.Y.Z` → producción |
| P-09 | Sin reversa | Reversa ≤ 15 min exigida (RNF-030, QM-43) | Conservar el artefacto/versión anterior en el servidor y un paso de reversa manual aprobado (4.5) |
| P-10 | Un cambio de `wp-snippets/` redespliega la web | Despliegues innecesarios | Filtros de ruta (`paths`) por componente |
| P-11 | `workflow_dispatch` sin restricción de rama | Se puede desplegar cualquier rama a producción | Restringir el entorno `production` a `main`/tags protegidos |
| P-12 | Prueba de humo solo de `/` | No cubre BFF ni checkout | Humo ampliado (QG-B06, `/api/health`, un `GET /mobile/v1/config`) |

---

## 2. Elección de plataforma de CI (DO-08)

| Opción | Pro | Contra | Estado |
|---|---|---|---|
| **GitHub Actions** (recomendada) | `ipr-frontend` ya está en GitHub y usa Actions; sin proveedor nuevo ni cuenta adicional; entornos con revisores y secretos por entorno; ejecutores macOS para iOS; ecosistema amplio | Costo de minutos macOS (**NO VERIFICADO**: precio y multiplicador vigentes); acciones de terceros exigen fijar SHA; depende de GitHub | PROPUESTA (SUP-DO-03) |
| Codemagic / Bitrise (CI especializados para móvil) | Firma y distribución a tiendas gestionadas; ejecutores Flutter listos | Nuevo proveedor con acceso a claves de firma (más custodios y terceros); costo y condiciones **NO VERIFICADOS**; no se evaluaron | Descartada para el MVP por añadir un tercero con las claves; reabrir si el costo/mantenimiento de macOS es inviable |
| CI propio (Jenkins, runners autoalojados) | Control total | Mantenimiento; runner persistente comprometible (GitHub desaconseja autoalojados no efímeros) | Descartada |

Condiciones para que GitHub Actions siga siendo la opción: plan de GitHub que soporte entornos con revisores (DO-07) y disponibilidad de ejecutores macOS con **Xcode 26** (exigido por Apple, `deployment_guide.md` §6.1; disponibilidad en el ejecutor: NO VERIFICADA).

---

## 3. Controles transversales del CI

### 3.1 Acciones de terceros: fijadas

| Regla | Detalle | Justificación |
|---|---|---|
| Acciones de terceros por **SHA completo de 40 caracteres** (con la versión en comentario) | `uses: owner/action@<SHA-de-40-caracteres>  # vX.Y.Z`. El SHA se resuelve y verifica contra el repositorio **oficial** de la acción (no un *fork*) por una persona al fijarlo. Este documento **no** incluye SHA porque no se verificaron. | Guía de endurecimiento de GitHub: un tag puede moverse o borrarse (consultada 2026-11-18). ST-006 exige "sin acciones por tag". |
| Acciones de GitHub (`actions/*`) | También por SHA (recomendado) | Coherencia y reproducibilidad |
| Minimizar terceros | Preferir ejecutar herramientas (gitleaks, OSV-Scanner, `oasdiff`, `doctl`) **como binarios con versión y suma SHA-256 fijadas** en el propio workflow antes que acciones de terceros | Menos código de terceros con acceso a secretos |
| Actualización | Dependabot/Renovate propone el nuevo SHA; el PR pasa por CODEOWNERS de `.github/workflows/` | Evita acciones obsoletas sin perder el control |
| Verificación | Linter de workflows (por ejemplo `zizmor`, citado en ST-006, y `actionlint`): ejecutarlos en CI. Versiones y alcance: NO VERIFICADO | QG-D01 propuesta |

### 3.2 Mínimo privilegio en tokens y secretos

| Elemento | Regla | Estado |
|---|---|---|
| `GITHUB_TOKEN` | Predeterminado de repositorio y organización en **solo lectura**; cada workflow declara `permissions:` mínimo; escritura (`contents: write`, `id-token: write`, `attestations: write`) solo en el job que la necesite | PROPUESTA (en `deploy.yml` hoy ya hay `contents: read`) |
| Secretos por **entorno** (no de repositorio) | `production`, `staging`, `android-release`, `ios-release`, con revisores obligatorios distintos de quien lanza el flujo | PROPUESTA |
| PR desde forks | Sin secretos; **prohibido** `pull_request_target` salvo revisión de Seg | PROPUESTA |
| Datos no confiables | No interpolar `${{ github.event.* }}` (título de PR, nombre de rama) dentro de `run:`; pasarlos por variables de entorno y citar en el shell | Guía de GitHub (2026-11-18) |
| Token de DigitalOcean | Solo en el entorno `production`; alcance mínimo; rotación periódica; sustituir por mecanismo sin firewall (DO-11) | PROPUESTA; hoy secreto de repositorio (HECHO) |
| Clave SSH de despliegue | Clave de despliegue **dedicada**; en el servidor, usuario `deploy` sin *shell* general, con comando forzado y restricciones de `authorized_keys`; rotación documentada | PROPUESTA; configuración actual DESCONOCIDA |
| Cuenta de servicio de Google Play | Un solo propósito (publicar), restringida a la app, **permiso mínimo que permita subir a pistas de prueba**; la promoción a producción es manual (ver `deployment_guide.md`) | PROPUESTA |
| Clave de API de App Store Connect | Rol mínimo que permita subir *builds*; solo en el entorno `ios-release`; revocable (ver `deployment_guide.md` §4.3) | PROPUESTA; rol exacto NO VERIFICADO |
| Almacén de claves Android y certificado de Apple | **Nunca** en secretos del repositorio como solución definitiva: el origen es el gestor de secretos con ≥ 2 custodios; en GitHub solo se carga la copia operativa en el entorno protegido (SC-040) | PROPUESTA; gestor DESCONOCIDO (D-14) |
| Credenciales de nube de larga vida | Preferir OIDC (tokens de corta vida) cuando el proveedor lo permita (guía de GitHub); para Google Play/Apple/DigitalOcean: NO VERIFICADO | PROPUESTA |
| Logs | Revisar logs tras pruebas (ST-023); un secreto visible en un log: borrar el log y **rotar** | Guía de GitHub; SC-039 |
| *Runners* | Ejecutores alojados por GitHub, efímeros; **sin** *runners* autoalojados persistentes | PROPUESTA |

### 3.3 Cadena de suministro y artefactos

| Control | Detalle |
|---|---|
| Archivos de bloqueo | `npm ci` con `package-lock.json`; `flutter pub get` con `pubspec.lock` versionado y modo que falle si cambia (`--enforce-lockfile`; disponibilidad en Flutter 3.50: NO VERIFICADO) |
| SBOM | Generar por versión de app y de BFF (CycloneDX/Syft, ST-014) y archivarlo con el artefacto; licencias revisadas |
| Procedencia/atestación | Atestación de procedencia de artefactos de GitHub: disponibilidad en el plan: NO VERIFICADO; opcional |
| Suma SHA-256 | Cada AAB/IPA/artefacto se publica con su hash (evidencia ST-154, ST-022) |
| Retención | Los **símbolos de ofuscación** (`--split-debug-info`), el mapeo de R8 y los dSYM deben conservarse **durante toda la vida de cada versión publicada** para simbolizar fallos (RNF-097): se copian a un almacenamiento propiedad de IPR (DO-09); la retención por defecto de artefactos de CI no es suficiente (valor vigente NO VERIFICADO) |

---

## 4. Pipeline del BFF / `ipr-frontend`

### 4.1 Verificaciones previas (PR y `main`) — FE-11

| Paso | Comando (propuesta) | Puerta | Bloquea merge | Estado de la herramienta |
|---|---|---|---|---|
| Instalación reproducible | `npm ci` | — | Sí (falla si el *lockfile* no coincide) | `package-lock.json` existe (HECHO) |
| Tipos | `tsc --noEmit` (modo estricto); requiere añadir el script `typecheck` | QG-B01, RNF-088 | Sí | Script inexistente hoy (HECHO) |
| Lint | `npm run lint` (`eslint`, ya existe) | QG-B02 | Sí | HECHO (script) |
| Pruebas unitarias de `/mobile/v1` | Ejecutor por decidir (Vitest o Jest); cobertura ≥ 80 % del módulo | QG-B03, QM-03 | Sí | **Ejecutor NO VERIFICADO** frente a Next.js 16.3.4 y al Node de producción (Q-07, H-Q3) |
| Pruebas de contrato | 100 % de endpoints con caso feliz, error y autenticación contra `openapi.yaml`; Spectral para lint del OpenAPI; Schemathesis contra staging (nocturno) | QG-B04, QM-04 | Sí (contra fixtures); la ejecución contra staging es nocturna y de release | Existencia verificada; soporte OpenAPI 3.1 NO VERIFICADO (`testing_strategy.md` §6) |
| Compatibilidad del contrato | `oasdiff` entre el PR y `main`/último tag | QG-B05, QM-58 | Sí | OpenAPI 3.1: NO VERIFICADO |
| Humo de la web | Inicio, ficha, traspaso de checkout con WooCommerce simulado | QG-B06 | Sí | Por crear |
| SCA | `npm audit --omit=dev --audit-level=high` **y** OSV-Scanner sobre el *lockfile*; informe archivado | QG-B07, SC-048, ST-010, ST-011 | Sí con críticas/altas | **El primer `npm audit` aún no se ha ejecutado** (NLS-04) |
| Secretos | gitleaks sobre el historial completo en el PR (`fetch-depth: 0`) | SC-038, ST-020 | Sí | Por ejecutar (CH-13) |
| SAST | Semgrep con reglas TS/Node (SSRF, uso de `cookies()`/`next/headers` en `src/app/mobile/**`, falta de `Cache-Control`) | SC-049, ST-003 | Sí con altos/críticos | Reglas por definir |
| Build | `next build` en CI con variables **ficticias** | Verifica compilación | Sí | **DESCONOCIDO** si el *build* necesita claves reales de WooCommerce (ISR/generación estática); si las necesita, se usa un WooCommerce simulado o staging (RD-07) |
| Linter de workflows | `actionlint` + `zizmor` sobre `.github/workflows/` | ST-006, QG-D01 | Sí | NO VERIFICADO (versiones) |
| Trazabilidad OpenAPI | El PR que cambia un endpoint cambia `openapi.yaml` (QM-57) | RNF-096 | Sí | Script por crear |

### 4.2 Despliegue (después de las verificaciones)

| Aspecto | Propuesta |
|---|---|
| Estructura | `ci.yml` reutilizable (`workflow_call`) llamado por PR y por `deploy.yml`; `deploy` con `needs: verify` |
| Disparadores | Antes de staging (C2): `push` a `main` → verificar → **aprobación del entorno `production`** → desplegar. Con staging: `main` → desplegar en staging; tag `vX.Y.Z` → verificar → aprobación → producción |
| Entorno `production` | Revisores obligatorios (≠ quien disparó), secretos del entorno, solo ramas/tags protegidos |
| Concurrencia | Se conserva `cancel-in-progress: false` |
| Acciones | Fijadas por SHA (3.1) |
| Humo post-despliegue | `/api/health`; `GET /mobile/v1/config`; verificación TLS completa; lectura de catálogo; sin escrituras ni compras en producción (RNF-102) |
| Reversa | 4.5 |
| Qué no se despliega | Un cambio solo en `docs/**`, `wp-snippets/**`, `wordpress/**` no despliega Next.js |

### 4.3 Ejemplo ilustrativo — `ci.yml` de `ipr-frontend` (ejemplo, no probado)

```yaml
# EJEMPLO, NO PROBADO. Ilustra el orden y los controles; no es un archivo listo para usar.
# Todo <SHA-de-40-caracteres> debe resolverse y verificarse contra el repositorio oficial de la acción.
name: ci
on:
  pull_request:
  workflow_call:        # lo llama deploy.yml con `needs`
permissions:
  contents: read        # mínimo; ningún job pide más salvo que lo declare
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  verify:
    runs-on: ubuntu-24.04
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@<SHA-de-40-caracteres>   # vX.Y.Z
        with:
          fetch-depth: 0            # para escanear el historial completo
          persist-credentials: false
      - uses: actions/setup-node@<SHA-de-40-caracteres> # vX.Y.Z
        with:
          node-version-file: .nvmrc   # versión de Node = la de producción (DESCONOCIDA hoy)
          cache: npm
      - run: npm ci
      - run: npx tsc --noEmit                         # requiere script/tsconfig estricto (cambio de código)
      - run: npm run lint
      - run: npm test -- --coverage                   # script inexistente hoy; ejecutor por decidir
      - run: npm audit --omit=dev --audit-level=high  # bloquea críticas/altas
      # OSV-Scanner, gitleaks, Semgrep, oasdiff y Spectral: binarios con versión y suma SHA-256 fijadas
      # (no se escriben aquí porque no se verificaron versiones ni sumas).
      - run: npx next build
        env:
          # Valores FICTICIOS o servidor simulado; nunca secretos reales de WooCommerce en PR.
          NEXT_TELEMETRY_DISABLED: "1"
```

### 4.4 Alternativas al puerto 22 abierto (DO-11, DECISIÓN PENDIENTE)

| Opción | Cómo | Pro | Contra / riesgo | Estado |
|---|---|---|---|---|
| A. Mantener con endurecimiento | Entorno protegido; token del firewall de alcance mínimo; clave y usuario restringidos; IP fuera del repositorio | Cambio mínimo, ya probado en producción (HECHO que funciona hoy según el workflow actual) | Persiste la ventana de exposición y el token de firewall | **Recomendada a corto plazo** |
| B. Despliegue por *pull* | El servidor descarga una versión etiquetada y verifica su suma/firma | Sin puerto de entrada | Requiere agente en el servidor y gestión de claves de verificación; cambia el modelo de despliegue (lo decide el Resp. técnico) | NO EVALUADA |
| C. Acceso por túnel de Cloudflare | SSH a través de acceso de Cloudflare | Sin regla de firewall dinámica | Depende del plan (DESCONOCIDO, AP-08); credenciales de servicio en CI | NO EVALUADA; NO VERIFICADO |
| D. *Runner* efímero en la red del proveedor | Ejecutor dentro de la misma red | Sin exposición pública | Un runner comprometido tiene acceso a la red interna; operación más compleja | NO EVALUADA |

### 4.5 Reversa del BFF (RNF-030, QM-43: ≤ 15 min, ensayada una vez en staging)

| Elemento | Propuesta |
|---|---|
| Artefacto anterior | El servidor conserva la versión anterior desplegada (directorio de lanzamiento anterior o tag) hasta el siguiente despliegue exitoso: **DESCONOCIDO** si hoy es así; se confirma con el comando remoto (DO-10) |
| Disparo | `workflow_dispatch` con entrada "tag a restaurar", mismo entorno protegido y mismas verificaciones de humo |
| Datos | El BFF no tiene base de datos propia (`api_architecture.md` §3.3): la reversa no migra datos; los contadores en memoria se pierden en cada reinicio (R-NF-01, aceptado) |
| Contrato | `/mobile/v1` no se rompe: la reversa es segura con las apps instaladas siempre que el cambio revertido fuese compatible (QG-B05) |
| Complemento | Interruptores remotos (RNF-029, efecto ≤ 5 min) para apagar una función sin redesplegar |
| Evidencia | El ensayo de reversa se archiva (QG-R05/QM-43) |

---

## 5. Pipeline de WordPress (snippets y plugin `ipr/v1/m/*`)

Hoy los snippets se instalan copiando código en wp-admin; **no hay control de versiones desplegado verificable** (`security_architecture.md` §8.5). El mecanismo de publicación a staging y producción es **DESCONOCIDO**.

| Etapa | Contenido | Herramienta (sugerida; NO VERIFICADO salvo indicación) | Bloquea |
|---|---|---|---|
| Sintaxis | `php -l` con la versión de PHP del hosting (hoy PHP 8.3 según `INV` §2.1) | PHP CLI | Merge |
| Estándar y seguridad | PHPCS con WordPress Coding Standards (*sniffs* de seguridad: escape, nonces, `$wpdb->prepare`) | PHPCS + WPCS | Merge: 0 hallazgos altos en `ipr/v1/m/*`; heredados con plan (ST-004, CH-25) |
| SAST | Semgrep con reglas PHP; búsqueda de `__return_true` en `permission_callback` | Semgrep | Merge |
| Pruebas | Opción 1: PHPUnit con entorno de pruebas de WordPress; opción 2 (mínimo viable): **pruebas HTTP contra staging** (BE-13..BE-19) | PHPUnit o pruebas HTTP | Release (staging) |
| Inventario de plugins | Versiones de WordPress, WooCommerce, Wompi, Wordfence y demás en **staging**; contraste con avisos públicos; no escanear producción | WP-CLI (`wp plugin list`) y base de avisos | Release (ST-013) |
| Secretos | `IPR_HANDOFF_SECRET` e `IPR_BFF_SECRET` solo como constantes de `wp-config.php` (la opción de BD no debe existir) | Revisión de configuración (ST-024) | Release (CH-26) |
| Despliegue a staging | **DESCONOCIDO**. Propuesta: mu-plugin versionado copiado por un usuario de despliegue **restringido al directorio del plugin** (SFTP/rsync o mecanismo Git del panel de hosting: NO VERIFICADO) | — | — |
| Promoción a producción | Manual y aprobada: copia de seguridad de BD previa, `dbDelta` versionado, ventana acordada, humo de login web y checkout | Aprobación (entorno) | Release |
| Reversa | Volver a la versión anterior del plugin; el esquema es **aditivo** (no se borran columnas durante un ciclo). Un interruptor `IPR_MOBILE_DISABLED` (propuesta) que apague `ipr/v1/m/*` sin desinstalar | Ver `deployment_guide.md` §9 | — |
| Regresión de la web | Los cambios en snippets compartidos (cookie del handoff, direcciones, formato del ticket) exigen pruebas de regresión de la web **antes** de la app (`resolucion_inconsistencias.md`, hallazgo 3) | Pruebas manuales/automáticas en staging | Release |

Cambios en WordPress **no** se despliegan a producción sin staging (ADR-001 C2). Si no existe staging, el cambio se bloquea (NLS-08).

---

## 6. Pipelines de la app Flutter

### 6.1 Etapas (alineadas con `flutter_app_architecture.md` §16 y `testing_strategy.md` §7.5)

| # | Etapa | Contenido | Cuándo |
|---|---|---|---|
| 1 | Formato | `dart format --output=none --set-exit-if-changed .` | Cada PR |
| 2 | Análisis | `flutter analyze` con `very_good_analysis`; reglas personalizadas (`custom_lint`) que prohíben `print`/`debugPrint` en *release*, `badCertificateCallback`, `webview_flutter`, `shared_preferences` para datos sensibles (ST-001) | Cada PR |
| 3 | Reglas de dependencia | Script que falla ante violaciones D1–D6 (ST-002, QG-M03) | Cada PR |
| 4 | Pruebas y cobertura | `flutter test --coverage`: unitarias, widget, golden (`alchemist`), integración ligera; script de umbral por módulo (≥ 70 % global, ≥ 90 % en críticos; no se permite bajar) | Cada PR |
| 5 | Contrato (lado app) | Los *fixtures* JSON validan contra la copia fijada del `openapi.yaml` (QG-M06) | Cada PR |
| 6 | Accesibilidad | Guías de `flutter_test` en pantallas críticas (QG-M07) | Cada PR |
| 7 | Trazabilidad | AC → TC → prueba (QG-M08) | Cada PR |
| 8 | Seguridad | gitleaks (historial), OSV-Scanner sobre `pubspec.lock`, SBOM, `dart pub outdated` informativo (QG-M09, ST-012, ST-014, ST-021) | Cada PR |
| 9 | Compilación | Android (APK/AAB de depuración, *flavor* `dev`) e iOS sin firma (QG-M10) | Cada PR |
| 10 | Integración en emulador | Reinicio, modo avión, enlace profundo | PR a `main` y nocturno |
| 11 | E2E | Compra completa contra **staging** con Wompi sandbox (`patrol`, condicionado a SPK-01) | Nocturno y por candidato; **bloqueado si no existe staging** (NLS-08) |
| 12 | Build de release firmado | AAB e IPA por *flavor*, `--obfuscate --split-debug-info`, desde CI con secretos del entorno | Tag `vX.Y.Z` |
| 13 | Análisis del binario | Búsqueda de secretos y MASVS L1 sobre el *build* de release (ST-022, ST-123) | Candidato a release |
| 14 | SBOM y artefactos | AAB/IPA, símbolos, mapeo R8, dSYM, SBOM, informes, hashes | Tag |

Notas de verificación (NO VERIFICADO): el paso `flutter pub get --enforce-lockfile`; las acciones concretas de instalación de Flutter y de cobertura (`very_good_coverage` y la herramienta `lcov` figuran como NO VERIFICADAS en `testing_strategy.md` §6); Semgrep para Dart (el soporte no se evaluó; la SAST de Dart descansa en `flutter analyze` + `custom_lint`); la ejecución de `patrol` con el navegador seguro (SPK-01); el costo y la disponibilidad de ejecutores macOS con Xcode 26.

### 6.2 Reglas específicas de la app

| Regla | Detalle |
|---|---|
| Qué firma qué | Las PR **nunca** reciben secretos de firma. Los builds de PR son de depuración, *flavor* `dev`, sin firma de tienda. La firma ocurre solo en el flujo de release, en entornos protegidos, ejecutado desde un tag firmado en `main` |
| Configuración | `--dart-define-from-file=config/<flavor>.json` con **solo valores públicos** (ADR-009); un *check* falla si el JSON contiene claves con nombres como `secret`, `token`, `key` o `password` (script propio) |
| Un *build* por *flavor* | `dev`, `staging`, `prod` con identificadores distintos; el *build* `prod` solo sale del tag y con apuntador a producción (evita el riesgo de apuntar a producción desde pruebas) |
| Reproducibilidad | Flutter fijado (FVM o `.flutter-version`: NO VERIFICADO), `pubspec.lock` versionado |
| Ofuscación | `--obfuscate --split-debug-info=<dir>`; el directorio de símbolos se archiva y **no** se incluye en el binario (RNF-051) |
| Número de *build* | Entero creciente asignado por el flujo de release (`git_strategy.md` §4.2) |
| Salida | Artefacto firmado + hash + SBOM + símbolos. La **subida a pistas de prueba** puede automatizarse (Play pista interna / TestFlight); **la promoción a producción es manual** en la consola (compuerta humana) |
| Costo de iOS | QG-M10 exige compilar iOS en cada PR; el ejecutor macOS es más caro y lento que Linux (**NO VERIFICADO** el costo). Alternativa (requiere aprobación de QA/TI porque cambia QG-M10): compilar iOS en PR solo si cambian `ios/`, `pubspec.*` o código nativo, y siempre en `main` y de noche |

### 6.3 Ejemplo ilustrativo — CI de la app (ejemplo, no probado)

```yaml
# EJEMPLO, NO PROBADO. Repositorio de la app Flutter.
name: app-ci
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
concurrency:
  group: app-ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  static-and-tests:
    runs-on: ubuntu-24.04
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@<SHA-de-40-caracteres>   # vX.Y.Z
        with: { fetch-depth: 0, persist-credentials: false }
      # Instalación de Flutter con la versión fijada del repositorio (acción o binario verificado: NO VERIFICADO).
      - run: flutter pub get --enforce-lockfile          # NO VERIFICADO en Flutter 3.50
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze --fatal-infos
      - run: dart run ci/check_layer_rules.dart          # script propio (QG-M03), por crear
      - run: flutter test --coverage
      - run: dart run ci/check_coverage.dart             # umbral por módulo sobre lcov, por crear
      - run: dart run ci/check_contract_fixtures.dart    # valida fixtures contra contract/openapi.yaml, por crear
      - run: dart run ci/check_public_config.dart        # falla si config/*.json tiene claves sospechosas
  security:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<SHA-de-40-caracteres>   # vX.Y.Z
        with: { fetch-depth: 0, persist-credentials: false }
      # gitleaks (historial), OSV-Scanner sobre pubspec.lock y SBOM: binarios con versión y suma fijadas.
  build-android-debug:
    needs: static-and-tests
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<SHA-de-40-caracteres>   # vX.Y.Z
      - run: flutter build apk --debug --flavor dev --dart-define-from-file=config/dev.json
  build-ios-nosign:
    needs: static-and-tests
    runs-on: macos-<versión-con-Xcode-26>                # NO VERIFICADO: etiqueta e imagen vigentes
    steps:
      - uses: actions/checkout@<SHA-de-40-caracteres>   # vX.Y.Z
      - run: flutter build ios --no-codesign --flavor dev --dart-define-from-file=config/dev.json
```

### 6.4 Ejemplo ilustrativo — release de la app (ejemplo, no probado)

```yaml
# EJEMPLO, NO PROBADO. Se dispara solo con tag firmado; las firmas viven en entornos protegidos.
name: app-release
on:
  push:
    tags: ["v*"]
permissions:
  contents: read
jobs:
  android:
    runs-on: ubuntu-24.04
    environment: android-release          # revisores obligatorios, secretos del entorno
    steps:
      - uses: actions/checkout@<SHA-de-40-caracteres>   # vX.Y.Z
        with: { persist-credentials: false }
      - name: Preparar clave de subida (temporal)
        env:
          UPLOAD_KEYSTORE_B64: ${{ secrets.ANDROID_UPLOAD_KEYSTORE_B64 }}   # nombre de secreto; valor en el entorno
        run: |
          printf '%s' "$UPLOAD_KEYSTORE_B64" | base64 -d > "$RUNNER_TEMP/upload.keystore"
          # contraseñas por variables del entorno hacia key.properties temporal; nunca se imprimen ni se versionan
      - run: >
          flutter build appbundle --release --flavor prod
          --dart-define-from-file=config/prod.json
          --obfuscate --split-debug-info=build/symbols
          --build-number=${{ github.run_number }}
      - name: Borrar clave temporal
        if: always()
        run: shred -u "$RUNNER_TEMP/upload.keystore" || rm -f "$RUNNER_TEMP/upload.keystore"
      # Subir AAB, símbolos, mapeo R8, SBOM y hash como artefactos; copiar los símbolos al almacén de IPR.
      # Subida a la pista INTERNA de Google Play con cuenta de servicio de permiso mínimo (herramienta por elegir).
  ios:
    runs-on: macos-<versión-con-Xcode-26>   # NO VERIFICADO
    environment: ios-release
    steps:
      - uses: actions/checkout@<SHA-de-40-caracteres>   # vX.Y.Z
        with: { persist-credentials: false }
      # Firma: opción A, clave de API de App Store Connect con firma administrada en la nube; opción B, certificado
      # y perfil importados a un llavero temporal. Ver deployment_guide.md §4.3 (decisión DO-12).
      - run: >
          flutter build ipa --release --flavor prod
          --dart-define-from-file=config/prod.json
          --obfuscate --split-debug-info=build/symbols
          --build-number=${{ github.run_number }}
      # Subida a TestFlight (herramienta de subida vigente: NO VERIFICADO); archivar dSYM, SBOM y hash.
```

---

## 7. Puertas de calidad: qué bloquea un merge y qué bloquea un release

Las puertas no se redefinen aquí: se **referencian** las de `08_quality/testing_strategy.md` §7 y `06_security/security_controls.md` §3–§4 (las pruebas de seguridad las define Seguridad; QA las exige como *checks* requeridos, §7.4 de la estrategia). Las puertas `QG-D**` son propuestas **adicionales de DevOps**.

### 7.1 Qué bloquea un merge (comprobaciones requeridas en la rama protegida)

| Repo | Puerta | Regla | Origen / NL relacionado |
|---|---|---|---|
| App | QG-M01 formato | 0 diferencias | RNF-087 |
| App | QG-M02 `flutter analyze` + `very_good_analysis` | 0 errores y 0 advertencias | RNF-087, ST-001 |
| App | QG-M03 reglas de dependencia | 0 violaciones | ADR-003, ST-002 |
| App | QG-M04 pruebas | 100 % en verde | RNF-093 |
| App | QG-M05 cobertura | ≥ 70 % global; ≥ 90 % en críticos; no baja | RNF-089 (valores propuestos por la práctica habitual, sin medición) |
| App | QG-M06 contrato lado app | *Fixtures* válidos | RNF-085, 090 |
| App | QG-M07 accesibilidad automática | 0 incumplimientos en pantallas críticas | RNF-069..073 |
| App | QG-M08 trazabilidad | 0 casos huérfanos | `testing_strategy.md` §4.2 |
| App y BFF | **QG-M09 / QG-B07 seguridad estática** | Secretos (0), OSV/`npm audit` sin críticas ni altas, SBOM; **falla con crítica o alta** | NL-01, NL-03, NLS-01, NLS-04, SC-048 |
| App | QG-M10 compilación Android e iOS | Ambas compilan | RNF-093 |
| Ambos | QG-M11 revisión | ≥ 1 aprobación independiente; `/mobile/v1`, `ipr/v1`, firma y CI por el Resp. técnico | RNF-095, SC-050 |
| App | QG-M12 dependencias | Plugin nativo nuevo = nota de decisión | RNF-094 |
| BFF | QG-B01 `tsc --noEmit` | 0 errores | RNF-088 |
| BFF | QG-B02 ESLint | 0 errores | RNF-088 |
| BFF | QG-B03 pruebas de `/mobile/v1` | ≥ 80 % de líneas del módulo | RNF-090 |
| BFF | QG-B04 contrato | 100 % de endpoints (feliz, error, autenticación) | RNF-090 |
| BFF | QG-B05 compatibilidad | 0 cambios incompatibles en `v1` | RNF-085 |
| BFF | QG-B06 humo de la web | Inicio, ficha y traspaso siguen funcionando | RA-08 |
| BFF | SAST (ST-003) | 0 altos/críticos sin justificación | SC-049 |
| WP | SAST PHP (ST-004) y `php -l` | 0 hallazgos altos en `ipr/v1/m/*` | SC-049 |
| CI (**propuesta**) | **QG-D01** linter de workflows | Sin acciones por tag, sin inyección, permisos mínimos declarados | ST-006, SC-050 |
| CI (**propuesta**) | **QG-D02** configuración pública | Ningún secreto en `config/*.json` ni `--dart-define` | SC-038 |

Las puertas de **merge no admiten excepciones** salvo aceptación formal y escrita para los criterios condicionales NL-C (`testing_strategy.md` §7, principio 4).

### 7.2 Qué bloquea un release (candidato a piloto o a tiendas)

Un *release candidate* se promueve **solo si todas las puertas absolutas están en verde con evidencia** archivada (QG-R, NL, NLS y CH P0).

| Puerta | Evidencia exigida | Criterio de no-lanzamiento |
|---|---|---|
| QG-R01 regresión P1 completa (integración y E2E) | 100 % de P1 en verde en el RC | NL-Q1 |
| QG-R02 compra de extremo a extremo (aprobado, rechazado, cancelado) en **Android e iOS** con Wompi sandbox | Resultados con evidencia | NL-02, NL-Q5 |
| QG-R03 cero duplicados | 0 pedidos o cobros duplicados | NL-02, NLS-06, CH-16 |
| QG-R04 sesiones y límites | Sesión por dispositivo, renovación, revocación, límite persistente | NL-05, CH-01, CH-02 |
| QG-R05 contrato y capacidad | 100 % de endpoints; carga sin degradar la web | NL-12, NL-C3 |
| QG-R06 matriz de dispositivos | Humo en la matriz completa | RNF-082 |
| QG-R07 rendimiento | Arranque en frío < 5 s duro | NL-C1 |
| QG-R08 accesibilidad | Login, compra y eliminar cuenta con TalkBack/VoiceOver y texto al 200 % | NL-14 |
| QG-R09 calidad de datos | 0 comprables con precio ≤ 0, 0 "$0", 0 no publicados | NL-13 |
| QG-R10 privacidad | Consentimiento, eliminación E2E, política revisada por Jurídico | NL-07 |
| QG-R11 seguridad | Evidencia de `security_testing.md` para NL-01, 03, 04, 06, 08, 10 | NL-01..10, NLS-01..NLS-09 |
| QG-R12 defectos | 0 S1; 0 S2 sin aceptación formal | NL-Q2 |
| QG-R13 contenido aprobado | Textos legales/garantía/estimación aprobados | NL-07 |
| QG-R14 estabilidad (piloto → producción) | ≥ 99,5 % de usuarios sin fallos y ANR ≤ 0,3 % | NL-C2 |
| QG-R15 condiciones de ADR-001 | C1 a C4 cumplidas (conformidad del Resp. técnico, staging, Cloudflare, carga) | NL-12 |
| **Cambios P0 de seguridad CH-01..CH-22** | Cada uno con su criterio de cierre evidenciado | NLS-02 |
| Pruebas ST con riesgo residual | Sin riesgo residual Alto/Crítico ni controles con prueba "Pendiente" o "Fallida" | NLS-03 |
| Staging existente con Wompi sandbox | Existe y se usó | NLS-08 |
| Custodia de firmas y titularidad de cuentas de tienda | Lista de verificación de F4 (ST-154) | NL-11, CH-20 |
| Aceptaciones de riesgo firmadas (sin *pinning*, sin detección de root, sin atestación, verificación de correo) | Documento firmado por Seg y Gerencia | NLS-09, CH-22 |
| Prueba de penetración independiente con reprueba | 0 críticos/altos abiertos | NL-01, CH-21 |
| Monitoreo, alertas y reporte de fallos activos | Configuración verificada | NL-09 |
| **QG-D03 (propuesta)** integridad del artefacto | AAB/IPA publicado = el construido por el tag (hash coincide); símbolos archivados | RNF-097, SC-041 |
| **QG-D04 (propuesta)** reversa ensayada | Reversa del BFF ≤ 15 min ensayada en staging; interruptor remoto ≤ 5 min | QM-43, QM-44, RNF-029/030 |
| **QG-D05 (propuesta)** requisitos vigentes de tienda | `targetSdk` y Xcode exigidos cumplidos; Data safety y App Privacy coherentes con el tráfico real | RNF-080, NL-07, `deployment_guide.md` |
| **QG-D06 (propuesta)** análisis del *build* de release | Sin secretos en el binario; MASVS L1 evaluado | NL-03, NL-10, ST-022, ST-123 |

Los **criterios condicionales** (NL-C, NLS-C1..C4) solo se aceptan con **aceptación formal y por escrito** de IPR (Gerencia + TI), con plan y fecha. Los absolutos **no tienen excepción**.

### 7.3 Evidencia

| Evidencia | Dónde se archiva |
|---|---|
| Resultados de CI de cada PR | Historial de GitHub (referencia, no copia) |
| Informes de SCA, secretos, SBOM, hashes y símbolos por versión | Almacén de IPR (DO-09), referenciados desde `08_quality/test_results.md` |
| Capturas de configuración de protección de ramas, Cloudflare y firewall | Archivo de evidencia con valores enmascarados (ST-153, ST-151, ST-150) |
| Acta de aceptaciones de riesgo | Documento firmado (CH-22) |

---

## 8. Ejecuciones nocturnas y verificaciones programadas

| Qué | Frecuencia | Prerrequisito |
|---|---|---|
| E2E de compra en staging, enlaces legales, árbol de categorías | Cada noche | Staging con Wompi sandbox (bloqueado si no existe, NLS-08) |
| Contrato del BFF contra staging (Schemathesis u otro) | Cada noche | Staging |
| SCA programado (aunque no haya PR) | Semanal | — (nuevas CVE aparecen sin cambios de código) |
| Actualizaciones de dependencias y acciones | Mensual (RNF-094) | Dependabot/Renovate |
| Monitoreo sintético de producción de solo lectura | ≤ 5 min (RNF-102) | Herramienta DESCONOCIDA |

---

## 9. Decisiones pendientes, supuestos, riesgos y no verificado

### 9.1 Decisiones pendientes

| ID | Decisión | Recomendación | Quién decide | Bloquea |
|---|---|---|---|---|
| DO-08 | Plataforma de CI de la app | GitHub Actions | Solicitante + TI | Pipeline de la app |
| DO-09 | Almacén duradero de símbolos, SBOM e informes | Almacenamiento propiedad de IPR | TI | RNF-097 |
| DO-10 | Documentar el comando remoto de despliegue y la versión de Node en producción; `npm ci` | Sí | Web/TI | FE-11, reversa |
| DO-11 | Qué hacer con el puerto 22 abierto | Corto plazo A; evaluar B/C/D | Resp. técnico + TI | CH-11, SC-050 |
| DO-12 | Firma de iOS: administrada en la nube o certificado importado | Evaluar la administrada en la nube (menos material de firma custodiado); NO VERIFICADO | TI + Móvil | Release iOS |
| DO-13 | Ejecutor de pruebas del BFF (Vitest/Jest) | Decidir tras SPK frente a Next 16.3.4 y Node de producción | Web | QG-B03 |
| DO-14 | Compilar iOS en cada PR o filtrado por rutas | Filtrado + `main` + nocturno | QA + TI | Costo de CI |

### 9.2 Supuestos

| ID | Supuesto |
|---|---|
| SUP-DO-03 | GitHub Actions es la plataforma de CI (el repositorio ya está en GitHub). |
| SUP-DO-04 | El plan de GitHub permite entornos con revisores y *code owners* en repos privados (DO-07). |
| SUP-H-12 | Staging con Wompi sandbox será autorizado; sin ello, E2E, nocturnos y la promoción por tag quedan bloqueados (NLS-08). |
| SUP-DO-05 | El *build* de Next.js puede ejecutarse con valores ficticios o un WooCommerce simulado (DESCONOCIDO, RD-07). |

### 9.3 Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| RD-06 | El servidor ejecuta `npm install` en lugar de `npm ci` (DESCONOCIDO) | Confirmar y corregir (DO-10) |
| RD-07 | `next build` necesita secretos reales de WooCommerce | Servidor simulado o staging en CI; nunca secretos de producción en PR |
| RD-08 | Coste y tiempo de macOS en CI | Filtros por ruta (DO-14); medir |
| RD-09 | Un PR malicioso o comprometido modifica un workflow | CODEOWNERS de `.github/workflows/`, entornos con revisores, `pull_request` sin secretos |
| RD-10 | Herramientas de CI con versiones nuevas incompatibles (Flutter 3.50, Xcode 26, Next 16.3.4) | Pruebas de humo de la cadena en F1/F2 (SPK-02) antes de depender de ellas |
| RD-11 | La IP del servidor sigue expuesta en el historial de Git aunque se quite del archivo | La restricción del origen a Cloudflare (CH-11) es la mitigación real; reescribir historial no es recomendable |

### 9.4 NO VERIFICADO en este documento

Precio y multiplicador de minutos macOS; imagen de ejecutor con Xcode 26; `--enforce-lockfile` en Flutter 3.50; Semgrep para Dart; ejecutor de pruebas del BFF frente a Next 16.3.4; `oasdiff`/Schemathesis con OpenAPI 3.1; atestación de procedencia en el plan de GitHub; alcance de *scopes* del token de DigitalOcean; rol mínimo de la clave de App Store Connect; OIDC con Google Play/Apple; versión y suma de las herramientas de seguridad; mecanismo de despliegue de WordPress (Plesk).

*Fin del documento.*

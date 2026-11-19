# Entornos, configuración, secretos y accesos

| | |
|---|---|
| **Proyecto** | App Flutter de IPR Partes y Repuestos (Inverprimos S.A.S.), BFF `/mobile/v1` y WordPress/WooCommerce |
| **Fase** | DEVSECOPS. **No se programa nada ni se tocan repositorios ni servidores.** |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. Nada de lo descrito como "propuesto" existe hoy. **No incluye IP, dominios internos, claves, tokens ni valores de `.env`.** |
| **Relacionados** | [`git_strategy.md`](git_strategy.md) · [`ci_cd.md`](ci_cd.md) · [`deployment_guide.md`](deployment_guide.md) · `03_architecture/deployment_architecture.md` (12a, 12b, 12e) · `03_architecture/flutter_app_architecture.md` §16 (ADR-009) · ADR-001 condiciones C1–C4 · `06_security/security_controls.md` (SC-038..SC-040, SC-053, SC-067) · `08_quality/testing_strategy.md` §5 |

## 0. Convenciones

**HECHO**, **SUPUESTO** (`SUP-DO-xx`), **PROPUESTA**, **DECISIÓN PENDIENTE** (`DO-xx`), **RIESGO** (`RD-xx`), **DESCONOCIDO**, **NO VERIFICADO**. `SUP-H-nn` = supuesto basado en la recomendación H-nn **no aprobada** (`decisiones_pendientes.md` §E).

---

## 1. Hechos y desconocidos de partida

| # | Dato | Estado | Fuente |
|---|---|---|---|
| 1 | Producción existe: Cloudflare (CDN y WAF) → Next.js 16 en servidor propio (DigitalOcean) → WordPress/WooCommerce en hosting con Plesk (PHP 8.3) → Wompi dentro del checkout de WooCommerce. | HECHO | `deployment_architecture.md` 12a |
| 2 | **No existe evidencia de staging** (ni frontend, ni WordPress, ni Wompi sandbox). | **DESCONOCIDO** (C2 de ADR-001; DA-13; NLS-08) | `informe_codigo_frontend.md` §8; `testing_strategy.md` §5.1 |
| 3 | Dominios de staging y de sus archivos `.well-known`. | DESCONOCIDO (IN-16, CR-076) | `flutter_app_architecture.md` §6.2; `resolucion_inconsistencias.md` CR-076 |
| 4 | Plan de Cloudflare, reglas existentes y si el origen solo acepta tráfico de Cloudflare. | DESCONOCIDO (AP-08, SA-03) | `deployment_architecture.md` 12a |
| 5 | Número de procesos Node en producción, contenedor y comando remoto de despliegue. | DESCONOCIDO (SA-01) | idem |
| 6 | Gestor de secretos corporativo; titular de cuentas de tienda; identificador definitivo de la app (`co.ipr.app` PENDIENTE). | DESCONOCIDO (D-14, DA-12) | `flutter_app_architecture.md` §16 |
| 7 | La app **no contiene secretos**; configuración pública por `--dart-define-from-file` (ADR-009, propuesta no aprobada). | PROPUESTA (RNF-036) | `architecture_overview.md` ADR-009 |
| 8 | Las únicas decisiones aprobadas son ADR-001 y ADR-002; ADR-003..ADR-022 están en estado **Propuesta**. | HECHO | `architecture_decisions.md` |
| 9 | Hoy el workflow tiene secretos de repositorio con estos **nombres** (sin valores): `DIGITALOCEAN_ACCESS_TOKEN`, `DO_FIREWALL_ID`, `DEPLOY_HOST`, `DEPLOY_SSH_KEY_B64`, `DEPLOY_KNOWN_HOSTS`. | HECHO (leído en `deploy.yml`) | — |

---

## 2. Mapa de entornos

| Entorno | Para qué | App (flavor) | BFF | WordPress/WooCommerce | Wompi | Cloudflare | Estado |
|---|---|---|---|---|---|---|---|
| **Local / dev** | Desarrollo, unitarias, widget, golden, integración ligera con BFF simulado | `dev` (`co.ipr.app.dev`) | Local o simulado (DESCONOCIDO si existe uno de desarrollo compartido) | Ninguno (se simula) o instancia local con datos sintéticos | Ninguno | No aplica | PROPUESTA (ADR-009) |
| **CI** | Todas las puertas de merge | `dev` (compilaciones de depuración) | Simulado | Simulado | Ninguno | No aplica | PROPUESTA |
| **Staging** | Contrato contra servidor, E2E de compra, seguridad dinámica, carga, reversa, ensayo de incidentes | `staging` (`co.ipr.app.staging`) | `/mobile/v1` desplegado en un Next.js de staging | WordPress y WooCommerce de staging con el plugin `ipr/v1/m/*` y datos sintéticos | **Sandbox** de Wompi | Hostnames propios de staging, mismas reglas que producción cuando sea posible | **DESCONOCIDO** (C2). Sin staging: pruebas dinámicas **bloqueadas** (NLS-08) |
| **Piloto / beta** | Estabilidad y rendimiento reales con usuarios reales acotados | `prod` en pista cerrada/TestFlight externo | Producción | Producción | Producción | Producción | F5 (`testing_strategy.md` §9) |
| **Producción** | Usuarios finales | `prod` (`co.ipr.app`, PENDIENTE) | Producción (`/mobile/v1` en el mismo Next.js: **aún no existe**) | Producción | Wompi producción | Producción | Existe (web); BFF y app **por crear** |

Regla: **no hay pruebas de escritura ni de compra en producción**; solo monitoreo sintético de solo lectura y login con cuenta de prueba dedicada y autorizada (RNF-102, `testing_strategy.md` §5.1).

### 2.1 Qué hacer mientras staging no exista

| Situación | Consecuencia | Acción propuesta |
|---|---|---|
| Staging no confirmado | No se pueden ejecutar E2E de compra, sesiones por dispositivo, doble pago ni carga (NLS-08, NL-12) | Priorizar **H-12** (autorizar staging con Wompi sandbox y acceso de solo lectura al servidor para resolver los DESCONOCIDOS). Hasta entonces no se libera nada que toque autenticación, checkout o WordPress. |
| Construir staging | Propuesta mínima: (1) segunda instancia de Next.js (otro proceso/servidor), (2) WordPress/WooCommerce de staging (instancia o subdominio del hosting de Plesk: DESCONOCIDO si el plan lo permite), (3) Wompi sandbox con sus claves de prueba, (4) hostnames propios | Costo y plazo: **DESCONOCIDOS** (D-15). Decide: Gerencia + TI + Resp. técnico (DO-15). |
| Alternativa "staging local" | Entorno efímero con contenedores (WordPress/WooCommerce con datos sintéticos + Next.js) para el desarrollo y las pruebas de contrato | No sustituye a staging con Wompi sandbox ni con Cloudflare: **no basta** para NLS-08 |

---

## 3. Configuración por entorno (app)

### 3.1 `--dart-define-from-file` (ADR-009, propuesta)

| Campo en `config/<flavor>.json` | ¿Público? | `dev` | `staging` | `prod` |
|---|---|---|---|---|
| `apiBaseUrl` | Sí (URL base del BFF) | URL del BFF local/dev (DESCONOCIDA) | URL del BFF de staging (DESCONOCIDA) | URL del BFF de producción |
| `environment` | Sí | `dev` | `staging` | `prod` |
| `deepLinkHost` | Sí | Host propio (DESCONOCIDO) | Host de staging (DESCONOCIDO) | Dominio público de la web (ruta `/app/*`; **IN-01**: ruta de retorno por aprobar) |
| `checkoutAllowedHosts` | Sí (lista cerrada; el servidor también la entrega, `allowedHosts`) | Hosts de dev | Hosts de staging | Hosts de producción |
| `supportWhatsApp` | Sí (dato público de la web) | Número ficticio | Número ficticio | Número oficial |
| Cualquier clave, token, contraseña, usuario | **NO** | — | — | — |

Reglas (PROPUESTA, SC-038, RNF-036):

| Regla | Justificación |
|---|---|
| Los archivos `config/*.json` están en Git porque solo contienen valores públicos; un script de CI falla si aparece una clave sospechosa (`ci_cd.md` QG-D02). | Detecta errores humanos. |
| **Prohibido** `flutter_dotenv`, `envied` o `.env` empaquetado. | Un `.env` empaquetado es legible; ofuscar un secreto no lo protege (ADR-009). |
| El *flavor* `prod` solo se compila desde el flujo de release (tag) y apunta a producción; los demás no pueden apuntar a producción. | Evita apuntar a producción desde pruebas. |
| Un único binario con selector de entorno está **descartado**. | Riesgo de apuntar a producción (ADR-009). |
| El host aceptado por la política de enlaces es solo el del *flavor* (SUP-SEC-16, SC-067). | Un *build* de staging no abre enlaces de producción y viceversa. |

### 3.2 Qué NO va en el repositorio ni en el binario

| Qué | Repositorio | Binario de la app | Dónde vive realmente |
|---|---|---|---|
| Claves de WooCommerce (`wc/v3`) | No | **Nunca** | Servidor Next.js (variables de entorno desde gestor de secretos) |
| `HANDOFF_SECRET`, `IPR_BFF_SECRET`, `REVALIDATE_SECRET`, credenciales SMTP | No | Nunca | Servidor Next.js; en WordPress como **constantes de `wp-config.php`** (no en la base de datos) |
| Claves del plugin de Wompi (sandbox y producción; nombres DESCONOCIDOS) | No | Nunca | Configuración del plugin en WooCommerce de cada entorno |
| Access token y refresh token | No | No (se obtienen en tiempo de ejecución; refresh en Keychain/Keystore) | Dispositivo (almacén seguro) y tabla de sesiones de WordPress (hash) |
| Almacén de claves Android (clave de subida) y sus contraseñas | No | No | Gestor de secretos con ≥ 2 custodios; copia operativa en el entorno protegido de CI |
| Certificados de distribución de Apple, perfiles de aprovisionamiento, clave de API de App Store Connect | No | No | Gestor de secretos / Apple; copia operativa en el entorno protegido de CI |
| Cuenta de servicio de Google Play | No | No | Entorno protegido de CI |
| Token de DigitalOcean, clave SSH de despliegue | No | No | Entorno `production` de CI |
| Credenciales de cuentas de prueba de QA (`QA_PWD_n`) | No | No | Gestor de secretos de QA |
| Token de subida de símbolos al proveedor de fallos (si aplica) | No | No | Entorno protegido de CI |
| **IP de servidores y datos de infraestructura** | **No** (hoy una IP está en `deploy.yml`: ver `ci_cd.md` P-05) | No | Variable/secreto del entorno de CI |
| Datos reales de clientes o empleados | No | No | Solo producción |

Los nombres de los secretos se pueden citar en documentación; **nunca sus valores**.

---

## 4. Secretos: inventario, custodia y rotación

Gestor de secretos: **DESCONOCIDO** (D-14). Propuesta: un gestor corporativo con **≥ 2 custodios y 2FA** como origen de verdad (SC-040, RNF-055); las copias operativas viven en **secretos de entorno** de CI con revisores. Elegir el producto es decisión de TI (DO-16).

| Secreto (nombre) | Entorno | Quién lo opera | Rotación propuesta | Estado |
|---|---|---|---|---|
| Claves de WooCommerce | Servidor Next.js (prod y staging **distintas**) | TI/Web | Anual o ante incidente (RNF-096) | Existe; procedimiento no documentado |
| `IPR_HANDOFF_SECRET`, `IPR_BFF_SECRET` | WordPress + Next.js, **valores distintos por entorno y distintos entre sí** | WP/TI | Con doble valor (actual/siguiente) durante la rotación (WP-16, CH-26) | PROPUESTO |
| `REVALIDATE_SECRET` (HMAC del webhook) | Un valor por entorno | Web/TI | Ante cualquier exposición (SC-060) | Hoy uno solo para dos usos (H-SEC-04) |
| Credenciales SMTP | Producción; en staging, buzón de captura (sin envíos reales) | TI | Anual | Existe |
| Token de DigitalOcean (escritura de firewalls) y `DO_FIREWALL_ID` | Entorno `production` de CI | TI | Periódica; sustituir si se elimina la regla dinámica (DO-11) | Existe como secreto de repositorio |
| Clave SSH de despliegue y `known_hosts` | Entorno `production` | TI | Periódica y al salir un custodio | Existe |
| Clave de subida de Android | Gestor + `android-release` | TI/Móvil (≥ 2 custodios) | Solo ante pérdida o compromiso: se **solicita restablecer** la clave de subida a Google (ver `deployment_guide.md` §4.2) | PROPUESTO |
| Certificado de distribución de Apple, perfiles, clave de API de App Store Connect | Gestor + `ios-release` | TI/Móvil (≥ 2 custodios) | Antes de su vencimiento; la clave de API ante cambio de personal | PROPUESTO |
| Cuenta de servicio de Google Play | `android-release` | TI | Semestral o al salir un custodio | PROPUESTO |
| `QA_PWD_n` y secreto del webhook de prueba | Staging | QA | Por ciclo de pruebas | Convención de `testing_strategy.md` §5.2 |
| Claves del plugin de Wompi (sandbox/producción) | WooCommerce de cada entorno | Finanzas/TI | Según Wompi | DESCONOCIDO |

Principios (SC-039, SC-040, SC-066):

| Principio | Detalle |
|---|---|
| Un secreto, un propósito, un entorno | `IPR_BFF_SECRET` no es `IPR_HANDOFF_SECRET`; los de staging nunca son los de producción |
| Ningún secreto en logs, informes ni capturas | Revisión de logs (ST-023); valores enmascarados en evidencias |
| Rotación ensayada | El manual de incidentes cubre revocación masiva de sesiones, rotación de secretos, interruptor de checkout y versión forzada (SC-066, ST-156) |
| Salida de personal | Revocar clave SSH personal, acceso a entornos de CI, a cuentas de tienda y rotar lo que conocía |
| Historial de Git | Se escanea (ST-020); si aparece un secreto, se **rota** (no basta con borrarlo) |

---

## 5. Datos de prueba y aislamiento

### 5.1 Datos sintéticos (`testing_strategy.md` §5.2, `security_testing.md` §0)

| Regla | Detalle |
|---|---|
| Solo sintéticos | Nunca datos reales de clientes ni de empleados; correos en el dominio reservado `example.test`; direcciones, teléfonos y sedes ficticios |
| Catálogo de pruebas | Productos con prefijo `QA-` (con precio, sin precio, agotado, bajo pedido, oferta, de nombre largo, sin imagen) y categorías `QA-CAT-*` |
| Cuentas | `CLI-01..03`, cuenta de rol administrativo ad hoc `CLI-ADM` creada **solo** en staging, cuentas descartables `CLI-DEL*` recreadas por ciclo; contraseñas generadas y guardadas en el gestor de QA |
| Valores canario | Marcadores `CANARY-…` para detectar fugas en logs (RNF-047) |
| Pagos | Solo Wompi sandbox con los medios de prueba publicados por Wompi (su vigencia: NO VERIFICADO; no se transcriben) |
| Siembra y reposición | Guion que deja staging en estado conocido antes de cada ciclo |
| **Prohibido** | Restaurar en staging una copia de la base de producción **sin anonimización verificada** (Ley 1581: datos personales de clientes); usar tarjetas reales; usar producción para pruebas de escritura |

### 5.2 Aislamiento

| Aspecto | Regla |
|---|---|
| Secretos | Distintos por entorno (sección 4) |
| Webhooks | El webhook `/api/revalidate` de staging solo lo envía WooCommerce de staging, con su propio HMAC; el de producción no apunta a staging ni viceversa |
| Correo | En staging, SMTP a un buzón de captura (sin entrega a personas reales) para no enviar correos a clientes |
| Pagos | WooCommerce de staging con Wompi sandbox; sin credenciales de producción |
| Red | Origen de staging restringido a Cloudflare (CH-11/SC-010 aplicado también a staging) |
| Indexación | `noindex` y `robots.txt` restrictivo en staging; `/mobile/` en `Disallow` (`api_architecture.md` §11) |
| Dominios de enlaces | Staging con su propio `assetlinks.json` y `apple-app-site-association` (CR-076); la política de enlaces de cada *flavor* acepta solo su host |
| Identificadores | `co.ipr.app.dev`, `co.ipr.app.staging`, `co.ipr.app` instalables lado a lado; **cada identificador de aplicación es un registro propio en las tiendas** (ver 5.3) |
| Reporte de fallos | Un proyecto por *flavor* (DN-02 pendiente): staging y producción no mezclan datos |

### 5.3 Distribución de los *builds* de dev y staging

Un *flavor* con identificador propio no se publica en las tiendas públicas. Opciones para que QA instale el *build* de staging (DECISIÓN PENDIENTE DO-17):

| Opción | Pro | Contra |
|---|---|---|
| A. Registros propios en las tiendas para `staging` (pista interna de Play y TestFlight interno) | Mismo canal que producción, firma real, enlaces probables | Un registro adicional por plataforma; el registro de iOS exige un identificador de paquete propio (requisito general de Apple; no verificado hoy); costo operativo |
| B. Distribución interna fuera de tienda (APK firmado, *ad hoc*/MDM, herramienta de distribución de terceros) | Sin registros extra | iOS fuera de TestFlight tiene límites de dispositivos y perfiles de aprovisionamiento (NO VERIFICADO); más material de firma que custodiar; terceros |
| C. Solo `prod` en pistas cerradas + staging solo en dev local | Menos registros | No prueba contra staging con Wompi sandbox: **no sirve** para el E2E de pago |

La opción A es la recomendada (PROPUESTA) porque conserva la firma y el canal reales; el costo es administrativo.

### 5.4 Tensión de diseño: proteger staging sin poner un secreto en la app

Si se protege **todo** staging con un control tipo "Zero Trust" que requiere credenciales de servicio, el *build* `staging` necesitaría esa credencial **dentro del binario**, lo que contradice ADR-009. Opciones (DECISIÓN PENDIENTE DO-18):

| Opción | Detalle | Riesgo |
|---|---|---|
| A (recomendada) | Proteger con control de acceso de Cloudflare solo las **superficies de administración** de staging (wp-admin, paneles, versión web); dejar `/mobile/v1` y `/.well-known/*` de staging alcanzables públicamente, con datos **solo sintéticos**, `noindex`, límites por IP y el mismo WAF que producción | Código preliminar visible por quien conozca la URL; datos no sensibles por construcción |
| B | Lista de IP permitidas (oficina y CI) | Los testers móviles cambian de red; inviable para dispositivos reales |
| C | Autenticación propia del BFF de staging para el *tester* (cuenta/token de QA entregado fuera del binario) | Más desarrollo; complica las pruebas de sesión |

Cualquier opción debe **probar que Cloudflare no desafía a la app** (MED-15, QM-45, TC-032).

---

## 6. Wompi: sandbox frente a producción

| Aspecto | Staging | Producción |
|---|---|---|
| Entorno de Wompi | **Sandbox** | Producción |
| Claves | Claves de prueba, solo en WooCommerce de staging | Claves reales, solo en WooCommerce de producción; fuera de Git y del binario |
| Medios de pago | Los de prueba publicados por Wompi (vigencia NO VERIFICADA) | Reales |
| Confirmación de pago | **DESCONOCIDO**: si el plugin actualiza el estado por webhook sin el navegador (SA-05, CR-018) y qué estados produce Wompi; se mide en staging | Idem; sin pruebas de compra |
| Doble pago | Prueba en staging: 0 duplicados en 100 interrupciones por plataforma (CH-16, TM-027) | Monitoreo de pedidos duplicados (QM-38) |
| Comprobación de firma de eventos | Verificar firma de eventos de Wompi (CH-16) | Idem |
| Quién opera la cuenta de Wompi | Finanzas/TI (DESCONOCIDO) | Idem |
| Reglas | Ningún dato de pago pasa por la app ni por el BFF (el pago ocurre en el checkout web de WooCommerce, ADR-001 §4); la app **no integra SDK de Wompi** (ADR-008) | Idem |

El checkout del MVP **no se libera** sin pruebas en staging con Wompi sandbox (`resolucion_inconsistencias.md`, hallazgo 4; NL-02). Si no se resuelven a tiempo, D-06 prevé la opción (b) (compra en fase 2).

---

## 7. Cloudflare por entorno

| Aspecto | Estado propuesto | Evidencia |
|---|---|---|
| WAF gestionado activo | Mantener en todos los entornos | SC-053 |
| *Cache Rule* para `/mobile/v1/(config|categories|brands|filters|products|liquidaciones|search|stores)` | Solo respuestas públicas; **nunca** cachear privadas (NLS-07, TM-020) | SC-053, ST-069 |
| Sin desafíos interactivos en `/mobile/v1/*` y `/.well-known/*` | Una app no resuelve desafíos; Apple descarga el AASA desde su CDN | `api_architecture.md` §11, §13.3 |
| Límites por IP para `/mobile/v1/auth/*`, `/wp-json/ipr/v1/auth/*`, `wp-login.php`, `xmlrpc.php`, `/api/auth/*` | Configurar | CH-02 |
| Cloudflare delante de WordPress | A confirmar (IN-11, SUP-SEC-11) | `deployment_architecture.md` IN-11 |
| Origen restringido a Cloudflare (Next.js y WordPress); IP fuera del repositorio | Obligatorio antes de producción | CH-11, SC-010 |
| Plan contratado y capacidad de reglas por ruta | **DESCONOCIDO** (AP-08, SA-04). Si el plan tiene *Bot Fight Mode* no omitible por ruta, el riesgo R-02 sigue abierto | `api_architecture.md` §11 |
| Configuración fuera de Git | La configuración de Cloudflare no está versionada (DESCONOCIDO si existe infraestructura como código). Propuesta mínima: **exportar y archivar** la configuración antes y después de cada cambio, con valores enmascarados | ST-151 |

---

## 8. Matriz de accesos (roles, mínimo privilegio)

Roles: **Gerencia**, **TI**, **Web**, **WP**, **Móvil**, **QA**, **Seg**, **Jur** (sin nombres de personas). `L` = lectura, `E` = escritura/operación, `A` = aprobación, `C` = custodio de secretos, `—` = sin acceso. Es una **propuesta**: el equipo real es DESCONOCIDO (D-15) y una persona puede tener varios roles, salvo que **quien despliega no aprueba su propio despliegue** (SC-050).

| Recurso | Gerencia | TI | Web | WP | Móvil | QA | Seg | Jur |
|---|---|---|---|---|---|---|---|---|
| Repo `ipr-frontend` (código) | — | L | E (por PR) | E (por PR, solo WP) | L, PR en contrato | L | L | — |
| Repo `ipr-frontend` (rama `main`, entorno `production`) | A | A/E | — | — | — | — | A | — |
| Repo de la app | — | E (CI) | L | — | E (por PR) | L | L | — |
| Entorno CI `production` (secretos de despliegue) | A | E/C | — | — | — | — | A | — |
| Entornos CI `android-release` / `ios-release` | A | C | — | — | E (lanza) | — | A | — |
| Cuenta de Google Play (titular IPR) | **Propietario** | C | — | — | E (publica, roles acotados) | L (informes) | L | L (declaraciones) |
| Cuenta de Apple Developer y App Store Connect (titular IPR) | **Titular de cuenta** | C | — | — | E (roles acotados) | L (TestFlight) | L | L (privacidad) |
| Servidor Next.js de producción | A | E | L (logs sin PII) | — | — | — | L | — |
| WordPress de producción (wp-admin, wp-config) | A | E | — | E | — | — | L | — |
| WordPress y Next.js de staging | — | E | E | E | L | E | E | — |
| Cloudflare (producción y staging) | A | E | L | — | L | L | L | — |
| Wompi (producción) | A | — | — | — | — | — | — | — (Finanzas, DESCONOCIDO) |
| Wompi sandbox y datos de prueba | — | — | L | L | L | E | — | — |
| Gestor de secretos | A | E/C | — | — | C (solo firmas de la app) | C (solo `QA_PWD_n`) | A | — |
| Reporte de fallos y paneles | — | E | L | L | L | L | L | — |
| Bases de datos con datos reales | — | E (solo TI) | — | — | — | — | — | L (cumplimiento) |

Reglas: 2FA obligatorio en GitHub, Google Play, Apple, Cloudflare, DigitalOcean y el gestor de secretos; cuentas nominales (no compartidas); revisión trimestral de accesos; baja inmediata al salir una persona (RNF-055, SC-040).

---

## 9. Lo que NO se sabe (y cómo se resuelve)

| ID | DESCONOCIDO | Impacto | Cómo se obtiene | Quién |
|---|---|---|---|---|
| U-01 | ¿Existe staging (frontend + WordPress + Wompi sandbox)? Dominios | Bloquea E2E, seguridad dinámica, carga (NLS-08) | H-12/D-16: autorización y revisión de solo lectura | Equipo web + TI |
| U-02 | Comando remoto de despliegue, `npm ci` vs `npm install`, número de procesos, contenedor | Reversa y capacidad | Leer el `authorized_keys`/script del servidor en solo lectura | Web/TI |
| U-03 | Plan de Cloudflare, reglas, origen restringido | Cloudflare y NLS-07 | Panel de Cloudflare en modo lectura | TI |
| U-04 | Cloudflare delante de WordPress; ruta interna opcional | Tramo BFF → WordPress | Revisión de configuración | TI/WP |
| U-05 | Mecanismo de publicación de cambios en WordPress y de snippets | Pipeline de WordPress | Entrevista al equipo WP | WP |
| U-06 | Gestor de secretos, titular de cuentas de tienda | Custodia de firmas | D-14 | Gerencia/TI |
| U-07 | Versiones de WordPress, WooCommerce, Wompi, Wordfence | SCA de WordPress | Inventario en staging | WP |
| U-08 | Versión de Node de producción | Elegir ejecutor de pruebas y versión de CI | Servidor, lectura | Web/TI |
| U-09 | Plan de GitHub y política de revisión actual | Rama protegida, entornos | Ajustes del repositorio | TI |
| U-10 | Estados que produce Wompi y mecanismo de confirmación | Checkout, NLS-06 | Sandbox en staging | Equipo web + Finanzas |

---

## 10. Decisiones pendientes, supuestos y riesgos

### 10.1 Decisiones pendientes

| ID | Decisión | Recomendación | Quién decide | Bloquea |
|---|---|---|---|---|
| DO-15 | Crear staging (alcance, plazo, presupuesto) | Sí, con Wompi sandbox | Gerencia + TI + Resp. técnico | E2E, NLS-08, F3 |
| DO-16 | Producto y custodios del gestor de secretos | ≥ 2 custodios, 2FA | TI + Gerencia | F4 (CH-20) |
| DO-17 | Cómo se distribuye `staging` | Registros propios en las tiendas | TI + Móvil | Pruebas en dispositivo |
| DO-18 | Cómo proteger staging sin secreto en la app | Opción A | TI + Seg | Staging |
| DO-19 | Anonimización de datos si algún día se copia producción | Prohibir copias; solo sintéticos | Seg + Jur | Datos de prueba |
| DO-20 | Infraestructura como código para Cloudflare | Evaluar; mínimo exportar configuración | TI | Reversa de cambios de Cloudflare |

### 10.2 Supuestos

| ID | Supuesto |
|---|---|
| SUP-H-12 | Se autorizará staging con Wompi sandbox (H-12, no aprobada). |
| SUP-DO-06 | Los dominios de staging pueden crearse bajo el dominio corporativo sin afectar el SEO ni la reputación del principal. |
| SUP-DO-07 | El hosting de WordPress (Plesk) permite una instancia de staging. |

### 10.3 Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| RD-12 | Sin staging, el proyecto no puede liberar checkout ni sesiones (NLS-08) | DO-15 / H-12 prioritarios |
| RD-13 | Un *build* de staging o dev apunta a producción por error | Un *flavor* por entorno, `deepLinkHost` y `apiBaseUrl` propios, *build* `prod` solo desde tag |
| RD-14 | Staging con datos reales por conveniencia | Prohibido (5.1); revisión periódica |
| RD-15 | Reutilizar un secreto entre staging y producción | Inventario y verificación (ST-024) |
| RD-16 | Staging público filtra código preliminar | Opción A de 5.4 con aceptación escrita o proteger de otro modo |

*Fin del documento.*

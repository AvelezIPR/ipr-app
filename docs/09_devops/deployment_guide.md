# Guía de publicación, firma, reversa y lanzamiento

| | |
|---|---|
| **Proyecto** | App Flutter de IPR Partes y Repuestos (Inverprimos S.A.S.), BFF `/mobile/v1` y WordPress/WooCommerce |
| **Fase** | DEVSECOPS. **No se programa nada ni se tocan repositorios, consolas ni servidores.** Procedimiento documentado; **ningún paso ha sido ejecutado**. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. Sin claves, tokens, certificados, IP ni valores de `.env`. Los requisitos de tienda se consultaron **hoy** (ver 0.2) y se citan con su fuente; lo no comprobado está marcado **NO VERIFICADO**. |
| **Relacionados** | [`git_strategy.md`](git_strategy.md) · [`ci_cd.md`](ci_cd.md) · [`environments.md`](environments.md) · `06_security/security_controls.md` (SC-040, SC-052, SC-057, SC-058, SC-066; CH-20, CH-22; NLS-01..NLS-09) · `08_quality/testing_strategy.md` §7.2 · `08_quality/quality_metrics.md` §5 · `05_api/api_architecture.md` §5, §13 |

## 0. Convenciones y fuentes

### 0.1 Etiquetas

**HECHO**, **SUPUESTO** (`SUP-DO-xx`), **PROPUESTA**, **DECISIÓN PENDIENTE** (`DO-xx`), **RIESGO** (`RD-xx`), **DESCONOCIDO**, **NO VERIFICADO**. `SUP-H-nn` = supuesto basado en la recomendación H-nn **no aprobada** (`decisiones_pendientes.md` §E). Solo ADR-001 y ADR-002 están aprobadas.

### 0.2 Qué se verificó hoy (2026-11-18) y con qué alcance

**Limitación:** las páginas se leyeron con una herramienta web que resume el contenido; **no se leyó el texto íntegro**. Algunas páginas de ayuda de Google no se cargaron completas (Data safety y la primera lectura del despliegue escalonado). Antes de enviar a revisión, **una persona debe releer cada requisito en la consola y en la fuente oficial**.

| Tema | Resultado verificado | Fuente | Alcance |
|---|---|---|---|
| Nivel de API objetivo en Google Play | Apps nuevas y actualizaciones deben apuntar a **Android 16 (API 36)** desde el **2026-08-31**; había prórroga hasta **2026-11-01** (ya vencida hoy); apps existentes que no cumplan dejan de mostrarse en versiones nuevas de Android | [Play Console Help: target API level](https://support.google.com/googleplay/android-developer/answer/11926878) | Leída (resumen) |
| Prueba cerrada obligatoria en cuentas **personales** | Cuentas personales creadas después del 2023-11-13: ≥ 12 testers durante 14 días continuos antes de pedir acceso a producción. La página **no trata las cuentas de organización** | [Play Console Help: requisitos de prueba](https://support.google.com/googleplay/android-developer/answer/14151465) | Leída (resumen) |
| Play App Signing | Clave de firma de la app (la guarda Google) y clave de subida (la guarda IPR); la de subida se puede **restablecer** si se pierde o compromete; la de firma solo se puede cambiar **antes** de publicar en pruebas abiertas o producción; mejora anual de clave para instalaciones en Android 17 (API 37) o superior con registro de nuevas huellas | [Play Console Help: Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756) | Leída (resumen) |
| Eliminación de cuenta (Google Play) | Si la app permite crear cuenta: debe ofrecer eliminación **dentro de la app** y un **enlace web** para solicitarla sin reinstalar; ambos se declaran en el formulario Data safety; se permite conservar datos por seguridad, fraude o cumplimiento si se informa | [Play Console Help: User Data / eliminación de cuenta](https://support.google.com/googleplay/android-developer/answer/13327111) | Leída (resumen) |
| Despliegue escalonado (Play) | Solo actualizaciones; usuarios al azar; el porcentaje **no sube solo**; **detener** impide llegar a más usuarios y los que ya la tienen se quedan con ella; se puede reanudar con otro porcentaje; para un fallo se publica un paquete corregido. El resumen del buscador añade: **no se puede detener la primera versión de una pista** | [Play Console Help: despliegues escalonados](https://support.google.com/googleplay/android-developer/answer/6346149) | Leída (resumen) + resumen de buscador |
| Data safety | Todo desarrollador con app publicada debe completar el formulario; las apps solo en pista **interna** estarían exentas (dato del resumen de buscador; página no cargada) | [Play Console Help: Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) | **Resumen de buscador; página NO leída** |
| Requisito de herramientas de Apple | Desde el **2026-04-28**, las apps subidas a App Store Connect deben compilarse con **Xcode 26 o posterior** y SDK 26 (iOS, iPadOS, etc.). Lista además "2026-09-09: apps de iOS/iPadOS subidas deben apuntar a iOS 13 o superior" (dato del resumen; confirmar) | [Apple: upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) | Leída (resumen) |
| Directrices de revisión de Apple | 5.1.1(v): si se permite crear cuenta, hay que ofrecer su **eliminación dentro de la app**; 4.8: login de terceros exige alternativa equivalente, **no** si solo se usa el sistema de cuentas propio; 5.1.1(i): política de privacidad en metadatos y en la app; 2.1: credenciales de demostración y backend activo durante la revisión | [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) | Leída (resumen; ~100 000 de 114 384 caracteres) |
| Desactivar no basta | "Ofrecer desactivar temporalmente la cuenta no es suficiente"; si se usa Sign in with Apple, revocar sus tokens al borrar | [Apple: account deletion](https://developer.apple.com/news?id=12m75xbj) | Resumen de buscador; página no leída |
| App Privacy | Declaran Account Holder, Admin o App Manager; la política de privacidad (URL) es obligatoria en iOS; se deben incluir las prácticas de terceros cuyo código se integra; publicar para que surta efecto | [App Store Connect Help: App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy) | Leída (resumen) |
| TestFlight | Internos: hasta 100 usuarios de App Store Connect; externos: hasta 10 000; las compilaciones caducan a los **90 días**; la primera compilación de un grupo externo pasa por revisión | [App Store Connect Help: TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview) | Leída (resumen) |
| Liberación por fases (Apple) | 7 días; solo actualizaciones automáticas; se puede **pausar hasta 30 días en total**; se puede liberar a todos; quien actualiza a mano la recibe de inmediato | [App Store Connect Help: phased release](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases) | Resumen de buscador; la página directa no se pudo leer |
| Alta de organización en Apple | Entidad legal con **número D-U-N-S**, autoridad legal vinculante, sitio web público funcional, correo del dominio, 2FA; 99 USD por año | [Apple: enrollment](https://developer.apple.com/programs/enroll/) | Leída (resumen) |
| Endurecimiento de GitHub Actions y protección de ramas | SHA completo para acciones de terceros, `GITHUB_TOKEN` mínimo, entornos con revisores; ramas: revisiones, *code owners*, comprobaciones, commits firmados | [GitHub Docs: secure use](https://docs.github.com/en/actions/reference/security/secure-use) · [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) | Leídas (resumen) |

### 0.3 Lo que NO se pudo verificar hoy (NO VERIFICADO)

| Tema | Por qué importa |
|---|---|
| Si Google Play exige a una cuenta de **organización** (Inverprimos) la prueba cerrada de 12 testers/14 días, y si la verificación de organización exige D-U-N-S | Plazo del primer lanzamiento |
| Límites vigentes de testers de la pista interna y de las pistas cerradas | Plan de pruebas |
| Lista actual de **declaraciones** de Play Console para esta app (funciones financieras, seguridad de datos, público, etc.) | Evitar rechazos |
| Si hay requisitos nuevos de tamaño de página de 16 KB o de librerías nativas para apuntar a API 36 y si los plugins elegidos los cumplen | Compilación |
| Mínimos reales de Android/iOS con Flutter 3.50 + plugins (SPK-02) | DN-01 |
| Vigencia del certificado de distribución de Apple y efecto de revocarlo sobre apps ya publicadas | Rotación |
| Herramienta vigente de subida a App Store Connect desde CI | CI |
| Pregunta de cifrado (export compliance) y si HTTPS solo la deja exenta | Envío iOS |
| Tratamiento por Apple de pagos de bienes físicos en navegador externo (guía 3.1.3(e)); la parte de las directrices que cubre pagos no se leyó | Riesgo de rechazo (RD-21) |
| Idiomas disponibles en App Store Connect para es-CO | Ficha |
| Tiempo de revisión de ambas tiendas | Calendario (no se promete fecha) |
| Solicitud de revisión acelerada de Apple y su vigencia | Reversa |
| Revisión del límite de `versionCode` de Play | Versionado |

---

## 1. Roles y prerrequisitos

### 1.1 Roles (sin nombres)

| Rol | Responsabilidad en la publicación |
|---|---|
| **Gerencia** | Titularidad de las cuentas (Inverprimos S.A.S.), aprueba el lanzamiento y las aceptaciones de riesgo |
| **TI** | Custodio de firmas y secretos, CI/CD, Cloudflare |
| **Móvil** | Construye, sube a pistas de prueba, prepara fichas y declaraciones |
| **Web / WP** | BFF, WordPress, `/mobile/v1/config`, `.well-known`, página `/app/pedido` |
| **QA** | Ejecuta las puertas de release (QG-R) |
| **Seg** | Evidencia de seguridad, revisa binario, firma de aceptaciones |
| **Jur** | Política de datos, Data safety, App Privacy, eliminación de cuenta |
| **Producto** | Ficha, textos, calendario |

Quien sube un *build* no aprueba su promoción a producción.

### 1.2 Prerrequisitos (bloqueantes antes de F4)

| # | Prerrequisito | Estado | Referencia |
|---|---|---|---|
| 1 | Cuenta de Google Play Console **a nombre de Inverprimos S.A.S.**, 2FA, ≥ 2 administradores | DESCONOCIDO (D-14) | RNF-055, NL-11 |
| 2 | Cuenta de Apple Developer (organización) a nombre de Inverprimos, con D-U-N-S, sitio web público, 2FA; el Account Holder tiene autoridad legal | DESCONOCIDO (D-14) | Requisitos de enrolamiento (0.2) |
| 3 | **Identificador de aplicación de producción definitivo** (hoy `co.ipr.app` es **PENDIENTE**) | PENDIENTE (DA-12) | `flutter_app_architecture.md` §16. **No se puede cambiar tras publicar** |
| 4 | Política de privacidad vigente y revisada por Jurídico, accesible por URL pública | PENDIENTE (D-12) | NL-07 |
| 5 | Página web pública para **solicitar la eliminación de la cuenta** (requisito de Google Play, además de la ruta dentro de la app) | **No está en los documentos**: RF-110 solo habla de la app | Ver GAP-DO-01 (11.1) |
| 6 | Staging operativo con Wompi sandbox y E2E en verde | DESCONOCIDO (C2) | NLS-08 |
| 7 | Gestor de secretos con ≥ 2 custodios | DESCONOCIDO | SC-040 |
| 8 | Proveedor de reporte de fallos elegido (DN-02) y configurado por *flavor* | PENDIENTE | NL-09 |
| 9 | Cuenta de prueba **sintética** de producción para revisores y monitoreo (sin permisos administrativos) | PROPUESTA (RNF-102 prevé una cuenta de prueba dedicada y autorizada) | RD-20 |
| 10 | Archivos `.well-known` (`assetlinks.json`, AASA) alojados con las huellas reales | PROPUESTO (FE-10, DA-03) | `api_architecture.md` §13.3 |
| 11 | Interruptores y `minSupportedVersion` operativos en `/mobile/v1/config` | PROPUESTO (FE-15, RNF-029) | SC-052 |

---

## 2. Requisitos vigentes de tienda que condicionan el *build*

| Tienda | Requisito | Valor verificado hoy | Consecuencia para el proyecto |
|---|---|---|---|
| Google Play | `targetSdk` | **API 36** (desde 2026-08-31; la prórroga a 2026-11-01 ya venció) | La app **debe apuntar a API 36**; comprobarlo en SPK-02 con Flutter 3.50 y los plugins (NO VERIFICADO que lo haga por defecto) |
| Google Play | Formato | Paquete de la app (AAB) con Play App Signing: las apps nuevas se inscriben por defecto al subir un *bundle* | La página consultada no afirma que el AAB sea obligatorio; el pipeline publica **AAB** |
| Apple | Compilar con | **Xcode 26 o posterior**, SDK 26, desde 2026-04-28 | El ejecutor macOS de CI debe tener Xcode 26 (NO VERIFICADO que exista la imagen) |
| Apple | Versión de iOS objetivo | El resumen lista "apuntar a iOS 13 o superior" desde 2026-09-09 | El mínimo propuesto de la app es iOS 15 (DN-01): cumple; confirmar |
| Apple | Preguntas de clasificación por edad | Respuesta requerida a las preguntas actualizadas desde 2026-01-31 | Contestarlas al crear la app |
| Apple | Estado de comerciante DSA (UE) | Requerido para distribuir en la UE | Si la app solo se distribuye en Colombia, no aplica; decidir territorios (DO-21) |
| Ambas | Eliminación de cuenta | En la app (y, en Google Play, enlace web) | RF-110 cubre la ruta en la app; falta la página web (GAP-DO-01) |

---

## 3. Versionado de *build*

| Elemento | Regla | Fuente |
|---|---|---|
| Versión visible | `MAJOR.MINOR.PATCH` (SemVer) en `pubspec.yaml` | `git_strategy.md` §4.2 |
| Número de *build* | Entero creciente asignado por el flujo de release (`${{ github.run_number }}` o equivalente); Android `versionCode`, iOS `CFBundleVersion` | idem |
| Reglas de tienda | Cada AAB debe tener un `versionCode` **mayor** que el anterior publicado (no se puede volver a uno menor); iOS exige `CFBundleVersion` creciente por versión (conocimiento general, NO VERIFICADO hoy) | — |
| Cabecera | La app envía `X-App-Version` (versión y *build*) y `X-App-Platform` (N-01/T-09) para `minSupportedVersion` y 426 | `api_architecture.md` §5 |
| Tag | `vX.Y.Z` firmado en el repositorio de la app; el *build* se produce **solo desde el tag** | `ci_cd.md` §6 |
| Un *build* por *flavor* | `dev`, `staging`, `prod` (identificadores distintos) | ADR-009 |
| Trazabilidad | Se archivan junto al *build*: hash SHA-256, SBOM, símbolos de ofuscación, mapeo de R8, dSYM, informes de seguridad | `ci_cd.md` §3.3 |

---

## 4. Firma de aplicaciones sin exponer claves ni certificados

### 4.1 Principios (SC-040, RNF-055, RNF-093, NL-11, CH-20)

| Principio | Detalle |
|---|---|
| **Cuentas y claves son de IPR**, no de una persona ni de un proveedor | Titularidad de Inverprimos S.A.S. (D-14) |
| ≥ 2 custodios con recuperación; 2FA en todas las cuentas | RNF-055 |
| Origen de verdad: gestor de secretos; en CI solo una **copia operativa** en entornos protegidos con revisores | `environments.md` §4 |
| Nunca en Git, nunca en el binario, nunca en logs, nunca por correo o mensajería | `git_strategy.md` §5.5 |
| Las PR no tienen acceso a firmas; el *build* firmado sale solo de un tag firmado y de un entorno aprobado | `ci_cd.md` §6.2 |
| Separar **clave de subida** (se puede restablecer) de **clave de firma de la app** (la custodia Google) | Play App Signing (verificado) |
| Ensayar la recuperación | ST-154, ST-156 |

### 4.2 Android: Play App Signing

| Paso | Procedimiento (PROPUESTA) | Nota |
|---|---|---|
| 1 | Elegir que **Google genere y custodie** la clave de firma de la app al inscribir la app en Play App Signing | Si IPR custodiara la clave de firma y la perdiera, **no se puede restablecer** (verificado). La clave de firma solo se puede cambiar **antes** de publicar en pruebas abiertas o producción (verificado). Decisión DO-22 |
| 2 | Un custodio genera la **clave de subida** en un equipo limpio y controlado con la herramienta del SDK de Android (`keytool`), con algoritmo, tamaño y validez según lo que exija Google Play al momento (**NO VERIFICADO**: confirmar al generarla) | Contraseñas aleatorias generadas por gestor |
| 3 | Guardar el almacén y sus contraseñas en el gestor de secretos (entradas separadas), con copia cifrada fuera de línea sellada por el segundo custodio | Sin copias en correo ni chats |
| 4 | Cargar en el entorno `android-release` de CI la copia operativa (almacén codificado) y las contraseñas como secretos del entorno | `ci_cd.md` §6.4 |
| 5 | El flujo de release crea un archivo temporal de clave, firma el AAB y lo **borra siempre** (`if: always()`) | Ejemplo, no probado |
| 6 | Registrar las **huellas SHA-256** que muestra Play Console (certificado de firma de la app) en `assetlinks.json` del dominio de cada entorno | `api_architecture.md` §13.3. Las compilaciones de depuración o de CI no coinciden con la huella: las App Links no se verifican en ellas |
| 7 | Para staging, la huella correspondiente a su identificador y su registro en la consola | `environments.md` §5.3 |

**Si se pierde o compromete la clave de subida (procedimiento verificado en la ayuda de Google):** crear una nueva clave de subida, exportar su certificado a PEM, en Play Console abrir "Play app signing" → "Upload key certificate" → "Request upload key reset", indicar el motivo y subir el PEM. Además: revocar la cuenta de servicio de CI y los secretos del entorno, rotar los que haya conocido el custodio que sale, y registrar el incidente (SC-066).

**Mejora anual de la clave (según la página consultada):** Google ofrece mejoras anuales de clave para instalaciones en Android 17 (API 37) o superior; tras una mejora hay que **registrar las nuevas huellas** con los proveedores de API. Para IPR significa **añadir la nueva huella a `assetlinks.json` antes de que entre en vigor** (si no, la verificación de App Links falla en esos dispositivos). Responsable: Web (alojamiento) + Móvil.

### 4.3 iOS: certificados, perfiles y clave de API

| Elemento | Qué es | Custodia | Notas |
|---|---|---|---|
| Cuenta de organización | Account Holder con autoridad legal; acepta contratos | Gerencia | Verificado (0.2) |
| Identificador de paquete (Bundle ID) | Registro por *flavor*; capacidad **Associated Domains** para Universal Links | TI/Móvil | Un registro de aplicación por identificador (conocimiento general, no verificado hoy) |
| Certificado de distribución | Prueba de identidad para firmar | Gestor (clave privada, si se gestiona manualmente) o administrado por Apple en la nube | **Opción A (recomendada, DO-12):** firma administrada por Apple en la nube con una **clave de API de App Store Connect** (reduce material de firma custodiado). **Opción B:** certificado y perfil importados a un llavero temporal de CI. Capacidad de la opción A: **NO VERIFICADO** |
| Perfil de aprovisionamiento (App Store) | Vincula app, certificado y capacidades | Generado en el portal | Caduca; calendario de renovación |
| Clave de API de App Store Connect (archivo descargable una sola vez) | Permite subir *builds* y administrar | Gestor + `ios-release` | Rol mínimo que permita subir *builds* (NO VERIFICADO cuál); revocable |
| Llavero temporal en CI | Importar certificado solo durante el job | CI | Contraseña aleatoria, borrar el llavero al terminar |

Rotación y revocación (PROPUESTA; **verificar con Apple antes de ejecutar**): calendario con recordatorio ≥ 60 días antes del vencimiento del certificado y de los perfiles (vigencia exacta NO VERIFICADA; el conocimiento general indica aproximadamente un año); crear el certificado nuevo, actualizar el entorno `ios-release`, compilar y verificar; solo después revocar el anterior. Si se compromete: revocar el certificado y la clave de API en el portal y actualizar el entorno.

### 4.4 Revisión de custodios y salida de personal

| Evento | Acción |
|---|---|
| Un custodio sale | Revocar sus accesos a Play, Apple, CI, gestor y SSH; rotar lo que conocía; nombrar reemplazo; probar la recuperación |
| Cambio de titular de la cuenta de tienda | Proceso formal de transferencia en cada tienda (NO VERIFICADO el procedimiento vigente) |
| Revisión trimestral | Lista de accesos y de roles de ambas tiendas (`environments.md` §8) |
| Auditoría previa a producción | ST-154 y CH-20: titularidad, 2FA, ≥ 2 custodios, Play App Signing activo, respaldo de claves |

---

## 5. Publicación en Google Play Console (paso a paso)

> Estado: PROPUESTA. Cada paso se **ejecuta por primera vez en staging/pruebas** (ver `testing_strategy.md` §9 F3–F4). Los nombres exactos de menús de la consola pueden cambiar: confirmar en la consola.

### 5.1 Preparación de la cuenta y la app

| Paso | Acción | Responsable |
|---|---|---|
| 5.1.1 | Crear/verificar la cuenta de **organización** de Google Play a nombre de Inverprimos (requisitos de verificación de organización: NO VERIFICADO) | Gerencia + TI |
| 5.1.2 | Asignar roles mínimos en Play Console; 2FA para todos | TI |
| 5.1.3 | Crear la aplicación (`prod`): nombre, idioma (es-CO), tipo "aplicación", gratuita; aceptar las políticas (**lo hace una persona autorizada**, no el CI) | Móvil + Gerencia |
| 5.1.4 | Inscribir en **Play App Signing** al subir el primer AAB (4.2) | Móvil + TI |
| 5.1.5 | Configurar la cuenta de servicio de CI con permiso mínimo (subida a pistas de prueba) | TI |

### 5.2 Contenido de la app (declaraciones)

Todas deben reflejar el **tráfico y los datos reales** (NL-07, SC-058, ST-132). Una declaración inexacta puede suspender la app.

| Declaración | Contenido propuesto | Notas |
|---|---|---|
| Política de privacidad | URL pública de la política aprobada por Jurídico (D-12) | Misma que en iOS |
| Acceso a la app (credenciales para revisión) | La app permite explorar catálogo sin cuenta (sin precio B2B); **comprar exige cuenta** (SUP-H-10: sin compra de invitado, no aprobada). Se entrega una cuenta sintética de revisión con instrucciones | **RD-20:** la cuenta existe en **producción**; no debe tener permisos administrativos; el pago real ocurre en Wompi producción: ver 7.3 |
| Anuncios | No | La app no integra publicidad (no hay SDK de anuncios en `flutter_app_architecture.md` §17) |
| Clasificación de contenido | Cuestionario con respuestas veraces | NO VERIFICADO el formulario vigente |
| Público objetivo | No dirigido a menores (propuesta; decidir con Jurídico) | — |
| **Data safety** | Ver tabla 5.2.1 | Obligatorio para apps publicadas (pista interna exenta: dato de buscador) |
| **Cuenta y eliminación de datos** | Declarar que la app permite crear cuenta y ofrece eliminación; ingresar el **enlace web** para solicitarla | GAP-DO-01: hoy no existe esa página |
| Funciones financieras, salud, gobierno, otras | Responder lo que la consola pida; la app no es financiera ni de salud (el pago se hace en la web de WooCommerce con Wompi). La lista vigente de declaraciones es **NO VERIFICADA** | Revisar al momento |
| Permisos y componentes | Solo permiso de Internet (SC-042, RNF-060); sin permisos sensibles; revisar el manifiesto fusionado de los plugins | `security_controls.md` SC-042 |
| App Links | Declarar el dominio verificado y comprobar que `assetlinks.json` responde sin redirección ni desafío de Cloudflare | `api_architecture.md` §13.3 |

#### 5.2.1 Data safety: datos probables y su origen (PROPUESTA; **Jurídico decide** y debe contrastarlo con el tráfico real)

| Dato | ¿La app lo recibe/envía? | Origen documental | Declarar (propuesta) |
|---|---|---|---|
| Nombre, correo, teléfono | Sí (registro, perfil, PQRS, checkout) | `authentication.md`, RF-104..106 | Recopilados; funcionalidad de la app y gestión de la cuenta |
| Dirección | Sí (direcciones del perfil) | WP-08 | Recopilados |
| Cédula/NIT | Posible (checkout web; perfil): **DESCONOCIDO si la app lo maneja** | `resolucion_inconsistencias.md` CR-044 | Confirmar antes de declarar |
| Historial de compras / pedidos | Sí (lista y detalle) | RF-107, RF-108 | Recopilados |
| Identificadores de dispositivo / instalación | Sí (`deviceId` aleatorio, no es identificador publicitario) | `authentication.md`; SC-030 | Identificador de dispositivo u otros; confirmar |
| Registros de fallos y diagnóstico | Sí (proveedor de fallos, DN-02) | RNF-097 | Diagnóstico; el proveedor determina si hay transferencia internacional (R-NF-09) |
| Contenido de PQRS | Sí (mensaje) | RF-096 | Mensajes del usuario |
| Ubicación, contactos, fotos, micrófono | No | RNF-060 | No recopilados |
| Analítica de producto y push | No en el MVP | `flutter_app_architecture.md` §18 | Si se añaden, **actualizar antes de publicar** |
| Cifrado en tránsito | Sí (TLS ≥ 1.2) | SC-036 | Sí |
| Eliminación disponible | Sí (RF-110, WP-09) | SC-057 | Sí, con enlace web |

### 5.3 Ficha de la tienda

| Elemento | Regla |
|---|---|
| Textos (título, descripción corta y larga), novedades | Aprobados por Producto/Jurídico (QG-R13); en es-CO |
| Capturas, ícono y gráficos | Con **datos sintéticos** (nunca clientes reales ni precios no vigentes); coherentes con lo que la app hace |
| Datos de contacto y política | Los públicos de IPR (dato público: la web) |
| Metadatos | No prometer funciones que no existen (cotizaciones, B2B, push, favoritos son fase 2) |

### 5.4 Pistas de prueba

| Pista | Uso en este proyecto | Condiciones |
|---|---|---|
| **Interna** | Humo de cada *build* de CI, equipo propio | Cargas automáticas desde CI con la cuenta de servicio de permiso mínimo. Límite de testers: NO VERIFICADO |
| **Cerrada** | QA y piloto controlado (F3/F5), lista de correos o grupos | Si la cuenta resultara **personal**: ≥ 12 testers durante 14 días continuos antes de acceder a producción (verificado). Para **organización**: la página no lo trata → NO VERIFICADO |
| **Abierta** | Opcional; piloto abierto con más usuarios | Requiere Data safety completo y revisión |
| **Producción** | Lanzamiento escalonado (8) | Todas las puertas QG-R y NLS en verde |

Informe previo al lanzamiento y vitales de Android: usarlos como señal adicional, no como puerta (NO VERIFICADOS en esta sesión).

### 5.5 Subir y publicar

| Paso | Acción |
|---|---|
| 5.5.1 | CI sube el AAB firmado a la pista **interna** (automático) con notas de versión es-CO |
| 5.5.2 | Móvil verifica instalación desde Play (la firma real), App Links, login, checkout en staging |
| 5.5.3 | Promover a cerrada (piloto) tras puertas de F3/F4; recopilar crash-free y ANR |
| 5.5.4 | Promover a **producción** **manualmente** por una persona distinta de quien construyó (compuerta humana), con despliegue escalonado (sección 8) |
| 5.5.5 | Revisar el estado de la revisión de Google; no se promete plazo (NO VERIFICADO) |
| 5.5.6 | Tras publicar, **no** cambiar la ficha de tienda hasta llegar al 100 % salvo urgencia (recomendación de Google en la ayuda: hacer cambios de ficha después del 100 %) |

---

## 6. Publicación en Apple App Store Connect (paso a paso)

### 6.1 Requisitos vigentes (verificados hoy)

| Requisito | Valor | Acción |
|---|---|---|
| Compilar con | Xcode 26 o posterior (SDK 26) desde 2026-04-28 | Ejecutor macOS con Xcode 26; fijar la versión en CI |
| iOS objetivo (resumen) | iOS 13 o superior desde 2026-09-09 | El mínimo propuesto es iOS 15 |
| Edad | Preguntas actualizadas respondidas desde 2026-01-31 | Responder al crear la app |
| DSA | Estado de comerciante para distribuir en la UE | Decidir territorios (DO-21) |
| Política de privacidad | URL obligatoria en iOS | URL pública aprobada |

### 6.2 Cuenta y registros

| Paso | Acción | Responsable |
|---|---|---|
| 6.2.1 | Inscribir a **Inverprimos S.A.S.** como organización en Apple Developer Program: D-U-N-S, autoridad vinculante del Account Holder, sitio web, 2FA, 99 USD anuales (verificado) | Gerencia |
| 6.2.2 | Asignar roles mínimos en App Store Connect; limitar quién puede declarar App Privacy (Account Holder, Admin o App Manager) | TI |
| 6.2.3 | Registrar el **Bundle ID** de producción (`co.ipr.app`, PENDIENTE) y de `staging` y `dev` si se distribuirán; activar **Associated Domains** | Móvil |
| 6.2.4 | Crear el registro de la app en App Store Connect: nombre, SKU, idioma principal (es-CO no está garantizado: elegir el más cercano, NO VERIFICADO), categoría | Móvil |
| 6.2.5 | Configurar firma (4.3) y la clave de API para CI | TI |

### 6.3 Compilar y subir

| Paso | Acción |
|---|---|
| 6.3.1 | El flujo de release compila el IPA con Xcode 26+, `--obfuscate --split-debug-info`, número de *build* creciente (3) |
| 6.3.2 | Subida a App Store Connect desde CI con la clave de API (herramienta vigente: NO VERIFICADO); archivar dSYM, hash y SBOM |
| 6.3.3 | Responder las preguntas de cifrado (HTTPS estándar; si queda exenta: NO VERIFICADO) y de clasificación por edad |
| 6.3.4 | La compilación procesada aparece en TestFlight |

### 6.4 TestFlight

| Grupo | Uso | Límite verificado |
|---|---|---|
| Interno | Equipo y QA | Hasta 100 usuarios de App Store Connect |
| Externo | Piloto F5 | Hasta 10 000 personas; la primera compilación de cada grupo pasa por revisión de Apple |
| Caducidad | Las compilaciones caducan a los 90 días | Renovar las de piloto largo |

### 6.5 App Privacy y privacidad

| Paso | Acción |
|---|---|
| 6.5.1 | Declarar App Privacy (roles autorizados, 6.2.2): **lo mismo que Data safety** (tabla 5.2.1), incluidas las prácticas de terceros cuyo código integra la app (proveedor de fallos). Publicar para que surta efecto |
| 6.5.2 | URL de la política de privacidad en metadatos **y dentro de la app** (directriz 5.1.1(i), verificada) |
| 6.5.3 | Si no hay seguimiento entre apps, no se requiere solicitud de seguimiento; confirmar con la lista de SDK |
| 6.5.4 | Cualquier cambio posterior de datos recopilados exige actualizar App Privacy y Data safety **antes** de publicar (NL-07) |

### 6.6 Revisión de Apple: reglas relevantes (verificadas)

| Directriz | Qué exige | Cómo se cumple |
|---|---|---|
| **5.1.1(v)** eliminación de cuenta | Si la app permite crear cuenta, debe permitir **eliminarla dentro de la app**; desactivar temporalmente no basta; informar si el proceso tarda | RF-110 y WP-09: ruta "Cuenta → Eliminar cuenta"; la anonimización se programa (SC-057). SUP-H-11 (sin periodo de gracia, ≤ 15 días hábiles) **no está aprobada**: la ficha y la política deben decir lo mismo que se implemente |
| **4.8** inicio de sesión | Con login de terceros hay que ofrecer una alternativa equivalente; **no** hace falta si solo se usa el sistema de cuentas propio | La app usa **solo** cuentas propias (correo y contraseña de WordPress): **Sign in with Apple no es necesario hoy**. Si se añade Google, Facebook u otro login social, **sí** (con las condiciones de la directriz) |
| **2.1** información de revisión | Credenciales de demostración y **backend activo** durante la revisión | Cuenta sintética de revisión, BFF y WordPress en producción disponibles; sin mantenimientos durante la revisión |
| **5.1.1(i)** privacidad | Política enlazada en metadatos y en la app; debe explicar recopilación, uso, retención y eliminación | URL pública aprobada |
| **5.1.2** uso de datos | Permiso explícito para usar o compartir datos personales; sin elaborar perfiles encubiertos | La app no comparte datos con terceros salvo el proveedor de fallos (a declarar) |
| Pagos (**NO VERIFICADO**) | La parte de las directrices que regula pagos de bienes físicos o por navegador externo no se leyó hoy | RD-21: preparar notas de revisión que expliquen que se venden **bienes físicos** y el pago se completa en el checkout web de WooCommerce con Wompi (ADR-001 §4) |
| Funcionalidad mínima | Una app que solo envuelve la web puede rechazarse (conocimiento general; NO VERIFICADO hoy) | La app es nativa en catálogo, búsqueda, sedes y herramientas (ADR-002) |

### 6.7 Enviar a revisión y liberar

| Paso | Acción |
|---|---|
| 6.7.1 | Completar metadatos, capturas (datos sintéticos), notas de revisión y cuenta de demostración (sin permisos administrativos) |
| 6.7.2 | Seleccionar la compilación y enviar |
| 6.7.3 | Elegir liberación: **manual** tras la aprobación (recomendado para controlar la hora y los interruptores) o automática |
| 6.7.4 | **Liberación por fases para actualizaciones automáticas**: 7 días, pausable hasta 30 días en total, con opción de liberar a todos (verificado); quienes actualicen manualmente la reciben de inmediato. **Se recomienda activarla** en cada versión después de la primera |
| 6.7.5 | Primera versión: no hay "fase" (no hay actualizaciones automáticas): compensar con un lanzamiento previo por TestFlight externo/piloto y con **interruptores remotos** |

---

## 7. Notas de revisión y riesgos de las tiendas

### 7.1 Plantilla de notas de revisión (PROPUESTA; sin credenciales aquí)

| Campo | Contenido |
|---|---|
| Qué hace la app | Catálogo de repuestos y equipos, búsqueda, sedes, calculadora BTU, cuenta y compra |
| Cómo se compra | La compra se completa en el checkout web de WooCommerce (Wompi) en el navegador seguro del sistema; la app no recopila datos de pago |
| Cuenta de demostración | Entregada en el campo seguro de la consola; cuenta sintética sin permisos administrativos |
| Dónde eliminar la cuenta | Cuenta → Eliminar cuenta |
| Dónde está la política | Enlace en la ficha y en la app |
| Aviso | No finalizar un pago real; si se desea probar el pago, contactar a IPR (ver 7.3) |

### 7.2 Entorno de revisión

El revisor usa **producción**. Antes de enviar: sin mantenimientos, BFF y WordPress estables, cuenta de revisión vigente, interruptores en estado normal, catálogo con productos reales publicados.

### 7.3 Riesgo: el revisor intenta pagar (RD-20, RD-21)

El pago real ocurre en Wompi **producción**; las tarjetas de prueba de Wompi solo funcionan en sandbox. Opciones (DECISIÓN PENDIENTE DO-23):

| Opción | Detalle | Riesgo |
|---|---|---|
| A | Notas que expliquen el pago y un video de la compra en staging; sin credenciales de pago | El revisor puede considerar que no pudo probar el pago |
| B | Producto de prueba de bajo valor, reembolsable, solo visible a la cuenta de revisión | Requiere lógica de visibilidad por cuenta (cambio no previsto en los documentos) y gestión de reembolsos |
| C | Solicitar a Apple un modo de demostración (la directriz 2.1 lo admite con autorización previa) | Requiere aprobación y desarrollo (no previsto) |

No se resuelve en este documento; se registra para decisión de Producto, Finanzas y Seg.

---

## 8. Plan de lanzamiento escalonado y puertas de avance

### 8.1 Orden

| Fase | Contenido | Condición para avanzar |
|---|---|---|
| F3 | Pistas internas y staging | QG-M y QG-B en verde; E2E de staging (NLS-08) |
| F4 | Pre-lanzamiento: RC, pruebas de seguridad, pentest, checklist de lanzamiento | QG-R01..R13, R15; NLS-01..NLS-09; CH P0 cerrados |
| F5 | **Piloto**: Play pista cerrada/abierta y TestFlight externo | QG-R14: crash-free ≥ 99,5 % y ANR ≤ 0,3 %; 0 S1; sin duplicados |
| F6 | Producción con despliegue escalonado | Puertas del 8.2 en cada escalón |

### 8.2 Escalones propuestos en Google Play (ajustar tras el piloto; los porcentajes y las ventanas son PROPUESTA)

| Escalón | Porcentaje | Ventana mínima de observación | Condición para subir |
|---|---|---|---|
| 1 | 5 % | 24–48 h | crash-free ≥ 99,5 %; ANR ≤ 0,3 %; 0 pedidos o cobros duplicados; tasa de errores 5xx del BFF < 2 % en 5 min; solicitudes con desafío/403 del WAF ≤ 0,1 % |
| 2 | 20 % | 24–48 h | Igual; sin alertas abiertas de RNF-101 |
| 3 | 50 % | 24–48 h | Igual; la web no se degrada más del 10 % (RNF-015) |
| 4 | 100 % | — | Igual; luego, cambios de ficha si hay |

**Importante (verificado):** el porcentaje **no sube solo**; hay que subirlo manualmente. **La primera versión de una pista no se puede detener** (resumen de buscador de la ayuda de Play): por eso la **primera publicación de producción** se hace después de un piloto en pista cerrada/abierta y con interruptores remotos probados; si no, la única reversa son los interruptores y la versión mínima forzada.

En Apple, versiones posteriores a la primera: liberación por fases de 7 días (6.7.4).

---

## 9. Reversa y desactivación

Las tiendas **no permiten volver atrás un binario ya instalado**. La reversa es **detener la propagación**, **apagar funciones desde el servidor**, **forzar actualización** y **publicar una versión corregida** (hacia adelante, con número de *build* mayor).

### 9.1 Capas de defensa (de la más rápida a la más lenta)

| # | Capa | Efecto | Tiempo objetivo | Requisito |
|---|---|---|---|---|
| 1 | **Interruptores remotos** en `/mobile/v1/config` (p. ej. apagar el checkout, mostrar aviso) | La app deja de ofrecer la función | ≤ 5 min (RNF-029, QM-44) | Interruptores probados en staging; configuración con caché corta; la app trae valores por defecto empaquetados (SC-044) |
| 2 | **Detener el despliegue escalonado**: Play (Manage rollout → Halt rollout) y Apple (pausar la liberación por fases, ≤ 30 días en total) | No llega a más usuarios; los que ya la tienen la conservan (verificado) | Minutos | La primera versión de una pista de Play no se puede detener |
| 3 | **Versión mínima forzada**: `minSupportedVersion` (aviso suave) y 426 `app_version_unsupported` (mínimo duro) con la pantalla `/update-required` | Obliga a actualizar | ≤ 5 min | Ver 9.3 |
| 4 | **Publicar versión corregida** (`PATCH`, `versionCode` mayor) y promover a 100 % | Corrige a los usuarios | Horas a días (revisión de tienda NO VERIFICADA) | Rama `release/X.Y` (`git_strategy.md` §3.2) |
| 5 | Retirar la app de la venta (Play: despublicar; Apple: retirar de la venta) | Impide nuevas descargas | Minutos a horas | Decisión de Gerencia |

### 9.2 Escenarios

| Escenario | Acción | Responsable | Referencias |
|---|---|---|---|
| Fallo grave en la app durante el escalonado | 2 (detener) + 1 si hay función apagable + 4 | Móvil + QA | QG-R14 |
| Fallo grave en la **primera** versión de Play | 1, 3 y 4; la detención no es posible | Móvil + Web | 8.2 |
| Vulnerabilidad explotable (token, checkout, autorización) | 1 (apagar checkout/endpoint), revocación masiva de sesiones, rotación de secretos, 3 (versión mínima) y 4; notificación a Jurídico (plantilla de Ley 1581) | Seg + TI + Web/WP + Jur | SC-066, ST-156 |
| Pedidos o cobros duplicados | 1 (apagar checkout) de inmediato; investigar con Finanzas | Web + Finanzas | NLS-06, TM-027 |
| BFF defectuoso | Reversa del BFF (9.4) | Web + TI | RNF-030, QM-43 |
| Cambio en WordPress defectuoso | Reversa de WordPress (9.5) | WP + TI | — |
| Regla de Cloudflare defectuosa (desafía a la app) | Revertir la regla desde la exportación archivada; no desactivar el WAF general | TI | C3, RA-06 |
| Pasarela Wompi caída o confirmaciones fallando | 1 (apagar checkout); la app conserva el carrito local | Web + Finanzas | RF-044 |
| Clave de subida de Android comprometida | Restablecimiento de la clave de subida (4.2); revocar CI | TI | Verificado |
| Certificado o clave de API de Apple comprometidos | Revocar y regenerar (4.3) | TI | — |
| Caída del endpoint de configuración | La app usa la última configuración válida o la empaquetada; **nunca se bloquea por no poder leerla** | Móvil | SC-044 |

### 9.3 Versión mínima forzada: reglas de uso (cuidado)

| Regla | Justificación |
|---|---|
| No subir el mínimo duro por encima de una versión que **no está disponible aún** en ambas tiendas | Los usuarios quedarían en `/update-required` sin actualización disponible |
| Antes de forzar, comprobar que la corrección llega a Play y a la App Store (el escalonado de Play debe estar al 100 % o el usuario no la recibe) | El enlace de actualización lleva a la tienda; si el usuario aún no recibe la actualización por el escalonado, queda bloqueado |
| Aviso suave (`minSupportedVersion`) primero; 426 solo si es necesario por seguridad o por incompatibilidad | Reduce el impacto |
| Medir el efecto (QM-44: ≤ 5 min) y ensayarlo en staging | QG-D04 |
| La reversa de la propia configuración (bajar el mínimo) es la palanca si se forzó por error | Documentar quién la ejecuta |

### 9.4 Plan de contingencia del BFF

| Elemento | Procedimiento (PROPUESTA) |
|---|---|
| Disparo | Flujo manual con aprobación del entorno `production`, entrada "tag a restaurar" (`ci_cd.md` §4.5) |
| Tiempo objetivo | ≤ 15 min, **ensayado una vez en staging** (QM-43) |
| Artefacto anterior | Conservado en el servidor hasta el siguiente despliegue exitoso (DESCONOCIDO si hoy es así: DO-10) |
| Datos | Sin base de datos propia; los contadores en memoria se pierden (R-NF-01) |
| Contrato | `v1` no se rompe: la reversa es compatible con apps instaladas |
| Degradado | 503 con `Retry-After` y código de error de mantenimiento; la app muestra "servicio no disponible" (no vacío ni 404, RNF-022/023) |
| Caché de borde | Purga selectiva de rutas públicas afectadas; **nunca** cachear privadas (NLS-07) |
| Mantenimiento programado | Aviso por `/config` y ventana fuera de la revisión de tienda |

### 9.5 Plan de contingencia de WordPress

| Elemento | Procedimiento (PROPUESTA) |
|---|---|
| Antes de cada cambio | Copia de seguridad de la base de datos y de los archivos del plugin; humo de login web y checkout en staging |
| Esquema | **Solo aditivo** durante un ciclo (`dbDelta` versionado): volver a la versión anterior del plugin no requiere migración inversa |
| Reversa | Reinstalar la versión anterior del plugin/mu-plugin; si el mecanismo de instalación es copiar archivos (DESCONOCIDO), conservar la versión anterior etiquetada |
| Apagar la superficie móvil sin tocar la web | Constante en `wp-config.php` (`IPR_MOBILE_DISABLED`, propuesta de nombre) que haga responder 503 a `ipr/v1/m/*` sin desactivar `ipr/v1` heredado ni el checkout web |
| Sesiones | La revocación masiva de sesiones (`ipr_auth_sessions`) es una herramienta de incidente (SC-066) |
| Secretos | Rotación con doble valor (WP-16) |
| Prueba | Simulacro en staging (ST-156) |

### 9.6 Comunicación

| Quién | Qué |
|---|---|
| Responsable del incidente (TI) | Decide capa de reversa, coordina |
| Producto | Mensaje en la app (por `/config`) y a clientes |
| Jurídico | Evalúa la notificación por incidentes de datos personales (plantilla en el manual; no se redacta aquí asesoría legal) |
| Gerencia | Aprueba retirar la app de la venta |

---

## 10. Listas de verificación

### 10.1 Lanzamiento (marcar con evidencia archivada; si una casilla absoluta falta, **no se lanza**)

**Calidad y seguridad (puertas absolutas)**

| ☐ | Verificación | Referencia |
|---|---|---|
| [ ] | QG-M01..M12 y QG-B01..B07 en verde en el RC | `ci_cd.md` §7.1 |
| [ ] | QG-R01..R13 y R15 en verde con evidencia | `testing_strategy.md` §7.2 |
| [ ] | NLS-01..NLS-09 sin incumplimientos; CH-01..CH-22 con criterio de cierre | `security_controls.md` §3–§4 |
| [ ] | `npm audit`/OSV ejecutados y revisados: 0 críticas/altas | NLS-04 |
| [ ] | Escaneo de secretos del historial, del binario y de los logs de CI: 0 | ST-020..ST-023 |
| [ ] | Pentest independiente con reprueba: 0 críticos/altos | NL-01, CH-21 |
| [ ] | Aceptaciones de riesgo firmadas (sin *pinning*, sin detección de root, sin atestación, verificación de correo) | CH-22, NLS-09 |
| [ ] | Staging existente y E2E de compra aprobado en Android e iOS con Wompi sandbox; 0 duplicados | NLS-08, QG-R02, R03 |
| [ ] | Reversa del BFF ≤ 15 min y interruptor remoto ≤ 5 min ensayados | QG-D04 |
| [ ] | Cloudflare no desafía a la app; `.well-known` sin desafío; Cloudflare delante de WordPress confirmado | QM-45, C3 |
| [ ] | Monitoreo, alertas y reporte de fallos activos (producción y por *flavor*) | NL-09 |
| [ ] | Condiciones C1..C4 de ADR-001 cumplidas | QG-R15 |

**Firma y cuentas**

| ☐ | Verificación | Referencia |
|---|---|---|
| [ ] | Cuentas de tienda a nombre de Inverprimos con 2FA y ≥ 2 administradores | NL-11, ST-154 |
| [ ] | Clave de subida y certificados en gestor con ≥ 2 custodios; respaldo probado | CH-20 |
| [ ] | Play App Signing activo; huellas registradas en `assetlinks.json` | 4.2 |
| [ ] | Identificador de producción definitivo confirmado | DA-12 |
| [ ] | *Build* producido solo desde el tag firmado; hash, SBOM, símbolos y mapeos archivados | QG-D03 |

**Tiendas y privacidad**

| ☐ | Verificación | Referencia |
|---|---|---|
| [ ] | `targetSdk` = API 36 (o el vigente) y Xcode 26+ | 2 |
| [ ] | Política de privacidad aprobada por Jurídico, en ficha y en la app | NL-07 |
| [ ] | **Data safety** y **App Privacy** coinciden con el tráfico real (contrastadas con la lista de SDK) | QG-D05, ST-132 |
| [ ] | Eliminación de cuenta: ruta en la app **y** página web para Google Play | RF-110, GAP-DO-01 |
| [ ] | Sign in with Apple no requerido (solo cuentas propias) o añadido si hay login social | 6.6 |
| [ ] | Cuenta de demostración vigente, notas de revisión y plan ante pago real (DO-23) | 7 |
| [ ] | Textos legales, de garantía y de estimación aprobados | QG-R13 |
| [ ] | Capturas y ficha con datos sintéticos | 5.3 |

**Operación**

| ☐ | Verificación | Referencia |
|---|---|---|
| [ ] | Manual de incidentes ensayado (revocación masiva, rotación, interruptor de checkout, versión mínima) | SC-066, ST-156 |
| [ ] | Equipo de guardia y canales definidos para el día del lanzamiento | — |
| [ ] | Calendario: sin lanzar en viernes o antes de festivos (propuesta) | — |
| [ ] | Decisión escrita de **go/no-go** firmada por Gerencia, Seg y QA | QG-R, NL |

### 10.2 Postlanzamiento

| Momento | Verificación | Umbral / referencia |
|---|---|---|
| T+1 h | Humo de producción (solo lectura); `/api/health`; `GET /mobile/v1/config`; instalación desde la tienda; App Links | RNF-102 |
| T+24 h | Crash-free, ANR, errores 5xx, p95 del BFF, desafíos de WAF, pedidos duplicados | ≥ 99,5 %; ≤ 0,3 %; < 2 % en 5 min; ≤ 0,1 %; 0 (QM-35, 36, 38, 45) |
| Antes de cada escalón | Condiciones de 8.2; decisión por escrito de subir/mantener/detener | — |
| T+72 h | Reseñas, tickets de soporte, PQRS, calidad de catálogo en la app | QM-69/70 (calidad de datos) |
| T+7 d | Revisar desempeño y capacidad del BFF; degradación de la web ≤ 10 % | QM-31..33 |
| T+30 d | Crash-free 30 días; ANR; revisión de métricas mensual; retrospectiva; actualizar este documento | QM-35, 36 |
| Mensual | Dependencias, acciones de CI, SCA programado, requisitos de tiendas (revisión anual de `targetSdk`/Xcode antes de cada plazo) | RNF-080, RNF-094 |
| Trimestral | Revisión de accesos y custodios; ensayo de recuperación | 4.4 |
| Anual | Rotación de secretos del servidor, vigencia de certificados Apple, mejora anual de clave de Play | `environments.md` §4 |

---

## 11. Decisiones pendientes, huecos, supuestos y riesgos

### 11.1 Hueco detectado en la documentación

| ID | Hueco | Impacto | Propuesta |
|---|---|---|---|
| GAP-DO-01 | Google Play exige un **enlace web** para solicitar la eliminación de cuenta y datos (declarado en Data safety), además de la ruta dentro de la app. Los requisitos (RF-110, WP-09) describen solo la ruta en la app. | Rechazo o suspensión por incumplimiento de política | Añadir un requisito y un cambio en `ipr-frontend` (página pública de solicitud de eliminación) y alinear el texto con SUP-H-11. Registrar en `decisiones_pendientes.md` |

### 11.2 Decisiones pendientes

| ID | Decisión | Recomendación | Quién decide | Bloquea |
|---|---|---|---|---|
| DO-21 | Territorios de distribución (¿solo Colombia?) | Decidir con Gerencia; condiciona DSA | Gerencia | Fichas |
| DO-22 | Clave de firma de Android: la genera Google | Sí | TI + Gerencia | Primera subida (después no se cambia en pruebas abiertas/producción) |
| DO-23 | Cómo manejar a un revisor que intente pagar | Opción A inicial; B/C si Apple lo exige | Producto + Finanzas + Seg | Envío a revisión |
| DO-24 | Aprobar los porcentajes y ventanas del escalonado | Aprobar tras el piloto | QA + TI + Producto | Producción |
| DO-25 | Aprobar el procedimiento de reversa y los nombres de interruptores | Aprobar | Resp. técnico + Seg | QG-D04 |
| DO-26 | Firma de iOS: administrada en la nube o certificado importado (DO-12) | Evaluar la primera | TI + Móvil | Release iOS |

Siguen abiertas fuera de este documento: D-14 (titularidad y custodia), DA-12 (identificador de producción), DN-02 (proveedor de fallos), D-12 (política y retención), C1..C4 de ADR-001 y H-12 (staging).

### 11.3 Supuestos

| ID | Supuesto |
|---|---|
| SUP-H-10 | Sin compra de invitado en el MVP: la revisión de tiendas necesitará una cuenta de demostración. |
| SUP-H-11 | Eliminación de cuenta sin periodo de gracia y supresión ≤ 15 días hábiles: el texto de la tienda y la política deben coincidir con lo que se apruebe. |
| SUP-H-12 | Staging con Wompi sandbox será autorizado. |
| SUP-DO-08 | La cuenta de Google Play será de **organización** y no de **persona**; si fuese personal, rige la prueba cerrada de 12 testers/14 días (verificado). |
| SUP-DO-09 | La app se distribuirá en Colombia (DO-21). |

### 11.4 Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| RD-17 | Rechazo o suspensión por Data safety / App Privacy inexactas | Contrastar con tráfico real y lista de SDK (ST-132); Jurídico aprueba |
| RD-18 | Falta de la página web de eliminación (GAP-DO-01) | Resolver antes del envío |
| RD-19 | La primera versión de Play no se puede detener | Piloto previo; interruptores; versión mínima |
| RD-20 | Cuenta de revisión en producción con permisos indebidos o datos reales | Cuenta sintética sin rol administrativo (NLS-05); revocar tras la revisión |
| RD-21 | Apple cuestiona el pago de bienes físicos por navegador externo (NO VERIFICADO) | Notas de revisión; verificar la directriz antes del envío |
| RD-22 | El revisor completa un pago real | DO-23 |
| RD-23 | Forzar una versión mínima sin que la corrección esté disponible | 9.3 |
| RD-24 | Pérdida de la clave de subida o de custodios | Restablecimiento verificado; ≥ 2 custodios; ensayo |
| RD-25 | Cambios de requisitos de tienda posteriores a este documento (fecha de consulta 2026-11-18) | Revisión anual y antes de cada plazo (RNF-080) |
| RD-26 | Las huellas de `assetlinks.json` no incluyen una huella nueva tras una mejora de clave | Añadir huellas antes de que entren en vigor (4.2) |

*Fin del documento.*

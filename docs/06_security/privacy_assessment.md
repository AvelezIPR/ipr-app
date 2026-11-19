# Evaluación de privacidad y protección de datos personales — App móvil IPR (enfoque Colombia)

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Seguridad / Privacidad. **No se programa nada.** |
| **Fecha** | 2026-11-18 |
| **Autor / rol** | Analista de Privacidad y Protección de Datos (técnico). **No es abogado.** |
| **Estado** | BORRADOR para validación del equipo jurídico de IPR. Este documento **no** es un dictamen legal ni afirma cumplimiento: identifica obligaciones, responsabilidades y puntos que el jurídico **debe** validar. |
| **Insumos** | `05_api/authentication.md` (AUTH), `api_contracts.md` (APIC), `openapi.yaml` (OAS), `03_architecture/*` (FLU, OV, DEP), `00_discovery/*` (COD, INV), `02_requirements/*` (RF, RNF, AC), `project/decisiones_pendientes.md`, `04_database/data_dictionary.md` (DD) y `data_model.md` (DM) — **ambos existen y se usaron**; código de solo lectura de `ipr-frontend` (`wp-snippets/*.php`, `src/app/api/pqrs`, `src/app/api/newsletter`, `src/lib/auth.ts`). **No se abrió ni se leyó `.env`.** |
| **No se hizo** | No se descargaron ni leyeron los PDF legales de IPR (términos, política de datos personales, etc.); se piden a IPR (§11.2). No se contactaron sistemas de producción. No hay datos personales reales en este documento. |

## 0. Cómo leer este documento

### 0.1 Etiquetas

| Etiqueta | Significado |
|---|---|
| **HECHO** | Observado en código o documentos del proyecto, con evidencia citada. |
| **SUPUESTO** | Inferencia razonable no confirmada; se indica cómo confirmarla. |
| **PROPUESTA** | Control o diseño sugerido; no existe hoy ni está aprobado. |
| **DECISIÓN PENDIENTE** | Requiere aprobación humana (jurídico, finanzas, producto, TI). |
| **RIESGO** | Evento adverso identificado (matriz en §9). |
| **VERIFICADO (primaria)** | Texto leído de una fuente oficial o de repositorio normativo oficial en esta sesión (fuente citada). |
| **VERIFICADO (secundaria)** | Confirmado solo por resúmenes de terceros o por el buscador; no sustituye al texto oficial. |
| **NO VERIFICADO** | No se pudo comprobar. No debe usarse como base sin validación del jurídico. |

### 0.2 Abreviaturas de evidencia

Código de `ipr-frontend` (solo lectura): `AR` = `wp-snippets/ipr-auth-rest.php` · `HO` = `wp-snippets/ipr-cart-handoff.php` · `RM` = `wp-snippets/ipr-ruleta-midea.php` · `RS` = `wp-snippets/ipr-raspa-y-gana-samsung.php` · `PQ` = `src/app/api/pqrs/route.ts` · `NL` = `src/app/api/newsletter/route.ts` · `AU` = `src/lib/auth.ts`. Se citan líneas como `AR:208-209`. Documentos del proyecto: `AUTH`, `APIC`, `OAS`, `FLU`, `OV`, `DEP` (deployment_architecture), `COD`, `INV`, `DD` (data_dictionary, entidades `E01`…`E41`), `DM` (data_model), `RF-xxx`, `RNF-xxx`, `AC-xxx`.

### 0.3 Lo que este documento NO hace

- No interpreta si un tratamiento es lícito ni si IPR "cumple". Donde hay una norma verificada se cita su texto; la aplicación al caso concreto queda marcada para el jurídico.
- No fija plazos de conservación. Todo plazo de retención que no sea técnico (sesiones, logs, contadores) queda como **DECISIÓN PENDIENTE (D-12)**.
- No califica un dato como "sensible" en el sentido del art. 5 de la Ley 1581; solo señala cuáles son de **riesgo alto** por daño potencial (cédula/NIT, texto libre).

---

## 1. Resumen ejecutivo

| # | Hallazgo | Tipo | Dónde |
|---|---|---|---|
| 1 | La app tratará datos personales de clientes (identificación, contacto, direcciones, historial de compras, identificadores de dispositivo/sesión, IP) con Inverprimos S.A.S. como **responsable**; los terceros (Cloudflare, hosting, SMTP, Wompi, proveedor de fallos) requieren definir rol (encargado/responsable) y contrato. | HECHO / DECISIÓN PENDIENTE | §2, §3 |
| 2 | La política de tratamiento vigente y los términos **no se han leído** (D-12 abierta). No se puede afirmar que cubran la app (dispositivo, fallos, push, ubicación, finalidades separadas). | RIESGO | §4, §11 |
| 3 | El texto verificado de la Ley 1581 (art. 4 c, 9, 10) no incluye "contrato" ni "interés legítimo" como excepción a la autorización. **Ruta prudente propuesta:** autorización previa, expresa e informada para cada finalidad, con prueba. | PROPUESTA (validar) | §4 |
| 4 | El registro actual no guarda prueba de aceptación ni versión de política (`AUTH` A-07); PQRS y boletín solo "validan" un campo o ni siquiera lo exigen (`PQ:22-37`, `NL:30,80`). La app nueva sí propone `ipr_consents` (`AUTH` §8.4). | HECHO / PROPUESTA | §3, §4 |
| 5 | La cédula/NIT es el dato de mayor riesgo del flujo de compra: no se persiste en el perfil hoy (`DD` E02) pero viaja en el ticket de 60 s y se copia al pedido (`HO:322-323,340-341`; `DM` RM-01). | HECHO / RIESGO | §3 F-04 |
| 6 | La eliminación de cuenta debe ser iniciable **dentro de la app** (Apple, verificado) y con enlace web (Google, verificado). Qué se retiene por obligación legal y por cuánto es **DECISIÓN PENDIENTE del jurídico y Finanzas**; ningún plazo de este documento es legal. | DECISIÓN PENDIENTE | §5 |
| 7 | Cloudflare delante del BFF y de WordPress (`INV` §2.1) y el proveedor de fallos (DN-02) implican **transmisión internacional** probable; hosting (DigitalOcean/Plesk) y SMTP: país **DESCONOCIDO**. | SUPUESTO / DECISIÓN PENDIENTE | §6 |
| 8 | Si IPR está obligada al RNBD (umbral de activos, **DESCONOCIDO**), las bases nuevas deben registrarse **dentro de los dos meses siguientes a su creación** (art. 2.2.2.26.3.1, verificado). Conviene evaluar antes del lanzamiento. | DECISIÓN PENDIENTE | §2.3, §11 |
| 9 | Hay proyectos de reforma de la Ley 1581 en el Congreso (2025–2026); su estado a hoy es **NO VERIFICADO**. Una reforma podría cambiar transferencias internacionales y evaluaciones de impacto. | RIESGO | §1.1, §9 |
| 10 | Las etiquetas de Apple y Google deben coincidir con el tráfico real (incluidos SDKs). Se entrega borrador A VALIDAR. | PROPUESTA | §8 |

**Cifras:** 20 flujos con datos personales (14 del MVP + 6 condicionales o fuera de la app); 20 riesgos de privacidad; 36 preguntas/decisiones para el jurídico (§10); 16 documentos que IPR debe entregar (§11).

### 1.1 Marco normativo consultado y estado de verificación

| Norma / fuente | Qué se usó | Verificación | Fuente |
|---|---|---|---|
| **Ley Estatutaria 1581 de 2012** (17-oct-2012) | Definiciones (art. 3), principios (art. 4), datos sensibles (5, 6), menores (7), derechos (8), autorización (9), excepciones (10), deber de informar (12), consultas (14), reclamos (15), procedibilidad (16), deberes de responsables (17) y encargados (18), SIC (19–21), sanciones (23), RNBD (25), transferencias (26). | **VERIFICADO (primaria)** contra la copia del Repositorio Normativo del Archivo General de la Nación, generada el 08-11-2022, con nota "Vigente; reglamentado por Decreto 886 de 2014 y parcialmente por Decreto 1377 de 2013". **NO VERIFICADO** que no haya modificaciones posteriores a esa fecha. | PDF del Repositorio Normativo (AGN), consultado 2026-11-18 vía `transparencia.ipcc.gov.co`. Los portales de Función Pública y de la Secretaría del Senado **no respondieron** (error de certificado / conexión), por lo que no se pudo contrastar en SUIN-Juriscol ni Función Pública. |
| **Decreto 1074 de 2015, Cap. 25** (origen Decreto 1377 de 2013) | Recolección (2.2.2.25.2.1), autorización (…2.2), sensibles (…2.3), modo de obtener (…2.4), **prueba** (…2.5), revocatoria/supresión (…2.6), limitación temporal (…2.8), menores (…2.9), políticas (…3.1), aviso (…3.2–3.5), procedimientos (…3.6), legitimación y acceso (…4.1–4.4), transferencia/transmisión (…5.1–5.2), responsabilidad demostrada (…6.1–6.2). | **VERIFICADO (primaria)** en la compilación publicada por Colpensiones (normograma), con "Última actualización 5-ago-2020". **NO VERIFICADO** el texto consolidado a nov-2026. | `normativa.colpensiones.gov.co/colpens/docs/decreto_1074_2015_pr025.htm` y `…pr026.htm` |
| **Decreto 1074 de 2015, Cap. 26** (origen Decreto 886 de 2014, modificado por Decreto 090 de 2018) | Quién debe inscribir bases (2.2.2.26.1.2: sociedades y ESAL con activos totales **superiores a 100.000 UVT** y personas jurídicas públicas); cada base se inscribe de forma independiente (…1.3); información mínima (…2.1); plazo para bases creadas después de los plazos iniciales: **dos meses desde su creación** (…3.1). | **VERIFICADO (primaria)** en la misma compilación (act. 2020). El monto de activos de Inverprimos es **DESCONOCIDO**. | `…decreto_1074_2015_pr026.htm` |
| **Circular Externa 002 de 2025 (SIC)** (7-oct-2025; D.O. 53.268 del 9-oct-2025) | Instrucciones sobre procesos de transferencia de tecnología que involucran datos personales: verificación previa de funcionalidades que tratan datos (§1), responsabilidad demostrada (§2), privacidad desde el diseño y por defecto, minimización y seudonimización (§3), cláusulas contractuales sobre responsabilidades, seguridad, garantías de transmisiones/transferencias internacionales y auditoría (§4, 4.3). | **VERIFICADO (primaria)** (normograma MinTIC). Es relevante al contratar proveedores tecnológicos (SDKs, nube, fallos). | `normograma.mintic.gov.co/mintic/compilacion/docs/circular_superindustria_0002_2025.htm` |
| **Circular Externa 005 de 2017 (SIC)** y 008 de 2017; Título V, Cap. 3 de la Circular Única | Estándar de "nivel adecuado" y lista de países (numeral 3.2). La lista original (2017) incluía a Estados Unidos; se añadió Japón (CE 008/2017) y Australia (2018, proyecto). | **VERIFICADO (secundaria)**. **NO VERIFICADO** el texto y la lista vigentes a nov-2026 (la versión más reciente hallada del Título V es de 29-sep-2022 y no se pudo abrir). | Boletines SIC y resúmenes de terceros (Holland & Knight, Buk). |
| **Ley 1266 de 2008** (habeas data financiero) | La Ley 1581 la excluye de su ámbito (art. 2, lit. e: "bases de datos y archivos regulados por la Ley 1266 de 2008"). | **VERIFICADO (primaria)** solo la exclusión. **SUPUESTO:** no aplica a la app mientras IPR no reporte ni consulte información crediticia/financiera de clientes. Confirmar con el jurídico (ver J-31). | Ley 1581, art. 2. |
| **Proyectos de reforma de la Ley 1581** (P.L. 214 y 274 de 2025 Cámara, acumulados; P.L.E. 282 de 2026 Cámara) | Posible rediseño de transferencias internacionales (dos niveles) y evaluación de impacto como obligación expresa. | **VERIFICADO (secundaria)** (resúmenes de prensa y gacetas indexadas). **NO VERIFICADO** el estado actual del trámite. | Búsqueda web 2026-11-18. |
| **Apple** — Guideline 5.1.1(v) (eliminación de cuenta) y *App Privacy Details* | Eliminación iniciable en la app; web solo si completa el proceso y enlazada directamente; informar qué se retiene y plazos; política de privacidad obligatoria; SDKs de terceros cuentan. | **VERIFICADO (primaria)** (developer.apple.com, 2026-11-18). Fecha de entrada en vigor: no figura en la página (**NO VERIFICADO**). | `developer.apple.com/support/offering-account-deletion-in-your-app/`; `…/app-store/app-privacy-details/` |
| **Google Play** — *Data safety* y requisitos de eliminación de cuenta | Formulario obligatorio para todas las apps; SDKs cuentan; cifrado en tránsito; eliminación: ruta en la app + enlace web en Play Console; retención debe informarse. | **VERIFICADO (primaria)** (support.google.com, 2026-11-18). | `support.google.com/googleplay/android-developer/answer/10787469` y `…/13327111` |
| **Firebase Crashlytics** (privacidad) | Recoge UUID de instalación, ID de Firebase Installations, trazas, datos de dispositivo (modelo, SO, si está rooteado); procesamiento "en cualquier centro de datos de Google" salvo que el servicio ofrezca selección (no figura para Crashlytics); retención 90 días; Google actúa normalmente como encargado. | **VERIFICADO (primaria)**. | `firebase.google.com/support/privacy` |
| **Sentry** (ubicación de datos) | Si ofrece región UE/EE. UU. y si se puede cambiar. | **NO VERIFICADO** (la página consultada devolvió "no encontrada"). | — |
| **Guías de la SIC** (responsabilidad demostrada, privacidad desde el diseño, reporte de incidentes en el RNBD, plazo de actualización del RNBD) | — | **NO VERIFICADO**: no se abrieron los textos. Solo se verificó el principio en los arts. 2.2.2.25.6.1–6.2 del Decreto 1074 y en la CE 002/2025. Un resumen de terceros menciona actualización del RNBD "dentro de los 10 primeros días hábiles del mes siguiente" a cambios sustanciales (Circular 003 de 2018): **NO VERIFICADO**. | — |
| **Ley 1480 de 2011** (consumidor), **Ley 527 de 1999** (mensajes de datos) | Posibles obligaciones de información y de conservación de la compra a distancia; Ley 527 se cita en el Decreto (art. 2.2.2.25.3.4) para medios electrónicos. | **NO VERIFICADO** (no se leyó; se listan solo para que el jurídico las considere). | — |

---

## 2. Roles, responsabilidades y encargados

### 2.1 Responsable y encargados

| Rol | Quién | Estado | Evidencia / nota |
|---|---|---|---|
| **Responsable del tratamiento** (art. 3 e: decide sobre la base de datos y/o el tratamiento) | **Inverprimos S.A.S.** (NIT publicado en la web; no se reproduce aquí). Decide finalidades y medios de la app, el BFF y WordPress. | **HECHO** (titularidad de IPR) / **DECISIÓN PENDIENTE** de formalizar quién dentro de IPR es el área de atención de titulares (art. 2.2.2.25.4.4). | `OV` §2; art. 3 Ley 1581 |
| **Encargado** (art. 3 d: trata por cuenta del responsable) | Proveedores que traten datos de IPR solo por instrucción de IPR. Ver tabla 2.2. | **SUPUESTO** por proveedor; el rol real depende del contrato y de si el proveedor usa los datos para fines propios. | art. 3, 18 Ley 1581; art. 2.2.2.25.5.2 Decreto 1074 |
| **Responsable independiente / tercero que recibe datos (transferencia)** | Wompi (datos de pago del pagador), Meta/WhatsApp (conversación del usuario), Apple y Google (cuentas de tienda, notificaciones push vía APNs/FCM si se adoptan). | **SUPUESTO** a validar por el jurídico (puede variar con los términos de cada proveedor). | `COD` §2; `RF-053` |
| **Autoridad** | Superintendencia de Industria y Comercio (SIC), Delegatura para la Protección de Datos Personales. | **VERIFICADO** | art. 19, 21 Ley 1581 |

### 2.2 Terceros y encargados potenciales (qué datos ven y qué valida el jurídico)

| Tercero | Función | Datos que puede ver | Rol probable | País / región | Contrato / cláusulas que el jurídico valida | Evidencia |
|---|---|---|---|---|---|---|
| **Wompi** (pasarela, vía WooCommerce, en navegador seguro) | Cobro | Datos del pagador, medio de pago, importe, referencia del pedido; correo/teléfono/cédula si el plugin los envía (**DESCONOCIDO**). La app y el BFF **no** reciben datos de pago (`RF-053`). | Responsable independiente respecto de los datos de pago (**SUPUESTO**); IPR, respecto de los datos del pedido que le entrega. | **DESCONOCIDO** (verificar si el procesamiento es en Colombia). | Términos del comercio; qué datos del cliente envía el plugin; conservación; cómo atiende supresión; confirmación de pago por webhook (D-02). | `COD` §2; `DD` E15 |
| **Cloudflare** (CDN/WAF delante del BFF y de WordPress) | Entrega, WAF, límites | IP del cliente y **todo el contenido de las solicitudes**, porque en modo proxy termina el TLS (incluye contraseñas en el login y datos del perfil). **SUPUESTO** (comportamiento estándar del modo proxy; confirmar configuración). | Encargado (transmisión) | Red global; centros de datos fuera de Colombia (**SUPUESTO**). | Contrato/DPA de Cloudflare y cláusulas de transmisión internacional; retención de logs de borde; plan contratado (**DESCONOCIDO**, MED-15). | `INV` §2.1; `DEP` §3; `DM` fila "IP del cliente" |
| **DigitalOcean** (servidor del BFF Next.js) | Hosting del BFF, logs, caché en memoria | Todo el tráfico `/mobile/v1` en claro dentro del servidor; logs JSON seudonimizados (`E33`); correo PQRS en tránsito hacia SMTP. | Encargado | **DESCONOCIDA** (región del centro de datos). | Términos/DPA; región; copias de seguridad; acceso de soporte. | `COD` §2; `DEP` |
| **Hosting de WordPress (Plesk)** — proveedor **DESCONOCIDO** | Base de datos de clientes, pedidos, tablas `ipr_*`, WP-Cron | **Todos** los datos de cuenta, direcciones, pedidos, sesiones, consentimientos, auditoría, campañas. | Encargado | **DESCONOCIDO** | Contrato de hosting; ubicación; copias de seguridad y su retención (afecta la supresión); acceso administrativo. | `COD` §2; `DEP` |
| **Proveedor SMTP** — **DESCONOCIDO** | Envío de PQRS y boletín al buzón corporativo; correos transaccionales de WordPress (recuperación, confirmación de eliminación) | Contenido completo de PQRS (nombre, correo, teléfono, pedido, mensaje), altas de boletín. | Encargado | **DESCONOCIDO** | Contrato; retención del buzón; cifrado en tránsito; quién accede al buzón. | `PQ:107-116`; `NL:70-83` |
| **Proveedor de reporte de fallos** (Firebase Crashlytics o Sentry; DN-02, ADR-010) | Fallos y ANR | UUID de instalación, ID de Firebase Installations (Crashlytics), trazas, modelo y SO, estado root/jailbreak (Crashlytics); **sin PII por diseño** (RNF-097). | Encargado (Google actúa normalmente como encargado en Firebase, según su página) | Crashlytics: centros de datos de Google en cualquier país (verificado); Sentry: **NO VERIFICADO** | DPA del proveedor (Firebase Data Processing and Security Terms, mencionados en su página); región; retención (Crashlytics: 90 días, verificado); depuración de PII. | `OV` ADR-010; `RNF-097`, `RNF-061` |
| **Apple App Store / Google Play** | Distribución, cuentas de desarrollador, notificaciones push (APNs/FCM, fase 2) | Datos de la cuenta de tienda del usuario (propios); tokens de push (fase 2). | Responsables propios; para push, encargado de transmisión (**SUPUESTO**) | EE. UU. y otros (**SUPUESTO**) | Acuerdos de desarrollador; ficha de privacidad coherente con el tráfico; titularidad de cuentas a nombre de Inverprimos (D-14). | `RNF-055` |
| **Meta / WhatsApp** | Canal de asesoría con mensaje prellenado (`wa.me`) | El usuario envía su número y su mensaje a la cuenta de IPR; el producto consultado va en el mensaje prellenado. | Responsable propio (Meta); IPR trata la conversación que recibe. | EE. UU. y otros (**SUPUESTO**) | Qué producto de WhatsApp usa IPR (app Business, API, CRM) y quién atiende (**DESCONOCIDO**, PA-07); retención de chats; uso de celulares personales de asesores (D-09). | `RF-094`, `RF-064`; `COD` §4 |
| **Google reCAPTCHA** (solo campaña Raspa y Gana, **fuera del MVP**) | Anti-bot | Datos de interacción e IP al cargar el widget. | Responsable propio / encargado (**SUPUESTO**) | EE. UU. y otros | Condiciones de reCAPTCHA; cobertura en la política. | `RS:56-58,584` |
| **GitHub Actions / repositorios** | CI/CD | No debe contener datos personales de clientes. **RIESGO** si hay `.env` con credenciales o datos en el repositorio. | Encargado (infraestructura) | EE. UU. | Confirmar que no hay datos de clientes en repos, artefactos ni logs de CI. | `COD` §2 |
| **Wordfence** (plugin de WordPress) | Fuerza bruta y WAF | IP, usuario/correo de intentos de login, posible envío a servicios del fabricante según su configuración (**DESCONOCIDO**). | **DESCONOCIDO** | **DESCONOCIDO** | Configuración actual, versión (gratuita/de pago) y qué datos reporta a terceros (MED-10). | `AUTH` §13; `COD` H-04 |

### 2.3 Registro Nacional de Bases de Datos (RNBD)

| Punto | Estado | Acción / pregunta |
|---|---|---|
| ¿Está Inverprimos obligada a inscribir bases? | Depende de que sus **activos totales superen 100.000 UVT** (art. 2.2.2.26.1.2, verificado). Activos de IPR: **DESCONOCIDO**. | Jurídico/Contabilidad confirman el umbral (J-03). |
| ¿Hay bases ya inscritas? | **DESCONOCIDO** (la inscripción RNBD es documento pendiente, §11.2). | IPR entrega constancia y bases inscritas (J-03). |
| ¿Las bases de la app son nuevas o ya están cubiertas? | **DECISIÓN PENDIENTE.** Candidatas: clientes (WordPress), pedidos, consentimientos, dispositivos/sesiones, auditoría, PQRS, boletín, campañas. Cada base se inscribe de forma independiente (art. 2.2.2.26.1.3). | Jurídico define el catálogo de bases y qué cambia con la app (`RNF-064`). |
| Plazo para bases nuevas | Si hay obligación: dentro de los **dos meses siguientes a su creación** (art. 2.2.2.26.3.1, verificado). | Planificar antes del piloto. |
| Actualizaciones y reporte de incidentes | Reglas operativas de la SIC: **NO VERIFICADO** (no se abrió la Circular Única, Título V). El deber de **informar a la autoridad** cuando haya violaciones a los códigos de seguridad con riesgo para los titulares sí está en el art. 17 n y 18 k de la Ley 1581 (verificado). | Definir protocolo de incidentes con canal a la SIC (J-26). |

---

## 3. Inventario de datos personales por flujo

Convención de la tabla maestra: **Base/autorización (propuesta)** = lo que este análisis propone **para validar**; ninguna celda afirma que hoy exista o que sea suficiente. **Retención** repite lo que proponen los documentos del proyecto (técnico) o marca **D-12**.

### 3.1 Tabla maestra (20 flujos)

| ID | Flujo | Estado | Finalidad | Base/autorización (propuesta) | Sistema de registro | Encargados / terceros | Retención | Eliminación / supresión |
|---|---|---|---|---|---|---|---|---|
| **F-01** | Registro de cuenta | MVP | Crear la cuenta del cliente para comprar y consultar pedidos | Autorización expresa en el registro, casilla sin marcar, con versión de política y términos (RF-039, RNF-056) | WordPress (`users`, `usermeta`) + `ipr_consents` | Cloudflare, DigitalOcean, hosting WP | Mientras exista la cuenta (`RET-01`); excepciones **D-12** | Eliminación de cuenta (F-06) |
| **F-02** | Sesión, dispositivo y tokens | MVP | Autenticar y mantener sesión por dispositivo; revocación | Parte de la prestación del servicio autorizado; informar en la política (**D-12**) | WordPress (`ipr_auth_sessions`, meta `_ipr_auth_token_*`); app (secure storage) | Cloudflare, hosting WP | Sesiones: borrar a los 30 días de vencidas/revocadas (`RET-03`, propuesta técnica) | Revocación inmediata; borrado local; filas al `delete_user` |
| **F-03** | Perfil y direcciones (incluye cédula/NIT si se decide) | MVP | Prellenar envío y facturación; contacto del pedido | Autorización en el registro; edición por el titular | WordPress (`usermeta` `billing`/`shipping`) | Cloudflare, hosting WP | Mientras exista la cuenta (`RET-01`) | Eliminación de cuenta; edición/borrado por el titular |
| **F-04** | Pedidos, checkout y pago (Wompi) | MVP | Cumplir la compra, facturar, soporte posventa | Ejecución del contrato + autorización; **retención contable: D-12** | WooCommerce (pedidos); transient de *handoff* 60 s; Wompi | Wompi, Cloudflare, hosting WP, SMTP (correos de pedido) | Pedido: `RET-02` **D-12 (Jurídico + Finanzas)**; ticket 60 s | Anonimizar lo no exigible; conservar soporte contable (**D-12**) |
| **F-05** | Recuperación de contraseña y correos transaccionales | MVP | Restablecer acceso; avisar cambios de correo/eliminación | Parte del servicio | WordPress (`retrieve_password`) | SMTP de WordPress (**DESCONOCIDO**) | Registro de evento 90 días (`RET-04`) | Eventos expiran; correos en buzón según **D-12** |
| **F-06** | Eliminación de cuenta | MVP | Atender supresión/revocatoria | Derecho del titular (art. 8 e; art. 2.2.2.25.2.6) | WordPress (`_ipr_account_state`, solicitud de privacidad de WP) | Hosting WP, SMTP | Registro mínimo de la solicitud: **D-12** (`RET-15`) | Ver §5.3 |
| **F-07** | Consentimientos y prueba de autorización | MVP | Acreditar autorizaciones (art. 9, 12 par., 17 b; art. 2.2.2.25.2.5) | Obligación legal de conservar prueba | WordPress (`ipr_consents`); `GET /config` (versiones) | Hosting WP | Mientras haya tratamiento + plazo posterior: **D-12** (`RET-06`) | Registro mínimo tras supresión: **D-12** |
| **F-08** | PQRS | MVP | Atender peticiones, quejas, reclamos y sugerencias | Autorización al enviar (hoy **no** exigida por `PQ:22-37`); contrato propone `acceptsDataPolicy` (EP-27) | Buzón corporativo (SMTP); **no** se persiste en base | SMTP, DigitalOcean (BFF) | Buzón: **DESCONOCIDA** (`RET-12`, **D-12**) | Según política del buzón (**D-12**) |
| **F-09** | WhatsApp y canales de contacto | MVP | Asesoría, cotización de productos sin precio | El usuario inicia el chat; IPR trata lo que recibe: informar en política | WhatsApp de IPR (**DESCONOCIDO** cómo se gestiona) | Meta | **DESCONOCIDA** | Canal de derechos (F-14) |
| **F-10** | Reporte de fallos (crash reporting) | MVP | Estabilidad y soporte técnico | **Pregunta J-12**: ¿requiere autorización si hay identificadores seudónimos? Propuesta: aviso + opción | Proveedor de fallos (DN-02) | Google/Firebase o Sentry | Crashlytics 90 días (verificado en su página) | Según proveedor; sin PII por diseño |
| **F-11** | Logs técnicos del BFF y borde (Cloudflare) | MVP | Seguridad, diagnóstico, rendimiento | Informar en política; minimización | DigitalOcean (logs JSON); Cloudflare | Cloudflare, DigitalOcean | Logs BFF ≤ 90 días (`RET-07`, propuesta); borde **DESCONOCIDA** | Caducidad; seudónimos (HMAC) |
| **F-12** | Auditoría de seguridad y anti fuerza bruta | MVP | Detectar abuso, investigar incidentes (RNF-105) | Informar en política; interés de seguridad (**D-12**) | WordPress (`ipr_auth_events`, `ipr_auth_throttle`) | Hosting WP; Wordfence (**DESCONOCIDO**) | Auditoría 90 días (`RET-04`); contadores 24 h (`RET-05`) — propuestas técnicas | Expiración; evento de eliminación: **D-12** |
| **F-13** | Instalación y almacenamiento local en el dispositivo | MVP | Funcionamiento de la app, carrito, caché | Parte del servicio; sin PII persistente salvo tokens | Dispositivo (Keychain/Keystore, Hive, prefs) | Ninguno | Hasta cerrar sesión/eliminar/desinstalar (`RET-09/10/14`) | Borrado local inmediato (RNF-062) |
| **F-14** | Canal de derechos del titular | MVP (Should) | Consultas, reclamos, actualización, supresión, revocatoria (RF-111) | Obligación legal | Buzón corporativo / formulario (**DESCONOCIDO**) | SMTP | Radicado y respuesta: **D-12** | Según **D-12** |
| **F-15** | Medición de uso / analítica agregada (RF-065, PA-08) | Condicional (apagado hasta decidir) | Estimar demanda de "Más información" | Autorización específica (**D-12**, PA-08) | Por definir | Por definir | **DESCONOCIDA** | Por definir |
| **F-16** | Ubicación para "sede más cercana" (RF-078) | Fase 2 | Ordenar sedes por cercanía | Permiso del SO + aviso y autorización; ubicación aproximada, "mientras se usa" (RNF-060) | Solo en el dispositivo (propuesta) | Ninguno (propuesta) | No se envía ni se guarda en servidor (propuesta) | N/A si no sale del dispositivo |
| **F-17** | Notificaciones push (RF-090–093) | Fase 2 | Estado de pedido; promociones solo con consentimiento | Consentimiento por categoría, separado y sin marcar (RNF-066) | WordPress (token de push, `N-14`) | Apple/Google (APNs/FCM) | **D-12** | Revocación desactiva y borra el token |
| **F-18** | Boletín (newsletter) (RF-101) | Fase 2 | Mercadeo por correo | Autorización de mercadeo separada; prueba | Buzón corporativo (hoy) | SMTP | **DESCONOCIDA** (`RET-12`) | Baja + supresión (**D-12**) |
| **F-19** | Campañas (ruleta Midea, raspa Samsung) | Fuera de la app (web existente; RF-103 Won't) | Participación en promociones | Autorización propia y términos de la campaña (hoy casilla de aceptación) | WordPress (tablas `ipr_ruleta_*`, `ipr_raspa_samsung_*`) | Google reCAPTCHA (raspa) | **DESCONOCIDA** (`RET-13`) | Sin política (**D-12**) |
| **F-20** | Directorio de contacto de asesores (web, no app) | Fuera de la app (RF-102 Won't) | Contacto comercial por ciudad | Autorización de los empleados (**D-12**) | Archivos del repositorio web | — | Sin plazo (`RET-11`) | Edición manual |

### 3.2 Detalle de datos por flujo (con evidencia)

Categorías (de `DD` §0.2): `PERSONAL`, `PERSONAL-ALTO` (riesgo alto por daño potencial; **no** implica "sensible" del art. 5), `SECRETO`, `INTERNO`, `PÚBLICO`.

#### F-01 Registro

| Dato | Categoría | Obligatorio | Evidencia |
|---|---|---|---|
| Correo electrónico | PERSONAL | Sí | `AR:181-206`; `OAS` RegisterRequest; `DD` E01 |
| Nombre y apellido | PERSONAL | Sí (contrato); opcional hoy | `AR:208-209`; `DD` E01 |
| Contraseña (viaja en claro por HTTPS; se guarda solo su *hash*) | SECRETO | Sí | `AR:318`; `DD` E01 `user_pass`; AC-038-8 |
| Aceptación de términos y política (versiones) | INTERNO (prueba de consentimiento) | Sí (contrato) | `APIC` EP-02; `AUTH` §10, §8.4 |
| `X-Device-Id`, plataforma, versión | PERSONAL (identificador indirecto) | Sí | `APIC` cabeceras; `AUTH` §4 |
| IP del cliente (auditoría) | PERSONAL | Sí (servidor) | `AUTH` §8.2 `ip_address` |
| Nombre de usuario generado por WooCommerce | PERSONAL | Interno | `AR:198`; `DD` E01 |

#### F-02 Sesión, dispositivo y tokens

| Dato | Categoría | Dónde | Evidencia |
|---|---|---|---|
| Hash SHA-256 de access/refresh token | SECRETO | `ipr_auth_sessions` | `AUTH` §8.1 |
| `device_id` (UUID v4 aleatorio, sin datos de hardware) | PERSONAL (indirecto) | App (secure storage), `ipr_auth_sessions`, cabecera | `AUTH` §4; `FLU` §8 |
| `device_label` (plataforma + versión de SO, sin modelo ni nombre) | INTERNO | `ipr_auth_sessions` | `AUTH` §4, §8.1 |
| `user_id` | PERSONAL (indirecto) | `ipr_auth_sessions` | `AUTH` §8.1 |
| Token web heredado (hash) | SECRETO | `usermeta` | `AR:47-48` |
| Refresh token en el dispositivo | SECRETO | Keychain/Keystore, sin copia de seguridad | `FLU` §8; RNF-034/035 |

#### F-03 Perfil y direcciones

| Dato | Categoría | Evidencia |
|---|---|---|
| Nombre, apellido, `displayName` | PERSONAL | `AR:113-115`; `DD` E01 |
| Dirección (línea 1 y 2, ciudad, departamento, código postal, país) | PERSONAL | `AR:335-336`; `DD` E02 |
| Empresa / razón social | PERSONAL | `AR:335`; `DD` E02 |
| Teléfono (facturación) | PERSONAL | `AR:335`; `DD` E02 |
| Correo de facturación (puede diferir del de la cuenta) | PERSONAL | `AR:335`; `DD` E02 |
| **Cédula/NIT** | **PERSONAL-ALTO** | `DD` E02; `HO:322-323,340-341`; no persiste en el perfil hoy (`AR:335` no la incluye); decisión **DM-02** |
| `roles`, `username` (hoy se devuelven; no deben viajar a la app) | INTERNO / PERSONAL | `AR:110-120` según `AUTH` A-08 |

#### F-04 Pedidos, checkout y pago

| Dato | Categoría | Evidencia |
|---|---|---|
| Pedido: número, fecha, estado, importes, medio de pago (título), líneas | PERSONAL (historial de compra enlazado a persona) | `DD` E15, E16; `AR:241-266` |
| Copia de facturación del pedido (nombre, empresa, cédula/NIT, dirección, teléfono, correo) | PERSONAL-ALTO | `DD` E15 `billing_snapshot`; `AUTH` §12.2 |
| Copia de envío | PERSONAL | `DD` E15 |
| Notas del cliente (texto libre) | PERSONAL-ALTO | `HO:221-223`; `DD` E15 |
| IP y *user agent* que registra WooCommerce | PERSONAL | `DD` E15 (por `APIC` EP-26) |
| Ticket de *handoff* (transient 60 s): correo, facturación, envío, notas, `authToken` | SECRETO + PERSONAL-ALTO | `HO:92,214-235`; el token ya no se guardaría con el rediseño (`AUTH` WP-06) |
| Cookie de sesión de WordPress persistente en el navegador del sistema al consumir el ticket | SECRETO | `HO:271` (`wp_set_auth_cookie($user->ID, true)`) |
| `_ipr_checkout_ref`, `_ipr_channel` | PERSONAL / INTERNO | `AUTH` §8.5 (propuesto) |
| Datos de pago (tarjeta, cuenta) | **No pasan por IPR ni por la app** | `RF-053`; `DD` §0.5 |

#### F-05 Recuperación de contraseña y correos transaccionales

| Dato | Categoría | Evidencia |
|---|---|---|
| Correo del titular (solicitud) | PERSONAL | `AUTH` §11 |
| Enlace de restablecimiento (token de WordPress) | SECRETO | `AUTH` §11 |
| `subject_hash` HMAC del correo (contadores y eventos) | PERSONAL (seudónimo) | `AUTH` §8.2, §8.3; `DD` §0.2 |

#### F-06 Eliminación de cuenta

| Dato | Categoría | Evidencia |
|---|---|---|
| `_ipr_account_state`, `_ipr_deletion_requested_at`, `_ipr_deletion_request_id` | PERSONAL (indirecto) | `AUTH` §8.5 |
| Solicitud de privacidad de WordPress (`wp_create_user_request`, incluye el correo) | PERSONAL | `AUTH` §12.1 paso 5 |
| Eventos `deletion_requested` / `deletion_completed` | PERSONAL (indirecto) | `AUTH` §8.2 |

#### F-07 Consentimientos

| Dato | Categoría | Evidencia |
|---|---|---|
| `user_id`, `document`, `document_version`, `action`, `occurred_at`, `client_type`, `app_version`, `request_id` | PERSONAL (indirecto) / INTERNO | `AUTH` §8.4; `DD` E07 |
| Versión y URL vigentes de términos y política | PÚBLICO | `DD` E23; `OAS` LegalDocument |
| **No se guarda hoy** prueba en la web (registro) ni en PQRS/boletín | HECHO | `AUTH` A-07; `PQ:22-37`; `NL:30,80`; `DD` E24, E25 |

#### F-08 PQRS

| Dato | Categoría | Evidencia |
|---|---|---|
| Tipo (petición/queja/reclamo/sugerencia) | INTERNO | `PQ:23-25` |
| Nombre (3–120) | PERSONAL | `PQ:26-28` |
| Correo (≤ 254) | PERSONAL | `PQ:29-31` |
| Teléfono (7–20) | PERSONAL | `PQ:32` |
| Pedido/factura (≤ 60, texto libre) | PERSONAL | `PQ:33` |
| Mensaje (≤ 1.000, texto libre) | PERSONAL-ALTO | `PQ:34-37` |
| Marca de tiempo y copia en el buzón corporativo | PERSONAL | `PQ:98-116` |
| **Falta:** campo/prueba de autorización en el endpoint web actual | HECHO (ausencia) | `PQ:22-37`; el texto del formulario en la página **no se leyó** |

#### F-09 WhatsApp y contacto

| Dato | Categoría | Evidencia |
|---|---|---|
| Mensaje prellenado con el producto consultado (lo arma la app; **no** incluye datos de cuenta) | INTERNO | `RF-094`, `RF-023`, AC-065-3 |
| Número y contenido del chat del usuario (los recibe WhatsApp/IPR, no la app) | PERSONAL | `COD` §4 |
| Teléfono/WhatsApp **corporativos** de sedes | PÚBLICO | `RF-073`; D-09 confirmar que no son personales |

#### F-10 Fallos

| Dato | Categoría | Evidencia |
|---|---|---|
| Traza, versión de app y SO, modelo | INTERNO / PERSONAL (puede identificar el dispositivo) | `RNF-097`; Firebase privacy |
| UUID de instalación / ID de Firebase Installations | PERSONAL (identificador) | página de privacidad de Firebase (verificada) |
| Datos de ruta o cuerpos de solicitudes | **No deben enviarse** (`PiiScrubber`) | `FLU` §10 y §2.1 `observability`; AC-SEC-4 |

#### F-11 Logs técnicos y borde

| Dato | Categoría | Evidencia |
|---|---|---|
| `requestId`, ruta (plantilla), método, estado, duración, versión y plataforma | INTERNO | `DD` E33; `APIA` §12 |
| `userRef`, `deviceRef` (HMAC truncado) | PERSONAL (seudónimo) | `DD` E33 |
| `ipPrefix` (/24 IPv4, /48 IPv6) | PERSONAL (prudencia) | `DD` E33 |
| IP completa en Cloudflare (`CF-Connecting-IP`) | PERSONAL | `DM` fila "IP del cliente" |
| **Nunca:** `Authorization`, tokens, contraseñas, cuerpos de auth/me/pqrs, correo, teléfono, cédula, direcciones, texto de búsqueda completo | Regla | `DD` E33; RNF-047 |

#### F-12 Auditoría y anti fuerza bruta

| Dato | Categoría | Evidencia |
|---|---|---|
| `event_type`, `outcome`, `occurred_at`, `reason_code`, `request_id` | INTERNO | `AUTH` §8.2 |
| `ip_address` | PERSONAL | `AUTH` §8.2 |
| `subject_hash` (HMAC del login/correo/IP) | PERSONAL (seudónimo) | `AUTH` §8.2, §8.3 |
| `session_uuid`, `user_id` | PERSONAL (indirecto) | `AUTH` §8.2 |

#### F-13 Instalación y almacenamiento local

| Dato | Almacén | Categoría | Evidencia |
|---|---|---|---|
| Refresh token | Keychain/Keystore | SECRETO | `FLU` §8 |
| Access token | Memoria | SECRETO | `FLU` §8 |
| Identificador de instalación (UUID aleatorio) | Secure storage | PERSONAL (indirecto) | `FLU` §8; `AUTH` §4 |
| Carrito (productId, cantidad, instantánea de nombre/imagen/precio) | Hive `cart` | Sin PII | `FLU` §8 |
| Caché pública (catálogo, sedes) | Hive `cache` | Sin PII | `FLU` §7.4, §8 |
| Intento de checkout (id y marca de tiempo) | Hive `cache` | Sin PII | `FLU` §8 |
| Preferencias no sensibles | `shared_preferences` | Sin PII | `FLU` §8 |
| Perfil, direcciones, pedidos | **Solo memoria** | PERSONAL | `FLU` §8; RNF-062 |

#### F-14 Canal de derechos del titular

| Dato | Categoría | Evidencia |
|---|---|---|
| Tipo de derecho, nombre, correo, descripción del reclamo, documentos que adjunte el titular | PERSONAL (puede ser PERSONAL-ALTO si adjunta identificación) | `RF-111`, AC-111-1…5; art. 15 Ley 1581 (contenido del reclamo) |
| Prueba de identidad del solicitante | PERSONAL-ALTO | art. 2.2.2.25.4.1 (el titular acredita identidad) |

#### F-15 a F-20 (condicionales / fuera de la app)

| Flujo | Datos | Evidencia |
|---|---|---|
| **F-15 Medición** | Evento "Más información" (producto, fecha); sin PII (propuesta) | `RF-065`; PA-08 |
| **F-16 Ubicación** | Coordenadas aproximadas **solo en el dispositivo** (propuesta); no se persiste | `RF-078`; RNF-060 |
| **F-17 Push** | Token de push, preferencias por categoría, consentimiento | `RF-090/091`; `APIC` `PUT /me/devices/{deviceId}/push` (fase 2) |
| **F-18 Boletín** | Nombre y correo; consentimiento solo se "valida" y se escribe como texto en el correo; **no** hay versión de política | `NL:19-31,70-83`; `DD` E25 |
| **F-19 Campañas — Ruleta Midea** | Nombre, documento, correo, celular, ciudad, número de factura (único); resultado y premio; fecha. Constante con URL del PDF de la política (`IPR_RULETA_PRIVACY`). La casilla de autorización es obligatoria pero **no se guarda** como prueba (la tabla no tiene columnas de consentimiento). Cada jugada se **copia por correo** al buzón configurado | `RM:48,117-132,179-211,252-273,286-305` |
| **F-19 Campañas — Raspa Samsung** | Con `IPR_RASPA_SAMSUNG_GUARDAR = false` (estado actual) **no guarda** (modo vista previa). Si se activa: nombre, documento, correo, celular, resultado, premio; reCAPTCHA de Google; **exportación CSV** de ganadores con documento, correo y celular desde el administrador. Enlace de términos "pendiente de definir". Reutiliza lógica de snippets "Tripleta" (otras tablas): **DESCONOCIDO** | `RS:3-59,78,153-191,240-262,764-773` |
| **F-20 Directorio** | Nombres, correos y celulares de 59 asesores/puntos de venta, publicados en la web | `INV` F16; RNF-065; `DD` E21 |

### 3.3 Hallazgos del código existente relevantes para privacidad (HECHOS)

| # | Hallazgo | Evidencia | Consecuencia |
|---|---|---|---|
| H-P1 | El alta de cuenta no registra aceptación de términos ni versión de política. | `AUTH` A-07 | La app necesita `ipr_consents`; las cuentas web existentes **no tienen prueba** (ver J-08). |
| H-P2 | PQRS: el endpoint no exige ni guarda autorización; el correo copia todos los datos al buzón; no hay política de retención. | `PQ:22-37,107-116` | Riesgo de recolección sin prueba (R-P01, R-P05). |
| H-P3 | Boletín: exige `consent === true` pero solo lo escribe como "aceptado" en el cuerpo del correo; sin versión ni fecha propia (usa la marca de tiempo del correo). | `NL:30,80` | Prueba débil; fuera del MVP. |
| H-P4 | Ruleta Midea guarda documento, correo y celular sin retención definida; la aceptación se exige pero no se registra como prueba. | `RM:117-132,208` | Fuera del MVP; si se incorpora, autorización y retención propias (RNF-065). |
| H-P5 | El ticket de *handoff* guarda PII y token durante 60 s en un *transient* de WordPress; al consumirlo se crea una cookie persistente de WordPress en el navegador del sistema. | `HO:214-235,271` | Dato y sesión residuales (R-P09). El rediseño propone no guardar el token (`AUTH` WP-06). |
| H-P6 | El perfil devuelto hoy incluye `roles`, `username` y todos los metadatos de facturación/envío. | `AUTH` A-08 | Minimización: lista blanca (`DM` DM-01). |
| H-P7 | La web guarda el perfil completo en `localStorage` (incluye cédula/NIT, teléfono, dirección según la auditoría interna). | `COD` §1, SEC-08; `INV` R-08 | Fuera de la app, pero es el mismo responsable; recomendar al equipo web. |
| H-P8 | Dos formatos de almacenamiento de direcciones (arreglo `billing`/`shipping` frente a `billing_*` nativo) pueden dejar restos tras la supresión. | `DM` INC-05, RM-05 | Unificar **antes** de la eliminación de cuenta (DM-03). |

---

## 4. Autorización, finalidades y prueba del consentimiento

### 4.1 Marco verificado (qué dice el texto)

| Norma | Contenido relevante | Estado |
|---|---|---|
| Ley 1581, art. 4 c | Tratamiento solo con consentimiento previo, expreso e informado, salvo mandato legal o judicial. | VERIFICADO (primaria) |
| art. 9 | Autorización previa e informada, "por cualquier medio que pueda ser objeto de consulta posterior". | VERIFICADO |
| art. 10 | Casos sin autorización: requerimiento de entidad pública/orden judicial; datos públicos; urgencia médica; fines históricos/estadísticos/científicos autorizados por ley; registro civil. **No figuran "contrato" ni "interés legítimo".** | VERIFICADO — la conclusión sobre su aplicación a la app es del jurídico (J-01) |
| art. 12 | Al solicitar la autorización, informar de forma clara y expresa: (a) tratamiento y finalidad; (b) carácter facultativo de respuestas sobre datos sensibles o de menores; (c) derechos del titular; (d) identificación, dirección física o electrónica y teléfono del responsable. **Conservar prueba** y entregar copia al titular que la pida. | VERIFICADO |
| art. 17 b, c | Solicitar y conservar copia de la autorización; informar finalidad y derechos. | VERIFICADO |
| Decreto 1074, art. 2.2.2.25.2.2 | Solicitar la autorización a más tardar al recolectar, informando datos y finalidades; **nueva autorización si cambia la finalidad**. | VERIFICADO (act. 2020) |
| art. 2.2.2.25.2.4 | Autorización escrita, oral o por conductas inequívocas; **el silencio nunca es conducta inequívoca**. | VERIFICADO |
| art. 2.2.2.25.2.5 | Conservar prueba de las autorizaciones. | VERIFICADO |
| art. 2.2.2.25.3.1–3.4 | Política de tratamiento (contenido: identificación y contacto del responsable, finalidades, derechos, área de atención, procedimiento, fecha de vigencia); cambios sustanciales se comunican **antes** de aplicarlos; aviso de privacidad si no se puede poner la política a disposición; conservar el modelo del aviso mientras se traten datos conforme a él. | VERIFICADO |

### 4.2 Consentimientos y avisos que la app necesitaría (PROPUESTA — validar con el jurídico)

El texto definitivo lo redacta el jurídico. La tabla fija **qué elementos debe tener cada pantalla** y cómo se prueba.

| ID | Consentimiento / aviso | Dónde aparece | Tipo | ¿Condiciona el servicio? | Elementos mínimos (art. 12 Ley 1581) | Prueba (`ipr_consents`) | Estado |
|---|---|---|---|---|---|---|---|
| C-01 | **Términos y condiciones** (relación contractual de uso/compra) | Registro; enlace en menú de Ayuda | Aceptación contractual (no sustituye la autorización de datos) | Sí, para registrarse | Texto completo abierto desde el enlace (RNF-056, AC-039-1) | `document = terms`, versión, fecha | RF-039; PROPUESTA |
| C-02 | **Autorización de tratamiento de datos personales** y acceso a la **Política de Tratamiento** | Registro (casilla **sin marcar**, antes de enviar) y primer uso del flujo de compra | Autorización expresa | Sí, para las finalidades **necesarias** de la cuenta y la compra | (a) finalidades del tratamiento; (b) carácter facultativo si se pidiera dato sensible o de menores; (c) derechos; (d) identificación y contacto del responsable | `document = privacy_policy`, versión, fecha, canal, versión de app | RF-039; AC-039-1…7 |
| C-03 | **Autorización de mercadeo** (correo/promociones) | Pantalla separada o casilla independiente, **sin marcar**, opcional | Autorización específica | **No** (no puede condicionar el registro ni la compra) | Finalidad de mercadeo, canales, cómo revocar | `document = marketing` (fase 2 en `AUTH` §8.4) | Fase 2 (RF-101/RF-092) |
| C-04 | **Notificaciones push**: transaccionales y promocionales por separado | Permiso del SO solicitado **en contexto**, no al primer arranque; preferencia por categoría | Consentimiento por categoría | No | Qué se envía, desactivable en ≤ 2 toques (RNF-066) | `document = push` | Fase 2 |
| C-05 | **Ubicación** (sede más cercana) | Aviso previo + permiso del SO "mientras se usa", aproximada | Permiso + aviso | No | Finalidad única; no sale del dispositivo (propuesta) | Si no sale del dispositivo, la prueba es el permiso del SO (**J-14**) | Fase 2 (RF-078) |
| C-06 | **Autorización para PQRS** (formulario) | Casilla o texto antes de "Enviar" | Autorización contextual | Sí, para tramitar la solicitud | Finalidad (atender PQRS), quién la recibe, retención, derechos | Hoy: **no existe prueba**. Opciones **DM-04**: A) `user_id` nulo + `subject_hash`; B) persistir PQRS mínima con consentimiento | EP-27 `acceptsDataPolicy`; AC-039-6 |
| C-07 | **Aviso de reporte de fallos y seguridad** | Política + ajustes (opción de desactivar si el jurídico lo exige) | Aviso/autorización (**J-12**) | No | Qué datos técnicos, proveedor, país | Registro de versión de política aceptada; opción en ajustes | DN-02 |
| C-08 | **Aviso de continuación en la web** (checkout en navegador seguro, Wompi) | Antes de abrir el navegador seguro | Información | Sí, para pagar | Que el pago continúa en el sitio web de IPR y en la pasarela, con sus propias políticas | Versión de política mostrada | PROPUESTA |
| C-09 | **Aviso sobre WhatsApp** | Pantalla de Ayuda/contacto | Información | No | Que la conversación se rige por las condiciones de WhatsApp y por la política de IPR | N/A | PROPUESTA |
| C-10 | **Edad / menores** | Registro (declaración de mayoría de edad en términos) | Declaración | Sí | La app no se dirige a menores; si se supiera que un titular es menor, aplicar art. 7 y art. 2.2.2.25.2.9 | Aceptación de términos | **J-15** |
| C-11 | **Campañas** (ruleta/raspa), si algún día entran | Formulario de campaña | Autorización propia | Solo para participar | Finalidad promocional, retención propia, términos de la campaña | Debe registrarse (hoy no se hace) | Fuera del MVP (RNF-065) |

### 4.3 Versionado de la política y prueba del consentimiento

| Aspecto | Propuesta | Evidencia / norma |
|---|---|---|
| **Versión vigente** | `GET /config` publica `legal.terms` y `legal.privacyPolicy` con `version` y `url`. El servidor rechaza el registro si las versiones enviadas no coinciden con las vigentes. | `AUTH` §10; `DD` E22/E23 |
| **Qué se guarda** | `user_id`, `document`, `document_version`, `action` (`accepted`/`revoked`), `occurred_at` (UTC), `client_type`, `app_version`, `request_id`. | `AUTH` §8.4 |
| **Refuerzos recomendados al modelo (para el modelador de datos)** | (1) Huella SHA-256 del texto exacto mostrado, para probar qué se aceptó aunque el PDF cambie; (2) idioma/formato; (3) decidir si se guarda IP (hoy no está en `ipr_consents`; está en auditoría 90 días): **decisión del jurídico**, equilibrando prueba y minimización (AC-039-6). | PROPUESTA — art. 12 par., art. 17 b |
| **Conservación del modelo de texto** | Archivar cada versión publicada (texto y fecha de vigencia) mientras existan datos tratados conforme a ella. | art. 2.2.2.25.3.4 |
| **Cambios de política** | Cambio sustancial: comunicar antes de aplicarlo; cambio de finalidad: nueva autorización. Qué hace la app al cambiar la versión (bloquear hasta aceptar o aviso) es **decisión del jurídico**. | art. 2.2.2.25.3.1, 2.2.2.25.2.2; AC-039-7 |
| **Revocatoria** | Registrar `action = revoked` por documento; endpoint y pantalla "Mis autorizaciones" no existen (DM-08). | art. 2.2.2.25.2.6; `DM` DM-08 |
| **Cuentas web existentes** | No tienen prueba de aceptación (H-P1). Al iniciar sesión en la app por primera vez habría que mostrar y registrar la aceptación vigente (o decidir otra vía). | **J-08** |
| **Pruebas de aceptación** | AC-039-3 (registro consultable por IPR), AC-039-4 (el servidor no depende de la UI), AC-039-5 (no se acepta lo que no se pudo ver), AC-039-6 (mínimo de datos). | `AC` |

### 4.4 Finalidades (inventario propuesto a validar)

| Finalidad | Datos | Flujos | ¿Necesaria para el servicio? |
|---|---|---|---|
| Gestión de cuenta y autenticación | Correo, nombre, contraseña (hash), sesiones | F-01, F-02, F-05 | Sí |
| Compra, entrega y facturación | Direcciones, teléfono, cédula/NIT, pedido | F-03, F-04 | Sí |
| Soporte posventa y PQRS | Nombre, correo, teléfono, pedido, mensaje | F-08, F-09, F-14 | Sí (cuando se solicita) |
| Seguridad y prevención de abuso | IP, identificadores seudónimos, eventos | F-11, F-12 | Sí (informar) |
| Diagnóstico técnico | Trazas, versión, SO | F-10 | Pregunta J-12 |
| Obligaciones legales (contables, tributarias, SIC) | Pedido y facturación | F-04, F-06 | Sí (plazos: D-12) |
| Mercadeo y notificaciones promocionales | Correo, token de push | F-17, F-18 | **No** (consentimiento separado) |
| Ubicación para sedes | Coordenadas aproximadas | F-16 | No (opcional) |
| Medición de uso | Eventos agregados | F-15 | No (consentimiento, PA-08) |

---

## 5. Derechos del titular y eliminación de cuenta

### 5.1 Derechos y plazos (verificados)

| Derecho | Fuente | Plazo / regla verificada |
|---|---|---|
| Conocer, actualizar y rectificar | art. 8 a | — |
| Solicitar **prueba de la autorización** | art. 8 b; art. 17 b; art. 2.2.2.25.2.5 | — |
| Ser informado del uso dado a sus datos | art. 8 c; art. 17 m | — |
| Presentar **quejas ante la SIC** | art. 8 d | Solo tras agotar consulta o reclamo ante el responsable (art. 16, requisito de procedibilidad) |
| **Revocar** la autorización y/o solicitar la **supresión** | art. 8 e; art. 2.2.2.25.2.6 | Mediante reclamo; mecanismos gratuitos y de fácil acceso; **no procede** si el titular tiene un deber legal o contractual de permanecer en la base (art. 2.2.2.25.2.6). El art. 8 e condiciona la procedencia a la determinación de la SIC en ciertos casos: la lectura conjunta es del jurídico (J-17) |
| **Acceso gratuito** | art. 8 f; art. 2.2.2.25.4.2 | Gratis al menos una vez al mes y tras cambios sustanciales de la política |
| **Consultas** | art. 14 | **10 días hábiles** desde el recibo; si no es posible, informar motivos y fecha, sin superar **5 días hábiles** adicionales |
| **Reclamos** (corrección, actualización, supresión, presunto incumplimiento) | art. 15 | Reclamo incompleto: requerir en **5 días** para subsanar; desistimiento a los **2 meses**; traslado en **2 días hábiles** si no es competente; leyenda **"reclamo en trámite"** en la base en **2 días hábiles**; respuesta en **15 días hábiles** desde el día siguiente al recibo, prorrogable hasta **8 días hábiles** más informando motivos |
| Legitimación | art. 2.2.2.25.4.1 | Titular (acredita identidad), causahabientes, representante/apoderado; derechos de menores los ejercen sus representantes |
| Persona o área designada | art. 2.2.2.25.4.4 | Cada responsable y encargado designa quién tramita solicitudes |
| Procedimientos accesibles | art. 2.2.2.25.3.6 | Deben darse a conocer e incluirse en la política |

**Nota sobre RNF-058/RNF-059 (HECHO, consistente):** el "≤ 15 días hábiles" de los requisitos coincide con el plazo de atención del reclamo (art. 15 num. 3). Dos matices para el jurídico: (a) el plazo legal es **para atender el reclamo** y admite prórroga de hasta 8 días hábiles con aviso; (b) no está verificado que 15 días sea un plazo legal específico para completar una **supresión** de cuenta. Se mantiene como objetivo técnico propuesto.

### 5.2 Cómo se ejercen (desde la app y fuera de ella)

| Derecho | Desde la app (MVP) | Fuera de la app | Brecha / decisión |
|---|---|---|---|
| Conocer / acceder | Ver perfil, direcciones y pedidos (RF-104–108). Exportación **no existe** (RNF-059, DM-08). | Canal de derechos con radicado (RF-111) | Decidir si se ofrece exportación (la portabilidad no figura en el art. 8; el acceso gratuito sí). J-18 |
| Actualizar / rectificar | Editar nombre, direcciones, correo y contraseña (con contraseña actual) | Canal de derechos | — |
| Prueba de autorización | No hay pantalla. Propuesta: "Mis autorizaciones" (versión, fecha). | Canal de derechos | DM-08; J-09 |
| Revocar / suprimir | **Eliminar cuenta** (US-110); revocar mercadeo/push desde ajustes (fase 2) | Canal de derechos; enlace web para tiendas (S-05) | Define el jurídico qué es "supresión" frente a retención legal (§5.3) |
| Consultas y reclamos | Enlace "Derechos sobre mis datos" (AC-111-1) | Correo/formulario/PQRS (**canal vigente DESCONOCIDO**) | Designar área, SLA, radicado, verificación de identidad (J-16) |
| Queja ante la SIC | Informar en la política | SIC | Solo tras consulta o reclamo (art. 16) |

**Verificación de identidad fuera de la app (PROPUESTA):** las solicitudes hechas desde la app autenticada ya identifican al titular. Las recibidas por correo/PQRS requieren un procedimiento de verificación proporcional (el titular acredita identidad, art. 2.2.2.25.4.1) para evitar suplantación; no solicitar más datos de los necesarios (AC-111-4).

### 5.3 Eliminación de cuenta — qué se borra y qué se retiene

> **Insumo técnico, no asesoría jurídica.** Los plazos de conservación y el alcance de la anonimización son **DECISIÓN PENDIENTE D-12 / PA-09 / DN-08 (Jurídico + Finanzas)**. En `AUTH` §12.2 aparece una referencia a "plazos de 5 a 10 años según la norma aplicable": **NO VERIFICADA** en esta evaluación; **no debe adoptarse** hasta que el jurídico la confirme y cite la norma.

| Dato / sistema | Acción propuesta | Plazo | Estado |
|---|---|---|---|
| Usuario, correo, nombre, contraseña (hash) | Eliminar tras anonimizar lo vinculado | Objetivo técnico: inmediata para el acceso; supresión ≤ 15 días hábiles (RNF-058) | PROPUESTA |
| Direcciones y teléfono del perfil; cédula/NIT del perfil (si existiera) | Eliminar | Ídem | PROPUESTA |
| Sesiones, tokens (app y web) | Eliminar/revocar | Revocación inmediata | PROPUESTA (`AUTH` §3.5) |
| Carrito persistente y sesión de WooCommerce | Eliminar | Ídem | PROPUESTA |
| Tokens de pago de WooCommerce/Wompi (si existen) | Eliminar; pedir a Wompi la supresión de lo que guarde como encargado, si aplica | Ídem | **DESCONOCIDO** si se tokeniza |
| **Pedidos, líneas y copia de facturación/envío** | **Conservar** el soporte contable y tributario exigible; **anonimizar** lo no exigible (teléfono, notas) y desvincular `customer_id` | **A VALIDAR (Jurídico + Finanzas)** | DECISIÓN PENDIENTE |
| Facturación electrónica emitida fuera de WooCommerce | Qué sistema, qué datos, qué plazo | **DESCONOCIDO** | Preguntar a Finanzas |
| Pedidos en curso | Permitir o bloquear la eliminación hasta cierre | **A VALIDAR** (AC-110-8) | DECISIÓN PENDIENTE |
| Consentimientos (`ipr_consents`) | Conservar el registro mínimo como prueba; luego eliminar | **A VALIDAR** | DECISIÓN PENDIENTE |
| Auditoría (`ipr_auth_events`) | ≤ 90 días (propuesta técnica); evento de eliminación sin PII salvo `user_id` | Evento: **A VALIDAR** | DECISIÓN PENDIENTE |
| PQRS enviadas y boletín | Fuera del sistema: política del buzón | **DESCONOCIDA** | DECISIÓN PENDIENTE |
| Chats de WhatsApp con asesores | Fuera de la app; atender por canal de derechos | **DESCONOCIDA** | DECISIÓN PENDIENTE |
| Logs del BFF (seudónimos) | Caducan a los 90 días (propuesta técnica) | 90 días | PROPUESTA |
| Reporte de fallos | Sin PII por diseño; el proveedor conserva 90 días (Crashlytics, verificado) | Según proveedor | PROPUESTA |
| **Copias de seguridad del hosting** | Documentar cuánto tardan en expirar y cómo se evita restaurar datos suprimidos | **DESCONOCIDO** | Preguntar al hosting |
| Datos locales del dispositivo | Borrado inmediato (RNF-062) | Inmediato | PROPUESTA |
| Reutilizar el correo para una cuenta nueva | Permitido tras completar la eliminación (AC-110-6) | — | DECISIÓN PENDIENTE (PA-09) |

**Requisitos de las tiendas que condicionan el diseño (verificados):**
- **Apple (5.1.1(v)):** la eliminación debe poder **iniciarse en la app**; no basta desactivar la cuenta; si el trámite tarda, decirlo; si se retiene algo por ley, **informar qué y por qué**; no exigir llamada, correo o chat (salvo industrias reguladas); se admite confirmación (p. ej. contraseña). El enlace web solo es válido si completa un proceso que empezó en la app.
- **Google Play:** si la app permite crear cuenta, ruta de eliminación en la app (preferida) **y enlace web** declarado en Play Console; informar qué datos se retienen y por qué (p. ej. en la política); borrar en servidores propios y **pedir a proveedores que borren**; la insignia de eliminación del *Data safety* aplica si hay mecanismo de solicitud o borrado/anonimización automática en 90 días.
- **AC-110-2** exige que la confirmación explique qué se elimina y qué se conserva "y por cuánto tiempo": **requiere los plazos del jurídico antes de publicar**.

---

## 6. Transferencias y transmisiones internacionales

### 6.1 Distinción verificada

| Figura | Qué es | Régimen | Fuente |
|---|---|---|---|
| **Transferencia** | El responsable envía datos a **otro responsable** fuera del país | Prohibida a países sin nivel adecuado, salvo excepciones (art. 26: autorización expresa e inequívoca del titular; ejecución de contrato **con autorización del titular**; otras) o declaración de conformidad de la SIC (par. 1) | Ley 1581, art. 26 (VERIFICADO) |
| **Transmisión** | El responsable comunica datos a un **encargado** (dentro o fuera del país) para que los trate por su cuenta | No exige informar ni obtener consentimiento **si existe el contrato** del art. 2.2.2.25.5.2 (alcances, actividades del encargado, obligaciones; aplicar la política del responsable, tratar según las finalidades autorizadas, seguridad y confidencialidad) | Decreto 1074, arts. 2.2.2.25.5.1–5.2 (VERIFICADO, act. 2020) |
| **Instrucciones recientes de la SIC** | Verificar funcionalidades que tratan datos, riesgos y decisiones documentadas; cláusulas sobre responsabilidades, seguridad, garantías de transmisión/transferencia internacional y auditoría | CE 002/2025, §1–§4 (VERIFICADO) | `normograma.mintic.gov.co` |

### 6.2 Proveedores y ubicación

| Proveedor | Figura probable | País/región | Datos | Acción propuesta | Estado |
|---|---|---|---|---|---|
| Cloudflare | Transmisión (encargado) | Global; fuera de Colombia (**SUPUESTO**) | IP y contenido en tránsito (incluye credenciales y PII si el modo es proxy) | Contrato/DPA; confirmar que el modo es proxy y qué logs conserva; incluir en política | SUPUESTO |
| DigitalOcean | Transmisión | **DESCONOCIDA** | BFF, logs seudonimizados | Confirmar región; contrato | DESCONOCIDO |
| Hosting WordPress (Plesk) | Transmisión | **DESCONOCIDA** | Base completa de clientes | Confirmar país y copias de seguridad; contrato | DESCONOCIDO |
| SMTP | Transmisión | **DESCONOCIDA** | PQRS, boletín, correos transaccionales | Confirmar proveedor y región; contrato | DESCONOCIDO |
| Firebase Crashlytics (opción 1) | Transmisión (Google, normalmente encargado) | Cualquier centro de datos de Google (verificado); sin selección de región | UUID de instalación, ID de Firebase Installations, trazas, modelo, SO | DPA de Firebase; depurar PII; no adjuntar `user_id` | VERIFICADO (primaria) |
| Sentry (opción 2) | Transmisión | **NO VERIFICADO** (región UE/EE. UU.) | Trazas, SO, modelo | Verificar región y plan de datos; DPA | NO VERIFICADO |
| Wompi | Transferencia o transmisión según contrato (**SUPUESTO**) | **DESCONOCIDO** | Datos del pagador | Revisar términos y conservación | DESCONOCIDO |
| Apple/Google (push, fase 2) | Transmisión (APNs/FCM) | EE. UU. y otros (**SUPUESTO**) | Token de push | Revisar términos al habilitar push | Fase 2 |
| Meta/WhatsApp | Responsable propio | EE. UU. y otros (**SUPUESTO**) | Conversación | Informar en política; revisar uso de WhatsApp Business | SUPUESTO |
| Google reCAPTCHA (campañas) | Responsable propio / encargado (**SUPUESTO**) | EE. UU. y otros | IP, interacción | Solo si se incorpora la campaña | Fuera del MVP |

**Nivel adecuado:** Estados Unidos figura en la lista original de la CE 005/2017 (VERIFICADO secundaria); **la lista vigente no se pudo verificar**. Aun si el destino figurara como adecuado, hay que poder demostrar cumplimiento de responsabilidad demostrada (resumen secundario de la CE 005/2017). Hay un proyecto de reforma (P.L.E. 282 de 2026 Cámara) que propone rediseñar el art. 26 (estado **NO VERIFICADO**).

**Propuestas técnicas de minimización:**
1. No enviar identificadores de cuenta (`user_id`, correo) al proveedor de fallos; usar solo el identificador de instalación aleatorio, y evaluar no adjuntarlo.
2. Elegir región del proveedor que el jurídico considere aceptable cuando exista selección.
3. Documentar en el inventario de SDKs el destino de cada tráfico (RNF-061: 0 destinos no declarados en captura de proxy).
4. Redactar la política indicando que parte del tratamiento se hace con proveedores en el exterior (**J-19**).

---

## 7. Permisos del dispositivo y SDKs: minimización

### 7.1 Permisos (MVP) — lista aprobada y lista de "NO recoger"

| Permiso / capacidad | MVP | Justificación | Evidencia |
|---|---|---|---|
| Internet (red) | **Sí** (permiso normal) | Operar contra `/mobile/v1` | `FLU` §7 |
| Ubicación (aproximada o precisa) | **No** | Fase 2, solo "sedes cercanas", aproximada, "mientras se usa" | AC-SEC-10; RNF-060; RF-078 |
| Notificaciones push | **No** (fase 2) | Consentimiento por categoría, en contexto | AC-SEC-10; RNF-066 |
| Cámara, micrófono, fotos/archivos, contactos, calendario | **No** | Sin funcionalidad que los requiera | AC-SEC-10; RNF-060 |
| Identificador publicitario (IDFA/AAID) y seguimiento (ATT) | **No** | Sin publicidad ni seguimiento entre apps | RNF-060 |
| Biometría (huella/rostro) | **No** (fase 2 si se evalúa) | Si se usara para desbloquear la sesión, es dato biométrico (art. 5 Ley 1581: sensible) → exige análisis del jurídico | art. 5 Ley 1581 |

**Qué NO debe recogerse (propuesta, para el inventario aprobado por el jurídico):**

| No recoger | Motivo |
|---|---|
| Android ID, IMEI, MAC, número de serie, huella del hardware, nombre del dispositivo (suele contener el nombre de la persona), modelo en la tabla de sesiones | Minimización; `AUTH` §4 ya lo excluye (solo plataforma y versión de SO) |
| Lista de aplicaciones instaladas, SSID, contactos, portapapeles, galería | Sin finalidad |
| Ubicación precisa o histórica | Sin finalidad en el MVP |
| Datos de pago (tarjeta, cuenta bancaria) | No pasan por IPR ni por la app (RF-053); el pago ocurre en navegador seguro |
| Contraseñas, tokens, tickets, cédula/NIT, teléfono, dirección en logs, reportes de fallos, analítica o URLs | AC-SEC-4, AC-SEC-5, RNF-047 |
| Datos de menores | Art. 7 Ley 1581; art. 2.2.2.25.2.9 |
| Datos sensibles (art. 5) | Ninguna funcionalidad los requiere; si algún campo libre (PQRS, notas) los recibiera, el carácter es facultativo y no pueden condicionarse actividades a entregarlos (art. 2.2.2.25.2.3) |
| Texto de búsqueda completo en logs | `DD` E33 |
| Perfil, direcciones y pedidos en almacenamiento persistente | RNF-062, `FLU` §8 |
| Identificadores de cuenta en URLs de enlaces profundos | El enlace `/pedido-confirmado` solo lleva datos mínimos validados como "pista" (`FLU` §6.2); evitar PII en URLs por historial del navegador |

### 7.2 SDKs y paquetes con implicación de privacidad

| Componente | Datos que toca | Destino | Decisión de privacidad |
|---|---|---|---|
| `flutter_secure_storage` | Tokens, `deviceId` | Solo dispositivo (Keychain/Keystore, excluido de copias) | Permitido (RNF-034/035) |
| `hive_ce` / `shared_preferences` | Carrito, caché pública, preferencias | Solo dispositivo | Permitido; **sin PII** (si algún día la hay, cifrar) |
| `dio` (cliente HTTP) | Todas las solicitudes a `/mobile/v1` | IPR vía Cloudflare | Cabeceras sin PII (`FLU` §7.1) |
| `cached_network_image` | Solicitudes de imágenes (IP del dispositivo hacia el CDN de IPR) | IPR/Cloudflare | Permitido; fuentes empaquetadas como activos para no descargar de terceros (`FLU` §13.2) |
| `url_launcher` / navegador seguro (Custom Tabs, SFSafariViewController) | Abre WhatsApp, mapas, teléfono, checkout | Apps y sitios fuera de la app | Informar al usuario (C-08, C-09); no pasar PII en URL |
| **Crashlytics o Sentry** | Ver F-10 | Exterior | **Un solo** proveedor; PII scrubber obligatorio; decidir DN-02/J-12 |
| **Analítica** (cualquier SDK) | — | — | **Apagada** hasta decidir PA-08 y consentimiento (ADR-010) |
| Push (FCM/APNs) | Token | Apple/Google | **No** en el MVP |
| Cualquier SDK publicitario o de atribución | — | — | **Prohibido** en el MVP |
| Dependencias transitivas (Firebase Core instala Firebase Installations, que Crashlytics recoge) | ID de instalación | Google | Inventariar transitivas en el SBOM (RNF-049) y comparar con tráfico real |

**Controles de plataforma ya previstos (HECHOS de diseño):** `allowBackup=false` o reglas de exclusión; Keychain sin sincronización iCloud; ocultar capturas en cuenta, pedidos y checkout (Should) (`FLU` §8). **Verificar en el *build*:** manifiesto de Android y `Info.plist` sin permisos fuera de lista (RNF-060); manifiestos de privacidad de Apple y firmas de SDK: **NO VERIFICADO** (la página de Apple menciona soporte de firmas y manifiestos de privacidad de SDK; el contenido de los requisitos no se revisó en esta evaluación).

---

## 8. Etiquetas de privacidad de las tiendas (borrador, A VALIDAR)

> Se completan con lo que la app **recogerá en el MVP** según este análisis. Las respuestas dependen de decisiones abiertas (DN-02 proveedor de fallos, PA-08 analítica, DM-02 cédula/NIT, logs). **Deben contrastarse con una captura de tráfico real antes de publicar** (RNF-061). Apple define "recoger" como transmitir datos fuera del dispositivo de modo que IPR o sus socios puedan acceder a ellos por más tiempo del necesario para atender la solicitud en tiempo real (verificado). Google considera "recopilar" todo envío fuera del dispositivo, incluido el de SDKs y el de datos seudónimos que puedan vincularse (verificado).

### 8.1 Apple — App Privacy (borrador)

| Categoría Apple | Tipo | ¿Se recoge? | ¿Vinculado al usuario? | ¿Seguimiento? | Finalidad | Notas |
|---|---|---|---|---|---|---|
| Contact Info | Name | Sí | Sí | No | App Functionality | Registro, direcciones, PQRS |
| Contact Info | Email Address | Sí | Sí | No | App Functionality | Cuenta, pedidos, PQRS |
| Contact Info | Phone Number | Sí | Sí | No | App Functionality | Dirección de facturación, PQRS |
| Contact Info | Physical Address | Sí | Sí | No | App Functionality | Envío/facturación |
| Identifiers | User ID | Sí | Sí | No | App Functionality | Sesión y pedidos |
| Identifiers | Device ID | **A validar**: UUID de instalación aleatorio enviado al servidor | Sí | No | App Functionality; seguridad | Declaración conservadora recomendada; **J-20** |
| Purchases | Purchase History | Sí | Sí | No | App Functionality | Historial de pedidos |
| User Content | Customer Support | Sí | Sí | No | App Functionality | Texto de PQRS |
| Diagnostics | Crash Data | Sí (si se adopta crash reporting) | Según configuración (con identificador de instalación puede ser "vinculado") | No | App Functionality / Analytics (diagnóstico) | Depende de DN-02 |
| Other Data Types | Documento de identidad (cédula/NIT) | **A validar** | Sí | No | App Functionality | Solo si se persiste o se captura en la app (DM-02); en el checkout web lo captura el sitio |
| Financial Info | Payment Info | **No recoge la app** (el pago ocurre en navegador seguro) | — | — | — | **A validar** con Apple: la información la recoge el sitio web/Wompi, no el binario |
| Location | Coarse/Precise | **No** en el MVP | — | — | — | Fase 2 si se implementa |
| Usage Data / Search History | Product Interaction / búsquedas | **No** en el MVP si no se retienen; **A validar** según logs (texto de búsqueda no se registra completo) | — | — | — | RF-065 apagada hasta PA-08 |
| Contacts, Health, Sensitive Info, Browsing History | — | **No** | — | — | — | — |
| **Tracking** | — | **No** | — | — | — | Sin ATT ni IDFA |

Otros requisitos Apple (verificados): URL de política de privacidad **obligatoria** y accesible públicamente; URL de "opciones de privacidad" opcional (útil: enlace al canal de derechos y a la eliminación); eliminación de cuenta iniciable en la app (Guideline 5.1.1(v)).

### 8.2 Google Play — Data safety (borrador)

| Categoría Google | Dato | ¿Se recopila? | ¿Se comparte? | Obligatorio u opcional | Finalidad | Notas |
|---|---|---|---|---|---|---|
| Personal info | Nombre | Sí | No (a proveedores que tratan por cuenta de IPR no cuenta como "compartir", verificado) | Obligatorio para registro/compra | App functionality; account management | — |
| Personal info | Correo electrónico | Sí | No | Obligatorio | App functionality; account management | — |
| Personal info | Dirección y número de teléfono | Sí | No | Obligatorio para compra | App functionality | — |
| Personal info | Otro (cédula/NIT) | **A validar** | No | Obligatorio para facturar | App functionality | DM-02 |
| Financial info | Historial de compras | Sí | No | Obligatorio (si compra) | App functionality | Pedidos |
| Financial info | Datos de pago | **No** (navegador seguro) | — | — | — | **A validar**: el pago ocurre fuera del binario |
| App activity / mensajes | Contenido de PQRS | Sí | No | Opcional (el usuario decide enviarla) | App functionality; soporte | — |
| App info and performance | Registros de fallos / diagnóstico | Sí (si se adopta) | No (proveedor como encargado) | Obligatorio (no desactivable) o con opción: **J-12** | Analytics (diagnóstico); fraud/security | Depende de DN-02 |
| Device or other IDs | Identificador de instalación / ID de Firebase Installations | Sí | No | Obligatorio | App functionality; fraud prevention, security | **J-20** |
| Location, Contacts, Photos, Audio, Health | — | **No** | — | — | — | Fase 2 solo ubicación |
| **Seguridad** | Datos cifrados en tránsito | Sí (HTTPS, AC-SEC-3) | — | — | — | — |
| **Seguridad** | ¿El usuario puede pedir eliminación? | Sí: en la app + enlace web declarado en Play Console | — | — | — | Requisito Google para apps con cuentas |

Notas: (1) los nombres exactos de categorías y la política de compartición deben contrastarse con la versión actual del formulario en Play Console (NO VERIFICADO el texto de 2026 más allá de la página consultada); (2) el *Data safety* exige declarar también lo que recogen los SDKs; (3) los formularios de **público objetivo/edad** de Play y la **clasificación por edad** de Apple: **NO VERIFICADO** en esta evaluación (ver J-15).

---

## 9. Matriz de riesgos de privacidad

Escala **cualitativa propuesta** (Baja / Media / Alta); no se asignan probabilidades numéricas ni se afirma frecuencia. Residual = nivel estimado **si se implementa el control**; el jurídico y el responsable de seguridad lo confirman.

| ID | Riesgo | Prob. | Impacto | Control propuesto | Residual | RNF / AC relacionados |
|---|---|---|---|---|---|---|
| R-P01 | Recolección sin autorización probada (registro actual, PQRS, boletín, cuentas web existentes que usan la app) | Alta | Alto | `ipr_consents` con versión; casilla sin marcar; servidor no depende de la UI; flujo para cuentas existentes; autorización en PQRS | Media (hasta definir J-08 y DM-04) | RNF-056; AC-039-1…7, AC-038-4 |
| R-P02 | La política vigente no cubre los tratamientos nuevos de la app | Alta | Alto | Revisión y actualización por el jurídico **antes** de publicar; versionado | Baja (si se publica versión actualizada) | RNF-057, RNF-064; AC-099-6 |
| R-P03 | Transmisión/transferencia internacional sin contrato ni base documentada (Cloudflare, fallos, hosting) | Media | Alto | Inventario de encargados, contratos del art. 2.2.2.25.5.2, DPA, región; información en política | Media (varios países DESCONOCIDOS) | RNF-061; R-NF-09 |
| R-P04 | Bases nuevas sin evaluar para el RNBD (consentimientos, dispositivos, auditoría) | Media | Medio–Alto | Catálogo de bases; confirmar umbral de activos; inscribir dentro de 2 meses de su creación si aplica | Baja | RNF-064 |
| R-P05 | Retención indefinida de PII fuera de la base de datos (buzones PQRS/boletín, tablas de campañas, copias de seguridad) | Alta | Medio | Política de retención por flujo (jurídico); depuración periódica del buzón; documentar expiración de backups | Media | RNF-063; `RET-12/13` |
| R-P06 | Eliminación de cuenta incompleta, o que destruya soportes contables exigibles | Media | Alto | Tabla §5.3 validada por Jurídico + Finanzas; unificar direcciones (DM-03); prueba E2E en staging | Baja–Media | RNF-058, RNF-062; AC-110-1…16 |
| R-P07 | PII en logs, reportes de fallos, URLs o analítica | Media | Alto | `PiiScrubber`; sin cuerpos en logs; valores canario; captura de tráfico | Baja | RNF-047, RNF-097; AC-SEC-4, AC-SEC-5 |
| R-P08 | Exposición excesiva en la API (`roles`, `username`, metadatos crudos, `id` interno) | Media | Alto | DTO por lista blanca; esquemas estrictos; `UserProfile.id` opaco o ausente (DM-01) | Baja | AC-SEC-8; `AUTH` §14 API3 |
| R-P09 | *Handoff*: PII y token en transient; cookie persistente de WordPress en el navegador del sistema tras el pago | Media | Medio | No guardar el token en el ticket (WP-06); ticket sin facturación en el flujo de la app; informar y ofrecer cerrar sesión web; confirmar si las cookies de WP/WooCommerce y Wompi requieren aviso (política de cookies: **NO VERIFICADO**) | Media | RNF-045; `DM` RM-01 |
| R-P10 | Enumeración de cuentas (el registro devuelve `409 email_in_use`) | Alta | Bajo–Medio | Límites por IP/dispositivo; verificación de correo en fase 2 (RF-046) | Media (riesgo aceptado RA-11) | AC-038-5; `AUTH` RS-04 |
| R-P11 | Incidente de seguridad sin protocolo para informar a la SIC y a los titulares | Media | Alto | Procedimiento de respuesta, roles y plantillas; el deber de informar a la autoridad está en art. 17 n y 18 k Ley 1581 (verificado); plazos operativos SIC **NO VERIFICADOS** | Media | RNF-105; J-26 |
| R-P12 | Menores de edad se registran o dejan datos | Baja–Media | Alto | Términos de mayoría de edad; no dirigir a menores; procedimiento si se detecta; art. 7 Ley 1581 | Baja–Media | — |
| R-P13 | Etiquetas de Apple/Google inexactas frente al tráfico real (rechazo o retiro) | Media | Alto | Captura de tráfico en staging; inventario de SDKs; revisión del jurídico | Baja | RNF-061 |
| R-P14 | Campañas con PII (documento, correo, celular) sin retención ni prueba, públicas y conectadas al sitio | Media | Alto | Mantenerlas **fuera de la app**; política, retención y prueba de autorización antes de cualquier integración; revisar exportes CSV y correos de constancia | Media (riesgo vive en la web actual) | RNF-065; `DM` RM-08 |
| R-P15 | Datos personales de empleados publicados en la web (59 contactos) | Media | Medio | Fuera de la app (RNF-065 = 0); sugerir al jurídico revisar autorización y art. 4 f (disponibilidad en Internet) | Media | RNF-065 |
| R-P16 | Canal de derechos del titular sin responsable, SLA ni radicado; incumplimiento de plazos de consulta/reclamo | Alta | Alto | Designar área (art. 2.2.2.25.4.4); radicado; calendario de días hábiles; leyenda "reclamo en trámite"; verificación de identidad | Baja–Media | RNF-059; AC-111-1…5 |
| R-P17 | Cédula/NIT capturada, copiada al pedido y enviada al ticket sin necesidad | Media | Alto | No persistirla en el perfil del MVP (DM-02); ticket sin facturación en el flujo de la app; acceso restringido a pedidos | Media | `DM` RM-01 |
| R-P18 | Cambio normativo (reforma de la Ley 1581, circulares SIC nuevas) altera obligaciones | Media | Medio | Revisión normativa antes del piloto; diseño modular de consentimientos | Media | — |
| R-P19 | WhatsApp: datos de clientes en celulares personales de asesores o sin política de conservación | Media | Medio | Canales corporativos (RF-095, D-09); procedimiento de conservación; informar en política | Media | RF-073, RF-080 |
| R-P20 | Plugins de WordPress (Wordfence, Wompi, otros) envían datos a terceros no inventariados | Media | Medio | Inventario de plugins y de destinos de red en staging (MED-10) | Media (DESCONOCIDO) | RNF-061 |

---

## 10. Preguntas y decisiones para el equipo jurídico de IPR (D-12 ampliado)

**Prioridad:** **P0** = bloquea la publicación/piloto; **P1** = debe resolverse antes del lanzamiento; **P2** = mejora o fase 2. Las preguntas repiten, amplían y ordenan D-12.

### 10.1 P0 — Antes de publicar

| ID | Pregunta / decisión | Por qué importa | Insumo técnico |
|---|---|---|---|
| J-01 | ¿La política y los avisos deben basarse en **autorización para todas las finalidades** de la cuenta y la compra, dado que el art. 10 no incluye contrato ni interés legítimo? ¿Qué finalidades requieren autorización separada? | Define pantallas y prueba | §4.1, §4.2 |
| J-02 | ¿La **Política de Tratamiento vigente** cubre: app móvil, identificadores de dispositivo, reporte de fallos, seguridad/auditoría, WhatsApp, proveedores en el exterior, retención, canal de derechos y fecha de vigencia (art. 2.2.2.25.3.1)? ¿Se actualiza antes de publicar? | Sin política vigente y completa no hay base informada | §11.2 |
| J-03 | ¿Inverprimos supera el umbral de **100.000 UVT** de activos y está obligada al RNBD? ¿Qué bases están inscritas? ¿Las bases nuevas (consentimientos, sesiones/dispositivos, auditoría) deben inscribirse en los **dos meses** posteriores a su creación? | Obligación y plazo | §2.3 |
| J-04 | **Eliminación de cuenta:** ¿qué datos deben conservarse por obligación contable/tributaria, **con qué norma y por cuánto tiempo**? ¿Se anonimizan los pedidos y qué campos? ¿Qué texto de aviso verá el usuario (AC-110-2)? | Texto obligatorio para Apple y para el usuario | §5.3 |
| J-05 | ¿La referencia "plazos de 5 a 10 años" de `AUTH` §12.2 es correcta? ¿Qué norma la sustenta? (**No verificada** en esta evaluación.) | Evita adoptar un plazo sin sustento | §5.3 |
| J-06 | **Contratos con encargados:** ¿existen contratos o cláusulas de transmisión (art. 2.2.2.25.5.2) con Cloudflare, DigitalOcean, hosting de WordPress, SMTP y proveedor de fallos? ¿Quién los firma? | Condición de la transmisión sin consentimiento adicional | §2.2, §6 |
| J-07 | **Wompi:** ¿es responsable independiente o encargado? ¿Qué datos del cliente recibe del plugin (incluida cédula/NIT)? ¿Se guardan medios de pago tokenizados? | Alcance de la política y de la supresión | §2.2, §5.3 |
| J-08 | **Cuentas web existentes sin prueba de aceptación:** ¿cómo se obtiene y registra la autorización la primera vez que usan la app? ¿Se bloquea hasta aceptar? | Evita tratar datos de cuentas existentes sin prueba | §4.3 |
| J-09 | ¿Qué debe guardarse exactamente como **prueba de la autorización** (versión, fecha, huella del texto, canal, IP)? ¿Por cuánto tiempo tras la supresión? | Define `ipr_consents` | §4.3 |
| J-10 | **PQRS:** ¿qué autorización y qué texto se muestran? ¿Se persiste la solicitud (opción B de DM-04) o se acepta `user_id` nulo + `subject_hash` (opción A)? ¿Cuánto se conservan las PQRS y el buzón? | Hoy no hay prueba ni retención | §3.3 H-P2 |
| J-11 | ¿Quién es el **área o persona designada** para consultas y reclamos (art. 2.2.2.25.4.4), con qué canal, SLA y radicado? | Plazos de 10/15 días hábiles | §5.1 |
| J-12 | **Reporte de fallos:** ¿los datos técnicos con identificador de instalación son dato personal que requiere autorización? ¿Se ofrece opción de desactivarlo? ¿Qué proveedor (Crashlytics/Sentry) y en qué región? | Decide proveedor y pantalla de ajustes | §3.2 F-10, §6.2 |
| J-13 | ¿Está aprobado el **inventario de datos** de §3 (campo, finalidad, retención) como requisito para publicar (RNF-060)? Firmar o corregir. | Requisito de publicación | §3 |

### 10.2 P1 — Antes del lanzamiento

| ID | Pregunta / decisión | Por qué importa | Insumo técnico |
|---|---|---|---|
| J-14 | **Ubicación (fase 2):** si las coordenadas aproximadas **no salen del dispositivo**, ¿basta el permiso del SO más un aviso o se requiere autorización registrada? | Define C-05 | §4.2 |
| J-15 | **Menores:** ¿qué declaración de edad se exige? ¿Cómo se responden los formularios de público objetivo/clasificación por edad de Apple y Google? ¿Qué hacer si se detecta un menor (art. 7; art. 2.2.2.25.2.9)? | Evita tratamiento prohibido | §4.2 C-10 |
| J-16 | **Verificación de identidad** para derechos ejercidos por correo/PQRS (sin cuenta): ¿qué documentos pedir sin excederse? | Suplantación vs minimización | §5.2 |
| J-17 | **Supresión:** ¿cómo se concilian el art. 8 e (condición de la SIC en ciertos casos) y el art. 2.2.2.25.2.6 (supresión por reclamo, salvo deber legal/contractual)? ¿Hay periodo de arrepentimiento? ¿Se permite eliminar con pedidos en curso (AC-110-8)? | Flujo y texto | §5.1, §5.3 |
| J-18 | ¿Se ofrece **exportación de datos** al titular (RNF-059)? ¿Con qué formato y verificación? | Backlog de API | §5.2 |
| J-19 | **Transferencias:** ¿qué proveedores están en países con nivel adecuado según la **lista vigente** de la SIC? ¿Se requiere autorización expresa e inequívoca (art. 26 a) para alguno? ¿Se acude a declaración de conformidad? | Cumplimiento de art. 26 | §6.2 |
| J-20 | **Etiquetas de las tiendas:** ¿se aprueban las respuestas de §8 (identificador de instalación, cédula/NIT, pago, diagnósticos)? | Riesgo de rechazo o retiro | §8 |
| J-21 | **Política de retención por flujo:** logs de borde y BFF (≥ 90 días propuesto), auditoría (90 días propuesto), buzones, WhatsApp, campañas, copias de seguridad. | Hoy casi todo es D-12 | §5.3 |
| J-22 | **Cédula/NIT:** ¿se persiste en el perfil o solo en el checkout (DM-02)? ¿Se limita su visibilidad en pedidos? | Dato de riesgo alto | §3.2 F-03 |
| J-23 | **Texto del aviso del checkout en la web** (C-08): ¿qué política rige el flujo en el sitio y en Wompi? ¿Hay aviso de cookies del sitio (WordPress/WooCommerce/Wompi)? | La experiencia termina fuera de la app | §4.2 |
| J-24 | **Cambios de versión de política:** ¿bloquear hasta aceptar la nueva versión o solo avisar? ¿Qué cambios son "sustanciales" (art. 2.2.2.25.3.1)? | AC-039-7 | §4.3 |
| J-25 | **WhatsApp:** ¿qué producto usa IPR (Business app/API/CRM), quién accede y por cuánto se guardan los chats? ¿Se usan celulares personales? | Datos fuera de la app | §2.2 |
| J-26 | **Incidentes de seguridad:** protocolo, responsables y canal hacia la SIC (art. 17 n, 18 k) y hacia los titulares. ¿Qué plazos operativos fija la SIC vigentes (no verificados aquí)? | Deber legal verificado; plazos no | §2.3, R-P11 |
| J-27 | **Contratos de proveedores tecnológicos:** ¿se incorporarán las recomendaciones de la CE 002/2025 (responsabilidades, seguridad, garantías internacionales, auditoría)? | Instrucción reciente de la SIC | §1.1 |

### 10.3 P2 — Fase 2 y mejora

| ID | Pregunta / decisión | Por qué importa | Insumo técnico |
|---|---|---|---|
| J-28 | **Push y mercadeo:** eventos permitidos, texto de consentimiento por categoría, revocación, prueba (D-11). | Define fase 2 | §4.2 C-03, C-04 |
| J-29 | **Analítica de uso** (RF-065, PA-08): ¿se admite medición agregada sin identificadores? ¿Con qué autorización? | Hoy apagada | F-15 |
| J-30 | **Campañas** (ruleta/raspa): ¿qué autorización, términos y retención aplican a las tablas y a los exportes CSV actuales? ¿Qué se hace con los datos ya recolectados? | Datos reales en producción | F-19; H-P4 |
| J-31 | **Ley 1266 de 2008:** ¿IPR reporta o consulta centrales de riesgo o gestiona cartera de forma que aplique? (SUPUESTO: no.) | Régimen distinto | §1.1 |
| J-32 | **Directorio de asesores en la web:** ¿existe autorización de los empleados y política de retiro? ¿Se deja como está? | Fuera de la app | F-20; R-P15 |
| J-33 | **Biometría opcional** (huella/rostro para desbloquear): ¿se permite como dato sensible con autorización explícita? | Evita introducirla sin análisis | §7.1 |
| J-34 | **Reforma de la Ley 1581 en trámite:** ¿quién vigila su avance y cómo se adapta el diseño (transferencias en dos niveles, evaluación de impacto)? | Cambio normativo | §1.1 |
| J-35 | **Evaluación de impacto de privacidad** formal para la app (responsabilidad demostrada, arts. 2.2.2.25.6.1–6.2; CE 002/2025): ¿se adopta este documento como base y quién la firma? | Evidencia ante la SIC | §1.1 |
| J-36 | **Verificación de correo antes de comprar** (RF-046, PA-02): ¿tiene implicaciones de privacidad (confirmación de titularidad del correo)? | Calidad y veracidad del dato (art. 4 d) | `AUTH` §10 |

**Total: 36 preguntas/decisiones (13 P0, 14 P1, 9 P2).**

---

## 11. Documentos y confirmaciones que IPR debe entregar

### 11.1 Decisiones técnicas relacionadas (para el equipo del proyecto, no para el jurídico)

| ID | Decisión | Dueño | Referencia |
|---|---|---|---|
| T-P1 | Proveedor de fallos y región (DN-02) | TI + Jurídico | ADR-010 |
| T-P2 | Cédula/NIT en el perfil (DM-02) | Equipo web + Jurídico | `DM` |
| T-P3 | Unificar almacenamiento de direcciones (DM-03) | Equipo web | `DM` |
| T-P4 | Persistir o no la PQRS mínima (DM-04) | Jurídico + arquitecto | `DM` |
| T-P5 | Añadir al `ipr_consents` huella del texto y decidir IP | Modelador de datos + Jurídico | §4.3 |
| T-P6 | `UserProfile.id` opaco o ausente (DM-01) | Arquitecto de API | `DM` |

### 11.2 Documentos y datos que IPR debe entregar (pendientes)

| # | Documento / dato | Para qué | Pregunta relacionada |
|---|---|---|---|
| 1 | **Política de Tratamiento de Datos Personales vigente** (PDF; versión y fecha). La URL aparece fijada en el código de la ruleta (`RM:48`); **no se descargó**. | Contraste con el inventario (§3) | J-02 |
| 2 | **Términos y condiciones** vigentes (PDF) | C-01 | J-02 |
| 3 | **Aviso de privacidad** (si existe) y textos de autorización usados hoy en registro, checkout, PQRS y boletín | Comparar con §4 | J-01, J-10 |
| 4 | **Constancia de inscripción en el RNBD** y detalle de las bases inscritas (o confirmación de que no aplica y por qué) | Obligación y plazo | J-03 |
| 5 | **Activos totales** (para el umbral de 100.000 UVT) — dato de Contabilidad | RNBD | J-03 |
| 6 | **Manual interno de políticas y procedimientos** de datos personales (art. 17 k) | Deber del responsable | J-11 |
| 7 | **Contratos o cláusulas con encargados** (hosting de WordPress, DigitalOcean, Cloudflare, SMTP, proveedor de fallos) | Transmisión | J-06, J-27 |
| 8 | **Términos y política de Wompi** aplicables al comercio; configuración del plugin (datos enviados, tokenización, webhook) | Rol de Wompi | J-07 |
| 9 | **Canal vigente de derechos del titular**, área designada y procedimiento de reclamos | RF-111 | J-11, J-16 |
| 10 | **Protocolo de incidentes de seguridad** (si existe) | Deber de informar | J-26 |
| 11 | **Política de retención** o criterios actuales por sistema (buzón PQRS, WhatsApp, WordPress, copias de seguridad, campañas) | Retención | J-21 |
| 12 | **Regiones y países** de DigitalOcean, hosting de WordPress, SMTP y plan de Cloudflare | Transmisión internacional | J-19 |
| 13 | **Facturación electrónica:** sistema, proveedor, datos y plazos de conservación | Eliminación de cuenta | J-04 |
| 14 | **Autorizaciones y términos de las campañas** (ruleta y raspa), y estado de los datos recolectados | Campañas | J-30 |
| 15 | **Configuración de Wordfence y lista de plugins** de WordPress | Terceros no inventariados | R-P20 |
| 16 | **Titularidad de las cuentas** de Google Play y Apple a nombre de Inverprimos S.A.S. (D-14) y responsables de firmas | Responsable de las fichas de privacidad | J-20 |

---

## 12. Relación con requisitos y criterios (trazabilidad)

| Tema | RNF | RF | AC |
|---|---|---|---|
| Autorización y prueba | RNF-056, RNF-057 | RF-039, RF-099 | AC-039-1…7, AC-038-4, AC-099-6 |
| Eliminación de cuenta | RNF-058, RNF-062 | RF-110 | AC-110-1…16 |
| Derechos del titular | RNF-059 | RF-111 | AC-111-1…5 |
| Minimización de datos y permisos | RNF-060 | RF-078 (fase 2) | AC-SEC-10 |
| SDKs y transferencias | RNF-061, RNF-097 | RF-065 | AC-SEC-2, AC-SEC-4 |
| Retención | RNF-063 | — | AC-110-15 |
| RNBD y bases nuevas | RNF-064 | — | — |
| Empleados y campañas | RNF-065 | RF-102, RF-103 | — |
| Push y mercadeo | RNF-066 | RF-090–093 | — |
| Auditoría y logs sin PII | RNF-047, RNF-105 | — | AC-SEC-4, AC-110-15 |

## 13. Limitaciones de esta evaluación

1. **Texto legal:** la Ley 1581 se verificó en una copia oficial del Archivo General de la Nación de 2022; el Decreto 1074 (Cap. 25 y 26), en la compilación de Colpensiones actualizada en 2020; la CE 002/2025, en el normograma de MinTIC. **No** se pudo contrastar en SUIN-Juriscol, Función Pública ni en el sitio de la SIC (errores de certificado/conexión; no se eludió la verificación del certificado). El jurídico debe confirmar la vigencia de cada artículo citado.
2. **No se leyeron** la política de datos ni los términos de IPR, ni el texto del formulario de PQRS de la página, ni la Circular Única (Título V) de la SIC.
3. **Proveedores:** país/región de DigitalOcean, hosting de WordPress, SMTP, Wompi y plan de Cloudflare son **DESCONOCIDOS**; la región de Sentry **NO VERIFICADA**.
4. **Ninguna** afirmación de este documento acredita cumplimiento. Es un insumo técnico para el equipo jurídico.

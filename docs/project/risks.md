# Matriz de riesgos consolidada — App móvil IPR

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fecha** | 2026-11-18 |
| **Estado** | **BORRADOR para validación.** Consolida riesgos ya documentados; no hay riesgo verificado ni mitigación ejecutada. |
| **Relacionado** | [roadmap.md](roadmap.md) · [implementation_plan.md](implementation_plan.md) · [decisions_log.md](decisions_log.md) · [threat_model.md](../06_security/threat_model.md) · [privacy_assessment.md](../06_security/privacy_assessment.md) |

## 1. Cómo leer esta matriz

**Fuentes que se consolidan (sin duplicados):** riesgos del informe de investigación (`R-01..R-10`, INV §6); riesgos de requisitos (`R-11`, `R-12`, FR §4) y de RNF (`R-NF-01..15`); riesgos de arquitectura de la app (`RA-01..12`, OV §8) y de la API (`RA-01..12`, ARQ §17.2, citados como "ARQ RA-xx"); hallazgos del análisis de la capa WooCommerce (`RB-01..12`); amenazas STRIDE de mayor riesgo (`TM-xxx`); contradicciones más graves (`CR-xxx`); riesgos de privacidad (`R-P01..20`) y de datos (`RM-01..14`); riesgos de calidad (`R-Q01..14`); y riesgos de plan y de negocio identificados al consolidar este roadmap (sin ID de fuente: se marca "Plan").

**Criterios de valoración (propuesta de este documento):**

| Concepto | Definición |
|---|---|
| **Probabilidad (P)** y **Impacto (I)** | Escala 1-5 igual a la de [threat_model §1.3-1.4](../06_security/threat_model.md). Donde la fuente usa Alta/Media/Baja se mapea: Alta = 4, Media = 3, Baja = 2; impacto Alto = 4, Medio = 3, Bajo = 2. Si hay varias fuentes se toma la de **mayor exposición**. Las filas con fuente `Plan` son **estimaciones de planificación, no verificadas**. |
| **Exposición (E)** | P × I. Bandas del modelo de amenazas: Bajo 1-5 · Medio 6-11 · Alto 12-19 · Crítico 20-25. |
| **Momento de valoración** | **Antes de mitigar**: ninguna mitigación está implementada (todo cambio P0 está en estado Abierto, security_controls §3). Por eso el número de riesgos Altos es elevado; no indica que el proyecto sea inviable sino cuánto trabajo y cuántas decisiones faltan. |
| **Estado** | **Abierto** (identificado, sin mitigación ejecutada) · **Pendiente de aceptación** (la fuente propone aceptarlo, requiere firma) · **Pendiente de decisión** (depende de una decisión humana). Ninguno está "Mitigado" o "Cerrado". |
| **Disparador** | Señal observable que indica que el riesgo se está materializando. |
| **Responsable sugerido** | Rol, sin nombres (ver [roadmap §2.3](roadmap.md)). |
| **Mitigación** | Remite a paquetes de trabajo `PT-xx` de [implementation_plan.md](implementation_plan.md) y a cambios `FE/WP/CH` de [security_controls §3](../06_security/security_controls.md). |

---

## 2. Plan y negocio (RK-001 a RK-013)

| ID | Riesgo | Fuente | P | I | E | Mitigación | Resp. | Disparador | Estado |
|---|---|---|---|---|---|---|---|---|---|
| RK-001 | **Equipo, presupuesto y dedicación sin definir:** no se puede estimar ni calendarizar; el pentest, las herramientas de carga y las granjas de dispositivos no tienen presupuesto | Plan; D-15; DN-13; Q-11 (testing) | 4 | 4 | **16** | Obtener D-15 antes de cerrar la Etapa 1; usar esfuerzo relativo; plan de recorte ([roadmap §6](roadmap.md)) | Gerencia | D-15 sin respuesta al cerrar la Etapa 1 | Pendiente de decisión |
| RK-002 | **Sin conformidad del responsable técnico de `ipr-frontend` y WordPress (C1)** o sin revisión por PR: no se puede tocar el repositorio ni el backend | ADR-001 C1; NL-12; INV R-09 | 3 | 5 | **15** | Reunión técnica; acuerdo escrito de reglas de rama y revisión (QG-M11, RNF-095); PT-01, PT-03 | Gerencia + Web | Sin acta de conformidad; PR sin revisor asignado | Abierto |
| RK-003 | **Staging con Wompi sandbox inexistente o no autorizado (C2, D-16, H-12):** sin él no hay resolución de DESCONOCIDOS, E2E de compra ni pruebas de seguridad (criterio absoluto NLS-08/NL-02) | ADR-001 C2; R-Q01; NLS-08; DA-13 | 3 | 5 | **15** | Escalar como bloqueante; PT-02; aprobar H-12 | TI + Web | H-12 sin respuesta; sin dominio de staging | Pendiente de decisión |
| RK-004 | **Decisiones humanas pendientes frenan o rehacen la construcción:** 12 recomendaciones H sin aprobar, 20 ADR en Propuesta, 89 CR sin aplicar, 107 AC con `[A VALIDAR]` | resolución §4.3; R-Q07; DA-01; AP-01 | 4 | 4 | **16** | Calendario de decisiones y orden de aprobación sugerido ([decisions_log §10](decisions_log.md)); PT-01; registrar `[A VALIDAR]` como decisión, no como defecto (testing §8.2) | BA + Arq | Una rebanada llega a implementación con AC `[A VALIDAR]` sin resolver | Pendiente de decisión |
| RK-005 | **El alcance de backend es mayor que el aprobado:** la ampliación de `ipr/v1/m/*` supera el "únicamente" de ADR-001 §2; la verificación de correo entraría al MVP si se aprueba H-03(b); más trabajo en WordPress | CR-038; CR-030; resolución §5 hallazgos 1-2 | 4 | 3 | **12** | Aprobar la enmienda H-01 antes de G1; decidir H-03; dimensionar PT-07/08/09 | Solicitante + Arq | H-01/H-03 sin decidir al empezar PT-07 | Pendiente de decisión |
| RK-006 | **Demanda móvil no demostrada y sin metas ni analítica:** no hay datos de uso móvil de la web ni metas O-1..O-5; el valor del MVP no es medible | vision V-1, §4; MED-01; MED-18; PA-08 | 3 | 3 | 9 | Medir con Cloudflare/servidor (MED-01) y WooCommerce (MED-18); pedir metas a Gerencia | Gerencia + Prod | MED-01/18 sin ejecutar | Abierto |
| RK-007 | **Pérdida de ventas por productos sin precio y B2B atendidos solo por WhatsApp** | FR R-11; ADR-002; vision §10 | 3 | 3 | 9 | RF-065 (medición agregada; requiere PA-08 y D-12); SLA de asesores (PA-07) | Prod | Muchas consultas "Más información" sin respuesta | Abierto |
| RK-008 | **Operación y soporte posteriores sin responsable ni SLA** (WhatsApp, PQRS, incidentes, versión mínima) | DN-06; PA-07; D-15; Plan | 3 | 3 | 9 | Definir responsables y horario antes del piloto; PT-22 | Gerencia + Prod | Piloto sin responsable de soporte | Pendiente de decisión |
| RK-009 | **Cuentas de tienda y claves de firma sin titularidad ni custodia de IPR** (el identificador de producción no se puede cambiar tras publicar) | D-14; NL-11; TM-051; SC-040; DA-12 | 3 | 4 | **12** | Confirmar titularidad a nombre de Inverprimos S.A.S.; ≥ 2 custodios con 2FA; PT-24 | Gerencia + TI | Cuentas a nombre de una persona o tercero | Abierto |
| RK-010 | **Rechazo o retiro por las tiendas:** política de privacidad, eliminación de cuenta desde la app (supuesto S-05 no verificado), etiquetas de privacidad que no coinciden con el tráfico real | S-05; R-P13; RNF-080; J-20 | 3 | 4 | **12** | Verificar guías vigentes antes de F4; captura de tráfico en staging; revisión de Jurídico; PT-21, PT-24 | Jur + Móvil | Cambio de guías de la tienda; etiqueta no coincide con el tráfico | Abierto |
| RK-011 | **Calidad del catálogo:** precios 0, categorías sucias, marcas heurísticas, sin imagen; la app los expone más que la web | INV R-05; OV RA-12; D-10; MED-06; RB-08 | 4 | 3 | **12** | Auditoría MED-06; reglas mínimas (D-10); placeholders y tolerancia a nulos en la app; PT-23 | Cat + Web | MED-06 muestra productos con precio ≤ 0 comprables | Abierto |
| RK-012 | **Cifras institucionales y datos de sedes inconsistentes o insuficientes** (31/32 sedes, 885/10.000 referencias; sin coordenadas ni horarios; teléfonos posiblemente personales) | INV §8; D-07; D-09; S-06; R-P19; RM-07 | 3 | 2 | 6 | No publicar cifras sin D-07; respaldo empaquetado de sedes (ADR-018); confirmar canales corporativos; PT-10, PT-23 | Mkt + Ops | Hoja maestra no entregada | Abierto |
| RK-013 | **Calculadora BTU sin validación de Ingeniería o con error de fórmula** | D-08; COD §6; RF-085..089 | 3 | 3 | 9 | Módulo condicionado a D-08; ≥ 30 vectores validados (FA §15); PT-23 | Ing | D-08 sin firma al cerrar M5 | Pendiente de decisión |

## 3. Arquitectura e integración (RK-014 a RK-029)

| ID | Riesgo | Fuente | P | I | E | Mitigación | Resp. | Disparador | Estado |
|---|---|---|---|---|---|---|---|---|---|
| RK-014 | **El retorno del pago no llega a la app:** WordPress no redirige en `failed/cancelled/pending`; el App/Universal Link tras una redirección 302 en Custom Tabs/ASWebAuthenticationSession no está verificado; el callback https de iOS exige 17.4 | OV RA-01; ARQ RA-04; R-NF-12; CR-001..004; SPK-01 | 4 | 4 | **16** | La consulta autenticada EP-24 es la fuente de verdad y el enlace solo acelera (ADR-008 + ADR-017 fusionadas, H-02); SPK-01 por plataforma; PT-11, PT-12, PT-16 | Móvil + Web | SPK-01 muestra que el enlace no se dispara en una versión mínima | Abierto |
| RK-015 | **Doble pago / pedidos duplicados con confirmación de Wompi desconocida:** webhook, estados (`on-hold`) y control de duplicados DESCONOCIDOS (D-02, PA-11, PA-12) | TM-027; TM-030; OV RA-03; ARQ RA-07; RM-13; CR-018; NLS-06 | 3 | 4 | **12** (residual 8 "no aceptable sin cerrar D-02/PA-11") | Pruebas en staging con Wompi sandbox (100 interrupciones por plataforma, ST-086, ST-089); `Idempotency-Key` obligatoria (CR-005); botón de pago bloqueado; PT-02, PT-06, PT-08, PT-16 | WP + Finanzas + Web | Un duplicado en el sandbox; estado `on-hold` inesperado | Pendiente de decisión |
| RK-016 | **El ticket de 60 s vence** con red lenta o con la app en segundo plano; el pago se bloquea | OV RA-04; R-NF-11; RNF-026 | 3 | 4 | **12** | Abrir el navegador de inmediato (≤ 5 s); un reintento automático de ticket; "Reintentar pago"; PT-16 | Móvil | TC de ticket expirado falla | Abierto |
| RK-017 | **Contrato `/mobile/v1` inestable o tardío:** OpenAPI `1.0.0-draft` con 27 endpoints propuestos y 89 CR que lo tocan | OV RA-02; CR-086; R-Q04; R-Q14 | 3 | 4 | **12** | Aplicar CR y congelar `1.0.0` (PT-01); capa `data` aislada con DTO; BFF simulado y pruebas de contrato (PT-13, PT-19); `oasdiff` | Arq + Web | Cambio incompatible detectado por el detector de contrato | Abierto |
| RK-018 | **Falsos vacíos o 404 por fallos aguas arriba:** el código actual convierte errores en "vacío" o `null`; el carrito pierde ítems o la búsqueda dice "sin resultados" | OV RA-05; TM-021; RB-02; ARQ RA-02 | 4 | 4 | **16** | FE-02 (variantes discriminadas sin cambiar firmas); semántica 404/502/503/504 (ADR-016); el carrito nunca elimina por error de red; PT-04, PT-05, PT-14, PT-16 | Web + Móvil | TC-099..TC-106 fallan | Abierto |
| RK-019 | **Proceso Node compartido se degrada:** cola de `wcGet` sin tope, búsqueda en CPU sobre hasta 10.000 entradas, índice en RAM; la web y la app caen juntas; capacidad DESCONOCIDA | TM-017; OV RA-09; RB-03; R-NF-01; R-NF-03; ARQ RA-03; ADR-001 C4 | 3 | 4 | **12** | FE-06 (cola acotada, espera ≤ 3 s), FE-07 (señal "índice en construcción"); caché de borde; *debounce*; prueba de carga y piloto C4 (BE-20); PT-04, PT-19, PT-24 | Web + TI | p95 de catálogo > 2,5 s o cola > 1 s (disparadores de ARQ §14) | Abierto |
| RK-020 | **Rate limit en memoria evadible y número de procesos Node desconocido:** la IP sale de `X-Forwarded-For` y el mapa se vacía al pasar de 5.000 claves; si hay más de un proceso, los contadores no protegen | TM-018; CR-035; ARQ RA-05; R-NF-01; SA-01 | 4 | 3 | **12** | FE-05 (LRU, `CF-Connecting-IP`); contadores de autenticación en BD de WordPress; verificar SA-01; si hay > 1 proceso, Redis pasa a P0 (ADR-015); PT-02, PT-04, PT-07 | Web + TI | MED-04 revela > 1 proceso | Pendiente de decisión |
| RK-021 | **Cloudflare desafía o bloquea a la app** (Bot Fight Mode, CAPTCHA, TLS mínimo) o desafía `.well-known` | INV R-02; OV RA-06; ARQ RA-06; R-NF-06; R-Q11; MED-15; ADR-001 C3 | 3 | 4 | **12** | Reglas por ruta para `/mobile/v1/*` y `/.well-known/*`; cabeceras propias; probar en staging; PT-11 | TI | 403/desafío en tráfico sintético | Abierto |
| RK-022 | **Origen expuesto o WordPress sin Cloudflare:** evasión del WAF y de los límites; `wp-login.php`, `xmlrpc.php` y `ipr/v1/auth/*` accesibles; IP de origen versionada | TM-002; TM-052; CR-075; SA-03; SUP-SEC-11 | 3 | 4 | **12** | Origen solo desde rangos de Cloudflare o *Authenticated Origin Pulls*; contadores en WordPress; IP de origen fuera del repo; PT-11 | TI | El origen responde a tráfico directo en 80/443 | Abierto |
| RK-023 | **Despliegue acoplado web + BFF sin pruebas ni puertas:** un cambio de la web rompe `/mobile/v1` y viceversa; el workflow despliega en cada *push* sin `tsc`, lint ni `npm audit` | RB-09; ARQ RA-08; R-Q05; R-NF-07; SEC-10; TM-050 | 4 | 3 | **12** | FE-11 y QG-B01..B07 como condición de despliegue; pruebas de caracterización BE-01; PT-03 | Web + TI | Despliegue sin las puertas activas | Abierto |
| RK-024 | **Cambios obligatorios en snippets compartidos rompen la web en producción:** cookie y rol del handoff (CR-010), formato del ticket (CR-012), direcciones (CR-045); hace falta staging y regresión **antes** de la app | CR-010; CR-012; CR-045; resolución §5 hallazgo 3 | 3 | 4 | **12** | Hacer los cambios solo tras C2; regresión de la web (QG-B06); feature flag o despliegue escalonado; PT-08, PT-09 | WP + QA | Fallo del login web o del handoff web en staging | Abierto |
| RK-025 | **Direcciones guardadas en un meta propio que WooCommerce no lee:** el prellenado puede romperse y la eliminación de datos personales dejar restos | CR-045; DM-03; RM-05; INC-05 | 3 | 4 | **12** | Migrar a `WC_Customer` con respaldo del meta heredado (WP-08); verificar en staging antes de quitar la facturación del ticket; PT-09 | WP | El checkout de la app llega sin datos prellenados | Abierto |
| RK-026 | **Imágenes a tamaño original:** consumo de datos, memoria y batería; variantes optimizadas DESCONOCIDAS | R-NF-04; INV R-10; RB-12; DN-03; MED-07 | 4 | 3 | **12** | Medir (MED-07); decidir variantes (WordPress, Cloudflare Images o proxy; desaconsejado el optimizador de Next); `cached_network_image` con tamaño en memoria; PT-10, PT-23 | TI web | Peso de imagen medio > presupuesto de RNF-009 | Pendiente de decisión |
| RK-027 | **Mínimos de Android/iOS, plugins y rendimiento:** Flutter 3.50 y plugins pueden superar los mínimos propuestos (API 26, iOS 15); la matriz de dispositivos carece de datos de la clientela; arranque en gama baja | OV RA-10; R-NF-13; R-Q06; DN-01; SPK-02; MED-01; MED-11; NL-C1 | 3 | 3 | 9 | SPK-02 y MED-11 en la Etapa 2; matriz por ranuras y ajuste con el piloto; PT-12, PT-19 | Móvil + QA | SPK-02 eleva los mínimos | Pendiente de decisión |
| RK-028 | **Dependencias Flutter de terceros abandonadas o inmaduras:** `hive_ce` es un *fork* comunitario; versiones muy recientes (Flutter 3.50, Riverpod 3, go_router 18) | OV RA-08; RNF-094; FA §17 | 3 | 3 | 9 | Encapsular cada paquete tras una interfaz de `core`; revisión mensual; OSV sobre `pubspec.lock`; PT-13, PT-20 | Móvil | Paquete sin publicación o con CVE | Abierto |
| RK-029 | **Código de WordPress sin repositorio ni procedimiento de migración:** solo existen los snippets; las tablas nuevas requieren `dbDelta` versionado y acceso al hosting | AUT RS-02; SA-02; COD §0 | 3 | 3 | 9 | Plugin propio (`mu-plugin`) con `dbDelta` versionado y prueba en staging; versionar los snippets en un repositorio con PR; PT-07 | WP + TI | Hosting no permite crear tablas | Abierto |

## 4. Seguridad (RK-030 a RK-047)

| ID | Riesgo | Fuente | P | I | E | Mitigación | Resp. | Disparador | Estado |
|---|---|---|---|---|---|---|---|---|---|
| RK-030 | **Fuerza bruta y *credential stuffing* contra el login** sin límite efectivo; Wordfence con reglas DESCONOCIDAS; el login del BFF puede toparse con Wordfence por IP única | TM-001; COD H-04; R-NF-14; AUT RS-03; MED-10 | 4 | 4 | **16** | CH-02 (contadores persistentes en WordPress, `X-IPR-Client-IP` solo con secreto del BFF, reglas de Cloudflare); respuestas uniformes; alertas; PT-07, PT-11 | WP + TI | Pico de `invalid_credentials`; ST-040..042 fallan | Abierto |
| RK-031 | **Sesión única de 30 días, revocación incompleta, carrera de refresh y ventana de gracia:** un token robado vale un mes; iniciar sesión en la web cierra la app | TM-005; TM-009; TM-006..008; COD H-01, H-02; AUT RS-01; CR-022..027 | 3 | 4 | **12** | CH-01 y CH-04: sesiones por dispositivo, rotación con detección de reutilización, revocación global (H-04, H-05); PT-07 | WP | ST-030..039 fallan; `refresh_token_reused` > N/h | Abierto |
| RK-032 | **Escalada de privilegios por el handoff y por roles:** el login no filtra roles; el handoff abre sesión de WordPress con cookie persistente para cualquier rol | TM-010; TM-012; CR-010; CR-028; NLS-05 | 2 | 5 | 10 | CH-05: `user_id` en el ticket, cookie no persistente, denegar `edit_posts`/`manage_woocommerce` también en el handoff (web y app); contar roles (H-09); PT-07, PT-08. **Criterio absoluto de no-lanzamiento** | WP | ST-044/045 fallan | Abierto |
| RK-033 | **BOLA/IDOR en pedidos y `checkoutRef`** (endpoints nuevos con identificador) | TM-028; CR-009; SC-014 | 3 | 4 | **12** | CH-06: `customer_id` = usuario, 404 en pedidos ajenos, `checkoutRef` solo entre pedidos propios; PT-08 | WP + Web | ST-050..053 fallan con dos cuentas | Abierto |
| RK-034 | **Dependencias vulnerables:** 17 CVE (2 críticas) reportados en octubre de 2026 sin verificar; **`npm audit` y OSV nunca ejecutados**; plugins de WordPress sin inventario | TM-050; COD §5.2 SEC-05; MED-09; NLS-04 | 3 | 5 | **15** | Ejecutar y archivar MED-09 en la Etapa 0; SCA bloqueante en CI (SC-048); plazos críticas ≤ 7 d, altas ≤ 30 d; PT-03, PT-20 | Web + Seg | `npm audit` con críticas o altas | Abierto |
| RK-035 | **Exposición de borradores, ocultos o privados y de campos de más** (`stockQuantity`, `roles`, `username`, HTML crudo) | TM-014; TM-015; TM-031; RB-01; RB-05; SEC-07 | 4 | 3 | **12** | FE-01 (`status=publish`, visibilidad, contraseña), FE-03 (DTO por lista blanca); PT-04, PT-05, PT-09 | Web | ST-064..066 fallan | Abierto |
| RK-036 | **Scraping masivo de precios y catálogo**, amplificado por una API JSON paginada | TM-016 | 5 | 2 | 10 | `page ≤ 50`, `perPage` fijo, caché de borde, límites; **la fuente propone aceptarlo** (precios públicos) con monitoreo | Prod + Seg | Tráfico anómalo en `/mobile/v1/products` | Pendiente de aceptación |
| RK-037 | **Contenido activo (XSS) en descripciones** renderizadas por la app; sanitizador propio sin batería de pruebas | TM-019; COD §5.1 H-09; ADR-019; SPK-04 | 2 | 3 | 6 | Saneado en servidor con perfil móvil, batería XSS en CI, render nativo sin JavaScript; PT-05, PT-12 | Web | ST-067 con vectores no neutralizados | Abierto |
| RK-038 | **Fuga o envenenamiento por la caché de borde** de respuestas privadas | TM-020; NLS-07 | 2 | 4 | 8 | `Cache-Control: private, no-store` en lo autenticado; *Cache Rule* solo para rutas públicas; PT-05, PT-11 | Web + TI | ST-068/069 fallan | Abierto |
| RK-039 | **Enumeración de cuentas, cuentas falsas y bloqueo deliberado de cuentas ajenas** | TM-003; TM-056; TM-057; CR-030; COD H-06 | 4 | 2 | 8 | Decidir H-03 (respuesta uniforme + verificación de correo, o `409` con riesgo firmado); límites de registro; PT-07, PT-09 | Prod + Seg | Picos de registro; cuentas con correos inválidos | Pendiente de decisión |
| RK-040 | **Spam y suplantación en PQRS** con límite en memoria evadible | TM-036; TM-038; CH-18; RF-097 | 4 | 3 | **12** | Límite compartido (Cloudflare o WordPress), `Idempotency-Key`, marca "identidad no verificada"; PT-06, PT-11 | Web + TI | Bombardeo del buzón corporativo | Abierto |
| RK-041 | **Secretos de servidor y cadena de despliegue:** secretos en el binario, historial o logs de CI; `HANDOFF_SECRET` admitido como opción de BD; pipeline sin puertas; claves de firma | TM-042; TM-051; TM-060; TM-053; CH-13; CH-26 | 2 | 5 | 10 | Escaneo de secretos del historial y por PR; constantes en `wp-config.php`; rotación con doble valor; PT-03, PT-20 | Seg + TI | Hallazgo verdadero de secreto | Abierto |
| RK-042 | **Sin *pinning*, sin detección de root y sin atestación:** MITM con CA comprometida, clon reempaquetado; aceptación por escrito pendiente | TM-043; TM-044; ADR-011; DA-15; CH-22 | 2 | 4 | 8 | Compensatorios (TLS estricto, vencimiento corto de tokens, monitoreo de Certificate Transparency); **aceptación firmada** (CH-22); PT-20 | Seg + Gerencia | Falta de firma de DA-15 al cerrar la Etapa 5 | Pendiente de aceptación |
| RK-043 | **Fuga de tokens o datos en el dispositivo:** copias de seguridad, capturas, Keychain tras reinstalar | TM-006; TM-046; TM-047; TM-048; SPK-03 | 2 | 4 | 8 | Refresh y `deviceId` en Keychain/Keystore, access en memoria (SUP-SEC-07), exclusión de backups, `FLAG_SECURE`, limpieza al primer arranque; PT-13, PT-15 | Móvil | ST-100..107 fallan | Abierto |
| RK-044 | **PII o tokens en logs, reportes de fallos o analítica** (el código actual registra objetos de error completos) | TM-045; R-P07; NL-08; RNF-047 | 3 | 3 | 9 | `PiiScrubber`, logs del BFF con HMAC y prefijo de IP, pruebas con valores canario; PT-22 | Web + Móvil | Un canario aparece en logs | Abierto |
| RK-045 | **Phishing por `checkoutUrl` maliciosa o por configuración remota comprometida** (número de WhatsApp, `allowedHosts`) | TM-024; TM-040; SC-044; SUP-SEC-10 | 2 | 5 | 10 | `https` + `allowedHosts` empaquetados como límite superior; configuración editable solo por rol administrativo, auditada y validada; PT-10, PT-16 | Web + WP | ST-088, ST-141 fallan | Abierto |
| RK-046 | **Falsificación del resultado de pago mostrado en la app** (parámetros `order` y `status` del enlace) | TM-025; CR-002; SUP-SEC-02; SUP-SEC-13 | 3 | 3 | 9 | Mostrar solo lo devuelto por EP-24; solo `paid` vacía el carrito; PT-16 | Móvil | ST-082/083 fallan | Abierto |
| RK-047 | **Versiones antiguas de la app sin forma de forzar la actualización**; `v1` debe sostenerse ≥ 12 meses | TM-061; DN-14; SC-052 | 3 | 3 | 9 | `GET /config` con versión mínima y `426`; interruptor remoto del checkout; PT-05, PT-22 | Web + Móvil | Vulnerabilidad en una versión instalada | Abierto |

## 5. Privacidad y legal (RK-048 a RK-057)

| ID | Riesgo | Fuente | P | I | E | Mitigación | Resp. | Disparador | Estado |
|---|---|---|---|---|---|---|---|---|---|
| RK-048 | **La política vigente no se ha leído ni cubre la app; la autorización no tiene prueba** (registro actual sin versión ni fecha de aceptación; cuentas web existentes sin aceptación) | R-P01; R-P02; INV R-07; J-01; J-02; J-08 | 4 | 4 | **16** | Entregar los documentos a Jurídico; `ipr_consents` con versión; flujo para cuentas existentes; PT-09, PT-21 | Jur | Sin dictamen al llegar a M2 | Pendiente de decisión |
| RK-049 | **Eliminación de cuenta incompleta o que destruya soportes contables;** retención no definida (no adoptar "5 a 10 años" sin Jurídico) | TM-035; R-P06; CR-081; CR-083; J-04; J-05; J-17; H-11 | 3 | 4 | **12** | Tabla de retención validada por Jurídico y Finanzas; prueba E2E con revisión de datos; PT-09, PT-17, PT-21 | Jur + Finanzas | Sin respuesta de J-04/J-05 al llegar a M4 | Pendiente de decisión |
| RK-050 | **Canal de derechos del titular sin responsable, SLA ni radicado** | R-P16; J-11; RF-111 | 4 | 4 | **16** | Designar área y canal (art. 2.2.2.25.4.4); calendario de días hábiles; PT-21, PT-17 | Jur + Prod | Sin área designada al llegar a M4 | Pendiente de decisión |
| RK-051 | **Transmisión o transferencia internacional sin contratos ni inventario** (Cloudflare, proveedor de fallos, hosting, SMTP, Wompi); países DESCONOCIDOS | R-P03; R-NF-09; J-06; J-19; J-27; DN-02 | 3 | 4 | **12** | Inventario de encargados, contratos y región; elegir proveedor de fallos con Jurídico (DA-04); PT-21, PT-22 | Jur + TI | Proveedor de fallos elegido sin análisis | Abierto |
| RK-052 | **Bases nuevas sin dictamen ni evaluación de registro** (consentimientos, sesiones y dispositivos, auditoría) | R-P04; RM-10; J-03 | 3 | 3 | 9 | Confirmar umbral de activos (100.000 UVT, dato de Contabilidad); inscribir en los dos meses siguientes si aplica; PT-21 | Jur | Tablas creadas en producción sin dictamen | Abierto |
| RK-053 | **Cédula/NIT en el ticket, el pedido y el perfil sin mínimo necesario** (el dato de mayor riesgo del flujo de compra) | R-P17; RM-01; CR-012; DM-02; J-22 | 3 | 4 | **12** | Ticket de la app sin facturación (condicionado a CR-045); no persistir la cédula en el perfil del MVP (DM-02); PT-08, PT-09 | WP + Jur | La cédula aparece en el transient o en logs | Abierto |
| RK-054 | **PQRS sin evidencia de autorización ni retención definida** (texto libre `PERSONAL-ALTO`) | RM-04; CR-056; DM-04; J-10 | 4 | 3 | **12** | Decidir DM-04 (A: `user_id` nulo + `subject_hash`, B: persistir) con Jurídico; política de retención del buzón; PT-06, PT-21 | Jur + Web | Sin decisión de DM-04 al llegar a M5 | Pendiente de decisión |
| RK-055 | **Incidente de seguridad sin protocolo hacia la SIC y los titulares** | R-P11; J-26; CH-29 | 3 | 4 | **12** | Protocolo, roles y plantillas; manual de incidentes ensayado en staging; PT-21, PT-22 | Seg + Jur | Primer incidente sin procedimiento | Abierto |
| RK-056 | **Cambio normativo** (reforma de la Ley 1581 en trámite, circulares de la SIC) | R-P18; J-34 | 3 | 3 | 9 | Revisión normativa antes del piloto; diseño modular de consentimientos; PT-21 | Jur | Aprobación de una reforma | Abierto |
| RK-057 | **Campañas (ruleta y raspa) con datos personales y abuso en la web:** fuera del alcance de la app, pero riesgo vigente en producción | TM-055; R-P14; CH-31; J-30 | 4 | 3 | **12** | Mantenerlas fuera de la app; captcha, límite y validación de factura antes del cupo en la web (CH-31, P1); seguimiento por Web; PT-20 (seguimiento) | Web + Prod + Jur | Consumo anómalo de cupos | Abierto |

## 6. Calidad y accesibilidad (RK-058 a RK-059)

| ID | Riesgo | Fuente | P | I | E | Mitigación | Resp. | Disparador | Estado |
|---|---|---|---|---|---|---|---|---|---|
| RK-058 | **E2E de pago no automatizable o sandbox no representativo:** `patrol` puede no controlar el navegador seguro; el sandbox puede no simular el estado pendiente; pruebas inestables; la herramienta de carga k6 es AGPL y las herramientas del BFF pueden no ser compatibles con el Node/Next de producción | R-Q02; R-Q03; R-Q10; R-Q13; R-Q12; R-Q08; S-NF-06; H-Q3 | 3 | 4 | **12** | SPK-01 decide; guion manual con evidencia como alternativa; cuarentena de pruebas inestables; revisar licencia con IPR; spike de herramientas (Q-07); PT-12, PT-19 | QA + Móvil | SPK-01 no puede automatizar el navegador | Abierto |
| RK-059 | **Contraste de marca y accesibilidad:** el verde `#5ba628` ≈ 3,03:1 sobre blanco; el checkout externo no depende de la app; criterio NL-14 | OV RA-11; R-NF-08; R-NF-15; MED-12; D-13; DA-07 | 4 | 3 | **12** | Tokens con verde oscuro para texto (propuesta DA-07 `#3d7519`, a aprobar); verde original solo decorativo; pruebas TalkBack/VoiceOver y texto al 200 %; PT-13, PT-19 | Mkt + Móvil + QA | `textContrastGuideline` falla en pantallas críticas | Pendiente de decisión |

---

## 7. Resumen

| Banda de exposición | Riesgos | IDs |
|---|---|---|
| Crítico (20-25) | 0 | — |
| Alto (12-19) | **37** | RK-001, 002, 003, 004, 005, 009, 010, 011, 014, 015, 016, 017, 018, 019, 020, 021, 022, 023, 024, 025, 026, 030, 031, 033, 034, 035, 040, 048, 049, 050, 051, 053, 054, 055, 057, 058, 059 |
| Medio (6-11) | **22** | RK-006, 007, 008, 012, 013, 027, 028, 029, 032, 036, 037, 038, 039, 041, 042, 043, 044, 045, 046, 047, 052, 056 |
| Bajo (1-5) | 0 | — |
| **Total** | **59** | |

### 7.1 Los diez riesgos de mayor exposición

| # | ID | Riesgo (resumen) | E |
|---|---|---|---|
| 1 | RK-001 | Equipo y presupuesto sin definir | 16 |
| 2 | RK-004 | Decisiones humanas pendientes | 16 |
| 3 | RK-014 | El retorno del pago no llega a la app | 16 |
| 4 | RK-018 | Falsos vacíos y 404 por fallos aguas arriba | 16 |
| 5 | RK-030 | Fuerza bruta y *credential stuffing* | 16 |
| 6 | RK-048 | Política de datos y autorización sin prueba | 16 |
| 7 | RK-050 | Canal de derechos del titular sin responsable | 16 |
| 8 | RK-002 | Sin conformidad del responsable técnico (C1) | 15 |
| 9 | RK-003 | Sin staging con Wompi sandbox (C2) | 15 |
| 10 | RK-034 | Dependencias vulnerables sin auditar | 15 |

(Desempate entre exposiciones iguales: primero los que ya existen hoy o bloquean la ruta crítica.)

### 7.2 Riesgos que requieren aceptación formal y no se resuelven técnicamente

| ID | Decisión | Quién |
|---|---|---|
| RK-036 | Aceptar el *scraping* residual (precios públicos) con monitoreo | Prod + Seg |
| RK-042 | Aceptar por escrito la ausencia de *pinning*, de detección de root y de atestación (DA-15, NL-C7) | Seg + Gerencia |
| RK-039 | Aceptar enumeración de cuentas hasta la verificación de correo, o implantarla (H-03) | Prod + Seg |
| RK-015 | **No aceptable** sin cerrar D-02/PA-11 (NL-02) | Web + Finanzas |

### 7.3 Riesgos que bloquean el lanzamiento por criterio absoluto

NL-01 (RK-034, RK-035), NL-02 (RK-015, RK-046), NL-03 (RK-041), NL-04 (RK-031), NL-05 (RK-030, RK-031, RK-020), NL-06 (RK-033), NL-07 (RK-048, RK-049), NL-08 (RK-044), NL-09 (RK-008), NL-11 (RK-009), NL-12 (RK-002, RK-003, RK-021, RK-019), NL-13 (RK-011), NL-14 (RK-059); NLS-05 (RK-032), NLS-07 (RK-038), NLS-08 (RK-003). Fuente: [NFR §5.1](../02_requirements/non_functional_requirements.md), [security_controls §4](../06_security/security_controls.md).

### 7.4 Riesgos de las fuentes que se **fusionaron** (sin pérdida)

| Fuente | Se consolidó en |
|---|---|
| INV R-01 (usar `/api/*` como contrato) | Mitigado por diseño en ADR-001 (aprobada); no genera riesgo propio salvo drift de contrato → RK-017 |
| INV R-03, COD H-01/H-02, TM-005..009 | RK-031 |
| INV R-04, TM-027, TM-030, OV RA-03, ARQ RA-07, RM-13 | RK-015 |
| INV R-05, OV RA-12, RB-08 | RK-011 |
| INV R-06 (precios B2B) y FR R-06 | Fuera del MVP por ADR-002/D-03; se retoma en la Etapa 7 (no es riesgo del MVP; precio único público) |
| INV R-08, TM-062 (`localStorage` de la web) | No aplica a la app; cambio P2 CH-36 en la web (Etapa 7) |
| INV R-09, FR R-12 | RK-002, RK-019 |
| INV R-10, R-NF-04, RB-12, ARQ RA-12 | RK-026 |
| TM-011, TM-022, TM-026, TM-033, TM-037 (riesgo actual Bajo) | No se incluyen (exposición ≤ 5 con controles existentes); se verifican en las pruebas (ST-078, ST-080, ST-125, ST-037, ST-143) |
| TM-004, TM-007, TM-008, TM-013, TM-021, TM-029, TM-032, TM-034, TM-041, TM-049, TM-054, TM-058, TM-059 | Cubiertos por las mitigaciones de RK-031, RK-018, RK-023, RK-033, RK-045, RK-044 y por los cambios CH-03, CH-05, CH-24, CH-25; se mantienen en el modelo de amenazas |

*Fin del documento. BORRADOR: ningún riesgo está verificado ni mitigado.*

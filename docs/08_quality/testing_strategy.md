# Estrategia de pruebas — App móvil IPR (MVP)

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.), con compra vía Wompi |
| **Fase** | Calidad. No se programa nada. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para validación de IPR, del responsable técnico del repositorio y del equipo de seguridad |
| **Rol** | Ingeniería de QA Automation |
| **Fuentes** | [acceptance_criteria.md](../02_requirements/acceptance_criteria.md) · [non_functional_requirements.md](../02_requirements/non_functional_requirements.md) · [flutter_app_architecture.md](../03_architecture/flutter_app_architecture.md) · [api_architecture.md](../05_api/api_architecture.md) · [openapi.yaml](../05_api/openapi.yaml) · [informe_codigo_frontend.md](../00_discovery/informe_codigo_frontend.md) · [decisiones_pendientes.md](../project/decisiones_pendientes.md) |
| **Documentos hermanos** | [test_cases.md](test_cases.md) (160 casos) · [test_results.md](test_results.md) (plantilla) · [quality_metrics.md](quality_metrics.md) · pruebas de seguridad: `06_security/security_testing.md` (otro agente; puede no existir aún) |

> **Aviso central.** **Hoy no se ha ejecutado ninguna prueba.** La app no existe; el backend móvil `/mobile/v1` no existe (todas las operaciones del OpenAPI llevan `x-status: proposed`); el repositorio web no tiene pruebas automáticas y su CI solo despliega; el entorno *staging* con Wompi sandbox **no está confirmado** (condición C2 de ADR-001). Este documento es una estrategia propuesta, no un informe de calidad. Todos los umbrales proceden de los RNF y son **objetivos propuestos**, no mediciones.

---

## 0. Cómo leer este documento

| Tipo | Dónde está |
|---|---|
| **Hechos** (verificados en los documentos fuente o en el repositorio local) | Sección 1; versiones y estado de mantenimiento de herramientas consultadas el 2026-11-18 (sección 6) |
| **Supuestos** | Sección 1.2 |
| **Propuestas** | Pirámide, puertas de calidad, severidades y SLA, criterios de entrada y salida, plan del backend, convención de trazabilidad |
| **Decisiones pendientes** | Sección 15 |
| **Riesgos** | Sección 14 |

Marcas: **[A VALIDAR]** = depende de una decisión abierta (PA-xx, D-xx, DN-xx); **NO VERIFICADO** = no se pudo confirmar en esta fase.

---

## 1. Punto de partida

### 1.1 Hechos

| # | Hecho | Fuente |
|---|---|---|
| H-Q1 | El frontend web **no tiene pruebas automáticas** (`CLAUDE.md`: "No existen tests"). Su `package.json` solo define los scripts `dev`, `build`, `start` y `lint`, y no incluye ningún ejecutor de pruebas entre sus dependencias de desarrollo | COD §2; `ipr-frontend/package.json` (leído en esta fase) |
| H-Q2 | El CI existente (`.github/workflows/deploy.yml`) **solo despliega**: sin `tsc`, lint, `npm audit` ni pruebas | COD §2; SEC-10 |
| H-Q3 | `package.json` no declara `engines` y fija `@types/node ^20`: la versión de Node de producción es **DESCONOCIDA** y condiciona las herramientas de prueba del BFF | `ipr-frontend/package.json` |
| H-Q4 | El BFF `/mobile/v1` vivirá dentro del proyecto Next.js (ADR-001, aprobada) y será desplegado junto con la web, sin pruebas (RB-09, RA-08) | ADR-001; análisis 1.2 |
| H-Q5 | El OpenAPI de `/mobile/v1` es 3.1.0, versión `1.0.0-draft`, **todas las operaciones propuestas** | `openapi.yaml` |
| H-Q6 | El checkout manda solo `{id, quantity}` (máx. 100 líneas, cantidad 1–99); WooCommerce recalcula precio, impuestos y stock; ticket de un solo uso de 60 s; Wompi corre dentro del checkout de WooCommerce | COD §1, §5.4 |
| H-Q7 | Hoy `ipr/v1` tiene un solo token por usuario, sin refresh, sin rate limit de autenticación, `__return_true` en todas las rutas (H-01 a H-05) | COD §5.1 |
| H-Q8 | Plataforma propuesta: Flutter 3.50.0 y Dart 3.14 (estado "Verificado" en la arquitectura, no instalado en esta fase) | `flutter_app_architecture.md` §1 |
| H-Q9 | El AC define 490 criterios: 198 Integración, 109 Widget, 95 Seguridad, 34 Unitaria, 34 E2E y 20 Manual; 107 llevan **[A VALIDAR]** | Conteo automático sobre `acceptance_criteria.md` |
| H-Q10 | Las mediciones MED-01 a MED-18 no existen: ningún umbral es definitivo | RNF §6 |

### 1.2 Supuestos

| ID | Supuesto | Si es falso |
|---|---|---|
| S-Q1 | Existirá *staging* (frontend + WooCommerce + Wompi sandbox) y se autorizará sondearlo (D-16) | Los casos E2E, de contrato contra staging, SKU, frescura y eliminación de cuenta no pueden ejecutarse; son criterio de no-lanzamiento (NL-02, NL-12) |
| S-Q2 | El sandbox de Wompi representa el comportamiento de producción (S-NF-06) y puede simular aprobado, rechazado y, idealmente, pendiente | Repetir pruebas de pago con transacciones controladas en el piloto |
| S-Q3 | El equipo mantendrá fixtures sintéticos en *staging* (productos `QA-*`, cuentas `CLI-*`) | Se depende del catálogo real y de datos de IPR |
| S-Q4 | El CI de la app será GitHub Actions (el repositorio web ya lo usa para desplegar) | Se adapta el diseño de puertas a otra plataforma |
| S-Q5 | Habrá acceso a dispositivos físicos según RNF-082 (≥ 8) | La matriz queda como emuladores y granjas, que RNF-082 declara complemento, no sustituto |

---

## 2. Objetivos y alcance

**Objetivos de calidad (propuestos):**
1. Que ningún cobro, pedido o precio se determine en la app (RF-050, RF-052; NL-02).
2. Que los fallos de red o servidor nunca borren el carrito ni se confundan con "no existe" o "vacío" (RF-009; RNF-022, RNF-023).
3. Que la autenticación por dispositivo, la renovación y la revocación funcionen sin cerrar sesiones ajenas (RF-043; NL-05).
4. Que los flujos críticos sean accesibles y funcionen en la matriz de dispositivos y redes (RNF-067 a 071, RNF-082, RNF-083).
5. Que cada AC tenga trazabilidad a un caso y, si es automatizable, a una capa automatizada.

**Dentro del alcance de este documento:** pirámide, entornos, datos, herramientas, puertas de CI/CD, defectos, criterios de entrada y salida, plan del backend, trazabilidad.

**Fuera del alcance (no se duplica):** el diseño de las pruebas de seguridad (inspección de binario, proxy, abuso, MASVS L1, pruebas de penetración, corpus XSS, canarios en logs) corresponde a `06_security/security_testing.md`. Aquí solo se define **cómo se integran sus resultados como puertas de calidad** (sección 7.4) y qué regresiones funcionales automatizables se mantienen en la suite de QA (20 de los 95 AC de seguridad; ver [test_cases.md](test_cases.md) §5).

---

## 3. Pirámide de pruebas

Los conteos son de **casos de prueba (TC)** desarrollados en [test_cases.md](test_cases.md), no de pruebas automatizadas: un TC parametrizado puede ser decenas de pruebas. La proporción de pruebas automatizadas debe ser mayoritariamente unitaria y de widget; no se fija una proporción numérica por falta de base.

| Capa | Qué verifica | Herramientas propuestas (ver sección 6) | Dónde corre y cuándo | RNF / AC dominantes | TC hoy |
|---|---|---|---|---|---|
| **Unitaria de dominio** | Reglas del carrito, elegibilidad de compra, máquina de estados del checkout, formato de importes, texto de precio, URL de WhatsApp, calculadora BTU, validadores, mapeo de estados | `flutter_test`, `mocktail` | CI en cada PR | RNF-089 (≥ 90 % en módulos críticos), RNF-092; AC tipo Unitaria (34) | 13 |
| **Unitaria de datos** | Mapeadores DTO → entidad con fixtures JSON (campos faltantes, enum nuevo, precio nulo, imagen vacía), mapeo de errores (404, 503, 429, HTML de Cloudflare), refresh de vuelo único | `flutter_test`, `mocktail`, adaptador HTTP simulado de Dio | CI en cada PR | RNF-021, 022, 027, 028 | (incluidos arriba) |
| **Widget** | Pantallas con repositorios falsos mediante *overrides* de Riverpod; estados cargando, vacío, error y obsoleto; doble toque; textos prohibidos ("$0") | `flutter_test` | CI en cada PR | AC tipo Widget (109); RNF-027, 068 a 073 | 25 |
| **Golden** | Componentes y pantallas clave a escala de texto 1,0 y 2,0 y a 360 dp; estados de resultado de pago | `alchemist` | CI en cada PR (referencias aprobadas por revisión) | RNF-068, 069, 081 | 1 + goldens dentro de casos de Widget |
| **Integración ligera** | Controladores y repositorios con BFF simulado (adaptador de Dio o servidor local): solicitudes emitidas, reintentos, un solo refresh, carrito intacto | `flutter test`, `shelf` para un BFF simulado local | CI en cada PR | AC tipo Integración (198), la mayoría | 74 (junto con la siguiente) |
| **Integración en emulador** | Ciclo de vida real de la app: reinicio con carrito, modo avión, retorno de enlace profundo, segundo plano | `integration_test` (SDK) | CI en emulador y nocturno | RNF-020, 031; AC-049-4, AC-055-7 | (incluidos arriba) |
| **Contrato** | (a) Lado app: los fixtures son válidos contra los esquemas del OpenAPI. (b) Lado BFF: 100 % de los endpoints con caso feliz, error y autenticación; 0 cambios incompatibles en `v1` | Script de CI (app); en el repo web, ejecutor de pruebas del BFF más validación de esquema y detector de cambios incompatibles | CI en cada PR de cualquiera de los dos repositorios | RNF-085, RNF-090; ADR-001 | 7 |
| **E2E en *staging*** | Compra completa con Wompi sandbox: aprobado, rechazado, cancelado, pendiente, abandono, doble toque, ticket vencido, retorno por enlace profundo | `patrol` (condicionado a SPK-01) en dispositivos reales o granja | Nocturno y por candidato a versión | RNF-024, 025, 026, 091; NL-02; AC tipo E2E (34) | 26 |
| **Rendimiento** | Arranque, fluidez, memoria, tamaño, peso de respuestas; carga del BFF | Trazas de plataforma y DevTools (app); herramienta de carga (BFF) | Primero en el *spike* (F2), luego F3 y F5; carga previa al piloto | RNF-001 a 013, 014 a 018 | 5 |
| **Accesibilidad** | Guías automáticas (contraste, objetivos táctiles, etiquetas) y recorridos con TalkBack, VoiceOver y texto al 200 % | Guías de `flutter_test`; revisión manual | Automática en cada PR; manual por candidato | RNF-067 a 077; NL-14 | 2 |
| **Compatibilidad en matriz** | Humo de flujos críticos en la matriz de dispositivos y versiones | Dispositivos físicos; granja como complemento | Por candidato a versión | RNF-078 a 082, 086 | 1 |
| **Red lenta y sin conexión** | Flujos críticos bajo Wi-Fi, 4G lenta, red degradada, intermitente y sin red | Emulación de red del emulador y del sistema, proxy de red | E2E y manual por candidato | RNF-083, 020, 003 | 2 (G: NET_PROFILES, OFFLINE_READ) |
| **Regresión** | Humo P1 en cada candidato; suite completa nocturna; verificación nocturna de enlaces legales y árbol de categorías | CI programado | Nocturno y por candidato | RNF-091, 093, 113 | TC-160 (contado en E2E) y reutilización de los P1 |
| **Manual y exploratoria** | Textos aprobados por Jurídico, Ingeniería y Comercial; guías de tiendas; ubicación en mapas; `.well-known` | Listas de verificación con evidencia fechada | Por candidato y antes de F4 | AC tipo Manual (20) | 6 |
| **Seguridad** | **No se define aquí**; ver `06_security/security_testing.md` | — | CI y F4 | NL-01, 03, 04, 06, 08, 10 | 0 propios (20 regresiones funcionales dentro de otros casos) |

**Decisión de ejecución de los AC "Integración" (propuesta).** Se implementan por defecto como *integración ligera* (rápida, determinista, dentro de `flutter test`). Solo pasan a `integration_test` en emulador los que requieren el ciclo de vida real (reinicio, avión, enlace profundo). Los que dependen del servidor real (frescura, SKU, eliminación) corren contra *staging* en la capa de contrato o E2E. Esto reduce el costo de CI sin quitar cobertura.

---

## 4. Trazabilidad: de cada AC a su capa automatizada

### 4.1 Regla por tipo de AC

| Tipo del AC | AC (cantidad) | Capa automatizada | Se ejecuta en | Condición de cierre del AC |
|---|---|---|---|---|
| Unitaria | 34 | Unitaria (`flutter_test`) | PR | Caso en verde con la tabla de valores del AC |
| Widget | 109 | Widget (+ golden si es visual) | PR | Caso en verde y golden aprobado |
| Integración | 198 | Integración ligera; Integración en emulador si requiere ciclo de vida; Contrato si toca el esquema | PR / nocturno | Caso en verde y respuesta simulada conforme al OpenAPI |
| E2E | 34 | E2E en *staging* con Wompi sandbox | Nocturno / candidato | Ejecución aprobada en Android e iOS con evidencia |
| Manual | 20 | Lista de verificación manual (no automatizable) | Candidato | Lista firmada con evidencia fechada |
| Seguridad | 95 | **Delegado** a `06_security/security_testing.md`; QA añade regresión funcional si el AC lo permite (20 casos hoy) y exige el resultado como puerta | CI de seguridad / F4 | Resultado del documento de seguridad con evidencia; la regresión de QA no lo sustituye |

### 4.2 Cadena de trazabilidad

```
RF / RNF → US → AC-xxx-n → TC-nnn → prueba automatizada (archivo + nombre) → resultado por ciclo (test_results.md)
```

**Convención propuesta (a validar con el equipo de desarrollo):**

| Elemento | Convención |
|---|---|
| Nombre de la prueba Dart | `TC-nnn · AC-xxx-n · descripción` (varios AC separados por coma) |
| Etiqueta | `@Tags(['tc-nnn'])` o equivalente, para ejecutar un caso aislado |
| Archivo | Espejo de `lib/` bajo `test/` e `integration_test/`, con el feature como carpeta |
| Reporte | Un script de CI lista AC → TC → pruebas → último resultado y falla si una prueba cita un TC inexistente (prueba huérfana) |
| Cambio de AC | Un PR que cambie un AC debe actualizar su TC en el mismo PR (revisión humana, RNF-095) |

La verificación automática de cobertura de AC (cada AC tiene TC o está delegado) se ejecuta al cierre de cada ciclo y se registra en [test_results.md](test_results.md).

### 4.3 Trazado de las historias críticas

| Historia crítica | AC (cantidad) | Casos principales ([test_cases.md](test_cases.md)) | Capa de la prueba automatizada |
|---|---|---|---|
| Autenticación y sesiones por dispositivo (US-037 a 045, 048) | 74 | TC-001 a TC-035 | Widget, Integración, Contrato, E2E con dos dispositivos |
| Carrito (US-029, 049 a 051) | 32 | TC-036 a TC-050 | Unitaria, Widget, Integración, Contrato |
| Checkout con Wompi (US-052 a 058) | 62 | TC-061 a TC-082 | Integración, E2E (aprobado, rechazado, cancelado, pendiente, doble toque, retorno) |
| Pedidos (US-107, 108) | 15 | TC-083 a TC-086 | Integración, Widget, Contrato |
| Eliminación de cuenta (US-110) | 16 | TC-087 a TC-092 | Widget, Integración, E2E, Manual |
| Integridad de precio (US-011, 012, 026, 050, 051) | transversal | TC-051 a TC-054, TC-081 | Unitaria, Widget, E2E |
| Producto sin precio → WhatsApp (US-012, 030, 062, 063) | 21 | TC-052 a TC-057, TC-060 | Unitaria, Widget, Integración, Manual |
| Búsqueda por SKU (US-022) | 5 | TC-108 a TC-110 | Integración contra *staging*, Manual |
| Errores 404 y 503 (US-009, AC-026-6 y 026-7; RNF-022, 023) | 7 + 2 + RNF | TC-099 a TC-106 | Integración, Contrato |
| Sin red (US-009; RNF-020, 083) | 7 + RNF | TC-099, TC-102, TC-106, TC-107 | Integración, Rendimiento |

### 4.4 Trazado RNF → capa

| Familia de RNF | Capa | Casos |
|---|---|---|
| Rendimiento (RNF-001 a 013) | Rendimiento | TC-154 a TC-156 |
| Capacidad y BFF (RNF-014 a 018) | Rendimiento (carga) | TC-152 |
| Disponibilidad y resiliencia (RNF-019 a 032) | Integración, Contrato, E2E | TC-099 a TC-107, TC-104, TC-067 a TC-074 |
| Seguridad (RNF-033 a 055) | Delegado a `06_security/security_testing.md` | Regresiones: TC-031, TC-078, TC-086, TC-094 |
| Privacidad (RNF-056 a 066) | Integración, E2E, Manual | TC-006, TC-087 a TC-092, TC-097, TC-035 |
| Accesibilidad (RNF-067 a 077) | Accesibilidad, Golden | TC-157, TC-158, TC-119 |
| Compatibilidad (RNF-078 a 086) | Compatibilidad, Red | TC-159, TC-107, TC-066 |
| Mantenibilidad (RNF-087 a 096) | Puertas de CI | Sección 7 |
| Observabilidad (RNF-097 a 105) | Monitoreo y piloto | `quality_metrics.md` |
| Calidad de datos (RNF-106 a 116) | Verificación automatizada del catálogo | Sección 12; TC-054, TC-110, TC-116, TC-132, TC-138 |

---

## 5. Entornos y datos de prueba

### 5.1 Entornos

| Entorno | Flavor de la app | Uso | Estado |
|---|---|---|---|
| Local | `dev` | Desarrollo y pruebas unitarias, widget, golden e integración ligera con BFF simulado | Propuesto (ADR-009) |
| CI | `dev` | Todas las puertas de merge | Propuesto |
| *staging* | `staging` (`co.ipr.app.staging`, propuesto) | Contrato contra servidor, E2E con Wompi sandbox, eliminación de cuenta, frescura, SKU | **Existencia DESCONOCIDA** (C2); dominio de *staging* y archivos `.well-known` por entorno: DESCONOCIDOS |
| Beta / piloto | `prod` con distribución cerrada | Estabilidad, rendimiento real, telemetría de versiones (RNF-098, 104) | F5 |
| Producción | `prod` | **Sin pruebas de escritura ni de compra.** Solo monitoreo sintético de solo lectura y login con cuenta de prueba dedicada y autorizada (RNF-102) | F6 |

### 5.2 Datos de prueba

| Regla | Detalle |
|---|---|
| Sintéticos siempre | Nunca datos reales de clientes ni de empleados; correos en el dominio reservado `example.test`; direcciones, teléfonos y sedes ficticios |
| Sin secretos en documentos ni en el repositorio | Las contraseñas de cuentas de prueba, el secreto del webhook de prueba y cualquier credencial de *staging* viven en el gestor de secretos de CI; los documentos solo las nombran (`QA_PWD_n`) |
| Catálogo de pruebas | Productos con prefijo `QA-` (con precio, sin precio, agotado, bajo pedido, en oferta, de precio cambiante, de nombre largo, sin imagen) y categorías `QA-CAT-*`; ver [test_cases.md](test_cases.md) §3 |
| Cuentas | Clientes `CLI-01` a `CLI-03`; cuenta de rol administrativo ad hoc `CLI-ADM` (nunca una cuenta real); cuentas descartables `CLI-DEL*` recreadas antes de cada ciclo |
| Reposición | Un guion de siembra y reposición deja *staging* en estado conocido antes de cada ciclo; los casos que cambian datos (precio, stock, sedes) los restauran al terminar |
| Pagos | Solo Wompi sandbox con las tarjetas de prueba de su documentación oficial (**NO VERIFICADO** su vigencia; no se transcriben); nunca tarjetas reales; nunca producción |
| Canarios | Valores marcadores (`CANARY-…`) para detectar fugas en logs; su verificación la ejecuta seguridad (RNF-047) |
| Tiempo | Los casos con ticket de 60 s controlan el reloj del servidor de pruebas o esperan; no dependen de la hora del dispositivo |
| Fixtures de contrato | Derivados de los ejemplos del OpenAPI; si el contrato cambia de forma incompatible, fallan (ADR-012) |

---

## 6. Herramientas sugeridas

Versiones y estado consultados el **2026-11-18** en pub.dev (API pública), GitHub (API pública) y el registro de npm. "Compatible" significa que **el requisito de SDK publicado** admite Flutter 3.50 / Dart 3.14; **no se instaló ni se ejecutó nada**. Todo lo marcado **NO VERIFICADO** debe confirmarse en un *spike* antes de adoptarse.

| Herramienta | Versión / estado | Uso | Compatibilidad y verificación |
|---|---|---|---|
| `flutter_test` (SDK) | Incluido en Flutter | Unitarias, widget y guías de accesibilidad | Incluido en el SDK. Nombres de las guías de accesibilidad (`androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) citados en la arquitectura: **confirmar al fijar el SDK (SPK-02)** |
| `mocktail` | 1.0.5 (2026-04-10); Dart `>=2.12 <4.0` | Dobles de prueba sin generación de código | **Verificado** (pub.dev); admite Dart 3.14 |
| `alchemist` | 0.15.0 (2026-11-17); Dart `^3.12`, Flutter `>=3.44` | Golden independientes de plataforma | **Verificado** en pub.dev; el requisito de SDK admite Flutter 3.50. Sucede a `golden_toolkit` (descontinuado, última 0.15.0 de 2023-02-21) |
| `integration_test` (SDK) | Incluido en Flutter | Integración en emulador | **Verificado**: el paquete de pub.dev está descontinuado (1.0.2+3, 2021); se usa el del SDK |
| `patrol` | 4.11.0 (2026-11-02); Dart `>=3.8 <4.0`, Flutter `>=3.32` | E2E con interacción de UI nativa | Requisito de SDK **verificado**. **NO VERIFICADO** que automatice Custom Tabs, SFSafariViewController o ASWebAuthenticationSession (SPK-01, decide la adopción). `patrol_finders` 3.7.0 (2026-11-02) como complemento |
| `shelf` | 1.4.3 (2026-10-16); Dart `^3.9` | Servidor local que sirve el BFF simulado en integración ligera | **Verificado**; admite Dart 3.14 |
| `http_mock_adapter` | 0.6.1 (2023-11-23) | Adaptador simulado de Dio | **No recomendado como principal**: sin publicaciones en ≈ 3 años. Alternativa: adaptador propio con `mocktail` o `shelf` |
| `json_schema` | 5.2.2 (2025-10-08) | Validar fixtures contra esquemas | Existe; **NO VERIFICADO** que soporte el dialecto de esquema de OpenAPI 3.1.0 (JSON Schema 2020-12) |
| `coverage` | 1.16.1 (2026-11-18); Dart `^3.9` | Procesado de cobertura | **Verificado**. La verificación del umbral por módulo requiere un script propio sobre el reporte `lcov`; la herramienta `lcov` y la acción `very_good_coverage` quedan **NO VERIFICADAS** |
| `very_good_analysis` | 11.0.0 (2026-09-03); Dart `^3.13` | Análisis estático estricto (RNF-087) | **Verificado**; admite Dart 3.14 |
| DevTools y trazas de plataforma | SDK / herramientas del sistema | Arranque, fluidez, memoria (RNF-001 a 008) | Medición de rendimiento con `integration_test` y *profile*: **NO VERIFICADO** en Flutter 3.50 (SPK-02) |
| `oasdiff` | v1.39.0 (2026-11-17), Apache-2.0, activo | Detección de cambios incompatibles del OpenAPI en CI | Existencia y mantenimiento **verificados**; soporte de OpenAPI 3.1 en este contrato: **NO VERIFICADO** |
| Spectral | v6.17.1 (2026-11-06), Apache-2.0 | Lint del OpenAPI | Existencia **verificada**; conjunto de reglas por definir |
| Schemathesis | v4.33.4 (2026-11-12), MIT | Pruebas de contrato generadas desde el OpenAPI contra *staging* | Existencia **verificada**; soporte de OpenAPI 3.1 y adecuación a este BFF: **NO VERIFICADO** |
| Prism | v5.16.0 (2026-07-17), Apache-2.0 | Servidor simulado desde el OpenAPI | Existencia **verificada**; soporte de OpenAPI 3.1: **NO VERIFICADO** |
| k6 | v2.4.0 (2026-11-12), **AGPL-3.0** | Carga del BFF (RNF-014 a 018) | Existencia **verificada**; **la licencia AGPL debe revisarla IPR/Jurídico** antes de adoptarla; alternativas no evaluadas |
| Vitest | 5.1.1; requiere Node `^22.12 \|\| ^24 \|\| >=26` | Pruebas del BFF en el repositorio web | Existencia **verificada**; **NO VERIFICADO** frente al Node de producción (H-Q3) ni frente a Next.js 16.3.4 |
| Jest | 30.5.2; Node `^18.14 \|\| ^20 \|\| ^22 \|\| >=24` | Alternativa para el BFF | Existencia **verificada**; **NO VERIFICADO** frente a Next.js 16.3.4 |
| MSW | 3.0.7; Node `>=22.12` | Simular WooCommerce y WordPress en pruebas del BFF | Existencia **verificada**; **NO VERIFICADO** frente al Node de producción |
| Pruebas de `ipr/v1/m` en PHP | — | Pruebas de sesiones, límites, pedidos | PHPUnit con el entorno de pruebas de WordPress o pruebas HTTP contra *staging*: **NO VERIFICADO** (versiones de WordPress y PHP DESCONOCIDAS) |
| Maestro | cli-2.12.1 (2026-11-02), Apache-2.0 | Alternativa de E2E | Existencia **verificada**; soporte de Flutter y del navegador seguro: **NO VERIFICADO** |
| Granjas de dispositivos (Firebase Test Lab, BrowserStack, AWS Device Farm) | — | Complemento de la matriz (RNF-082) | **NO VERIFICADO**: no se consultó disponibilidad, costo ni modelos |
| Emulación de red (emulador de Android, condicionador de red de Apple, proxy) | — | Perfiles de red de RNF-083 | **NO VERIFICADO** en esta sesión |
| Ejecutores de CI para iOS | — | Compilar IPA y ejecutar el simulador | Se asume un ejecutor macOS; disponibilidad y costo: **NO VERIFICADO** |
| FVM o `.flutter-version` | — | Fijar la versión del SDK (RNF-094) | Citado en la arquitectura; **NO VERIFICADO** |

---

## 7. Puertas de calidad en CI/CD

Principios: (1) una puerta bloqueante es automática y reproducible; (2) lo que no se puede automatizar es una puerta de release con firma; (3) una puerta de seguridad la define seguridad y QA la exige como *check* requerido; (4) las excepciones solo existen para los criterios condicionales NL-C, con aceptación formal y por escrito de IPR (Gerencia + TI).

### 7.1 Qué bloquea un merge (PR hacia la rama principal)

| ID | Puerta | Herramienta | Regla | Origen |
|---|---|---|---|---|
| QG-M01 | Formato | `dart format --set-exit-if-changed` | 0 diferencias | RNF-087 |
| QG-M02 | Análisis estático | `flutter analyze` con `very_good_analysis` | 0 errores y 0 advertencias | RNF-087 |
| QG-M03 | Reglas de dependencia entre capas | Script de verificación de importaciones | 0 violaciones (presentation → domain; data no importa presentation; features no se importan entre sí) | Arquitectura §3, ADR-003 |
| QG-M04 | Pruebas unitarias, widget, golden e integración ligera | `flutter test` | 100 % en verde | RNF-093 |
| QG-M05 | Cobertura | `flutter test --coverage` + script de umbral | ≥ 70 % global y ≥ 90 % en `core/session`, `core/network`, `features/cart/domain`, `features/checkout/domain`, `shared/formatting`, `features/technical_tools/domain`; no se permite bajar | RNF-089 |
| QG-M06 | Contrato (lado app) | Script de CI | Los fixtures son válidos contra el OpenAPI vigente | RNF-085, 090 |
| QG-M07 | Accesibilidad automática | Guías de `flutter_test` | 0 incumplimientos en las pantallas críticas (TC-157) | RNF-069, 070, 071, 073 |
| QG-M08 | Trazabilidad | Script de reporte AC → TC → prueba | 0 pruebas que citen un TC inexistente; un cambio de AC actualiza su TC | Sección 4.2 |
| QG-M09 | Seguridad estática | **Definida en `06_security/security_testing.md`**: escaneo de secretos, dependencias (OSV) y SBOM | Falla con vulnerabilidad crítica o alta | RNF-049, NL-01, NL-03 |
| QG-M10 | Compilación | Build de Android y de iOS en CI | Ambas compilan | RNF-093 |
| QG-M11 | Revisión de código | Rama protegida | ≥ 1 aprobación de alguien distinto del autor; cambios en `/mobile/v1` e `ipr/v1` revisados por el responsable técnico del repositorio | RNF-095 |
| QG-M12 | Dependencias | Revisión del diff de `pubspec.lock` | Plugin nuevo con código nativo requiere nota de decisión | RNF-094 |

**Repositorio web (BFF), previas al despliegue** (el flujo `deploy.yml` debe depender de ellas, FE-11):

| ID | Puerta | Regla | Origen |
|---|---|---|---|
| QG-B01 | `tsc --noEmit` en modo estricto | 0 errores | RNF-088 |
| QG-B02 | ESLint (ya configurado) | 0 errores | RNF-088 |
| QG-B03 | Pruebas unitarias de `/mobile/v1` | ≥ 80 % de líneas del módulo | RNF-090 |
| QG-B04 | Pruebas de contrato | 100 % de los endpoints con caso feliz, error y autenticación contra el OpenAPI | RNF-090 |
| QG-B05 | Compatibilidad del contrato | 0 cambios incompatibles en `v1` | RNF-085 |
| QG-B06 | Humo de la web | Inicio, ficha de producto y traspaso de checkout de la web siguen funcionando (el BFF se despliega junto con ella) | RB-09, RA-08 |
| QG-B07 | Seguridad de dependencias | `npm audit` u OSV sin críticas ni altas (definido por seguridad) | RNF-049, FE-11 |

### 7.2 Qué bloquea un release

Un *release candidate* (RC) se promueve a piloto o a tiendas solo si **todas** las puertas absolutas están en verde con evidencia en [test_results.md](test_results.md).

| ID | Puerta | Evidencia requerida | Casos | Criterio de no-lanzamiento |
|---|---|---|---|---|
| QG-R01 | Regresión P1 completa | 100 % de los casos P1 de Integración y E2E en verde en el RC | TC-160 y todos los P1 | — |
| QG-R02 | Compra de extremo a extremo | Aprobado, rechazado y cancelado, en Android **e** iOS, con Wompi sandbox | TC-067, TC-068, TC-069 | NL-02 |
| QG-R03 | Cero duplicados | 0 pedidos o cobros duplicados (doble toque, abandono, cierre forzado, ticket reutilizado) | TC-062, TC-071, TC-073, TC-147 | NL-02 |
| QG-R04 | Sesiones y límites | Sesión por dispositivo, renovación, revocación y límite de intentos persistente | TC-017, TC-018, TC-020 a TC-023, TC-031, TC-148, TC-149 | NL-05 |
| QG-R05 | Contrato y capacidad | 100 % de los endpoints en contrato; prueba de carga con el perfil acordado y sin degradar la web | TC-144, TC-152 | NL-12, NL-C3 |
| QG-R06 | Matriz de dispositivos | Humo en la matriz completa | TC-159 | RNF-082 |
| QG-R07 | Rendimiento | Dentro de los límites duros (arranque en frío < 5 s) y de los objetivos | TC-154 a TC-156 | NL-C1 (3,0 a 5,0 s condicional; ≥ 5 s absoluto) |
| QG-R08 | Accesibilidad | Login, compra y eliminar cuenta completos con TalkBack y VoiceOver y con texto al 200 % | TC-158 | NL-14 |
| QG-R09 | Calidad de datos | 0 productos con precio ≤ 0 comprables, 0 "$0", 0 no publicados visibles | TC-053, TC-054, TC-104 | NL-13 |
| QG-R10 | Privacidad | Consentimiento registrado; eliminación de cuenta E2E; política revisada por Jurídico | TC-006, TC-089, TC-092, TC-035 | NL-07 |
| QG-R11 | Seguridad | Evidencia de `06_security/security_testing.md` para NL-01, 03, 04, 06, 08, 10 | Documento de seguridad | NL-01, 03, 04, 06, 08, 10 |
| QG-R12 | Defectos | 0 defectos S1 abiertos; 0 defectos S2 abiertos salvo aceptación formal si el criterio es condicional | Gestor de defectos | Sección 8 |
| QG-R13 | Contenido aprobado | Textos legales, de garantía y de estimación coinciden con los aprobados | TC-143, TC-035 | NL-07 |
| QG-R14 | Estabilidad (piloto → producción) | ≥ 99,5 % de usuarios sin fallos y ANR ≤ 0,3 % en el piloto | Panel de estabilidad | NL-C2 |
| QG-R15 | Condiciones de ADR-001 | C1 a C4 cumplidas (responsable técnico conforme, *staging*, Cloudflare permite la app, piloto de carga sin degradar la web) | Registro de condiciones | NL-12 |

### 7.3 Mapa de los criterios de no-lanzamiento (NL) a puertas y responsables

| NL | Tema | Puerta o casos | Responsable de la evidencia |
|---|---|---|---|
| NL-01 | Vulnerabilidades críticas o altas; pentest | QG-M09, QG-R11 | Seguridad |
| NL-02 | Fallo de compra, duplicados, manipulación de precio | QG-R02, QG-R03 | **QA** (manipulación de precio: seguridad) |
| NL-03 | Secretos en binario o CI | QG-M09, QG-R11 | Seguridad |
| NL-04 | Tokens inseguros, tráfico en claro | QG-R11 | Seguridad |
| NL-05 | Sesiones, renovación, revocación, rate limit | QG-R04 | **QA** (funcional) y seguridad (abuso) |
| NL-06 | Autorización deficiente | QG-R11; regresión TC-086, TC-150 | Seguridad (QA mantiene la regresión) |
| NL-07 | Eliminación de cuenta, consentimiento, política | QG-R10, QG-R13 | **QA** y Jurídico |
| NL-08 | Datos personales en registros | QG-R11 | Seguridad |
| NL-09 | Reporte de fallos, monitoreo y alertas | `quality_metrics.md` §7 | TI / QA verifica |
| NL-10 | MASVS L1 en falla | QG-R11 | Seguridad |
| NL-11 | Cuentas de tienda y claves | Lista de verificación de F4 | Gerencia / TI |
| NL-12 | Condiciones C1 a C4 | QG-R05, QG-R15 | **QA** (carga) y TI |
| NL-13 | Precios o disponibilidad incorrectos | QG-R09 | **QA** |
| NL-14 | Accesibilidad de flujos críticos | QG-R08 | **QA** |

### 7.4 Integración con las pruebas de seguridad

- QA no define el contenido de las pruebas de seguridad; **consume** sus resultados como *checks* requeridos en el mismo pipeline (QG-M09, QG-B07, QG-R11).
- Los artefactos de seguridad (reporte de secretos, de dependencias, SBOM, resultado de MASVS) se archivan junto a los resultados del ciclo y se referencian en [test_results.md](test_results.md); no se copian.
- Si `06_security/security_testing.md` cambia un umbral o una puerta, esta estrategia lo adopta por referencia y no lo redefine.
- Las regresiones funcionales de QA que tocan seguridad (401 tras cerrar sesión, cuerpo de `/checkout` solo con ids, 404 en pedido ajeno, estado del pedido tomado del servidor) siguen siendo útiles como detección temprana, pero **no cierran** el AC de seguridad correspondiente.

### 7.5 Pipeline propuesto

| Etapa | Contenido | Frecuencia |
|---|---|---|
| 1. Estática | Formato, análisis, reglas de dependencia, trazabilidad | Cada PR |
| 2. Pruebas rápidas | Unitarias, widget, golden, integración ligera, contrato lado app, cobertura | Cada PR |
| 3. Seguridad | Puertas de `06_security` | Cada PR |
| 4. Construcción | Android e iOS | Cada PR |
| 5. Integración en emulador | Reinicio, avión, enlace profundo | Cada PR a la rama principal y nocturno |
| 6. Nocturna | E2E en *staging*, enlaces legales, árbol de categorías, contrato contra *staging* | Cada noche |
| 7. Release candidate | Puertas QG-R01 a QG-R15 | Por candidato |

---

## 8. Gestión de defectos

### 8.1 Severidades y plazos (PROPUESTA a validar con IPR y TI)

No existen SLA de defectos en los documentos fuente, salvo dos referencias que se respetan: vulnerabilidades críticas ≤ 7 días y altas ≤ 30 días (RNF-048) y errores críticos de datos de catálogo ≤ 1 día hábil (RNF-116, propuesta). **Los demás plazos son una propuesta de partida sin base empírica y deben validarse.**

| Severidad | Definición | Ejemplos | Triage | Corrección o mitigación (propuesta) | Efecto en puertas |
|---|---|---|---|---|---|
| **S1 Crítico** | Impide comprar, iniciar sesión o eliminar la cuenta; cobro o pedido duplicado o incorrecto; precio decidido en el cliente; fuga de datos personales o de otro usuario; pérdida del carrito; vulnerabilidad crítica | "$0" comprable; carrito borrado tras un 503; doble cobro; token en logs | ≤ 1 día hábil | ≤ 2 días hábiles (en producción, corrección urgente) | **Bloquea el merge del cambio afectado y todo release.** No admite excepción |
| **S2 Alto** | Funcionalidad principal degradada con alternativa, o fallo en una plataforma o en un grupo de dispositivos; incumplimiento AA en flujo no crítico; vulnerabilidad alta | Retorno por enlace profundo que falla pero la consulta de estado funciona; filtro que ignora la marca | ≤ 2 días hábiles | Antes del siguiente RC | Bloquea el release salvo aceptación formal si el criterio es condicional (NL-C) |
| **S3 Medio** | Defecto con alternativa clara y efecto limitado; texto incorrecto no legal | Mensaje poco claro; golden con diferencia menor | ≤ 5 días hábiles | Planificado en ≤ 2 ciclos | No bloquea; se registra |
| **S4 Bajo** | Cosmético o mejora | Alineación de 1 dp | Por lote | Backlog | No bloquea |

Las vulnerabilidades las gestiona el documento de seguridad con los plazos de RNF-048. Los defectos de datos del catálogo (RNF-106 a 116) se asignan al responsable de calidad de datos (RNF-116).

### 8.2 Ciclo de vida y reglas

| Elemento | Regla |
|---|---|
| Estados | Nuevo → Triage → Asignado → En corrección → Listo para verificar → Verificado → Cerrado (o Rechazado / Duplicado / No reproducible) |
| Campos obligatorios | Título, caso de prueba y AC, severidad, versión y *build*, entorno, dispositivo y sistema operativo, pasos, resultado esperado y obtenido, evidencia (captura, video o registro **sin datos personales**), identificador de solicitud (`X-Request-Id`) si hay llamada al BFF |
| Evidencia | Sin tokens, contraseñas ni datos personales reales; se enmascaran antes de adjuntar |
| Cierre | Solo QA cierra, tras repetir el caso fallido y la regresión relacionada |
| Reaperturas | Un defecto reabierto dos veces se escala a S2 como mínimo |
| Defecto por decisión pendiente | Si el comportamiento depende de una pregunta [A VALIDAR], se registra como **decisión pendiente**, no como defecto, hasta que se cierre la pregunta |
| Métricas | Defectos abiertos por severidad, antigüedad y escape a producción (ver `quality_metrics.md`) |

---

## 9. Criterios de entrada y salida por fase

Fases nominales de los RNF: **F1** arquitectura y diseño · **F2** desarrollo (CI por PR) · **F3** QA en *staging* · **F4** pre-lanzamiento · **F5** piloto o beta · **F6** operación.

| Fase | Criterios de entrada | Criterios de salida |
|---|---|---|
| **F1** | ADR aprobadas; MED-01 y MED-03 a MED-10 planificadas | Estrategia de pruebas aprobada; matriz de dispositivos definida con MED-01; decisión de staging (C2) y autorización D-16; elección de herramientas de contrato y de carga |
| **F2** | Estrategia aprobada; repositorios con CI configurado; OpenAPI versionado | Puertas QG-M01 a QG-M12 y QG-B01 a QG-B07 activas y en verde; cobertura de RNF-089 sin bajar; *spikes* SPK-01 a SPK-04 resueltos; derivación de los AC pendientes a TC completada (100 % de los AC no Seguridad con caso) |
| **F3** | `/mobile/v1` desplegado en *staging* con contratos en verde; fixtures `QA-*` y cuentas `CLI-*` creados; Wompi sandbox operativo; build `staging` firmado | 100 % de los casos P1 ejecutados; compra E2E en verde en Android e iOS; 0 S1 abiertos; S2 con plan; rendimiento y accesibilidad medidos; matriz de dispositivos ejecutada |
| **F4** | F3 cerrada; textos legales y de tiendas aprobados; documento de seguridad ejecutado | QG-R01 a QG-R13 y QG-R15 en verde; pruebas de penetración sin críticos ni altos; cuentas de tienda con titularidad de IPR; criterios NL absolutos en verde |
| **F5** | RC de F4 aprobado; monitoreo, alertas y reporte de fallos activos (NL-09) | QG-R14: ≥ 99,5 % de usuarios sin fallos y ANR ≤ 0,3 % en el piloto; 0 S1; sin pedidos duplicados; telemetría de versiones y dispositivos revisada |
| **F6** | Producción estable | Revisión mensual de métricas; regresión por cada versión; revisión anual de mínimos de SO y de requisitos de tiendas (RNF-080) |

---

## 10. Plan para el backend (hoy sin pruebas)

El BFF compartirá proceso y despliegue con la web; sin pruebas, un cambio de la web puede romper `/mobile/v1` (RB-09, RA-08). **El backend no se integra con la app hasta cumplir este mínimo.**

### 10.1 Pruebas mínimas antes de integrar

| ID | Prueba mínima | Capa | Caso | Origen |
|---|---|---|---|---|
| BE-01 | Pruebas de caracterización de las funciones reutilizadas de `lib/woocommerce.ts` con WooCommerce simulado (humo) | Unitaria | (por crear: `TC-D`) | RB-09 |
| BE-02 | Regresión de visibilidad: solo `status=publish`; ocultos y con contraseña no se devuelven | Contrato | (por crear: `TC-D`) | RB-01, FE-01 |
| BE-03 | Resultados discriminados `ok`/`not_found`/`unavailable` en catálogo, ficha y búsqueda; 404 solo con respuesta definitiva | Contrato | TC-104 | RB-02, FE-02, ADR-016 |
| BE-04 | Contrato de **cada** endpoint contra el OpenAPI: caso feliz, error y autenticación | Contrato | TC-144 | RNF-090 |
| BE-05 | DTO: precio nulo cuando es 0, sin `stockQuantity`, `roles` ni claves, HTML saneado | Unitaria | TC-145 | RF-012, FE-03 |
| BE-06 | Validación estricta: campos extra, tamaños, token por URL, paginación | Contrato | TC-146 | RNF-041, 044 |
| BE-07 | Idempotencia y un ticket por intención en `POST /checkout` | Integración | TC-147 | RNF-024 |
| BE-08 | Mapeo de estados de WooCommerce a `paymentState` | Unitaria | TC-151 | api_architecture §13.2 |
| BE-09 | Cola de `wcGet` acotada: más de 3 s de espera responde 503 con `Retry-After` | Integración | TC-104, TC-152 | RNF-018, FE-06 |
| BE-10 | Arranque en frío: 503 `catalog_index_warming`, nunca 200 vacío | Contrato | TC-104 | RNF-023, FE-07 |
| BE-11 | Límite de tasa en lecturas: IP desde `CF-Connecting-IP`, LRU acotado | Integración | (por crear: `TC-D`) | FE-05 |
| BE-12 | Webhook de revalidación: firma válida invalida, inválida se rechaza | Integración | TC-134 | RF-019 |
| BE-13 | Sesiones por dispositivo con refresh rotativo, gracia y detección de reutilización | Integración (WordPress) | TC-148 | WP-01, NL-05 |
| BE-14 | Límite de intentos persistente por cuenta e IP | Integración (WordPress) | TC-149, TC-031 | WP-03, NL-05 |
| BE-15 | Pedidos solo del usuario; `checkout_ref` ajeno devuelve vacío | Integración (WordPress) | TC-150, TC-086 | WP-07, NL-06 |
| BE-16 | Cada ruta `ipr/v1/m/*` sin secreto del BFF responde 401 (ninguna con `__return_true` sin validación) | Integración (WordPress) | (por crear: `TC-D`; el diseño de abuso es de seguridad) | WP-02, NL-06 |
| BE-17 | Ticket de handoff con `checkoutRef`, `channel` y pedido con `_ipr_checkout_ref` | E2E | TC-067, TC-073 | WP-06 |
| BE-18 | Eliminación de cuenta y trabajo de anonimización | E2E | TC-089 | WP-09, NL-07 |
| BE-19 | Registro de consentimiento con versión, fecha y canal | Integración | TC-006 | WP-11 |
| BE-20 | Carga con el perfil acordado y no degradación de la web | Rendimiento | TC-152 | RNF-014, 015; C4 |
| BE-21 | Cloudflare no desafía a la app; `.well-known` sin desafío | E2E / Manual | TC-032, TC-082 | RNF-032; C3 |

### 10.2 Definición de "listo para integrar la app con el backend"

Todas las condiciones, verificables:

1. OpenAPI deja de ser `x-status: proposed` para los endpoints del MVP y se versiona en el repositorio web.
2. BE-01 a BE-12 en verde en CI del repositorio web y `deploy.yml` depende de ellas (FE-11).
3. BE-13 a BE-19 en verde contra el WordPress de *staging*.
4. *staging* operativo con fixtures `QA-*` y cuentas `CLI-*`.
5. QG-B01 a QG-B07 activas.
6. Resultado de las pruebas de seguridad del BFF disponible (QG-R11) o plan acordado.

### 10.3 Notas

- Las pruebas de PHP para `ipr/v1/m` requieren un entorno de pruebas de WordPress o pruebas HTTP contra *staging* (**NO VERIFICADO**; versiones de WordPress y PHP DESCONOCIDAS). Hasta decidirlo, el mínimo viable son pruebas HTTP contra *staging*.
- Los cambios de la web que toquen `lib/woocommerce.ts` obligan a ejecutar las pruebas de caracterización del BFF (QG-B06).

---

## 11. Red lenta, sin conexión y matriz de dispositivos

### 11.1 Perfiles de red (RNF-083, definidos por QA)

| Perfil | Definición | Uso |
|---|---|---|
| Wi-Fi | Sin limitación | Línea base |
| `RED-4G-LENTA` | ≈ 1,6 Mbps y ≈ 150 ms RTT (referencia Lighthouse, re-verificar) | Umbrales de RNF-003 |
| `RED-DEGRADADA` | ≈ 400 kbps y RTT ≥ 400 ms | Flujos críticos sin cierres |
| `RED-INTERMITENTE` | Cortes de 5 a 15 s | Reintentos, estado de pago, carrito |
| `RED-OFF` | Modo avión | Lectura sin conexión, mensajes, "el pago exige conexión" |

### 11.2 Matriz de dispositivos (a definir tras MED-01)

RNF-082 propone ≥ 8 dispositivos físicos. **Los modelos y versiones concretos no se eligen aún**: dependen de MED-01 (perfil real de la clientela), DN-01 y SPK-02.

| Ranura | Criterio de selección | Objetivo |
|---|---|---|
| Android gama baja | Marca A; versión mínima soportada (propuesta API 26, DN-01) | Rendimiento y memoria en peor caso |
| Android gama media | Marca B; dispositivo de referencia de rendimiento (MED-11) | Línea base de RNF-001 a 008 |
| Android gama alta | Marca C | Compatibilidad |
| Android sin Chrome | Navegador predeterminado distinto | RNF-086 (respaldo del navegador seguro) |
| iPhone más antiguo soportado | iOS mínimo (propuesta iOS 15, DN-01) | Enlaces universales, ASWebAuthenticationSession |
| iPhone intermedio | — | Humo |
| iPhone reciente | iOS más reciente | Humo y compatibilidad |
| Tableta | Android o iPad | "Usable" a partir de 600 dp (RNF-081) |

Los emuladores y granjas complementan la matriz, no la sustituyen (RNF-082).

---

## 12. Regresión, estabilidad de las pruebas y datos del catálogo

| Tema | Regla |
|---|---|
| Humo por candidato | Los casos P1 de Integración y E2E se ejecutan en cada candidato a versión |
| Completa nocturna | Todos los casos automatizables contra *staging* |
| Pruebas inestables | Una prueba que falla de forma intermitente se pone en cuarentena en ≤ 1 día hábil, se abre un defecto y no puede bloquear merges mientras tanto; no se reintenta a ciegas |
| Actualización de golden | Solo con revisión visual humana en el PR; nunca automática |
| Datos del catálogo | Verificación automática programada de RNF-106 a 116 sobre *staging*: precio ≤ 0 comprable, "$0", no publicados visibles, enlaces de imágenes, árbol de categorías (RNF-113), SKU duplicado o vacío; los resultados alimentan MED-06 |
| Cambios de contrato | Cualquier cambio de `v1` pasa por el detector de incompatibilidades antes del merge |

---

## 13. Roles (propuesta mínima)

| Actividad | QA | Desarrollo app | Desarrollo BFF/WordPress | Seguridad | IPR (producto, Jurídico, Comercial) |
|---|---|---|---|---|---|
| Estrategia y casos | Responsable | Revisa | Revisa | Coordina límites | Aprueba |
| Pruebas unitarias y de widget | Revisa | Responsable | — | — | — |
| Pruebas del BFF y de contrato | Define | — | Responsable | — | — |
| E2E y matriz de dispositivos | Responsable | Apoya | Apoya | — | Provee muestra de SKUs |
| Pruebas de seguridad | Integra las puertas | Corrige | Corrige | Responsable | Acepta riesgos |
| Textos legales y contenido | Verifica con lista | — | — | — | Responsable de los textos |
| Decisión de lanzamiento | Recomienda | — | — | Recomienda | Decide (Gerencia + TI) |

---

## 14. Riesgos de calidad

| ID | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| R-Q01 | *staging* con Wompi sandbox no existe o no se autoriza (C2, D-16) | Media | **Crítico**: sin E2E de compra no hay lanzamiento (NL-02) | Pedir confirmación en F1; escalar como bloqueante |
| R-Q02 | El sandbox de Wompi no simula el estado pendiente ni el abandono | Media | Alto | Documentar con MED-14; probar el estado pendiente con simulaciones del lado de WooCommerce o en piloto controlado |
| R-Q03 | `patrol` no automatiza Custom Tabs o SFSafariViewController (SPK-01) | Media | Alto | Alternativa: Maestro (**NO VERIFICADO**) o guion manual de compra por candidato con evidencia |
| R-Q04 | El backend `/mobile/v1` llega tarde: casos de integración y E2E bloqueados | Alta | Alto | BFF simulado conforme al OpenAPI para integración ligera; casos de contrato en cuanto exista el endpoint |
| R-Q05 | Sin pruebas ni puertas en el repositorio web: regresiones por despliegues de la web | Alta | Alto | QG-B01 a QG-B07 como condición de despliegue |
| R-Q06 | Matriz de dispositivos sin datos (MED-01) | Alta | Medio | Definir ranuras por criterio y ajustar con datos del piloto |
| R-Q07 | Los 107 AC con [A VALIDAR] bloquean la aprobación de sus casos | Alta | Alto | Registro de decisiones y revisión semanal con IPR; los casos se ejecutan en su parte determinista |
| R-Q08 | Herramientas de prueba del BFF no compatibles con el Node o con Next.js de producción (H-Q3) | Media | Medio | *Spike* en F1; elegir entre Vitest y Jest según resultado |
| R-Q09 | Calidad del catálogo (precios, categorías, imágenes) afecta los casos de datos reales | Alta | Medio | Datos sintéticos `QA-*` para determinismo y verificación automatizada del catálogo real (MED-06) |
| R-Q10 | E2E inestables (red, sandbox, navegador del sistema) | Alta | Medio | Cuarentena, reintento controlado en infraestructura (no en la prueba), evidencia por ejecución |
| R-Q11 | Cloudflare desafía a los *runners* de CI o a la app (R-02, MED-15) | Media | Alto | Reglas por ruta en *staging*; cabeceras propias; QG-R05 |
| R-Q12 | Licencia AGPL de la herramienta de carga | Baja | Medio | Revisión de IPR/Jurídico o alternativa |
| R-Q13 | El sandbox no representa producción (S-NF-06) | Media | Alto | Transacciones controladas en el piloto |
| R-Q14 | Inconsistencias documentales (por ejemplo, `OrderDetail` del OpenAPI frente a AC-108-2; AC-038-5 frente a `409 email_in_use`) | Media | Medio | Resolverlas antes de cerrar el contrato; ver [test_cases.md](test_cases.md) TC-007 y TC-085 |

---

## 15. Decisiones pendientes que afectan a la estrategia

| ID | Decisión | Recomendación | Quién decide |
|---|---|---|---|
| Q-01 | Existencia y autorización de *staging* con Wompi sandbox (C2, D-16) | Bloqueante: confirmar en F1 | TI web + Gerencia |
| Q-02 | Matriz de dispositivos y mínimos de SO (DN-01, MED-01, SPK-02) | Definir ranuras ahora y modelos tras MED-01 | Gerencia + TI |
| Q-03 | Perfil de carga para el BFF (DN-07, MED-01) | Definir con Comercial | Comercial + TI |
| Q-04 | Plazo máximo de frescura (PA-04) | Medir y proponer; hoy el valor medido se registra | Dirección comercial + TI |
| Q-05 | Severidades y SLA de la sección 8 | Validar o ajustar | IPR (Gerencia + TI) |
| Q-06 | Adopción de `patrol` (SPK-01) y alternativas | Decidir tras el *spike* | Responsable técnico de la app |
| Q-07 | Herramienta de pruebas del BFF y de carga (compatibilidad con Node y licencia) | *Spike* en F1 | Responsable técnico web |
| Q-08 | Herramienta de gestión de casos y defectos (hoy los casos viven en Markdown) | Elegir antes de F3; mantener la numeración TC | IPR + QA |
| Q-09 | Quién crea y mantiene los fixtures `QA-*` en *staging* | Equipo web con QA | TI web |
| Q-10 | Resolución de las 107 marcas [A VALIDAR] (PA-xx, D-xx) | Calendario de decisiones | IPR |
| Q-11 | Granjas de dispositivos y ejecutores de CI para iOS (costo y disponibilidad) | Evaluar en F1 (D-15) | Gerencia |

---

## 16. Próximos pasos (sin ejecutar nada hoy)

1. Confirmar *staging* y Wompi sandbox (Q-01) y autorizar el sondeo (D-16).
2. Resolver SPK-01 a SPK-04 y el *spike* de herramientas del BFF (Q-06, Q-07).
3. Definir la matriz de dispositivos con MED-01 (Q-02).
4. Crear los fixtures sintéticos y las cuentas de prueba en *staging* (Q-09).
5. Completar la derivación de los AC sin caso (26 no Seguridad) y coordinar con seguridad los 75 AC delegados.
6. Activar las puertas de CI del repositorio web (QG-B01 a QG-B07) antes de que exista código de `/mobile/v1`.
7. Registrar el primer ciclo en [test_results.md](test_results.md) solo cuando exista una prueba ejecutada con evidencia.

*Fin del documento. BORRADOR: ninguna prueba fue ejecutada.*

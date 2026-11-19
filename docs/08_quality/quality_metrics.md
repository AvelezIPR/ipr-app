# Métricas de calidad — App móvil IPR (MVP)

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Calidad. No se programa nada. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para validación de IPR. Umbrales = **objetivos propuestos**, no mediciones |
| **Rol** | Ingeniería de QA Automation |
| **Fuentes** | [non_functional_requirements.md](../02_requirements/non_functional_requirements.md) (RNF, MED-xx, NL-xx) · [acceptance_criteria.md](../02_requirements/acceptance_criteria.md) · [api_architecture.md](../05_api/api_architecture.md) |
| **Relacionados** | [testing_strategy.md](testing_strategy.md) · [test_cases.md](test_cases.md) · [test_results.md](test_results.md) |

> **Aviso central.** **La medición actual de todos los indicadores es "sin medición".** La app no existe, el backend móvil no existe y la web móvil tampoco tiene Core Web Vitals reales medidos (el SEO audit es solo análisis estático). Los umbrales de este documento **son objetivos tomados de los RNF** y cada RNF ya los declara provisionales hasta completar las mediciones MED-xx. **Ningún requisito se declara cumplido.**

---

## 1. Cómo leer este documento

### 1.1 Objetivo frente a medición

| Concepto | Definición | Estado hoy |
|---|---|---|
| **Umbral inicial (objetivo)** | Valor que se pretende alcanzar. Se toma de un RNF o de una puerta de la estrategia; se indica el origen y su justificación. Es una **propuesta** | Definido (provisional) |
| **Medición actual** | Valor observado en una ejecución real, con evidencia, fecha, versión, entorno y dispositivo (reglas de [test_results.md](test_results.md)) | **Sin medición** en todos los indicadores |
| **Método de medición** | Cómo se obtendrá la medición | Propuesto |

Reglas:
1. Un objetivo nunca se presenta como medición ni se redacta en pasado ("cumple", "alcanza").
2. No se inventan umbrales nuevos: cuando ningún RNF define uno, el indicador dice **"sin umbral inicial"** y se registra solo para ver tendencia hasta tener línea base.
3. Toda medición de rendimiento se hace en *builds* *profile* o *release*, nunca en *debug* (RNF §0.2).
4. Los umbrales provisionales se recalibran con las mediciones MED-xx de la sección 4; **ningún umbral es definitivo mientras esas mediciones no existan**.
5. Las referencias a umbrales de las tiendas (Android vitals, Core Web Vitals, WCAG) se citan de los RNF y deben **re-verificarse** antes de cerrarlos.

### 1.2 Clasificación del contenido

| Tipo | Dónde está |
|---|---|
| **Hechos** | Sección 2 (datos del diseño de pruebas, calculados sobre los documentos); columna "Medición actual" |
| **Supuestos** | Los de [testing_strategy.md](testing_strategy.md) §1.2 |
| **Propuestas** | Umbrales y métodos de las secciones 3 y 6 |
| **Decisiones pendientes** | Sección 8 |
| **Riesgos** | Sección 9 |

---

## 2. Qué existe hoy (hechos del diseño, no mediciones de calidad)

Estos datos describen el **diseño de las pruebas**, no el estado del producto.

| Dato | Valor | Fuente |
|---|---|---|
| Criterios de aceptación del MVP | 490 | `acceptance_criteria.md` |
| AC con marca [A VALIDAR] | 107 | `acceptance_criteria.md` |
| Casos de prueba desarrollados | 160 | [test_cases.md](test_cases.md) |
| AC con caso desarrollado (cualquier tipo) | 389 de 490 (79,4 %) | [test_cases.md](test_cases.md) §5.2 |
| AC no Seguridad con caso desarrollado | 369 de 395 (93,4 %) | idem |
| AC de seguridad con regresión funcional complementaria / delegados íntegramente a seguridad | 20 / 75 | idem |
| Casos ejecutados, aprobados o fallidos | 0, 0, 0 | [test_results.md](test_results.md) §1 |
| Pruebas automáticas del frontend web | 0 | COD §2 |
| Puertas de CI de calidad activas | Ninguna (el CI solo despliega) | COD §2, SEC-10 |

---

## 3. Indicadores, umbrales y métodos

Todas las filas tienen **Medición actual: sin medición**. Las columnas de origen indican el RNF o la puerta de la que se toma el umbral inicial.

### 3.1 Cobertura de pruebas

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-01 | Cobertura de líneas de la app (unitarias y widget) | ≥ 70 % global; no se permite bajar | RNF-089: valor propuesto por práctica habitual; la cobertura no sustituye la calidad de las pruebas | Sin medición | `flutter test --coverage` y script de umbral por módulo en CI (QG-M05) | F2, F3 |
| QM-02 | Cobertura en módulos críticos (`core/session`, `core/network`, `features/cart/domain`, `features/checkout/domain`, `shared/formatting`, `features/technical_tools/domain`) | ≥ 90 % | RNF-089 | Sin medición | Igual que QM-01, por carpeta | F2, F3 |
| QM-03 | Cobertura de líneas del módulo `/mobile/v1` del BFF | ≥ 80 % | RNF-090 | Sin medición | Cobertura del ejecutor de pruebas del BFF (herramienta por decidir, Q-07) | F2, F3 |
| QM-04 | Endpoints con pruebas de contrato (caso feliz, error y autenticación) contra el OpenAPI | 100 % | RNF-090; ADR-001 | Sin medición | Reporte de contrato en CI (QG-B04) | F2, F3 |
| QM-05 | Casos de la calculadora BTU y paridad con la web | ≥ 30 casos y paridad | RNF-092; **[A VALIDAR — D-08]** | Sin medición | Pruebas unitarias con los vectores validados por Ingeniería | F2, F3 |
| QM-06 | Aprobación del recorrido de compra E2E (aprobado, rechazado, cancelado) en ambas plataformas | 100 % | RNF-091; NL-02 | Sin medición | E2E en *staging* con Wompi sandbox | F3, F4 |
| QM-07 | AC con caso desarrollado (cobertura del diseño) | Propuesta: 100 % de los AC no Seguridad del MVP antes de F3 | Propuesta de QA; no hay RNF. Hoy 93,4 % (sección 2) | Sin medición de ejecución | Conteo automático AC → TC (sección 4.2 de la estrategia) | F2 |
| QM-08 | AC verificados (todos sus casos "Aprobado" con evidencia) | 100 % de los AC no Seguridad del MVP para el release, salvo los condicionados por [A VALIDAR] con aceptación formal | Propuesta de QA derivada de QG-R01 | **0 de 490** | Matriz AC → resultado ([test_results.md](test_results.md) §10) | F3, F4 |
| QM-09 | Tasa de aprobación de los casos P1 | 100 % en el candidato a versión | QG-R01 (propuesta de QA) | Sin medición | [test_results.md](test_results.md) §5 | F3, F4 |

### 3.2 Defectos

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-10 | Defectos S1 abiertos en un release | 0 | Criterio de no-lanzamiento NL-02, NL-13 y definición de S1 ([testing_strategy.md](testing_strategy.md) §8) | Sin medición | Gestor de defectos | F3 a F6 |
| QM-11 | Defectos S2 abiertos en un release | 0, o aceptación formal si el criterio es condicional | NL-C1 a NL-C7 | Sin medición | Gestor de defectos | F3 a F5 |
| QM-12 | Cumplimiento de los plazos de triage y de corrección | Triage S1 ≤ 1 día hábil, S2 ≤ 2 días hábiles; corrección S1 ≤ 2 días hábiles | **[A VALIDAR]** Solo el triage de S1 tiene respaldo (RNF-116 para errores críticos de datos); el resto es propuesta de QA sin base empírica | Sin medición | Fechas de apertura y cierre en el gestor | F3 a F6 |
| QM-13 | Defectos corregidos por reapertura (reaperturas) | Sin umbral inicial | No hay RNF; se mide para tendencia | Sin medición | Gestor de defectos | F3 a F6 |
| QM-14 | Escape de defectos al piloto o a producción (defectos hallados después del release frente al total) | Sin umbral inicial | No hay RNF ni línea base; se mide para tendencia | Sin medición | Gestor de defectos, etiqueta "escape" | F5, F6 |

### 3.3 Vulnerabilidades (medición y pruebas a cargo de `06_security/security_testing.md`)

QA **no mide** estos indicadores: los consume del documento de seguridad como puertas (QG-M09, QG-R11).

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-15 | Vulnerabilidades críticas o altas abiertas en app, `/mobile/v1`, `ipr/v1` y dependencias | 0 al publicar; críticas ≤ 7 días y altas ≤ 30 días tras el aviso | RNF-048 (plazos propuestos; ajustar con IPR); NL-01 | Sin medición. La auditoría interna de oct-2026 reportó 17 CVE (2 críticas) y su estado actual no está verificado (MED-09) | Escaneo de dependencias en CI y revisión de seguridad | F2, F4, F6 |
| QM-16 | Controles de MASVS L1 evaluados y sin falla sin aceptación | 100 % evaluados; 0 en falla sin riesgo aceptado por escrito | RNF-033; NL-10 | Sin medición | Evaluación de seguridad | F3, F4 |
| QM-17 | Secretos en el binario, el código o los registros de CI | 0 | RNF-036; NL-03 | Sin medición | Escaneo de secretos y análisis del binario | F2, F4 |
| QM-18 | Pruebas de penetración independientes | 0 críticos y 0 altos abiertos tras reprueba; informe archivado | RNF-050; NL-01 | Sin medición | Informe del proveedor (D-15) | F4 |

### 3.4 Rendimiento

Todos los umbrales de rendimiento son **provisionales** hasta MED-01, MED-03, MED-08 y MED-11. Dispositivo de referencia: un Android de gama media-baja y el iPhone más antiguo soportado (por definir con MED-01).

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-19 | Arranque en frío (p90) | ≤ 3,0 s; límite duro 5 s | RNF-001: Android vitals considera excesivo ≥ 5 s (re-verificar); margen del 40 % | Sin medición | Trazas de arranque, 20 corridas por dispositivo, *profile* o *release* (TC-154) | F2 (*spike*), F3, F5 |
| QM-20 | Arranque tibio y reanudación (p90) | Tibio ≤ 1,5 s; reanudación ≤ 1,0 s | RNF-002 | Sin medición | Igual que QM-19 | F3, F5 |
| QM-21 | Contenido útil de pantallas de datos bajo `RED-4G-LENTA` (p90) | Esqueleto ≤ 100 ms; ≤ 2,0 s con caché acertada; ≤ 4,0 s con fallo de caché; Wi-Fi ≤ 1,0 s | RNF-003: umbrales de percepción de latencia de Nielsen | Sin medición | Pruebas con red emulada y cronometraje (TC-107) | F3, F5 |
| QM-22 | Fluidez del desplazamiento | ≤ 5 % de cuadros lentos en listado de 100 ítems; 0 cuadros congelados | RNF-004 (provisional) | Sin medición | DevTools y trazas en *profile* (TC-155) | F2, F3, F5 |
| QM-23 | Retroalimentación e interacción | Respuesta ≤ 100 ms; primer cuadro de la pantalla destino ≤ 300 ms | RNF-005 | Sin medición | Trazas de interacción | F3 |
| QM-24 | Memoria | Crecimiento ≤ 10 % y 0 cierres por memoria; techo absoluto por definir | RNF-006; **[A VALIDAR — MED-11]** | Sin medición | Perfil de memoria en recorridos repetidos | F3, F5 |
| QM-25 | Batería | 0 servicios o *wake locks* sostenidos en segundo plano; techo numérico por definir | RNF-007; **[A VALIDAR — MED-11]** | Sin medición | Herramientas de energía del sistema | F3, F5 |
| QM-26 | Tamaño de la app | ≤ 40 MB Android y ≤ 60 MB iOS; crecimiento > 10 % requiere justificación | RNF-008: supuesto de ingeniería sin medición | Sin medición | Tamaño del *build* de *release* | F2, F4 |
| QM-27 | Peso de imágenes | Miniatura ≤ 40 KB p90; imagen principal ≤ 200 KB p90; WebP o AVIF | RNF-009; MED-07 | Sin medición | Captura en *staging* (TC-156) | F1, F3 |
| QM-28 | Peso de respuestas y datos por sesión | Página de 20 productos ≤ 50 KB sin comprimir; ficha ≤ 150 KB; sesión de referencia ≤ 5 MB | RNF-011: estimación propia; MED-08 | Sin medición | Captura en *staging* (TC-156) | F3 |
| QM-29 | Latencia del BFF por endpoint | Listados con caché ≤ 300 ms; sugerencias ≤ 150 ms; catálogo con fallo de caché ≤ 2,5 s; login/refresh ≤ 1,5 s; pedidos ≤ 2,0 s; ticket de checkout ≤ 2,0 s | RNF-012 (provisional); MED-03 | Sin medición | Métricas del BFF y prueba de carga (TC-152) | F3, F5, F6 |
| QM-30 | Traspaso a checkout dentro del TTL del ticket | Apertura ≤ 5 s tras recibir el ticket; solicitud del ticket p95 ≤ 2,0 s | RNF-013: consumir ≤ 10 % del TTL de 60 s | Sin medición | Cronometraje en E2E (TC-066) | F3 |
| QM-31 | Capacidad del BFF | Errores 5xx < 1 %; pico ×3 sin abrir el *breaker*; memoria estable en 2 h | RNF-014; **[A VALIDAR — DN-07, MED-01]** el perfil de carga no está definido | Sin medición | Prueba de carga con el perfil acordado (TC-152) | F3, F5 |
| QM-32 | Degradación de la web por la carga móvil | p95 de la web degradado ≤ 10 % | RNF-015 (propuesta: margen no perceptible); ADR-001 C4 | Sin medición | Medición paralela en la prueba de carga y el piloto | F3, F5 |
| QM-33 | Recursos del proceso Node | Crecimiento sostenido ≤ 5 %/h; retraso del bucle de eventos p99 ≤ 100 ms; CPU p95 ≤ 70 % | RNF-016 | Sin medición | Métricas del proceso en *staging* | F3, F5, F6 |
| QM-34 | Espera en cola hacia WooCommerce | p95 ≤ 1,0 s; > 3 s responde 503 con `Retry-After` | RNF-018 | Sin medición | Métricas de `wcGet` | F3 |

### 3.5 Estabilidad y fallos (crash-free)

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-35 | Usuarios sin fallos (crash-free) | ≥ 99,5 % en el piloto y los primeros 30 días | RNF-098: más estricto que el umbral de comportamiento deficiente de Android vitals (≈ 1,09 % de fallos percibidos por usuario, re-verificar) | Sin medición | Panel de estabilidad (Play Console, App Store Connect, proveedor de fallos por decidir en DN-02) | F5, F6 |
| QM-36 | ANR | ≤ 0,3 % en el piloto y los primeros 30 días | RNF-098 (referencia de Google ≈ 0,47 %, re-verificar) | Sin medición | Igual que QM-35 | F5, F6 |
| QM-37 | Excepciones no controladas con pila simbolizada | 100 %; 0 con datos personales | RNF-097 | Sin medición | Revisión del reporte de fallos | F2, F5 |
| QM-38 | Pedidos o cobros duplicados | 0 | RNF-024; NL-02 | Sin medición | E2E (TC-062, TC-071, TC-073) y conteo en WooCommerce | F3, F4, F5 |
| QM-39 | Estado correcto del pedido tras el retorno | ≤ 5 s tras volver (p95); si sigue pendiente tras ≈ 2 min se muestra "pendiente" con acción | RNF-025 | Sin medición | E2E (TC-067 a TC-071) | F3 |
| QM-40 | Errores comprensibles | 100 % de errores mapeados a un mensaje en español de Colombia con acción; 0 trazas visibles | RNF-027 | Sin medición | Casos de resiliencia (TC-099 a TC-102) | F2, F3 |

### 3.6 Disponibilidad y resiliencia

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-41 | Disponibilidad del BFF móvil | ≥ 99,5 % mensual (≈ 3,6 h de caída por mes de 30 días) | RNF-019: un proceso y un servidor sin redundancia no sustentan 99,9 %; **[A VALIDAR — DN-06]** | Sin medición. Disponibilidad histórica de la web: sin datos (MED-05) | Monitoreo sintético cada ≤ 5 min (RNF-102) | F5, F6 |
| QM-42 | Respuestas 200 vacías causadas por un fallo ascendente o por el índice no listo | 0 | RNF-022, RNF-023 | Sin medición | Contrato y resiliencia (TC-104) | F3 |
| QM-43 | Reversa del BFF | ≤ 15 min, ensayada una vez en *staging* | RNF-030 | Sin medición | Ensayo de reversa | F3, F4 |
| QM-44 | Efecto de un interruptor remoto | ≤ 5 min | RNF-029 | Sin medición | Prueba con cambio de configuración | F3 |
| QM-45 | Solicitudes de la app con desafío o 403 del WAF | ≤ 0,1 % | RNF-032: "ruido tolerable" propuesto; MED-15 | Sin medición | Tráfico sintético en *staging* (TC-032) y piloto | F3, F5 |
| QM-46 | Alertas operativas activas | Mínimo las de RNF-101 (*breaker* abierto > 60 s, 5xx > 2 % en 5 min, p95 > 2× objetivo en 10 min, índice con antigüedad > 15 min…) | RNF-101; NL-09 | Sin medición | Verificación de configuración de alertas | F5, F6 |

### 3.7 Accesibilidad

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-47 | Criterios WCAG 2.2 A/AA aplicables en falla en flujos críticos | 0, o con excepción documentada y aceptada | RNF-067 | Sin medición | Guías automáticas más revisión manual | F3, F4 |
| QM-48 | Flujos críticos completos con TalkBack y VoiceOver y con texto al 200 % | 3 de 3 (login, compra, eliminar cuenta) en ambas plataformas | RNF-068, RNF-070; NL-14 | Sin medición | Recorrido manual (TC-158) | F3, F4 |
| QM-49 | Contraste de texto e iconos | Texto ≥ 4,5:1 (grande ≥ 3:1); iconos y bordes ≥ 3:1 | RNF-069; riesgo R-NF-08 (el verde de marca `#5ba628` ≈ 3,0:1 sobre blanco según cálculo propio); MED-12 | Sin medición | Prueba de contraste y herramienta sobre los tokens oficiales | F1, F3 |
| QM-50 | Objetivos táctiles | ≥ 48 × 48 dp (Android) y ≥ 44 × 44 pt (iOS); nunca < 24 × 24 px | RNF-071 | Sin medición | Guías de accesibilidad (TC-157) | F2, F3 |
| QM-51 | Elementos interactivos con nombre, rol y estado | 100 % | RNF-070 | Sin medición | Guías y recorrido con lector | F3, F4 |

### 3.8 Calidad de código

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-52 | Análisis estático de la app | 0 errores y 0 advertencias con reglas estrictas; formato verificado | RNF-087 | Sin medición | `flutter analyze` y `dart format` en CI | F2 |
| QM-53 | Tipos y lint del BFF | 0 errores en modo estricto | RNF-088 | Sin medición (hoy el CI no ejecuta `tsc` ni lint) | `tsc --noEmit` y ESLint en CI | F2 |
| QM-54 | Fusiones con pipeline verde | 100 %; 0 *builds* de *release* manuales | RNF-093 | Sin medición | Historial del CI | F2, F4 |
| QM-55 | Revisión de código | 100 % con ≥ 1 aprobación de alguien distinto del autor | RNF-095 | Sin medición | Configuración de rama protegida | F2 |
| QM-56 | Gestión de dependencias | `pubspec.lock` versionado; ninguna dependencia crítica sin publicaciones en 24 meses sin excepción | RNF-094 | Sin medición | Revisión del diff y reporte de dependencias | F2, F6 |
| QM-57 | OpenAPI actualizado en el mismo PR que cambia un endpoint | 100 % | RNF-096 | Sin medición | Verificación en CI | F2 |
| QM-58 | Cambios incompatibles en `/mobile/v1` | 0 | RNF-085 | Sin medición | Detector de incompatibilidades en CI (QG-B05) | F2, F3, F6 |
| QM-59 | Complejidad ciclomática, duplicación y otras métricas estáticas | **Sin umbral inicial** | Ningún RNF las define; no se inventa un valor | Sin medición | Tendencia con las herramientas del análisis estático | F2 |

### 3.9 Compatibilidad

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-60 | Dispositivos físicos en la matriz | ≥ 8 (≥ 4 Android de gama baja, media y alta con ≥ 3 marcas; ≥ 3 iPhone incluido el más antiguo soportado; ≥ 1 tableta) | RNF-082: heurística de cobertura; se ajusta con MED-01 | Sin medición | Inventario de la matriz | F3, F4 |
| QM-61 | Humo de flujos críticos en la matriz | 100 % de los dispositivos | RNF-082 | Sin medición | TC-159 | F3, F4 |
| QM-62 | Flujos críticos sin cierres inesperados bajo los perfiles de red | 0 cierres en Wi-Fi, `RED-4G-LENTA`, `RED-DEGRADADA` e intermitente | RNF-083 | Sin medición | TC-107 | F3 |
| QM-63 | Sin desbordes de pantalla | Desde 320 dp; usable desde 600 dp | RNF-081 | Sin medición | Golden y matriz | F3 |
| QM-64 | Mínimos de Android e iOS | Propuesta API 26 e iOS 15.0, sujetos a validación | RNF-078, RNF-079; **[A VALIDAR — DN-01, MED-01, SPK-02]** | Sin medición | Spike y telemetría de versiones del piloto (RNF-104) | F1, F5 |

### 3.10 Calidad de datos del catálogo

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-65 | Productos comprables con precio ≤ 0, y "$0" o vacíos mostrados | 0 | RNF-107; NL-13 | Sin medición | Verificación automatizada del catálogo (TC-053, TC-054) | F3, F6 |
| QM-66 | Productos no publicados u ocultos visibles | 0 | RNF-112; NL-13 | Sin medición | Verificación automatizada | F3, F6 |
| QM-67 | Frescura de precio y stock (p95) | ≤ 10 min | RNF-111 (índice cada 5 min más caché); **[A VALIDAR — PA-04]** | Sin medición | E2E con cambio en WooCommerce (TC-116) | F3, F5 |
| QM-68 | Búsqueda por SKU exacto en primer lugar | 100 % de 100 SKUs de prueba | RNF-110; **[A VALIDAR — RF-022]** el tamaño de muestra y el ranking | Sin medición | TC-108, TC-110 | F3, F6 |
| QM-69 | Productos mal clasificados | ≤ 2 % de la muestra | RNF-106: criterio editorial a validar con Catálogo; MED-06 | Sin medición | Muestra de ≈ 270 a 300 productos | F3, F5, F6 |
| QM-70 | Imágenes presentes y utilizables | 100 % con imagen; lado menor ≥ 600 px; 0 enlaces rotos | RNF-108 (provisional) | Sin medición | Verificación semanal | F3, F6 |
| QM-71 | Navegación sin enlaces rotos | 0 | RNF-113 | Sin medición | Recorrido nocturno del árbol de categorías | F3, F6 |
| QM-72 | Corrección de errores críticos de datos | ≤ 1 día hábil | RNF-116 (propuesta) | Sin medición | Tablero semanal de calidad de datos | F5, F6 |

### 3.11 Privacidad

| ID | Indicador | Umbral inicial (objetivo) | Justificación y origen | Medición actual | Método de medición | Fase |
|---|---|---|---|---|---|---|
| QM-73 | Registros con autorización previa, expresa e informada | 100 %; casilla sin marcar; no se registra sin aceptar | RNF-056; **[A VALIDAR — D-12, PA-10]** | Sin medición | TC-002, TC-006 | F3, F4 |
| QM-74 | Eliminación de cuenta desde la app | ≤ 3 toques desde Mi cuenta; acceso revocado de inmediato; datos suprimidos o anonimizados ≤ 15 días hábiles | RNF-058 (plazo de reclamos del art. 15 de la Ley 1581); **[A VALIDAR — PA-09]** | Sin medición | TC-087, TC-089 | F3, F4 |
| QM-75 | Borrado de datos locales al cerrar sesión o eliminar la cuenta | 100 % | RNF-062 | Sin medición | Verificación funcional (la inspección forense es de seguridad) | F3 |
| QM-76 | Datos personales o secretos en los registros | 0 apariciones | RNF-047; NL-08 | Sin medición | Valores canario; **a cargo de seguridad** | F2, F3, F4 |

---

## 4. Mediciones pendientes que fijan los umbrales (de RNF §6)

Mientras no existan, los umbrales anteriores son provisionales.

| MED | Qué mide | Desbloquea | Estado |
|---|---|---|---|
| MED-01 | Perfil real de la clientela (visitas, picos, sistema operativo, gama) | Matriz de dispositivos, mínimos de SO, perfil de carga | Sin medición |
| MED-02 | Core Web Vitals reales de la web móvil | Referencia de paridad (RNF-003) | Sin medición |
| MED-03 | Latencia y errores del backend actual | RNF-003, 012, 013, 015, 018, 022 | Sin medición |
| MED-04 | Capacidad del servidor y del proceso Node | RNF-014, 016, 017, 030 | Sin medición |
| MED-05 | Disponibilidad histórica | RNF-019 | Sin medición |
| MED-06 | Auditoría de calidad del catálogo | RNF-106 a 112 | Sin medición |
| MED-07 | Peso y dimensiones de imágenes | RNF-009, 011, 108 | Sin medición |
| MED-08 | Tamaño real de respuestas | RNF-011 | Sin medición |
| MED-09 | `npm audit` u OSV del frontend actual | RNF-048 | Sin medición |
| MED-10 | Reglas de Wordfence y WAF | RNF-042, 105 | Sin medición |
| MED-11 | Línea base del prototipo Flutter (arranque, fluidez, memoria, batería, tamaño) | RNF-001 a 008, 077 | Sin medición |
| MED-12 | Contraste de la paleta de marca | RNF-069 | Sin medición |
| MED-13 | Inventario de datos personales y política vigente | RNF-056 a 066 | Sin medición |
| MED-14 | Tiempos de confirmación de pago de Wompi | RNF-013, 024, 025 | Sin medición |
| MED-15 | Comportamiento de Cloudflare frente a la app | RNF-032, 037 | Sin medición |
| MED-16 | Costo de la búsqueda de token por `usermeta` | RNF-012 | Sin medición |
| MED-17 | Calentamiento del índice de catálogo | RNF-016, 023, 111 | Sin medición |
| MED-18 | Embudo de compra de la web | RNF-103 | Sin medición |

---

## 5. Criterios de no-lanzamiento

La app **no se publica** (ni en tiendas ni en piloto abierto) si se cumple cualquiera de los criterios **absolutos** (RNF §5.1). Los **condicionales** solo pueden aceptarse con aceptación formal y por escrito de IPR (Gerencia + TI), con plan y fecha de corrección.

### 5.1 Absolutos (bloquean sin excepción)

"Estado hoy" indica si existe evidencia: **ninguno tiene evidencia, por lo tanto ninguno puede considerarse cumplido.**

| ID | Criterio | Puerta o casos de QA | Estado hoy |
|---|---|---|---|
| NL-01 | Vulnerabilidad crítica o alta abierta; pentest no realizado sobre autenticación y checkout | QG-M09, QG-R11 (seguridad) | Sin evidencia |
| NL-02 | Fallo de compra E2E en *staging* con Wompi sandbox en cualquiera de las dos plataformas; pedido o cobro duplicado; manipulación de precio, repetición de ticket o redirección aceptada | QG-R02, QG-R03; TC-062, TC-067 a TC-074, TC-147 | Sin evidencia |
| NL-03 | Secretos en binario, código o registros de CI | QG-M09, QG-R11 (seguridad) | Sin evidencia |
| NL-04 | Tokens inseguros; token por URL; tráfico en claro; TLS deshabilitado | QG-R11 (seguridad); TC-146 | Sin evidencia |
| NL-05 | Sesiones por dispositivo no funcionan; sin renovación ni revocación; rate limit inexistente o solo en memoria | QG-R04; TC-017, TC-018, TC-020 a TC-023, TC-031, TC-148, TC-149 | Sin evidencia |
| NL-06 | Endpoint privado sin token o con fuga entre usuarios | QG-R11 (seguridad); regresión TC-086, TC-150 | Sin evidencia |
| NL-07 | Sin eliminación de cuenta; sin registro de consentimiento; política no revisada por Jurídico; fichas de privacidad de las tiendas que no coinciden con el tráfico real | QG-R10, QG-R13; TC-006, TC-035, TC-089, TC-092 | Sin evidencia |
| NL-08 | Datos personales, tokens o secretos en registros | QG-R11 (seguridad) | Sin evidencia |
| NL-09 | Sin reporte de fallos, monitoreo ni alertas en producción | QM-37, QM-46 | Sin evidencia |
| NL-10 | Controles de MASVS L1 en "falla" sin riesgo aceptado | QG-R11 (seguridad) | Sin evidencia |
| NL-11 | Cuentas de tienda o claves de firma sin titularidad ni custodia de IPR | Lista de verificación de F4 | Sin evidencia |
| NL-12 | No se cumplen las condiciones C1 a C4 de ADR-001 | QG-R05, QG-R15; TC-032, TC-152 | Sin evidencia |
| NL-13 | Precios o disponibilidad incorrectos de forma sistemática | QG-R09; QM-65, QM-66 | Sin evidencia |
| NL-14 | Un flujo crítico (compra, login, eliminar cuenta) no se completa con TalkBack o VoiceOver, o se rompe con texto al 200 % | QG-R08; TC-158 | Sin evidencia |

### 5.2 Condicionales (requieren aceptación formal del riesgo)

| ID | Criterio | Indicadores | Estado hoy |
|---|---|---|---|
| NL-C1 | Arranque en frío p90 entre 3,0 y 5,0 s (≥ 5 s es absoluto) | QM-19 a QM-21 | Sin evidencia |
| NL-C2 | Crash-free < 99,5 % en el piloto pero fuera de "comportamiento deficiente" de las tiendas (dentro de ese umbral es absoluto) | QM-35, QM-36 | Sin evidencia |
| NL-C3 | Perfil de carga probado y superado, con recomendaciones pendientes (si la prueba de carga no se hizo es absoluto) | QM-31, QM-33, QM-34 | Sin evidencia |
| NL-C4 | Fallos AA menores en pantallas no críticas, o contraste insuficiente en elementos secundarios | QM-47, QM-49, QM-50 | Sin evidencia |
| NL-C5 | Defectos de categorías, imágenes o atributos sobre el umbral sin afectar precio ni compra | QM-69, QM-70 | Sin evidencia |
| NL-C6 | Límites de tamaño, memoria o batería superados sin impacto en estabilidad | QM-24 a QM-26 | Sin evidencia |
| NL-C7 | Verificación de correo, *certificate pinning* y detección de root diferidos por decisión documentada | (decisión documentada) | Sin evidencia |

### 5.3 Criterios de no-lanzamiento adicionales de QA (PROPUESTA)

Derivados de la estrategia; **no están en los RNF** y requieren validación de IPR.

| ID | Criterio | Justificación |
|---|---|---|
| NL-Q1 | Algún caso P1 de Integración o E2E en estado "Fallido" o "Bloqueado" en el candidato a versión | QG-R01; los casos P1 cubren los flujos críticos |
| NL-Q2 | Algún defecto S1 abierto | Definición de S1 |
| NL-Q3 | Cobertura de código por debajo de los umbrales de RNF-089 (QM-01, QM-02) o BFF por debajo de RNF-090 | Puertas de merge |
| NL-Q4 | Algún AC [A VALIDAR] de un flujo crítico (compra, sesión, eliminación) cuya decisión siga abierta y cuyo comportamiento no esté implementado según una decisión documentada | Un caso con [A VALIDAR] no puede aprobarse (regla de `acceptance_criteria.md` §0.2) |
| NL-Q5 | Casos de resultado de pago (aprobado, rechazado, cancelado) o de eliminación de cuenta ejecutados con evidencia solo en una plataforma | NL-02 y RNF-091 exigen ambas plataformas |

---

## 6. Cadencia y responsables

| Indicador (familia) | Cuándo se mide | Quién lo produce | Quién lo revisa |
|---|---|---|---|
| Cobertura y análisis estático | Cada PR | CI | Desarrollo |
| Contrato | Cada PR de cualquiera de los repositorios | CI | Desarrollo BFF |
| E2E y compatibilidad | Nocturno y por candidato | CI y QA | QA |
| Rendimiento y accesibilidad manual | Por candidato y en el piloto | QA | QA y Desarrollo |
| Carga del BFF | Antes del piloto | QA y TI | TI web |
| Estabilidad y disponibilidad | Piloto y operación (semanal y mensual) | Monitoreo y paneles | TI y QA |
| Calidad de datos del catálogo | Semanal | Responsable de calidad de datos (RNF-116) | Catálogo y QA |
| Seguridad | Según `06_security/security_testing.md` | Seguridad | Seguridad y QA (puerta) |

---

## 7. Tablero de calidad (plantilla, vacío)

Se completa por ciclo con datos de [test_results.md](test_results.md). **Hoy no hay datos.**

| Semana o ciclo | Versión | Casos ejecutados / planificados | Aprobación P1 | AC verificados | Defectos S1 abiertos | Defectos S2 abiertos | Cobertura app / BFF | Crash-free | Decisión recomendada |
|---|---|---|---|---|---|---|---|---|---|
| — | — | 0 / 160 | Sin medición | 0 de 490 | Sin medición | Sin medición | Sin medición | Sin medición | — |

---

## 8. Decisiones pendientes que afectan a las métricas

| ID | Decisión | Efecto |
|---|---|---|
| DN-01, MED-01, SPK-02 | Mínimos de SO y matriz de dispositivos | QM-60 a QM-64 |
| DN-02 | Proveedor de reporte de fallos y analítica | QM-35 a QM-37 |
| DN-06 | Objetivo de disponibilidad y soporte | QM-41 |
| DN-07 | Perfil de carga | QM-31 |
| D-08 | Validación de la fórmula BTU | QM-05 |
| D-12, PA-09, PA-10 | Textos legales, retención y consentimiento | QM-73, QM-74 |
| PA-04 | Plazo máximo de frescura | QM-67 |
| D-15 | Presupuesto de pentest y herramientas | QM-18, herramientas de carga y granjas |
| Q-05 | Severidades y SLA | QM-12 |
| Q-08 | Herramienta de gestión de casos y defectos | Cálculo automático de QM-08 y QM-09 |

---

## 9. Riesgos de las métricas

| ID | Riesgo | Mitigación |
|---|---|---|
| R-M01 | Tomar un objetivo por una medición (por ejemplo, declarar "cumple" por haber definido el umbral) | Regla 1 de la sección 1.1; columna "Medición actual" con "sin medición" hasta que exista evidencia |
| R-M02 | Umbrales de las tiendas desactualizados (Android vitals, requisitos de privacidad) | Re-verificar antes de cerrar umbrales (S-NF-07); revisión anual (RNF-080) |
| R-M03 | La cobertura de código da una falsa seguridad | RNF-089 aclara que no sustituye la calidad de las pruebas; se combina con QM-08 (AC verificados) y QM-06 |
| R-M04 | Medir rendimiento en *debug* o en emulador | Regla 3; solo *profile* o *release* y dispositivo físico de referencia |
| R-M05 | Las mediciones del piloto no son representativas sin datos de la clientela (MED-01) | Telemetría agregada de versiones y dispositivos desde el piloto (RNF-104) |
| R-M06 | Métricas de seguridad duplicadas o contradictorias entre documentos | QA las consume por referencia de `06_security/security_testing.md` |

*Fin del documento. BORRADOR: todas las mediciones actuales están "sin medición".*

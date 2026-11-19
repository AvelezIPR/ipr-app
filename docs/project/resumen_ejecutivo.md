# Resumen ejecutivo para la Gerencia — App móvil de IPR Partes y Repuestos

| | |
|---|---|
| **Proyecto** | App móvil (Android e iOS, hecha con Flutter) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fecha** | 2026-11-18 |
| **Estado** | **BORRADOR para decisión de la Gerencia.** Resume la documentación existente; no aprueba nada ni afirma que algo funcione. |
| **Para quién** | Gerencia (lectura no técnica). El detalle está en los documentos citados entre paréntesis. |

**Etiquetas:** **[HECHO]** comprobado en un documento o en el código · **[SUPUESTO]** se asume para planificar · **[PROPUESTA]** recomendación del equipo de proyecto, sin aprobar · **[PENDIENTE]** decisión humana abierta.

**Fuentes abreviadas:** INV = `00_discovery/informe_investigacion` · COD = `informe_codigo_frontend` · VIS = `01_business/vision` · ALC = `scope` · FR/NFR = requisitos funcionales / no funcionales · ADR = `architecture_decisions` · OV = `architecture_overview` · AA = `05_api/api_architecture` · SR = `06_security/security_review` · SC = `security_controls` · PRI = `privacy_assessment` · DS = `07_ux_ui/design_system` · QM = `quality_metrics` · TR = `test_results` · DG = `deployment_guide` · IR = `incident_response` · RM = `project/roadmap` · RK = `risks` · DL = `decisions_log` · IP = `implementation_plan` · DP = `decisiones_pendientes` · RI = `resolucion_inconsistencias`.

## En un minuto

1. Se documentó el proyecto completo, del descubrimiento al plan de trabajo. **No hay código, no hay app, no se ha ejecutado ninguna prueba.**
2. La propuesta: una app que usa los mismos productos, cuentas y pedidos de la web, a través de una capa móvil nueva, con compra pagada en Wompi.
3. **Lo único aprobado** (por el solicitante, 2026-11-18) es la arquitectura de conexión y el alcance del MVP. Todo lo demás es propuesta o está pendiente (DL §2).
4. Para empezar a construir faltan 8 decisiones o condiciones (§6, grupo A). La mayor: **equipo y presupuesto sin definir**, por lo que no hay fechas ni costos.
5. Hoy **no se puede afirmar** nada sobre cumplimiento de la Ley 1581, seguridad ni rendimiento: no hay mediciones ni pruebas (§9).

---

## 1. Qué se pidió y qué se hizo

**Se pidió** una app móvil Flutter para Android e iOS para IPR (VIS §1-3). **Se hizo** únicamente trabajo de análisis y diseño por escrito:

| Se hizo [HECHO] | Cifra | Fuente |
|---|---|---|
| Auditoría pasiva de la web pública y lectura del código del frontend (sin llamar a la API, sin comprar, sin crear cuentas) | — | INV §0; COD cabecera |
| Requisitos funcionales (47 *Must*, 31 *Should*, 25 *Could*, 10 *Won't*) | **113**, de los cuales **76** entran al MVP | FR §0.3 |
| Requisitos no funcionales (rendimiento, seguridad, privacidad, accesibilidad…) | 116 | NFR §0.3 |
| Decisiones de arquitectura (ADR) | 22 (2 aprobadas) | DL §1.1 |
| Controles de seguridad / amenazas / cambios obligatorios antes de producción | 77 / 78 / 41 (recontado) | SC §3.4 y recuento |
| Preguntas para el área jurídica | 36 | PRI §10 |
| Casos de prueba **definidos** | 160 | TR §1 |
| Riesgos consolidados | 59 | RK §7 |
| Plan de implementación | 24 paquetes de trabajo, 8 etapas | IP §2; RM §1 |

| NO se ha hecho [HECHO] | Fuente |
|---|---|
| Escribir código de la app o de la capa móvil; tocar `ipr-frontend` o WordPress | RM §1 (Etapas 2-3 "No iniciada") |
| Ejecutar pruebas: **0 de 160** casos ejecutados; **0 de 18** mediciones base hechas | TR §1; QM §4 |
| Probar en un entorno de pruebas (*staging*) o con Wompi de prueba: su existencia es **desconocida** | DL §6 (C2) |
| Ejecutar `npm audit` (revisión de librerías vulnerables) | COD §5.2; RK RK-034 |
| Leer la política de datos y los términos legales de IPR | PRI §1 (hallazgo 2) |

---

## 2. Qué se encontró de la web actual

Hoy la web es un sitio moderno (Next.js, detrás de Cloudflare) que usa WooCommerce/WordPress como motor de catálogo, clientes y pedidos (INV §1; COD §2).

| Lo bueno [HECHO] | Fuente |
|---|---|
| 885 productos publicados y unas 216 categorías; 31 sedes publicadas (cifra por conciliar) | INV §1, §8 |
| El precio, los impuestos y el stock los recalcula el servidor: la web solo envía "qué producto y cuántos" | COD §1 |
| Pago con Wompi dentro del checkout de WooCommerce; los datos de tarjeta no pasan por IPR | COD §1 |
| Sesión en cookie protegida; el token se guarda cifrado (hash) en WordPress | COD §1 |
| Tres hallazgos graves de una auditoría interna (oct. 2026) ya aparecen corregidos en el código; el equipo atiende hallazgos | COD §5.2 |
| Hay código reutilizable de valor (caché, tolerancia a fallos de WooCommerce) que la app aprovecharía | COD §4 |

| Lo que hay que arreglar o resolver [HECHO salvo indicación] | Fuente |
|---|---|
| **Un solo acceso por usuario:** iniciar sesión en la web cierra la sesión en la app y al revés; la sesión dura 30 días fijos, sin renovación | COD §5.1 H-01, H-02 |
| **El login no limita intentos** (se delega en Wordfence, de reglas desconocidas) | COD H-04 |
| Un token de sesión puede viajar en la URL (queda en registros) | COD H-03 |
| **Sin pruebas automáticas;** el despliegue publica sin revisar tipos, estilo ni librerías vulnerables | COD §2 |
| 17 librerías con vulnerabilidades reportadas en oct. 2026 (2 críticas): **no verificado**; falta ejecutar `npm audit` | COD §5.2 |
| Hoy la web no tiene eliminación de cuenta, recuperación de clave por API, favoritos ni cotizaciones | COD H-08 |
| Cifras institucionales que no coinciden (p. ej. "10.000 referencias" frente a 885 en línea y 1.418; 31 frente a 32 sedes) | INV §8 |
| Las sedes no tienen coordenadas ni horarios; los datos están dentro del código | COD §3 |
| Catálogo: categorías incoherentes, productos sin precio (3 de 7 en la muestra); la app expondrá estos defectos más que la web | INV F3, F6 |
| B2B/mayorista: el código no lo distingue; es una decisión de negocio | COD §1 |

---

## 3. La propuesta en palabras simples

### 3.1 Qué haría la app en su primera versión (MVP) [PROPUESTA con alcance aprobado, ver §4]

El MVP son **76 requisitos** repartidos en cinco bloques (RM §5; 30 + 10 + 11 + 7 + 18 = 76):

| Bloque | Qué incluye | Requisitos |
|---|---|---|
| Catálogo y búsqueda (sin necesidad de cuenta) | Inicio, categorías, filtros, búsqueda por marca o referencia, ficha con precio público IVA incluido; productos sin precio muestran "Más información" que abre WhatsApp con el producto | 30 |
| Cuenta | Registro con aceptación de políticas, ingreso, recuperar clave, sesión por dispositivo | 10 |
| Carrito y compra | Carrito en el celular, resumen, pago en Wompi, resultado de la compra | 11 |
| Perfil y pedidos | Datos, direcciones, historial y detalle de pedidos, **eliminar cuenta**, derechos del titular | 7 |
| Sedes, atención y herramientas | Sedes, ayuda, PQRS, asesoría técnica, calculadora BTU (solo si Ingeniería valida la fórmula) | 18 |

### 3.2 Cómo se conecta [PROPUESTA; aprobada por el solicitante como ADR-001]

La app **nunca** habla directamente con WooCommerce ni guarda claves. Habla con una **capa móvil nueva (`/mobile/v1`) dentro del sitio web existente**, que a su vez usa el código actual para consultar WooCommerce. WordPress se amplía solo donde falta algo (sesiones por dispositivo, eliminar cuenta, etc.) (ADR-001).

### 3.3 El pago con Wompi [PROPUESTA]

1. La app envía al servidor solo producto y cantidad; el servidor responde con un **enlace de pago de un solo uso que vence en 60 segundos** (AA §2 F-08).
2. El enlace se abre en el **navegador del sistema** del teléfono, no en una pantalla propia de la app; ahí WooCommerce y Wompi cobran como en la web. La app no maneja datos de tarjeta (OV §1).
3. **Al volver, la app pregunta al servidor el resultado** y no confía en el enlace de retorno: WordPress solo redirige a la web cuando el pedido no está fallido, cancelado ni pendiente (OV §1, punto 4; COD §5.4).
4. **Sin resolver [PENDIENTE]:** cómo confirma Wompi los pagos (webhooks), qué estados produce y cómo se evita el **doble cobro**. Solo se sabrá con pruebas en un entorno de prueba (DL §4 D-02).

### 3.4 Trabajo que el MVP exige en el sitio actual

Por la decisión de compra completa, el MVP **depende de lo más exigente**: sesiones por dispositivo, límite de intentos de acceso, recuperación y eliminación de cuenta, enlaces que devuelvan a la app, un entorno de pruebas (ALC §3). Los 41 cambios obligatorios antes de producción (23 de prioridad P0) **están todos abiertos** (SC §3). Tres cambios tocan código compartido con la web y exigen pruebas de regresión antes (RI §5, hallazgo 3).

### 3.5 Para una fase 2 [PROPUESTA]

Cotización estructurada, precios B2B por rol, favoritos, notificaciones push, mapa de sedes con coordenadas y horarios, pagos diferidos (Addi), seguimiento de envío, carrito en servidor, modo oscuro, lista de dispositivos. En total 32 requisitos en fase 2 y 5 descartados por ahora (ALC §5; FR §0.3).

---

## 4. Lo que la Gerencia ya aprobó frente a lo que son propuestas

**Aprobado [HECHO, DL §2]**, el 2026-11-18, por el *"solicitante del proyecto"* (el registro no aclara si equivale a la Gerencia: conviene confirmarlo o ratificar):

| Decisión | Qué significa |
|---|---|
| **ADR-001** (= D-01) | La app usa la capa móvil `/mobile/v1` dentro del Next.js existente; no llama a WooCommerce ni a las rutas internas de la web |
| **ADR-002** (resume D-06, D-03, D-04) | MVP con compra completa |
| **D-06** | Carrito y pago con Wompi en el navegador del sistema dentro del MVP |
| **D-03** | Sin B2B en el MVP: un solo perfil con precio público IVA incluido |
| **D-04** | Productos sin precio: solo "Más información" por WhatsApp; sin formulario ni cotizaciones |

Son dos decisiones de fondo (arquitectura y alcance) registradas en cinco entradas. **ADR-001 queda condicionada a cuatro puntos abiertos [PENDIENTE]:** C1 conformidad del responsable técnico de la web y WordPress, C2 existencia de entorno de pruebas, C3 que Cloudflare deje pasar a la app, C4 un piloto que demuestre que la carga móvil no perjudica la web (DL §6).

**Todo lo demás es propuesta o está abierto** (DL §1.1):

| Familia | Total | Aprobadas |
|---|---|---|
| ADR | 22 | 2 |
| Decisiones D-01..D-16 | 16 | 4 (D-01, 03, 04, 06); 12 abiertas |
| Recomendaciones H-01..H-12 | 12 | 0 |
| Decisiones sobre requisitos no funcionales, datos, API y app (DN, DM, AP, DA) | 14 + 9 + 10 + 15 | 0 |
| Preguntas abiertas PA / preguntas al jurídico J | 12 / 36 | 0 |

---

## 5. Riesgos principales en lenguaje de negocio

Hay **59 riesgos: 37 altos, 22 medios, ninguno crítico** (RK §7). Se valoraron **antes de mitigar**: ninguna mitigación está ejecutada. Eso mide cuánto trabajo falta, no que el proyecto sea inviable (RK §1).

| Tema | Qué podría pasar al negocio | Base en hechos hoy | Riesgos |
|---|---|---|---|
| **Seguridad del acceso** | Robo de cuentas por intentos masivos de clave; un acceso robado serviría un mes; clientes sacados de la app al entrar en la web | Sin límite efectivo de intentos; un token por usuario; 30 días sin renovación (COD H-01, H-02, H-04) | RK-030, 031, 032 |
| **Seguridad del pago** | El cliente paga y la app no se entera; doble cobro o pedidos duplicados; enlace que vence a los 60 s | Retorno no garantizado; webhooks y doble pago **desconocidos**; el riesgo se declara "no aceptable" sin cerrarlo (RK §3) | RK-014, 015, 016 |
| **Ley 1581 (datos personales)** | Tratar datos sin prueba de autorización; eliminación de cuenta que borre soportes contables o que sea incompleta; canal de derechos sin responsable; contratos con proveedores sin revisar | Política vigente no leída; el registro actual no guarda prueba de aceptación; plazos de retención sin definir (PRI §1) | RK-048, 049, 050, 051, 053 |
| **Dependencia de terceros** | Cloudflare bloquea a la app; las tiendas la rechazan; Wompi cambia sus estados; librerías abandonadas | Plan de Cloudflare y reglas desconocidos; reglas de tiendas leídas en resumen (DG §0.2) | RK-010, 021, 028 |
| **Calidad de datos del catálogo** | Precios en 0, productos mal clasificados o sin imagen visibles en la app | Auditoría de catálogo no hecha (MED-06) (RK-011) | RK-011, 026 |
| **Infraestructura desconocida** | La web y la app caen juntas por compartir proceso; protecciones que no protegen | Número de procesos del servidor, existencia de entorno de pruebas, Cloudflare en WordPress y versiones: **desconocidos** (10 datos en RI Anexo B) | RK-003, 019, 020, 022 |
| **Plan y equipo** | No se puede estimar ni empezar; cambios en código compartido que rompan la web; despliegue sin pruebas | Equipo y presupuesto sin definir; web sin pruebas (RK §2) | RK-001, 002, 004, 023, 024 |

**Criterios que impedirían publicar** (14 absolutos en NFR §5.1 más los de seguridad en SC §4), entre ellos: vulnerabilidades altas abiertas o prueba de penetración no hecha; compra fallida o duplicada en el entorno de pruebas; sesiones por dispositivo que no funcionan; sin eliminación de cuenta; política de datos no revisada por Jurídico; cuentas de tienda sin titularidad de IPR. Con el estado de hoy **ninguno está superado**.

---

## 6. Decisiones que se necesitan de la Gerencia

Ordenadas por urgencia. Las recomendaciones son del equipo de proyecto y del revisor de consistencia, **no están aprobadas** (DL §5, §10). **Total: 19 decisiones** (A: 8, B: 7, C: 4).

**A. Bloquean el inicio de la construcción (Gate G1, IP §3.1)**

| # | Decisión | Recomendación | Fuente |
|---|---|---|---|
| 1 | **D-15** Equipo, roles y presupuesto (incluye prueba de penetración independiente y herramientas) | Asignarlos antes de cerrar la arquitectura; sin esto no hay plazos | DP D-15; RK-001 |
| 2 | **H-12 / D-16** Autorizar entorno de pruebas con Wompi de prueba y acceso de solo lectura al servidor | Sí, de inmediato: desbloquea 8 contradicciones y las pruebas | RI §4.3 |
| 3 | **C1** Conformidad escrita del responsable técnico de la web y WordPress, con revisión de cambios | Obtenerla antes de cualquier cambio en el sitio | DL §6; RK-002 |
| 4 | **H-01** Ampliar ADR-001 para que WordPress aporte registro, perfil, pedidos, sedes y configuración | Sí; fija el tamaño real del trabajo en WordPress | RI §4.3, CR-038 |
| 5 | **H-02** Retorno del pago: el resultado se confirma siempre consultando al servidor | Sí | RI §4.3 |
| 6 | **H-04** Duración de sesiones: acceso 15 min; renovación 30 días de inactividad, máx. 90 | Sí | RI §4.3 |
| 7 | **D-14** Cuentas de Google Play y Apple a nombre de Inverprimos S.A.S. y custodia de firmas | Confirmarlo antes de fijar el identificador de la app (no se cambia tras publicar) | DP D-14; RK-009 |
| 8 | **DA-01** Aprobar la arquitectura de la app (ADR-003..012) | Aprobar | DL §8.3 |

**B. Alcance y producto (antes de construir cada módulo)**

| # | Decisión | Recomendación | Fuente |
|---|---|---|---|
| 9 | **H-03** Registro con correo ya existente: respuesta uniforme **y verificación de correo en el MVP** (amplía el alcance) | Sí, con verificación | RI §5 hallazgo 1 |
| 10 | **H-05** Solo "cerrar todas las sesiones" en el MVP (incluida la web) | Sí; lista de dispositivos a fase 2 | RI §4.3 |
| 11 | **H-06** Productos "bajo pedido": ¿comprables en la app? | No (WhatsApp) | RI §4.3 |
| 12 | **H-07** Carrito: se conserva al cerrar sesión y se borra al eliminar la cuenta | Sí | RI §4.3 |
| 13 | **H-08** Detalle del pedido con envío, descuento e impuestos | Sí | RI §4.3 |
| 14 | **H-09** Solo clientes (`customer`/`subscriber`) sin permisos administrativos pueden entrar en la app, tras contar los roles | Sí | RI §4.3 |
| 15 | **H-10** Sin compra como invitado | Sin invitado | RI §4.3 |

**C. Antes del piloto y el lanzamiento**

| # | Decisión | Recomendación | Fuente |
|---|---|---|---|
| 16 | Metas de negocio O-1..O-5 (hoy sin metas ni línea base) | Definirlas con datos de tráfico y de pedidos (MED-01, MED-18) | VIS §4; RK-006 |
| 17 | **DN-06** Disponibilidad y soporte posteriores al lanzamiento (horario, canal, responsables) | Soporte en horario comercial; designar responsables antes del piloto | DL §7; IR §1 |
| 18 | **DN-01** Versiones mínimas de Android e iOS | Android 8.0 e iOS 15.0 si las pruebas técnicas lo permiten | DL §7 |
| 19 | **DA-15** Aceptar por escrito el riesgo de no usar *pinning*, detección de root ni atestación | Aceptar con firma de Seguridad y Gerencia | DL §8.3 |

**Condicional, no recomendada por defecto:** si los puntos desconocidos de Wompi no se resuelven, la alternativa prevista es dejar la **compra para fase 2**. Contradice D-06 y sería una decisión nueva del solicitante (RM §6.3).

---

## 7. Qué se necesita de otras áreas

| Área | Qué se necesita | Fuente |
|---|---|---|
| **Jurídico** | Entregar y revisar los 16 documentos de datos (política vigente, términos, contratos con proveedores…); responder las **13 preguntas P0** antes de publicar (de 36); fijar retención al eliminar cuenta (H-11); designar área para derechos del titular; confirmar si IPR debe inscribir bases ante la SIC; aprobar textos de consentimiento y de tiendas | PRI §10, §11.2; DL §9.3 |
| **Marketing / marca** | Manual de marca y logo vectorial; **cuál es el verde oficial** (la documentación dice `#5BA628`, el código web usa `#99C120`); modo oscuro; tono (tú o usted); tipografías y licencias; cifras institucionales oficiales; criterio de "más vendidos" | DS §17.1; DP D-07, D-13 |
| **TI / responsable del sitio** | Conformidad (C1); entorno de pruebas con Wompi de prueba (C2); reglas de Cloudflare para la app (C3); piloto de carga (C4); datos de servidor (procesos, versiones, roles); alojar archivos de enlaces de la app; ejecutar `npm audit`; activar doble verificación en cuentas privilegiadas (propuesta aún sin aprobar) | DL §6; RI Anexo B; SC §3 |
| **Ingeniería y comercial** | Validar la fórmula de la calculadora BTU (si no, sale del MVP); canal corporativo de ingeniería; quién atiende WhatsApp y PQRS y en cuánto tiempo; reglas mínimas del catálogo; hoja maestra de sedes (Operaciones) con coordenadas, horarios y teléfonos corporativos | DP D-08, D-09, D-10; DL §9.1 |
| **Finanzas** | Medios de pago y estados de Wompi, y cómo evitar doble cobro; retención contable al eliminar cuentas (con Jurídico); activos totales (umbral de inscripción de bases); facturación electrónica (sistema, proveedor, plazos); presupuesto (D-15) con prueba de penetración. **Costos:** la documentación no los trae; solo cita 99 USD/año de Apple Developer, a reconfirmar (DG §0.2) | DL §8; PRI §11.2 |

---

## 8. Próximos pasos y qué desbloquea cada uno [PROPUESTA]

| Paso | Qué se hace | Qué desbloquea |
|---|---|---|
| 1 | Responder las decisiones del grupo A (§6) | Gate G1: permiso para empezar a implementar |
| 2 | Etapa 0: autorización de lectura/pruebas, resolver los datos desconocidos, ejecutar mediciones base (incluido `npm audit`), entregar documentos a Jurídico | Umbrales definitivos; 8 contradicciones técnicas; arranque de la revisión legal |
| 3 | Etapa 1: aprobar o rechazar ADR, **aplicar las 89 contradicciones**, propagar correcciones de seguridad, congelar el contrato de la API | Construir sobre una sola versión coherente |
| 4 | Etapa 2: entorno de pruebas, controles de calidad en el despliegue, sesiones por dispositivo, cambios de WordPress, Cloudflare, base de la app | Integrar cada módulo con su backend |
| 5 | Etapa 3: módulos M1 a M5, siempre con el servidor un paso por delante | MVP completo en pruebas |
| 6 | Etapas 4-5: integración Wompi extremo a extremo, pruebas, prueba de penetración independiente, cierre jurídico | Condición para el piloto |
| 7 | Etapa 6: piloto cerrado y tiendas | Publicación (decisión firmada por Gerencia y TI) |

En paralelo, desde IPR: revisión jurídica y datos/contenido. **Esfuerzo relativo** (sin horas): Etapa 0 pequeño, 1 mediano, 2 grande, 3 **muy grande**, 4 mediano, 5 grande, 6 mediano (RM §4.1). **Plazos, equipo y presupuesto: no hay dato.** Se obtienen con la decisión D-15 y los resultados del paso 2; con eso el plan se recalibra (RM SUP-EQ-01). El tiempo de revisión de las tiendas no es controlable ni está verificado (DG §0.3).

---

## 9. Qué NO se puede afirmar todavía

| Tema | No se puede decir | Por qué | Cómo se sabrá |
|---|---|---|---|
| Cumplimiento de la Ley 1581 | Que la app o IPR la cumplan | Política y términos no leídos; ningún dictamen jurídico; normas leídas en copias de 2020-2022 (PRI §13) | Respuestas J-01..J-13 y dictamen archivado |
| Seguridad | Que la app, la capa móvil o WordPress sean seguros | Cambios P0 abiertos (SC §3); sin pruebas ni pentest; `npm audit` no ejecutado | Pruebas ST, pentest con reprueba, criterios NL/NLS en verde |
| Rendimiento y capacidad | Velocidad de la app, o que la web resista la carga móvil | Cero mediciones (QM §4); capacidad del servidor desconocida | Prueba de carga y piloto (C4) |
| Pago | Que no habrá doble cobro ni pedidos perdidos | Comportamiento de Wompi desconocido | Pruebas con Wompi de prueba (100 interrupciones por plataforma) |
| Calidad del catálogo y precios | Que los datos mostrados sean correctos | Auditoría no hecha (MED-06) | Auditoría y reglas mínimas |
| Accesibilidad y compatibilidad | Que sea usable con lector de pantalla o en dispositivos antiguos | Nada probado; versiones mínimas por decidir | Pruebas con usuarios y matriz de dispositivos |
| Demanda y valor | Que haya suficiente compra móvil | No hay analítica móvil ni metas (VIS §8, V-1) | MED-01, MED-18 |
| Costo y plazos | Cualquier cifra | Equipo y presupuesto sin definir | D-15 |

**Limitaciones de esta documentación** (reconocidas en los propios documentos):

- **~89 contradicciones entre documentos sin resolver** (74 técnicas, 10 de producto, 5 legales; RI §4.1). El revisor no editó ningún documento (RI cabecera). Ejemplos de cifras distintas: H-12 habla de 8 datos desconocidos y el Anexo B lista 10; la sede de color verde tiene dos valores derivados en discusión (DS §3.2).
- **Correcciones de seguridad aplicadas en 4 documentos** (arquitectura, amenazas, controles y pruebas de seguridad; SC §5) **pero no propagadas** a los otros: la lista de 21 impactos no se ha aplicado (SR §9). Prueba: roadmap y registro de decisiones citan 72 controles, 62 amenazas y 22 cambios P0; el recuento actual da 77, 78 y 23.
- **43 diagramas con sintaxis validada, no revisados visualmente** (`03_architecture/mermaid_validation`).
- Reglas de las tiendas leídas mediante resúmenes: una persona debe releerlas antes de publicar (DG §0.2).
- Todos los documentos fuente están marcados **BORRADOR**.

---

## Glosario mínimo

| Término | Significado |
|---|---|
| **MVP** | Primera versión de la app, con lo mínimo para operar |
| **BFF / capa móvil `/mobile/v1`** | Intermediario del servidor entre la app y WooCommerce; evita poner claves en la app |
| **WooCommerce / WordPress** | Sistema que guarda catálogo, clientes y pedidos |
| **Wompi** | Pasarela de pagos usada hoy en el checkout |
| **Entorno de pruebas (*staging*)** | Copia del sistema para probar sin afectar la web real |
| **Cloudflare** | Servicio que protege y acelera el sitio |
| **ADR** | Registro de una decisión de arquitectura |
| **Gate G1** | Lista de aprobaciones exigidas para empezar a construir |
| **P0** | Cambio obligatorio antes de publicar |
| **Pentest** | Prueba de penetración: un tercero intenta vulnerar el sistema |
| **Ley 1581 / SIC / RNBD** | Ley de datos personales de Colombia / la superintendencia que la vigila / registro de bases de datos |
| **PQRS** | Peticiones, quejas, reclamos y sugerencias |
| **SKU** | Referencia interna del producto |

# Casos de prueba — App móvil IPR (MVP)

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Calidad. No se programa nada. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para validación de IPR y del responsable técnico |
| **Rol** | Ingeniería de QA Automation |
| **Fuentes** | [acceptance_criteria.md](../02_requirements/acceptance_criteria.md) · [non_functional_requirements.md](../02_requirements/non_functional_requirements.md) · [flutter_app_architecture.md](../03_architecture/flutter_app_architecture.md) · [api_architecture.md](../05_api/api_architecture.md) · [openapi.yaml](../05_api/openapi.yaml) |
| **Documentos hermanos** | [testing_strategy.md](testing_strategy.md) · [test_results.md](test_results.md) · [quality_metrics.md](quality_metrics.md) · pruebas de seguridad: `06_security/security_testing.md` (diseñado por otro agente; puede no existir aún) |

> **Aviso central.** **Ninguno de los casos de este documento se ha ejecutado.** Todos tienen RESULTADO OBTENIDO "NO EJECUTADO", evidencia "—" y estado "Pendiente". Ningún caso puede pasar a "Aprobado" sin evidencia adjunta, fecha, versión, entorno y dispositivo (ver [test_results.md](test_results.md)). Los casos dependen de un backend `/mobile/v1` y de un entorno *staging* que **hoy no existen o no están confirmados** (condiciones C1 a C4 de ADR-001).

---

## 1. Cómo leer este documento

### 1.1 Clasificación del contenido

| Tipo | Dónde está |
|---|---|
| **Hechos** (verificados en los documentos fuente) | El catálogo de 490 AC, las cifras de las secciones 4 y 5 (calculadas por script sobre `acceptance_criteria.md`), los valores de umbral citados de los RNF |
| **Supuestos** | Datos sintéticos de la sección 3 (productos `QA-*`, cuentas `CLI-*`): deben crearse en *staging* o simularse; existencia de *staging* y de Wompi sandbox (C2) |
| **Propuestas** | Prioridades P1 a P3, agrupación de AC en casos, regla de derivación de la sección 5, valores de referencia marcados como "propuesto" |
| **Decisiones pendientes** | Marcas **[A VALIDAR]** en cada caso, con la pregunta que lo bloquea (PA-xx, D-xx, DN-xx) |
| **Riesgos** | Casos con dependencia de SPK-01 (retorno del pago), del sandbox de Wompi y de la matriz de dispositivos (MED-01) |

### 1.2 Campos de cada caso

| Campo | Significado |
|---|---|
| **ID** | `TC-nnn`, correlativo. Los casos derivados por regla (sección 5) se nombrarán `TC-D-<AC>` |
| **AC / RF / RNF** | Criterios de aceptación que cubre y requisitos relacionados. Un caso puede cubrir varios AC cuando comparte el mismo procedimiento parametrizado |
| **AC de tipo Seguridad** | Se listan en el caso solo cuando existe una verificación funcional automatizable en CI (por ejemplo, regresión de contrato). **El diseño de las pruebas de seguridad (inspección de binario, proxy, abuso, MASVS, pentest) es de `06_security/security_testing.md` y no se duplica aquí** |
| **Capa** | Unitaria · Widget · Golden · Integración (app con BFF simulado) · Contrato (BFF contra OpenAPI) · E2E (staging con Wompi sandbox) · Manual · Rendimiento · Accesibilidad · Compatibilidad |
| **Automatizable** | Sí / No (con la condición entre paréntesis cuando aplica) |
| **Prioridad** | **P1** bloquea el release (flujo crítico o criterio NL-xx); **P2** debe ejecutarse en cada candidato a versión; **P3** se ejecuta por ciclo completo |
| **Marca [A VALIDAR]** | Se copia del AC con la misma etiqueta y pregunta. Un caso con esa marca **no puede darse por aprobado** hasta cerrar la pregunta; se prueba la parte determinista y se deja pendiente el umbral o el texto |
| **Resultado obtenido / Evidencia / Estado** | Siempre "NO EJECUTADO" / "—" / "Pendiente" en este documento |

---

## 2. Entornos

| Entorno | Uso | Estado |
|---|---|---|
| Local con BFF simulado | Unitarias, widget, golden e integración en CI | Propuesto (ADR-012) |
| *staging* (frontend + WooCommerce + Wompi sandbox) | Contrato, E2E, SKU, frescura, eliminación de cuenta | **Existencia DESCONOCIDA** (C2 de ADR-001; D-16 pendiente de autorización) |
| Producción | **Ninguna prueba de compra ni de escritura.** Solo, si se autoriza, el monitoreo sintético de solo lectura (RNF-102) | Fuera de este documento |

---

## 3. Datos de prueba sintéticos

Regla: **nunca** datos reales, de clientes ni de empleados; sin secretos en este documento. Las contraseñas de las cuentas de prueba se guardan en el gestor de secretos del equipo de QA y aquí solo se nombran (`QA_PWD_n`). Los correos usan el dominio reservado `example.test`. Las direcciones y teléfonos son ficticios.

| Código | Descripción | Observación |
|---|---|---|
| `CLI-01`, `CLI-02`, `CLI-03` | Clientes sintéticos con rol de cliente (`qa.cliente.01@example.test`, etc.). `CLI-01` con facturación y 3 pedidos; `CLI-02` sin facturación ni pedidos; `CLI-03` con 25 pedidos | Se crean en *staging*; credenciales en el gestor de secretos |
| `CLI-NEW` | Cuenta que se registra durante el caso (`qa.cliente.nuevo@example.test`) | Se elimina al terminar |
| `CLI-ADM` | Cuenta de prueba con rol administrativo creada ad hoc en *staging* | Nunca una cuenta real de IPR |
| `CLI-DEL`, `CLI-DEL-A`, `CLI-DEL-B` | Cuentas descartables para eliminación; la `A` con pedidos pagados y la `B` con un pedido pendiente | Se recrean antes de cada ciclo |
| `P-PRECIO` (SKU `QA-0001`) | Producto con precio y en stock (precio sintético, p. ej. 100.000 COP) | Fixture de *staging* o simulado |
| `P-SINPRECIO` (`QA-0002`) | Producto con precio 0 (sin precio) |  |
| `P-AGOTADO` (`QA-0003`) | Producto agotado |  |
| `P-BACKORDER` (`QA-0004`) | Producto disponible bajo pedido |  |
| `P-OFERTA` (`QA-0005`) | Producto en oferta (regular y especial sintéticos) |  |
| `P-CAMBIO` (`QA-0006`) | Producto cuyo precio se cambia durante el caso |  |
| `P-LARGO`, `P-SINIMG`, `P-HTML` | Nombre de 150 caracteres; sin imágenes; descripción con HTML legítimo (el corpus XSS es de seguridad) |  |
| `QA-CAT-MIXTA` | Categoría con 10 productos (3 sin precio), ampliable a 60 |  |
| `QA-MARCA-A`, `QA-MARCA-B` | Marcas sintéticas |  |
| `QA-SEDE-1` a `QA-SEDE-8` | Sedes ficticias con direcciones y teléfonos ficticios (una "próximamente", una sin WhatsApp, una sin teléfono de repuestos) |  |
| `C3` | Carrito de 3 líneas con cantidades 2, 1 y 5 |  |
| `DEV-A`, `DEV-B` | Dos dispositivos con `X-Device-Id` distintos |  |
| `WEB-01` | Navegador de escritorio para la sesión web |  |
| `RED-OFF`, `RED-4G-LENTA`, `RED-DEGRADADA`, `RED-INTERMITENTE` | Sin red; ≈1,6 Mbps con 150 ms RTT; ≈400 kbps con RTT ≥ 400 ms; cortes de 5 a 15 s (RNF-083) | Perfiles definidos por QA |
| `TARJ-APROBADA`, `TARJ-RECHAZADA` | Tarjetas de prueba publicadas en la documentación oficial de Wompi para su sandbox | **NO VERIFICADO** su vigencia; no se transcriben aquí. Verificar en la documentación de Wompi antes del ciclo |
| Escenario pendiente de Wompi | Método o condición del sandbox que deje el pedido en `on-hold`/`pending` | **NO VERIFICADO** que el sandbox lo permita (MED-14) |

---

## 4. Resumen de los casos

Cifras calculadas por script sobre este documento y sobre `acceptance_criteria.md` (490 AC).

| Indicador | Valor |
|---|---|
| Casos de prueba desarrollados | **160** |
| Casos con RESULTADO OBTENIDO "NO EJECUTADO" | **160 de 160** (el 100 %) |
| Casos con marca [A VALIDAR] (por AC o por requisito) | 68 |
| Casos automatizables (Sí) / no automatizables (No) | 151 / 9 |
| Casos sin AC directo (trazados solo a RNF o a la arquitectura) | 19 |

| Capa | Casos |
|---|---|
| Integración | 74 |
| E2E | 26 |
| Widget | 25 |
| Unitaria | 13 |
| Contrato | 7 |
| Manual | 6 |
| Rendimiento | 5 |
| Accesibilidad | 2 |
| Golden | 1 |
| Compatibilidad | 1 |

| Prioridad | Casos |
|---|---|
| P1 | 90 |
| P2 | 54 |
| P3 | 16 |

---

## 5. Regla de derivación AC → TC y cobertura

### 5.1 Regla de derivación para los AC sin caso desarrollado

Cada AC que aún no tiene caso desarrollado se deriva como `TC-D-<AC>` aplicando la regla según su tipo (columna "Tipo" de `acceptance_criteria.md`):

| Tipo del AC | Capa del caso derivado | Plantilla del caso |
|---|---|---|
| Unitaria | Unitaria (`flutter_test`) | Tabla de valores límite y equivalentes del AC; cobertura del módulo según RNF-089 |
| Widget | Widget con *overrides* de Riverpod (+ golden si el AC es visual) | Estado de la pantalla con repositorio falso; verificación de texto, presencia y accesibilidad |
| Integración | Integración (`integration_test` con BFF simulado) y, si el AC toca el contrato, Contrato contra el OpenAPI | Respuesta simulada conforme al esquema; verificación de solicitudes emitidas |
| E2E | E2E en *staging* con Wompi sandbox (Patrol, condicionado a SPK-01) | Procedimiento del AC con las cuentas y productos de la sección 3 |
| Manual | Manual con lista de verificación y evidencia fechada | Guion de revisión humana |
| Seguridad | **Delegado a `06_security/security_testing.md`**; QA solo integra la puerta en CI y, si el AC es verificable funcionalmente, añade una regresión automatizada | — |

Reglas adicionales: (1) los AC con **[A VALIDAR]** conservan la marca y la pregunta en el caso derivado; (2) los AC de tipo "se aplica AC-009-x" se derivan como variantes parametrizadas de los casos de resiliencia (grupo G); (3) un AC solo se considera cubierto cuando su caso existe en este documento; (4) la derivación se completa antes de la fase F3 para el 100 % de los AC no Seguridad del MVP.

### 5.2 Cobertura global

| Concepto | AC | Porcentaje |
|---|---|---|
| AC totales del MVP (490) | 490 | 100 % |
| AC con caso desarrollado en este documento (cualquier tipo) | 389 | 79.4 % |
| AC no Seguridad (395) con caso desarrollado | 369 de 395 | 93.4 % |
| AC no Seguridad **sin** caso desarrollado aún (se derivan por regla) | 26 | 6.6 % |
| AC de tipo Seguridad (95) con verificación funcional complementaria en CI | 20 de 95 | 21.1 % |
| AC de tipo Seguridad **delegados** íntegramente a `06_security/security_testing.md` (no cuentan como cubiertos aquí) | 75 | 78.9 % |
| AC con marca [A VALIDAR] (107) que tienen caso desarrollado | 82 de 107 | 76.6 % |

Por tipo de AC:

| Tipo | AC | Con caso | Sin caso |
|---|---|---|---|
| Unitaria | 34 | 34 | 0 |
| Widget | 109 | 103 | 6 |
| Integración | 198 | 183 | 15 |
| E2E | 34 | 34 | 0 |
| Manual | 20 | 15 | 5 |
| Seguridad | 95 | 20 | 75 |

> Los AC de tipo Seguridad con "caso" son regresiones funcionales automatizables (por ejemplo, 401 tras cerrar sesión, cuerpo de `/checkout`, 404 en pedido ajeno). **No sustituyen** la verificación de seguridad de `06_security/security_testing.md`, que sigue siendo obligatoria para esos AC.

### 5.3 Cobertura por historia

"Cubiertos" = AC con caso desarrollado. "Sin caso aún" = AC no Seguridad pendientes de derivar. "Seg. delegados" = AC de tipo Seguridad sin verificación funcional aquí.

| Historia | AC | Cubiertos | Sin caso aún (no Seguridad) | Seg. con regresión | Seg. delegados |
|---|---|---|---|---|---|
| US-001 | 3 | 3 | — | — | — |
| US-002 | 4 | 4 | — | — | — |
| US-003 | 5 | 5 | — | — | — |
| US-004 | 2 | 2 | — | — | — |
| US-005 | 4 | 4 | — | — | — |
| US-006 | 2 | 2 | — | — | — |
| US-007 | 2 | 2 | — | — | — |
| US-009 | 7 | 7 | — | — | — |
| US-010 | 6 | 6 | — | — | — |
| US-011 | 8 | 8 | — | — | — |
| US-012 | 5 | 5 | — | — | — |
| US-013 | 6 | 6 | — | — | — |
| US-014 | 4 | 4 | — | — | — |
| US-015 | 4 | 3 | 015-1 | — | — |
| US-016 | 5 | 5 | — | — | — |
| US-018 | 6 | 5 | 018-4 | — | — |
| US-019 | 6 | 6 | — | — | — |
| US-020 | 7 | 7 | — | 020-4 | — |
| US-021 | 5 | 5 | — | — | — |
| US-022 | 5 | 5 | — | — | — |
| US-023 | 6 | 6 | — | — | — |
| US-026 | 7 | 7 | — | — | — |
| US-027 | 6 | 3 | — | — | 027-1, 027-2, 027-4 |
| US-028 | 3 | 2 | — | — | 028-3 |
| US-029 | 8 | 8 | — | — | — |
| US-030 | 5 | 5 | — | — | — |
| US-031 | 5 | 5 | — | — | — |
| US-032 | 3 | 2 | 032-3 | — | — |
| US-037 | 4 | 3 | — | — | 037-4 |
| US-038 | 8 | 7 | — | — | 038-8 |
| US-039 | 7 | 5 | — | — | 039-4, 039-6 |
| US-040 | 9 | 7 | — | — | 040-6, 040-7 |
| US-041 | 8 | 6 | — | 041-2 | 041-3, 041-4 |
| US-042 | 8 | 5 | — | — | 042-3, 042-5, 042-7 |
| US-043 | 6 | 5 | — | — | 043-5 |
| US-044 | 11 | 5 | — | — | 044-1, 044-2, 044-4, 044-8, 044-9, 044-10 |
| US-045 | 8 | 3 | — | — | 045-1, 045-2, 045-3, 045-5, 045-8 |
| US-048 | 5 | 2 | — | 048-1, 048-2 | 048-3, 048-4, 048-5 |
| US-049 | 9 | 8 | — | — | 049-7 |
| US-050 | 10 | 10 | — | 050-8 | — |
| US-051 | 5 | 4 | — | — | 051-4 |
| US-052 | 16 | 11 | — | 052-5 | 052-2, 052-4, 052-12, 052-13, 052-14 |
| US-053 | 6 | 2 | — | — | 053-1, 053-2, 053-3, 053-6 |
| US-054 | 5 | 3 | — | — | 054-3, 054-5 |
| US-055 | 7 | 7 | — | 055-4, 055-5 | — |
| US-056 | 10 | 10 | — | 056-6, 056-10 | — |
| US-057 | 9 | 8 | — | — | 057-9 |
| US-058 | 9 | 7 | — | — | 058-5, 058-6 |
| US-062 | 6 | 6 | — | — | — |
| US-063 | 5 | 5 | — | — | — |
| US-064 | 4 | 1 | 064-2, 064-3, 064-4 | — | — |
| US-065 | 6 | 0 | 065-1, 065-3, 065-4, 065-5, 065-6 | — | 065-2 |
| US-072 | 6 | 6 | — | — | — |
| US-073 | 4 | 2 | 073-3, 073-4 | — | — |
| US-074 | 5 | 4 | 074-3 | — | — |
| US-075 | 5 | 4 | — | — | 075-4 |
| US-076 | 6 | 3 | 076-5, 076-6 | — | 076-2 |
| US-079 | 5 | 3 | 079-5 | — | 079-2 |
| US-080 | 4 | 3 | 080-2 | — | — |
| US-085 | 7 | 7 | — | — | — |
| US-086 | 5 | 5 | — | — | — |
| US-087 | 3 | 3 | — | — | — |
| US-088 | 4 | 3 | 088-2 | — | — |
| US-089 | 5 | 3 | 089-2, 089-3 | — | — |
| US-094 | 5 | 2 | 094-2, 094-3, 094-5 | — | — |
| US-095 | 4 | 2 | 095-3, 095-4 | — | — |
| US-096 | 12 | 9 | — | — | 096-6, 096-9, 096-12 |
| US-097 | 6 | 6 | — | — | — |
| US-099 | 7 | 6 | — | — | 099-7 |
| US-104 | 10 | 9 | — | 104-3, 104-4 | 104-7 |
| US-105 | 10 | 7 | — | 105-2, 105-5 | 105-3, 105-6, 105-7 |
| US-106 | 8 | 6 | — | — | 106-5, 106-6 |
| US-107 | 9 | 9 | — | 107-2 | — |
| US-108 | 6 | 6 | — | 108-3 | — |
| US-110 | 16 | 14 | — | 110-3, 110-12, 110-13 | 110-14, 110-15 |
| US-111 | 5 | 4 | — | — | 111-4 |
| SEC | 13 | 1 | — | SEC-8 | SEC-1, SEC-2, SEC-3, SEC-4, SEC-5, SEC-6, SEC-7, SEC-9, SEC-10, SEC-11, SEC-12, SEC-13 |

Los identificadores de las columnas "sin caso", "con regresión" y "delegados" se escriben sin el prefijo `AC-` (por ejemplo `009-3` = AC-009-3).

---

## 6. Casos de prueba

### Grupo A — Autenticación y sesiones por dispositivo (US-037 a US-048)

Cubre registro, consentimiento, login, cierre de sesión, recuperación, sesiones independientes, renovación de tokens y límite de intentos. Los AC de tipo Seguridad (inspección de almacenamiento, proxy, ataque simulado) los diseña `06_security/security_testing.md`; aquí solo aparecen cuando existe una verificación funcional automatizable complementaria.

#### TC-001 · Validaciones locales del registro

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Unitaria · Sí |
| AC que cubre | AC-038-2, AC-038-3 |
| RF / RNF | RF-038; RNF-053 |
| Objetivo | Verificar sin red las reglas de validación del formulario de registro. |
| Precondiciones | Ninguna (lógica pura de dominio, sin dispositivo). |
| Procedimiento | 1. Validar las contraseñas `Qa12345` (7 caracteres) y `Qa123456` (8 caracteres).<br>2. Validar los correos `a@`, `a@b`, `qa.sin.arroba.test` y `qa.cliente.nuevo@example.test`.<br>3. Validar cada campo obligatorio vacío (correo, nombre, apellido, contraseña) de a uno.<br>4. Con cada entrada inválida, comprobar que el repositorio simulado no recibe ninguna llamada. |
| Datos de prueba sintéticos | Cadenas del paso 1 a 3 (sintéticas); mock del repositorio de autenticación. |
| Resultado esperado | 7 caracteres rechazada con mensaje; 8 aceptada; los tres correos inválidos rechazados con error en el campo de correo; cada vacío marca su campo; 0 llamadas al repositorio en los casos inválidos. |
| Criterio de aprobación | Todas las combinaciones se comportan según lo esperado y `verifyNever` se cumple en los casos inválidos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-002 · Pantalla de registro: campos, enmascarado y consentimiento sin marcar

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Widget · Sí |
| AC que cubre | AC-038-1, AC-039-1, AC-039-2, AC-099-1 |
| RF / RNF | RF-038, RF-039, RF-099; RNF-056 |
| Objetivo | Verificar que el registro pide los datos correctos, enmascara la contraseña y no permite registrarse sin aceptar términos y política. |
| Precondiciones | Visitante sin sesión; repositorios simulados (overrides de Riverpod). |
| Procedimiento | 1. Abrir la pantalla de registro.<br>2. Comprobar la presencia de correo, nombre, apellido y contraseña; contraseña enmascarada y control de mostrar.<br>3. Comprobar que la casilla de aceptación está sin marcar y que existen enlaces a términos y a política de datos, accesibles sin sesión.<br>4. Completar todos los campos válidos sin marcar la casilla y pulsar "Registrarme". |
| Datos de prueba sintéticos | Datos del registro `CLI-NEW` (correo `qa.cliente.nuevo@example.test`, nombre y apellido sintéticos, contraseña `Qa123456`). |
| Resultado esperado | Campos y enlaces presentes; casilla desmarcada; con la casilla sin marcar no se emite la solicitud y se indica que debe aceptar para continuar. |
| Criterio de aprobación | Los 4 aspectos verificados y 0 solicitudes de red emitidas en el paso 4. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-003 · Registro: doble toque emite una sola solicitud

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | AC-038-6 |
| RF / RNF | RF-038; RNF-027 |
| Objetivo | Evitar cuentas o solicitudes duplicadas por doble toque. |
| Precondiciones | Formulario de registro válido y con aceptación marcada; repositorio simulado con respuesta demorada. |
| Procedimiento | 1. Pulsar "Registrarme" dos veces en menos de 300 ms.<br>2. Contar las solicitudes recibidas por el repositorio simulado.<br>3. Verificar el estado del botón hasta que llega la respuesta. |
| Datos de prueba sintéticos | `CLI-NEW`; respuesta simulada con retraso de 2 s. |
| Resultado esperado | Exactamente 1 solicitud; botón deshabilitado hasta la respuesta. |
| Criterio de aprobación | Contador = 1 y botón deshabilitado durante la espera. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-004 · Registro sin red conserva lo escrito

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-038-7 |
| RF / RNF | RF-038, RF-009; RNF-027 |
| Objetivo | Verificar mensaje de falta de conexión y conservación de campos. |
| Precondiciones | Dispositivo/emulador con perfil `RED-OFF`. |
| Procedimiento | 1. Completar el formulario válido y marcar la aceptación.<br>2. Activar `RED-OFF` y pulsar "Registrarme".<br>3. Observar el mensaje y el contenido de los campos. |
| Datos de prueba sintéticos | `CLI-NEW`. |
| Resultado esperado | Mensaje de falta de conexión en lenguaje no técnico; nombre, apellido y correo conservados; no se presenta como registrado. |
| Criterio de aprobación | Mensaje presente, campos conservados, 0 cuentas creadas en staging. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-005 · Registro válido contra staging y resultado posterior

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-038-4 |
| RF / RNF | RF-038, RF-039; RNF-053 |
| Objetivo | Verificar que un registro válido crea la cuenta y que la app muestra el resultado definido. |
| Precondiciones | Staging con `ipr/v1/m` desplegado; cuenta `CLI-NEW` inexistente. |
| Procedimiento | 1. Registrar `CLI-NEW` con aceptación marcada.<br>2. Verificar en WordPress (staging) que la cuenta existe con rol de cliente.<br>3. Observar la pantalla posterior al registro. |
| Datos de prueba sintéticos | `CLI-NEW`. |
| Resultado esperado | Cuenta creada con rol de cliente; la app muestra el resultado. El comportamiento posterior (sesión iniciada o pedir login) queda pendiente de definición. |
| Criterio de aprobación | Cuenta existente y rol de cliente; la parte del comportamiento posterior se aprueba solo cuando se cierre la definición. |
| **[A VALIDAR]** | AC-038-4: **[A VALIDAR — propuesta de PA nueva]** si tras registrarse se inicia sesión automáticamente o se pide iniciar sesión.<br>Pregunta que bloquea: Si tras registrarse se inicia sesión automáticamente o se pide iniciar sesión (propuesta de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-006 · Registro de la aceptación de términos con fecha, versión y canal

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-039-3 |
| RF / RNF | RF-039; RNF-056 |
| Objetivo | Comprobar que el servidor guarda la aceptación de forma consultable por IPR. |
| Precondiciones | Staging; tabla de consentimientos de `ipr/v1/m` (authentication.md §8.4) desplegada. |
| Procedimiento | 1. Registrar `CLI-NEW` aceptando los documentos.<br>2. Consultar el registro de consentimiento de esa cuenta en staging (consulta a la base o herramienta administrativa).<br>3. Verificar fecha-hora, versión del documento y canal. |
| Datos de prueba sintéticos | `CLI-NEW`. |
| Resultado esperado | Existe 1 registro con fecha-hora, versión del documento aceptada y canal; sin datos personales adicionales innecesarios. |
| Criterio de aprobación | Registro presente y legible por IPR. La versión que rige y los campos exactos quedan pendientes de Jurídico. |
| **[A VALIDAR]** | AC-039-3: **[A VALIDAR — D-12, PA-10]** qué versión rige y qué datos exactos se registran (la web podría no registrar nada hoy).<br>Pregunta que bloquea: Los campos exactos y la versión vigente dependen de D-12 y PA-10 (la web podría no registrar nada hoy). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-007 · Registro con correo ya registrado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-038-5 |
| RF / RNF | RF-038, RF-045 |
| Objetivo | Verificar el mensaje cuando el correo ya existe y contrastarlo con RF-045. |
| Precondiciones | Staging; cuenta `CLI-01` existente. |
| Procedimiento | 1. Intentar registrar un usuario nuevo con el correo de `CLI-01`.<br>2. Registrar código HTTP y mensaje mostrados.<br>3. Comparar con el mensaje de un registro exitoso y de login fallido. |
| Datos de prueba sintéticos | Correo de `CLI-01`. |
| Resultado esperado | Resultado según la decisión de PA-02. Observación: el AC pide no revelar existencia; api_architecture §6.3 define `409 email_in_use` y RA-11 acepta el riesgo; los dos textos están en conflicto hasta que se decida. |
| Criterio de aprobación | No se aprueba hasta cerrar la decisión; se registra el comportamiento observado. |
| **[A VALIDAR]** | AC-038-5: **[A VALIDAR — PA-02]** tensión entre RF-045 (no revelar existencia) y la usabilidad cuando no hay verificación de correo (RF-046 está en fase 2); definir el mensaje. |
| Nota | Conflicto documental AC-038-5 frente a api_architecture §6.3 / RA-11: debe resolverlo Producto + seguridad. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-008 · Documentos legales que no cargan durante el registro

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-039-5, AC-099-5 |
| RF / RNF | RF-039, RF-099 |
| Objetivo | Verificar que, si los documentos no cargan, hay error con reintento y no se acepta lo no visto. |
| Precondiciones | Registro abierto; `RED-OFF` al abrir el enlace legal. |
| Procedimiento | 1. Pulsar el enlace de términos con `RED-OFF`.<br>2. Observar el error y pulsar "Reintentar" tras restablecer la red.<br>3. Intentar marcar la casilla sin haber podido abrir el documento. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Error con botón "Reintentar"; al reintentar con red el documento carga. Si se permite o no aceptar sin haber abierto el documento queda pendiente. |
| Criterio de aprobación | Error y reintento verificados; la regla de aceptación sin lectura se aprueba tras la decisión. |
| **[A VALIDAR]** | AC-039-5: **[A VALIDAR — D-12]** si se permite aceptar sin haberlos abierto.<br>Pregunta que bloquea: Si se permite aceptar documentos que no se pudieron abrir depende de D-12. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-009 · Formulario de login: validación, doble toque y mostrar contraseña

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Widget · Sí |
| AC que cubre | AC-040-3, AC-040-4, AC-040-8 |
| RF / RNF | RF-040; RNF-073 |
| Objetivo | Verificar validaciones locales, una sola solicitud y comportamiento del control de mostrar contraseña. |
| Precondiciones | Pantalla de login; repositorio simulado con retraso. |
| Procedimiento | 1. Pulsar "Iniciar sesión" con usuario vacío, luego con contraseña vacía.<br>2. Con datos válidos, pulsar dos veces rápido y contar solicitudes.<br>3. Activar "mostrar", verificar texto visible, desactivar, verificar oculto; enviar la app a segundo plano con la contraseña visible y volver. |
| Datos de prueba sintéticos | `CLI-01` (usuario y `QA_PWD_1` desde el gestor de secretos de QA). |
| Resultado esperado | Errores por campo sin solicitud; 1 sola solicitud en doble toque; contraseña visible solo mientras está activado y enmascarada al volver de segundo plano. |
| Criterio de aprobación | Las tres verificaciones pasan. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-010 · Login con correo y con usuario (E2E)

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-040-1, AC-037-3 |
| RF / RNF | RF-040, RF-037 |
| Objetivo | Verificar el acceso a la cuenta con ambos identificadores y la vuelta a la pantalla de origen. |
| Precondiciones | Staging; cuenta `CLI-01`; carrito `C3` guardado; app en modo visitante. |
| Procedimiento | 1. Desde el carrito pulsar "Pagar" (visitante) y seleccionar iniciar sesión.<br>2. Iniciar sesión con el correo de `CLI-01`.<br>3. Cerrar sesión y repetir con el nombre de usuario de `CLI-01`.<br>4. Verificar la pantalla de destino tras cada login y el contenido del carrito. |
| Datos de prueba sintéticos | `CLI-01`; `C3` (3 líneas, cantidades 2, 1, 5). |
| Resultado esperado | Acceso exitoso en ambos casos; la app vuelve a la pantalla desde donde se inició el flujo; el carrito conserva 3 líneas y cantidades. |
| Criterio de aprobación | Dos logins exitosos y carrito idéntico. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-011 · Mismo resultado ante usuario inexistente y contraseña incorrecta

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-040-2 |
| RF / RNF | RF-040, RF-045; RNF-053 |
| Objetivo | Comprobar que no se puede distinguir si la cuenta existe. |
| Precondiciones | Staging; `CLI-01` existente; usuario `qa.inexistente@example.test` inexistente. |
| Procedimiento | 1. Enviar login con usuario inexistente y contraseña cualquiera.<br>2. Enviar login con `CLI-01` y contraseña incorrecta.<br>3. Comparar código HTTP, `code` y mensaje mostrado. |
| Datos de prueba sintéticos | Credenciales sintéticas incorrectas. |
| Resultado esperado | Código de respuesta y mensaje idénticos en ambos casos (`401 invalid_credentials` según el contrato propuesto). |
| Criterio de aprobación | Igualdad exacta del código y del texto en pantalla. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-012 · Login sin red conserva el usuario escrito

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-040-5 |
| RF / RNF | RF-040, RF-009 |
| Objetivo | Verificar mensaje de falta de conexión y campos. |
| Precondiciones | `RED-OFF`. |
| Procedimiento | 1. Escribir usuario y contraseña; activar `RED-OFF`; pulsar "Iniciar sesión". |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | Mensaje de falta de conexión; usuario conservado (la contraseña puede limpiarse). |
| Criterio de aprobación | Mensaje presente y usuario conservado. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-013 · Cuenta con rol administrativo no inicia sesión en la app

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-040-9 |
| AC de tipo Seguridad (regresión funcional complementaria; diseño en `06_security/security_testing.md`) | AC-048-1, AC-048-2 |
| RF / RNF | RF-040, RF-048 |
| Objetivo | Verificar el bloqueo funcional del rol administrativo y que el cliente normal sí accede. |
| Precondiciones | Staging; `CLI-ADM` (rol administrativo de prueba creada ad hoc, no una cuenta real de IPR); `CLI-01` como control. |
| Procedimiento | 1. Iniciar sesión con `CLI-ADM`.<br>2. Observar mensaje y comprobar que no se almacenan tokens.<br>3. Iniciar sesión con `CLI-01`. |
| Datos de prueba sintéticos | `CLI-ADM`, `CLI-01`. |
| Resultado esperado | `CLI-ADM`: mensaje genérico de credenciales no válidas, sin tokens; `CLI-01`: sesión emitida con normalidad. |
| Criterio de aprobación | Ambos resultados observados. La lista de roles considerados administrativos queda pendiente de PA-03; el diseño de abuso (manipular la solicitud, AC-048-3/5) está en seguridad. |
| **[A VALIDAR]** | AC-048-1: **[A VALIDAR — PA-03]** decisión de IPR y lista exacta de roles considerados administrativos.<br>Pregunta que bloquea: La decisión de IPR y la lista exacta de roles dependen de PA-03. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-014 · Cierre de sesión revoca en servidor y es de una sola solicitud

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-041-1, AC-041-8 |
| AC de tipo Seguridad (regresión funcional complementaria; diseño en `06_security/security_testing.md`) | AC-041-2 |
| RF / RNF | RF-041; RNF-040 |
| Objetivo | Verificar que el cierre de sesión emite una sola revocación y que los tokens quedan inválidos. |
| Precondiciones | Staging; sesión activa de `CLI-01` en `DEV-A`; proxy de pruebas de la suite (interceptor HTTP) que cuenta solicitudes. |
| Procedimiento | 1. Guardar de forma controlada el token de acceso y el de refresco (solo en el entorno de la prueba, no se registran).<br>2. Pulsar "Cerrar sesión" dos veces seguidas.<br>3. Contar las solicitudes de revocación.<br>4. Reutilizar los dos tokens guardados contra una ruta autenticada y contra `/auth/refresh`. |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | 1 sola solicitud de revocación con el token de ese dispositivo; ambos tokens reutilizados responden 401. |
| Criterio de aprobación | Contador = 1 y dos respuestas 401. (La inspección de Keystore/Keychain, AC-041-3/4, la ejecuta seguridad.) |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-015 · Cierre de sesión sin red

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-041-6 |
| RF / RNF | RF-041 |
| Objetivo | Observar el comportamiento sin red y que el usuario no quede con sesión abierta sin saberlo. |
| Precondiciones | Sesión activa; `RED-OFF`. |
| Procedimiento | 1. Pulsar "Cerrar sesión" con `RED-OFF`.<br>2. Observar el estado de la app y los datos de sesión locales.<br>3. Restablecer la red y comprobar si se reintenta la revocación. |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | Mínimo: el usuario no queda con la sesión abierta en pantalla sin saberlo. Cierre local con reintento de revocación u otro comportamiento queda pendiente. |
| Criterio de aprobación | Se registra el comportamiento observado; se aprueba solo con la definición cerrada. |
| **[A VALIDAR]** | AC-041-6: **[A VALIDAR — ADR-001 §2]** comportamiento sin red no definido; el criterio mínimo es que el usuario no quede con la sesión abierta en pantalla sin saberlo.<br>Pregunta que bloquea: El comportamiento sin red no está definido (ADR-001 §2). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-016 · Qué pasa con el carrito local al cerrar sesión explícitamente

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-041-7 |
| RF / RNF | RF-041, RF-049 |
| Objetivo | Verificar que tras cerrar sesión la app queda en modo visitante y documentar el destino del carrito. |
| Precondiciones | Sesión activa con carrito `C3`. |
| Procedimiento | 1. Cerrar sesión (con red).<br>2. Abrir el inicio y el carrito. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | App en modo visitante; el destino del carrito (conservar o vaciar) sigue la decisión pendiente. La arquitectura propone conservarlo (flutter_app_architecture §8). |
| Criterio de aprobación | Modo visitante verificado; comportamiento del carrito a aprobar tras la decisión. |
| **[A VALIDAR]** | AC-041-7: **[A VALIDAR — propuesta de PA nueva]** si el carrito local se conserva o se vacía al cerrar sesión explícitamente (RF-044 solo garantiza conservarlo al expirar).<br>Pregunta que bloquea: Si el carrito se conserva o se vacía al cerrar sesión explícitamente no está definido en RF-044. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-017 · Cerrar sesión en un dispositivo no afecta al otro

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (dos dispositivos) |
| AC que cubre | AC-041-5, AC-043-3 |
| RF / RNF | RF-041, RF-043; RNF-039, RNF-040 |
| Objetivo | Verificar sesiones independientes entre dos dispositivos móviles. |
| Precondiciones | Staging; `CLI-01` con sesión iniciada en `DEV-A` y `DEV-B` (identificadores de dispositivo distintos). |
| Procedimiento | 1. En `DEV-B` cerrar sesión.<br>2. En `DEV-A` abrir Mis pedidos (solicitud autenticada).<br>3. En `DEV-B` iniciar sesión de nuevo.<br>4. En `DEV-A` repetir la solicitud autenticada. |
| Datos de prueba sintéticos | `CLI-01`, `DEV-A`, `DEV-B`. |
| Resultado esperado | `DEV-A` permanece autenticado (200) tras cada acción en `DEV-B`. |
| Criterio de aprobación | Dos respuestas 200 en `DEV-A`. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-018 · Sesión web y sesión de la app coexisten

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (parte web con Playwright o manual) |
| AC que cubre | AC-043-1, AC-043-2 |
| RF / RNF | RF-043; RNF-039 |
| Objetivo | Verificar que iniciar sesión en la web no cierra la app y viceversa (hallazgo H-01). |
| Precondiciones | Staging con sesiones por dispositivo desplegadas; `CLI-01` en `DEV-A` y en `WEB-01`. |
| Procedimiento | 1. Con sesión activa en `DEV-A`, iniciar sesión en la web en `WEB-01`.<br>2. En `DEV-A` ejecutar una solicitud autenticada.<br>3. Cerrar la web; iniciar sesión en la app en `DEV-B`.<br>4. Comprobar que la sesión web sigue válida (recargar Mi cuenta). |
| Datos de prueba sintéticos | `CLI-01`, `DEV-A`, `DEV-B`, `WEB-01`. |
| Resultado esperado | La app A responde 200 tras el login web; la sesión web sigue válida tras el login en la app. Es criterio de no-lanzamiento NL-05. |
| Criterio de aprobación | Ninguna sesión se cierra en ningún sentido. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-019 · Sesión revocada desde el servidor: reautenticación sin perder el carrito

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-043-4, AC-052-10 |
| RF / RNF | RF-043, RF-044, RF-052 |
| Objetivo | Verificar el tratamiento de 401 por revocación: sesión expirada, login y carrito conservado, sin bucles. |
| Precondiciones | Sesión activa con carrito `C3`; revocación de la sesión en staging (herramienta administrativa o revocación desde la web). |
| Procedimiento | 1. Revocar la sesión de `DEV-A` en el servidor.<br>2. Pulsar "Pagar" (o abrir Mis pedidos).<br>3. Contar las solicitudes enviadas tras el 401.<br>4. Iniciar sesión de nuevo y volver al carrito. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | 401; no se genera ticket; la app muestra sesión expirada y pide iniciar sesión; no hay bucle de reintentos (máximo 1 intento de refresh); el carrito conserva las 3 líneas y cantidades. |
| Criterio de aprobación | Una única secuencia de refresh fallido, pantalla de login y carrito idéntico. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-020 · Renovación transparente con access vencido

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-044-3 |
| RF / RNF | RF-044; RNF-028, RNF-039 |
| Objetivo | Verificar que la app renueva el access sin interacción y reintenta la solicitud original una sola vez. |
| Precondiciones | BFF simulado (o staging) con access de vida corta; refresh válido. |
| Procedimiento | 1. Forzar la expiración del access.<br>2. Ejecutar una solicitud autenticada.<br>3. Registrar la secuencia: solicitud original, 401, `POST /auth/refresh`, reintento. |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | Una renovación y un reintento exitoso; el usuario no ve pantallas intermedias. |
| Criterio de aprobación | Secuencia exacta registrada. Las vigencias numéricas (15 min de access, vida del refresh) quedan pendientes. |
| **[A VALIDAR]** | AC-044-3: **[A VALIDAR — ADR-001 §2]** vigencias (el informe propone 15 min para el acceso; la del refresco es DESCONOCIDA).<br>Pregunta que bloquea: Vigencias de access y de refresh no confirmadas (ADR-001 §2, DN-04). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-021 · Cinco solicitudes simultáneas producen un solo refresh

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Unitaria · Sí |
| AC que cubre | AC-044-6 |
| RF / RNF | RF-044; RNF-028 |
| Objetivo | Evitar consumir dos veces el refresh rotativo. |
| Precondiciones | Interceptor de autenticación con adaptador HTTP simulado de Dio. |
| Procedimiento | 1. Lanzar 5 solicitudes autenticadas en paralelo con el access vencido.<br>2. Responder 401 a las 5 y 200 al refresh (un solo token nuevo).<br>3. Verificar el número de llamadas a `/auth/refresh` y que las 5 se reintentan con el token nuevo. |
| Datos de prueba sintéticos | Tokens ficticios generados por la prueba. |
| Resultado esperado | 1 llamada a refresh; 5 reintentos con el token nuevo; 5 respuestas exitosas. |
| Criterio de aprobación | Contador de refresh = 1 y 5 reintentos correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-022 · Refresh expirado o revocado: login con mensaje y carrito intacto

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-044-5 |
| RF / RNF | RF-044; RNF-028 |
| Objetivo | Verificar que un refresh inválido lleva al login sin perder el carrito. |
| Precondiciones | BFF simulado que responde 401 al refresh; carrito `C3`. |
| Procedimiento | 1. Ejecutar una solicitud autenticada con access vencido.<br>2. Responder 401 al refresh.<br>3. Observar la pantalla y el carrito. |
| Datos de prueba sintéticos | `C3`. |
| Resultado esperado | Pantalla de login con mensaje de sesión expirada; carrito con las mismas líneas y cantidades. |
| Criterio de aprobación | Pantalla correcta y carrito idéntico. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-023 · Falla de red al renovar no cierra la sesión

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-044-7 |
| RF / RNF | RF-044; RNF-028 |
| Objetivo | Verificar que sin red no se borran los tokens ni se cierra la sesión. |
| Precondiciones | Sesión activa; access vencido. |
| Procedimiento | 1. Activar `RED-OFF`.<br>2. Ejecutar una acción autenticada (abrir Mis pedidos).<br>3. Restablecer la red y repetir. |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | Mensaje de falta de conexión; tokens y sesión conservados; con red la acción funciona sin pedir login. |
| Criterio de aprobación | Sesión intacta tras el ciclo sin red. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-024 · Efecto de cambiar contraseña o correo, o restablecer, sobre las demás sesiones

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · E2E · Sí |
| AC que cubre | AC-043-6, AC-042-6, AC-104-10, AC-105-10 |
| RF / RNF | RF-043, RF-104, RF-105, RF-042 |
| Objetivo | Documentar y verificar la política de sesiones tras cambios de credenciales. |
| Precondiciones | `CLI-01` con sesión en `DEV-A` y `DEV-B` y en `WEB-01`. |
| Procedimiento | 1. Cambiar la contraseña desde `DEV-A`.<br>2. Comprobar el estado de `DEV-B` y `WEB-01`.<br>3. Repetir con cambio de correo y con restablecimiento por correo. |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | Propuesta de arquitectura (authentication.md §15): la sesión actual sigue y las demás reciben 401; restablecimiento revoca todas. Debe confirmarse como política. |
| Criterio de aprobación | Se registra el comportamiento observado; se aprueba al cerrar la política. |
| **[A VALIDAR]** | AC-043-6: **[A VALIDAR — propuesta de PA nueva]** (RF-104 exige que cambiar el correo invalide el token anterior; falta definir el efecto sobre las demás sesiones).<br>AC-042-6: **[A VALIDAR — propuesta de PA nueva]** (hoy el token solo cambia al cambiar correo o contraseña, COD H-02).<br>AC-104-10: **[A VALIDAR — propuesta de PA nueva]** (ver AC-043-6).<br>AC-105-10: **[A VALIDAR — propuesta de PA nueva]** (ver AC-043-6).<br>Pregunta que bloquea: La política sobre las demás sesiones no está definida en los requisitos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-025 · Recuperación de contraseña: acceso visible y sin red

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | AC-042-1, AC-042-8 |
| RF / RNF | RF-042 |
| Objetivo | Verificar el acceso desde login y el mensaje sin red. |
| Precondiciones | Pantalla de login; repositorio simulado. |
| Procedimiento | 1. Verificar que "¿Olvidaste tu contraseña?" es visible en login.<br>2. Con `RED-OFF`, solicitar recuperación y observar el mensaje. |
| Datos de prueba sintéticos | Correo `qa.cliente.01@example.test`. |
| Resultado esperado | Acceso visible; mensaje de falta de conexión sin avanzar. |
| Criterio de aprobación | Ambos puntos verificados. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-026 · Recuperación: respuesta idéntica para correo registrado y no registrado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-042-4 |
| RF / RNF | RF-042, RF-045 |
| Objetivo | Verificar que no se revela si la cuenta existe. |
| Precondiciones | Staging; `CLI-01` registrado; correo no registrado `qa.nadie@example.test`. |
| Procedimiento | 1. Solicitar recuperación con cada correo.<br>2. Comparar código, cuerpo y pantalla resultante. |
| Datos de prueba sintéticos | Dos correos sintéticos. |
| Resultado esperado | Código (202 según contrato propuesto), mensaje y pantalla idénticos. |
| Criterio de aprobación | Igualdad exacta en los tres aspectos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-027 · Recuperación completa y login con la nueva contraseña

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · No (depende de correo y navegador del sistema; se ejecuta con guion manual) |
| AC que cubre | AC-042-2 |
| RF / RNF | RF-042 |
| Objetivo | Verificar el ciclo de recuperación punta a punta. |
| Precondiciones | Staging; buzón de prueba controlado por QA asociado a `CLI-01`. |
| Procedimiento | 1. Solicitar recuperación desde la app.<br>2. Abrir el enlace del correo (navegador seguro del sistema).<br>3. Establecer una nueva contraseña.<br>4. Iniciar sesión en la app con la nueva contraseña. |
| Datos de prueba sintéticos | `CLI-01` y `QA_PWD_1` nueva. |
| Resultado esperado | Login exitoso con la nueva contraseña; el flujo se abre en el navegador seguro del sistema. |
| Criterio de aprobación | Login exitoso; evidencia con capturas del flujo. |
| **[A VALIDAR]** | AC-042-2: **[A VALIDAR — ADR-001 §2]** el mecanismo (API propia o navegador seguro hacia la página `lost-password` de WordPress) lo define arquitectura; si es navegador, aplica AC-042-3.<br>Pregunta que bloquea: El mecanismo (API propia o navegador seguro hacia `lost-password`) lo define arquitectura (ADR-001 §2); ADR-021 propone solicitud por API con restablecimiento en WordPress. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-028 · Acceso sin iniciar sesión a catálogo, búsqueda, sedes y contacto

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí |
| AC que cubre | AC-037-1, AC-001-3 |
| RF / RNF | RF-037, RF-001 |
| Objetivo | Verificar que una instalación nueva no pide login para las funciones públicas. |
| Precondiciones | Instalación nueva (datos de la app borrados), sin sesión. |
| Procedimiento | 1. Abrir la app.<br>2. Abrir catálogo, buscador, una ficha, sedes y el botón de WhatsApp.<br>3. Verificar que en ningún paso aparece login. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Llegada directa al inicio; las cinco funciones operan sin pedir inicio de sesión. |
| Criterio de aprobación | 0 pantallas de login en el recorrido. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-029 · Acciones que exigen sesión piden login y conservan el carrito

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-037-3 |
| RF / RNF | RF-037, RF-052 |
| Objetivo | Verificar el bloqueo de pagar, perfil, pedidos y eliminar cuenta para visitantes. |
| Precondiciones | Visitante con carrito `C3`. |
| Procedimiento | 1. Intentar abrir Perfil, Mis pedidos y Eliminar cuenta.<br>2. Pulsar "Pagar". |
| Datos de prueba sintéticos | `C3`. |
| Resultado esperado | En cada caso se pide iniciar sesión o registrarse; el carrito conserva sus 3 líneas. |
| Criterio de aprobación | 4 de 4 acciones piden sesión y el carrito queda igual. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-030 · Mensaje de bloqueo por intentos: espera sin revelar la cuenta

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | AC-045-7 |
| RF / RNF | RF-045; RNF-042 |
| Objetivo | Verificar que el mensaje informa cuánto esperar y no indica si la cuenta existe. |
| Precondiciones | Respuesta simulada `429` con `Retry-After: 60` y `code: rate_limited`. |
| Procedimiento | 1. Simular la respuesta 429 en login.<br>2. Observar texto, botón y temporizador. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Mensaje de espera con el tiempo; botón deshabilitado durante ese tiempo; texto sin referencia a la existencia de la cuenta. |
| Criterio de aprobación | Botón deshabilitado hasta transcurrir el tiempo simulado. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-031 · Contador de intentos compartido entre procesos y persistente a reinicios

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-045-4 |
| RF / RNF | RF-045; RNF-017, RNF-042 |
| Objetivo | Verificar que el límite no depende de la memoria de un solo proceso (hallazgo H-04). |
| Precondiciones | Staging con 2 instancias del BFF (o reinicio controlado) y límite de autenticación en WordPress. |
| Procedimiento | 1. Realizar intentos fallidos alternando entre las dos instancias hasta superar el umbral de referencia propuesto.<br>2. Verificar el 429 con `Retry-After`.<br>3. Reiniciar un proceso y repetir un intento. |
| Datos de prueba sintéticos | Cuenta `CLI-01` con contraseña errónea; umbral de referencia: 5 fallos en 15 min (api_architecture §10.2, propuesto). |
| Resultado esperado | El bloqueo se activa con el total de intentos de ambas instancias; tras el reinicio el contador no se reinicia. Es parte de NL-05. |
| Criterio de aprobación | 429 a partir del intento n+1 con contadores compartidos. |
| Nota | Umbral, ventana y alcance (cuenta/IP) pendientes de R-02 y MED-10; el AC de umbral (AC-045-1) es de seguridad. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-032 · El tráfico legítimo de la app no recibe desafío del WAF de Cloudflare

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí |
| AC que cubre | AC-045-6 |
| RF / RNF | RF-045; RNF-032 |
| Objetivo | Verificar que login, registro y checkout desde la app no son desafiados ni bloqueados. |
| Precondiciones | Staging detrás de Cloudflare; al menos 2 redes distintas (Wi-Fi y datos móviles). |
| Procedimiento | 1. Ejecutar login, registro y solicitud de checkout desde dispositivos de la matriz en 2 redes.<br>2. Contar respuestas 403 o con HTML de Cloudflare. |
| Datos de prueba sintéticos | `CLI-01`, `CLI-NEW`; MED-15. |
| Resultado esperado | 0 desafíos o bloqueos en la muestra; el umbral global de RNF-032 (≤ 0,1 %) se mide en el piloto. |
| Criterio de aprobación | 0 respuestas del WAF en la muestra de staging. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-033 · Rutas públicas de `/mobile/v1` responden sin cabecera `Authorization`

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Contrato · Sí |
| AC que cubre | AC-037-2, AC-010-4 |
| RF / RNF | RF-037; RNF-043 |
| Objetivo | Verificar que catálogo, búsqueda, ficha, sedes y contacto no exigen sesión. |
| Precondiciones | BFF de staging o simulado conforme al OpenAPI. |
| Procedimiento | 1. Llamar sin `Authorization` a `/config`, `/categories`, `/products`, `/products/{slug}`, `/search`, `/search/suggestions`, `/brands`, `/liquidaciones`, `/stores` y `/filters`.<br>2. Validar código 200 y esquema de cada respuesta. |
| Datos de prueba sintéticos | Parámetros sintéticos (`QA-CAT-MIXTA`, `QA-0001`). |
| Resultado esperado | Todas responden 200 con el esquema del OpenAPI y sin depender de cookies ni cabeceras de la app. |
| Criterio de aprobación | 10 de 10 rutas en verde. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-034 · Sesión expirada al intentar pagar: reautenticar y continuar

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-044-11 |
| RF / RNF | RF-044, RF-052; RNF-028 |
| Objetivo | Verificar que, con el refresh expirado, el usuario vuelve al carrito con las mismas líneas y puede continuar con el pago. |
| Precondiciones | Staging; `CLI-01`; carrito `C3`; refresh expirado o revocado a propósito. |
| Procedimiento | 1. Pulsar "Pagar" con la sesión expirada.<br>2. Autenticarse en la pantalla de login.<br>3. Observar el regreso y el contenido del carrito.<br>4. Continuar hasta abrir el navegador seguro. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | Regreso al carrito con las mismas líneas y cantidades; el pago continúa sin repetir pasos. |
| Criterio de aprobación | Carrito idéntico y checkout abierto. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-035 · Cambio de versión de los términos y versión legal vigente

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Manual · No |
| AC que cubre | AC-039-7, AC-099-4 |
| RF / RNF | RF-039, RF-099 |
| Objetivo | Verificar con Jurídico el comportamiento ante cambio de versión de términos y que el documento mostrado coincide con el vigente. |
| Precondiciones | Versiones vigente y nueva de los documentos entregadas por Jurídico de IPR. |
| Procedimiento | 1. Comparar el documento mostrado en la app con el publicado por IPR.<br>2. Simular la publicación de una versión nueva y abrir la app con un usuario ya registrado.<br>3. Documentar el comportamiento observado. |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | Coincidencia con el texto vigente; comportamiento ante nueva versión según lo definido por Jurídico. |
| Criterio de aprobación | Lista de verificación firmada por Jurídico y evidencia con fecha. |
| **[A VALIDAR]** | AC-039-7: **[A VALIDAR — D-12]** .<br>AC-099-4: **[A VALIDAR — D-12]** versión vigente y fuente (los PDF legales no han sido leídos).<br>Pregunta que bloquea: Versión vigente, fuente y política de nueva aceptación (D-12; los PDF legales no han sido leídos). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo B — Carrito local y revalidación (US-029, US-049 a US-051)

El carrito es local; precio y disponibilidad los entrega siempre el servidor (RF-050).

#### TC-036 · Añadir al carrito como visitante y como cliente

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-029-4, AC-029-7, AC-049-1, AC-049-8 |
| RF / RNF | RF-029, RF-049; RNF-031 |
| Objetivo | Verificar que añadir funciona sin sesión, sin pedir login y sin depender de la red del BFF. |
| Precondiciones | Visitante; ficha de `P-PRECIO` cargada; luego repetir con `CLI-01`. |
| Procedimiento | 1. Elegir cantidad 3 y pulsar "Añadir al carrito".<br>2. Observar confirmación y contador.<br>3. Abrir el carrito: línea con nombre, cantidad y controles de cantidad y quitar.<br>4. Activar `RED-OFF` y añadir otro producto ya en caché. |
| Datos de prueba sintéticos | `P-PRECIO` (SKU `QA-0001`), `P-OFERTA` (SKU `QA-0005`). |
| Resultado esperado | El carrito contiene la línea con cantidad 3; confirmación visible; contador actualizado; ninguna pantalla de login; la operación funciona sin red. |
| Criterio de aprobación | Línea y contador correctos en visitante y en cliente. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-037 · Límites de cantidad 1 a 99 en selector y en carrito

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Unitaria · Sí |
| AC que cubre | AC-029-2, AC-029-3, AC-049-2 |
| RF / RNF | RF-029, RF-049; RNF-031, RNF-044 |
| Objetivo | Verificar los límites y la validación de valores escritos a mano. |
| Precondiciones | Lógica de dominio del carrito y del selector de cantidad. |
| Procedimiento | 1. Intentar bajar de 1 y subir de 99.<br>2. Confirmar cantidades escritas `0`, `100`, `-1`, `1.5`, vacío y `abc`.<br>3. En una línea con cantidad 1 intentar bajar a 0 y subir a 100 desde el carrito.<br>4. Verificar que quitar solo ocurre con la acción explícita. |
| Datos de prueba sintéticos | Tabla de valores del paso 2. |
| Resultado esperado | Valores mantenidos en 1 y 99; los inválidos se rechazan o corrigen al rango 1–99 con mensaje; no se crea ninguna línea inválida; la línea no se elimina por bajar a 0. |
| Criterio de aprobación | Todas las filas de la tabla se comportan según lo esperado (≥ 90 % de cobertura del módulo, RNF-089). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-038 · Añadir un producto que ya está en el carrito

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-029-5 |
| RF / RNF | RF-029, RF-049 |
| Objetivo | Verificar que no se duplican líneas y que se respeta el tope de 99. |
| Precondiciones | Carrito con `P-PRECIO` cantidad 98. |
| Procedimiento | 1. Añadir `P-PRECIO` con cantidad 1 (→ 99 si se suma).<br>2. Añadir de nuevo `P-PRECIO` con cantidad 5.<br>3. Revisar número de líneas y cantidad final. |
| Datos de prueba sintéticos | `P-PRECIO`. |
| Resultado esperado | Una sola línea; cantidad nunca mayor que 99 y se informa si se limitó. Suma frente a reemplazo queda pendiente. |
| Criterio de aprobación | Una sola línea y tope respetado; la regla de fusión se aprueba al cerrarse. |
| **[A VALIDAR]** | AC-029-5: **[A VALIDAR — propuesta de PA nueva]** regla de fusión: sumar o reemplazar (no definida en RF-049).<br>Pregunta que bloquea: Regla de fusión (sumar o reemplazar) no definida en RF-049. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-039 · Tope de 100 líneas

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-029-6, AC-049-3 |
| RF / RNF | RF-029, RF-049; RNF-031, RNF-044 |
| Objetivo | Verificar el rechazo de la línea 101 con mensaje. |
| Precondiciones | Carrito sembrado con 100 líneas (fixtures). |
| Procedimiento | 1. Intentar añadir un producto nuevo.<br>2. Verificar mensaje y número de líneas. |
| Datos de prueba sintéticos | 100 productos sintéticos de fixtures. |
| Resultado esperado | No se añade; mensaje del límite de 100 líneas; el carrito sigue en 100. |
| Criterio de aprobación | 100 líneas antes y después. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-040 · Persistencia del carrito tras cierre total y sin red

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí (integration_test) |
| AC que cubre | AC-049-4, AC-009-6 |
| RF / RNF | RF-049, RF-009; RNF-031 |
| Objetivo | Verificar que el carrito sobrevive al cierre del proceso y es visible sin red. |
| Precondiciones | Carrito `C3` guardado; visitante. |
| Procedimiento | 1. Terminar el proceso de la app por completo.<br>2. Reabrir con red apagada (`RED-OFF`).<br>3. Abrir el carrito y tocar "Pagar". |
| Datos de prueba sintéticos | `C3`. |
| Resultado esperado | 3 líneas y cantidades idénticas sin sesión; al tocar "Pagar" sin red aparece el mensaje de que se requiere conexión y no se abre el navegador. |
| Criterio de aprobación | Persistencia al 100 % de las corridas (RNF-031) y mensaje correcto. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-041 · Quitar línea, subtotal y estado vacío

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | AC-049-5, AC-049-6 |
| RF / RNF | RF-049, RF-051 |
| Objetivo | Verificar quitar línea, contador, subtotal y estado vacío sin "Pagar". |
| Precondiciones | Carrito `C3` en widget test. |
| Procedimiento | 1. Quitar una línea.<br>2. Comprobar contador y subtotal informativo.<br>3. Quitar las demás líneas.<br>4. Verificar estado vacío con acción al catálogo y ausencia de "Pagar". |
| Datos de prueba sintéticos | `C3`. |
| Resultado esperado | La línea desaparece; contador y subtotal se actualizan; estado vacío con acción y sin botón "Pagar". |
| Criterio de aprobación | Todas las verificaciones pasan. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-042 · Qué se almacena de cada línea

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Unitaria · Sí |
| AC que cubre | AC-029-8 |
| RF / RNF | RF-029, RF-050; RNF-031 |
| Objetivo | Verificar que se guarda id y cantidad y que el precio mostrado se refresca desde el servidor. |
| Precondiciones | Repositorio de carrito con almacén simulado. |
| Procedimiento | 1. Añadir una línea y leer el contenido persistido.<br>2. Cambiar el precio en la respuesta de revalidación simulada.<br>3. Reabrir el carrito y comparar el precio mostrado. |
| Datos de prueba sintéticos | `P-PRECIO` con precio 100.000 y luego 110.000 (valores sintéticos). |
| Resultado esperado | Se persisten identificador y cantidad (más datos de presentación); el precio mostrado es el de la última respuesta del servidor, no el guardado. |
| Criterio de aprobación | El precio mostrado coincide con la respuesta simulada. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-043 · El carrito no se sincroniza con el servidor

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-049-9 |
| RF / RNF | RF-049, RF-059 |
| Objetivo | Verificar que cerrar y abrir sesión no envía el carrito al servidor. |
| Precondiciones | Sesión de `CLI-01` con carrito `C3`; interceptor HTTP. |
| Procedimiento | 1. Cerrar y abrir sesión.<br>2. Revisar las solicitudes emitidas. |
| Datos de prueba sintéticos | `C3`. |
| Resultado esperado | 0 solicitudes que contengan líneas de carrito, salvo `cart/validate` y `checkout`. |
| Criterio de aprobación | Ninguna solicitud de sincronización de carrito. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-044 · Revalidación al abrir el carrito: solicitud por IDs y contrato

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Contrato · Sí |
| AC que cubre | AC-050-1, AC-050-10 |
| AC de tipo Seguridad (regresión funcional complementaria; diseño en `06_security/security_testing.md`) | AC-050-8 |
| RF / RNF | RF-050; RNF-085, RNF-090 |
| Objetivo | Verificar que se consulta precio y disponibilidad de cada ítem por ID y que el contrato rechaza más de 100 IDs. |
| Precondiciones | BFF de staging (o simulado conforme al OpenAPI) con `POST /cart/validate`; carrito de 4 ítems. |
| Procedimiento | 1. Abrir el carrito y observar el indicador de carga.<br>2. Capturar la solicitud: solo `{id, quantity}` por línea, sin precios.<br>3. Validar la respuesta contra el esquema `CartValidation` del OpenAPI.<br>4. Enviar 101 IDs y cantidades 0 y 100 directamente al endpoint. |
| Datos de prueba sintéticos | Carrito de 4 ítems (`P-PRECIO`, `P-OFERTA`, `P-AGOTADO`, `P-SINPRECIO`); lote de 101 IDs sintéticos. |
| Resultado esperado | Una solicitud con las 4 líneas; respuesta conforme al esquema (estado por línea); 101 IDs o cantidades fuera de 1–99 responden 400 `validation_failed`; el precio mostrado proviene de la respuesta. |
| Criterio de aprobación | Esquema válido y rechazos 400 observados. Nota: el AC-050-8 (tipo Seguridad) se verifica funcionalmente aquí; su diseño de abuso es de seguridad. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-045 · Cambio de precio detectado al abrir el carrito

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-050-2, AC-050-9 |
| RF / RNF | RF-050, RF-051 |
| Objetivo | Verificar el aviso de cambio de precio y que el total final no se presenta como definitivo. |
| Precondiciones | Carrito con `P-CAMBIO` (SKU `QA-0006`) a 100.000; el precio se cambia a 110.000 en staging o en el simulado. |
| Procedimiento | 1. Abrir el carrito.<br>2. Observar precio anterior y nuevo y el aviso.<br>3. Intentar pagar. |
| Datos de prueba sintéticos | `P-CAMBIO`. |
| Resultado esperado | La línea muestra el precio nuevo con aviso visible (anterior y nuevo); no se presenta un total definitivo. Si se exige confirmación explícita antes de pagar queda pendiente. |
| Criterio de aprobación | Aviso presente y precio vigente mostrado; la parte de confirmación explícita se aprueba tras la decisión. |
| **[A VALIDAR]** | AC-050-2: **[A VALIDAR — propuesta de PA nueva]** si el usuario debe confirmar explícitamente el cambio antes de poder pagar.<br>Pregunta que bloquea: Si el usuario debe confirmar explícitamente el cambio antes de pagar no está definido. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-046 · Ítem agotado bloquea el pago hasta quitarlo

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-050-3, AC-050-4, AC-031-3, AC-052-7 |
| RF / RNF | RF-050, RF-031, RF-052 |
| Objetivo | Verificar el bloqueo de "Pagar" por agotado y su desbloqueo al quitar la línea. |
| Precondiciones | Carrito con `P-PRECIO` y `P-AGOTADO` (marcado agotado después de añadirlo). |
| Procedimiento | 1. Abrir el carrito.<br>2. Verificar marca "Agotado" y botón "Pagar" deshabilitado; intentar tocarlo y contar solicitudes.<br>3. Quitar la línea agotada.<br>4. Verificar que "Pagar" se habilita. |
| Datos de prueba sintéticos | `P-PRECIO`, `P-AGOTADO`. |
| Resultado esperado | Línea marcada "Agotado"; "Pagar" deshabilitado y 0 solicitudes a `/checkout`; al quitar la línea, "Pagar" se habilita. |
| Criterio de aprobación | Estados del botón y 0 solicitudes verificados. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-047 · Ítem que pasó a precio 0 no es pagable

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-050-5, AC-030-4 |
| RF / RNF | RF-050, RF-030, RF-012 |
| Objetivo | Verificar que un ítem sin precio se marca, ofrece "Más información" y bloquea el pago. |
| Precondiciones | Carrito con `P-PRECIO`; en staging se cambia su precio a 0. |
| Procedimiento | 1. Abrir el carrito.<br>2. Observar la marca de sin precio, "Más información" y el estado de "Pagar".<br>3. Quitar la línea y volver a observar. |
| Datos de prueba sintéticos | `P-PRECIO` con precio 0 (conmutable). |
| Resultado esperado | Línea marcada sin precio, sin cifra ni "$0", con "Más información"; "Pagar" bloqueado hasta quitarla. |
| Criterio de aprobación | Marca, texto y bloqueo verificados. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-048 · Ítem despublicado (not_found) se trata como no disponible

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-050-6 |
| RF / RNF | RF-050; RNF-022 |
| Objetivo | Verificar el bloqueo con el mismo tratamiento que un agotado y que la línea no se borra sola. |
| Precondiciones | Carrito con un producto que se despublica en staging o respuesta simulada `status: not_found`. |
| Procedimiento | 1. Abrir el carrito.<br>2. Observar la línea y el estado de "Pagar". |
| Datos de prueba sintéticos | Producto sintético despublicado. |
| Resultado esperado | Línea marcada no disponible (no se elimina sola); "Pagar" bloqueado como en el caso de agotado. |
| Criterio de aprobación | Línea conservada y pago bloqueado. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-049 · Falla la revalidación: no se paga con datos sin verificar

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-050-7 |
| RF / RNF | RF-050; RNF-021, RNF-027 |
| Objetivo | Verificar el bloqueo del pago con mensaje y reintentar cuando la revalidación falla. |
| Precondiciones | Carrito `C3`; respuestas simuladas: sin red, 503 y tiempo agotado (una por corrida). |
| Procedimiento | 1. Abrir el carrito con cada fallo.<br>2. Intentar pagar.<br>3. Pulsar "Reintentar" con la red restablecida. |
| Datos de prueba sintéticos | `C3`. |
| Resultado esperado | Pago bloqueado con mensaje y "Reintentar"; no se emite `POST /checkout`; tras reintentar con éxito se habilita el pago. |
| Criterio de aprobación | 3 de 3 fallos bloquean el pago y se recuperan. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-050 · Resumen del carrito: subtotal informativo y avisos

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Widget · Sí |
| AC que cubre | AC-051-1, AC-051-2, AC-051-3, AC-051-5 |
| RF / RNF | RF-051; RNF-084 |
| Objetivo | Verificar rótulos, avisos y exclusión de ítems sin precio del subtotal. |
| Precondiciones | Carrito con 2 ítems con precio y 1 sin precio; respuesta de revalidación simulada. |
| Procedimiento | 1. Abrir el carrito como visitante.<br>2. Revisar el rótulo "informativo" e "IVA incluido", el formato en COP y el aviso de impuestos, envío y total en checkout.<br>3. Buscar cualquier cifra rotulada "Total a pagar" o un envío calculado.<br>4. Comprobar que el ítem sin precio no suma ni muestra "$0". |
| Datos de prueba sintéticos | Líneas con precios sintéticos 100.000 y 50.000; un `P-SINPRECIO`. |
| Resultado esperado | Subtotal = 150.000 (formateado), rotulado informativo e IVA incluido; aviso presente; sin "Total a pagar" ni envío; ítem sin precio no suma. |
| Criterio de aprobación | Subtotal correcto y ausencia de los textos prohibidos (golden + búsqueda de texto). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo C — Integridad de precio, producto sin precio, agotado y WhatsApp (US-011, US-012, US-029 a US-031, US-062, US-063)

La app no calcula ni redondea importes; "sin precio" nunca se muestra como cero; WhatsApp es el único canal de cotización (D-04).

#### TC-051 · Formato de importes sin alterar el valor del servidor

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Unitaria · Sí |
| AC que cubre | AC-011-5, AC-026-5, AC-107-8, AC-108-4 |
| RF / RNF | RF-011, RF-026, RF-107, RF-108; RNF-084 |
| Objetivo | Verificar que el texto mostrado corresponde exactamente al valor recibido, sin recálculo de IVA ni redondeos. |
| Precondiciones | Función de formato COP (`es_CO`, 0 decimales) y mapeadores DTO. |
| Procedimiento | 1. Formatear 1234567, 999, 1000, 1000000 y 0,49 (este último como valor inválido de prueba).<br>2. Convertir el texto resultante de vuelta a número (solo dígitos) y compararlo con el original.<br>3. Verificar que no existe ningún cálculo de IVA ni multiplicación en el módulo (revisión estática + prueba).<br>4. Repetir para total y subtotal de pedido con valores del servidor simulado. |
| Datos de prueba sintéticos | Valores 1234567, 999, 1000, 1000000, subtotal 150000, total 178500 (sintéticos). |
| Resultado esperado | Los dígitos mostrados reproducen el valor recibido; separadores de miles según es_CO; el formato de símbolo y espacio se fija con un golden aprobado por diseño. |
| Criterio de aprobación | Igualdad de valor tras el viaje de ida y vuelta en todos los casos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-052 · Texto de precio para productos sin precio

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Unitaria · Sí |
| AC que cubre | AC-012-1, AC-012-4 |
| RF / RNF | RF-012; RNF-107 |
| Objetivo | Verificar que precio 0, nulo o no numérico nunca produce "$0", "NaN" ni "null". |
| Precondiciones | Mapeador de precio y función de texto de precio. |
| Procedimiento | 1. Evaluar `status: on_request` con `amount: null`.<br>2. Evaluar precio 0 en un DTO heredado.<br>3. Evaluar `null` y una cadena no numérica en `amount`.<br>4. Buscar en el texto resultante `$0`, `$ 0`, `0,00`, `0`, `NaN`, `null`. |
| Datos de prueba sintéticos | Fixtures JSON sintéticos con cada variante. |
| Resultado esperado | Todas las variantes resultan en el indicador "Más información" y ninguna cadena prohibida. |
| Criterio de aprobación | Ninguna coincidencia con las cadenas prohibidas. |
| **[A VALIDAR]** | AC-012-4: **[A VALIDAR — propuesta de PA nueva]** : ADR-002/D-04 definen solo `price = 0`; confirmar con el equipo web si otros valores son posibles.<br>Pregunta que bloquea: Los casos de precio ausente o no numérico más allá de `price = 0` están pendientes de confirmación con el equipo web (ADR-002/D-04). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-053 · Producto sin precio en tarjeta, ficha y listas

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Widget · Sí (+ golden) |
| AC que cubre | AC-012-2, AC-012-3, AC-030-1, AC-030-2, AC-030-5, AC-003-2 |
| RF / RNF | RF-012, RF-030; RNF-107 |
| Objetivo | Verificar que sin precio no hay cifra, "Añadir al carrito" ni selector, y sí "Más información". |
| Precondiciones | Listas: inicio, categoría, búsqueda, marca, Liquidaciones y carrito con `P-SINPRECIO`; visitante sin sesión. |
| Procedimiento | 1. Renderizar la tarjeta en cada lista.<br>2. Tocar la tarjeta y abrir la ficha.<br>3. Buscar en la ficha cualquier texto de precio.<br>4. Verificar ausencia de "Añadir al carrito" y selector de cantidad. |
| Datos de prueba sintéticos | `P-SINPRECIO` (SKU `QA-0002`). |
| Resultado esperado | Sin cifra de precio; sin acción de añadir; ficha con "Más información"; sin "$0"; funciona sin autenticación. |
| Criterio de aprobación | Las 6 listas cumplen y no hay texto de precio en la ficha. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-054 · Conteo de productos sin precio en un listado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-012-5 |
| RF / RNF | RF-012; RNF-107 |
| Objetivo | Verificar que exactamente los productos sin precio muestran "Más información". |
| Precondiciones | Categoría sintética con 10 productos, 3 con precio 0 (fixtures de staging o simulado). |
| Procedimiento | 1. Cargar el listado.<br>2. Contar tarjetas con "Más información" y con cifra.<br>3. Comparar contra la respuesta del servidor. |
| Datos de prueba sintéticos | Categoría `QA-CAT-MIXTA`. |
| Resultado esperado | 3 tarjetas con "Más información" y 7 con cifra. |
| Criterio de aprobación | Conteos coinciden con la respuesta del servidor. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-055 · "Más información" abre WhatsApp con nombre y SKU

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí (launcher simulado) + manual en dispositivo |
| AC que cubre | AC-030-3, AC-062-1, AC-062-3, AC-062-6 |
| RF / RNF | RF-062, RF-030; RNF-084 |
| Objetivo | Verificar el destino y el mensaje prellenado, sin sesión y sin red. |
| Precondiciones | Ficha de `P-SINPRECIO`; `url_launcher` simulado; luego dispositivo real con WhatsApp. |
| Procedimiento | 1. Tocar "Más información" como visitante.<br>2. Capturar la URL solicitada al lanzador.<br>3. Repetir con `RED-OFF`.<br>4. En dispositivo real con WhatsApp verificar que abre el chat con el mensaje. |
| Datos de prueba sintéticos | `P-SINPRECIO`; línea nacional de atención configurada en el flavor (no se transcribe aquí). |
| Resultado esperado | La URL apunta a la línea nacional y el mensaje contiene nombre y SKU; funciona sin sesión y sin red del BFF; no se recopilan datos personales. |
| Criterio de aprobación | URL correcta capturada y apertura verificada en dispositivo. El texto exacto queda pendiente. |
| **[A VALIDAR]** | AC-062-1: **[A VALIDAR — D-04]** texto exacto del mensaje (la web usa nombre y SKU; confirmar redacción con Comercial).<br>Pregunta que bloquea: Texto exacto del mensaje por confirmar con Comercial (D-04). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-056 · Codificación de URL de WhatsApp (producto y término buscado)

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Unitaria · Sí |
| AC que cubre | AC-062-2, AC-062-5, AC-023-2 |
| RF / RNF | RF-062, RF-023 |
| Objetivo | Verificar codificación y ausencia de "undefined" o "null". |
| Precondiciones | Constructor de enlaces de WhatsApp. |
| Procedimiento | 1. Construir el enlace con nombre `Válvula 1/4" & tubo #3` y SKU `ABC-123`; decodificar y comparar.<br>2. Construir con producto sin SKU.<br>3. Construir con el término `válvula 1/4 & tubo #3` (estado vacío de búsqueda). |
| Datos de prueba sintéticos | Cadenas del paso 1 a 3. |
| Resultado esperado | Texto codificado en URL; al decodificar coincide con nombre, SKU y término originales; sin SKU el mensaje lleva el nombre y no contiene "undefined", "null" ni SKU vacío. |
| Criterio de aprobación | Las 3 decodificaciones son idénticas al original. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-057 · Sin WhatsApp: alternativas web y llamada

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí (launcher simulado) |
| AC que cubre | AC-063-1, AC-063-2, AC-063-3, AC-063-5, AC-062-4, AC-005-3 |
| RF / RNF | RF-063, RF-062, RF-005 |
| Objetivo | Verificar las dos alternativas cuando WhatsApp no está disponible y que no hay error técnico. |
| Precondiciones | `url_launcher` simulado que devuelve "no se puede abrir" para WhatsApp; luego tableta sin telefonía. |
| Procedimiento | 1. Tocar un botón de WhatsApp.<br>2. Elegir "abrir en el navegador" y verificar que el enlace `wa.me` conserva el mensaje.<br>3. Elegir "llamar" y verificar que se abre el marcador sin marcar.<br>4. En dispositivo sin telefonía, elegir "llamar". |
| Datos de prueba sintéticos | `P-SINPRECIO`, término `válvula`. |
| Resultado esperado | Se ofrecen las dos alternativas; el mensaje se conserva; el marcador queda con el número escrito sin marcar; sin telefonía hay mensaje claro; la app no falla ni se cierra. |
| Criterio de aprobación | Alternativas y mensajes verificados. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-058 · Producto agotado: ficha, tarjetas y todos los caminos de añadido

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Widget · Sí |
| AC que cubre | AC-031-1, AC-031-2, AC-031-5, AC-003-3 |
| RF / RNF | RF-031 |
| Objetivo | Verificar "Agotado" y que ningún camino añade la línea. |
| Precondiciones | `P-AGOTADO` en ficha, listado e inicio. |
| Procedimiento | 1. Abrir la ficha y verificar "Agotado" y botón ausente o deshabilitado.<br>2. Intentar añadir desde la tarjeta y desde "repetir compra" (si existe).<br>3. Verificar el carrito. |
| Datos de prueba sintéticos | `P-AGOTADO` (SKU `QA-0003`). |
| Resultado esperado | "Agotado" consistente en ficha y tarjeta; el botón no responde; 0 líneas añadidas. |
| Criterio de aprobación | Carrito sin líneas del producto. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-059 · Producto "Disponible bajo pedido"

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-031-4 |
| RF / RNF | RF-031 |
| Objetivo | Verificar que hasta decidir no se habilita la compra de productos `onbackorder`. |
| Precondiciones | `P-TC-059` (SKU `QA-0004`). |
| Procedimiento | 1. Abrir la ficha y el listado.<br>2. Intentar añadir al carrito. |
| Datos de prueba sintéticos | `P-BACKORDER`. |
| Resultado esperado | Tratamiento según IPR; mientras tanto no se habilita la compra (AP-04 recomienda no comprable en el MVP). |
| Criterio de aprobación | Compra no habilitada; el texto y tratamiento final se aprueban al decidir. |
| **[A VALIDAR]** | AC-031-4: **[A VALIDAR — PA-12]** (la web distingue `instock`, `outofstock` y `onbackorder`; el tratamiento en la app está por decidir). Hasta entonces no se habilita la compra de estos productos.<br>Pregunta que bloquea: El tratamiento en la app de `onbackorder` está por decidir (PA-12). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-060 · Detección de WhatsApp en Android 11 o superior e iOS

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Manual · No |
| AC que cubre | AC-063-4 |
| RF / RNF | RF-063 |
| Objetivo | Verificar que no hay falsos negativos por restricciones de visibilidad de paquetes o esquemas. |
| Precondiciones | Dispositivos Android 11 o superior e iPhone con WhatsApp instalado y otros sin él. |
| Procedimiento | 1. Con WhatsApp instalado, tocar un botón de WhatsApp en cada dispositivo.<br>2. Sin WhatsApp, tocar el botón y verificar que aparece la alternativa. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Con WhatsApp se abre directamente sin ofrecer la alternativa; sin WhatsApp se ofrece. |
| Criterio de aprobación | Comportamiento correcto en cada dispositivo de la matriz. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo D — Checkout con Wompi sandbox y retorno a la app (US-052 a US-058)

Todos los casos E2E corren en staging con Wompi sandbox, nunca en producción. Las tarjetas de prueba se toman de la documentación oficial vigente de Wompi; no se transcriben aquí.

#### TC-061 · Pagar sin sesión: pedir login o registro y continuar

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Widget · Sí |
| AC que cubre | AC-052-1 |
| RF / RNF | RF-052, RF-037 |
| Objetivo | Verificar que el visitante con carrito válido es llevado a login/registro y puede continuar tras autenticarse. |
| Precondiciones | Visitante con carrito `C3`. |
| Procedimiento | 1. Pulsar "Pagar".<br>2. Autenticarse con `CLI-01`.<br>3. Verificar que se continúa con la revalidación y el pago y que el carrito se conservó. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | Pantalla de login/registro; tras autenticarse continúa el flujo de pago con el mismo carrito. |
| Criterio de aprobación | Flujo continuo y carrito idéntico. |
| **[A VALIDAR]** | AC-052-1: **[A VALIDAR — PA-01]** si se permitirá compra de invitado (hoy S-02: exige sesión).<br>Pregunta que bloquea: Compra de invitado (hoy S-02 exige sesión): la decisión depende de PA-01. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-062 · Doble toque en "Pagar": una sola solicitud y un solo ticket

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Widget · Sí |
| AC que cubre | AC-052-6, AC-057-7, AC-058-7 |
| RF / RNF | RF-052, RF-057, RF-058; RNF-024 |
| Objetivo | Verificar una sola solicitud a `/checkout` por intención de pago, también en reintentos rápidos. |
| Precondiciones | Cliente con sesión y carrito válido; adaptador HTTP con retraso de 3 s; luego repetir en staging con contador de tickets. |
| Procedimiento | 1. Tocar "Pagar" dos veces en menos de 300 ms.<br>2. Contar solicitudes a `POST /mobile/v1/checkout`.<br>3. Tras un error simulado, pulsar "Reintentar" 5 veces rápido y contar solicitudes simultáneas.<br>4. En staging, verificar que se emitió 1 ticket por intención. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | Exactamente 1 solicitud; botón deshabilitado con indicador de progreso; una solicitud a la vez en los reintentos; 1 ticket por intención. Es parte de NL-02 (duplicados). |
| Criterio de aprobación | Contador = 1 en cada escenario. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-063 · Validación del cuerpo de `/checkout`

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Contrato · Sí |
| AC que cubre | AC-052-11 |
| RF / RNF | RF-052; RNF-044 |
| Objetivo | Verificar que cuerpos inválidos responden 400 sin generar ticket. |
| Precondiciones | BFF de staging; sesión de `CLI-01`. |
| Procedimiento | 1. Enviar cantidad 0, cantidad 100, id `abc`, lista vacía y 101 líneas.<br>2. Verificar el 400 y que no existe ticket.<br>3. Validar el cuerpo del error contra el esquema `Problem` (RFC 9457). |
| Datos de prueba sintéticos | Cuerpos sintéticos de cada caso. |
| Resultado esperado | 400 `validation_failed` con mensaje legible en los 5 casos; 0 tickets. |
| Criterio de aprobación | 5 de 5 casos rechazados y esquema válido. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-064 · Errores del traspaso al checkout con mensajes en español y carrito intacto

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-058-1, AC-058-2, AC-058-3, AC-058-9, AC-009-4, AC-052-8, AC-052-9 |
| RF / RNF | RF-058, RF-052, RF-009; RNF-027 |
| Objetivo | Verificar el tratamiento de 400, 502/503/504, respuesta sin ticket y falta de red. |
| Precondiciones | BFF simulado; carrito `C3`; access vencido en uno de los casos. |
| Procedimiento | 1. Simular 400 de la tienda y pulsar "Pagar".<br>2. Simular 503, 504 y tiempo agotado.<br>3. Simular una respuesta 201 sin `checkoutUrl` válido.<br>4. Simular `RED-OFF`.<br>5. Simular access vencido en el momento de pagar.<br>6. En cada caso, verificar mensaje, botón "Reintentar" y carrito. |
| Datos de prueba sintéticos | `C3`. |
| Resultado esperado | Mensajes legibles en español sin códigos ni HTML ni nombres de variables; "No se pudo conectar con la tienda, inténtalo de nuevo" ante 502/503/timeout; sin URL abierta ni almacenamiento con respuesta inválida; sin red no se abre el navegador; con access vencido se renueva de forma transparente; carrito idéntico en todos los casos. |
| Criterio de aprobación | 6 de 6 escenarios cumplen. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-065 · WordPress no responde: la app no queda bloqueada

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-052-16 |
| RF / RNF | RF-052; RNF-021, RNF-013 |
| Objetivo | Verificar un tiempo acotado y salida con error. |
| Precondiciones | BFF simulado que no responde (o staging con WordPress detenido de forma controlada con autorización). |
| Procedimiento | 1. Pulsar "Pagar".<br>2. Cronometrar hasta la aparición del error.<br>3. Verificar que el indicador de progreso desaparece. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | Error en tiempo acotado (referencia del cliente: 20 s para ticket, RNF-021); el indicador desaparece y se puede reintentar. |
| Criterio de aprobación | Tiempo medido dentro del umbral aprobado. |
| **[A VALIDAR]** | AC-052-16: **[A VALIDAR — propuesta de PA nueva]** umbral de tiempo en la app (en la web el BFF espera 8 s a WordPress).<br>Pregunta que bloquea: El umbral de tiempo en la app no está definido (en la web el BFF espera 8 s a WordPress). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-066 · El checkout se abre en el navegador seguro del sistema

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) + observación manual |
| AC que cubre | AC-052-3, AC-053-5 |
| RF / RNF | RF-052, RF-053; RNF-045, RNF-086 |
| Objetivo | Verificar Custom Tabs (Android) y ASWebAuthenticationSession o SFSafariViewController (iOS), nunca WebView propio, con la barra de dominio visible. |
| Precondiciones | Staging; `CLI-01`; carrito válido; un Android con Chrome y uno sin Chrome (RNF-086); un iPhone. |
| Procedimiento | 1. Pulsar "Pagar".<br>2. Observar el componente que abre la URL y medir el tiempo hasta la apertura tras recibir el ticket.<br>3. Verificar la barra de dirección con el dominio de la tienda.<br>4. Repetir en Android sin Chrome. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | Navegador seguro del sistema (no WebView incrustado); dominio visible; apertura ≤ 5 s tras recibir el ticket (RNF-013); en Android sin Chrome hay respaldo al navegador predeterminado. |
| Criterio de aprobación | Componente correcto y tiempo dentro del umbral en las 3 plataformas. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-067 · E2E compra aprobada

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-052-15, AC-056-2, AC-057-1, AC-107-4 |
| AC de tipo Seguridad (regresión funcional complementaria; diseño en `06_security/security_testing.md`) | AC-052-5 |
| RF / RNF | RF-052, RF-056, RF-057, RF-107; RNF-024, RNF-025, RNF-091 |
| Objetivo | Verificar el recorrido completo: añadir, login, pagar con tarjeta de prueba aprobada, volver, ver pedido y carrito vacío. Es el criterio de salida del MVP. |
| Precondiciones | Staging con Wompi sandbox; `CLI-01`; `P-PRECIO` y `P-OFERTA` en carrito; Android y iOS. |
| Procedimiento | 1. Añadir los productos al carrito.<br>2. Iniciar sesión y pulsar "Pagar".<br>3. En el checkout elegir envío y pagar con la tarjeta de prueba APROBADA de Wompi.<br>4. Volver a la app por enlace profundo.<br>5. Verificar el resultado, el número de pedido contra WooCommerce, el monto contra el precio vigente de WooCommerce y el historial.<br>6. Verificar que el carrito quedó vacío. |
| Datos de prueba sintéticos | `CLI-01`; `TARJ-APROBADA`; precios vigentes sintéticos. |
| Resultado esperado | Estado "pagado" con número igual al del pedido de WooCommerce; monto igual al precio vigente; carrito en 0 líneas; el pedido aparece en el historial con número y estado correctos. 100 % de aprobación del recorrido en ambas plataformas (RNF-091, NL-02). |
| Criterio de aprobación | Recorrido completo aprobado en Android y en iOS con evidencia. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-068 · E2E pago rechazado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-056-3, AC-057-2 |
| RF / RNF | RF-056, RF-057; RNF-091 |
| Objetivo | Verificar estado "fallido" con reintento y carrito conservado. |
| Precondiciones | Como TC-067 con carrito `C3`. |
| Procedimiento | 1. Pagar con la tarjeta de prueba RECHAZADA de Wompi.<br>2. Volver a la app.<br>3. Verificar el estado y el carrito.<br>4. Pulsar "Reintentar". |
| Datos de prueba sintéticos | `CLI-01`, `C3`; `TARJ-RECHAZADA`. |
| Resultado esperado | Estado "fallido" con opción de reintentar; el carrito conserva las mismas líneas y cantidades; "Reintentar" genera un intento nuevo. |
| Criterio de aprobación | Estado y carrito verificados en ambas plataformas. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-069 · E2E pago cancelado por el usuario

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-056-4, AC-057-2 |
| RF / RNF | RF-056, RF-057; RNF-091 |
| Objetivo | Verificar estado "cancelado" y carrito intacto. |
| Precondiciones | Como TC-067. |
| Procedimiento | 1. En el checkout cancelar el pago o volver atrás.<br>2. Volver a la app y observar el resultado. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | Estado "cancelado"; carrito intacto. |
| Criterio de aprobación | Estado correcto y carrito idéntico. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-070 · E2E pago pendiente de confirmación

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (si el sandbox permite simular pendiente; NO VERIFICADO) |
| AC que cubre | AC-056-5, AC-057-3 |
| RF / RNF | RF-056, RF-057; RNF-025 |
| Objetivo | Verificar que "pendiente" no se presenta como pagado, que el carrito no se vacía y que al confirmarse se actualiza. |
| Precondiciones | Staging con Wompi sandbox; medio de pago o escenario que deje el pedido en `on-hold` o `pending` (MED-14). |
| Procedimiento | 1. Iniciar un pago que quede pendiente.<br>2. Volver a la app.<br>3. Verificar el estado "pendiente" con explicación y el carrito.<br>4. Confirmar el pago en el sandbox y recargar la pantalla de resultado. |
| Datos de prueba sintéticos | `CLI-01`; escenario pendiente de Wompi sandbox (a documentar). |
| Resultado esperado | "Pendiente" con explicación, nunca "pagado"; carrito sin vaciar hasta confirmación del servidor; tras la confirmación, la pantalla pasa a "pagado" al recargar sin cerrar sesión. |
| Criterio de aprobación | Transición pendiente → pagado verificada. Si el sandbox no puede simular pendiente, el caso se bloquea y se registra como riesgo. |
| **[A VALIDAR]** | AC-057-3: **[A VALIDAR — PA-11, D-02]** tratamiento exacto del carrito mientras el pedido está pendiente.<br>Pregunta que bloquea: El tratamiento exacto del carrito con pedido pendiente depende de PA-11 y D-02; que el sandbox simule el estado pendiente es NO VERIFICADO. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-071 · E2E abandono del pago y cierre forzado de la app

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-057-2, AC-057-8, AC-055-3 |
| RF / RNF | RF-055, RF-057; RNF-024, RNF-025 |
| Objetivo | Verificar que cerrar el navegador sin pagar, o matar la app, no vacía el carrito y que se puede ver el pedido más reciente. |
| Precondiciones | Como TC-067. |
| Procedimiento | 1. Abrir el checkout y cerrar el navegador seguro sin pagar.<br>2. Volver a la app; verificar la consulta de estado y el carrito.<br>3. Repetir forzando el cierre de la app durante el pago y reabrirla.<br>4. Abrir Mis pedidos. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | La app consulta el estado al volver a primer plano y muestra el resultado correspondiente; el carrito no se vacía solo; el pedido más reciente es visible en el historial. Cómo se identifica el pedido en este camino alterno queda pendiente. |
| Criterio de aprobación | Carrito idéntico y estado visible en ambas plataformas. |
| **[A VALIDAR]** | AC-055-3: **[A VALIDAR — ADR-001 C1/C2]** cómo se identifica el pedido en este camino alterno (COD §5.4).<br>Pregunta que bloquea: Cómo se identifica el pedido cuando el enlace profundo no abre la app depende de ADR-001 C1/C2 (COD §5.4). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-072 · E2E pago completado mientras la app no tenía red

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-057-4 |
| RF / RNF | RF-057; RNF-025 |
| Objetivo | Verificar que el carrito se vacía solo tras confirmar el servidor al recuperar red. |
| Precondiciones | Staging con Wompi sandbox. |
| Procedimiento | 1. Pagar con `TARJ-APROBADA`.<br>2. Apagar la red del dispositivo antes del retorno a la app.<br>3. Volver a la app sin red y observar.<br>4. Restablecer la red. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | Sin red no se vacía el carrito; al recuperarla, la app consulta el estado y lo vacía solo tras la confirmación "pagado". |
| Criterio de aprobación | Carrito vacío solo después de la confirmación. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-073 · E2E segundo intento tras abandono: un pedido pagado, ninguno duplicado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-057-5, AC-057-6 |
| RF / RNF | RF-057; RNF-024 |
| Objetivo | Descubrir y verificar cómo WooCommerce trata el pedido pendiente previo y que no hay doble cobro. Es parte de NL-02. |
| Precondiciones | Staging con Wompi sandbox; acceso de lectura a los pedidos de WooCommerce de staging. |
| Procedimiento | 1. Iniciar un pago y abandonarlo.<br>2. Pulsar "Pagar" de nuevo sobre el mismo carrito.<br>3. Completar el pago en el segundo intento con `TARJ-APROBADA`.<br>4. Contar en WooCommerce los pedidos del usuario para ese carrito y su estado. |
| Datos de prueba sintéticos | `CLI-01`, `C3`. |
| Resultado esperado | Exactamente 1 pedido pagado y 0 pedidos duplicados pagados. Si hay un pedido pendiente reciente, la app informa antes de generar otro ticket (política pendiente: bloquear, advertir o permitir). |
| Criterio de aprobación | Conteo en WooCommerce = 1 pagado, 0 duplicados pagados; el comportamiento observado se documenta como hallazgo. |
| **[A VALIDAR]** | AC-057-5: **[A VALIDAR — PA-11]** el comportamiento de WooCommerce ante un pedido pendiente previo es DESCONOCIDO; probar con Wompi sandbox.<br>AC-057-6: **[A VALIDAR — PA-11, D-02]** si se bloquea, se advierte o se permite.<br>Pregunta que bloquea: El comportamiento de WooCommerce ante un pedido pendiente previo es DESCONOCIDO (PA-11); la política de la app depende de PA-11 y D-02. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-074 · Ticket vencido o ya usado: se genera uno nuevo

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-058-4, AC-058-8 |
| RF / RNF | RF-058; RNF-026 |
| Objetivo | Verificar la recuperación ante ticket expirado o reutilizado. |
| Precondiciones | Staging; ticket obtenido y abierto después de 60 s, o abierto dos veces. |
| Procedimiento | 1. Pulsar "Pagar" y esperar más de 60 s antes de abrir el enlace (o abrirlo dos veces).<br>2. Observar la respuesta de WooCommerce y volver a la app.<br>3. Pulsar "Pagar" otra vez.<br>4. Provocar que un ítem se agote al abrir el checkout y observar el retorno a la app. |
| Datos de prueba sintéticos | `CLI-01`, `C3`, `P-AGOTADO`. |
| Resultado esperado | WooCommerce rechaza el ticket; la app permite reintentar y un nuevo ticket continúa el flujo; sin pantallas sin salida. El comportamiento al volver cuando WooCommerce no pudo agregar un ítem queda pendiente. |
| Criterio de aprobación | Reintento exitoso con ticket nuevo. |
| **[A VALIDAR]** | AC-058-8: **[A VALIDAR — propuesta de PA nueva]** (COD §5.4 punto 5: los agotados hacen que la operación falle y WooCommerce muestre el carrito).<br>Pregunta que bloquea: Comportamiento al regresar a la app cuando WooCommerce no puede agregar un ítem (propuesta de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-075 · Prellenado del checkout con datos de la cuenta

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-054-1, AC-054-2, AC-054-4 |
| RF / RNF | RF-054, RF-106 |
| Objetivo | Verificar que el checkout viene prellenado cuando hay datos y vacío cuando no. |
| Precondiciones | Staging; `CLI-01` con facturación guardada; `CLI-02` sin facturación. |
| Procedimiento | 1. Abrir el checkout con `CLI-01` y revisar los campos.<br>2. Abrir el checkout con `CLI-02`.<br>3. Editar la dirección de `CLI-01` en el perfil y abrir un nuevo checkout. |
| Datos de prueba sintéticos | `CLI-01` (dirección sintética), `CLI-02`. |
| Resultado esperado | Campos prellenados con los valores de la cuenta; vacíos para `CLI-02`; el checkout refleja la dirección actualizada. |
| Criterio de aprobación | Tres escenarios correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-076 · Retorno por enlace profundo con la app en segundo plano y cerrada

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-055-1, AC-055-7 |
| RF / RNF | RF-055; RNF-025, RNF-046 |
| Objetivo | Verificar que el enlace de retorno abre la app en el resultado y que el botón atrás lleva al inicio. |
| Precondiciones | Staging con `assetlinks.json` y `apple-app-site-association` servidos; `CLI-01`; pago aprobado. |
| Procedimiento | 1. Completar un pago con la app en segundo plano y observar si el enlace abre la app.<br>2. Repetir con la app cerrada (arranque en frío).<br>3. En el resultado, pulsar atrás. |
| Datos de prueba sintéticos | `CLI-01`, `TARJ-APROBADA`. |
| Resultado esperado | La app abre en la pantalla de resultado en ambos casos; atrás lleva al inicio; si el enlace no abre la app, la consulta de estado al volver a primer plano da el mismo resultado (ver TC-071). |
| Criterio de aprobación | Resultado correcto por enlace, o por consulta de estado si el enlace falla (documentar matriz por versión de SO, SPK-01). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-077 · Enlace de retorno recibido sin sesión activa

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-055-6 |
| RF / RNF | RF-055 |
| Objetivo | Verificar que se pide login y después se muestra el resultado. |
| Precondiciones | App sin sesión; enlace de retorno de un pedido de `CLI-01`. |
| Procedimiento | 1. Abrir el enlace de retorno sin sesión.<br>2. Iniciar sesión con `CLI-01`. |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | Se pide iniciar sesión y, tras autenticarse, se muestra el resultado del pedido. |
| Criterio de aprobación | Resultado visible tras el login. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-078 · Enlace manipulado: el estado lo dicta el servidor

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | — |
| AC de tipo Seguridad (regresión funcional complementaria; diseño en `06_security/security_testing.md`) | AC-055-4, AC-056-6, AC-055-5, AC-056-10 |
| RF / RNF | RF-055, RF-056; RNF-045, RNF-046 |
| Objetivo | Verificación funcional (regresión en CI) de que los parámetros del enlace son solo una pista. El diseño de abuso lo cubre seguridad. |
| Precondiciones | BFF simulado con un pedido `pending` de `CLI-01` y otro de `CLI-02`. |
| Procedimiento | 1. Abrir `/app/pedido?ref=<ref>&order=<n>&status=completed` falsificado con el pedido pendiente.<br>2. Abrir un enlace con el número de pedido de `CLI-02` estando con `CLI-01`.<br>3. Observar el resultado. |
| Datos de prueba sintéticos | Pedido pendiente de `CLI-01`; pedido de `CLI-02`. |
| Resultado esperado | La app consulta al servidor con la sesión del usuario y muestra "pendiente"; ante un pedido ajeno el servidor no devuelve datos y la app muestra un error genérico sin revelar la existencia. |
| Criterio de aprobación | Estados mostrados = estados del servidor en ambos casos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-079 · Pantalla de resultado: textos, íconos y acciones por estado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Widget · Sí (+ golden) |
| AC que cubre | AC-056-9, AC-056-1, AC-056-7, AC-056-8 |
| RF / RNF | RF-056; RNF-027 |
| Objetivo | Verificar que cada estado muestra lo que le corresponde y que los datos vienen del servidor. |
| Precondiciones | Repositorio de checkout simulado con estados: paid, pending, failed, cancelled, refunded, unknown. |
| Procedimiento | 1. Renderizar la pantalla con cada estado.<br>2. Verificar texto, ícono y acciones (ver pedido, seguir comprando, reintentar).<br>3. Simular falla del servidor al consultar y verificar "Reintentar" sin afirmar éxito ni fallo.<br>4. Simular un estado no mapeado y verificar `statusLabel`. |
| Datos de prueba sintéticos | Respuestas `CheckoutStatus` sintéticas conformes al OpenAPI. |
| Resultado esperado | Elementos propios de cada estado y sin mezclas; error de consulta con "Reintentar"; estado no mapeado muestra `statusLabel`. |
| Criterio de aprobación | Golden de los 6 estados aprobados y comportamiento verificado. La lista real de estados de WooCommerce queda pendiente. |
| **[A VALIDAR]** | AC-056-8: **[A VALIDAR — PA-12]** lista de estados reales de WooCommerce.<br>Pregunta que bloquea: Lista de estados reales de WooCommerce (PA-12). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-080 · Medios de pago ofrecidos en el checkout

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · E2E · No (inspección visual contra la configuración de WooCommerce/Wompi) |
| AC que cubre | AC-053-4 |
| RF / RNF | RF-053 |
| Objetivo | Comparar los medios ofrecidos con los habilitados en WooCommerce/Wompi. |
| Precondiciones | Staging con Wompi sandbox. |
| Procedimiento | 1. Abrir el checkout.<br>2. Listar los medios de pago ofrecidos.<br>3. Compararlos con la configuración del plugin de pagos. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Los medios ofrecidos coinciden con los habilitados. |
| Criterio de aprobación | Coincidencia 1 a 1, con captura. |
| **[A VALIDAR]** | AC-053-4: **[A VALIDAR — D-02, PA-12]** lista de medios habilitados.<br>Pregunta que bloquea: La lista de medios habilitados depende de D-02 y PA-12. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-081 · El cobro usa el precio vigente aunque la lista muestre el anterior

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí (condicionado a SPK-01) |
| AC que cubre | AC-019-5 |
| RF / RNF | RF-019, RF-052; RNF-111 |
| Objetivo | Verificar que la frescura de la lista no afecta el monto del checkout. |
| Precondiciones | Staging; `P-CAMBIO` visible en la app a 100.000; luego precio en WooCommerce cambiado a 110.000 sin recargar la lista. |
| Procedimiento | 1. Con la lista aún mostrando el precio anterior, añadir el producto al carrito.<br>2. Pagar hasta el checkout de WooCommerce.<br>3. Comparar el monto con el precio vigente. |
| Datos de prueba sintéticos | `P-CAMBIO`. |
| Resultado esperado | El monto del checkout es el precio vigente de WooCommerce (110.000, más impuestos y envío que calcula WooCommerce), no el que mostraba la lista. |
| Criterio de aprobación | Monto = precio vigente. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-082 · Archivos `.well-known` y verificación de enlaces del sistema

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Manual · No (la consulta HTTP del archivo sí es automatizable) |
| AC que cubre | AC-055-2 |
| RF / RNF | RF-055; RNF-046 |
| Objetivo | Verificar que `assetlinks.json` y `apple-app-site-association` responden 200 con los identificadores de la app y que el sistema los marca como verificados. |
| Precondiciones | Staging o dominio de pruebas con los archivos publicados; build firmado con la huella de prueba. |
| Procedimiento | 1. Consultar ambas URL: estado 200, `Content-Type` JSON, sin redirecciones ni desafío de Cloudflare.<br>2. Comprobar identificadores y huellas.<br>3. Verificar en Android (`pm get-app-links`) y en iOS que el dominio está verificado. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Respuestas 200 con identificadores correctos y verificación del sistema en estado verificado. Es criterio de salida de RF-055. |
| Criterio de aprobación | Ambas plataformas verificadas con evidencia. |
| **[A VALIDAR]** | AC-055-2: **[A VALIDAR — ADR-001 C1/C2]** si se pueden alojar esos archivos en el dominio (COD §8, pregunta 3).<br>Pregunta que bloquea: Si se pueden alojar esos archivos en el dominio (ADR-001 C1/C2, COD §8 pregunta 3). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo E — Pedidos: historial y detalle (US-107, US-108)

Los pedidos se muestran tal como los entrega el servidor; ningún importe se recalcula en la app.

#### TC-083 · Historial: datos, orden, vacío, sesión y errores

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-107-1, AC-107-3, AC-107-5, AC-107-6, AC-107-9 |
| RF / RNF | RF-107; RNF-020 |
| Objetivo | Verificar el historial con y sin pedidos, sin sesión, con token expirado y con falla de carga. |
| Precondiciones | Staging; `CLI-01` con 3 pedidos; `CLI-02` sin pedidos. |
| Procedimiento | 1. Abrir el historial con `CLI-01`: número, fecha, estado (etiqueta del servidor) y total en COP.<br>2. Abrirlo con `CLI-02`.<br>3. Abrirlo como visitante.<br>4. Abrirlo con token expirado.<br>5. Simular error de carga. |
| Datos de prueba sintéticos | `CLI-01`, `CLI-02`. |
| Resultado esperado | 3 pedidos con campos del servidor; estado vacío con acción al catálogo; el visitante recibe petición de login; token expirado se renueva o pide reautenticación sin perder el carrito; error con "Reintentar". |
| Criterio de aprobación | 5 escenarios correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-084 · Orden y paginación del historial

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-107-7 |
| RF / RNF | RF-107 |
| Objetivo | Verificar orden y paginación con muchos pedidos. |
| Precondiciones | Cuenta sintética con más de 20 pedidos (fixtures). |
| Procedimiento | 1. Abrir el historial y desplazar hasta cargar la segunda página.<br>2. Verificar orden y que no hay duplicados. |
| Datos de prueba sintéticos | Cuenta sintética `CLI-03` con 25 pedidos. |
| Resultado esperado | Orden definido y paginación sin duplicados (el contrato propone `perPage` 10 o 20). |
| Criterio de aprobación | Sin duplicados; el orden se aprueba al definirlo. |
| **[A VALIDAR]** | AC-107-7: **[A VALIDAR — propuesta de PA nueva]** orden y tamaño de página (no definidos).<br>Pregunta que bloquea: Orden y tamaño de página del historial no definidos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-085 · Detalle de pedido: líneas, totales y campos no soportados

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí (+ golden) |
| AC que cubre | AC-108-1, AC-108-2, AC-108-5, AC-108-6 |
| RF / RNF | RF-108 |
| Objetivo | Verificar contenido del detalle, ausencia de campos no soportados y ajuste de texto largo. |
| Precondiciones | Respuesta `OrderDetail` sintética; pantalla de 360 dp. |
| Procedimiento | 1. Renderizar el detalle: productos con nombre, cantidad y total por línea, subtotal, total y método de pago.<br>2. Verificar ausencia de imagen, envío, seguimiento y dirección, y de campos vacíos o ceros por ellos.<br>3. Renderizar un nombre de 150 caracteres.<br>4. Renderizar con un estado no mapeado. |
| Datos de prueba sintéticos | `P-LARGO`; pedido sintético con 3 líneas. |
| Resultado esperado | Contenido según el AC; sin campos vacíos ni ceros; texto ajustado sin desbordar; etiqueta `statusLabel` del servidor. Nota de inconsistencia: el OpenAPI propuesto incluye `shippingTotal`, `taxTotal` e `imageUrl` en `OrderDetail`, que el AC-108-2 indica no mostrar; debe alinearse. |
| Criterio de aprobación | Golden aprobado y sin overflow en 360 dp. |
| **[A VALIDAR]** | AC-108-6: **[A VALIDAR — PA-12]** estados reales.<br>Pregunta que bloquea: Los estados reales de WooCommerce dependen de PA-12. |
| Nota | Inconsistencia AC-108-2 frente a openapi.yaml OrderDetail; resolver antes de cerrar el contrato. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-086 · Pedidos solo del usuario autenticado (regresión de contrato)

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Contrato · Sí |
| AC que cubre | — |
| AC de tipo Seguridad (regresión funcional complementaria; diseño en `06_security/security_testing.md`) | AC-107-2, AC-108-3, AC-SEC-8 |
| RF / RNF | RF-107, RF-108; RNF-043 |
| Objetivo | Verificación funcional en CI de que un pedido ajeno devuelve 404 sin datos. El diseño de abuso lo cubre seguridad. |
| Precondiciones | Staging; pedidos de `CLI-01` y `CLI-02`. |
| Procedimiento | 1. Con el token de `CLI-01`, listar pedidos y comprobar que solo hay los suyos.<br>2. Consultar `/orders/{id}` con el id de un pedido de `CLI-02`.<br>3. Consultar `/checkout/{ref}` con la referencia de `CLI-02`. |
| Datos de prueba sintéticos | `CLI-01`, `CLI-02`. |
| Resultado esperado | Solo pedidos propios; 404 sin datos ni indicios de existencia para el pedido ajeno; `awaiting_order` para referencia ajena. |
| Criterio de aprobación | Respuestas conformes en los 3 pasos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo F — Eliminación de cuenta, perfil y derechos del titular (US-104 a US-106, US-110, US-111)

La eliminación de cuenta es historia crítica y requisito de tienda (S-05). Se prueba solo con cuentas sintéticas descartables (`CLI-DEL`).

#### TC-087 · Eliminar cuenta: acceso, confirmación explícita, cancelar y doble toque

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Widget · Sí |
| AC que cubre | AC-110-1, AC-110-2, AC-110-10, AC-110-11 |
| RF / RNF | RF-110; RNF-058 |
| Objetivo | Verificar acceso desde el perfil, información previa, confirmación explícita, cancelación y una sola solicitud. |
| Precondiciones | Cliente con sesión; repositorio simulado con retraso. |
| Procedimiento | 1. Abrir el perfil y localizar "Eliminar cuenta" (número de toques desde Mi cuenta).<br>2. Abrir la confirmación y revisar el texto de qué se elimina y qué se conserva.<br>3. Cancelar y verificar 0 solicitudes.<br>4. Confirmar y tocar dos veces el botón final. |
| Datos de prueba sintéticos | `CLI-DEL`. |
| Resultado esperado | Acceso en ≤ 3 toques desde Mi cuenta (RNF-058); confirmación explícita; cancelar no emite solicitud; el doble toque emite exactamente 1 solicitud. Texto, datos conservados y plazos quedan pendientes. |
| Criterio de aprobación | Acceso, confirmación, cancelación y doble toque verificados; el texto se aprueba tras la decisión. |
| **[A VALIDAR]** | AC-110-2: **[A VALIDAR — PA-09, D-12]** texto, datos conservados (pedidos y soporte tributario) y plazos (DESCONOCIDOS).<br>Pregunta que bloquea: Texto, datos conservados (pedidos y soporte tributario) y plazos DESCONOCIDOS (PA-09, D-12). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-088 · Eliminar cuenta exige la contraseña actual

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | — |
| AC de tipo Seguridad (regresión funcional complementaria; diseño en `06_security/security_testing.md`) | AC-110-3, AC-110-12, AC-110-13 |
| RF / RNF | RF-110; RNF-058 |
| Objetivo | Verificar que sin contraseña no se emite la solicitud y que el endpoint no acepta id de cuenta del cliente. |
| Precondiciones | Cliente con sesión; interceptor HTTP; luego solicitud directa al endpoint. |
| Procedimiento | 1. Confirmar la eliminación sin escribir contraseña.<br>2. Escribir contraseña incorrecta.<br>3. Llamar `POST /me/deletion` sin token y con token inválido.<br>4. Inspeccionar el cuerpo emitido por la app. |
| Datos de prueba sintéticos | `CLI-DEL`. |
| Resultado esperado | Sin contraseña no se emite la solicitud; contraseña incorrecta rechazada con mensaje en el campo; sin token 401; el cuerpo contiene solo `currentPassword` y `confirm` sin identificador de cuenta. |
| Criterio de aprobación | Resultados observados en los 4 pasos. |
| **[A VALIDAR]** | AC-110-3: **[A VALIDAR — propuesta de PA nueva]** reautenticación exigida para esta acción.<br>Pregunta que bloquea: La reautenticación exigida para esta acción es propuesta de PA nueva (AC-110-3). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-089 · E2E eliminación completa de cuenta sintética

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí |
| AC que cubre | AC-110-4, AC-110-5 |
| RF / RNF | RF-110; RNF-058, RNF-062 |
| Objetivo | Verificar eliminación o anonimización, revocación en todos los dispositivos, borrado local y modo visitante. Es parte de NL-07. |
| Precondiciones | Staging; `CLI-DEL` con sesión en `DEV-A` y `DEV-B`. |
| Procedimiento | 1. Eliminar la cuenta desde `DEV-A` con confirmación y contraseña.<br>2. Verificar en WordPress el estado de la cuenta (eliminada, anonimizada o `pending_deletion`).<br>3. Con los tokens de `DEV-B` hacer una solicitud autenticada.<br>4. Intentar iniciar sesión con las credenciales anteriores.<br>5. Revisar que la app vuelve a modo visitante y que no quedan tokens ni datos personales locales (verificación funcional; la inspección forense es de seguridad). |
| Datos de prueba sintéticos | `CLI-DEL`. |
| Resultado esperado | Cuenta eliminada o anonimizada según política; todas las sesiones devuelven 401; el login falla con el mensaje genérico de credenciales inválidas; la app queda en modo visitante. |
| Criterio de aprobación | Todos los puntos verificados. La eliminación inmediata o diferida queda pendiente. |
| **[A VALIDAR]** | AC-110-4: **[A VALIDAR — PA-09]** eliminación inmediata o diferida.<br>Pregunta que bloquea: Eliminación inmediata o diferida (PA-09). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-090 · Pedidos y reutilización del correo tras eliminar

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-110-6, AC-110-7, AC-110-8 |
| RF / RNF | RF-110; RNF-058 |
| Objetivo | Documentar qué ocurre con pedidos, pedidos pendientes y re-registro con el mismo correo. |
| Precondiciones | Staging; cuentas `CLI-DEL-A` (con pedidos pagados), `CLI-DEL-B` (con un pedido pendiente). |
| Procedimiento | 1. Eliminar `CLI-DEL-A` y revisar sus pedidos en WooCommerce.<br>2. Intentar eliminar `CLI-DEL-B`.<br>3. Intentar registrar un usuario nuevo con el correo de `CLI-DEL-A`. |
| Datos de prueba sintéticos | `CLI-DEL-A`, `CLI-DEL-B`. |
| Resultado esperado | Comportamiento conforme a la política de Jurídico y Finanzas (conservar, anonimizar o eliminar; bloquear, advertir o permitir; reutilizar o no el correo). |
| Criterio de aprobación | Se registra el comportamiento observado; no se aprueba hasta cerrar la política. |
| **[A VALIDAR]** | AC-110-6: **[A VALIDAR — PA-09]** .<br>AC-110-7: **[A VALIDAR — PA-09]** (Finanzas/Jurídico).<br>AC-110-8: **[A VALIDAR — PA-09]** .<br>Pregunta que bloquea: Política de pedidos, pedidos pendientes y reutilización del correo (PA-09, Finanzas/Jurídico). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-091 · Eliminar cuenta con error de red o servidor

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-110-9 |
| RF / RNF | RF-110; RNF-027 |
| Objetivo | Verificar que no hay estado ambiguo cuando falla la eliminación. |
| Precondiciones | Cliente con sesión; `RED-OFF` y luego 503 simulado. |
| Procedimiento | 1. Confirmar la eliminación con `RED-OFF`.<br>2. Repetir con 503.<br>3. Comprobar que la cuenta sigue activa y que se puede reintentar. |
| Datos de prueba sintéticos | `CLI-DEL`. |
| Resultado esperado | Mensaje de que no se completó; cuenta activa; se puede reintentar; la app mantiene la sesión. |
| Criterio de aprobación | Estado consistente en ambos fallos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-092 · Cumplimiento de la guía de tiendas sobre eliminación de cuenta

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Manual · No |
| AC que cubre | AC-110-16 |
| RF / RNF | RF-110 |
| Objetivo | Confirmar que el flujo cumple el requisito vigente de las tiendas. |
| Precondiciones | Guías vigentes de Apple y Google descargadas el día de la revisión. |
| Procedimiento | 1. Leer la guía vigente de cada tienda sobre eliminación de cuenta.<br>2. Contrastar con el flujo implementado y con RNF-058.<br>3. Registrar el resultado con enlace y fecha de consulta. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Checklist completo y firmado por el responsable. |
| Criterio de aprobación | Evidencia con fecha. |
| **[A VALIDAR]** | AC-110-16: **[A VALIDAR — S-05]** vigencia.<br>Pregunta que bloquea: Vigencia de las guías de tiendas por verificar (S-05). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-093 · Perfil y contraseña: validaciones y doble toque

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | AC-104-5, AC-104-8, AC-105-1, AC-105-4, AC-105-8, AC-104-9 |
| RF / RNF | RF-104, RF-105; RNF-073 |
| Objetivo | Verificar validaciones locales, enmascarado y una sola solicitud. |
| Precondiciones | Perfil de `CLI-01` en widget test. |
| Procedimiento | 1. Escribir un correo inválido y guardar.<br>2. Tocar dos veces "Guardar".<br>3. En contraseña: abrir el formulario; usar nueva de 7 caracteres, confirmación distinta y nueva de 8 caracteres con confirmación igual.<br>4. Guardar cambios con `RED-OFF`. |
| Datos de prueba sintéticos | `CLI-01`; `Qa12345`, `Qa123456`. |
| Resultado esperado | Error sin solicitud para correo inválido; 1 sola solicitud; tres campos enmascarados; 7 caracteres y confirmación distinta rechazados sin solicitud; sin red los cambios escritos se conservan sin aplicarse. |
| Criterio de aprobación | Todos los casos correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-094 · Cambio de correo con contraseña actual reemite la sesión

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-104-1, AC-104-2 |
| AC de tipo Seguridad (regresión funcional complementaria; diseño en `06_security/security_testing.md`) | AC-104-3, AC-104-4, AC-105-2, AC-105-5 |
| RF / RNF | RF-104, RF-105; RNF-040 |
| Objetivo | Verificación funcional de que el cambio exige contraseña actual y reemite el token. El diseño de abuso lo cubre seguridad. |
| Precondiciones | Staging; `CLI-01` con sesión. |
| Procedimiento | 1. Ver el perfil (nombre, apellido, correo) y editar nombre y apellido; recargar.<br>2. Intentar cambiar el correo sin contraseña actual y con contraseña incorrecta.<br>3. Cambiar el correo con contraseña correcta.<br>4. Usar el token anterior contra una ruta autenticada.<br>5. Repetir la secuencia con el cambio de contraseña. |
| Datos de prueba sintéticos | `CLI-01`; correo nuevo sintético `qa.cliente.01b@example.test`. |
| Resultado esperado | Sin contraseña no se emite solicitud; con contraseña incorrecta el correo no cambia y el mensaje es genérico; con la correcta se emite sesión nueva y la app sigue autenticada; el token anterior devuelve 401. |
| Criterio de aprobación | Cuatro verificaciones correctas. |
| **[A VALIDAR]** | Pregunta que bloquea: Si el correo nuevo ya pertenece a otra cuenta (AC-104-6) depende de PA-02; no se incluye en este caso. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-095 · Contraseña nueva igual a la actual

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-105-9 |
| RF / RNF | RF-105 |
| Objetivo | Documentar el comportamiento. |
| Precondiciones | Staging; `CLI-01`. |
| Procedimiento | 1. Cambiar la contraseña usando como nueva la misma actual. |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | Comportamiento definido (rechazar o aceptar) y mensaje acorde. |
| Criterio de aprobación | Se registra lo observado; se aprueba al definirlo. |
| **[A VALIDAR]** | AC-105-9: **[A VALIDAR — propuesta de PA nueva]** .<br>Pregunta que bloquea: Comportamiento no definido (propuesta de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-096 · Direcciones de facturación y envío

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | AC-106-1, AC-106-2, AC-106-3, AC-106-4, AC-106-7, AC-106-8 |
| RF / RNF | RF-106; RNF-084 |
| Objetivo | Verificar campos, reglas de validación, selector de ubicación y prellenado del checkout. |
| Precondiciones | Perfil de `CLI-01`; repositorio simulado; datos de ubicación de Colombia de los fixtures. |
| Procedimiento | 1. Abrir la gestión de direcciones y verificar los campos de facturación y envío.<br>2. Validar cédula/NIT `000-000-001`, `ab`, 31 caracteres; nombre de 61 caracteres; dirección de 201; teléfono de 6 y 21 caracteres.<br>3. Elegir un departamento y verificar que la ciudad depende de él y que solo existe Colombia.<br>4. Guardar dos veces rápido y con `RED-OFF`.<br>5. Iniciar compra y verificar el prellenado (ver TC-075). |
| Datos de prueba sintéticos | `CLI-01`; valores del paso 2. |
| Resultado esperado | Reglas del contrato de dirección respetadas; ciudad dependiente del departamento; 1 sola solicitud; sin red se conservan los datos escritos. |
| Criterio de aprobación | Reglas verificadas. Los campos obligatorios en el perfil quedan pendientes. |
| **[A VALIDAR]** | AC-106-2: **[A VALIDAR — propuesta de PA nueva]** qué campos son obligatorios en el perfil (el contrato web marca como opcionales empresa, dirección 2 y código postal).<br>Pregunta que bloquea: Qué campos son obligatorios en el perfil (el contrato web marca como opcionales empresa, dirección 2 y código postal). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-097 · Canal de derechos del titular

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-111-1, AC-111-2, AC-111-3, AC-111-5 |
| RF / RNF | RF-111; RNF-059 |
| Objetivo | Verificar acceso, envío al destinatario corporativo y mensaje sobre eliminación directa. |
| Precondiciones | Perfil de `CLI-01`; canal definido por Jurídico. |
| Procedimiento | 1. Abrir "Derechos sobre mis datos".<br>2. Enviar una solicitud de tipo consulta.<br>3. Verificar su llegada al destinatario corporativo.<br>4. Repetir con `RED-OFF`. |
| Datos de prueba sintéticos | `CLI-01`. |
| Resultado esperado | Acceso desde el perfil; la solicitud llega con el tipo elegido y se muestra confirmación; informa que la eliminación puede hacerse en la app; sin red se conserva lo escrito. |
| Criterio de aprobación | Llegada comprobada en el buzón de prueba. |
| **[A VALIDAR]** | AC-111-2: **[A VALIDAR — D-12]** canal vigente (DESCONOCIDO).<br>Pregunta que bloquea: Canal vigente DESCONOCIDO (D-12). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-098 · Cambio de correo a uno que ya pertenece a otra cuenta

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-104-6 |
| RF / RNF | RF-104, RF-045 |
| Objetivo | Documentar el mensaje y el código ante correo duplicado. |
| Precondiciones | Staging; `CLI-01` y `CLI-02`. |
| Procedimiento | 1. Desde `CLI-01` intentar cambiar el correo al de `CLI-02` con contraseña correcta. |
| Datos de prueba sintéticos | `CLI-01`, `CLI-02`. |
| Resultado esperado | Se rechaza con un mensaje definido. El contrato propuesto responde `409 email_in_use` (revela existencia, RA-11). |
| Criterio de aprobación | Se registra lo observado; se aprueba al decidir. |
| **[A VALIDAR]** | AC-104-6: **[A VALIDAR — PA-02]** equilibrio entre no revelar existencia de cuentas (RF-045) y claridad para el usuario.<br>Pregunta que bloquea: Equilibrio entre no revelar la existencia de cuentas (RF-045) y claridad para el usuario (PA-02). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo G — Resiliencia: errores 404 frente a 503, sin red y degradación (US-009, US-026, RNF-020 a RNF-023)

Distingue "no existe" de "no disponible". Regla propuesta en api_architecture §6.3: el BFF devuelve 404 solo con respuesta definitiva de WooCommerce; las caídas se traducen a 503, 502 o 504, y un dato vencido se sirve con `X-IPR-Data-State: stale`.

#### TC-099 · Sin red en pantallas de contenido remoto

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-009-1, AC-009-3, AC-009-7 |
| RF / RNF | RF-009; RNF-020, RNF-027 |
| Objetivo | Verificar mensaje no técnico, reintento sin reiniciar y que error y vacío son estados distintos. |
| Precondiciones | `RED-OFF`; pantallas: inicio, listado, ficha, sedes, búsqueda y filtro. |
| Procedimiento | 1. Abrir cada pantalla sin red y leer el mensaje.<br>2. Restablecer la red y pulsar "Reintentar".<br>3. En búsqueda y filtro, provocar el fallo y verificar que no se muestra "sin resultados". |
| Datos de prueba sintéticos | — |
| Resultado esperado | Mensaje en lenguaje no técnico (sin códigos HTTP, trazas ni nombres de servidor) con "Reintentar"; al reintentar con red el contenido carga y desaparece el mensaje; en búsqueda/filtro se muestra error y no vacío. |
| Criterio de aprobación | 6 pantallas verificadas. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-100 · Error 5xx, timeout o breaker abierto

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-009-2, AC-002-3, AC-010-6, AC-072-5 |
| RF / RNF | RF-009; RNF-022, RNF-027 |
| Objetivo | Verificar el mismo tratamiento que sin red y que la app no se cierra. |
| Precondiciones | BFF simulado con respuestas 500, 503 con `Retry-After`, 504 y tiempo agotado. |
| Procedimiento | 1. Abrir inicio, categorías y sedes con cada respuesta.<br>2. Observar mensaje y botón.<br>3. Verificar que la app no se cierra y que no hay cuadrícula vacía sin mensaje. |
| Datos de prueba sintéticos | Respuestas problem+json sintéticas. |
| Resultado esperado | Mensaje con "Reintentar"; sin cierres; sin pantallas vacías sin explicación. |
| Criterio de aprobación | 4 respuestas × 3 pantallas sin fallos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-101 · Falla la carga de la tercera página de un listado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-009-5, AC-011-6 |
| RF / RNF | RF-009, RF-011 |
| Objetivo | Verificar conservación de lo cargado y reintento solo de esa página. |
| Precondiciones | Listado con 2 páginas cargadas; la tercera responde 503. |
| Procedimiento | 1. Desplazar hasta el final para pedir la página 3.<br>2. Observar los productos y el control de reintento.<br>3. Reintentar con éxito.<br>4. Verificar duplicados y pérdidas. |
| Datos de prueba sintéticos | Categoría `QA-CAT-MIXTA` extendida a 60 productos (fixtures). |
| Resultado esperado | Los productos ya cargados siguen visibles; se ofrece reintentar solo esa página; sin duplicados ni pérdida. |
| Criterio de aprobación | Conteo final = 60 sin repetidos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-102 · Ningún error de red o servidor borra el carrito

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-009-4 |
| RF / RNF | RF-009, RF-049; RNF-031 |
| Objetivo | Verificar la regla de oro: las fallas no provocan borrado de datos locales. |
| Precondiciones | Carrito `C3`. |
| Procedimiento | 1. Provocar en secuencia: sin red, timeout, 500, 503, 401 con refresh fallido y 404 en un ítem.<br>2. Después de cada uno, reintentar y abrir el carrito. |
| Datos de prueba sintéticos | `C3`. |
| Resultado esperado | Tras cada error y reintento el carrito conserva las mismas líneas y cantidades. |
| Criterio de aprobación | 6 de 6 escenarios con carrito idéntico. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-103 · Producto eliminado (404) frente a fallo de red en la ficha

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-026-6, AC-026-7 |
| RF / RNF | RF-026; RNF-022 |
| Objetivo | Verificar "Producto no disponible" para 404 definitivo y error con reintento para 503/sin red. |
| Precondiciones | BFF simulado: 404 `not_found`; 503 `upstream_unavailable`; `RED-OFF`. |
| Procedimiento | 1. Abrir la ficha con cada respuesta.<br>2. En el 404 pulsar la acción de volver.<br>3. En 503 pulsar "Reintentar". |
| Datos de prueba sintéticos | Producto sintético inexistente. |
| Resultado esperado | 404: "Producto no disponible" con acción de volver y sin texto técnico; 503 y sin red: error con "Reintentar", sin afirmar que el producto no existe. |
| Criterio de aprobación | Los tres comportamientos distintos verificados. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-104 · Semántica 404 / 502 / 503 / 504 del BFF

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Contrato · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-022, RNF-023; api_architecture §6.3 (ADR-016) |
| Objetivo | Verificar que una caída nunca se presenta como "no existe" ni como lista vacía. Caso sin AC directo: se traza a RNF. |
| Precondiciones | BFF con WooCommerce simulado (WireMock/MSW o servidor propio de la suite, NO VERIFICADO) y staging para humo. |
| Procedimiento | 1. Pedir `GET /products/{slug}` de un producto publicado: 200.<br>2. Pedir un slug que WooCommerce confirma inexistente o no publicado: 404 `not_found`.<br>3. Apagar WooCommerce simulado (conexión rechazada): 503/502/504 con `Retry-After`, nunca 404.<br>4. Con dato en caché vencido y WooCommerce caído: 200 con `X-IPR-Data-State: stale`.<br>5. Abrir el breaker y pedir un listado: 503 o 200 `stale`, nunca 200 con lista vacía.<br>6. Reiniciar el proceso y pedir búsqueda antes de que el índice esté listo: 503 `catalog_index_warming` con `Retry-After: 5`. |
| Datos de prueba sintéticos | Producto `QA-0001`; slug `qa-no-existe`. |
| Resultado esperado | Cada situación produce el código indicado; 0 respuestas 200 vacías por fallo ascendente (RNF-022/023). |
| Criterio de aprobación | 6 de 6 situaciones conforme; falla = defecto S1 de contrato (puede causar borrado indebido en el carrito, RA-02). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-105 · Datos obsoletos con aviso (StaleBanner)

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-022; flutter_app_architecture §7.4 |
| Objetivo | Verificar que un dato vencido se muestra marcado como posiblemente desactualizado. Caso sin AC directo. |
| Precondiciones | Repositorio simulado que emite dato `stale`. |
| Procedimiento | 1. Renderizar un listado con `dataState: stale`.<br>2. Verificar el banner y que la acción de compra no usa ese precio como autoridad. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Banner "Mostrando información guardada; puede no estar actualizada." visible; la revalidación del carrito sigue siendo obligatoria. |
| Criterio de aprobación | Banner presente y compra condicionada a revalidación. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-106 · Lectura sin conexión de lo ya visitado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-020; DN-10 |
| Objetivo | Verificar que inicio, listados y fichas vistos, sedes y carrito se abren sin red y sin fallar. |
| Precondiciones | Contenido visitado con red; luego `RED-OFF`. |
| Procedimiento | 1. Visitar inicio, 2 listados, 3 fichas y sedes con red.<br>2. Activar `RED-OFF` y reabrir cada uno.<br>3. Cronometrar el aviso de falta de conexión. |
| Datos de prueba sintéticos | — |
| Resultado esperado | 100 % de las pantallas del alcance se abren sin fallar con aviso de desactualización (≤ 3 s, RNF-020); el pago indica que exige conexión. |
| Criterio de aprobación | Todas las pantallas del alcance abren. |
| **[A VALIDAR]** | Pregunta que bloquea: El alcance exacto de la lectura sin conexión depende de DN-10. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-107 · Flujos críticos bajo perfiles de red

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Rendimiento · Sí (emulación de red) + manual |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-083, RNF-003, RNF-021 |
| Objetivo | Verificar que los flujos críticos se completan sin cierres bajo Wi-Fi, 4G lenta, red degradada e intermitente. |
| Precondiciones | Dispositivos de la matriz; perfiles `RED-4G-LENTA` (≈1,6 Mbps, 150 ms RTT), `RED-DEGRADADA` (≈400 kbps, RTT ≥ 400 ms) e `RED-INTERMITENTE` (cortes de 5 a 15 s). |
| Procedimiento | 1. Ejecutar bajo cada perfil: inicio → búsqueda → ficha → añadir → login → pagar (hasta abrir el navegador).<br>2. Cronometrar el contenido útil de listado y ficha.<br>3. Registrar cierres inesperados, ANR y mensajes. |
| Datos de prueba sintéticos | `CLI-01`, `P-PRECIO`. |
| Resultado esperado | El flujo se completa sin cierres inesperados en los 4 perfiles; contenido p90 ≤ 2,0 s con caché acertada y ≤ 4,0 s con fallo de caché en 4G lenta (umbrales provisionales de RNF-003). |
| Criterio de aprobación | 0 cierres y tiempos dentro del umbral; los valores medidos se registran en test_results.md. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo H — Búsqueda: texto, SKU, sugerencias y sin resultados (US-020 a US-023)

#### TC-108 · Búsqueda por SKU exacto en staging

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-022-1, AC-022-2, AC-022-5 |
| RF / RNF | RF-022; RNF-110 |
| Objetivo | Verificar que el SKU exacto devuelve el producto en primera posición, con variantes de mayúsculas y espacios, y que un SKU inexistente da el estado vacío. |
| Precondiciones | Staging con catálogo sintético; `P-PRECIO` (SKU `QA-0001`). |
| Procedimiento | 1. Buscar `QA-0001`, `qa-0001` y ` QA-0001 ` (con espacios).<br>2. Verificar la posición del producto.<br>3. Buscar `QA-9999` (inexistente). |
| Datos de prueba sintéticos | SKU sintéticos. |
| Resultado esperado | En las 3 variantes `QA-0001` aparece en la primera posición; `QA-9999` muestra el estado vacío con WhatsApp. |
| Criterio de aprobación | Posición 1 en las 3 variantes. El criterio de la posición exacta y el ranking quedan pendientes de verificación en staging. |
| **[A VALIDAR]** | AC-022-1: **[A VALIDAR — RF-022]** "primeras posiciones" no está cuantificado y el ranking actual es DESCONOCIDO; el criterio propone posición 1 y se confirma al verificar en staging.<br>Pregunta que bloquea: "Primeras posiciones" no está cuantificado y el ranking actual es DESCONOCIDO (RF-022). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-109 · SKU con guiones o espacios distintos del registrado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-022-3 |
| RF / RNF | RF-022 |
| Objetivo | Documentar el comportamiento ante variaciones de formato. |
| Precondiciones | Staging; SKU `QA-0001`. |
| Procedimiento | 1. Buscar `QA0001`, `QA 0001` y `QA--0001`. |
| Datos de prueba sintéticos | SKU sintéticos. |
| Resultado esperado | Resultado determinista y documentado (encontrar o no encontrar). |
| Criterio de aprobación | Se registra lo observado. |
| **[A VALIDAR]** | AC-022-3: **[A VALIDAR — propuesta de PA nueva]** (tolerancia a variaciones de formato).<br>Pregunta que bloquea: Tolerancia a variaciones de formato (propuesta de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-110 · Muestra de SKUs reales de IPR

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Manual · Sí (script sobre staging con la lista entregada) |
| AC que cubre | AC-022-4 |
| RF / RNF | RF-022; RNF-110 |
| Objetivo | Verificar que el 100 % de la muestra devuelve su producto en la posición definida. |
| Precondiciones | Lista de SKUs reales entregada por IPR (no se incluye en este documento). |
| Procedimiento | 1. Ejecutar la búsqueda de cada SKU de la muestra.<br>2. Registrar la posición y los fallos. |
| Datos de prueba sintéticos | Muestra de IPR (objetivo de referencia: 100 SKUs, RNF-110). |
| Resultado esperado | 100 % en la posición definida. |
| Criterio de aprobación | Cero fallos en la muestra; el tamaño final de la muestra se acuerda con IPR. |
| **[A VALIDAR]** | AC-022-4: **[A VALIDAR — RF-022]** tamaño de la muestra.<br>Pregunta que bloquea: Tamaño de la muestra por acordar (RF-022). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-111 · Búsqueda por texto: resultados, vacío de entrada y sin sesión

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | AC-020-1, AC-020-2, AC-020-3, AC-020-7, AC-020-6 |
| AC de tipo Seguridad (regresión funcional complementaria; diseño en `06_security/security_testing.md`) | AC-020-4 |
| RF / RNF | RF-020; RNF-044 |
| Objetivo | Verificar relevancia básica, paginación, entrada vacía, acceso sin sesión y caracteres especiales. |
| Precondiciones | Staging; visitante. |
| Procedimiento | 1. Buscar por nombre, marca y referencia de productos sintéticos.<br>2. Desplazar hasta pedir la segunda página.<br>3. Enviar un campo vacío y uno de espacios.<br>4. Buscar `' " < > % & #` y `válvula`.<br>5. Provocar fallo de red en la búsqueda. |
| Datos de prueba sintéticos | Términos sintéticos. |
| Resultado esperado | Resultados paginados; vacío y espacios no emiten solicitud y mantienen el foco; caracteres especiales codificados sin error ni interpretación como marcado; fallo de red muestra error y no vacío. |
| Criterio de aprobación | Los 5 pasos correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-112 · Equivalencia con y sin tildes

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-020-5 |
| RF / RNF | RF-020, RF-022 |
| Objetivo | Documentar el comportamiento. |
| Precondiciones | Staging con un producto cuyo nombre contiene `válvula`. |
| Procedimiento | 1. Buscar `válvula` y `valvula`. |
| Datos de prueba sintéticos | Producto sintético. |
| Resultado esperado | Equivalencia documentada. |
| Criterio de aprobación | Se registra lo observado. |
| **[A VALIDAR]** | AC-020-5: **[A VALIDAR — propuesta de PA nueva]** (tolerancia a tildes y errores: DESCONOCIDA, ver RF-022).<br>Pregunta que bloquea: Tolerancia a tildes y errores DESCONOCIDA (propuesta de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-113 · Sugerencias: orden de respuestas, fallo y borrado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Unitaria · Sí |
| AC que cubre | AC-021-2, AC-021-4, AC-021-5, AC-021-1, AC-021-3 |
| RF / RNF | RF-021; RNF-012 |
| Objetivo | Verificar que solo se muestran las sugerencias del último término y que la búsqueda no depende de las sugerencias. |
| Precondiciones | Controlador de sugerencias con respuestas simuladas fuera de orden. |
| Procedimiento | 1. Escribir `ab` y luego `abc`; entregar primero la respuesta de `abc` y después la de `ab`.<br>2. Simular fallo del servicio de sugerencias y enviar la búsqueda.<br>3. Borrar el texto. |
| Datos de prueba sintéticos | Respuestas sintéticas. |
| Resultado esperado | Se muestran solo las de `abc`; la búsqueda funciona sin error bloqueante; al vaciar el campo desaparecen las sugerencias. Mínimo de caracteres, retraso (la arquitectura propone 300 ms y 2 caracteres) y destino al tocar quedan pendientes. |
| Criterio de aprobación | Orden correcto y búsqueda funcional. |
| **[A VALIDAR]** | AC-021-1: **[A VALIDAR — propuesta de PA nueva]** número mínimo de caracteres y retraso de envío (debounce).<br>AC-021-3: **[A VALIDAR — propuesta de PA nueva]** (destino al tocar la sugerencia no definido).<br>Pregunta que bloquea: Número mínimo de caracteres, debounce y destino al tocar una sugerencia (propuestas de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-114 · Sin resultados: botón de WhatsApp con el término

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-023-1, AC-023-3, AC-023-4, AC-023-5, AC-023-6 |
| RF / RNF | RF-023; RNF-084 |
| Objetivo | Verificar el estado vacío real frente al error, y el botón de WhatsApp. |
| Precondiciones | Staging; visitante; término `qa-sin-resultados`. |
| Procedimiento | 1. Buscar un término sin resultados.<br>2. Verificar mensaje y botón de WhatsApp.<br>3. Tocar el botón y capturar la URL.<br>4. Sin WhatsApp verificar la alternativa.<br>5. Repetir con fallo de red y verificar que no aparece el botón con el término. |
| Datos de prueba sintéticos | Término sintético. |
| Resultado esperado | Mensaje de no encontrado con botón de WhatsApp que incluye el término; sin WhatsApp aplica la alternativa; ante fallo se muestra error con "Reintentar", no el vacío. |
| Criterio de aprobación | Cinco pasos correctos; el texto del mensaje queda pendiente. |
| **[A VALIDAR]** | AC-023-3: **[A VALIDAR — propuesta de PA nueva]** texto del mensaje (no existe en la web, que no describe estado vacío).<br>Pregunta que bloquea: Texto del mensaje prellenado de este estado no existe en la web (propuesta de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo I — Selección representativa del resto de historias

Una muestra por épica para asegurar que cada capa de la pirámide queda ejercitada. Los AC restantes se derivan según la regla de la sección 5.

#### TC-115 · Inicio: buscador, categorías, WhatsApp y marcas

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí (+ golden) |
| AC que cubre | AC-001-1, AC-001-2, AC-002-1, AC-002-2, AC-005-1, AC-004-1, AC-004-2, AC-005-4 |
| RF / RNF | RF-001, RF-002, RF-004, RF-005 |
| Objetivo | Verificar los accesos del inicio y su comportamiento sin sesión. |
| Precondiciones | Inicio con 8 categorías simuladas; visitante. |
| Procedimiento | 1. Renderizar el inicio y comprobar buscador y botón de WhatsApp visibles sin desplazar y con etiqueta accesible.<br>2. Tocar el buscador y verificar campo enfocado y teclado.<br>3. Verificar que el número de accesos de categorías es igual al número devuelto.<br>4. Tocar una categoría y verificar título.<br>5. Tocar marcas y WhatsApp como visitante. |
| Datos de prueba sintéticos | 8 categorías sintéticas. |
| Resultado esperado | Accesos visibles y etiquetados; navegación correcta; todo funciona sin sesión. |
| Criterio de aprobación | Todos los puntos verificados. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-116 · Categoría agregada en WooCommerce aparece sin nueva versión

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · E2E · Sí (parte de cambio en WooCommerce manual) |
| AC que cubre | AC-002-4, AC-019-1, AC-019-2 |
| RF / RNF | RF-002, RF-019; RNF-111 |
| Objetivo | Medir el tiempo real de refresco de catálogo, precio y stock. |
| Precondiciones | Staging; acceso de administración de WooCommerce de staging. |
| Procedimiento | 1. Agregar una categoría raíz sintética, cambiar el precio de `P-CAMBIO` y marcar `P-PRECIO` agotado.<br>2. Recargar el inicio y la ficha cada minuto hasta ver el cambio.<br>3. Registrar el tiempo transcurrido. |
| Datos de prueba sintéticos | `P-CAMBIO`, `P-PRECIO`, categoría `QA-CAT-NUEVA`. |
| Resultado esperado | Los cambios se reflejan sin publicar versión. El plazo máximo aceptable no está definido; el valor medido se registra (referencia: SWR de 5 min + borde de 5 min, RNF-111 propone p95 ≤ 10 min). |
| Criterio de aprobación | Tiempo medido registrado; la aprobación espera el plazo definido. |
| **[A VALIDAR]** | AC-002-4: **[A VALIDAR — PA-04]** (plazo).<br>AC-019-1: **[A VALIDAR — PA-04]** el plazo máximo aceptable es DESCONOCIDO; medir y registrar el tiempo real (web actual: revalidación por webhook y refresco del índice de búsqueda cada 5 min).<br>AC-019-2: **[A VALIDAR — PA-04]** .<br>Pregunta que bloquea: Plazo máximo aceptable de refresco (PA-04). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-117 · Navegación jerárquica de categorías y vacío

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-010-1, AC-010-2, AC-010-3, AC-010-4 |
| RF / RNF | RF-010; RNF-113 |
| Objetivo | Verificar subcategorías, productos de la hoja, retorno con scroll y categoría vacía; sin cabecera de autorización. |
| Precondiciones | Staging; visitante; categoría raíz con subcategorías y una categoría vacía. |
| Procedimiento | 1. Entrar raíz → subcategoría → hoja.<br>2. Retroceder y verificar posición de scroll.<br>3. Abrir la categoría vacía.<br>4. Revisar las cabeceras de las solicitudes. |
| Datos de prueba sintéticos | Categorías sintéticas. |
| Resultado esperado | Niveles correctos; retorno al nivel anterior con scroll conservado; mensaje de categoría vacía con acceso a la búsqueda; 0 cabeceras `Authorization`. |
| Criterio de aprobación | 4 pasos correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-118 · Carga progresiva sin duplicados ni solicitudes de más

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-011-2, AC-011-3, AC-011-8, AC-018-3 |
| RF / RNF | RF-011, RF-018 |
| Objetivo | Verificar solicitud única de página siguiente, fin del listado y ausencia de duplicados. |
| Precondiciones | Listado de 60 productos con tamaño de página de referencia 24 (valor propuesto); simulado con un ID repetido. |
| Procedimiento | 1. Desplazar al final de cada página y contar solicitudes.<br>2. Llegar a la última página y seguir desplazando.<br>3. Devolver una página con un ID repetido. |
| Datos de prueba sintéticos | Fixtures de 60 productos. |
| Resultado esperado | Una sola solicitud por página; sin repetidos; tras la última página 0 solicitudes y se indica el fin. |
| Criterio de aprobación | Conteos exactos. El tamaño de página queda pendiente. |
| **[A VALIDAR]** | AC-011-2: **[A VALIDAR — D-05/ADR-001]** el tamaño de página en la app (la web usa 12) no está definido.<br>Pregunta que bloquea: El tamaño de página en la app no está definido (D-05/ADR-001; la web usa 12 y la API propone 12, 24 o 48). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-119 · Tarjeta de producto: contenido, sin imagen y nombre largo

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Golden · Sí |
| AC que cubre | AC-011-1, AC-011-4, AC-011-7 |
| RF / RNF | RF-011; RNF-068, RNF-084 |
| Objetivo | Verificar la tarjeta en escala de texto 1,0 y 2,0 y a 360 dp. |
| Precondiciones | Alchemist con fuentes embebidas; `P-PRECIO`, `P-SINIMG`, `P-LARGO`. |
| Procedimiento | 1. Generar goldens de la tarjeta con cada producto a 360 dp y escala de texto 1,0 y 2,0.<br>2. Comparar con la referencia aprobada. |
| Datos de prueba sintéticos | `P-PRECIO`, `P-SINIMG`, `P-LARGO`. |
| Resultado esperado | Imagen, nombre, marca, SKU, precio con etiqueta de IVA incluido y stock presentes; marcador de posición sin romper el diseño; texto largo recortado sin desbordar. |
| Criterio de aprobación | Diferencia de píxeles dentro de la tolerancia configurada con la referencia aprobada. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-120 · Filtros por marca y categoría

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-013-1, AC-013-2, AC-013-3, AC-013-4, AC-013-5, AC-013-6 |
| RF / RNF | RF-013 |
| Objetivo | Verificar intersección, chips removibles, sin resultados, conservación en error y paginación con filtro. |
| Precondiciones | Staging; categoría con productos de 2 marcas. |
| Procedimiento | 1. Aplicar la marca X y comparar el contador con el servidor.<br>2. Aplicar marca y categoría a la vez.<br>3. Quitar un filtro y usar "Limpiar filtros".<br>4. Aplicar una combinación sin productos.<br>5. Provocar un fallo al filtrar.<br>6. Avanzar de página con el filtro. |
| Datos de prueba sintéticos | Marcas sintéticas `QA-MARCA-A` y `QA-MARCA-B`. |
| Resultado esperado | Todos los productos cumplen los filtros; chips visibles y removibles; mensaje de sin resultados con limpiar; en el fallo se conserva el listado previo; las páginas siguientes respetan el filtro. |
| Criterio de aprobación | 6 pasos correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-121 · Orden por precio con productos sin precio

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-015-2, AC-015-3, AC-015-4 |
| RF / RNF | RF-015 |
| Objetivo | Verificar reinicio de paginación, conservación de filtros y posición de los productos sin precio. |
| Precondiciones | Staging; listado con productos sin precio. |
| Procedimiento | 1. Cambiar el orden a precio ascendente con un filtro aplicado.<br>2. Cargar la página siguiente.<br>3. Observar dónde quedan los productos sin precio. |
| Datos de prueba sintéticos | Categoría `QA-CAT-MIXTA`. |
| Resultado esperado | Recarga desde la primera página con filtros conservados; sin reordenar lo ya mostrado. Dónde van los sin precio queda pendiente (AP-06 propone aceptar el comportamiento de WooCommerce: primero en ascendente, inferencia). |
| Criterio de aprobación | Comportamiento documentado. |
| **[A VALIDAR]** | AC-015-4: **[A VALIDAR — propuesta de PA nueva]** (dónde se ubican los productos sin precio).<br>Pregunta que bloquea: Posición de los productos sin precio al ordenar por precio (propuesta de PA nueva; AP-06). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-122 · Ficha: galería, stock genérico, cantidad y avisos

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí (+ golden) |
| AC que cubre | AC-026-1, AC-026-2, AC-026-3, AC-026-4, AC-029-1, AC-032-1 |
| RF / RNF | RF-026, RF-029, RF-032 |
| Objetivo | Verificar el contenido de la ficha de un producto con precio y en stock. |
| Precondiciones | `P-PRECIO` con 4 imágenes; `P-SINIMG`. |
| Procedimiento | 1. Renderizar la ficha y verificar galería, nombre, marca, SKU, precio con "IVA incluido" y estado de stock.<br>2. Deslizar la galería y verificar el indicador.<br>3. Verificar que solo se muestra "En stock" o "Agotado", sin cantidades.<br>4. Verificar selector con valor 1 y botón; aviso de envío "valor según transportadora".<br>5. Abrir la ficha sin imágenes. |
| Datos de prueba sintéticos | `P-PRECIO`, `P-SINIMG`. |
| Resultado esperado | Contenido según el AC; sin cantidades de stock; marcador de posición sin error. |
| Criterio de aprobación | Golden aprobado y verificaciones correctas. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-123 · Descripción: formato legítimo y secciones

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | AC-027-3, AC-027-5, AC-027-6, AC-028-1, AC-028-2 |
| RF / RNF | RF-027, RF-028 |
| Objetivo | Verificar el renderizado de HTML legítimo ya saneado, sin descripción y con ambas descripciones. |
| Precondiciones | `flutter_widget_from_html_core` (SPK-04); fixtures de descripción. |
| Procedimiento | 1. Renderizar párrafos, listas, negritas y tablas.<br>2. Renderizar un producto sin descripción ni atributos.<br>3. Renderizar descripción corta y larga. |
| Datos de prueba sintéticos | HTML sintético sin contenido activo. |
| Resultado esperado | Formato básico conservado; secciones vacías omitidas; ambas descripciones en secciones distintas. El corpus de payloads XSS (AC-027-1/2/4) lo diseña seguridad y se ejecuta como puerta de CI. |
| Criterio de aprobación | Tres escenarios correctos. |
| **[A VALIDAR]** | AC-028-1: **[A VALIDAR — D-10]** en la muestra revisada no se vieron atributos estructurados; la cobertura real depende de la calidad del catálogo.<br>Pregunta que bloquea: La cobertura real de atributos estructurados depende de la calidad del catálogo (D-10). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-124 · Sedes: agrupación, próximamente y acciones

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | AC-072-2, AC-072-3, AC-073-1, AC-073-2, AC-074-4, AC-074-5, AC-072-6 |
| RF / RNF | RF-072, RF-073, RF-074 |
| Objetivo | Verificar sedes en operación, "próximamente" y datos faltantes. |
| Precondiciones | Fixtures de sedes sintéticas (3 ciudades, una sede próximamente, una sin WhatsApp, una sin teléfono de repuestos, una ciudad sin sedes). |
| Procedimiento | 1. Renderizar el listado agrupado por ciudad.<br>2. Verificar la etiqueta "Próximamente" y la ausencia de botones en esa sede.<br>3. Abrir la ficha de una sede completa y de una con datos faltantes. |
| Datos de prueba sintéticos | Sedes `QA-SEDE-1` a `QA-SEDE-5` con direcciones y teléfonos ficticios. |
| Resultado esperado | Agrupación por ciudad sin grupos vacíos; "Próximamente" sin acciones; teléfonos faltantes omitidos sin "null"; sin WhatsApp no hay botón. |
| Criterio de aprobación | Escenarios correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-125 · Llamar, WhatsApp y Cómo llegar

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí (lanzador simulado) + manual en dispositivo |
| AC que cubre | AC-074-1, AC-074-2, AC-075-1, AC-075-2, AC-075-3 |
| RF / RNF | RF-074, RF-075 |
| Objetivo | Verificar URLs de teléfono, WhatsApp y mapas, codificación y alternativas. |
| Precondiciones | `url_launcher` simulado; dirección `Calle 0 # 0-00, Local 1, Ciudad de Prueba` con tildes, `#`, `&` y comas. |
| Procedimiento | 1. Tocar Llamar y capturar `tel:`.<br>2. Tocar WhatsApp y capturar el destino.<br>3. Tocar Cómo llegar y decodificar la URL.<br>4. Simular ausencia de app de mapas. |
| Datos de prueba sintéticos | Sede sintética. |
| Resultado esperado | Marcador con el número sin marcar; WhatsApp con el número de la sede; URL de mapas decodificada igual a la dirección; sin app de mapas se abre el navegador sin error. La verificación manual de la ubicación (AC-075-5) es posterior. |
| Criterio de aprobación | URLs correctas y alternativas verificadas. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-126 · Sede nueva en la fuente aparece sin recompilar

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · E2E · Sí (cambio en la fuente manual) |
| AC que cubre | AC-076-1, AC-076-3, AC-076-4 |
| RF / RNF | RF-076; RNF-029 |
| Objetivo | Verificar que cambios de sedes llegan sin nueva versión y que datos faltantes no rompen la pantalla. |
| Precondiciones | Staging con la fuente de sedes definida. |
| Procedimiento | 1. Crear una sede sintética en la fuente, otra "próxima" y otra con un campo faltante.<br>2. Esperar el plazo de actualización y abrir Sedes.<br>3. Verificar cada una. |
| Datos de prueba sintéticos | `QA-SEDE-6` a `QA-SEDE-8`. |
| Resultado esperado | Aparecen sin publicar versión; la "próxima" se muestra como "Próximamente"; la de campo faltante se muestra sin fallar. |
| Criterio de aprobación | Tres sedes correctas; el plazo medido se registra. |
| **[A VALIDAR]** | AC-076-1: **[A VALIDAR — D-09, PA-04]** mecanismo de la fuente (DESCONOCIDO) y plazo.<br>Pregunta que bloquea: Mecanismo de la fuente (DESCONOCIDO) y plazo (D-09, PA-04). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-127 · Calculadora BTU: rangos, casos T1 a T10 y monotonía

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Unitaria · Sí |
| AC que cubre | AC-085-2, AC-085-3, AC-085-4, AC-086-1, AC-086-2, AC-086-3, AC-086-4, AC-088-4 |
| RF / RNF | RF-085, RF-086, RF-088; RNF-092 |
| Objetivo | Verificar la fórmula con la tabla de referencia y los límites. Se ejecuta solo tras la validación de Ingeniería; hasta entonces el módulo está fuera del MVP. |
| Precondiciones | Lógica de dominio de la calculadora; tabla T1 a T10 del AC-086-1 más ≥ 20 casos de límite (total ≥ 30, RNF-092). |
| Procedimiento | 1. Validar los límites aceptados y rechazados (largo y ancho 0,9/1/15/15,1; alto 1,9/2/4/4,1; ocupantes 0/1/10/11; equipos -1/0/10/11).<br>2. Calcular T1 a T10 y comparar requerido (±1 BTU) y sugerido.<br>3. Verificar `alto = 2,5` sin recargo y `2,51` con recargo 0,10.<br>4. Verificar monotonía con áreas crecientes y requerido exactamente igual a una capacidad.<br>5. Entradas vacías, no numéricas y decimales en ocupantes. |
| Datos de prueba sintéticos | Tabla T1 a T10 del AC-086-1 (valores esperados derivados de COD §6, no validados). |
| Resultado esperado | Todos los casos coinciden con los esperados; T9 y T10 sin sugerencia; T2 y T8 sugieren la misma capacidad; entradas inválidas rechazadas con error y sin cálculo. |
| Criterio de aprobación | Todos los casos pasan y la cobertura del módulo es ≥ 90 %. |
| **[A VALIDAR]** | AC-085-4: **[A VALIDAR — D-08]** confirmar que ocupantes y equipos son enteros.<br>AC-086-1: **[A VALIDAR — D-08]** valores validados por Ingeniería.<br>Pregunta que bloquea: Fórmula, rangos, valores esperados y si ocupantes y equipos son enteros dependen de la validación de Ingeniería (D-08). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-128 · Calculadora BTU: aviso, más de 36.000 BTU y enlace al catálogo

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Widget · Sí |
| AC que cubre | AC-087-1, AC-087-2, AC-088-1, AC-088-3, AC-089-4, AC-089-1, AC-089-5 |
| RF / RNF | RF-087, RF-088, RF-089 |
| Objetivo | Verificar el aviso de estimación, el caso sin sugerencia y el filtro por capacidad. |
| Precondiciones | Resultados simulados T4 (24.000), T9 (sin sugerencia). |
| Procedimiento | 1. Mostrar el resultado de T4: aviso de estimación y enlace "Ver equipos" con filtro de capacidad 24.000.<br>2. Mostrar T9: aviso, mensaje de capacidad máxima sin "0 BTU" ni "undefined", contacto con asesor y sin enlace al catálogo.<br>3. Verificar el filtro construido para las 5 capacidades comerciales. |
| Datos de prueba sintéticos | Resultados sintéticos. |
| Resultado esperado | Aviso visible sin acción adicional en ambos casos; en T9 sin enlace; el filtro se construye con el valor correcto para cada capacidad. |
| Criterio de aprobación | Verificaciones correctas; textos finales pendientes. |
| **[A VALIDAR]** | AC-087-1: **[A VALIDAR — D-08]** texto exacto aprobado por Ingeniería.<br>AC-089-5: **[A VALIDAR — D-10, RF-014]** disponibilidad del atributo en el catálogo.<br>Pregunta que bloquea: Texto del aviso, valores de la tabla y disponibilidad del atributo de capacidad (D-08, D-10, RF-014). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-129 · PQRS: límites de campos y contador

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Unitaria · Sí |
| AC que cubre | AC-096-2, AC-096-3 |
| RF / RNF | RF-096; RNF-044 |
| Objetivo | Verificar los límites de validación del contrato de la web. |
| Precondiciones | Validador de PQRS. |
| Procedimiento | 1. Nombre de 2, 3, 120 y 121 caracteres.<br>2. Correo inválido y de 255 caracteres.<br>3. Celular de 6, 7, 20, 21 caracteres y con letras.<br>4. Pedido de 61 caracteres.<br>5. Mensaje vacío, 1 y 1.000 y 1.001 caracteres; intentar escribir el carácter 1.001. |
| Datos de prueba sintéticos | Cadenas sintéticas. |
| Resultado esperado | Se rechaza o acepta según los límites; el carácter 1.001 no se admite y el contador muestra 1.000/1.000. |
| Criterio de aprobación | Todos los límites verificados. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-130 · PQRS: envío, doble toque, sin red y falla de correo

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-096-4, AC-096-5, AC-096-7, AC-096-8, AC-096-10, AC-096-1, AC-096-11 |
| RF / RNF | RF-096; RNF-027 |
| Objetivo | Verificar confirmación, una sola solicitud, conservación de datos y mensajes de error. |
| Precondiciones | BFF simulado: 202, 500 y `RED-OFF`; visitante. |
| Procedimiento | 1. Abrir el formulario y revisar tipos, campos y contador.<br>2. Enviar un formulario válido y tocar dos veces.<br>3. Enviar sin red.<br>4. Enviar con 500 del servicio de correo. |
| Datos de prueba sintéticos | `CLI-NEW` (nombre y correo sintéticos), mensaje de 40 caracteres. |
| Resultado esperado | Confirmación y formulario limpio; 1 sola solicitud; sin red y con 500 los datos se conservan y no se presenta como enviado; funciona sin autenticación. El aviso de política de datos antes del envío depende de Jurídico. |
| Criterio de aprobación | Cinco escenarios correctos. |
| **[A VALIDAR]** | AC-096-11: **[A VALIDAR — D-12]** si Jurídico exige aviso o aceptación en este formulario (el formulario recoge nombre, correo y teléfono).<br>Pregunta que bloquea: Si Jurídico exige aviso o aceptación en este formulario (D-12). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-131 · PQRS llega al buzón corporativo

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · E2E · No (revisión de buzón de prueba) |
| AC que cubre | AC-097-1, AC-097-2 |
| RF / RNF | RF-097 |
| Objetivo | Verificar asunto, contenido, zona horaria y Reply-To. |
| Precondiciones | Staging con buzón de PQRS de pruebas. |
| Procedimiento | 1. Enviar una PQRS desde la app.<br>2. Revisar el correo recibido.<br>3. Responder y verificar el destinatario. |
| Datos de prueba sintéticos | `CLI-NEW`. |
| Resultado esperado | Asunto `[PQRS] <tipo> — <nombre>`; contiene tipo, nombre, correo, teléfono, pedido/factura, mensaje y fecha-hora en America/Bogota; la respuesta va al correo del solicitante. |
| Criterio de aprobación | Correo conforme. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-132 · Todos los enlaces legales cargan

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí (verificación nocturna) |
| AC que cubre | AC-099-3, AC-099-2 |
| RF / RNF | RF-099 |
| Objetivo | Verificar HTTP 200 y contenido no vacío de cada documento y acceso desde el menú. |
| Precondiciones | Lista de documentos legales publicados por IPR. |
| Procedimiento | 1. Abrir el menú y verificar los accesos.<br>2. Solicitar cada URL y comprobar estado y contenido. |
| Datos de prueba sintéticos | URLs de los documentos entregadas por IPR. |
| Resultado esperado | Todos responden 200 con contenido no vacío. |
| Criterio de aprobación | 0 enlaces rotos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-133 · Ayuda y contacto: accesos y acciones

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Widget · Sí |
| AC que cubre | AC-094-1, AC-095-1, AC-095-2, AC-064-1, AC-005-2 |
| RF / RNF | RF-094, RF-095, RF-064, RF-005 |
| Objetivo | Verificar que Ayuda agrupa los canales y que cada acceso realiza su acción. |
| Precondiciones | Pantalla de Ayuda; lanzador simulado. |
| Procedimiento | 1. Verificar WhatsApp, PQRS, teléfono, correo institucional y sedes.<br>2. Tocar cada uno y capturar la acción.<br>3. Verificar "Cotizar por WhatsApp" en inicio y Ayuda. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Cada acceso abre su destino (WhatsApp con mensaje no vacío, PQRS, marcador sin marcar, `mailto:` institucional, sedes). |
| Criterio de aprobación | Cinco accesos correctos; número y texto vigentes pendientes. |
| **[A VALIDAR]** | AC-005-2: **[A VALIDAR — PA-07]** número vigente y texto final; el SLA no se promete en pantalla.<br>Pregunta que bloquea: Número vigente y texto final del WhatsApp (PA-07). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-134 · Webhook de revalidación firmado y caída del webhook

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-019-3, AC-019-4 |
| RF / RNF | RF-019; RNF-111, RNF-112 |
| Objetivo | Verificar invalidación de caché con firma válida, rechazo con firma inválida y actualización aunque el webhook falle. |
| Precondiciones | BFF en staging o de pruebas con `/api/revalidate`; secreto del webhook de prueba (nunca el de producción). |
| Procedimiento | 1. Emitir un webhook con firma válida tras cambiar un producto y consultar el BFF.<br>2. Emitir uno con firma inválida y verificar el rechazo y que la caché no se invalida.<br>3. Cambiar el producto sin webhook y esperar el plazo máximo de caché. |
| Datos de prueba sintéticos | `P-CAMBIO`. |
| Resultado esperado | Firma válida invalida solo ese producto; firma inválida se rechaza; sin webhook el dato se actualiza al vencer la caché. |
| Criterio de aprobación | Tres comportamientos verificados; el plazo máximo queda pendiente. |
| **[A VALIDAR]** | AC-019-4: **[A VALIDAR — PA-04]** .<br>Pregunta que bloquea: Plazo máximo de caché aceptable (PA-04). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-135 · Liquidaciones: precios regular y especial

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-018-1, AC-018-2, AC-018-5, AC-018-6 |
| RF / RNF | RF-018 |
| Objetivo | Verificar precio regular y especial, filtrado solo de ofertas, precio vigente en el carrito y estado vacío. |
| Precondiciones | Staging con `P-OFERTA`; segundo escenario sin ofertas. |
| Procedimiento | 1. Abrir Liquidaciones y verificar los dos precios diferenciables.<br>2. Comparar con la respuesta del servidor: solo ofertas.<br>3. Añadir `P-OFERTA` al carrito y abrir el carrito tras cambiar su precio especial.<br>4. Abrir Liquidaciones sin ofertas. |
| Datos de prueba sintéticos | `P-OFERTA`. |
| Resultado esperado | Dos precios distintos; solo productos en oferta; el carrito usa el precio vigente del servidor; mensaje de no hay liquidaciones vigentes. |
| Criterio de aprobación | Cuatro escenarios correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-136 · Directorio de marcas y productos por marca

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-016-1, AC-016-2, AC-016-3, AC-016-4, AC-016-5 |
| RF / RNF | RF-016 |
| Objetivo | Verificar el listado, la navegación y la búsqueda interna por marca. |
| Precondiciones | Staging; visitante; `QA-MARCA-A` con productos y una marca sin productos. |
| Procedimiento | 1. Abrir el directorio y contar marcas frente al servidor.<br>2. Abrir una marca y desplazar.<br>3. Buscar dentro de la marca.<br>4. Abrir la marca sin productos. |
| Datos de prueba sintéticos | `QA-MARCA-A`. |
| Resultado esperado | Número de marcas igual al del servidor; paginación; resultados solo de la marca; mensaje sin productos; sin autenticación. |
| Criterio de aprobación | Cuatro pasos correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-137 · Filtros por atributos técnicos

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-014-1, AC-014-2, AC-014-3, AC-014-4 |
| RF / RNF | RF-014 |
| Objetivo | Verificar que las opciones y los resultados corresponden a lo que entrega el servidor. |
| Precondiciones | Staging; categoría con atributo filtrable "capacidad BTU" y otra sin atributos. |
| Procedimiento | 1. Abrir el panel de filtros y comparar las opciones con la respuesta de `/filters`.<br>2. Seleccionar un valor y verificar los resultados.<br>3. Combinar con una marca.<br>4. Abrir una categoría sin atributos. |
| Datos de prueba sintéticos | Atributos que entregue el servidor de pruebas. |
| Resultado esperado | Opciones iguales a las del servidor; resultados con el valor; intersección con marca; sin sección vacía. |
| Criterio de aprobación | Cuatro pasos correctos. |
| **[A VALIDAR]** | AC-014-1: **[A VALIDAR — D-10]** la lista de atributos filtrables (`search-facets`, `filter-context` de la web) no está confirmada; la prueba se limita a los atributos que entregue `/mobile/v1`.<br>Pregunta que bloquea: La lista de atributos filtrables no está confirmada; calidad del catálogo (D-10). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-138 · Conteo de sedes y acceso sin sesión

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-072-1, AC-072-4 |
| RF / RNF | RF-072; RNF-114, RNF-115 |
| Objetivo | Verificar que las sedes mostradas coinciden con la fuente oficial. |
| Precondiciones | Staging con la fuente de sedes; visitante. |
| Procedimiento | 1. Abrir Sedes y contar las agrupadas por ciudad.<br>2. Comparar con la fuente oficial entregada por IPR. |
| Datos de prueba sintéticos | Fuente oficial de IPR. |
| Resultado esperado | Total mostrado igual al de la fuente y agrupación por ciudad; sin autenticación. |
| Criterio de aprobación | Igualdad de conteo con la fuente oficial. |
| **[A VALIDAR]** | AC-072-1: **[A VALIDAR — D-07, D-09]** las cifras 31/32 sedes no concuerdan entre fuentes; se valida contra la fuente oficial que entregue IPR.<br>Pregunta que bloquea: Las cifras 31 y 32 sedes no concuerdan entre fuentes (D-07, D-09). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-139 · Asesoría técnica y contacto corporativo

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Widget · Sí |
| AC que cubre | AC-079-1, AC-079-3, AC-079-4, AC-080-1, AC-080-3, AC-080-4 |
| RF / RNF | RF-079, RF-080 |
| Objetivo | Verificar contenido de servicios de ingeniería y canales corporativos de contacto. |
| Precondiciones | Pantalla de asesoría con contenido simulado; lanzador simulado. |
| Procedimiento | 1. Abrir la sección como visitante.<br>2. Verificar los servicios de aire acondicionado y refrigeración y la acción de contacto.<br>3. Tocar el correo (sin cliente de correo) y el teléfono PBX. |
| Datos de prueba sintéticos | Contenido sintético. |
| Resultado esperado | Contenido y acción de contacto presentes sin sesión; PBX abre el marcador sin marcar; correo abre el cliente o, sin cliente, ofrece copiar. |
| Criterio de aprobación | Verificaciones correctas; fuente del contenido y canal de ingeniería pendientes. |
| **[A VALIDAR]** | AC-079-1: **[A VALIDAR — ADR-001]** fuente del contenido (hoy está en el repositorio web; no hay API).<br>AC-080-1: **[A VALIDAR — PA-06]** si existe un canal corporativo propio de ingeniería; mientras no se confirme, se usa el WhatsApp de asesoría general (RF-094).<br>AC-080-3: **[A VALIDAR — propuesta de PA nueva]** comportamiento sin cliente de correo.<br>Pregunta que bloquea: Fuente del contenido (ADR-001), existencia de canal corporativo de ingeniería (PA-06) y comportamiento sin cliente de correo (propuesta de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-140 · Calculadora BTU: pantalla de entradas

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Widget · Sí |
| AC que cubre | AC-085-1, AC-085-5, AC-085-6, AC-085-7 |
| RF / RNF | RF-085 |
| Objetivo | Verificar campos, valores iniciales, formato decimal y funcionamiento sin sesión ni red. |
| Precondiciones | Calculadora en widget test; `RED-OFF`. |
| Procedimiento | 1. Abrir la calculadora y verificar los campos (largo, ancho, alto, ocupantes, equipos y clima).<br>2. Escribir alto `2,5` y `2.5` y comparar el comportamiento.<br>3. Verificar los valores iniciales.<br>4. Calcular sin red y sin sesión. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Campos presentes; mismo comportamiento ante coma y punto; cálculo local sin red. |
| Criterio de aprobación | Verificaciones correctas; valores iniciales y formato decimal pendientes. |
| **[A VALIDAR]** | AC-085-5: **[A VALIDAR — propuesta de PA nueva]** formato decimal (configuración regional es-CO).<br>AC-085-6: **[A VALIDAR — D-08]** valor por defecto y valores iniciales de los demás campos.<br>AC-085-7: **[A VALIDAR — propuesta de PA nueva]** si la fórmula debe vivir en el cliente o en el BFF.<br>Pregunta que bloquea: Valores por defecto (D-08), formato decimal es-CO y si la fórmula vive en el cliente o en el BFF (propuestas de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-141 · Paridad de la calculadora con la web

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Unitaria · Sí |
| AC que cubre | AC-086-5 |
| RF / RNF | RF-086; RNF-092 |
| Objetivo | Comparar 20 combinaciones aleatorias con semilla fija entre la web y la app. |
| Precondiciones | Resultados de referencia de la web para las mismas entradas. |
| Procedimiento | 1. Generar 20 combinaciones con semilla fija.<br>2. Calcular en la app y comparar con la web. |
| Datos de prueba sintéticos | Combinaciones sintéticas. |
| Resultado esperado | Resultados idénticos. |
| Criterio de aprobación | 20 de 20 idénticos. |
| **[A VALIDAR]** | AC-086-5: **[A VALIDAR — D-08]** si la web actual sigue siendo la referencia.<br>Pregunta que bloquea: Si la web actual sigue siendo la referencia (D-08). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-142 · Inicio: bloque de más vendidos, calculadora y Liquidaciones

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Integración · Sí |
| AC que cubre | AC-003-1, AC-003-4, AC-003-5, AC-006-1, AC-006-2, AC-007-1, AC-007-2 |
| RF / RNF | RF-003, RF-006, RF-007 |
| Objetivo | Verificar los bloques opcionales del inicio y su falla aislada. |
| Precondiciones | BFF simulado; módulo K habilitado o no. |
| Procedimiento | 1. Cargar el inicio con el bloque de más vendidos y tocar una tarjeta.<br>2. Fallar solo ese bloque y verificar el resto del inicio.<br>3. Verificar el acceso a la calculadora con y sin D-08 cerrada.<br>4. Tocar Liquidaciones como visitante. |
| Datos de prueba sintéticos | Productos sintéticos. |
| Resultado esperado | Tarjetas con nombre, SKU, stock y precio o "Más información"; la falla del bloque no afecta al resto; la calculadora aparece solo si D-08 está cerrada. |
| Criterio de aprobación | Verificaciones correctas. |
| **[A VALIDAR]** | AC-003-1: **[A VALIDAR — PA-05]** el criterio de selección y el número de productos del bloque no están definidos; la prueba solo valida que se renderiza lo que entrega el servidor.<br>AC-006-2: **[A VALIDAR — D-08]** (si no se valida la fórmula, el módulo K sale del MVP).<br>Pregunta que bloquea: Criterio de selección y número de productos del bloque (PA-05) y validación de la fórmula (D-08). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-143 · Revisión humana de textos y contenidos

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P3 · Manual · No |
| AC que cubre | AC-032-2, AC-087-3, AC-094-4, AC-099-6, AC-097-6, AC-010-5, AC-075-5 |
| RF / RNF | RF-032, RF-087, RF-094, RF-099, RF-097, RF-010, RF-075 |
| Objetivo | Verificar a mano los textos aprobados, las promesas de respuesta, la política de privacidad pública, el buzón y la calidad de categorías y mapas. |
| Precondiciones | Textos aprobados por Jurídico, Ingeniería y Comercial; muestra de categorías y direcciones de *staging*. |
| Procedimiento | 1. Comparar el aviso de garantía y el aviso de estimación con el texto aprobado.<br>2. Revisar que no se promete un tiempo de respuesta en WhatsApp o PQRS.<br>3. Verificar la URL pública de política de privacidad para tiendas.<br>4. Verificar que el buzón de PQRS es el definido por IPR y es configurable.<br>5. Revisar la jerarquía de categorías y la ubicación de una muestra de sedes en mapas. |
| Datos de prueba sintéticos | Muestra de IPR. |
| Resultado esperado | Todos los puntos coinciden con lo aprobado; limitaciones documentadas. |
| Criterio de aprobación | Lista de verificación firmada con evidencia fechada. |
| **[A VALIDAR]** | AC-032-2: **[A VALIDAR — D-12]** el texto de garantía vigente es DESCONOCIDO.<br>AC-094-4: **[A VALIDAR — PA-07]** hasta que se defina el SLA y los responsables.<br>AC-099-6: **[A VALIDAR — S-05]** verificar las guías vigentes de Apple y Google.<br>AC-097-6: **[A VALIDAR — PA-07]** responsables y SLA de atención.<br>AC-010-5: **[A VALIDAR — D-10]** .<br>Pregunta que bloquea: Texto de garantía (D-12), texto del aviso de estimación (D-08), SLA y responsables (PA-07), guías de tiendas (S-05) y calidad del catálogo (D-10). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo J — Contrato y plan mínimo del backend (`/mobile/v1` y `ipr/v1/m`)

Hoy el backend móvil no existe y el repositorio web no tiene pruebas. Estos casos son la puerta mínima antes de integrar la app (ver testing_strategy.md §9).

#### TC-144 · Pruebas de contrato de cada endpoint contra el OpenAPI

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Contrato · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-085, RNF-090, RNF-096; ADR-001 verificación |
| Objetivo | Verificar que cada endpoint cumple su esquema en caso feliz, error y autenticación. |
| Precondiciones | OpenAPI `openapi.yaml` versionado; BFF en CI con WooCommerce y WordPress simulados; humo en staging. |
| Procedimiento | 1. Para cada operación del OpenAPI, ejecutar el caso feliz y validar la respuesta contra el esquema.<br>2. Ejecutar un caso de error (400/404/429/503) y validar `Problem`.<br>3. Para rutas autenticadas, ejecutar sin token (401) y con token válido.<br>4. Ejecutar el detector de cambios incompatibles contra la versión publicada. |
| Datos de prueba sintéticos | Fixtures derivados de los ejemplos del OpenAPI. |
| Resultado esperado | 100 % de los endpoints con los 3 tipos de caso en verde; 0 cambios incompatibles en `v1`. |
| Criterio de aprobación | Verde en CI; es puerta de merge del BFF. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-145 · DTO de producto: precio nulo, sin stock exacto y HTML saneado

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Unitaria · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RF-012, RF-027, RNF-107; FE-03 |
| Objetivo | Verificar que el BFF mapea precio 0 a `on_request` con `amount` nulo, nunca expone `stockQuantity`, roles ni claves, y sanea HTML. |
| Precondiciones | Mapeadores del BFF con objetos de WooCommerce sintéticos. |
| Procedimiento | 1. Mapear un producto con precio 0 y con precio positivo.<br>2. Mapear un producto con `stockQuantity` 5, nulo y negativo.<br>3. Mapear un producto cuya descripción contiene `<script>` e `<iframe>`.<br>4. Verificar los campos de la respuesta con una lista blanca. |
| Datos de prueba sintéticos | Productos sintéticos de WooCommerce. |
| Resultado esperado | `price.status = on_request` y `amount = null` para precio 0; la respuesta no incluye `stockQuantity`, `roles`, `username` ni metadatos crudos; el HTML no contiene elementos activos. |
| Criterio de aprobación | Todas las aserciones pasan; cobertura de líneas del módulo ≥ 80 % (RNF-090). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-146 · Validación estricta de entradas y token por URL

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Contrato · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-041, RNF-044; api_architecture §11 |
| Objetivo | Verificar rechazo de campos extra, tamaños máximos y tokens en la URL. |
| Precondiciones | BFF en CI. |
| Procedimiento | 1. Enviar `price`, `role` y `user_id` extra en registro, perfil y checkout.<br>2. Enviar cuerpo > 32 KB y `Content-Type` distinto de JSON.<br>3. Enviar `?token=` y `?access_token=` en rutas autenticadas.<br>4. Enviar `perPage` fuera de {12, 24, 48} y `page` > 50. |
| Datos de prueba sintéticos | Cuerpos sintéticos. |
| Resultado esperado | 400 `validation_failed`; 413; 415; 400 `token_in_url_forbidden`; `perPage` ajustado al permitido y `page` rechazado. |
| Criterio de aprobación | Todas las respuestas conforme al catálogo de códigos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-147 · Idempotencia y un ticket por intención en el BFF

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-024; api_architecture §9.2 |
| Objetivo | Verificar que la misma `Idempotency-Key` devuelve la misma respuesta durante 60 s y que una clave con cuerpo distinto da 409. |
| Precondiciones | BFF con `handoff-ticket` simulado y contador de llamadas. |
| Procedimiento | 1. Enviar `POST /checkout` dos veces con la misma clave y cuerpo.<br>2. Enviar la misma clave con cuerpo distinto.<br>3. Enviar tras 60 s. |
| Datos de prueba sintéticos | Cuerpos con `P-PRECIO`. |
| Resultado esperado | La segunda llamada devuelve la misma respuesta con 1 sola llamada a `handoff-ticket`; `409 idempotency_conflict` ante cuerpo distinto; tras 60 s se emite un ticket nuevo. |
| Criterio de aprobación | Contadores y códigos correctos. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-148 · WordPress `ipr/v1/m`: sesiones por dispositivo y rotación de refresh

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RF-043, RF-044; RNF-039, RNF-040; WP-01 |
| Objetivo | Verificar sesiones independientes, rotación con ventana de gracia y detección de reutilización. |
| Precondiciones | WordPress de staging o de pruebas con las tablas de sesión; pruebas por HTTP (el stack de pruebas de WordPress es NO VERIFICADO). |
| Procedimiento | 1. Iniciar sesión con 2 `X-Device-Id`.<br>2. Rotar el refresh de un dispositivo.<br>3. Reutilizar el refresh anterior dentro de 30 s y fuera de 30 s.<br>4. Revocar un dispositivo y revocar todos. |
| Datos de prueba sintéticos | `CLI-01`, dos identificadores de dispositivo sintéticos. |
| Resultado esperado | Sesiones independientes; reutilización dentro de la gracia devuelve un par nuevo; fuera de la gracia `401 refresh_token_reused` y sesión revocada; la revocación afecta solo lo indicado. |
| Criterio de aprobación | Seis de seis comportamientos conforme a authentication.md §15. Es parte de NL-05. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-149 · WordPress `ipr/v1/m`: límite de intentos persistente

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RF-045; RNF-042, RNF-017; WP-03 |
| Objetivo | Verificar contadores en base de datos, respuestas uniformes y expiración del bloqueo. |
| Precondiciones | WordPress de staging; cuenta existente e inexistente. |
| Procedimiento | 1. Superar el umbral de referencia en login con cuenta existente y con inexistente.<br>2. Reiniciar el proceso de PHP/servidor web.<br>3. Esperar `Retry-After` y reintentar con credenciales correctas. |
| Datos de prueba sintéticos | `CLI-01`; correo `qa.nadie@example.test`. |
| Resultado esperado | `429` con `Retry-After` idéntico en ambos casos; el contador sobrevive al reinicio; pasado el tiempo el usuario legítimo entra y el contador se restablece. |
| Criterio de aprobación | Comportamiento conforme. Umbral final pendiente de R-02 y MED-10. |
| Nota | Umbral de referencia: 5 fallos por cuenta en 15 min (api_architecture §10.2, propuesto). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-150 · WordPress `ipr/v1/m`: propiedad de pedidos y filtro por `checkout_ref`

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Integración · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RF-107, RF-108, RF-056; RNF-043; WP-07 |
| Objetivo | Verificar que solo se devuelven pedidos del usuario y que `checkout_ref` ajeno no devuelve pedido. |
| Precondiciones | WordPress de staging con pedidos de dos usuarios. |
| Procedimiento | 1. Listar pedidos paginados.<br>2. Pedir el detalle de un pedido ajeno.<br>3. Consultar `checkout_ref` propio y ajeno. |
| Datos de prueba sintéticos | `CLI-01`, `CLI-02`. |
| Resultado esperado | Solo pedidos propios; 404 en el ajeno; `checkout_ref` ajeno devuelve vacío. |
| Criterio de aprobación | Tres comprobaciones correctas. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-151 · Mapeo de estados de WooCommerce a `paymentState`

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Unitaria · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RF-056; api_architecture §13.2 |
| Objetivo | Verificar el mapeo de cada estado y el tratamiento de estados desconocidos. |
| Precondiciones | Función de mapeo del BFF. |
| Procedimiento | 1. Mapear `processing`, `completed`, `pending`, `on-hold`, `failed`, `cancelled`, `refunded` y un estado de plugin.<br>2. Verificar el `statusLabel` del estado desconocido. |
| Datos de prueba sintéticos | Estados sintéticos. |
| Resultado esperado | paid, paid, pending, pending, failed, cancelled, refunded y unknown respectivamente; el estado desconocido conserva su etiqueta. |
| Criterio de aprobación | 8 de 8 mapeos correctos. El mapeo de `on-hold` a pendiente es un supuesto (SA-06). |
| **[A VALIDAR]** | Pregunta que bloquea: Estados reales y el significado de `on-hold` dependen de PA-12. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-152 · Prueba de carga del BFF y no degradación de la web

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Rendimiento · Sí |
| AC que cubre | AC-019-6 |
| RF / RNF | RNF-014, RNF-015, RNF-016, RNF-018; ADR-001 C4 |
| Objetivo | Verificar capacidad con el perfil acordado sin degradar la web. Es condición NL-12. |
| Precondiciones | Staging con servidor comparable (MED-04); perfil de carga acordado (DN-07, MED-01). |
| Procedimiento | 1. Ejecutar la carga del perfil acordado sobre los endpoints móviles, con pico ×3.<br>2. Medir en paralelo p95 de la web.<br>3. Mantener 2 h y medir memoria, bucle de eventos y CPU.<br>4. Saturar `wcGet` y verificar el 503 con `Retry-After` en lugar de bloqueo. |
| Datos de prueba sintéticos | Perfil numérico pendiente. |
| Resultado esperado | 5xx < 1 %; breaker sin abrirse en el pico ×3; degradación de p95 de la web ≤ 10 %; crecimiento de memoria ≤ 5 %/h; bucle de eventos p99 ≤ 100 ms; CPU p95 ≤ 70 %; espera en cola p95 ≤ 1,0 s. |
| Criterio de aprobación | Todas las métricas dentro del umbral. Sin perfil de carga acordado no se puede ejecutar. |
| **[A VALIDAR]** | AC-019-6: **[A VALIDAR — ADR-001 C4]** perfil de tráfico y umbral.<br>Pregunta que bloquea: El perfil numérico de carga está pendiente (DN-07, MED-01); los umbrales de RNF-014 a RNF-018 son provisionales. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-153 · PQRS: contador compartido entre instancias y reinicios

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Integración · Sí |
| AC que cubre | AC-097-3, AC-097-4, AC-097-5 |
| RF / RNF | RF-097; RNF-017 |
| Objetivo | Verificar que el límite de 5 envíos se comparte y no depende de la memoria de un solo proceso. |
| Precondiciones | Dos instancias del BFF en staging detrás de un proxy. |
| Procedimiento | 1. Enviar 6 PQRS alternadas entre las dos instancias desde el mismo origen.<br>2. Reiniciar el proceso y enviar otra.<br>3. Verificar que se identifica la IP real del cliente. |
| Datos de prueba sintéticos | Origen de prueba. |
| Resultado esperado | La sexta recibe 429; el reinicio no restablece el contador (en la propuesta actual el límite del BFF está en memoria y la parte compartida vive en Cloudflare o WordPress, api_architecture §10.1); se identifica la IP real. |
| Criterio de aprobación | Comportamiento conforme o hallazgo registrado. |
| **[A VALIDAR]** | AC-097-5: **[A VALIDAR — propuesta de PA nueva]** cabecera de confianza.<br>Pregunta que bloquea: Cabecera de confianza para identificar la IP real (propuesta de PA nueva). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

### Grupo K — No funcionales: rendimiento, accesibilidad y compatibilidad

Umbrales tomados de los RNF (todos provisionales hasta MED-xx). Se miden siempre en builds profile o release, nunca en debug.

#### TC-154 · Arranque en frío y tibio

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Rendimiento · Sí (trazas en CI de dispositivos) + manual |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-001, RNF-002; MED-11 |
| Objetivo | Medir el arranque en el dispositivo de referencia. |
| Precondiciones | Build profile/release en el Android gama media-baja y el iPhone más antiguo soportado (se definen con MED-01). |
| Procedimiento | 1. Ejecutar 20 corridas de arranque en frío.<br>2. Ejecutar 20 corridas de arranque tibio y reanudación.<br>3. Calcular p90. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Frío p90 ≤ 3,0 s (límite duro 5 s); tibio p90 ≤ 1,5 s; reanudación ≤ 1,0 s. |
| Criterio de aprobación | Valores bajo el umbral; entre 3,0 y 5,0 s es condicional (NL-C1); ≥ 5 s es absoluto. |
| **[A VALIDAR]** | Pregunta que bloquea: Los umbrales son provisionales hasta MED-11 y el dispositivo de referencia depende de MED-01. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-155 · Fluidez, memoria y tamaño del build

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Rendimiento · Sí (DevTools/trazas) + manual |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-004, RNF-006, RNF-008, RNF-010 |
| Objetivo | Medir cuadros lentos, crecimiento de memoria y tamaño de la app. |
| Precondiciones | Build profile/release; listado de 100 ítems. |
| Procedimiento | 1. Desplazar el listado de 100 ítems y recorrer home → listado → ficha → carrito; medir cuadros lentos y congelados.<br>2. Repetir el recorrido 10 veces y medir memoria.<br>3. Medir el tamaño del build de cada plataforma. |
| Datos de prueba sintéticos | — |
| Resultado esperado | ≤ 5 % de cuadros lentos y 0 congelados; crecimiento de memoria ≤ 10 % y 0 cierres por memoria; ≤ 40 MB Android y ≤ 60 MB iOS. |
| Criterio de aprobación | Valores bajo el umbral; el tamaño es un supuesto de ingeniería no medido. |
| **[A VALIDAR]** | Pregunta que bloquea: El techo absoluto de memoria y el tamaño dependen de MED-11 (los umbrales son provisionales). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-156 · Peso de respuestas e imágenes

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P2 · Rendimiento · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-009, RNF-011; MED-07, MED-08 |
| Objetivo | Medir el tamaño de listados, fichas, imágenes y el consumo de datos de una sesión. |
| Precondiciones | Staging; caché frío; compresión activa. |
| Procedimiento | 1. Capturar una página de 20 productos y una ficha.<br>2. Medir la miniatura y la imagen principal.<br>3. Medir la sesión de referencia: home → búsqueda → 3 fichas → carrito. |
| Datos de prueba sintéticos | — |
| Resultado esperado | Página de 20 productos ≤ 50 KB sin comprimir; ficha ≤ 150 KB; miniatura ≤ 40 KB p90; imagen principal ≤ 200 KB p90; sesión ≤ 5 MB. |
| Criterio de aprobación | Valores bajo el umbral (estimación propia, MED-08). |
| **[A VALIDAR]** | Pregunta que bloquea: Los umbrales son provisionales hasta MED-07 y MED-08. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-157 · Guías de accesibilidad automáticas en pantallas críticas

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Accesibilidad · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-067, RNF-069, RNF-070, RNF-071, RNF-073, RNF-076 |
| Objetivo | Verificar con las guías de Flutter contraste, objetivos táctiles, etiquetas y formularios. |
| Precondiciones | Widget tests de login, registro, inicio, listado, ficha, carrito, resultado y eliminar cuenta. |
| Procedimiento | 1. Ejecutar `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` y `textContrastGuideline` en cada pantalla.<br>2. Verificar etiquetas visibles, `autofillHints` y errores asociados en formularios.<br>3. Verificar que ningún estado se comunica solo por color. |
| Datos de prueba sintéticos | Pantallas con fixtures sintéticos. |
| Resultado esperado | 0 incumplimientos en las pantallas críticas; objetivos ≥ 48 dp (Android) y 44 pt (iOS); texto ≥ 4,5:1. |
| Criterio de aprobación | Verde en CI. Las guías automáticas no sustituyen la prueba con lector de pantalla. |
| Nota | El contraste del verde de marca (≈ 3,0:1 sobre blanco según cálculo propio) es riesgo R-NF-08; se confirma con MED-12. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-158 · Flujos críticos con TalkBack, VoiceOver y texto al 200 %

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Accesibilidad · No |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-067, RNF-068, RNF-070, RNF-072, RNF-074, RNF-075; NL-14 |
| Objetivo | Verificar que login, compra y eliminar cuenta se completan con lector de pantalla y se mantienen usables al 200 % de texto. |
| Precondiciones | Android con TalkBack, iPhone con VoiceOver; escala de fuente 200 %; "reducir movimiento" activo. |
| Procedimiento | 1. Completar login, añadir al carrito, pagar (hasta el navegador seguro) y eliminar cuenta usando solo el lector de pantalla.<br>2. Repetir con texto al 200 %.<br>3. Verificar anuncios de cambios (carrito, errores), orden de foco, alternativas a gestos y respeto de "reducir movimiento". |
| Datos de prueba sintéticos | `CLI-01`, `CLI-DEL`. |
| Resultado esperado | Los tres flujos se completan; 0 desbordes ni pérdida de contenido al 200 %; los cambios se anuncian. |
| Criterio de aprobación | Tres flujos completados en ambas plataformas; si no se completa uno, es criterio de no-lanzamiento (NL-14). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-159 · Suite de humo en la matriz de dispositivos

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · Compatibilidad · Sí (granja o dispositivos) + manual |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-078, RNF-079, RNF-081, RNF-082, RNF-086 |
| Objetivo | Ejecutar el humo de flujos críticos en la matriz definida tras MED-01. |
| Precondiciones | Matriz objetivo: ≥ 8 dispositivos físicos (≥ 4 Android de gama baja/media/alta y ≥ 3 marcas, ≥ 3 iPhone incluido el más antiguo soportado, ≥ 1 tableta) más emuladores como complemento; un Android sin Chrome. |
| Procedimiento | 1. Instalar el build candidato en cada dispositivo.<br>2. Ejecutar el humo: inicio, búsqueda, ficha, carrito, login y apertura del checkout.<br>3. Verificar anchos desde 320 dp y layout adaptativo ≥ 600 dp.<br>4. Registrar defectos por dispositivo. |
| Datos de prueba sintéticos | `CLI-01`, `P-PRECIO`. |
| Resultado esperado | El humo pasa en el 100 % de los dispositivos de la matriz; sin desbordes en 320 dp. |
| Criterio de aprobación | Matriz completa verde. La lista concreta de dispositivos y las versiones mínimas se definen tras MED-01 y SPK-02. |
| **[A VALIDAR]** | Pregunta que bloquea: Versiones mínimas de Android e iOS y dispositivo de referencia pendientes (DN-01, MED-01, SPK-02). |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

#### TC-160 · Suite de regresión de humo por candidato a versión

| Campo | Detalle |
|---|---|
| Prioridad · Capa · Automatizable | P1 · E2E · Sí |
| AC que cubre | — (caso trazado solo a RNF/arquitectura) |
| RF / RNF | RNF-091, RNF-093 |
| Objetivo | Garantizar que cada candidato a versión ejecuta la regresión mínima de flujos críticos. |
| Precondiciones | Pipeline de CI; staging disponible. |
| Procedimiento | 1. Ejecutar los casos P1 de las capas Integración y E2E.<br>2. Comparar con la ejecución anterior.<br>3. Registrar fallos nuevos y recurrencias. |
| Datos de prueba sintéticos | — |
| Resultado esperado | 100 % de los casos P1 en verde antes del release. |
| Criterio de aprobación | Cero casos P1 fallidos o bloqueados. |
| RESULTADO OBTENIDO | **NO EJECUTADO** |
| Evidencia | — |
| Estado | **Pendiente** |

---

## 7. Decisiones pendientes que bloquean la aprobación de casos

| Marca | Casos afectados |
|---|---|
| [A VALIDAR — ADR-001 C1/C2] | TC-071, TC-082 |
| [A VALIDAR — ADR-001 C4] | TC-152 |
| [A VALIDAR — ADR-001 §2] | TC-015, TC-020, TC-027 |
| [A VALIDAR — ADR-001] | TC-139 |
| [A VALIDAR — D-02, PA-12] | TC-080 |
| [A VALIDAR — D-04] | TC-055 |
| [A VALIDAR — D-05/ADR-001] | TC-118 |
| [A VALIDAR — D-07, D-09] | TC-138 |
| [A VALIDAR — D-08] | TC-127, TC-128, TC-140, TC-141, TC-142 |
| [A VALIDAR — D-09, PA-04] | TC-126 |
| [A VALIDAR — D-10, RF-014] | TC-128 |
| [A VALIDAR — D-10] | TC-123, TC-137, TC-143 |
| [A VALIDAR — D-12, PA-10] | TC-006 |
| [A VALIDAR — D-12] | TC-008, TC-035, TC-097, TC-130, TC-143 |
| [A VALIDAR — PA-01] | TC-061 |
| [A VALIDAR — PA-02] | TC-007, TC-098 |
| [A VALIDAR — PA-03] | TC-013 |
| [A VALIDAR — PA-04] | TC-116, TC-134 |
| [A VALIDAR — PA-05] | TC-142 |
| [A VALIDAR — PA-06] | TC-139 |
| [A VALIDAR — PA-07] | TC-133, TC-143 |
| [A VALIDAR — PA-09, D-12] | TC-087 |
| [A VALIDAR — PA-09] | TC-089, TC-090 |
| [A VALIDAR — PA-11, D-02] | TC-070, TC-073 |
| [A VALIDAR — PA-11] | TC-073 |
| [A VALIDAR — PA-12] | TC-059, TC-079, TC-085 |
| [A VALIDAR — RF-022] | TC-108, TC-110 |
| [A VALIDAR — S-05] | TC-092, TC-143 |
| [A VALIDAR — propuesta de PA nueva] | TC-005, TC-016, TC-024, TC-038, TC-045, TC-052, TC-065, TC-074, TC-084, TC-088, TC-095, TC-096, TC-109, TC-112, TC-113, TC-114, TC-121, TC-139, TC-140, TC-153 |

Además, los casos con pregunta propia (campo "Pregunta que bloquea") dependen de DN-01, DN-07, DN-10, PA-01 a PA-12 y D-02, D-08 a D-12, según su ficha.

*Fin del documento. BORRADOR: ningún caso fue ejecutado.*

# Registro de resultados de pruebas — App móvil IPR (MVP)

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Calidad. No se programa nada. |
| **Fecha de este documento** | 2026-11-18 |
| **Estado** | PLANTILLA. Sin ciclos ejecutados |
| **Rol** | Ingeniería de QA Automation |
| **Relacionados** | [test_cases.md](test_cases.md) (160 casos) · [testing_strategy.md](testing_strategy.md) · [quality_metrics.md](quality_metrics.md) |

---

## 1. Estado actual: nada se ha ejecutado

> **HOY NO SE HA EJECUTADO NINGUNA PRUEBA. TODAS LAS PRUEBAS ESTÁN PENDIENTES.**
> No existe la app, no existe el backend `/mobile/v1` y no hay un entorno *staging* confirmado. Este documento no contiene resultados: contiene la plantilla para registrarlos cuando existan, con las reglas que impiden declarar como aprobado algo sin evidencia.

| Indicador | Valor hoy |
|---|---|
| Ciclos de prueba ejecutados | **0** |
| Casos de prueba definidos | 160 |
| Casos ejecutados | **0** |
| Casos aprobados | **0** |
| Casos fallidos | **0** |
| Casos bloqueados | **0** |
| Casos pendientes | **160 de 160 (100 %)** |
| AC con un resultado de ejecución | **0 de 490** |
| Defectos registrados | 0 (no hay nada contra qué registrar defectos) |
| Cobertura de código medida | **Sin medición** (la app no existe) |

Los valores de esta tabla solo cambian cuando se agrega un ciclo en la sección 7 con evidencia adjunta.

---

## 2. Estados permitidos

| Estado | Significado | ¿Cuenta como aprobado? |
|---|---|---|
| **Pendiente** | No se ha intentado ejecutar | No |
| **En ejecución** | Iniciado en un ciclo, sin cerrar | No |
| **Aprobado** | Se ejecutó el procedimiento completo, el resultado coincide con el esperado y existe evidencia adjunta | **Sí** |
| **Aprobado parcial** | Solo para casos con **[A VALIDAR]**: se aprobó la parte determinista y queda pendiente el umbral o el texto por decidir | **No** (se informa aparte) |
| **Fallido** | El resultado difiere del esperado; exige un defecto vinculado | No |
| **Bloqueado** | No se pudo ejecutar (entorno, dato, defecto previo, decisión pendiente); exige motivo y responsable | No |
| **No aplica** | El caso no corresponde a la versión o al alcance; exige justificación aprobada | No (se excluye del denominador solo con justificación) |

---

## 3. Campos obligatorios de cada ejecución

Una ejecución sin **todos** estos campos no es válida y su caso permanece "Pendiente".

| Campo | Descripción |
|---|---|
| **ID de ciclo** | `CIC-nnn`, correlativo |
| **TC** | Identificador del caso (`TC-nnn`) |
| **AC y RF/RNF** | Los del caso |
| **Fecha y hora** | Fecha y hora de la ejecución (zona America/Bogota) |
| **Versión** | Versión de la app (`X-App-Version`) y número de *build*; versión del BFF y de `ipr/v1` |
| **Entorno** | `dev`, `staging` o `prod` (solo lectura); URL base |
| **Flavor y tipo de *build*** | `dev`, `staging` o `prod`; *debug*, *profile* o *release* (el rendimiento solo vale en *profile* o *release*) |
| **Dispositivo** | Marca, modelo y sistema operativo con versión; físico, emulador o granja |
| **Red** | `Wi-Fi`, `RED-4G-LENTA`, `RED-DEGRADADA`, `RED-INTERMITENTE` o `RED-OFF` |
| **Datos de prueba** | Cuentas y productos sintéticos usados (códigos de la sección 3 de `test_cases.md`) |
| **Ejecutor** | Persona o *job* de CI (con enlace a la ejecución) |
| **Resultado obtenido** | Descripción de lo observado |
| **Resultado** | Estado de la sección 2 |
| **Evidencia** | Enlace o ruta a la evidencia (sección 6); obligatoria para "Aprobado" y "Fallido" |
| **Defecto** | Identificador del defecto si el resultado es "Fallido" |
| **Notas** | Desviaciones del procedimiento |

---

## 4. Reglas de registro

1. **Nada se marca "Aprobado" sin evidencia adjunta y sin fecha, versión, entorno y dispositivo.** Si falta cualquiera, el estado permanece "Pendiente".
2. **El resultado obtenido siempre se redacta a partir de lo observado**, nunca copiando el resultado esperado.
3. Un caso con **[A VALIDAR]** no puede quedar "Aprobado": como máximo "Aprobado parcial", con la pregunta pendiente (PA-xx, D-xx) citada.
4. Un caso se aprueba solo si **todos** sus pasos y su criterio de aprobación se cumplen en la misma ejecución.
5. La evidencia **no contiene** tokens, contraseñas ni datos personales reales; se enmascara antes de adjuntar.
6. Las ejecuciones automatizadas se registran con el enlace al *job* de CI y al reporte; un resultado de CI sin reporte adjunto no cuenta como evidencia.
7. Un cambio de versión o de entorno invalida la evidencia anterior: cada candidato a versión repite los casos P1 (QG-R01).
8. Un caso "Fallido" genera un defecto con severidad (S1 a S4) y no se vuelve a marcar "Aprobado" hasta repetir el caso y su regresión relacionada.
9. Un caso "Bloqueado" registra motivo, responsable y fecha prevista; no se cuenta como aprobado ni como fallido.
10. No se modifica un registro cerrado; las correcciones se hacen con una nueva ejecución y una nota.
11. Los resultados de seguridad se referencian desde `06_security/security_testing.md` (con su evidencia) y no se copian ni se resumen aquí sin enlace.
12. Solo el responsable de QA cierra un ciclo, tras la verificación de integridad de la sección 9.

---

## 5. Cálculo de indicadores del ciclo

| Indicador | Fórmula |
|---|---|
| Tasa de ejecución | casos con resultado distinto de "Pendiente" ÷ casos planificados del ciclo |
| Tasa de aprobación | casos "Aprobado" ÷ casos ejecutados (excluye "Aprobado parcial" y "Bloqueado") |
| Tasa de aprobación P1 | casos P1 "Aprobado" ÷ casos P1 planificados (el release exige 100 %, QG-R01) |
| AC verificados | AC cuyos casos están todos "Aprobado" (un AC con un caso "Aprobado parcial" o fallido no cuenta) |
| Cobertura de AC (diseño) | AC con caso desarrollado ÷ 490; **es una medida del diseño, no de la calidad del producto** |

---

## 6. Evidencia

| Tipo de caso | Evidencia mínima |
|---|---|
| Unitaria, Widget, Golden, Integración, Contrato | Enlace al *job* de CI, reporte de pruebas con el nombre `TC-nnn · AC-xxx-n`, reporte de cobertura; en golden, la imagen de referencia y la imagen actual |
| E2E | Video o capturas por paso, registro de la ejecución, número de pedido de WooCommerce (sandbox) y su estado, `X-Request-Id` de las solicitudes relevantes |
| Rendimiento | Archivo de traza, número de corridas, dispositivo, tipo de *build*, valor p90 calculado |
| Accesibilidad | Grabación de pantalla con el lector de pantalla activo, escala de texto usada, lista de verificación |
| Manual | Lista de verificación firmada con fecha, capturas y fuente del texto aprobado (por ejemplo, versión de la política) |
| Seguridad | Evidencia de `06_security/security_testing.md` |

Convención de nombres de archivo (propuesta): `CIC-nnn/TC-nnn/<plataforma>-<fecha>-<n>.<ext>`. Retención: mientras la versión esté publicada y 12 meses adicionales (propuesta; a validar con Jurídico y TI).

---

## 7. Plantilla de ciclo

> Copiar este bloque por cada ciclo. **No hay ciclos ejecutados**; el bloque siguiente está vacío a propósito.

### CIC-000 — Plantilla (no es un ciclo real)

| Campo | Valor |
|---|---|
| ID de ciclo | CIC-nnn |
| Objetivo del ciclo | (candidato a versión, regresión nocturna, piloto…) |
| Versión de la app / *build* | — |
| Versión del BFF y de `ipr/v1` | — |
| Entorno y URL base | — |
| Fechas (inicio – fin) | — |
| Responsable | — |
| Casos planificados | — |
| Dispositivos de la matriz usados | — |

**Resultados por caso**

| TC | AC | Capa | Fecha y hora | Versión / *build* | Entorno | Dispositivo y SO | Red | Ejecutor | Resultado | Evidencia | Defecto | Notas |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | |

**Resumen del ciclo**

| Capa | Planificados | Aprobados | Aprobados parciales | Fallidos | Bloqueados | Pendientes |
|---|---|---|---|---|---|---|
| Unitaria | | | | | | |
| Widget y Golden | | | | | | |
| Integración | | | | | | |
| Contrato | | | | | | |
| E2E | | | | | | |
| Rendimiento | | | | | | |
| Accesibilidad | | | | | | |
| Compatibilidad | | | | | | |
| Manual | | | | | | |
| **Total** | | | | | | |

**Defectos del ciclo**

| ID | Severidad | TC / AC | Título | Estado | Responsable | Fecha de apertura | Fecha de cierre |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

**Casos bloqueados y decisiones pendientes**

| TC | Motivo | Decisión o dato que falta (PA-xx, D-xx, C-x) | Responsable | Fecha prevista |
|---|---|---|---|---|
| | | | | |

**Evaluación de puertas de release (solo en candidatos a versión)**

| Puerta | Resultado | Evidencia |
|---|---|---|
| QG-R01 a QG-R15 | | |

**Cierre del ciclo**

| Elemento | Valor |
|---|---|
| Verificación de integridad (sección 9) realizada por | |
| Fecha de cierre | |
| Decisión recomendada por QA (aprobar, aprobar con condiciones, rechazar) | |

---

## 8. Registro de ciclos

| Ciclo | Fecha | Versión / *build* | Objetivo | Planificados | Aprobados | Fallidos | Bloqueados | Resultado global |
|---|---|---|---|---|---|---|---|---|
| — | — | — | **Ningún ciclo ejecutado** | 0 | 0 | 0 | 0 | — |

---

## 9. Verificación de integridad al cerrar un ciclo

Lista que cumple QA antes de firmar el cierre:

- [ ] Todo caso "Aprobado" tiene evidencia adjunta, fecha, versión, entorno y dispositivo.
- [ ] Ningún caso con [A VALIDAR] figura como "Aprobado" (solo "Aprobado parcial").
- [ ] Todo caso "Fallido" tiene un defecto con severidad.
- [ ] Todo caso "Bloqueado" tiene motivo, responsable y fecha.
- [ ] Los casos P1 del ciclo están todos ejecutados (o el motivo está registrado).
- [ ] Las versiones de la app y del BFF coinciden con las de la evidencia.
- [ ] La evidencia no contiene datos personales reales ni secretos.
- [ ] Los resultados de seguridad se referencian con enlace y fecha.
- [ ] El resumen del ciclo coincide con el detalle por caso.

---

## 10. Matriz AC → resultado (a generar)

Cuando exista el primer ciclo, un script de CI generará esta matriz a partir de los nombres de las pruebas y del registro de resultados. **Hoy:**

| Concepto | Valor |
|---|---|
| AC del MVP | 490 |
| AC con al menos un resultado de ejecución | **0** |
| AC verificados | **0** |
| AC de seguridad con resultado en `06_security/security_testing.md` | No evaluado en este documento |

---

## 11. Plantilla de registro de defecto

| Campo | Valor |
|---|---|
| ID | DEF-nnn |
| Título | |
| Severidad (S1 a S4, ver `testing_strategy.md` §8) | |
| TC y AC afectados | |
| Versión y *build* | |
| Entorno | |
| Dispositivo y SO | |
| Red | |
| Datos de prueba usados | |
| Pasos para reproducir | |
| Resultado esperado | |
| Resultado obtenido | |
| Evidencia (sin datos personales) | |
| `X-Request-Id` (si hay llamada al BFF) | |
| Estado | Nuevo / Triage / Asignado / En corrección / Listo para verificar / Verificado / Cerrado / Rechazado / Duplicado / No reproducible |
| Responsable | |
| Fecha de apertura / cierre | |
| ¿Es una decisión pendiente? (si el comportamiento depende de una pregunta [A VALIDAR], se registra como decisión, no como defecto) | |

*Fin del documento. PLANTILLA: ningún caso fue ejecutado.*

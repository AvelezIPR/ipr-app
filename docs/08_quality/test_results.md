# Registro de resultados de pruebas — App móvil IPR (MVP)

| | |
|---|---|
| **Proyecto** | App móvil Flutter (Android/iOS) de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | Ejecución local automatizada M0–M5 (`PT-19` + `PT-20`, ciclo `CIC-001` abierto). Sin *staging* ni dispositivos físicos. |
| **Fecha de este documento** | 2026-11-23 |
| **Estado** | **CIC-001 EN EJECUCIÓN** (verificación local en verde · pendiente cierre QA, CI remoto, *staging* y dispositivos reales) |
| **Rol** | Ingeniería de QA Automation / Trazabilidad |
| **Relacionados** | [test_cases.md](test_cases.md) (160 casos) · [testing_strategy.md](testing_strategy.md) · [quality_metrics.md](quality_metrics.md) · [security_testing.md](../06_security/security_testing.md) · [pt19_pt20_resultados.md](../project/pt19_pt20_resultados.md) |

---

## 1. Estado actual: CIC-001 en ejecución local (pendiente *staging*, dispositivos y cierre QA)

> **EL CÓDIGO FLUTTER LOCAL M0–M5 EXISTE Y PASA 9/9 PUERTAS LOCALES (`2159/2159` PRUEBAS), PERO EL CICLO SIGUE ABIERTO.**
> Aún no existen el backend real `/mobile/v1`, *staging* (`C2`), Wompi *sandbox*, dispositivos físicos probados ni ejecución en CI remoto. Por regla de la sección 4, ningún caso con `[A VALIDAR]` ni dependiente de *staging*/dispositivos se marca como "Aprobado", y solo el responsable de QA puede cerrar el ciclo tras la sección 9.

| Indicador | Valor actual (`CIC-001`, en ejecución) |
|---|---|
| Ciclos de prueba ejecutados | **1 iniciado** (`CIC-001`, **En ejecución**; `0` cerrados formalmente) |
| Casos de prueba definidos | 160 |
| Casos con ejecución determinista local | **52 de 160 (32.5 %)** (`32 Aprobado` + `20 Aprobado parcial` + `0 Fallido`) |
| Casos aprobados (§2/§4) | **32 de 160 (20.0 %)** (`20` P1, `11` P2, `1` P3 · `32 / 32 = 100.0 %` sobre completos §5) |
| Casos aprobados parciales (solo `[A VALIDAR]`) | **20 de 160 (12.5 %)** (`5` P1, `9` P2, `6` P3 · excluidos de tasa de aprobación §5) |
| Casos fallidos | **0** *(en `CIC-001` se registraron `DEF-001..DEF-008`: `4` resueltos en sesión y `4` menores/abiertos)* |
| Casos bloqueados | **108 de 160 (67.5 %)** (`65` P1, `34` P2, `9` P3 — *staging* `C2`, BFF real, Wompi, dispositivos o brecha local) |
| Casos pendientes | **0** en la planificación de `CIC-001` (quedan pendientes de F3/F4 los `108` bloqueados y el cierre de los `20` parciales) |
| AC con resultado de ejecución / verificados | **150 de 490** en casos `Aprobado`/`Aprobado parcial` (`270` en `test/` expandidos) · **75 de 490 (15.3 %) AC verificados** (§5) |
| Defectos registrados | **8** (`DEF-001..DEF-004` resueltos en `#10`/`#12`/`#17`; `DEF-005..DEF-008` abiertos menores/config) |
| Cobertura de código medida | **95.6 % global CI** (`95.61 %`, `9843/10295` en `coverage/lcov.info` excl. generados y `l10n`; `95.24 %` con `l10n`) |

Los valores de esta tabla solo cambian con evidencia adjunta en la sección 7 y cierre verificado en la sección 9.

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


### CIC-001 — Verificación local automatizada M0–M5 (En ejecución — pendiente cierre QA, CI y staging)

| Campo | Valor |
|---|---|
| ID de ciclo | CIC-001 |
| Objetivo del ciclo | Verificación local automatizada M0–M5 (`PT-19` + `PT-20`), auditoría de accesibilidad `TC-157`, HTTP real sobre `mock_bff`, controles cliente de seguridad y trazabilidad `TC`/`AC`/`ST` |
| Versión de la app / *build* | `1.0.0+1` ([pubspec.yaml](../../pubspec.yaml) · `HEAD d5a2d8a` + `6` modificados + `7` suites nuevas verificadas en `#21`) |
| Versión del BFF y de `ipr/v1` | **No existen en entorno real** (simulado local `tool/mock_bff` conforme a `contract/openapi.yaml`) |
| Entorno y URL base | Local `flutter_test` (Windows 11) + `startMockBff()` en `http://127.0.0.1:<efímero>/mobile/v1` (sin *staging* `C2`) |
| Fechas (inicio – fin) | `2026-11-23 10:19:27 -05:00` → `2026-11-23 10:25:53 -05:00` (**En ejecución**, sin cierre formal) |
| Responsable | Verificación local: `verifier` (`#21`), `a11y` (`#10`), `e2e` (`#6`/`#17`), `security` (`#7`/`#12`), `traceability` · Cierre QA pendiente |
| Casos planificados | **160 de 160** del catálogo MVP ([test_cases.md](test_cases.md)) |
| Dispositivos de la matriz usados | **Ninguno** (`0` físicos / `0` emuladores; solo host Windows 11 · Dart VM / Flutter `3.50.0` *tester* lógico `360x800` y `320x568`) |

**Evidencia automatizada consolidada de `CIC-001` (`verifier`, `#21`):**
* **9/9 puertas oficiales en `exit 0`**: formato (`434` archivos), análisis `--fatal-infos` (`0` issues), `check_layer_rules` (`0` violaciones D1–D6), `check_public_config`, `check_openapi_fixtures` (`121` fixtures, `44` esquemas), `merge_arb --check` (`609` textos en `14` partes), `gen_coverage_helper` (`297` archivos no generados de `lib/`), `flutter test --coverage` (**`2159/2159` pruebas pasadas, `0` fallidas, `0` omitidas** en `365.3 s` sobre `96` suites = `2158` en `95` `*_test.dart` + `1` en `coverage_helper_test.dart`) y `check_coverage`.
* **Cobertura (`coverage/lcov.info`)**: **`95.6 %` global CI** (`95.61 %`, `9843/10295` líneas, `267/297` archivos no generados en `lcov`), `core/session` `95.6 %`, `core/network` `100.0 %`, `features/cart/domain` `99.6 %`, `features/checkout/domain` `100.0 %`, `shared/formatting` `100.0 %`, `features/technical_tools/domain` `97.4 %`. Desglose completo por módulo en [pt19_pt20_resultados.md](../project/pt19_pt20_resultados.md#L24-L57).

**Resultados por caso**

| TC | AC | Capa | Fecha y hora | Versión / *build* | Entorno | Dispositivo y SO | Red | Ejecutor | Resultado | Evidencia | Defecto | Notas |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-001 (P1) | AC-038-2, AC-038-3 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado** | `test/unit/features/authentication/auth_controllers_test.dart`; `test/unit/features/authentication/auth_validation_test.dart`; `test/widget/features/authentication/register_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Unitaria). |
| TC-002 (P1) | AC-038-1, AC-039-1, AC-039-2, AC-099-1 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/authentication/auth_controllers_test.dart`; `test/widget/features/authentication/register_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Widget). |
| TC-003 (P2) | AC-038-6 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/authentication/auth_controllers_test.dart`; `test/widget/features/authentication/register_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Widget). |
| TC-004 (P2) | AC-038-7 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/authentication/auth_controllers_test.dart`; `test/unit/features/authentication/auth_data_test.dart`; `test/widget/features/authentication/register_screen_test.dart` (#21) | — | C2 staging / emulador RED-OFF (criterio exige 0 cuentas en staging; cliente offline pasa en register_screen_test.dart y auth_controllers_test.dart) |
| TC-005 (P1) | AC-038-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/authentication/auth_controllers_test.dart`; `test/widget/features/authentication/register_screen_test.dart` (#21) | — | C2 staging + propuesta PA nueva (auto-login vs pedir login; parte cliente pasa en auth_controllers_test.dart y register_screen_test.dart) |
| TC-006 (P1) | AC-039-3 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + D-12 / PA-10 (tabla consentimientos ipr/v1/m y campos legales) |
| TC-007 (P2) | AC-038-5 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/authentication/auth_controllers_test.dart`; `test/unit/features/authentication/auth_data_test.dart`; `test/widget/features/authentication/register_screen_test.dart` (#21) | — | C2 staging + PA-02 (409 neutral en cliente pasa en auth_controllers_test.dart) |
| TC-008 (P2) | AC-039-5, AC-099-5 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | D-12 + prueba integrada registro/RED-OFF abriendo enlace legal |
| TC-009 (P1) | AC-040-3, AC-040-4, AC-040-8 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/authentication/auth_controllers_test.dart`; `test/unit/features/authentication/auth_validation_test.dart`; `test/widget/features/authentication/login_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Widget). |
| TC-010 (P1) | AC-040-1, AC-037-3 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/authentication/auth_controllers_test.dart` (#21) | — | C2 staging + SPK-01 (login con correo y usuario E2E; controlador y pantalla pasan en auth_controllers_test.dart/login_screen_test.dart) |
| TC-011 (P1) | AC-040-2 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/authentication/auth_controllers_test.dart`; `test/unit/features/authentication/auth_data_test.dart`; `test/widget/features/authentication/login_screen_test.dart` (#21) | — | C2 staging (anti-enumeración real; manejo uniforme 401/403 pasa en cliente) |
| TC-012 (P2) | AC-040-5 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/authentication/auth_controllers_test.dart`; `test/unit/features/authentication/auth_data_test.dart`; `test/widget/features/authentication/login_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Integración). |
| TC-013 (P1) | AC-040-9, AC-048-1, AC-048-2 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/authentication/auth_controllers_test.dart` (#21) | — | C2 staging + PA-03 (CLI-ADM real en WordPress; rechazo 401 cliente pasa en auth_controllers_test.dart) |
| TC-014 (P1) | AC-041-1, AC-041-8, AC-041-2 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/profile/logout_controller_test.dart`; `test/widget/features/profile/account_harness.dart`; `test/widget/features/profile/account_screen_test.dart` (#21) | — | C2 staging (revocar en servidor y 401 al reusar; 1 solicitud cliente pasa en logout_controller_test.dart y account_screen_test.dart) |
| TC-015 (P2) | AC-041-6 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/core/session/session_controller_test.dart`; `test/unit/features/profile/logout_controller_test.dart`; `test/widget/features/profile/account_screen_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — ADR-001 §2]: cierre local sin red borra tokens de inmediato (session_controller_test.dart); falta definición cerrada sin red |
| TC-016 (P2) | AC-041-7 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Propuesta PA nueva (conservar o vaciar carrito al cerrar sesión; código actual lo conserva por H-07 pendiente en cart_controller_test.dart) |
| TC-017 (P1) | AC-041-5, AC-043-3 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + 2 dispositivos físicos (DEV-A y DEV-B) |
| TC-018 (P1) | AC-043-1, AC-043-2 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + app web (Playwright / manual) |
| TC-019 (P1) | AC-043-4, AC-052-10 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging (revocación administrativa en servidor; expiración local con carrito conservado pasa en cliente) |
| TC-020 (P1) | AC-044-3 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/core/session/auth_interceptor_test.dart`; `test/unit/core/session/session_controller_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — ADR-001 §2, DN-04]: secuencia 401 → POST /auth/refresh → reintento pasa en auth_interceptor_test.dart; vigencias numéricas pendientes |
| TC-021 (P1) | AC-044-6 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado** | `test/unit/core/session/auth_interceptor_test.dart`; `test/unit/core/session/session_controller_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Unitaria). |
| TC-022 (P1) | AC-044-5 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/core/session/auth_interceptor_test.dart`; `test/unit/core/session/session_controller_test.dart`; `test/widget/app_router_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Integración). |
| TC-023 (P2) | AC-044-7 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/core/session/auth_interceptor_test.dart`; `test/unit/core/session/session_controller_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Integración). |
| TC-024 (P2) | AC-043-6, AC-042-6, AC-104-10, AC-105-10 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + 2 dispositivos/web + propuesta PA nueva (efecto en otras sesiones) |
| TC-025 (P2) | AC-042-1, AC-042-8 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/authentication/auth_controllers_test.dart`; `test/unit/features/authentication/auth_validation_test.dart`; `test/widget/features/authentication/password_recovery_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Widget). |
| TC-026 (P1) | AC-042-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/authentication/auth_controllers_test.dart`; `test/unit/features/authentication/auth_data_test.dart`; `test/widget/features/authentication/password_recovery_screen_test.dart` (#21) | — | C2 staging (respuesta real 202 idéntica en servidor; cliente pasa en auth_controllers_test.dart y password_recovery_screen_test.dart) |
| TC-027 (P1) | AC-042-2 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + correo real + ADR-001 §2 (flujo manual/E2E con lost-password) |
| TC-028 (P1) | AC-037-1, AC-001-3 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Sin integration_test/ en instalación nueva sin sesión (rutas individuales sin sesión pasan en widget tests) |
| TC-029 (P1) | AC-037-3 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/app/router_policy_test.dart`; `test/widget/app_router_test.dart`; `test/widget/app_router_features_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Integración). |
| TC-030 (P2) | AC-045-7 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/widget/features/authentication/login_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Widget). |
| TC-031 (P1) | AC-045-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging (2 instancias BFF y límite en WordPress) |
| TC-032 (P1) | AC-045-6 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging detrás de Cloudflare + 2 redes reales (Wi-Fi y datos móviles) |
| TC-033 (P1) | AC-037-2, AC-010-4 | Contrato | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/tool/mock_bff_e2e_flows_test.dart`; `test/unit/tool/contract_and_mock_test.dart` (#21) | — | BFF real /mobile/v1 (8/10 rutas públicas pasan sin Authorization en mock_bff_e2e_flows_test.dart/contract_and_mock_test.dart; faltan /products/{slug} y /search/suggestions en mock_bff) |
| TC-034 (P1) | AC-044-11 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + SPK-01 (flujo E2E de pago con sesión expirada) |
| TC-035 (P2) | AC-039-7, AC-099-4 | Manual | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Manual + D-12 (PDFs legales vigentes entregados por Jurídico de IPR) |
| TC-036 (P1) | AC-029-4, AC-029-7, AC-049-1, AC-049-8 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/cart/cart_controller_test.dart`; `test/widget/features/cart/cart_screen_test.dart`; `test/widget/features/product_detail/product_detail_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Integración). |
| TC-037 (P1) | AC-029-2, AC-029-3, AC-049-2 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado** | `test/unit/features/cart/cart_controller_test.dart`; `test/unit/features/cart/cart_domain_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Unitaria). |
| TC-038 (P2) | AC-029-5 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/cart/cart_controller_test.dart`; `test/unit/features/cart/cart_domain_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — propuesta PA nueva]: tope 99 y fusión en 1 línea probados en cart_controller_test.dart; falta cerrar regla sumar vs reemplazar |
| TC-039 (P2) | AC-029-6, AC-049-3 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/cart/cart_controller_test.dart`; `test/unit/features/cart/cart_domain_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Integración). |
| TC-040 (P1) | AC-049-4, AC-009-6 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/cart/cart_controller_test.dart`; `test/unit/features/cart/cart_data_test.dart`; `test/widget/features/cart/cart_screen_test.dart` (#21) | — | Sin integration_test/ para matar proceso completo (persistencia simulada MemoryDurableStore + RED-OFF pasa en cart_controller_test.dart y cart_screen_test.dart) |
| TC-041 (P2) | AC-049-5, AC-049-6 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/cart/cart_controller_test.dart`; `test/unit/features/cart/cart_domain_test.dart`; `test/widget/features/cart/cart_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Widget). |
| TC-042 (P1) | AC-029-8 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/cart/cart_integration_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Unitaria). |
| TC-043 (P3) | AC-049-9 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/cart/cart_controller_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P3 · Integración). |
| TC-044 (P1) | AC-050-1, AC-050-10, AC-050-8 | Contrato | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/cart/cart_controller_test.dart`; `test/unit/features/cart/cart_data_test.dart`; `test/widget/features/cart/cart_screen_test.dart` (#21) | — | Falta paso 4 directo a POST /cart/validate (101 IDs y cantidades 0/100 → 400); pasos 1–3 cliente/contrato pasan en cart_data_test.dart y cart_controller_test.dart |
| TC-045 (P1) | AC-050-2, AC-050-9 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/cart/cart_controller_test.dart`; `test/unit/features/cart/cart_rules_test.dart`; `test/widget/features/cart/cart_screen_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — propuesta PA nueva]: detección 100k → 110k y aviso en cart_integration_test.dart/checkout_screen_test.dart; falta decidir confirmación explícita |
| TC-046 (P1) | AC-050-3, AC-050-4, AC-031-3, AC-052-7 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/cart/cart_controller_test.dart`; `test/unit/features/cart/cart_rules_test.dart`; `test/widget/features/cart/cart_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Integración). |
| TC-047 (P1) | AC-050-5, AC-030-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/shared/shared_test.dart`; `test/widget/features/cart/cart_screen_test.dart` (#21) | — | C2 staging (cambio de precio a 0 en staging; defensa local $0/OnRequest y bloqueo de pago pasan en shared_test.dart y cart_screen_test.dart) |
| TC-048 (P1) | AC-050-6 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/cart/cart_controller_test.dart`; `test/widget/features/cart/cart_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Integración). |
| TC-049 (P1) | AC-050-7 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/cart/cart_controller_test.dart`; `test/unit/features/cart/cart_integration_test.dart`; `test/widget/features/cart/cart_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Integración). |
| TC-050 (P1) | AC-051-1, AC-051-2, AC-051-3, AC-051-5 | Widget | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/cart/cart_rules_test.dart`; `test/widget/features/cart/cart_screen_test.dart` (#21) | — | Falta golden de resumen del carrito requerido en criterio (golden + texto); cálculos y ausencia de textos prohibidos pasan en cart_screen_test.dart |
| TC-051 (P1) | AC-011-5, AC-026-5, AC-107-8, AC-108-4 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado** | `test/unit/shared/shared_test.dart`; `test/unit/features/orders/orders_data_test.dart`; `test/golden/design_system_golden_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Unitaria). |
| TC-052 (P1) | AC-012-1, AC-012-4 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/catalog/catalog_mappers_test.dart`; `test/widget/shared_product_widgets_test.dart`; `test/widget/shared_widgets_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — ADR-002 / D-04]: on_request, price=0, null y no numéricos probados sin "$0" ni NaN en shared_test.dart; falta confirmar valores de WooCommerce |
| TC-053 (P1) | AC-012-2, AC-012-3, AC-030-1, AC-030-2, AC-030-5, AC-003-2 | Widget | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart`; `test/widget/features/product_detail/product_detail_screen_test.dart` (#21) | — | Faltan golden y casos explícitos de P-SINPRECIO en marca y Liquidaciones (brands_and_sale_test.dart); inicio, listado, búsqueda, carrito y ficha sí pasan |
| TC-054 (P1) | AC-012-5 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/widget/features/catalog/product_list_screen_test.dart` · #21 (2159/2159) | — | Aprobado en alcance simulado (product_list_screen_test.dart L122 AC-012-5: 3 sin precio + 7 con precio de 10); observación menor: falta etiqueta TC-054 en el nombre del test |
| TC-055 (P1) | AC-030-3, AC-062-1, AC-062-3, AC-062-6 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/shared_product_widgets_test.dart` (#21) | — | Dispositivo físico con WhatsApp + D-04 (apertura con mock url_launcher sí pasa en product_detail_screen_test.dart) |
| TC-056 (P1) | AC-062-2, AC-062-5, AC-023-2 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado** | `test/widget/shared_product_widgets_test.dart`; `test/widget/features/product_detail/product_detail_screen_test.dart`; `test/widget/features/search/search_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Unitaria). |
| TC-057 (P2) | AC-063-1, AC-063-2, AC-063-3, AC-063-5, AC-062-4, AC-005-3 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/product_detail/product_detail_screen_test.dart` (#21) | — | Falta simular tableta sin telefonía cuando tel: devuelve false (alternativa WhatsApp web y tel: con /config sí pasan en shared_product_widgets_test.dart) |
| TC-058 (P1) | AC-031-1, AC-031-2, AC-031-5, AC-003-3 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/widget/features/product_detail/product_detail_screen_test.dart`; `test/widget/features/home/home_screen_test.dart`; `test/widget/features/catalog/product_list_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Widget). |
| TC-059 (P2) | AC-031-4 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/widget/features/product_detail/product_detail_screen_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — PA-12]: onbackorder ("Bajo pedido") visible y compra bloqueada en product_detail_screen_test.dart; tratamiento final pendiente |
| TC-060 (P2) | AC-063-4 | Manual | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Manual + dispositivos físicos Android 11+ e iPhone con/sin WhatsApp |
| TC-061 (P1) | AC-052-1 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/checkout/controllers/checkout_controller_test.dart`; `test/widget/features/checkout/checkout_screen_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — PA-01]: visitante al pagar pide login y conserva carrito C3 en cart_screen_test.dart/app_router_features_test.dart; compra invitado pendiente |
| TC-062 (P1) | AC-052-6, AC-057-7, AC-058-7 | Widget | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/data/checkout_data_test.dart`; `test/unit/features/checkout/domain/checkout_flow_test.dart`; `test/widget/features/checkout/checkout_screen_test.dart` (#21) | — | C2 staging (paso 4 exige contar 1 ticket por intención en staging; doble toque y reintentos rápidos en cliente pasan en checkout_screen_test.dart) |
| TC-063 (P1) | AC-052-11 | Contrato | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging / BFF real /mobile/v1 (validación estricta del cuerpo de POST /checkout) |
| TC-064 (P1) | AC-058-1, AC-058-2, AC-058-3, AC-058-9, AC-009-4, AC-052-8, AC-052-9 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/checkout/controllers/checkout_controller_test.dart`; `test/unit/features/checkout/data/checkout_data_test.dart`; `test/unit/features/checkout/domain/checkout_flow_test.dart`; `test/unit/features/checkout/domain/checkout_rules_test.dart`; `test/widget/features/checkout/checkout_screen_test.dart`; `test/unit/core/session/auth_interceptor_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Integración). |
| TC-065 (P2) | AC-052-16 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging / WordPress detenido (y umbral pendiente por propuesta PA nueva) |
| TC-066 (P1) | AC-052-3, AC-053-5 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart`; `test/unit/features/checkout/data/checkout_data_test.dart`; `test/unit/features/checkout/domain/checkout_flow_test.dart`; `test/widget/features/checkout/checkout_screen_test.dart` (#21) | — | C2 staging + SPK-01 + dispositivos físicos (Android con/sin Chrome y iPhone; política de navegador pasa en cliente) |
| TC-067 (P1) | AC-052-15, AC-056-2, AC-057-1, AC-107-4, AC-052-5 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart`; `test/unit/features/checkout/controllers/checkout_wiring_test.dart`; `test/widget/features/checkout/checkout_screen_test.dart` (#21) | — | C2 staging + Wompi sandbox + SPK-01 + dispositivos físicos Android/iOS |
| TC-068 (P1) | AC-056-3, AC-057-2 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart` (#21) | — | C2 staging + Wompi sandbox + SPK-01 |
| TC-069 (P1) | AC-056-4, AC-057-2 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart` (#21) | — | C2 staging + Wompi sandbox + SPK-01 |
| TC-070 (P1) | AC-056-5, AC-057-3 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart` (#21) | — | C2 staging + Wompi sandbox + PA-11 + D-02 (vista pending pasa en checkout_result_screen_test.dart) |
| TC-071 (P1) | AC-057-2, AC-057-8, AC-055-3 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart`; `test/unit/features/checkout/data/checkout_data_test.dart`; `test/widget/features/checkout/checkout_screen_test.dart` (#21) | — | C2 staging + Wompi sandbox + SPK-01 + ADR-001 C1/C2 (reanudación local pasa en checkout_screen_test.dart) |
| TC-072 (P2) | AC-057-4 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart`; `test/widget/features/checkout/checkout_result_screen_test.dart` (#21) | — | C2 staging + Wompi sandbox + SPK-01 (estado pendiente y conservación del carrito pasan en checkout_result_screen_test.dart) |
| TC-073 (P1) | AC-057-5, AC-057-6 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + Wompi sandbox + PA-11 + D-02 |
| TC-074 (P1) | AC-058-4, AC-058-8 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart`; `test/unit/features/checkout/domain/checkout_flow_test.dart` (#21) | — | C2 staging + SPK-01 + propuesta PA nueva (reintento automático único en ticket_invalid pasa en checkout_controller_test.dart) |
| TC-075 (P2) | AC-054-1, AC-054-2, AC-054-4 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + Wompi sandbox (datos de facturación CLI-01/CLI-02 en checkout) |
| TC-076 (P1) | AC-055-1, AC-055-7 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/checkout/checkout_result_screen_test.dart` (#21) | — | C2 staging + assetlinks/AASA reales (D-14) + arranque en frío/segundo plano en dispositivo (resultado deep link simulado pasa en widget) |
| TC-077 (P2) | AC-055-6 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/app/router_policy_test.dart`; `test/widget/app_router_test.dart` · #21 (2159/2159) | DEF-001 (cerrado) | Alcance local 100 % cubierto (P2 · Integración). |
| TC-078 (P1) | AC-055-4, AC-056-6, AC-055-5, AC-056-10 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/app/router_policy_test.dart`; `test/widget/features/checkout/checkout_result_screen_test.dart` (#21) | — | Falta escenario simulado BFF de pedido ajeno CLI-02 (paso 2); ignorar status=paid y order=999 falsificados del enlace sí pasa en checkout_result_screen_test.dart |
| TC-079 (P1) | AC-056-9, AC-056-1, AC-056-7, AC-056-8 | Widget | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart`; `test/unit/features/checkout/data/checkout_data_test.dart`; `test/unit/features/checkout/domain/checkout_flow_test.dart`; `test/widget/features/checkout/checkout_result_screen_test.dart` (#21) | — | Falta golden de CheckoutResultScreen (+ golden) + PA-12; los 7 estados en widget test pasan en checkout_result_screen_test.dart |
| TC-080 (P2) | AC-053-4 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + Wompi sandbox + D-02 + PA-12 (inspección visual medios habilitados) |
| TC-081 (P1) | AC-019-5 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + Wompi sandbox + SPK-01 (cambio de precio en WooCommerce) |
| TC-082 (P1) | AC-055-2 | Manual | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + dominio real + ADR-001 C1/C2 + D-14 (archivos deploy/well-known tienen REEMPLAZAR_*; DEF-008) |
| TC-083 (P1) | AC-107-1, AC-107-3, AC-107-5, AC-107-6, AC-107-9 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/orders/orders_controllers_test.dart`; `test/unit/features/orders/orders_data_test.dart`; `test/widget/features/orders/orders_screens_test.dart` (#21) | — | C2 staging CLI-01/CLI-02 (datos/vacío/sesión/error en cliente pasan en orders_screens_test.dart y orders_controllers_test.dart) |
| TC-084 (P3) | AC-107-7 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/orders/orders_controllers_test.dart`; `test/widget/features/orders/orders_screens_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — propuesta PA nueva]: paginación sin duplicados y retención ante error pasan en orders_controllers_test.dart; orden y tamaño de página pendientes |
| TC-085 (P2) | AC-108-1, AC-108-2, AC-108-5, AC-108-6 | Widget | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/orders/orders_controllers_test.dart`; `test/widget/features/orders/orders_screens_test.dart` (#21) | — | Falta golden de OrderDetailScreen (+ golden) + PA-12; detalle, campos no soportados y 360 dp sin overflow pasan en orders_screens_test.dart |
| TC-086 (P1) | AC-107-2, AC-108-3, AC-SEC-8 | Contrato | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/orders/orders_controllers_test.dart`; `test/unit/features/orders/orders_data_test.dart`; `test/widget/features/orders/orders_screens_test.dart` (#21) | — | C2 staging CLI-01 vs CLI-02 (manejo cliente de 404 ajeno vs 503 pasa en orders_data_test.dart y orders_screens_test.dart) |
| TC-087 (P1) | AC-110-1, AC-110-2, AC-110-10, AC-110-11 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/profile/profile_controllers_test.dart`; `test/widget/features/profile/profile_screens_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — PA-09, D-12]: acceso, confirmación, cancelación y doble toque pasan en profile_screens_test.dart; textos legales finales pendientes |
| TC-088 (P1) | AC-110-3, AC-110-12, AC-110-13 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/profile/profile_data_test.dart`; `test/unit/features/profile/profile_validation_test.dart`; `test/widget/features/profile/profile_screens_test.dart` (#21) | — | Falta prueba POST /me/deletion sin token/token inválido en contrato/staging + propuesta PA nueva; contraseña requerida e idempotencia cliente pasan en profile_controllers_test.dart |
| TC-089 (P1) | AC-110-4, AC-110-5 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/profile/profile_controllers_test.dart`; `test/widget/features/profile/profile_screens_test.dart` (#21) | — | C2 staging + PA-09 (CLI-DEL en DEV-A y DEV-B; borrado local de sesión/carrito ante 202 pasa en profile_controllers_test.dart) |
| TC-090 (P1) | AC-110-6, AC-110-7, AC-110-8 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + PA-09 (pedidos previos y reutilización de correo tras eliminar cuenta) |
| TC-091 (P1) | AC-110-9 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/profile/profile_controllers_test.dart` (#21) | — | Falta escenario simulado 503 en eliminación de cuenta en profile_controllers_test.dart (solo cubierto NoConnection) |
| TC-092 (P1) | AC-110-16 | Manual | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Manual + S-05 (revisión contra guías vigentes de Apple y Google) |
| TC-093 (P2) | AC-104-5, AC-104-8, AC-105-1, AC-105-4, AC-105-8, AC-104-9 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/profile/profile_controllers_test.dart`; `test/unit/features/profile/profile_validation_test.dart`; `test/widget/features/profile/profile_screens_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Widget). |
| TC-094 (P1) | AC-104-1, AC-104-2, AC-104-3, AC-104-4, AC-105-2, AC-105-5 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/profile/profile_controllers_test.dart`; `test/widget/features/profile/profile_screens_test.dart` (#21) | — | C2 staging CLI-01 (rotación de token y perfil actualizado en cliente pasan en profile_controllers_test.dart) |
| TC-095 (P3) | AC-105-9 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + propuesta PA nueva (contraseña nueva igual a la actual) |
| TC-096 (P2) | AC-106-1, AC-106-2, AC-106-3, AC-106-4, AC-106-7, AC-106-8 | Widget | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/profile/profile_validation_test.dart`; `test/widget/features/profile/profile_screens_test.dart` (#21) | — | Depende de TC-075 en staging (paso 5 prellenado) + propuesta PA nueva; reglas Colombia/dpto/ciudad y doble toque pasan en profile_screens_test.dart |
| TC-097 (P2) | AC-111-1, AC-111-2, AC-111-3, AC-111-5 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/profile/profile_screens_test.dart` (#21) | — | C2 staging / buzón corporativo + D-12 (canal real de derechos pendiente; pantalla pasa en profile_accessibility_test.dart) |
| TC-098 (P2) | AC-104-6 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/profile/profile_controllers_test.dart` (#21) | — | C2 staging + PA-02 (409 email_in_use neutral en cliente pasa en profile_controllers_test.dart) |
| TC-099 (P1) | AC-009-1, AC-009-3, AC-009-7 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/widget/features/catalog/product_list_screen_test.dart`; `test/widget/features/home/home_screen_test.dart`; `test/widget/features/catalog/catalog_screen_test.dart`; `test/widget/features/product_detail/product_detail_screen_test.dart`; `test/widget/features/branches/branches_screens_test.dart`; `test/widget/features/search/search_screen_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P1 · Integración). |
| TC-100 (P1) | AC-009-2, AC-002-3, AC-010-6, AC-072-5 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/catalog/product_list_screen_test.dart` (#21) | — | Faltan respuestas 500/503/504/timeout sobre BranchesScreen (matriz 4x3 completa en Sedes solo cubrió NoConnection) |
| TC-101 (P2) | AC-009-5, AC-011-6 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/catalog/product_list_controller_test.dart`; `test/widget/features/catalog/product_list_screen_test.dart` (#21) | — | Falta prueba integrada con 60 ítems / 3ª página (product_list_screen_test.dart cubrió fallo en página 2 con 24 ítems) |
| TC-102 (P1) | AC-009-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Falta suite unificada de los 6 fallos consecutivos sobre carrito C3 (validado parcialmente por piezas en cart_integration_test.dart y checkout_screen_test.dart) |
| TC-103 (P1) | AC-026-6, AC-026-7 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/product_detail/product_detail_repository_test.dart`; `test/widget/features/product_detail/product_detail_screen_test.dart`; `test/widget/shared_widgets_test.dart` · #21 (2159/2159) | — | 404 ("Producto no disponible" + Volver), 503 y NoConnection ("Reintentar" sin afirmar inexistencia) pasan en product_detail_screen_test.dart y product_detail_repository_test.dart |
| TC-104 (P1) | — (RNF) | Contrato | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/core/network/api_client_test.dart`; `test/unit/core/network/failure_mapper_test.dart`; `test/unit/features/catalog/api_catalog_repository_test.dart`; `test/unit/features/home/api_home_repository_test.dart`; `test/unit/features/product_detail/product_detail_repository_test.dart`; `test/unit/features/search/search_data_test.dart`; `test/widget/features/catalog/brands_and_sale_test.dart`; `test/widget/features/catalog/product_list_screen_test.dart`; `test/widget/features/home/home_screen_test.dart`; `test/widget/features/product_detail/product_detail_screen_test.dart` (#21) | — | C2 staging + BFF real /mobile/v1 (semántica 404/502/503/504 del BFF incluyendo catalog_index_warming y X-IPR-Data-State: stale; mapeo cliente pasa en failure_mapper_test.dart) |
| TC-105 (P2) | — (RNF) | Widget | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/golden/design_system_golden_test.dart`; `test/widget/shared_widgets_test.dart`; `test/widget/features/catalog/product_list_screen_test.dart` (#21) | — | Sin prueba integrada etiquetada TC-105 que encadene listado stale + compra condicionada (StaleBanner, design_system_golden_test.dart y gate de revalidación pasan por separado) |
| TC-106 (P2) | — (RNF) | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Dispositivo/emulador RED-OFF tras navegación previa + DN-10 |
| TC-107 (P1) | — (RNF) | Rendimiento | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Rendimiento en dispositivos físicos con perfiles RED-4G-LENTA/DEGRADADA/INTERMITENTE (MED-01 / DN-01) |
| TC-108 (P1) | AC-022-1, AC-022-2, AC-022-5 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + RF-022 (ranking real de SKU en WooCommerce/BFF) |
| TC-109 (P3) | AC-022-3 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + propuesta PA nueva (SKU con guiones o espacios) |
| TC-110 (P1) | AC-022-4 | Manual | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + muestra real de SKUs de IPR + RF-022 |
| TC-111 (P1) | AC-020-1, AC-020-2, AC-020-3, AC-020-7, AC-020-6, AC-020-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/search/search_screen_test.dart` (#21) | — | C2 staging (relevancia de búsqueda; paginación, vacío, caracteres especiales y sin sesión pasan en search_screen_test.dart) |
| TC-112 (P3) | AC-020-5 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + propuesta PA nueva (equivalencia con y sin tildes) |
| TC-113 (P2) | AC-021-2, AC-021-4, AC-021-5, AC-021-1, AC-021-3 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado parcial** | `test/widget/features/search/search_screen_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — propuesta PA nueva]: orden de respuestas ab/abc, fallo sin bloqueo y borrado pasan en search_controllers_test.dart; mínimo/debounce/destino pendientes |
| TC-114 (P2) | AC-023-1, AC-023-3, AC-023-4, AC-023-5, AC-023-6 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/search/search_screen_test.dart` (#21) | — | C2 staging + propuesta PA nueva (texto WhatsApp; codificación y estado vacío en cliente pasan en search_screen_test.dart) |
| TC-115 (P2) | AC-001-1, AC-001-2, AC-002-1, AC-002-2, AC-005-1, AC-004-1, AC-004-2, AC-005-4 | Widget | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/home/home_screen_test.dart` (#21) | — | Falta golden de HomeScreen (+ golden); buscador, 8 categorías, WhatsApp, marcas y autofocus pasan en home_screen_test.dart y search_screen_test.dart |
| TC-116 (P2) | AC-002-4, AC-019-1, AC-019-2 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + acceso WooCommerce + PA-04 |
| TC-117 (P2) | AC-010-1, AC-010-2, AC-010-3, AC-010-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/catalog/catalog_screen_test.dart` (#21) | — | C2 staging (árbol jerárquico; navegación, retorno, vacío y sin Authorization pasan en catalog_screen_test.dart) |
| TC-118 (P2) | AC-011-2, AC-011-3, AC-011-8, AC-018-3 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/catalog/product_list_controller_test.dart`; `test/widget/features/catalog/product_list_screen_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — D-05 / ADR-001]: paginación sin duplicados ni peticiones extra pasa en product_list_screen_test.dart; tamaño de página pendiente |
| TC-119 (P2) | AC-011-1, AC-011-4, AC-011-7 | Golden | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/shared_product_widgets_test.dart` (#21) | — | Falta golden/Alchemist de ProductCard en 1,0x y 2,0x a 360 dp (propiedades equivalentes pasan en shared_product_widgets_test.dart) |
| TC-120 (P2) | AC-013-1, AC-013-2, AC-013-3, AC-013-4, AC-013-5, AC-013-6 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/catalog/product_list_screen_test.dart` (#21) | — | C2 staging (categoría con 2 marcas; filtros, chips, vacío, retención en error y paginación pasan en product_list_screen_test.dart) |
| TC-121 (P3) | AC-015-2, AC-015-3, AC-015-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/catalog/product_list_screen_test.dart` (#21) | — | C2 staging + propuesta PA nueva (orden por precio con sin precio; selector de orden pasa en product_list_screen_test.dart) |
| TC-122 (P2) | AC-026-1, AC-026-2, AC-026-3, AC-026-4, AC-029-1, AC-032-1 | Widget | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/product_detail/product_detail_screen_test.dart` (#21) | — | Falta golden de ProductDetailScreen exigido en criterio; galería, stock genérico, cantidad, avisos y sin imagen pasan en product_detail_screen_test.dart |
| TC-123 (P2) | AC-027-3, AC-027-5, AC-027-6, AC-028-1, AC-028-2 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/product_detail/html_sanitizer_test.dart`; `test/widget/features/product_detail/product_detail_content_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — D-10]: descripción HTML saneada, sin descripción y descripción larga pasan en product_detail_screen_test.dart; calidad catálogo pendiente |
| TC-124 (P2) | AC-072-2, AC-072-3, AC-073-1, AC-073-2, AC-074-4, AC-074-5, AC-072-6 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/unit/features/branches/branches_data_test.dart`; `test/widget/features/branches/branches_screens_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Widget). |
| TC-125 (P2) | AC-074-1, AC-074-2, AC-075-1, AC-075-2, AC-075-3 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/branches/branches_data_test.dart`; `test/widget/features/branches/branches_screens_test.dart` (#21) | DEF-002 (cerrado) | Falta prueba de fallback sin app de mapas (url_launcher=false en Cómo llegar) + verificación manual en dispositivo; tel:/WhatsApp/codificación URL pasan en branches_*_test.dart |
| TC-126 (P2) | AC-076-1, AC-076-3, AC-076-4 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + fuente real de sedes + D-09 + PA-04 |
| TC-127 (P2) | AC-085-2, AC-085-3, AC-085-4, AC-086-1, AC-086-2, AC-086-3, AC-086-4, AC-088-4 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/technical_tools/btu_calculator_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — D-08]: límites, T1..T10, 2,5/2,51, monotonía y cobertura >=97% pasan en btu_calculator_test.dart; validación de Ingeniería pendiente |
| TC-128 (P2) | AC-087-1, AC-087-2, AC-088-1, AC-088-3, AC-089-4, AC-089-1, AC-089-5 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/technical_tools/btu_calculator_test.dart`; `test/widget/features/catalog/product_list_btu_test.dart`; `test/widget/features/technical_tools/btu_calculator_screen_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — D-08, D-10, RF-014]: T4, T9 (>36.000) y 5 capacidades pasan en btu_calculator_screen_test.dart y product_list_btu_test.dart; textos/atributos pendientes |
| TC-129 (P2) | AC-096-2, AC-096-3 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado** | `test/unit/features/support/pqrs_test.dart`; `test/widget/features/support/support_screens_test.dart` · #21 (2159/2159) | — | Alcance local 100 % cubierto (P2 · Unitaria). |
| TC-130 (P2) | AC-096-4, AC-096-5, AC-096-7, AC-096-8, AC-096-10, AC-096-1, AC-096-11 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/support/pqrs_test.dart`; `test/widget/features/support/support_screens_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — D-12]: 202, doble toque, RED-OFF y 500 pasan en pqrs_test.dart y support_screens_test.dart; falta confirmación legal de aviso |
| TC-131 (P2) | AC-097-1, AC-097-2 | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + revisión manual del buzón corporativo de PQRS |
| TC-132 (P2) | AC-099-3, AC-099-2 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/profile/account_screen_test.dart`; `test/widget/features/support/legal_screen_test.dart` (#21) | — | Sin URLs legales reales publicadas ni verificación HTTP 200 nocturna (D-12; accesos desde menú y LegalScreen pasan en widget tests) |
| TC-133 (P3) | AC-094-1, AC-095-1, AC-095-2, AC-064-1, AC-005-2 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/widget/features/support/support_screens_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — PA-07]: 5 accesos de Ayuda y Cotizar por WhatsApp pasan en support_screens_test.dart y home_screen_test.dart; número y texto finales pendientes |
| TC-134 (P2) | AC-019-3, AC-019-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + /api/revalidate HMAC + PA-04 |
| TC-135 (P3) | AC-018-1, AC-018-2, AC-018-5, AC-018-6 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/catalog/brands_and_sale_test.dart` (#21) | — | C2 staging P-OFERTA (oferta regular/especial y vacío pasan en brands_and_sale_test.dart) |
| TC-136 (P3) | AC-016-1, AC-016-2, AC-016-3, AC-016-4, AC-016-5 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/catalog/brands_and_sale_test.dart` (#21) | — | C2 staging QA-MARCA-A (directorio, filtro por marca y vacío pasan en brands_and_sale_test.dart) |
| TC-137 (P3) | AC-014-1, AC-014-2, AC-014-3, AC-014-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + D-10 (atributos técnicos; hoja de filtros sin vacíos y con reintento pasa en product_list_screen_test.dart) |
| TC-138 (P3) | AC-072-1, AC-072-4 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/widget/features/branches/branches_screens_test.dart` (#21) | — | C2 staging + D-07 + D-09 (conteo 31/32 sedes; listado sin sesión pasa en branches_screens_test.dart) |
| TC-139 (P3) | AC-079-1, AC-079-3, AC-079-4, AC-080-1, AC-080-3, AC-080-4 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/widget/features/support/support_screens_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — ADR-001, PA-06, PA nueva]: servicios, teléfono, correo con fallback y WhatsApp pasan en support_screens_test.dart; fuente y canal pendientes |
| TC-140 (P3) | AC-085-1, AC-085-5, AC-085-6, AC-085-7 | Widget | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/technical_tools/btu_calculator_test.dart`; `test/widget/features/technical_tools/btu_calculator_screen_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — D-08, PA nueva]: 6 entradas, coma/punto (2,5 y 2.5), sin red ni sesión pasan en btu_calculator_screen_test.dart; defaults pendientes |
| TC-141 (P3) | AC-086-5 | Unitaria | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | N/A (simulada) | `verifier` (#21) | **Aprobado parcial** | `test/unit/features/technical_tools/btu_calculator_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — D-08]: 20 vectores deterministas con semilla fija pasan en btu_calculator_test.dart; paridad contra web oficial pendiente |
| TC-142 (P3) | AC-003-1, AC-003-4, AC-003-5, AC-006-1, AC-006-2, AC-007-1, AC-007-2 | Integración | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado parcial** | `test/widget/features/home/home_m5_test.dart`; `test/widget/features/home/home_screen_test.dart` · #21 (2159/2159) | — | Parcial [A VALIDAR — PA-05, D-08]: más vendidos, fallo aislado del bloque, toggle BTU y Liquidaciones pasan en home_screen_test.dart; criterio de selección pendiente |
| TC-143 (P3) | AC-032-2, AC-087-3, AC-094-4, AC-099-6, AC-097-6, AC-010-5, AC-075-5 | Manual | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Manual + D-08, D-10, D-12, PA-07, S-05 (revisión humana de textos aprobados) |
| TC-144 (P1) | — (RNF) | Contrato | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/tool/mock_bff_e2e_flows_test.dart` (#21) | DEF-007 (abierto) | BFF real /mobile/v1 en CI + openapi-diff + humo staging (en local mock_bff cubre HTTP real GET públicos, 401 privados y POST login/orders/pqrs/idempotencia en mock_bff_e2e_flows_test.dart; DEF-007) |
| TC-145 (P1) | — (RNF) | Unitaria | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Repositorio BFF real inexistente (Node/TypeScript con mapeadores WooCommerce) |
| TC-146 (P1) | — (RNF) | Contrato | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Repositorio BFF real inexistente (validación 413/415/token en URL en servidor real; cabeceras 400 pasan en contract_and_mock_test.dart) |
| TC-147 (P1) | — (RNF) | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | Parcial en local: `test/unit/features/checkout/controllers/checkout_controller_test.dart` (#21) | — | BFF real con handoff-ticket e idempotencia 60s/409 (envío de Idempotency-Key UUID v4 y rechazo 400 sin clave en mock_bff pasan en mock_bff_e2e_flows_test.dart) |
| TC-148 (P1) | — (RNF) | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging WordPress ipr/v1/m (sesiones por dispositivo y rotación) |
| TC-149 (P1) | — (RNF) | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging WordPress ipr/v1/m (límite de intentos persistente) |
| TC-150 (P1) | — (RNF) | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging WordPress ipr/v1/m (propiedad de pedidos y checkout_ref) |
| TC-151 (P1) | — (RNF) | Unitaria | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Repositorio BFF real + PA-12 (mapeo WooCommerce -> paymentState; tolerancia cliente unknown pasa en orders_data_test.dart) |
| TC-152 (P1) | AC-019-6 | Rendimiento | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + DN-07 + MED-01 + ADR-001 C4 (prueba de carga del BFF) |
| TC-153 (P2) | AC-097-3, AC-097-4, AC-097-5 | Integración | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging (2 instancias BFF) + propuesta PA nueva (cabecera IP de confianza) |
| TC-154 (P1) | — (RNF) | Rendimiento | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Dispositivos físicos (build profile/release) + MED-01 + MED-11 |
| TC-155 (P2) | — (RNF) | Rendimiento | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Dispositivos físicos (build profile/release, DevTools/memoria/tamaño) + MED-11 |
| TC-156 (P2) | — (RNF) | Rendimiento | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | C2 staging + MED-07 + MED-08 (peso respuestas e imágenes) |
| TC-157 (P1) | — (RNF) | Accesibilidad | 2026-11-23 10:19–10:25 -05:00 | 1.0.0+1 (`d5a2d8a`+local) | Local (`flutter_test`, sin staging) | Host Win11 · Dart VM / Flutter 3.50.0 | Simulada (mocks / `FakeHttpAdapter`) | `verifier` (#21) | **Aprobado** | `test/widget/features/branches/branches_accessibility_test.dart`; `test/widget/features/orders/orders_accessibility_test.dart`; `test/widget/features/profile/profile_accessibility_test.dart`; `test/widget/features/support/support_accessibility_test.dart`; `test/widget/features/technical_tools/btu_accessibility_test.dart`; `test/widget/shared_product_widgets_test.dart`; `test/widget/shared_widgets_test.dart` · #21 (2159/2159) | DEF-003 (cerrado) | 4 guías + texto 200 % + `autofillHints` + no solo color pasan en pantallas críticas y 5 suites a11y (`#10`, `148/148`). Pendiente lector manual (`TC-158`) y confirmación `MED-12` (`R-NF-08`). |
| TC-158 (P1) | — (RNF) | Accesibilidad | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Manual + dispositivos físicos Android (TalkBack) e iOS (VoiceOver) al 200 % |
| TC-159 (P1) | — (RNF) | Compatibilidad | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Local (incompleto / sin dispositivo) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | Matriz ≥ 8 dispositivos físicos + DN-01 + MED-01 + SPK-02 |
| TC-160 (P1) | — (RNF) | E2E | 2026-11-23 (evaluado) | 1.0.0+1 (`d5a2d8a`+local) | Sin staging (`C2`) | N/A (no ejecutado en dispositivo) | — | `traceability` / `verifier` (#21) | **Bloqueado** | — | — | CI remoto + C2 staging disponible (regresión P1 de humo) |

**Resumen del ciclo**

| Capa | Planificados | Aprobados | Aprobados parciales | Fallidos | Bloqueados | Pendientes |
|---|---|---|---|---|---|---|
| Unitaria | 13 | 7 | 4 | 0 | 2 | 0 |
| Widget y Golden | 26 | 9 | 7 | 0 | 10 | 0 |
| Integración | 74 | 15 | 9 | 0 | 50 | 0 |
| Contrato | 7 | 0 | 0 | 0 | 7 | 0 |
| E2E | 26 | 0 | 0 | 0 | 26 | 0 |
| Rendimiento | 5 | 0 | 0 | 0 | 5 | 0 |
| Accesibilidad | 2 | 1 | 0 | 0 | 1 | 0 |
| Compatibilidad | 1 | 0 | 0 | 0 | 1 | 0 |
| Manual | 6 | 0 | 0 | 0 | 6 | 0 |
| **Total** | **160** | **32** | **20** | **0** | **108** | **0** |

**Desglose por prioridad (§5):**

| Prioridad | Planificados | Aprobados | Aprobados parciales | Fallidos | Bloqueados | Tasa aprobación s/ §5 (Apr ÷ Plan P1 / Apr ÷ Ejec) |
|---|---|---|---|---|---|---|
| P1 (crítico release QG-R01) | 90 | 20 | 5 | 0 | 65 | **22.2 %** (20/90 P1; QG-R01 exige 100 %) |
| P2 | 54 | 11 | 9 | 0 | 34 | 20.4 % sobre planificados |
| P3 | 16 | 1 | 6 | 0 | 9 | 6.2 % sobre planificados |
| **Total** | **160** | **32** | **20** | **0** | **108** | **100.0 %** sobre 32 completos (32/32); **20 %** del catálogo (32/160) |

**Casos bloqueados y decisiones pendientes (108 casos `Bloqueado`; los 20 `Aprobado parcial` también quedan bloqueados de cierre completo por `[A VALIDAR]`)**

| TC | Motivo | Decisión o dato que falta (PA-xx, D-xx, C-x) | Responsable | Fecha prevista |
|---|---|---|---|---|
| TC-004 | C2 staging / emulador RED-OFF | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-005 | C2 staging + propuesta PA nueva | C2 staging, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-006 | C2 staging + D-12 / PA-10 | C2 staging, D-12, PA-10 | Jurídico IPR / QA | Por definir (al habilitar staging / F3) |
| TC-007 | C2 staging + PA-02 | C2 staging, PA-02 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-008 | D-12 + prueba integrada registro/RED-OFF abriendo enlace legal | D-12 | Jurídico IPR / QA | Por definir (al habilitar staging / F3) |
| TC-010 | C2 staging + SPK-01 | C2 staging, SPK-01 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-011 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-013 | C2 staging + PA-03 | C2 staging, PA-03 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-014 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-016 | Propuesta PA nueva | Propuesta PA nueva (DA-09 / retención carrito en logout) | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-017 | C2 staging + 2 dispositivos físicos | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-018 | C2 staging + app web | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-019 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-024 | C2 staging + 2 dispositivos/web + propuesta PA nueva | C2 staging, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-026 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-027 | C2 staging + correo real + ADR-001 §2 | C2 staging, ADR-001 §2 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-028 | Sin integration_test/ en instalación nueva sin sesión | Suite `integration_test/` en emulador/dispositivo | Desarrollo app / QA | Fase F2/F3 |
| TC-031 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-032 | C2 staging detrás de Cloudflare + 2 redes reales | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-033 | BFF real /mobile/v1 | BFF real /mobile/v1 + /products/{slug} y /search/suggestions en mock_bff | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-034 | C2 staging + SPK-01 | C2 staging, SPK-01 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-035 | Manual + D-12 | D-12 | Jurídico IPR / QA | Por definir (al habilitar staging / F3) |
| TC-040 | Sin integration_test/ para matar proceso completo | Suite `integration_test/` en emulador/dispositivo | Desarrollo app / QA | Fase F2/F3 |
| TC-044 | Falta paso 4 directo a POST /cart/validate (101 IDs y cantidades 0/100 → 400); pasos 1–3 cliente/contrato pasan en cart_data_test.dart y cart_controller_test.dart | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-047 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-050 | Falta golden de resumen del carrito requerido en criterio (golden + texto); cálculos y ausencia de textos prohibidos pasan en cart_screen_test.dart | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-053 | Faltan golden y casos explícitos de P-SINPRECIO en marca y Liquidaciones (brands_and_sale_test.dart); inicio, listado, búsqueda, carrito y ficha sí pasan | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-055 | Dispositivo físico con WhatsApp + D-04 | D-04 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-057 | Falta simular tableta sin telefonía cuando tel: devuelve false | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-060 | Manual + dispositivos físicos Android 11+ e iPhone con/sin WhatsApp | Dispositivos físicos / matriz RNF-082 | QA / Gerencia TI (D-15) | Por definir (al habilitar staging / F3) |
| TC-062 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-063 | C2 staging / BFF real /mobile/v1 | C2 staging, BFF real /mobile/v1 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-065 | C2 staging / WordPress detenido | C2 staging, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-066 | C2 staging + SPK-01 + dispositivos físicos | C2 staging, SPK-01 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-067 | C2 staging + Wompi sandbox + SPK-01 + dispositivos físicos Android/iOS | C2 staging, Wompi sandbox, SPK-01 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-068 | C2 staging + Wompi sandbox + SPK-01 | C2 staging, Wompi sandbox, SPK-01 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-069 | C2 staging + Wompi sandbox + SPK-01 | C2 staging, Wompi sandbox, SPK-01 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-070 | C2 staging + Wompi sandbox + PA-11 + D-02 | C2 staging, Wompi sandbox, PA-11, D-02 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-071 | C2 staging + Wompi sandbox + SPK-01 + ADR-001 C1/C2 | C2 staging, Wompi sandbox, SPK-01, ADR-001 C1/C2 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-072 | C2 staging + Wompi sandbox + SPK-01 | C2 staging, Wompi sandbox, SPK-01 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-073 | C2 staging + Wompi sandbox + PA-11 + D-02 | C2 staging, Wompi sandbox, PA-11, D-02 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-074 | C2 staging + SPK-01 + propuesta PA nueva | C2 staging, SPK-01, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-075 | C2 staging + Wompi sandbox | C2 staging, Wompi sandbox | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-076 | C2 staging + assetlinks/AASA reales (D-14) + arranque en frío/segundo plano en dispositivo | C2 staging, D-14 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-078 | Falta escenario simulado BFF de pedido ajeno CLI-02 (paso 2); ignorar status=paid y order=999 falsificados del enlace sí pasa en checkout_result_screen_test.dart | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-079 | Falta golden de CheckoutResultScreen (+ golden) + PA-12; los 7 estados en widget test pasan en checkout_result_screen_test.dart | Golden de pantalla + PA-12 | Desarrollo app / QA | Siguiente iteración F2/F3 |
| TC-080 | C2 staging + Wompi sandbox + D-02 + PA-12 | C2 staging, Wompi sandbox, D-02, PA-12 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-081 | C2 staging + Wompi sandbox + SPK-01 | C2 staging, Wompi sandbox, SPK-01 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-082 | C2 staging + dominio real + ADR-001 C1/C2 + D-14 | C2 staging, ADR-001 C1/C2, D-14 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-083 | C2 staging CLI-01/CLI-02 | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-085 | Falta golden de OrderDetailScreen (+ golden) + PA-12; detalle, campos no soportados y 360 dp sin overflow pasan en orders_screens_test.dart | Golden de pantalla + PA-12 | Desarrollo app / QA | Siguiente iteración F2/F3 |
| TC-086 | C2 staging CLI-01 vs CLI-02 | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-088 | Falta prueba POST /me/deletion sin token/token inválido en contrato/staging + propuesta PA nueva; contraseña requerida e idempotencia cliente pasan en profile_controllers_test.dart | propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-089 | C2 staging + PA-09 | C2 staging, PA-09 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-090 | C2 staging + PA-09 | C2 staging, PA-09 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-091 | Falta escenario simulado 503 en eliminación de cuenta en profile_controllers_test.dart | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-092 | Manual + S-05 | S-05 | Jurídico IPR / QA | Por definir (al habilitar staging / F3) |
| TC-094 | C2 staging CLI-01 | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-095 | C2 staging + propuesta PA nueva | C2 staging, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-096 | Depende de TC-075 en staging (paso 5 prellenado) + propuesta PA nueva; reglas Colombia/dpto/ciudad y doble toque pasan en profile_screens_test.dart | propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-097 | C2 staging / buzón corporativo + D-12 | C2 staging, D-12 | Jurídico IPR / QA | Por definir (al habilitar staging / F3) |
| TC-098 | C2 staging + PA-02 | C2 staging, PA-02 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-100 | Faltan respuestas 500/503/504/timeout sobre BranchesScreen | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-101 | Falta prueba integrada con 60 ítems / 3ª página | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-102 | Falta suite unificada de los 6 fallos consecutivos sobre carrito C3 | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-104 | C2 staging + BFF real /mobile/v1 | C2 staging, BFF real /mobile/v1 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-105 | Sin prueba integrada etiquetada TC-105 que encadene listado stale + compra condicionada | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-106 | Dispositivo/emulador RED-OFF tras navegación previa + DN-10 | DN-10 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-107 | Rendimiento en dispositivos físicos con perfiles RED-4G-LENTA/DEGRADADA/INTERMITENTE | MED-01, DN-01 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-108 | C2 staging + RF-022 | C2 staging, RF-022 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-109 | C2 staging + propuesta PA nueva | C2 staging, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-110 | C2 staging + muestra real de SKUs de IPR + RF-022 | C2 staging, RF-022 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-111 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-112 | C2 staging + propuesta PA nueva | C2 staging, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-114 | C2 staging + propuesta PA nueva | C2 staging, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-115 | Falta golden de HomeScreen (+ golden); buscador, 8 categorías, WhatsApp, marcas y autofocus pasan en home_screen_test.dart y search_screen_test.dart | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-116 | C2 staging + acceso WooCommerce + PA-04 | C2 staging, PA-04 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-117 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-119 | Falta golden/Alchemist de ProductCard en 1,0x y 2,0x a 360 dp | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-120 | C2 staging | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-121 | C2 staging + propuesta PA nueva | C2 staging, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-122 | Falta golden de ProductDetailScreen exigido en criterio; galería, stock genérico, cantidad, avisos y sin imagen pasan en product_detail_screen_test.dart | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-125 | Falta prueba de fallback sin app de mapas (url_launcher=false en Cómo llegar) + verificación manual en dispositivo; tel:/WhatsApp/codificación URL pasan en branches_*_test.dart | Cobertura de prueba faltante en `test/` (golden o escenario simulado) | Desarrollo app / QA | Siguiente iteración F2 |
| TC-126 | C2 staging + fuente real de sedes + D-09 + PA-04 | C2 staging, D-09, PA-04 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-131 | C2 staging + revisión manual del buzón corporativo de PQRS | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-132 | Sin URLs legales reales publicadas ni verificación HTTP 200 nocturna | D-12 | Jurídico IPR / QA | Por definir (al habilitar staging / F3) |
| TC-134 | C2 staging + /api/revalidate HMAC + PA-04 | C2 staging, PA-04 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-135 | C2 staging P-OFERTA | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-136 | C2 staging QA-MARCA-A | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-137 | C2 staging + D-10 | C2 staging, D-10 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-138 | C2 staging + D-07 + D-09 | C2 staging, D-07, D-09 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-143 | Manual + D-08, D-10, D-12, PA-07, S-05 | D-08, D-10, D-12, PA-07, S-05 | Jurídico IPR / QA | Por definir (al habilitar staging / F3) |
| TC-144 | BFF real /mobile/v1 en CI + openapi-diff + humo staging | BFF real /mobile/v1 | TI web / Backend BFF | Por definir (al habilitar staging / F3) |
| TC-145 | Repositorio BFF real inexistente | BFF real | TI web / Backend BFF | Por definir (al habilitar staging / F3) |
| TC-146 | Repositorio BFF real inexistente | BFF real | TI web / Backend BFF | Por definir (al habilitar staging / F3) |
| TC-147 | BFF real con handoff-ticket e idempotencia 60s/409 | BFF real | TI web / Backend BFF | Por definir (al habilitar staging / F3) |
| TC-148 | C2 staging WordPress ipr/v1/m | C2 staging + plugin `ipr/v1/m` | TI web / WordPress | Por definir (al habilitar staging / F3) |
| TC-149 | C2 staging WordPress ipr/v1/m | C2 staging + plugin `ipr/v1/m` | TI web / WordPress | Por definir (al habilitar staging / F3) |
| TC-150 | C2 staging WordPress ipr/v1/m | C2 staging + plugin `ipr/v1/m` | TI web / WordPress | Por definir (al habilitar staging / F3) |
| TC-151 | Repositorio BFF real + PA-12 | BFF real, PA-12 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-152 | C2 staging + DN-07 + MED-01 + ADR-001 C4 | C2 staging, DN-07, MED-01, ADR-001 C4 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-153 | C2 staging (2 instancias BFF) + propuesta PA nueva | C2 staging, propuesta PA nueva | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-154 | Dispositivos físicos (build profile/release) + MED-01 + MED-11 | MED-01, MED-11 · Dispositivos físicos / matriz RNF-082 | QA / Gerencia TI (D-15) | Por definir (al habilitar staging / F3) |
| TC-155 | Dispositivos físicos (build profile/release, DevTools/memoria/tamaño) + MED-11 | MED-11 | QA / Gerencia TI (D-15) | Por definir (al habilitar staging / F3) |
| TC-156 | C2 staging + MED-07 + MED-08 | C2 staging, MED-07, MED-08 | QA / TI web | Por definir (al habilitar staging / F3) |
| TC-158 | Manual + dispositivos físicos Android (TalkBack) e iOS (VoiceOver) al 200 % | Dispositivos físicos / matriz RNF-082 | QA / Gerencia TI (D-15) | Por definir (al habilitar staging / F3) |
| TC-159 | Matriz ≥ 8 dispositivos físicos + DN-01 + MED-01 + SPK-02 | DN-01, MED-01, SPK-02 | QA / Gerencia TI (D-15) | Por definir (al habilitar staging / F3) |
| TC-160 | CI remoto + C2 staging disponible | C2 staging | QA / TI web | Por definir (al habilitar staging / F3) |

**Defectos del ciclo (`CIC-001`)**

| ID | Severidad | TC / AC / ST | Título | Estado | Responsable | Fecha de apertura | Fecha de cierre |
|---|---|---|---|---|---|---|---|
| DEF-001 | S2 | `ST-124` · `TC-077` | `DeepLinkPolicy.isDeepLink` omitía `uri.hasScheme` permitiendo esquemas `javascript:`, `data:` y `file:` en `computeRedirect` (`#7`) | **Verificado (local)** | `security` (`#12`) / `verifier` (`#21`) | 2026-11-23 | 2026-11-23 |
| DEF-002 | S3 | `ST-122` · `TC-125` | `ExternalUrlPolicy` aceptaba `/maps-evil` o `..`/`%2e` en `www.google.com/maps` y comparación sensible a mayúsculas en `extraHttpsHosts` (`#7`) | **Verificado (local)** | `security` (`#12`) / `verifier` (`#21`) | 2026-11-23 | 2026-11-23 |
| DEF-003 | S2 | `TC-157` (`RNF-068/070`) | `DropdownButtonFormField` sin `isExpanded: true` y falta de `errorMaxLines` desbordaban al `200 %` en `pqrs_screen.dart` (`50`–`90 px`) y `btu_calculator_screen.dart` (`25 px`) (`#10`) | **Verificado (local)** | `a11y` (`#10`) / `verifier` (`#21`) | 2026-11-23 | 2026-11-23 |
| DEF-004 | S3 | Puerta 6 CI | `tool/merge_arb.dart:86` fallaba `--check` en Windows por `\r\n` (`core.autocrlf = true`) sobre `l10n/app_es.arb` (`#15`) | **Verificado (local)** | `e2e` (`#17`) / `verifier` (`#21`) | 2026-11-23 | 2026-11-23 |
| DEF-005 | S4 | `ST-108` · `ST-109` | `lib/core/observability/pii_scrubber.dart:27-28` exige `>= 7` dígitos en teléfonos (comentario indica `6`); cadenas libres dependen de `toString()` redactado o `?query` (`#7`, `#11`) | **Abierto (backlog)** | Desarrollo app | 2026-11-23 | — |
| DEF-006 | S4 | `ST-016` *(huérfano)* | `test/unit/tool/contract_and_mock_test.dart:33` referencia `ST-016`, identificador inexistente en `06_security/security_testing.md` (SCA termina en `ST-015`, viola `QG-M08`) | **Abierto (backlog)** | QA / `traceability` | 2026-11-23 | — |
| DEF-007 | S3 | `TC-144` · `PT-19` | En `mock_bff` (`openapi.yaml`), `GET /filters` sintetiza `key: "ejemplo"` (descartado por `mapFilters`) y `GET /orders*` sintetiza `currency: "ejemplo"` sin `const: COP` (`#6`) | **Abierto (backlog)** | Contrato / Desarrollo | 2026-11-23 | — |
| DEF-008 | S2 | `ST-085` · `ST-125` · `TC-082` | `deploy/well-known/{assetlinks.json,apple-app-site-association}` mantienen `REEMPLAZAR_*` (`D-14`) y `secure_browser.dart:36-37` mantiene brecha `SPK-01` en iOS (`#7`) | **Abierto (bloqueante F3)** | TI / Desarrollo (`D-14`, `SPK-01`) | 2026-11-23 | — |

**Evaluación de puertas de *release* (`QG-R01` a `QG-R15`, solo referencia — `CIC-001` no es un candidato a *release*)**

| Puerta | Resultado en `CIC-001` | Evidencia / motivo |
|---|---|---|
| `QG-R01` Regresión P1 completa | **No cumple** (`20 / 90` P1 `Aprobado` = `22.2 %`) | Faltan *staging* `C2`, BFF real, dispositivos y completar brechas locales (`65` P1 bloqueados, `5` parciales) |
| `QG-R02` Compra de extremo a extremo | **Bloqueado** | `TC-067`, `TC-068`, `TC-069` bloqueados por `C2 staging`, `Wompi sandbox`, `SPK-01` y dispositivos |
| `QG-R03` Cero duplicados | **Bloqueado** | `TC-062` paso 4, `TC-071`, `TC-073`, `TC-147` bloqueados por `C2 staging` / BFF real (`Idempotency-Key` local probada en `mock_bff`) |
| `QG-R04` Sesiones y límites | **Parcial / Bloqueado** | `TC-021..023` `Aprobado` y `TC-020` `Aprobado parcial` en local; `TC-017`, `TC-018`, `TC-031`, `TC-148`, `TC-149` bloqueados por `C2 staging` |
| `QG-R05` Contrato y capacidad | **Bloqueado** | `TC-144` solo probado contra `mock_bff` (`DEF-007`); `TC-152` carga bloqueado por `C2 staging` + `DN-07`/`MED-01` |
| `QG-R06` Matriz de dispositivos | **Bloqueado** | `TC-159` no ejecutado (`0` dispositivos físicos probados; `DN-01`/`MED-01`/`SPK-02` pendientes) |
| `QG-R07` Rendimiento | **Bloqueado** | `TC-154..TC-156` no ejecutados (`build profile/release` en dispositivos y `C2 staging` ausentes) |
| `QG-R08` Accesibilidad | **Parcial / Bloqueado** | `TC-157` **`Aprobado`** en automático (`148/148` nuevas + pantallas críticas); `TC-158` TalkBack/VoiceOver manual **Bloqueado** |
| `QG-R09` Calidad de datos | **Parcial / Bloqueado** | `TC-054` **`Aprobado`** en simulado; `TC-053` (falta marca/Liquidaciones + golden) y `TC-104` (BFF real) **Bloqueado** |
| `QG-R10` Privacidad | **Bloqueado** | `TC-006`, `TC-035`, `TC-089`, `TC-092` bloqueados por `C2 staging`, `D-12`, `PA-09`, `S-05` (`TC-087` `Aprobado parcial` en cliente) |
| `QG-R11` Seguridad | **Bloqueado** | `23` `ST-*` válidos cubiertos solo en alcance cliente/estático/`mock_bff` en `test/`; F2-CI (`gitleaks`/SCA), F3 y F4 siguen **Pendientes** en `06_security/security_testing.md` |
| `QG-R12` Defectos | **En seguimiento** | `DEF-001..DEF-004` verificados; `DEF-008` (S2 abierto `D-14`/`SPK-01`) y `DEF-005..DEF-007` (S3/S4) abiertos |
| `QG-R13` Contenido aprobado | **Bloqueado** | `TC-035`, `TC-143` bloqueados por textos legales/garantía/estimación (`D-08`, `D-10`, `D-12`, `PA-07`) |
| `QG-R14` Estabilidad piloto | **No aplica en `CIC-001`** | Etapa F5 piloto no iniciada |
| `QG-R15` Condiciones ADR-001 | **Bloqueado** | Condiciones `C1..C4` (incl. *staging* `C2` y Cloudflare) no confirmadas |

**Cierre del ciclo (`CIC-001`)**

| Elemento | Valor |
|---|---|
| Verificación de integridad (sección 9) realizada por | **Pendiente** (solo el responsable de QA cierra tras completar verificación de §9) |
| Fecha de cierre | **En ejecución (ciclo abierto)** — última actualización local: `2026-11-23 10:25:53 -05:00` |
| Decisión recomendada por QA | **No apto para *release* aún.** Base local M0–M5 aprobada en CI local (`9/9` puertas, `2159/2159` pruebas, `95.6 %` cobertura), pero bloqueada para promoción a F3/RC por falta de *staging* `C2`, BFF real `/mobile/v1`, Wompi *sandbox*, dispositivos físicos y decisiones `[A VALIDAR]`. |

---

## 8. Registro de ciclos

| Ciclo | Fecha | Versión / *build* | Objetivo | Planificados | Aprobados | Fallidos | Bloqueados | Resultado global |
|---|---|---|---|---|---|---|---|---|
| `CIC-001` | 2026-11-23 | `1.0.0+1` (`d5a2d8a`+local) | Verificación local automatizada M0–M5 (`PT-19` + `PT-20`) | 160 | **32** *(+20 parciales)* | 0 | 108 | **En ejecución** (pendiente cierre QA, CI remoto y *staging*) |
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

## 10. Matriz AC → resultado (`CIC-001`, parcial local)

Un *script* de CI consolidará la matriz completa cuando exista ejecución en CI remoto y *staging*. **Estado tras `CIC-001` local (`verifier`, `#21`):**

| Concepto | Valor |
|---|---|
| AC del MVP | 490 |
| AC con al menos un resultado de ejecución en `CIC-001` | **150** *(trazados a los 52 TCs `Aprobado` o `Aprobado parcial`; además `270` de `490` aparecen referenciados en `test/` expandiendo `a/b` y `a..b`, `237` exactos)* |
| AC verificados (§5: todos sus `TC` en `Aprobado`, sin `[A VALIDAR]` ni `Seguridad`) | **75 de 490 (15.3 %)** |
| AC de seguridad con resultado en `06_security/security_testing.md` | **Pendiente de cierre en [security_testing.md](../06_security/security_testing.md)** (`140` `ST-*` siguen `NO EJECUTADO / Pendiente` en F2-CI/F3/F4; en local se automatizaron controles cliente/estáticos/`mock_bff` de `23` `ST-*` válidos + `1` huérfano `ST-016` en `DEF-006`) |

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

*Fin del documento. Ciclo CIC-001 en ejecución local (`2026-11-23`, `HEAD d5a2d8a` + cambios locales, 9/9 puertas en verde); pendiente cierre formal QA (§9), CI remoto, staging y dispositivos físicos.*

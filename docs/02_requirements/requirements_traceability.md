# Matriz de trazabilidad de requisitos — App móvil IPR

| | |
|---|---|
| **Fecha de generación** | 2026-11-18 |
| **Generado por** | Script de extracción sobre los Markdown de `docs/02_requirements/`, `docs/project/decisiones_pendientes.md` y `docs/03_architecture/architecture_decisions.md` (solo lectura). No contiene relaciones inventadas. |
| **Reglas** | ¿MVP? y MoSCoW de `functional_requirements.md` §1. US por la columna RF de `user_stories.md` §1; AC por el encabezado `#### US-xxx · RF-xxx` de `acceptance_criteria.md` §1. Tipos de prueba = tipos de los AC de la US más los AC-SEC que citan el RF en su texto. Dependencias = D-xx, ADR-xxx y PA-xx presentes en la fila del RF. `[A VALIDAR]` = AC cuyo texto contiene esa etiqueta. |

---

## 1. Trazabilidad RF → US → AC

"Automatizable" = cualquier tipo distinto de Manual. Los RF de fase 2 no tienen US ni AC en el documento (fuera del MVP), por eso su fila muestra "—".

| RF | US | AC (IDs) | Nº AC | MoSCoW | ¿MVP? | Tipos de prueba | AC-SEC que citan el RF | Dependencias (D/ADR/PA) | Nº [A VALIDAR] |
|---|---|---|---|---|---|---|---|---|---|
| RF-001 | US-001 | AC-001-1, AC-001-2, AC-001-3 | 3 | Must | sí | Widget, Integración | — | — | 0 |
| RF-002 | US-002 | AC-002-1, AC-002-2, AC-002-3, AC-002-4 | 4 | Must | sí | Widget, Integración | — | — | 1 |
| RF-003 | US-003 | AC-003-1, AC-003-2, AC-003-3, AC-003-4, AC-003-5 | 5 | Should | sí | Widget, Integración | — | PA-05 | 1 |
| RF-004 | US-004 | AC-004-1, AC-004-2 | 2 | Should | sí | Widget | — | — | 0 |
| RF-005 | US-005 | AC-005-1, AC-005-2, AC-005-3, AC-005-4 | 4 | Must | sí | Widget, Integración | — | — | 1 |
| RF-006 | US-006 | AC-006-1, AC-006-2 | 2 | Should | sí | Widget, Manual | — | D-08 | 1 |
| RF-007 | US-007 | AC-007-1, AC-007-2 | 2 | Should | sí | Widget | — | — | 0 |
| RF-008 | — | — | 0 | Could | fase 2 | — | — | D-07 | 0 |
| RF-009 | US-009 | AC-009-1, AC-009-2, AC-009-3, AC-009-4, AC-009-5, AC-009-6, AC-009-7 | 7 | Should | sí | Integración | — | ADR-001 | 0 |
| RF-010 | US-010 | AC-010-1, AC-010-2, AC-010-3, AC-010-4, AC-010-5, AC-010-6 | 6 | Must | sí | Widget, Integración, Manual | — | D-10, ADR-001 | 1 |
| RF-011 | US-011 | AC-011-1, AC-011-2, AC-011-3, AC-011-4, AC-011-5, AC-011-6, AC-011-7, AC-011-8 | 8 | Must | sí | Unitaria, Widget, Integración | — | D-05, ADR-001 | 1 |
| RF-012 | US-012 | AC-012-1, AC-012-2, AC-012-3, AC-012-4, AC-012-5 | 5 | Must | sí | Unitaria, Widget, Integración | — | ADR-002, D-04 | 1 |
| RF-013 | US-013 | AC-013-1, AC-013-2, AC-013-3, AC-013-4, AC-013-5, AC-013-6 | 6 | Must | sí | Widget, Integración | — | ADR-001 | 0 |
| RF-014 | US-014 | AC-014-1, AC-014-2, AC-014-3, AC-014-4 | 4 | Should | sí | Widget, Integración | — | D-10 | 1 |
| RF-015 | US-015 | AC-015-1, AC-015-2, AC-015-3, AC-015-4 | 4 | Should | sí | Widget, Integración | — | — | 2 |
| RF-016 | US-016 | AC-016-1, AC-016-2, AC-016-3, AC-016-4, AC-016-5 | 5 | Should | sí | Widget, Integración | — | ADR-001 | 0 |
| RF-017 | — | — | 0 | Could | fase 2 | — | — | — | 0 |
| RF-018 | US-018 | AC-018-1, AC-018-2, AC-018-3, AC-018-4, AC-018-5, AC-018-6 | 6 | Should | sí | Widget, Integración | — | ADR-001 | 0 |
| RF-019 | US-019 | AC-019-1, AC-019-2, AC-019-3, AC-019-4, AC-019-5, AC-019-6 | 6 | Must | sí | Integración, E2E | — | PA-04, ADR-001 | 4 |
| RF-020 | US-020 | AC-020-1, AC-020-2, AC-020-3, AC-020-4, AC-020-5, AC-020-6, AC-020-7 | 7 | Must | sí | Widget, Integración, Seguridad | — | ADR-001 | 1 |
| RF-021 | US-021 | AC-021-1, AC-021-2, AC-021-3, AC-021-4, AC-021-5 | 5 | Should | sí | Unitaria, Widget, Integración | — | ADR-001 | 2 |
| RF-022 | US-022 | AC-022-1, AC-022-2, AC-022-3, AC-022-4, AC-022-5 | 5 | Must | sí | Integración, Manual | — | — | 3 |
| RF-023 | US-023 | AC-023-1, AC-023-2, AC-023-3, AC-023-4, AC-023-5, AC-023-6 | 6 | Should | sí | Unitaria, Widget, Integración | — | — | 1 |
| RF-024 | — | — | 0 | Could | fase 2 | — | — | — | 0 |
| RF-025 | — | — | 0 | Could | fase 2 | — | — | D-12 | 0 |
| RF-026 | US-026 | AC-026-1, AC-026-2, AC-026-3, AC-026-4, AC-026-5, AC-026-6, AC-026-7 | 7 | Must | sí | Unitaria, Widget, Integración | — | — | 0 |
| RF-027 | US-027 | AC-027-1, AC-027-2, AC-027-3, AC-027-4, AC-027-5, AC-027-6 | 6 | Must | sí | Widget, Seguridad | — | ADR-001 | 1 |
| RF-028 | US-028 | AC-028-1, AC-028-2, AC-028-3 | 3 | Should | sí | Widget, Seguridad | — | D-10 | 1 |
| RF-029 | US-029 | AC-029-1, AC-029-2, AC-029-3, AC-029-4, AC-029-5, AC-029-6, AC-029-7, AC-029-8 | 8 | Must | sí | Unitaria, Widget, Integración | — | — | 1 |
| RF-030 | US-030 | AC-030-1, AC-030-2, AC-030-3, AC-030-4, AC-030-5 | 5 | Must | sí | Widget, Integración | — | ADR-002 | 0 |
| RF-031 | US-031 | AC-031-1, AC-031-2, AC-031-3, AC-031-4, AC-031-5 | 5 | Must | sí | Widget, Integración | — | D-05, PA-12 | 1 |
| RF-032 | US-032 | AC-032-1, AC-032-2, AC-032-3 | 3 | Should | sí | Widget, Manual | — | D-12 | 2 |
| RF-033 | — | — | 0 | Could | fase 2 | — | — | — | 0 |
| RF-034 | — | — | 0 | Could | fase 2 | — | — | D-10 | 0 |
| RF-035 | — | — | 0 | Won't | fase 2 | — | — | D-10 | 0 |
| RF-036 | — | — | 0 | Could | fase 2 | — | — | ADR-001 | 0 |
| RF-037 | US-037 | AC-037-1, AC-037-2, AC-037-3, AC-037-4 | 4 | Must | sí | Integración, E2E, Seguridad | — | — | 0 |
| RF-038 | US-038 | AC-038-1, AC-038-2, AC-038-3, AC-038-4, AC-038-5, AC-038-6, AC-038-7, AC-038-8 | 8 | Must | sí | Unitaria, Widget, Integración, Seguridad | — | ADR-001 | 2 |
| RF-039 | US-039 | AC-039-1, AC-039-2, AC-039-3, AC-039-4, AC-039-5, AC-039-6, AC-039-7 | 7 | Must | sí | Widget, Integración, Seguridad, Manual | — | D-12, PA-10 | 4 |
| RF-040 | US-040 | AC-040-1, AC-040-2, AC-040-3, AC-040-4, AC-040-5, AC-040-6, AC-040-7, AC-040-8, AC-040-9 | 9 | Must | sí | Unitaria, Widget, Integración, E2E, Seguridad | — | ADR-001 | 0 |
| RF-041 | US-041 | AC-041-1, AC-041-2, AC-041-3, AC-041-4, AC-041-5, AC-041-6, AC-041-7, AC-041-8 | 8 | Must | sí | Widget, Integración, E2E, Seguridad | — | ADR-001 | 2 |
| RF-042 | US-042 | AC-042-1, AC-042-2, AC-042-3, AC-042-4, AC-042-5, AC-042-6, AC-042-7, AC-042-8 | 8 | Must | sí | Widget, Integración, E2E, Seguridad | — | ADR-001 | 4 |
| RF-043 | US-043 | AC-043-1, AC-043-2, AC-043-3, AC-043-4, AC-043-5, AC-043-6 | 6 | Must | sí | Integración, E2E, Seguridad | — | ADR-001, ADR-002 | 1 |
| RF-044 | US-044 | AC-044-1, AC-044-2, AC-044-3, AC-044-4, AC-044-5, AC-044-6, AC-044-7, AC-044-8, AC-044-9, AC-044-10, AC-044-11 | 11 | Must | sí | Unitaria, Integración, E2E, Seguridad | — | ADR-001 | 2 |
| RF-045 | US-045 | AC-045-1, AC-045-2, AC-045-3, AC-045-4, AC-045-5, AC-045-6, AC-045-7, AC-045-8 | 8 | Must | sí | Widget, Integración, E2E, Seguridad | — | ADR-001 | 2 |
| RF-046 | — | — | 0 | Should | fase 2 | — | — | PA-02 | 0 |
| RF-047 | — | — | 0 | Could | fase 2 | — | — | PA-01, D-06 | 0 |
| RF-048 | US-048 | AC-048-1, AC-048-2, AC-048-3, AC-048-4, AC-048-5 | 5 | Should | sí | Seguridad | — | PA-03 | 2 |
| RF-049 | US-049 | AC-049-1, AC-049-2, AC-049-3, AC-049-4, AC-049-5, AC-049-6, AC-049-7, AC-049-8, AC-049-9 | 9 | Must | sí | Unitaria, Widget, Integración, Seguridad | — | ADR-002 | 0 |
| RF-050 | US-050 | AC-050-1, AC-050-2, AC-050-3, AC-050-4, AC-050-5, AC-050-6, AC-050-7, AC-050-8, AC-050-9, AC-050-10 | 10 | Must | sí | Integración, Seguridad | AC-SEC-6 | ADR-001 | 1 |
| RF-051 | US-051 | AC-051-1, AC-051-2, AC-051-3, AC-051-4, AC-051-5 | 5 | Must | sí | Unitaria, Widget, Seguridad | — | — | 1 |
| RF-052 | US-052 | AC-052-1, AC-052-2, AC-052-3, AC-052-4, AC-052-5, AC-052-6, AC-052-7, AC-052-8, AC-052-9, AC-052-10, AC-052-11, AC-052-12, AC-052-13, AC-052-14, AC-052-15, AC-052-16 | 16 | Must | sí | Widget, Integración, E2E, Seguridad | AC-SEC-1, AC-SEC-6 | ADR-001, ADR-002 | 3 |
| RF-053 | US-053 | AC-053-1, AC-053-2, AC-053-3, AC-053-4, AC-053-5, AC-053-6 | 6 | Must | sí | E2E, Seguridad, Manual | AC-SEC-1 | D-02, PA-12, ADR-002 | 1 |
| RF-054 | US-054 | AC-054-1, AC-054-2, AC-054-3, AC-054-4, AC-054-5 | 5 | Should | sí | E2E, Seguridad | — | — | 0 |
| RF-055 | US-055 | AC-055-1, AC-055-2, AC-055-3, AC-055-4, AC-055-5, AC-055-6, AC-055-7 | 7 | Must | sí | Integración, E2E, Seguridad, Manual | — | ADR-001 | 2 |
| RF-056 | US-056 | AC-056-1, AC-056-2, AC-056-3, AC-056-4, AC-056-5, AC-056-6, AC-056-7, AC-056-8, AC-056-9, AC-056-10 | 10 | Must | sí | Widget, Integración, E2E, Seguridad | — | D-02, PA-12 | 1 |
| RF-057 | US-057 | AC-057-1, AC-057-2, AC-057-3, AC-057-4, AC-057-5, AC-057-6, AC-057-7, AC-057-8, AC-057-9 | 9 | Must | sí | Widget, Integración, E2E, Seguridad | — | D-02, PA-11 | 3 |
| RF-058 | US-058 | AC-058-1, AC-058-2, AC-058-3, AC-058-4, AC-058-5, AC-058-6, AC-058-7, AC-058-8, AC-058-9 | 9 | Should | sí | Integración, Seguridad | — | — | 1 |
| RF-059 | — | — | 0 | Won't | fase 2 | — | — | ADR-001 | 0 |
| RF-060 | — | — | 0 | Won't | no | — | — | D-02 | 0 |
| RF-061 | — | — | 0 | Won't | fase 2 | — | — | — | 0 |
| RF-062 | US-062 | AC-062-1, AC-062-2, AC-062-3, AC-062-4, AC-062-5, AC-062-6 | 6 | Must | sí | Unitaria, Integración | — | ADR-002, D-04 | 1 |
| RF-063 | US-063 | AC-063-1, AC-063-2, AC-063-3, AC-063-4, AC-063-5 | 5 | Should | sí | Integración, Manual | — | — | 0 |
| RF-064 | US-064 | AC-064-1, AC-064-2, AC-064-3, AC-064-4 | 4 | Should | sí | Widget, Integración | — | — | 1 |
| RF-065 | US-065 | AC-065-1, AC-065-2, AC-065-3, AC-065-4, AC-065-5, AC-065-6 | 6 | Should | sí | Integración, Seguridad, Manual | — | ADR-002, PA-08, D-12 | 4 |
| RF-066 | — | — | 0 | Could | fase 2 | — | — | D-04, ADR-002 | 0 |
| RF-067 | — | — | 0 | Won't | fase 2 | — | — | D-04 | 0 |
| RF-068 | — | — | 0 | Could | fase 2 | — | — | ADR-002 | 0 |
| RF-069 | — | — | 0 | Could | fase 2 | — | — | — | 0 |
| RF-070 | — | — | 0 | Could | fase 2 | — | — | ADR-001, ADR-002 | 0 |
| RF-071 | — | — | 0 | Won't | no | — | — | D-11, D-12 | 0 |
| RF-072 | US-072 | AC-072-1, AC-072-2, AC-072-3, AC-072-4, AC-072-5, AC-072-6 | 6 | Must | sí | Widget, Integración | — | D-07, D-09 | 1 |
| RF-073 | US-073 | AC-073-1, AC-073-2, AC-073-3, AC-073-4 | 4 | Must | sí | Widget, Manual | — | D-09 | 1 |
| RF-074 | US-074 | AC-074-1, AC-074-2, AC-074-3, AC-074-4, AC-074-5 | 5 | Must | sí | Widget, Integración | — | — | 0 |
| RF-075 | US-075 | AC-075-1, AC-075-2, AC-075-3, AC-075-4, AC-075-5 | 5 | Should | sí | Unitaria, Integración, Seguridad, Manual | — | — | 0 |
| RF-076 | US-076 | AC-076-1, AC-076-2, AC-076-3, AC-076-4, AC-076-5, AC-076-6 | 6 | Must | sí | Integración, E2E, Seguridad | — | D-09, ADR-001 | 1 |
| RF-077 | — | — | 0 | Should | fase 2 | — | — | D-09 | 0 |
| RF-078 | — | — | 0 | Could | fase 2 | — | — | D-12 | 0 |
| RF-079 | US-079 | AC-079-1, AC-079-2, AC-079-3, AC-079-4, AC-079-5 | 5 | Should | sí | Widget, Seguridad, Manual | — | ADR-001 | 1 |
| RF-080 | US-080 | AC-080-1, AC-080-2, AC-080-3, AC-080-4 | 4 | Should | sí | Widget, Integración, Manual | — | D-12, PA-06 | 2 |
| RF-081 | — | — | 0 | Could | fase 2 | — | — | PA-06 | 0 |
| RF-082 | — | — | 0 | Could | fase 2 | — | — | ADR-001 | 0 |
| RF-083 | — | — | 0 | Won't | no | — | — | — | 0 |
| RF-084 | — | — | 0 | Could | fase 2 | — | — | ADR-001 | 0 |
| RF-085 | US-085 | AC-085-1, AC-085-2, AC-085-3, AC-085-4, AC-085-5, AC-085-6, AC-085-7 | 7 | Should | sí | Unitaria, Widget | — | D-08 | 4 |
| RF-086 | US-086 | AC-086-1, AC-086-2, AC-086-3, AC-086-4, AC-086-5 | 5 | Should | sí | Unitaria | — | D-08 | 2 |
| RF-087 | US-087 | AC-087-1, AC-087-2, AC-087-3 | 3 | Must | sí | Widget, Manual | — | D-08 | 1 |
| RF-088 | US-088 | AC-088-1, AC-088-2, AC-088-3, AC-088-4 | 4 | Must | sí | Unitaria, Widget, Integración | — | D-08 | 1 |
| RF-089 | US-089 | AC-089-1, AC-089-2, AC-089-3, AC-089-4, AC-089-5 | 5 | Should | sí | Widget, Integración | — | D-08 | 1 |
| RF-090 | — | — | 0 | Could | fase 2 | — | — | D-11, D-12, ADR-001 | 0 |
| RF-091 | — | — | 0 | Could | fase 2 | — | — | D-11, D-12 | 0 |
| RF-092 | — | — | 0 | Won't | no | — | — | D-11, D-12 | 0 |
| RF-093 | — | — | 0 | Could | fase 2 | — | — | — | 0 |
| RF-094 | US-094 | AC-094-1, AC-094-2, AC-094-3, AC-094-4, AC-094-5 | 5 | Must | sí | Widget, Integración, Manual | — | PA-07 | 2 |
| RF-095 | US-095 | AC-095-1, AC-095-2, AC-095-3, AC-095-4 | 4 | Should | sí | Widget, Integración, Manual | — | D-12 | 0 |
| RF-096 | US-096 | AC-096-1, AC-096-2, AC-096-3, AC-096-4, AC-096-5, AC-096-6, AC-096-7, AC-096-8, AC-096-9, AC-096-10, AC-096-11, AC-096-12 | 12 | Must | sí | Unitaria, Widget, Integración, Seguridad | — | ADR-001 | 2 |
| RF-097 | US-097 | AC-097-1, AC-097-2, AC-097-3, AC-097-4, AC-097-5, AC-097-6 | 6 | Must | sí | Integración, E2E, Manual | — | ADR-001 | 2 |
| RF-098 | — | — | 0 | Could | fase 2 | — | — | — | 0 |
| RF-099 | US-099 | AC-099-1, AC-099-2, AC-099-3, AC-099-4, AC-099-5, AC-099-6, AC-099-7 | 7 | Must | sí | Widget, Integración, Seguridad, Manual | — | D-12 | 2 |
| RF-100 | — | — | 0 | Could | fase 2 | — | — | D-12 | 0 |
| RF-101 | — | — | 0 | Could | fase 2 | — | — | D-12 | 0 |
| RF-102 | — | — | 0 | Won't | no | — | — | D-12 | 0 |
| RF-103 | — | — | 0 | Won't | fase 2 | — | — | — | 0 |
| RF-104 | US-104 | AC-104-1, AC-104-2, AC-104-3, AC-104-4, AC-104-5, AC-104-6, AC-104-7, AC-104-8, AC-104-9, AC-104-10 | 10 | Must | sí | Unitaria, Widget, Integración, Seguridad | — | — | 2 |
| RF-105 | US-105 | AC-105-1, AC-105-2, AC-105-3, AC-105-4, AC-105-5, AC-105-6, AC-105-7, AC-105-8, AC-105-9, AC-105-10 | 10 | Must | sí | Unitaria, Widget, Integración, Seguridad | — | — | 3 |
| RF-106 | US-106 | AC-106-1, AC-106-2, AC-106-3, AC-106-4, AC-106-5, AC-106-6, AC-106-7, AC-106-8 | 8 | Should | sí | Unitaria, Widget, Integración, Seguridad | — | — | 1 |
| RF-107 | US-107 | AC-107-1, AC-107-2, AC-107-3, AC-107-4, AC-107-5, AC-107-6, AC-107-7, AC-107-8, AC-107-9 | 9 | Must | sí | Unitaria, Widget, Integración, E2E, Seguridad | — | ADR-001 | 1 |
| RF-108 | US-108 | AC-108-1, AC-108-2, AC-108-3, AC-108-4, AC-108-5, AC-108-6 | 6 | Should | sí | Unitaria, Widget, Integración, Seguridad | — | ADR-001 | 1 |
| RF-109 | — | — | 0 | Could | fase 2 | — | — | — | 0 |
| RF-110 | US-110 | AC-110-1, AC-110-2, AC-110-3, AC-110-4, AC-110-5, AC-110-6, AC-110-7, AC-110-8, AC-110-9, AC-110-10, AC-110-11, AC-110-12, AC-110-13, AC-110-14, AC-110-15, AC-110-16 | 16 | Must | sí | Widget, Integración, E2E, Seguridad, Manual | — | D-12, PA-09 | 9 |
| RF-111 | US-111 | AC-111-1, AC-111-2, AC-111-3, AC-111-4, AC-111-5 | 5 | Should | sí | Widget, Integración, Seguridad | — | D-12 | 1 |
| RF-112 | — | — | 0 | Could | fase 2 | — | — | ADR-001 | 0 |
| RF-113 | — | — | 0 | Could | fase 2 | — | — | D-13 | 0 |

---

## 2. Trazabilidad RNF → prioridad → verificación → línea base

Método y fase = columnas "Método" y "Momento" de `non_functional_requirements.md` §4. MED = `MED-xx` citados en la fila del RNF; la definición de cada MED está en §6.

| RNF | Prioridad | Método de verificación | MED-xx (línea base requerida) | Fase de medición |
|---|---|---|---|---|
| RNF-001 | Must | Medición en *profile/release* (trazas de arranque de Android y de Xcode Instruments), 20 corridas por dispositivo. | MED-11 | F2 (spike), F3, F5 |
| RNF-002 | Should | Igual que RNF-001. | MED-11 | F3, F5 |
| RNF-003 | Must | Pruebas de integración con red emulada; cronometraje por pantalla. | MED-11, MED-03 | F3, F5 |
| RNF-004 | Should | Flutter DevTools en modo *profile*; Android vitals (renderizado) en piloto. | MED-11 | F2, F3, F5 |
| RNF-005 | Should | Perfil de tiempos en dispositivo de referencia. | MED-11 | F3 |
| RNF-006 | Should | DevTools de memoria; *monkey/scripts*; Instruments (Leaks). | MED-11 | F3, F5 |
| RNF-007 | Should | Battery Historian / perfilador de energía de Android; Xcode Energy Gauge. | MED-11 | F3, F5 |
| RNF-008 | Should | Informe de tamaño de la tienda / `--analyze-size`; comparación por versión en CI. | MED-11 | F2 (primer *build* release), F4 |
| RNF-009 | Must | Inspección de respuestas del BFF/CDN sobre muestra de 100 productos. | MED-07 | F1 (diseño del contrato), F3 |
| RNF-010 | Should | Revisión de configuración + prueba de uso prolongado. | — | F2, F3 |
| RNF-011 | Should | Captura de red en *staging*; revisión de cabeceras `Content-Encoding`. | MED-08 | F3 |
| RNF-012 | Must | Pruebas de carga contra *staging*; histogramas del BFF (RNF-100). | MED-03, MED-16 | F3, F5, F6 |
| RNF-013 | Must | Prueba E2E con red lenta en *staging*. | MED-03, MED-14 | F3 |
| RNF-014 | Must | Prueba de carga con *k6*/*Artillery* contra *staging* (D-16). | MED-01, MED-04 | F3, F5 |
| RNF-015 | Must | Comparación de métricas web antes/durante el piloto. | MED-01, MED-03 | F3, F5 |
| RNF-016 | Should | Prueba de resistencia de 2 h + métricas del proceso. | MED-04, MED-17 | F3, F5, F6 |
| RNF-017 | Should | Prueba: reiniciar el proceso durante un ataque de fuerza bruta simulado. | — | F1, F3 |
| RNF-018 | Should | Prueba de pico con fallos de caché forzados. | MED-03 | F3 |
| RNF-019 | Should | Monitoreo sintético (RNF-102) y revisión mensual. | MED-05 | F5, F6 |
| RNF-020 | Must | Pruebas en modo avión; *golden tests* de estado sin conexión. | — | F3 |
| RNF-021 | Must | Revisión de código + pruebas con red inestable emulada. | — | F2, F3 |
| RNF-022 | Must | Inyección de fallos en *staging* (bloquear `wc/v3`). | — | F3 |
| RNF-023 | Must | Reiniciar el proceso y consultar durante el calentamiento (100 solicitudes). | MED-17 | F3 |
| RNF-024 | Must | Pruebas E2E en *staging* con Wompi sandbox. | MED-14 | F3, F4 |
| RNF-025 | Must | E2E: pago aprobado, rechazado, cancelado, abandono del navegador. | MED-14 | F3 |
| RNF-026 | Must | Prueba con ticket expirado a propósito. | — | F3 |
| RNF-027 | Must | Revisión de código + pruebas de fallos (4xx/5xx/timeouts). | — | F2, F3 |
| RNF-028 | Must | Pruebas automatizadas con tokens expirados y concurrencia. | — | F3 |
| RNF-029 | Should | Prueba en *staging* cambiando la configuración. | — | F1, F3 |
| RNF-030 | Should | Ensayo de reversa; pipeline de contrato. | MED-04 | F3, F4 |
| RNF-031 | Must | Pruebas de instrumentación + E2E. | — | F3 |
| RNF-032 | Must | Tráfico sintético de la app en *staging*/piloto; análisis de eventos del WAF. | MED-15 | F3, F5 |
| RNF-033 | Must | Lista de verificación MASVS + pruebas MASTG sobre el *build* de release. | — | F3, F4 |
| RNF-034 | Must | Revisión estática + inspección del sandbox en dispositivo rooteado/*jailbroken* de pruebas. | — | F2, F4 |
| RNF-035 | Should | Revisión de manifiestos + pruebas manuales. | — | F2, F4 |
| RNF-036 | Must | Escaneo de secretos en cada PR + análisis de cadenas del binario antes de publicar. | — | F2, F4 |
| RNF-037 | Must | Revisión de configuración + captura con proxy de pruebas + escaneo TLS del dominio del BFF. | MED-15 | F2, F4 |
| RNF-038 | Could | Si se adopta: prueba de rotación en *staging*. | — | F1 (decisión DN-05) |
| RNF-039 | Must | Pruebas de integración en *staging* (login web + app + otro dispositivo). | — | F3, F4 |
| RNF-040 | Must | Pruebas de integración. | — | F3 |
| RNF-041 | Must | Prueba negativa por endpoint. | — | F3 |
| RNF-042 | Must | Ataque simulado automatizado en *staging*. | MED-10 | F3, F4 |
| RNF-043 | Must | Matriz de pruebas por endpoint + pruebas de IDOR. | — | F3, F4 |
| RNF-044 | Must | Revisión de código + pruebas de contrato y de valores límite. | — | F2, F3 |
| RNF-045 | Must | Pruebas de manipulación de precio, repetición de ticket y redirección abierta en *staging*. | — | F3, F4 |
| RNF-046 | Must | Pruebas con una app "maliciosa" que registra el mismo esquema; verificación de enlaces. | — | F3, F4 |
| RNF-047 | Must | Prueba automatizada con valores canario + revisión de configuración de logs. | — | F2, F3, F4 |
| RNF-048 | Must | `flutter pub`/OSV-Scanner, `npm audit`, revisión de plugins de WordPress en cada PR y antes de publicar. | MED-09 | F2, F4, F6 |
| RNF-049 | Must | Configuración del pipeline revisada en F2. | — | F2 |
| RNF-050 | Must | Prueba por tercero; seguimiento de hallazgos. | — | F4 |
| RNF-051 | Must | Revisión del manifiesto/*entitlements* y del pipeline. | — | F2, F4 |
| RNF-052 | Should | Revisión de manifiesto + MASTG. | — | F2, F4 |
| RNF-053 | Should | Pruebas de integración. | — | F3 |
| RNF-054 | Could | Decisión en F1. | — | F1 |
| RNF-055 | Must | Lista de verificación previa a publicar. | — | F4 |
| RNF-056 | Must | Pruebas de integración + consulta de datos en *staging*. | — | F3, F4 |
| RNF-057 | Must | Revisión de UI + revisión de Jurídico. | — | F3, F4 |
| RNF-058 | Must | Prueba E2E + revisión de datos tras la baja. | — | F3, F4 |
| RNF-059 | Must | Revisión del proceso + simulacro de solicitud. | — | F4, F6 |
| RNF-060 | Must | Revisión de manifiestos + inventario firmado. | — | F2, F4 |
| RNF-061 | Must | Captura de tráfico con proxy en *staging* + revisión legal. | — | F2, F4 |
| RNF-062 | Must | Inspección del sistema de archivos tras cerrar sesión. | — | F3 |
| RNF-063 | Should | Revisión de configuración y auditoría de retención. | — | F4, F6 |
| RNF-064 | Must | Dictamen de Jurídico. | — | F4 |
| RNF-065 | Must | Revisión de contenidos y fuentes de datos. | — | F3, F4 |
| RNF-066 | Could (Must si se habilitan) | Prueba de flujo y de segmentación. | — | F4 (si se habilita) |
| RNF-067 | Must | Lista de verificación por criterio + pruebas con tecnologías de apoyo. | — | F3, F4 |
| RNF-068 | Must | Pruebas con escala 2,0 en ambos sistemas + *golden tests*. | — | F2, F3 |
| RNF-069 | Must | Auditoría de la paleta (tokens) + verificación automática por pantalla. | MED-12 | F1 (paleta), F3 |
| RNF-070 | Must | Pruebas manuales con TalkBack y VoiceOver + guías automáticas de Flutter (etiquetas, objetivos) en pruebas de widgets. | — | F3, F4 |
| RNF-071 | Must | Guías automáticas de objetivos de Flutter en pruebas de widgets + inspector de accesibilidad. | — | F2, F3 |
| RNF-072 | Must | Revisión de funciones con gestos + prueba con accesibilidad de interruptores. | — | F3 |
| RNF-073 | Must | Pruebas de widgets + revisión manual. | — | F2, F3 |
| RNF-074 | Should | Revisión + pruebas con la preferencia del SO. | — | F3 |
| RNF-075 | Should | Pruebas manuales con teclado externo y accesibilidad de interruptores. | — | F3 |
| RNF-076 | Must | Revisión de diseño + simulación de daltonismo. | — | F1, F3 |
| RNF-077 | Should | Revisión de diseño + prueba manual del flujo de pago. | MED-11 | F3 |
| RNF-078 | Must | Revisión de `minSdk` + pruebas en la matriz de dispositivos. | MED-01 | F1 (decisión), F3 |
| RNF-079 | Must | Revisión del objetivo de despliegue + pruebas en dispositivos. | MED-01 | F1, F3 |
| RNF-080 | Must | Revisión de la documentación de las tiendas en F4 y cada año. | — | F4, F6 |
| RNF-081 | Should | Pruebas en emuladores y matriz de dispositivos, incluyendo escala de fuente al 200 %. | — | F3 |
| RNF-082 | Should | Ejecución de la suite en cada candidato a versión. | MED-01 | F3, F4 |
| RNF-083 | Must | Emulación de red en pruebas manuales y E2E. | — | F3 |
| RNF-084 | Must | Revisión de código y de pantallas. | — | F2, F3 |
| RNF-085 | Must | Detección de cambios incompatibles de OpenAPI en CI + pruebas de contrato. | — | F2, F3, F6 |
| RNF-086 | Should | Prueba en dispositivo sin Chrome. | — | F3 |
| RNF-087 | Must | Paso de CI en cada PR. | — | F2 |
| RNF-088 | Must | Paso de CI. | — | F2 |
| RNF-089 | Should (Must en módulos críticos) | `flutter test --coverage` en CI con umbral. | — | F2, F3 |
| RNF-090 | Must | Pruebas automatizadas en CI contra *staging*. | — | F2, F3 |
| RNF-091 | Must | Prueba de integración en *staging*. | — | F3, F4 |
| RNF-092 | Should | Pruebas unitarias con tabla de vectores validada por Ingeniería IPR. | — | F2, F3 |
| RNF-093 | Must | Revisión de configuración del pipeline. | — | F2, F4 |
| RNF-094 | Should | Revisión + herramienta de actualizaciones. | — | F2, F6 |
| RNF-095 | Must | Reglas de protección de rama. | — | F2 |
| RNF-096 | Should | Revisión por versión. | — | F2, F4 |
| RNF-097 | Must | Fallos provocados a propósito en *staging* y piloto. | — | F2, F5 |
| RNF-098 | Must | Panel de estabilidad (Play Console, App Store Connect, proveedor de fallos). | — | F5, F6 |
| RNF-099 | Must | Revisión de logs en *staging* con valores canario. | — | F2, F3 |
| RNF-100 | Must | Revisión del panel en F3. | — | F3, F5 |
| RNF-101 | Must | Simulacro de cada alerta en *staging*. | — | F5, F6 |
| RNF-102 | Should | Configuración del monitor. | — | F5, F6 |
| RNF-103 | Should | Verificación de eventos en *staging*. | — | F3, F5 |
| RNF-104 | Should | Panel de la tienda/proveedor. | MED-01 | F5, F6 |
| RNF-105 | Must | Pruebas de integración + revisión de registros. | MED-10 | F3, F6 |
| RNF-106 | Must | Verificación automática + muestra manual. | MED-06 | F3, F5, F6 |
| RNF-107 | Must | Verificación automática diaria sobre el catálogo expuesto. | MED-06 | F3, F6 |
| RNF-108 | Must | Verificación automática (HTTP 200 y dimensiones). | MED-06, MED-07 | F3, F6 |
| RNF-109 | Should | Verificación automática + muestra manual. | MED-06 | F3, F6 |
| RNF-110 | Must | Verificación automática + prueba de búsqueda. | MED-06 | F3, F6 |
| RNF-111 | Should | Comparación BFF vs. WooCommerce en muestra + auditoría. | MED-06, MED-17 | F3, F5 |
| RNF-112 | Must | Comparación automatizada + prueba de propagación. | MED-06 | F3, F6 |
| RNF-113 | Must | Recorrido automático en CI/monitor. | — | F3, F6 |
| RNF-114 | Should | Validación del conjunto de datos + prueba de mapa. | — | F3 |
| RNF-115 | Should | Revisión de contenidos. | — | F3 |
| RNF-116 | Should | Revisión del proceso. | — | F5, F6 |

---

## 3. Huecos

### RF MVP sin US: 0

Ninguno.

### RF MVP sin AC: 0

Ninguno.

### US sin AC: 0

Ninguno.

### RF MVP sin ningún tipo de prueba automatizable: 0

Ninguno.

### RF Must con [A VALIDAR] (bloqueantes): 39

| RF | Nº [A VALIDAR] | AC afectados |
|---|---|---|
| RF-002 | 1 | AC-002-4 |
| RF-005 | 1 | AC-005-2 |
| RF-010 | 1 | AC-010-5 |
| RF-011 | 1 | AC-011-2 |
| RF-012 | 1 | AC-012-4 |
| RF-019 | 4 | AC-019-1, AC-019-2, AC-019-4, AC-019-6 |
| RF-020 | 1 | AC-020-5 |
| RF-022 | 3 | AC-022-1, AC-022-3, AC-022-4 |
| RF-027 | 1 | AC-027-1 |
| RF-029 | 1 | AC-029-5 |
| RF-031 | 1 | AC-031-4 |
| RF-038 | 2 | AC-038-4, AC-038-5 |
| RF-039 | 4 | AC-039-3, AC-039-5, AC-039-6, AC-039-7 |
| RF-041 | 2 | AC-041-6, AC-041-7 |
| RF-042 | 4 | AC-042-2, AC-042-5, AC-042-6, AC-042-7 |
| RF-043 | 1 | AC-043-6 |
| RF-044 | 2 | AC-044-3, AC-044-4 |
| RF-045 | 2 | AC-045-1, AC-045-2 |
| RF-050 | 1 | AC-050-2 |
| RF-051 | 1 | AC-051-4 |
| RF-052 | 3 | AC-052-1, AC-052-13, AC-052-16 |
| RF-053 | 1 | AC-053-4 |
| RF-055 | 2 | AC-055-2, AC-055-3 |
| RF-056 | 1 | AC-056-8 |
| RF-057 | 3 | AC-057-3, AC-057-5, AC-057-6 |
| RF-062 | 1 | AC-062-1 |
| RF-072 | 1 | AC-072-1 |
| RF-073 | 1 | AC-073-4 |
| RF-076 | 1 | AC-076-1 |
| RF-087 | 1 | AC-087-1 |
| RF-088 | 1 | AC-088-2 |
| RF-094 | 2 | AC-094-2, AC-094-4 |
| RF-096 | 2 | AC-096-6, AC-096-11 |
| RF-097 | 2 | AC-097-5, AC-097-6 |
| RF-099 | 2 | AC-099-4, AC-099-6 |
| RF-104 | 2 | AC-104-6, AC-104-10 |
| RF-105 | 3 | AC-105-6, AC-105-9, AC-105-10 |
| RF-107 | 1 | AC-107-7 |
| RF-110 | 9 | AC-110-2, AC-110-3, AC-110-4, AC-110-6, AC-110-7, AC-110-8, AC-110-14, AC-110-15, AC-110-16 |

### RNF sin método de verificación: 0

Ninguno.

### RNF sin MED de línea base referenciado: 77

RNF-010, RNF-017, RNF-020, RNF-021, RNF-022, RNF-026, RNF-027, RNF-028, RNF-029, RNF-031, RNF-033, RNF-034, RNF-035, RNF-036, RNF-038, RNF-039, RNF-040, RNF-041, RNF-043, RNF-044, RNF-045, RNF-046, RNF-047, RNF-049, RNF-050, RNF-051, RNF-052, RNF-053, RNF-054, RNF-055, RNF-056, RNF-057, RNF-058, RNF-059, RNF-060, RNF-061, RNF-062, RNF-063, RNF-064, RNF-065, RNF-066, RNF-067, RNF-068, RNF-070, RNF-071, RNF-072, RNF-073, RNF-074, RNF-075, RNF-076, RNF-080, RNF-081, RNF-083, RNF-084, RNF-085, RNF-086, RNF-087, RNF-088, RNF-089, RNF-090, RNF-091, RNF-092, RNF-093, RNF-094, RNF-095, RNF-096, RNF-097, RNF-098, RNF-099, RNF-100, RNF-101, RNF-102, RNF-103, RNF-113, RNF-114, RNF-115, RNF-116

### NO EXTRAÍDO: 0

Ninguno. Todas las celdas se extrajeron de forma determinista.

### Inconsistencias de trazabilidad entre documentos: 0

Ninguna.

### IDs referenciados que no existen: 0

Ninguno.

### IDs duplicados: 0

Ninguno.

### Filas o celdas mal formadas: 0

Ninguna.

### MED definidos sin referencia en ningún RNF: 3

MED-02, MED-13, MED-18

---

## 4. Resumen con conteos

| Concepto | Conteo |
|---|---|
| RF en la tabla (functional_requirements §1) | 113 |
| RF ¿MVP? sí / fase 2 / no | 76 / 32 / 5 |
| RF por MoSCoW Must / Should / Could / Won't | 47 / 31 / 25 / 10 |
| RF MVP con al menos una US | 76 de 76 |
| US (user_stories §1) | 76 |
| AC en historias (acceptance_criteria §1) | 477 |
| AC transversales AC-SEC | 13 |
| AC totales | 490 |
| AC por tipo (un AC puede tener varios) | Unitaria: 34 · Widget: 109 · Integración: 198 · E2E: 34 · Seguridad: 95 · Manual: 20 |
| AC con [A VALIDAR] | 107 |
| RNF en la tabla (non_functional_requirements §4) | 116 |
| RNF por prioridad Must / Should / Could / Won't | 77 / 35 / 2 / 0 |
| MED definidos (§6) / MED referenciados por RNF | 18 / 15 |
| D-xx / ADR-xxx / PA-xx definidos | 16 / 2 / 12 |
| Huecos (conteo por categoría en §3) | RF MVP sin US: 0; RF MVP sin AC: 0; US sin AC: 0; RF MVP sin ningún tipo de prueba automatizable: 0; RF Must con [A VALIDAR] (bloqueantes): 39; RNF sin método de verificación: 0; RNF sin MED de línea base referenciado: 77; IDs inexistentes: 0; duplicados: 0; NO EXTRAÍDO: 0 |


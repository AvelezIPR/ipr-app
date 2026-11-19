# Design System — App móvil IPR (Flutter, Android/iOS)

| | |
|---|---|
| **Proyecto** | App móvil Flutter de IPR Partes y Repuestos (Inverprimos S.A.S.), repuestos HVAC-R en Colombia |
| **Fase** | UX/UI. **No se programa ni se generan imágenes.** Este documento es especificación verificable, no implementación. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR para aprobación de IPR/Marketing. Nada de lo marcado PROPUESTA o PENDIENTE es oficial. |
| **Documentos hermanos** | [navigation.md](navigation.md) · [user_flows.md](user_flows.md) · [accessibility.md](accessibility.md) |
| **Fuentes** | [Requisitos funcionales](../02_requirements/functional_requirements.md) · [Criterios de aceptación](../02_requirements/acceptance_criteria.md) · [RNF §F Accesibilidad](../02_requirements/non_functional_requirements.md) · [Arquitectura Flutter §10–14](../03_architecture/flutter_app_architecture.md) · [Informe de investigación §9](../00_discovery/informe_investigacion.md) · [Decisiones pendientes §E](../project/decisiones_pendientes.md) · código web de referencia (solo lectura): `ipr-frontend/src/app/globals.css`, `src/components/ui/`, `src/components/product/`, `docs/documentacion-proyecto.md` §17 |

---

## 0. Cómo leer este documento

### 0.1 Convenciones de certeza

| Etiqueta | Significado |
|---|---|
| **[HECHO]** | Comprobado en un documento del proyecto, en el código web o con un cálculo/medición reproducible (con su fuente). |
| **[SUPUESTO]** | Se asume para poder diseñar. Si es falso, el diseño cambia. |
| **[PROPUESTA]** | Decisión de diseño de este documento. No es oficial hasta aprobarse. |
| **[PENDIENTE]** | Depende de una decisión de IPR, Marketing, Jurídico o de una prueba con usuarios. |

### 0.2 Identificadores propios de esta fase

| Prefijo | Qué es |
|---|---|
| `SUP-Hnn` | Supuesto basado en la recomendación **H-nn** de [decisiones pendientes §E](../project/decisiones_pendientes.md), que **NO está aprobada**. Se diseña como si fuera cierta y se marca para poder revertirla. Ejemplo: `SUP-H06` = los productos "bajo pedido" no se compran en la app. |
| `SUP-UXnn` | Supuesto de diseño propio de esta fase. |
| `APR-nn` | Aprobación que debe dar una persona de IPR (Marketing, Jurídico, Ingeniería o Gerencia). Registro en §17. |
| `VAL-nn` | Decisión que debe probarse con usuarios reales antes de fijarse. Registro en §17. |
| `PT-xx` | Pantalla (identificador definido en [navigation.md §6](navigation.md)). |
| `Fnn` | Flujo (definido en [user_flows.md](user_flows.md)). |

### 0.3 Decisiones que condicionan este diseño y no se reabren

ADR-001 y ADR-002 (aprobadas): la app solo habla con `/mobile/v1`; compra completa con carrito local y checkout de WooCommerce con Wompi en navegador seguro; sin B2B (un solo precio público con IVA incluido); producto sin precio solo con "Más información" hacia WhatsApp. **S-01** (D-05 abierta): disponibilidad genérica, sin cantidades ni stock por sede. **S-02**: el MVP exige sesión para pagar.

### 0.4 Resumen de lo que necesita aprobación

| # | Qué | Dónde |
|---|---|---|
| 1 | Paleta accesible derivada: verde `#3F731C`, rojo `#C1292F`, gris de texto secundario `#66686B` y tintes (APR-02). **El verde de marca `#5BA628` no puede usarse como texto normal ni con texto blanco** (3,03:1). | §3 |
| 2 | Cuál es el verde oficial: la documentación dice `#5BA628`, pero `globals.css` define `green-brand` = `#99C120` (APR-01). | §3.2 |
| 3 | Modo oscuro: MVP sí/no (APR-03, RF-113, D-13). Tokens oscuros ya calculados. | §4 |
| 4 | Voz de la interfaz: tuteo ("tú") frente a "usted" (APR-04). | §12 |
| 5 | Excepción de escala de texto en las etiquetas de la barra inferior (APR-12). | §10.7 |

---

## 1. Principios de diseño

Todos son **[PROPUESTA]** derivados de los requisitos citados.

| # | Principio | Qué significa en pantalla | Origen |
|---|---|---|---|
| P1 | **Encontrar la pieza exacta primero** | El buscador (nombre, marca, referencia/SKU) está a un toque desde el inicio y el catálogo; el SKU se muestra siempre en monoespaciada. | RF-001, RF-020, RF-022; INV §1 (placeholder "por marca o referencia") |
| P2 | **Estados honestos, nunca "$0"** | Un producto sin precio muestra "Más información", jamás una cifra. Stock, precio y pago se comunican con **texto + ícono**, no solo con color. | RF-012, RF-031, RNF-076 |
| P3 | **El servidor manda en el dinero** | Subtotales y precios del carrito se rotulan "informativo"; el total lo confirma el checkout. La UI no calcula impuestos ni envío. | RF-050, RF-051, AC-SEC-6 |
| P4 | **Accesible por defecto** | Objetivo WCAG 2.2 AA: contraste, objetivos ≥ 48 dp, texto hasta 200 %, lectores de pantalla, sin gestos obligatorios. Nada se da por cumplido hasta verificarlo ([accessibility.md](accessibility.md)). | RNF-067 a RNF-077 |
| P5 | **Resiliente a la red** | Esqueleto de carga, caché con aviso, el carrito nunca se pierde por un error. Error ≠ vacío (son estados distintos). | RF-009, AC-009-1 a 009-7, RNF-020 |
| P6 | **Sobrio y técnico** | La marca se expresa con azul, espacio y tipografía. No se replican efectos decorativos de la web (brillo `btn-depth`, Ken Burns, marquesinas, destello `cta-shine`). | PROPUESTA; ver §8 |
| P7 | **Contacto humano siempre a mano** | WhatsApp/ayuda está en la misma ubicación relativa en las pantallas raíz (ayuda consistente, WCAG 3.2.6). La atención real de IPR ocurre por WhatsApp y teléfono. | RNF-077, INV §7, RF-094 |
| P8 | **Un solo camino claro para pagar** | El pago ocurre fuera de la app (navegador seguro): la interfaz prepara al usuario, no lo sorprende, y siempre permite reintentar sin perder el carrito. | RF-052 a RF-058 |

---

## 2. Identidad visual observada

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Azul `#0A3651`, `#07628E`, `#0B4970` y verde `#5BA628` | Colores de marca | **[HECHO]** declarados en `docs/documentacion-proyecto.md` §17. Una búsqueda en `ipr-frontend/src` encontró `#0A3651`, `#0B4970` y `#5BA628` 31 veces en 4 archivos (ingeniería, sedes, contacto y "dónde estamos"); `#07628E` está además en `globals.css` como `--primary`. | `informe_codigo_frontend.md` §1 (fila "Colores de marca"); búsqueda de los hexadecimales en `src/` |
| Tokens de interfaz de la web | `--primary #07628E`, `--secondary #EAF4F9`, `--accent #E8F3FA`, `--foreground #151A21`, `--muted #F3F5F7`, `--muted-foreground #75777B`, `--destructive #D64045`, `--border #E2E8F0`, `--input #CBD5E1`, radio `0.625rem` | **[HECHO]** observados en `globals.css`. No son el manual de marca. | `globals.css` L46-85 |
| Modo oscuro web | `--background #0A1320`, `--card #0F1A26`, `--foreground #EAF3F9`, `--primary #439BE4`, `--destructive #F2797D`… | **[HECHO]** observado en `.dark` de `globals.css` | L87-106 |
| Tipografía | Poppins (400, 500, 600, 700, 900) y JetBrains Mono, vía `next/font` | **[HECHO]**; el comentario del código la atribuye al "Manual de Marca (2025)", que **no se ha entregado** (D-13) | `src/app/layout.tsx` L15-35 |
| Logo | `iprpartesyrepuestos.com/logos/logo-ipr-2025.png` | **[HECHO]**; vectorial pendiente | INV §9; D-13 |
| Manual de marca oficial | No disponible | **[PENDIENTE]** D-13 / APR-01 / APR-10 | `decisiones_pendientes.md` |

> **Regla de este Design System:** solo se usan colores observados en la web o derivados de ellos por cálculo. Los derivados se marcan **PROPUESTA** y no son colores oficiales de marca hasta que Marketing los apruebe (APR-02).

---

## 3. Paleta de color

Todas las razones de contraste se calcularon con el script reproducible del [Anexo A de accessibility.md](accessibility.md#anexo-a-script-de-contraste) (luminancia relativa WCAG 2.x; 94 combinaciones). Los identificadores `L##`, `N##`, `C##`, `D##` y `W##` remiten a su tabla.

### 3.1 Colores base (tema claro)

| Token base | Hex | Origen | Uso permitido | Contraste clave |
|---|---|---|---|---|
| `ipr.blue.900` | `#0A3651` | Marca **[HECHO]** | Títulos, barra superior en tono oscuro, chip activo, anillo de foco | 12,66:1 sobre blanco (L13) |
| `ipr.blue.700` | `#07628E` | Marca **[HECHO]** | **Primario**: botones, enlaces, íconos activos, foco de campos | 6,67:1 sobre blanco (L10); blanco sobre él 6,67:1 (L16) |
| `ipr.blue.800` | `#0B4970` | Marca **[HECHO]** | Estado **presionado** del primario, texto sobre fondo claro | 9,54:1 sobre blanco (L14); blanco sobre él 9,54:1 (L17) |
| `ipr.green.500` | `#5BA628` | Marca **[HECHO]** (ver §3.2) | **Solo** relleno con texto oscuro `#151A21` (5,77:1, L21), íconos/indicadores ≥ 24 dp sobre blanco (3,03:1, N01), cualquier uso sobre fondo oscuro (6,15:1, D13) | **No** como texto normal sobre claro (3,03:1, L19); **no** con texto blanco (3,03:1, L20); **no** sobre tinte azul (2,71:1, N02) |
| `ipr.ink` | `#151A21` | Web **[HECHO]** (`--foreground`) | Texto principal; fondo de snackbar | 17,48:1 sobre blanco (L01) |
| `ipr.surface.muted` | `#F3F5F7` | Web **[HECHO]** | Fondo atenuado, imagen de producto, esqueleto (claro) | Texto principal 15,99:1 (L02) |
| `ipr.surface.tint` | `#EAF4F9` | Web **[HECHO]** (`--secondary`) | Contenedores informativos, indicador de pestaña, chips tonales | Texto principal 15,65:1 (L03); primario 5,98:1 (L12) |
| `ipr.surface.accent` | `#E8F3FA` | Web **[HECHO]** (`--accent`) | Realces, fila seleccionada | — |
| `ipr.onTint` | `#055177` | Web **[HECHO]** (`--secondary-foreground`) | Texto sobre contenedores tonales | 7,68:1 sobre `#EAF4F9` (L15) |
| `ipr.gray.500` | `#75777B` | Web **[HECHO]** (`--muted-foreground`) | **Solo no-texto**: borde de campo y casilla, íconos secundarios (≥ 3:1) | 4,49:1 sobre blanco (N09), 4,10:1 sobre atenuada (N07), 4,02:1 sobre tinte (N08). **Como texto normal NO CUMPLE** (4,49 < 4,5: L04, L05, L06) |
| `ipr.outline.soft` | `#E2E8F0` | Web **[HECHO]** (`--border`) | Divisores y bordes **decorativos** de tarjeta (la tarjeta se identifica por su contenido, no por su borde) | 1,23:1 (N06): nunca como borde de campo |
| `ipr.red.500` | `#D64045` | Web **[HECHO]** (`--destructive`) | Solo íconos grandes/no esenciales; **no texto** | 4,49:1 sobre blanco (L23): **no alcanza 4,5** por 0,01 |

### 3.2 Colores derivados — PROPUESTA A APROBAR por Marketing (APR-02)

Se derivan bajando la luminosidad HSL de un color observado, **sin cambiar tono ni saturación**, hasta cumplir ≥ 5,0:1 contra todas las superficies claras (margen de 0,5 sobre el umbral por antialiasing y escalado). Procedimiento reproducible en el script (`--derivar`).

| Token | Hex | Deriva de | Uso | Contraste | Estado |
|---|---|---|---|---|---|
| `ipr.green.700` | `#3F731C` | `#5BA628` | Texto e íconos de éxito ("En stock"), relleno "Oferta" con texto blanco | 5,71:1 sobre blanco (L26); 5,22:1 sobre atenuada (L27); 5,11:1 sobre tinte azul (L28); blanco sobre él 5,71:1 (L29) | **PROPUESTA A APROBAR por marketing** |
| `ipr.green.50` | `#EBF8E2` | `#5BA628` (L = 93 %) | Fondo de insignia "En stock" | Texto principal 15,86:1 (C04); ícono `#3F731C` 5,18:1 (C05) | **PROPUESTA A APROBAR por marketing** |
| `ipr.red.700` | `#C1292F` | `#D64045` | Texto e íconos de error, botón destructivo con texto blanco | 5,79:1 sobre blanco (L31); 5,30:1 sobre atenuada (L32); blanco sobre él 5,79:1 (L33) | **PROPUESTA A APROBAR por marketing** |
| `ipr.red.50` | `#FAEBEB` | `#D64045` (L = 95 %) | Fondo de insignia "Agotado" y de mensajes de error | Texto principal 15,10:1 (C06); ícono `#C1292F` 5,01:1 (C07) | **PROPUESTA A APROBAR por marketing** |
| `ipr.gray.700` | `#66686B` | `#75777B` | **Texto secundario** (SKU, "IVA incluido", ayudas, precio tachado) | 5,59:1 sobre blanco (L07); 5,11:1 sobre atenuada (L08); 5,01:1 sobre tinte (L09) | **PROPUESTA A APROBAR por marketing** |

**Reglas de uso del verde `#5BA628` (obligatorias):**

1. **Permitido:** relleno decorativo o de insignia **con texto `#151A21`**; ícono o indicador de estado sobre **blanco** acompañado siempre de texto; cualquier uso sobre fondos oscuros.
2. **Prohibido:** texto normal verde sobre fondo claro; texto blanco sobre verde; verde como único canal de un estado; ícono verde sobre fondo tinte azul o atenuado.
3. **Alternativa si Marketing rechaza `#3F731C`:** "En stock" = ícono de verificación `#5BA628` sobre blanco + texto `#151A21`; "Oferta" = relleno `#5BA628` + texto `#151A21` (5,77:1, C08). Ningún estado depende del verde derivado: el diseño sigue siendo válido sin él.

**Discrepancia detectada (APR-01):** `docs/documentacion-proyecto.md` §17 afirma que el verde de marca es `#5BA628` y lo asocia al token `green-brand`, pero `globals.css` define `--color-green-brand: #99C120` ("Verde lima 382 U"). Con `#99C120` el contraste sobre blanco es **2,10:1** (W01) y blanco sobre él **2,10:1** (W02). Este Design System usa `#5BA628` por indicación de la documentación; Marketing debe confirmar cuál es el verde oficial.

### 3.3 Problemas de contraste encontrados

**En la paleta propuesta (resueltos por regla de uso):** el verde `#5BA628` (L19, L20, N02), el rojo `#D64045` (L23 a L25), el gris `#75777B` como texto (L04 a L06) y el azul oscuro `#0A3651` sobre verde (L22: 4,18:1). El borde de campo web `#CBD5E1` (1,48:1, N05) y el borde `#E2E8F0` (1,23:1, N06) no sirven como límite de un campo (WCAG 1.4.11): el campo usa `#75777B`.

**En el sitio web actual (referencia; no se replican y se informa al equipo web):**

| ID | Hallazgo | Razón |
|---|---|---|
| W01 | "En stock" con `text-green-brand` (`#99C120`) sobre blanco (`ProductBuyBox.tsx`) | 2,10:1 |
| W02 | Insignia "Oferta" con texto blanco sobre `bg-green-brand` (`ProductBuyBox.tsx`) | 2,10:1 |
| W03 | "Disponible bajo pedido" con `text-amber-600` (`#D97706`) sobre blanco | 3,19:1 |
| W06 | Texto `#75777B` sobre superficie `#F3F5F7` | 4,10:1 |
| — | Etiquetas de 11 px (`text-[11px]`) en tarjetas e insignias | Por debajo del mínimo de 12 sp que fija este Design System (§5) |

Total: de 94 combinaciones evaluadas, **21 no cumplen** y **ninguna de las 21 se adopta**: 4 son hallazgos del sitio web actual (W01, W02, W03, W06), 2 son azules de marca claros sobre fondo oscuro (D15, D16) y 15 son colores observados usados donde no alcanzan (como texto o como borde: L04 a L06, L19, L20, L22 a L25, N02, N05, N06, N11, D17, D18), cada uno con su sustituto en §3.2 y §3.4.

### 3.4 Tokens semánticos (tema claro y oscuro)

Los tokens semánticos son la **única** capa que usan los componentes. Se mapean a un `ColorScheme` Material 3 explícito (no `fromSeed`, para garantizar los contrastes medidos; Arquitectura §13.2) y a una extensión de tema `IprColors` para los roles que Material no tiene.

| Token semántico | Claro | Oscuro | `ColorScheme` / extensión | Notas y contraste |
|---|---|---|---|---|
| `color.primary` | `#07628E` | `#439BE4` | `primary` | Oscuro: observado en web. 6,25:1 sobre fondo oscuro (D06) |
| `color.onPrimary` | `#FFFFFF` | `#06233F` | `onPrimary` | 6,67:1 (L16); 5,34:1 (D08) |
| `color.primaryPressed` | `#0B4970` | `#7BB8EC` **[SUPUESTO-UX01]** | `IprColors.primaryPressed` | Oscuro: variante más clara del primario; **sin calcular → verificar al activar tema oscuro** |
| `color.primaryContainer` | `#EAF4F9` | `#163D57` | `primaryContainer` | Chips tonales, indicador de pestaña |
| `color.onPrimaryContainer` | `#055177` | `#EAF3F9` | `onPrimaryContainer` | 7,68:1 (L15); 10,16:1 (D10) |
| `color.secondary` | `#0A3651` | `#CFE6F5` | `secondary` | Títulos y barra superior oscura |
| `color.onSecondary` | `#FFFFFF` | `#122A3A` | `onSecondary` | 12,66:1 (L18) |
| `color.secondaryContainer` | `#E8F3FA` | `#122A3A` | `secondaryContainer` | — |
| `color.onSecondaryContainer` | `#055177` | `#CFE6F5` | `onSecondaryContainer` | 11,49:1 oscuro (D09) |
| `color.surface` | `#FFFFFF` | `#0A1320` | `surface` | Fondo de pantalla |
| `color.surfaceContainer` | `#F3F5F7` | `#0F1A26` | `surfaceContainer` | Fondo atenuado / tarjeta oscura |
| `color.surfaceContainerHigh` | `#E2E8F0` | `#122A3A` | `surfaceContainerHigh` | Esqueleto, contenedor deshabilitado |
| `color.onSurface` | `#151A21` | `#EAF3F9` | `onSurface` | 17,48:1 (L01); 16,58:1 (D01) |
| `color.onSurfaceVariant` | `#66686B` | `#9BACBD` | `onSurfaceVariant` | Texto secundario. 5,59:1 (L07); 8,01:1 (D03) |
| `color.outline` | `#75777B` | `#42698B` | `outline` | Borde de campo/casilla. Claro 4,49:1 (N09); oscuro derivado 3,22:1 (D21) |
| `color.outlineVariant` | `#E2E8F0` | `#1D3345` | `outlineVariant` | Divisores **decorativos** únicamente |
| `color.focusRing` | `#0A3651` | `#EAF3F9` | `IprColors.focusRing` | 12,66:1 (N12); 16,58:1 (D20b) |
| `color.error` | `#C1292F` | `#F2797D` | `error` | Texto/íconos de error. 5,79:1 (L31); 6,93:1 (D11) |
| `color.onError` | `#FFFFFF` | `#0A1320` | `onError` | 5,79:1 (L33); 6,93:1 (D27) |
| `color.errorContainer` | `#FAEBEB` | `#4E1315` | `errorContainer` | Insignia "Agotado", mensajes |
| `color.onErrorContainer` | `#151A21` | `#EAF3F9` | `onErrorContainer` | 15,10:1 (C06); 13,09:1 (D25) |
| `color.success` | `#3F731C` | `#5BA628` | `IprColors.success` | Texto/íconos de éxito. 5,71:1 (L26); 6,15:1 (D13) |
| `color.onSuccess` | `#FFFFFF` | `#0A1320` | `IprColors.onSuccess` | 5,71:1 (L29); 6,15:1 (D28) |
| `color.successContainer` | `#EBF8E2` | `#244110` | `IprColors.successContainer` | Insignia "En stock" |
| `color.onSuccessContainer` | `#151A21` | `#EAF3F9` | `IprColors.onSuccessContainer` | 15,86:1 (C04); 10,16:1 (D23) |
| `color.brandGreen` | `#5BA628` | `#5BA628` | `IprColors.brandGreen` | Solo decorativo/relleno con texto oscuro (reglas §3.2) |
| `color.inverseSurface` | `#151A21` | `#EAF3F9` | `inverseSurface` | Snackbar. Texto blanco 17,48:1 (C02); acción `#439BE4` 5,87:1 (C03) |
| `color.scrim` | `#000000` al 32 % | igual | `scrim` | Detrás de hojas y diálogos |

> **Sin color de advertencia.** No se introduce un ámbar: el único uso observado (`text-amber-600`, 3,19:1, W03) falla. Los avisos no críticos (cambio de precio, "bajo pedido", datos guardados) usan **contenedor tonal azul + ícono + texto**. Nunca color solo (RNF-076).

---

## 4. Modo oscuro (decisión pendiente APR-03)

| Aspecto | Contenido |
|---|---|
| **Hecho** | La web ya tiene modo oscuro (`.dark` en `globals.css`). RF-113 (preferencia de tema) es *Could / fase 2*; la arquitectura prepara los tokens y fija el tema oscuro en fase 2 (FA §13.2). D-13 pregunta si la app lo soportará. |
| **Decisión pendiente (APR-03)** | ¿MVP solo claro (recomendado) o claro + oscuro? |
| **Recomendación [PROPUESTA]** | **MVP solo claro**, con todos los tokens oscuros ya definidos y con contraste verificado (§3.4; D01 a D28) para que activarlo en fase 2 sea cambiar el tema, no rediseñar. Si IPR decide incluirlo en el MVP, se necesitan: golden tests de cada componente en ambos temas, revisión de imágenes de producto sobre fondo oscuro (muchas fotos tienen fondo blanco; se mantienen sobre un recuadro `#FFFFFF`/claro) y verificación de `color.primaryPressed` oscuro. |
| **Reglas si se activa** | Seguir el ajuste del sistema por defecto; el selector manual (claro/oscuro/sistema) es RF-113. Los colores de marca oscuros (`#0A3651`, `#07628E`) **no** se usan como texto sobre fondo oscuro (1,47:1 y 2,79:1; D16, D15): se sustituyen por `#439BE4`. El verde `#5BA628` sí funciona como texto sobre oscuro (6,15:1). |
| **Valores del tema oscuro** | Observados en la web salvo `outline`, tintes de éxito/error oscuros y `primaryPressed` (derivados, **PROPUESTA**; los bordes de campo observados `#2A4359` dan 1,82:1, D17, y no cumplen 1.4.11). |

---

## 5. Tipografía

### 5.1 Familias, licencia y empaquetado

| Familia | Uso | Licencia | Archivos propuestos | Tamaño medido |
|---|---|---|---|---|
| **Poppins** | Interfaz y titulares | **SIL Open Font License 1.1**, © 2020 The Poppins Project Authors (itfoundry) | Regular 400, Medium 500, SemiBold 600, Bold 700 (TTF) | 160.316 + 158.576 + 157.312 + 155.996 = **632.200 B (≈ 617 KiB)** |
| **JetBrains Mono** | SKU, códigos de pedido, referencias | **SIL Open Font License 1.1**, © 2020 The JetBrains Mono Project Authors | Variable `[wght]` (TTF) | **187.208 B (≈ 183 KiB)** |
| **Total** | | | 5 archivos | **819.408 B (≈ 800 KiB)** |

**Verificación [HECHO]:** licencia y tamaños consultados el 2026-11-18 en el repositorio público `github.com/google/fonts` (rama `main`: `ofl/poppins/OFL.txt`, `ofl/poppins/Poppins-*.ttf`, `ofl/jetbrainsmono/OFL.txt`, `ofl/jetbrainsmono/JetBrainsMono[wght].ttf`) descargando cada archivo y midiendo los bytes. `METADATA.pb` de ambas familias indica `license: "OFL"`. No se descarga ninguna fuente en tiempo de ejecución (privacidad y uso sin red; FA §13.2).

**Implicaciones [HECHO sobre la licencia, PROPUESTA sobre el proceso]:**

- La OFL permite empaquetar las fuentes en una app y redistribuirlas con ella; exige conservar el aviso de derechos de autor y el texto de la licencia (se incluyen en la pantalla estándar de licencias de código abierto de Flutter) y prohíbe vender las fuentes por sí solas.
- El peso total (≈ 0,8 MB sin subconjunto) es ≈ 2 % del tope de 40 MB de Android (RNF-008). **[SUPUESTO]** Se puede reducir con un subconjunto Latin + puntuación española (¿ ¡ á é í ó ú ñ ü); la reducción no se midió.
- La web usa además el peso 900 (Black, 153.440 B); la app **no** lo incluye.
- **APR-05:** Marketing/Jurídico deben confirmar que el Manual de Marca 2025 (no entregado) no exige otra fuente o archivo (D-13).
- Prueba de glifos obligatoria antes de empaquetar: `ñ Ñ á é í ó ú ü ¿ ¡ $ . , : ;`, guion largo y las comillas españolas, en cada peso.

### 5.2 Escala tipográfica

Unidad: **sp** (escalable con el ajuste de tamaño de fuente del sistema). Mínimo absoluto de texto: **12 sp** (la web usa 11 px en varias etiquetas: no se replica). Cociente de interlineado ≥ 1,43; texto corrido ≥ 1,5 (16/24). Sin mayúsculas sostenidas en botones ni etiquetas (la web usa `uppercase` a 11 px; en la app se prefiere minúscula inicial por legibilidad y por lectura de pantalla).

| Token | Tamaño / interlineado | Peso | Familia | Espaciado de letra | Uso | `TextTheme` |
|---|---|---|---|---|---|---|
| `type.display.price` | 28 / 36 | 700 | Poppins | 0 | Precio en la ficha | `headlineLarge` |
| `type.headline` | 24 / 32 | 600 | Poppins | 0 | Título de pantalla en el cuerpo, título de resultado de pago | `headlineMedium` |
| `type.title.large` | 20 / 28 | 600 | Poppins | 0 | Título de barra superior, encabezados de sección | `titleLarge` |
| `type.title.medium` | 16 / 24 | 500 | Poppins | 0,15 | Nombre de producto, título de fila | `titleMedium` |
| `type.title.small` | 14 / 20 | 500 | Poppins | 0,1 | Subtítulos, encabezados de grupo | `titleSmall` |
| `type.body.large` | 16 / 24 | 400 | Poppins | 0,5 | Texto corrido, descripción, contenido de campo | `bodyLarge` |
| `type.body.medium` | 14 / 20 | 400 | Poppins | 0,25 | Texto secundario, ayudas, mensajes | `bodyMedium` |
| `type.body.small` | 12 / 16 | 400 | Poppins | 0,4 | Notas ("IVA incluido"), contadores | `bodySmall` |
| `type.label.large` | 14 / 20 | 600 | Poppins | 0,1 | Texto de botones y pestañas | `labelLarge` |
| `type.label.medium` | 12 / 16 | 500 | Poppins | 0,5 | Chips, insignias, etiquetas de barra inferior | `labelMedium` |
| `type.price.card` | 16 / 24 | 700 | Poppins | 0 | Precio en tarjeta (web: `text-base font-bold`) | extensión `IprTextStyles` |
| `type.mono.sku` | 13 / 18 | 400 | JetBrains Mono | 0 | SKU y números de pedido | extensión `IprTextStyles` |

### 5.3 Texto del sistema hasta 200 %

| Regla | Detalle |
|---|---|
| **No se limita el factor de escala** (`TextScaler` sin tope) | Requisito RNF-068; excepción única propuesta en §10.7 (APR-12). |
| Contenedores sin altura fija para texto | Alturas **mínimas**, nunca máximas. Nada de `SizedBox(height:)` alrededor de texto. |
| Reflujo de la tarjeta de producto | Hasta 1,3×: rejilla de 2 columnas, nombre a 2 líneas con puntos suspensivos (AC-011-7). Desde **1,5×**: pasa a **variante de lista de 1 columna** y el nombre admite 4 líneas. El nombre completo siempre está en la ficha y en la etiqueta de accesibilidad. |
| Formularios | Etiqueta **sobre** el campo y ayuda debajo; nunca etiqueta flotante (se recorta a 200 %). |
| Botones | Pueden crecer en alto y envolver el texto; ancho completo en formularios y llamadas a la acción. |
| Barra superior | Título hasta 2 líneas a 200 %; las acciones (buscar, ayuda, carrito) conservan 48 dp. |
| Pruebas | *Golden* a escala 1,0, 1,3 y 2,0 de cada componente y pantalla crítica (FA §14); manual con 200 % en Android e iOS. |

---

## 6. Espaciado, rejilla, radios, elevación, movimiento

### 6.1 Espaciado (base 4 dp)

| Token | dp | Uso típico |
|---|---|---|
| `space.0` / `space.1` | 0 / 4 | Separación íconos-texto mínima; margen interno de insignia |
| `space.2` | 8 | Separación entre elementos relacionados; hueco ícono-etiqueta del botón |
| `space.3` | 12 | Relleno interno de tarjeta; separación entre campos de un mismo grupo |
| `space.4` | 16 | **Margen lateral de pantalla** (compacto); relleno de contenedores |
| `space.5` | 24 | Separación entre secciones; margen lateral en pantallas medias |
| `space.6` | 32 | Separación de bloques grandes |
| `space.7` / `space.8` | 48 / 64 | Espacio de estados vacíos; altura mínima de objetivo táctil / alturas grandes |

### 6.2 Rejilla y tamaños de pantalla

| Clase de ancho | Rango | Columnas | Margen | Rejilla de productos |
|---|---|---|---|---|
| Compacta | 320 a 599 dp | 4 | 16 dp | 2 columnas (ancho mínimo de tarjeta 148 dp); 1 columna a escala ≥ 1,5 |
| Media | 600 a 839 dp | 8 | 24 dp | 3 columnas |
| Expandida | ≥ 840 dp | 12 | 24 dp | 4 columnas (contenido centrado, ancho máximo 840 dp) |

Ancho mínimo soportado **320 dp** sin desbordes; tablet "usable, no optimizada" (RNF-081, DN-11). Vertical optimizado, horizontal usable; no se bloquea la orientación (RNF-074). Respeta las áreas seguras (muescas, barra de gestos) y el teclado: el campo enfocado nunca queda tapado por la barra inferior ni por el teclado (WCAG 2.4.11).

### 6.3 Radios

Derivados de `--radius: 0.625rem` (10 px) de la web: `calc` ×0,6 / 0,8 / 1 / 1,4 / 1,8 / 2,2.

| Token | dp | Uso |
|---|---|---|
| `radius.sm` | 6 | Insignias, chips pequeños |
| `radius.md` | 8 | Campos de texto, imagen de producto |
| `radius.lg` | 10 | **Botones** |
| `radius.xl` | 14 | Contenedores informativos, hojas inferiores (esquinas superiores 28 dp: M3) |
| `radius.2xl` | 18 | **Tarjetas** de producto y de sede |
| `radius.full` | 999 | Indicador de pestaña, avatares |

### 6.4 Elevación

**[PROPUESTA]** Superficies planas con borde decorativo y elevación tonal (M3); no se replica el relieve `btn-depth` (brillo superior + doble sombra), que es decorativo y costoso de pintar en gama baja.

| Nivel | Uso | Tratamiento |
|---|---|---|
| 0 | Fondo, tarjetas | Sin sombra; borde `outlineVariant` 1 dp |
| 1 | Barra superior al desplazar, barra de resumen de carrito fija | Sombra suave o tinte `surfaceContainer` |
| 2 | Snackbar, botón de acción flotante (no se usa en el MVP) | Sombra M3 nivel 2 |
| 3 | Hojas inferiores modales, diálogos | Sombra M3 nivel 3 + `scrim` 32 % |

### 6.5 Movimiento

| Regla | Detalle |
|---|---|
| Duraciones | 100 ms (respuesta táctil), 200 ms (transiciones de componente), 300 ms (transiciones de pantalla). RNF-005: retroalimentación ≤ 100 ms; primer cuadro de pantalla destino ≤ 300 ms. |
| Curvas | Estándar M3 (`easeInOutCubicEmphasized` para pantallas, `easeOut` para entradas). |
| Movimiento reducido | Si `MediaQuery.disableAnimations` es verdadero: sin transiciones animadas, sin pulso de esqueleto, sin autodesplazamiento de la galería; los cambios son instantáneos. |
| Prohibido | Animaciones automáticas > 5 s sin control (WCAG 2.2.2): no se replican las marquesinas, el destello `cta-shine` ni el zoom Ken Burns de la web. Carruseles sin autoavance. |

---

## 7. Iconografía

| Aspecto | Propuesta | Estado |
|---|---|---|
| Biblioteca | **Material Icons (incluidos en el SDK de Flutter)**, variante *rounded*, 24 dp, trazo uniforme. Ventaja: cero dependencias nuevas (la tabla de dependencias de FA §17 no incluye un paquete de íconos). La web usa Lucide (`lucide-react`); usarlo en la app exigiría añadir un paquete y registrar una ADR. | **PROPUESTA**; APR-09 |
| Tamaños | 16 (en línea con texto), 20 (dentro de botón), 24 (estándar), 32 (estados vacíos pequeños), 48 (estados vacíos grandes) | PROPUESTA |
| Objetivo táctil | Todo ícono interactivo tiene área ≥ 48 × 48 dp (el ícono mide 24) | RNF-071 |
| Significado | Nunca solo ícono para una acción: etiqueta visible o `semanticsLabel`/tooltip. Íconos decorativos se excluyen del árbol de semántica. | RNF-070 |
| Correspondencias mínimas | Inicio `home`; Catálogo `category`/`grid_view`; Carrito `shopping_cart`; Cuenta `person`; Buscar `search`; Ayuda `support_agent`; Filtros `tune`; Orden `swap_vert`; Stock `check_circle`; Agotado `block`; Pendiente `schedule`; Error `error`; Éxito `check_circle`; Sede `store`; Llamar `call`; WhatsApp `chat`; Mapa `directions`; Atrás `arrow_back`; Cerrar `close`. | PROPUESTA |
| Color de WhatsApp | **No se usa el verde de WhatsApp** (marca de un tercero cuyas guías de uso no se verificaron): el botón usa el estilo secundario de IPR con el ícono `chat` y el texto "Escribir por WhatsApp". | **PROPUESTA**; APR-11 |
| Ilustraciones de estados vacíos | **No se generan en esta fase.** Se entrega el brief (§13): estilo lineal de un solo trazo, paleta azul de marca, sin texto incrustado, con alternativa textual. | APR-09 |
| Marca | Logo vectorial pendiente (D-13, APR-10). Mientras tanto, la barra superior de Inicio usa el logotipo de la web en PNG solo para maquetación; no se publica sin versión vectorial. | PENDIENTE |

---

## 8. Qué se adopta y qué no de la web actual

| Elemento web | En la app | Motivo |
|---|---|---|
| Colores de marca y tokens `--primary`, `--secondary`, `--accent`, `--foreground`, `--muted` | **Se adoptan** | Continuidad de marca |
| `--muted-foreground` como texto, `text-green-brand`, `text-amber-600`, `--input` como borde | **No** (fallan contraste) | §3.3 |
| Poppins + JetBrains Mono | Se adoptan | Licencia OFL verificada |
| Radio base 10 px y sus escalas | Se adoptan | Continuidad |
| Relieve `btn-depth`, `cta-shine`, Ken Burns, marquesinas, `animate-float` | **No** | Decorativos, movimiento continuo, costo de render (P6) |
| Etiquetas de 11 px en mayúsculas | **No** | Mínimo 12 sp; legibilidad |
| Tarjeta de producto: imagen cuadrada `object-contain`, marca, nombre (2 líneas), SKU en mono, precio + "IVA incluido", "Más información" sin cifra | **Se adopta** la estructura | `ProductCard.tsx` |
| Botón "Añadir al carrito" dentro de la tarjeta | **No en el MVP** (se añade desde la ficha, RF-029) — ver VAL-05 | Menos toques accidentales; coherencia con RF-029 |
| Selector de cantidad con botones − y + de 48 px, 1 a 99 | Se adopta | `ProductBuyBox.tsx`; RF-029 |
| Calculadora con *sliders* | **Se sustituye** por campos numéricos con − y + (alternativa a arrastre, WCAG 2.5.7) | RNF-072 |

---

## 9. Tokens de componente comunes

| Token | Valor | Nota |
|---|---|---|
| `size.touchMin` | 48 dp | Objetivo táctil mínimo (Android 48 dp; iOS 44 pt también cubierto) |
| `size.button.default` / `size.button.large` | 48 / 56 dp | `large` para "Pagar", "Añadir al carrito", "Enviar" |
| `size.field.min` | 56 dp | Campo de texto |
| `size.icon.default` | 24 dp | |
| `size.navbar` | 80 dp | Barra inferior M3 |
| `size.appbar` | 64 dp | Barra superior (crece con la escala de texto) |
| `size.productImage` | 1:1 | `object-contain` sobre `surfaceContainer` |
| `stroke.border` | 1 dp | Bordes de campo, tarjetas |
| `stroke.focus` | 2 dp + 2 dp de separación | Anillo de foco `focusRing` fuera del componente |
| `stroke.error` | 2 dp | Borde de campo con error (más ícono y texto) |
| `opacity.disabled` | Sin opacidad: se usan `surfaceContainerHigh` + `onSurfaceVariant` (C01: 4,53:1) | Los inactivos están exentos de contraste, pero se mantiene legible |
| `scrim.opacity` | 0,32 | |

---

## 10. Componentes

> Estados universales: **normal, foco, presionado, deshabilitado, error, carga**. Donde un estado no aplica se indica. El foco es visible siempre (RNF-075, WCAG 2.4.7): anillo `focusRing` de 2 dp separado 2 dp del borde del componente (≥ 3:1 contra el fondo, N12 a N14). El estado "presionado" usa capa de estado del 12 % más color `primaryPressed`, sin escala (la web escala 0,97; no se replica por consistencia con movimiento reducido).

### 10.1 Botones

| Variante | Fondo / texto / borde | Uso | RF/AC |
|---|---|---|---|
| **Primario** (relleno) | `primary` / `onPrimary` / — (6,67:1) | Una acción principal por pantalla: "Añadir al carrito", "Pagar", "Iniciar sesión", "Enviar" | RF-029, RF-052 |
| **Tonal** | `primaryContainer` / `onPrimaryContainer` / — (7,68:1) | Acción secundaria: "Ver equipos", "Escribir por WhatsApp" | RF-062, RF-089 |
| **Contorno** | transparente / `primary` / `primary` 1 dp (borde 6,67:1) | "Quitar", "Reintentar" cuando hay otra primaria | — |
| **Texto** | transparente / `primary` | Enlaces de acción: "¿Olvidaste tu contraseña?", "Limpiar filtros" | RF-042, AC-013-3 |
| **Destructivo** | `error` / `onError` (5,79:1) | Solo en diálogos de confirmación irreversible ("Eliminar cuenta") | RF-110 |

| Estado | Especificación |
|---|---|
| Normal | Alto 48 dp (56 dp en `large`); ancho mínimo 64 dp; relleno horizontal 24 dp; radio `radius.lg`; texto `type.label.large`, ícono de 20 dp con 8 dp de hueco. |
| Foco | Anillo `focusRing` 2 dp con 2 dp de separación. |
| Presionado | Capa de estado 12 % + `primaryPressed` (`#0B4970`, 9,54:1 con texto blanco, L17). |
| Deshabilitado | `surfaceContainerHigh` + texto `onSurfaceVariant`; **siempre acompañado de una línea visible que explica por qué** (p. ej. bajo "Pagar": "Quita los productos agotados para continuar"). TalkBack/VoiceOver anuncian "no disponible" + el motivo en la descripción. |
| Error | Un botón no tiene estado de error propio: el error se muestra en un `Banner`/mensaje adyacente. |
| Carga | Mismo ancho (sin saltos de diseño), el texto se reemplaza por indicador circular de 20 dp; semántica "Procesando"; el botón queda deshabilitado y **bloquea el doble toque** (AC-038-6, AC-040-4, AC-052-6, AC-096-5). |

### 10.2 Campo de texto (`IprTextField`)

| Aspecto | Especificación |
|---|---|
| Anatomía | **Etiqueta visible encima** (`type.label.large`, `onSurface`); campo con borde 1 dp `outline` (`#75777B`, ≥ 3:1) y radio `radius.md`; ayuda o error debajo (`type.body.small`). La etiqueta **no** se reemplaza por el texto de ayuda ni por el *placeholder* (RNF-073). |
| Alto / relleno | ≥ 56 dp; relleno 16 dp horizontal. |
| Normal | Texto `onSurface` 16 sp; *placeholder* en `onSurfaceVariant` solo como ejemplo ("Ej.: 500-0144"), nunca como instrucción esencial. |
| Foco | Borde 2 dp `primary` (6,67:1) + anillo de foco; el campo se desplaza a la vista sobre el teclado. |
| Presionado | No aplica (el foco sustituye). |
| Deshabilitado | Fondo `surfaceContainerHigh`, texto `onSurfaceVariant`; se evita en formularios (se prefiere mostrar el valor como texto). |
| Error | Borde 2 dp `error` **más** ícono `error` y mensaje en `error` con texto de **cómo corregirlo** (WCAG 3.3.1, 3.3.3). El campo expone el error a lectores de pantalla (`errorText` en `Semantics`). El error no depende del color: ícono + texto. |
| Carga | Indicador lineal bajo el campo solo en sugerencias de búsqueda; el campo sigue editable. |
| Contraseña | Enmascarada; botón 48 dp "Mostrar contraseña"/"Ocultar contraseña" con etiqueta semántica; se vuelve a enmascarar al pasar a segundo plano (AC-040-8); pegado y gestores de contraseñas permitidos (WCAG 3.3.8). |
| Teclado y autocompletado | `keyboardType` y `autofillHints` por campo (`email`, `username`, `password`, `newPassword`, `name`, `telephoneNumber`, `addressLine1`…) (WCAG 1.3.5). |

### 10.3 Selector de cantidad

Control compuesto `−` / valor / `+` de 48 dp cada parte (la web usa `size-12` = 48 px). Rango **1 a 99** (RF-029, RF-049). Valor editable con teclado numérico; fuera de rango se corrige al límite con mensaje (AC-029-3). `−` deshabilitado en 1 y `+` en 99 (AC-029-2). Semántica: control ajustable ("Cantidad, 3. Deslizar para ajustar") **y** botones con etiquetas "Reducir cantidad" / "Aumentar cantidad"; cada cambio se anuncia ("Cantidad 4"). Estados: normal, foco (anillo), presionado (capa de estado), deshabilitado (límite), error ("La cantidad debe estar entre 1 y 99."), carga (no aplica).

### 10.4 Tarjeta de producto (`ProductCard`)

Estructura (RF-011, AC-011-1): imagen 1:1 `object-contain` sobre `surfaceContainer` (radio `radius.md`) → marca en texto `type.label.medium` → **nombre** (`type.title.medium`, 2 líneas con puntos suspensivos) → **SKU** (`type.mono.sku`, `onSurfaceVariant`, prefijo "SKU ") → bloque de precio → insignia de stock. Toda la tarjeta es **un único objetivo táctil** que abre la ficha (AC-003-5, AC-012-3). Tarjeta: radio `radius.2xl`, relleno `space.3`, borde `outlineVariant` (decorativo).

| Variante | Bloque de precio y estado | Reglas |
|---|---|---|
| **Con precio, en stock** | `$ 1.234.567` (`type.price.card`, `primary`) + "IVA incluido" (`type.body.small`, `onSurfaceVariant`); insignia "En stock" | Formato COP sin decimales; el cliente no recalcula (AC-011-5) |
| **Con descuento** (Liquidaciones, `onSale`) | Precio regular tachado en `onSurfaceVariant` + precio especial en `primary` + insignia "Oferta" (`success`/`onSuccess`) | Dos valores distinguibles por **forma** (tachado) además de color (AC-018-1) |
| **Sin precio** | **Sin cifra.** Texto "Más información" como botón tonal de la tarjeta o indicación textual; nunca "$0", "NaN" ni "null" | RF-012, AC-012-1/-2/-4 |
| **Agotado** | Precio (si lo tiene) + insignia "Agotado"; sin acción de compra | RF-031, AC-031-5 |
| **Bajo pedido** (`onbackorder`) | Insignia informativa "Disponible bajo pedido" (contenedor tonal azul + ícono `schedule`); **no comprable** en el MVP | `SUP-H06` (recomendación H-06 no aprobada; RF-031 y PA-12 aún abiertos) |
| **Sin imagen** | Marcador de posición con ícono y `semanticsLabel` "{nombre} (sin imagen disponible)" | AC-011-4 |
| **Carga** | Esqueleto: bloque 1:1 + 3 líneas, sin pulso si hay movimiento reducido | RNF-003 |
| **Error de imagen** | Igual que "sin imagen" | — |

| Estado | Especificación |
|---|---|
| Foco | Anillo alrededor de toda la tarjeta. |
| Presionado | Capa de estado 8 % sobre la tarjeta. |
| Lista (1 columna) | Imagen 96–120 dp a la izquierda y texto a la derecha; se activa a escala ≥ 1,5 o por conmutador vista cuadrícula/lista (la web ya tiene ambas variantes). |

**Semántica (obligatoria):** un solo nodo fusionado con etiqueta `"{nombre}, marca {marca}, referencia {SKU}, {precio} pesos, IVA incluido, {estado de stock}"` (sin precio: "{nombre}, marca…, más información"); acción por defecto "Abrir detalle del producto". El precio se lee "1.234.567 pesos" (RNF-070, FA §12).

### 10.5 Chips de filtro y de orden

| Tipo | Especificación |
|---|---|
| Chip de filtro (selector) | Alto visual 32 dp con **área táctil de 48 dp**; sin seleccionar: borde `outline`, texto `onSurface` (C09, 17,48:1); **seleccionado: relleno `secondary` (`#0A3651`) + texto blanco (12,66:1) + ícono de verificación** (el estado no es solo color). |
| Chip de filtro activo (quitable) | Texto + ícono `close` con etiqueta "Quitar filtro {nombre}"; cada uno se quita individualmente y existe "Limpiar filtros" (AC-013-3). |
| Chip de orden | Botón que abre una hoja con las opciones **que entrega el servidor** (AC-015-1); el orden elegido se indica en el chip ("Ordenar: …"). |
| Estados | Normal, foco, presionado, seleccionado, deshabilitado (sin opciones), error (no aplica), carga (esqueleto de 4 chips). |

### 10.6 Insignias (stock, precio, estado)

Todas combinan **ícono + texto** en un contenedor tonal (RNF-076). Alto mínimo 24 dp, texto `type.label.medium` (12 sp), no interactivas (se leen dentro de la tarjeta o la ficha).

| Insignia | Contenedor / texto / ícono | Texto |
|---|---|---|
| Stock disponible | `successContainer` / `onSuccessContainer` / `success` `check_circle` | "En stock" |
| Agotado | `errorContainer` / `onErrorContainer` / `error` `block` | "Agotado" |
| Bajo pedido | `primaryContainer` / `onPrimaryContainer` / `primary` `schedule` | "Disponible bajo pedido" (`SUP-H06`) |
| Oferta | `success` / `onSuccess` (o alternativa `#5BA628` + `#151A21`) | "Oferta" |
| Sede próxima | `surfaceContainerHigh` / `onSurface` | "Próximamente" |
| Estado de pedido | Contenedor tonal + ícono + **etiqueta del servidor (`statusLabel`)**; si el estado no está mapeado se muestra la etiqueta tal cual | Pagado, Pendiente, Fallido, Cancelado… (AC-056-8) |

Estados: son indicadores de solo lectura: normal únicamente; carga (esqueleto de 64 × 24 dp).

### 10.7 Barra de navegación inferior

| Aspecto | Especificación |
|---|---|
| Estructura | M3 `NavigationBar`, **4 destinos** (Inicio, Catálogo, Carrito, Cuenta). Decisión y alternativas: [navigation.md §3](navigation.md) (VAL-01, APR-06). |
| Dimensiones | Alto 80 dp; a 320 dp de ancho cada destino mide **80 dp** (con 5 destinos serían 64 dp), muy por encima del objetivo táctil de 48 dp. Ícono 24 dp + etiqueta `type.label.medium`. |
| Seleccionado | Ícono relleno + etiqueta SemiBold + color `primary` + indicador `primaryContainer`. Sin seleccionar: ícono contorno + `onSurfaceVariant` (5,59:1, N15). **El estado no se comunica solo con color** (forma del ícono + peso de la etiqueta). |
| Insignia de Carrito | Número de productos (tope visual "99+"); semántica "Carrito, 3 productos". Anuncia cambios con `liveRegion` ("Producto añadido. Carrito: 4 productos."). |
| Foco / presionado | Anillo de foco; capa de estado 12 %. |
| Deshabilitado | No hay destinos deshabilitados. |
| Visibilidad | Visible en las pantallas raíz y de primer nivel de cada pestaña; **oculta** en pantallas de flujo (checkout en curso, formularios largos, resultado de pago) para evitar salidas accidentales. |
| **Escala de texto** | Con 4 destinos de 80 dp, la etiqueta "Catálogo" a 200 % (≈ 24 sp) mide más de 80 dp. **[PROPUESTA]** limitar **solo las etiquetas de la barra** a escala 1,3× (el nombre accesible completo y el *tooltip* se conservan; el resto de la app no se limita). Esto es una **excepción a RNF-068 ("no se limita el factor de escala")**; RNF-067 admite "excepción documentada y aceptada". **APR-12:** aceptarla, o adoptar la alternativa de pasar a menú lateral (*drawer*) a escalas ≥ 1,5×. Debe probarse a 200 % en dispositivos reales (VAL-12). |

### 10.8 Barra superior (`AppBar`)

| Variante | Contenido | Notas |
|---|---|---|
| **Raíz** (Inicio, Catálogo, Carrito, Cuenta) | Título o logotipo (Inicio); acción **Buscar** (excepto en Inicio, donde el buscador es un campo visible); acción **Ayuda** (ícono `support_agent`, misma posición en todas las raíces: WCAG 3.2.6, RNF-077); en Catálogo y Carrito, **Carrito** con insignia solo fuera de la pestaña Carrito | Alto 64 dp que crece con la escala |
| **Detalle** | Flecha atrás (48 dp, etiqueta "Atrás"), título (2 líneas a 200 %), acciones contextuales | Título de la pantalla = nombre de la categoría / del producto / de la sede |
| **Flujo** | Cierre ("X" con etiqueta "Cerrar") o "Cancelar" textual; sin barra inferior | Checkout, formularios con cambios sin guardar |
| Estados | Normal, desplazado (elevación 1), foco de cada acción | Sin estado de error ni carga propios |

### 10.9 Hojas inferiores (bottom sheets)

Modales para: **filtros y orden**, **alternativas de contacto** ("WhatsApp no disponible"), **selección de departamento y ciudad** (con buscador), **revisión de cambios del carrito** si no cabe en pantalla. Altura máxima 90 % de la pantalla; esquinas superiores 28 dp; fondo `surface`; `scrim` 32 %.

| Regla | Detalle |
|---|---|
| Cierre | Botón **"Cerrar"** visible (48 dp) **además** del gesto de arrastre y del botón atrás del sistema (WCAG 2.5.7). Tocar el *scrim* cierra, salvo en hojas con cambios sin aplicar (pide confirmación). |
| Foco y semántica | Al abrir, el foco pasa al título; la hoja es un `scope`/nombre de ruta ("Filtros"); el foco queda atrapado dentro y vuelve al disparador al cerrar (RNF-075). |
| Contenido | Desplazable; acciones finales ("Aplicar", "Limpiar") en barra fija inferior sobre el teclado. |
| Estados | Normal; carga (esqueleto de opciones); error (mensaje + "Reintentar" dentro de la hoja, conservando los filtros previos, AC-013-5); vacío (p. ej. sin atributos: la sección se omite, AC-014-2). |

### 10.10 Diálogos

| Tipo | Uso | Especificación |
|---|---|---|
| **Confirmación destructiva** | Eliminar cuenta (RF-110) | Título, cuerpo con **qué se elimina y qué se conserva y por cuánto tiempo** (texto final de Jurídico, APR-08), acciones "Cancelar" (texto, **foco inicial aquí**) y "Eliminar cuenta" (destructivo). Exige contraseña actual en un segundo paso (AC-110-3). |
| **Información** | Avisos puntuales que el usuario debe leer antes de seguir (uso excepcional). **No** se usa para avisar que el pago se abre en el navegador seguro: ese aviso va como línea fija bajo el botón "Pagar" para no consumir la vigencia del ticket (≈ 60 s) ni añadir un toque | Título + cuerpo + "Entendido" |
| **Sesión expirada** | AC-044-5 | No bloquea: se prefiere pantalla de inicio de sesión con mensaje (ver [F17](user_flows.md)) |

Reglas: máximo 2 acciones; ancho 280–560 dp; el foco queda atrapado; `Escape`/atrás = "Cancelar"; el diálogo se anuncia ("Eliminar cuenta, diálogo"). Cerrar sesión **no** usa diálogo (reversible).

### 10.11 Snackbars y avisos efímeros

| Aspecto | Especificación |
|---|---|
| Aspecto | `inverseSurface` (`#151A21`), texto blanco (17,48:1, C02), acción en `#439BE4` (5,87:1, C03), radio `radius.lg`, margen 16 dp, **sobre la barra inferior**. |
| Duración | 4 s sin acción; 8 s con acción ("Deshacer", "Ver carrito"); **sin cierre automático** si `MediaQuery.accessibleNavigation` está activo o la acción es crítica. Tiempos revisables con las preferencias de tiempo del sistema. |
| Semántica | `liveRegion` (cortés): se anuncia el texto y la acción. **La información crítica no vive solo en un snackbar**: los errores que bloquean quedan en pantalla (banner). |
| Usos | "Producto añadido al carrito" (+ "Ver carrito"), "Producto quitado" (+ "Deshacer"), "Enlace copiado". |
| Estados | Normal; foco (acción con anillo); no tiene error ni carga. |

### 10.12 Esqueletos (skeletons)

Forma por componente (tarjeta de producto, fila de pedido, ficha, lista de sedes), color `surfaceContainerHigh` con pulso 1,2 s entre 60 % y 100 % de opacidad; **sin pulso** con movimiento reducido. Aparecen en **≤ 100 ms** tras navegar (RNF-003). Los elementos del esqueleto **no** entran al árbol de semántica: el contenedor expone una sola etiqueta "Cargando productos…" anunciada una vez (`liveRegion`). Si la carga supera ≈ 10 s se reemplaza por `ErrorState` de tiempo agotado.

### 10.13 Banners en pantalla

| Banner | Cuándo | Contenido |
|---|---|---|
| **Datos guardados** (`StaleBanner`) | Se muestra caché vencida o sin red (RNF-022) | "Mostrando información guardada; puede no estar actualizada." + "Actualizar" |
| **Sin conexión** (no bloqueante) | ≤ 3 s tras detectar fallos de red (RNF-020) | "Sin conexión. Algunas funciones no están disponibles." |
| **Cambios en el carrito** | Tras revalidar (RF-050) | Lista de cambios (precio anterior → nuevo; agotado; sin precio) |
| **Pago pendiente** | Resultado "pendiente" o intento reciente (RF-056) | "Tu pago está en verificación." + "Ver mis pedidos" |

Contenedor tonal azul (`primaryContainer`/`onPrimaryContainer`) + ícono + texto; para errores bloqueantes, `errorContainer` + ícono `error`. Se anuncian con `liveRegion` cortés.

### 10.14 Otros componentes

| Componente | Especificación |
|---|---|
| **Casilla** (consentimiento) | Objetivo 48 dp; sin marcar por defecto (AC-039-1); borde `outline`; con texto y enlaces subrayados a términos y política (los enlaces tienen su propio objetivo táctil ≥ 48 dp de alto). |
| **Selección única** (tipo de PQRS, clima) | `SegmentedButton` o lista de opciones de 48 dp con ícono de selección; etiqueta de grupo visible. |
| **Selector de departamento y ciudad** | Campo que abre una hoja con **buscador** y lista; la ciudad depende del departamento (AC-106-3). |
| **Galería de imágenes** | Deslizar **y** botones "Imagen anterior"/"Imagen siguiente" de 48 dp; indicador "Imagen 2 de 4" (texto, no solo puntos); sin autoavance; toque abre pantalla completa con cierre explícito (RNF-072, AC-026-2). |
| **Fila de lista** (`ListTile`) | Alto ≥ 56 dp, ícono inicial opcional, chevron final; todo el renglón es el objetivo; subtítulo en `onSurfaceVariant`. |
| **Indicador de progreso** | Circular de 20/40 dp; lineal para cargas de hoja; en el checkout, texto de estado ("Abriendo el pago seguro…", "Confirmando tu pago…"). |
| **Contador de caracteres** | "523/1.000"; al llegar al límite no admite más caracteres (AC-096-3); se anuncia solo al pasar de 90 %. |
| **Resumen de precio** (`PriceText`) | Cifra + "IVA incluido"; semántica "{n} pesos, IVA incluido"; en el carrito el subtotal se rotula "Subtotal informativo". |

---

## 11. Estados vacío, carga y error (patrones)

Cada pantalla de contenido remoto resuelve **cuatro estados mutuamente excluyentes**: cargando, datos, vacío (el servidor respondió 200 con lista vacía) y error (falló la red o el servidor). **Error y vacío nunca se confunden** (AC-009-7, AC-023-5).

| Estado | Componente | Estructura | Accesibilidad |
|---|---|---|---|
| Cargando | `SkeletonList` / `SkeletonDetail` | §10.12 | Anuncio único "Cargando…" |
| Vacío | `EmptyState` | Ilustración opcional 120 dp (decorativa, excluida de semántica) + titular `type.title.medium` + explicación `type.body.medium` + **una** acción primaria | El titular recibe el foco de lectura al aparecer; la acción es alcanzable |
| Error | `ErrorState(AppFailure)` | Ícono `error` + titular + explicación en lenguaje no técnico (**sin códigos HTTP, trazas ni nombres de servidor**, AC-009-1) + "Reintentar" (+ "Escribir por WhatsApp" cuando aplique) | `liveRegion` asertivo al aparecer en carga principal |
| Datos obsoletos | `StaleBanner` | §10.13 | `liveRegion` cortés |
| Error al cargar más | Pie de lista con "Reintentar" | No borra lo ya cargado (AC-009-5, AC-011-6) | Foco alcanzable al final de la lista |

---

## 12. Textos de interfaz (es-CO) — catálogo base

**Voz:** tuteo, tono cercano y técnico, sin exclamaciones ni jerga (borrador coherente con los mensajes de FA §7.3 y la calculadora web). **[PENDIENTE]** APR-04 (tú frente a usted; la web mezcla ambos: "Su solicitud fue enviada…" en PQRS y "confírmalo con un asesor" en la calculadora) y VAL-10. Formatos: precios `$ 1.234.567`, "IVA incluido"; fechas `dd/MM/aaaa`; hora de Colombia. **No se promete tiempo de respuesta** (AC-094-4). Todo texto final lo aprueban Marketing (voz) y Jurídico (textos legales, APR-08).

### 12.1 Vacíos

| Contexto | Titular | Explicación | Acción |
|---|---|---|---|
| Búsqueda sin resultados (RF-023) | "No encontramos “{término}”" | "Revisa la ortografía o prueba con la referencia (SKU) o la marca. También puedes pedir ayuda a un asesor." | **"Escribir por WhatsApp"** (con el término) · "Buscar de nuevo" |
| Filtros sin resultados (AC-013-4) | "Ningún producto cumple estos filtros" | "Quita algún filtro para ver más resultados." | "Limpiar filtros" |
| Categoría sin productos (AC-010-3) | "Esta categoría aún no tiene productos" | "Prueba con el buscador o explora otra categoría." | "Buscar productos" |
| Marca sin productos (AC-016-4) | "Esta marca no tiene productos disponibles" | "Explora otras marcas o escribe a un asesor." | "Ver marcas" |
| Liquidaciones vacías (AC-018-6) | "No hay liquidaciones vigentes" | "Vuelve pronto o explora el catálogo." | "Ver catálogo" |
| Carrito vacío (AC-049-6) | "Tu carrito está vacío" | "Agrega productos desde el catálogo o busca por referencia." | "Ir al catálogo" (sin "Pagar") |
| Sin pedidos (AC-107-3) | "Aún no tienes pedidos" | "Cuando compres, aquí verás su estado." | "Ir al catálogo" |

### 12.2 Cargas

| Contexto | Texto de anuncio |
|---|---|
| Listados | "Cargando productos…" |
| Ficha | "Cargando producto…" |
| Carrito (revalidación) | "Revisando precios y disponibilidad…" |
| Checkout | "Preparando el pago seguro…" · "Abriendo el pago seguro…" · "Confirmando tu pago…" |
| Sedes | "Cargando sedes…" |

### 12.3 Errores (base: FA §7.3, borrador)

| Fallo | Titular / mensaje | Acción |
|---|---|---|
| Sin conexión | "No tienes conexión. Revisa tu internet." | Reintentar (se muestra caché si existe) |
| Tiempo agotado | "La respuesta está tardando. Intenta de nuevo." | Reintentar |
| Producto no disponible (404, AC-026-6) | "Este producto ya no está disponible." | Volver |
| Tienda no disponible (503) | "La tienda no está disponible en este momento. Intenta de nuevo en unos minutos." | Reintentar |
| Demasiados intentos (429, AC-045-1) | "Demasiados intentos. Espera {tiempo} para volver a intentarlo." | Botón deshabilitado con cuenta regresiva en texto; **no indica si la cuenta existe** (AC-045-7) |
| Credenciales (AC-040-2) | "Correo o contraseña incorrectos." | Mismo mensaje exista o no la cuenta; mismo para rol administrativo bloqueado (AC-048-1) |
| Sesión expirada (AC-044-5) | "Tu sesión terminó. Inicia sesión de nuevo." | Ir a inicio de sesión; **el carrito se conserva** |
| Verificación fallida del checkout | "No pudimos abrir el pago. Tu carrito sigue igual." | Reintentar |
| Estado del pedido no confirmado (AC-056-7) | "No pudimos confirmar el estado de tu pedido todavía." | Reintentar · Ver mis pedidos (**no** afirma éxito ni fallo) |
| Versión obsoleta | "Actualiza la app para continuar." | Ir a la tienda |
| Genérico | "Algo salió mal. Intenta de nuevo." | Reintentar |

### 12.4 Estados de pago (pantalla de resultado, RF-056)

| Estado | Titular | Cuerpo | Acciones |
|---|---|---|---|
| Pagado | "Pago confirmado" | "Tu pedido n.º {número} quedó registrado." | Ver pedido · Seguir comprando |
| Pendiente | "Tu pago está en verificación" | "Aún no recibimos la confirmación. Tu carrito no se vaciará hasta confirmarlo." | Ver mis pedidos · Volver al inicio |
| Fallido | "El pago no se completó" | "No se hizo ningún cobro **[a validar con Wompi, D-02]**. Tu carrito sigue igual." | Reintentar pago · Ver carrito |
| Cancelado | "Cancelaste el pago" | "Tu carrito sigue igual." | Reintentar pago · Seguir comprando |
| Sin pedido / abandonado | "No encontramos un pedido para este pago" | "Si pagaste, revisa Mis pedidos en unos minutos." | Reintentar pago · Ver mis pedidos |

> La afirmación "no se hizo ningún cobro" **no puede darse por cierta** mientras no se confirme el comportamiento de Wompi/WooCommerce (D-02, PA-11): el texto final lo fija el equipo web y Jurídico.

---

## 13. Brief de ilustraciones para estados vacíos y de error (no se generan imágenes)

| Estado | Escena sugerida | Notas |
|---|---|---|
| Búsqueda sin resultados | Lupa sobre un componente HVAC-R genérico (válvula, compresor) | Sin marcas de terceros |
| Carrito vacío | Carrito de compras con una pieza | — |
| Sin conexión | Antena o nube tachada | — |
| Error del servidor | Herramienta (llave) y cable desconectado | — |
| Pago pendiente | Reloj sobre un recibo | — |
| Sin pedidos | Caja vacía | — |

Requisitos: trazo lineal, paleta de marca (`#07628E`, `#0A3651`, `#EAF4F9`), 120–160 dp, **sin texto incrustado**, vectoriales, formato a definir con el equipo de desarrollo; decorativas (excluidas de semántica). Entrega y propiedad: APR-09.

---

## 14. Tokens nombrados y correspondencia con el tema de Flutter

> Ilustrativo de contrato interno, **no implementación**. La estructura sigue `shared/design_system/tokens/` (FA §13.2).

| Familia de tokens | Prefijo | Equivalente en Flutter |
|---|---|---|
| Color semántico | `color.*` (§3.4) | `ColorScheme` explícito (claro y oscuro) + `ThemeExtension<IprColors>` para `success*`, `brandGreen`, `focusRing`, `primaryPressed` |
| Tipografía | `type.*` (§5.2) | `TextTheme` + `ThemeExtension<IprTextStyles>` para `price.card`, `mono.sku` |
| Espaciado | `space.*` (§6.1) | Clase de constantes `SpacingTokens` (`double`) |
| Radio | `radius.*` (§6.3) | `RadiusTokens` + `ShapeBorder` de los temas de componente |
| Elevación | nivel 0 a 3 (§6.4) | `ElevationTokens` + `surfaceTintColor` |
| Tamaños | `size.*`, `stroke.*` (§9) | `SizeTokens`; `MaterialTapTargetSize.padded` (48 dp) |
| Movimiento | `motion.*` (§6.5) | `MotionTokens` (`Duration`, `Curve`) + lectura de `MediaQuery.disableAnimations` |

| Tema de componente (Flutter) | Configuración |
|---|---|
| `FilledButtonTheme` | Alto 48; `radius.lg`; colores `primary`/`onPrimary`; estado presionado `primaryPressed` |
| `OutlinedButtonTheme`, `TextButtonTheme` | Alto 48; borde `primary` |
| `InputDecorationTheme` | Borde `outline` 1 dp; foco `primary` 2 dp; error `error` 2 dp; etiqueta externa (no flotante) |
| `CardTheme` | `radius.2xl`; borde `outlineVariant`; elevación 0 |
| `NavigationBarTheme` | Alto 80; indicador `primaryContainer`; etiquetas `labelMedium` con tope de escala 1,3 (APR-12) |
| `ChipTheme` | Alto 32 + área táctil 48; seleccionado `secondary`/`onSecondary` con marca de verificación |
| `SnackBarTheme` | `inverseSurface`; comportamiento flotante; duración por accesibilidad |
| `DialogTheme`, `BottomSheetTheme` | Esquinas 28 dp; `scrim` 0,32 |
| `AppBarTheme` | `surface`; título `titleLarge`; elevación al desplazar |
| `PageTransitionsTheme` | Estándar por plataforma; `Duration.zero` con movimiento reducido |

**Correspondencia de componentes propios (FA §13.2):** `IprButton`, `PriceText`, `StockBadge` (texto + ícono, RNF-076), `ProductCard`, `IprTextField`, `WhatsAppButton`, además de `AsyncView`, `EmptyState`, `ErrorState`, `StaleBanner`, `SkeletonList`/`SkeletonDetail` (FA §10).

---

## 15. Trazabilidad

| Elemento del Design System | RF / RNF / AC |
|---|---|
| Tarjeta de producto y estados de precio/stock | RF-011, RF-012, RF-031; AC-011-1/-4/-5/-7, AC-012-1 a 012-5, AC-031-5; RNF-070, RNF-076 |
| Selector de cantidad y botón de compra | RF-029, RF-049; AC-029-1 a 029-3 |
| Filtros, orden, chips | RF-013 a RF-015; AC-013-3/-4, AC-015-1 |
| Estados vacío/carga/error | RF-009, RF-023; AC-009-1 a 009-7, AC-023-5; RNF-003, RNF-020, RNF-022, RNF-027 |
| Campo de texto y formularios | RF-038, RF-040, RF-096, RF-106; RNF-073 |
| Contraste y color | RNF-069, RNF-076 |
| Texto escalable, objetivos, gestos, foco, movimiento | RNF-068, RNF-071, RNF-072, RNF-075, RNF-074 |
| Textos es-CO, COP, fechas | RNF-084; FA §12 |
| Ayuda consistente | RNF-077 |
| Tipografía y licencias | D-13; RNF-008 |

---

## 16. Clasificación del contenido de este documento

| Tipo | Dónde |
|---|---|
| **Hechos** | §2 (tokens y tipografía de la web), §3.1 (contrastes calculados de colores observados), §5.1 (licencias y tamaños medidos), §3.3 (hallazgos del sitio web) |
| **Supuestos** | `SUP-H06` (bajo pedido no comprable), `SUP-UX01` (primario oscuro presionado) |
| **Propuestas** | Paleta derivada, reglas de uso del verde, tipografía y escala, rejilla, componentes, textos |
| **Pendientes** | APR-01 a APR-12, VAL-01 a VAL-14 (§17) |

---

## 17. Registro de aprobaciones (APR) y validaciones con usuarios (VAL)

Registro único para los cuatro documentos de `07_ux_ui`.

### 17.1 Aprobaciones requeridas

| ID | Quién | Qué se aprueba | Si se rechaza |
|---|---|---|---|
| APR-01 | Marketing | Paleta oficial; **cuál es el verde de marca** (`#5BA628` según docs frente a `#99C120` en `globals.css`); manual de marca 2025 (D-13) | Se reemplaza el valor del token `ipr.green.500`; los derivados se recalculan con el script |
| APR-02 | Marketing | Colores derivados: `#3F731C`, `#EBF8E2`, `#C1292F`, `#FAEBEB`, `#66686B` y tintes oscuros | Se usan las alternativas de §3.2 (regla 3); para el texto secundario se usa `#151A21` en peso 400 |
| APR-03 | IPR / Marketing | Modo oscuro en el MVP o fase 2 (RF-113, D-13) | Se ajusta solo el tema |
| APR-04 | Marketing | Voz: tú o usted; textos finales | Se reescribe el catálogo de §12 |
| APR-05 | Marketing / Jurídico | Tipografías y licencias frente al manual de marca (D-13) | Se cambia la familia |
| APR-06 | IPR | Estructura final de pestañas, tras VAL-01 | Se pasa a la alternativa de 5 destinos |
| APR-07 | Ingeniería IPR | Texto del aviso de estimación, etiquetas de clima y rangos de la calculadora (D-08) | El módulo K sale del MVP |
| APR-08 | Jurídico | Textos de consentimiento, eliminación de cuenta, datos conservados y plazos, derechos del titular (D-12) | No se publica la pantalla |
| APR-09 | IPR | Biblioteca de íconos (Material frente a Lucide) y producción de ilustraciones | — |
| APR-10 | Marketing | Logo vectorial y reglas de uso | Se usa texto de marca |
| APR-11 | IPR | Uso del verde de WhatsApp en el botón | Se mantiene el estilo tonal de IPR |
| APR-12 | IPR | Excepción documentada a RNF-068 (tope de escala 1,3× en etiquetas de la barra inferior) o adoptar *drawer* a escalas ≥ 1,5× | Se adopta el *drawer* adaptativo |

### 17.2 Validaciones con usuarios

| ID | Qué se valida | Método sugerido | Tema |
|---|---|---|---|
| VAL-01 | Pestañas: 4 (Inicio, Catálogo, Carrito, Cuenta) frente a 5 con Sedes; dónde buscan "Sedes" y "Ayuda" | Prueba de árbol + primer clic; clasificación de tarjetas | navigation.md §3 |
| VAL-02 | Sin onboarding: ¿entienden el inicio y el buscador sin guía? | Prueba de primer uso | F01 |
| VAL-03 | Búsqueda por SKU: formato de referencia que escriben (guiones, espacios, mayúsculas) y ubicación del buscador | Prueba de tareas con SKU reales de IPR | F03 |
| VAL-04 | Filtros en hoja inferior frente a pantalla completa; atributos útiles | Prueba de tareas | F04 |
| VAL-05 | Añadir rápido desde la tarjeta (sí/no) | Prueba A/B de prototipo | §8 |
| VAL-06 | Comprensión de "Más información" y de "IVA incluido"; confianza al no ver precio | Entrevista + prueba de comprensión | F05 |
| VAL-07 | Comprensión del pago en navegador seguro, del estado "pendiente" y de los mensajes de retorno | Prueba de usabilidad con sandbox | F10 |
| VAL-08 | Registro con respuesta uniforme y verificación de correo (`SUP-H03`) | Prueba de tareas | F06 |
| VAL-09 | Calculadora: campos con − y + frente a *sliders*; comprensión del aviso | Prueba de tareas | F14 |
| VAL-10 | Voz (tú/usted) y claridad de errores | Prueba de comprensión | §12 |
| VAL-11 | Eliminación de cuenta: ¿entienden qué se conserva? | Prueba de comprensión | F13 |
| VAL-12 | **Accesibilidad con personas usuarias de TalkBack/VoiceOver y texto al 200 %** | Pruebas con usuarios con discapacidad visual y motriz | accessibility.md §10 |
| VAL-13 | Etiqueta "Disponible bajo pedido" y expectativa de compra (`SUP-H06`) | Prueba de comprensión | F05 |
| VAL-14 | Sedes: lista por ciudad frente a buscador; acciones llamar/WhatsApp/cómo llegar | Prueba de tareas | F15 |

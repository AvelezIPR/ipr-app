# Accesibilidad — App móvil IPR (objetivo WCAG 2.2 AA)

| | |
|---|---|
| **Proyecto** | App móvil Flutter de IPR Partes y Repuestos (Inverprimos S.A.S.) |
| **Fase** | UX/UI. No se programa. Especificación de diseño y plan de verificación. |
| **Fecha** | 2026-11-18 |
| **Estado** | BORRADOR. **Nada se declara cumplido**: todo lo descrito es diseño por verificar (ver §1.2). |
| **Documentos hermanos** | [design_system.md](design_system.md) (convenciones, tokens, registro APR/VAL en §17) · [navigation.md](navigation.md) · [user_flows.md](user_flows.md) |
| **Fuentes** | [RNF §F Accesibilidad (RNF-067 a RNF-077)](../02_requirements/non_functional_requirements.md) · [Criterios de aceptación](../02_requirements/acceptance_criteria.md) · [Arquitectura Flutter §14](../03_architecture/flutter_app_architecture.md) · WCAG 2.2 (W3C) |

Etiquetas: **[HECHO]**, **[SUPUESTO]**, **[PROPUESTA]**, **[PENDIENTE]** (design_system.md §0.1).

---

## 1. Objetivo, alcance y estado

### 1.1 Objetivo y alcance

| Aspecto | Contenido |
|---|---|
| **Objetivo [HECHO: RNF-067]** | Conformidad **WCAG 2.2 nivel AA** en los flujos críticos del MVP: catálogo, búsqueda, ficha, carrito, inicio de sesión y registro, inicio de pago, pedidos y eliminación de cuenta. Meta: **0 criterios A/AA aplicables en falla**, o excepción documentada y aceptada. |
| **Interpretación** | WCAG se redactó para web; en una app nativa se aplica por interpretación (WCAG2ICT y guías móviles del W3C). Cada criterio se verifica con su equivalente móvil. |
| **Fuera del control de la app [HECHO: RNF-077]** | El checkout de WooCommerce/Wompi que se abre en el navegador seguro. Se prueba con lector de pantalla y zoom 200 % y los hallazgos se reportan al equipo web como riesgo. |
| **Plataformas** | Android (TalkBack, Switch Access, Accessibility Scanner) e iOS (VoiceOver, Switch Control, Accessibility Inspector). |

### 1.2 Estado de verificación

| Área | Estado a la fecha de este documento |
|---|---|
| Contraste de la paleta | **Calculado** con un script reproducible (Anexo A; 94 combinaciones). **No verificado** con una herramienta independiente ni sobre pantallas reales (MED-12 pendiente). |
| Objetivos táctiles, texto al 200 %, lectores de pantalla, formularios, foco, movimiento | **Solo diseño.** No hay app ni prototipo evaluado. |
| Pruebas con personas usuarias de tecnologías de apoyo | **No realizadas** (VAL-12). |
| Declaración de conformidad | **No se emite.** Solo podrá emitirse tras ejecutar el plan del §12 y cerrar o aceptar formalmente los hallazgos. |

### 1.3 Excepciones propuestas (a aprobar formalmente)

| ID | Excepción | Criterio afectado | Estado |
|---|---|---|---|
| EX-01 | Etiquetas de la barra inferior limitadas a escala 1,3× (nombre accesible completo y *tooltip* se conservan) | WCAG 1.4.4 / RNF-068 | **PROPUESTA**, APR-12 (alternativa: menú lateral a escalas ≥ 1,5×) |
| EX-02 | Checkout externo (WooCommerce/Wompi) | Todos | Fuera de control; se reporta (RNF-077) |
| EX-03 | Tamaños de accesibilidad de iOS por encima del 200 % (hasta AX5) | WCAG 1.4.4 | "Mejor esfuerzo" según RNF-068 |
| EX-04 | Orientación bloqueada en vertical, solo si DN-11 la decide | WCAG 1.3.4 | **PENDIENTE** (por ahora no se bloquea) |

---

## 2. Resumen de lo que se encontró

| Hallazgo | Detalle | Dónde |
|---|---|---|
| **Verde de marca `#5BA628`** | 3,03:1 sobre blanco: **no es válido para texto normal** ni para texto blanco sobre verde (3,03:1); sobre tinte azul solo 2,71:1 (ni siquiera como ícono). Sí vale con texto `#151A21` encima (5,77:1) y sobre fondo oscuro (6,15:1). | §3, design_system §3 |
| **Gris de texto secundario web `#75777B`** | 4,49:1 sobre blanco, 4,10:1 sobre `#F3F5F7`, 4,02:1 sobre `#EAF4F9`: **no alcanza 4,5:1** (queda en 0,01 en el mejor caso). | §3 |
| **Rojo destructivo web `#D64045`** | 4,49:1 sobre blanco, 4,11:1 sobre atenuada: **no alcanza 4,5:1** como texto. | §3 |
| **Bordes de campo web** | `#CBD5E1` (1,48:1) y `#E2E8F0` (1,23:1) no cumplen 3:1 (WCAG 1.4.11) como límite del campo. | §3 |
| **Sitio web actual** | "En stock" con `#99C120` sobre blanco 2,10:1; insignia "Oferta" blanco sobre `#99C120` 2,10:1; "Disponible bajo pedido" con ámbar `#D97706` 3,19:1; etiquetas de 11 px. | §3.3 |
| **Derivados propuestos** | Verde `#3F731C`, rojo `#C1292F`, gris `#66686B` y tintes: ≥ 5,0:1 sobre todas las superficies claras. **PROPUESTA A APROBAR por marketing** (APR-02). | design_system §3.2 |
| **Escala de texto en la barra inferior** | A 200 % la etiqueta "Catálogo" no cabe en 80 dp: requiere EX-01 o alternativa. | §5.3 |
| **Calculadora web con *sliders*** | El arrastre exige alternativa de un toque (WCAG 2.5.7): la app usa campos con − y +. | §9 |

Total: de **94** combinaciones calculadas, **21 no cumplen** y ninguna se adopta (detalle en design_system §3.3).

---

## 3. Contraste (WCAG 1.4.3 y 1.4.11, RNF-069)

### 3.1 Método

| Aspecto | Contenido |
|---|---|
| Fórmula | Luminancia relativa WCAG 2.x: `L = 0,2126·R + 0,7152·G + 0,0722·B` (canales linealizados); razón `(L1 + 0,05) / (L2 + 0,05)`. |
| Umbrales | Texto normal ≥ **4,5:1**; texto grande (≥ 24 sp, o ≥ 18,66 sp en negrita) y componentes gráficos/bordes de campo ≥ **3:1**. Los componentes inactivos están exentos (se mantienen legibles igualmente). |
| Reproducibilidad | Script en el Anexo A; se ejecuta con `python -I contraste.py` (solo biblioteca estándar). Los colores derivados se calculan con `--derivar` (se baja la luminosidad HSL manteniendo tono y saturación hasta cumplir ≥ 5,0:1 contra todas las superficies claras). |
| Límites | El cálculo es teórico: **no** evalúa texto sobre imágenes ni degradados, antialiasing real, modos de alto contraste del sistema ni daltonismo. Debe confirmarse con una herramienta independiente y en pantallas reales (MED-12). |

### 3.2 Reglas derivadas

1. Texto normal solo con pares marcados "CUMPLE" en la tabla del Anexo A.
2. El **azul `#07628E`** es el único color de marca válido como texto sobre claro (6,67:1); en oscuro se usa `#439BE4` (6,25:1).
3. **Verde `#5BA628`:** nunca como texto normal sobre claro; nunca con texto blanco; solo como relleno con texto `#151A21`, como ícono sobre **blanco** (3,03:1, margen mínimo) acompañado de texto, o sobre fondo oscuro.
4. Bordes de campos y casillas: `#75777B` (≥ 4,0:1 sobre todas las superficies).
5. Foco: anillo `#0A3651` de 2 dp (12,66:1 sobre blanco) en claro; `#EAF3F9` en oscuro.
6. Tarjetas e imágenes se identifican por su contenido: su borde decorativo (`#E2E8F0`) no necesita 3:1.
7. Estados con color siempre llevan texto o ícono (§8).

---

## 4. Objetivos táctiles (RNF-071, WCAG 2.5.8, Material y HIG)

**Requisito:** ≥ **48 × 48 dp** (Android) y ≥ **44 × 44 pt** (iOS) para todo elemento interactivo; en ningún caso < 24 × 24 px (WCAG 2.5.8). Se diseña a **48 dp** en ambas plataformas. Separación mínima de **8 dp** entre objetivos adyacentes.

| Elemento | Tamaño visual → área táctil | Observación |
|---|---|---|
| Botones | 48 dp (56 dp "large") | design_system §10.1 |
| Íconos de barra superior (Buscar, Ayuda, Carrito, Atrás, Cerrar) | 24 dp → **48 × 48 dp** | `MaterialTapTargetSize.padded`; etiqueta semántica obligatoria |
| Pestañas de la barra inferior | 80 dp de ancho × 80 dp de alto | — |
| Chips de filtro | 32 dp → **48 dp** de alto | Área táctil ampliada |
| Botones − y + de cantidad | 48 × 48 dp | La web ya usa 48 px |
| Casillas y botones de opción | 24 dp → **48 × 48 dp** | Texto adjunto también es tocable |
| "Mostrar contraseña" | 24 dp → 48 × 48 dp | — |
| Enlaces dentro de párrafos (términos, política) | Fila propia de ≥ 48 dp de alto | Evita pulsar el enlace equivocado |
| "Quitar" y "Deshacer" | 48 dp | Acción de snackbar incluida |
| Tarjeta de producto, fila de pedido, fila de sede | Toda el área de la tarjeta/fila | Un solo objetivo por tarjeta |
| Puntos del indicador de galería | **No son interactivos** | Se sustituyen por botones anterior/siguiente y texto "Imagen n de N" |

**Verificación:** `androidTapTargetGuideline` y `iOSTapTargetGuideline` en pruebas de widgets; inspección con Accessibility Scanner (Android) y Accessibility Inspector (iOS); revisión manual a escala 2,0.

---

## 5. Texto escalable (RNF-068, WCAG 1.4.4 y 1.4.10)

### 5.1 Reglas

| Regla | Detalle |
|---|---|
| Sin tope de escala | No se limita `TextScaler` (excepción única EX-01). Hasta **200 %** sin pérdida de contenido ni de función; 0 desbordes. |
| Alturas | Solo mínimas; ningún contenedor de texto con altura fija. |
| Reflujo | Tarjetas pasan a lista de 1 columna desde 1,5×; formularios en una columna; botones crecen en alto; barra superior admite 2 líneas de título. |
| Etiquetas de formulario | Siempre **encima** del campo (no flotantes). |
| Texto mínimo | 12 sp; ningún texto de 11 sp (la web los usa). |
| Preferencias del sistema | Se respetan el texto en negrita y los modos de alto contraste del sistema donde existan. |
| Ancho mínimo | 320 dp sin desplazamiento horizontal (reflujo, WCAG 1.4.10). |

### 5.2 Matriz de pruebas

| Escala | Android | iOS | Qué se revisa |
|---|---|---|---|
| 1,0 | Predeterminado | Predeterminado | Línea base |
| 1,3 | Grande | Grande | Tarjeta de 2 columnas; etiquetas de barra |
| 2,0 | Máximo (200 %) | Escala de accesibilidad grande (mejor esfuerzo) | Reflujo, ausencia de recortes, botones y campos completos |
| Tamaño de pantalla grande | "Tamaño de pantalla" al máximo + texto al máximo | Zoom de pantalla | Combinación peor caso a 320 dp |

Pantallas críticas: PT-01, PT-03, PT-08, PT-10, PT-12, PT-14, PT-15, PT-18, PT-20, PT-24, PT-31, PT-35. *Golden tests* a 1,0, 1,3 y 2,0 (FA §14).

### 5.3 Riesgo conocido: etiquetas de la barra inferior

Con 4 destinos de 80 dp (320 dp de ancho) la etiqueta más larga ("Catálogo", 12 sp) a 200 % mide ≈ 24 sp y **no cabe** en una línea. **Propuesta EX-01:** limitar solo esas etiquetas a 1,3×, conservar el nombre accesible completo (el lector lo anuncia entero) y un *tooltip* en pulsación larga. Requiere aprobación formal (APR-12) porque contradice "no se limita el factor de escala". Alternativa sin excepción: a escalas ≥ 1,5× sustituir la barra por un menú lateral. **Debe probarse en dispositivos reales a 200 %** (VAL-12).

---

## 6. Lectores de pantalla: TalkBack y VoiceOver (RNF-070, WCAG 1.1.1, 1.3.1, 4.1.2, 4.1.3)

### 6.1 Principios

| Principio | Detalle |
|---|---|
| Nombre, rol y estado | **100 %** de los elementos interactivos con nombre accesible, rol y estado (seleccionado, deshabilitado, expandido, error). |
| Idioma | La app declara `es_CO` para que los lectores usen voz en español. |
| Imágenes | Imagen de producto con alternativa = nombre del producto; ilustraciones y adornos **excluidos** del árbol de semántica. |
| Nombre visible incluido en el nombre accesible | El nombre accesible empieza con el texto visible (WCAG 2.5.3). |
| Un nodo por tarjeta | Las tarjetas se fusionan en un solo nodo con una acción por defecto. |
| Encabezados | Cada pantalla tiene un título (barra superior) y secciones con encabezado semántico (p. ej. ciudades en Sedes, secciones de Cuenta). |
| Precios | Se leen en pesos: "1.234.567 pesos, IVA incluido" (no "peso 1 234 567"). |
| Fechas | `dd/MM/aaaa` visible; lectura completa ("18 de noviembre de 2026"). |

### 6.2 Etiquetas semánticas por componente (es-CO, borrador)

| Componente | Etiqueta / valor leído | Rol y estado |
|---|---|---|
| Buscador de Inicio | "Buscar productos por nombre, marca o referencia" | Campo de texto; al activarlo abre PT-06 con el teclado |
| Botón Ayuda | "Ayuda y contacto" | Botón |
| Botón Carrito (barra) | "Carrito, 3 productos" / "Carrito, vacío" | Botón; el cambio se anuncia |
| Pestaña | "Catálogo, pestaña 2 de 4" | Pestaña; seleccionada / no seleccionada |
| Tarjeta de producto | "{nombre}, marca {marca}, referencia {SKU}, {n} pesos, IVA incluido, en stock" · sin precio: "…, más información" · agotado: "…, agotado" | Botón; acción "Abrir detalle del producto" |
| SKU | "Referencia 500 guion 0144" **[PROPUESTA: la lectura exacta debe probarse con TalkBack/VoiceOver, VAL-12]** | Texto |
| Insignia de stock | Se lee dentro de la tarjeta/ficha ("En stock", "Agotado", "Disponible bajo pedido") | Texto (no foco independiente) |
| Galería | "Galería de imágenes, imagen 2 de 4" · botones "Imagen anterior", "Imagen siguiente" · "Ampliar imagen" | Contenedor + botones |
| Selector de cantidad | "Cantidad, 3" · "Reducir cantidad" · "Aumentar cantidad" | Control ajustable; el cambio se anuncia ("Cantidad 4") |
| Añadir al carrito | "Añadir al carrito, {nombre}" | Botón; carga: "Añadiendo…" |
| Más información | "Más información sobre {nombre}, abre WhatsApp" | Botón |
| Chip de filtro | "Marca {X}, seleccionado" / "Capacidad 12.000 BTU, no seleccionado" | Casilla/chip con estado |
| Filtro activo | "Quitar filtro Marca {X}" | Botón |
| Orden | "Ordenar por, {opción actual}" | Botón que abre hoja |
| Campo con error | "Correo, campo de texto, error: Escribe un correo válido, por ejemplo nombre@correo.com" | Campo con `errorText` |
| Mostrar contraseña | "Mostrar contraseña" / "Ocultar contraseña" | Botón con estado |
| Casilla de consentimiento | "Acepto los términos y la política de tratamiento de datos, casilla, no marcada" | Casilla |
| Línea del carrito | "{nombre}, cantidad 2, {n} pesos" · "…, agotado, quítalo para continuar" | Fila con acciones personalizadas "Quitar" y "Cambiar cantidad" |
| Pagar | "Pagar" / deshabilitado: "Pagar, no disponible. Quita los productos agotados o sin precio" | Botón |
| Estado de pedido | "Pedido 12345, 18 de noviembre de 2026, Pagado, 210.000 pesos" | Fila |
| Sede próxima | "{sede}, próximamente. Sin acciones de contacto" | Fila sin acción |
| Resultado del pago | Encabezado "Pago confirmado" + texto; `liveRegion` | Encabezado |
| Calculadora | "Largo en metros, 5,0" · "Resultado: potencia requerida 13.200 BTU, capacidad sugerida 18.000 BTU" | Control ajustable / región viva |
| Esqueleto | Contenedor "Cargando productos…" (los bloques del esqueleto no se leen) | Región viva (una vez) |
| Snackbar | Texto + "Deshacer"/"Ver carrito" | Región viva cortés |
| Hoja inferior, diálogo | "Filtros, hoja inferior" / "Eliminar cuenta, diálogo" | Ruta con nombre; foco atrapado |

### 6.3 Orden de foco y navegación

| Regla | Detalle (RNF-075, WCAG 2.4.3) |
|---|---|
| Orden | Igual al visual: arriba→abajo, inicio→fin. En la ficha: galería → marca → nombre → SKU → precio → stock → cantidad → botón → avisos → descripción → atributos. |
| Cambio de pantalla | El foco pasa al título de la nueva pantalla. |
| Hojas y diálogos | El foco entra al título, queda atrapado y **vuelve al elemento que abrió** al cerrar. |
| Errores de formulario | Al enviar con errores, el foco va al **primer campo con error**; los errores se anuncian. |
| Resultado de la calculadora | El foco pasa al encabezado del resultado. |
| Listas paginadas | Al cargar más: anuncio cortés "12 productos más cargados" sin mover el foco. |
| Barras fijas | La barra inferior y el teclado **no tapan** el elemento enfocado (WCAG 2.4.11): se desplaza a la vista. |
| Teclado externo / Switch | Todo alcanzable y operable con Tab/flechas/Enter y con interruptores; indicador de foco visible (2.4.7). |

### 6.4 Anuncios de cambios de estado (WCAG 4.1.3)

| Evento | Anuncio | Tipo |
|---|---|---|
| Añadir al carrito | "Producto añadido. Carrito: 4 productos." | Cortés |
| Quitar del carrito | "Producto quitado. Deshacer disponible." | Cortés |
| Revisión del carrito termina con cambios | "Revisamos tu carrito. Hay 2 cambios." | Cortés |
| Cargando y carga completa | "Cargando productos…" una vez; "{n} productos" al terminar | Cortés |
| Error de pantalla completa | "No tienes conexión. Revisa tu internet." | Asertivo |
| Pago | "Preparando el pago seguro" · "Abriendo el pago seguro" · "Confirmando tu pago" · resultado | Cortés; resultado asertivo |
| Bloqueo por intentos | "Demasiados intentos. Espera 30 segundos." (sin cuenta regresiva hablada por segundo) | Asertivo |
| Cambio de cantidad | "Cantidad 4" | Cortés |
| Resultado de calculadora | Texto completo del resultado | Cortés |

---

## 7. Formularios accesibles (RNF-073, WCAG 1.3.5, 3.3.1 a 3.3.4, 3.3.7, 3.3.8)

| Requisito | Diseño |
|---|---|
| **Etiqueta visible** (3.3.2) | Encima del campo, siempre visible; el *placeholder* solo da un ejemplo. Campos obligatorios: texto "(obligatorio)" o campos opcionales con "(opcional)", no solo asterisco o color. |
| **Identificación y sugerencia del error** (3.3.1, 3.3.3) | Mensaje junto al campo con ícono + texto que dice **cómo corregir**; asociado al campo para lectores. Ejemplo: "La contraseña debe tener al menos 8 caracteres." |
| **Prevención de errores** (3.3.4) | Acciones legales o irreversibles (**eliminar cuenta**, pagar) con confirmación explícita; el pago se confirma en el checkout. |
| **Propósito de entrada** (1.3.5) | `autofillHints`: `email`, `username`, `password`, `newPassword`, `givenName`, `familyName`, `telephoneNumber`, `streetAddress`/`addressLine1`, `postalCode`; `keyboardType` por campo (correo, teléfono, numérico). |
| **Entrada redundante** (3.3.7) | La dirección de envío ofrece "Igual a facturación"; el checkout se prellena con la cuenta (RF-054); el formulario conserva lo escrito ante errores de red. |
| **Autenticación accesible** (3.3.8) | Se permite **pegar** y usar gestores de contraseñas; "Mostrar contraseña"; **sin pruebas cognitivas** ni transcribir códigos. El anti-spam de PQRS "captcha o equivalente" (AC-096-6 **[A VALIDAR]**) **no puede ser** un CAPTCHA visual o de reconocimiento sin alternativa accesible. |
| **Etiqueta en el nombre** (2.5.3) | Los botones se leen con el texto visible ("Iniciar sesión", no "Entrar"). |
| **Estado de envío** | Botón en carga con texto "Procesando…" y bloqueo del doble toque; el resultado se anuncia. |
| **Límite de caracteres** | Contador "523/1.000" que se anuncia al pasar del 90 %; con 1.000 no admite más. |
| **Selectores largos** | Departamento y ciudad en hoja con **buscador**; la lista se opera con un toque, sin arrastre. |
| **Compatibilidad con teclado** | Tipo de acción del teclado ("Siguiente"/"Enviar"); el campo enfocado no queda tapado. |

---

## 8. El color no es el único canal (RNF-076, WCAG 1.4.1)

| Estado | Canal 1 | Canal 2 (no color) |
|---|---|---|
| En stock | Contenedor verde claro | Ícono de verificación + texto "En stock" |
| Agotado | Contenedor rojo claro | Ícono de bloqueo + texto "Agotado" |
| Disponible bajo pedido | Contenedor azul claro | Ícono de reloj + texto |
| Oferta / precio especial | Color de relleno | Texto "Oferta" + precio regular **tachado** |
| Campo con error | Borde rojo de 2 dp | Ícono de error + mensaje de texto + `errorText` semántico |
| Filtro / chip seleccionado | Relleno azul oscuro | Marca de verificación + estado semántico |
| Pestaña seleccionada | Color primario + indicador | Ícono relleno frente a contorno + etiqueta en negrita |
| Estado de pedido / pago | Contenedor tonal | Ícono + texto de la etiqueta del servidor |
| Sede próxima | Contenedor atenuado | Texto "Próximamente" y ausencia de botones |
| Enlaces | Azul primario | **Subrayado** en texto corrido |
| Producto sin precio en el carrito | Marca de aviso | Texto "Sin precio: no se puede pagar" |

**Verificación:** revisión de diseño pantalla por pantalla + simulación de daltonismo (protanopia, deuteranopia, tritanopia) en capturas.

---

## 9. Gestos, movimiento, orientación y tiempos

| Tema | Diseño | Criterio |
|---|---|---|
| **Alternativas a gestos** | Galería con botones anterior/siguiente; borrar del carrito con botón "Quitar" (no solo deslizar); hojas con botón "Cerrar"; calculadora con campos − y + (no *sliders*); selector de ubicación con lista y buscador; sin multitoque obligatorio ni zoom por pellizco como única vía (la galería ampliada tiene botones de zoom) | RNF-072; WCAG 2.5.1, 2.5.7 |
| **Cancelación del puntero** | Las acciones se ejecutan al **soltar** dentro del objetivo (comportamiento por defecto de los botones); las destructivas piden confirmación | WCAG 2.5.2 |
| **Sin movimiento del dispositivo** | No hay funciones por agitar o inclinar | WCAG 2.5.4 |
| **Movimiento reducido** | Con `MediaQuery.disableAnimations`: sin transiciones, sin pulso de esqueleto, sin desplazamiento animado; cambios instantáneos | RNF-074 |
| **Animaciones automáticas** | Ninguna > 5 s sin control; sin carruseles con autoavance; no se replican las marquesinas ni el destello de la web | WCAG 2.2.2 |
| **Parpadeo** | Nada parpadea (< 3 veces por segundo) | WCAG 2.3.1 |
| **Orientación** | No se bloquea; si DN-11 la fija en vertical se registra EX-04 | WCAG 1.3.4 |
| **Tiempo** | La app no impone límites de tiempo al usuario. La vigencia de 60 s del ticket afecta a la **apertura** del pago (≤ 5 s), no al usuario; el usuario puede reabrir el pago con un ticket nuevo | WCAG 2.2.1 |
| **Snackbars** | Con acción: 8 s; sin cierre automático si la navegación accesible está activa o la acción es crítica | WCAG 2.2.1 |
| **Transparencia/negrita** | Se respetan "texto en negrita" y los modos de alto contraste del sistema | RNF-069 (mejor esfuerzo) |

---

## 10. Criterios nuevos de WCAG 2.2 y otros de nivel A/AA clave: cómo los atiende el diseño

> "Estado" = **Diseñado, sin verificar** para todos (§1.2).

| Criterio | Cómo se atiende | Dónde |
|---|---|---|
| 1.1.1 Contenido no textual | Alternativas de imagen; decorativas excluidas | §6 |
| 1.3.1 Información y relaciones | Encabezados, listas y campos con semántica | §6.1 |
| 1.3.4 Orientación | No bloqueada | §9 |
| 1.3.5 Propósito de entrada | `autofillHints` | §7 |
| 1.4.1 Uso del color | Doble canal | §8 |
| 1.4.3 Contraste mínimo | Paleta calculada | §3 |
| 1.4.4 Cambio de tamaño del texto | 200 % sin límite (EX-01) | §5 |
| 1.4.10 Reflujo | 320 dp sin desplazamiento horizontal | §5 |
| 1.4.11 Contraste no textual | Bordes de campo, foco, íconos | §3 |
| 1.4.12 Espaciado del texto | Mejor esfuerzo (nativo); contenedores sin altura fija | §5 |
| 2.1.1 / 2.1.2 Teclado, sin trampas | Teclado externo y Switch; foco atrapado solo en modales con salida | §6.3 |
| 2.2.1 / 2.2.2 Tiempo, pausa | Sin límites; sin animación automática | §9 |
| 2.3.1 Umbral de destellos | Nada parpadea | §9 |
| 2.4.2 Título de página | Cada pantalla con título | §6.1 |
| 2.4.3 Orden del foco | Igual al visual | §6.3 |
| 2.4.4 / 2.4.6 Propósito del enlace, encabezados y etiquetas | Etiquetas descriptivas | §6.2 |
| 2.4.7 Foco visible | Anillo de 2 dp | §3.2 |
| **2.4.11 Foco no oculto (mínimo)** | Desplazamiento a la vista bajo barras y teclado | §6.3 |
| 2.5.1 / **2.5.7** Gestos, arrastre | Alternativa de un toque | §9 |
| 2.5.2 Cancelación del puntero | Acción al soltar | §9 |
| 2.5.3 Etiqueta en el nombre | Nombre accesible empieza con el texto visible | §6.1 |
| 2.5.4 Activación por movimiento | No se usa | §9 |
| **2.5.8 Tamaño del objetivo (mínimo)** | 48 dp | §4 |
| 3.1.1 Idioma | `es_CO` | §6.1 |
| 3.2.1 / 3.2.2 Al recibir foco / al introducir datos | Sin cambios de contexto inesperados | — |
| 3.2.3 / 3.2.4 Navegación e identificación consistentes | Misma barra y mismos nombres | navigation.md §4 |
| **3.2.6 Ayuda consistente** | Ayuda/WhatsApp en la misma posición relativa | navigation.md §4; RNF-077 |
| 3.3.1 a 3.3.4 Errores | Mensajes con sugerencia; confirmación en acciones irreversibles | §7 |
| **3.3.7 Entrada redundante** | "Igual a facturación"; prellenado; datos conservados | §7 |
| **3.3.8 Autenticación accesible (mínimo)** | Pegar y gestores permitidos | §7 |
| 4.1.2 Nombre, función, valor | Semántica completa | §6.2 |
| 4.1.3 Mensajes de estado | Regiones vivas | §6.4 |

---

## 11. Checkout externo (RNF-077)

| Aspecto | Tratamiento |
|---|---|
| Control | La app solo abre el navegador seguro; no controla el contenido de WooCommerce/Wompi (EX-02). |
| Prueba | Recorrido completo con TalkBack/VoiceOver y zoom 200 % en staging con Wompi sandbox (H-12). |
| Registro | Hallazgos como riesgo para el equipo web (formularios sin etiqueta, contraste, objetivos). |
| Mitigación en la app | Aviso en línea bajo "Pagar" ("Pagarás en un navegador seguro."); pantalla de espera con "Abrir de nuevo el pago" y "Ya pagué, verificar" operables sin gestos; textos de retorno claros. |

---

## 12. Cómo se verificará (plan; **nada se declara cumplido**)

### 12.1 Pruebas automáticas (en CI y en pruebas de widget)

| Qué | Herramienta / técnica | Cuándo | RNF |
|---|---|---|---|
| Objetivos táctiles | `androidTapTargetGuideline`, `iOSTapTargetGuideline` (`flutter_test`) en cada pantalla crítica | Cada PR | RNF-071 |
| Etiquetas en objetivos | `labeledTapTargetGuideline` | Cada PR | RNF-070 |
| Contraste de texto | `textContrastGuideline` (limitada: no cubre imágenes ni degradados) **más** el script del Anexo A sobre los tokens (falla el PR si un par pasa de "CUMPLE" a "NO CUMPLE") | Cada PR | RNF-069 |
| Semántica | Pruebas de `Semantics` por componente: etiqueta, rol, estado, acciones personalizadas, región viva | Cada PR | RNF-070 |
| Escala de texto | *Golden tests* (p. ej. `alchemist`) a 1,0 / 1,3 / 2,0 en componentes y pantallas críticas; sin desbordes | Cada PR | RNF-068 |
| Movimiento | Prueba con `disableAnimations` activo: sin animaciones | Cada PR | RNF-074 |
| Foco no oculto | Prueba de widget con teclado abierto: el campo enfocado está visible | Cada PR | RNF-075 |
| Escáneres | Accessibility Scanner (Android) y Accessibility Inspector (iOS) sobre capturas de cada pantalla | Cada candidato a versión | RNF-067 |

### 12.2 Pruebas manuales (candidato a versión)

| Prueba | Cómo | Dispositivos (RNF-082) |
|---|---|---|
| **TalkBack** | Completar con pantalla apagada o cubierta: buscar por SKU, ver ficha, añadir al carrito, iniciar sesión, registro, abrir el pago, ver pedido, eliminar cuenta | ≥ 2 Android (gama baja y media) |
| **VoiceOver** | Mismos recorridos | ≥ 2 iPhone (incluido el más antiguo soportado) |
| **Switch Access / Switch Control** | Recorrer y operar los flujos críticos | ≥ 1 por plataforma |
| **Teclado externo** | Tab/flechas/Enter; foco visible y no oculto | ≥ 1 por plataforma |
| **Texto al 200 %** y tamaño de pantalla máximo | Matriz del §5.2; se registran recortes y desbordes | ≥ 1 por plataforma |
| **Movimiento reducido, texto en negrita, alto contraste** | Activar cada preferencia y revisar | ≥ 1 por plataforma |
| **Simulación de daltonismo** | Capturas con filtros de protanopia/deuteranopia/tritanopia | — |
| **Contraste real** | Medir con herramienta independiente (colorímetro de pantalla o *Colour Contrast Analyser*) los pares críticos sobre pantalla real | — |
| **Checkout externo** | Recorrido completo con lector de pantalla y zoom 200 % (EX-02) | ≥ 1 por plataforma |

### 12.3 Pruebas con personas usuarias (VAL-12)

| Aspecto | Propuesta |
|---|---|
| Participantes | Personas usuarias de TalkBack y VoiceOver, de ampliación de texto y con limitación motriz (interruptores o dificultad con gestos finos). Reclutamiento con IPR; **cantidad y perfil por definir** (no se inventan cifras). |
| Tareas | Buscar una referencia, hacer una compra hasta el pago, consultar un pedido, contactar por WhatsApp, calcular BTU. |
| Salida | Hallazgos priorizados por gravedad y criterio WCAG; registro de excepciones con aprobación. |

### 12.4 Criterios de salida (propuestos, alineados con RNF-067)

1. **0 criterios A/AA aplicables en falla** en los flujos críticos del MVP, **o** excepción documentada y aceptada por IPR (EX-01 a EX-04).
2. Todas las pruebas automáticas del §12.1 en verde.
3. Recorridos del §12.2 completados con TalkBack y VoiceOver **sin ayuda visual** por evaluadores (RNF-070).
4. Hallazgos del checkout externo entregados al equipo web (RNF-077).
5. Antes de publicar una declaración de accesibilidad, se ejecuta el plan completo; **hasta entonces la app no se describe como accesible ni como conforme**.

### 12.5 Responsabilidades y cadencia [PROPUESTA]

| Actividad | Responsable | Cuándo |
|---|---|---|
| Revisión de diseño (contraste, color, objetivos) | Diseño UX/UI | Antes de cada entrega de pantallas |
| Pruebas automáticas | Desarrollo | Cada PR |
| Pruebas manuales con lectores de pantalla | QA | Cada candidato a versión |
| Pruebas con personas usuarias | UX con IPR | Antes del piloto |
| Re-evaluación | QA/UX | Cada versión mayor o cambio de paleta |

---

## 13. Limitaciones y riesgos

| Riesgo | Detalle | Mitigación |
|---|---|---|
| Semántica de Flutter y diferencias entre plataformas | El comportamiento de TalkBack y VoiceOver difiere en lectura de números, SKU y regiones vivas | Pruebas manuales en ambas; ajuste de etiquetas (VAL-12) |
| Lectura del SKU y de precios | Los motores de voz pueden leer mal "500-0144" o "$ 1.234.567" | Etiquetas semánticas explícitas; probar |
| Checkout externo | No controlable | EX-02, §11 |
| Colores derivados sin aprobar | Si Marketing los rechaza, cambian pares de contraste | Alternativas del design_system §3.2; el script recalcula |
| Herramientas automáticas | No cubren todo (imágenes, degradados, contexto) | Complemento manual y con usuarios |
| iOS por encima del 200 % | Mejor esfuerzo | EX-03 |
| CAPTCHA en PQRS | Podría vulnerar 3.3.8 | Exigir alternativa accesible (AC-096-6 **[A VALIDAR]**) |
| Contenido HTML de descripciones | Estructura no controlada (tablas, listas) | Saneado y estilos propios; revisar con lector |

---

## 14. Clasificación del contenido de este documento

| Tipo | Dónde |
|---|---|
| **Hechos** | §3 (razones de contraste calculadas), §1.1 (RNF-067, RNF-077), §2 (hallazgos del cálculo y del sitio web) |
| **Supuestos** | Lectura de SKU y precios por los motores de voz; comportamiento del `TextScaler` en la barra inferior |
| **Propuestas** | Etiquetas semánticas, anuncios, EX-01, reglas de reflujo, plan de verificación |
| **Pendientes** | APR-02 (paleta derivada), APR-12 (excepción de escala), VAL-12 (pruebas con usuarios), MED-12 (contraste oficial), DN-11 (orientación) |

---

## Anexo A. Script de contraste

Cálculo reproducible de las razones de contraste de la paleta (Python 3, solo biblioteca estándar). Se ejecuta con `python -I contraste.py`. Con `--derivar` imprime los colores derivados. Los pares marcan "NO CUMPLE" cuando no alcanzan el umbral de su tipo (texto 4,5:1; componente/gráfico 3,0:1).

```python
#!/usr/bin/env python3
"""Contraste WCAG 2.x (luminancia relativa) para el Design System de la app IPR.
Uso: python contraste.py            -> imprime tablas Markdown
     python contraste.py --derivar  -> imprime la derivacion de verde y rojo accesibles
Solo usa la biblioteca estandar. Umbrales: texto 4.5, texto grande 3.0, componente/grafico 3.0."""
import colorsys
import sys


def lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def lum(h):
    h = h.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def hexof(r, g, b):
    return '#%02X%02X%02X' % (round(r * 255), round(g * 255), round(b * 255))


def hsl(h):
    h = h.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    return hh, ss, ll


def from_hsl(hh, ss, ll):
    r, g, b = colorsys.hls_to_rgb(hh, ll, ss)
    return hexof(r, g, b)


def derivar(base, fondos, minimo=5.0):
    """Baja la luminosidad HSL de `base` (mismo tono y saturacion) hasta cumplir `minimo` contra todos los `fondos`."""
    hh, ss, ll = hsl(base)
    l = ll
    while l > 0:
        c = from_hsl(hh, ss, l)
        if all(ratio(c, f) >= minimo for f in fondos):
            return c
        l -= 0.005
    return None


def tinte(base, l=0.93):
    hh, ss, _ = hsl(base)
    return from_hsl(hh, min(ss, 0.6), l)


# --------------------------------------------------------------------------
# Colores. obs = observado en el sitio web (globals.css o docs §17); der = derivado (PROPUESTA)
# --------------------------------------------------------------------------
BLANCO = '#FFFFFF'
TEXTO = '#151A21'          # obs --foreground
GRIS_TXT = '#75777B'       # obs --muted-foreground
MUTED = '#F3F5F7'          # obs --muted
TINTE = '#EAF4F9'          # obs --secondary
TINTE2 = '#E8F3FA'         # obs --accent
AZUL = '#07628E'           # marca
AZUL_OSC = '#0A3651'       # marca
AZUL_PRES = '#0B4970'      # marca
SEC_FG = '#055177'         # obs --secondary-foreground
VERDE = '#5BA628'          # marca
VERDE_WEB = '#99C120'      # obs globals.css --color-green-brand (382 U)
ROJO = '#D64045'           # obs --destructive
BORDE = '#E2E8F0'          # obs --border
INPUT = '#CBD5E1'          # obs --input
GRAY500 = '#6B7280'        # clase text-gray-500 en ProductCard
AMBAR600 = '#D97706'       # clase text-amber-600 (STOCK_LABELS onbackorder)
ROJO600 = '#DC2626'        # clase bg-red-600 (badge Oferta)

# Oscuro (obs en .dark de globals.css)
D_BG = '#0A1320'; D_CARD = '#0F1A26'; D_TEXT = '#EAF3F9'; D_PRIM = '#439BE4'; D_ONPRIM = '#06233F'
D_SEC = '#122A3A'; D_ONSEC = '#CFE6F5'; D_MUTED_FG = '#9BACBD'; D_ACC = '#163D57'; D_DEST = '#F2797D'
D_BORDER = '#1D3345'; D_INPUT = '#2A4359'


def tablas():
    verde_acc = derivar(VERDE, [BLANCO, MUTED, TINTE, tinte(VERDE, 0.93)])
    rojo_acc = derivar(ROJO, [BLANCO, MUTED, tinte(ROJO, 0.95)])
    gris_acc = derivar(GRIS_TXT, [BLANCO, MUTED, TINTE])
    verde_tinte = tinte(VERDE, 0.93)
    rojo_tinte = tinte(ROJO, 0.95)
    verde_acc_t = derivar(VERDE, [verde_tinte, BLANCO, MUTED, TINTE])
    rojo_acc_t = derivar(ROJO, [rojo_tinte, BLANCO, MUTED])
    P = []  # (id, descripcion, fg, bg, tipo)
    T, G, U = 'texto', 'grande', 'ui'
    # --- Claro: texto
    P += [
        ('L01', 'Texto principal sobre fondo', TEXTO, BLANCO, T),
        ('L02', 'Texto principal sobre superficie atenuada', TEXTO, MUTED, T),
        ('L03', 'Texto principal sobre tinte azul', TEXTO, TINTE, T),
        ('L04', 'Texto secundario observado (web) sobre fondo', GRIS_TXT, BLANCO, T),
        ('L05', 'Texto secundario observado (web) sobre atenuada', GRIS_TXT, MUTED, T),
        ('L06', 'Texto secundario observado (web) sobre tinte azul', GRIS_TXT, TINTE, T),
        ('L07', 'Texto secundario derivado (PROPUESTA) sobre fondo', gris_acc, BLANCO, T),
        ('L08', 'Texto secundario derivado (PROPUESTA) sobre atenuada', gris_acc, MUTED, T),
        ('L09', 'Texto secundario derivado (PROPUESTA) sobre tinte azul', gris_acc, TINTE, T),
        ('L10', 'Azul primario como texto/enlace sobre fondo', AZUL, BLANCO, T),
        ('L11', 'Azul primario como texto sobre superficie atenuada', AZUL, MUTED, T),
        ('L12', 'Azul primario como texto sobre tinte azul', AZUL, TINTE, T),
        ('L13', 'Azul oscuro (titulos) sobre fondo', AZUL_OSC, BLANCO, T),
        ('L14', 'Azul presionado (#0b4970) como texto sobre fondo', AZUL_PRES, BLANCO, T),
        ('L15', 'Texto de contenedor secundario (#055177) sobre tinte azul', SEC_FG, TINTE, T),
        ('L16', 'Blanco sobre azul primario (boton relleno)', BLANCO, AZUL, T),
        ('L17', 'Blanco sobre azul presionado (boton presionado)', BLANCO, AZUL_PRES, T),
        ('L18', 'Blanco sobre azul oscuro (barra superior / chip activo)', BLANCO, AZUL_OSC, T),
        ('L19', 'VERDE de marca #5ba628 como texto normal sobre fondo', VERDE, BLANCO, T),
        ('L20', 'Blanco sobre VERDE de marca (boton/insignia)', BLANCO, VERDE, T),
        ('L21', 'Texto principal #151a21 sobre VERDE de marca', TEXTO, VERDE, T),
        ('L22', 'Azul oscuro #0a3651 sobre VERDE de marca', AZUL_OSC, VERDE, T),
        ('L23', 'Rojo observado #d64045 como texto sobre fondo', ROJO, BLANCO, T),
        ('L24', 'Rojo observado #d64045 como texto sobre atenuada', ROJO, MUTED, T),
        ('L25', 'Blanco sobre rojo observado #d64045', BLANCO, ROJO, T),
        ('L26', f'Verde derivado {verde_acc} (PROPUESTA) sobre fondo', verde_acc, BLANCO, T),
        ('L27', f'Verde derivado {verde_acc} (PROPUESTA) sobre atenuada', verde_acc, MUTED, T),
        ('L28', f'Verde derivado {verde_acc} (PROPUESTA) sobre tinte azul', verde_acc, TINTE, T),
        ('L29', f'Blanco sobre verde derivado {verde_acc} (PROPUESTA)', BLANCO, verde_acc, T),
        ('L30', f'Verde derivado {verde_acc_t} sobre tinte verde {verde_tinte} (PROPUESTA)', verde_acc_t, verde_tinte, T),
        ('L31', f'Rojo derivado {rojo_acc} (PROPUESTA) sobre fondo', rojo_acc, BLANCO, T),
        ('L32', f'Rojo derivado {rojo_acc} (PROPUESTA) sobre atenuada', rojo_acc, MUTED, T),
        ('L33', f'Blanco sobre rojo derivado {rojo_acc} (PROPUESTA)', BLANCO, rojo_acc, T),
        ('L34', f'Rojo derivado {rojo_acc_t} sobre tinte rojo {rojo_tinte} (PROPUESTA)', rojo_acc_t, rojo_tinte, T),
    ]
    # --- Claro: componentes y graficos (>= 3:1)
    P += [
        ('N01', 'VERDE de marca como icono/indicador sobre fondo', VERDE, BLANCO, U),
        ('N02', 'VERDE de marca como icono sobre tinte azul', VERDE, TINTE, U),
        ('N03', 'Azul primario como icono/foco sobre fondo', AZUL, BLANCO, U),
        ('N04', 'Anillo de foco azul primario sobre tinte azul', AZUL, TINTE, U),
        ('N05', 'Borde de campo observado (#cbd5e1) sobre fondo', INPUT, BLANCO, U),
        ('N06', 'Borde decorativo observado (#e2e8f0) sobre fondo', BORDE, BLANCO, U),
        ('N07', 'Borde de campo y de casilla = gris observado (#75777b) sobre atenuada', GRIS_TXT, MUTED, U),
        ('N08', 'Borde de campo y de casilla = gris observado (#75777b) sobre tinte azul', GRIS_TXT, TINTE, U),
        ('N09', 'Icono gris secundario observado (#75777b) sobre fondo', GRIS_TXT, BLANCO, U),
        ('N10', 'Azul primario como borde de boton contorno sobre fondo', AZUL, BLANCO, U),
        ('N11', 'Superficie atenuada #f3f5f7 contra fondo (limite de tarjeta sin borde)', MUTED, BLANCO, U),
    ]
    # --- Componentes (combinaciones concretas del catalogo de componentes)
    P += [
        ('C01', 'Boton deshabilitado: texto secundario derivado sobre #e2e8f0 (informativo; WCAG exime los inactivos)', gris_acc, BORDE, T),
        ('C02', 'Snackbar: texto blanco sobre #151a21', BLANCO, TEXTO, T),
        ('C03', 'Snackbar: accion #439be4 sobre #151a21', D_PRIM, TEXTO, T),
        ('C04', f'Insignia "En stock": texto #151a21 sobre tinte verde {verde_tinte}', TEXTO, verde_tinte, T),
        ('C05', f'Insignia "En stock": icono verde derivado {verde_acc} sobre tinte verde', verde_acc, verde_tinte, U),
        ('C06', f'Insignia "Agotado": texto #151a21 sobre tinte rojo {rojo_tinte}', TEXTO, rojo_tinte, T),
        ('C07', f'Insignia "Agotado": icono rojo derivado {rojo_acc} sobre tinte rojo', rojo_acc, rojo_tinte, U),
        ('C08', 'Insignia "Oferta" con alternativa previa a la aprobacion: texto #151a21 sobre VERDE #5ba628', TEXTO, VERDE, T),
        ('C09', 'Chip de filtro sin seleccionar: texto #151a21 sobre fondo y borde #75777b', TEXTO, BLANCO, T),
        ('C10', 'Precio tachado (precio regular) en texto secundario derivado sobre fondo', gris_acc, BLANCO, T),
    ]
    P += [
        ('N12', 'Anillo de foco #0a3651 (claro) sobre fondo', AZUL_OSC, BLANCO, U),
        ('N13', 'Anillo de foco #0a3651 (claro) sobre tinte azul', AZUL_OSC, TINTE, U),
        ('N14', 'Anillo de foco #0a3651 (claro) sobre superficie atenuada', AZUL_OSC, MUTED, U),
        ('N15', 'Icono de barra inferior sin seleccionar (#66686b derivado) sobre fondo', gris_acc, BLANCO, U),
    ]
    # --- Oscuro
    P += [
        ('D01', 'Texto principal oscuro sobre fondo', D_TEXT, D_BG, T),
        ('D02', 'Texto principal oscuro sobre tarjeta', D_TEXT, D_CARD, T),
        ('D03', 'Texto secundario oscuro sobre fondo', D_MUTED_FG, D_BG, T),
        ('D04', 'Texto secundario oscuro sobre tarjeta', D_MUTED_FG, D_CARD, T),
        ('D05', 'Texto secundario oscuro sobre contenedor secundario', D_MUTED_FG, D_SEC, T),
        ('D06', 'Azul primario oscuro #439be4 como texto sobre fondo', D_PRIM, D_BG, T),
        ('D07', 'Azul primario oscuro #439be4 como texto sobre tarjeta', D_PRIM, D_CARD, T),
        ('D08', 'Texto #06233f sobre azul primario oscuro (boton)', D_ONPRIM, D_PRIM, T),
        ('D09', 'Texto de contenedor secundario oscuro sobre #122a3a', D_ONSEC, D_SEC, T),
        ('D10', 'Texto principal oscuro sobre acento #163d57', D_TEXT, D_ACC, T),
        ('D11', 'Rojo oscuro #f2797d como texto sobre fondo', D_DEST, D_BG, T),
        ('D12', 'Rojo oscuro #f2797d como texto sobre tarjeta', D_DEST, D_CARD, T),
        ('D13', 'VERDE de marca como texto sobre fondo oscuro', VERDE, D_BG, T),
        ('D14', 'VERDE de marca como texto sobre tarjeta oscura', VERDE, D_CARD, T),
        ('D15', 'Azul primario CLARO #07628e como texto sobre fondo oscuro (NO usar)', AZUL, D_BG, T),
        ('D16', 'Azul oscuro #0a3651 como texto sobre fondo oscuro (NO usar)', AZUL_OSC, D_BG, T),
        ('D17', 'Borde de campo observado oscuro (#2a4359) sobre fondo', D_INPUT, D_BG, U),
        ('D18', 'Borde decorativo observado oscuro (#1d3345) sobre fondo', D_BORDER, D_BG, U),
        ('D19', 'Anillo de foco #439be4 sobre fondo oscuro', D_PRIM, D_BG, U),
        ('D20', 'VERDE de marca como icono sobre fondo oscuro', VERDE, D_BG, U),
        ('D20b', 'Anillo de foco oscuro #eaf3f9 sobre fondo oscuro', D_TEXT, D_BG, U),
    ]
    derivado_borde_oscuro = derivar_claro('#2A4359', [D_BG, D_CARD], 3.0)
    P += [
        ('D21', f'Borde de campo oscuro derivado {derivado_borde_oscuro} (PROPUESTA) sobre fondo', derivado_borde_oscuro, D_BG, U),
        ('D22', f'Borde de campo oscuro derivado {derivado_borde_oscuro} (PROPUESTA) sobre tarjeta', derivado_borde_oscuro, D_CARD, U),
    ]
    verde_t_osc = tinte(VERDE, 0.16)
    rojo_t_osc = tinte(ROJO, 0.19)
    P += [
        ('D23', f'Insignia oscura "En stock": texto #eaf3f9 sobre tinte verde oscuro {verde_t_osc} (PROPUESTA)', D_TEXT, verde_t_osc, T),
        ('D24', f'Insignia oscura "En stock": icono verde de marca sobre {verde_t_osc}', VERDE, verde_t_osc, U),
        ('D25', f'Insignia oscura "Agotado": texto #eaf3f9 sobre tinte rojo oscuro {rojo_t_osc} (PROPUESTA)', D_TEXT, rojo_t_osc, T),
        ('D26', f'Insignia oscura "Agotado": icono #f2797d sobre {rojo_t_osc}', D_DEST, rojo_t_osc, U),
        ('D27', 'Texto #0a1320 sobre rojo oscuro #f2797d (boton destructivo oscuro)', D_BG, D_DEST, T),
        ('D28', 'Texto #0a1320 sobre VERDE de marca (relleno en oscuro)', D_BG, VERDE, T),
    ]
    # --- Hallazgos del sitio web actual (referencia, no se replican)
    P += [
        ('W01', 'WEB: "En stock" (text-green-brand #99c120) sobre blanco', VERDE_WEB, BLANCO, T),
        ('W02', 'WEB: insignia "Oferta" (texto blanco sobre #99c120)', BLANCO, VERDE_WEB, T),
        ('W03', 'WEB: "Disponible bajo pedido" (text-amber-600 #d97706) sobre blanco', AMBAR600, BLANCO, T),
        ('W04', 'WEB: insignia Oferta de tarjeta (blanco sobre #dc2626)', BLANCO, ROJO600, T),
        ('W05', 'WEB: "IVA incluido" (text-gray-500 #6b7280) sobre blanco, 11 px', GRAY500, BLANCO, T),
        ('W06', 'WEB: gris #75777b (muted-foreground) sobre #f3f5f7', GRIS_TXT, MUTED, T),
    ]
    meta = dict(verde_acc=verde_acc, rojo_acc=rojo_acc, gris_acc=gris_acc, verde_tinte=verde_tinte,
                rojo_tinte=rojo_tinte, verde_t_osc=verde_t_osc, rojo_t_osc=rojo_t_osc, verde_acc_t=verde_acc_t, rojo_acc_t=rojo_acc_t,
                borde_oscuro=derivado_borde_oscuro)
    return P, meta


def derivar_claro(base, fondos, minimo):
    """Sube la luminosidad HSL de `base` hasta cumplir `minimo` contra todos los `fondos` oscuros."""
    hh, ss, ll = hsl(base)
    l = ll
    while l < 1:
        c = from_hsl(hh, ss, l)
        if all(ratio(c, f) >= minimo for f in fondos):
            return c
        l += 0.005
    return None


def main():
    P, meta = tablas()
    umbral = {'texto': 4.5, 'grande': 3.0, 'ui': 3.0}
    print('| ID | Combinacion | Texto/primer plano | Fondo | Razon | Minimo | Resultado |')
    print('|---|---|---|---|---|---|---|')
    n_fail = 0
    for i, d, fg, bg, k in P:
        r = ratio(fg, bg)
        ok = r >= umbral[k]
        n_fail += (not ok)
        print(f'| {i} | {d} | `{fg}` | `{bg}` | {r:.2f}:1 | {umbral[k]}:1 | {"CUMPLE" if ok else "NO CUMPLE"} |')
    print()
    print('Derivados:', meta)
    print('Total combinaciones:', len(P), ' no cumplen:', n_fail)


if __name__ == '__main__':
    if '--derivar' in sys.argv:
        _, m = tablas()
        for k, v in m.items():
            print(k, v)
    else:
        main()
```

### Resultado de la ejecución (2026-11-18)

IDs: `L` = tema claro (texto), `N` = componentes y gráficos claros, `C` = componentes concretos, `D` = tema oscuro, `W` = hallazgos del sitio web actual.

| ID | Combinacion | Texto/primer plano | Fondo | Razon | Minimo | Resultado |
|---|---|---|---|---|---|---|
| L01 | Texto principal sobre fondo | `#151A21` | `#FFFFFF` | 17.48:1 | 4.5:1 | CUMPLE |
| L02 | Texto principal sobre superficie atenuada | `#151A21` | `#F3F5F7` | 15.99:1 | 4.5:1 | CUMPLE |
| L03 | Texto principal sobre tinte azul | `#151A21` | `#EAF4F9` | 15.65:1 | 4.5:1 | CUMPLE |
| L04 | Texto secundario observado (web) sobre fondo | `#75777B` | `#FFFFFF` | 4.49:1 | 4.5:1 | NO CUMPLE |
| L05 | Texto secundario observado (web) sobre atenuada | `#75777B` | `#F3F5F7` | 4.10:1 | 4.5:1 | NO CUMPLE |
| L06 | Texto secundario observado (web) sobre tinte azul | `#75777B` | `#EAF4F9` | 4.02:1 | 4.5:1 | NO CUMPLE |
| L07 | Texto secundario derivado (PROPUESTA) sobre fondo | `#66686B` | `#FFFFFF` | 5.59:1 | 4.5:1 | CUMPLE |
| L08 | Texto secundario derivado (PROPUESTA) sobre atenuada | `#66686B` | `#F3F5F7` | 5.11:1 | 4.5:1 | CUMPLE |
| L09 | Texto secundario derivado (PROPUESTA) sobre tinte azul | `#66686B` | `#EAF4F9` | 5.01:1 | 4.5:1 | CUMPLE |
| L10 | Azul primario como texto/enlace sobre fondo | `#07628E` | `#FFFFFF` | 6.67:1 | 4.5:1 | CUMPLE |
| L11 | Azul primario como texto sobre superficie atenuada | `#07628E` | `#F3F5F7` | 6.11:1 | 4.5:1 | CUMPLE |
| L12 | Azul primario como texto sobre tinte azul | `#07628E` | `#EAF4F9` | 5.98:1 | 4.5:1 | CUMPLE |
| L13 | Azul oscuro (titulos) sobre fondo | `#0A3651` | `#FFFFFF` | 12.66:1 | 4.5:1 | CUMPLE |
| L14 | Azul presionado (#0b4970) como texto sobre fondo | `#0B4970` | `#FFFFFF` | 9.54:1 | 4.5:1 | CUMPLE |
| L15 | Texto de contenedor secundario (#055177) sobre tinte azul | `#055177` | `#EAF4F9` | 7.68:1 | 4.5:1 | CUMPLE |
| L16 | Blanco sobre azul primario (boton relleno) | `#FFFFFF` | `#07628E` | 6.67:1 | 4.5:1 | CUMPLE |
| L17 | Blanco sobre azul presionado (boton presionado) | `#FFFFFF` | `#0B4970` | 9.54:1 | 4.5:1 | CUMPLE |
| L18 | Blanco sobre azul oscuro (barra superior / chip activo) | `#FFFFFF` | `#0A3651` | 12.66:1 | 4.5:1 | CUMPLE |
| L19 | VERDE de marca #5ba628 como texto normal sobre fondo | `#5BA628` | `#FFFFFF` | 3.03:1 | 4.5:1 | NO CUMPLE |
| L20 | Blanco sobre VERDE de marca (boton/insignia) | `#FFFFFF` | `#5BA628` | 3.03:1 | 4.5:1 | NO CUMPLE |
| L21 | Texto principal #151a21 sobre VERDE de marca | `#151A21` | `#5BA628` | 5.77:1 | 4.5:1 | CUMPLE |
| L22 | Azul oscuro #0a3651 sobre VERDE de marca | `#0A3651` | `#5BA628` | 4.18:1 | 4.5:1 | NO CUMPLE |
| L23 | Rojo observado #d64045 como texto sobre fondo | `#D64045` | `#FFFFFF` | 4.49:1 | 4.5:1 | NO CUMPLE |
| L24 | Rojo observado #d64045 como texto sobre atenuada | `#D64045` | `#F3F5F7` | 4.11:1 | 4.5:1 | NO CUMPLE |
| L25 | Blanco sobre rojo observado #d64045 | `#FFFFFF` | `#D64045` | 4.49:1 | 4.5:1 | NO CUMPLE |
| L26 | Verde derivado #3F731C (PROPUESTA) sobre fondo | `#3F731C` | `#FFFFFF` | 5.71:1 | 4.5:1 | CUMPLE |
| L27 | Verde derivado #3F731C (PROPUESTA) sobre atenuada | `#3F731C` | `#F3F5F7` | 5.22:1 | 4.5:1 | CUMPLE |
| L28 | Verde derivado #3F731C (PROPUESTA) sobre tinte azul | `#3F731C` | `#EAF4F9` | 5.11:1 | 4.5:1 | CUMPLE |
| L29 | Blanco sobre verde derivado #3F731C (PROPUESTA) | `#FFFFFF` | `#3F731C` | 5.71:1 | 4.5:1 | CUMPLE |
| L30 | Verde derivado #3F731C sobre tinte verde #EBF8E2 (PROPUESTA) | `#3F731C` | `#EBF8E2` | 5.18:1 | 4.5:1 | CUMPLE |
| L31 | Rojo derivado #C1292F (PROPUESTA) sobre fondo | `#C1292F` | `#FFFFFF` | 5.79:1 | 4.5:1 | CUMPLE |
| L32 | Rojo derivado #C1292F (PROPUESTA) sobre atenuada | `#C1292F` | `#F3F5F7` | 5.30:1 | 4.5:1 | CUMPLE |
| L33 | Blanco sobre rojo derivado #C1292F (PROPUESTA) | `#FFFFFF` | `#C1292F` | 5.79:1 | 4.5:1 | CUMPLE |
| L34 | Rojo derivado #C1292F sobre tinte rojo #FAEBEB (PROPUESTA) | `#C1292F` | `#FAEBEB` | 5.01:1 | 4.5:1 | CUMPLE |
| N01 | VERDE de marca como icono/indicador sobre fondo | `#5BA628` | `#FFFFFF` | 3.03:1 | 3.0:1 | CUMPLE |
| N02 | VERDE de marca como icono sobre tinte azul | `#5BA628` | `#EAF4F9` | 2.71:1 | 3.0:1 | NO CUMPLE |
| N03 | Azul primario como icono/foco sobre fondo | `#07628E` | `#FFFFFF` | 6.67:1 | 3.0:1 | CUMPLE |
| N04 | Anillo de foco azul primario sobre tinte azul | `#07628E` | `#EAF4F9` | 5.98:1 | 3.0:1 | CUMPLE |
| N05 | Borde de campo observado (#cbd5e1) sobre fondo | `#CBD5E1` | `#FFFFFF` | 1.48:1 | 3.0:1 | NO CUMPLE |
| N06 | Borde decorativo observado (#e2e8f0) sobre fondo | `#E2E8F0` | `#FFFFFF` | 1.23:1 | 3.0:1 | NO CUMPLE |
| N07 | Borde de campo y de casilla = gris observado (#75777b) sobre atenuada | `#75777B` | `#F3F5F7` | 4.10:1 | 3.0:1 | CUMPLE |
| N08 | Borde de campo y de casilla = gris observado (#75777b) sobre tinte azul | `#75777B` | `#EAF4F9` | 4.02:1 | 3.0:1 | CUMPLE |
| N09 | Icono gris secundario observado (#75777b) sobre fondo | `#75777B` | `#FFFFFF` | 4.49:1 | 3.0:1 | CUMPLE |
| N10 | Azul primario como borde de boton contorno sobre fondo | `#07628E` | `#FFFFFF` | 6.67:1 | 3.0:1 | CUMPLE |
| N11 | Superficie atenuada #f3f5f7 contra fondo (limite de tarjeta sin borde) | `#F3F5F7` | `#FFFFFF` | 1.09:1 | 3.0:1 | NO CUMPLE |
| C01 | Boton deshabilitado: texto secundario derivado sobre #e2e8f0 (informativo; WCAG exime los inactivos) | `#66686B` | `#E2E8F0` | 4.53:1 | 4.5:1 | CUMPLE |
| C02 | Snackbar: texto blanco sobre #151a21 | `#FFFFFF` | `#151A21` | 17.48:1 | 4.5:1 | CUMPLE |
| C03 | Snackbar: accion #439be4 sobre #151a21 | `#439BE4` | `#151A21` | 5.87:1 | 4.5:1 | CUMPLE |
| C04 | Insignia "En stock": texto #151a21 sobre tinte verde #EBF8E2 | `#151A21` | `#EBF8E2` | 15.86:1 | 4.5:1 | CUMPLE |
| C05 | Insignia "En stock": icono verde derivado #3F731C sobre tinte verde | `#3F731C` | `#EBF8E2` | 5.18:1 | 3.0:1 | CUMPLE |
| C06 | Insignia "Agotado": texto #151a21 sobre tinte rojo #FAEBEB | `#151A21` | `#FAEBEB` | 15.10:1 | 4.5:1 | CUMPLE |
| C07 | Insignia "Agotado": icono rojo derivado #C1292F sobre tinte rojo | `#C1292F` | `#FAEBEB` | 5.01:1 | 3.0:1 | CUMPLE |
| C08 | Insignia "Oferta" con alternativa previa a la aprobacion: texto #151a21 sobre VERDE #5ba628 | `#151A21` | `#5BA628` | 5.77:1 | 4.5:1 | CUMPLE |
| C09 | Chip de filtro sin seleccionar: texto #151a21 sobre fondo y borde #75777b | `#151A21` | `#FFFFFF` | 17.48:1 | 4.5:1 | CUMPLE |
| C10 | Precio tachado (precio regular) en texto secundario derivado sobre fondo | `#66686B` | `#FFFFFF` | 5.59:1 | 4.5:1 | CUMPLE |
| N12 | Anillo de foco #0a3651 (claro) sobre fondo | `#0A3651` | `#FFFFFF` | 12.66:1 | 3.0:1 | CUMPLE |
| N13 | Anillo de foco #0a3651 (claro) sobre tinte azul | `#0A3651` | `#EAF4F9` | 11.33:1 | 3.0:1 | CUMPLE |
| N14 | Anillo de foco #0a3651 (claro) sobre superficie atenuada | `#0A3651` | `#F3F5F7` | 11.58:1 | 3.0:1 | CUMPLE |
| N15 | Icono de barra inferior sin seleccionar (#66686b derivado) sobre fondo | `#66686B` | `#FFFFFF` | 5.59:1 | 3.0:1 | CUMPLE |
| D01 | Texto principal oscuro sobre fondo | `#EAF3F9` | `#0A1320` | 16.58:1 | 4.5:1 | CUMPLE |
| D02 | Texto principal oscuro sobre tarjeta | `#EAF3F9` | `#0F1A26` | 15.62:1 | 4.5:1 | CUMPLE |
| D03 | Texto secundario oscuro sobre fondo | `#9BACBD` | `#0A1320` | 8.01:1 | 4.5:1 | CUMPLE |
| D04 | Texto secundario oscuro sobre tarjeta | `#9BACBD` | `#0F1A26` | 7.55:1 | 4.5:1 | CUMPLE |
| D05 | Texto secundario oscuro sobre contenedor secundario | `#9BACBD` | `#122A3A` | 6.37:1 | 4.5:1 | CUMPLE |
| D06 | Azul primario oscuro #439be4 como texto sobre fondo | `#439BE4` | `#0A1320` | 6.25:1 | 4.5:1 | CUMPLE |
| D07 | Azul primario oscuro #439be4 como texto sobre tarjeta | `#439BE4` | `#0F1A26` | 5.89:1 | 4.5:1 | CUMPLE |
| D08 | Texto #06233f sobre azul primario oscuro (boton) | `#06233F` | `#439BE4` | 5.34:1 | 4.5:1 | CUMPLE |
| D09 | Texto de contenedor secundario oscuro sobre #122a3a | `#CFE6F5` | `#122A3A` | 11.49:1 | 4.5:1 | CUMPLE |
| D10 | Texto principal oscuro sobre acento #163d57 | `#EAF3F9` | `#163D57` | 10.16:1 | 4.5:1 | CUMPLE |
| D11 | Rojo oscuro #f2797d como texto sobre fondo | `#F2797D` | `#0A1320` | 6.93:1 | 4.5:1 | CUMPLE |
| D12 | Rojo oscuro #f2797d como texto sobre tarjeta | `#F2797D` | `#0F1A26` | 6.53:1 | 4.5:1 | CUMPLE |
| D13 | VERDE de marca como texto sobre fondo oscuro | `#5BA628` | `#0A1320` | 6.15:1 | 4.5:1 | CUMPLE |
| D14 | VERDE de marca como texto sobre tarjeta oscura | `#5BA628` | `#0F1A26` | 5.79:1 | 4.5:1 | CUMPLE |
| D15 | Azul primario CLARO #07628e como texto sobre fondo oscuro (NO usar) | `#07628E` | `#0A1320` | 2.79:1 | 4.5:1 | NO CUMPLE |
| D16 | Azul oscuro #0a3651 como texto sobre fondo oscuro (NO usar) | `#0A3651` | `#0A1320` | 1.47:1 | 4.5:1 | NO CUMPLE |
| D17 | Borde de campo observado oscuro (#2a4359) sobre fondo | `#2A4359` | `#0A1320` | 1.82:1 | 3.0:1 | NO CUMPLE |
| D18 | Borde decorativo observado oscuro (#1d3345) sobre fondo | `#1D3345` | `#0A1320` | 1.43:1 | 3.0:1 | NO CUMPLE |
| D19 | Anillo de foco #439be4 sobre fondo oscuro | `#439BE4` | `#0A1320` | 6.25:1 | 3.0:1 | CUMPLE |
| D20 | VERDE de marca como icono sobre fondo oscuro | `#5BA628` | `#0A1320` | 6.15:1 | 3.0:1 | CUMPLE |
| D20b | Anillo de foco oscuro #eaf3f9 sobre fondo oscuro | `#EAF3F9` | `#0A1320` | 16.58:1 | 3.0:1 | CUMPLE |
| D21 | Borde de campo oscuro derivado #42698B (PROPUESTA) sobre fondo | `#42698B` | `#0A1320` | 3.22:1 | 3.0:1 | CUMPLE |
| D22 | Borde de campo oscuro derivado #42698B (PROPUESTA) sobre tarjeta | `#42698B` | `#0F1A26` | 3.03:1 | 3.0:1 | CUMPLE |
| D23 | Insignia oscura "En stock": texto #eaf3f9 sobre tinte verde oscuro #244110 (PROPUESTA) | `#EAF3F9` | `#244110` | 10.16:1 | 4.5:1 | CUMPLE |
| D24 | Insignia oscura "En stock": icono verde de marca sobre #244110 | `#5BA628` | `#244110` | 3.77:1 | 3.0:1 | CUMPLE |
| D25 | Insignia oscura "Agotado": texto #eaf3f9 sobre tinte rojo oscuro #4E1315 (PROPUESTA) | `#EAF3F9` | `#4E1315` | 13.09:1 | 4.5:1 | CUMPLE |
| D26 | Insignia oscura "Agotado": icono #f2797d sobre #4E1315 | `#F2797D` | `#4E1315` | 5.47:1 | 3.0:1 | CUMPLE |
| D27 | Texto #0a1320 sobre rojo oscuro #f2797d (boton destructivo oscuro) | `#0A1320` | `#F2797D` | 6.93:1 | 4.5:1 | CUMPLE |
| D28 | Texto #0a1320 sobre VERDE de marca (relleno en oscuro) | `#0A1320` | `#5BA628` | 6.15:1 | 4.5:1 | CUMPLE |
| W01 | WEB: "En stock" (text-green-brand #99c120) sobre blanco | `#99C120` | `#FFFFFF` | 2.10:1 | 4.5:1 | NO CUMPLE |
| W02 | WEB: insignia "Oferta" (texto blanco sobre #99c120) | `#FFFFFF` | `#99C120` | 2.10:1 | 4.5:1 | NO CUMPLE |
| W03 | WEB: "Disponible bajo pedido" (text-amber-600 #d97706) sobre blanco | `#D97706` | `#FFFFFF` | 3.19:1 | 4.5:1 | NO CUMPLE |
| W04 | WEB: insignia Oferta de tarjeta (blanco sobre #dc2626) | `#FFFFFF` | `#DC2626` | 4.83:1 | 4.5:1 | CUMPLE |
| W05 | WEB: "IVA incluido" (text-gray-500 #6b7280) sobre blanco, 11 px | `#6B7280` | `#FFFFFF` | 4.83:1 | 4.5:1 | CUMPLE |
| W06 | WEB: gris #75777b (muted-foreground) sobre #f3f5f7 | `#75777B` | `#F3F5F7` | 4.10:1 | 4.5:1 | NO CUMPLE |

**Total: 94 combinaciones; 21 no cumplen.**

Colores derivados calculados (PROPUESTA A APROBAR por marketing): `{'verde_acc': '#3F731C', 'rojo_acc': '#C1292F', 'gris_acc': '#66686B', 'verde_tinte': '#EBF8E2', 'rojo_tinte': '#FAEBEB', 'verde_t_osc': '#244110', 'rojo_t_osc': '#4E1315', 'verde_acc_t': '#3F731C', 'rojo_acc_t': '#C1292F', 'borde_oscuro': '#42698B'}`

## Anexo B. Procedencia de los colores del script

| Color | Procedencia |
|---|---|
| `#0A3651`, `#07628E`, `#0B4970`, `#5BA628` | Marca (`docs/documentacion-proyecto.md` §17) |
| `#151A21`, `#F3F5F7`, `#EAF4F9`, `#E8F3FA`, `#055177`, `#75777B`, `#D64045`, `#E2E8F0`, `#CBD5E1` | Tokens del tema claro de `globals.css` |
| `#0A1320`, `#0F1A26`, `#EAF3F9`, `#439BE4`, `#06233F`, `#122A3A`, `#CFE6F5`, `#9BACBD`, `#163D57`, `#F2797D`, `#1D3345`, `#2A4359` | Tokens del tema oscuro de `globals.css` |
| `#99C120` | `--color-green-brand` de `globals.css` (verde lima 382 U); solo como referencia de hallazgo |
| `#6B7280`, `#D97706`, `#DC2626` | Clases `text-gray-500`, `text-amber-600` y `bg-red-600` de Tailwind usadas en `ProductCard.tsx` y `ProductBuyBox.tsx`; solo como hallazgo |
| `#3F731C`, `#C1292F`, `#66686B`, `#EBF8E2`, `#FAEBEB`, `#244110`, `#4E1315`, `#42698B` | **Derivados por cálculo (PROPUESTA A APROBAR por marketing)** |

# M2 — Cuenta y sesión · resultados

Fecha: 2026-11-20 · Rebanada PT-15: registro con aceptación de políticas, login, recuperación,
sesión por dispositivo, cierre de sesión y páginas legales (RF-038..045, 048, 099).

Construida por 2 agentes en paralelo (`authentication`; `profile` + `support`) sobre el núcleo de
sesión de M0 (`core/session`). El orquestador integró rutas y corrió las puertas.

## Evidencia ejecutada (Windows, Flutter 3.50.0)

| Puerta | Resultado |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | 278 archivos, 0 cambios |
| `flutter analyze --fatal-infos` | sin problemas |
| `dart run ci/check_layer_rules.dart` | 0 violaciones (D1–D6) |
| `dart run ci/check_public_config.dart` | OK |
| `dart run ci/check_openapi_fixtures.dart` | OK · 66 fixtures · 44 esquemas |
| `dart run tool/merge_arb.dart --check` | al día · 261 textos |
| `flutter test --coverage` | **1035 pruebas pasan** (0 fallos) |
| `dart run ci/check_coverage.dart` | OK · global 96,8 % · core/session 95,6 % · core/network 98,4 % · shared/formatting 100 % |

Cobertura por módulo (lcov de cada agente): authentication 98,8 % · profile 99,1 % · support 100 %.

> Nota de método: una primera corrida mostró 2 pruebas del router fallando (`pumpAndSettle` sin
> terminar) aunque `check_coverage` dijo OK — **ese verificador no detecta pruebas rotas**. La causa
> era el arnés (`pumpIprApp` no llamaba a `restore()` de la sesión, así que la pestaña Cuenta se
> quedaba en «Cargando»). Corregido imitando a `bootstrap` y repetida la suite completa.

## Qué se construyó

* **authentication**: `LoginScreen`, `RegisterScreen`, `PasswordRecoveryScreen`. Contraseña nunca
  guardada ni impresa; tras 200/201 solo `setSession` persiste (refresh en almacén seguro, access en
  memoria). 401 y 403 `account_locked` muestran el mismo mensaje; error de red ≠ credenciales
  incorrectas; 429 con cuenta regresiva si hay `Retry-After`. Registro bloqueado (falla cerrado) si
  `/config` no trae versiones de términos/política.
* **profile**: `AccountScreen` (invitado / autenticado / sesión terminada / cargando), cierre de
  sesión con un solo disparo aunque se toque dos veces, sin llamar a `/me` ni mostrar datos
  personales.
* **support**: `LegalScreen` accesible sin sesión; documentos desde `/config`, abiertos en el
  navegador seguro solo si pasan la política de URLs; estado «no disponibles» con «Reintentar».
* **core** (orquestador): `RemoteConfig` lee `legal` (versiones y URLs de términos/política, canal de
  derechos, aviso de eliminación). Rutas cableadas y probadas
  (`test/widget/app_router_features_test.dart`).

## Decisiones pendientes que condicionan este código

| Decisión | Tratamiento en M2 |
|---|---|
| H-03 / PA-02 (registro con correo existente: `409` o registro uniforme + verificación) | Un solo punto (`RegisterConflictPolicy`) con aviso neutral que no confirma la cuenta. Cambiará el alcance del registro. |
| H-05 («cerrar todas» también cierra la web) | NO implementado «cerrar en todos los dispositivos». |
| H-07 (carrito al cerrar sesión) | No tocado; el carrito es M3. |
| D-12 (textos y URLs legales) | Nada inventado: todo viene de `/config`; sin documentos, estado explicativo. |

## Hallazgos abiertos

| ID | Hallazgo |
|---|---|
| H2-01 | `ExternalUrlPolicy` no admite `mailto:`: el correo de derechos del titular se copia al portapapeles. Se dejó así a propósito (es un control de seguridad); decidir si se amplía. |
| H2-02 | Los documentos legales alojados fuera del host del flavor no abren (misma raíz que H1-01). Hay que confirmar dónde se publican (D-12) o ampliar la lista en `core`. |
| H2-03 | `api_architecture.md` §403 pide «mensaje genérico de cuenta no disponible» y AC-045-5 pide el mismo 401; la app muestra un único mensaje para ambos. Confirmar con Seguridad. |
| H2-04 | Los dos enlaces de aceptación (términos y política) abren `Routes.legal` sin indicar el documento; si se quiere ir directo a uno, añadir parámetro de ruta. |
| H2-05 | `check_coverage` no falla ante pruebas rotas (solo mide cobertura); en CI sí falla `flutter test`, pero conviene no fiarse del verificador local solo. |
| H2-06 | 429 sin `Retry-After`: el botón sigue habilitado (no se inventó una espera). |
| H2-07 | Pendiente la prueba de que el gestor de contraseñas del SO ofrece guardar la clave, el aviso de revocación pendiente al cerrar sesión sin red (AC-041-6) y AC-099-3: requieren dispositivo/staging. |

## No verificado en esta máquina

Ejecución en dispositivo, integración contra el BFF/WordPress de staging (TC-001..035 E2E,
ST-030..036, ST-100..107), inspección del sistema de archivos tras cerrar sesión (RNF-062), y
comportamiento de Keystore/Keychain real. El backend de M2 (PT-07, PT-09) sigue sin existir
(`x-status: proposed`): todo se probó con `FakeHttpAdapter`.

## Siguiente

M3 (carrito y compra: RF-029, 049..058) es la rebanada de mayor riesgo y depende de decisiones
externas (Wompi D-02, H-10 sin compra de invitado). **Pendiente de tu visto bueno**; no se inicia sin él.

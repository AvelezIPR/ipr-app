# M4 — Perfil, pedidos y eliminación de cuenta · resultados

Fecha: 2026-11-20 · Rebanada `PT-17`: datos de perfil y correo, cambio de contraseña,
direcciones de facturación y envío (Colombia), historial y detalle de pedidos (`orders`),
eliminación de cuenta con confirmación y contraseña actual (`POST /me/deletion` con
`Idempotency-Key`), aviso de retención desde `/config` y canal de derechos del titular
(`RF-104..108`, `RF-110`, `RF-111`; `TC-083..TC-098`).

## Evidencia ejecutada (Windows 11, Flutter 3.50.0 / Dart 3.14)

| Puerta | Resultado |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | **exit 0** · 392 archivos, 0 cambios |
| `flutter analyze --fatal-infos` | **exit 0** · `No issues found!` |
| `dart run ci/check_layer_rules.dart` | **exit 0** · 0 violaciones (D1–D6, features MVP, paquetes prohibidos) |
| `dart run ci/check_public_config.dart` | **exit 0** · OK |
| `dart run ci/check_openapi_fixtures.dart` | **exit 0** · 114 fixtures (23 nuevos de `orders` y `profile`), 44 esquemas |
| `dart run tool/merge_arb.dart --check` | **exit 0** · al día · 495 textos (12 partes) |
| `dart run ci/gen_coverage_helper.dart` | **exit 0** · 271 archivos de `lib/` importados |
| `flutter test --coverage` | **exit 0** · **1939 pruebas pasan**, 0 fallos (confirmado: sin pruebas en error) |
| `dart run ci/check_coverage.dart` | **exit 0** · global **95.6 %** · `core/session` **95.6 %** · `core/network` **98.4 %** · `features/cart/domain` **99.6 %** · `features/checkout/domain` **100.0 %** · `shared/formatting` **100.0 %** |

Cobertura por módulo de M4 (medida sobre `coverage/lcov.info` sin código generado):
* `lib/features/orders`: **93.2 %** (494 / 530 líneas)
* `lib/features/profile`: **89.4 %** (1186 / 1326 líneas)
* Pendiente de código (umbral ≥ 90 % se exigirá en M5): `lib/features/technical_tools/domain`.

## Qué se construyó

* **`orders`** (`lib/features/orders/`):
  * Entidades puras (`OrderSummary`, `OrderPage`, `OrderItem`, `OrderDetail`,
    `OrderPaymentState`) y política aislada `OrderDetailDisplayPolicy`.
  * Datasource y repositorio solo en memoria (`GET /orders` paginado `perPage=10`,
    `GET /orders/{orderId}` por id entero según CR-054, `no-store`, sin caché en disco por
    RNF-062). Validación estricta de importes COP enteros (`Money.tryFromJson`, CR-047)
    dentro de `sendDecoded` para que cualquier dato malformado llegue como `ContractFailure`.
  * `OrdersScreen` y `OrderDetailScreen` envueltas en `SensitiveScreen` (SC-035): estado
    vacío con acción al catálogo (AC-107-3), paginación sin duplicados conservando páginas
    previas ante error en página ≥ 2, distinción `404 NotFound` («Pedido no encontrado»
    sin «Reintentar») vs `503`/`NoConnection` (con «Reintentar»), totales del servidor sin
    recalcular (AC-107-8, AC-108-4), fechas en hora de Colombia (`UTC-5`) y texto al 200 %
    sin desbordar (incluyendo nombres de producto de 150 caracteres en 360 dp).
* **`profile`** (`lib/features/profile/`):
  * Entidades y DTOs sin impresión de PII ni contraseñas en `toString()` (RNF-062),
    catálogo de los 33 departamentos de Colombia y municipios dependientes
    (`colombia_locations.dart`), y `ProfileValidation` con las reglas del contrato y de
    `checkout-schema` (`nationalId` 3–30, `phone` 7–20 obligatorio en facturación según
    CR-070, nombres ≤ 60, dirección ≤ 200, contraseña 8–128).
  * `ApiProfileRepository` sobre `/mobile/v1`: `GET /me`, `PATCH /me`, `POST /me/email`
    (rota sesión en `SessionController.setSession`), `POST /me/password` (rota sesión),
    `PUT /me/addresses/{type}` (omite opcionales vacíos para respetar `minLength` del
    contrato) y `POST /me/deletion` con `Idempotency-Key` obligatoria (CR-005) y **sin**
    identificador de cuenta en el cuerpo (AC-110-13).
  * `ProfileScreen`, `ChangePasswordScreen`, `AddressesScreen`, `DeleteAccountScreen` y
    `DataRightsScreen`, todas envueltas en `SensitiveScreen`, con bloqueo de doble toque,
    preservación de entrada ante falta de red, soporte de `429` con cuenta regresiva y
    enmascarado que se oculta al pasar a segundo plano (`ProfilePasswordField`).
  * `DeleteAccountScreen` lee `accountDeletionNotice` desde `/config` (sin inventar textos
    ni plazos legales, D-12) y tras `202` invoca `SessionController.onAccountDeleted()`,
    revocando tokens locales, regenerando `deviceId` y limpiando el carrito vía
    `CartRetentionPolicy` (H-07 / CR-040).
  * `AccountScreen` incorpora el acceso «Derechos sobre mis datos» (`Routes.dataRights`,
    AC-111-1) sin llamar a `/me` en la pestaña Cuenta.
* **`shared/navigation` y `app/router`**:
  * Rutas reales `/orders`, `/orders/:orderId` (CR-054), `/account/profile`,
    `/account/password`, `/account/addresses`, `/account/delete` y `/account/data-rights`,
    todas protegidas por la guarda de sesión y probadas en `app_router_features_test.dart`.

## Decisiones pendientes que condicionan este código

| Decisión | Tratamiento en M4 |
|---|---|
| **H-07 (`CR-040`)** carrito al cerrar sesión vs eliminar cuenta | Ya aislado en `CartRetentionPolicy` (`clearOnLogout = false`, `clearOnAccountDeleted = true`). Probado de punta a punta con `DeleteAccountController` → `SessionController.onAccountDeleted()`. |
| **H-08 (`CR-053`)** campos de `OrderDetail` (`AC-108-2` vs `openapi.yaml`) | Aislado en `OrderDetailDisplayPolicy.current`: muestra envío, descuento e impuestos cuando el pedido los trae (> 0) y la imagen del producto si existen `productId` e `imageUrl`, omitiendo siempre seguimiento y dirección (RF-109 fase 2) y sin inventar ceros. |
| **H-03 / PA-02** correo duplicado en `POST /me/email` (`AC-104-6`, `TC-098`) | Aislado en `EmailChangeConflictPolicy.current` (`treatConflictAsNeutral = true`): ante `409 email_in_use` muestra un aviso neutral sin confirmar si el correo pertenece a otra cuenta. |
| **H-11 / D-12** aviso de retención y eliminación de cuenta | La app no inventa textos legales ni plazos: muestra `RemoteConfig.accountDeletionNotice`; si aún no está publicado, muestra un mensaje genérico mínimo con «Recargar información». |
| **D-12 (`RF-111`)** canal vigente de derechos del titular | `DataRightsScreen` informa la eliminación directa en la app (AC-111-3) y expone `legal.dataRightsChannel` (`url` vía navegador seguro y/o `email` con copia al portapapeles); sin canal publicado ofrece reintentar `/config` y WhatsApp. |

## Hallazgos abiertos

| ID | Hallazgo |
|---|---|
| H4-01 | `DataRightsScreen` y `LegalScreen` comparten la misma limitación de `H1-01` / `H2-01` / `H2-02`: `ExternalUrlPolicy` no abre `mailto:` (cae a copiar el correo al portapapeles) y solo abre URLs `https` en el host del flavor hasta que `core` amplíe `extraHttpsHosts`. |
| H4-02 | Las listas de municipios por departamento (`colombia_locations.dart`) se tomaron de `ipr-frontend/src/lib/colombia.ts`; si en WooCommerce se habilitan nuevos municipios o códigos de departamento distintos, requerirán actualizarse o servirse desde `/config`. |
| H4-03 | El contrato `openapi.yaml` sigue con `x-status: proposed` en `EP-07..EP-12`, `EP-25` y `EP-26`; en `EP-11` la clave real de usermeta de `nationalId` en WordPress sigue **DESCONOCIDA** (CR-044 / CR-045) y su validación E2E depende de PT-08/PT-09. |
| H4-04 | `test/unit/app/router_policy_test.dart` verifica `Routes.isProtected` sobre `/account/profile`, `/account/addresses` y `/account/delete`; las rutas nuevas `/account/password` y `/account/data-rights` están cubiertas por `app_router_features_test.dart`. |

## Lo que NO se pudo verificar en esta máquina

* Ejecución en dispositivo Android/iOS real ni emulador (el emulador Android no cabe en la RAM del equipo).
* Integración real contra BFF/WordPress/WooCommerce de staging (`PT-06`, `PT-08`, `PT-09`): `TC-086`, `TC-089` (revocación en otro dispositivo `DEV-B` y `pending_deletion` en WordPress), `TC-090` (pedidos y reutilización del correo tras baja), `TC-092` (revisión manual de guías vigentes de Apple/Google `S-05`), `TC-094` (invalidación real del token anterior en servidor), `TC-095` (contraseña nueva igual a la actual), `ST-056`, `ST-107` (inspección forense del sandbox del dispositivo) y `ST-134`.
* Protección real de capturas de pantalla (`FLAG_SECURE` en Android / `AppDelegate` en iOS) y `autofill` del gestor de contraseñas del SO: se verificó solo mediante `ScreenProtection` simulado en pruebas de widget.

## Siguiente

M5 (`PT-18+`: sedes `listStores`, ayuda y PQRS `submitPqrs` con `Idempotency-Key`, calculadora BTU detrás de `btuCalculatorEnabled` y condicionada a `D-08`, acceso a calculadora y barra superior de Inicio con Ayuda e insignia de Carrito). **Pendiente de tu visto bueno**; no se inicia sin él.

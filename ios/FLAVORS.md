# iOS: flavors, Associated Domains y SC-035 (PENDIENTE: requiere Xcode en macOS)

Esta máquina es Windows: **nada de iOS se pudo compilar ni abrir en Xcode**. Lo que
sí está en el código:

* `AppDelegate.swift` / `SceneDelegate.swift`: canal `co.ipr.app/screen_protection`
  y vista de privacidad en segundo plano (SC-035). **Sin compilar.**
* `Info.plist`: nombre visible, `LSApplicationQueriesSchemes` (whatsapp, tel). ATS
  queda en su valor estricto por defecto (sin `NSAllowsArbitraryLoads`).

Lo que falta hacer en Xcode (no se edita `project.pbxproj` a mano por riesgo de
corromper el proyecto):

1. Crear las configuraciones `Debug/Release/Profile` × `dev/staging/prod` y los tres
   esquemas, con `PRODUCT_BUNDLE_IDENTIFIER` = `co.ipr.app[.dev|.staging]`
   (identificador definitivo pendiente: D-14) y nombre visible por flavor.
2. Añadir la capacidad **Associated Domains** con `applinks:<deepLinkHost>` de
   `config/<flavor>.json`.
3. Subir `deploy/well-known/apple-app-site-association` al dominio.
4. Verificar con un dispositivo real que `/app/pedido` abre la app (SPK-01).
5. Decidir `ASWebAuthenticationSession` efímera (CR-004) frente a
   SFSafariViewController tras el spike SPK-01.

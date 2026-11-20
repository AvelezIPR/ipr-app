/// API pública de la feature `checkout` (RF-052..RF-058): solo las pantallas
/// de nivel de ruta.
///
/// * `Routes.checkout` (`/checkout`, protegida por sesión): `CheckoutScreen`.
/// * `Routes.checkoutResult` (`/checkout/result`, protegida): `CheckoutResultScreen`
///   con las pistas opcionales `order` y `status` del enlace de retorno
///   (`/app/pedido` → `/checkout/result?order=&status=`). Son SOLO pistas: la
///   verdad es `GET /checkout/{checkoutRef}`.
///
/// El orquestador debe sobrescribir `checkoutCartProvider` (puente con la
/// feature `cart`); ver `checkout_providers.dart`.
library;

export 'package:ipr_mobile/features/checkout/checkout_providers.dart'
    show checkoutSessionHookProvider;
export 'package:ipr_mobile/features/checkout/presentation/screens/checkout_result_screen.dart'
    show CheckoutResultScreen;
export 'package:ipr_mobile/features/checkout/presentation/screens/checkout_screen.dart'
    show CheckoutScreen;

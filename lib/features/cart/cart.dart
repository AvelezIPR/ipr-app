// API pública de la feature `cart` (acordada con `checkout` y `product_detail`).
// El orquestador declara `GoRoute('/cart')` con `CartScreen()`; `checkout`
// vacía el carrito SOLO con `clear()` cuando el servidor confirma `paid`; la
// ficha conecta su `AddToCartAction` a `CartController.add`.
export 'domain/entities/cart.dart'
    show CartAddRejected, CartAddResult, CartAdded, CartLimits, CartRejection;
export 'domain/entities/cart_line.dart' show CartLine;
export 'domain/entities/cart_validation.dart'
    show CartLineStatus, CartValidation, ValidatedCartLine;
export 'domain/rules/cart_retention_policy.dart' show CartRetentionPolicy;
export 'presentation/controllers/cart_controller.dart'
    show
        CartCheckoutAttempt,
        CartController,
        CartState,
        cartProvider,
        cartRejectionCode,
        cartUnitCountProvider;
export 'presentation/controllers/cart_session_hook.dart'
    show CartSessionHook, cartSessionHookProvider;
export 'presentation/screens/cart_screen.dart' show CartScreen;
export 'presentation/widgets/cart_messages.dart'
    show cartAddFailureText, cartQuantityLimitedText;

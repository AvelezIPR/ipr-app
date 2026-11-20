/// Qué campos adicionales del contrato `OrderDetail` se muestran en la UI.
///
/// **Único punto** donde se aísla la decisión **H-08 / CR-053** (pendiente de
/// aprobación formal):
/// * Con la recomendación CR-053 (por defecto): se muestran envío, descuento e
///   impuestos cuando el pedido los trae (> 0), y la imagen cuando hay
///   `productId` e `imageUrl`, sin mostrar nunca seguimiento ni dirección
///   (RF-109, fase 2).
/// * Si se optara por AC-108-2 literal, basta cambiar [current] para ocultar
///   esos campos sin tocar el contrato ni el resto de la pantalla.
final class OrderDetailDisplayPolicy {
  const new({
    this.showShipping = true,
    this.showDiscount = true,
    this.showTax = true,
    this.showItemImage = true,
  });

  /// Política vigente (recomendación CR-053 / H-08).
  static const current = OrderDetailDisplayPolicy();

  final bool showShipping;
  final bool showDiscount;
  final bool showTax;
  final bool showItemImage;
}

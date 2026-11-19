/// Orden de los listados (parámetro `sort` del contrato). El conjunto es el
/// enum cerrado de `openapi.yaml`; el servidor no entrega una lista de
/// criterios en tiempo de ejecución (RF-015: criterios fijados por contrato).
enum ProductSort {
  latest('latest'),
  popularity('popularity'),
  priceAsc('price-asc'),
  priceDesc('price-desc'),
  name('name');

  new(this.value);

  /// Valor que viaja en `sort=`.
  final String value;

  static const ProductSort defaultSort = ProductSort.latest;
}

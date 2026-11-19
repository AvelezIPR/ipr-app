import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_sort.dart';
import 'package:meta/meta.dart';

/// Una opción de filtro elegida: dimensión + valor, con las etiquetas que se
/// vieron al elegirla (para los chips de filtros activos sin volver a pedir).
@immutable
final class FilterChoice {
  const new({
    required this.key,
    required this.value,
    required this.keyLabel,
    required this.valueLabel,
    this.boolean = false,
  });

  /// Parámetro de `/products` (`brand`, `onSale`, `attr[pa_…]`…).
  final String key;
  final String value;
  final String keyLabel;
  final String valueLabel;

  /// Dimensión booleana: el chip muestra solo la etiqueta de la dimensión.
  final bool boolean;

  /// Igualdad por (clave, valor): las etiquetas son solo de presentación.
  @override
  bool operator ==(Object other) =>
      other is FilterChoice && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(key, value);
}

/// Categoría elegida en el filtro (sustituye a la del contexto del listado).
@immutable
final class CategoryChoice {
  const new({required this.slug, required this.name});

  final String slug;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is CategoryChoice && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}

/// Filtros, orden y búsqueda interna aplicados a un listado. Inmutable: cada
/// cambio devuelve una copia.
@immutable
final class ProductFilters {
  const new({
    this.choices = const [],
    this.category,
    this.sort = ProductSort.defaultSort,
    this.searchTerm,
  });

  static const empty = ProductFilters();

  /// Máximo del contrato para `q` (`SearchQuery`).
  static const maxSearchLength = 120;

  /// Opciones elegidas, en el orden en que se eligieron.
  final List<FilterChoice> choices;
  final CategoryChoice? category;
  final ProductSort sort;

  /// Búsqueda interna de una marca (RF-016); `null` si no hay.
  final String? searchTerm;

  bool get isSearching => searchTerm != null;

  /// Opciones y categoría elegidas (lo que muestra la hoja de filtros).
  int get selectionCount => choices.length + (category == null ? 0 : 1);

  /// Cantidad de filtros activos (chips). El orden no cuenta como filtro.
  int get activeCount => selectionCount + (isSearching ? 1 : 0);

  bool get hasActive => activeCount > 0;

  bool contains(String key, String value) =>
      choices.any((c) => c.key == key && c.value == value);

  List<FilterChoice> choicesOf(String key) => [
    for (final c in choices)
      if (c.key == key) c,
  ];

  Set<String> get _attributeKeys => {
    for (final c in choices)
      if (FilterKeys.isAttribute(c.key)) c.key,
  };

  /// ¿Se puede añadir una opción más de [key]? (máximos del contrato)
  bool canAdd(String key) {
    if (choicesOf(key).length >= FilterKeys.maxValuesPerKey) return false;
    if (FilterKeys.isAttribute(key) &&
        choicesOf(key).isEmpty &&
        _attributeKeys.length >= FilterKeys.maxAttributes) {
      return false;
    }
    return true;
  }

  /// Alterna [choice]. Respeta los máximos del contrato (5 valores por clave,
  /// 5 atributos): si añadirla los supera, no cambia nada.
  ProductFilters toggled(FilterChoice choice) {
    if (contains(choice.key, choice.value)) return without(choice);
    if (!canAdd(choice.key)) return this;
    return copyWith(choices: [...choices, choice]);
  }

  ProductFilters without(FilterChoice choice) => copyWith(
    choices: [
      for (final c in choices)
        if (c != choice) c,
    ],
  );

  ProductFilters withSort(ProductSort value) => copyWith(sort: value);

  ProductFilters withCategory(CategoryChoice? value) =>
      copyWith(category: value, clearCategory: value == null);

  /// Texto de búsqueda normalizado; vacío lo quita.
  ProductFilters withSearch(String? term) {
    final clean = sanitizeSearchTerm(term);
    return copyWith(searchTerm: clean, clearSearch: clean == null);
  }

  /// "Limpiar filtros": quita opciones, categoría y búsqueda; conserva el
  /// orden (no es un filtro).
  ProductFilters cleared() => ProductFilters(sort: sort);

  ProductFilters copyWith({
    List<FilterChoice>? choices,
    CategoryChoice? category,
    bool clearCategory = false,
    ProductSort? sort,
    String? searchTerm,
    bool clearSearch = false,
  }) => ProductFilters(
    choices: choices ?? this.choices,
    category: clearCategory ? null : (category ?? this.category),
    sort: sort ?? this.sort,
    searchTerm: clearSearch ? null : (searchTerm ?? this.searchTerm),
  );

  static final _controlOrMarkup = RegExp('[\u0000-\u001F\u007F<>]');

  /// Quita caracteres de control y marcado, recorta y limita a 120 (contrato
  /// `SearchQuery`). Devuelve `null` si queda vacío. El término lo escribe el
  /// usuario: nunca se registra ni se guarda en caché.
  static String? sanitizeSearchTerm(String? raw) {
    if (raw == null) return null;
    var text = raw.replaceAll(_controlOrMarkup, ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > maxSearchLength) {
      text = text.substring(0, maxSearchLength).trim();
    }
    return text.isEmpty ? null : text;
  }

  @override
  bool operator ==(Object other) {
    if (other is! ProductFilters) return false;
    if (other.sort != sort ||
        other.category != category ||
        other.searchTerm != searchTerm ||
        other.choices.length != choices.length) {
      return false;
    }
    for (final c in choices) {
      if (!other.choices.contains(c)) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(sort, category, searchTerm, Object.hashAllUnordered(choices));
}

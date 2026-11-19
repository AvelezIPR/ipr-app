import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_filters.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_sort.dart';

FilterChoice choice(String key, String value, {bool boolean = false}) =>
    FilterChoice(
      key: key,
      value: value,
      keyLabel: key,
      valueLabel: value,
      boolean: boolean,
    );

void main() {
  group('M1 · RF-013/014 · ProductFilters', () {
    test(
      'toggled añade y quita una opción; el orden de elección se conserva',
      () {
        var f = ProductFilters.empty
            .toggled(choice('brand', 'elitech'))
            .toggled(choice('attr[pa_capacidad-btu]', '12-000-btu'));
        expect(f.choices.map((c) => c.value), ['elitech', '12-000-btu']);
        expect(f.selectionCount, 2);
        f = f.toggled(choice('brand', 'elitech'));
        expect(f.choices.map((c) => c.value), ['12-000-btu']);
        expect(f.contains('brand', 'elitech'), isFalse);
      },
    );

    test('respeta el máximo del contrato: 5 valores por clave', () {
      var f = ProductFilters.empty;
      for (var i = 0; i < 7; i++) {
        f = f.toggled(choice('brand', 'm$i'));
      }
      expect(f.choicesOf('brand'), hasLength(5));
      expect(f.canAdd('brand'), isFalse);
      // Quitar una libera el cupo.
      f = f.toggled(choice('brand', 'm0'));
      expect(f.canAdd('brand'), isTrue);
    });

    test('respeta el máximo del contrato: 5 atributos distintos', () {
      var f = ProductFilters.empty;
      for (var i = 0; i < 6; i++) {
        f = f.toggled(choice('attr[pa_a$i]', 'v'));
      }
      expect(f.choices.map((c) => c.key).toSet(), hasLength(5));
      expect(f.canAdd('attr[pa_a5]'), isFalse);
      // Otro valor de un atributo ya elegido sí cabe.
      expect(f.canAdd('attr[pa_a0]'), isTrue);
    });

    test(
      'cleared quita filtros, categoría y búsqueda pero conserva el orden',
      () {
        final f = ProductFilters.empty
            .toggled(choice('brand', 'elitech'))
            .withCategory(const CategoryChoice(slug: 'minisplit', name: 'M'))
            .withSearch('manómetro')
            .withSort(ProductSort.priceAsc);
        expect(f.activeCount, 3);
        final cleared = f.cleared();
        expect(cleared.hasActive, isFalse);
        expect(cleared.sort, ProductSort.priceAsc);
      },
    );

    test('withCategory(null) quita la categoría elegida', () {
      final f = ProductFilters.empty.withCategory(
        const CategoryChoice(slug: 'a', name: 'A'),
      );
      expect(f.category?.slug, 'a');
      expect(f.withCategory(null).category, isNull);
    });

    test(
      'sanitizeSearchTerm recorta, quita marcado y control, y limita a 120',
      () {
        expect(ProductFilters.sanitizeSearchTerm(null), isNull);
        expect(ProductFilters.sanitizeSearchTerm('   '), isNull);
        expect(
          ProductFilters.sanitizeSearchTerm('<b>  r410a\n\t </b>'),
          'b r410a /b',
        );
        expect(
          ProductFilters.sanitizeSearchTerm('x' * 300),
          hasLength(ProductFilters.maxSearchLength),
        );
        expect(ProductFilters.empty.withSearch('  ').searchTerm, isNull);
        expect(ProductFilters.empty.withSearch(' r410a ').searchTerm, 'r410a');
      },
    );

    test('igualdad por valor, sin importar el orden de las opciones', () {
      final a = ProductFilters.empty
          .toggled(choice('brand', 'x'))
          .toggled(choice('brand', 'y'));
      final b = ProductFilters.empty
          .toggled(choice('brand', 'y'))
          .toggled(choice('brand', 'x'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.withSort(ProductSort.name), isFalse);
    });
  });

  group('M1 · RF-010 · CategoryNode', () {
    const leaf = CategoryNode(id: 3, slug: 'hoja', name: 'Hoja', parentId: 2);
    const mid = CategoryNode(
      id: 2,
      slug: 'medio',
      name: 'Medio',
      parentId: 1,
      children: [leaf],
    );
    const root = CategoryNode(
      id: 1,
      slug: 'raiz',
      name: 'Raíz',
      children: [mid],
    );

    test('find recorre todos los niveles', () {
      expect(root.find('hoja'), leaf);
      expect(root.find('nada'), isNull);
      expect(findCategory([root], 'medio'), mid);
      expect(findCategory([root], 'zzz'), isNull);
      expect(leaf.isLeaf, isTrue);
      expect(root.isLeaf, isFalse);
    });

    test('igualdad y hash por valor', () {
      const other = CategoryNode(
        id: 1,
        slug: 'raiz',
        name: 'Raíz',
        children: [mid],
      );
      expect(root, other);
      expect(root.hashCode, other.hashCode);
      expect(root == leaf, isFalse);
    });
  });

  group('M1 · contrato · entidades pequeñas', () {
    test('FilterKeys solo admite parámetros de /products', () {
      expect(FilterKeys.isSupported('brand'), isTrue);
      expect(FilterKeys.isSupported('tag'), isTrue);
      expect(FilterKeys.isSupported('onSale'), isTrue);
      expect(FilterKeys.isSupported('attr[pa_capacidad-btu]'), isTrue);
      expect(FilterKeys.isSupported('attr[color]'), isFalse);
      expect(FilterKeys.isSupported('price'), isFalse);
      expect(FilterKeys.isAttribute('brand'), isFalse);
    });

    test('FilterDimension y Brand comparan por valor', () {
      const a = FilterDimension(
        key: 'brand',
        label: 'Marca',
        type: FilterDimensionType.multi,
        options: [FilterOption(value: 'x', label: 'X')],
      );
      const b = FilterDimension(
        key: 'brand',
        label: 'Marca',
        type: FilterDimensionType.multi,
        options: [FilterOption(value: 'x', label: 'X')],
      );
      const c = FilterDimension(
        key: 'brand',
        label: 'Marca',
        type: FilterDimensionType.multi,
        options: [FilterOption(value: 'y', label: 'Y')],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      const brand = Brand(slug: 's', name: 'N');
      expect(brand, const Brand(slug: 's', name: 'N'));
      expect(brand.hasLanding, isFalse);
    });

    test('ListScope distingue categoría, marca y liquidaciones', () {
      expect(const ListScope.category('a'), const ListScope.category('a'));
      expect(
        const ListScope.category('a') == const ListScope.brand('a'),
        isFalse,
      );
      expect(const ListScope.sale().slug, isNull);
      expect(const ListScope.all().categorySlug, isNull);
      expect(const ListScope.category('a').categorySlug, 'a');
      expect(const ListScope.brand('b').brandSlug, 'b');
      expect(const ListScope.brand('b').categorySlug, isNull);
      expect(const ListScope.sale().toString(), contains('sale'));
      expect(
        const ListScope.brand('b').hashCode,
        const ListScope.brand('b').hashCode,
      );
    });

    test('ProductQuery.forPage conserva contexto y filtros', () {
      final q = ProductQuery(
        scope: const ListScope.category('a'),
        filters: ProductFilters.empty.withSort(ProductSort.name),
      ).forPage(3);
      expect(q.page, 3);
      expect(q.filters.sort, ProductSort.name);
      expect(q.perPage, ProductQuery.defaultPerPage);
    });

    test('ProductSort usa los valores del contrato', () {
      expect(ProductSort.values.map((s) => s.value), [
        'latest',
        'popularity',
        'price-asc',
        'price-desc',
        'name',
      ]);
    });
  });
}

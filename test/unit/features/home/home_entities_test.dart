import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';

void main() {
  group('M1 · entidades del inicio', () {
    test('HomeCategory se compara por valor', () {
      const a = HomeCategory(id: 1, slug: 'aire', name: 'Aire');
      const b = HomeCategory(id: 1, slug: 'aire', name: 'Aire');
      const c = HomeCategory(id: 2, slug: 'aire', name: 'Aire');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('HomeBrand se compara por valor', () {
      const a = HomeBrand(slug: 'elitech', name: 'Elitech');
      const b = HomeBrand(slug: 'elitech', name: 'Elitech');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const HomeBrand(slug: 'otra', name: 'Elitech')));
    });

    test('SectionData: por defecto los datos no son obsoletos', () {
      expect(const SectionData([1]).stale, isFalse);
      expect(const SectionData([1], stale: true).stale, isTrue);
    });
  });
}

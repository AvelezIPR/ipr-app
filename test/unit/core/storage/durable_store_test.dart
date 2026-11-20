import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';

void main() {
  group('M3 · RF-049 · DurableStore', () {
    test('MemoryDurableStore guarda, lee y borra sin caducar', () async {
      final store = MemoryDurableStore();
      expect(await store.read('cart'), isNull);
      await store.write('cart', '{"items":[]}');
      expect(await store.read('cart'), '{"items":[]}');
      await store.remove('cart');
      expect(await store.read('cart'), isNull);
    });

    test('el valor inicial se copia (no se comparte el mapa)', () async {
      final seed = {'a': '1'};
      final store = MemoryDurableStore(seed);
      await store.write('b', '2');
      expect(seed.containsKey('b'), isFalse);
      expect(await store.read('a'), '1');
    });
  });
}

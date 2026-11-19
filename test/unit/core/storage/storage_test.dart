import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/core/storage/preferences_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';
import 'package:ipr_mobile/core/storage/storage_hygiene.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mocks/memory_preferences_store.dart';
import '../../../mocks/memory_secure_key_value.dart';

void main() {
  group('M0 · SC-032 · primera ejecución limpia el almacén seguro', () {
    test('sin marca: limpia el Keychain y escribe la marca', () async {
      final prefs = InMemoryPreferencesStore();
      final secure = InMemorySecureKeyValue({
        SecureKeys.refreshToken: 'iprr_viejo',
      });
      final cleaned = await clearSecureStorageOnFirstLaunch(
        preferences: prefs,
        secure: secure,
      );
      expect(cleaned, isTrue);
      expect(secure.data, isEmpty);
      expect(prefs.getBool(PreferenceKeys.installMarker), isTrue);
    });

    test('con marca: no toca el almacén seguro', () async {
      final prefs = InMemoryPreferencesStore();
      await prefs.setBool(PreferenceKeys.installMarker, value: true);
      final secure = InMemorySecureKeyValue({
        SecureKeys.refreshToken: 'iprr_ok',
      });
      final cleaned = await clearSecureStorageOnFirstLaunch(
        preferences: prefs,
        secure: secure,
      );
      expect(cleaned, isFalse);
      expect(secure.data[SecureKeys.refreshToken], 'iprr_ok');
    });
  });

  group('SharedPreferencesStore', () {
    test('lee, escribe y borra', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesStore(
        await SharedPreferences.getInstance(),
      );
      await store.setBool('a', value: true);
      await store.setString('b', 'x');
      expect(store.getBool('a'), isTrue);
      expect(store.getString('b'), 'x');
      await store.remove('a');
      expect(store.getBool('a'), isNull);
    });
  });

  group('CacheStore · política de frescura (CR-078)', () {
    const policy = CachePolicy.listing;

    test('MemoryCacheStore: fresco, obsoleto y vencido', () async {
      var now = DateTime.utc(2026, 11, 19, 12);
      final store = MemoryCacheStore(now: () => now);
      await store.write('k', 'v');

      expect((await store.read('k', policy))!.freshness, CacheFreshness.fresh);
      now = now.add(const Duration(minutes: 10));
      final stale = (await store.read('k', policy))!;
      expect(stale.freshness, CacheFreshness.stale);
      expect(stale.isStale, isTrue);
      now = now.add(const Duration(hours: 25));
      expect(await store.read('k', policy), isNull);
      expect(store.length, 0, reason: 'lo vencido se descarta');
    });

    test('MemoryCacheStore: remove, clear y claves ausentes', () async {
      final store = MemoryCacheStore();
      await store.write('a', '1');
      await store.write('b', '2');
      await store.remove('a');
      expect(await store.read('a', policy), isNull);
      await store.clear();
      expect(store.length, 0);
    });

    group('HiveCacheStore (disco real en carpeta temporal)', () {
      late Directory dir;
      late Box<String> box;
      var now = DateTime.utc(2026, 11, 19, 12);

      setUp(() async {
        now = DateTime.utc(2026, 11, 19, 12);
        dir = Directory.systemTemp.createTempSync('ipr_hive_');
        Hive.init(dir.path);
        box = await Hive.openBox<String>('cache');
      });

      tearDown(() async {
        await Hive.close();
        dir.deleteSync(recursive: true);
      });

      test('escribe y lee con frescura', () async {
        final store = HiveCacheStore(box, now: () => now);
        await store.write('k', 'valor');
        final read = (await store.read('k', policy))!;
        expect(read.value, 'valor');
        expect(read.freshness, CacheFreshness.fresh);
        now = now.add(const Duration(minutes: 30));
        expect(
          (await store.read('k', policy))!.freshness,
          CacheFreshness.stale,
        );
      });

      test('lo vencido se elimina al leerlo', () async {
        final store = HiveCacheStore(box, now: () => now);
        await store.write('k', 'v');
        now = now.add(const Duration(days: 2));
        expect(await store.read('k', policy), isNull);
        expect(store.length, 0);
      });

      test(
        'expulsión LRU: se va la entrada menos usada al superar el tope',
        () async {
          final store = HiveCacheStore(box, maxEntries: 3, now: () => now);
          for (final k in ['a', 'b', 'c']) {
            await store.write(k, k);
            now = now.add(const Duration(seconds: 1));
          }
          await store.read('a', policy); // 'a' pasa a ser la más reciente
          now = now.add(const Duration(seconds: 1));
          await store.write('d', 'd');
          expect(store.length, 3);
          expect(
            await store.read('b', policy),
            isNull,
            reason: 'b era la menos usada',
          );
          expect(await store.read('a', policy), isNotNull);
          expect(await store.read('d', policy), isNotNull);
        },
      );

      test('una entrada corrupta se descarta sin lanzar', () async {
        final store = HiveCacheStore(box, now: () => now);
        await box.put('rota', '{no es json');
        expect(await store.read('rota', policy), isNull);
        expect(box.containsKey('rota'), isFalse);
      });

      test('remove y clear', () async {
        final store = HiveCacheStore(box, now: () => now);
        await store.write('a', '1');
        await store.write('b', '2');
        await store.remove('a');
        expect(store.length, 1);
        await store.clear();
        expect(store.length, 0);
      });
    });

    test(
      'las políticas por recurso coinciden con flutter_app_architecture §7.4',
      () {
        expect(CachePolicy.taxonomy.fresh, const Duration(hours: 1));
        expect(CachePolicy.taxonomy.stale, const Duration(days: 7));
        expect(CachePolicy.listing.fresh, const Duration(minutes: 5));
        expect(CachePolicy.listing.stale, const Duration(hours: 24));
        expect(CachePolicy.stores.fresh, const Duration(hours: 24));
        expect(CachePolicy.stores.stale, const Duration(days: 30));
      },
    );
  });
}

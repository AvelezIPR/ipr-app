import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_ref.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:ipr_mobile/shared/formatting/cop_format.dart';
import 'package:ipr_mobile/shared/formatting/date_format.dart';

void main() {
  group('TC-051 · AC-012-1 · RNF-084 · formato COP', () {
    test('agrupa con puntos y sin decimales', () {
      expect(formatCop(Money.zero), r'$ 0');
      expect(formatCop(const Money(999)), r'$ 999');
      expect(formatCop(const Money(1000)), r'$ 1.000');
      expect(formatCop(const Money(11300)), r'$ 11.300');
      expect(formatCop(const Money(1445000)), r'$ 1.445.000');
      expect(formatCop(const Money(1830000)), r'$ 1.830.000');
      expect(formatCop(const Money(1234567890)), r'$ 1.234.567.890');
    });

    test('formatCopNumber y etiqueta semántica sin símbolo', () {
      expect(formatCopNumber(const Money(213600)), '213.600');
      expect(copSemanticsAmount(const Money(1445000)), '1.445.000');
    });

    test('el formato nunca altera el valor del servidor', () {
      for (final pesos in [
        1,
        12,
        123,
        1234,
        12345,
        123456,
        1234567,
        99999999,
      ]) {
        final text = formatCopNumber(Money(pesos));
        expect(int.parse(text.replaceAll('.', '')), pesos);
      }
    });

    test('un importe negativo conserva el signo (no debería ocurrir)', () {
      expect(formatCop(const Money(-1500)), r'$ -1.500');
    });
  });

  group('Money · entero, nunca double (RNF-107)', () {
    test('tryFromJson acepta enteros y dobles sin fracción', () {
      expect(Money.tryFromJson(1500), const Money(1500));
      expect(Money.tryFromJson(1830000.0), const Money(1830000));
      expect(Money.tryFromJson(0), Money.zero);
    });

    test('tryFromJson rechaza fracciones, negativos y no numéricos', () {
      for (final bad in <Object?>[
        1500.5,
        -1,
        -0.5,
        double.nan,
        double.infinity,
        '1500',
        null,
        true,
      ]) {
        expect(Money.tryFromJson(bad), isNull, reason: '$bad');
      }
    });

    test('operaciones, igualdad y orden', () {
      expect(const Money(100) + const Money(50), const Money(150));
      expect(const Money(100) * 3, const Money(300));
      expect(const Money(100).compareTo(const Money(50)), greaterThan(0));
      expect(const Money(100).hashCode, const Money(100).hashCode);
      expect(Money.zero.isZero, isTrue);
      expect(const Money(7).toString(), 'Money(7)');
    });
  });

  group(r'TC-047 · AC-050-5 · RF-012 · PriceStatus: nunca "$0"', () {
    test('priced con monto positivo', () {
      final p = PriceStatus.fromContract(status: 'priced', amount: 1445000);
      expect(p, const Priced(Money(1445000)));
      expect(p.hasPrice, isTrue);
    });

    test('defensa en profundidad: precio 0, nulo, negativo o ilegible es OnRequest', () {
      for (final amount in <Object?>[0, 0.0, null, -5, '1000', 12.5]) {
        final p = PriceStatus.fromContract(status: 'priced', amount: amount);
        expect(p, isA<OnRequest>(), reason: '$amount');
        expect(p.hasPrice, isFalse);
      }
    });

    test('on_request y estados desconocidos son OnRequest', () {
      expect(
        PriceStatus.fromContract(status: 'on_request', amount: 1000),
        isA<OnRequest>(),
      );
      expect(PriceStatus.fromContract(status: null), isA<OnRequest>());
      expect(
        PriceStatus.fromContract(status: 'nuevo_estado'),
        isA<OnRequest>(),
      );
    });

    test('igualdad de valor', () {
      expect(const OnRequest(), const OnRequest());
      expect(const OnRequest().hashCode, const OnRequest().hashCode);
      expect(const Priced(Money(1)).hashCode, const Priced(Money(1)).hashCode);
      expect(const Priced(Money(1)) == const Priced(Money(2)), isFalse);
    });
  });

  group('CR-017 · StockStatus y elegibilidad de compra', () {
    test('lectura tolerante del contrato', () {
      expect(StockStatus.fromContract('in_stock'), StockStatus.inStock);
      expect(StockStatus.fromContract('out_of_stock'), StockStatus.outOfStock);
      expect(StockStatus.fromContract('on_backorder'), StockStatus.onBackorder);
      expect(StockStatus.fromContract('algo_nuevo'), StockStatus.unknown);
      expect(StockStatus.fromContract(null), StockStatus.unknown);
    });

    test('solo "en stock" con precio se puede añadir', () {
      const priced = Priced(Money(1000));
      const none = OnRequest();
      expect(canAddToCart(price: priced, stock: StockStatus.inStock), isTrue);
      expect(
        canAddToCart(price: priced, stock: StockStatus.outOfStock),
        isFalse,
      );
      expect(
        canAddToCart(price: priced, stock: StockStatus.onBackorder),
        isFalse,
        reason: 'bajo pedido NO comprable en el MVP (CR-017)',
      );
      expect(canAddToCart(price: priced, stock: StockStatus.unknown), isFalse);
      expect(
        canAddToCart(price: none, stock: StockStatus.inStock),
        isFalse,
        reason: 'sin precio solo WhatsApp (ADR-002)',
      );
    });
  });

  group('ProductRef', () {
    test('slug válido según el contrato', () {
      expect(ProductRef.isValidSlug('mini-split-12000-btu'), isTrue);
      expect(ProductRef.isValidSlug('a'), isTrue);
      expect(ProductRef.isValidSlug('-malo'), isFalse);
      expect(ProductRef.isValidSlug('Mayuscula'), isFalse);
      expect(ProductRef.isValidSlug('con espacio'), isFalse);
      expect(ProductRef.isValidSlug('a' * 201), isFalse);
      expect(ProductRef.isValidSlug(''), isFalse);
    });

    test('igualdad y representación', () {
      const a = ProductRef(id: 1, slug: 'x');
      expect(a, const ProductRef(id: 1, slug: 'x'));
      expect(a.hashCode, const ProductRef(id: 1, slug: 'x').hashCode);
      expect(a == const ProductRef(id: 2, slug: 'x'), isFalse);
      expect(a.toString(), 'ProductRef(1, x)');
    });
  });

  group('Fechas · America/Bogota (UTC−5, sin horario de verano)', () {
    test('convierte de UTC a hora de Colombia', () {
      final utc = DateTime.utc(2026, 11, 19, 3, 30);
      expect(toBogota(utc), DateTime.utc(2026, 11, 18, 22, 30));
      expect(formatDate(utc), '18/11/2026');
      expect(formatDateTime(utc), '18/11/2026 22:30');
    });

    test('acepta instantes locales (convierte vía UTC)', () {
      final local = DateTime.utc(2026, 1, 5, 12).toLocal();
      expect(formatDate(local), '05/01/2026');
    });

    test('rellena con ceros día, mes, hora y minuto', () {
      expect(
        formatDateTime(DateTime.utc(2026, 3, 4, 14, 5)),
        '04/03/2026 09:05',
      );
    });

    test('tryParseServerDate lee ISO 8601 y descarta lo ilegible', () {
      expect(
        tryParseServerDate('2026-11-19T03:30:00Z'),
        DateTime.utc(2026, 11, 19, 3, 30),
      );
      expect(tryParseServerDate('no es fecha'), isNull);
      expect(tryParseServerDate(42), isNull);
      expect(tryParseServerDate(null), isNull);
    });
  });
}

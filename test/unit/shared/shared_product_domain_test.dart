import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/external/media_host_policy.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

ProductSummary summary({
  PriceStatus price = const Priced(Money(1000)),
  StockStatus stock = StockStatus.inStock,
  bool onSale = false,
  Money? regular,
}) => ProductSummary(
  id: 1,
  slug: 'x',
  name: 'X',
  sku: '1',
  price: price,
  availability: stock,
  onSale: onSale,
  regularPrice: regular,
);

void main() {
  group('SC-043 · MediaHostPolicy', () {
    const policy = MediaHostPolicy(
      allowedHosts: {'ipr.iprpartesyrepuestos.com', 'IMG.example.com'},
    );

    test('solo https, sin credenciales, puerto 443 y host listado', () {
      expect(
        policy.isAllowed(
          'https://ipr.iprpartesyrepuestos.com/wp-content/a.png',
        ),
        isTrue,
      );
      expect(policy.isAllowed('https://img.example.com:443/a.png'), isTrue);
      for (final bad in <String?>[
        null,
        '',
        'http://ipr.iprpartesyrepuestos.com/a.png',
        'https://evil.example.com/a.png',
        'https://ipr.iprpartesyrepuestos.com.evil.com/a.png',
        'https://user:pw@ipr.iprpartesyrepuestos.com/a.png',
        'https://ipr.iprpartesyrepuestos.com:8443/a.png',
        'file:///etc/passwd',
        'javascript:alert(1)',
        '//ipr.iprpartesyrepuestos.com/a.png',
        'no es url',
      ]) {
        expect(policy.isAllowed(bad), isFalse, reason: '$bad');
      }
    });
  });

  group('ImageRef', () {
    test('lectura tolerante del contrato', () {
      final ok = ImageRef.tryFromJson({
        'url': 'https://x/a.png',
        'alt': 'foto',
        'width': 800,
        'height': 600,
      });
      expect(ok!.url, 'https://x/a.png');
      expect(ok.width, 800);
      expect(ImageRef.tryFromJson({'url': 'https://x/a.png'})!.alt, '');
      expect(
        ImageRef.tryFromJson({'url': 'https://x/a.png', 'width': '800'})!.width,
        isNull,
      );
      for (final bad in <Object?>[
        null,
        'texto',
        {'alt': 'x'},
        {'url': ''},
        {'url': 3},
      ]) {
        expect(ImageRef.tryFromJson(bad), isNull, reason: '$bad');
      }
    });

    test('igualdad por url y alt', () {
      expect(
        const ImageRef(url: 'u', alt: 'a'),
        const ImageRef(url: 'u', alt: 'a'),
      );
      expect(
        const ImageRef(url: 'u', alt: 'a').hashCode,
        const ImageRef(url: 'u', alt: 'a').hashCode,
      );
      expect(
        const ImageRef(url: 'u', alt: 'a') ==
            const ImageRef(url: 'u2', alt: 'a'),
        isFalse,
      );
    });
  });

  group('CR-017 · ProductSummary', () {
    test('canAddToCart: solo en stock y con precio', () {
      expect(summary().canAddToCart, isTrue);
      expect(summary(stock: StockStatus.outOfStock).canAddToCart, isFalse);
      expect(summary(stock: StockStatus.onBackorder).canAddToCart, isFalse);
      expect(summary(stock: StockStatus.unknown).canAddToCart, isFalse);
      expect(summary(price: const OnRequest()).canAddToCart, isFalse);
    });

    test('strikeThroughPrice solo en una oferta real', () {
      expect(
        summary(onSale: true, regular: const Money(2000)).strikeThroughPrice,
        const Money(2000),
      );
      expect(
        summary(onSale: true, regular: const Money(500)).strikeThroughPrice,
        isNull,
      );
      expect(
        summary(onSale: true, regular: const Money(1000)).strikeThroughPrice,
        isNull,
      );
      expect(summary(regular: const Money(2000)).strikeThroughPrice, isNull);
      expect(summary(onSale: true).strikeThroughPrice, isNull);
      expect(
        summary(
          price: const OnRequest(),
          onSale: true,
          regular: const Money(2000),
        ).strikeThroughPrice,
        isNull,
      );
    });

    test('igualdad de valor', () {
      expect(summary(), summary());
      expect(summary().hashCode, summary().hashCode);
      expect(summary() == summary(stock: StockStatus.outOfStock), isFalse);
    });
  });
}

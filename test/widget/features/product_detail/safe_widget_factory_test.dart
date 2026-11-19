import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/external/media_host_policy.dart';
import 'package:ipr_mobile/features/product_detail/presentation/widgets/safe_widget_factory.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final factory = SafeWidgetFactory(
    const MediaHostPolicy(allowedHosts: {'media.ipr.test'}),
  );

  test('SC-043 · solo resuelve imágenes https de la lista blanca', () {
    expect(
      factory.imageProviderFromNetwork('https://media.ipr.test/a.png'),
      isA<NetworkImage>(),
    );
    for (final url in [
      'https://evil.invalid/a.png',
      'http://media.ipr.test/a.png',
      'https://media.ipr.test.evil.invalid/a.png',
      '',
    ]) {
      expect(factory.imageProviderFromNetwork(url), isNull, reason: url);
    }
  });

  test('asset:, data: y file: nunca se cargan', () {
    expect(factory.imageProviderFromAsset('asset:x'), isNull);
    expect(
      factory.imageProviderFromDataUri('data:image/png;base64,AAAA'),
      isNull,
    );
    expect(factory.imageProviderFromFileUri('file:///etc/passwd'), isNull);
  });
}

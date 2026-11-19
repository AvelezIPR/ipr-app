import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/interceptors/app_headers_interceptor.dart';
import 'package:ipr_mobile/core/network/interceptors/error_mapping_interceptor.dart';
import 'package:ipr_mobile/core/network/interceptors/retry_interceptor.dart';
import 'package:ipr_mobile/core/session/auth_interceptor.dart';
import 'package:ipr_mobile/core/session/session_gateway.dart';

import 'fake_http_adapter.dart';

const testDeviceId = '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b';

final testConfig = AppConfig.fromMap(const {
  'environment': 'staging',
  'apiBaseUrl': 'https://staging.invalid/mobile/v1',
  'deepLinkHost': 'staging.invalid',
  'checkoutAllowedHosts': 'staging.invalid',
  'mediaHosts': 'staging.invalid',
  'supportWhatsApp': '573000000000',
});

/// Cliente con los interceptores reales en el orden de producción, sobre un
/// adaptador falso. Los `sleep` de reintento se registran sin esperar.
({ApiClient client, List<Duration> sleeps}) buildTestClient({
  required FakeHttpAdapter adapter,
  SessionGateway? gateway,
  void Function(Object failure)? onFailure,
}) {
  final sleeps = <Duration>[];
  final client = ApiClient.build(
    config: testConfig,
    adapter: adapter,
    interceptors: (dio) => [
      AppHeadersInterceptor(
        appVersion: '1.2.3',
        platform: 'android',
        deviceId: () async => testDeviceId,
        requestId: () => '22222222-2222-4222-8222-222222222222',
      ),
      ?(gateway == null ? null : AuthInterceptor(gateway: gateway, dio: dio)),
      RetryInterceptor(dio: dio, sleep: (d) async => sleeps.add(d)),
      ErrorMappingInterceptor(onFailure: onFailure),
    ],
  );
  return (client: client, sleeps: sleeps);
}

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart'
    show RemoteConfigSource;
import 'package:ipr_mobile/core/external/secure_browser.dart';
import 'package:ipr_mobile/core/providers.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';
import '../../../mocks/test_providers.dart';

/// Navegador seguro de prueba: registra las URL y devuelve [result].
final class FakeSecureBrowser implements SecureBrowser {
  new({this.result = true, this.throws = false});

  bool result;
  bool throws;
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    if (throws) throw StateError('navegador roto');
    return result;
  }
}

/// Host permitido por la política (`testConfig.deepLinkHost`).
const legalHost = 'staging.invalid';

/// Configuración con los tres documentos y un correo de derechos.
const fullLegalConfig = RemoteConfig(
  whatsappNumber: '573014021882',
  phoneDial: '+576043604440',
  termsVersion: '2026-01',
  termsUrl: 'https://$legalHost/terminos',
  privacyPolicyVersion: '2026-02',
  privacyPolicyUrl: 'https://$legalHost/privacidad',
  dataRightsEmail: 'datos@$legalHost',
);

/// `/config` con documentos legales (cuerpo del contrato).
Map<String, Object?> configBody({bool withLegal = true}) => {
  'data': {
    if (withLegal)
      'legal': {
        'terms': {'version': '2026-01', 'url': 'https://$legalHost/terminos'},
        'privacyPolicy': {
          'version': '2026-02',
          'url': 'https://$legalHost/privacidad',
        },
        'dataRightsChannel': {'url': 'https://$legalHost/derechos'},
        'accountDeletionNotice': 'Tu cuenta se elimina de forma permanente.',
      },
  },
};

/// Overrides de la feature: `/config` inicial con [config], navegador y
/// lanzador falsos y el cliente HTTP sobre [adapter] (`coreOverrides` arma con
/// él el repositorio de `/config` que usa "Reintentar").
List<Override> supportOverrides({
  required RemoteConfig config,
  required FakeHttpAdapter adapter,
  FakeSecureBrowser? browser,
  FakeExternalLauncher? launcher,
}) => testOverrides(
  launcher: launcher,
  extra: [
    apiClientProvider.overrideWithValue(
      buildTestClient(adapter: adapter).client,
    ),
    secureBrowserProvider.overrideWithValue(browser ?? FakeSecureBrowser()),
    remoteConfigProvider.overrideWithBuild(
      (ref, notifier) =>
          RemoteConfigState(config: config, source: RemoteConfigSource.network),
    ),
  ],
);

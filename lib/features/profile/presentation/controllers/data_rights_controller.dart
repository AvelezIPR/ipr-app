import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/external/external_url_policy.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:meta/meta.dart';

/// Canal de derechos del titular publicado por `/config` (RF-111, D-12).
@immutable
final class DataRightsChannelInfo {
  const new({this.url, this.email});

  final String? url;
  final String? email;

  bool get hasAny => url != null || email != null;
}

final Provider<DataRightsChannelInfo> dataRightsChannelProvider =
    Provider<DataRightsChannelInfo>((ref) {
      final config = ref.watch(remoteConfigProvider.select((s) => s.config));
      String? clean(String? value) {
        final t = value?.trim();
        return (t == null || t.isEmpty) ? null : t;
      }

      return DataRightsChannelInfo(
        url: clean(config.dataRightsUrl),
        email: clean(config.dataRightsEmail),
      );
    });

final NotifierProvider<DataRightsController, bool>
dataRightsControllerProvider =
    NotifierProvider.autoDispose<DataRightsController, bool>(
      DataRightsController.new,
    );

/// Abre el portal/correo del canal de derechos sin inventar destinos (D-12).
class DataRightsController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> openPortal(String rawUrl) async {
    if (state) return false;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    final host = ref.read(appConfigProvider).deepLinkHost;
    final policy = ExternalUrlPolicy(extraHttpsHosts: {host});
    if (uri.scheme.toLowerCase() != 'https' || !policy.isAllowed(uri)) {
      return false;
    }
    state = true;
    try {
      return await ref.read(secureBrowserProvider).open(uri);
    } on Object {
      return false;
    } finally {
      if (ref.mounted) state = false;
    }
  }

  Future<bool> openEmail(String email) async {
    try {
      return await ref
          .read(externalLauncherProvider)
          .open(Uri(scheme: 'mailto', path: email));
    } on Object {
      return false;
    }
  }

  Future<bool> retryConfig() async {
    if (state) return false;
    state = true;
    try {
      await ref.read(remoteConfigProvider.notifier).refresh();
    } on Object {
      // Mantiene estado actual.
    } finally {
      if (ref.mounted) state = false;
    }
    return ref.read(dataRightsChannelProvider).hasAny;
  }
}

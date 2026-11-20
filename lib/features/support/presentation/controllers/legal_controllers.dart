import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/support/domain/entities/legal_document.dart';
import 'package:ipr_mobile/features/support/support_providers.dart';

/// Estado: `true` mientras se abre un documento (evita doble lanzamiento).
final legalOpenControllerProvider = NotifierProvider<LegalOpenController, bool>(
  LegalOpenController.new,
);

/// Abre documentos y el correo del canal de derechos.
class LegalOpenController extends Notifier<bool> {
  @override
  bool build() => false;

  /// `null` si ya había una apertura en curso.
  Future<LegalOpenResult?> open(LegalDocument document) async {
    if (state) return null;
    state = true;
    try {
      return await ref.read(legalOpenerProvider).open(document);
    } on Object {
      return LegalOpenResult.failed;
    } finally {
      state = false;
    }
  }

  /// Intenta abrir el cliente de correo. La política de `core` hoy no permite
  /// `mailto:` (ver informe): la pantalla cae a copiar la dirección.
  Future<bool> openEmail(String email) async {
    try {
      return await ref
          .read(externalLauncherProvider)
          .open(Uri(scheme: 'mailto', path: email));
    } on Object {
      return false;
    }
  }
}

/// Estado: `true` mientras se vuelve a pedir `/config`.
final legalRetryControllerProvider =
    NotifierProvider<LegalRetryController, bool>(LegalRetryController.new);

/// "Reintentar" cuando no hay documentos publicados: refresca la
/// configuración remota (falla cerrado: sin documentos no se muestra nada).
class LegalRetryController extends Notifier<bool> {
  @override
  bool build() => false;

  /// `true` si tras refrescar ya hay documentos que mostrar.
  Future<bool> retry() async {
    if (state) return false;
    state = true;
    try {
      await ref.read(remoteConfigProvider.notifier).refresh();
    } on Object {
      // Sin datos nuevos: se mantiene el estado "no disponible".
    } finally {
      state = false;
    }
    return ref.read(legalDocumentsProvider).isNotEmpty;
  }
}

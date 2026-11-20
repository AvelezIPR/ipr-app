import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/logout_controller.dart';
import 'package:ipr_mobile/features/profile/presentation/widgets/account_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Pestaña Cuenta (`/account`, PT-13): RF-041, RF-099, RF-037.
///
/// La misma ruta cambia de contenido según la sesión: invitado (acceso,
/// registro, legales, ayuda) o con sesión (accesos de M4 y "Cerrar sesión").
/// No pide ni muestra datos personales: el perfil llega en M4 (RF-104).
class AccountScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return SafeArea(
      bottom: false,
      child: switch (session) {
        SessionUnknown() => const LoadingState(),
        SessionAuthenticated() => const _SignedInView(),
        SessionAnonymous() => const _GuestView(),
        SessionExpired() => const _GuestView(expired: true),
      },
    );
  }
}

const _pagePadding = EdgeInsets.fromLTRB(
  IprSpace.s4,
  IprSpace.s4,
  IprSpace.s4,
  IprSpace.s6,
);

/// Ayuda e información, común a invitado y cliente.
class _HelpSection extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AccountSectionTitle(l10n.profileSectionHelp),
        AccountTile(
          icon: Icons.description_outlined,
          label: l10n.profileLegal,
          onTap: () => unawaited(context.push(Routes.legal)),
        ),
        const SizedBox(height: IprSpace.s3),
        WhatsAppButton(
          label: l10n.sharedWhatsappAdvice,
          message: l10n.sharedWhatsappMsgAdvice,
          filled: false,
        ),
      ],
    );
  }
}

class _GuestView extends StatelessWidget {
  const new({this.expired = false});

  /// La sesión terminó (401 tras refrescar): se explica sin culpar al usuario.
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: _pagePadding,
      children: [
        AccountHeader(
          icon: Icons.person_outline,
          title: l10n.profileGuestTitle,
          body: l10n.profileGuestBody,
        ),
        if (expired) ...[
          const SizedBox(height: IprSpace.s3),
          Semantics(
            liveRegion: true,
            container: true,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: IprSpace.s2),
                Expanded(child: Text(l10n.failureUnauthorized)),
              ],
            ),
          ),
        ],
        const SizedBox(height: IprSpace.s4),
        FilledButton(
          onPressed: () => unawaited(context.push(Routes.login)),
          child: Text(l10n.profileLogin),
        ),
        const SizedBox(height: IprSpace.s3),
        OutlinedButton(
          onPressed: () => unawaited(context.push(Routes.register)),
          child: Text(l10n.profileRegister),
        ),
        const _HelpSection(),
      ],
    );
  }
}

class _SignedInView extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final loggingOut = ref.watch(logoutControllerProvider);

    void go(String route) => unawaited(context.push(route));

    return ListView(
      padding: _pagePadding,
      children: [
        AccountHeader(
          icon: Icons.verified_user_outlined,
          title: l10n.profileSignedInTitle,
          body: l10n.profileSignedInBody,
        ),
        AccountSectionTitle(l10n.profileSectionAccount),
        AccountTile(
          icon: Icons.receipt_long_outlined,
          label: l10n.profileOrders,
          onTap: () => go(Routes.orders),
        ),
        AccountTile(
          icon: Icons.badge_outlined,
          label: l10n.profileData,
          onTap: () => go(Routes.profile),
        ),
        AccountTile(
          icon: Icons.location_on_outlined,
          label: l10n.profileAddresses,
          onTap: () => go(Routes.addresses),
        ),
        AccountTile(
          icon: Icons.privacy_tip_outlined,
          label: l10n.profileDataRights,
          onTap: () => go(Routes.dataRights),
        ),
        AccountTile(
          icon: Icons.delete_outline,
          label: l10n.profileDeleteAccount,
          onTap: () => go(Routes.deleteAccount),
        ),
        const _HelpSection(),
        const SizedBox(height: IprSpace.s5),
        Semantics(
          liveRegion: loggingOut,
          child: OutlinedButton.icon(
            onPressed: loggingOut
                ? null
                : () => unawaited(_logout(context, ref)),
            icon: const ExcludeSemantics(child: Icon(Icons.logout)),
            label: Text(
              loggingOut ? l10n.profileLoggingOut : l10n.profileLogout,
            ),
          ),
        ),
      ],
    );
  }

  /// Cierra la sesión y avisa. La pantalla pasa sola a modo invitado cuando
  /// `core` limpia la sesión, así que el aviso usa el `ScaffoldMessenger`
  /// capturado antes de esperar (el botón ya no estará montado).
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final outcome = await ref.read(logoutControllerProvider.notifier).logout();
    final message = switch (outcome) {
      LogoutOutcome.done => l10n.profileLoggedOut,
      LogoutOutcome.failed => l10n.profileLogoutFailed,
      LogoutOutcome.ignored => null,
    };
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

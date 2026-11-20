import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/profile_controllers.dart';
import 'package:ipr_mobile/features/profile/presentation/widgets/account_widgets.dart';
import 'package:ipr_mobile/features/profile/presentation/widgets/profile_form_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Ver y editar nombre, apellido y correo (`/account/profile`, RF-104).
class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileState = ref.watch(profileDataProvider);

    return ProfileFormScaffold(
      title: l10n.profileScreenTitle,
      body: AsyncView<UserProfile>(
        state: profileState,
        onRetry: ref.read(profileDataProvider.notifier).load,
        builder: (context, profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const new({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  final TextEditingController _currentPassword = TextEditingController();
  String? _seededForEmail;
  String? _seededFirst;
  String? _seededLast;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.profile.firstName);
    _lastName = TextEditingController(text: widget.profile.lastName);
    _email = TextEditingController(text: widget.profile.email);
    _seededFirst = widget.profile.firstName;
    _seededLast = widget.profile.lastName;
    _seededForEmail = widget.profile.email;
  }

  @override
  void didUpdateWidget(covariant _ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza los controladores solo cuando el servidor trajo cambios
    // confirmados distintos de lo sembrado (sin pisar ediciones en curso).
    if (widget.profile.firstName != _seededFirst) {
      _firstName.text = widget.profile.firstName;
      _seededFirst = widget.profile.firstName;
    }
    if (widget.profile.lastName != _seededLast) {
      _lastName.text = widget.profile.lastName;
      _seededLast = widget.profile.lastName;
    }
    if (widget.profile.email != _seededForEmail) {
      _email.text = widget.profile.email;
      _seededForEmail = widget.profile.email;
    }
  }

  @override
  void dispose() {
    _currentPassword
      ..clear()
      ..dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _saveNames() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(profileEditProvider.notifier)
        .saveNames(firstName: _firstName.text, lastName: _lastName.text);
    if (!mounted || !ok) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.profileNamesSaved)));
  }

  Future<void> _changeEmail() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(profileEditProvider.notifier)
        .changeEmail(
          currentEmail: widget.profile.email,
          newEmail: _email.text,
          currentPassword: _currentPassword.text,
        );
    if (!mounted) return;
    _currentPassword.clear();
    if (!ok) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.profileEmailSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final editState = ref.watch(profileEditProvider);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(IprSpace.s4),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileFailureBanner(state: editState),
            Semantics(
              header: true,
              child: Text(
                l10n.profileNamesSection,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            TextField(
              controller: _firstName,
              autofillHints: const [AutofillHints.givenName],
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.profileFirstNameLabel,
                errorText: profileFieldError(
                  l10n,
                  editState,
                  ProfileField.firstName,
                ),
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            TextField(
              controller: _lastName,
              autofillHints: const [AutofillHints.familyName],
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.profileLastNameLabel,
                errorText: profileFieldError(
                  l10n,
                  editState,
                  ProfileField.lastName,
                ),
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: IprSpace.s4),
            ProfileSubmitButton(
              label: l10n.profileSaveNames,
              state: editState,
              onPressed: () => unawaited(_saveNames()),
            ),
            const Divider(height: IprSpace.s7),
            Semantics(
              header: true,
              child: Text(
                l10n.profileEmailSection,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            TextField(
              controller: _email,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.profileEmailLabel,
                errorText: profileFieldError(
                  l10n,
                  editState,
                  ProfileField.email,
                ),
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            ProfilePasswordField(
              controller: _currentPassword,
              label: l10n.profileCurrentPasswordLabel,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              errorText: profileFieldError(
                l10n,
                editState,
                ProfileField.currentPassword,
              ),
              onSubmitted: (_) => unawaited(_changeEmail()),
            ),
            const SizedBox(height: IprSpace.s4),
            ProfileSubmitButton(
              label: l10n.profileSaveEmail,
              state: editState,
              onPressed: () => unawaited(_changeEmail()),
            ),
            const Divider(height: IprSpace.s7),
            AccountTile(
              icon: Icons.lock_outline,
              label: l10n.profileChangePasswordTile,
              onTap: () => unawaited(context.push(Routes.changePassword)),
            ),
            AccountTile(
              icon: Icons.privacy_tip_outlined,
              label: l10n.profileDataRights,
              onTap: () => unawaited(context.push(Routes.dataRights)),
            ),
          ],
        ),
      ),
    );
  }
}

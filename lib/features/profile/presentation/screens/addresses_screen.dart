import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/profile/domain/rules/colombia_locations.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/profile_controllers.dart';
import 'package:ipr_mobile/features/profile/presentation/widgets/profile_form_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Gestión de direcciones de facturación y envío (`/account/addresses`, RF-106).
class AddressesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileState = ref.watch(profileDataProvider);

    return ProfileFormScaffold(
      title: l10n.profileAddressesTitle,
      body: AsyncView<UserProfile>(
        state: profileState,
        onRetry: ref.read(profileDataProvider.notifier).load,
        builder: (context, profile) => _AddressesBody(profile: profile),
      ),
    );
  }
}

class _AddressesBody extends ConsumerStatefulWidget {
  const new({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_AddressesBody> createState() => _AddressesBodyState();
}

class _AddressesBodyState extends ConsumerState<_AddressesBody> {
  AddressType _type = AddressType.billing;

  final _nationalId = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _company = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _postcode = TextEditingController();
  final _phone = TextEditingController();
  String? _department;
  String? _city;

  @override
  void initState() {
    super.initState();
    _seedFrom(_addressFor(_type));
  }

  Address? _addressFor(AddressType type) => type == AddressType.billing
      ? widget.profile.billing
      : widget.profile.shipping;

  void _seedFrom(Address? address) {
    _nationalId.text = address?.nationalId ?? '';
    _firstName.text = address?.firstName ?? '';
    _lastName.text = address?.lastName ?? '';
    _company.text = address?.company ?? '';
    _address1.text = address?.address1 ?? '';
    _address2.text = address?.address2 ?? '';
    _postcode.text = address?.postcode ?? '';
    _phone.text = address?.phone ?? '';

    final dept = address?.department.trim() ?? '';
    _department = isDepartmentCode(dept) ? dept : null;
    final rawCity = address?.city.trim() ?? '';
    if (_department != null && rawCity.isNotEmpty) {
      final matches = citiesOf(_department!)
          .where((c) => c.toLowerCase() == rawCity.toLowerCase());
      _city = matches.isEmpty ? null : matches.first;
    } else {
      _city = null;
    }
  }

  @override
  void dispose() {
    _nationalId.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _company.dispose();
    _address1.dispose();
    _address2.dispose();
    _postcode.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final input = AddressInput(
      nationalId: _nationalId.text,
      firstName: _firstName.text,
      lastName: _lastName.text,
      company: _company.text,
      address1: _address1.text,
      address2: _address2.text,
      department: _department ?? '',
      city: _city ?? '',
      postcode: _postcode.text,
      phone: _phone.text,
    );
    final ok = await ref
        .read(addressEditProvider.notifier)
        .save(type: _type, input: input);
    if (!mounted || !ok) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.profileAddressSaved)));
  }

  void _switchType(AddressType next) {
    if (next == _type) return;
    ref.read(addressEditProvider.notifier).clearStatus();
    setState(() {
      _type = next;
      _seedFrom(_addressFor(next));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(addressEditProvider);
    final isBilling = _type == AddressType.billing;
    final cities = _department == null
        ? const <String>[]
        : citiesOf(_department!);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(IprSpace.s4),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileFailureBanner(state: state),
            SegmentedButton<AddressType>(
              segments: [
                ButtonSegment(
                  value: AddressType.billing,
                  label: Text(l10n.profileAddressBillingTab),
                ),
                ButtonSegment(
                  value: AddressType.shipping,
                  label: Text(l10n.profileAddressShippingTab),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) _switchType(set.first);
              },
            ),
            const SizedBox(height: IprSpace.s4),
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.public,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: IprSpace.s2),
                Expanded(
                  child: Text(
                    l10n.profileAddressCountryLabel,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: IprSpace.s4),
            TextField(
              controller: _nationalId,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: isBilling
                    ? l10n.profileAddressNationalIdLabel
                    : l10n.profileAddressNationalIdOptionalLabel,
                errorText: profileFieldError(
                  l10n,
                  state,
                  ProfileField.nationalId,
                ),
                errorMaxLines: 4,
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
                  state,
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
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.profileLastNameLabel,
                errorText: profileFieldError(
                  l10n,
                  state,
                  ProfileField.lastName,
                ),
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            TextField(
              controller: _company,
              autofillHints: const [AutofillHints.organizationName],
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.profileAddressCompanyLabel,
                errorText: profileFieldError(l10n, state, ProfileField.company),
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            TextField(
              controller: _address1,
              autofillHints: const [AutofillHints.streetAddressLine1],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.profileAddressLine1Label,
                errorText: profileFieldError(
                  l10n,
                  state,
                  ProfileField.address1,
                ),
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            TextField(
              controller: _address2,
              autofillHints: const [AutofillHints.streetAddressLine2],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.profileAddressLine2Label,
                errorText: profileFieldError(
                  l10n,
                  state,
                  ProfileField.address2,
                ),
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            DropdownButtonFormField<String>(
              key: ValueKey('dept-${_type.name}-$_department'),
              initialValue: _department,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.profileAddressDepartmentLabel,
                errorText: profileFieldError(
                  l10n,
                  state,
                  ProfileField.department,
                ),
                errorMaxLines: 4,
              ),
              items: [
                for (final dept in colombiaDepartments)
                  DropdownMenuItem(value: dept.code, child: Text(dept.name)),
              ],
              onChanged: (value) {
                if (value == _department) return;
                setState(() {
                  _department = value;
                  _city = null;
                });
              },
            ),
            const SizedBox(height: IprSpace.s3),
            DropdownButtonFormField<String>(
              key: ValueKey('city-${_type.name}-$_department-$_city'),
              initialValue: _city,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.profileAddressCityLabel,
                hintText: _department == null
                    ? l10n.profileAddressCitySelectFirst
                    : null,
                errorText: profileFieldError(l10n, state, ProfileField.city),
                errorMaxLines: 4,
              ),
              items: [
                for (final city in cities)
                  DropdownMenuItem(value: city, child: Text(city)),
              ],
              onChanged: cities.isEmpty
                  ? null
                  : (value) => setState(() => _city = value),
            ),
            const SizedBox(height: IprSpace.s3),
            TextField(
              controller: _postcode,
              autofillHints: const [AutofillHints.postalCode],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.profileAddressPostcodeLabel,
                errorText: profileFieldError(
                  l10n,
                  state,
                  ProfileField.postcode,
                ),
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            TextField(
              controller: _phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: isBilling
                    ? l10n.profileAddressPhoneLabel
                    : l10n.profileAddressPhoneOptionalLabel,
                errorText: profileFieldError(l10n, state, ProfileField.phone),
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: IprSpace.s5),
            ProfileSubmitButton(
              label: isBilling
                  ? l10n.profileAddressSaveBilling
                  : l10n.profileAddressSaveShipping,
              state: state,
              onPressed: () => unawaited(_save()),
            ),
          ],
        ),
      ),
    );
  }
}

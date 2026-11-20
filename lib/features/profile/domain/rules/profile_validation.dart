import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/profile/domain/rules/colombia_locations.dart';

enum ProfileField {
  firstName,
  lastName,
  email,
  currentPassword,
  newPassword,
  confirmPassword,
  nationalId,
  company,
  address1,
  address2,
  department,
  city,
  postcode,
  phone,
  deleteConfirm;

  static ProfileField? fromServer(String field) {
    final last = field.trim().split('.').last.toLowerCase();
    return switch (last) {
      'firstname' => firstName,
      'lastname' => lastName,
      'email' || 'newemail' => email,
      'currentpassword' => currentPassword,
      'newpassword' => newPassword,
      'confirmpassword' => confirmPassword,
      'nationalid' => nationalId,
      'company' => company,
      'address1' => address1,
      'address2' => address2,
      'department' => department,
      'city' => city,
      'postcode' => postcode,
      'phone' => phone,
      'confirm' => deleteConfirm,
      _ => null,
    };
  }
}

enum ProfileFieldIssue {
  required,
  tooLong,
  emailInvalid,
  emailUnchanged,
  passwordTooShort,
  passwordMismatch,
  nationalIdInvalid,
  phoneInvalid,
  departmentInvalid,
  cityInvalid,
  confirmationRequired,
}

/// Límites del contrato (`UpdateProfileRequest`, `ChangeEmailRequest`,
/// `ChangePasswordRequest`, `AddressInput`, `AccountDeletionRequest`).
abstract final class ProfileLimits {
  static const nameMax = 60;
  static const emailMax = 120;
  static const passwordMin = 8;
  static const passwordMax = 128;
  static const nationalIdMin = 3;
  static const nationalIdMax = 30;
  static const companyMax = 120;
  static const addressMax = 200;
  static const cityMax = 80;
  static const postcodeMax = 20;
  static const phoneMin = 7;
  static const phoneMax = 20;

  static int maxFor(ProfileField field) => switch (field) {
    ProfileField.firstName || ProfileField.lastName => nameMax,
    ProfileField.email => emailMax,
    ProfileField.currentPassword ||
    ProfileField.newPassword ||
    ProfileField.confirmPassword => passwordMax,
    ProfileField.nationalId => nationalIdMax,
    ProfileField.company => companyMax,
    ProfileField.address1 || ProfileField.address2 => addressMax,
    ProfileField.department => 3,
    ProfileField.city => cityMax,
    ProfileField.postcode => postcodeMax,
    ProfileField.phone => phoneMax,
    ProfileField.deleteConfirm => 0,
  };
}

int _length(String value) => value.runes.length;

/// Validación local previa al envío (nunca sustituye la del servidor).
abstract final class ProfileValidation {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _nationalId = RegExp(r'^[\d.\-]+$');
  static final _phone = RegExp(r'^[\d\s+\-().]{7,20}$');

  static ProfileFieldIssue? name(String value) {
    final text = value.trim();
    if (text.isEmpty) return ProfileFieldIssue.required;
    if (_length(text) > ProfileLimits.nameMax) return ProfileFieldIssue.tooLong;
    return null;
  }

  static ProfileFieldIssue? email(String value, {String? currentEmail}) {
    final text = value.trim();
    if (text.isEmpty) return ProfileFieldIssue.required;
    if (_length(text) > ProfileLimits.emailMax) {
      return ProfileFieldIssue.tooLong;
    }
    if (!_email.hasMatch(text)) return ProfileFieldIssue.emailInvalid;
    if (currentEmail != null &&
        text.toLowerCase() == currentEmail.trim().toLowerCase()) {
      return ProfileFieldIssue.emailUnchanged;
    }
    return null;
  }

  static ProfileFieldIssue? currentPassword(String value) {
    if (value.isEmpty) return ProfileFieldIssue.required;
    if (_length(value) > ProfileLimits.passwordMax) {
      return ProfileFieldIssue.tooLong;
    }
    return null;
  }

  static ProfileFieldIssue? newPassword(String value) {
    if (value.isEmpty) return ProfileFieldIssue.required;
    if (_length(value) < ProfileLimits.passwordMin) {
      return ProfileFieldIssue.passwordTooShort;
    }
    if (_length(value) > ProfileLimits.passwordMax) {
      return ProfileFieldIssue.tooLong;
    }
    return null;
  }

  static ProfileFieldIssue? confirmPassword(String password, String confirm) {
    if (confirm.isEmpty) return ProfileFieldIssue.required;
    if (confirm != password) return ProfileFieldIssue.passwordMismatch;
    return null;
  }

  static ProfileFieldIssue? nationalId(String value, {required bool required}) {
    final text = value.trim();
    if (text.isEmpty) return required ? ProfileFieldIssue.required : null;
    if (_length(text) > ProfileLimits.nationalIdMax) {
      return ProfileFieldIssue.tooLong;
    }
    if (_length(text) < ProfileLimits.nationalIdMin ||
        !_nationalId.hasMatch(text)) {
      return ProfileFieldIssue.nationalIdInvalid;
    }
    return null;
  }

  static ProfileFieldIssue? phone(String value, {required bool required}) {
    final text = value.trim();
    if (text.isEmpty) return required ? ProfileFieldIssue.required : null;
    if (_length(text) > ProfileLimits.phoneMax) {
      return ProfileFieldIssue.tooLong;
    }
    if (_length(text) < ProfileLimits.phoneMin || !_phone.hasMatch(text)) {
      return ProfileFieldIssue.phoneInvalid;
    }
    return null;
  }

  static ProfileFieldIssue? requiredText(String value, int max) {
    final text = value.trim();
    if (text.isEmpty) return ProfileFieldIssue.required;
    if (_length(text) > max) return ProfileFieldIssue.tooLong;
    return null;
  }

  static ProfileFieldIssue? optionalText(String value, int max) {
    final text = value.trim();
    if (text.isEmpty) return null;
    if (_length(text) > max) return ProfileFieldIssue.tooLong;
    return null;
  }

  static Map<ProfileField, ProfileFieldIssue> forNames({
    required String firstName,
    required String lastName,
  }) => _collect({
    ProfileField.firstName: name(firstName),
    ProfileField.lastName: name(lastName),
  });

  static Map<ProfileField, ProfileFieldIssue> forEmailChange({
    required String currentEmail,
    required String newEmail,
    required String currentPassword,
  }) => _collect({
    ProfileField.email: email(newEmail, currentEmail: currentEmail),
    ProfileField.currentPassword: ProfileValidation.currentPassword(
      currentPassword,
    ),
  });

  static Map<ProfileField, ProfileFieldIssue> forPasswordChange({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) => _collect({
    ProfileField.currentPassword: ProfileValidation.currentPassword(
      currentPassword,
    ),
    ProfileField.newPassword: ProfileValidation.newPassword(newPassword),
    ProfileField.confirmPassword: ProfileValidation.confirmPassword(
      newPassword,
      confirmPassword,
    ),
  });

  static Map<ProfileField, ProfileFieldIssue> forAddress({
    required AddressType type,
    required AddressInput input,
  }) {
    final isBilling = type == AddressType.billing;
    final dept = input.department.trim();
    final deptValid = isDepartmentCode(dept);
    final cityText = input.city.trim();
    ProfileFieldIssue? cityIssue;
    if (cityText.isEmpty) {
      cityIssue = ProfileFieldIssue.required;
    } else if (_length(cityText) > ProfileLimits.cityMax) {
      cityIssue = ProfileFieldIssue.tooLong;
    } else if (deptValid &&
        !citiesOf(dept).any((c) => c.toLowerCase() == cityText.toLowerCase())) {
      cityIssue = ProfileFieldIssue.cityInvalid;
    }
    return _collect({
      ProfileField.nationalId: nationalId(
        input.nationalId,
        required: isBilling,
      ),
      ProfileField.firstName: name(input.firstName),
      ProfileField.lastName: name(input.lastName),
      ProfileField.company: optionalText(
        input.company,
        ProfileLimits.companyMax,
      ),
      ProfileField.address1: requiredText(
        input.address1,
        ProfileLimits.addressMax,
      ),
      ProfileField.address2: optionalText(
        input.address2,
        ProfileLimits.addressMax,
      ),
      ProfileField.department: deptValid
          ? null
          : (dept.isEmpty
                ? ProfileFieldIssue.required
                : ProfileFieldIssue.departmentInvalid),
      ProfileField.city: cityIssue,
      ProfileField.postcode: optionalText(
        input.postcode,
        ProfileLimits.postcodeMax,
      ),
      ProfileField.phone: phone(input.phone, required: isBilling),
    });
  }

  static Map<ProfileField, ProfileFieldIssue> forDeletion({
    required bool confirmed,
    required String currentPassword,
  }) => _collect({
    ProfileField.deleteConfirm: confirmed
        ? null
        : ProfileFieldIssue.confirmationRequired,
    ProfileField.currentPassword: ProfileValidation.currentPassword(
      currentPassword,
    ),
  });

  static Map<ProfileField, ProfileFieldIssue> _collect(
    Map<ProfileField, ProfileFieldIssue?> issues,
  ) => {
    for (final entry in issues.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
}

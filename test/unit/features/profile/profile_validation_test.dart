import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/profile/domain/rules/colombia_locations.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';

void main() {
  group(
    'TC-093 · AC-104-5 · AC-105-4 · validaciones de perfil y contraseña',
    () {
      test('nombre y apellido obligatorios y <= 60 caracteres', () {
        expect(
          ProfileValidation.forNames(firstName: '  ', lastName: 'A' * 61),
          {
            ProfileField.firstName: ProfileFieldIssue.required,
            ProfileField.lastName: ProfileFieldIssue.tooLong,
          },
        );
        expect(
          ProfileValidation.forNames(firstName: 'Ana', lastName: 'Prueba'),
          isEmpty,
        );
      });

      test(
        'cambio de correo exige formato válido, distinto y contraseña actual',
        () {
          expect(
            ProfileValidation.forEmailChange(
              currentEmail: 'qa@example.test',
              newEmail: 'invalido',
              currentPassword: '',
            ),
            {
              ProfileField.email: ProfileFieldIssue.emailInvalid,
              ProfileField.currentPassword: ProfileFieldIssue.required,
            },
          );
          expect(
            ProfileValidation.forEmailChange(
              currentEmail: 'qa@example.test',
              newEmail: 'QA@EXAMPLE.TEST',
              currentPassword: 'Password123',
            ),
            {ProfileField.email: ProfileFieldIssue.emailUnchanged},
          );
          expect(
            ProfileValidation.forEmailChange(
              currentEmail: 'qa@example.test',
              newEmail: 'nuevo@example.test',
              currentPassword: 'Password123',
            ),
            isEmpty,
          );
        },
      );

      test('contraseña nueva 7 caracteres o confirmación distinta se rechazan; 8 iguales pasan', () {
        expect(
          ProfileValidation.forPasswordChange(
            currentPassword: 'OldPassword',
            newPassword: 'Qa12345',
            confirmPassword: 'Qa123456',
          ),
          {
            ProfileField.newPassword: ProfileFieldIssue.passwordTooShort,
            ProfileField.confirmPassword: ProfileFieldIssue.passwordMismatch,
          },
        );
        expect(
          ProfileValidation.forPasswordChange(
            currentPassword: 'OldPassword',
            newPassword: 'Qa123456',
            confirmPassword: 'Qa123456',
          ),
          isEmpty,
        );
      });
    },
  );

  group(
    'TC-096 · AC-106-2 · AC-106-3 · validaciones de direcciones y Colombia',
    () {
      AddressInput validBilling() => const AddressInput(
        nationalId: '000-000-001',
        firstName: 'Ana',
        lastName: 'Prueba',
        address1: 'Calle 10 # 20-30',
        department: 'ANT',
        city: 'Medellín',
        phone: '3000000000',
      );

      test('billing válido pasa', () {
        expect(
          ProfileValidation.forAddress(
            type: AddressType.billing,
            input: validBilling(),
          ),
          isEmpty,
        );
      });

      test(
        'cédula/NIT ab o 31 chars, nombre 61, dir 201 y teléfono 6/21 fallan',
        () {
          expect(
            ProfileValidation.forAddress(
              type: AddressType.billing,
              input: AddressInput(
                nationalId: 'ab',
                firstName: 'A' * 61,
                lastName: 'Prueba',
                address1: 'B' * 201,
                department: 'ANT',
                city: 'Medellín',
                phone: '123456',
              ),
            ),
            {
              ProfileField.nationalId: ProfileFieldIssue.nationalIdInvalid,
              ProfileField.firstName: ProfileFieldIssue.tooLong,
              ProfileField.address1: ProfileFieldIssue.tooLong,
              ProfileField.phone: ProfileFieldIssue.phoneInvalid,
            },
          );

          expect(
            ProfileValidation.forAddress(
              type: AddressType.billing,
              input: AddressInput(
                nationalId: '1' * 31,
                firstName: 'Ana',
                lastName: 'Prueba',
                address1: 'Calle 10',
                department: 'BOG',
                city: 'Bogotá',
                phone: '3' * 21,
              ),
            ),
            {
              ProfileField.nationalId: ProfileFieldIssue.tooLong,
              ProfileField.phone: ProfileFieldIssue.tooLong,
            },
          );
        },
      );

      test('la ciudad debe pertenecer al departamento elegido', () {
        expect(
          ProfileValidation.forAddress(
            type: AddressType.shipping,
            input: const AddressInput(
              firstName: 'Ana',
              lastName: 'Prueba',
              address1: 'Calle 10',
              department: 'ANT',
              city: 'Bogotá',
            ),
          ),
          {ProfileField.city: ProfileFieldIssue.cityInvalid},
        );
        expect(citiesOf('BOG'), ['Bogotá']);
        expect(departmentName('ANT'), 'Antioquia');
      });

      test('ProfileField.fromServer mapea campos anidados y planos', () {
        expect(
          ProfileField.fromServer('body.currentPassword'),
          ProfileField.currentPassword,
        );
        expect(ProfileField.fromServer('newEmail'), ProfileField.email);
        expect(ProfileField.fromServer('confirm'), ProfileField.deleteConfirm);
        expect(ProfileField.fromServer('unknown'), isNull);
      });
    },
  );

  group('TC-088 · validación de eliminación', () {
    test('exige confirmación explícita y contraseña actual', () {
      expect(
        ProfileValidation.forDeletion(confirmed: false, currentPassword: ''),
        {
          ProfileField.deleteConfirm: ProfileFieldIssue.confirmationRequired,
          ProfileField.currentPassword: ProfileFieldIssue.required,
        },
      );
      expect(
        ProfileValidation.forDeletion(
          confirmed: true,
          currentPassword: 'QaPassword123',
        ),
        isEmpty,
      );
    });
  });
}

import 'package:ipr_mobile/features/profile/data/dtos/profile_dtos.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/shared/formatting/date_format.dart';

Address mapAddress(AddressDto dto) => Address(
  firstName: dto.firstName,
  lastName: dto.lastName,
  company: dto.company,
  nationalId: dto.nationalId,
  address1: dto.address1,
  address2: dto.address2,
  department: dto.department,
  city: dto.city,
  postcode: dto.postcode,
  phone: dto.phone,
);

UserProfile mapUserProfile(UserProfileDto dto) => UserProfile(
  id: dto.id,
  email: dto.email,
  firstName: dto.firstName,
  lastName: dto.lastName,
  displayName: dto.displayName,
  billing: dto.billing == null ? null : mapAddress(dto.billing!),
  shipping: dto.shipping == null ? null : mapAddress(dto.shipping!),
);

EmailChangeResult mapEmailChange(ChangeEmailResponseDto dto) =>
    EmailChangeResult(tokens: dto.tokens, profile: mapUserProfile(dto.user));

AddressInputDto addressInputDtoOf(AddressInput input) => AddressInputDto(
  nationalId: input.nationalId.trim(),
  firstName: input.firstName.trim(),
  lastName: input.lastName.trim(),
  company: input.company.trim(),
  address1: input.address1.trim(),
  address2: input.address2.trim(),
  department: input.department.trim(),
  city: input.city.trim(),
  postcode: input.postcode.trim(),
  phone: input.phone.trim(),
);

AccountDeletionStatus mapAccountDeletionStatus(AccountDeletionStatusDto dto) =>
    AccountDeletionStatus(
      requestId: dto.requestId,
      status: AccountDeletionState.fromContract(dto.status),
      completeBy: tryParseServerDate(dto.completeBy),
    );

import 'package:json_annotation/json_annotation.dart';

part 'profile_update_dto.g.dart';

/// Request body for PATCH /v1/applicants/me. The edit form owns the full
/// editable set, so all keys are sent every save — including explicit nulls
/// for cleared fields (default includeIfNull: true), so clearing persists.
/// `full_name`/`locations` are always non-null from the form.
@JsonSerializable(createFactory: false, includeIfNull: true)
class ProfileUpdateDto {
  const ProfileUpdateDto({
    required this.fullName,
    required this.locations,
    this.noticePeriodDays,
    this.currentCtc,
    this.expectedCtc,
    this.yearsExperience,
  });

  @JsonKey(name: 'full_name')
  final String fullName;
  final List<String> locations;
  // Sent as JSON numbers; the backend's Decimal fields coerce from number.
  @JsonKey(name: 'notice_period_days')
  final int? noticePeriodDays;
  @JsonKey(name: 'current_ctc')
  final num? currentCtc;
  @JsonKey(name: 'expected_ctc')
  final num? expectedCtc;
  @JsonKey(name: 'years_experience')
  final num? yearsExperience;

  Map<String, dynamic> toJson() => _$ProfileUpdateDtoToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'me_dto.g.dart';

@JsonSerializable()
class MeDto {
  const MeDto({
    required this.user,
    this.applicant,
  });

  factory MeDto.fromJson(Map<String, dynamic> json) => _$MeDtoFromJson(json);

  final MeUserDto user;
  final ApplicantSummaryDto? applicant;

  Map<String, dynamic> toJson() => _$MeDtoToJson(this);
}

@JsonSerializable()
class MeUserDto {
  const MeUserDto({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.displayName,
  });

  factory MeUserDto.fromJson(Map<String, dynamic> json) =>
      _$MeUserDtoFromJson(json);

  final String id;
  final String email;
  final String role;
  final DateTime createdAt;
  final String? displayName;

  Map<String, dynamic> toJson() => _$MeUserDtoToJson(this);
}

@JsonSerializable()
class ApplicantSummaryDto {
  const ApplicantSummaryDto({
    required this.id,
    required this.userId,
  });

  factory ApplicantSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$ApplicantSummaryDtoFromJson(json);

  final String id;
  final String userId;

  Map<String, dynamic> toJson() => _$ApplicantSummaryDtoToJson(this);
}

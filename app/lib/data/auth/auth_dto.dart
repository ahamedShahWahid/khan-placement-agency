import 'package:json_annotation/json_annotation.dart';

part 'auth_dto.g.dart';

@JsonSerializable()
class SignInResponseDto {
  const SignInResponseDto({
    required this.access,
    required this.refresh,
    required this.user,
    this.applicant,
  });

  factory SignInResponseDto.fromJson(Map<String, dynamic> json) =>
      _$SignInResponseDtoFromJson(json);

  final String access;
  final String refresh;
  final AuthUserDto user;
  final AuthApplicantDto? applicant;

  Map<String, dynamic> toJson() => _$SignInResponseDtoToJson(this);
}

@JsonSerializable()
class RefreshResponseDto {
  const RefreshResponseDto({
    required this.access,
    required this.refresh,
  });

  factory RefreshResponseDto.fromJson(Map<String, dynamic> json) =>
      _$RefreshResponseDtoFromJson(json);

  final String access;
  final String refresh;

  Map<String, dynamic> toJson() => _$RefreshResponseDtoToJson(this);
}

@JsonSerializable()
class AuthUserDto {
  const AuthUserDto({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
  });

  factory AuthUserDto.fromJson(Map<String, dynamic> json) =>
      _$AuthUserDtoFromJson(json);

  final String id;
  final String email;
  final String role;
  final String? displayName;

  Map<String, dynamic> toJson() => _$AuthUserDtoToJson(this);
}

@JsonSerializable()
class AuthApplicantDto {
  const AuthApplicantDto({
    required this.id,
    required this.userId,
  });

  factory AuthApplicantDto.fromJson(Map<String, dynamic> json) =>
      _$AuthApplicantDtoFromJson(json);

  final String id;
  final String userId;

  Map<String, dynamic> toJson() => _$AuthApplicantDtoToJson(this);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SignInResponseDto _$SignInResponseDtoFromJson(Map<String, dynamic> json) =>
    SignInResponseDto(
      access: json['access'] as String,
      refresh: json['refresh'] as String,
      user: AuthUserDto.fromJson(json['user'] as Map<String, dynamic>),
      applicant: json['applicant'] == null
          ? null
          : AuthApplicantDto.fromJson(
              json['applicant'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SignInResponseDtoToJson(SignInResponseDto instance) =>
    <String, dynamic>{
      'access': instance.access,
      'refresh': instance.refresh,
      'user': instance.user.toJson(),
      'applicant': instance.applicant?.toJson(),
    };

RefreshResponseDto _$RefreshResponseDtoFromJson(Map<String, dynamic> json) =>
    RefreshResponseDto(
      access: json['access'] as String,
      refresh: json['refresh'] as String,
    );

Map<String, dynamic> _$RefreshResponseDtoToJson(RefreshResponseDto instance) =>
    <String, dynamic>{
      'access': instance.access,
      'refresh': instance.refresh,
    };

AuthUserDto _$AuthUserDtoFromJson(Map<String, dynamic> json) => AuthUserDto(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      displayName: json['display_name'] as String?,
    );

Map<String, dynamic> _$AuthUserDtoToJson(AuthUserDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'role': instance.role,
      'display_name': instance.displayName,
    };

AuthApplicantDto _$AuthApplicantDtoFromJson(Map<String, dynamic> json) =>
    AuthApplicantDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
    );

Map<String, dynamic> _$AuthApplicantDtoToJson(AuthApplicantDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
    };

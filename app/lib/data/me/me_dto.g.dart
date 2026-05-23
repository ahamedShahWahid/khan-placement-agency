// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MeDto _$MeDtoFromJson(Map<String, dynamic> json) => MeDto(
      user: MeUserDto.fromJson(json['user'] as Map<String, dynamic>),
      applicant: json['applicant'] == null
          ? null
          : ApplicantSummaryDto.fromJson(
              json['applicant'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MeDtoToJson(MeDto instance) => <String, dynamic>{
      'user': instance.user.toJson(),
      'applicant': instance.applicant?.toJson(),
    };

MeUserDto _$MeUserDtoFromJson(Map<String, dynamic> json) => MeUserDto(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      displayName: json['display_name'] as String?,
    );

Map<String, dynamic> _$MeUserDtoToJson(MeUserDto instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'role': instance.role,
      'created_at': instance.createdAt.toIso8601String(),
      'display_name': instance.displayName,
    };

ApplicantSummaryDto _$ApplicantSummaryDtoFromJson(Map<String, dynamic> json) =>
    ApplicantSummaryDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
    );

Map<String, dynamic> _$ApplicantSummaryDtoToJson(
        ApplicantSummaryDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
    };

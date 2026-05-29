// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dsr_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OwnerlessEmployerWarningDto _$OwnerlessEmployerWarningDtoFromJson(
        Map<String, dynamic> json) =>
    OwnerlessEmployerWarningDto(
      type: json['type'] as String,
      employerId: json['employer_id'] as String,
      employerName: json['employer_name'] as String,
      message: json['message'] as String,
    );

Map<String, dynamic> _$OwnerlessEmployerWarningDtoToJson(
        OwnerlessEmployerWarningDto instance) =>
    <String, dynamic>{
      'type': instance.type,
      'employer_id': instance.employerId,
      'employer_name': instance.employerName,
      'message': instance.message,
    };

DsrDeleteResponse _$DsrDeleteResponseFromJson(Map<String, dynamic> json) =>
    DsrDeleteResponse(
      deletedAt: DateTime.parse(json['deleted_at'] as String),
      sectionCounts: Map<String, int>.from(json['section_counts'] as Map),
      warnings: (json['warnings'] as List<dynamic>)
          .map((e) =>
              OwnerlessEmployerWarningDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DsrDeleteResponseToJson(DsrDeleteResponse instance) =>
    <String, dynamic>{
      'deleted_at': instance.deletedAt.toIso8601String(),
      'section_counts': instance.sectionCounts,
      'warnings': instance.warnings.map((e) => e.toJson()).toList(),
    };

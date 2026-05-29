// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consent_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConsentDto _$ConsentDtoFromJson(Map<String, dynamic> json) => ConsentDto(
      scope: json['scope'] as String,
      granted: json['granted'] as bool,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ConsentDtoToJson(ConsentDto instance) =>
    <String, dynamic>{
      'scope': instance.scope,
      'granted': instance.granted,
      'updated_at': instance.updatedAt.toIso8601String(),
    };

ConsentListResponse _$ConsentListResponseFromJson(Map<String, dynamic> json) =>
    ConsentListResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => ConsentDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ConsentListResponseToJson(
        ConsentListResponse instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

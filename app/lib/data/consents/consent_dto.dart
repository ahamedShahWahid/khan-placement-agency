import 'package:json_annotation/json_annotation.dart';

part 'consent_dto.g.dart';

@JsonSerializable()
class ConsentDto {
  ConsentDto(
      {required this.scope, required this.granted, required this.updatedAt});

  final String scope;
  final bool granted;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  factory ConsentDto.fromJson(Map<String, dynamic> json) =>
      _$ConsentDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ConsentDtoToJson(this);
}

@JsonSerializable()
class ConsentListResponse {
  ConsentListResponse({required this.items});

  final List<ConsentDto> items;

  factory ConsentListResponse.fromJson(Map<String, dynamic> json) =>
      _$ConsentListResponseFromJson(json);
}

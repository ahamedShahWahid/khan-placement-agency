import 'package:json_annotation/json_annotation.dart';

part 'application_status.g.dart';

@JsonEnum(alwaysCreate: true)
enum ApplicationStatus {
  @JsonValue('applied')
  applied,
  @JsonValue('withdrawn')
  withdrawn,
  @JsonValue('unknown')
  unknown,
}

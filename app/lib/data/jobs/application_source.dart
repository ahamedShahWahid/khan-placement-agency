import 'package:json_annotation/json_annotation.dart';

part 'application_source.g.dart';

@JsonEnum(alwaysCreate: true)
enum ApplicationSource {
  @JsonValue('feed')
  feed,
  @JsonValue('detail')
  detail,
  @JsonValue('unknown')
  unknown,
}

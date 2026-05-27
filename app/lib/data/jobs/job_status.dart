import 'package:json_annotation/json_annotation.dart';

part 'job_status.g.dart';

@JsonEnum(alwaysCreate: true)
enum JobStatus {
  @JsonValue('open')
  open,
  @JsonValue('closed')
  closed,
  @JsonValue('unknown')
  unknown,
}

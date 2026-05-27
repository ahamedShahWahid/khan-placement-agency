import 'package:json_annotation/json_annotation.dart';

part 'match_generator.g.dart';

@JsonEnum(alwaysCreate: true)
enum MatchGenerator {
  @JsonValue('templated')
  templated,
  @JsonValue('llm')
  llm,
  @JsonValue('unknown')
  unknown,
}

extension MatchGeneratorLabel on MatchGenerator {
  String get label => switch (this) {
        MatchGenerator.templated => 'templated',
        MatchGenerator.llm => 'LLM',
        MatchGenerator.unknown => '',
      };
}

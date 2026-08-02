import 'package:jobify_app/data/preferences/desired_role.dart';
import 'package:json_annotation/json_annotation.dart';

part 'preferences_dto.g.dart';

/// Mirrors api `PreferencesRead` (routes/applicants.py).
@JsonSerializable(createToJson: false)
class PreferencesDto {
  const PreferencesDto({
    required this.desiredRole,
    required this.locations,
    required this.expectedCtc,
    this.language = 'en',
  });

  factory PreferencesDto.fromJson(Map<String, dynamic> json) =>
      _$PreferencesDtoFromJson(json);

  @JsonKey(name: 'desired_role', unknownEnumValue: DesiredRole.unknown)
  final DesiredRole? desiredRole;
  final List<String> locations;
  // Pydantic v2 serializes Decimal as a JSON string.
  @JsonKey(name: 'expected_ctc')
  final String? expectedCtc;

  /// "en" | "hi". Defaults to "en" when the key is absent — covers
  /// pre-deploy servers that haven't shipped the `language` column yet.
  @JsonKey(defaultValue: 'en')
  final String language;

  bool get isComplete =>
      desiredRole != null && locations.isNotEmpty && expectedCtc != null;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/preferences/preferences_dto.dart';

void main() {
  test('fromJson without language key defaults to "en"', () {
    final dto = PreferencesDto.fromJson(const {
      'desired_role': null,
      'locations': <String>[],
      'expected_ctc': null,
    });
    expect(dto.language, 'en');
  });

  test('fromJson with language "hi" round-trips to "hi"', () {
    final dto = PreferencesDto.fromJson(const {
      'desired_role': null,
      'locations': <String>[],
      'expected_ctc': null,
      'language': 'hi',
    });
    expect(dto.language, 'hi');
  });

  test('fromJson with language "en" round-trips to "en"', () {
    final dto = PreferencesDto.fromJson(const {
      'desired_role': null,
      'locations': <String>[],
      'expected_ctc': null,
      'language': 'en',
    });
    expect(dto.language, 'en');
  });
}

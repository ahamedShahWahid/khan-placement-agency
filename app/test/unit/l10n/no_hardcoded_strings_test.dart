import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Files allowed to keep string literals (wire values, keys, routes).
const _allowlist = <String>{
  // `jobify_recruiter_shell_scaffold.dart` is a deliberately English
  // recruiter-facing surface that lives outside `presentation/recruiter/`
  // (it's the shared shell widget recruiter routes mount into), so the
  // path-based `/recruiter/` exclusion below doesn't cover it. Recruiter
  // copy is out of scope for this Hindi-i18n pass — see Task 9 brief.
  'lib/presentation/widgets/jobify_recruiter_shell_scaffold.dart',
};

// A heuristic scan, not a proof — it catches the shapes that actually recur.
// Widened after an audit found `semanticsLabel`, `helperText` and `errorText`
// were unguarded: all three render user-visible copy and all three would have
// sailed past the original four patterns. Both quote styles for every property
// (the originals only checked single quotes for the `*Text:` family).
final _patterns = [
  for (final p in <String>[
    'hintText',
    'labelText',
    'tooltip',
    'semanticsLabel',
    'helperText',
    'errorText',
  ]) ...[RegExp('$p:\\s*\'[A-Za-z]'), RegExp('$p:\\s*"[A-Za-z]')],
  RegExp(r"Text\(\s*'[A-Za-z]"),
  RegExp(r'Text\(\s*"[A-Za-z]'),
];

void main() {
  test(
    'no hardcoded user-visible strings outside recruiter/ and allowlist',
    () {
      final offenders = <String>[];
      final dir = Directory('lib/presentation');
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        final rel = f.path;
        if (!rel.endsWith('.dart') || rel.contains('/recruiter/')) continue;
        if (_allowlist.contains(rel)) continue;
        final src = f.readAsStringSync();
        for (final p in _patterns) {
          for (final m in p.allMatches(src)) {
            final line = src.substring(0, m.start).split('\n').length;
            final snippet = src
                .substring(m.start, m.start + 30)
                .replaceAll('\n', ' ');
            offenders.add('$rel:$line $snippet');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Localize via context.l10n (ARB), or allowlist with '
            'justification:\n${offenders.join('\n')}',
      );
    },
  );
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/config/language_provider.dart';

void main() {
  final es = LanguageProvider.translations[Language.es]!;
  final en = LanguageProvider.translations[Language.en]!;

  test('Spanish and English define the same keys', () {
    expect(es.keys.toSet().difference(en.keys.toSet()), isEmpty,
        reason: 'missing in English');
    expect(en.keys.toSet().difference(es.keys.toSet()), isEmpty,
        reason: 'missing in Spanish');
  });

  test('every literal translate(...) key used in lib/ exists', () {
    final used = <String>{};
    final pattern = RegExp(r"""translate\(\s*['"]([A-Za-z0-9_]+)['"]""");
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        used.addAll(pattern
            .allMatches(file.readAsStringSync())
            .map((m) => m.group(1)!));
      }
    }
    expect(used, isNotEmpty);
    expect(used.difference(es.keys.toSet()), isEmpty);
  });
}

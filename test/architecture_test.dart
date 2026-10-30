import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layer rules of docs/architecture.md, checked on every import in lib/.
///
/// A rule names the files it applies to and the imports they may not have.
/// Imports are resolved to `lib/...` paths first, so `../../core/x.dart` and
/// `package:dummy_shop/core/x.dart` are the same thing.
class Rule {
  const Rule(this.name, {required this.appliesTo, required this.forbids, this.except = _none});

  final String name;
  final bool Function(String file) appliesTo;
  final bool Function(String import, String file) forbids;
  final bool Function(String file) except;

  static bool _none(String _) => false;
}

bool under(String file, String dir) => file.startsWith(dir);
String? featureOf(String path) => RegExp(r'^lib/features/(\w+)/').firstMatch(path)?.group(1);
String? layerOf(String path) => RegExp(r'^lib/features/\w+/(\w+)/').firstMatch(path)?.group(1);

final rules = [
  Rule(
    'core is plain Dart and knows nothing above it',
    appliesTo: (f) => under(f, 'lib/core/'),
    forbids: (i, _) =>
        i.startsWith('package:flutter/') ||
        i.startsWith('package:flutter_bloc/') ||
        under(i, 'lib/features/') ||
        under(i, 'lib/app/') ||
        under(i, 'lib/platform/'),
  ),
  Rule(
    'data and bloc layers are plain Dart (testable without widgets)',
    appliesTo: (f) => const {'data', 'bloc'}.contains(layerOf(f)),
    forbids: (i, _) =>
        i.startsWith('package:flutter/') ||
        i.startsWith('package:flutter_bloc/') ||
        i.startsWith('package:go_router/') ||
        layerOf(i) == 'presentation',
  ),
  Rule(
    'blocs never touch HTTP',
    appliesTo: (f) => layerOf(f) == 'bloc',
    forbids: (i, _) => i.startsWith('package:dio/') || i.endsWith('_api.dart'),
  ),
  Rule(
    'screens never touch HTTP or the session internals',
    appliesTo: (f) => layerOf(f) == 'presentation',
    forbids: (i, _) =>
        i.startsWith('package:dio/') ||
        i.endsWith('_api.dart') ||
        i == 'lib/core/network/auth_interceptor.dart' ||
        i == 'lib/core/session/session_manager.dart',
  ),
  Rule(
    'a feature reaches another feature only through its bloc',
    appliesTo: (f) => featureOf(f) != null,
    forbids: (i, f) => featureOf(i) != null && featureOf(i) != featureOf(f) && layerOf(i) != 'bloc',
  ),
  Rule(
    'only the composition root knows the platform',
    appliesTo: (f) => true,
    except: (f) => f == 'lib/app/dependencies.dart' || under(f, 'lib/platform/'),
    forbids: (i, _) => under(i, 'lib/platform/') || i.startsWith('package:flutter_secure_storage/'),
  ),
];

/// Every `import`/`export` of every file, as `lib/...` paths or `package:` URIs.
Map<String, List<String>> importsIn(Directory lib) {
  final directive = RegExp(r'''^(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);
  return {
    for (final file in lib.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
      _relative(file.path): [
        for (final match in directive.allMatches(file.readAsStringSync()))
          _resolve(_relative(file.path), match.group(1)!),
      ],
  };
}

String _relative(String path) => path.replaceAll(r'\', '/').substring(path.replaceAll(r'\', '/').indexOf('lib/'));

String _resolve(String from, String import) {
  if (import.startsWith('package:dummy_shop/')) return 'lib/${import.substring('package:dummy_shop/'.length)}';
  if (import.contains(':')) return import;
  return Uri(path: from).resolve(import).path;
}

List<String> violations(Map<String, List<String>> imports) => [
  for (final MapEntry(key: file, value: list) in imports.entries)
    for (final rule in rules)
      if (rule.appliesTo(file) && !rule.except(file))
        for (final import in list)
          if (rule.forbids(import, file)) '$file imports $import\n    breaks: ${rule.name}',
];

void main() {
  test('lib/ follows the layer rules', () {
    final found = violations(importsIn(Directory('lib')));
    expect(found, isEmpty, reason: found.join('\n'));
  });

  // The rules above are only worth something if they can fail.
  group('the checker catches', () {
    test('Flutter in core', () {
      expect(
        violations({
          'lib/core/x.dart': ['package:flutter/widgets.dart'],
        }),
        isNotEmpty,
      );
    });

    test('a bloc calling an API', () {
      expect(
        violations({
          'lib/features/products/bloc/x.dart': ['lib/features/products/data/products_api.dart'],
        }),
        isNotEmpty,
      );
    });

    test('a screen using Dio', () {
      expect(
        violations({
          'lib/features/products/presentation/x.dart': ['package:dio/dio.dart'],
        }),
        isNotEmpty,
      );
    });

    test('a screen using another feature\'s data', () {
      expect(
        violations({
          'lib/features/products/presentation/x.dart': ['lib/features/auth/data/auth_user.dart'],
        }),
        isNotEmpty,
      );
    });

    test('the keychain outside the composition root', () {
      expect(
        violations({
          'lib/features/auth/data/x.dart': ['lib/platform/secure_token_storage.dart'],
        }),
        isNotEmpty,
      );
    });

    test('relative imports resolved to their real path', () {
      expect(
        _resolve('lib/features/auth/presentation/login_page.dart', '../../../core/session/session_manager.dart'),
        'lib/core/session/session_manager.dart',
      );
    });
  });
}

import 'dart:convert';

import 'package:auto_go_route_generator/builder.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'stub_package.dart';

/// The `import` + `part` preamble every router-library fixture starts with.
const routerHeader = '''
import 'package:auto_go_route/auto_go_route.dart';

part 'app_router.routes.g.dart';
''';

/// A bare `@AutoGoRouteBase` router class.
const routerBase = '''
@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''';

/// Runs the builder over [routerLibrary] plus any [extraLibraries] and returns
/// the generated part file.
Future<String> generate(
  String routerLibrary, {
  Map<String, String> extraLibraries = const {},
  List<String>? warnings,
  String routerPath = 'lib/app_router.dart',
}) async {
  final logs = <LogRecord>[];
  String? captured;
  await testBuilder(
    autoGoRouteBuilder(const BuilderOptions({})),
    {
      ...stubAssets,
      'app|$routerPath': routerLibrary,
      ...extraLibraries.map(
        (k, v) => MapEntry('app|${k.contains('/') ? k : 'lib/$k'}', v),
      ),
    },
    generateFor: {'app|$routerPath'},
    rootPackage: 'app',
    onLog: logs.add,
    // Generated assets live in the build's output filesystem, which the test
    // reader cannot see; a capturing matcher is how `build_test` hands the
    // content back.
    outputs: {
      'app|${routerPath.replaceFirst(RegExp(r'\.dart$'), '.routes.g.dart')}':
          predicate<List<int>>((bytes) {
            captured = utf8.decode(bytes);
            return true;
          }),
    },
  );
  warnings?.addAll(
    logs.where((log) => log.level >= Level.WARNING).map((log) => log.message),
  );

  return captured ?? (throw StateError('the builder produced no output'));
}

/// Matches generated source ignoring how `dart_style` chose to wrap it.
///
/// The builder hands its output to the formatter, so asserting on exact line
/// breaks would make these tests fail whenever the formatter's preferences
/// change rather than when the generator's behaviour does.
Matcher containsCode(String expected) => predicate<String>(
  (actual) => _collapse(actual).contains(_collapse(expected)),
  'contains the code `${_collapse(expected)}`',
);

String _collapse(String source) => source
    // Collapse newlines and indentation the formatter introduced.
    .replaceAll(RegExp(r'\s+'), ' ')
    // Drop spaces the formatter left next to punctuation when wrapping.
    .replaceAllMapped(
      RegExp(r'\s*([(),\[\]{}])\s*'),
      (match) => match.group(1)!,
    )
    // Ignore the trailing commas the formatter adds before a closer.
    .replaceAllMapped(RegExp(r',([)\]}])'), (match) => match.group(1)!)
    .trim();

/// Runs the builder and returns what it reported as a build failure.
///
/// `source_gen` turns an `InvalidGenerationSourceError` into a `SEVERE` log
/// rather than letting it escape the build, so both channels are collected.
/// Every case here either hung the build or emitted an unparseable file in
/// 1.x; the assertion is that the generator now *names the problem*.
Future<String> errorFor(
  String routerLibrary, {
  Map<String, String> extraLibraries = const {},
}) async {
  final severe = <String>[];
  try {
    await testBuilder(
      autoGoRouteBuilder(const BuilderOptions({})),
      {
        ...stubAssets,
        'app|lib/app_router.dart': routerLibrary,
        ...extraLibraries.map((k, v) => MapEntry('app|lib/$k', v)),
      },
      generateFor: {'app|lib/app_router.dart'},
      rootPackage: 'app',
      onLog: (log) {
        if (log.level >= Level.SEVERE) {
          severe.add('${log.message}\n${log.error ?? ''}');
        }
      },
    );
  } on Object catch (error) {
    severe.add(error.toString());
  }
  return severe.join('\n');
}

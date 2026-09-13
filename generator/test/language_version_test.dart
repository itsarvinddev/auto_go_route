import 'dart:io';

// The analyzer's supported language version is only exposed from its
// implementation library; this test exists precisely to watch that number.
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/experiments.dart';
import 'package:auto_go_route_generator/builder.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'support/stub_package.dart';

/// Regression test for issue #3, "Hanging action when building app_router
/// class".
///
/// The generator pinned `analyzer: ^7.0.0`, whose supported language version
/// is 3.9.0. On Dart 3.10+ the analyzer hit syntax it had no visitor for and
/// the build died with
/// `Exception: Missing implementation of visitDotShorthandPropertyAccess`
/// from `ThrowingAstVisitor` inside `BundleWriter.writeLibraryElement`.
///
/// The fixture below uses a dot shorthand (`Sort sort = .asc;`), which is
/// exactly the syntax that tripped it. If the analyzer constraint ever slips
/// backwards, this test fails instead of users' builds.
void main() {
  test(
    'the resolved analyzer understands the running SDK language version',
    tags: 'latest-resolution',
    () {
      // This is the mechanism of issue #3, checked directly: the generator runs
      // on the user's SDK but parses with whatever analyzer pub resolved, and
      // when that analyzer's language version trails the SDK's, new syntax is
      // unparseable. The fixture test below proves one such syntax builds; this
      // one fails for *any* future syntax the moment the analyzer range stops
      // admitting a version that keeps up with the SDK.
      final sdk = Version.parse(Platform.version.split(' ').first);
      final sdkLanguage = Version(sdk.major, sdk.minor, 0);
      final analyzerLanguage = ExperimentStatus.currentVersion;
      expect(
        analyzerLanguage,
        greaterThanOrEqualTo(sdkLanguage),
        reason:
            'analyzer supports language $analyzerLanguage but the SDK is '
            '$sdkLanguage. Widen the `analyzer` constraint in '
            'generator/pubspec.yaml so pub can pick a newer one.',
      );
    },
  );

  test('builds a library using post-3.9 syntax', () async {
    final severe = <String>[];
    var wroteOutput = false;

    await testBuilder(
      autoGoRouteBuilder(const BuilderOptions({})),
      {
        ...stubAssets,
        'app|lib/app_router.dart': r'''
import 'package:auto_go_route/auto_go_route.dart';

part 'app_router.routes.g.dart';

enum Sort { asc, desc }

/// A dot shorthand: valid from Dart 3.10, unparseable by analyzer 7.
const Sort defaultSort = .asc;

@AutoGoRoute(path: '/items')
class ItemsPage {
  const ItemsPage({this.sort = defaultSort});
  final Sort sort;
}

@AutoGoRouteBase()
class AppRouter extends _$AppRouter {}
''',
      },
      generateFor: {'app|lib/app_router.dart'},
      rootPackage: 'app',
      onLog: (log) {
        if (log.level >= Level.SEVERE) {
          severe.add('${log.message}\n${log.error ?? ''}');
        }
      },
      outputs: {
        'app|lib/app_router.routes.g.dart': predicate<List<int>>((bytes) {
          wroteOutput = bytes.isNotEmpty;
          return true;
        }),
      },
    );

    expect(
      severe,
      isEmpty,
      reason:
          'A SEVERE log here means the resolved analyzer cannot parse the '
          "input's language version — the cause of issue #3.",
    );
    expect(wroteOutput, isTrue);
  });
}

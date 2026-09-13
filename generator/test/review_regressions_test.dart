import 'package:test/test.dart';

import 'support/harness.dart';

/// Regressions found by the pre-release adversarial review.
///
/// Each of these passed the original suite: the generator either wrote a file
/// that does not compile, or one that compiles and misbehaves. Every test here
/// names the shape that used to slip through.
void main() {
  group('generated helpers do not shadow themselves', () {
    test('a parameter named like a helper argument is refused', () async {
      for (final name in ['queries', 'fragment', 'extra']) {
        final message = await errorFor('''
$routerHeader

@AutoGoRoute(path: '/a')
class PageA {
  const PageA({this.$name});
  final String? $name;
}

$routerBase
''');
        expect(
          message,
          allOf(contains('`$name`'), contains("@QueryParam('$name')")),
          reason: name,
        );
      }
    });

    test(
      'a parameter named `location` cannot shadow the URL builder',
      () async {
        // `pathWith`'s body called `location(...)`; a parameter of that name
        // shadowed the method and the call became an invocation of a String.
        final output = await generate('''
$routerHeader

@AutoGoRoute(path: '/map')
class MapPage {
  const MapPage({this.location});
  final String? location;
}

$routerBase
''');
        expect(output, contains('return this.location('));
      },
    );

    test('navigation helpers call through `this`', () async {
      // A query parameter named `go` or `push` would otherwise shadow the
      // go_router extension method the helper forwards to.
      final output = await generate('''
$routerHeader

@AutoGoRoute(path: '/a')
class PageA {
  const PageA({this.go, this.push});
  final bool? go;
  final bool? push;
}

$routerBase
''');
      expect(output, contains('this.go('));
      expect(output, contains('this.push<T>('));
      expect(output, contains('this.pushReplacement('));
      expect(output, contains('this.replace('));
    });
  });

  group('shapes go_router refuses are build errors', () {
    test('a shell with no child routes', () async {
      // Previously emitted `routes: [,]`, which is not parseable Dart.
      for (final stateful in [false, true]) {
        final slot = stateful
            ? 'StatefulNavigationShell navigationShell'
            : 'Widget child';
        final field = stateful ? 'navigationShell' : 'child';
        final message = await errorFor('''
$routerHeader

@AutoGoRouteShell(path: '/empty', isStateful: $stateful)
class EmptyShell {
  const EmptyShell({required this.$field});
  final ${slot.split(' ').first} $field;
}

@AutoGoRoute(path: '/other')
class Other {
  const Other();
}

$routerBase
''');
        expect(
          message,
          allOf(contains('EmptyShell'), contains('no child routes')),
          reason: 'stateful: $stateful',
        );
      }
    });

    test('a branch whose only route takes path parameters', () async {
      // go_router cannot derive an initial location and asserts at startup.
      final message = await errorFor('''
$routerHeader

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/users/:id', parent: Tabs)
class UserTab {
  const UserTab({required this.id});
  final String id;
}

$routerBase
''');
      expect(
        message,
        allOf(
          contains('UserTab'),
          contains('@AutoGoRouteBranch(initialLocation'),
        ),
      );
    });

    test('an explicit branch initialLocation makes that shape valid', () async {
      final output = await generate('''
$routerHeader

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/users/:id', parent: Tabs)
@AutoGoRouteBranch(initialLocation: '/users/me')
class UserTab {
  const UserTab({required this.id});
  final String id;
}

$routerBase
''');
      expect(output, contains("initialLocation: '/users/me'"));
    });

    test(
      'a nested shell whose initialRoute points outside its branch',
      () async {
        final message = await errorFor('''
$routerHeader

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRouteShell(path: '/inner', parent: Tabs, initialRoute: '/outside')
class InnerShell {
  const InnerShell({required this.child});
  final Widget child;
}

@AutoGoRoute(path: '/inside', parent: InnerShell)
class Inside {
  const Inside();
}

@AutoGoRoute(path: '/outside')
class Outside {
  const Outside();
}

$routerBase
''');
        expect(
          message,
          allOf(contains('"/outside"'), contains('not a route inside')),
        );
      },
    );

    test('a stateful shell given a navigatorKey or observers', () async {
      final message = await errorFor('''
$routerHeader

@AutoGoRouteShell(path: '/', isStateful: true, navigatorKey: 'key')
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/a', parent: Tabs)
class PageA {
  const PageA();
}

$routerBase

Object? key;
''');
      expect(
        message,
        allOf(contains('navigatorKey'), contains('@AutoGoRouteBranch')),
      );
    });

    test(
      'initialExtra or overridePlatformDefaultLocation without a location',
      () async {
        for (final field in [
          "initialExtra: 'payload'",
          'overridePlatformDefaultLocation: true',
        ]) {
          final message = await errorFor('''
$routerHeader

@AutoGoRoute(path: '/a')
class PageA {
  const PageA();
}

@AutoGoRouteBase($field)
class AppRouter extends _\$AppRouter {}

Object? payload;
''');
          expect(message, contains('initialLocation'), reason: field);
        }
      },
    );
  });

  group('the route enum', () {
    test('rejects names the enum itself declares, and keywords', () async {
      for (final name in ['routeName', 'template', 'values', 'class']) {
        final message = await errorFor('''
$routerHeader

@AutoGoRoute(path: '/a', name: '$name')
class PageA {
  const PageA();
}

$routerBase
''');
        expect(
          message,
          contains('reserved inside the generated route enum'),
          reason: name,
        );
      }
    });
  });

  group('caseSensitive is a default, not an override', () {
    const fixture =
        '''
$routerHeader

@AutoGoRoute(path: '/Inherits')
class Inherits {
  const Inherits();
}

@AutoGoRoute(path: '/OptsIn', caseSensitive: true)
class OptsIn {
  const OptsIn();
}

@AutoGoRouteBase(caseSensitive: false)
class AppRouter extends _\$AppRouter {}
''';

    test('a route without its own value inherits the router default', () async {
      final output = await generate(fixture);
      final inherits = output.substring(
        output.indexOf('class InheritsRoute'),
        output.indexOf(
          'static const String routeName',
          output.indexOf('class InheritsRoute'),
        ),
      );
      expect(inherits, contains('caseSensitive: false'));
    });

    test('a route that opts back in keeps its value', () async {
      // The values were ANDed, so this route silently became insensitive.
      final output = await generate(fixture);
      final optsIn = output.substring(
        output.indexOf('class OptsInRoute'),
        output.indexOf(
          'static const String routeName',
          output.indexOf('class OptsInRoute'),
        ),
      );
      expect(optsIn, isNot(contains('caseSensitive: false')));
    });
  });

  group('shell redirects', () {
    test('a root shell does not shadow a real route at "/"', () async {
      // The redirect-only wrapper matched "/" first, so the user's own "/"
      // route could never be reached.
      final output = await generate('''
$routerHeader

@AutoGoRoute(path: '/')
class Landing {
  const Landing();
}

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/feed', parent: Tabs)
class Feed {
  const Feed();
}

$routerBase
''');
      expect(output, isNot(contains("state.uri.path == '/'")));
      expect(output, contains('landingRoute.toGoRoute()'));
    });

    test('a non-root shell redirect precedes pattern routes', () async {
      // Appended last, the redirect lost to any earlier `/:slug` route.
      final output = await generate('''
$routerHeader

@AutoGoRoute(path: '/:slug')
class CatchAll {
  const CatchAll({required this.slug});
  final String slug;
}

@AutoGoRouteShell(path: '/settings', initialRoute: '/settings-general')
class SettingsShell {
  const SettingsShell({required this.child});
  final Widget child;
}

@AutoGoRoute(path: '/settings-general', parent: SettingsShell)
class General {
  const General();
}

$routerBase
''');
      final redirect = output.indexOf("path: '/settings'");
      final catchAll = output.indexOf('catchAllRoute.toGoRoute()');
      expect(redirect, isNonNegative);
      expect(redirect, lessThan(catchAll));
    });

    test(
      'a non-root shell without initialRoute lands on its first child',
      () async {
        // The annotation documents this default; only the root shell honoured it.
        final output = await generate('''
$routerHeader

@AutoGoRouteShell(path: '/compose')
class ComposeShell {
  const ComposeShell({required this.child});
  final Widget child;
}

@AutoGoRoute(path: '/compose-body', parent: ComposeShell)
class ComposeBody {
  const ComposeBody();
}

$routerBase
''');
        expect(
          output,
          containsCode(
            "GoRoute(path: '/compose', redirect: (context, state) => '/compose-body')",
          ),
        );
      },
    );

    test(
      'no redirect is emitted over a real route at the shell path',
      () async {
        final output = await generate('''
$routerHeader

@AutoGoRoute(path: '/account')
class Account {
  const Account();
}

@AutoGoRouteShell(path: '/account', initialRoute: '/account-home')
class AccountShell {
  const AccountShell({required this.child});
  final Widget child;
}

@AutoGoRoute(path: '/account-home', parent: AccountShell)
class AccountHome {
  const AccountHome();
}

$routerBase
''');
        expect(
          output,
          isNot(contains("redirect: (context, state) => '/account-home'")),
        );
      },
    );
  });

  group('visibility', () {
    test('a widget not imported into the router library is named', () async {
      final message = await errorFor(
        '''
$routerHeader

$routerBase
''',
        extraLibraries: {
          'pages.dart': '''
import 'package:auto_go_route/auto_go_route.dart';

@AutoGoRoute(path: '/hidden')
class HiddenPage {
  const HiddenPage();
}
''',
        },
      );
      expect(
        message,
        allOf(contains('HiddenPage'), contains('visible from that library')),
      );
    });

    test('a parameter type not visible from the router is named', () async {
      final message = await errorFor(
        '''
import 'package:auto_go_route/auto_go_route.dart';
import 'page.dart';

part 'app_router.routes.g.dart';

$routerBase
''',
        extraLibraries: {
          'model.dart': 'class Invoice { const Invoice(); }',
          'page.dart': '''
import 'package:auto_go_route/auto_go_route.dart';
import 'model.dart';

@AutoGoRoute(path: '/invoice')
class InvoicePage {
  const InvoicePage({this.invoice});
  final Invoice? invoice;
}
''',
        },
      );
      expect(
        message,
        allOf(contains('Invoice'), contains('the type of `invoice`')),
      );
    });
  });

  group('discovery', () {
    test('a router under test/ scans the directory beside it', () async {
      final output = await generate(
        '''
import 'package:auto_go_route/auto_go_route.dart';
import 'test_page.dart';

part 'app_router.routes.g.dart';

$routerBase
''',
        routerPath: 'test/app_router.dart',
        extraLibraries: {
          'test/test_page.dart': '''
import 'package:auto_go_route/auto_go_route.dart';

@AutoGoRoute(path: '/from-test')
class TestPage {
  const TestPage();
}
''',
        },
      );
      expect(output, contains('TestPageRoute'));
    });

    test('sourceGlobs scopes a router to part of the package', () async {
      final warnings = <String>[];
      final output = await generate(
        '''
import 'package:auto_go_route/auto_go_route.dart';
import 'admin/admin_page.dart';

part 'app_router.routes.g.dart';

@AutoGoRouteBase(sourceGlobs: ['lib/admin/**/*.dart', 'lib/app_router.dart'])
class AppRouter extends _\$AppRouter {}
''',
        warnings: warnings,
        extraLibraries: {
          'lib/admin/admin_page.dart': '''
import 'package:auto_go_route/auto_go_route.dart';

@AutoGoRoute(path: '/admin')
class AdminPage {
  const AdminPage();
}
''',
          'lib/shop/shop_page.dart': '''
import 'package:auto_go_route/auto_go_route.dart';

@AutoGoRoute(path: '/shop')
class ShopPage {
  const ShopPage();
}
''',
          'lib/shop/shop_router.dart': '''
import 'package:auto_go_route/auto_go_route.dart';

@AutoGoRouteBase()
class ShopRouter {}
''',
        },
      );
      expect(output, contains('AdminPageRoute'));
      expect(output, isNot(contains('ShopPageRoute')));
      // AppRouter is scoped explicitly, so nothing is reported against it. (The
      // unscoped ShopRouter still warns about itself, correctly.)
      expect(warnings.where((w) => w.startsWith('AppRouter and')), isEmpty);
    });

    test(
      'a comment mentioning @AutoGoRouteBase is not a second router',
      () async {
        final warnings = <String>[];
        await generate(
          '''
$routerHeader

@AutoGoRoute(path: '/a')
class PageA {
  const PageA();
}

$routerBase
''',
          warnings: warnings,
          extraLibraries: {
            'main.dart': '''
// The router is configured by `@AutoGoRouteBase` in app_router.dart.
void main() {}
''',
          },
        );
        expect(warnings.join(), isNot(contains('both scan the same sources')));
      },
    );

    test('two unscoped routers in one package are warned about', () async {
      final warnings = <String>[];
      await generate(
        '''
$routerHeader

@AutoGoRoute(path: '/a')
class PageA {
  const PageA();
}

$routerBase
''',
        warnings: warnings,
        extraLibraries: {
          'other_router.dart': '''
import 'package:auto_go_route/auto_go_route.dart';

@AutoGoRouteBase()
class OtherRouter {}
''',
        },
      );
      expect(
        warnings.join('\n'),
        allOf(contains('other_router.dart'), contains('sourceGlobs')),
      );
    });
  });

  group('list query parameters', () {
    test('every documented element type has a decoder', () async {
      // README promised List<bool>, List<num>, List<BigInt>, List<DateTime>
      // and List<Uri>; the emitter silently read them as strings.
      final output = await generate('''
$routerHeader

@AutoGoRoute(path: '/filters')
class Filters {
  const Filters({
    this.flags,
    this.weights,
    this.ids,
    this.days,
    this.links,
  });

  final List<bool>? flags;
  final List<num>? weights;
  final List<BigInt>? ids;
  final List<DateTime>? days;
  final List<Uri>? links;
}

$routerBase
''');
      for (final reader in [
        "RouteCodec.boolList(state, 'flags')",
        "RouteCodec.numList(state, 'weights')",
        "RouteCodec.bigIntList(state, 'ids')",
        "RouteCodec.dateTimeList(state, 'days')",
        "RouteCodec.uriList(state, 'links')",
      ]) {
        expect(output, contains(reader), reason: reader);
      }
    });
  });
}

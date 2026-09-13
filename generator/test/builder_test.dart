import 'package:test/test.dart';

import 'support/harness.dart';

const _header = '''
import 'package:auto_go_route/auto_go_route.dart';

part 'app_router.routes.g.dart';
''';

void main() {
  group('a single top-level route', () {
    late String output;

    setUpAll(() async {
      output = await generate('''
$_header

@AutoGoRoute(path: '/home', description: 'The home screen.')
class HomePage {
  const HomePage();
}

@AutoGoRouteBase(initialLocation: '/home')
class AppRouter extends _\$AppRouter {}
''');
    });

    test('emits the route class extending RoutePaths', () {
      expect(output, contains('class HomePageRoute extends RoutePaths {'));
      expect(output, contains("path: '/home'"));
      expect(output, contains("name: 'homePage'"));
      expect(output, contains("description: 'The home screen.'"));
    });

    test('emits static name and template constants', () {
      expect(output, contains("static const String routeName = 'homePage';"));
      expect(output, contains("static const String routeTemplate = '/home';"));
    });

    test('emits a plain builder when no page options are set', () {
      expect(output, containsCode('builder: (context, state) => HomePage()'));
      expect(output, isNot(contains('pageBuilder:')));
    });

    test('exposes the route tree publicly', () {
      expect(output, contains('List<RouteBase> get routes => ['));
      expect(output, contains('homePageRoute.toGoRoute()'));
    });

    test('caches each route definition behind a getter', () {
      expect(
        output,
        containsCode(
          'late final HomePageRoute _homePageRoute = HomePageRoute();',
        ),
      );
      expect(
        output,
        contains('HomePageRoute get homePageRoute => _homePageRoute;'),
      );
    });

    test('emits the full navigation helper family', () {
      for (final method in [
        'String locationOfHomePage(',
        'void goToHomePage(',
        'Future<T?> pushToHomePage<T extends Object?>(',
        'void replaceWithHomePage(',
        'void replaceInPlaceWithHomePage(',
      ]) {
        expect(output, contains(method), reason: method);
      }
    });

    test('emits a route enum named after the router', () {
      expect(output, contains('enum AppRoute {'));
      expect(output, containsCode("homePage('homePage', '/home')"));
    });

    test('buildRouter forwards the annotation defaults', () {
      expect(output, contains("initialLocation: initialLocation ?? '/home'"));
      expect(output, contains('routes: routes ?? this.routes'));
    });
  });

  group('typed parameters', () {
    late String output;

    setUpAll(() async {
      output = await generate('''
$_header

enum Sort { asc, desc }

class Payload {
  const Payload();
}

@AutoGoRoute(path: '/items/:id')
class ItemPage {
  const ItemPage({
    required this.id,
    this.q,
    this.sort = Sort.asc,
    this.page = 1,
    this.tags,
    this.when,
    this.payload,
  });

  final int id;
  final String? q;
  final Sort sort;
  final int page;
  final List<String>? tags;
  final DateTime? when;
  final Payload? payload;
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
    });

    test('reads an int path parameter as an int', () {
      expect(output, containsCode("id: RouteCodec.requireInt(state, 'id')"));
    });

    test('reads a nullable query parameter as optional', () {
      expect(output, containsCode("q: RouteCodec.optionalString(state, 'q')"));
    });

    test('falls back to the widget default for a non-nullable query param', () {
      expect(
        output,
        contains("RouteCodec.optionalEnum(state, 'sort', Sort.values)"),
      );
      expect(output, contains('Sort.asc'));
      expect(output, contains("RouteCodec.optionalInt(state, 'page')"));
      expect(output, contains('?? 1'));
    });

    test('reads a repeated query parameter as a list, null when absent', () {
      expect(output, containsCode("RouteCodec.rawAll(state, 'tags').isEmpty"));
      expect(output, contains("RouteCodec.stringList(state, 'tags')"));
    });

    test('reads a DateTime', () {
      expect(
        output,
        containsCode("when: RouteCodec.optionalDateTime(state, 'when')"),
      );
    });

    test('routes an unrepresentable type to extra', () {
      expect(
        output,
        containsCode('payload: RouteCodec.optionalExtra<Payload>(state)'),
      );
    });

    test('pathWith carries the declared types', () {
      expect(output, contains('required int id,'));
      expect(output, contains('String? q,'));
      expect(output, contains('Sort? sort,'));
      expect(output, contains('List<String>? tags,'));
      expect(output, contains('DateTime? when,'));
    });

    test('pathWith guards every optional query entry', () {
      expect(output, containsCode("if (q != null) 'q': RouteCodec.encode(q)"));
      expect(
        output,
        containsCode("if (tags != null) 'tags': RouteCodec.encodeAll(tags)"),
      );
    });

    test('the navigation helper takes the extra as its declared type', () {
      expect(output, contains('Payload? extra,'));
    });

    test('a marker annotation on the backing field is honoured', () async {
      // Widgets annotate the field, not the `this.x` constructor parameter, so
      // reading annotations from the parameter alone silently ignored the
      // rename and read `?featureDisabled` instead of `?feature-disabled`.
      final renamed = await generate('''
$_header

@AutoGoRoute(path: '/home')
class HomePage {
  const HomePage({this.featureDisabled, this.id});

  @QueryParam('feature-disabled')
  final bool? featureDisabled;

  @RouteIgnore()
  final String? id;
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
      expect(
        renamed,
        containsCode(
          "featureDisabled: RouteCodec.optionalBool(state, 'feature-disabled')",
        ),
      );
      expect(
        renamed,
        containsCode("if (featureDisabled != null) 'feature-disabled':"),
      );
      // @RouteIgnore on the field keeps the parameter out of the builder.
      expect(renamed, isNot(contains('id:')));
    });

    test('@PathParam on a field renames the path binding', () async {
      final renamed = await generate('''
$_header

@AutoGoRoute(path: '/products/:id')
class ProductPage {
  const ProductPage({required this.productId});

  @PathParam('id')
  final int productId;
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
      expect(
        renamed,
        containsCode("productId: RouteCodec.requireInt(state, 'id')"),
      );
      expect(
        renamed,
        containsCode("params: {'id': RouteCodec.encode(productId)}"),
      );
      expect(renamed, contains('required int productId,'));
    });
  });

  group('nesting', () {
    late String output;

    setUpAll(() async {
      output = await generate('''
$_header

@AutoGoRoute(path: '/products/:id')
class ProductPage {
  const ProductPage({required this.id});
  final String id;
}

@AutoGoRoute(path: 'reviews', parent: ProductPage)
class ReviewsPage {
  const ReviewsPage({required this.id});
  final String id;
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
    });

    test('a child extends NestedRoutePaths and keeps its relative path', () {
      expect(
        output,
        contains('class ReviewsPageRoute extends NestedRoutePaths'),
      );
      expect(output, contains("parentTemplate: '/products/:id'"));
      expect(output, contains("path: 'reviews'"));
    });

    test('the child template is the joined path', () {
      expect(
        output,
        contains(
          "static const String routeTemplate = '/products/:id/reviews';",
        ),
      );
    });

    test('the child inherits the parent path parameter in its signature', () {
      expect(output, contains('required String id,'));
    });

    test('the tree nests the child under the parent', () {
      expect(
        output,
        containsCode(
          'productPageRoute.toGoRoute(routes: [reviewsPageRoute.toGoRoute()])',
        ),
      );
    });
  });

  group('shells', () {
    test('a stateless shell emits toShellRoute and a child builder', () async {
      final output = await generate('''
$_header

@AutoGoRouteShell(path: '/wrap')
class WrapShell {
  const WrapShell({required this.child});
  final Widget child;
}

@AutoGoRoute(path: 'inner', parent: WrapShell)
class InnerPage {
  const InnerPage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
      expect(output, contains('class WrapShellRoute extends ShellRoutePaths'));
      expect(output, contains('isStateful: false'));
      expect(
        output,
        containsCode(
          'builder: (context, state, child) => WrapShell(child: child)',
        ),
      );
      // Asserting the whole call, child included — an assertion that stopped
      // at the opening bracket also accepted an empty (unparseable) list.
      expect(
        output,
        containsCode(
          'wrapShellRoute.toShellRoute(routes: [innerPageRoute.toGoRoute()])',
        ),
      );
      // A shell contributes no URL segment, so the child sits at the root.
      expect(output, contains("static const String routeTemplate = '/inner';"));
    });

    test('a stateful shell emits branches with initial locations', () async {
      final output = await generate('''
$_header

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/feed', parent: Tabs, order: 0)
@AutoGoRouteBranch(preload: true)
class FeedPage {
  const FeedPage();
}

@AutoGoRoute(path: '/inbox', parent: Tabs, order: 1)
class InboxPage {
  const InboxPage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
      expect(
        output,
        containsCode(
          'statefulBuilder: (context, state, child) => '
          'Tabs(navigationShell: child)',
        ),
      );
      expect(
        output,
        containsCode(
          'tabsRoute.toStatefulShellRoute(branches: ['
          'StatefulShellBranch(routes: [feedPageRoute.toGoRoute()], '
          "initialLocation: '/feed', preload: true), "
          'StatefulShellBranch(routes: [inboxPageRoute.toGoRoute()], '
          "initialLocation: '/inbox')])",
        ),
      );
      // Only the annotated branch preloads.
      expect('preload: true'.allMatches(output), hasLength(1));
      // A root shell matches no location of its own, so "/" needs a redirect.
      expect(output, containsCode("state.uri.path == '/' ? '/feed' : null"));
    });

    test('"/" lands on the first branch\'s explicit initialLocation', () async {
      final output = await generate('''
$_header

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/users/:id', parent: Tabs, order: 0)
@AutoGoRouteBranch(initialLocation: '/users/1')
class UserPage {
  const UserPage({required this.id});
  final int id;
}

@AutoGoRoute(path: '/inbox', parent: Tabs, order: 1)
class InboxPage {
  const InboxPage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
      // Previously the parameterised first branch was skipped and "/" went to
      // the second branch.
      expect(output, containsCode("state.uri.path == '/' ? '/users/1' : null"));
    });

    test('branch order follows `order`, not discovery order', () async {
      final output = await generate('''
$_header

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/zebra', parent: Tabs, order: 0)
class ZebraPage {
  const ZebraPage();
}

@AutoGoRoute(path: '/apple', parent: Tabs, order: 1)
class ApplePage {
  const ApplePage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
      expect(
        output.indexOf("initialLocation: '/zebra'"),
        lessThan(output.indexOf("initialLocation: '/apple'")),
      );
    });

    test('a non-root shell redirects from its own path as a sibling', () async {
      final output = await generate('''
$_header

@AutoGoRouteShell(path: '/wizard', initialRoute: '/step-one')
class WizardShell {
  const WizardShell({required this.child});
  final Widget child;
}

@AutoGoRoute(path: '/step-one', parent: WizardShell)
class StepOne {
  const StepOne();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
      expect(
        output,
        containsCode(
          "GoRoute(path: '/wizard', redirect: (context, state) => '/step-one')",
        ),
      );
    });
  });

  group('go_router parity', () {
    test('forwards every GoRoute field', () async {
      final output = await generate('''
$_header

@AutoGoRoute(
  path: '/secret',
  middleware: ['guardA', 'guardB'],
  redirect: 'routeRedirect',
  onExit: 'confirmExit',
  parentNavigatorKey: 'rootKey',
  caseSensitive: false,
  metadata: {'requiresAuth': true, 'level': 3, 'tags': ['a']},
)
class SecretPage {
  const SecretPage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}

Object? guardA;
Object? guardB;
Object? routeRedirect;
Object? confirmExit;
Object? rootKey;
''');
      expect(output, containsCode('middleware: const [guardA, guardB]'));
      expect(output, contains('redirect: routeRedirect'));
      expect(output, contains('onExit: confirmExit'));
      expect(output, contains('parentNavigatorKey: rootKey'));
      expect(output, contains('caseSensitive: false'));
      expect(
        output,
        containsCode(
          "metadata: const {'requiresAuth': true, 'level': 3, 'tags': ['a']}",
        ),
      );
    });

    test('a transition emits a generated pageBuilder', () async {
      final output = await generate('''
$_header

@AutoGoRoute(
  path: '/sheet',
  transition: AutoRouteTransition.slideUp,
  transitionDurationMs: 250,
  reverseTransitionDurationMs: 150,
  fullscreenDialog: true,
  opaque: false,
  barrierDismissible: true,
  restorationId: 'sheet',
)
class SheetPage {
  const SheetPage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''');
      expect(
        output,
        containsCode('pageBuilder: (context, state) => buildAutoRoutePage('),
      );
      expect(output, contains('transition: AutoRouteTransition.slideUp'));
      expect(
        output,
        contains('transitionDuration: const Duration(milliseconds: 250)'),
      );
      expect(
        output,
        containsCode(
          'reverseTransitionDuration: const Duration(milliseconds: 150)',
        ),
      );
      expect(output, contains('fullscreenDialog: true'));
      expect(output, contains('opaque: false'));
      expect(output, contains('barrierDismissible: true'));
      expect(output, contains("restorationId: 'sheet'"));
    });

    test('a custom pageBuilder is used verbatim', () async {
      final output = await generate('''
$_header

@AutoGoRoute(path: '/custom', pageBuilder: 'myPage')
class CustomPage {
  const CustomPage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}

Object? myPage;
''');
      expect(output, contains('pageBuilder: myPage'));
      expect(output, isNot(contains('buildAutoRoutePage')));
    });

    test('buildRouter accepts every GoRouter option', () async {
      final output = await generate('''
$_header

@AutoGoRoute(path: '/a')
class APage {
  const APage();
}

@AutoGoRouteBase(
  navigatorKey: 'rootKey',
  // go_router accepts exactly one error handler, so `onException` cannot
  // appear alongside this one — see the dedicated test below.
  errorWidget: 'ErrorScreen.new',
  redirect: 'globalRedirect',
  onEnter: 'onEnter',
  observers: 'observers',
  refreshListenable: 'listenable',
  extraCodec: 'codec',
  redirectLimit: 9,
  routerNeglect: true,
  debugLogDiagnostics: true,
  requestFocus: false,
  restorationScopeId: 'app',
)
class AppRouter extends _\$AppRouter {}

class ErrorScreen {
  ErrorScreen({this.error});
  final Object? error;
}

Object? rootKey;
Object? globalRedirect;
Object? onEnter;
Object? observers;
Object? listenable;
Object? codec;
''');
      // Each annotation default is read through a top-level getter, outside
      // `buildRouter`'s parameter scope. Spliced inline, `onEnter: 'onEnter'`
      // emitted `onEnter: onEnter ?? onEnter` — the parameter both times —
      // and the annotation value was silently lost.
      expect(
        output,
        contains(r'onEnter: onEnter ?? _autoGoRouteDefault$onEnter'),
      );
      expect(
        output,
        containsCode(r'OnEnter? get _autoGoRouteDefault$onEnter => onEnter;'),
      );
      expect(output, isNot(contains('onEnter ?? onEnter')));

      expect(
        output,
        containsCode(
          r'GoRouterWidgetBuilder? get _autoGoRouteDefault$errorBuilder => '
          // `ErrorScreen.new(...)` is a valid invocation of the unnamed
          // constructor, so the reference is spliced through as written.
          '(context, state) => ErrorScreen.new(error: state.error);',
        ),
      );
      expect(
        output,
        contains(r'redirect: redirect ?? _autoGoRouteDefault$redirect'),
      );
      expect(
        output,
        containsCode(
          r'GoRouterRedirect? get _autoGoRouteDefault$redirect => globalRedirect;',
        ),
      );
      expect(
        output,
        containsCode(
          r'Codec<Object?, Object?>? get _autoGoRouteDefault$extraCodec => codec;',
        ),
      );
      expect(
        output,
        containsCode(
          r'GlobalKey<NavigatorState>? get _autoGoRouteDefault$navigatorKey => '
          'rootKey;',
        ),
      );
      expect(output, contains('redirectLimit: redirectLimit ?? 9'));
      expect(output, contains('routerNeglect: routerNeglect ?? true'));
      expect(
        output,
        contains('debugLogDiagnostics: debugLogDiagnostics ?? true'),
      );
      expect(output, contains('requestFocus: requestFocus ?? false'));
      expect(
        output,
        contains("restorationScopeId: restorationScopeId ?? 'app'"),
      );
      // Unset references pass the parameter straight through.
      expect(output, contains('errorPageBuilder: errorPageBuilder,'));
    });

    test(
      'onException is forwarded when it is the only error handler',
      () async {
        final output = await generate('''
$_header

@AutoGoRoute(path: '/a')
class APage {
  const APage();
}

@AutoGoRouteBase(onException: 'handleException')
class AppRouter extends _\$AppRouter {}

Object? handleException;
''');
        expect(
          output,
          contains(
            r'onException: onException ?? _autoGoRouteDefault$onException',
          ),
        );
        expect(
          output,
          containsCode(
            r'GoExceptionHandler? get _autoGoRouteDefault$onException => '
            'handleException;',
          ),
        );
        expect(output, contains('errorBuilder: errorBuilder,'));
      },
    );
  });

  group('naming and configuration', () {
    test('honours an explicit route name and extension name', () async {
      final output = await generate('''
$_header

@AutoGoRoute(path: '/a', name: 'alpha')
class SomeVeryLongPageName {
  const SomeVeryLongPageName();
}

@AutoGoRouteBase(navigatorExtensionName: 'AppNav', generateRouteEnum: false)
class AppRouter extends _\$AppRouter {}
''');
      expect(output, contains('extension AppNav on BuildContext'));
      expect(output, contains('void goToAlpha('));
      expect(output, isNot(contains('enum ')));
    });

    test(
      'a path parameter with a regex constraint survives escaping',
      () async {
        final output = await generate(r'''
import 'package:auto_go_route/auto_go_route.dart';

part 'app_router.routes.g.dart';

@AutoGoRoute(path: r'/users/:id(\d+)')
class UserPage {
  const UserPage({required this.id});
  final int id;
}

@AutoGoRouteBase()
class AppRouter extends _$AppRouter {}
''');
        expect(output, contains(r"path: '/users/:id(\\d+)'"));
        expect(output, contains("RouteCodec.requireInt(state, 'id')"));
      },
    );

    test('output is byte-identical across runs', () async {
      const source =
          '''
$_header

@AutoGoRoute(path: '/a')
class APage {
  const APage();
}

@AutoGoRoute(path: '/b')
class BPage {
  const BPage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''';
      expect(await generate(source), await generate(source));
    });

    test('libraries that never mention the annotations are skipped', () async {
      // The scan filters on the annotation's own name before resolving, which
      // is what keeps a large package from re-resolving every file.
      final output = await generate(
        '''
$_header

@AutoGoRoute(path: '/a')
class APage {
  const APage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''',
        extraLibraries: {
          'unrelated.dart': 'class Unrelated { const Unrelated(); }',
        },
      );
      expect(output, contains('APageRoute'));
      expect(output, isNot(contains('Unrelated')));
    });

    test('warns when a child path is written as though absolute', () async {
      final warnings = <String>[];
      await generate('''
$_header

@AutoGoRoute(path: '/products')
class ProductPage {
  const ProductPage();
}

@AutoGoRoute(path: '/reviews', parent: ProductPage)
class ReviewsPage {
  const ReviewsPage();
}

@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''', warnings: warnings);
      expect(
        warnings.join('\n'),
        allOf(contains('/products/reviews'), contains('ReviewsPage')),
      );
    });
  });
}

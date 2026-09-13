import 'package:test/test.dart';

import 'support/harness.dart';

const _tabs =
    '''
$routerHeader

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/inbox', parent: Tabs, order: 1)
class InboxTab {
  const InboxTab();
}

@AutoGoRoute(path: '/feed', parent: Tabs, order: 0)
class FeedTab {
  const FeedTab();
}

@AutoGoRouteBase(redirect: 'appRedirect', redirectLimit: 7)
class AppRouter extends _\$AppRouter {}

Object? appRedirect;
''';

void main() {
  group('dynamic routing', () {
    late String output;

    setUpAll(() async => output = await generate(_tabs));

    test('buildRoutingConfig carries the route table and its defaults', () {
      expect(output, contains('RoutingConfig buildRoutingConfig({'));
      expect(
        output,
        containsCode(
          'return RoutingConfig('
          'routes: routes ?? this.routes, '
          r'redirect: redirect ?? _autoGoRouteDefault$redirect ?? _autoGoRouteNoRedirect, '
          'onEnter: onEnter, '
          'redirectLimit: redirectLimit ?? 7)',
        ),
      );
    });

    test('RoutingConfig always receives a non-null redirect', () {
      // `RoutingConfig.redirect` is non-nullable with a private default, so
      // the fallback chain must end in a real function.
      expect(
        output,
        containsCode(
          'String? _autoGoRouteNoRedirect(BuildContext context, '
          'GoRouterState state) => null;',
        ),
      );
    });

    test(
      'buildDynamicRouter forwards the router options, not the routing ones',
      () {
        final start = output.indexOf('GoRouter buildDynamicRouter({');
        final method = output.substring(
          start,
          output.indexOf('\n  }\n', start),
        );
        expect(
          method,
          contains('required ValueListenable<RoutingConfig> routingConfig,'),
        );
        expect(method, contains('return GoRouter.routingConfig('));
        expect(method, contains('routingConfig: routingConfig,'));
        expect(method, contains('errorBuilder: errorBuilder,'));
        // Routes, redirect, onEnter and redirectLimit live on RoutingConfig.
        for (final routingOption in ['routes', 'onEnter', 'redirectLimit']) {
          expect(
            method,
            isNot(contains('$routingOption:')),
            reason: routingOption,
          );
        }
        expect(method, isNot(contains('redirect: redirect')));
      },
    );
  });

  group('branch enums', () {
    late String output;

    setUpAll(() async => output = await generate(_tabs));

    test('one enum per stateful shell, in branch order', () {
      expect(output, contains('enum TabsBranch {'));
      // `order:` puts FeedTab first even though InboxTab is declared first.
      final feed = output.indexOf("feedTab('/feed')");
      final inbox = output.indexOf("inboxTab('/inbox')");
      expect(feed, isNonNegative);
      expect(inbox, greaterThan(feed));
    });

    test('exposes navigation that cannot drift from the branch index', () {
      expect(
        output,
        containsCode(
          'static TabsBranch of(StatefulNavigationShell shell) => '
          'values[shell.currentIndex];',
        ),
      );
      expect(
        output,
        containsCode(
          'void go(StatefulNavigationShell shell, {bool initialLocation = false}) '
          '=> shell.goBranch(index, initialLocation: initialLocation);',
        ),
      );
      expect(
        output,
        containsCode(
          'void goFrom(BuildContext context, {bool initialLocation = false}) => '
          'StatefulNavigationShell.of(context).goBranch(index, '
          'initialLocation: initialLocation);',
        ),
      );
      expect(
        output,
        containsCode(
          'bool isActiveIn(StatefulNavigationShell shell) => '
          'shell.currentIndex == index;',
        ),
      );
    });

    test('no enum for a stateless shell, or when enums are disabled', () async {
      final stateless = await generate('''
$routerHeader

@AutoGoRouteShell(path: '/wrap')
class Wrap {
  const Wrap({required this.child});
  final Widget child;
}

@AutoGoRoute(path: '/inner', parent: Wrap)
class Inner {
  const Inner();
}

$routerBase
''');
      expect(stateless, isNot(contains('enum WrapBranch')));

      final disabled = await generate(
        _tabs.replaceFirst(
          "@AutoGoRouteBase(redirect: 'appRedirect', redirectLimit: 7)",
          "@AutoGoRouteBase(redirect: 'appRedirect', generateRouteEnum: false)",
        ),
      );
      expect(disabled, isNot(contains('enum TabsBranch')));
    });

    test('a branch route named like an enum member is refused', () async {
      for (final name in ['go', 'goFrom', 'of', 'initialLocation']) {
        final message = await errorFor('''
$routerHeader

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/a', parent: Tabs, name: '$name')
class PageA {
  const PageA();
}

$routerBase
''');
        expect(
          message,
          allOf(contains('TabsBranch'), contains('"$name"')),
          reason: name,
        );
      }
    });

    test('an enum name taken by an annotated widget is refused', () async {
      final message = await errorFor('''
$routerHeader

@AutoGoRouteShell(path: '/', isStateful: true)
class Tabs {
  const Tabs({required this.navigationShell});
  final StatefulNavigationShell navigationShell;
}

@AutoGoRoute(path: '/a', parent: Tabs)
class TabsBranch {
  const TabsBranch();
}

$routerBase
''');
      expect(message, contains('`TabsBranch`'));
    });
  });
}

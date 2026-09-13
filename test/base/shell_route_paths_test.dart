import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_router.dart';

class _Shell extends ShellRoutePaths {
  const _Shell({
    super.navigatorKey,
    super.middleware,
    super.observers,
    super.restorationScopeId,
    super.notifyRootObserver,
    super.metadata,
    super.parentNavigatorKey,
  }) : super(path: '/', name: 'shell', builder: _build);

  static Widget _build(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => Scaffold(
    appBar: AppBar(title: const Text('shell')),
    body: child,
  );
}

class _StatefulShell extends ShellRoutePaths {
  const _StatefulShell({super.navigatorContainerBuilder})
    : super(
        path: '/',
        name: 'stateful',
        isStateful: true,
        statefulBuilder: _build,
      );

  static Widget _build(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell shell,
  ) => Scaffold(body: shell);
}

void main() {
  group('toShellRoute', () {
    test('forwards every field go_router accepts', () {
      final navigatorKey = GlobalKey<NavigatorState>();
      final parentKey = GlobalKey<NavigatorState>();
      final observers = <NavigatorObserver>[NavigatorObserver()];
      String? guard(BuildContext c, GoRouterState s) => '/login';

      final shellRoute =
          _Shell(
            navigatorKey: navigatorKey,
            middleware: [guard],
            observers: observers,
            restorationScopeId: 'scope',
            notifyRootObserver: false,
            metadata: const {'k': 'v'},
            parentNavigatorKey: parentKey,
          ).toShellRoute(
            routes: [GoRoute(path: '/a', builder: _leaf)],
          );

      expect(shellRoute.navigatorKey, same(navigatorKey));
      expect(shellRoute.parentNavigatorKey, same(parentKey));
      expect(shellRoute.observers, same(observers));
      expect(shellRoute.restorationScopeId, 'scope');
      expect(shellRoute.notifyRootObserver, isFalse);
      expect(shellRoute.metadata, const {'k': 'v'});
      expect(shellRoute.redirect, same(guard));
      expect(shellRoute.builder, isNotNull);
    });

    test('refuses to build a plain ShellRoute for a stateful shell', () {
      // 1.x ignored `isStateful` here and handed the widget a plain child,
      // which failed later as a cast error in user code.
      expect(
        () => _StatefulShell().toShellRoute(
          routes: [GoRoute(path: '/a', builder: _leaf)],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('toStatefulShellRoute'),
          ),
        ),
      );
    });
  });

  group('toStatefulShellRoute', () {
    test('emits an indexed stack by default', () {
      final route = _StatefulShell().toStatefulShellRoute(
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/a', builder: _leaf)],
          ),
        ],
      );
      expect(route.branches, hasLength(1));
      expect(route.builder, isNotNull);
    });

    test('uses the general constructor when a container builder is given', () {
      Widget container(
        BuildContext context,
        StatefulNavigationShell shell,
        List<Widget> children,
      ) => Column(children: children);

      final route = _StatefulShell(navigatorContainerBuilder: container)
          .toStatefulShellRoute(
            branches: [
              StatefulShellBranch(
                routes: [GoRoute(path: '/a', builder: _leaf)],
              ),
            ],
          );
      expect(route.navigatorContainerBuilder, same(container));
    });

    test('refuses a stateless shell', () {
      expect(
        () => _Shell().toStatefulShellRoute(branches: []),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('constructor assertions', () {
    test('a stateless shell needs exactly one of builder or pageBuilder', () {
      expect(() => _BadShell(), throwsA(isA<AssertionError>()));
    });

    test('a stateful shell needs a stateful builder', () {
      expect(() => _BadStatefulShell(), throwsA(isA<AssertionError>()));
    });
  });

  testWidgets('a shell wraps its children in a live router', (tester) async {
    await pumpRouter(
      tester,
      routes: [
        _Shell().toShellRoute(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Text('child'),
            ),
          ],
        ),
      ],
    );
    expect(find.text('shell'), findsOneWidget);
    expect(find.text('child'), findsOneWidget);
  });

  test('equality ignores the builder closure', () {
    expect(_Shell(), _Shell());
    expect(_Shell().hashCode, _Shell().hashCode);
  });

  test('toString names the shell', () {
    expect(_Shell().toString(), contains('isStateful: false'));
  });
}

Widget _leaf(BuildContext context, GoRouterState state) =>
    const SizedBox.shrink();

class _BadShell extends ShellRoutePaths {
  const _BadShell() : super(path: '/', name: 'bad');
}

class _BadStatefulShell extends ShellRoutePaths {
  const _BadStatefulShell()
    : super(path: '/', name: 'bad', isStateful: true, builder: _wrongBuilder);

  static Widget _wrongBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => child;
}

// Regressions found by the pre-release adversarial review. Each of these
// passed the original suite.
import 'dart:async';

import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_router.dart';

class _Route extends RoutePaths {
  const _Route(String path, {super.name, super.middleware, super.redirect})
    : super(path: path, builder: _build);

  static Widget _build(BuildContext context, GoRouterState state) =>
      Scaffold(body: Text('at ${state.uri.path}'));
}

class _Tabs extends ShellRoutePaths {
  const _Tabs({super.metadata})
    : super(path: '/', name: 'tabs', isStateful: true, statefulBuilder: _build);

  static Widget _build(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell shell,
  ) => Scaffold(body: shell);
}

enum _Colour { red, green }

void main() {
  group('state getters follow an imperative push', () {
    // `currentConfiguration.uri`/`fullPath` describe the declarative stack; a
    // push appends an ImperativeRouteMatch whose own matches are the visible
    // location. Reading straight off the configuration reported the route
    // *underneath* the pushed one.
    testWidgets('location, name, template and isOnRoute', (tester) async {
      const home = _Route('/', name: 'home');
      const detail = _Route('/detail/:id', name: 'detail');
      final router = await pumpRouter(
        tester,
        routes: [home.toGoRoute(), detail.toGoRoute()],
      );

      unawaited(
        tester
            .element(find.text('at /'))
            .pushRoute(detail, params: {'id': '7'}),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.text('at /detail/7'));

      expect(router.currentLocation, '/detail/7');
      expect(router.currentRouteName, 'detail');
      expect(router.currentRouteTemplate, '/detail/:id');
      expect(router.currentMatchedLocation, '/detail/7');
      expect(context.isOnRoute(detail), isTrue);
      expect(context.isOnRoute(home), isFalse);
      expect(context.isOnNamedRoute('detail'), isTrue);
    });
  });

  group('deprecated 1.x helpers still work', () {
    testWidgets('BuildContext helpers', (tester) async {
      const home = _Route('/', name: 'home');
      const detail = _Route('/detail/:id', name: 'detail');
      final router = await pumpRouter(
        tester,
        routes: [home.toGoRoute(), detail.toGoRoute()],
      );
      BuildContext at(String text) => tester.element(find.text(text));

      // ignore: deprecated_member_use_from_same_package
      at('at /').goWithParams(detail, {'id': 3});
      await tester.pumpAndSettle();
      expect(router.currentLocation, '/detail/3');

      // ignore: deprecated_member_use_from_same_package
      expect(at('at /detail/3').canPopSafely(), isFalse);
      // ignore: deprecated_member_use_from_same_package
      at('at /detail/3').safePop();
      await tester.pumpAndSettle();
      expect(router.currentLocation, '/');

      // ignore: deprecated_member_use_from_same_package
      at('at /').goToNamed('detail', pathParameters: {'id': '4'});
      await tester.pumpAndSettle();
      expect(router.currentLocation, '/detail/4');

      // ignore: deprecated_member_use_from_same_package
      at('at /detail/4').popOrHome();
      await tester.pumpAndSettle();
      expect(router.currentLocation, '/');

      unawaited(at('at /').pushRoute(detail, params: {'id': '5'}));
      await tester.pumpAndSettle();
      // ignore: deprecated_member_use_from_same_package
      at('at /detail/5').popUntilRoute('/');
      await tester.pumpAndSettle();
      expect(router.currentLocation, '/');

      // ignore: deprecated_member_use_from_same_package
      expect(router.location, '/');
      // ignore: deprecated_member_use_from_same_package
      expect(router.safeLocation, '/');
      // ignore: deprecated_member_use_from_same_package
      expect(router.safeCurrentRouteName, '/');
    });
  });

  group('stateful shells keep their metadata', () {
    // `StatefulShellRoute.indexedStack` has no `metadata` parameter, so going
    // through it silently dropped the shell's metadata — and every guard that
    // reads it for a child.
    testWidgets('a child sees the shell metadata', (tester) async {
      GoRouterState? seen;
      final shell = const _Tabs(metadata: {'requiresAuth': true})
          .toStatefulShellRoute(
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/feed',
                    builder: (context, state) {
                      seen = state;
                      return const Text('feed');
                    },
                  ),
                ],
              ),
            ],
          );
      await pumpRouter(tester, routes: [shell], initialLocation: '/feed');

      expect(shell.metadata, {'requiresAuth': true});
      expect(seen!.metadataAs<bool>('requiresAuth'), isTrue);
    });

    testWidgets('the default layout shows only the active branch', (
      tester,
    ) async {
      final router = await pumpRouter(
        tester,
        routes: [
          const _Tabs().toStatefulShellRoute(
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/a',
                    builder: (c, s) => const Text('branch a'),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/b',
                    builder: (c, s) => const Text('branch b'),
                  ),
                ],
              ),
            ],
          ),
        ],
        initialLocation: '/a',
      );
      expect(find.text('branch a'), findsOneWidget);
      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('branch b'), findsOneWidget);
      // The inactive branch stays mounted (state preserved) but offstage.
      expect(find.text('branch a', skipOffstage: false), findsOneWidget);
      expect(find.text('branch a'), findsNothing);
    });
  });

  group('transitions outside a MaterialApp', () {
    // `MaterialLocalizations.of` throws with no Material ancestor, so a
    // dismissible animated page crashed inside a CupertinoApp.
    testWidgets('a dismissible page builds in a CupertinoApp', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => buildAutoRoutePage<void>(
              context: context,
              state: state,
              transition: AutoRouteTransition.fade,
              opaque: false,
              barrierDismissible: true,
              barrierColor: const Color(0x80000000),
              child: const Text('sheet'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(CupertinoApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('sheet'), findsOneWidget);
    });

    testWidgets('the barrier label falls back when nothing localises it', (
      tester,
    ) async {
      late Page<void> page;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => page = buildAutoRoutePage<void>(
              context: context,
              state: state,
              transition: AutoRouteTransition.none,
              barrierDismissible: true,
              child: const Text('x'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(CupertinoApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect((page as CustomTransitionPage<void>).barrierLabel, isNotEmpty);
    });
  });

  group('RouteUtils', () {
    test('normalizePath keeps a leading segment after //', () {
      // Uri.parse('//products/42') treats `products` as the authority.
      expect(RouteUtils.normalizePath('//products//42'), '/products/42');
      expect(RouteUtils.normalizePath('//a/b?q=1#f'), '/a/b?q=1#f');
      expect(RouteUtils.normalizePath('/a?next=//b'), '/a?next=//b');
    });

    test('isValidTemplate accepts constraints containing ? or #', () {
      expect(RouteUtils.isValidTemplate(r'/p/:id(\d?)'), isTrue);
      expect(RouteUtils.isValidTemplate('/p/:hex(#[0-9a-f]{6})'), isTrue);
      expect(RouteUtils.isValidTemplate('/p/:id?'), isFalse);
      expect(RouteUtils.isValidTemplate('/p#frag'), isFalse);
    });

    test('extractParams matches a template ending in a literal', () {
      expect(RouteUtils.extractParams('/orders/:id/items', '/orders/9/items'), {
        'id': '9',
      });
      expect(
        RouteUtils.extractParams('/orders/:id/items', '/orders/9/other'),
        isNull,
      );
    });

    test('similarity treats parameters as wildcards and credits typos', () {
      expect(
        RouteUtils.calculateRouteSimilarity('/products/:id', '/products/42'),
        1.0,
      );
      expect(
        RouteUtils.calculateRouteSimilarity('/products', '/prodcuts'),
        greaterThan(0.6),
      );
      expect(RouteUtils.calculateRouteSimilarity('/products', '/zzz'), 0.0);
    });

    test('findClosest suggests the route a typo meant', () {
      final registry = RouteRegistry.scoped()
        ..registerAll(const [
          _Route('/products', name: 'products'),
          _Route('/profile', name: 'profile'),
        ]);
      expect(registry.findClosest('/prodcuts')?.name, 'products');
    });
  });

  group('parameters', () {
    testWidgets('nullable BigInt, DateTime and Uri read when present', (
      tester,
    ) async {
      final probe = StateProbe();
      await pumpRouter(
        tester,
        routes: [probe.route('/a')],
        initialLocation:
            '/a?big=12&when=2026-01-01T00:00:00.000Z&link=https%3A%2F%2Fa.test',
      );
      final state = probe.state!;
      expect(state.getParam<BigInt?>('big'), BigInt.from(12));
      expect(state.getParam<DateTime?>('when'), DateTime.utc(2026));
      expect(state.getParam<Uri?>('link'), Uri.parse('https://a.test'));
      expect(state.getParam<BigInt?>('absent'), isNull);
    });

    testWidgets('an untyped read yields the raw string', (tester) async {
      // Dart infers `dynamic` for `getTypedPathParameters()` with no type
      // argument, which used to throw an ArgumentError.
      final probe = StateProbe();
      await pumpRouter(
        tester,
        routes: [probe.route('/a/:id/:slug')],
        initialLocation: '/a/7/hello',
      );
      final state = probe.state!;
      expect(state.getParam<dynamic>('id'), '7');
      expect(state.getParam<Object>('slug'), 'hello');
      // The missing type argument is the point of this assertion.
      // ignore: inference_failure_on_function_invocation
      expect(state.getTypedPathParameters(), {'id': '7', 'slug': 'hello'});
    });

    testWidgets('typed path maps skip values that do not convert', (
      tester,
    ) async {
      final probe = StateProbe();
      await pumpRouter(
        tester,
        routes: [probe.route('/a/:n/:word')],
        initialLocation: '/a/7/seven',
      );
      expect(probe.state!.getTypedPathParameters<int>(), {'n': 7});
    });

    testWidgets('every list codec decodes, and rejects a bad element', (
      tester,
    ) async {
      final probe = StateProbe();
      await pumpRouter(
        tester,
        routes: [probe.route('/a')],
        initialLocation:
            '/a?b=true&b=0&n=1.5&n=2&big=9&d=2026-01-01T00:00:00.000Z'
            '&u=https%3A%2F%2Fa.test&c=red&c=green&bad=maybe',
      );
      final state = probe.state!;
      expect(RouteCodec.boolList(state, 'b'), [true, false]);
      expect(RouteCodec.numList(state, 'n'), [1.5, 2]);
      expect(RouteCodec.bigIntList(state, 'big'), [BigInt.from(9)]);
      expect(RouteCodec.dateTimeList(state, 'd'), [DateTime.utc(2026)]);
      expect(RouteCodec.uriList(state, 'u'), [Uri.parse('https://a.test')]);
      expect(RouteCodec.enumList(state, 'c', _Colour.values), [
        _Colour.red,
        _Colour.green,
      ]);
      expect(
        () => RouteCodec.boolList(state, 'bad'),
        throwsA(isA<RouteParamFormatException>()),
      );
    });

    testWidgets('flag reads presence, and still rejects garbage', (
      tester,
    ) async {
      final probe = StateProbe();
      await pumpRouter(
        tester,
        routes: [probe.route('/a')],
        initialLocation: '/a?on&off=false&bad=maybe',
      );
      final state = probe.state!;
      expect(RouteCodec.flag(state, 'on'), isTrue);
      expect(RouteCodec.flag(state, 'off'), isFalse);
      expect(RouteCodec.flag(state, 'absent'), isFalse);
      expect(
        () => RouteCodec.flag(state, 'bad'),
        throwsA(isA<RouteParamFormatException>()),
      );
    });
  });

  group('guards', () {
    test('a route redirect runs before its middleware', () {
      final calls = <String>[];
      String? redirect(BuildContext c, GoRouterState s) {
        calls.add('redirect');
        return null;
      }

      String? guard(BuildContext c, GoRouterState s) {
        calls.add('middleware');
        return '/stop';
      }

      final result = _Route(
        '/a',
        redirect: redirect,
        middleware: [guard],
      ).composedRedirect!(_FakeContext(), _FakeState());
      expect(result, '/stop');
      expect(calls, ['redirect', 'middleware']);
    });

    test('a route redirect that redirects short-circuits middleware', () {
      var middlewareRan = false;
      final result = _Route(
        '/a',
        redirect: (c, s) => '/first',
        middleware: [
          (c, s) {
            middlewareRan = true;
            return '/second';
          },
        ],
      ).composedRedirect!(_FakeContext(), _FakeState());
      expect(result, '/first');
      expect(middlewareRan, isFalse);
    });

    test('an async global redirect composes ahead of a route guard', () async {
      final calls = <String>[];
      final registry = RouteRegistry.scoped()
        ..register(
          _Route(
            '/a',
            name: 'a',
            middleware: [
              (c, s) {
                calls.add('route');
                return '/route';
              },
            ],
          ),
        );
      final route = registry
          .generateGoRoutes(
            globalRedirect: (c, s) async {
              calls.add('global');
              return null;
            },
          )
          .single;
      expect(await route.redirect!(_FakeContext(), _FakeState()), '/route');
      expect(calls, ['global', 'route']);
    });

    test('an async global redirect that redirects wins', () async {
      final registry = RouteRegistry.scoped()
        ..register(_Route('/a', name: 'a', middleware: [(c, s) => '/route']));
      final route = registry
          .generateGoRoutes(globalRedirect: (c, s) async => '/global')
          .single;
      expect(await route.redirect!(_FakeContext(), _FakeState()), '/global');
    });
  });

  test('GoRoute.copyWith accepts go_router\'s own ExitCallback shape', () {
    // Declared as `Future<bool> Function(...)`, which a synchronous
    // `FutureOr<bool>` callback does not satisfy.
    FutureOr<bool> syncExit(BuildContext context, GoRouterState state) => true;
    final copy = GoRoute(
      path: '/a',
      builder: (c, s) => const SizedBox.shrink(),
    ).copyWith(onExit: syncExit);
    expect(copy.onExit, same(syncExit));
  });

  group('exception hierarchy', () {
    test('each exception names itself and its subject', () {
      expect(
        const RouteGenerationException('boom', 'home').toString(),
        'RouteGenerationException for home: boom',
      );
      expect(
        const RouteValidationException('bad', '/a').toString(),
        'RouteValidationException for /a: bad',
      );
      expect(
        const NavigationException('nope', null).toString(),
        'NavigationException: nope',
      );
      expect(
        const ParameterException('bad', 'id', 'int').toString(),
        'ParameterException for id (expected int): bad',
      );
      expect(
        const RouteGenerationException('x', null),
        isA<AutoGoRouteException>(),
      );
    });
  });
}

class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeState implements GoRouterState {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

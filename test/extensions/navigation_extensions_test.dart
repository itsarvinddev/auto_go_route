import 'dart:async';

import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_router.dart';

class _Detail extends RoutePaths {
  const _Detail()
    : super(path: '/products/:id', name: 'detail', builder: _build);

  static Widget _build(BuildContext context, GoRouterState state) =>
      Scaffold(body: Text('detail ${state.pathParameters['id']}'));
}

class _Home extends RoutePaths {
  const _Home() : super(path: '/', name: 'home', builder: _build);

  static Widget _build(BuildContext context, GoRouterState state) =>
      const Scaffold(body: Text('home'));
}

void main() {
  final home = _Home();
  final detail = _Detail();
  late List<RouteBase> routes;

  setUp(() {
    routes = [home.toGoRoute(), detail.toGoRoute()];
  });

  /// `context.pushNamed(...)` was a hard compile error in 1.x: an extension
  /// member on `BuildContext` named `pushNamed` collided with go_router's
  /// `GoRouterHelper`, so every call site importing both packages failed with
  /// `ambiguous_extension_member_access`. That this file compiles at all is
  /// the regression test.
  testWidgets("go_router's own BuildContext helpers stay reachable", (
    tester,
  ) async {
    await pumpRouter(tester, routes: routes);
    final context = tester.element(find.text('home'));
    // Not awaited: a push completes only when the route is popped.
    unawaited(context.pushNamed<void>('detail', pathParameters: {'id': '1'}));
    await tester.pumpAndSettle();
    expect(find.text('detail 1'), findsOneWidget);
  });

  testWidgets('locationOf builds a URL without navigating', (tester) async {
    await pumpRouter(tester, routes: routes);
    final context = tester.element(find.text('home'));
    expect(
      context.locationOf(detail, params: {'id': '9'}, queries: {'q': 'x'}),
      '/products/9?q=x',
    );
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('goToRoute navigates and replaces the stack', (tester) async {
    final router = await pumpRouter(tester, routes: routes);
    tester.element(find.text('home')).goToRoute(detail, params: {'id': '3'});
    await tester.pumpAndSettle();
    expect(find.text('detail 3'), findsOneWidget);
    expect(router.currentLocation, '/products/3');
  });

  testWidgets('pushRoute pushes and completes with the popped value', (
    tester,
  ) async {
    await pumpRouter(tester, routes: routes);
    final future = tester
        .element(find.text('home'))
        .pushRoute<String>(detail, params: {'id': '4'});
    await tester.pumpAndSettle();
    expect(find.text('detail 4'), findsOneWidget);

    tester.element(find.text('detail 4')).pop('done');
    await tester.pumpAndSettle();
    expect(await future, 'done');
  });

  testWidgets('replaceRoute swaps the top of the stack', (tester) async {
    final router = await pumpRouter(tester, routes: routes);
    tester.element(find.text('home')).replaceRoute(detail, params: {'id': '5'});
    await tester.pumpAndSettle();
    expect(router.currentLocation, '/products/5');
  });

  testWidgets('replaceRouteInPlace swaps without a history entry', (
    tester,
  ) async {
    final router = await pumpRouter(tester, routes: routes);
    tester
        .element(find.text('home'))
        .replaceRouteInPlace(detail, params: {'id': '6'});
    await tester.pumpAndSettle();
    expect(router.currentLocation, '/products/6');
  });

  testWidgets('goToRouteWithParams stringifies values', (tester) async {
    await pumpRouter(tester, routes: routes);
    tester.element(find.text('home')).goToRouteWithParams(detail, {'id': 8});
    await tester.pumpAndSettle();
    expect(find.text('detail 8'), findsOneWidget);
  });

  testWidgets('goToRouteWithParams refuses a null path value', (tester) async {
    // Dropping the segment would build a URL for a *different* route.
    await pumpRouter(tester, routes: routes);
    expect(
      () => tester.element(find.text('home')).goToRouteWithParams(detail, {
        'id': null,
      }),
      throwsArgumentError,
    );
  });

  testWidgets('popOrGo falls back when there is nothing to pop', (
    tester,
  ) async {
    final router = await pumpRouter(
      tester,
      routes: routes,
      initialLocation: '/products/1',
    );
    tester.element(find.text('detail 1')).popOrGo('/');
    await tester.pumpAndSettle();
    expect(router.currentLocation, '/');
  });

  testWidgets('popOrGo pops when it can', (tester) async {
    final router = await pumpRouter(tester, routes: routes);
    unawaited(
      tester.element(find.text('home')).pushRoute(detail, params: {'id': '2'}),
    );
    await tester.pumpAndSettle();
    tester.element(find.text('detail 2')).popOrGo('/nowhere');
    await tester.pumpAndSettle();
    expect(router.currentLocation, '/');
  });

  testWidgets('popUntilLocation stops at the requested location', (
    tester,
  ) async {
    await pumpRouter(tester, routes: routes);
    final context = tester.element(find.text('home'));
    unawaited(context.pushRoute(detail, params: {'id': '1'}));
    await tester.pumpAndSettle();
    unawaited(
      tester
          .element(find.text('detail 1'))
          .pushRoute(detail, params: {'id': '2'}),
    );
    await tester.pumpAndSettle();

    tester.element(find.text('detail 2')).popUntilLocation('/products/1');
    await tester.pumpAndSettle();
    expect(find.text('detail 1'), findsOneWidget);
  });

  testWidgets('popUntilLocation is bounded when the location never matches', (
    tester,
  ) async {
    // The loop cannot observe a refused pop, so it must not be able to spin.
    final router = await pumpRouter(tester, routes: routes);
    unawaited(
      tester.element(find.text('home')).pushRoute(detail, params: {'id': '1'}),
    );
    await tester.pumpAndSettle();
    tester.element(find.text('detail 1')).popUntilLocation('/nope');
    await tester.pumpAndSettle();
    expect(router.currentLocation, '/');
  });

  group('state getters', () {
    testWidgets('report the current location, name and template', (
      tester,
    ) async {
      final router = await pumpRouter(
        tester,
        routes: routes,
        initialLocation: '/products/7?q=1',
      );
      final context = tester.element(find.text('detail 7'));

      expect(context.currentLocation, '/products/7?q=1');
      // 1.x returned `matchedLocation` here, so every name comparison failed.
      expect(context.currentRouteName, 'detail');
      expect(context.currentRouteTemplate, '/products/:id');
      expect(context.isOnRoute(detail), isTrue);
      expect(context.isOnRoute(home), isFalse);
      expect(context.isOnNamedRoute('detail'), isTrue);
      expect(context.isOnNamedRoute('home'), isFalse);

      expect(router.currentLocation, '/products/7?q=1');
      expect(router.currentRouteName, 'detail');
      expect(router.currentRouteTemplate, '/products/:id');
      expect(router.canGoBack, isFalse);
    });
  });
}

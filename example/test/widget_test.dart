// End-to-end tests for the *generated* router.
//
// They drive the real `GoRouter` that `buildRouter()` produces from the
// committed `app_router.routes.g.dart`. On their own they test that file, not
// the generator: CI regenerates it first and fails if the fresh output differs
// from what is committed, and it is that pairing that makes these the
// generator's acceptance tests.
import 'package:auto_go_route/auto_go_route.dart';
import 'package:example/src/app_router.dart';
import 'package:example/src/auth_service.dart';
import 'package:example/src/presentation/models/product.dart';
import 'package:example/src/presentation/screens/product_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Pumps the app at [location] and returns its router.
Future<GoRouter> pumpApp(
  WidgetTester tester, {
  String? location,
  bool signedIn = false,
  String role = 'user',
}) async {
  signedIn ? authService.login(role: role) : authService.logout();
  addTearDown(authService.logout);

  final router = AppRouter().buildRouter(
    initialLocation: location,
    refreshListenable: authService,
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: authService,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('boots at the annotation default location', (tester) async {
    final router = await pumpApp(tester);
    expect(router.currentLocation, '/home-screen');
    expect(find.text('Welcome'), findsOneWidget);
  });

  testWidgets('the root shell redirects "/" to the first branch', (
    tester,
  ) async {
    // A shell contributes no URL segment, so "/" matches nothing without the
    // generated redirect.
    final router = await pumpApp(tester, location: '/');
    expect(router.currentLocation, '/home-screen');
  });

  testWidgets('the bottom navigation bar switches branches', (tester) async {
    final router = await pumpApp(tester, signedIn: true);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(router.currentLocation, '/settings');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(router.currentLocation, '/home-screen');
  });

  testWidgets('the generated branch enum switches tabs', (tester) async {
    final router = await pumpApp(tester, signedIn: true);
    await tester.ensureVisible(find.text('Settings tab (typed branch switch)'));
    await tester.tap(find.text('Settings tab (typed branch switch)'));
    await tester.pumpAndSettle();
    expect(router.currentLocation, '/settings');
    expect(DashboardShellBranch.values.map((b) => b.initialLocation), [
      '/home-screen',
      '/profile',
      '/settings',
    ]);
  });

  testWidgets('routing config can change while the app runs', (tester) async {
    final app = AppRouter();
    final config = ValueNotifier(app.buildRoutingConfig());
    final router = app.buildDynamicRouter(
      routingConfig: config,
      initialLocation: '/products',
      refreshListenable: authService,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authService,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Products'), findsOneWidget);

    // A feature flag turns the product list off without rebuilding the router.
    config.value = app.buildRoutingConfig(
      redirect: (context, state) =>
          state.uri.path == '/products' ? '/home-screen' : null,
    );
    router.go('/products');
    await tester.pumpAndSettle();
    expect(router.currentLocation, '/home-screen');
  });

  group('guards', () {
    testWidgets('metadata sends an unauthenticated user to login', (
      tester,
    ) async {
      final router = await pumpApp(tester, location: '/profile');
      expect(router.currentLocation, startsWith('/login'));
      // The guard carries the origin so login can return there.
      expect(router.currentLocation, contains('from=%2Fprofile'));
      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets('an authenticated user reaches the guarded route', (
      tester,
    ) async {
      final router = await pumpApp(
        tester,
        location: '/profile',
        signedIn: true,
      );
      expect(router.currentLocation, '/profile');
      expect(
        find.text('This route is guarded by its metadata.'),
        findsOneWidget,
      );
    });

    testWidgets('a role mismatch is redirected away', (tester) async {
      final router = await pumpApp(tester, location: '/admin', signedIn: true);
      expect(router.currentLocation, '/home-screen');
    });

    testWidgets('the right role gets through', (tester) async {
      final router = await pumpApp(
        tester,
        location: '/admin',
        signedIn: true,
        role: 'admin',
      );
      expect(router.currentLocation, '/admin');
      expect(find.text('You have the admin role.'), findsOneWidget);
    });

    testWidgets('a route-level redirect moves a legacy location', (
      tester,
    ) async {
      final router = await pumpApp(
        tester,
        location: '/account',
        signedIn: true,
      );
      expect(router.currentLocation, '/profile');
    });

    testWidgets('middleware redirects a flagged-off route', (tester) async {
      final router = await pumpApp(tester, location: '/new-feature');
      expect(router.currentLocation, contains('feature-disabled=true'));
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('signing in moves the user off the login screen', (
      tester,
    ) async {
      final router = await pumpApp(tester, location: '/login');
      expect(router.currentLocation, startsWith('/login'));

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      // `refreshListenable` re-runs the guard the moment auth changes.
      expect(router.currentLocation, isNot(startsWith('/login')));
    });
  });

  group('typed parameters', () {
    testWidgets('an int path parameter reaches the widget as an int', (
      tester,
    ) async {
      await pumpApp(tester, location: '/products/123');
      expect(find.text('Product #123'), findsOneWidget);
    });

    testWidgets('a digits-only constraint rejects a non-numeric id', (
      tester,
    ) async {
      final router = await pumpApp(tester, location: '/products/abc');
      // `:id(\d+)` does not match, and `/products` only prefix-matches with
      // no child to take `abc`, so nothing matches: the error widget renders.
      expect(router.currentLocation, '/products/abc');
      expect(find.text('Product #abc'), findsNothing);
      expect(find.text('404 - Oops!'), findsOneWidget);
    });

    testWidgets('an enum and a repeated key decode from the query string', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: '/products?sort=priceAsc&tags=new&tags=sale&page=3',
      );
      expect(find.text('page 3 · tags: new, sale'), findsOneWidget);
      expect(find.text('sorted by priceAsc'), findsWidgets);
    });

    testWidgets('a missing query parameter falls back to the widget default', (
      tester,
    ) async {
      await pumpApp(tester, location: '/products');
      expect(find.text('page 1 · tags: none'), findsOneWidget);
      expect(find.text('sorted by rating'), findsWidgets);
    });

    testWidgets('a renamed query parameter is read under its wire name', (
      tester,
    ) async {
      await pumpApp(tester, location: '/home-screen?feature-disabled=true');
      await tester.pumpAndSettle();
      expect(find.text('That feature is currently disabled.'), findsOneWidget);
    });
  });

  group('generated navigation helpers', () {
    testWidgets('goTo… builds a typed location and navigates', (tester) async {
      final router = await pumpApp(tester);
      final context = tester.element(find.text('Welcome'));

      context.goToProductDetails(id: 42, name: 'Answer');
      await tester.pumpAndSettle();

      expect(router.currentLocation, '/products/42?name=Answer');
      expect(find.text('Product #42'), findsOneWidget);
    });

    testWidgets('locationOf… builds a URL without navigating', (tester) async {
      final router = await pumpApp(tester);
      final context = tester.element(find.text('Welcome'));

      expect(context.locationOfProductReviews(id: 7), '/products/7/reviews');
      expect(router.currentLocation, '/home-screen');
    });

    testWidgets('pushTo… carries an extra payload', (tester) async {
      await pumpApp(tester);
      tester
          .element(find.text('Welcome'))
          .pushToProductDetails(
            id: 5,
            extra: Product(id: '5', name: 'Five'),
          );
      await tester.pumpAndSettle();
      expect(find.textContaining('Five'), findsOneWidget);
    });

    testWidgets('a deep link without an extra still renders', (tester) async {
      // The screen has to survive a cold link, which carries no `extra`.
      await pumpApp(tester, location: '/products/9');
      expect(find.text('Extra: not passed (deep link)'), findsOneWidget);
    });

    testWidgets('replaceInPlaceWith… swaps the query string', (tester) async {
      final router = await pumpApp(tester, location: '/products');
      await tester.tap(find.text('priceDesc'));
      await tester.pumpAndSettle();
      expect(router.currentLocation, contains('sort=priceDesc'));
    });
  });

  group('nesting and shells', () {
    testWidgets('a nested route resolves to the joined path', (tester) async {
      final router = await pumpApp(tester, location: '/products/3/reviews');
      expect(router.currentLocation, '/products/3/reviews');
      expect(find.text('Reviews for product 3'), findsOneWidget);
    });

    testWidgets('the profile shell wraps its tabs', (tester) async {
      await pumpApp(tester, location: '/profile', signedIn: true);
      expect(find.text('My profile'), findsOneWidget);
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Notifications'), findsWidgets);
    });

    testWidgets('a non-root shell redirects from its own path', (tester) async {
      final router = await pumpApp(
        tester,
        location: '/profile-shell',
        signedIn: true,
      );
      expect(router.currentLocation, '/profile');
    });

    testWidgets('a deeply nested route inherits the parent path parameter', (
      tester,
    ) async {
      final router = await pumpApp(
        tester,
        location: '/notifications/N1/action?action=archive',
        signedIn: true,
      );
      expect(router.currentLocation, contains('/notifications/N1/action'));
      expect(find.text('archive N1'), findsOneWidget);
    });

    testWidgets('the overlay shell redirects from its own path', (
      tester,
    ) async {
      final router = await pumpApp(tester, location: '/bottom-sheet');
      expect(router.currentLocation, '/content');
      expect(find.text('This sheet has its own URL.'), findsOneWidget);
    });
  });

  group('the generated router surface', () {
    test('exposes every route, shell and location', () {
      final router = AppRouter();
      expect(router.allRoutes, isNotEmpty);
      expect(router.allShells, hasLength(3));
      expect(router.routes, isNotEmpty);

      // Static constants make a route's identity usable in guards and tests
      // without building a location.
      expect(ProductDetailsRouteRoute.routeName, 'productDetails');
      expect(ProductDetailsRouteRoute.routeTemplate, r'/products/:id(\d+)');
    });

    test('the route enum lists every route', () {
      expect(AppRoute.values, isNotEmpty);
      expect(
        AppRoute.values.map((route) => route.routeName),
        contains('productDetails'),
      );
      expect(
        AppRoute.values.firstWhere((r) => r.routeName == 'homeRoute').template,
        '/home-screen',
      );
    });

    test('every registered route passes validation', () {
      final registry = RouteRegistry.scoped()
        ..registerAll(AppRouter().allRoutes);
      expect(registry.validate().errors, isEmpty);
    });

    test('pathWith encodes typed values', () {
      final route = AppRouter().productListRouteRoute;
      expect(
        route.pathWith(sort: ProductSort.priceDesc, tags: const ['a', 'b']),
        '/products?sort=priceDesc&tags=a&tags=b',
      );
      expect(route.pathWith(), '/products');
    });

    test('buildRouter overrides the annotation defaults', () {
      final router = AppRouter().buildRouter(initialLocation: '/login');
      addTearDown(router.dispose);
      expect(router.routeInformationProvider.value.uri.path, '/login');
    });
  });
}

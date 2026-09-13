import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a real router over [routes] and returns it.
///
/// Tests go through a live `GoRouter` rather than constructing a
/// `GoRouterState` by hand: the state's constructor needs a
/// `RouteConfiguration`, and a hand-built one would not exercise the matching
/// and parameter extraction that these helpers exist to sit on top of.
Future<GoRouter> pumpRouter(
  WidgetTester tester, {
  required List<RouteBase> routes,
  String initialLocation = '/',
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  final router = GoRouter(
    routes: routes,
    initialLocation: initialLocation,
    redirect: redirect,
    refreshListenable: refreshListenable,
    navigatorKey: navigatorKey,
    errorBuilder: (context, state) =>
        Scaffold(body: Text('error: ${state.error}')),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

/// A route that records the [GoRouterState] it was built with.
class StateProbe {
  /// The last state this probe's route was built with.
  GoRouterState? state;

  /// The last [BuildContext] this probe's route was built with.
  BuildContext? context;

  /// Builds a `GoRoute` at [path] that records its state and renders [label].
  GoRoute route(String path, {String? name, String label = 'probe'}) => GoRoute(
    path: path,
    name: name,
    builder: (buildContext, routerState) {
      state = routerState;
      context = buildContext;
      return Scaffold(body: Text(label));
    },
  );
}

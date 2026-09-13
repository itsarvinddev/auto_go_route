import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../base/route_paths.dart';

/// The match list describing what is actually on screen.
///
/// `routerDelegate.currentConfiguration` describes the *declarative* stack.
/// An imperative `push` does not replace it — go_router appends an
/// [ImperativeRouteMatch] whose own `matches` hold the pushed location — so
/// reading `uri` or `fullPath` straight off the configuration reports the
/// route *underneath* the pushed one. This follows the chain to the top.
RouteMatchList _visibleMatches(GoRouter router) {
  var matches = router.routerDelegate.currentConfiguration;
  var last = matches.lastOrNull;
  while (last is ImperativeRouteMatch) {
    matches = last.matches;
    last = matches.lastOrNull;
  }
  return matches;
}

/// Navigation helpers that take a [RoutePaths] instead of a raw URL string.
///
/// Every method builds the location from the route's own template, so a typo
/// in a path is a compile error at the route definition rather than a 404 at
/// runtime.
///
/// ```dart
/// context.goToRoute(router.productPageRoute, params: {'id': '42'});
/// ```
///
/// The generated `goTo…`/`pushTo…` extension is usually nicer still, since it
/// takes typed named arguments. Reach for these when the route is chosen
/// dynamically.
///
/// ### No method here shadows go_router
///
/// Names are deliberately distinct from `GoRouterHelper`'s (`go`, `push`,
/// `pushNamed`, …). An extension member that collides makes *every* call site
/// importing both packages fail with `ambiguous_extension_member_access`, so
/// this extension stays out of go_router's namespace.
extension TypeSafeNavigation on BuildContext {
  /// The URL [route] would navigate to, without navigating.
  ///
  /// Useful for `Link` widgets, share sheets, logging and tests.
  String locationOf(
    RoutePaths route, {
    Map<String, String>? params,
    Map<String, dynamic>? queries,
    String? fragment,
  }) => route.location(
    params: params ?? const {},
    queries: queries,
    fragment: fragment,
  );

  /// Navigates to [route], replacing the current navigation stack.
  void goToRoute(
    RoutePaths route, {
    Map<String, String>? params,
    Map<String, dynamic>? queries,
    String? fragment,
    Object? extra,
  }) => go(
    locationOf(route, params: params, queries: queries, fragment: fragment),
    extra: extra,
  );

  /// Pushes [route] onto the stack and completes with the value it pops.
  Future<T?> pushRoute<T extends Object?>(
    RoutePaths route, {
    Map<String, String>? params,
    Map<String, dynamic>? queries,
    String? fragment,
    Object? extra,
  }) => push<T>(
    locationOf(route, params: params, queries: queries, fragment: fragment),
    extra: extra,
  );

  /// Replaces the top of the stack with [route], keeping a history entry.
  ///
  /// Maps onto go_router's `pushReplacement`.
  void replaceRoute(
    RoutePaths route, {
    Map<String, String>? params,
    Map<String, dynamic>? queries,
    String? fragment,
    Object? extra,
  }) => pushReplacement(
    locationOf(route, params: params, queries: queries, fragment: fragment),
    extra: extra,
  );

  /// Replaces the top of the stack with [route] *in place*, reusing the same
  /// page key so no history entry is added.
  ///
  /// Maps onto go_router's `replace`.
  void replaceRouteInPlace(
    RoutePaths route, {
    Map<String, String>? params,
    Map<String, dynamic>? queries,
    String? fragment,
    Object? extra,
  }) => replace(
    locationOf(route, params: params, queries: queries, fragment: fragment),
    extra: extra,
  );

  /// Navigates to [route] with parameters of any type, stringified on the way
  /// in.
  ///
  /// A `null` value is an error rather than an empty segment: dropping a path
  /// parameter silently produces a URL for a *different* route.
  void goToRouteWithParams(
    RoutePaths route,
    Map<String, Object?> params, {
    Map<String, dynamic>? queries,
    String? fragment,
    Object? extra,
  }) {
    final stringified = <String, String>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null) {
        throw ArgumentError.notNull('params["${entry.key}"]');
      }
      stringified[entry.key] = value.toString();
    }
    goToRoute(
      route,
      params: stringified,
      queries: queries,
      fragment: fragment,
      extra: extra,
    );
  }

  /// Pops if there is anything to pop, otherwise goes to [fallback].
  ///
  /// The usual case for a screen reachable both by push and by deep link,
  /// where a bare `pop()` would do nothing.
  void popOrGo([String fallback = '/', Object? result]) {
    if (canPop()) {
      pop(result);
    } else {
      go(fallback);
    }
  }

  /// Pops until the visible location is [location], or until nothing is left
  /// to pop.
  ///
  /// [location] is compared against the top match's `matchedLocation`, i.e. a
  /// concrete URL path like `/products/42` — not a route template, and without
  /// the query string.
  ///
  /// [maxPops] bounds the loop. `onExit` callbacks resolve asynchronously, so
  /// a synchronous "pop until" cannot observe a refused pop; without a bound
  /// it would spin forever on a route that declines to leave.
  void popUntilLocation(String location, {int maxPops = 100}) {
    final router = GoRouter.of(this);
    var pops = 0;
    while (pops < maxPops &&
        router.canPop() &&
        _visibleMatches(router).lastOrNull?.matchedLocation != location) {
      router.pop();
      pops++;
    }
  }

  // ---------------------------------------------------------------------------
  // 1.x compatibility
  // ---------------------------------------------------------------------------

  /// Pops if possible, otherwise goes to `/`.
  @Deprecated('Use popOrGo(). Will be removed in 3.0.0.')
  void safePop([Object? result]) => popOrGo('/', result);

  /// Pops if possible, otherwise goes to `/`.
  @Deprecated('Use popOrGo(). Will be removed in 3.0.0.')
  void popOrHome() => popOrGo();

  /// Whether there is anything to pop.
  @Deprecated('Use canPop(). Will be removed in 3.0.0.')
  bool canPopSafely() => canPop();

  /// Navigates to [route] with stringified parameters.
  ///
  /// Unlike 1.x, a `null` value throws instead of producing a URL for a
  /// different route, and a failure is not swallowed into a fallback
  /// navigation.
  @Deprecated('Use goToRouteWithParams(). Will be removed in 3.0.0.')
  void goWithParams<T extends RoutePaths>(
    T route,
    Map<String, dynamic> params, {
    Map<String, String>? queries,
    Object? extra,
  }) => goToRouteWithParams(route, params, queries: queries, extra: extra);

  /// Navigates to the route named [name].
  ///
  /// Unlike 1.x, an unknown name throws rather than silently going to `/`.
  @Deprecated('Use goNamed() from go_router. Will be removed in 3.0.0.')
  void goToNamed(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) => goNamed(
    name,
    pathParameters: pathParameters,
    queryParameters: queryParameters,
    extra: extra,
  );

  /// Pops until the visible location is [routePath].
  @Deprecated('Use popUntilLocation(). Will be removed in 3.0.0.')
  void popUntilRoute(String routePath) => popUntilLocation(routePath);
}

/// Convenience getters over the current router state.
///
/// All of these describe what is *visible*, following imperative pushes to the
/// top of the stack.
extension GoRouterStateAccess on BuildContext {
  /// The visible location, including query string and fragment.
  String get currentLocation => GoRouter.of(this).currentLocation;

  /// The name of the visible route, or `null` if it has none.
  ///
  /// This is the route's `name`, not its path — 1.x returned `matchedLocation`
  /// here, which made every name comparison fail.
  String? get currentRouteName => GoRouter.of(this).currentRouteName;

  /// The path *template* of the visible route, e.g. `/products/:id`.
  String? get currentRouteTemplate => GoRouter.of(this).currentRouteTemplate;

  /// Whether the visible route is [route].
  ///
  /// Compares path templates, so it is true for `/products/42` when [route] is
  /// `/products/:id`.
  bool isOnRoute(RoutePaths route) => currentRouteTemplate == route.template;

  /// Whether the visible route is the route named [name].
  bool isOnNamedRoute(String name) => currentRouteName == name;
}

/// Convenience getters on [GoRouter] itself, for code that holds the router
/// rather than a [BuildContext].
extension AutoGoRouterExtensions on GoRouter {
  /// The visible location, including query string and fragment.
  String get currentLocation => _visibleMatches(this).uri.toString();

  /// The name of the visible route, or `null` if it has none.
  String? get currentRouteName => _visibleMatches(this).lastOrNull?.route.name;

  /// The path template of the visible route.
  String? get currentRouteTemplate {
    final matches = _visibleMatches(this);
    return matches.isEmpty ? null : matches.fullPath;
  }

  /// The concrete path of the visible route, e.g. `/products/42`.
  String? get currentMatchedLocation =>
      _visibleMatches(this).lastOrNull?.matchedLocation;

  /// Whether there is anything to pop.
  bool get canGoBack => canPop();

  /// The visible location.
  @Deprecated('Use currentLocation. Will be removed in 3.0.0.')
  String get location => currentLocation;

  /// The visible location.
  @Deprecated('Use currentLocation. Will be removed in 3.0.0.')
  String get safeLocation => currentLocation;

  /// The visible route's matched location, as 1.x returned.
  @Deprecated(
    'This returned a location, not a name. Use currentMatchedLocation, or '
    'currentRouteName for the name. Will be removed in 3.0.0.',
  )
  String? get safeCurrentRouteName => currentMatchedLocation;
}

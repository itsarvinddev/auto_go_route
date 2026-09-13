// The router library. Everything an annotation names by string — guards,
// navigator keys, page builders, the error widget — has to be visible from
// here, because the generated file below is a `part of` this library.
import 'dart:async';

import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'presentation/models/product.dart';
import 'presentation/models/user.dart';
import 'presentation/screens/bottom_sheet.dart';
import 'presentation/screens/dashboard_shell.dart';
import 'presentation/screens/error_screen.dart';
import 'presentation/screens/feature_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/product_screens.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/settings_screen.dart';

part 'app_router.routes.g.dart';

// --- Navigator keys -------------------------------------------------------

/// The root navigator. Routes naming it as their `parentNavigatorKey` are
/// drawn over the bottom navigation bar rather than inside it.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The profile shell's own navigator.
final profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Observers for the root navigator, passed by name to `@AutoGoRouteBase`.
final List<NavigatorObserver> appObservers = [_LoggingObserver()];

/// Stands in for a remote feature flag.
bool get _newFeatureEnabled => false;

// --- Guards ---------------------------------------------------------------

/// Logs every navigation. Returns `null`, so it never redirects.
FutureOr<String?> loggingMiddleware(BuildContext context, GoRouterState state) {
  if (kDebugMode) debugPrint('→ ${state.uri}');
  return null;
}

/// The app's single top-level guard.
///
/// Reads each route's own `metadata` instead of hard-coding a list of
/// protected paths, so adding a guarded route is a one-line annotation change.
FutureOr<String?> appRedirect(BuildContext context, GoRouterState state) {
  final requiresAuth = state.metadataAs<bool>('requiresAuth') ?? false;
  final requiredRole = state.metadataAs<String>('requiresRole');
  final loginLocation = LoginRouteRoute.routeTemplate;

  if (state.uri.path == loginLocation) {
    // Already signed in? Nothing to do on the login screen.
    return authService.isLoggedIn ? HomeRouteRoute.routeTemplate : null;
  }
  if (requiresAuth && !authService.isLoggedIn) {
    return Uri(
      path: loginLocation,
      queryParameters: {'from': state.uri.toString()},
    ).toString();
  }
  if (requiredRole != null && authService.role != requiredRole) {
    return HomeRouteRoute.routeTemplate;
  }
  return null;
}

/// A route-level redirect: `/account` has moved to the profile tab.
FutureOr<String?> legacyProfileRedirect(
  BuildContext context,
  GoRouterState state,
) => ProfileTabRoute.routeTemplate;

/// Simulates a feature flag, as a route-level guard.
FutureOr<String?> featureFlagMiddleware(
  BuildContext context,
  GoRouterState state,
) {
  if (_newFeatureEnabled) return null;
  return Uri(
    path: HomeRouteRoute.routeTemplate,
    queryParameters: {'feature-disabled': 'true'},
  ).toString();
}

/// An `onExit` callback: asks before leaving a half-finished form.
Future<bool> confirmLeaveOnboarding(
  BuildContext context,
  GoRouterState state,
) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Leave onboarding?'),
      content: const Text('Your progress will not be saved.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  return leave ?? false;
}

/// Runs before every navigation, with both the current and the next state.
///
/// `onEnter` is the place for a decision that has to be made *before* the
/// route resolves — analytics, a maintenance gate, a one-shot interstitial.
/// Return `Allow()` to continue or `Block.stop()` to refuse.
FutureOr<OnEnterResult> appOnEnter(
  BuildContext context,
  GoRouterState current,
  GoRouterState next,
  GoRouter router,
) {
  if (kDebugMode) debugPrint('onEnter: ${current.uri} → ${next.uri}');
  return const Allow();
}

// --- The router -----------------------------------------------------------

/// The app's router.
///
/// Everything below is a *default*: `buildRouter()` takes the same options as
/// named arguments, which is how `refreshListenable` — a runtime object — gets
/// in (see `main.dart`).
@AutoGoRouteBase(
  navigatorKey: 'rootNavigatorKey',
  initialLocation: '/home-screen',
  // go_router accepts exactly one error handler, so this rules out
  // `errorBuilder`, `errorPageBuilder` and `onException`. The generator
  // rejects the combination at build time rather than letting go_router assert
  // at startup.
  errorWidget: 'ErrorScreen.new',
  redirect: 'appRedirect',
  onEnter: 'appOnEnter',
  observers: 'appObservers',
  // Left false here and passed as `kDebugMode` from `buildRouter()`: an
  // annotation value is baked in at build time, so a debug-only flag belongs
  // at the call site.
  debugLogDiagnostics: false,
)
class AppRouter extends _$AppRouter {}

class _LoggingObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (kDebugMode) debugPrint('pushed ${route.settings.name}');
  }
}

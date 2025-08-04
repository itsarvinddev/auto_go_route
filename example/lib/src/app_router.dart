// lib/src/app_router.dart
import 'dart:async';

import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import 'auth_service.dart';
import 'presentation/models/product.dart';
import 'presentation/models/user.dart';
import 'presentation/screens/dashboard_shell.dart';
import 'presentation/screens/error_screen.dart';
import 'presentation/screens/feature_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/product_screens.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/settings_screen.dart';

part 'app_router.routes.g.dart';

// --- Middleware Functions ---

/// Logs every navigation event to the console.
FutureOr<String?> loggingMiddleware(BuildContext context, GoRouterState state) {
  if (kDebugMode) {
    print('Navigating to: ${state.uri.toString()}');
  }
  return null; // Returning null means proceed with navigation
}

/// Checks if the user is authenticated.
/// If the route requires auth and the user is not logged in, it redirects to the login page.
FutureOr<String?> authGuardMiddleware(
  BuildContext context,
  GoRouterState state,
  AuthService authService,
) {
  final isLoggedIn = authService.isLoggedIn;
  final isGoingToLogin = state.uri.toString() == appRouter.loginRouteRoute.path;

  // If the route requires auth and the user is not logged in, redirect to login.
  // We check `isGoingToLogin` to prevent an infinite redirect loop.
  if (!isLoggedIn && !isGoingToLogin) {
    return appRouter.loginRouteRoute.path;
  }

  // If the user is logged in and tries to go to the login page, redirect to home.
  if (isLoggedIn && isGoingToLogin) {
    return appRouter.homeRouteRoute.path;
  }

  return null;
}

/// A simple redirect for a legacy path.
FutureOr<String?> legacyProfileRedirect(
  BuildContext context,
  GoRouterState state,
) {
  // Always redirect from /account to /profile
  return appRouter.profileRouteRoute.path;
}

/// Simulates a feature flag. If the feature is disabled, it redirects.
FutureOr<String?> featureFlagMiddleware(
  BuildContext context,
  GoRouterState state,
) {
  const bool isNewFeatureEnabled = kDebugMode; // Simulate a disabled feature
  if (!isNewFeatureEnabled) {
    // Redirect to the home page with a query parameter indicating the feature is disabled.
    return '${appRouter.homeRouteRoute.path}?feature-disabled=true';
  }
  return null;
}

@AutoGoRouteBase(errorBuilder: 'ErrorScreen.new', redirect: 'loggingMiddleware')
class AppRouter extends _$AppRouter {
  final AuthService authService;

  AppRouter({required this.authService});

  List<RouteBase> get routes => _buildNestedRoutes();

  GoRouter get router => GoRouter(
    debugLogDiagnostics: kDebugMode,
    routes: routes,
    initialLocation: homeRouteRoute.path,
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
    refreshListenable: authService,
    redirect: (context, state) {
      // This top-level redirect composes all our middleware.
      // It runs on every navigation change.
      // The order is important.
      final authRedirect = authGuardMiddleware(context, state, authService);
      if (authRedirect != null) return authRedirect;

      // You could add other global middleware here if needed.
      return null;
    },
  );
}

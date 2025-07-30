import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../base/route_paths.dart';

/// Type-safe navigation extensions
extension TypeSafeNavigation on BuildContext {
  /// Navigate to a route with validation
  void goToRoute(
    RoutePaths route, {
    Map<String, String>? params,
    Map<String, String>? queries,
    Object? extra,
  }) {
    try {
      final path = (params != null || queries != null)
          ? route.pathWithParams(params ?? {}, queries: queries)
          : route.path;
      go(path, extra: extra);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Navigation error to ${route.path}: $e');
      }
      // Fallback to base path
      go(route.path, extra: extra);
    }
  }

  /// Push a route with validation
  void pushRoute(
    RoutePaths route, {
    Map<String, String>? params,
    Map<String, String>? queries,
    Object? extra,
  }) {
    try {
      final path = (params != null || queries != null)
          ? route.pathWithParams(params ?? {}, queries: queries)
          : route.path;
      push(path, extra: extra);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push error to ${route.path}: $e');
      }
      // Fallback to base path
      push(route.path, extra: extra);
    }
  }

  /// Navigate to a route by name with error handling
  void goToNamed(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
  }) {
    try {
      goNamed(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        extra: extra,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Navigation error to named route "$name": $e');
      }
      // Try fallback navigation
      go('/', extra: extra);
    }
  }

  /// Push a route by name with error handling
  void pushNamed(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
  }) {
    try {
      pushNamed(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        extra: extra,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push error to named route "$name": $e');
      }
      // Fallback to regular push
      push('/', extra: extra);
    }
  }

  /// Replace current route with error handling
  void replaceRoute(
    RoutePaths route, {
    Map<String, String>? params,
    Map<String, String>? queries,
    Object? extra,
  }) {
    try {
      final path = (params != null || queries != null)
          ? route.pathWithParams(params ?? {}, queries: queries)
          : route.path;
      pushReplacement(path, extra: extra);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Replace error to ${route.path}: $e');
      }
      pushReplacement(route.path, extra: extra);
    }
  }

  /// Navigate with type-safe parameters
  void goWithParams<T extends RoutePaths>(
    T route,
    Map<String, dynamic> params, {
    Map<String, String>? queries,
    Object? extra,
  }) {
    try {
      final stringParams =
          params.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      goToRoute(route, params: stringParams, queries: queries, extra: extra);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Parameter conversion error for ${route.path}: $e');
      }
      goToRoute(route, extra: extra);
    }
  }

  /// Safe pop operation
  void safePop([Object? result]) {
    if (canPop()) {
      pop(result);
    } else {
      go('/');
    }
  }

  /// Pop until reaching a specific route
  void popUntilRoute(String routePath) {
    while (canPop() && GoRouter.of(this).location != routePath) {
      pop();
    }
  }

  /// Navigate with animation control
  Future<T?> pushWithTransition<T>(
    RoutePaths route, {
    Map<String, String>? params,
    Map<String, String>? queries,
    Object? extra,
    Duration? transitionDuration,
  }) async {
    try {
      final path = (params != null || queries != null)
          ? route.pathWithParams(params ?? {}, queries: queries)
          : route.path;
      return await push<T>(path, extra: extra);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Transition navigation error: $e');
      }
      return await push<T>(route.path, extra: extra);
    }
  }
}

/// Enhanced GoRouter extensions
extension GoRouterExtensions on GoRouter {
  /// Get current location safely
  String get safeLocation {
    try {
      return location;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting location: $e');
      }
      return '/';
    }
  }

  /// Get current route name safely
  String? get safeCurrentRouteName {
    try {
      final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
      return lastMatch.matchedLocation;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting current route name: $e');
      }
      return null;
    }
  }

  /// Check if can navigate back
  bool get canGoBack {
    try {
      return canPop();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking canPop: $e');
      }
      return false;
    }
  }
}

/// Navigation state management
extension NavigationState on BuildContext {
  /// Get current location safely
  String get currentLocation {
    try {
      return GoRouter.of(this).safeLocation;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting current location: $e');
      }
      return '/';
    }
  }

  /// Get current route name safely
  String? get currentRouteName {
    try {
      return GoRouter.of(this).safeCurrentRouteName;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting current route name: $e');
      }
      return null;
    }
  }

  /// Check if currently on route
  bool isOnRoute(RoutePaths route) {
    try {
      return currentLocation == route.path;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking route: $e');
      }
      return false;
    }
  }

  /// Check if currently on named route
  bool isOnNamedRoute(String name) {
    try {
      return currentRouteName == name;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking named route: $e');
      }
      return false;
    }
  }

  /// Safe navigation home
  void popOrHome() {
    try {
      if (canPop()) {
        pop();
      } else {
        go('/');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in popOrHome: $e');
      }
      go('/');
    }
  }

  /// Check if can pop safely
  bool canPopSafely() {
    try {
      return canPop();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking canPop: $e');
      }
      return false;
    }
  }
}

extension GoRouterLocation on GoRouter {
  String get location {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    final String location = matchList.uri.toString();
    return location;
  }

  String? get currentRouteName {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    return lastMatch.matchedLocation;
  }
}

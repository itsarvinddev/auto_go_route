// lib/src/annotations/auto_go_route.dart
/// Annotation for generating Go Router routes automatically
class AutoGoRoute {
  const AutoGoRoute({
    required this.path,
    this.name,
    this.description,
    this.parent,
    this.middleware = const [],
    this.order,
  });

  final String path;
  final String? name;
  final String? description;
  final Type? parent;
  final List<String> middleware;

  /// The index of this route when used as a branch in a StatefulShellRoute.
  final int? order;
}

/// Annotation for route base class that collects all routes
class AutoGoRouteBase {
  const AutoGoRouteBase({
    this.initialLocation,
    this.errorBuilder,
    this.redirect,
  });

  final String? initialLocation;
  final String? errorBuilder;
  final String? redirect;
}

/// Annotation for a ShellRoute
class AutoGoRouteShell {
  const AutoGoRouteShell({
    required this.path,
    this.name,
    this.description,
    this.navigatorKey,
    this.parent,
    this.isStateful = false,
    this.initialRoute,
  });

  final String path;
  final String? name;
  final String? description;
  final String? navigatorKey;
  final Type? parent;
  final bool isStateful;

  /// The absolute path to redirect to when this shell is navigated to directly.
  /// If not provided for a root shell (`path: '/'`), it defaults to the
  /// path of the first child route.
  final String? initialRoute;
}

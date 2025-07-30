import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../base/route_paths.dart';

/// Central registry for all application routes
class RouteRegistry {
  static final RouteRegistry _instance = RouteRegistry._internal();
  factory RouteRegistry() => _instance;
  RouteRegistry._internal();

  final Map<String, RoutePaths> _routes = {};
  final Map<String, List<RoutePaths>> _routeGroups = {};
  final Map<String, RouteMetadata> _metadata = {};

  /// Register a single route
  void register(RoutePaths route) {
    final key = route.name ?? route.path;
    _routes[key] = route;
    _metadata[key] = RouteMetadata.fromRoute(route);
  }

  /// Register multiple routes
  void registerAll(List<RoutePaths> routes) {
    for (final route in routes) {
      register(route);
    }
  }

  /// Register routes in a group
  void registerGroup(String groupName, List<RoutePaths> routes) {
    _routeGroups[groupName] = routes;
    registerAll(routes);
  }

  /// Get route by name or path
  RoutePaths? getRoute(String identifier) {
    return _routes[identifier];
  }

  /// Get routes by group
  List<RoutePaths>? getRouteGroup(String groupName) {
    return _routeGroups[groupName];
  }

  /// Get all registered routes
  List<RoutePaths> get allRoutes => _routes.values.toList();

  /// Get all route names
  List<String> get allRouteNames => _routes.keys.toList();

  /// Generate GoRouter routes
  List<GoRoute> generateGoRoutes({
    String? Function(BuildContext, GoRouterState)? globalRedirect,
  }) {
    return _routes.values.map((route) {
      final goRoute = route.toGoRoute();
      // If a global redirect is provided, it overrides the route-specific one.
      return goRoute.copyWith(redirect: globalRedirect);
    }).toList();
  }

  /// Validate all registered routes
  void validateAllRoutes() {
    final errors = <String>[];

    for (final route in _routes.values) {
      try {
        _validateRoute(route);
      } catch (e) {
        errors.add('Route ${route.path}: $e');
      }
    }

    if (errors.isNotEmpty) {
      throw StateError('Route validation failed:\n${errors.join('\n')}');
    }
  }

  void _validateRoute(RoutePaths route) {
    // Extract parameters from path
    final pathParams = RegExp(r':(\w+)\??')
        .allMatches(route.path)
        .map((m) => m.group(1)!)
        .toSet();

    final declaredParams = {
      ...route.requiredParams,
      ...route.optionalParams,
    }.toSet();

    // Check for undeclared parameters
    final undeclaredParams = pathParams.difference(declaredParams);
    if (undeclaredParams.isNotEmpty) {
      throw StateError('Undeclared parameters: ${undeclaredParams.join(', ')}');
    }

    // Check for unused declared parameters
    final unusedParams = declaredParams.difference(pathParams);
    if (unusedParams.isNotEmpty) {
      throw StateError(
          'Unused declared parameters: ${unusedParams.join(', ')}');
    }

    // Validate path format
    if (!route.path.startsWith('/')) {
      throw StateError('Path must start with /');
    }
  }

  /// Generate comprehensive documentation
  String generateDocumentation({
    bool includeMetadata = true,
    bool includeParameters = true,
    bool includeExamples = true,
    DocumentationFormat format = DocumentationFormat.markdown,
  }) {
    switch (format) {
      case DocumentationFormat.markdown:
        return _generateMarkdownDocs(
            includeMetadata, includeParameters, includeExamples);
      case DocumentationFormat.json:
        return _generateJsonDocs(includeMetadata, includeParameters);
      case DocumentationFormat.html:
        return _generateHtmlDocs(
            includeMetadata, includeParameters, includeExamples);
    }
  }

  String _generateMarkdownDocs(
      bool includeMetadata, bool includeParameters, bool includeExamples) {
    final buffer = StringBuffer();
    buffer.writeln('# Application Routes Documentation\n');
    buffer.writeln('Generated on: ${DateTime.now().toIso8601String()}\n');
    buffer.writeln('Total routes: ${_routes.length}\n');

    // Group routes by category
    final grouped = _groupRoutesByCategory();

    for (final entry in grouped.entries) {
      buffer.writeln('## ${entry.key}\n');

      for (final route in entry.value) {
        buffer.writeln('### ${route.name ?? _extractNameFromPath(route.path)}');
        buffer.writeln('- **Path:** `${route.path}`');

        if (route.name != null) {
          buffer.writeln('- **Name:** `${route.name}`');
        }

        if (includeMetadata && route.description != null) {
          buffer.writeln('- **Description:** ${route.description}');
        }

        if (includeParameters) {
          if (route.requiredParams.isNotEmpty) {
            buffer.writeln('- **Required Parameters:**');
            for (final param in route.requiredParams) {
              buffer.writeln('  - `$param`: String');
            }
          }

          if (route.optionalParams.isNotEmpty) {
            buffer.writeln('- **Optional Parameters:**');
            for (final param in route.optionalParams) {
              buffer.writeln('  - `$param`: String (optional)');
            }
          }
        }

        if (includeExamples) {
          buffer.writeln('- **Example Usage:**');
          if (route.requiredParams.isEmpty && route.optionalParams.isEmpty) {
            buffer.writeln('  ```');
            buffer.writeln('  context.go("${route.path}");');
            buffer.writeln('  ```');
          } else {
            buffer.writeln('  ```');
            buffer.writeln('  context.goToRoute(route, params: {');
            for (final param in route.requiredParams) {
              buffer.writeln('    "$param": "example_value",');
            }
            for (final param in route.optionalParams) {
              buffer.writeln('    "$param": "optional_value", // optional');
            }
            buffer.writeln('  });');
            buffer.writeln('  ```');
          }
        }

        buffer.writeln('');
      }
    }

    return buffer.toString();
  }

  String _generateJsonDocs(bool includeMetadata, bool includeParameters) {
    final docs = <String, dynamic>{
      'generated_at': DateTime.now().toIso8601String(),
      'total_routes': _routes.length,
      'routes': {},
    };

    for (final route in _routes.values) {
      final routeDoc = <String, dynamic>{
        'path': route.path,
        'name': route.name,
      };

      if (includeMetadata && route.description != null) {
        routeDoc['description'] = route.description;
      }

      if (includeParameters) {
        routeDoc['required_params'] = route.requiredParams;
        routeDoc['optional_params'] = route.optionalParams;
      }

      docs['routes'][route.name ?? route.path] = routeDoc;
    }

    return jsonEncode(docs);
  }

  String _generateHtmlDocs(
      bool includeMetadata, bool includeParameters, bool includeExamples) {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html><head><title>Route Documentation</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: Arial, sans-serif; margin: 40px; }');
    buffer.writeln(
        '.route { border: 1px solid #ddd; margin: 20px 0; padding: 20px; border-radius: 5px; }');
    buffer.writeln(
        '.path { background: #f5f5f5; padding: 5px; border-radius: 3px; font-family: monospace; }');
    buffer.writeln('.required { color: #d9534f; }');
    buffer.writeln('.optional { color: #5bc0de; }');
    buffer.writeln('</style>');
    buffer.writeln('</head><body>');
    buffer.writeln('<h1>Application Routes Documentation</h1>');
    buffer.writeln('<p>Generated on: ${DateTime.now()}</p>');
    buffer.writeln('<p>Total routes: ${_routes.length}</p>');

    for (final route in _routes.values) {
      buffer.writeln('<div class="route">');
      buffer.writeln(
          '<h3>${route.name ?? _extractNameFromPath(route.path)}</h3>');
      buffer.writeln(
          '<p><strong>Path:</strong> <span class="path">${route.path}</span></p>');

      if (includeMetadata && route.description != null) {
        buffer.writeln(
            '<p><strong>Description:</strong> ${route.description}</p>');
      }

      if (includeParameters &&
          (route.requiredParams.isNotEmpty ||
              route.optionalParams.isNotEmpty)) {
        buffer.writeln('<p><strong>Parameters:</strong></p>');
        buffer.writeln('<ul>');
        for (final param in route.requiredParams) {
          buffer.writeln('<li class="required">$param (required)</li>');
        }
        for (final param in route.optionalParams) {
          buffer.writeln('<li class="optional">$param (optional)</li>');
        }
        buffer.writeln('</ul>');
      }

      buffer.writeln('</div>');
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  Map<String, List<RoutePaths>> _groupRoutesByCategory() {
    final groups = <String, List<RoutePaths>>{};

    for (final route in _routes.values) {
      final category = _extractCategoryFromPath(route.path);
      groups.putIfAbsent(category, () => []).add(route);
    }

    return groups;
  }

  String _extractCategoryFromPath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return 'Root';
    final firstSegment = segments.first;
    return firstSegment.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
  }

  String _extractNameFromPath(String path) {
    return path
        .split('/')
        .where((s) => s.isNotEmpty && !s.startsWith(':'))
        .join(' ');
  }

  /// Clear all registered routes
  void clear() {
    _routes.clear();
    _routeGroups.clear();
    _metadata.clear();
  }

  /// Get registry statistics
  RegistryStatistics get statistics {
    return RegistryStatistics(
      totalRoutes: _routes.length,
      totalGroups: _routeGroups.length,
      routesWithParams: _routes.values
          .where(
              (r) => r.requiredParams.isNotEmpty || r.optionalParams.isNotEmpty)
          .length,
    );
  }
}

/// Route metadata for documentation and analysis
class RouteMetadata {
  final String path;
  final String? name;
  final String? description;
  final List<String> requiredParams;
  final List<String> optionalParams;
  final DateTime registeredAt;

  RouteMetadata({
    required this.path,
    this.name,
    this.description,
    required this.requiredParams,
    required this.optionalParams,
    required this.registeredAt,
  });

  factory RouteMetadata.fromRoute(RoutePaths route) {
    return RouteMetadata(
      path: route.path,
      name: route.name,
      description: route.description,
      requiredParams: route.requiredParams,
      optionalParams: route.optionalParams,
      registeredAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'description': description,
      'requiredParams': requiredParams,
      'optionalParams': optionalParams,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }
}

/// Registry statistics
class RegistryStatistics {
  final int totalRoutes;
  final int totalGroups;
  final int routesWithParams;

  const RegistryStatistics({
    required this.totalRoutes,
    required this.totalGroups,
    required this.routesWithParams,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalRoutes': totalRoutes,
      'totalGroups': totalGroups,
      'routesWithParams': routesWithParams,
    };
  }
}

/// Documentation format options
enum DocumentationFormat {
  markdown,
  json,
  html,
}

/// Extension for GoRoute copying
extension GoRouteExtension on GoRoute {
  GoRoute copyWith({
    String? path,
    String? name,
    Widget Function(BuildContext, GoRouterState)? builder,
    String? Function(BuildContext, GoRouterState)? redirect,
    List<RouteBase>? routes,
  }) {
    return GoRoute(
      path: path ?? this.path,
      name: name ?? this.name,
      builder: builder ?? this.builder,
      redirect: redirect ?? this.redirect,
      routes: routes ?? this.routes,
    );
  }
}

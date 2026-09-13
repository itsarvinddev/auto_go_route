import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../base/route_guard.dart';
import '../base/route_paths.dart';
import '../utils/route_utils.dart';

/// The format [RouteRegistry.generateDocumentation] emits.
enum DocumentationFormat {
  /// GitHub-flavoured Markdown.
  markdown,

  /// A JSON object, for feeding other tooling.
  json,

  /// A standalone HTML page.
  html,
}

/// An index of route definitions, for validation, documentation and
/// diagnostics.
///
/// The generated router does not need a registry to work — it builds its
/// `GoRoute` tree directly. Use one when you want to introspect your routes:
/// dump a route table into your docs, assert in a test that every route has a
/// description, or render a debug screen listing every location in the app.
///
/// ```dart
/// final registry = RouteRegistry.scoped()..registerAll(router.allRoutes);
/// registry.validateAllRoutes();
/// print(registry.generateDocumentation());
/// ```
///
/// [RouteRegistry.new] returns a process-wide singleton for compatibility with
/// 1.x. Prefer [RouteRegistry.scoped] — a global registry makes tests order
/// dependent, since one test's routes leak into the next.
class RouteRegistry {
  /// Returns the process-wide singleton.
  ///
  /// Prefer [RouteRegistry.scoped].
  factory RouteRegistry() => instance;

  /// Creates an independent registry.
  RouteRegistry.scoped();

  /// The process-wide singleton returned by [RouteRegistry.new].
  static final RouteRegistry instance = RouteRegistry.scoped();

  final Map<String, RoutePaths> _routes = {};
  final Map<String, List<RoutePaths>> _routeGroups = {};
  final Map<String, RouteMetadata> _metadata = {};

  /// Registers [route] under its name, falling back to its path template.
  ///
  /// Throws a [StateError] on a duplicate key unless [replace] is set. 1.x
  /// overwrote silently, which hid the duplicate-name bugs the generator now
  /// catches at build time.
  void register(RoutePaths route, {bool replace = false}) {
    final key = route.name ?? route.template;
    if (!replace && _routes.containsKey(key)) {
      final existing = _routes[key]!;
      if (existing == route) return;
      throw StateError(
        'A different route is already registered as "$key": '
        '${existing.template} vs ${route.template}. Give one of them a '
        'distinct name, or pass replace: true.',
      );
    }
    _routes[key] = route;
    _metadata[key] = RouteMetadata.fromRoute(route);
  }

  /// Registers every route in [routes].
  void registerAll(Iterable<RoutePaths> routes, {bool replace = false}) {
    for (final route in routes) {
      register(route, replace: replace);
    }
  }

  /// Registers [routes] and records them under [groupName].
  void registerGroup(
    String groupName,
    List<RoutePaths> routes, {
    bool replace = false,
  }) {
    _routeGroups[groupName] = List.unmodifiable(routes);
    registerAll(routes, replace: replace);
  }

  /// The route registered as [identifier] — its name, or its path template.
  RoutePaths? getRoute(String identifier) => _routes[identifier];

  /// The routes registered under [groupName].
  List<RoutePaths>? getRouteGroup(String groupName) => _routeGroups[groupName];

  /// Every registered route.
  List<RoutePaths> get allRoutes => List.unmodifiable(_routes.values);

  /// Every registered key.
  List<String> get allRouteNames => List.unmodifiable(_routes.keys);

  /// Recorded metadata for every registered route.
  Map<String, RouteMetadata> get metadata => Map.unmodifiable(_metadata);

  /// The registered route whose template is closest to [location].
  ///
  /// Powers "did you mean…?" messages for an unmatched URL. Returns `null`
  /// when nothing scores above [threshold].
  RoutePaths? findClosest(String location, {double threshold = 0.3}) {
    RoutePaths? best;
    var bestScore = threshold;
    for (final route in _routes.values) {
      final score = RouteUtils.calculateRouteSimilarity(
        route.template,
        location,
      );
      if (score > bestScore) {
        bestScore = score;
        best = route;
      }
    }
    return best;
  }

  /// Builds a flat list of `GoRoute`s from the registered routes.
  ///
  /// This is a *flat* projection: each route is mounted at its own absolute
  /// [RoutePaths.template] with no nesting, which is useful for a quick
  /// router in a test but is not how the generated router builds its tree —
  /// use the generated `routes` getter for that, which preserves shells and
  /// parent/child structure.
  ///
  /// [globalRedirect] is composed *ahead of* each route's own guards rather
  /// than replacing them. In 1.x it overwrote `GoRoute.redirect`, silently
  /// deleting every route's auth guard.
  List<GoRoute> generateGoRoutes({RouteGuard? globalRedirect}) {
    return [
      for (final route in _routes.values)
        GoRoute(
          path: route.template,
          name: route.name,
          builder: route.builder,
          pageBuilder: route.pageBuilder,
          onExit: route.onExit,
          parentNavigatorKey: route.parentNavigatorKey,
          caseSensitive: route.caseSensitive,
          metadata: route.metadata,
          redirect: _compose(globalRedirect, route.composedRedirect),
        ),
    ];
  }

  static RouteGuard? _compose(RouteGuard? first, RouteGuard? second) {
    if (first == null) return second;
    if (second == null) return first;
    return (context, state) {
      final outer = first(context, state);
      if (outer is Future<String?>) {
        return outer.then(
          // go_router keeps this context alive across the redirect chain.
          // ignore: use_build_context_synchronously
          (value) => value ?? second(context, state),
        );
      }
      return outer ?? second(context, state);
    };
  }

  /// Validates every registered route, throwing a [StateError] listing all
  /// problems found.
  ///
  /// See [validate] for a non-throwing version.
  void validateAllRoutes() {
    final result = validate();
    if (!result.isValid) {
      throw StateError('Route validation failed:\n${result.errors.join('\n')}');
    }
  }

  /// Validates every registered route.
  ///
  /// Checks that templates are absolute and well formed, that no two routes
  /// share a template, and that no template repeats a parameter name.
  ///
  /// 1.x also compared "declared" against "used" parameters and rejected every
  /// nested route and every route with an optional parameter — including the
  /// generator's own output.
  RouteValidationResult validate() {
    final errors = <String>[];
    final warnings = <String>[];
    final byTemplate = <String, String>{};

    for (final route in _routes.values) {
      final label = route.name ?? route.template;
      final template = route.template;

      if (!RouteUtils.isValidTemplate(template)) {
        errors.add(
          'Route "$label" has an invalid path template "$template". It must '
          'start with "/" and contain no whitespace, "//", "?" or "#".',
        );
        continue;
      }

      final names = <String>[];
      for (final match in RegExp(
        r':(\w+)',
      ).allMatches(template.replaceAll(RegExp(r'\([^)]*\)'), ''))) {
        names.add(match.group(1)!);
      }
      final duplicates = <String>{};
      final seen = <String>{};
      for (final name in names) {
        if (!seen.add(name)) duplicates.add(name);
      }
      if (duplicates.isNotEmpty) {
        errors.add(
          'Route "$label" repeats path ${duplicates.length == 1 ? 'parameter' : 'parameters'} '
          '${duplicates.join(', ')} in "$template".',
        );
      }

      final previous = byTemplate[template];
      if (previous != null) {
        errors.add(
          'Routes "$previous" and "$label" both resolve to "$template".',
        );
      } else {
        byTemplate[template] = label;
      }

      if (route.description == null || route.description!.isEmpty) {
        warnings.add('Route "$label" has no description.');
      }
    }

    return errors.isEmpty
        ? RouteValidationResult.valid(warnings: warnings)
        : RouteValidationResult.invalid(errors, warnings);
  }

  /// Renders documentation for every registered route.
  ///
  /// [generatedAt] is stamped into the output; pass a fixed value to make the
  /// result reproducible, which is what lets a golden test diff it.
  String generateDocumentation({
    bool includeMetadata = true,
    bool includeParameters = true,
    bool includeExamples = true,
    DocumentationFormat format = DocumentationFormat.markdown,
    DateTime? generatedAt,
  }) {
    switch (format) {
      case DocumentationFormat.markdown:
        return _markdown(
          includeMetadata,
          includeParameters,
          includeExamples,
          generatedAt,
        );
      case DocumentationFormat.json:
        return _json(includeMetadata, includeParameters, generatedAt);
      case DocumentationFormat.html:
        return _html(includeMetadata, includeParameters, generatedAt);
    }
  }

  List<RoutePaths> get _sorted =>
      _routes.values.toList()..sort((a, b) => a.template.compareTo(b.template));

  String _markdown(
    bool includeMetadata,
    bool includeParameters,
    bool includeExamples,
    DateTime? generatedAt,
  ) {
    final buffer = StringBuffer()
      ..writeln('# Application routes')
      ..writeln();
    if (generatedAt != null) {
      buffer
        ..writeln('Generated on: ${generatedAt.toIso8601String()}')
        ..writeln();
    }
    buffer
      ..writeln('Total routes: ${_routes.length}')
      ..writeln();

    final grouped = <String, List<RoutePaths>>{};
    for (final route in _sorted) {
      grouped.putIfAbsent(_category(route.template), () => []).add(route);
    }

    for (final entry in grouped.entries) {
      buffer
        ..writeln('## ${entry.key}')
        ..writeln();
      for (final route in entry.value) {
        buffer
          ..writeln('### ${route.name ?? _label(route.template)}')
          ..writeln('- **Path:** `${route.template}`');
        if (route.name != null) buffer.writeln('- **Name:** `${route.name}`');
        if (includeMetadata && route.description != null) {
          buffer.writeln('- **Description:** ${route.description}');
        }
        if (includeMetadata && route.metadata != null) {
          buffer.writeln('- **Metadata:** `${route.metadata}`');
        }
        if (includeParameters && route.pathParameters.isNotEmpty) {
          buffer.writeln('- **Path parameters:**');
          for (final param in route.pathParameters) {
            buffer.writeln('  - `$param`');
          }
        }
        if (includeExamples) {
          buffer
            ..writeln('- **Example:**')
            ..writeln('  ```dart')
            ..writeln(
              route.pathParameters.isEmpty
                  ? "  context.go('${route.template}');"
                  : '  context.goToRoute(route, params: {'
                        '${route.pathParameters.map((p) => "'$p': '…'").join(', ')}'
                        '});',
            )
            ..writeln('  ```');
        }
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  String _json(
    bool includeMetadata,
    bool includeParameters,
    DateTime? generatedAt,
  ) => jsonEncode({
    if (generatedAt != null) 'generated_at': generatedAt.toIso8601String(),
    'total_routes': _routes.length,
    'routes': {
      for (final route in _sorted)
        route.name ?? route.template: {
          'path': route.template,
          'name': route.name,
          if (includeMetadata && route.description != null)
            'description': route.description,
          if (includeMetadata && route.metadata != null)
            'metadata': route.metadata,
          if (includeParameters) 'path_params': route.pathParameters,
        },
    },
  });

  String _html(
    bool includeMetadata,
    bool includeParameters,
    DateTime? generatedAt,
  ) {
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en"><head><meta charset="utf-8">')
      ..writeln('<title>Route documentation</title>')
      ..writeln('<style>')
      ..writeln(
        'body{font-family:system-ui,sans-serif;margin:2rem auto;max-width:60rem;padding:0 1rem}',
      )
      ..writeln(
        '.route{border:1px solid #d0d7de;border-radius:6px;margin:1rem 0;padding:1rem}',
      )
      ..writeln(
        'code{background:#f6f8fa;padding:.15em .35em;border-radius:3px}',
      )
      ..writeln('</style></head><body>')
      ..writeln('<h1>Application routes</h1>');
    if (generatedAt != null) {
      buffer.writeln(
        '<p>Generated on ${_escape(generatedAt.toIso8601String())}</p>',
      );
    }
    buffer.writeln('<p>Total routes: ${_routes.length}</p>');

    for (final route in _sorted) {
      buffer
        ..writeln('<div class="route">')
        ..writeln('<h3>${_escape(route.name ?? _label(route.template))}</h3>')
        ..writeln(
          '<p><strong>Path:</strong> <code>${_escape(route.template)}</code></p>',
        );
      if (includeMetadata && route.description != null) {
        buffer.writeln(
          '<p><strong>Description:</strong> ${_escape(route.description!)}</p>',
        );
      }
      if (includeParameters && route.pathParameters.isNotEmpty) {
        buffer
          ..writeln('<p><strong>Path parameters:</strong></p><ul>')
          ..writeAll(
            route.pathParameters.map(
              (p) => '<li><code>${_escape(p)}</code></li>',
            ),
            '\n',
          )
          ..writeln('</ul>');
      }
      buffer.writeln('</div>');
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _category(String template) {
    final segments = template.split('/').where((s) => s.isNotEmpty);
    if (segments.isEmpty) return 'Root';
    final first = segments.first;
    return first.startsWith(':') ? 'Root' : first;
  }

  static String _label(String template) => template
      .split('/')
      .where((s) => s.isNotEmpty && !s.startsWith(':'))
      .join(' ');

  /// Clears every registered route, group and metadata entry.
  ///
  /// Call this in `setUp` when using the [RouteRegistry.new] singleton from
  /// tests.
  void clear() {
    _routes.clear();
    _routeGroups.clear();
    _metadata.clear();
  }

  /// Counts of what is registered.
  RegistryStatistics get statistics => RegistryStatistics(
    totalRoutes: _routes.length,
    totalGroups: _routeGroups.length,
    routesWithParams: _routes.values
        .where((r) => r.pathParameters.isNotEmpty)
        .length,
  );
}

/// A snapshot of one route's shape, taken when it was registered.
class RouteMetadata {
  /// Creates a metadata snapshot.
  const RouteMetadata({
    required this.path,
    required this.pathParameters,
    this.name,
    this.description,
    this.registeredAt,
  });

  /// Snapshots [route].
  factory RouteMetadata.fromRoute(RoutePaths route, {DateTime? registeredAt}) =>
      RouteMetadata(
        path: route.template,
        name: route.name,
        description: route.description,
        pathParameters: route.pathParameters,
        registeredAt: registeredAt,
      );

  /// The route's absolute path template.
  final String path;

  /// The route's name.
  final String? name;

  /// The route's description.
  final String? description;

  /// The route's path parameter names.
  final List<String> pathParameters;

  /// When the route was registered, if the caller supplied a clock.
  ///
  /// `null` by default: reading `DateTime.now()` here would make otherwise
  /// identical registries unequal and documentation output unreproducible.
  final DateTime? registeredAt;

  /// This snapshot as a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'description': description,
    'pathParameters': pathParameters,
    'registeredAt': registeredAt?.toIso8601String(),
  };
}

/// Counts describing a [RouteRegistry]'s contents.
class RegistryStatistics {
  /// Creates a statistics snapshot.
  const RegistryStatistics({
    required this.totalRoutes,
    required this.totalGroups,
    required this.routesWithParams,
  });

  /// How many routes are registered.
  final int totalRoutes;

  /// How many groups are registered.
  final int totalGroups;

  /// How many routes declare at least one path parameter.
  final int routesWithParams;

  /// These counts as a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    'totalRoutes': totalRoutes,
    'totalGroups': totalGroups,
    'routesWithParams': routesWithParams,
  };

  @override
  String toString() =>
      'RegistryStatistics(routes: $totalRoutes, groups: $totalGroups, '
      'withParams: $routesWithParams)';
}

/// Copying helpers for `GoRoute`.
extension GoRouteExtension on GoRoute {
  /// Returns a copy of this route with the given fields replaced.
  ///
  /// Every field `GoRoute` accepts is forwarded. 1.x dropped `pageBuilder`,
  /// `onExit`, `parentNavigatorKey`, `caseSensitive` and `metadata`, so
  /// copying a `pageBuilder`-only route produced one go_router rejects.
  GoRoute copyWith({
    String? path,
    String? name,
    Widget Function(BuildContext, GoRouterState)? builder,
    Page<dynamic> Function(BuildContext, GoRouterState)? pageBuilder,
    RouteGuard? redirect,
    ExitCallback? onExit,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    bool? caseSensitive,
    Map<String, dynamic>? metadata,
    List<RouteBase>? routes,
  }) => GoRoute(
    path: path ?? this.path,
    name: name ?? this.name,
    builder: builder ?? this.builder,
    pageBuilder: pageBuilder ?? this.pageBuilder,
    redirect: redirect ?? this.redirect,
    onExit: onExit ?? this.onExit,
    parentNavigatorKey: parentNavigatorKey ?? this.parentNavigatorKey,
    caseSensitive: caseSensitive ?? this.caseSensitive,
    metadata: metadata ?? this.metadata,
    routes: routes ?? this.routes,
  );
}

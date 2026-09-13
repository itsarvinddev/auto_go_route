import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_guard.dart';

/// The path-parameter grammar go_router itself uses.
///
/// Kept byte-identical to `patternToRegExp`'s `_parameterRegExp` in
/// `go_router/src/path_utils.dart` so that the parameters this package
/// advertises are exactly the ones go_router will bind, including regular
/// expression constraints like `:id(\d+)`.
final RegExp _parameterRegExp = RegExp(r':(\w+)(\((?:\\.|[^\\()])+\))?');

/// Base class for a generated route definition.
///
/// One subclass is generated per `@AutoGoRoute` widget. Instances are value
/// objects describing the route; [toGoRoute] turns one into the `GoRoute`
/// go_router consumes, and [location] builds a URL for it without navigating.
abstract class RoutePaths extends Equatable with RouteGuardMixin {
  /// Creates a route definition.
  ///
  /// Exactly one of [builder] or [pageBuilder] should be supplied, unless the
  /// route exists only to [redirect].
  const RoutePaths({
    required this.path,
    this.name,
    this.builder,
    this.pageBuilder,
    this.description,
    this.middleware = const [],
    this.redirect,
    this.onExit,
    this.parentNavigatorKey,
    this.caseSensitive = true,
    this.metadata,
  }) : assert(
         builder != null || pageBuilder != null || redirect != null,
         'A route needs a builder, a pageBuilder, or a redirect.',
       ),
       assert(
         builder == null || pageBuilder == null,
         'Supply either builder or pageBuilder, not both.',
       );

  /// The path as declared on the annotation: absolute for a top-level route,
  /// relative for a nested one.
  ///
  /// Use [template] when you need the absolute pattern.
  final String path;

  /// The route's name, unique across the router.
  final String? name;

  /// Builds the route's widget.
  final Widget Function(BuildContext, GoRouterState)? builder;

  /// Builds the route's page, for custom transitions and modal routes.
  final Page<dynamic> Function(BuildContext, GoRouterState)? pageBuilder;

  /// Free-text description, used by [RouteRegistry] documentation output.
  final String? description;

  @override
  final List<RouteGuard> middleware;

  @override
  final RouteGuard? redirect;

  /// Called before this route is popped. Return `false` to stay.
  final FutureOr<bool> Function(BuildContext, GoRouterState)? onExit;

  /// The navigator this route is placed on. Set it to a shell's root navigator
  /// key to have the route cover that shell.
  final GlobalKey<NavigatorState>? parentNavigatorKey;

  /// Whether path matching is case-sensitive.
  final bool caseSensitive;

  /// Application-defined metadata, merged into `GoRouterState.metadata`.
  final Map<String, dynamic>? metadata;

  /// The absolute path pattern for this route.
  ///
  /// Equal to [path] for a top-level route; `NestedRoutePaths` overrides it to
  /// splice in the parent chain. This — never [path] — is what URL building
  /// and parameter discovery work from.
  String get template => path;

  /// The names of every path parameter in [template], in order of appearance
  /// and without duplicates.
  List<String> get pathParameters {
    final seen = <String>{};
    for (final match in _parameterRegExp.allMatches(template)) {
      seen.add(match.group(1)!);
    }
    return seen.toList(growable: false);
  }

  /// Alias for [pathParameters]; every path parameter is required, because
  /// go_router has no optional path segments.
  List<String> get requiredParams => pathParameters;

  /// Always empty.
  ///
  /// go_router has no optional path parameters — `:id?` registers a route
  /// nothing can match — so `auto_go_route` rejects that syntax at build time
  /// and directs you to a query parameter or a second route instead.
  @Deprecated(
    'Optional path parameters do not exist in go_router and are now a build '
    'error. Use a query parameter or declare a second route. '
    'This getter always returns an empty list and will be removed in 3.0.0.',
  )
  List<String> get optionalParams => const <String>[];

  /// Throws an [ArgumentError] unless [params] supplies every path parameter.
  void validateParams(Map<String, String> params) {
    final missing = pathParameters
        .where((p) => !params.containsKey(p))
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Route "${name ?? template}" is missing required path '
        '${missing.length == 1 ? 'parameter' : 'parameters'}: '
        '${missing.join(', ')}. Expected: ${pathParameters.join(', ')}.',
      );
    }
  }

  /// Builds the URL for this route.
  ///
  /// [params] supplies path parameters, [queries] the query string, and
  /// [fragment] the `#…` part. Query values may be a `String`, anything with a
  /// sensible `toString`, or an `Iterable` — which expands to a repeated key
  /// (`?tag=a&tag=b`). Null values, and null elements inside an iterable, are
  /// dropped.
  ///
  /// Substitution is a single pass over [template], so parameter names that
  /// prefix one another (`:id` and `:idCard`) and regex constraints
  /// (`:id(\d+)`) are both handled correctly.
  String location({
    Map<String, String> params = const {},
    Map<String, dynamic>? queries,
    String? fragment,
    bool validate = true,
  }) {
    if (validate) validateParams(params);

    final buffer = StringBuffer();
    var start = 0;
    for (final match in _parameterRegExp.allMatches(template)) {
      if (match.start > start) {
        buffer.write(template.substring(start, match.start));
      }
      final name = match.group(1)!;
      final value = params[name];
      if (value == null) {
        // Only reachable with validate: false. Leave the placeholder in rather
        // than silently producing a URL that resolves to a different route.
        buffer.write(match.group(0));
      } else {
        buffer.write(Uri.encodeComponent(value));
      }
      start = match.end;
    }
    if (start < template.length) {
      buffer.write(template.substring(start));
    }

    final normalizedQueries = _normalizeQueries(queries);
    if (normalizedQueries == null && fragment == null) {
      return buffer.toString();
    }
    return Uri(
      path: buffer.toString(),
      queryParameters: normalizedQueries,
      fragment: (fragment != null && fragment.isNotEmpty) ? fragment : null,
    ).toString();
  }

  /// Builds the URL for this route.
  ///
  /// Retained for source compatibility with 1.x. Prefer [location], whose
  /// parameter list also covers `fragment` and whose name says what it
  /// returns.
  String pathWithParams(
    Map<String, String> params, {
    Map<String, dynamic>? queries,
    String? fragment,
    bool validate = true,
  }) => location(
    params: params,
    queries: queries,
    fragment: fragment,
    validate: validate,
  );

  static Map<String, dynamic>? _normalizeQueries(Map<String, dynamic>? input) {
    if (input == null || input.isEmpty) return null;
    final out = <String, dynamic>{};
    for (final entry in input.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is Iterable) {
        final items = <String>[
          for (final item in value)
            if (item != null) item.toString(),
        ];
        if (items.isNotEmpty) out[entry.key] = items;
      } else {
        out[entry.key] = value.toString();
      }
    }
    return out.isEmpty ? null : out;
  }

  /// Converts this definition into a `GoRoute`, forwarding every field
  /// go_router accepts.
  GoRoute toGoRoute({List<RouteBase> routes = const []}) {
    return GoRoute(
      path: path,
      name: name,
      builder: builder,
      pageBuilder: pageBuilder,
      redirect: composedRedirect,
      onExit: onExit,
      parentNavigatorKey: parentNavigatorKey,
      caseSensitive: caseSensitive,
      metadata: metadata,
      routes: routes,
    );
  }

  @override
  List<Object?> get props => [
    path,
    template,
    name,
    description,
    caseSensitive,
    metadata,
    // `builder`/`pageBuilder` are deliberately excluded: they are closures
    // rebuilt on every construction, so including them would make two
    // instances of the same generated route unequal and their `hashCode`
    // unstable — defeating the point of extending Equatable.
  ];

  @override
  String toString() =>
      'RoutePaths(template: $template, name: $name'
      '${description == null ? '' : ', description: $description'})';
}

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Base class for all route definitions
abstract class RoutePaths extends Equatable {
  const RoutePaths({
    required this.path,
    this.name,
    required this.builder,
    this.description,
    this.middleware = const [],
  });

  /// The route path with parameters
  final String path;

  /// Optional route name
  final String? name;

  /// Widget builder function
  final Widget Function(BuildContext, GoRouterState) builder;

  /// Route description for documentation
  final String? description;

  /// Middleware functions
  final List<FutureOr<String?> Function(BuildContext, GoRouterState)>
      middleware;

  /// Auto-detect required parameters from path
  List<String> get requiredParams {
    return RegExp(r':(\w+)(?!\?)')
        .allMatches(path)
        .map((match) => match.group(1)!)
        .toList();
  }

  /// Auto-detect optional parameters from path
  List<String> get optionalParams {
    return RegExp(r':(\w+)\?')
        .allMatches(path)
        .map((match) => match.group(1)!)
        .toList();
  }

  /// Validate parameters
  void validateParams(Map<String, String> params) {
    final missing =
        requiredParams.where((p) => !params.containsKey(p)).toList();
    if (missing.isNotEmpty) {
      throw ArgumentError('Missing required parameters: ${missing.join(', ')}');
    }
  }

  /// Generate path with parameters
  String pathWithParams(
    Map<String, String> params, {
    Map<String, String>? queries,
    bool validate = true,
  }) {
    if (validate) {
      validateParams(params);
    }

    String finalPath = path;

    // Handle required parameters
    for (final param in requiredParams) {
      finalPath = finalPath.replaceAll(
        ':$param',
        Uri.encodeComponent(params[param]!),
      );
    }

    // Handle optional parameters
    for (final param in optionalParams) {
      if (params.containsKey(param) && params[param]!.isNotEmpty) {
        finalPath = finalPath.replaceAll(
          ':$param?',
          Uri.encodeComponent(params[param]!),
        );
      } else {
        finalPath = finalPath.replaceAll('/:$param?', '');
      }
    }

    // Add query parameters
    if (queries != null && queries.isNotEmpty) {
      final queryString = queries.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      finalPath += '?$queryString';
    }

    return finalPath;
  }

  Future<String?> _executeMiddleware(
      BuildContext context, GoRouterState state) async {
    for (final function in middleware) {
      final result = await function(context, state);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  /// Generate GoRoute
  GoRoute toGoRoute({
    List<RouteBase> routes = const [],
  }) {
    return GoRoute(
      path: _normalizePathForGoRoute(),
      name: name ?? _generateName(),
      builder: builder,
      redirect: middleware.isNotEmpty ? _executeMiddleware : null,
      routes: routes,
    );
  }

  /// Convert path with optional params to GoRouter format
  String _normalizePathForGoRoute() {
    return path.replaceAll(RegExp(r':(\w+)\?'), r':$1');
  }

  String _generateName() {
    return path
        .replaceAll('/', '_')
        .replaceAll(':', '')
        .replaceAll('?', '')
        .replaceAll('-', '_')
        .toLowerCase()
        .substring(1);
  }

  @override
  List<Object?> get props => [path, name, builder, description];

  @override
  String toString() {
    return 'RoutePaths(path: $path, name: $name, description: $description)';
  }
}

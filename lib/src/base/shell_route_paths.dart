// lib/src/base/shell_route_paths.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Base class for shell route definitions
abstract class ShellRoutePaths extends Equatable {
  const ShellRoutePaths({
    required this.path,
    this.name,
    required this.builder,
    this.description,
    this.navigatorKey,
    this.isStateful = false,
  });

  final String path;
  final String? name;
  // Note: The builder signature is `(context, state, childAsWidget)`.
  // For stateful shells, `go_router` passes the `StatefulNavigationShell` as the child widget.
  // This compatibility is key to making this work without a separate base class.
  final Widget Function(BuildContext, GoRouterState, Widget) builder;
  final String? description;
  final GlobalKey<NavigatorState>? navigatorKey;
  final bool isStateful;

  /// Generate ShellRoute
  ShellRoute toShellRoute({List<RouteBase> routes = const []}) {
    return ShellRoute(
      builder: builder,
      routes: routes,
      navigatorKey: navigatorKey,
    );
  }

  /// Generate regular GoRoute (fallback). This should ideally not be called directly for a shell.
  GoRoute toGoRoute({List<RouteBase> routes = const []}) {
    return GoRoute(
      path: path,
      name: name,
      builder: (context, state) {
        assert(false,
            'A ShellRoute was rendered without a child. This is usually an error in your routing setup.');
        return const Scaffold(
          body: Center(
            child: Text('Error: ShellRoute rendered without a child widget.'),
          ),
        );
      },
      routes: routes,
    );
  }

  @override
  List<Object?> get props =>
      [path, name, builder, description, navigatorKey, isStateful];
}

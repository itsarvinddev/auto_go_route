import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_guard.dart';

/// Base class for a generated shell-route definition.
///
/// One subclass is generated per `@AutoGoRouteShell` widget. A shell wraps its
/// children without contributing a URL segment: [toShellRoute] emits a plain
/// `ShellRoute`, [toStatefulShellRoute] a `StatefulShellRoute.indexedStack`
/// (or the general constructor when [navigatorContainerBuilder] is set).
///
/// The builder fields come in stateless and stateful pairs because go_router
/// hands a stateless shell a plain `Widget child` and a stateful one a
/// `StatefulNavigationShell`. Keeping them as separately typed fields is what
/// turns "declared `isStateful: false` but wrote a `navigationShell`
/// parameter" into a compile error instead of a runtime cast failure.
abstract class ShellRoutePaths extends Equatable with RouteGuardMixin {
  /// Creates a shell-route definition.
  const ShellRoutePaths({
    required this.path,
    this.name,
    this.description,
    this.builder,
    this.pageBuilder,
    this.statefulBuilder,
    this.statefulPageBuilder,
    this.navigatorKey,
    this.isStateful = false,
    this.middleware = const [],
    this.redirect,
    this.parentNavigatorKey,
    this.metadata,
    this.observers,
    this.restorationScopeId,
    this.notifyRootObserver = true,
    this.navigatorContainerBuilder,
    this.initialRoute,
  }) : assert(
         isStateful
             ? (statefulBuilder != null) != (statefulPageBuilder != null)
             : (builder != null) != (pageBuilder != null),
         'A shell needs exactly one builder, matching its isStateful flag: '
         'builder/pageBuilder when false, '
         'statefulBuilder/statefulPageBuilder when true.',
       );

  /// The shell's declared path.
  ///
  /// Shells are transparent in go_router, so this is used for identity,
  /// [initialRoute] redirection and diagnostics rather than for matching.
  final String path;

  /// The shell's name.
  final String? name;

  /// Free-text description for generated documentation.
  final String? description;

  /// Builds a stateless shell around its child navigator.
  final Widget Function(BuildContext, GoRouterState, Widget)? builder;

  /// Builds the page for a stateless shell.
  final Page<dynamic> Function(BuildContext, GoRouterState, Widget)?
  pageBuilder;

  /// Builds a stateful shell around its branch navigators.
  final Widget Function(BuildContext, GoRouterState, StatefulNavigationShell)?
  statefulBuilder;

  /// Builds the page for a stateful shell.
  final Page<dynamic> Function(
    BuildContext,
    GoRouterState,
    StatefulNavigationShell,
  )?
  statefulPageBuilder;

  /// The shell's own navigator key.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Whether this shell preserves per-branch state.
  final bool isStateful;

  @override
  final List<RouteGuard> middleware;

  @override
  final RouteGuard? redirect;

  /// The navigator the shell itself is placed on.
  final GlobalKey<NavigatorState>? parentNavigatorKey;

  /// Metadata merged into every child's `GoRouterState.metadata`.
  final Map<String, dynamic>? metadata;

  /// Observers for the shell's navigator.
  final List<NavigatorObserver>? observers;

  /// State-restoration scope id for the shell's navigator.
  final String? restorationScopeId;

  /// Whether navigation inside the shell notifies the router's top-level
  /// observers.
  final bool notifyRootObserver;

  /// Lays the branch navigators out in place of the default `IndexedStack`.
  ///
  /// Only used when [isStateful] is `true`.
  final ShellNavigationContainerBuilder? navigatorContainerBuilder;

  /// Absolute location to redirect to when the shell's own [path] is visited.
  final String? initialRoute;

  /// Emits the `ShellRoute` for a stateless shell.
  ///
  /// Throws a [StateError] when called on a stateful shell — use
  /// [toStatefulShellRoute] there.
  ShellRoute toShellRoute({required List<RouteBase> routes}) {
    if (isStateful) {
      throw StateError(
        'Shell "${name ?? path}" is stateful; call toStatefulShellRoute() '
        'instead of toShellRoute().',
      );
    }
    return ShellRoute(
      builder: builder,
      pageBuilder: pageBuilder,
      routes: routes,
      navigatorKey: navigatorKey,
      parentNavigatorKey: parentNavigatorKey,
      redirect: composedRedirect,
      metadata: metadata,
      observers: observers,
      restorationScopeId: restorationScopeId,
      notifyRootObserver: notifyRootObserver,
    );
  }

  /// Emits the `StatefulShellRoute` for a stateful shell.
  ///
  /// Lays the branch navigators out in an `IndexedStack` unless
  /// [navigatorContainerBuilder] is supplied, in which case the caller controls
  /// the layout.
  ///
  /// Always uses the general `StatefulShellRoute` constructor. go_router's
  /// `StatefulShellRoute.indexedStack` has no `metadata` parameter, so going
  /// through it would silently drop the shell's metadata — and with it every
  /// guard that reads `GoRouterState.metadata` for a child route. The default
  /// container here is a faithful copy of the one that constructor uses.
  ///
  /// Throws a [StateError] when called on a stateless shell.
  StatefulShellRoute toStatefulShellRoute({
    required List<StatefulShellBranch> branches,
  }) {
    if (!isStateful) {
      throw StateError(
        'Shell "${name ?? path}" is not stateful; call toShellRoute() '
        'instead of toStatefulShellRoute().',
      );
    }
    return StatefulShellRoute(
      branches: branches,
      navigatorContainerBuilder:
          navigatorContainerBuilder ?? indexedStackContainerBuilder,
      builder: statefulBuilder,
      pageBuilder: statefulPageBuilder,
      parentNavigatorKey: parentNavigatorKey,
      redirect: composedRedirect,
      metadata: metadata,
      restorationScopeId: restorationScopeId,
      notifyRootObserver: notifyRootObserver,
    );
  }

  /// The branch layout `StatefulShellRoute.indexedStack` uses: every branch
  /// navigator stays mounted, only the active one is visible and ticking.
  ///
  /// Public so a custom [navigatorContainerBuilder] can wrap it — adding an
  /// animation around the default layout, for instance.
  static Widget indexedStackContainerBuilder(
    BuildContext context,
    StatefulNavigationShell navigationShell,
    List<Widget> children,
  ) {
    final currentIndex = navigationShell.currentIndex;
    return IndexedStack(
      index: currentIndex,
      children: [
        for (var index = 0; index < children.length; index++)
          Offstage(
            offstage: index != currentIndex,
            child: TickerMode(
              enabled: index == currentIndex,
              child: children[index],
            ),
          ),
      ],
    );
  }

  @override
  List<Object?> get props => [
    path,
    name,
    description,
    isStateful,
    navigatorKey,
    parentNavigatorKey,
    restorationScopeId,
    notifyRootObserver,
    initialRoute,
    metadata,
  ];

  @override
  String toString() =>
      'ShellRoutePaths(path: $path, name: $name, isStateful: $isStateful)';
}

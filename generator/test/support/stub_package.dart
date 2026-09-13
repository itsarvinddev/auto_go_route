/// A stand-in for `package:auto_go_route` used by the builder tests.
///
/// `testBuilder` resolves its inputs against the assets it is handed, and the
/// real `auto_go_route` depends on Flutter — which a pure-Dart generator
/// package cannot resolve. This stub declares only what the generator actually
/// looks at:
///
/// * the annotation classes, matched by name plus package via
///   `TypeChecker.typeNamedLiterally(…, inPackage: 'auto_go_route')`;
/// * `Widget` and `StatefulNavigationShell`, matched by display name when
///   finding a shell's child slot.
///
/// The generator emits *source*, so nothing here has to be runnable — the
/// golden assertions compare the emitted text.
const stubAnnotations = r'''
class AutoGoRoute {
  const AutoGoRoute({
    required this.path,
    this.name,
    this.description,
    this.parent,
    this.middleware = const [],
    this.order,
    this.redirect,
    this.onExit,
    this.parentNavigatorKey,
    this.caseSensitive,
    this.metadata,
    this.pageBuilder,
    this.transition,
    this.transitionDurationMs,
    this.reverseTransitionDurationMs,
    this.fullscreenDialog = false,
    this.opaque = true,
    this.barrierDismissible = false,
    this.barrierColor,
    this.restorationId,
  });

  final String path;
  final String? name;
  final String? description;
  final Type? parent;
  final List<String> middleware;
  final int? order;
  final String? redirect;
  final String? onExit;
  final String? parentNavigatorKey;
  final bool? caseSensitive;
  final Map<String, Object?>? metadata;
  final String? pageBuilder;
  final AutoRouteTransition? transition;
  final int? transitionDurationMs;
  final int? reverseTransitionDurationMs;
  final bool fullscreenDialog;
  final bool opaque;
  final bool barrierDismissible;
  final String? barrierColor;
  final String? restorationId;
}

class AutoGoRouteShell {
  const AutoGoRouteShell({
    required this.path,
    this.name,
    this.description,
    this.navigatorKey,
    this.parent,
    this.isStateful = false,
    this.initialRoute,
    this.order,
    this.pageBuilder,
    this.middleware = const [],
    this.redirect,
    this.parentNavigatorKey,
    this.metadata,
    this.observers,
    this.restorationScopeId,
    this.notifyRootObserver = true,
    this.navigatorContainerBuilder,
  });

  final String path;
  final String? name;
  final String? description;
  final String? navigatorKey;
  final Type? parent;
  final bool isStateful;
  final String? initialRoute;
  final int? order;
  final String? pageBuilder;
  final List<String> middleware;
  final String? redirect;
  final String? parentNavigatorKey;
  final Map<String, Object?>? metadata;
  final String? observers;
  final String? restorationScopeId;
  final bool notifyRootObserver;
  final String? navigatorContainerBuilder;
}

class AutoGoRouteBranch {
  const AutoGoRouteBranch({
    this.navigatorKey,
    this.initialLocation,
    this.restorationScopeId,
    this.observers,
    this.preload = false,
  });

  final String? navigatorKey;
  final String? initialLocation;
  final String? restorationScopeId;
  final String? observers;
  final bool preload;
}

class AutoGoRouteBase {
  const AutoGoRouteBase({
    this.sourceGlobs,
    this.navigatorKey,
    this.initialLocation,
    this.initialExtra,
    this.errorBuilder,
    this.errorPageBuilder,
    this.errorWidget,
    this.onException,
    this.redirect,
    this.onEnter,
    this.observers,
    this.refreshListenable,
    this.extraCodec,
    this.redirectLimit = 5,
    this.routerNeglect = false,
    this.debugLogDiagnostics = false,
    this.overridePlatformDefaultLocation = false,
    this.requestFocus = true,
    this.restorationScopeId,
    this.caseSensitive = true,
    this.navigatorExtensionName = 'AutoGoRouteNavigation',
    this.generateRouteEnum = true,
  });

  final List<String>? sourceGlobs;
  final String? navigatorKey;
  final String? initialLocation;
  final String? initialExtra;
  final String? errorBuilder;
  final String? errorPageBuilder;
  final String? errorWidget;
  final String? onException;
  final String? redirect;
  final String? onEnter;
  final String? observers;
  final String? refreshListenable;
  final String? extraCodec;
  final int redirectLimit;
  final bool routerNeglect;
  final bool debugLogDiagnostics;
  final bool overridePlatformDefaultLocation;
  final bool requestFocus;
  final String? restorationScopeId;
  final bool caseSensitive;
  final String navigatorExtensionName;
  final bool generateRouteEnum;
}

class PathParam {
  const PathParam([this.name]);
  final String? name;
}

class QueryParam {
  const QueryParam([this.name]);
  final String? name;
}

class RouteExtra {
  const RouteExtra();
}

class RouteIgnore {
  const RouteIgnore();
}

enum AutoRouteTransition {
  platform,
  material,
  cupertino,
  fade,
  slide,
  slideUp,
  slideDown,
  scale,
  rotation,
  none,
}

/// Stands in for Flutter's `Widget`, which is how a stateless shell's child
/// slot is recognised.
class Widget {
  const Widget();
}

/// Stands in for go_router's `StatefulNavigationShell`.
class StatefulNavigationShell extends Widget {
  const StatefulNavigationShell();
}
''';

/// The asset map entry every builder test needs.
Map<String, String> get stubAssets => {
  'auto_go_route|lib/auto_go_route.dart': stubAnnotations,
};

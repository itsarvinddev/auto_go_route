/// The page transition a generated route should use.
///
/// Anything beyond these presets is expressible with
/// [AutoGoRoute.pageBuilder], which hands you the raw
/// `Page<dynamic> Function(BuildContext, GoRouterState)` that go_router wants.
enum AutoRouteTransition {
  /// Use the ambient platform default: `MaterialPage` on Android/desktop/web,
  /// `CupertinoPage` on iOS/macOS. This is what a plain `builder:` route does,
  /// and it is the default.
  platform,

  /// Always a Material page transition, on every platform.
  material,

  /// Always a Cupertino page transition, on every platform.
  cupertino,

  /// Cross-fade.
  fade,

  /// Slide in from the trailing edge (right in LTR, left in RTL).
  slide,

  /// Slide up from the bottom.
  slideUp,

  /// Slide down from the top.
  slideDown,

  /// Scale up from the centre.
  scale,

  /// Rotate and scale in.
  rotation,

  /// No animation at all. Useful for tab switches and shell children, where an
  /// animation reads as a glitch.
  none,
}

/// Marks a widget as a route and generates a typed `GoRoute` for it.
///
/// Apply it to the widget itself — the widget *is* the route definition:
///
/// ```dart
/// @AutoGoRoute(path: '/products/:id')
/// class ProductPage extends StatelessWidget {
///   const ProductPage({super.key, required this.id, this.tab});
///
///   /// Read from the path, and typed: `context.goToProductPage(id: 7)`.
///   final int id;
///
///   /// Not in the path, so read from the query string: `?tab=reviews`.
///   final String? tab;
///   // ...
/// }
/// ```
///
/// Constructor parameters are classified in this order:
///
/// 1. `key`, and a shell's child slot, are skipped.
/// 2. An explicit [PathParam], [QueryParam], [RouteExtra] or [RouteIgnore]
///    annotation wins.
/// 3. A name appearing in the route's resolved full path is a path parameter.
/// 4. A [RouteCodec]-supported type is a query parameter.
/// 5. Anything else comes from `state.extra`.
///
/// A required parameter with no derivable source is a build error rather than
/// a silently empty string.
class AutoGoRoute {
  /// Creates a route annotation.
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

  /// The route path.
  ///
  /// Absolute (`/products`) for a top-level route, relative (`:id`) for a
  /// route with a [parent]. go_router has no optional path parameters, so
  /// `:id?` is rejected at build time — use a query parameter or declare two
  /// routes.
  ///
  /// Regular-expression constraints are supported and preserved:
  /// `':id(\\d+)'` matches only digits.
  final String path;

  /// The route's name, used for `goNamed`-style navigation and for the
  /// generated helper names.
  ///
  /// Defaults to the widget's class name in lower camel case. Must be a valid
  /// Dart identifier, because it becomes part of `goTo…`/`pushTo…` method
  /// names.
  final String? name;

  /// Free-text description, surfaced in generated doc comments and in
  /// [RouteRegistry] documentation output.
  final String? description;

  /// The widget class this route nests under — another `@AutoGoRoute` widget,
  /// or an `@AutoGoRouteShell` one.
  final Type? parent;

  /// Names of guard functions to run before this route is shown, in order.
  ///
  /// Each must be a top-level or static function visible from the library
  /// holding `@AutoGoRouteBase`, with the signature
  /// `FutureOr<String?> Function(BuildContext, GoRouterState)`. Returning
  /// `null` allows navigation; returning a location redirects to it. The first
  /// non-null result wins, and [redirect] runs before any of them.
  final List<String> middleware;

  /// Sort order among siblings.
  ///
  /// Also fixes branch order — and therefore tab index — under a stateful
  /// shell. Routes without an explicit order sort last, then by class name so
  /// the output is stable across builds.
  final int? order;

  /// Name of a `FutureOr<String?> Function(BuildContext, GoRouterState)` to
  /// use as this route's `GoRoute.redirect`.
  ///
  /// Unlike [middleware] this maps straight onto go_router's own field, so a
  /// parent's redirect takes priority over a child's.
  final String? redirect;

  /// Name of a `FutureOr<bool> Function(BuildContext, GoRouterState)` called
  /// before this route is popped.
  ///
  /// Return `false` to keep the user here — the standard "discard unsaved
  /// changes?" prompt.
  final String? onExit;

  /// Name of a `GlobalKey<NavigatorState>` to place this route on.
  ///
  /// Set it to a shell's root navigator key to have the route cover the shell
  /// — a full-screen page over a bottom navigation bar, for instance.
  final String? parentNavigatorKey;

  /// Whether path matching is case-sensitive.
  ///
  /// Leave `null` to inherit [AutoGoRouteBase.caseSensitive], which itself
  /// defaults to `true` (go_router 15+). An explicit value here always wins.
  final bool? caseSensitive;

  /// Application-defined metadata attached to this route.
  ///
  /// Merged down the match and readable as `GoRouterState.metadata`, which
  /// makes it the natural home for declarative guard data:
  ///
  /// ```dart
  /// @AutoGoRoute(path: '/admin', metadata: {'requiresRole': 'admin'})
  /// ```
  ///
  /// Values must be compile-time constants the generator can re-emit: `null`,
  /// `String`, `int`, `double`, `bool`, enum values, and lists or maps of
  /// those.
  final Map<String, Object?>? metadata;

  /// Name of a `Page<dynamic> Function(BuildContext, GoRouterState)` to build
  /// this route's page.
  ///
  /// The escape hatch for anything [transition] does not cover. Mutually
  /// exclusive with [transition].
  final String? pageBuilder;

  /// The page transition to use. Leave `null` for a plain `builder:` route,
  /// which follows the platform default.
  final AutoRouteTransition? transition;

  /// Forward transition duration in milliseconds. Only meaningful with
  /// [transition].
  final int? transitionDurationMs;

  /// Reverse transition duration in milliseconds. Defaults to
  /// [transitionDurationMs].
  final int? reverseTransitionDurationMs;

  /// Whether the route is presented as a full-screen dialog.
  final bool fullscreenDialog;

  /// Whether the page is opaque. Set `false` to keep the route beneath it
  /// visible — required for dialog- and sheet-style routes.
  final bool opaque;

  /// Whether tapping outside a non-[opaque] page dismisses it.
  final bool barrierDismissible;

  /// Name of a `Color` constant to use as the modal barrier colour behind a
  /// non-[opaque] page.
  final String? barrierColor;

  /// State-restoration id for this route's page.
  ///
  /// Restoration works only through a `Page`, so setting this implies a
  /// [transition] (defaulting to [AutoRouteTransition.platform]).
  final String? restorationId;
}

/// Marks a widget as a `ShellRoute` or `StatefulShellRoute` wrapping its
/// children.
///
/// A non-stateful shell's widget takes a `Widget child`; a stateful one takes a
/// `StatefulNavigationShell navigationShell`:
///
/// ```dart
/// @AutoGoRouteShell(path: '/', isStateful: true)
/// class DashboardShell extends StatelessWidget {
///   const DashboardShell({super.key, required this.navigationShell});
///   final StatefulNavigationShell navigationShell;
///   // ... Scaffold with a NavigationBar driven by navigationShell ...
/// }
/// ```
class AutoGoRouteShell {
  /// Creates a shell-route annotation.
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

  /// The shell's path.
  ///
  /// A shell contributes no URL segment of its own — go_router shells are
  /// transparent — so this is used for identity, for [initialRoute]
  /// redirection, and for diagnostics.
  final String path;

  /// The shell's name. Defaults to the class name in lower camel case.
  final String? name;

  /// Free-text description for generated documentation.
  final String? description;

  /// Name of a `GlobalKey<NavigatorState>` for the shell's own navigator.
  ///
  /// Supply one when routes elsewhere need to target this navigator via
  /// [AutoGoRoute.parentNavigatorKey].
  final String? navigatorKey;

  /// The widget class this shell nests under.
  final Type? parent;

  /// Whether to emit a `StatefulShellRoute.indexedStack` — each child becomes
  /// a branch with its own navigator and preserved state, which is what a
  /// bottom navigation bar needs.
  final bool isStateful;

  /// Absolute path to redirect to when the shell's own [path] is visited
  /// directly.
  ///
  /// Defaults to the first child's resolved path. Honoured for every shell,
  /// not just the root one.
  final String? initialRoute;

  /// Sort order among siblings. See [AutoGoRoute.order].
  final int? order;

  /// Name of a page builder for the shell.
  ///
  /// For a non-stateful shell the signature is
  /// `Page<dynamic> Function(BuildContext, GoRouterState, Widget)`; for a
  /// stateful one it is
  /// `Page<dynamic> Function(BuildContext, GoRouterState, StatefulNavigationShell)`.
  final String? pageBuilder;

  /// Guard function names run before any child of this shell. See
  /// [AutoGoRoute.middleware].
  final List<String> middleware;

  /// Name of a redirect function mapped onto `ShellRoute.redirect`.
  final String? redirect;

  /// Name of a `GlobalKey<NavigatorState>` to place the shell itself on.
  final String? parentNavigatorKey;

  /// Metadata merged into every child's `GoRouterState.metadata`. See
  /// [AutoGoRoute.metadata].
  final Map<String, Object?>? metadata;

  /// Name of a `List<NavigatorObserver>` for the shell's navigator.
  final String? observers;

  /// State-restoration scope id for the shell's navigator.
  final String? restorationScopeId;

  /// Whether navigation inside this shell notifies the router's top-level
  /// observers. Defaults to `true`, matching go_router 17+.
  final bool notifyRootObserver;

  /// Name of a `ShellNavigationContainerBuilder` to lay the branch navigators
  /// out yourself instead of using an `IndexedStack`.
  ///
  /// Only meaningful when [isStateful] is `true`; supplying it emits the
  /// general `StatefulShellRoute` constructor.
  final String? navigatorContainerBuilder;

  /// Whether the shell is stateless in the go_router sense (a plain
  /// `ShellRoute`).
  bool get isPlainShell => !isStateful;
}

/// Configures the branch a child route occupies under a stateful shell.
///
/// Branch identity *is* the child route, so this goes on the child rather than
/// as index-parallel lists on the shell:
///
/// ```dart
/// @AutoGoRouteBranch(preload: true, initialLocation: '/feed')
/// @AutoGoRoute(path: '/feed', parent: DashboardShell, order: 0)
/// class FeedPage extends StatelessWidget { /* ... */ }
/// ```
///
/// Ignored, with a build warning, on a route whose parent is not a stateful
/// shell.
class AutoGoRouteBranch {
  /// Creates a branch annotation.
  const AutoGoRouteBranch({
    this.navigatorKey,
    this.initialLocation,
    this.restorationScopeId,
    this.observers,
    this.preload = false,
  });

  /// Name of a `GlobalKey<NavigatorState>` for this branch's navigator.
  final String? navigatorKey;

  /// The location this branch starts at.
  ///
  /// Defaults to the child route's own resolved path. Set it explicitly when
  /// the branch's landing route takes path parameters, which go_router cannot
  /// derive a default for.
  final String? initialLocation;

  /// State-restoration scope id for this branch.
  final String? restorationScopeId;

  /// Name of a `List<NavigatorObserver>` for this branch's navigator.
  final String? observers;

  /// Whether to build this branch eagerly instead of on first visit.
  final bool preload;
}

/// Marks the class the router is generated into.
///
/// The annotated class must be `part`-linked to the generated file and extend
/// the generated `_$`-prefixed base:
///
/// ```dart
/// part 'app_router.routes.g.dart';
///
/// @AutoGoRouteBase(initialLocation: '/home')
/// class AppRouter extends _$AppRouter {}
/// ```
///
/// Every value passed here is a *default*: the generated
/// `buildRouter({...})` accepts the same options as named parameters, so
/// anything that cannot be a compile-time constant — a `refreshListenable`,
/// a closure over your DI container — is passed at call time instead.
class AutoGoRouteBase {
  /// Creates a router-base annotation.
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

  /// Asset globs this router scans for annotated widgets, overriding the
  /// builder's `source_globs` option.
  ///
  /// Only needed when a package has more than one `@AutoGoRouteBase`: without
  /// it every router picks up every route, and the generated route classes of
  /// the two collide if both libraries are imported together.
  ///
  /// ```dart
  /// @AutoGoRouteBase(sourceGlobs: ['lib/admin/**/*.dart'])
  /// class AdminRouter extends _$AdminRouter {}
  /// ```
  final List<String>? sourceGlobs;

  /// Name of a `GlobalKey<NavigatorState>` for the router's root navigator.
  ///
  /// Declare it here whenever any route uses
  /// [AutoGoRoute.parentNavigatorKey] to draw itself over a shell: go_router
  /// asserts that a route's `parentNavigatorKey` is either a shell's navigator
  /// key or *the router's own*, and this is what makes the latter true without
  /// every caller having to remember to pass it to `buildRouter()`.
  final String? navigatorKey;

  /// The location the router starts at.
  final String? initialLocation;

  /// Name of a constant to pass as the initial route's `extra`.
  final String? initialExtra;

  /// Name of a `Widget Function(BuildContext, GoRouterState)` used as
  /// `GoRouter.errorBuilder`.
  ///
  /// Mutually exclusive with [errorPageBuilder] and [errorWidget].
  final String? errorBuilder;

  /// Name of a `Page<dynamic> Function(BuildContext, GoRouterState)` used as
  /// `GoRouter.errorPageBuilder`.
  final String? errorPageBuilder;

  /// Name of a widget constructor taking a single named `error` argument,
  /// e.g. `'ErrorScreen.new'`.
  ///
  /// Shorthand for the common case; generates
  /// `errorBuilder: (context, state) => ErrorScreen(error: state.error)`.
  final String? errorWidget;

  /// Name of a `void Function(BuildContext, GoRouterState, GoRouter)` used as
  /// `GoRouter.onException`.
  final String? onException;

  /// Name of a top-level redirect function.
  final String? redirect;

  /// Name of an `OnEnter` callback, run before every navigation with access to
  /// both the current and the next state.
  ///
  /// Return `Allow()` or `Block.stop()`. Requires go_router >= 16.3.0.
  final String? onEnter;

  /// Name of a `List<NavigatorObserver>` for the root navigator.
  final String? observers;

  /// Name of a `Listenable` that triggers re-evaluation of redirects when it
  /// notifies — typically your auth service.
  final String? refreshListenable;

  /// Name of a `Codec<Object?, Object?>` used to serialise `extra` for state
  /// restoration and browser history.
  final String? extraCodec;

  /// How many redirects to follow before giving up. Defaults to 5.
  final int redirectLimit;

  /// Whether to tell the engine not to push browser history entries.
  final bool routerNeglect;

  /// Whether go_router logs its routing decisions.
  final bool debugLogDiagnostics;

  /// Whether [initialLocation] wins over the platform's initial route.
  final bool overridePlatformDefaultLocation;

  /// Whether the router requests focus after navigating.
  final bool requestFocus;

  /// State-restoration scope id for the root navigator.
  final String? restorationScopeId;

  /// The case sensitivity of every route that does not set
  /// [AutoGoRoute.caseSensitive] itself.
  final bool caseSensitive;

  /// Name of the generated `BuildContext` extension carrying the
  /// `goTo…`/`pushTo…` helpers.
  final String navigatorExtensionName;

  /// Whether to generate the route enum (one value per route, with its name
  /// and template) and a branch enum per stateful shell (one value per branch,
  /// in tab order, with `go`, `goFrom`, `of` and `isActiveIn`).
  final bool generateRouteEnum;
}

/// Forces a constructor parameter to be read from the path.
///
/// Only needed to rename: `@PathParam('id') final int productId`.
class PathParam {
  /// Creates a path-parameter marker, optionally renaming it.
  const PathParam([this.name]);

  /// The parameter's name in the path, when it differs from the Dart field.
  final String? name;
}

/// Forces a constructor parameter to be read from the query string.
///
/// Use it to rename (`@QueryParam('q') final String? search`) or to keep a
/// parameter out of `extra` when its type would otherwise land there.
class QueryParam {
  /// Creates a query-parameter marker, optionally renaming it.
  const QueryParam([this.name]);

  /// The parameter's name in the query string, when it differs from the Dart
  /// field.
  final String? name;
}

/// Marks the constructor parameter that receives `GoRouterState.extra`.
///
/// At most one per route. Without it, a parameter whose type no URL can carry
/// is inferred to be the `extra` — but only one such parameter is allowed,
/// since there is only one `extra` to go around.
class RouteExtra {
  /// Marks a parameter as the route's `extra` payload.
  const RouteExtra();
}

/// Excludes a constructor parameter from route generation.
///
/// The parameter must have a default value or be nullable, since the generated
/// builder will not pass it.
class RouteIgnore {
  /// Marks a parameter as not route-provided.
  const RouteIgnore();
}

/// Shorthand for `@RouteExtra()`.
const routeExtra = RouteExtra();

/// Shorthand for `@RouteIgnore()`.
const routeIgnore = RouteIgnore();

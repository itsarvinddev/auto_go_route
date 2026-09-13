/// Where a route builder sources a constructor argument from.
enum ParamSource {
  /// A `:name` segment in the route's path.
  path,

  /// A `?name=` entry in the query string.
  query,

  /// `GoRouterState.extra`.
  extra,

  /// The child widget or navigation shell a shell route wraps.
  shellChild,
}

/// The parameter kinds that survive a round trip through a URL.
enum ParamKind {
  /// `String`
  string,

  /// `int`
  int,

  /// `double`
  double,

  /// `num`
  num,

  /// `bool`
  bool,

  /// `BigInt`
  bigInt,

  /// `DateTime`
  dateTime,

  /// `Uri`
  uri,

  /// Any enum declaration.
  enumeration,

  /// A `List<T>` of any of the above; only valid for a query parameter.
  list,

  /// A type no URL can carry, so it travels in `extra`.
  opaque,
}

/// One constructor argument of an annotated widget, resolved to a source and a
/// codec.
class ParamInfo {
  /// Creates a parameter description.
  const ParamInfo({
    required this.dartName,
    required this.wireName,
    required this.typeSource,
    required this.kind,
    required this.source,
    required this.isNullable,
    required this.isNamed,
    required this.isRequired,
    required this.hasDefault,
    this.defaultValueCode,
    this.enumTypeSource,
    this.elementKind,
    this.elementTypeSource,
  });

  /// The constructor parameter's Dart name.
  final String dartName;

  /// The name used in the URL, which differs from [dartName] when
  /// `@PathParam('x')` or `@QueryParam('x')` renames it.
  final String wireName;

  /// The parameter's type, spelled as source (`int`, `String?`,
  /// `List<SortOrder>`).
  final String typeSource;

  /// Which codec family the type belongs to.
  final ParamKind kind;

  /// Where the value comes from.
  final ParamSource source;

  /// Whether the declared type admits null.
  final bool isNullable;

  /// Whether the constructor takes this parameter by name.
  final bool isNamed;

  /// Whether the constructor requires this parameter.
  final bool isRequired;

  /// Whether the constructor declares a default for this parameter.
  final bool hasDefault;

  /// The default's source text, when the constructor declares one.
  ///
  /// Emitted as the `??` fallback for a non-nullable query parameter, so the
  /// widget's own default is what applies when the query string omits it.
  final String? defaultValueCode;

  /// For [ParamKind.enumeration], the enum type's source name.
  final String? enumTypeSource;

  /// For [ParamKind.list], the element's kind.
  final ParamKind? elementKind;

  /// For [ParamKind.list], the element type's source name.
  final String? elementTypeSource;

  /// The type with any trailing `?` removed.
  String get nonNullableTypeSource => isNullable && typeSource.endsWith('?')
      ? typeSource.substring(0, typeSource.length - 1)
      : typeSource;
}

/// Page and transition configuration read from an `@AutoGoRoute`.
class PageConfig {
  /// Creates a page configuration.
  const PageConfig({
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

  /// Name of a user-supplied page-builder function.
  final String? pageBuilder;

  /// The `AutoRouteTransition` value's name, e.g. `fade`.
  final String? transition;

  /// Forward transition duration in milliseconds.
  final int? transitionDurationMs;

  /// Reverse transition duration in milliseconds.
  final int? reverseTransitionDurationMs;

  /// Whether the page is a full-screen dialog.
  final bool fullscreenDialog;

  /// Whether the page is opaque.
  final bool opaque;

  /// Whether tapping outside dismisses a non-opaque page.
  final bool barrierDismissible;

  /// Name of a `Color` constant for the modal barrier.
  final String? barrierColor;

  /// State-restoration id for the page.
  final String? restorationId;

  /// Whether this route needs a `pageBuilder` rather than a plain `builder`.
  bool get needsPage =>
      pageBuilder != null || transition != null || restorationId != null;
}

/// Branch configuration read from an `@AutoGoRouteBranch`.
class BranchConfig {
  /// Creates a branch configuration.
  const BranchConfig({
    this.navigatorKey,
    this.initialLocation,
    this.restorationScopeId,
    this.observers,
    this.preload = false,
  });

  /// Name of a `GlobalKey<NavigatorState>` for the branch navigator.
  final String? navigatorKey;

  /// Explicit initial location for the branch.
  final String? initialLocation;

  /// State-restoration scope id for the branch.
  final String? restorationScopeId;

  /// Name of a `List<NavigatorObserver>` for the branch navigator.
  final String? observers;

  /// Whether the branch is built eagerly.
  final bool preload;
}

/// Fields common to a route and a shell.
abstract class NodeInfo {
  /// Creates the shared part of a route or shell description.
  const NodeInfo({
    required this.id,
    required this.className,
    required this.libraryUri,
    required this.path,
    required this.name,
    required this.parentId,
    required this.order,
    required this.description,
    required this.middleware,
    required this.redirect,
    required this.parentNavigatorKey,
    required this.metadataSource,
  });

  /// A library-qualified identity, `package:app/x.dart#MyPage`.
  ///
  /// Keying the graph on this rather than on the bare class name is what keeps
  /// two same-named widgets in different libraries from overwriting each other
  /// — and stops one from being mistaken for the other's parent.
  final String id;

  /// The annotated widget's class name.
  final String className;

  /// The URI of the library declaring the widget.
  final String libraryUri;

  /// The path as declared on the annotation.
  final String path;

  /// The route's name; defaults to the class name in lower camel case.
  final String name;

  /// The [id] of the parent node, if any.
  final String? parentId;

  /// Sort order among siblings.
  final int? order;

  /// Free-text description.
  final String? description;

  /// Names of guard functions.
  final List<String> middleware;

  /// Name of a redirect function.
  final String? redirect;

  /// Name of a `GlobalKey<NavigatorState>`.
  final String? parentNavigatorKey;

  /// The `metadata` map re-emitted as Dart source, or `null`.
  final String? metadataSource;
}

/// A widget annotated with `@AutoGoRoute`.
class RouteInfo extends NodeInfo {
  /// Creates a route description.
  const RouteInfo({
    required super.id,
    required super.className,
    required super.libraryUri,
    required super.path,
    required super.name,
    required super.parentId,
    required super.order,
    required super.description,
    required super.middleware,
    required super.redirect,
    required super.parentNavigatorKey,
    required super.metadataSource,
    required this.params,
    required this.caseSensitive,
    required this.page,
    required this.branch,
    this.onExit,
  });

  /// The widget's constructor parameters, resolved.
  final List<ParamInfo> params;

  /// Whether path matching is case-sensitive.
  final bool caseSensitive;

  /// Page and transition configuration.
  final PageConfig page;

  /// Branch configuration, when this route is a stateful shell's child.
  final BranchConfig? branch;

  /// Name of an `onExit` callback.
  final String? onExit;

  /// Path parameters, in constructor order.
  Iterable<ParamInfo> get pathParams =>
      params.where((p) => p.source == ParamSource.path);

  /// Query parameters, in constructor order.
  Iterable<ParamInfo> get queryParams =>
      params.where((p) => p.source == ParamSource.query);

  /// The `extra` parameter, if the route takes one.
  ParamInfo? get extraParam {
    for (final param in params) {
      if (param.source == ParamSource.extra) return param;
    }
    return null;
  }
}

/// A widget annotated with `@AutoGoRouteShell`.
class ShellInfo extends NodeInfo {
  /// Creates a shell description.
  const ShellInfo({
    required super.id,
    required super.className,
    required super.libraryUri,
    required super.path,
    required super.name,
    required super.parentId,
    required super.order,
    required super.description,
    required super.middleware,
    required super.redirect,
    required super.parentNavigatorKey,
    required super.metadataSource,
    required this.isStateful,
    required this.notifyRootObserver,
    required this.childParamName,
    this.navigatorKey,
    this.initialRoute,
    this.pageBuilder,
    this.observers,
    this.restorationScopeId,
    this.navigatorContainerBuilder,
    this.branch,
  });

  /// Whether the shell preserves per-branch state.
  final bool isStateful;

  /// Whether navigation inside the shell notifies root observers.
  final bool notifyRootObserver;

  /// The constructor parameter receiving the child widget or navigation shell.
  final String childParamName;

  /// Name of a `GlobalKey<NavigatorState>` for the shell navigator.
  final String? navigatorKey;

  /// Location to redirect to when the shell's own path is visited.
  final String? initialRoute;

  /// Name of a shell page-builder function.
  final String? pageBuilder;

  /// Name of a `List<NavigatorObserver>`.
  final String? observers;

  /// State-restoration scope id.
  final String? restorationScopeId;

  /// Name of a `ShellNavigationContainerBuilder`.
  final String? navigatorContainerBuilder;

  /// Branch configuration, when this shell is itself a stateful shell's child.
  final BranchConfig? branch;
}

/// The `@AutoGoRouteBase` configuration.
class RouterBaseInfo {
  /// Creates a router-base description.
  const RouterBaseInfo({
    required this.className,
    required this.navigatorExtensionName,
    required this.redirectLimit,
    required this.routerNeglect,
    required this.debugLogDiagnostics,
    required this.overridePlatformDefaultLocation,
    required this.requestFocus,
    required this.caseSensitive,
    required this.generateRouteEnum,
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
    this.restorationScopeId,
  });

  /// The annotated class's name.
  final String className;

  /// Name of the generated `BuildContext` extension.
  final String navigatorExtensionName;

  /// How many redirects to follow.
  final int redirectLimit;

  /// Whether to suppress browser history entries.
  final bool routerNeglect;

  /// Whether go_router logs routing decisions.
  final bool debugLogDiagnostics;

  /// Whether `initialLocation` overrides the platform's initial route.
  final bool overridePlatformDefaultLocation;

  /// Whether the router requests focus after navigating.
  final bool requestFocus;

  /// Default case sensitivity for generated routes.
  final bool caseSensitive;

  /// Whether to generate a route-name enum.
  final bool generateRouteEnum;

  /// Globs scoping which assets this router scans, overriding the builder
  /// option.
  final List<String>? sourceGlobs;

  /// Name of a `GlobalKey<NavigatorState>` for the root navigator.
  final String? navigatorKey;

  /// The router's initial location.
  final String? initialLocation;

  /// Name of a constant passed as the initial `extra`.
  final String? initialExtra;

  /// Name of a `GoRouterWidgetBuilder` for errors.
  final String? errorBuilder;

  /// Name of a `GoRouterPageBuilder` for errors.
  final String? errorPageBuilder;

  /// Name of a widget constructor taking a named `error` argument.
  final String? errorWidget;

  /// Name of a `GoExceptionHandler`.
  final String? onException;

  /// Name of a top-level redirect function.
  final String? redirect;

  /// Name of an `OnEnter` callback.
  final String? onEnter;

  /// Name of a `List<NavigatorObserver>`.
  final String? observers;

  /// Name of a `Listenable`.
  final String? refreshListenable;

  /// Name of a `Codec<Object?, Object?>`.
  final String? extraCodec;

  /// State-restoration scope id for the root navigator.
  final String? restorationScopeId;
}

/// A route or shell with its resolved absolute path and parameter names.
class ResolvedNode {
  /// Creates a resolved node.
  ResolvedNode({
    required this.info,
    required this.template,
    required this.parentTemplate,
    required this.pathParameterNames,
  });

  /// The underlying route or shell.
  final NodeInfo info;

  /// The absolute path pattern, with shell ancestors contributing nothing.
  final String template;

  /// The nearest URL-contributing ancestor's absolute pattern.
  final String parentTemplate;

  /// Path parameter names declared anywhere in [template].
  final List<String> pathParameterNames;

  /// Whether the node is a shell.
  bool get isShell => info is ShellInfo;
}

/// The whole route graph, resolved and ordered.
class RouteGraph {
  /// Creates a route graph.
  const RouteGraph({
    required this.routes,
    required this.shells,
    required this.byId,
    required this.childrenOf,
    required this.topLevel,
  });

  /// Every `@AutoGoRoute` node, in deterministic order.
  final List<ResolvedNode> routes;

  /// Every `@AutoGoRouteShell` node, in deterministic order.
  final List<ResolvedNode> shells;

  /// Every node by [NodeInfo.id].
  final Map<String, ResolvedNode> byId;

  /// Child ids by parent id, each list already sorted.
  final Map<String, List<String>> childrenOf;

  /// Ids of nodes with no parent, sorted.
  final List<String> topLevel;
}

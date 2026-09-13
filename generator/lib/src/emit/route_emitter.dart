import '../analysis/graph_resolver.dart';
import '../errors.dart';
import '../model/route_model.dart';
import '../utils/generator_utils.dart';

/// Emits the generated `part` file for one `@AutoGoRouteBase` class.
///
/// Output is plain Dart source: `PartBuilder` formats it with the input
/// library's own language version, so there is no formatter here to disagree
/// with the user's SDK.
class RouteEmitter {
  /// Creates an emitter over a resolved graph.
  RouteEmitter({required this.base, required this.graph, required this.nodes});

  /// The router-base configuration.
  final RouterBaseInfo base;

  /// The resolved graph shape.
  final ResolvedGraph graph;

  /// Every route and shell by id.
  final Map<String, NodeInfo> nodes;

  late final List<RouteInfo> _routes = [
    for (final id in _allIdsInOrder)
      if (nodes[id] case final RouteInfo route) route,
  ];

  late final List<ShellInfo> _shells = [
    for (final id in _allIdsInOrder)
      if (nodes[id] case final ShellInfo shell) shell,
  ];

  late final List<String> _allIdsInOrder = _flatten(graph.topLevel);

  List<String> _flatten(List<String> ids) => [
    for (final id in ids) ...[
      id,
      ..._flatten(graph.childrenOf[id] ?? const []),
    ],
  ];

  /// Renders the whole part file.
  String emit() {
    _validateTree();
    final buffer = StringBuffer();
    _emitBaseClass(buffer);
    _emitDefaults(buffer);
    for (final route in _routes) {
      _emitRouteClass(buffer, route);
    }
    for (final shell in _shells) {
      _emitShellClass(buffer, shell);
    }
    _emitSingletons(buffer);
    _emitContextExtension(buffer);
    if (base.generateRouteEnum) {
      _emitRouteEnum(buffer);
      _emitBranchEnums(buffer);
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Naming
  // ---------------------------------------------------------------------------

  String _routeClassName(NodeInfo info) => '${info.className}Route';

  String _getterName(NodeInfo info) =>
      '${GeneratorUtils.toLowerCamelCase(info.className)}Route';

  /// The private top-level instance the `BuildContext` extension uses.
  ///
  /// Prefixed distinctly so two generators emitting parts of the same library
  /// cannot collide.
  String _singletonName(NodeInfo info) =>
      '_autoGoRoute\$${GeneratorUtils.toLowerCamelCase(info.className)}';

  String _methodSuffix(NodeInfo info) =>
      GeneratorUtils.toUpperCamelCase(info.name);

  // ---------------------------------------------------------------------------
  // Base class
  // ---------------------------------------------------------------------------

  void _emitBaseClass(StringBuffer buffer) {
    buffer
      ..writeln('/// Generated router for [${base.className}].')
      ..writeln('///')
      ..writeln(
        '/// ${_routes.length} ${_routes.length == 1 ? 'route' : 'routes'} and '
        '${_shells.length} ${_shells.length == 1 ? 'shell' : 'shells'}.',
      )
      ..writeln('abstract class _\$${base.className} {');

    for (final info in [..._routes, ..._shells]) {
      final className = _routeClassName(info);
      final getter = _getterName(info);
      buffer
        ..writeln('  late final $className _$getter = $className();')
        ..writeln()
        ..writeln('  /// The [$className] definition.');
      if (info.description != null) {
        buffer.writeln('  ///');
        for (final line in info.description!.split('\n')) {
          buffer.writeln('  /// ${line.trim()}');
        }
      }
      buffer
        ..writeln('  $className get $getter => _$getter;')
        ..writeln();
    }

    buffer
      ..writeln('  /// Every generated route definition.')
      ..writeln('  List<RoutePaths> get allRoutes => [')
      ..writeln(_routes.map((r) => '    ${_getterName(r)},').join('\n'))
      ..writeln('  ];')
      ..writeln()
      ..writeln('  /// Every generated shell definition.')
      ..writeln('  List<ShellRoutePaths> get allShells => [')
      ..writeln(_shells.map((s) => '    ${_getterName(s)},').join('\n'))
      ..writeln('  ];')
      ..writeln()
      ..writeln('  /// The route tree, ready to hand to `GoRouter(routes:)`.')
      ..writeln('  ///')
      ..writeln(
        '  /// Public so the tree can be composed into a router you build '
        'yourself,',
      )
      ..writeln('  /// or merged with routes from another package.')
      ..writeln('  List<RouteBase> get routes => [');
    for (final code in _emitTopLevel()) {
      buffer.writeln('    $code,');
    }
    buffer
      ..writeln('  ];')
      ..writeln();

    _emitBuildRouter(buffer);
    buffer.writeln('}');
    buffer.writeln();
  }

  /// `GoRouter` options that configure the router itself, and so apply to
  /// both [GoRouter.new] and [GoRouter.routingConfig].
  static const _routerOptions = <(String, String)>[
    ('navigatorKey', 'GlobalKey<NavigatorState>?'),
    ('initialLocation', 'String?'),
    ('initialExtra', 'Object?'),
    ('onException', 'GoExceptionHandler?'),
    ('errorBuilder', 'GoRouterWidgetBuilder?'),
    ('errorPageBuilder', 'GoRouterPageBuilder?'),
    ('refreshListenable', 'Listenable?'),
    ('observers', 'List<NavigatorObserver>?'),
    ('extraCodec', 'Codec<Object?, Object?>?'),
    ('routerNeglect', 'bool?'),
    ('debugLogDiagnostics', 'bool?'),
    ('overridePlatformDefaultLocation', 'bool?'),
    ('requestFocus', 'bool?'),
    ('restorationScopeId', 'String?'),
  ];

  /// Options that describe the route table, and so live on [RoutingConfig]
  /// when routing is dynamic.
  static const _routingOptions = <(String, String)>[
    ('routes', 'List<RouteBase>?'),
    ('redirect', 'GoRouterRedirect?'),
    ('onEnter', 'OnEnter?'),
    ('redirectLimit', 'int?'),
  ];

  /// The argument expression for [param]: the caller's value, falling back to
  /// the annotation's.
  String _optionArgument(String param) {
    if (param == 'routes') return 'routes ?? this.routes';
    if (_defaultReferences.containsKey(param)) {
      return _defaultReferences[param] == null
          ? param
          : '$param ?? ${_defaultGetterName(param)}';
    }
    final literal = switch (param) {
      'initialLocation' =>
        base.initialLocation == null
            ? null
            : GeneratorUtils.stringLiteral(base.initialLocation!),
      'restorationScopeId' =>
        base.restorationScopeId == null
            ? null
            : GeneratorUtils.stringLiteral(base.restorationScopeId!),
      'redirectLimit' => '${base.redirectLimit}',
      'routerNeglect' => '${base.routerNeglect}',
      'debugLogDiagnostics' => '${base.debugLogDiagnostics}',
      'overridePlatformDefaultLocation' =>
        '${base.overridePlatformDefaultLocation}',
      'requestFocus' => '${base.requestFocus}',
      _ => throw StateError('Unknown router option $param'),
    };
    return literal == null ? param : '$param ?? $literal';
  }

  void _writeOptionParams(StringBuffer buffer, List<(String, String)> options) {
    for (final (name, type) in options) {
      buffer.writeln('    $type $name,');
    }
  }

  void _writeOptionArgs(StringBuffer buffer, List<(String, String)> options) {
    for (final (name, _) in options) {
      buffer.writeln('      $name: ${_optionArgument(name)},');
    }
  }

  void _emitBuildRouter(StringBuffer buffer) {
    // Every `@AutoGoRouteBase` value is a default here, overridable per call —
    // 1.x accepted only `navigatorKey`, which is why its own example
    // hand-rolled a `GoRouter` and ignored the generated one.
    buffer
      ..writeln('  /// Builds the [GoRouter] for this route tree.')
      ..writeln('  ///')
      ..writeln(
        '  /// Every argument defaults to the value on `@AutoGoRouteBase`, so '
        'pass only',
      )
      ..writeln(
        '  /// what has to be decided at runtime — a `refreshListenable`, a '
        'redirect that',
      )
      ..writeln('  /// closes over your DI container, observers.')
      ..writeln('  GoRouter buildRouter({');
    _writeOptionParams(buffer, _routingOptions);
    _writeOptionParams(buffer, _routerOptions);
    buffer
      ..writeln('  }) {')
      ..writeln('    return GoRouter(');
    _writeOptionArgs(buffer, _routingOptions);
    _writeOptionArgs(buffer, _routerOptions);
    buffer
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln(
        '  /// The route table as a [RoutingConfig], for '
        '[GoRouter.routingConfig].',
      )
      ..writeln('  ///')
      ..writeln(
        '  /// Hold it in a `ValueNotifier` and assign a new config to change '
        'the',
      )
      ..writeln(
        '  /// available routes at runtime — after sign-in, or when a feature '
        'flag flips —',
      )
      ..writeln(
        '  /// without rebuilding the router. See [buildDynamicRouter].',
      )
      ..writeln('  RoutingConfig buildRoutingConfig({');
    _writeOptionParams(buffer, _routingOptions);
    buffer
      ..writeln('  }) {')
      ..writeln('    return RoutingConfig(');
    for (final (name, _) in _routingOptions) {
      // RoutingConfig.redirect is non-nullable with a private default, so the
      // fallback chain has to end in a real function.
      final argument = name == 'redirect'
          ? '${_optionArgument(name)} ?? _autoGoRouteNoRedirect'
          : _optionArgument(name);
      buffer.writeln('      $name: $argument,');
    }
    buffer
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln(
        '  /// Builds a [GoRouter] whose routes come from [routingConfig] and '
        'can change',
      )
      ..writeln('  /// while the app runs.')
      ..writeln('  ///')
      ..writeln('  /// ```dart')
      ..writeln(
        '  /// final config = ValueNotifier(appRouter.buildRoutingConfig());',
      )
      ..writeln(
        '  /// final router = appRouter.buildDynamicRouter(routingConfig: '
        'config);',
      )
      ..writeln('  /// // later:')
      ..writeln(
        '  /// config.value = appRouter.buildRoutingConfig(routes: '
        '[...appRouter.routes, extra]);',
      )
      ..writeln('  /// ```')
      ..writeln('  ///')
      ..writeln(
        '  /// Every other argument defaults to the value on '
        '`@AutoGoRouteBase`.',
      )
      ..writeln('  GoRouter buildDynamicRouter({')
      ..writeln('    required ValueListenable<RoutingConfig> routingConfig,');
    _writeOptionParams(buffer, _routerOptions);
    buffer
      ..writeln('  }) {')
      ..writeln('    return GoRouter.routingConfig(')
      ..writeln('      routingConfig: routingConfig,');
    _writeOptionArgs(buffer, _routerOptions);
    buffer
      ..writeln('    );')
      ..writeln('  }');
  }

  /// The `buildRouter` parameters whose annotation default is a code
  /// reference, with that reference's source — `null` when not set.
  ///
  /// Kept in parameter order so the emitted call reads top to bottom.
  late final Map<String, String?> _defaultReferences = {
    'navigatorKey': base.navigatorKey,
    'initialExtra': base.initialExtra,
    'redirect': base.redirect,
    'onEnter': base.onEnter,
    'onException': base.onException,
    'refreshListenable': base.refreshListenable,
    'observers': base.observers,
    'extraCodec': base.extraCodec,
    'errorBuilder':
        base.errorBuilder ??
        (base.errorWidget == null
            ? null
            : '(context, state) => ${base.errorWidget}(error: state.error)'),
    'errorPageBuilder': base.errorPageBuilder,
  };

  static const _defaultTypes = <String, String>{
    'navigatorKey': 'GlobalKey<NavigatorState>?',
    'initialExtra': 'Object?',
    'redirect': 'GoRouterRedirect?',
    'onEnter': 'OnEnter?',
    'onException': 'GoExceptionHandler?',
    'refreshListenable': 'Listenable?',
    'observers': 'List<NavigatorObserver>?',
    'extraCodec': 'Codec<Object?, Object?>?',
    'errorBuilder': 'GoRouterWidgetBuilder?',
    'errorPageBuilder': 'GoRouterPageBuilder?',
  };

  String _defaultGetterName(String param) => '_autoGoRouteDefault\$$param';

  /// Emits one top-level getter per annotation default.
  ///
  /// The defaults cannot be spliced into `buildRouter` directly: that method's
  /// parameters share their names with the annotation fields, so
  /// `@AutoGoRouteBase(onEnter: 'onEnter')` emitted `onEnter: onEnter ??
  /// onEnter` — the parameter both times, and the annotation value silently
  /// lost. A top-level getter is outside that scope. It is a getter rather
  /// than a final so a reference to a mutable top-level is read each time a
  /// router is built, exactly as an inline reference would be.
  void _emitDefaults(StringBuffer buffer) {
    buffer
      ..writeln(
        '/// A redirect that allows every navigation, for `RoutingConfig`, '
        'whose',
      )
      ..writeln('/// `redirect` cannot be null.')
      ..writeln(
        'String? _autoGoRouteNoRedirect(BuildContext context, GoRouterState '
        'state) =>',
      )
      ..writeln('    null;')
      ..writeln();
    final set = _defaultReferences.entries.where((e) => e.value != null);
    if (set.isEmpty) return;
    buffer.writeln(
      '// `@AutoGoRouteBase` defaults, read outside `buildRouter` so its '
      'parameters',
    );
    buffer.writeln('// cannot shadow a reference that shares their name.');
    for (final entry in set) {
      buffer.writeln(
        '${_defaultTypes[entry.key]} get ${_defaultGetterName(entry.key)} => '
        '${entry.value};',
      );
    }
    buffer.writeln();
  }

  // ---------------------------------------------------------------------------
  // Route tree
  // ---------------------------------------------------------------------------

  /// Templates occupied by a real route, which a generated redirect must never
  /// shadow.
  late final Set<String> _routeTemplates = {
    for (final route in _routes) graph.templates[route.id]!,
  };

  List<String> _emitTopLevel() {
    final redirects = <String>[];
    final out = <String>[];
    final handledByWrapper = <String>{};

    for (final id in graph.topLevel) {
      final info = nodes[id]!;
      if (info is ShellInfo &&
          info.path == '/' &&
          !_routeTemplates.contains('/')) {
        final initial = info.initialRoute ?? _landingLocation(id);
        if (initial != null && initial != '/') {
          // A shell contributes no URL segment, so nothing matches the shell's
          // own "/" — wrap it in a redirect-only parent. Safe for "/"
          // specifically: go_router joins child paths onto their parent, and
          // joining onto "/" is a no-op, so the children keep the exact
          // templates this generator resolved for them. Skipped when a real
          // route lives at "/", which the wrapper would otherwise shadow.
          handledByWrapper.add(id);
          out.add(
            'GoRoute(\n'
            "  path: '/',\n"
            '  redirect: (context, state) =>\n'
            "      state.uri.path == '/' ? ${GeneratorUtils.stringLiteral(initial)} : null,\n"
            '  routes: [${_emitNode(id)}],\n'
            ')',
          );
          continue;
        }
      }
      out.add(_emitNode(id));
    }

    // Every other shell redirects from its own path to its `initialRoute` —
    // or, when it declares none, to its first reachable child. A shell's path
    // is an alias rather than a mount point, so the redirect cannot be the
    // shell's *parent* (that would prepend the path to every child's URL).
    //
    // The redirects come *first*. A redirect-only route matches its path
    // exactly or not at all — a longer location prefix-matches it, finds no
    // child, and go_router moves on to the next sibling — so leading with
    // them costs nothing, while trailing them let any earlier pattern route
    // (`/:slug`) swallow the shell's path. A real route at the same template
    // always wins: no redirect is emitted for it.
    for (final shell in _shells) {
      if (handledByWrapper.contains(shell.id)) continue;
      if (shell.path.isEmpty || shell.path == '/') continue;
      if (_routeTemplates.contains(shell.path)) continue;
      final initial = shell.initialRoute ?? _landingLocation(shell.id);
      if (initial == null || initial == shell.path) continue;
      redirects.add(
        'GoRoute(\n'
        '  path: ${GeneratorUtils.stringLiteral(shell.path)},\n'
        '  redirect: (context, state) => ${GeneratorUtils.stringLiteral(initial)},\n'
        ')',
      );
    }

    return [...redirects, ...out];
  }

  /// The first concrete, parameter-free location reachable at [id].
  ///
  /// A shell contributes no URL segment, so a branch rooted at a shell has to
  /// land on one of the shell's descendants — using the shell's own (empty)
  /// template would send the branch outside itself.
  String? _landingLocation(String id) {
    final info = nodes[id];
    if (info == null) return null;

    if (info is ShellInfo) {
      final explicit = info.initialRoute;
      if (explicit != null) return explicit;
      for (final childId in graph.childrenOf[id] ?? const <String>[]) {
        final landing = _landingLocation(childId);
        if (landing != null) return landing;
      }
      return null;
    }

    final template = graph.templates[id];
    if (template == null) return null;
    // A parameterised location cannot be navigated to without values.
    return GeneratorUtils.pathParameterNames(template).isEmpty
        ? template
        : null;
  }

  /// Every parameter-free template reachable inside [id]'s subtree.
  Set<String> _reachableTemplates(String id) {
    final found = <String>{};
    final info = nodes[id];
    if (info is RouteInfo) {
      final template = graph.templates[id]!;
      if (GeneratorUtils.pathParameterNames(template).isEmpty) {
        found.add(template);
      }
    }
    for (final childId in graph.childrenOf[id] ?? const <String>[]) {
      found.addAll(_reachableTemplates(childId));
    }
    return found;
  }

  /// Rejects shapes go_router would refuse, before any source is written.
  ///
  /// Each of these used to reach go_router as an assertion at router
  /// construction — or, for an empty shell, as `routes: [,]`, which is not
  /// parseable Dart at all.
  void _validateTree() {
    for (final shell in _shells) {
      final children = graph.childrenOf[shell.id] ?? const <String>[];
      if (children.isEmpty) {
        throw routeError(
          '${shell.className} is a shell with no child routes. go_router '
          'requires a ${shell.isStateful ? 'stateful shell to have at least '
                    'one branch' : 'shell to wrap at least one route'}.',
          todo:
              'Give a route `parent: ${shell.className}`, or remove the '
              'annotation.',
        );
      }
      if (!shell.isStateful) continue;

      for (final childId in children) {
        final child = nodes[childId]!;
        final branch = child is RouteInfo
            ? child.branch
            : (child as ShellInfo).branch;
        if (branch?.initialLocation != null) continue;

        final landing = _landingLocation(childId);
        if (landing == null) {
          throw routeError(
            'The branch of ${shell.className} rooted at ${child.className} '
            'has no parameter-free route to start at, so go_router cannot '
            'derive its initial location and asserts when the router is '
            'built.',
            todo:
                'Add `@AutoGoRouteBranch(initialLocation: \'/some/concrete/'
                'path\')` to ${child.className}.',
          );
        }
        final reachable = _reachableTemplates(childId);
        if (!reachable.contains(landing)) {
          throw routeError(
            '${child.className} starts its branch of ${shell.className} at '
            '"$landing", which is not a route inside that branch. go_router '
            'would open the branch somewhere else entirely.',
            todo:
                'Point `initialRoute` at one of '
                '${reachable.map((t) => '"$t"').join(', ')}, or set '
                '`@AutoGoRouteBranch(initialLocation:)` explicitly.',
          );
        }
      }
    }
  }

  String _emitNode(String id) {
    final info = nodes[id]!;
    final children = graph.childrenOf[id] ?? const [];
    final instance = _getterName(info);

    if (info is ShellInfo) {
      if (info.isStateful) {
        final branches = children.map(_emitBranch).join(',\n');
        return '$instance.toStatefulShellRoute(branches: [\n$branches,\n])';
      }
      final childCode = children.map(_emitNode).join(',\n');
      return '$instance.toShellRoute(routes: [\n$childCode,\n])';
    }

    final childCode = children.map(_emitNode).join(',\n');
    return children.isEmpty
        ? '$instance.toGoRoute()'
        : '$instance.toGoRoute(routes: [\n$childCode,\n])';
  }

  String _emitBranch(String id) {
    final info = nodes[id]!;
    final branch = info is RouteInfo ? info.branch : (info as ShellInfo).branch;
    final buffer = StringBuffer('StatefulShellBranch(\n')
      ..writeln('  routes: [${_emitNode(id)}],');

    // go_router derives a branch's default location from its first route and
    // asserts when that route takes path parameters, so the initial location
    // is always emitted. `_validateTree` has already guaranteed one exists.
    final initial = branch?.initialLocation ?? _landingLocation(id)!;
    buffer.writeln(
      '  initialLocation: ${GeneratorUtils.stringLiteral(initial)},',
    );
    if (branch != null) {
      if (branch.navigatorKey != null) {
        buffer.writeln('  navigatorKey: ${branch.navigatorKey},');
      }
      if (branch.restorationScopeId != null) {
        buffer.writeln(
          '  restorationScopeId: '
          '${GeneratorUtils.stringLiteral(branch.restorationScopeId!)},',
        );
      }
      if (branch.observers != null) {
        buffer.writeln('  observers: ${branch.observers},');
      }
      if (branch.preload) buffer.writeln('  preload: true,');
    }
    buffer.write(')');
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Route classes
  // ---------------------------------------------------------------------------

  void _emitRouteClass(StringBuffer buffer, RouteInfo route) {
    final className = _routeClassName(route);
    final template = graph.templates[route.id]!;
    final parentTemplate = graph.parentTemplates[route.id]!;
    final isNested = route.parentId != null;

    buffer
      ..writeln('/// Route for [${route.className}].')
      ..writeln('///')
      ..writeln('/// Path: `$template`');
    if (route.description != null) {
      buffer.writeln('///');
      for (final line in route.description!.split('\n')) {
        buffer.writeln('/// ${line.trim()}');
      }
    }
    buffer
      ..writeln(
        'class $className extends ${isNested ? 'NestedRoutePaths' : 'RoutePaths'} {',
      )
      ..writeln('  /// Creates the route definition.')
      ..writeln('  $className()')
      ..writeln('    : super(');
    if (isNested) {
      buffer.writeln(
        '        parentTemplate: ${GeneratorUtils.stringLiteral(parentTemplate)},',
      );
    }
    buffer
      ..writeln('        path: ${GeneratorUtils.stringLiteral(route.path)},')
      ..writeln('        name: ${GeneratorUtils.stringLiteral(route.name)},');
    if (route.description != null) {
      buffer.writeln(
        '        description: ${GeneratorUtils.stringLiteral(route.description!)},',
      );
    }
    if (route.middleware.isNotEmpty) {
      buffer.writeln(
        '        middleware: const [${route.middleware.join(', ')}],',
      );
    }
    if (route.redirect != null) {
      buffer.writeln('        redirect: ${route.redirect},');
    }
    if (route.onExit != null) {
      buffer.writeln('        onExit: ${route.onExit},');
    }
    if (route.parentNavigatorKey != null) {
      buffer.writeln(
        '        parentNavigatorKey: ${route.parentNavigatorKey},',
      );
    }
    if (!route.caseSensitive) {
      buffer.writeln('        caseSensitive: false,');
    }
    if (route.metadataSource != null) {
      buffer.writeln('        metadata: const ${route.metadataSource},');
    }
    if (route.page.needsPage) {
      buffer.writeln('        pageBuilder: ${_emitPageBuilder(route)},');
    } else {
      buffer.writeln('        builder: ${_emitWidgetBuilder(route)},');
    }
    buffer
      ..writeln('      );')
      ..writeln()
      ..writeln("  /// This route's name, `${route.name}`.")
      ..writeln(
        '  static const String routeName = ${GeneratorUtils.stringLiteral(route.name)};',
      )
      ..writeln()
      ..writeln("  /// This route's absolute path pattern, `$template`.")
      ..writeln(
        '  static const String routeTemplate = ${GeneratorUtils.stringLiteral(template)};',
      )
      ..writeln();

    _emitPathWith(buffer, route);
    buffer
      ..writeln('}')
      ..writeln();
  }

  String _emitWidgetBuilder(RouteInfo route) =>
      '(context, state) => ${route.className}(${_emitConstructorArgs(route)})';

  String _emitPageBuilder(RouteInfo route) {
    final page = route.page;
    if (page.pageBuilder != null) return page.pageBuilder!;
    final args = StringBuffer()
      ..write('context: context, ')
      ..write('state: state, ')
      ..write('child: ${route.className}(${_emitConstructorArgs(route)}), ')
      ..write('transition: AutoRouteTransition.${page.transition}, ');
    if (page.transitionDurationMs != null) {
      args.write(
        'transitionDuration: const Duration(milliseconds: '
        '${page.transitionDurationMs}), ',
      );
    }
    if (page.reverseTransitionDurationMs != null) {
      args.write(
        'reverseTransitionDuration: const Duration(milliseconds: '
        '${page.reverseTransitionDurationMs}), ',
      );
    }
    if (page.fullscreenDialog) args.write('fullscreenDialog: true, ');
    if (!page.opaque) args.write('opaque: false, ');
    if (page.barrierDismissible) args.write('barrierDismissible: true, ');
    if (page.barrierColor != null) {
      args.write('barrierColor: ${page.barrierColor}, ');
    }
    if (page.restorationId != null) {
      args.write(
        'restorationId: ${GeneratorUtils.stringLiteral(page.restorationId!)}, ',
      );
    }
    return '(context, state) => buildAutoRoutePage(${args.toString().trimRight()})';
  }

  String _emitConstructorArgs(RouteInfo route) {
    final positional = <String>[];
    final named = <String>[];
    for (final param in route.params) {
      final read = _emitRead(route, param);
      if (param.isNamed) {
        named.add('${param.dartName}: $read');
      } else {
        positional.add(read);
      }
    }
    return [...positional, ...named].join(', ');
  }

  /// The expression that reads [param] out of `state`.
  String _emitRead(RouteInfo route, ParamInfo param) {
    if (param.source == ParamSource.extra) {
      final type = param.nonNullableTypeSource;
      return param.isNullable
          ? 'RouteCodec.optionalExtra<$type>(state)'
          : 'RouteCodec.requireExtra<$type>(state, '
                '${GeneratorUtils.stringLiteral(route.name)})';
    }

    final name = GeneratorUtils.stringLiteral(param.wireName);

    if (param.kind == ParamKind.list) {
      final reader = switch (param.elementKind) {
        ParamKind.int => 'RouteCodec.intList(state, $name)',
        ParamKind.double => 'RouteCodec.doubleList(state, $name)',
        ParamKind.num => 'RouteCodec.numList(state, $name)',
        ParamKind.bool => 'RouteCodec.boolList(state, $name)',
        ParamKind.bigInt => 'RouteCodec.bigIntList(state, $name)',
        ParamKind.dateTime => 'RouteCodec.dateTimeList(state, $name)',
        ParamKind.uri => 'RouteCodec.uriList(state, $name)',
        ParamKind.enumeration =>
          'RouteCodec.enumList(state, $name, ${param.enumTypeSource}.values)',
        _ => 'RouteCodec.stringList(state, $name)',
      };
      // `*List` yields an empty list for an absent key; a nullable list
      // parameter should see `null` there so the widget can tell "no filter"
      // from "empty filter".
      return param.isNullable
          ? '(RouteCodec.rawAll(state, $name).isEmpty ? null : $reader)'
          : reader;
    }

    // A path parameter is present whenever the route matched, so it reads as
    // required unless the widget declared it nullable.
    final optional =
        param.isNullable ||
        (param.source == ParamSource.query && param.hasDefault);
    final prefix = optional ? 'optional' : 'require';

    final read = switch (param.kind) {
      ParamKind.string => 'RouteCodec.${prefix}String(state, $name)',
      ParamKind.int => 'RouteCodec.${prefix}Int(state, $name)',
      ParamKind.double => 'RouteCodec.${prefix}Double(state, $name)',
      ParamKind.num => 'RouteCodec.${prefix}Num(state, $name)',
      ParamKind.bool => 'RouteCodec.${prefix}Bool(state, $name)',
      ParamKind.bigInt => 'RouteCodec.${prefix}BigInt(state, $name)',
      ParamKind.dateTime => 'RouteCodec.${prefix}DateTime(state, $name)',
      ParamKind.uri => 'RouteCodec.${prefix}Uri(state, $name)',
      ParamKind.enumeration =>
        'RouteCodec.${prefix}Enum(state, $name, ${param.enumTypeSource}.values)',
      ParamKind.list ||
      ParamKind.opaque => 'RouteCodec.${prefix}String(state, $name)',
    };

    if (optional && !param.isNullable) {
      // Non-nullable with a constructor default: fall back to that default so
      // the widget's own declaration stays the single source of truth.
      return '$read ?? ${param.defaultValueCode}';
    }
    return read;
  }

  void _emitPathWith(StringBuffer buffer, RouteInfo route) {
    final template = graph.templates[route.id]!;
    buffer
      ..writeln('  /// Builds this route\'s location, `$template`.')
      ..writeln('  ///')
      ..writeln(
        '  /// Extra entries in [queries] are merged in alongside the '
        'route\'s own',
      )
      ..writeln('  /// query parameters.')
      ..writeln('  String pathWith({');
    _writeParamSignature(buffer, route, indent: '    ');
    buffer
      ..writeln('  }) {')
      ..writeln('    return this.location(');

    final pathParams = route.pathParams.toList();
    if (pathParams.isEmpty) {
      buffer.writeln('      params: const {},');
    } else {
      buffer.writeln('      params: {');
      for (final param in pathParams) {
        buffer.writeln(
          '        ${GeneratorUtils.stringLiteral(param.wireName)}: '
          '${_emitEncode(param)},',
        );
      }
      buffer.writeln('      },');
    }

    final queryParams = route.queryParams.toList();
    if (queryParams.isEmpty) {
      buffer.writeln('      queries: queries,');
    } else {
      buffer.writeln('      queries: {');
      for (final param in queryParams) {
        final key = GeneratorUtils.stringLiteral(param.wireName);
        if (param.kind == ParamKind.list) {
          buffer.writeln(
            '        if (${param.dartName} != null) $key: '
            'RouteCodec.encodeAll(${param.dartName}),',
          );
        } else {
          // Query parameters are always nullable in the generated signature
          // (they are optional in a URL), so the entry is guarded even when
          // the widget declares the field non-nullable with a default.
          buffer.writeln(
            '        if (${param.dartName} != null) $key: '
            'RouteCodec.encode(${param.dartName}),',
          );
        }
      }
      buffer
        ..writeln('        ...?queries,')
        ..writeln('      },');
    }

    buffer
      ..writeln('      fragment: fragment,')
      ..writeln('    );')
      ..writeln('  }');
  }

  String _emitEncode(ParamInfo param) => 'RouteCodec.encode(${param.dartName})';

  /// Writes the typed named-parameter list a route's helpers share.
  void _writeParamSignature(
    StringBuffer buffer,
    RouteInfo route, {
    required String indent,
    bool includeExtra = false,
  }) {
    // A path parameter always has a value in a URL, so the helper requires it
    // even when the widget declares the field nullable.
    for (final param in route.pathParams) {
      buffer.writeln(
        '${indent}required ${param.nonNullableTypeSource} ${param.dartName},',
      );
    }
    for (final param in route.queryParams) {
      final nullableType = param.isNullable
          ? param.typeSource
          : '${param.typeSource}?';
      buffer.writeln('$indent$nullableType ${param.dartName},');
    }
    buffer
      ..writeln('${indent}Map<String, dynamic>? queries,')
      ..writeln('${indent}String? fragment,');
    if (includeExtra) {
      final extra = route.extraParam;
      final type = extra == null
          ? 'Object?'
          : (extra.isNullable
                ? extra.typeSource
                : '${extra.nonNullableTypeSource}?');
      buffer.writeln('$indent$type extra,');
    }
  }

  /// The argument list forwarding a helper's parameters into `pathWith`.
  String _forwardArgs(RouteInfo route) {
    final args = <String>[
      for (final param in route.pathParams)
        '${param.dartName}: ${param.dartName}',
      for (final param in route.queryParams)
        '${param.dartName}: ${param.dartName}',
      'queries: queries',
      'fragment: fragment',
    ];
    return args.join(', ');
  }

  // ---------------------------------------------------------------------------
  // Shell classes
  // ---------------------------------------------------------------------------

  void _emitShellClass(StringBuffer buffer, ShellInfo shell) {
    final className = _routeClassName(shell);
    buffer.writeln('/// Shell route for [${shell.className}].');
    if (shell.description != null) {
      buffer.writeln('///');
      for (final line in shell.description!.split('\n')) {
        buffer.writeln('/// ${line.trim()}');
      }
    }
    buffer
      ..writeln('class $className extends ShellRoutePaths {')
      ..writeln('  /// Creates the shell definition.')
      ..writeln('  $className()')
      ..writeln('    : super(')
      ..writeln('        path: ${GeneratorUtils.stringLiteral(shell.path)},')
      ..writeln('        name: ${GeneratorUtils.stringLiteral(shell.name)},');
    if (shell.description != null) {
      buffer.writeln(
        '        description: ${GeneratorUtils.stringLiteral(shell.description!)},',
      );
    }
    buffer.writeln('        isStateful: ${shell.isStateful},');

    final childArg = '${shell.childParamName}: child';
    if (shell.isStateful) {
      if (shell.pageBuilder != null) {
        buffer.writeln('        statefulPageBuilder: ${shell.pageBuilder},');
      } else {
        buffer.writeln(
          '        statefulBuilder: (context, state, child) => '
          '${shell.className}($childArg),',
        );
      }
    } else {
      if (shell.pageBuilder != null) {
        buffer.writeln('        pageBuilder: ${shell.pageBuilder},');
      } else {
        buffer.writeln(
          '        builder: (context, state, child) => '
          '${shell.className}($childArg),',
        );
      }
    }

    if (shell.navigatorKey != null) {
      buffer.writeln('        navigatorKey: ${shell.navigatorKey},');
    }
    if (shell.middleware.isNotEmpty) {
      buffer.writeln(
        '        middleware: const [${shell.middleware.join(', ')}],',
      );
    }
    if (shell.redirect != null) {
      buffer.writeln('        redirect: ${shell.redirect},');
    }
    if (shell.parentNavigatorKey != null) {
      buffer.writeln(
        '        parentNavigatorKey: ${shell.parentNavigatorKey},',
      );
    }
    if (shell.metadataSource != null) {
      buffer.writeln('        metadata: const ${shell.metadataSource},');
    }
    if (shell.observers != null) {
      buffer.writeln('        observers: ${shell.observers},');
    }
    if (shell.restorationScopeId != null) {
      buffer.writeln(
        '        restorationScopeId: '
        '${GeneratorUtils.stringLiteral(shell.restorationScopeId!)},',
      );
    }
    if (!shell.notifyRootObserver) {
      buffer.writeln('        notifyRootObserver: false,');
    }
    if (shell.navigatorContainerBuilder != null) {
      buffer.writeln(
        '        navigatorContainerBuilder: ${shell.navigatorContainerBuilder},',
      );
    }
    if (shell.initialRoute != null) {
      buffer.writeln(
        '        initialRoute: ${GeneratorUtils.stringLiteral(shell.initialRoute!)},',
      );
    }
    buffer
      ..writeln('      );')
      ..writeln()
      ..writeln("  /// This shell's name, `${shell.name}`.")
      ..writeln(
        '  static const String routeName = ${GeneratorUtils.stringLiteral(shell.name)};',
      )
      ..writeln('}')
      ..writeln();
  }

  // ---------------------------------------------------------------------------
  // Singletons + BuildContext extension
  // ---------------------------------------------------------------------------

  void _emitSingletons(StringBuffer buffer) {
    if (_routes.isEmpty) return;
    buffer.writeln(
      '// Route definitions are immutable value objects, so the navigation '
      'extension',
    );
    buffer.writeln(
      '// shares one instance of each instead of rebuilding them.',
    );
    for (final route in _routes) {
      buffer.writeln(
        'final ${_routeClassName(route)} ${_singletonName(route)} = '
        '${_routeClassName(route)}();',
      );
    }
    buffer.writeln();
  }

  void _emitContextExtension(StringBuffer buffer) {
    buffer
      ..writeln('/// Typed navigation helpers for every generated route.')
      ..writeln('///')
      ..writeln(
        '/// Each route contributes `locationOf…`, `goTo…`, `pushTo…`, '
        '`replaceWith…`',
      )
      ..writeln('/// and `replaceInPlaceWith…`.')
      ..writeln('extension ${base.navigatorExtensionName} on BuildContext {');

    for (final route in _routes) {
      final suffix = _methodSuffix(route);
      final instance = _singletonName(route);
      final template = graph.templates[route.id]!;
      final forward = _forwardArgs(route);

      void signature(String indent, {bool withExtra = true}) {
        _writeParamSignature(
          buffer,
          route,
          indent: indent,
          includeExtra: withExtra,
        );
      }

      buffer
        ..writeln('  /// The location of [${route.className}], `$template`.')
        ..writeln('  ///')
        ..writeln('  /// Builds the URL without navigating.')
        ..writeln('  String locationOf$suffix({');
      signature('    ', withExtra: false);
      buffer
        ..writeln('  }) => $instance.pathWith($forward);')
        ..writeln()
        ..writeln('  /// Navigates to [${route.className}], `$template`.')
        ..writeln('  void goTo$suffix({');
      signature('    ');
      buffer
        ..writeln(
          '  }) => this.go($instance.pathWith($forward), extra: extra);',
        )
        ..writeln()
        ..writeln('  /// Pushes [${route.className}], `$template`.')
        ..writeln('  Future<T?> pushTo$suffix<T extends Object?>({');
      signature('    ');
      buffer
        ..writeln(
          '  }) => this.push<T>($instance.pathWith($forward), extra: extra);',
        )
        ..writeln()
        ..writeln(
          '  /// Replaces the current route with [${route.className}], '
          'keeping a history entry.',
        )
        ..writeln('  void replaceWith$suffix({');
      signature('    ');
      buffer
        ..writeln(
          '  }) => this.pushReplacement($instance.pathWith($forward), extra: extra);',
        )
        ..writeln()
        ..writeln(
          '  /// Replaces the current route with [${route.className}] in '
          'place, adding no',
        )
        ..writeln('  /// history entry.')
        ..writeln('  void replaceInPlaceWith$suffix({');
      signature('    ');
      buffer
        ..writeln(
          '  }) => this.replace($instance.pathWith($forward), extra: extra);',
        )
        ..writeln();
    }

    buffer
      ..writeln('}')
      ..writeln();
  }

  /// The generated branch enum's name for a stateful [shell].
  static String branchEnumName(ShellInfo shell) => '${shell.className}Branch';

  /// Emits one enum per stateful shell, naming its branches in tab order.
  ///
  /// `navigationShell.goBranch(1)` is the classic bottom-navigation bug: the
  /// index silently points at a different tab as soon as someone reorders the
  /// `order:` values. The enum is generated from the same ordering the branches
  /// are emitted in, so the two cannot drift.
  void _emitBranchEnums(StringBuffer buffer) {
    for (final shell in _shells.where((shell) => shell.isStateful)) {
      final children = graph.childrenOf[shell.id] ?? const <String>[];
      if (children.isEmpty) continue;
      final enumName = branchEnumName(shell);
      buffer
        ..writeln('/// The branches of [${shell.className}], in tab order.')
        ..writeln('///')
        ..writeln(
          '/// Each value\'s [index] is the branch index go_router uses, so '
          '[go] and',
        )
        ..writeln('/// [of] stay correct when `order:` changes.')
        ..writeln('enum $enumName {');
      for (final childId in children) {
        final child = nodes[childId]!;
        final branch = child is RouteInfo
            ? child.branch
            : (child as ShellInfo).branch;
        final initial = branch?.initialLocation ?? _landingLocation(childId)!;
        buffer
          ..writeln('  /// The branch rooted at [${child.className}].')
          ..writeln(
            '  ${child.name}(${GeneratorUtils.stringLiteral(initial)}),',
          );
      }
      buffer
        ..writeln('  ;')
        ..writeln()
        ..writeln('  const $enumName(this.initialLocation);')
        ..writeln()
        ..writeln('  /// Where this branch starts.')
        ..writeln('  final String initialLocation;')
        ..writeln()
        ..writeln('  /// The branch [shell] is showing.')
        ..writeln('  static $enumName of(StatefulNavigationShell shell) =>')
        ..writeln('      values[shell.currentIndex];')
        ..writeln()
        ..writeln('  /// Whether [shell] is showing this branch.')
        ..writeln('  bool isActiveIn(StatefulNavigationShell shell) =>')
        ..writeln('      shell.currentIndex == index;')
        ..writeln()
        ..writeln('  /// Switches [shell] to this branch.')
        ..writeln('  ///')
        ..writeln(
          '  /// With [initialLocation] set, the branch also resets to where '
          'it starts —',
        )
        ..writeln('  /// the usual response to tapping the active tab again.')
        ..writeln(
          '  void go(StatefulNavigationShell shell, {bool initialLocation = '
          'false}) =>',
        )
        ..writeln(
          '      shell.goBranch(index, initialLocation: initialLocation);',
        )
        ..writeln()
        ..writeln(
          '  /// Switches the nearest enclosing stateful shell to this branch.',
        )
        ..writeln('  ///')
        ..writeln(
          '  /// For a screen *inside* the shell that has no '
          '`StatefulNavigationShell`',
        )
        ..writeln(
          '  /// of its own — a "see all" button that jumps to another tab.',
        )
        ..writeln(
          '  void goFrom(BuildContext context, {bool initialLocation = false}) =>',
        )
        ..writeln(
          '      StatefulNavigationShell.of(context).goBranch(index, '
          'initialLocation: initialLocation);',
        )
        ..writeln('}')
        ..writeln();
    }
  }

  void _emitRouteEnum(StringBuffer buffer) {
    if (_routes.isEmpty) return;
    final enumName = _enumName();
    buffer
      ..writeln('/// Every route in [${base.className}], as an enum.')
      ..writeln('///')
      ..writeln(
        '/// Useful for exhaustive switches, analytics keys and tests that '
        'need to',
      )
      ..writeln('/// enumerate the app\'s locations.')
      ..writeln('enum $enumName {');
    for (final route in _routes) {
      final template = graph.templates[route.id]!;
      buffer
        ..writeln('  /// [${route.className}] at `$template`.')
        ..writeln(
          '  ${route.name}(${GeneratorUtils.stringLiteral(route.name)}, '
          '${GeneratorUtils.stringLiteral(template)}),',
        );
    }
    buffer
      ..writeln('  ;')
      ..writeln()
      ..writeln('  const $enumName(this.routeName, this.template);')
      ..writeln()
      ..writeln("  /// The route's name, as registered with go_router.")
      ..writeln('  final String routeName;')
      ..writeln()
      ..writeln("  /// The route's absolute path pattern.")
      ..writeln('  final String template;')
      ..writeln('}')
      ..writeln();
  }

  String _enumName() {
    var stem = base.className;
    for (final suffix in const ['Router', 'Routes', 'Route']) {
      if (stem.length > suffix.length && stem.endsWith(suffix)) {
        stem = stem.substring(0, stem.length - suffix.length);
        break;
      }
    }
    return '${stem}Route';
  }
}

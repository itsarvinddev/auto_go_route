import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

import '../model/route_model.dart';
import '../utils/generator_utils.dart';
import 'const_source.dart';
import 'param_classifier.dart';
import '../errors.dart';

/// Matches `@AutoGoRoute`, `@AutoGoRouteShell` and `@AutoGoRouteBase`.
///
/// `typeNamedLiterally` is matched on the element's own name plus its package,
/// so it keeps working when the annotation moves between files inside
/// `auto_go_route` — unlike a `fromUrl` checker pinned to
/// `package:auto_go_route/src/annotations/auto_go_route.dart`.
const routeChecker = TypeChecker.typeNamedLiterally(
  'AutoGoRoute',
  inPackage: 'auto_go_route',
);

/// Matches `@AutoGoRouteShell`.
const shellChecker = TypeChecker.typeNamedLiterally(
  'AutoGoRouteShell',
  inPackage: 'auto_go_route',
);

/// Matches `@AutoGoRouteBase`.
const baseChecker = TypeChecker.typeNamedLiterally(
  'AutoGoRouteBase',
  inPackage: 'auto_go_route',
);

/// Matches `@AutoGoRouteBranch`.
const branchChecker = TypeChecker.typeNamedLiterally(
  'AutoGoRouteBranch',
  inPackage: 'auto_go_route',
);

/// The substring every annotation this generator cares about shares.
///
/// Used to skip resolving libraries that cannot possibly declare a route. An
/// import prefix can rename the *library* (`@agr.AutoGoRoute`) but never the
/// annotation class itself, so a literal source match on the class-name stem
/// is sound — and turns "resolve every file in the package" into "resolve the
/// handful that mention routing", which is the bulk of the build cost that
/// made large projects appear to hang.
const _annotationStem = 'AutoGoRoute';

/// Discovers annotated widgets and resolves them into a [RouteGraph].
class RouteCollector {
  /// Creates a collector.
  ///
  /// [sourceGlobs] are the asset globs to scan; defaults to `lib/**/*.dart`.
  RouteCollector({List<String>? sourceGlobs})
    : _globs = (sourceGlobs == null || sourceGlobs.isEmpty)
          ? _defaultGlobs
          : sourceGlobs;

  static const _defaultGlobs = ['lib/**/*.dart'];

  final List<String> _globs;

  /// Router libraries other than the one being generated, found during the
  /// last [discover]. Each of them receives the same route table.
  final List<AssetId> otherRouterLibraries = [];

  /// Scans the package for annotated widgets.
  ///
  /// [globs] overrides the collector's configured globs — it is how
  /// `@AutoGoRouteBase(sourceGlobs:)` scopes one router in a package that has
  /// several. Without either, the scan covers `lib/`, plus the top-level
  /// directory holding the router library when that is not `lib/` — a router
  /// under `test/` otherwise came out missing the routes declared beside it.
  ///
  /// Assets are visited in sorted order so the generated file is byte-stable:
  /// `findAssets` makes no ordering promise, and unsorted discovery lets
  /// go_router's match precedence and a stateful shell's branch indices
  /// permute between builds.
  Future<List<DiscoveredNode>> discover(
    BuildStep buildStep, {
    List<String>? globs,
  }) async {
    final patterns = <String>{...(globs ?? _globs)};
    if (globs == null && identical(_globs, _defaultGlobs)) {
      final topDir = buildStep.inputId.pathSegments.first;
      if (topDir != 'lib') patterns.add('$topDir/**/*.dart');
    }

    final assets = <AssetId>{};
    for (final pattern in patterns) {
      await for (final asset in buildStep.findAssets(Glob(pattern))) {
        assets.add(asset);
      }
    }
    assets.add(buildStep.inputId);
    otherRouterLibraries.clear();

    final sorted = assets.toList()..sort((a, b) => a.path.compareTo(b.path));
    final discovered = <DiscoveredNode>[];

    for (final asset in sorted) {
      // The generator's own part output re-enters the glob as soon as it is
      // written to source. Reading it back would double-count nothing useful
      // and, once it exists, make the build depend on its own output.
      if (asset.path.endsWith('.routes.g.dart')) continue;

      final String source;
      try {
        source = await buildStep.readAsString(asset);
      } on Object {
        continue;
      }
      if (!source.contains(_annotationStem)) continue;
      if (!await buildStep.resolver.isLibrary(asset)) continue;

      // Deliberately unguarded: a library that mentions the annotations but
      // fails to resolve means the route table would silently come out
      // incomplete. 1.x funnelled this into `log.info`, below default
      // verbosity, so the build "succeeded" with routes missing.
      final library = await buildStep.resolver.libraryFor(asset);
      final reader = LibraryReader(library);

      // Checked on the resolved library, not the source text: a comment that
      // merely mentions `@AutoGoRouteBase` is not a second router.
      if (asset != buildStep.inputId &&
          reader.annotatedWith(baseChecker).isNotEmpty) {
        otherRouterLibraries.add(asset);
      }

      for (final annotated in reader.annotatedWith(routeChecker)) {
        final element = annotated.element;
        if (element is! ClassElement) {
          throw routeError(
            '@AutoGoRoute can only be applied to widget classes.',
            element: element,
          );
        }
        discovered.add(
          DiscoveredNode(element, annotated.annotation, isShell: false),
        );
      }
      for (final annotated in reader.annotatedWith(shellChecker)) {
        final element = annotated.element;
        if (element is! ClassElement) {
          throw routeError(
            '@AutoGoRouteShell can only be applied to widget classes.',
            element: element,
          );
        }
        discovered.add(
          DiscoveredNode(element, annotated.annotation, isShell: true),
        );
      }
    }

    return discovered;
  }

  /// Reads the `@AutoGoRouteBase` annotation.
  RouterBaseInfo readBase(ClassElement element, ConstantReader annotation) {
    final extensionName = annotation.read('navigatorExtensionName').stringValue;
    if (!GeneratorUtils.isDartIdentifier(extensionName)) {
      throw routeError(
        '`navigatorExtensionName` must be a valid Dart identifier, got '
        '"$extensionName".',
        element: element,
      );
    }

    // go_router asserts that at most one of `onException`,
    // `errorPageBuilder` and `errorBuilder` is supplied. Catching that here
    // turns a runtime assertion inside the generated `buildRouter()` into a
    // build error pointing at the annotation.
    final errorHandlers = [
      if (!annotation.read('errorBuilder').isNull) 'errorBuilder',
      if (!annotation.read('errorPageBuilder').isNull) 'errorPageBuilder',
      if (!annotation.read('errorWidget').isNull) 'errorWidget',
      if (!annotation.read('onException').isNull) 'onException',
    ];
    if (errorHandlers.length > 1) {
      throw routeError(
        'Supply at most one of ${errorHandlers.join(', ')} on '
        '@AutoGoRouteBase. go_router handles a routing error through exactly '
        'one of them.',
        element: element,
        todo:
            'Keep the one you want and drop the others. To choose at runtime, '
            'leave all of them off the annotation and pass one to '
            '`buildRouter()`.',
      );
    }

    final initialLocation = _optionalString(annotation, 'initialLocation');
    // Both of these assert inside `GoRouter` when there is no initial
    // location to apply them to.
    if (initialLocation == null) {
      final dependent = [
        if (!annotation.read('initialExtra').isNull) 'initialExtra',
        if (annotation.read('overridePlatformDefaultLocation').boolValue)
          'overridePlatformDefaultLocation',
      ];
      if (dependent.isNotEmpty) {
        throw routeError(
          '${dependent.join(' and ')} on @AutoGoRouteBase only apply to an '
          'initial location, and none is set. go_router asserts when the '
          'router is built.',
          element: element,
          todo:
              'Set `initialLocation:` too, or drop ${dependent.join(' and ')}.',
        );
      }
    }

    final globsField = annotation.read('sourceGlobs');
    final sourceGlobs = globsField.isNull
        ? null
        : [for (final glob in globsField.listValue) glob.toStringValue()!];
    if (sourceGlobs != null && sourceGlobs.isEmpty) {
      throw routeError(
        '`sourceGlobs` on @AutoGoRouteBase is empty, so the router would have '
        'no routes.',
        element: element,
        todo: 'List at least one glob, such as `lib/admin/**/*.dart`.',
      );
    }

    return RouterBaseInfo(
      sourceGlobs: sourceGlobs,
      className: element.displayName,
      navigatorExtensionName: extensionName,
      redirectLimit: annotation.read('redirectLimit').intValue,
      routerNeglect: annotation.read('routerNeglect').boolValue,
      debugLogDiagnostics: annotation.read('debugLogDiagnostics').boolValue,
      overridePlatformDefaultLocation: annotation
          .read('overridePlatformDefaultLocation')
          .boolValue,
      requestFocus: annotation.read('requestFocus').boolValue,
      caseSensitive: annotation.read('caseSensitive').boolValue,
      generateRouteEnum: annotation.read('generateRouteEnum').boolValue,
      navigatorKey: _optionalRef(annotation, 'navigatorKey', element),
      initialLocation: initialLocation,
      initialExtra: _optionalRef(annotation, 'initialExtra', element),
      errorBuilder: _optionalRef(annotation, 'errorBuilder', element),
      errorPageBuilder: _optionalRef(annotation, 'errorPageBuilder', element),
      errorWidget: _optionalRef(annotation, 'errorWidget', element),
      onException: _optionalRef(annotation, 'onException', element),
      redirect: _optionalRef(annotation, 'redirect', element),
      onEnter: _optionalRef(annotation, 'onEnter', element),
      observers: _optionalRef(annotation, 'observers', element),
      refreshListenable: _optionalRef(annotation, 'refreshListenable', element),
      extraCodec: _optionalRef(annotation, 'extraCodec', element),
      restorationScopeId: _optionalString(annotation, 'restorationScopeId'),
    );
  }

  /// Reads one discovered annotation into a [RouteInfo] or [ShellInfo].
  ///
  /// [pathParameterNames] must be the *resolved* names for this node, which is
  /// why extraction happens after the graph's templates are known.
  NodeInfo read(
    DiscoveredNode discovered, {
    required Set<String> pathParameterNames,
    required bool defaultCaseSensitive,
  }) => discovered.isShell
      ? _readShell(discovered)
      : _readRoute(
          discovered,
          pathParameterNames: pathParameterNames,
          defaultCaseSensitive: defaultCaseSensitive,
        );

  RouteInfo _readRoute(
    DiscoveredNode discovered, {
    required Set<String> pathParameterNames,
    required bool defaultCaseSensitive,
  }) {
    final element = discovered.element;
    final annotation = discovered.annotation;
    final path = annotation.read('path').stringValue;
    final name = _resolveName(element, annotation, path);
    final label = '${element.displayName} ($path)';

    final constructor = _requireConstructor(element, label);
    final params = ParamClassifier.classify(
      constructor: constructor,
      pathParameterNames: pathParameterNames,
      routeLabel: label,
      errorElement: element,
    );

    final pageBuilder = _optionalRef(annotation, 'pageBuilder', element);
    final transitionField = annotation.read('transition');
    final transition = transitionField.isNull
        ? null
        : _enumName(transitionField.objectValue);
    final restorationId = _optionalString(annotation, 'restorationId');

    if (pageBuilder != null && transition != null) {
      throw routeError(
        '`$label` sets both `pageBuilder` and `transition`. A route has one '
        'page builder — `transition` generates one for you, `pageBuilder` '
        'supplies your own.',
        element: element,
      );
    }

    return RouteInfo(
      id: _idOf(element),
      className: element.displayName,
      libraryUri: _libraryUriOf(element),
      path: path,
      name: name,
      parentId: _parentId(annotation, element),
      order: _optionalInt(annotation, 'order'),
      description: _optionalString(annotation, 'description'),
      middleware: _refList(annotation, 'middleware', element),
      redirect: _optionalRef(annotation, 'redirect', element),
      parentNavigatorKey: _optionalRef(
        annotation,
        'parentNavigatorKey',
        element,
      ),
      metadataSource: _metadataSource(annotation, element, label),
      params: params,
      // A route's own value wins; the router-wide flag is only a default. 1.x
      // of this generator ANDed them, so `caseSensitive: true` on a route was
      // silently discarded under `@AutoGoRouteBase(caseSensitive: false)`.
      caseSensitive:
          _optionalBool(annotation, 'caseSensitive') ?? defaultCaseSensitive,
      onExit: _optionalRef(annotation, 'onExit', element),
      page: PageConfig(
        pageBuilder: pageBuilder,
        // Restoration only works through a Page, so asking for a restoration
        // id implicitly asks for one.
        transition:
            transition ??
            (restorationId != null && pageBuilder == null ? 'platform' : null),
        transitionDurationMs: _optionalInt(annotation, 'transitionDurationMs'),
        reverseTransitionDurationMs: _optionalInt(
          annotation,
          'reverseTransitionDurationMs',
        ),
        fullscreenDialog: annotation.read('fullscreenDialog').boolValue,
        opaque: annotation.read('opaque').boolValue,
        barrierDismissible: annotation.read('barrierDismissible').boolValue,
        barrierColor: _optionalRef(annotation, 'barrierColor', element),
        restorationId: restorationId,
      ),
      branch: _readBranch(element),
    );
  }

  ShellInfo _readShell(DiscoveredNode discovered) {
    final element = discovered.element;
    final annotation = discovered.annotation;
    final path = annotation.read('path').stringValue;
    final isStateful = annotation.read('isStateful').boolValue;
    final name = _resolveName(element, annotation, path);
    final label = '${element.displayName} ($path)';
    final constructor = _requireConstructor(element, label);

    final childParam = _findShellChildParam(
      constructor,
      isStateful: isStateful,
      label: label,
      element: element,
    );

    // Every remaining parameter has to be satisfiable, so run the same
    // classification a route gets. A shell contributes no path segment, so it
    // has no path parameters of its own.
    final extras = ParamClassifier.classify(
      constructor: constructor,
      pathParameterNames: const {},
      routeLabel: label,
      errorElement: element,
      shellChildParamName: childParam,
    );
    if (extras.isNotEmpty) {
      throw routeError(
        '`$label` is a shell, so the generator can only supply its '
        '`$childParam` argument. Unsupported extra '
        '${extras.length == 1 ? 'parameter' : 'parameters'}: '
        '${extras.map((p) => p.dartName).join(', ')}.',
        element: element,
        todo:
            'Give the extra parameters defaults, make them nullable and mark '
            'them @RouteIgnore, or read the values inside the widget.',
      );
    }

    final navigatorContainerBuilder = _optionalRef(
      annotation,
      'navigatorContainerBuilder',
      element,
    );
    if (isStateful) {
      final unsupported = [
        if (!annotation.read('navigatorKey').isNull) 'navigatorKey',
        if (!annotation.read('observers').isNull) 'observers',
      ];
      if (unsupported.isNotEmpty) {
        throw routeError(
          '`$label` is a stateful shell, and `StatefulShellRoute` has no '
          '${unsupported.join(' or ')}: each branch owns its own navigator. The '
          'value would be silently ignored.',
          element: element,
          todo:
              'Move ${unsupported.join(' and ')} to `@AutoGoRouteBranch(...)` on '
              'the child route that roots each branch.',
        );
      }
    }
    if (navigatorContainerBuilder != null && !isStateful) {
      throw routeError(
        '`$label` sets `navigatorContainerBuilder`, which lays out a stateful '
        "shell's branch navigators. Set `isStateful: true`, or remove it.",
        element: element,
      );
    }

    return ShellInfo(
      id: _idOf(element),
      className: element.displayName,
      libraryUri: _libraryUriOf(element),
      path: path,
      name: name,
      parentId: _parentId(annotation, element),
      order: _optionalInt(annotation, 'order'),
      description: _optionalString(annotation, 'description'),
      middleware: _refList(annotation, 'middleware', element),
      redirect: _optionalRef(annotation, 'redirect', element),
      parentNavigatorKey: _optionalRef(
        annotation,
        'parentNavigatorKey',
        element,
      ),
      metadataSource: _metadataSource(annotation, element, label),
      isStateful: isStateful,
      notifyRootObserver: annotation.read('notifyRootObserver').boolValue,
      childParamName: childParam,
      navigatorKey: _optionalRef(annotation, 'navigatorKey', element),
      initialRoute: _optionalString(annotation, 'initialRoute'),
      pageBuilder: _optionalRef(annotation, 'pageBuilder', element),
      observers: _optionalRef(annotation, 'observers', element),
      restorationScopeId: _optionalString(annotation, 'restorationScopeId'),
      navigatorContainerBuilder: navigatorContainerBuilder,
      branch: _readBranch(element),
    );
  }

  BranchConfig? _readBranch(ClassElement element) {
    final annotation = branchChecker.firstAnnotationOfExact(element);
    if (annotation == null) return null;
    final reader = ConstantReader(annotation);
    return BranchConfig(
      navigatorKey: _optionalRef(reader, 'navigatorKey', element),
      initialLocation: _optionalString(reader, 'initialLocation'),
      restorationScopeId: _optionalString(reader, 'restorationScopeId'),
      observers: _optionalRef(reader, 'observers', element),
      preload: reader.read('preload').boolValue,
    );
  }

  String _findShellChildParam(
    ConstructorElement constructor, {
    required bool isStateful,
    required String label,
    required ClassElement element,
  }) {
    final wanted = isStateful ? 'StatefulNavigationShell' : 'Widget';
    for (final param in constructor.formalParameters) {
      if (param.displayName == 'key') continue;
      final typeName = param.type.getDisplayString();
      if (typeName == wanted) return param.displayName;
    }
    throw routeError(
      '`$label` is ${isStateful ? 'a stateful shell' : 'a shell'}, so its '
      'constructor needs a `$wanted` parameter to receive '
      '${isStateful ? 'the navigation shell' : 'the child navigator'}.',
      element: element,
      todo: isStateful
          ? 'Add `required StatefulNavigationShell navigationShell` to the '
                'constructor, or set `isStateful: false`.'
          : 'Add `required Widget child` to the constructor, or set '
                '`isStateful: true` and take a StatefulNavigationShell.',
    );
  }

  ConstructorElement _requireConstructor(ClassElement element, String label) {
    final constructor = element.unnamedConstructor;
    if (constructor == null) {
      throw routeError(
        '`$label` has no unnamed constructor, so the generated builder cannot '
        'construct it.',
        element: element,
        todo: 'Give the widget an unnamed (default) constructor.',
      );
    }
    return constructor;
  }

  String _resolveName(
    ClassElement element,
    ConstantReader annotation,
    String path,
  ) {
    final declared = _optionalString(annotation, 'name');
    if (declared != null) {
      if (!GeneratorUtils.isDartIdentifier(declared)) {
        throw routeError(
          'Route name "$declared" on ${element.displayName} is not a valid '
          'Dart identifier. Names become part of the generated '
          '`goTo…`/`pushTo…` method names, so a name with a space, dash or '
          'leading digit produces code that cannot be parsed.',
          element: element,
          todo: 'Use a name like "${GeneratorUtils.slugFromPath(path)}".',
        );
      }
      return declared;
    }
    final fromClass = GeneratorUtils.toLowerCamelCase(element.displayName);
    return GeneratorUtils.isDartIdentifier(fromClass)
        ? fromClass
        : GeneratorUtils.slugFromPath(path);
  }

  String? _parentId(ConstantReader annotation, ClassElement element) {
    final parent = annotation.read('parent');
    if (parent.isNull) return null;
    final type = parent.typeValue;
    final parentElement = type.element;
    if (parentElement == null) {
      throw routeError(
        '`parent` on ${element.displayName} does not resolve to a class.',
        element: element,
      );
    }
    // `typeNameOf` follows type aliases, so `parent: MyAlias` keys on the
    // aliased class rather than on the alias — which would never match the
    // annotated widget's own id.
    final name = typeNameOf(type);
    final uri = parentElement.library?.uri.toString() ?? '';
    return '$uri#$name';
  }

  static String _idOf(ClassElement element) =>
      '${_libraryUriOf(element)}#${element.displayName}';

  static String _libraryUriOf(ClassElement element) =>
      element.library.uri.toString();

  String? _metadataSource(
    ConstantReader annotation,
    ClassElement element,
    String label,
  ) {
    final field = annotation.read('metadata');
    if (field.isNull) return null;
    return ConstSource.render(
      field.objectValue,
      context: 'metadata on $label',
      element: element,
    );
  }

  static String? _optionalString(ConstantReader annotation, String field) {
    final reader = annotation.read(field);
    return reader.isNull ? null : reader.stringValue;
  }

  static bool? _optionalBool(ConstantReader annotation, String field) {
    final reader = annotation.read(field);
    return reader.isNull ? null : reader.boolValue;
  }

  static int? _optionalInt(ConstantReader annotation, String field) {
    final reader = annotation.read(field);
    return reader.isNull ? null : reader.intValue;
  }

  /// Reads a string-typed *code reference* field and checks it is at least
  /// shaped like one before it is spliced into generated source.
  static String? _optionalRef(
    ConstantReader annotation,
    String field,
    Element element,
  ) {
    final reader = annotation.read(field);
    if (reader.isNull) return null;
    final value = reader.stringValue;
    if (!GeneratorUtils.isFunctionReference(value)) {
      throw routeError(
        '`$field` must name a function, constructor or constant visible from '
        'the router library, got "$value".',
        element: element,
        todo:
            'Use a bare identifier (`myGuard`), a constructor reference '
            '(`ErrorScreen.new`), or a static member (`Guards.auth`).',
      );
    }
    return value;
  }

  static List<String> _refList(
    ConstantReader annotation,
    String field,
    Element element,
  ) {
    final reader = annotation.read(field);
    if (reader.isNull) return const [];
    return [
      for (final item in reader.listValue) _requireRef(item, field, element),
    ];
  }

  static String _requireRef(DartObject object, String field, Element element) {
    final value = object.toStringValue();
    if (value == null || !GeneratorUtils.isFunctionReference(value)) {
      throw routeError(
        'Every entry in `$field` must name a function visible from the router '
        'library, got "${value ?? object}".',
        element: element,
      );
    }
    return value;
  }

  static String? _enumName(DartObject object) =>
      object.getField('_name')?.toStringValue();
}

/// A discovered annotated class, paired with the annotation that found it.
class DiscoveredNode {
  /// Pairs an annotated [element] with the [annotation] that matched it.
  DiscoveredNode(this.element, this.annotation, {required this.isShell});

  /// The annotated widget class.
  final ClassElement element;

  /// The matched annotation.
  final ConstantReader annotation;

  /// Whether the match was `@AutoGoRouteShell`.
  final bool isShell;

  /// The library-qualified identity of [element].
  String get id => '${element.library.uri}#${element.displayName}';

  /// The declared path.
  String get path => annotation.read('path').stringValue;
}

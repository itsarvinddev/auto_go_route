import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../analysis/graph_resolver.dart';
import '../analysis/route_collector.dart';
import '../emit/route_emitter.dart';
import '../model/route_model.dart';
import '../utils/generator_utils.dart';
import '../errors.dart';

/// Generates a go_router configuration from `@AutoGoRoute` annotations.
///
/// Runs once per library, and produces output only for the library holding
/// `@AutoGoRouteBase`. That library's part file carries the whole route tree,
/// which is why discovery has to look beyond the input library.
class AutoGoRouteGenerator extends Generator {
  /// Creates the generator.
  ///
  /// [sourceGlobs] overrides which assets are scanned for annotations; it maps
  /// to the `source_globs` builder option.
  AutoGoRouteGenerator({List<String>? sourceGlobs})
    : _collector = RouteCollector(sourceGlobs: sourceGlobs);

  final RouteCollector _collector;

  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final annotatedBases = library.annotatedWith(baseChecker).toList();
    if (annotatedBases.isEmpty) return null;
    if (annotatedBases.length > 1) {
      throw routeError(
        'Only one @AutoGoRouteBase is allowed per library; found '
        '${annotatedBases.length}.',
        element: annotatedBases[1].element,
      );
    }

    final baseElement = annotatedBases.single.element;
    if (baseElement is! ClassElement) {
      throw routeError(
        '@AutoGoRouteBase can only be applied to a class.',
        element: baseElement,
      );
    }

    final base = _collector.readBase(
      baseElement,
      annotatedBases.single.annotation,
    );

    final discovered = await _collector.discover(
      buildStep,
      globs: base.sourceGlobs,
    );
    if (base.sourceGlobs == null &&
        _collector.otherRouterLibraries.isNotEmpty) {
      log.warning(
        '${base.className} and the @AutoGoRouteBase in '
        '${_collector.otherRouterLibraries.map((a) => a.path).join(', ')} both '
        'scan the same sources, so each generated router contains every route '
        'and both declare the same public route classes and helpers — importing '
        'the two libraries together is ambiguous. Give each router '
        '`sourceGlobs:` to split the route table between them.',
      );
    }
    if (discovered.isEmpty) {
      throw routeError(
        'No @AutoGoRoute or @AutoGoRouteShell annotated widgets were found. '
        'The generator scans this package\'s `lib/` directory.',
        element: baseElement,
        todo:
            'Annotate at least one widget, or point the builder elsewhere with '
            'the `source_globs` option in build.yaml.',
      );
    }

    final skeletons = [for (final node in discovered) _skeletonOf(node)];
    final graph = GraphResolver.resolve(skeletons, onWarning: log.warning);

    final nodes = <String, NodeInfo>{};
    for (final node in discovered) {
      nodes[node.id] = _collector.read(
        node,
        pathParameterNames:
            graph.pathParameterNames[node.id]?.toSet() ?? const {},
        defaultCaseSensitive: base.caseSensitive,
      );
    }

    _validateIdentifiers(nodes, baseElement, base);
    _validateBranchEnums(nodes, graph, baseElement, base);
    _validateBranchAnnotations(nodes, graph);
    _validateReferences(nodes, base, baseElement, library.element);

    return RouteEmitter(base: base, graph: graph, nodes: nodes).emit();
  }

  NodeSkeleton _skeletonOf(DiscoveredNode node) {
    final annotation = node.annotation;
    final order = annotation.read('order');
    final parent = annotation.read('parent');
    String? parentId;
    if (!parent.isNull) {
      final type = parent.typeValue;
      final element = type.element;
      if (element == null) {
        throw routeError(
          '`parent` on ${node.element.displayName} does not resolve to a '
          'class.',
          element: node.element,
        );
      }
      parentId = '${element.library?.uri}#${typeNameOf(type)}';
    }
    return NodeSkeleton(
      id: node.id,
      className: node.element.displayName,
      libraryUri: node.element.library.uri.toString(),
      path: node.path,
      isShell: node.isShell,
      parentId: parentId,
      order: order.isNull ? null : order.intValue,
    );
  }

  /// Checks that no two nodes would generate the same Dart identifier.
  ///
  /// Uniqueness is checked on the *generated* names rather than on the raw
  /// route names, because that is what actually has to be unique: `userProfile`
  /// and `UserProfile` are different route names but both yield
  /// `goToUserProfile`. Shells are included — 1.x checked routes only, so a
  /// route and a shell could collide and emit two `FooRoute` classes.
  void _validateIdentifiers(
    Map<String, NodeInfo> nodes,
    Element baseElement,
    RouterBaseInfo base,
  ) {
    final byMethodName = <String, NodeInfo>{};
    final byClassName = <String, NodeInfo>{};
    // Names an enum value cannot take: members every enum declares, the two
    // fields the generated enum adds, and Dart's reserved words.
    const reserved = <String>{
      'values', 'index', 'hashCode', 'runtimeType', 'toString', 'noSuchMethod',
      'routeName', 'template', //
      'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
      'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
      'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
      'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
    };

    for (final node in nodes.values) {
      if (base.generateRouteEnum && reserved.contains(node.name)) {
        throw routeError(
          'Route name "${node.name}" on ${node.className} is reserved inside '
          'the generated route enum — it is a Dart keyword or a member the '
          'enum already declares — so the enum would not compile.',
          element: baseElement,
          todo:
              'Rename the route, or set '
              '`@AutoGoRouteBase(generateRouteEnum: false)`.',
        );
      }

      final methodName = GeneratorUtils.toUpperCamelCase(node.name);
      final existing = byMethodName[methodName];
      if (existing != null) {
        throw routeError(
          '${node.className} and ${existing.className} both generate '
          '`goTo$methodName`. Route names must be unique after '
          'capitalisation — "${node.name}" and "${existing.name}" are not.',
          element: baseElement,
          todo: 'Give one of them an explicit, distinct `name:`.',
        );
      }
      byMethodName[methodName] = node;

      final className = '${node.className}Route';
      final classClash = byClassName[className];
      if (classClash != null) {
        throw routeError(
          'Two annotated widgets are both named ${node.className} '
          '(${classClash.libraryUri} and ${node.libraryUri}), so both would '
          'generate `class $className`.',
          element: baseElement,
          todo: 'Rename one of the widgets.',
        );
      }
      byClassName[className] = node;
    }
  }

  /// Checks that a stateful shell's children can be values of its generated
  /// branch enum, and that the enum's name is free.
  void _validateBranchEnums(
    Map<String, NodeInfo> nodes,
    ResolvedGraph graph,
    Element baseElement,
    RouterBaseInfo base,
  ) {
    if (!base.generateRouteEnum) return;
    // Enum members every enum has, the members the branch enum adds, and
    // Dart's reserved words.
    const reserved = <String>{
      'values', 'index', 'hashCode', 'runtimeType', 'toString', 'noSuchMethod',
      'initialLocation', 'of', 'isActiveIn', 'go', 'goFrom', //
      'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
      'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
      'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
      'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
    };
    final classNames = {for (final node in nodes.values) node.className};
    for (final shell in nodes.values.whereType<ShellInfo>()) {
      if (!shell.isStateful) continue;
      final enumName = RouteEmitter.branchEnumName(shell);
      if (classNames.contains(enumName)) {
        throw routeError(
          'The generated branch enum for ${shell.className} is named '
          '`$enumName`, which is already an annotated widget.',
          element: baseElement,
          todo:
              'Rename one of them, or set '
              '`@AutoGoRouteBase(generateRouteEnum: false)`.',
        );
      }
      for (final childId in graph.childrenOf[shell.id] ?? const <String>[]) {
        final child = nodes[childId]!;
        if (reserved.contains(child.name)) {
          throw routeError(
            'Route name "${child.name}" on ${child.className} cannot be a value '
            'of the generated `$enumName` enum: it is a Dart keyword or a '
            'member the enum already declares.',
            element: baseElement,
            todo:
                'Rename the route, or set '
                '`@AutoGoRouteBase(generateRouteEnum: false)`.',
          );
        }
      }
    }
  }

  /// Warns when `@AutoGoRouteBranch` is applied where it has no effect.
  void _validateBranchAnnotations(
    Map<String, NodeInfo> nodes,
    ResolvedGraph graph,
  ) {
    for (final node in nodes.values) {
      final branch = node is RouteInfo
          ? node.branch
          : (node as ShellInfo).branch;
      if (branch == null) continue;
      final parentId = node.parentId;
      final parent = parentId == null ? null : nodes[parentId];
      if (parent is! ShellInfo || !parent.isStateful) {
        log.warning(
          '${node.className} carries @AutoGoRouteBranch, which configures a '
          'branch of a stateful shell, but its parent is '
          '${parent == null ? 'not set' : '${parent.className} (not a stateful shell)'}. '
          'The annotation is ignored.',
        );
      }
    }
  }

  /// Checks that every string-named function, key or constant resolves in the
  /// router library's scope.
  ///
  /// Without this, a typo surfaces as `Undefined name 'authGaurd'` inside a
  /// generated file the user is told not to edit. Here it surfaces as a build
  /// error pointing at the annotation.
  void _validateReferences(
    Map<String, NodeInfo> nodes,
    RouterBaseInfo base,
    Element baseElement,
    LibraryElement baseLibrary,
  ) {
    final references = <String, String>{};

    void collect(String? reference, String where) {
      if (reference == null) return;
      references.putIfAbsent(
        GeneratorUtils.rootIdentifierOf(reference),
        () => where,
      );
    }

    collect(base.navigatorKey, '@AutoGoRouteBase(navigatorKey:)');
    collect(base.redirect, '@AutoGoRouteBase(redirect:)');
    collect(base.onEnter, '@AutoGoRouteBase(onEnter:)');
    collect(base.onException, '@AutoGoRouteBase(onException:)');
    collect(base.errorBuilder, '@AutoGoRouteBase(errorBuilder:)');
    collect(base.errorPageBuilder, '@AutoGoRouteBase(errorPageBuilder:)');
    collect(base.errorWidget, '@AutoGoRouteBase(errorWidget:)');
    collect(base.observers, '@AutoGoRouteBase(observers:)');
    collect(base.refreshListenable, '@AutoGoRouteBase(refreshListenable:)');
    collect(base.extraCodec, '@AutoGoRouteBase(extraCodec:)');
    collect(base.initialExtra, '@AutoGoRouteBase(initialExtra:)');

    for (final node in nodes.values) {
      final label = node.className;
      for (final guard in node.middleware) {
        collect(guard, '$label(middleware:)');
      }
      collect(node.redirect, '$label(redirect:)');
      collect(node.parentNavigatorKey, '$label(parentNavigatorKey:)');
      if (node is RouteInfo) {
        collect(node.onExit, '$label(onExit:)');
        collect(node.page.pageBuilder, '$label(pageBuilder:)');
        collect(node.page.barrierColor, '$label(barrierColor:)');
        final branch = node.branch;
        if (branch != null) {
          collect(branch.navigatorKey, '$label(branch navigatorKey:)');
          collect(branch.observers, '$label(branch observers:)');
        }
      } else if (node is ShellInfo) {
        collect(node.pageBuilder, '$label(pageBuilder:)');
        collect(node.navigatorKey, '$label(navigatorKey:)');
        collect(node.observers, '$label(observers:)');
        collect(
          node.navigatorContainerBuilder,
          '$label(navigatorContainerBuilder:)',
        );
      }
    }

    // The emitted part also names every annotated widget, and every type it
    // passes through a codec or `extra`. Those have to be visible from the
    // router library too — a forgotten widget import, or a type imported only
    // under a prefix (the emitted code spells it unprefixed), used to surface
    // as `Undefined name` inside the generated file.
    const builtIns = {'dynamic', 'void', 'Never', 'Null', 'Function'};
    final identifier = RegExp(r'[A-Za-z_$][\w$]*');
    for (final node in nodes.values) {
      references.putIfAbsent(
        node.className,
        () =>
            'the @${node is ShellInfo ? 'AutoGoRouteShell' : 'AutoGoRoute'} '
            'widget in ${node.libraryUri}',
      );
      if (node is! RouteInfo) continue;
      for (final param in node.params) {
        for (final match in identifier.allMatches(param.typeSource)) {
          final name = match.group(0)!;
          if (builtIns.contains(name)) continue;
          references.putIfAbsent(
            name,
            () => 'the type of `${param.dartName}` on ${node.className}',
          );
        }
      }
    }

    if (references.isEmpty) return;

    final scope = baseLibrary.firstFragment.scope;
    final missing = <String, String>{};
    for (final entry in references.entries) {
      final result = scope.lookup(entry.key);
      if (result.getter == null && result.setter == null) {
        missing[entry.key] = entry.value;
      }
    }
    if (missing.isEmpty) return;

    final details = missing.entries
        .map((e) => '  • `${e.key}` (from ${e.value})')
        .join('\n');
    throw routeError(
      'The generated file is a `part of` '
      '${baseLibrary.uri}, so every widget, parameter type, function, key '
      'and constant it refers to has to be visible from that library. These '
      'are not:\n'
      '$details',
      element: baseElement,
      todo:
          'Import or declare them in ${baseLibrary.uri}, and check the '
          'spelling.',
    );
  }
}

import '../utils/generator_utils.dart';
import '../errors.dart';

/// Sorts last. Routes without an explicit `order` go after those with one,
/// whatever integer they chose — 1.x used `999`, so `order: 1000` sorted
/// *before* an unordered sibling.
const _noOrder = 1 << 30;

/// The minimal facts needed to resolve the graph, read before the full
/// annotation is parsed.
///
/// Templates have to be known before parameters can be classified (a
/// parameter is a path parameter only if the *resolved* path declares it), and
/// the parent chain has to be known before templates can be resolved — hence
/// this cheap first pass.
class NodeSkeleton {
  /// Creates a skeleton.
  const NodeSkeleton({
    required this.id,
    required this.className,
    required this.libraryUri,
    required this.path,
    required this.isShell,
    required this.parentId,
    required this.order,
  });

  /// The library-qualified identity.
  final String id;

  /// The annotated class's name.
  final String className;

  /// The declaring library's URI.
  final String libraryUri;

  /// The declared path.
  final String path;

  /// Whether the node is a shell.
  final bool isShell;

  /// The parent's [id], if any.
  final String? parentId;

  /// The declared sort order.
  final int? order;
}

/// The resolved shape of the route graph: templates, parents and ordering.
class ResolvedGraph {
  /// Creates a resolved graph.
  const ResolvedGraph({
    required this.templates,
    required this.parentTemplates,
    required this.pathParameterNames,
    required this.childrenOf,
    required this.topLevel,
    required this.skeletons,
  });

  /// Absolute path pattern by node id.
  final Map<String, String> templates;

  /// Nearest URL-contributing ancestor's pattern by node id.
  final Map<String, String> parentTemplates;

  /// Path parameter names declared in each node's template.
  final Map<String, List<String>> pathParameterNames;

  /// Child ids by parent id, sorted.
  final Map<String, List<String>> childrenOf;

  /// Ids of nodes with no parent, sorted.
  final List<String> topLevel;

  /// Every skeleton by id.
  final Map<String, NodeSkeleton> skeletons;
}

/// Resolves parent chains into absolute path templates.
abstract final class GraphResolver {
  /// Resolves [skeletons], throwing on an unknown parent, a duplicate node or
  /// a parent cycle.
  ///
  /// [onWarning] receives advisory messages, such as a child route whose path
  /// was written absolutely under a parent that contributes a prefix.
  static ResolvedGraph resolve(
    List<NodeSkeleton> skeletons, {
    void Function(String message)? onWarning,
  }) {
    final byId = <String, NodeSkeleton>{};
    for (final skeleton in skeletons) {
      final existing = byId[skeleton.id];
      if (existing != null) {
        throw routeError(
          '${skeleton.className} in ${skeleton.libraryUri} is annotated more '
          'than once. A widget declares exactly one route.',
        );
      }
      byId[skeleton.id] = skeleton;
    }

    for (final skeleton in byId.values) {
      final parentId = skeleton.parentId;
      if (parentId != null && !byId.containsKey(parentId)) {
        throw routeError(
          '${skeleton.className} declares `parent: '
          '${_classNameOf(parentId)}`, but that class carries no @AutoGoRoute '
          'or @AutoGoRouteShell annotation, so it is not part of the route '
          'graph.',
          todo:
              'Annotate ${_classNameOf(parentId)}, or drop the `parent:` '
              'argument to make ${skeleton.className} a top-level route.',
        );
      }
    }

    // Walk each node's ancestors with a visited set. 1.x walked the chain
    // unbounded, so a widget naming itself as its own parent — or any two
    // widgets naming each other — spun forever inside the build step, which
    // is the literal "hanging" users reported.
    final ancestorsOf = <String, List<NodeSkeleton>>{};
    for (final skeleton in byId.values) {
      final chain = <NodeSkeleton>[];
      final seen = <String>{};
      NodeSkeleton? current = skeleton;
      while (current != null) {
        if (!seen.add(current.id)) {
          throw routeError(
            'The `parent:` chain starting at ${skeleton.className} forms a '
            'cycle: ${_cycleDescription(chain, current.id)}. A route graph is '
            'a tree.',
            todo: 'Break the cycle by removing one `parent:` argument.',
          );
        }
        chain.insert(0, current);
        final parentId = current.parentId;
        current = parentId == null ? null : byId[parentId];
      }
      ancestorsOf[skeleton.id] = chain;
    }

    final templates = <String, String>{};
    final parentTemplates = <String, String>{};
    final pathParameterNames = <String, List<String>>{};

    for (final skeleton in byId.values) {
      final chain = ancestorsOf[skeleton.id]!;
      // Shells are transparent in go_router: only a GoRoute contributes a URL
      // segment (see `fullPathForRoute` in go_router's path_utils.dart), so a
      // shell's own `path` never appears in its children's locations.
      var parentTemplate = '/';
      for (final ancestor in chain.take(chain.length - 1)) {
        if (ancestor.isShell) continue;
        parentTemplate = GeneratorUtils.concatenatePaths(
          parentTemplate,
          ancestor.path,
        );
      }
      final template = skeleton.isShell
          ? parentTemplate
          : GeneratorUtils.concatenatePaths(parentTemplate, skeleton.path);

      if (!skeleton.isShell &&
          skeleton.parentId != null &&
          GeneratorUtils.childPathLooksAbsolute(
            skeleton.path,
            parentTemplate,
          )) {
        onWarning?.call(
          '${skeleton.className} declares `path: \'${skeleton.path}\'` under a '
          'parent mounted at "$parentTemplate". go_router joins child paths '
          'onto their parent, so this route is reachable at "$template", not '
          'at "${skeleton.path}". Write the path relative '
          '("${skeleton.path.substring(1)}") to make that explicit.',
        );
      }

      templates[skeleton.id] = template;
      parentTemplates[skeleton.id] = parentTemplate;
      pathParameterNames[skeleton.id] = GeneratorUtils.pathParameterNames(
        template,
      );

      final duplicates = _duplicates(
        GeneratorUtils.allPathParameterNames(template),
      );
      if (duplicates.isNotEmpty) {
        throw routeError(
          '${skeleton.className} resolves to "$template", which declares '
          '${duplicates.length == 1 ? 'parameter' : 'parameters'} '
          '${duplicates.map((d) => ':$d').join(', ')} more than once. '
          'go_router binds one value per name, and the generated helper would '
          'declare the same argument twice.',
          todo:
              'Rename one of the duplicates, for example `:${duplicates.first}` '
              'in the parent and `:child${GeneratorUtils.toUpperCamelCase(duplicates.first)}` '
              'here.',
        );
      }

      if (GeneratorUtils.hasOptionalPathParameter(skeleton.path)) {
        throw routeError(
          '${skeleton.className} declares the optional path parameter '
          '"${skeleton.path}". go_router has no optional path segments — such '
          'a route registers a pattern nothing can match.',
          todo:
              'Either read the value from the query string (drop it from the '
              'path and declare a nullable constructor parameter), or declare '
              'two routes: one with the segment and one without.',
        );
      }
    }

    final childrenOf = <String, List<String>>{};
    final topLevel = <String>[];
    final sortedIds = byId.keys.toList()..sort();
    for (final id in sortedIds) {
      final skeleton = byId[id]!;
      final parentId = skeleton.parentId;
      if (parentId == null) {
        topLevel.add(id);
      } else {
        childrenOf.putIfAbsent(parentId, () => []).add(id);
      }
    }

    int compare(String a, String b) {
      final left = byId[a]!;
      final right = byId[b]!;
      final byOrder = (left.order ?? _noOrder).compareTo(
        right.order ?? _noOrder,
      );
      // Tie-break on class name, then id, so the comparator is total and the
      // sort is stable regardless of discovery order.
      if (byOrder != 0) return byOrder;
      final byName = left.className.compareTo(right.className);
      return byName != 0 ? byName : a.compareTo(b);
    }

    topLevel.sort(compare);
    for (final children in childrenOf.values) {
      children.sort(compare);
    }

    return ResolvedGraph(
      templates: templates,
      parentTemplates: parentTemplates,
      pathParameterNames: pathParameterNames,
      childrenOf: childrenOf,
      topLevel: topLevel,
      skeletons: byId,
    );
  }

  static List<String> _duplicates(List<String> names) {
    final seen = <String>{};
    final duplicated = <String>{};
    for (final name in names) {
      if (!seen.add(name)) duplicated.add(name);
    }
    return duplicated.toList();
  }

  static String _cycleDescription(List<NodeSkeleton> chain, String repeatedId) {
    final names = chain.map((node) => node.className).toList();
    names.add(_classNameOf(repeatedId));
    return names.join(' → ');
  }

  static String _classNameOf(String id) {
    final hash = id.indexOf('#');
    return hash < 0 ? id : id.substring(hash + 1);
  }
}

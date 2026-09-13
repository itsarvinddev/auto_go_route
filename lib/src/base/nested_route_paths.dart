import 'route_paths.dart';

/// Base class for a generated route that nests under a parent route or shell.
///
/// The only thing that changes versus [RoutePaths] is [template]: the absolute
/// pattern is the parent's pattern with this route's relative [path] appended,
/// which is what parameter discovery and URL building need. The `path` handed
/// to `GoRoute` stays relative, because go_router resolves nesting itself.
abstract class NestedRoutePaths extends RoutePaths {
  /// Creates a nested route definition.
  ///
  /// [parentTemplate] is the parent's absolute pattern, supplied by the
  /// generator.
  const NestedRoutePaths({
    required this.parentTemplate,
    required super.path,
    super.name,
    super.builder,
    super.pageBuilder,
    super.description,
    super.middleware,
    super.redirect,
    super.onExit,
    super.parentNavigatorKey,
    super.caseSensitive,
    super.metadata,
  });

  /// The parent's absolute path pattern.
  final String parentTemplate;

  /// The parent's absolute path pattern.
  ///
  /// Retained for source compatibility with 1.x, where this was the
  /// constructor argument's name.
  String get parentPath => parentTemplate;

  @override
  String get template => _concatenate(parentTemplate, path);

  /// The route's absolute path pattern.
  ///
  /// Retained for source compatibility with 1.x.
  String get fullPath => template;

  /// Joins a parent and child pattern the way go_router's `concatenatePaths`
  /// does: split on `/`, drop empty segments, re-join from the root.
  ///
  /// Matching that implementation is what guarantees the URL this class builds
  /// is the URL go_router will match — a plain string concatenation gets `//`,
  /// trailing slashes and an absolute child path all subtly wrong.
  static String _concatenate(String parent, String child) {
    final segments = <String>[
      ...parent.split('/'),
      ...child.split('/'),
    ].where((segment) => segment.isNotEmpty);
    return '/${segments.join('/')}';
  }

  @override
  List<Object?> get props => [...super.props, parentTemplate];
}

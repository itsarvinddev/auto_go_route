// lib/src/base/nested_route_paths.dart
import 'route_paths.dart';

/// Base class for nested route definitions
abstract class NestedRoutePaths extends RoutePaths {
  const NestedRoutePaths({
    required this.parentPath,
    required super.path,
    super.name,
    required super.builder,
    super.description,
    super.middleware,
  });

  final String parentPath;

  /// Get the full absolute path, correctly joining parent and child paths.
  String get fullPath {
    // Ensure parent path doesn't have a trailing slash
    final effectiveParent = parentPath.endsWith('/')
        ? parentPath.substring(0, parentPath.length - 1)
        : parentPath;

    // Ensure child path doesn't have a leading slash
    final effectivePath = path.startsWith('/') ? path.substring(1) : path;

    // Handle root case
    if (effectiveParent == '/') {
      return '/$effectivePath';
    }

    return '$effectiveParent/$effectivePath';
  }

  /// Override to scan the `fullPath` for required parameters.
  @override
  List<String> get requiredParams {
    return RegExp(r':(\w+)(?!\?)')
        .allMatches(fullPath)
        .map((match) => match.group(1)!)
        .toSet() // Use toSet() to remove duplicates from parent paths
        .toList();
  }

  /// Override to scan the `fullPath` for optional parameters.
  @override
  List<String> get optionalParams {
    return RegExp(r':(\w+)\?')
        .allMatches(fullPath)
        .map((match) => match.group(1)!)
        .toSet()
        .toList();
  }

  /// Override `pathWithParams` to use the `fullPath` as the template.
  @override
  String pathWithParams(
    Map<String, String> params, {
    Map<String, String>? queries,
    bool validate = true,
  }) {
    if (validate) {
      validateParams(params);
    }

    // Use `fullPath` as the template instead of the relative `path`.
    String finalPath = fullPath;

    // Handle required parameters
    for (final param in requiredParams) {
      finalPath = finalPath.replaceAll(
        ':$param',
        Uri.encodeComponent(params[param]!),
      );
    }

    // Handle optional parameters
    for (final param in optionalParams) {
      if (params.containsKey(param) && params[param]!.isNotEmpty) {
        finalPath = finalPath.replaceAll(
          ':$param?',
          Uri.encodeComponent(params[param]!),
        );
      } else {
        // Also remove the preceding slash for an optional param if it's not provided
        finalPath = finalPath.replaceAll('/:$param?', '');
      }
    }

    // Add query parameters
    if (queries != null && queries.isNotEmpty) {
      final queryString = queries.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      finalPath += '?$queryString';
    }

    return finalPath;
  }

  @override
  List<Object?> get props => [...super.props, parentPath];
}

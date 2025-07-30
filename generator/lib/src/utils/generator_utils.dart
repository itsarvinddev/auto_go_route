// generator/lib/src/utils/generator_utils.dart

import 'package:analyzer/dart/element/element.dart';
import 'package:auto_go_route_generator/src/generators/route_generator.dart'
    show RouteInfo;

/// Utility functions for code generation
class GeneratorUtils {
  /// Extract parameters from route path
  static PathParameters extractParametersFromPath(String path) {
    final required = <String>[];
    final optional = <String>[];

    final requiredPattern = RegExp(r':(\w+)(?!\?)');
    final optionalPattern = RegExp(r':(\w+)\?');

    for (final match in requiredPattern.allMatches(path)) {
      required.add(match.group(1)!);
    }

    for (final match in optionalPattern.allMatches(path)) {
      optional.add(match.group(1)!);
    }

    return PathParameters(required: required, optional: optional);
  }

  /// Convert path to valid class name
  static String pathToClassName(String path) {
    return path
        .split('/')
        .where((segment) => segment.isNotEmpty && !segment.startsWith(':'))
        .map((segment) => _capitalize(segment))
        .join('');
  }

  /// Convert parameter name to camelCase
  static String toCamelCase(String input) {
    final words = input.split(RegExp(r'[_\-\s]+'));
    if (words.isEmpty) return input;

    final first = words.first.toLowerCase();
    final rest = words.skip(1).map(_capitalize);

    return [first, ...rest].join('');
  }

  /// Convert string to PascalCase
  static String toPascalCase(String input) {
    return input.split(RegExp(r'[_\-\s]+')).map(_capitalize).join('');
  }

  /// Capitalize first letter
  static String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  /// Get Dart type from parameter element
  static String getDartType(ParameterElement parameter) {
    final type = parameter.type.toString();

    if (type.contains('<') && type.contains('>')) {
      return type.replaceAll(RegExp(r'<[^>]*>'), '');
    }

    return type;
  }

  /// Check if parameter is nullable
  static bool isNullable(ParameterElement parameter) {
    return parameter.type.toString().endsWith('?');
  }

  /// Generate method name from path
  static String generateMethodName(String path, String prefix) {
    final segments = path
        .split('/')
        .where((s) => s.isNotEmpty && !s.startsWith(':'))
        .toList();

    if (segments.isEmpty) return '${prefix}Root';

    return prefix + segments.map(_capitalize).join('');
  }

  /// Validate route path format
  static List<String> validatePath(String path) {
    final errors = <String>[];

    if (path.isEmpty) {
      errors.add('Path cannot be empty');
    }

    if (!path.startsWith('/')) {
      errors.add('Path must start with /');
    }

    final invalidParams = RegExp(r':([^a-zA-Z_]|\d)');
    if (invalidParams.hasMatch(path)) {
      errors.add('Parameter names must start with letter or underscore');
    }

    final params = extractParametersFromPath(path);
    final allParams = [...params.required, ...params.optional];
    final uniqueParams = allParams.toSet();

    if (allParams.length != uniqueParams.length) {
      errors.add('Duplicate parameters found in path');
    }

    return errors;
  }

  /// Generate documentation comment
  static String generateDocComment(RouteInfo routeInfo) {
    final buffer = StringBuffer();
    buffer.writeln('/// Generated route for ${routeInfo.className}');

    if (routeInfo.description != null) {
      buffer.writeln('/// ${routeInfo.description}');
    }

    buffer.writeln('/// Path: ${routeInfo.path}');

    if (routeInfo.requiredParams.isNotEmpty) {
      buffer.writeln(
          '/// Required parameters: ${routeInfo.requiredParams.join(', ')}');
    }

    if (routeInfo.optionalParams.isNotEmpty) {
      buffer.writeln(
          '/// Optional parameters: ${routeInfo.optionalParams.join(', ')}');
    }

    return buffer.toString();
  }
}

/// Container for path parameters
class PathParameters {
  final List<String> required;
  final List<String> optional;

  const PathParameters({
    required this.required,
    required this.optional,
  });
}

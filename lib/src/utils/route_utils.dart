import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Utility functions for route operations
class RouteUtils {
  /// Extract parameters from a path string
  static Map<String, String> extractParamsFromPath(String path) {
    final params = <String, String>{};
    final segments = path.split('/');

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.startsWith(':')) {
        final paramName = segment.substring(1).replaceAll('?', '');
        params[paramName] = segments.length > i + 1 ? segments[i + 1] : '';
      }
    }

    return params;
  }

  /// Validate path format
  static bool isValidPath(String path) {
    if (path.isEmpty || !path.startsWith('/')) return false;

    // Check for invalid characters
    final invalidChars = RegExp(r'[<>:"\\|?*]');
    if (invalidChars.hasMatch(path)) return false;

    // Check parameter format
    final paramPattern = RegExp(r':([a-zA-Z_][a-zA-Z0-9_]*)\??');
    final matches = paramPattern.allMatches(path);

    for (final match in matches) {
      final fullMatch = match.group(0)!;
      if (!path.contains(fullMatch)) return false;
    }

    return true;
  }

  /// Generate breadcrumb from path
  static List<String> generateBreadcrumb(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final breadcrumb = <String>[];

    // ignore: unused_local_variable
    String current = '';
    for (final segment in segments) {
      current += '/$segment';
      if (!segment.startsWith(':')) {
        breadcrumb.add(segment);
      }
    }

    return breadcrumb;
  }

  /// Convert path to URL-safe format
  static String sanitizePath(String path) {
    return path
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-_/:]'), '')
        .replaceAll(RegExp(r'/+'), '/')
        .toLowerCase();
  }

  /// Parse query string to map
  static Map<String, String> parseQueryString(String query) {
    final params = <String, String>{};
    if (query.isEmpty) return params;

    final pairs = query.split('&');
    for (final pair in pairs) {
      final keyValue = pair.split('=');
      if (keyValue.length == 2) {
        params[Uri.decodeComponent(keyValue[0])] =
            Uri.decodeComponent(keyValue[1]);
      }
    }

    return params;
  }

  /// Build query string from map
  static String buildQueryString(Map<String, String> params) {
    if (params.isEmpty) return '';

    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Deep link validation
  static bool isValidDeepLink(String link) {
    try {
      final uri = Uri.parse(link);
      return uri.isAbsolute && uri.hasScheme;
    } catch (e) {
      return false;
    }
  }

  /// Route similarity scoring (for suggestions)
  static double calculateRouteSimilarity(String route1, String route2) {
    if (route1 == route2) return 1.0;

    final segments1 = route1.split('/').where((s) => s.isNotEmpty).toList();
    final segments2 = route2.split('/').where((s) => s.isNotEmpty).toList();

    final maxLength =
        [segments1.length, segments2.length].reduce((a, b) => a > b ? a : b);
    if (maxLength == 0) return 0.0;

    int matches = 0;
    for (int i = 0;
        i <
            [segments1.length, segments2.length]
                .reduce((a, b) => a < b ? a : b);
        i++) {
      if (segments1[i] == segments2[i]) matches++;
    }

    return matches / maxLength;
  }

  /// Log route navigation for analytics
  static void logRouteNavigation(String from, String to,
      {Map<String, dynamic>? metadata}) {
    if (kDebugMode) {
      final log = {
        'timestamp': DateTime.now().toIso8601String(),
        'from': from,
        'to': to,
        'metadata': metadata,
      };
      debugPrint('Route Navigation: ${jsonEncode(log)}');
    }
  }

  /// Performance measurement wrapper
  static T measureRoutePerformance<T>(
      String routeName, T Function() operation) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = operation();
      stopwatch.stop();

      if (kDebugMode) {
        debugPrint(
            'Route "$routeName" operation took ${stopwatch.elapsedMilliseconds}ms');
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint(
            'Route "$routeName" operation failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      }
      rethrow;
    }
  }
}

/// Route validation result
class RouteValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const RouteValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory RouteValidationResult.valid() {
    return const RouteValidationResult(isValid: true);
  }

  factory RouteValidationResult.invalid(List<String> errors,
      [List<String>? warnings]) {
    return RouteValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
    );
  }
}

import 'package:auto_go_route/src/extensions/string.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Extension for type-safe parameter extraction from GoRouterState
extension GoRouterStateTypeExtension on GoRouterState {
  /// Get parameter as string from path or query parameters
  String? _getParam(String key) {
    // First check path parameters
    final pathParam = pathParameters[key];
    if (pathParam != null && pathParam.isNotEmpty) return pathParam;

    // Then check query parameters
    final queryParam = uri.queryParameters[key];
    if (queryParam != null && queryParam.isNotEmpty) return queryParam;

    return null;
  }

  /// Generic typed parameter getter with automatic type conversion
  T getParam<T>(String key) {
    final value = _getParam(key);

    // Handle empty values for optional parameters
    if (value == null || value.isEmpty) {
      if (T == String) return '' as T;
      if (T == int) return 0 as T;
      if (T == double) return 0.0 as T;
      if (T == bool) return false as T;

      // Handle nullable types
      final typeName = T.toString();
      if (typeName.endsWith('?')) {
        return null as T;
      }

      throw ArgumentError(
          'Parameter "$key" not found and no default available for type $T');
    }

    try {
      if (T == String) return value as T;
      if (T == int) return int.parse(value) as T;
      if (T == double) return double.parse(value) as T;
      if (T == bool) return (value.toBoolOrNull() == true) as T;

      // Handle nullable string
      if (T.toString() == 'String?') return value as T;

      return value as T;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'Failed to parse parameter "$key" with value "$value" to type $T: $e');
      }
      throw ArgumentError(
          'Failed to parse parameter "$key" with value "$value" to type $T: $e');
    }
  }

  /// Get required parameter with type checking
  T getRequiredParam<T>(String key) {
    final value = _getParam(key);
    if (value == null || value.isEmpty) {
      throw ArgumentError('Required parameter "$key" is missing or empty');
    }
    return getParam<T>(key);
  }

  /// Get optional parameter with default value
  T getOptionalParam<T>(String key, T defaultValue) {
    try {
      final value = _getParam(key);
      if (value == null || value.isEmpty) {
        return defaultValue;
      }
      return getParam<T>(key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Using default value for parameter "$key": $e');
      }
      return defaultValue;
    }
  }

  /// Get all path parameters as a typed map
  Map<String, T> getTypedPathParameters<T>() {
    final result = <String, T>{};
    for (final entry in pathParameters.entries) {
      try {
        result[entry.key] = getParam<T>(entry.key);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Skipped parameter ${entry.key}: $e');
        }
        continue;
      }
    }
    return result;
  }

  /// Get all query parameters as a typed map
  Map<String, T> getTypedQueryParameters<T>() {
    final result = <String, T>{};
    for (final entry in uri.queryParameters.entries) {
      try {
        result[entry.key] = getParam<T>(entry.key);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Skipped query parameter ${entry.key}: $e');
        }
        continue;
      }
    }
    return result;
  }

  /// Check if parameter exists in path or query
  bool hasParam(String key) {
    return pathParameters.containsKey(key) ||
        uri.queryParameters.containsKey(key);
  }

  /// Get parameter with validation
  T getValidatedParam<T>(String key, bool Function(T) validator,
      {T? fallback}) {
    try {
      final value = getParam<T>(key);
      if (validator(value)) {
        return value;
      }

      if (fallback != null) {
        return fallback;
      }

      throw ArgumentError('Parameter "$key" failed validation');
    } catch (e) {
      if (fallback != null) {
        return fallback;
      }
      rethrow;
    }
  }
}

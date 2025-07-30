/// Base exception for auto_go_route errors
abstract class AutoGoRouteException implements Exception {
  const AutoGoRouteException(this.message);

  final String message;

  @override
  String toString() => 'AutoGoRouteException: $message';
}

/// Exception thrown when route generation fails
class RouteGenerationException extends AutoGoRouteException {
  const RouteGenerationException(super.message, this.routeName);

  final String? routeName;

  @override
  String toString() =>
      'RouteGenerationException${routeName != null ? ' for $routeName' : ''}: $message';
}

/// Exception thrown when route validation fails
class RouteValidationException extends AutoGoRouteException {
  const RouteValidationException(super.message, this.routePath);

  final String? routePath;

  @override
  String toString() =>
      'RouteValidationException${routePath != null ? ' for $routePath' : ''}: $message';
}

/// Exception thrown when navigation fails
class NavigationException extends AutoGoRouteException {
  const NavigationException(super.message, this.targetRoute);

  final String? targetRoute;

  @override
  String toString() =>
      'NavigationException${targetRoute != null ? ' to $targetRoute' : ''}: $message';
}

/// Exception thrown when parameter parsing fails
class ParameterException extends AutoGoRouteException {
  const ParameterException(
      super.message, this.parameterName, this.expectedType);

  final String parameterName;
  final String? expectedType;

  @override
  String toString() =>
      'ParameterException for $parameterName${expectedType != null ? ' (expected $expectedType)' : ''}: $message';
}

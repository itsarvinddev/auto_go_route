/// Base class for application-level routing errors.
///
/// The package itself does not throw these: parameter decoding raises
/// [RouteParamFormatException] (a [FormatException]), and registry validation
/// raises [StateError]. They remain exported, unchanged from 1.x, as a
/// ready-made hierarchy for app code that wants typed routing errors of its
/// own — a guard that throws a [NavigationException], say.
abstract class AutoGoRouteException implements Exception {
  /// Creates an exception carrying [message].
  const AutoGoRouteException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'AutoGoRouteException: $message';
}

/// Signals that route generation failed at runtime.
class RouteGenerationException extends AutoGoRouteException {
  /// Creates a generation failure for [routeName].
  const RouteGenerationException(super.message, this.routeName);

  /// The route being generated, if known.
  final String? routeName;

  @override
  String toString() =>
      'RouteGenerationException'
      '${routeName == null ? '' : ' for $routeName'}: $message';
}

/// Signals that a route definition failed validation.
class RouteValidationException extends AutoGoRouteException {
  /// Creates a validation failure for [routePath].
  const RouteValidationException(super.message, this.routePath);

  /// The offending path template, if known.
  final String? routePath;

  @override
  String toString() =>
      'RouteValidationException'
      '${routePath == null ? '' : ' for $routePath'}: $message';
}

/// Signals that a navigation could not be performed.
class NavigationException extends AutoGoRouteException {
  /// Creates a navigation failure for [targetRoute].
  const NavigationException(super.message, this.targetRoute);

  /// The location that could not be reached, if known.
  final String? targetRoute;

  @override
  String toString() =>
      'NavigationException'
      '${targetRoute == null ? '' : ' to $targetRoute'}: $message';
}

/// Signals that a route parameter could not be read.
///
/// Prefer [RouteParamFormatException], which carries the raw value and is what
/// [RouteCodec] and the generated builders raise. This class remains for code
/// written against 1.x.
class ParameterException extends AutoGoRouteException {
  /// Creates a parameter failure for [parameterName].
  const ParameterException(
    super.message,
    this.parameterName,
    this.expectedType,
  );

  /// The parameter that could not be read.
  final String parameterName;

  /// The type it was expected to hold, if known.
  final String? expectedType;

  @override
  String toString() =>
      'ParameterException for $parameterName'
      '${expectedType == null ? '' : ' (expected $expectedType)'}: $message';
}

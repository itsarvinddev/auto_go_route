import 'package:go_router/go_router.dart';

import '../codec/route_codec.dart';

/// Returns the [Type] literal for [X], including its nullability.
///
/// `T == int` is `false` when `T` is `int?`, so a `getParam<int?>` call cannot
/// be recognised by comparing against `int` alone. Capturing both spellings up
/// front is what lets [GoRouterStateTypeExtension.getParam] handle nullable
/// type arguments — in 1.x it threw for every *present* nullable value.
Type _typeOf<X>() => X;

final _string = _typeOf<String>();
final _stringN = _typeOf<String?>();
final _int = _typeOf<int>();
final _intN = _typeOf<int?>();
final _double = _typeOf<double>();
final _doubleN = _typeOf<double?>();
final _num = _typeOf<num>();
final _numN = _typeOf<num?>();
final _bool = _typeOf<bool>();
final _boolN = _typeOf<bool?>();
final _bigInt = _typeOf<BigInt>();
final _bigIntN = _typeOf<BigInt?>();
final _dateTime = _typeOf<DateTime>();
final _dateTimeN = _typeOf<DateTime?>();
final _uri = _typeOf<Uri>();
final _uriN = _typeOf<Uri?>();
final _object = _typeOf<Object>();
final _objectN = _typeOf<Object?>();
final _dynamic = _typeOf<dynamic>();

/// Typed parameter access on [GoRouterState].
///
/// Path parameters are checked before query parameters, so a name appearing in
/// both resolves to the path.
///
/// Generated route builders call [RouteCodec] directly — it is monomorphic and
/// needs no runtime type dispatch. These helpers are for hand-written code:
/// redirects, `onExit` callbacks, and widgets that read the state themselves.
extension GoRouterStateTypeExtension on GoRouterState {
  /// Reads [key] as [T].
  ///
  /// Supported type arguments are `String`, `int`, `double`, `num`, `bool`,
  /// `BigInt`, `DateTime` and `Uri`, each with its nullable form. For enums
  /// use [getEnumParam], which needs the `values` list.
  ///
  /// Throws [RouteParamFormatException] when the parameter is missing and [T]
  /// is non-nullable, or when the value cannot be parsed as [T]. It never
  /// fabricates a value — 1.x returned `0`, `''` or `false` for a missing
  /// parameter, which turned routing mistakes into silent data corruption.
  ///
  /// Throws [ArgumentError] for an unsupported [T].
  T getParam<T>(String key) {
    final nullable = null is T;
    if (T == _string || T == _stringN) {
      return (nullable
              ? RouteCodec.optionalString(this, key)
              : RouteCodec.requireString(this, key))
          as T;
    }
    if (T == _int || T == _intN) {
      return (nullable
              ? RouteCodec.optionalInt(this, key)
              : RouteCodec.requireInt(this, key))
          as T;
    }
    if (T == _double || T == _doubleN) {
      return (nullable
              ? RouteCodec.optionalDouble(this, key)
              : RouteCodec.requireDouble(this, key))
          as T;
    }
    if (T == _num || T == _numN) {
      return (nullable
              ? RouteCodec.optionalNum(this, key)
              : RouteCodec.requireNum(this, key))
          as T;
    }
    if (T == _bool || T == _boolN) {
      return (nullable
              ? RouteCodec.optionalBool(this, key)
              : RouteCodec.requireBool(this, key))
          as T;
    }
    if (T == _bigInt || T == _bigIntN) {
      return (nullable
              ? RouteCodec.optionalBigInt(this, key)
              : RouteCodec.requireBigInt(this, key))
          as T;
    }
    if (T == _dateTime || T == _dateTimeN) {
      return (nullable
              ? RouteCodec.optionalDateTime(this, key)
              : RouteCodec.requireDateTime(this, key))
          as T;
    }
    if (T == _uri || T == _uriN) {
      return (nullable
              ? RouteCodec.optionalUri(this, key)
              : RouteCodec.requireUri(this, key))
          as T;
    }
    // An untyped read — `getParam<dynamic>`, or the `T` Dart infers for
    // `getTypedPathParameters()` with no type argument — yields the raw
    // string rather than an ArgumentError.
    if (T == _dynamic || T == _object || T == _objectN) {
      return (nullable
              ? RouteCodec.optionalString(this, key)
              : RouteCodec.requireString(this, key))
          as T;
    }
    throw ArgumentError(
      'getParam<$T>("$key") is not supported. Use String, int, double, num, '
      'bool, BigInt, DateTime or Uri (optionally nullable), or getEnumParam '
      'for enums.',
    );
  }

  /// Reads [key] as one of [values], matching on [Enum.name].
  ///
  /// Returns [orElse] when the parameter is absent, or throws
  /// [RouteParamFormatException] instead when [required] is `true`. A present
  /// value that matches none of [values] always throws.
  T? getEnumParam<T extends Enum>(
    String key,
    List<T> values, {
    T? orElse,
    bool required = false,
  }) {
    final value = RouteCodec.optionalEnum(this, key, values);
    if (value != null) return value;
    if (required) return RouteCodec.requireEnum(this, key, values);
    return orElse;
  }

  /// Reads [key] as [T], throwing when it is absent or empty.
  T getRequiredParam<T>(String key) {
    final raw = RouteCodec.raw(this, key);
    if (raw == null || raw.isEmpty) {
      throw RouteParamFormatException(
        parameterName: key,
        expectedType: '$T',
        rawValue: raw,
        reason: 'Required parameter "$key" is missing or empty.',
      );
    }
    return getParam<T>(key);
  }

  /// Reads [key] as [T], falling back to [defaultValue] when it is absent.
  ///
  /// A *present but unparseable* value still throws — silently substituting
  /// the default there would hide a malformed link.
  T getOptionalParam<T>(String key, T defaultValue) {
    final raw = RouteCodec.raw(this, key);
    if (raw == null || raw.isEmpty) return defaultValue;
    return getParam<T>(key);
  }

  /// Every value supplied for the repeated query parameter [key].
  List<String> getParamList(String key) => RouteCodec.rawAll(this, key);

  /// Whether [key] is present as a path or query parameter.
  bool hasParam(String key) =>
      pathParameters.containsKey(key) || uri.queryParameters.containsKey(key);

  /// Every path parameter converted to [T].
  ///
  /// Parameters that fail to convert are omitted rather than throwing, since
  /// the caller asked for a best-effort view of the whole map.
  Map<String, T> getTypedPathParameters<T>() {
    final result = <String, T>{};
    for (final key in pathParameters.keys) {
      try {
        result[key] = getParam<T>(key);
      } on FormatException {
        continue;
      }
    }
    return result;
  }

  /// Every query parameter converted to [T], skipping those that fail.
  Map<String, T> getTypedQueryParameters<T>() {
    final result = <String, T>{};
    for (final key in uri.queryParameters.keys) {
      try {
        result[key] = getParam<T>(key);
      } on FormatException {
        continue;
      }
    }
    return result;
  }

  /// Reads [key] as [T] and checks it against [validator].
  ///
  /// Returns [fallback] when the value is missing, unparseable or rejected.
  /// Without a [fallback], any of those rethrows — pass [hasFallback] to use
  /// `null` as a deliberate fallback for a nullable [T].
  T getValidatedParam<T>(
    String key,
    bool Function(T) validator, {
    T? fallback,
    bool hasFallback = false,
  }) {
    final useFallback = hasFallback || fallback != null;
    try {
      final value = getParam<T>(key);
      if (validator(value)) return value;
      if (useFallback) return fallback as T;
      throw RouteParamFormatException(
        parameterName: key,
        expectedType: '$T',
        rawValue: RouteCodec.raw(this, key),
        reason: 'Parameter "$key" failed validation.',
      );
    } on FormatException {
      if (useFallback) return fallback as T;
      rethrow;
    }
  }

  /// Reads `extra` as a `T?`, returning `null` when absent or of another type.
  T? extraAs<T extends Object>() => RouteCodec.optionalExtra<T>(this);

  /// Reads [key] from the route's merged [GoRouterState.metadata] as a `T?`.
  ///
  /// Handy for declarative guards: `state.metadataAs<String>('requiresRole')`.
  T? metadataAs<T>(String key) {
    final value = metadata[key];
    return value is T ? value : null;
  }
}

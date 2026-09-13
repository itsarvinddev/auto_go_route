import 'package:go_router/go_router.dart';

/// Thrown when a path or query parameter cannot be decoded into the type the
/// route declared for it.
///
/// This is a *programming* signal in the same family as
/// [FormatException]: it means the incoming URL did not match the route's
/// declared shape.
///
/// Generated builders decode while the page is being built, so an uncaught
/// throw surfaces as a build error rather than reaching
/// `GoRouter.onException` (which only sees *routing* failures). To send a
/// malformed link somewhere useful, validate in a route `redirect` —
/// `RouteCodec` works there too — and return a location.
class RouteParamFormatException extends FormatException {
  /// Creates an exception describing a failed parameter decode.
  RouteParamFormatException({
    required this.parameterName,
    required this.expectedType,
    required String? rawValue,
    String? reason,
  }) : super(
         reason ??
             'Parameter "$parameterName" could not be read as $expectedType '
                 '(raw value: ${rawValue == null ? 'absent' : '"$rawValue"'}).',
         rawValue,
       );

  /// The name of the path or query parameter that failed to decode.
  final String parameterName;

  /// The Dart type the route declared for this parameter.
  final String expectedType;

  @override
  String toString() => 'RouteParamFormatException: $message';
}

/// Encodes and decodes the parameter types `auto_go_route` supports in paths
/// and query strings.
///
/// The generated code calls into this class, so its behaviour is the contract
/// between a route's declared Dart types and the URLs your app produces and
/// accepts. It is also safe — and sometimes useful — to call directly, for
/// instance from a `redirect` that needs to read a parameter before the widget
/// is built.
///
/// ## Supported types
///
/// | Dart type   | Wire format                                  |
/// |-------------|----------------------------------------------|
/// | `String`    | verbatim                                     |
/// | `int`       | `42`                                         |
/// | `double`    | `4.2`                                        |
/// | `num`       | `42` or `4.2`                                |
/// | `bool`      | `true` / `false` (reads `1` / `0` too)       |
/// | `BigInt`    | `123456789012345678901234567890`             |
/// | `DateTime`  | ISO-8601, e.g. `2026-09-12T10:30:00.000Z`    |
/// | `Uri`       | the URI's string form                        |
/// | `enum`      | the value's `name`                           |
///
/// `List<T>` of any of the above is supported for **query** parameters only,
/// and maps to a repeated key (`?tag=a&tag=b`).
abstract final class RouteCodec {
  /// Converts [value] to its wire form.
  ///
  /// The result is *not* percent-encoded; callers substituting into a path or
  /// query string are responsible for that (see [encodeComponent]).
  ///
  /// Throws [ArgumentError] for unsupported types, which the generator
  /// prevents from reaching here.
  static String encode(Object value) {
    if (value is String) return value;
    if (value is bool) return value ? 'true' : 'false';
    if (value is int || value is double || value is num || value is BigInt) {
      return value.toString();
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Uri) return value.toString();
    if (value is Enum) return value.name;
    throw ArgumentError.value(
      value,
      'value',
      'Unsupported route parameter type ${value.runtimeType}. Supported: '
          'String, int, double, num, bool, BigInt, DateTime, Uri, enum.',
    );
  }

  /// [encode]s [value] and percent-encodes the result for use inside a URL.
  static String encodeComponent(Object value) =>
      Uri.encodeComponent(encode(value));

  /// Encodes an iterable into its repeated-key wire form.
  ///
  /// `null` and `null` elements are dropped, so `['a', null, 'b']` becomes
  /// `['a', 'b']`.
  static List<String> encodeAll(Iterable<Object?>? values) => values == null
      ? const <String>[]
      : <String>[
          for (final value in values)
            if (value != null) encode(value),
        ];

  // ---------------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------------

  /// Reads the raw string for [name], checking path parameters first and then
  /// query parameters.
  ///
  /// Returns `null` when the parameter is absent. An *empty* value is returned
  /// as an empty string rather than `null`, because `?q=` is a meaningful
  /// distinction from `?` for a `String` parameter.
  static String? raw(GoRouterState state, String name) =>
      state.pathParameters[name] ?? state.uri.queryParameters[name];

  /// Reads every value supplied for the query parameter [name].
  ///
  /// Returns an empty list when the parameter is absent.
  static List<String> rawAll(GoRouterState state, String name) =>
      state.uri.queryParametersAll[name] ?? const <String>[];

  static Never _missing(String name, String type) =>
      throw RouteParamFormatException(
        parameterName: name,
        expectedType: type,
        rawValue: null,
        reason:
            'Required parameter "$name" ($type) is missing from the route. '
            'Declare it as nullable or give it a default value if it is '
            'optional.',
      );

  static Never _bad(String name, String type, String value) =>
      throw RouteParamFormatException(
        parameterName: name,
        expectedType: type,
        rawValue: value,
      );

  // -- String -----------------------------------------------------------------

  /// Reads [name] as a required `String`.
  static String requireString(GoRouterState state, String name) =>
      raw(state, name) ?? _missing(name, 'String');

  /// Reads [name] as a `String?`, returning `null` when absent.
  static String? optionalString(GoRouterState state, String name) =>
      raw(state, name);

  // -- int --------------------------------------------------------------------

  /// Reads [name] as a required `int`.
  static int requireInt(GoRouterState state, String name) =>
      optionalInt(state, name) ?? _missing(name, 'int');

  /// Reads [name] as an `int?`, returning `null` when absent.
  ///
  /// Throws [RouteParamFormatException] when present but unparseable.
  static int? optionalInt(GoRouterState state, String name) {
    final value = raw(state, name);
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value) ?? _bad(name, 'int', value);
  }

  // -- double -----------------------------------------------------------------

  /// Reads [name] as a required `double`.
  static double requireDouble(GoRouterState state, String name) =>
      optionalDouble(state, name) ?? _missing(name, 'double');

  /// Reads [name] as a `double?`, returning `null` when absent.
  static double? optionalDouble(GoRouterState state, String name) {
    final value = raw(state, name);
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value) ?? _bad(name, 'double', value);
  }

  // -- num --------------------------------------------------------------------

  /// Reads [name] as a required `num`.
  static num requireNum(GoRouterState state, String name) =>
      optionalNum(state, name) ?? _missing(name, 'num');

  /// Reads [name] as a `num?`, returning `null` when absent.
  static num? optionalNum(GoRouterState state, String name) {
    final value = raw(state, name);
    if (value == null || value.isEmpty) return null;
    return num.tryParse(value) ?? _bad(name, 'num', value);
  }

  // -- bool -------------------------------------------------------------------

  /// Reads [name] as a required `bool`.
  static bool requireBool(GoRouterState state, String name) =>
      optionalBool(state, name) ?? _missing(name, 'bool');

  /// Reads [name] as a `bool?`, returning `null` when absent.
  ///
  /// Accepts `true`/`false` (any case) and `1`/`0`. Anything else — including
  /// the empty string — throws, rather than being coerced.
  static bool? optionalBool(GoRouterState state, String name) {
    final value = raw(state, name);
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
    }
    return _bad(name, 'bool', value);
  }

  /// Reads [name] as a `bool` that is `true` merely by being present.
  ///
  /// This is the HTML-form convention: `?archived` and `?archived=true` are
  /// both `true`, `?archived=false` and an absent key are `false`. Any other
  /// value throws [RouteParamFormatException], exactly as [optionalBool] does.
  /// Use [optionalBool] when you need to tell "absent" from "explicitly
  /// false".
  static bool flag(GoRouterState state, String name) {
    final value = raw(state, name);
    if (value == null) return false;
    if (value.isEmpty) return true;
    // Non-empty, so optionalBool either decodes it or throws; it never
    // returns null here.
    return optionalBool(state, name)!;
  }

  // -- BigInt -----------------------------------------------------------------

  /// Reads [name] as a required `BigInt`.
  static BigInt requireBigInt(GoRouterState state, String name) =>
      optionalBigInt(state, name) ?? _missing(name, 'BigInt');

  /// Reads [name] as a `BigInt?`, returning `null` when absent.
  static BigInt? optionalBigInt(GoRouterState state, String name) {
    final value = raw(state, name);
    if (value == null || value.isEmpty) return null;
    return BigInt.tryParse(value) ?? _bad(name, 'BigInt', value);
  }

  // -- DateTime ---------------------------------------------------------------

  /// Reads [name] as a required `DateTime`.
  static DateTime requireDateTime(GoRouterState state, String name) =>
      optionalDateTime(state, name) ?? _missing(name, 'DateTime');

  /// Reads [name] as a `DateTime?`, returning `null` when absent.
  ///
  /// Expects an ISO-8601 string, as produced by [encode].
  static DateTime? optionalDateTime(GoRouterState state, String name) {
    final value = raw(state, name);
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value) ?? _bad(name, 'DateTime', value);
  }

  // -- Uri --------------------------------------------------------------------

  /// Reads [name] as a required `Uri`.
  static Uri requireUri(GoRouterState state, String name) =>
      optionalUri(state, name) ?? _missing(name, 'Uri');

  /// Reads [name] as a `Uri?`, returning `null` when absent.
  static Uri? optionalUri(GoRouterState state, String name) {
    final value = raw(state, name);
    if (value == null || value.isEmpty) return null;
    return Uri.tryParse(value) ?? _bad(name, 'Uri', value);
  }

  // -- enum -------------------------------------------------------------------

  /// Reads [name] as a required enum value drawn from [values].
  ///
  /// Pass the enum's generated `values` list, e.g.
  /// `RouteCodec.requireEnum(state, 'sort', SortOrder.values)`.
  static T requireEnum<T extends Enum>(
    GoRouterState state,
    String name,
    List<T> values,
  ) => optionalEnum(state, name, values) ?? _missing(name, 'enum');

  /// Reads [name] as an enum value from [values], returning `null` when
  /// absent.
  ///
  /// Matching is on [Enum.name] and is case-sensitive, mirroring [encode].
  static T? optionalEnum<T extends Enum>(
    GoRouterState state,
    String name,
    List<T> values,
  ) {
    final value = raw(state, name);
    if (value == null || value.isEmpty) return null;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    throw RouteParamFormatException(
      parameterName: name,
      expectedType: values.isEmpty
          ? 'enum'
          : values.first.runtimeType.toString(),
      rawValue: value,
      reason:
          'Parameter "$name" was "$value", which is not one of '
          '${values.map((v) => v.name).join(', ')}.',
    );
  }

  // -- Lists (query parameters only) -----------------------------------------

  /// Reads every value of the repeated query parameter [name] as `String`s.
  static List<String> stringList(GoRouterState state, String name) =>
      rawAll(state, name);

  /// Reads every value of the repeated query parameter [name] as `int`s.
  static List<int> intList(GoRouterState state, String name) => <int>[
    for (final value in rawAll(state, name))
      if (value.isNotEmpty) int.tryParse(value) ?? _bad(name, 'int', value),
  ];

  /// Reads every value of the repeated query parameter [name] as `double`s.
  static List<double> doubleList(GoRouterState state, String name) => <double>[
    for (final value in rawAll(state, name))
      if (value.isNotEmpty)
        double.tryParse(value) ?? _bad(name, 'double', value),
  ];

  /// Reads every value of the repeated query parameter [name] as `num`s.
  static List<num> numList(GoRouterState state, String name) =>
      _decodeAll(state, name, 'num', num.tryParse);

  /// Reads every value of the repeated query parameter [name] as `bool`s.
  ///
  /// Accepts the same spellings as [optionalBool].
  static List<bool> boolList(GoRouterState state, String name) =>
      _decodeAll(state, name, 'bool', (value) {
        switch (value.toLowerCase()) {
          case 'true':
          case '1':
            return true;
          case 'false':
          case '0':
            return false;
        }
        return null;
      });

  /// Reads every value of the repeated query parameter [name] as `BigInt`s.
  static List<BigInt> bigIntList(GoRouterState state, String name) =>
      _decodeAll(state, name, 'BigInt', BigInt.tryParse);

  /// Reads every value of the repeated query parameter [name] as `DateTime`s.
  static List<DateTime> dateTimeList(GoRouterState state, String name) =>
      _decodeAll(state, name, 'DateTime', DateTime.tryParse);

  /// Reads every value of the repeated query parameter [name] as `Uri`s.
  static List<Uri> uriList(GoRouterState state, String name) =>
      _decodeAll(state, name, 'Uri', Uri.tryParse);

  static List<T> _decodeAll<T extends Object>(
    GoRouterState state,
    String name,
    String type,
    T? Function(String value) decode,
  ) => <T>[
    for (final value in rawAll(state, name))
      if (value.isNotEmpty) decode(value) ?? _bad(name, type, value),
  ];

  /// Reads every value of the repeated query parameter [name] as enum values
  /// drawn from [values].
  static List<T> enumList<T extends Enum>(
    GoRouterState state,
    String name,
    List<T> values,
  ) => <T>[
    for (final raw in rawAll(state, name))
      if (raw.isNotEmpty)
        values.firstWhere(
          (candidate) => candidate.name == raw,
          orElse: () => _bad(name, 'enum', raw),
        ),
  ];

  // ---------------------------------------------------------------------------
  // `extra`
  // ---------------------------------------------------------------------------

  /// Reads `state.extra` as a required `T`.
  ///
  /// Throws a descriptive [RouteParamFormatException] rather than a bare
  /// `TypeError` when `extra` is absent or of the wrong type — the common
  /// outcome of following a deep link into a route that expects an object the
  /// URL cannot carry.
  static T requireExtra<T extends Object>(GoRouterState state, String route) {
    final extra = state.extra;
    if (extra is T) return extra;
    throw RouteParamFormatException(
      parameterName: 'extra',
      expectedType: '$T',
      rawValue: extra?.runtimeType.toString(),
      reason: extra == null
          ? 'Route "$route" requires an `extra` of type $T, but none was '
                'passed. This happens when the route is reached by URL (a deep '
                'link, a browser reload, or a restored session) instead of by '
                'an in-app navigation that supplies `extra`. Make the '
                'parameter nullable, or carry the value in the path or query '
                'string so the URL is self-contained.'
          : 'Route "$route" expected an `extra` of type $T but got '
                '${extra.runtimeType}.',
    );
  }

  /// Reads `state.extra` as a `T?`, returning `null` when absent or of a
  /// different type.
  static T? optionalExtra<T extends Object>(GoRouterState state) {
    final extra = state.extra;
    return extra is T ? extra : null;
  }
}

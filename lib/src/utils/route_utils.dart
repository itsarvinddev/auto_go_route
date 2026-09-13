import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The path-parameter grammar go_router uses, including optional regular
/// expression constraints: `:id`, `:id(\d+)`.
final RegExp _parameterRegExp = RegExp(r':(\w+)(\((?:\\.|[^\\()])+\))?');

/// Helpers for working with route path templates and URLs.
///
/// These operate on *templates* (`/products/:id`) unless a method says
/// otherwise. Nothing here mutates router state.
abstract final class RouteUtils {
  /// The names of every path parameter declared in [template], in order and
  /// without duplicates.
  ///
  /// ```dart
  /// RouteUtils.parameterNames('/orders/:orderId/items/:itemId');
  /// // ['orderId', 'itemId']
  /// RouteUtils.parameterNames(r'/users/:id(\d+)');
  /// // ['id']
  /// ```
  static List<String> parameterNames(String template) {
    final seen = <String>{};
    for (final match in _parameterRegExp.allMatches(template)) {
      seen.add(match.group(1)!);
    }
    return seen.toList(growable: false);
  }

  /// Extracts parameter values by matching a concrete [location] against
  /// [template].
  ///
  /// Returns `null` when the location does not match the template, so a failed
  /// match is distinguishable from a template with no parameters.
  ///
  /// ```dart
  /// RouteUtils.extractParams('/products/:id', '/products/42');
  /// // {'id': '42'}
  /// RouteUtils.extractParams('/products/:id', '/orders/42');
  /// // null
  /// ```
  static Map<String, String>? extractParams(String template, String location) {
    final names = <String>[];
    final buffer = StringBuffer('^');
    var start = 0;
    for (final match in _parameterRegExp.allMatches(template)) {
      if (match.start > start) {
        buffer.write(RegExp.escape(template.substring(start, match.start)));
      }
      final name = match.group(1)!;
      final constraint = match.group(2);
      buffer.write(
        constraint == null ? '(?<$name>[^/]+)' : '(?<$name>$constraint)',
      );
      names.add(name);
      start = match.end;
    }
    if (start < template.length) {
      buffer.write(RegExp.escape(template.substring(start)));
    }
    buffer.write(r'$');

    final path = Uri.parse(location).path;
    final RegExpMatch? matched;
    try {
      matched = RegExp(buffer.toString()).firstMatch(path);
    } on FormatException {
      return null;
    }
    if (matched == null) return null;
    return <String, String>{
      for (final name in names)
        name: Uri.decodeComponent(matched.namedGroup(name) ?? ''),
    };
  }

  /// Whether [template] is a well-formed route path template.
  ///
  /// Requires a leading `/` and rejects whitespace, `//`, and parameter names
  /// that are not Dart-style identifiers. Parameter syntax (`:`) and regex
  /// constraints are allowed — 1.x rejected every parameterised path, since
  /// its "invalid characters" set contained both `:` and `?`.
  static bool isValidTemplate(String template) {
    if (template.isEmpty || !template.startsWith('/')) return false;
    // Regex constraints may legitimately contain `?`, `#` or `//`
    // (`:id(\\d?)`, `:hex(#[0-9a-f]{6})`), so the structural checks run on the
    // template with its constraint groups removed.
    final structural = template.replaceAllMapped(
      _parameterRegExp,
      (match) => ':${match.group(1)}',
    );
    if (structural.contains('//')) return false;
    if (structural.contains(RegExp(r'\s'))) return false;
    if (structural.contains('?') || structural.contains('#')) return false;

    // Every `:` must open a well-formed parameter.
    var cursor = 0;
    while (true) {
      final colon = template.indexOf(':', cursor);
      if (colon < 0) break;
      final match = _parameterRegExp.matchAsPrefix(template, colon);
      if (match == null) return false;
      cursor = match.end;
    }
    return true;
  }

  /// Whether [path] is a well-formed route path template.
  ///
  /// Retained for source compatibility; prefer [isValidTemplate], which says
  /// what it validates.
  static bool isValidPath(String path) => isValidTemplate(path);

  /// The literal (non-parameter) segments of [template], for breadcrumbs.
  ///
  /// ```dart
  /// RouteUtils.breadcrumbSegments('/shop/products/:id/reviews');
  /// // ['shop', 'products', 'reviews']
  /// ```
  static List<String> breadcrumbSegments(String template) => template
      .split('/')
      .where((segment) => segment.isNotEmpty && !segment.startsWith(':'))
      .toList(growable: false);

  /// The cumulative sub-paths of [template], for building breadcrumb links.
  ///
  /// ```dart
  /// RouteUtils.breadcrumbTrail('/shop/products/:id');
  /// // ['/shop', '/shop/products', '/shop/products/:id']
  /// ```
  static List<String> breadcrumbTrail(String template) {
    final trail = <String>[];
    var current = '';
    for (final segment in template.split('/')) {
      if (segment.isEmpty) continue;
      current = '$current/$segment';
      trail.add(current);
    }
    return trail;
  }

  /// Normalises [path]: collapses repeated slashes and drops a trailing one.
  ///
  /// Case is preserved. go_router treats URLs as case-sensitive since 15.0.0,
  /// so lower-casing a path — as 1.x did — changes which route it matches.
  static String normalizePath(String path) {
    if (path.isEmpty) return path;
    // Split off the query and fragment by hand rather than with `Uri.parse`:
    // a location beginning `//` parses as a scheme-relative URI, and the first
    // segment silently becomes the authority — `//products/42` would lose
    // `products`.
    var rest = path;
    var suffix = '';
    final cut = rest.indexOf(RegExp('[?#]'));
    if (cut >= 0) {
      suffix = rest.substring(cut);
      rest = rest.substring(0, cut);
    }
    var normalized = rest.replaceAll(RegExp(r'/{2,}'), '/');
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return '$normalized$suffix';
  }

  /// Parses a query string into a map, keeping only the last value for a
  /// repeated key.
  ///
  /// Handles values containing `=`, and valueless flags (which map to `''`).
  /// Use [parseQueryStringAll] to keep every value.
  static Map<String, String> parseQueryString(String query) =>
      Uri.splitQueryString(_stripLeadingQuestionMark(query));

  /// Parses a query string into a map keeping every value for each key.
  static Map<String, List<String>> parseQueryStringAll(String query) =>
      Uri(query: _stripLeadingQuestionMark(query)).queryParametersAll;

  static String _stripLeadingQuestionMark(String query) =>
      query.startsWith('?') ? query.substring(1) : query;

  /// Builds a query string from [params].
  ///
  /// Values may be a `String`, anything with a sensible `toString`, or an
  /// `Iterable` — which expands to a repeated key. Nulls are dropped.
  static String buildQueryString(Map<String, dynamic> params) {
    final normalized = <String, dynamic>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is Iterable) {
        final items = <String>[
          for (final item in value)
            if (item != null) item.toString(),
        ];
        if (items.isNotEmpty) normalized[entry.key] = items;
      } else {
        normalized[entry.key] = value.toString();
      }
    }
    if (normalized.isEmpty) return '';
    return Uri(queryParameters: normalized).query;
  }

  /// Whether [link] is an absolute URI with a scheme, as a deep link must be.
  static bool isValidDeepLink(String link) {
    final uri = Uri.tryParse(link);
    return uri != null && uri.isAbsolute && uri.hasScheme;
  }

  /// How similar a path template and a location are, from 0.0 to 1.0.
  ///
  /// Used to suggest "did you mean…?" for an unmatched location. Segments are
  /// compared position by position against the longer of the two; a `:param`
  /// segment on either side matches any value, and a near-miss literal (a typo
  /// such as `prodcuts` for `products`) earns partial credit.
  static double calculateRouteSimilarity(String a, String b) {
    if (a == b) return 1;
    final left = Uri.parse(a).path.split('/').where((s) => s.isNotEmpty);
    final right = Uri.parse(b).path.split('/').where((s) => s.isNotEmpty);
    final l = left.toList();
    final r = right.toList();
    final longest = l.length > r.length ? l.length : r.length;
    if (longest == 0) return 0;
    final shortest = l.length < r.length ? l.length : r.length;
    var score = 0.0;
    for (var i = 0; i < shortest; i++) {
      if (l[i].startsWith(':') || r[i].startsWith(':') || l[i] == r[i]) {
        score += 1;
      } else {
        score += _segmentSimilarity(l[i], r[i]);
      }
    }
    return score / longest;
  }

  /// 1 − normalised Levenshtein distance, counted only when the two segments
  /// are close enough to plausibly be a typo of one another.
  static double _segmentSimilarity(String a, String b) {
    final longest = a.length > b.length ? a.length : b.length;
    if (longest == 0) return 1;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        var best = deletion < insertion ? deletion : insertion;
        if (substitution < best) best = substitution;
        current[j] = best;
      }
      previous = current;
    }
    final similarity = 1 - previous[b.length] / longest;
    return similarity >= 0.6 ? similarity : 0;
  }

  /// Logs a navigation, in debug builds only.
  static void logRouteNavigation(
    String from,
    String to, {
    Map<String, dynamic>? metadata,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'Route navigation: ${jsonEncode({'from': from, 'to': to, 'metadata': ?metadata})}',
    );
  }

  /// Runs [operation], logging how long it took in debug builds.
  static T measureRoutePerformance<T>(String label, T Function() operation) {
    if (!kDebugMode) return operation();
    final stopwatch = Stopwatch()..start();
    try {
      return operation();
    } finally {
      stopwatch.stop();
      debugPrint('Route "$label" took ${stopwatch.elapsedMilliseconds}ms');
    }
  }
}

/// The outcome of validating a set of routes.
class RouteValidationResult {
  /// Creates a validation result.
  const RouteValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// A result with no problems.
  factory RouteValidationResult.valid({List<String> warnings = const []}) =>
      RouteValidationResult(isValid: true, warnings: warnings);

  /// A result carrying [errors].
  factory RouteValidationResult.invalid(
    List<String> errors, [
    List<String>? warnings,
  ]) => RouteValidationResult(
    isValid: false,
    errors: errors,
    warnings: warnings ?? const [],
  );

  /// Whether validation passed.
  final bool isValid;

  /// Problems that make the route set unusable.
  final List<String> errors;

  /// Problems worth fixing that do not break routing.
  final List<String> warnings;

  @override
  String toString() => isValid
      ? 'RouteValidationResult(valid${warnings.isEmpty ? '' : ', ${warnings.length} warnings'})'
      : 'RouteValidationResult(invalid: ${errors.join('; ')})';
}

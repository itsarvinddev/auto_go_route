/// The path-parameter grammar go_router uses, including regular expression
/// constraints.
///
/// Byte-identical to `patternToRegExp`'s pattern in go_router's
/// `path_utils.dart`. Any divergence here means the parameters this generator
/// emits helpers for are not the ones go_router will bind.
final RegExp parameterRegExp = RegExp(r':(\w+)(\((?:\\.|[^\\()])+\))?');

/// A Dart identifier that can safely be interpolated into generated code.
final RegExp dartIdentifierRegExp = RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$');

/// Helpers shared by the generator's analysis and emission phases.
abstract final class GeneratorUtils {
  /// The path parameter names declared in [template], in order and without
  /// duplicates.
  static List<String> pathParameterNames(String template) {
    final seen = <String>{};
    for (final match in parameterRegExp.allMatches(template)) {
      seen.add(match.group(1)!);
    }
    return seen.toList(growable: false);
  }

  /// Every path parameter name in [template], including repeats.
  ///
  /// Used to report a duplicated parameter, which would otherwise emit a
  /// method with two same-named arguments and an unparseable output file.
  static List<String> allPathParameterNames(String template) => [
    for (final match in parameterRegExp.allMatches(template)) match.group(1)!,
  ];

  /// Whether [template] declares an optional path parameter (`:id?`).
  ///
  /// go_router has no such thing, so this is rejected with a build error
  /// pointing at the two things that do work.
  static bool hasOptionalPathParameter(String template) {
    for (final match in parameterRegExp.allMatches(template)) {
      if (match.end < template.length && template[match.end] == '?') {
        return true;
      }
    }
    return false;
  }

  /// Joins a parent and child path pattern the way go_router's
  /// `concatenatePaths` does: split on `/`, drop empty segments, re-join from
  /// the root.
  ///
  /// Matching that exactly is what makes the generated URL the URL go_router
  /// matches. It also means a child path written absolutely (`/details`) is
  /// concatenated rather than replacing the parent — see
  /// [childPathLooksAbsolute].
  static String concatenatePaths(String parent, String child) {
    final segments = <String>[
      ...parent.split('/'),
      ...child.split('/'),
    ].where((segment) => segment.isNotEmpty);
    return '/${segments.join('/')}';
  }

  /// Whether [childPath] was written as though it were absolute while its
  /// parent contributes a real prefix.
  ///
  /// Not an error — go_router concatenates regardless — but worth warning
  /// about, because the author probably expected the leading slash to mean
  /// "from the root".
  static bool childPathLooksAbsolute(String childPath, String parentTemplate) =>
      childPath.startsWith('/') &&
      parentTemplate.isNotEmpty &&
      parentTemplate != '/';

  /// `input` with its first character lower-cased.
  static String toLowerCamelCase(String input) =>
      input.isEmpty ? '' : input[0].toLowerCase() + input.substring(1);

  /// `input` with its first character upper-cased.
  ///
  /// Only the first character changes, so an acronym keeps its shape:
  /// `httpRoute` becomes `HttpRoute`, and `HTTPRoute` stays `HTTPRoute`.
  static String toUpperCamelCase(String input) =>
      input.isEmpty ? '' : input[0].toUpperCase() + input.substring(1);

  /// Whether [value] can be interpolated into generated code as an identifier.
  static bool isDartIdentifier(String value) =>
      dartIdentifierRegExp.hasMatch(value);

  /// Whether [reference] is a valid reference to a function, constructor or
  /// static member — `foo`, `Foo.new`, `Foo.bar`, `prefix.foo`.
  static bool isFunctionReference(String reference) {
    if (reference.isEmpty) return false;
    final parts = reference.split('.');
    if (parts.length > 3) return false;
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part == 'new' && i > 0) continue;
      if (!isDartIdentifier(part)) return false;
    }
    return true;
  }

  /// The leading identifier of a function [reference], the part that has to
  /// resolve in the router library's scope.
  static String rootIdentifierOf(String reference) =>
      reference.split('.').first;

  /// [value] as a single-quoted Dart string literal.
  static String stringLiteral(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return "'$escaped'";
  }

  /// A route's declared path as a name slug, for the rare route that supplies
  /// neither a `name` nor a usable class name.
  static String slugFromPath(String path) {
    final segments = path
        .split('/')
        .where((s) => s.isNotEmpty && !s.startsWith(':'))
        .map((s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_'))
        .where((s) => s.isNotEmpty);
    if (segments.isEmpty) return 'root';
    final joined = segments.join('_').toLowerCase();
    return dartIdentifierRegExp.hasMatch(joined) ? joined : 'root';
  }
}

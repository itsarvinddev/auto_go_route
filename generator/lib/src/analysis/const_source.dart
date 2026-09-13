import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';
import '../errors.dart';

/// Re-emits a compile-time constant as Dart source.
///
/// Needed for `@AutoGoRoute(metadata: {...})`: the annotation's value reaches
/// the generator as a [DartObject], and the generated `GoRoute(metadata: …)`
/// argument has to be written back out as source. Only values that can be
/// re-emitted are accepted; anything else is a build error naming the key,
/// because an arbitrary object's `DartObject` has no source form and would
/// otherwise be emitted as something unparseable.
abstract final class ConstSource {
  /// Renders [object] as Dart source, or throws
  /// [InvalidGenerationSourceError] describing why it cannot be.
  ///
  /// [context] names the annotation field being read, and [element] anchors
  /// the error at the user's annotation.
  static String render(
    DartObject? object, {
    required String context,
    Element? element,
  }) {
    if (object == null || object.isNull) return 'null';

    final stringValue = object.toStringValue();
    if (stringValue != null) return _stringLiteral(stringValue);

    final boolValue = object.toBoolValue();
    if (boolValue != null) return boolValue.toString();

    final intValue = object.toIntValue();
    if (intValue != null) return intValue.toString();

    final doubleValue = object.toDoubleValue();
    if (doubleValue != null) return _doubleLiteral(doubleValue);

    final listValue = object.toListValue();
    if (listValue != null) {
      final items = listValue.map(
        (item) => render(item, context: context, element: element),
      );
      return '[${items.join(', ')}]';
    }

    final setValue = object.toSetValue();
    if (setValue != null) {
      final items = setValue.map(
        (item) => render(item, context: context, element: element),
      );
      return '{${items.join(', ')}}';
    }

    final mapValue = object.toMapValue();
    if (mapValue != null) {
      final entries = mapValue.entries.map((entry) {
        final key = render(entry.key, context: context, element: element);
        final value = render(entry.value, context: context, element: element);
        return '$key: $value';
      });
      return '{${entries.join(', ')}}';
    }

    final enumSource = _enumSource(object);
    if (enumSource != null) return enumSource;

    throw routeError(
      'Cannot re-emit the value of `$context` as source. Supported values are '
      'null, String, int, double, bool, enum values, and lists, sets and maps '
      'of those. Got a value of type '
      '${object.type?.getDisplayString() ?? 'unknown'}.',
      element: element,
      todo:
          'Replace the value with a compile-time constant of a supported type, '
          'or pass the object at runtime instead of through the annotation.',
    );
  }

  /// `EnumType.valueName` for an enum constant, or `null` if [object] is not
  /// one.
  ///
  /// The enum type has to be visible from the library holding
  /// `@AutoGoRouteBase`, since the generated file is a `part` of it.
  static String? _enumSource(DartObject object) {
    final type = object.type;
    final element = type?.element;
    if (element is! EnumElement) return null;
    final name = object.getField('_name')?.toStringValue();
    if (name == null) return null;
    final typeName = element.name;
    if (typeName == null || typeName.isEmpty) return null;
    return '$typeName.$name';
  }

  static String _stringLiteral(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return "'$escaped'";
  }

  /// A double literal that always round-trips.
  ///
  /// `toString()` already yields `1.0` rather than `1` for whole doubles, but
  /// infinities and NaN have no literal form and must be spelled as `double`
  /// constants.
  static String _doubleLiteral(double value) {
    if (value.isNaN) return 'double.nan';
    if (value == double.infinity) return 'double.infinity';
    if (value == double.negativeInfinity) return 'double.negativeInfinity';
    return value.toString();
  }
}

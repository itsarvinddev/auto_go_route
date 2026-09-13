import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import '../model/route_model.dart';
import '../errors.dart';

const _pathParamChecker = TypeChecker.typeNamedLiterally(
  'PathParam',
  inPackage: 'auto_go_route',
);
const _queryParamChecker = TypeChecker.typeNamedLiterally(
  'QueryParam',
  inPackage: 'auto_go_route',
);
const _routeExtraChecker = TypeChecker.typeNamedLiterally(
  'RouteExtra',
  inPackage: 'auto_go_route',
);
const _routeIgnoreChecker = TypeChecker.typeNamedLiterally(
  'RouteIgnore',
  inPackage: 'auto_go_route',
);

/// Resolves a widget's constructor parameters into route parameters.
///
/// Classification order, highest priority first:
///
/// 1. `key` and a shell's child slot are skipped.
/// 2. `@RouteIgnore` skips the parameter entirely.
/// 3. `@PathParam`, `@QueryParam` and `@RouteExtra` are honoured verbatim.
/// 4. A name appearing in the route's *resolved* path is a path parameter.
/// 5. A URL-representable type is a query parameter.
/// 6. Anything else travels in `extra`.
///
/// This replaces 1.x's `typeName.startsWith('String')` check, which classified
/// `StringBuffer` as a path parameter, sent `num`, `DateTime`, enums and
/// `List<T>` to `extra` without asking, and read *every* simple-typed
/// parameter out of the URL whether or not the route declared it.
abstract final class ParamClassifier {
  /// Classifies [constructor]'s parameters for a route.
  ///
  /// [pathParameterNames] are the names declared in the route's resolved path
  /// template. [routeLabel] appears in error messages.
  static List<ParamInfo> classify({
    required ConstructorElement constructor,
    required Set<String> pathParameterNames,
    required String routeLabel,
    required Element errorElement,
    String? shellChildParamName,
  }) {
    final result = <ParamInfo>[];
    var extraCount = 0;

    for (final param in constructor.formalParameters) {
      final name = param.displayName;
      if (name == 'key') continue;
      if (shellChildParamName != null && name == shellChildParamName) continue;
      if (_hasMarker(param, _routeIgnoreChecker)) {
        if (param.isPositional) {
          throw routeError(
            '`$routeLabel` marks the positional parameter `$name` with '
            '@RouteIgnore. Skipping a positional argument would shift every '
            'later one, so only named parameters can be ignored.',
            element: errorElement,
            todo: 'Make `$name` a named parameter.',
          );
        }
        if (param.isRequired && !param.hasDefaultValue) {
          throw routeError(
            '`$routeLabel` marks `$name` with @RouteIgnore, but the '
            'constructor requires it and gives it no default, so the '
            'generated builder cannot construct the widget.',
            element: errorElement,
            todo:
                'Make `$name` nullable, give it a default value, or drop '
                '@RouteIgnore.',
          );
        }
        continue;
      }

      // The generated helpers declare `queries`, `fragment` and `extra`
      // themselves, so a route parameter of the same name produced a method
      // with two identically named arguments — a file that does not compile.
      if (const {'queries', 'fragment', 'extra'}.contains(name)) {
        throw routeError(
          '`$routeLabel` has a constructor parameter named `$name`, which the '
          'generated `pathWith`/`goTo…` helpers already use for their own '
          'argument.',
          element: errorElement,
          todo:
              'Rename the parameter. To keep `$name` as the name in the URL, '
              "annotate the renamed field with `@QueryParam('$name')`.",
        );
      }

      final type = param.type;
      final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
      final explicitPath = _readMarker(param, _pathParamChecker);
      final explicitQuery = _readMarker(param, _queryParamChecker);
      final explicitExtra = _hasMarker(param, _routeExtraChecker);

      final markers = [
        if (explicitPath != null) '@PathParam',
        if (explicitQuery != null) '@QueryParam',
        if (explicitExtra) '@RouteExtra',
      ];
      if (markers.length > 1) {
        throw routeError(
          '`$routeLabel` marks `$name` with ${markers.join(' and ')}. '
          'A parameter has exactly one source.',
          element: errorElement,
        );
      }

      final classified = _kindOf(type);
      final ParamSource source;
      final String wireName;

      if (explicitExtra) {
        source = ParamSource.extra;
        wireName = name;
      } else if (explicitPath != null) {
        source = ParamSource.path;
        wireName = explicitPath.isEmpty ? name : explicitPath;
      } else if (explicitQuery != null) {
        source = ParamSource.query;
        wireName = explicitQuery.isEmpty ? name : explicitQuery;
      } else if (pathParameterNames.contains(name)) {
        source = ParamSource.path;
        wireName = name;
      } else if (classified.kind != ParamKind.opaque) {
        source = ParamSource.query;
        wireName = name;
      } else {
        source = ParamSource.extra;
        wireName = name;
      }

      if (source == ParamSource.path &&
          !pathParameterNames.contains(wireName)) {
        throw routeError(
          '`$routeLabel` reads `$name` from the path as `:$wireName`, but the '
          "route's path declares no such parameter. Declared: "
          '${pathParameterNames.isEmpty ? '(none)' : pathParameterNames.map((p) => ':$p').join(', ')}.',
          element: errorElement,
          todo:
              'Add `:$wireName` to the path, or annotate `$name` with '
              '@QueryParam to read it from the query string.',
        );
      }

      if (source == ParamSource.path && classified.kind == ParamKind.list) {
        throw routeError(
          '`$routeLabel` declares `$name` as ${type.getDisplayString()} and '
          'reads it from the path. A path segment holds one value; lists are '
          'only supported as repeated query parameters.',
          element: errorElement,
          todo: 'Annotate `$name` with @QueryParam, or use a single value.',
        );
      }

      if (source == ParamSource.extra) {
        extraCount++;
        if (extraCount > 1) {
          throw routeError(
            '`$routeLabel` needs more than one value from `state.extra`, but '
            'a route carries exactly one `extra` object. Offending '
            'parameter: `$name` (${type.getDisplayString()}).',
            element: errorElement,
            todo:
                'Keep one @RouteExtra parameter and fold the others into it, '
                'or carry the extra values in the path or query string.',
          );
        }
      }

      if (source == ParamSource.query &&
          param.isRequired &&
          !isNullable &&
          !param.hasDefaultValue) {
        throw routeError(
          '`$routeLabel` requires `$name` (${type.getDisplayString()}) but '
          'reads it from the query string, which may be absent — the '
          'generated builder would have nothing to pass.',
          element: errorElement,
          todo:
              'Make `$name` nullable, give it a default value, or add '
              '`:$name` to the route path.',
        );
      }

      result.add(
        ParamInfo(
          dartName: name,
          wireName: wireName,
          typeSource: type.getDisplayString(),
          kind: classified.kind,
          source: source,
          isNullable: isNullable,
          isNamed: param.isNamed,
          isRequired: param.isRequired,
          hasDefault: param.hasDefaultValue,
          defaultValueCode: param.defaultValueCode,
          enumTypeSource: classified.enumTypeSource,
          elementKind: classified.elementKind,
          elementTypeSource: classified.elementTypeSource,
        ),
      );
    }

    return result;
  }

  /// Every element a marker annotation could be written on for [param].
  ///
  /// A widget almost always declares `const Page({required this.id})` and
  /// annotates the *field*, not the constructor parameter — so reading
  /// annotations from the parameter alone silently ignores
  /// `@QueryParam('feature-disabled') final bool? featureDisabled;`.
  static Iterable<Element> _markerTargets(FormalParameterElement param) {
    final targets = <Element>[param];
    if (param is FieldFormalParameterElement) {
      final field = param.field;
      if (field != null) targets.add(field);
    }
    return targets;
  }

  static bool _hasMarker(FormalParameterElement param, TypeChecker checker) =>
      _markerTargets(param).any(checker.hasAnnotationOfExact);

  static String? _readMarker(
    FormalParameterElement param,
    TypeChecker checker,
  ) {
    for (final target in _markerTargets(param)) {
      final annotation = checker.firstAnnotationOfExact(target);
      if (annotation != null) {
        return annotation.getField('name')?.toStringValue() ?? '';
      }
    }
    return null;
  }

  static _Classified _kindOf(DartType type) {
    if (type.isDartCoreString) return const _Classified(ParamKind.string);
    if (type.isDartCoreInt) return const _Classified(ParamKind.int);
    if (type.isDartCoreDouble) return const _Classified(ParamKind.double);
    if (type.isDartCoreNum) return const _Classified(ParamKind.num);
    if (type.isDartCoreBool) return const _Classified(ParamKind.bool);

    final element = type.element;
    if (element is EnumElement) {
      return _Classified(
        ParamKind.enumeration,
        enumTypeSource: element.name ?? type.getDisplayString(),
      );
    }

    if (_isCoreClass(element, 'BigInt')) {
      return const _Classified(ParamKind.bigInt);
    }
    if (_isCoreClass(element, 'DateTime')) {
      return const _Classified(ParamKind.dateTime);
    }
    if (_isCoreClass(element, 'Uri')) {
      return const _Classified(ParamKind.uri);
    }

    if (type.isDartCoreList && type is InterfaceType) {
      final args = type.typeArguments;
      if (args.length == 1) {
        final inner = _kindOf(args.first);
        // Only a list of URL-representable scalars is a query parameter; a
        // `List<SomeModel>` still has to travel in `extra`.
        if (inner.kind != ParamKind.opaque && inner.kind != ParamKind.list) {
          return _Classified(
            ParamKind.list,
            elementKind: inner.kind,
            elementTypeSource: args.first.getDisplayString(),
            enumTypeSource: inner.enumTypeSource,
          );
        }
      }
    }

    return const _Classified(ParamKind.opaque);
  }

  static bool _isCoreClass(Element? element, String name) =>
      element != null &&
      element.name == name &&
      element.library?.uri.toString() == 'dart:core';
}

class _Classified {
  const _Classified(
    this.kind, {
    this.enumTypeSource,
    this.elementKind,
    this.elementTypeSource,
  });

  final ParamKind kind;
  final String? enumTypeSource;
  final ParamKind? elementKind;
  final String? elementTypeSource;
}

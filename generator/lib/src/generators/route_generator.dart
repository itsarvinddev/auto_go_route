// generator/lib/src/generators/route_generator.dart

import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

import '../utils/generator_utils.dart';

const autoGoRouteBaseChecker = TypeChecker.fromUrl(
    'package:auto_go_route/src/annotations/auto_go_route.dart#AutoGoRouteBase');
const autoGoRouteChecker = TypeChecker.fromUrl(
    'package:auto_go_route/src/annotations/auto_go_route.dart#AutoGoRoute');
const autoGoRouteShellChecker = TypeChecker.fromUrl(
    'package:auto_go_route/src/annotations/auto_go_route.dart#AutoGoRouteShell');

class AutoGoRouteGenerator extends Generator {
  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final annotatedElements = library.annotatedWith(autoGoRouteBaseChecker);

    if (annotatedElements.isEmpty) return null;
    if (annotatedElements.length > 1) {
      throw InvalidGenerationSourceError(
        'Only one @AutoGoRouteBase annotation is allowed per library',
      );
    }

    final annotatedElement = annotatedElements.first;
    final element = annotatedElement.element;
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@AutoGoRouteBase can only be applied to classes',
        element: element,
      );
    }

    try {
      final allRoutes = await _findAllRoutes(buildStep);
      final allShells = await _findAllShells(buildStep);

      if (allRoutes.isEmpty && allShells.isEmpty) {
        throw InvalidGenerationSourceError(
          'No @AutoGoRoute or @AutoGoRouteShell annotated classes found in the project',
          element: element,
        );
      }

      _validateRouteNames(allRoutes, element);
      final baseInfo = _extractBaseInfo(element, annotatedElement.annotation);
      final generatedCode =
          await _generateRouteBase(baseInfo, allRoutes, allShells);

      return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
          .format(generatedCode);
    } catch (e, st) {
      throw InvalidGenerationSourceError(
        'Failed to generate routes for ${element.name}: $e\n$st',
        element: element,
      );
    }
  }

  void _validateRouteNames(List<RouteInfo> routes, Element element) {
    final seen = <String>{};
    for (final route in routes) {
      final name = route.name ?? _toLowerCamelCase(route.className);
      if (!seen.add(name)) {
        throw InvalidGenerationSourceError(
          'Duplicate route name: $name. Route names must be unique.',
          element: element,
        );
      }
    }
  }

  Future<List<T>> _findAllAnnotatedElements<T>(
    BuildStep buildStep,
    TypeChecker checker,
    T Function(ClassElement, ConstantReader) extractor,
  ) async {
    final results = <T>[];
    await for (final input in buildStep.findAssets(Glob('lib/**/*.dart'))) {
      try {
        if (!await buildStep.resolver.isLibrary(input)) continue;
        final lib = await buildStep.resolver.libraryFor(input);
        final reader = LibraryReader(lib);
        for (final annotatedElement in reader.annotatedWith(checker)) {
          final element = annotatedElement.element;
          if (element is ClassElement) {
            results.add(extractor(element, annotatedElement.annotation));
          }
        }
      } catch (e) {
        log.info('Warning: Could not resolve library ${input.path}. Error: $e');
      }
    }
    return results;
  }

  Future<List<RouteInfo>> _findAllRoutes(BuildStep buildStep) =>
      _findAllAnnotatedElements<RouteInfo>(
        buildStep,
        autoGoRouteChecker,
        _extractRouteInfo,
      );

  Future<List<ShellInfo>> _findAllShells(BuildStep buildStep) =>
      _findAllAnnotatedElements<ShellInfo>(
        buildStep,
        autoGoRouteShellChecker,
        _extractShellInfo,
      );

  RouteBaseInfo _extractBaseInfo(
      ClassElement element, ConstantReader annotation) {
    return RouteBaseInfo(
      className: element.name,
      initialLocation:
          annotation.read('initialLocation').literalValue as String?,
      errorBuilder: annotation.read('errorBuilder').literalValue as String?,
      redirect: annotation.read('redirect').literalValue as String?,
    );
  }

  RouteInfo _extractRouteInfo(ClassElement element, ConstantReader annotation) {
    final path = annotation.read('path').stringValue;
    final name = annotation.read('name').isNull
        ? _toLowerCamelCase(element.name)
        : annotation.read('name').stringValue;

    final parent = annotation.read('parent').isNull
        ? null
        : annotation.read('parent').typeValue.element?.name;

    final constructor = element.unnamedConstructor;
    final params = constructor?.parameters ?? [];
    final pathParams = GeneratorUtils.extractParametersFromPath(path);

    final requiredParamSet = pathParams.required.toSet();
    final constructorParamSet = params.map((e) => e.name).toSet();
    final missing = requiredParamSet.difference(constructorParamSet);
    if (missing.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Missing constructor parameters for path: ${missing.join(', ')}',
        element: element,
      );
    }

    return RouteInfo(
      className: element.name,
      path: path,
      name: name,
      description: annotation.read('description').literalValue as String?,
      middleware: annotation
          .read('middleware')
          .listValue
          .map((e) => e.toStringValue()!)
          .toList(),
      constructorParams: params,
      requiredParams: pathParams.required,
      optionalParams: pathParams.optional,
      importPath: _getImportPath(element),
      parent: parent,
      order: annotation.read('order').isNull
          ? null
          : annotation.read('order').intValue,
    );
  }

  ShellInfo _extractShellInfo(ClassElement element, ConstantReader annotation) {
    return ShellInfo(
      className: element.name,
      path: annotation.read('path').stringValue,
      name: annotation.read('name').isNull
          ? null
          : annotation.read('name').stringValue,
      description: annotation.read('description').isNull
          ? null
          : annotation.read('description').stringValue,
      navigatorKey: annotation.read('navigatorKey').isNull
          ? null
          : annotation.read('navigatorKey').stringValue,
      importPath: _getImportPath(element),
      parent: annotation.read('parent').isNull
          ? null
          : annotation.read('parent').typeValue.element?.name,
      isStateful: annotation.read('isStateful').boolValue,
      initialRoute: annotation.read('initialRoute').isNull
          ? null
          : annotation.read('initialRoute').stringValue,
    );
  }

  String? _getImportPath(ClassElement element) =>
      element.library.source.uri.toString();

  String _toLowerCamelCase(String input) =>
      input.isEmpty ? '' : input[0].toLowerCase() + input.substring(1);

  Future<String> _generateRouteBase(
    RouteBaseInfo baseInfo,
    List<RouteInfo> routes,
    List<ShellInfo> shells,
  ) async {
    final allWidgetClassNames = {
      ...routes.map((r) => r.className),
      ...shells.map((s) => s.className)
    };
    final typeDefs = allWidgetClassNames.map((className) {
      return TypeDef((b) => b
        ..name = '_RouteRef$className'
        ..definition = refer(className));
    });

    final library = Library((b) {
      b.ignoreForFile.add('unused_element');
      b.body.addAll([
        ...typeDefs,
        _generateBaseClass(baseInfo, routes, shells),
        ...routes.map((r) => _generateRouteClass(r, [...routes, ...shells])),
        ...shells.map(_generateShellClass),
      ]);
    });

    return library
        .accept(
          DartEmitter(useNullSafetySyntax: true, orderDirectives: true),
        )
        .toString();
  }

  Class _generateBaseClass(
    RouteBaseInfo baseInfo,
    List<RouteInfo> routes,
    List<ShellInfo> shells,
  ) {
    return Class((b) {
      b.name = '_\$${baseInfo.className}';
      b.abstract = true;
      b.methods.addAll([
        Method((m) => m
          ..name = 'allRoutes'
          ..returns = refer('List<RoutePaths>')
          ..type = MethodType.getter
          ..body = Code(
              'return [${routes.map((r) => '${_toLowerCamelCase(r.className)}Route').join(', ')}];')),
        Method((m) => m
          ..name = 'allShells'
          ..returns = refer('List<ShellRoutePaths>')
          ..type = MethodType.getter
          ..body = Code(
              'return [${shells.map((s) => '${_toLowerCamelCase(s.className)}Route').join(', ')}];')),
        _generateBuildNestedRoutesMethod(routes, shells),
        _generateBuildRouterMethod(baseInfo),
        ...routes.map((r) => Method((m) => m
          ..name = '${_toLowerCamelCase(r.className)}Route'
          ..type = MethodType.getter
          ..returns = refer('${r.className}Route')
          ..body = Code('return ${r.className}Route();'))),
        ...shells.map((s) => Method((m) => m
          ..name = '${_toLowerCamelCase(s.className)}Route'
          ..type = MethodType.getter
          ..returns = refer('${s.className}Route')
          ..body = Code('return ${s.className}Route();'))),
      ]);
    });
  }

  Method _generateBuildRouterMethod(RouteBaseInfo baseInfo) {
    final errorBuilder = baseInfo.errorBuilder;
    final errorBuilderCode = errorBuilder != null
        ? 'errorBuilder: (context, state) => $errorBuilder(error: state.error),'
        : '';

    return Method((b) {
      b.name = 'buildRouter';
      b.returns = refer('GoRouter');
      b.optionalParameters.add(Parameter((p) => p
        ..name = 'navigatorKey'
        ..type = refer('GlobalKey<NavigatorState>?')));
      b.body = Code('''
        return GoRouter(
          ${baseInfo.initialLocation != null ? "initialLocation: '${baseInfo.initialLocation}'," : ""}
          ${baseInfo.redirect != null ? "redirect: ${baseInfo.redirect}," : ""}
          $errorBuilderCode
          navigatorKey: navigatorKey,
          routes: _buildNestedRoutes(),
        );
      ''');
    });
  }

  Class _generateRouteClass(RouteInfo route, List<dynamic> allInfos) {
    return Class((b) {
      b.name = '${route.className}Route';
      b.extend =
          refer(route.parent != null ? 'NestedRoutePaths' : 'RoutePaths');
      b.constructors.add(Constructor((c) {
        c.initializers.add(Code(_generateRouteSuperCall(route, allInfos)));
      }));
    });
  }

  String _generateRouteSuperCall(RouteInfo r, List<dynamic> all) {
    final parentInfo = r.parent != null
        ? all.firstWhere((e) => e.className == r.parent)
        : null;
    final buffer = StringBuffer('super(');
    if (parentInfo != null) buffer.writeln("parentPath: '${parentInfo.path}',");
    buffer.writeln("path: '${r.path}',");
    if (r.name != null) buffer.writeln("name: '${r.name}',");
    if (r.description != null) {
      buffer.writeln("description: r'''${r.description}''',");
    }
    if (r.middleware.isNotEmpty) {
      buffer.writeln("middleware: const [${r.middleware.join(', ')}],");
    }
    buffer.writeln("builder: ${_generateBuilderFunction(r)},");
    buffer.writeln(')');
    return buffer.toString();
  }

  String _generateBuilderFunction(RouteInfo r) {
    final buffer = StringBuffer('(context, state) => ${r.className}(');
    final args = r.constructorParams.where((p) => p.name != 'key').map((p) {
      final type = p.type.toString().replaceAll('?', '');
      final access = "state.getParam<$type>('${p.name}')";
      return p.isNamed ? '${p.name}: $access' : access;
    }).join(', ');
    buffer.write(args);
    buffer.write(')');
    return buffer.toString();
  }

  Class _generateShellClass(ShellInfo shell) {
    return Class((b) {
      b.name = '${shell.className}Route';
      b.extend = refer('ShellRoutePaths');
      b.constructors.add(Constructor((c) {
        c.initializers.add(Code(_generateShellSuperCall(shell)));
      }));
    });
  }

  String _generateShellSuperCall(ShellInfo shell) {
    final builderParam = shell.isStateful
        ? 'navigationShell: child as StatefulNavigationShell'
        : 'child: child';

    return '''
      super(
        path: '${shell.path}',
        ${shell.name != null ? "name: '${shell.name}'," : ''}
        ${shell.description != null ? "description: r'''${shell.description}'''," : ''}
        ${shell.navigatorKey != null ? "navigatorKey: ${shell.navigatorKey}," : ''}
        isStateful: ${shell.isStateful},
        builder: (context, state, child) => ${shell.className}($builderParam),
      )
    ''';
  }

  Method _generateBuildNestedRoutesMethod(
      List<RouteInfo> routes, List<ShellInfo> shells) {
    return Method((b) {
      b.name = '_buildNestedRoutes';
      b.returns = refer('List<RouteBase>');

      final all = <dynamic>[...routes, ...shells];
      final infoMap = {for (var i in all) i.className: i};
      final childrenMap = <String, List<dynamic>>{};
      final topLevel = <dynamic>[];

      for (final i in all) {
        if (i.parent != null && infoMap.containsKey(i.parent)) {
          childrenMap.putIfAbsent(i.parent, () => []).add(i);
        } else {
          topLevel.add(i);
        }
      }

      String build(dynamic info) {
        final instance = '${_toLowerCamelCase(info.className)}Route';
        final children = childrenMap[info.className] ?? [];

        children.sort((a, b) => (a.order ?? 999).compareTo(b.order ?? 999));

        if (info is ShellInfo) {
          final String shellItselfCode;
          if (info.isStateful) {
            final branchesCode = children
                .map(
                    (child) => 'StatefulShellBranch(routes: [${build(child)}])')
                .join(',');
            shellItselfCode =
                'StatefulShellRoute.indexedStack(builder: $instance.builder, branches: [$branchesCode])';
          } else {
            final childRoutesCode = children.map(build).join(',');
            shellItselfCode =
                '$instance.toShellRoute(routes: [$childRoutesCode])';
          }

          final isRootShell = info.path == '/';
          String? redirectPath = info.initialRoute;
          if (redirectPath == null &&
              isRootShell &&
              children.isNotEmpty &&
              info.isStateful) {
            redirectPath = (children.first as dynamic).path;
          }

          if (redirectPath != null) {
            return '''
              GoRoute(
                path: '${info.path}',
                redirect: (context, state) {
                  if (state.fullPath == '${info.path}') {
                    return '$redirectPath';
                  }
                  return null;
                },
                routes: [
                  $shellItselfCode
                ],
              )
            ''';
          }

          return shellItselfCode;
        } else {
          final childRoutesCode = children.map(build).join(',');
          return '$instance.toGoRoute(routes: [$childRoutesCode])';
        }
      }

      b.body = Code('return [${topLevel.map(build).join(',')}];');
    });
  }
}

class RouteBaseInfo {
  final String className;
  final String? initialLocation;
  final String? errorBuilder;
  final String? redirect;
  const RouteBaseInfo(
      {required this.className,
      this.initialLocation,
      this.errorBuilder,
      this.redirect});
}

class RouteInfo {
  final String className;
  final String path;
  final String? name;
  final String? description;
  final List<String> middleware;
  final List<ParameterElement> constructorParams;
  final List<String> requiredParams;
  final List<String> optionalParams;
  final String? importPath;
  final String? parent;
  final int? order;

  const RouteInfo({
    required this.className,
    required this.path,
    this.name,
    this.description,
    required this.middleware,
    required this.constructorParams,
    required this.requiredParams,
    required this.optionalParams,
    this.importPath,
    this.parent,
    this.order,
  });
}

class ShellInfo {
  final String className;
  final String path;
  final String? name;
  final String? description;
  final String? navigatorKey;
  final String? importPath;
  final String? parent;
  final bool isStateful;
  final String? initialRoute;

  const ShellInfo({
    required this.className,
    required this.path,
    this.name,
    this.description,
    this.navigatorKey,
    this.importPath,
    this.parent,
    required this.isStateful,
    this.initialRoute,
  });
}

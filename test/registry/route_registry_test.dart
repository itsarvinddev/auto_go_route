import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Route extends RoutePaths {
  const _Route(String path, {super.name, super.description, super.middleware})
    : super(path: path, builder: _build);

  static Widget _build(BuildContext context, GoRouterState state) =>
      const SizedBox.shrink();
}

void main() {
  late RouteRegistry registry;

  setUp(() => registry = RouteRegistry.scoped());

  test('RouteRegistry() returns the shared singleton', () {
    expect(RouteRegistry(), same(RouteRegistry.instance));
    // Scoped registries are independent, which is what makes tests isolated.
    expect(RouteRegistry.scoped(), isNot(same(RouteRegistry.instance)));
  });

  group('registration', () {
    test('keys on name, falling back to the template', () {
      registry
        ..register(_Route('/a', name: 'alpha'))
        ..register(_Route('/b'));
      expect(registry.allRouteNames, containsAll(['alpha', '/b']));
      expect(registry.getRoute('alpha')?.template, '/a');
      expect(registry.getRoute('/b')?.template, '/b');
      expect(registry.getRoute('missing'), isNull);
    });

    test('registering the same route twice is a no-op', () {
      registry
        ..register(_Route('/a', name: 'alpha'))
        ..register(_Route('/a', name: 'alpha'));
      expect(registry.allRoutes, hasLength(1));
    });

    test('a colliding name throws instead of overwriting silently', () {
      // 1.x overwrote, hiding exactly the duplicate-name bugs the generator
      // now catches at build time.
      registry.register(_Route('/a', name: 'dup'));
      expect(
        () => registry.register(_Route('/b', name: 'dup')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('dup'), contains('/a'), contains('/b')),
          ),
        ),
      );
    });

    test('replace: true overwrites deliberately', () {
      registry.register(_Route('/a', name: 'dup'));
      registry.register(_Route('/b', name: 'dup'), replace: true);
      expect(registry.getRoute('dup')?.template, '/b');
    });

    test('groups record membership and register their routes', () {
      registry.registerGroup('shop', [_Route('/a'), _Route('/b')]);
      expect(registry.getRouteGroup('shop'), hasLength(2));
      expect(registry.allRoutes, hasLength(2));
      expect(registry.statistics.totalGroups, 1);
    });

    test('clear empties everything', () {
      registry.registerGroup('g', [_Route('/a')]);
      registry.clear();
      expect(registry.allRoutes, isEmpty);
      expect(registry.getRouteGroup('g'), isNull);
      expect(registry.statistics.totalRoutes, 0);
    });

    test('statistics count parameterised routes', () {
      registry.registerAll([_Route('/a'), _Route('/b/:id')]);
      expect(registry.statistics.totalRoutes, 2);
      expect(registry.statistics.routesWithParams, 1);
      expect(registry.statistics.toJson()['routesWithParams'], 1);
    });
  });

  group('validation', () {
    test('accepts the shapes the generator emits', () {
      // 1.x rejected nested routes and anything with an optional parameter —
      // including its own generated output.
      registry.registerAll([
        _Route('/products/:id', name: 'a'),
        _Route(r'/users/:id(\d+)', name: 'b'),
        _Route('/products/:id/reviews', name: 'c'),
      ]);
      expect(registry.validate().isValid, isTrue);
      expect(registry.validateAllRoutes, returnsNormally);
    });

    test('reports a malformed template', () {
      registry.register(_Route('relative', name: 'bad'));
      final result = registry.validate();
      expect(result.isValid, isFalse);
      expect(result.errors.single, contains('invalid path template'));
    });

    test('reports a repeated parameter name', () {
      registry.register(_Route('/a/:id/b/:id', name: 'dupe'));
      expect(registry.validate().errors.single, contains('repeats'));
    });

    test('reports two routes resolving to the same template', () {
      registry
        ..register(_Route('/a', name: 'one'))
        ..register(_Route('/a', name: 'two'));
      expect(
        registry.validate().errors.single,
        allOf(contains('one'), contains('two')),
      );
    });

    test('warns about a missing description without failing', () {
      registry.register(_Route('/a', name: 'a'));
      final result = registry.validate();
      expect(result.isValid, isTrue);
      expect(result.warnings.single, contains('no description'));
    });

    test('validateAllRoutes throws listing every error', () {
      registry.register(_Route('bad', name: 'x'));
      expect(registry.validateAllRoutes, throwsStateError);
    });
  });

  group('generateGoRoutes', () {
    test('mounts each route at its absolute template', () {
      registry.register(_Route('/a', name: 'a'));
      expect(registry.generateGoRoutes().single.path, '/a');
    });

    test('composes the global redirect ahead of a route guard', () async {
      // 1.x overwrote `GoRoute.redirect`, silently deleting every route's
      // auth guard.
      final calls = <String>[];
      String? guard(BuildContext c, GoRouterState s) {
        calls.add('guard');
        return '/guarded';
      }

      String? global(BuildContext c, GoRouterState s) {
        calls.add('global');
        return null;
      }

      registry.register(_Route('/a', name: 'a', middleware: [guard]));
      final route = registry.generateGoRoutes(globalRedirect: global).single;
      final result = await route.redirect!(_FakeContext(), _FakeState());

      expect(result, '/guarded');
      expect(calls, ['global', 'guard']);
    });

    test('keeps the route guard when no global redirect is given', () async {
      String? guard(BuildContext c, GoRouterState s) => '/guarded';
      registry.register(_Route('/a', name: 'a', middleware: [guard]));
      final redirect = registry.generateGoRoutes().single.redirect!;
      // Asserting non-null alone passed even with the 1.x bug, which replaced
      // the guard with a different function.
      expect(redirect, same(guard));
      expect(await redirect(_FakeContext(), _FakeState()), '/guarded');
    });
  });

  group('documentation', () {
    setUp(() {
      registry.registerAll([
        _Route('/shop/products/:id', name: 'product', description: 'A product'),
        _Route('/about', name: 'about'),
      ]);
    });

    test('markdown lists every route and is reproducible', () {
      final first = registry.generateDocumentation();
      final second = registry.generateDocumentation();
      expect(first, second);
      expect(first, contains('/shop/products/:id'));
      expect(first, contains('A product'));
      expect(first, contains('Total routes: 2'));
      // No timestamp unless the caller supplies a clock, so the output can be
      // diffed in a golden test.
      expect(first, isNot(contains('Generated on')));
    });

    test('markdown stamps a supplied timestamp', () {
      expect(
        registry.generateDocumentation(generatedAt: DateTime.utc(2026)),
        contains('2026-01-01T00:00:00.000Z'),
      );
    });

    test('json is parseable and lists parameters', () {
      final json = registry.generateDocumentation(
        format: DocumentationFormat.json,
      );
      expect(json, contains('"path":"/shop/products/:id"'));
      expect(json, contains('"path_params":["id"]'));
    });

    test('html escapes its content', () {
      registry.register(
        _Route('/x', name: 'x', description: '<script>alert(1)</script>'),
      );
      final html = registry.generateDocumentation(
        format: DocumentationFormat.html,
      );
      expect(html, contains('&lt;script&gt;'));
      expect(html, isNot(contains('<script>alert')));
    });
  });

  group('findClosest', () {
    test('suggests the nearest template', () {
      registry.registerAll([
        _Route('/products/:id', name: 'a'),
        _Route('/orders/:id', name: 'b'),
      ]);
      expect(registry.findClosest('/products/9')?.name, 'a');
    });

    test('returns null when nothing is close enough', () {
      registry.register(_Route('/products', name: 'a'));
      expect(registry.findClosest('/zzz/yyy/xxx'), isNull);
    });
  });

  test('RouteMetadata snapshots a route without reading the clock', () {
    final metadata = RouteMetadata.fromRoute(
      _Route('/a/:id', name: 'a', description: 'd'),
    );
    expect(metadata.path, '/a/:id');
    expect(metadata.pathParameters, ['id']);
    expect(metadata.registeredAt, isNull);
    expect(metadata.toJson()['name'], 'a');
  });

  group('GoRoute.copyWith', () {
    test('preserves every field it does not replace', () {
      // 1.x dropped pageBuilder, onExit, parentNavigatorKey, caseSensitive and
      // metadata, so copying a pageBuilder-only route produced one go_router
      // rejects.
      final key = GlobalKey<NavigatorState>();
      final original = GoRoute(
        path: '/a',
        name: 'a',
        pageBuilder: (context, state) =>
            const MaterialPage(child: SizedBox.shrink()),
        onExit: (context, state) async => true,
        parentNavigatorKey: key,
        caseSensitive: false,
        metadata: const {'k': 'v'},
      );

      final copy = original.copyWith(name: 'b');

      expect(copy.name, 'b');
      expect(copy.path, '/a');
      expect(copy.pageBuilder, isNotNull);
      expect(copy.builder, isNull);
      expect(copy.onExit, isNotNull);
      expect(copy.parentNavigatorKey, same(key));
      expect(copy.caseSensitive, isFalse);
      expect(copy.metadata, const {'k': 'v'});
    });
  });
}

class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeState implements GoRouterState {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Route extends RoutePaths {
  const _Route(String path, {super.name, super.middleware, super.caseSensitive})
    : super(path: path, builder: _build);

  static Widget _build(BuildContext context, GoRouterState state) =>
      const SizedBox.shrink();
}

void main() {
  group('template and parameters', () {
    test('template is the declared path for a top-level route', () {
      expect(_Route('/products/:id').template, '/products/:id');
    });

    test('discovers parameters in declaration order without duplicates', () {
      expect(_Route('/orders/:orderId/items/:itemId').pathParameters, [
        'orderId',
        'itemId',
      ]);
    });

    test('discovers a parameter carrying a regular-expression constraint', () {
      expect(_Route(r'/users/:id(\d+)').pathParameters, ['id']);
    });

    test('an optional-looking parameter yields no phantom sibling', () {
      // The 1.x regex `:(\w+)(?!\?)` backtracked, so `/a/:tab?` reported a
      // required parameter named `ta` alongside the optional `tab`.
      expect(_Route('/a/:tab?').pathParameters, ['tab']);
    });
  });

  group('location', () {
    test('substitutes a single parameter', () {
      expect(
        _Route('/products/:id').location(params: {'id': '42'}),
        '/products/42',
      );
    });

    test('does not corrupt a parameter that prefixes another', () {
      // `/user/:id/card/:idCard` with a naive `replaceAll(':id', …)` produced
      // `/user/5/card/5Card`, silently discarding the second value.
      expect(
        _Route(
          '/user/:id/card/:idCard',
        ).location(params: {'id': '5', 'idCard': 'ABC'}),
        '/user/5/card/ABC',
      );
    });

    test('replaces a constrained parameter without leaving the pattern', () {
      expect(
        _Route(r'/users/:id(\d+)').location(params: {'id': '42'}),
        '/users/42',
      );
    });

    test('percent-encodes parameter values', () {
      expect(
        _Route('/search/:q').location(params: {'q': 'a b/c'}),
        '/search/a%20b%2Fc',
      );
    });

    test('appends scalar query parameters', () {
      expect(
        _Route('/products').location(queries: {'page': 2, 'sort': 'name'}),
        '/products?page=2&sort=name',
      );
    });

    test('expands an iterable query value into a repeated key', () {
      expect(
        _Route('/products').location(
          queries: {
            'tag': ['new', 'sale'],
          },
        ),
        '/products?tag=new&tag=sale',
      );
    });

    test('drops null query values and null elements', () {
      expect(
        _Route('/products').location(
          queries: {
            'a': null,
            'b': 'x',
            'c': ['y', null],
          },
        ),
        '/products?b=x&c=y',
      );
    });

    test('omits the query string entirely when nothing survives', () {
      expect(_Route('/products').location(queries: {'a': null}), '/products');
    });

    test('appends a fragment', () {
      expect(_Route('/docs').location(fragment: 'install'), '/docs#install');
    });

    test('pathWithParams is location under its 1.x name', () {
      final route = _Route('/products/:id');
      expect(
        route.pathWithParams({'id': '7'}, queries: {'q': '1'}),
        route.location(params: {'id': '7'}, queries: {'q': '1'}),
      );
    });
  });

  group('validateParams', () {
    test('throws naming every missing parameter', () {
      expect(
        () => _Route('/a/:x/:y').validateParams({'x': '1'}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('y'), contains('x, y')),
          ),
        ),
      );
    });

    test('passes when every parameter is supplied', () {
      expect(() => _Route('/a/:x').validateParams({'x': '1'}), returnsNormally);
    });

    test('location with validate: false leaves the placeholder in place', () {
      // Better a visibly wrong URL than one that silently resolves to a
      // different route.
      expect(_Route('/a/:x').location(validate: false), '/a/:x');
    });
  });

  group('equality', () {
    test('two instances of the same route are equal', () {
      // `builder` is a fresh closure per construction, so including it in
      // `props` — as 1.x did — made every instance unequal and its hashCode
      // unstable.
      expect(_Route('/a', name: 'a'), _Route('/a', name: 'a'));
      expect(
        _Route('/a', name: 'a').hashCode,
        _Route('/a', name: 'a').hashCode,
      );
    });

    test('routes differing by path are not equal', () {
      expect(_Route('/a'), isNot(_Route('/b')));
    });

    test('a route survives a round trip through a Set', () {
      final set = {_Route('/a', name: 'a'), _Route('/a', name: 'a')};
      expect(set, hasLength(1));
    });
  });

  group('toGoRoute', () {
    test('forwards path, name and caseSensitive', () {
      final goRoute = _Route(
        '/a',
        name: 'alpha',
        caseSensitive: false,
      ).toGoRoute();
      expect(goRoute.path, '/a');
      expect(goRoute.name, 'alpha');
      expect(goRoute.caseSensitive, isFalse);
    });

    test('passes no redirect when the route declares no guards', () {
      // A non-null redirect changes go_router's `redirectOnly` bookkeeping, so
      // an unguarded route has to pass nothing at all.
      expect(_Route('/a').toGoRoute().redirect, isNull);
    });

    test('passes the single guard through unwrapped', () {
      String? guard(BuildContext context, GoRouterState state) => '/login';
      expect(
        _Route('/a', middleware: [guard]).toGoRoute().redirect,
        same(guard),
      );
    });

    test('nests child routes', () {
      final child = _Route('/a/b').toGoRoute();
      expect(_Route('/a').toGoRoute(routes: [child]).routes, [child]);
    });
  });

  group('guard composition', () {
    test('runs guards in order and stops at the first redirect', () async {
      final calls = <String>[];
      String? first(BuildContext c, GoRouterState s) {
        calls.add('first');
        return null;
      }

      String? second(BuildContext c, GoRouterState s) {
        calls.add('second');
        return '/stop';
      }

      String? third(BuildContext c, GoRouterState s) {
        calls.add('third');
        return '/never';
      }

      final route = _Route('/a', middleware: [first, second, third]);
      final result = await route.composedRedirect!(
        _FakeContext(),
        _unusedState,
      );
      expect(result, '/stop');
      expect(calls, ['first', 'second']);
    });

    test('stays synchronous while its guards are synchronous', () {
      // go_router defers navigation a frame for an async redirect, so a
      // synchronous guard chain must not be wrapped in a Future.
      String? a(BuildContext c, GoRouterState s) => null;
      String? b(BuildContext c, GoRouterState s) => '/x';
      final result = _Route('/a', middleware: [a, b]).composedRedirect!(
        _FakeContext(),
        _unusedState,
      );
      expect(result, isNot(isA<Future<String?>>()));
      expect(result, '/x');
    });

    test('awaits an async guard mid-chain', () async {
      Future<String?> slow(BuildContext c, GoRouterState s) async => null;
      String? then(BuildContext c, GoRouterState s) => '/after';
      final result = await _Route(
        '/a',
        middleware: [slow, then],
      ).composedRedirect!(_FakeContext(), _unusedState);
      expect(result, '/after');
    });

    test('returns null when every guard allows navigation', () async {
      String? allow(BuildContext c, GoRouterState s) => null;
      expect(
        await _Route('/a', middleware: [allow, allow]).composedRedirect!(
          _FakeContext(),
          _unusedState,
        ),
        isNull,
      );
    });
  });

  test('toString names the template', () {
    expect(_Route('/a/:b').toString(), contains('/a/:b'));
  });
}

/// The guards under test never touch their context or state, so a stand-in
/// keeps these as plain unit tests instead of widget tests.
class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final GoRouterState _unusedState = _FakeState();

class _FakeState implements GoRouterState {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parameterNames', () {
    test('lists parameters in order without duplicates', () {
      expect(RouteUtils.parameterNames('/orders/:orderId/items/:itemId'), [
        'orderId',
        'itemId',
      ]);
    });

    test('handles a regular-expression constraint', () {
      expect(RouteUtils.parameterNames(r'/users/:id(\d+)'), ['id']);
    });

    test('returns nothing for a static path', () {
      expect(RouteUtils.parameterNames('/about'), isEmpty);
    });
  });

  group('extractParams', () {
    test('binds values from a matching location', () {
      expect(RouteUtils.extractParams('/products/:id', '/products/42'), {
        'id': '42',
      });
    });

    test('binds several parameters', () {
      expect(RouteUtils.extractParams('/o/:o/i/:i', '/o/1/i/2'), {
        'o': '1',
        'i': '2',
      });
    });

    test('returns null when the location does not match', () {
      expect(RouteUtils.extractParams('/products/:id', '/orders/42'), isNull);
      expect(RouteUtils.extractParams('/products/:id', '/products'), isNull);
    });

    test('honours a regular-expression constraint', () {
      expect(RouteUtils.extractParams(r'/u/:id(\d+)', '/u/42'), {'id': '42'});
      expect(RouteUtils.extractParams(r'/u/:id(\d+)', '/u/abc'), isNull);
    });

    test('decodes percent-encoded values and ignores the query string', () {
      expect(RouteUtils.extractParams('/s/:q', '/s/a%20b?ignored=1'), {
        'q': 'a b',
      });
    });
  });

  group('isValidTemplate', () {
    test('accepts a parameterised path', () {
      // 1.x rejected every parameterised path: its "invalid characters" set
      // contained both `:` and `?`.
      expect(RouteUtils.isValidTemplate('/products/:id'), isTrue);
      expect(RouteUtils.isValidTemplate(r'/users/:id(\d+)'), isTrue);
      expect(RouteUtils.isValidTemplate('/'), isTrue);
    });

    test('rejects malformed templates', () {
      expect(RouteUtils.isValidTemplate(''), isFalse);
      expect(RouteUtils.isValidTemplate('products'), isFalse);
      expect(RouteUtils.isValidTemplate('/a//b'), isFalse);
      expect(RouteUtils.isValidTemplate('/a b'), isFalse);
      expect(RouteUtils.isValidTemplate('/a?q=1'), isFalse);
      expect(RouteUtils.isValidTemplate('/a#frag'), isFalse);
      expect(RouteUtils.isValidTemplate('/a/:'), isFalse);
      expect(RouteUtils.isValidTemplate('/a/:-bad'), isFalse);
    });

    test('isValidPath is the same check under its 1.x name', () {
      expect(RouteUtils.isValidPath('/products/:id'), isTrue);
    });
  });

  group('breadcrumbs', () {
    test('segments drop parameters', () {
      expect(RouteUtils.breadcrumbSegments('/shop/products/:id/reviews'), [
        'shop',
        'products',
        'reviews',
      ]);
    });

    test('trail accumulates every segment, parameters included', () {
      expect(RouteUtils.breadcrumbTrail('/shop/products/:id'), [
        '/shop',
        '/shop/products',
        '/shop/products/:id',
      ]);
    });
  });

  group('normalizePath', () {
    test('collapses repeated slashes and drops a trailing one', () {
      expect(RouteUtils.normalizePath('/a//b/'), '/a/b');
      expect(RouteUtils.normalizePath('/'), '/');
    });

    test('preserves case, because go_router URLs are case-sensitive', () {
      // 1.x lower-cased, which changes which route a URL matches.
      expect(RouteUtils.normalizePath('/Home/Profile'), '/Home/Profile');
    });

    test('keeps the query string and fragment', () {
      expect(RouteUtils.normalizePath('/a//b?q=1#f'), '/a/b?q=1#f');
    });
  });

  group('query strings', () {
    test('parses values containing = and valueless flags', () {
      expect(RouteUtils.parseQueryString('?a=1=2&b&c=3'), {
        'a': '1=2',
        'b': '',
        'c': '3',
      });
    });

    test('parseQueryStringAll keeps every value of a repeated key', () {
      expect(RouteUtils.parseQueryStringAll('t=1&t=2'), {
        't': ['1', '2'],
      });
    });

    test('builds a query string, expanding iterables and dropping nulls', () {
      expect(
        RouteUtils.buildQueryString({
          'a': 1,
          'b': null,
          'c': ['x', 'y'],
        }),
        'a=1&c=x&c=y',
      );
      expect(RouteUtils.buildQueryString({}), '');
      expect(RouteUtils.buildQueryString({'a': null}), '');
    });
  });

  group('misc', () {
    test('isValidDeepLink requires an absolute URI with a scheme', () {
      expect(RouteUtils.isValidDeepLink('myapp://open/1'), isTrue);
      expect(RouteUtils.isValidDeepLink('https://a.test'), isTrue);
      expect(RouteUtils.isValidDeepLink('/relative'), isFalse);
    });

    test('calculateRouteSimilarity scores segment overlap', () {
      expect(RouteUtils.calculateRouteSimilarity('/a/b', '/a/b'), 1.0);
      expect(RouteUtils.calculateRouteSimilarity('/a/b', '/a/c'), 0.5);
      expect(RouteUtils.calculateRouteSimilarity('/a', '/b'), 0.0);
      expect(RouteUtils.calculateRouteSimilarity('/', '/'), 1.0);
    });

    test('measureRoutePerformance returns the operation result', () {
      expect(RouteUtils.measureRoutePerformance('t', () => 7), 7);
    });

    test('measureRoutePerformance rethrows', () {
      expect(
        () => RouteUtils.measureRoutePerformance<void>(
          't',
          () => throw StateError('boom'),
        ),
        throwsStateError,
      );
    });
  });

  group('RouteValidationResult', () {
    test('valid carries warnings but no errors', () {
      final result = RouteValidationResult.valid(warnings: ['w']);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, ['w']);
      expect(result.toString(), contains('1 warnings'));
    });

    test('invalid carries its errors', () {
      final result = RouteValidationResult.invalid(['e']);
      expect(result.isValid, isFalse);
      expect(result.toString(), contains('e'));
    });
  });
}

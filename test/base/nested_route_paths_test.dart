import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Nested extends NestedRoutePaths {
  const _Nested(String parent, String path)
    : super(parentTemplate: parent, path: path, builder: _build);

  static Widget _build(BuildContext context, GoRouterState state) =>
      const SizedBox.shrink();
}

void main() {
  group('template joins parent and child the way go_router does', () {
    // `concatenatePaths` in go_router splits on "/", drops empty segments and
    // re-joins from the root. Matching it exactly is what makes the URL this
    // class builds the URL go_router will match.
    final cases = <(String parent, String child, String expected)>[
      ('/products', 'reviews', '/products/reviews'),
      ('/products/', 'reviews', '/products/reviews'),
      ('/products', '/reviews', '/products/reviews'),
      ('/', 'home', '/home'),
      ('/', '/home', '/home'),
      ('/products/:id', 'reviews', '/products/:id/reviews'),
      ('/notifications', '/:id', '/notifications/:id'),
      ('/a/b', 'c/d', '/a/b/c/d'),
      ('/', '/', '/'),
    ];

    for (final (parent, child, expected) in cases) {
      test('"$parent" + "$child" = "$expected"', () {
        expect(_Nested(parent, child).template, expected);
      });
    }
  });

  test('fullPath is template under its 1.x name', () {
    final route = _Nested('/products', 'reviews');
    expect(route.fullPath, route.template);
  });

  test('parentPath is parentTemplate under its 1.x name', () {
    expect(_Nested('/products', 'reviews').parentPath, '/products');
  });

  test('inherits path parameters from the parent', () {
    expect(_Nested('/orders/:orderId', 'items/:itemId').pathParameters, [
      'orderId',
      'itemId',
    ]);
  });

  test('does not report the same inherited parameter twice', () {
    expect(_Nested('/a/:id', 'b').pathParameters, ['id']);
  });

  test('location substitutes inherited and own parameters', () {
    expect(
      _Nested(
        '/orders/:orderId',
        'items/:itemId',
      ).location(params: {'orderId': '7', 'itemId': '9'}),
      '/orders/7/items/9',
    );
  });

  test('the GoRoute keeps the relative path, since go_router nests it', () {
    expect(_Nested('/products', 'reviews').toGoRoute().path, 'reviews');
  });

  test('parentTemplate participates in equality', () {
    expect(_Nested('/a', 'c'), isNot(_Nested('/b', 'c')));
    expect(_Nested('/a', 'c'), _Nested('/a', 'c'));
  });
}

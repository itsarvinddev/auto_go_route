import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_router.dart';

enum Flavour { vanilla, chocolate }

void main() {
  late StateProbe probe;

  setUp(() => probe = StateProbe());

  Future<GoRouterState> stateFor(
    WidgetTester tester,
    String template,
    String location, {
    Map<String, dynamic>? metadata,
  }) async {
    await pumpRouter(
      tester,
      routes: [
        GoRoute(
          path: template,
          metadata: metadata,
          builder: (context, state) {
            probe.state = state;
            return const SizedBox.shrink();
          },
        ),
      ],
      initialLocation: location,
    );
    return probe.state!;
  }

  group('getParam', () {
    testWidgets('reads each supported non-nullable type', (tester) async {
      final state = await stateFor(
        tester,
        '/a',
        '/a?s=x&i=1&d=1.5&n=2&b=true&big=10&when=2026-01-02T03:04:05.000Z'
            '&link=https%3A%2F%2Fa.test',
      );
      expect(state.getParam<String>('s'), 'x');
      expect(state.getParam<int>('i'), 1);
      expect(state.getParam<double>('d'), 1.5);
      expect(state.getParam<num>('n'), 2);
      expect(state.getParam<bool>('b'), isTrue);
      expect(state.getParam<BigInt>('big'), BigInt.from(10));
      expect(
        state.getParam<DateTime>('when'),
        DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      expect(state.getParam<Uri>('link'), Uri.parse('https://a.test'));
    });

    testWidgets('reads a nullable type when the value is present', (
      tester,
    ) async {
      // 1.x switched on `T == int`, which is false for `int?`, so every
      // *present* nullable value threw.
      final state = await stateFor(tester, '/a', '/a?i=7&d=1.5&b=false&n=3');
      expect(state.getParam<int?>('i'), 7);
      expect(state.getParam<double?>('d'), 1.5);
      expect(state.getParam<bool?>('b'), isFalse);
      expect(state.getParam<num?>('n'), 3);
      expect(state.getParam<String?>('missing'), isNull);
    });

    testWidgets('a missing non-nullable parameter throws', (tester) async {
      // 1.x fabricated 0 / '' / false here, turning a routing mistake into
      // silently wrong data.
      final state = await stateFor(tester, '/a', '/a');
      expect(
        () => state.getParam<int>('i'),
        throwsA(isA<RouteParamFormatException>()),
      );
      expect(
        () => state.getParam<String>('s'),
        throwsA(isA<RouteParamFormatException>()),
      );
    });

    testWidgets('an unsupported type argument is refused', (tester) async {
      final state = await stateFor(tester, '/a', '/a');
      expect(() => state.getParam<Duration>('d'), throwsArgumentError);
    });
  });

  group('getRequiredParam and getOptionalParam', () {
    testWidgets('getRequiredParam throws for an empty value', (tester) async {
      final state = await stateFor(tester, '/a', '/a?q=');
      expect(
        () => state.getRequiredParam<String>('q'),
        throwsA(isA<RouteParamFormatException>()),
      );
    });

    testWidgets('getOptionalParam falls back when absent', (tester) async {
      final state = await stateFor(tester, '/a', '/a');
      expect(state.getOptionalParam<int>('page', 1), 1);
    });

    testWidgets('getOptionalParam still throws for a malformed value', (
      tester,
    ) async {
      // Substituting the default would hide a bad link.
      final state = await stateFor(tester, '/a', '/a?page=abc');
      expect(
        () => state.getOptionalParam<int>('page', 1),
        throwsA(isA<RouteParamFormatException>()),
      );
    });
  });

  group('enums, lists and metadata', () {
    testWidgets('getEnumParam decodes, defaults and can be required', (
      tester,
    ) async {
      final state = await stateFor(tester, '/a', '/a?f=chocolate');
      expect(state.getEnumParam('f', Flavour.values), Flavour.chocolate);
      expect(state.getEnumParam('missing', Flavour.values), isNull);
      expect(
        state.getEnumParam('missing', Flavour.values, orElse: Flavour.vanilla),
        Flavour.vanilla,
      );
      expect(
        () => state.getEnumParam('missing', Flavour.values, required: true),
        throwsA(isA<RouteParamFormatException>()),
      );
    });

    testWidgets('getParamList reads every value', (tester) async {
      final state = await stateFor(tester, '/a', '/a?t=1&t=2');
      expect(state.getParamList('t'), ['1', '2']);
    });

    testWidgets('metadataAs reads typed route metadata', (tester) async {
      final state = await stateFor(
        tester,
        '/a',
        '/a',
        metadata: const {'requiresAuth': true, 'role': 'admin'},
      );
      expect(state.metadataAs<bool>('requiresAuth'), isTrue);
      expect(state.metadataAs<String>('role'), 'admin');
      expect(state.metadataAs<int>('role'), isNull);
      expect(state.metadataAs<bool>('absent'), isNull);
    });
  });

  group('hasParam, typed maps and validation', () {
    testWidgets('hasParam covers path and query', (tester) async {
      final state = await stateFor(tester, '/a/:id', '/a/1?q=2');
      expect(state.hasParam('id'), isTrue);
      expect(state.hasParam('q'), isTrue);
      expect(state.hasParam('nope'), isFalse);
    });

    testWidgets('typed maps skip what cannot convert', (tester) async {
      final state = await stateFor(tester, '/a/:id', '/a/7?n=1&bad=xyz');
      expect(state.getTypedPathParameters<int>(), {'id': 7});
      expect(state.getTypedQueryParameters<int>(), {'n': 1});
    });

    testWidgets('getValidatedParam applies the validator and fallback', (
      tester,
    ) async {
      final state = await stateFor(tester, '/a', '/a?page=99');
      expect(state.getValidatedParam<int>('page', (v) => v < 100), 99);
      expect(
        state.getValidatedParam<int>('page', (v) => v < 10, fallback: 1),
        1,
      );
      expect(
        () => state.getValidatedParam<int>('page', (v) => v < 10),
        throwsA(isA<RouteParamFormatException>()),
      );
      expect(
        state.getValidatedParam<int?>(
          'missing',
          (_) => true,
          hasFallback: true,
        ),
        isNull,
      );
    });

    testWidgets('extraAs reads a typed extra', (tester) async {
      final router = await pumpRouter(
        tester,
        routes: [probe.route('/a')],
        initialLocation: '/a',
      );
      router.go('/a', extra: 42);
      await tester.pumpAndSettle();
      expect(probe.state!.extraAs<int>(), 42);
      expect(probe.state!.extraAs<String>(), isNull);
    });
  });
}

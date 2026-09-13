import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_router.dart';

enum Sort { asc, desc }

void main() {
  group('encode', () {
    test('String passes through verbatim', () {
      expect(RouteCodec.encode('a b'), 'a b');
    });

    test('int, double and num', () {
      expect(RouteCodec.encode(42), '42');
      expect(RouteCodec.encode(4.5), '4.5');
      expect(RouteCodec.encode(7 as num), '7');
    });

    test('bool', () {
      expect(RouteCodec.encode(true), 'true');
      expect(RouteCodec.encode(false), 'false');
    });

    test('BigInt', () {
      expect(
        RouteCodec.encode(BigInt.parse('123456789012345678901234567890')),
        '123456789012345678901234567890',
      );
    });

    test('DateTime round-trips through ISO-8601', () {
      final value = DateTime.utc(2026, 9, 12, 10, 30);
      expect(RouteCodec.encode(value), '2026-09-12T10:30:00.000Z');
      expect(DateTime.parse(RouteCodec.encode(value)), value);
    });

    test('Uri', () {
      expect(
        RouteCodec.encode(Uri.parse('https://example.com/a?b=c')),
        'https://example.com/a?b=c',
      );
    });

    test('an enum encodes as its name', () {
      expect(RouteCodec.encode(Sort.desc), 'desc');
    });

    test('encodeComponent percent-encodes the result', () {
      expect(RouteCodec.encodeComponent('a b/c'), 'a%20b%2Fc');
    });

    test('encodeAll drops nulls', () {
      expect(RouteCodec.encodeAll(['a', null, 'b']), ['a', 'b']);
      expect(RouteCodec.encodeAll(null), isEmpty);
    });

    test('an unsupported type is refused, naming the type', () {
      expect(
        () => RouteCodec.encode(Object()),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Unsupported route parameter type'),
          ),
        ),
      );
    });
  });

  group('reading', () {
    late StateProbe probe;

    setUp(() => probe = StateProbe());

    Future<GoRouterState> stateFor(
      WidgetTester tester,
      String template,
      String location,
    ) async {
      await pumpRouter(
        tester,
        routes: [probe.route(template)],
        initialLocation: location,
      );
      return probe.state!;
    }

    testWidgets('path parameters beat query parameters', (tester) async {
      final state = await stateFor(tester, '/a/:id', '/a/1?id=2');
      expect(RouteCodec.requireString(state, 'id'), '1');
    });

    testWidgets('int decodes from the path', (tester) async {
      final state = await stateFor(tester, '/a/:id', '/a/42');
      expect(RouteCodec.requireInt(state, 'id'), 42);
    });

    testWidgets('a missing required parameter throws a named error', (
      tester,
    ) async {
      final state = await stateFor(tester, '/a', '/a');
      expect(
        () => RouteCodec.requireInt(state, 'page'),
        throwsA(
          isA<RouteParamFormatException>()
              .having((e) => e.parameterName, 'parameterName', 'page')
              .having((e) => e.expectedType, 'expectedType', 'int'),
        ),
      );
    });

    testWidgets('a missing optional parameter is null', (tester) async {
      final state = await stateFor(tester, '/a', '/a');
      expect(RouteCodec.optionalInt(state, 'page'), isNull);
      expect(RouteCodec.optionalString(state, 'q'), isNull);
      expect(RouteCodec.optionalBool(state, 'flag'), isNull);
      expect(RouteCodec.optionalDateTime(state, 'when'), isNull);
    });

    testWidgets('an unparseable value throws rather than defaulting', (
      tester,
    ) async {
      final state = await stateFor(tester, '/a', '/a?page=abc');
      expect(
        () => RouteCodec.optionalInt(state, 'page'),
        throwsA(isA<RouteParamFormatException>()),
      );
    });

    testWidgets('bool accepts true/false and 1/0, in any case', (tester) async {
      final state = await stateFor(
        tester,
        '/a',
        '/a?t=TRUE&f=False&one=1&zero=0',
      );
      expect(RouteCodec.optionalBool(state, 't'), isTrue);
      expect(RouteCodec.optionalBool(state, 'f'), isFalse);
      expect(RouteCodec.optionalBool(state, 'one'), isTrue);
      expect(RouteCodec.optionalBool(state, 'zero'), isFalse);
    });

    testWidgets('bool refuses anything else instead of coercing', (
      tester,
    ) async {
      // `?admin=no` read as `true` in 1.x.
      final state = await stateFor(tester, '/a', '/a?admin=no');
      expect(
        () => RouteCodec.optionalBool(state, 'admin'),
        throwsA(isA<RouteParamFormatException>()),
      );
    });

    testWidgets('flag treats a bare key as true', (tester) async {
      final state = await stateFor(tester, '/a', '/a?archived');
      expect(RouteCodec.flag(state, 'archived'), isTrue);
      expect(RouteCodec.flag(state, 'missing'), isFalse);
    });

    testWidgets('an enum decodes by name and rejects anything else', (
      tester,
    ) async {
      final state = await stateFor(tester, '/a', '/a?sort=desc&bad=sideways');
      expect(RouteCodec.optionalEnum(state, 'sort', Sort.values), Sort.desc);
      expect(
        () => RouteCodec.optionalEnum(state, 'bad', Sort.values),
        throwsA(
          isA<RouteParamFormatException>().having(
            (e) => e.message,
            'message',
            contains('asc, desc'),
          ),
        ),
      );
    });

    testWidgets('a repeated key reads as a list', (tester) async {
      final state = await stateFor(tester, '/a', '/a?t=1&t=2&t=3');
      expect(RouteCodec.stringList(state, 't'), ['1', '2', '3']);
      expect(RouteCodec.intList(state, 't'), [1, 2, 3]);
    });

    testWidgets('an absent repeated key reads as an empty list', (
      tester,
    ) async {
      final state = await stateFor(tester, '/a', '/a');
      expect(RouteCodec.stringList(state, 't'), isEmpty);
    });

    testWidgets('DateTime and Uri decode', (tester) async {
      final state = await stateFor(
        tester,
        '/a',
        '/a?when=2026-09-12T10:30:00.000Z&link=https%3A%2F%2Fexample.com',
      );
      expect(
        RouteCodec.requireDateTime(state, 'when'),
        DateTime.utc(2026, 9, 12, 10, 30),
      );
      expect(
        RouteCodec.requireUri(state, 'link'),
        Uri.parse('https://example.com'),
      );
    });

    testWidgets('BigInt decodes beyond the int range', (tester) async {
      final state = await stateFor(tester, '/a', '/a?n=99999999999999999999');
      expect(
        RouteCodec.requireBigInt(state, 'n'),
        BigInt.parse('99999999999999999999'),
      );
    });
  });

  group('extra', () {
    testWidgets('reads a value of the expected type', (tester) async {
      final probe = StateProbe();
      final router = await pumpRouter(
        tester,
        routes: [probe.route('/a')],
        initialLocation: '/a',
      );
      router.go('/a', extra: const _Payload('hello'));
      await tester.pumpAndSettle();
      expect(
        RouteCodec.requireExtra<_Payload>(probe.state!, 'a').label,
        'hello',
      );
      expect(RouteCodec.optionalExtra<_Payload>(probe.state!)?.label, 'hello');
    });

    testWidgets('explains itself when extra is absent', (tester) async {
      final probe = StateProbe();
      await pumpRouter(
        tester,
        routes: [probe.route('/a')],
        initialLocation: '/a',
      );
      expect(
        () => RouteCodec.requireExtra<_Payload>(probe.state!, 'a'),
        throwsA(
          isA<RouteParamFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('deep link'), contains('_Payload')),
          ),
        ),
      );
      expect(RouteCodec.optionalExtra<_Payload>(probe.state!), isNull);
    });

    testWidgets('optionalExtra returns null for the wrong type', (
      tester,
    ) async {
      final probe = StateProbe();
      final router = await pumpRouter(
        tester,
        routes: [probe.route('/a')],
        initialLocation: '/a',
      );
      router.go('/a', extra: 'a string');
      await tester.pumpAndSettle();
      expect(RouteCodec.optionalExtra<_Payload>(probe.state!), isNull);
    });
  });
}

class _Payload {
  const _Payload(this.label);
  final String label;
}

import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toBoolOrNull', () {
    test('recognises true and false in any case', () {
      expect('true'.toBoolOrNull(), isTrue);
      expect('TRUE'.toBoolOrNull(), isTrue);
      expect('True'.toBoolOrNull(), isTrue);
      expect('false'.toBoolOrNull(), isFalse);
      expect('FALSE'.toBoolOrNull(), isFalse);
    });

    test('treats any integer as its truthiness', () {
      expect('1'.toBoolOrNull(), isTrue);
      expect('0'.toBoolOrNull(), isFalse);
      expect('-3'.toBoolOrNull(), isTrue);
      expect('42'.toBoolOrNull(), isTrue);
    });

    test('returns null for anything it does not recognise', () {
      // 1.x returned `true` here, because `int.tryParse('no') != 0` is
      // `null != 0` — so `?admin=no` read as `true`.
      expect('no'.toBoolOrNull(), isNull);
      expect('yes'.toBoolOrNull(), isNull);
      expect('something'.toBoolOrNull(), isNull);
      expect(''.toBoolOrNull(), isNull);
      expect('1.5'.toBoolOrNull(), isNull);
    });
  });
}

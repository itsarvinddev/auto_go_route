import 'package:test/test.dart';

import 'support/harness.dart';

const _header = '''
import 'package:auto_go_route/auto_go_route.dart';

part 'app_router.routes.g.dart';
''';

const _base = '''
@AutoGoRouteBase()
class AppRouter extends _\$AppRouter {}
''';

void main() {
  group('graph shape', () {
    test('a self-parent is reported, not walked forever', () {
      // The 1.x parent walk had no visited set, so this spun inside the build
      // step — the literal "hanging" of issue #3's title.
      expect(
        errorFor('''
$_header

@AutoGoRoute(path: '/a', parent: SelfParent)
class SelfParent {
  const SelfParent();
}

$_base
'''),
        completion(allOf(contains('cycle'), contains('SelfParent'))),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('a two-node cycle is reported with both names', () {
      expect(
        errorFor('''
$_header

@AutoGoRoute(path: '/a', parent: PageB)
class PageA {
  const PageA();
}

@AutoGoRoute(path: '/b', parent: PageA)
class PageB {
  const PageB();
}

$_base
'''),
        completion(
          allOf(contains('cycle'), contains('PageA'), contains('PageB')),
        ),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('an unannotated parent is reported', () async {
      expect(
        await errorFor('''
$_header

class NotARoute {
  const NotARoute();
}

@AutoGoRoute(path: '/a', parent: NotARoute)
class PageA {
  const PageA();
}

$_base
'''),
        allOf(contains('NotARoute'), contains('no @AutoGoRoute')),
      );
    });
  });

  group('paths', () {
    test(
      'an optional path parameter is refused with both alternatives',
      () async {
        // go_router has no optional path segments; 1.x registered the literal
        // pattern `/search/:$1`, which nothing could ever match.
        final message = await errorFor('''
$_header

@AutoGoRoute(path: '/search/:query?')
class SearchPage {
  const SearchPage({this.query});
  final String? query;
}

$_base
''');
        expect(message, contains('optional path parameter'));
        expect(message, contains('query string'));
        expect(message, contains('two routes'));
      },
    );

    test('a duplicated path parameter is refused', () async {
      // Two same-named arguments in one method is an unparseable output file.
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a/:id/b/:id')
class DupePage {
  const DupePage({required this.id});
  final String id;
}

$_base
'''),
        allOf(contains('more than once'), contains(':id')),
      );
    });
  });

  group('parameters', () {
    test('a required non-nullable query parameter is refused', () async {
      // 1.x read it from the URL anyway and defaulted to the empty string.
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a')
class NeedsQuery {
  const NeedsQuery({required this.q});
  final String q;
}

$_base
'''),
        allOf(contains('query string'), contains('nullable')),
      );
    });

    test('two extras are refused, since a route carries one', () async {
      // 1.x cast the single `extra` to both types.
      expect(
        await errorFor('''
$_header

class A {
  const A();
}

class B {
  const B();
}

@AutoGoRoute(path: '/a')
class TwoExtras {
  const TwoExtras({this.a, this.b});
  final A? a;
  final B? b;
}

$_base
'''),
        allOf(contains('one `extra`'), contains('TwoExtras')),
      );
    });

    test('a @PathParam naming a segment the path lacks is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a')
class Mismatch {
  const Mismatch({required this.id});
  @PathParam()
  final String id;
}

$_base
'''),
        allOf(contains('declares no such parameter'), contains('@QueryParam')),
      );
    });

    test('a list read from the path is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a/:tags')
class ListInPath {
  const ListInPath({required this.tags});
  final List<String> tags;
}

$_base
'''),
        contains('path segment holds one value'),
      );
    });

    test('conflicting parameter markers are refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a/:id')
class Conflicting {
  const Conflicting({required this.id});
  @PathParam()
  @QueryParam()
  final String id;
}

$_base
'''),
        contains('exactly one source'),
      );
    });

    test('a required positional @RouteIgnore is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a')
class Ignored {
  const Ignored(@RouteIgnore() this.value);
  final String value;
}

$_base
'''),
        contains('only named parameters can be ignored'),
      );
    });

    test('a widget with no unnamed constructor is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a')
class NamedOnly {
  const NamedOnly.create();
}

$_base
'''),
        contains('no unnamed constructor'),
      );
    });
  });

  group('shells', () {
    test('a stateless shell without a Widget slot is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRouteShell(path: '/s')
class NoChild {
  const NoChild();
}

@AutoGoRoute(path: '/a', parent: NoChild)
class PageA {
  const PageA();
}

$_base
'''),
        allOf(
          contains('needs a `Widget` parameter'),
          contains('required Widget child'),
        ),
      );
    });

    test('a stateful shell taking a plain Widget is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRouteShell(path: '/', isStateful: true)
class WrongSlot {
  const WrongSlot({required this.child});
  final Widget child;
}

@AutoGoRoute(path: '/a', parent: WrongSlot)
class PageA {
  const PageA();
}

$_base
'''),
        contains('needs a `StatefulNavigationShell` parameter'),
      );
    });

    test('a container builder on a stateless shell is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRouteShell(path: '/s', navigatorContainerBuilder: 'layout')
class Plain {
  const Plain({required this.child});
  final Widget child;
}

@AutoGoRoute(path: '/a', parent: Plain)
class PageA {
  const PageA();
}

$_base

Object? layout;
'''),
        contains('isStateful: true'),
      );
    });

    test('unsupported extra shell parameters are refused', () async {
      expect(
        await errorFor('''
$_header

class Service {
  const Service();
}

@AutoGoRouteShell(path: '/s')
class NeedsService {
  const NeedsService({required this.child, required this.service});
  final Widget child;
  final Service service;
}

@AutoGoRoute(path: '/a', parent: NeedsService)
class PageA {
  const PageA();
}

$_base
'''),
        allOf(contains('is a shell'), contains('service')),
      );
    });
  });

  group('naming', () {
    test('a route name that is not a Dart identifier is refused', () async {
      // 1.x produced `goToUser-profile`, killing the build with a formatter
      // error that named no route.
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/p', name: 'user-profile')
class UserProfile {
  const UserProfile();
}

$_base
'''),
        allOf(contains('not a valid Dart identifier'), contains('goTo')),
      );
    });

    test('names colliding after capitalisation are refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a', name: 'userProfile')
class PageA {
  const PageA();
}

@AutoGoRoute(path: '/b', name: 'UserProfile')
class PageB {
  const PageB();
}

$_base
'''),
        allOf(contains('goToUserProfile'), contains('unique')),
      );
    });

    test('a route name clashing with an enum member is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a', name: 'values')
class PageA {
  const PageA();
}

$_base
'''),
        allOf(
          contains('reserved inside the generated route enum'),
          contains('generateRouteEnum'),
        ),
      );
    });

    test('a bad navigatorExtensionName is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a')
class PageA {
  const PageA();
}

@AutoGoRouteBase(navigatorExtensionName: 'not an identifier')
class AppRouter extends _\$AppRouter {}
'''),
        contains('valid Dart identifier'),
      );
    });
  });

  group('references', () {
    test('an unresolvable guard name is reported at the annotation', () async {
      // Otherwise this surfaces as `Undefined name 'authGaurd'` inside a file
      // users are told not to edit.
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a', middleware: ['authGaurd'])
class PageA {
  const PageA();
}

$_base
'''),
        allOf(contains('authGaurd'), contains('middleware')),
      );
    });

    test('a reference that is not an identifier is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a', redirect: 'not a function()')
class PageA {
  const PageA();
}

$_base
'''),
        contains('must name a function'),
      );
    });

    test('a resolvable reference is accepted', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a', middleware: ['authGuard'])
class PageA {
  const PageA();
}

$_base

Object? authGuard;
'''),
        isEmpty,
      );
    });
  });

  group('annotation consistency', () {
    test('pageBuilder together with transition is refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(
  path: '/a',
  pageBuilder: 'myPage',
  transition: AutoRouteTransition.fade,
)
class PageA {
  const PageA();
}

$_base

Object? myPage;
'''),
        contains('one page builder'),
      );
    });

    test('two error builders are refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a')
class PageA {
  const PageA();
}

@AutoGoRouteBase(errorBuilder: 'a', errorWidget: 'b')
class AppRouter extends _\$AppRouter {}

Object? a;
Object? b;
'''),
        contains('at most one'),
      );
    });

    test('metadata holding a non-constant value is refused', () async {
      expect(
        await errorFor('''
$_header

class Thing {
  const Thing();
}

@AutoGoRoute(path: '/a', metadata: {'k': Thing()})
class PageA {
  const PageA();
}

$_base
'''),
        allOf(contains('Cannot re-emit'), contains('metadata')),
      );
    });

    test('two @AutoGoRouteBase in one library are refused', () async {
      expect(
        await errorFor('''
$_header

@AutoGoRoute(path: '/a')
class PageA {
  const PageA();
}

@AutoGoRouteBase()
class RouterOne extends _\$RouterOne {}

@AutoGoRouteBase()
class RouterTwo {}
'''),
        contains('Only one @AutoGoRouteBase'),
      );
    });

    test('no annotated widgets at all is refused', () async {
      expect(
        await errorFor('''
$_header

$_base
'''),
        allOf(contains('No @AutoGoRoute'), contains('source_globs')),
      );
    });
  });
}

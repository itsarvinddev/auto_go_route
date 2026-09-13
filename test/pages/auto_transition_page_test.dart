import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Builds the page each transition produces for the same child, so the
  /// mapping from enum value to `Page` subtype is pinned.
  Future<Page<void>> pageFor(
    WidgetTester tester,
    AutoRouteTransition transition, {
    TargetPlatform platform = TargetPlatform.android,
    Duration? duration,
    bool fullscreenDialog = false,
    bool opaque = true,
    String? restorationId,
  }) async {
    late Page<void> page;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) {
            page = buildAutoRoutePage<void>(
              context: context,
              state: state,
              child: const Text('child'),
              transition: transition,
              transitionDuration: duration,
              fullscreenDialog: fullscreenDialog,
              opaque: opaque,
              restorationId: restorationId,
            );
            return page;
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(platform: platform),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    return page;
  }

  testWidgets('platform follows the ambient target platform', (tester) async {
    expect(
      await pageFor(tester, AutoRouteTransition.platform),
      isA<MaterialPage<void>>(),
    );
    expect(
      await pageFor(
        tester,
        AutoRouteTransition.platform,
        platform: TargetPlatform.iOS,
      ),
      isA<CupertinoPage<void>>(),
    );
  });

  testWidgets('material and cupertino ignore the platform', (tester) async {
    expect(
      await pageFor(
        tester,
        AutoRouteTransition.material,
        platform: TargetPlatform.iOS,
      ),
      isA<MaterialPage<void>>(),
    );
    expect(
      await pageFor(
        tester,
        AutoRouteTransition.cupertino,
        platform: TargetPlatform.android,
      ),
      isA<CupertinoPage<void>>(),
    );
  });

  testWidgets('none produces a zero-duration custom page', (tester) async {
    final page =
        await pageFor(tester, AutoRouteTransition.none)
            as CustomTransitionPage<void>;
    expect(page.transitionDuration, Duration.zero);
    expect(page.reverseTransitionDuration, Duration.zero);
  });

  testWidgets('each animated transition renders and settles', (tester) async {
    for (final transition in [
      AutoRouteTransition.fade,
      AutoRouteTransition.slide,
      AutoRouteTransition.slideUp,
      AutoRouteTransition.slideDown,
      AutoRouteTransition.scale,
      AutoRouteTransition.rotation,
    ]) {
      final page = await pageFor(tester, transition);
      expect(page, isA<CustomTransitionPage<void>>(), reason: '$transition');
      expect(find.text('child'), findsOneWidget, reason: '$transition');
    }
  });

  testWidgets('duration defaults to 300ms and reverse mirrors forward', (
    tester,
  ) async {
    final page =
        await pageFor(tester, AutoRouteTransition.fade)
            as CustomTransitionPage<void>;
    expect(page.transitionDuration, const Duration(milliseconds: 300));
    expect(page.reverseTransitionDuration, const Duration(milliseconds: 300));

    final custom =
        await pageFor(
              tester,
              AutoRouteTransition.fade,
              duration: const Duration(milliseconds: 50),
            )
            as CustomTransitionPage<void>;
    expect(custom.transitionDuration, const Duration(milliseconds: 50));
    expect(custom.reverseTransitionDuration, const Duration(milliseconds: 50));
  });

  testWidgets('forwards fullscreenDialog, opaque and restorationId', (
    tester,
  ) async {
    final page =
        await pageFor(
              tester,
              AutoRouteTransition.fade,
              fullscreenDialog: true,
              opaque: false,
              restorationId: 'r',
            )
            as CustomTransitionPage<void>;
    expect(page.fullscreenDialog, isTrue);
    expect(page.opaque, isFalse);
    expect(page.restorationId, 'r');
  });

  testWidgets('uses the state page key, so the page identity is stable', (
    tester,
  ) async {
    final page = await pageFor(tester, AutoRouteTransition.fade);
    expect(page.key, isA<ValueKey<String>>());
  });
}

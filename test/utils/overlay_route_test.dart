import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pumps a router whose only route presents [page] and returns the created
  /// `Route`, so the sheet-versus-dialog decision can be inspected directly.
  Future<Route<void>> routeFor(
    WidgetTester tester,
    AdaptiveOverlayPage<void> Function(Widget child) page, {
    required Size surface,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late Route<void> created;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Text('below')),
        GoRoute(
          path: '/sheet',
          pageBuilder: (context, state) {
            final built = page(const Text('content'));
            created = built.createRoute(context);
            return built;
          },
        ),
      ],
      initialLocation: '/sheet',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return created;
  }

  testWidgets('narrow surfaces get a bottom sheet', (tester) async {
    final route = await routeFor(
      tester,
      (child) => AdaptiveOverlayPage<void>(child: child),
      surface: const Size(400, 900),
    );
    expect(route, isA<ModalBottomSheetRoute<void>>());
  });

  testWidgets('wide surfaces get a dialog', (tester) async {
    final route = await routeFor(
      tester,
      (child) => AdaptiveOverlayPage<void>(child: child),
      surface: const Size(1200, 900),
    );
    expect(route, isA<RawDialogRoute<void>>());
  });

  testWidgets('the breakpoint is configurable', (tester) async {
    final route = await routeFor(
      tester,
      (child) => AdaptiveOverlayPage<void>(child: child, breakpoint: 300),
      surface: const Size(400, 900),
    );
    expect(route, isA<RawDialogRoute<void>>());
  });

  testWidgets('background and barrier colours stay separate', (tester) async {
    // 1.x passed one value as both, so setting a scrim colour also repainted
    // the sheet.
    final route =
        await routeFor(
              tester,
              (child) => AdaptiveOverlayPage<void>(
                child: child,
                backgroundColor: Colors.green,
                barrierColor: Colors.red,
              ),
              surface: const Size(400, 900),
            )
            as ModalBottomSheetRoute<void>;
    expect(route.backgroundColor, Colors.green);
    expect(route.modalBarrierColor, Colors.red);
  });

  testWidgets('renders its child on a narrow surface', (tester) async {
    await routeFor(
      tester,
      (child) => AdaptiveOverlayPage<void>(child: child),
      surface: const Size(400, 900),
    );
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('renders its child on a wide surface', (tester) async {
    // The dialog branch dropped most of its configuration in 1.x and reached
    // back through `ModalRoute.of(context)!.settings` for the child, which
    // threw as soon as anything wrapped the route.
    await routeFor(
      tester,
      (child) => AdaptiveOverlayPage<void>(
        child: child,
        backgroundColor: Colors.blue,
        elevation: 4,
      ),
      surface: const Size(1200, 900),
    );
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('a null heightFactor lets the content size itself', (
    tester,
  ) async {
    await routeFor(
      tester,
      (child) => AdaptiveOverlayPage<void>(child: child, heightFactor: null),
      surface: const Size(400, 900),
    );
    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('forwards drag and dismissal settings', (tester) async {
    final route =
        await routeFor(
              tester,
              (child) => AdaptiveOverlayPage<void>(
                child: child,
                enableDrag: false,
                barrierDismissible: false,
                showDragHandle: true,
              ),
              surface: const Size(400, 900),
            )
            as ModalBottomSheetRoute<void>;
    expect(route.enableDrag, isFalse);
    expect(route.isDismissible, isFalse);
    expect(route.showDragHandle, isTrue);
  });
}

import 'package:auto_go_route/auto_go_route.dart';
import 'package:example/src/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

@AutoGoRouteShell(
  path: '/bottom-sheet',
  name: 'bottomSheetRoute',
  pageBuilder: 'adaptiveOverlayPageBuilder',
)
class BottomSheetRoute extends StatelessWidget {
  final Widget child;

  const BottomSheetRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

Page<dynamic> adaptiveOverlayPageBuilder(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return AdaptiveOverlayPage(
    child: child,
    // You now have full control to set any property you want!
    barrierDismissible: false,
    heightFactor: 0.9,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  );
}

@AutoGoRoute(
  path: '/content',
  parent: BottomSheetRoute,
  name: 'bottomSheetContent',
)
class BottomSheetContent extends StatelessWidget {
  const BottomSheetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          onPressed: () => context.pushToBottomSheetNext(),
          child: const Text('Next'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () => context.pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

@AutoGoRoute(path: '/next', parent: BottomSheetRoute, name: 'bottomSheetNext')
class BottomSheetNextRoute extends StatelessWidget {
  const BottomSheetNextRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bottom Sheet Next')),
      body: const Center(child: Text('Hello')),
    );
  }
}

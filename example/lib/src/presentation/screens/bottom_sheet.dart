import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../widgets/location_bar.dart';

/// Presents this shell's children as a bottom sheet on phones and a dialog on
/// wide screens, while keeping their URLs real and shareable.
Page<dynamic> adaptiveOverlayPageBuilder(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => AdaptiveOverlayPage(
  child: child,
  showDragHandle: true,
  heightFactor: 0.55,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
);

/// A non-stateful shell whose `pageBuilder` turns its children into an
/// adaptive overlay.
@AutoGoRouteShell(
  path: '/bottom-sheet',
  name: 'bottomSheetShell',
  pageBuilder: 'adaptiveOverlayPageBuilder',
  initialRoute: '/content',
  description: 'Overlay shell: bottom sheet on phones, dialog on desktop.',
)
class BottomSheetRoute extends StatelessWidget {
  /// Creates the overlay shell.
  const BottomSheetRoute({super.key, required this.child});

  /// The child navigator go_router hands in.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The overlay's first page.
@AutoGoRoute(
  path: '/content',
  parent: BottomSheetRoute,
  name: 'bottomSheetContent',
)
class BottomSheetContent extends StatelessWidget {
  /// Creates the sheet content.
  const BottomSheetContent({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.layers_rounded, size: 40, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            'Adaptive overlay',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'This sheet has its own URL.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const LocationBar.router(),
          const SizedBox(height: 8),
          Text(
            'A bottom sheet on phones, a dialog on wide screens — and a real, '
            'shareable location either way.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          FilledButton(
            onPressed: context.pushToBottomSheetNext,
            child: const Text('Next'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: context.pop, child: const Text('Close')),
        ],
      ),
    );
  }
}

/// The overlay's second page.
@AutoGoRoute(path: '/next', parent: BottomSheetRoute, name: 'bottomSheetNext')
class BottomSheetNextRoute extends StatelessWidget {
  /// Creates the second sheet page.
  const BottomSheetNextRoute({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sheet · next')),
    body: Center(
      child: TextButton(onPressed: context.pop, child: const Text('Back')),
    ),
  );
}

import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../widgets/location_bar.dart';

/// A full-screen flow that covers the bottom navigation bar and asks before
/// it is dismissed.
///
/// Demonstrates three things at once: `parentNavigatorKey` (drawn on the root
/// navigator, so the shell's `NavigationBar` is hidden), `onExit` (the
/// confirm-before-leaving prompt), and a slide-up transition.
@AutoGoRoute(
  path: '/onboarding',
  description: 'Full-screen onboarding drawn over the dashboard shell.',
  parentNavigatorKey: 'rootNavigatorKey',
  onExit: 'confirmLeaveOnboarding',
  transition: AutoRouteTransition.slideUp,
  transitionDurationMs: 350,
  metadata: {'requiresAuth': true},
)
class OnboardingRoute extends StatelessWidget {
  const OnboardingRoute({super.key, this.step = 1});

  /// Read from `?step=`, typed, with the widget's own default.
  final int step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Onboarding — step $step'),
        bottom: const LocationBar(),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Step $step of 3', style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 24),
            if (step < 3)
              FilledButton(
                onPressed: () =>
                    context.replaceInPlaceWithOnboardingRoute(step: step + 1),
                child: const Text('Next'),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.popOrGo('/home-screen'),
              child: const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}

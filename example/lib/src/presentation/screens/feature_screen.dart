import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

/// A route behind a feature flag, enforced by a route-level guard.
@AutoGoRoute(
  path: '/new-feature',
  name: 'newFeatureRoute',
  middleware: ['featureFlagMiddleware'],
  description: 'Guarded by a middleware function that always redirects.',
)
class NewFeatureRoute extends StatelessWidget {
  /// Creates the screen.
  const NewFeatureRoute({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    // Never shown: the guard redirects first.
    body: Center(child: Text('The new feature.')),
  );
}

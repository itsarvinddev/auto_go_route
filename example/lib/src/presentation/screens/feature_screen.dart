// lib/src/presentation/screens/feature_screen.dart
import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

@AutoGoRoute(path: '/new-feature', middleware: ['featureFlagMiddleware'])
class NewFeatureRoute extends StatelessWidget {
  const NewFeatureRoute({super.key});

  @override
  Widget build(BuildContext context) {
    // This UI will not be displayed due to the middleware redirect.
    return const Scaffold(
      body: Center(
        child: Text('This is the new feature page!'),
      ),
    );
  }
}
// lib/src/presentation/screens/home_screen.dart
import 'package:auto_go_route/auto_go_route.dart';
import 'package:example/src/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth_service.dart';
import '../widgets/route_button.dart';
import 'dashboard_shell.dart';

@AutoGoRoute(path: '/home', parent: DashboardShell, order: 0)
class HomeRoute extends StatelessWidget {
  final String? featureDisabled;

  const HomeRoute({super.key, this.featureDisabled});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Show a snackbar if redirected from the feature-flag middleware
    if (featureDisabled == 'true') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The requested feature is currently disabled.'),
            backgroundColor: Colors.amber,
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoGoRoute Example'),
        actions: [
          IconButton(
            icon: Icon(authService.isLoggedIn ? Icons.logout : Icons.login),
            onPressed: () {
              if (authService.isLoggedIn) {
                authService.logout();
              } else {
                // GoRouter's refreshListenable will handle the redirect
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Welcome!', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          const Text('Try these routes:'),
          const SizedBox(height: 10),
          RouteButton(
            label: 'View Products',
            onPressed: () => context.pushToProductListRoute(),
          ),
          RouteButton(
            label: 'View Product (ID: 123)',
            onPressed: () => context.pushToProductDetailsRoute(
              id: '123',
              queries: {'name': 'Product 123'},
            ),
          ),
          RouteButton(
            label: 'View Product Reviews (ID: 123)',
            onPressed: () => context.pushToProductReviewsRoute(
              id: '123',
              queries: {'name': 'Product 123'},
            ),
          ),
          RouteButton(
            label: 'Go to Legacy Profile (Redirects)',
            onPressed: () => context.goToLegacyProfileRoute(),
          ),
          RouteButton(
            label: 'Go to Disabled Feature (Redirects)',
            onPressed: () => context.pushToNewFeatureRoute(),
          ),
          RouteButton(
            label: 'Go to a Non-existent Route',
            onPressed: () => context.push('/this-route-does-not-exist'),
          ),
        ],
      ),
    );
  }
}

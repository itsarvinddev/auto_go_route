import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../auth_service.dart';
import '../models/product.dart';
import '../widgets/route_button.dart';
import 'dashboard_shell.dart';
import 'product_screens.dart';

/// The home tab, and the dashboard shell's first branch.
@AutoGoRoute(
  path: '/home-screen',
  name: 'homeRoute',
  parent: DashboardShell,
  order: 0,
  description: 'Home tab. Also the location the root "/" redirects to.',
)
@AutoGoRouteBranch(preload: true)
class HomeRoute extends StatelessWidget {
  /// Creates the home tab.
  const HomeRoute({super.key, this.featureDisabled});

  /// Read from `?feature-disabled=true`.
  ///
  /// `@QueryParam` renames it, because `feature-disabled` is not a Dart
  /// identifier — and the type is `bool?`, so the value is decoded rather than
  /// compared as a string.
  @QueryParam('feature-disabled')
  final bool? featureDisabled;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (featureDisabled == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That feature is currently disabled.')),
        );
      });
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('auto_go_route'),
        actions: [
          IconButton(
            tooltip: auth.isLoggedIn ? 'Sign out' : 'Sign in',
            icon: Icon(auth.isLoggedIn ? Icons.logout : Icons.login),
            onPressed: () => auth.isLoggedIn ? auth.logout() : auth.login(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: context.pushToBottomSheetContent,
        icon: const Icon(Icons.layers_outlined),
        label: const Text('Open sheet'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every route below is generated from an annotated widget, '
                  'with typed parameters and guards.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 14),
                Chip(
                  side: BorderSide.none,
                  backgroundColor: scheme.onPrimaryContainer.withValues(
                    alpha: 0.14,
                  ),
                  avatar: Icon(
                    auth.isLoggedIn
                        ? Icons.verified_user
                        : Icons.person_outline,
                    size: 18,
                  ),
                  label: Text(
                    auth.isLoggedIn ? 'Signed in as ${auth.role}' : 'Guest',
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('Typed parameters'),
          RouteButton(
            label: 'Products (typed enum + list query)',
            subtitle: '/products?sort=priceAsc&tags=new&tags=sale',
            icon: Icons.tune_rounded,
            onPressed: () => context.pushToProductList(
              sort: ProductSort.priceAsc,
              tags: const ['new', 'sale'],
            ),
          ),
          RouteButton(
            label: 'Product #123 with an extra payload',
            subtitle: context.locationOfProductDetails(
              id: 123,
              name: 'Product 123',
            ),
            icon: Icons.shopping_bag_outlined,
            onPressed: () => context.pushToProductDetails(
              id: 123,
              name: 'Product 123',
              extra: Product(
                id: '123',
                name: 'Product 123',
                description: 'Passed through state.extra',
                price: '100',
              ),
            ),
          ),
          const SectionLabel('Shells & pages'),
          RouteButton(
            label: 'Settings tab (typed branch switch)',
            subtitle: 'DashboardShellBranch.settings.goFrom()',
            icon: Icons.tab_rounded,
            // No StatefulNavigationShell in hand here — `goFrom` finds the
            // enclosing one.
            onPressed: () => DashboardShellBranch.settings.goFrom(context),
          ),
          RouteButton(
            label: 'Onboarding (full screen, asks before leaving)',
            subtitle: 'parentNavigatorKey · onExit · slideUp',
            icon: Icons.rocket_launch_outlined,
            onPressed: () => context.pushToOnboardingRoute(),
          ),
          const SectionLabel('Guards & redirects'),
          RouteButton(
            label: 'Legacy /account (route-level redirect)',
            subtitle: '/account → /profile',
            icon: Icons.alt_route_rounded,
            onPressed: () => context.goToLegacyProfileRoute(),
          ),
          RouteButton(
            label: 'Disabled feature (guard redirects back here)',
            subtitle: "middleware: ['featureFlagMiddleware']",
            icon: Icons.flag_outlined,
            onPressed: () => context.pushToNewFeatureRoute(),
          ),
          RouteButton(
            label: 'A location that does not exist',
            subtitle: '/nope → errorWidget',
            icon: Icons.error_outline_rounded,
            onPressed: () => context.push('/nope'),
          ),
        ],
      ),
    );
  }
}

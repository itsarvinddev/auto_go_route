import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../auth_service.dart';
import '../widgets/location_bar.dart';
import '../widgets/route_button.dart';
import 'dashboard_shell.dart';

/// The settings tab. `order: 2` fixes it as the third branch.
@AutoGoRoute(
  path: '/settings',
  name: 'settings',
  parent: DashboardShell,
  order: 2,
  description: 'Settings tab.',
)
class SettingsRoute extends StatelessWidget {
  /// Creates the settings tab.
  const SettingsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: const LocationBar(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  auth.isLoggedIn ? Icons.verified_user : Icons.person_outline,
                ),
              ),
              title: Text(auth.isLoggedIn ? 'Signed in' : 'Not signed in'),
              subtitle: Text(
                'Signed in: ${auth.isLoggedIn} · role: ${auth.role}',
              ),
              trailing: FilledButton.tonal(
                onPressed: () =>
                    auth.isLoggedIn ? auth.logout() : auth.login(role: 'admin'),
                child: Text(auth.isLoggedIn ? 'Sign out' : 'Sign in as admin'),
              ),
            ),
          ),
          const SectionLabel('Metadata guard'),
          RouteButton(
            label: 'Admin area (requires the admin role)',
            subtitle: "metadata: {'requiresRole': 'admin'}",
            icon: Icons.admin_panel_settings_outlined,
            onPressed: () => context.goToAdminRoute(),
          ),
        ],
      ),
    );
  }
}

/// Guarded purely by metadata — the top-level `appRedirect` reads it.
@AutoGoRoute(
  path: '/admin',
  name: 'adminRoute',
  description: 'Role-guarded screen. The guard reads the route metadata.',
  metadata: {'requiresAuth': true, 'requiresRole': 'admin'},
  transition: AutoRouteTransition.scale,
)
class AdminRoute extends StatelessWidget {
  /// Creates the admin screen.
  const AdminRoute({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin'), bottom: const LocationBar()),
    body: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.admin_panel_settings_rounded, size: 72),
          SizedBox(height: 16),
          Text('You have the admin role.'),
        ],
      ),
    ),
  );
}

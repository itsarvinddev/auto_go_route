import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

import '../../app_router.dart';

/// The bottom-navigation shell.
///
/// `isStateful: true` makes each child a `StatefulShellBranch` with its own
/// navigator, so switching tabs preserves each tab's stack.
@AutoGoRouteShell(
  path: '/',
  isStateful: true,
  description: 'Bottom navigation shell. Each child route becomes a branch.',
)
class DashboardShell extends StatelessWidget {
  /// Creates the shell.
  const DashboardShell({super.key, required this.navigationShell});

  /// The shell go_router hands in, carrying the branch navigators.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        // The generated `DashboardShellBranch` enum follows the branches'
        // `order:` values, so a destination's position and the branch it
        // opens cannot drift apart.
        onDestinationSelected: (index) {
          final branch = DashboardShellBranch.values[index];
          branch.go(
            navigationShell,
            // Tapping the active tab returns it to its root.
            initialLocation: branch.isActiveIn(navigationShell),
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

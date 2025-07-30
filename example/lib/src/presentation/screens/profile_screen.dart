// lib/src/presentation/screens/profile_screen.dart
import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

import 'dashboard_shell.dart';

@AutoGoRoute(path: '/profile', parent: DashboardShell, order: 1)
class ProfileRoute extends StatelessWidget {
  const ProfileRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, size: 80, color: Colors.greenAccent),
            SizedBox(height: 16),
            Text('This is a protected route.'),
          ],
        ),
      ),
    );
  }
}

// This route demonstrates a simple redirect.
// The `legacyProfileRedirect` middleware will always redirect it to `/profile`.
@AutoGoRoute(path: '/account', middleware: ['legacyProfileRedirect'])
class LegacyProfileRoute extends StatelessWidget {
  const LegacyProfileRoute({super.key});

  @override
  Widget build(BuildContext context) {
    // This UI will never be seen because of the redirect.
    return const Scaffold(body: Center(child: Text('This is a legacy page.')));
  }
}

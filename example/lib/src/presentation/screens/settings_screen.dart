// lib/src/presentation/screens/settings_screen.dart
import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

import 'dashboard_shell.dart';

@AutoGoRoute(path: '/settings', parent: DashboardShell, order: 2)
class SettingsRoute extends StatelessWidget {
  const SettingsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_applications,
              size: 80,
              color: Colors.cyanAccent,
            ),
            SizedBox(height: 16),
            Text('User settings page.'),
          ],
        ),
      ),
    );
  }
}

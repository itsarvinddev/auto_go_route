// lib/src/presentation/screens/profile_screen.dart
import 'package:auto_go_route/auto_go_route.dart';
import 'package:example/src/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import 'dashboard_shell.dart';

@AutoGoRouteShell(path: '/profile-shell', parent: DashboardShell, order: 1)
class ProfileRoute extends StatefulWidget {
  final Widget child;
  const ProfileRoute({super.key, required this.child});

  @override
  State<ProfileRoute> createState() => _ProfileRouteState();
}

class _ProfileRouteState extends State<ProfileRoute>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            _tabController.animateTo(index);
            switch (index) {
              case 0:
                context.go('/profile');
                break;
              case 1:
                context.go('/settings-tab');
                break;
              case 2:
                context.go('/notifications');
                break;
            }
          },
          tabs: [
            Tab(text: 'Profile'),
            Tab(text: 'Settings'),
            Tab(text: 'Notifications'),
          ],
        ),
      ),

      body: widget.child,
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

@AutoGoRoute(path: '/profile', parent: ProfileRoute, order: 0)
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user, size: 80, color: Colors.greenAccent),
          SizedBox(height: 16),
          Text('This is a protected route.'),
        ],
      ),
    );
  }
}

@AutoGoRoute(path: '/settings-tab', parent: ProfileRoute, order: 1)
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings'));
  }
}

@AutoGoRoute(path: '/notifications', parent: ProfileRoute, order: 2)
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Notifications'),
        ElevatedButton(
          onPressed: () {
            context.pushToNotificationDetail(
              id: "N3424",
              extra: User(
                id: "U3424",
                name: "John Doe",
                email: "john.doe@example.com",
              ),
            );
          },
          child: const Text('Go to Notification 1'),
        ),
        ElevatedButton(
          onPressed: () {
            context.pushToNotificationAction(
              id: "N3424",
              queries: {"action": "read"},
            );
          },
          child: const Text('Go to Notification 1 Action (read)'),
        ),
      ],
    );
  }
}

@AutoGoRoute(path: '/:id', parent: NotificationsTab)
class NotificationDetail extends StatelessWidget {
  final String id;
  final User? user;
  const NotificationDetail({super.key, required this.id, this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications, size: 80, color: Colors.blueAccent),
            SizedBox(height: 16),
            Text('Notification Detail: $id'),
            ElevatedButton(
              onPressed: () {
                context.pushToNotificationAction(
                  id: id,
                  queries: {"action": "read"},
                );
              },
              child: const Text('Action'),
            ),
            const SizedBox(height: 16),
            Text(
              'User Details: ${user?.toJson().toString() ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.pop();
              },
              child: const Text('Back to Notifications'),
            ),
          ],
        ),
      ),
    );
  }
}

@AutoGoRoute(path: '/action', parent: NotificationDetail)
class NotificationAction extends StatelessWidget {
  final String action;
  const NotificationAction({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications, size: 80, color: Colors.blueAccent),
            SizedBox(height: 16),
            Text('Notification Action: $action'),
            ElevatedButton(
              onPressed: () {
                context.pop();
              },
              child: const Text('Back to Notification Detail'),
            ),
          ],
        ),
      ),
    );
  }
}

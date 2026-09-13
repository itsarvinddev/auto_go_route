import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../models/user.dart';
import '../widgets/location_bar.dart';
import '../widgets/route_button.dart';
import 'dashboard_shell.dart';

/// What a notification action does. Decoded from `?action=`.
enum NotificationAction {
  /// Open the notification.
  view,

  /// Mark it read.
  read,

  /// Archive it.
  archive,
}

/// A nested, non-stateful shell inside the dashboard's second branch.
///
/// Gives the profile tabs a shared `AppBar` with its own navigator, so routes
/// elsewhere can target it by `parentNavigatorKey`.
@AutoGoRouteShell(
  path: '/profile-shell',
  name: 'profileShell',
  parent: DashboardShell,
  order: 1,
  navigatorKey: 'profileNavigatorKey',
  initialRoute: '/profile',
  description: 'Tabbed profile shell nested inside the dashboard shell.',
)
class ProfileRoute extends StatelessWidget {
  /// Creates the profile shell.
  const ProfileRoute({super.key, required this.child});

  /// The child navigator go_router hands in.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tabs = <String, String>{
      'Profile': ProfileTabRoute.routeTemplate,
      'Settings': SettingsTabRoute.routeTemplate,
      'Notifications': NotificationsTabRoute.routeTemplate,
    };
    final current = context.currentRouteTemplate;
    final index = tabs.values.toList().indexOf(current ?? '');

    final selected = index < 0 ? 0 : index;

    // Keyed on the selected tab so the controller is recreated — not leaked —
    // when the location changes: the URL is the source of truth, so the
    // selected tab is derived from it rather than kept in local state.
    return DefaultTabController(
      key: ValueKey(selected),
      length: tabs.length,
      initialIndex: selected,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My profile'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(92),
            child: Column(
              children: [
                const LocationBar.router(),
                TabBar(
                  onTap: (i) => context.go(tabs.values.elementAt(i)),
                  tabs: [for (final label in tabs.keys) Tab(text: label)],
                ),
              ],
            ),
          ),
        ),
        body: child,
      ),
    );
  }
}

/// `/account` moved; this route exists only to redirect.
@AutoGoRoute(
  path: '/account',
  name: 'legacyProfileRoute',
  redirect: 'legacyProfileRedirect',
  description: 'Legacy location, redirects to the profile tab.',
)
class LegacyProfileRoute extends StatelessWidget {
  /// Creates the placeholder.
  const LegacyProfileRoute({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Redirecting…')));
}

/// The profile tab.
@AutoGoRoute(
  path: '/profile',
  name: 'profileTab',
  parent: ProfileRoute,
  order: 0,
  metadata: {'requiresAuth': true},
  description: 'Auth-guarded profile tab.',
)
class ProfileTab extends StatelessWidget {
  /// Creates the profile tab.
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  'JD',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jane Doe',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'jane@example.com',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This route is guarded by its metadata.',
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "metadata: {'requiresAuth': true}",
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'A non-stateful shell nested inside the dashboard\'s stateful shell: '
          'the tabs above share an app bar and their own navigator.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The settings tab inside the profile shell.
@AutoGoRoute(
  path: '/settings-tab',
  name: 'settingsTab',
  parent: ProfileRoute,
  order: 1,
)
class SettingsTab extends StatelessWidget {
  /// Creates the tab.
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Profile settings'));
}

/// The notifications tab, parent of the notification detail route.
@AutoGoRoute(
  path: '/notifications',
  name: 'notificationsTab',
  parent: ProfileRoute,
  order: 2,
)
class NotificationsTab extends StatelessWidget {
  /// Creates the tab.
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const SectionLabel('Typed nested routes'),
      RouteButton(
        label: 'Open notification N3424',
        subtitle: context.locationOfNotificationDetail(id: 'N3424'),
        icon: Icons.notifications_active_outlined,
        onPressed: () => context.pushToNotificationDetail(
          id: 'N3424',
          extra: User(
            id: 'U3424',
            name: 'John Doe',
            email: 'john.doe@example.com',
          ),
        ),
      ),
      RouteButton(
        label: 'Mark N3424 read',
        subtitle: context.locationOfNotificationActionScreen(
          id: 'N3424',
          action: NotificationAction.read,
        ),
        icon: Icons.mark_email_read_outlined,
        onPressed: () => context.pushToNotificationActionScreen(
          id: 'N3424',
          action: NotificationAction.read,
        ),
      ),
    ],
  );
}

/// Notification detail, nested under the notifications tab.
@AutoGoRoute(
  path: ':id',
  name: 'notificationDetail',
  parent: NotificationsTab,
  description: 'Nested detail route with a relative path.',
)
class NotificationDetail extends StatelessWidget {
  /// Creates the detail screen.
  const NotificationDetail({super.key, required this.id, this.user});

  /// Read from the path.
  final String id;

  /// Carried in `state.extra`, so absent on a cold deep link.
  final User? user;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Notification $id'),
      bottom: const LocationBar(),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications, size: 72),
          const SizedBox(height: 16),
          Text('Notification $id'),
          const SizedBox(height: 8),
          Text('User: ${user?.toJson() ?? 'not passed (deep link)'}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.pushToNotificationActionScreen(
              id: id,
              action: NotificationAction.archive,
            ),
            child: const Text('Archive'),
          ),
          ElevatedButton(onPressed: context.pop, child: const Text('Back')),
        ],
      ),
    ),
  );
}

/// The action screen, nested under the detail route.
@AutoGoRoute(
  path: 'action',
  name: 'notificationActionScreen',
  parent: NotificationDetail,
)
class NotificationActionScreen extends StatelessWidget {
  /// Creates the action screen.
  const NotificationActionScreen({
    super.key,
    required this.id,
    this.action = NotificationAction.view,
  });

  /// Inherited from the parent's path.
  final String id;

  /// Read from `?action=read`, decoded into the enum, defaulting to
  /// [NotificationAction.view] when absent.
  final NotificationAction action;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${action.name} $id'),
      bottom: const LocationBar(),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Action "${action.name}" on notification $id'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: context.pop, child: const Text('Back')),
        ],
      ),
    ),
  );
}

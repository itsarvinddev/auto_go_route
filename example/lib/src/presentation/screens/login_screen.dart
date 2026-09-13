import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth_service.dart';
import '../widgets/location_bar.dart';

/// The login screen. `?from=` carries where to return to.
@AutoGoRoute(
  path: '/login',
  name: 'loginRoute',
  description: 'Sign-in screen. The guard sends unauthenticated users here.',
  transition: AutoRouteTransition.fade,
)
class LoginRoute extends StatelessWidget {
  /// Creates the login screen.
  const LoginRoute({super.key, this.from});

  /// Read from `?from=/some/location`, set by the top-level guard.
  final String? from;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in'), bottom: const LocationBar()),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 36,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'This area needs an account.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (from != null) ...[
                const SizedBox(height: 8),
                Text(
                  'You will return to $from',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    context.read<AuthService>().login();
                    if (from != null) context.go(from!);
                  },
                  child: const Text('Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

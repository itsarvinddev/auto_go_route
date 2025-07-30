// lib/src/presentation/screens/login_screen.dart
import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth_service.dart';

@AutoGoRoute(path: '/login')
class LoginRoute extends StatelessWidget {
  const LoginRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You need to be logged in to access this area.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Provider.of<AuthService>(context, listen: false).login();
              },
              child: const Text('Log In'),
            ),
          ],
        ),
      ),
    );
  }
}
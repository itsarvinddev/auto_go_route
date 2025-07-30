// lib/src/presentation/screens/error_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ErrorScreen extends StatelessWidget {
  final Exception? error;
  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 20),
            const Text(
              '404 - Oops!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'The page you are looking for does not exist.',
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 20),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go to Homepage'),
            ),
          ],
        ),
      ),
    );
  }
}
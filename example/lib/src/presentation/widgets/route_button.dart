// lib/src/presentation/widgets/route_button.dart
import 'package:flutter/material.dart';

class RouteButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const RouteButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.deepPurpleAccent.withOpacity(0.8),
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
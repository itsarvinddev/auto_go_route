import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app_router.dart';
import 'src/auth_service.dart';

/// The app's router. Built once, outside `build`, so hot reload does not
/// discard the navigation stack.
final appRouter = AppRouter();

/// Runtime configuration lives here rather than in the annotation: the
/// generated `buildRouter()` accepts every `GoRouter` option as a named
/// argument, defaulting to what `@AutoGoRouteBase` declared.
final router = appRouter.buildRouter(
  refreshListenable: authService,
  debugLogDiagnostics: kDebugMode,
);

void main() {
  runApp(
    ChangeNotifierProvider.value(value: authService, child: const ExampleApp()),
  );
}

/// The example application.
class ExampleApp extends StatelessWidget {
  /// Creates the app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'auto_go_route example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      routerConfig: router,
    );
  }
}

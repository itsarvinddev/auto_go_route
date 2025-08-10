# Auto Go Route

[![Pub Version](https://img.shields.io/pub/v/auto_go_route?color=blue&style=plastic)](https://pub.dev/packages/auto_go_route)
[![GitHub Repo stars](https://img.shields.io/github/stars/itsarvinddev/auto_go_route?color=gold&style=plastic)](https://github.com/itsarvinddev/auto_go_route/stargazers)
[![GitHub Repo forks](https://img.shields.io/github/forks/itsarvinddev/auto_go_route?color=slateblue&style=plastic)](https://github.com/itsarvinddev/auto_go_route/fork)
[![GitHub Repo issues](https://img.shields.io/github/issues/itsarvinddev/auto_go_route?color=coral&style=plastic)](https://github.com/itsarvinddev/auto_go_route/issues)
[![GitHub Repo contributors](https://img.shields.io/github/contributors/itsarvinddev/auto_go_route?color=green&style=plastic)](https://github.com/itsarvinddev/auto_go_route/graphs/contributors)

A powerful, type-safe, and feature-rich routing package for Flutter with automatic code generation. Built on top of GoRouter with enhanced developer experience and production-ready features.

<img src="https://raw.githubusercontent.com/itsarvinddev/auto_go_route/refs/heads/main/auto_go_route.webp" width="400" height="600">

## Features

✨ **Type-Safe Navigation** - Compile-time route validation and parameter checking  
🔄 **Automatic Code Generation** - Zero boilerplate with `@AutoGoRoute` annotations  
📱 **Flutter-First** - Built specifically for Flutter with full widget integration  
🎯 **Parameter Auto-Detection** - Automatically extract required/optional parameters from paths  
📚 **Documentation Generation** - Auto-generate route documentation in multiple formats  
🔍 **Route Registry** - Centralized route management with validation and analytics  
⚡ **Performance Monitoring** - Built-in performance tracking and optimization  
🛡️ **Production Ready** - Comprehensive error handling and validation  
🐚 **Shell Routes** - Support for nested navigation with shell routes  
🔗 **Nested Routes** - Hierarchical route structure with parent-child relationships

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  auto_go_route: ^1.0.8 # Use the latest version
  go_router: ^16.0.0 # Match the version compatible with the package

dev_dependencies:
  build_runner: ^2.4.15 # Match the version compatible with the package
  auto_go_route_generator: ^1.0.8 # Use the latest version
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1\. Annotate Your Page Widgets

Add the `@AutoGoRoute` annotation to any widget you want to make a screen.

```dart
import 'package:flutter/material.dart';
import 'package:auto_go_route/auto_go_route.dart';

@AutoGoRoute(path: '/login')
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const Center(child: Text('Login Page')),
    );
  }
}
```

### 2\. Create a Central Router Class

This class is the entry point for the generator.

```dart
// lib/app_router.dart
import 'package:auto_go_route/auto_go_route.dart';

part 'app_router.routes.g.dart'; // IMPORTANT: Use `.routes.g.dart`

@AutoGoRouteBase(initialLocation: '/home')
class AppRouter extends _$AppRouter {}
```

### 3\. Generate Routes

Run the build runner to generate the necessary code.

```bash
dart run build_runner build
```

### 4\. Set Up and Use the Router

Instantiate your `AppRouter` and use the generated `buildRouter()` method in your `MaterialApp`.

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'app_router.dart';

void main() {
  runApp(const MyApp());
}

// Create an instance of your generated router
final appRouter = AppRouter();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter.buildRouter(),
    );
  }
}
```

### 5\. Navigate with Type-Safety and Ease

Use the generated `BuildContext` extension for the shortest, safest, and most convenient navigation.

```dart
// Navigate to a simple route
context.goToLogin();

// Navigate to a route with path parameters, query parameters, and extra data
context.pushToUserProfile(
  userId: 'user123',
  queries: {'ref': 'email_campaign'},
  extra: User(id: 'user123', name: 'John Doe'),
);
```

## Advanced Usage

### Parameters and `extra` Injection

The generator automatically injects path/query parameters (simple types) and the `extra` object (complex types) into your widget's constructor.

```dart
// The user object is passed as `extra`
@AutoGoRoute(path: '/user/:userId')
class UserProfilePage extends StatelessWidget {
  final String userId; // From path
  final String? tab;   // From query (optional)
  final User? user;    // From `extra` object

  const UserProfilePage({
    super.key,
    required this.userId,
    this.tab,
    this.user,
  });
  //...
}

// Navigation call
context.pushToUserProfile(
  userId: '123',
  queries: {'tab': 'settings'},
  extra: User(id: '123', name: 'Jane Doe'),
);
```

### Stateful Shell Routes (e.g., Bottom Navigation)

Use `@AutoGoRouteShell` with `isStateful: true`. Use the `order` property on children to define the order of the branches (and bottom navigation tabs).

```dart
@AutoGoRouteShell(
  path: '/',
  isStateful: true,
  // Automatically redirects from '/' to the first child's path ('/home')
)
class DashboardShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const DashboardShell({super.key, required this.navigationShell});
  // ... build Scaffold with BottomNavigationBar using navigationShell ...
}

@AutoGoRoute(path: '/home', parent: DashboardShell, order: 0)
class HomePage extends StatelessWidget { /* ... */ }

@AutoGoRoute(path: '/profile', parent: DashboardShell, order: 1)
class ProfilePage extends StatelessWidget { /* ... */ }
```

### Custom Page Transitions (Dialogs/Bottom Sheets)

Use the `pageBuilder` property on a **non-stateful** `ShellRoute` to wrap its children in a custom `Page`, like a dialog or bottom sheet.

**1. Define your Page Builder function:**

```dart
// lib/utils/adaptive_page_builder.dart
Page<dynamic> adaptiveOverlayPageBuilder(BuildContext context, GoRouterState state, Widget child) {
  // Return your custom Page class, e.g., AdaptiveOverlayPage
  return AdaptiveOverlayPage(
    child: child,
    barrierDismissible: false,
    heightFactor: 0.9,
  );
}
```

**2. Use it in your annotation:**

```dart
@AutoGoRouteShell(
  path: '/my-dialog-flow',
  pageBuilder: 'adaptiveOverlayPageBuilder', // Pass the function name as a string
)
class MyDialogShell extends StatelessWidget {
  // This widget is a placeholder for the annotation
  final Widget child;
  const MyDialogShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

@AutoGoRoute(path: '/step1', parent: MyDialogShell)
class DialogStep1 extends StatelessWidget { /* ... */ }
```

## Middleware (Route Guards)

Middleware functions intercept navigation to perform checks like authentication or feature flagging.

### 1\. Create a Middleware Function

The function must return `null` to allow navigation or a `String` path to redirect.

```dart
// lib/middleware/auth_middleware.dart
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

FutureOr<String?> authMiddleware(BuildContext context, GoRouterState state) {
  final isLoggedIn = ... // Your auth logic here
  if (!isLoggedIn) {
    return '/login'; // Redirect to login
  }
  return null; // Proceed
}
```

### 2\. Apply Middleware to a Route

Add the name of your middleware function (as a string) to the `middleware` list in the annotation.

```dart
@AutoGoRoute(
  path: '/profile',
  middleware: ['authMiddleware'], // Apply the guard
)
class ProfilePage extends StatelessWidget { ... }
```

## API Reference

### Annotations

#### `@AutoGoRoute`

```dart
@AutoGoRoute({
  required String path,        // Route path with parameters
  String? name,               // Optional route name
  String? description,        // Description for documentation
  List middleware = const [], // Middleware functions
  Type? parent,               // Parent route class for nesting
  int? order,                 // Order of the route in the parent
})
```

#### `@AutoGoRouteShell`

```dart
@AutoGoRouteShell({
  required String path,        // Shell route path
  String? name,               // Optional shell name
  String? description,        // Description for documentation
  String? navigatorKey,       // Navigator key identifier
  Type? parent,              // Parent shell for nesting
  bool isStateful = false,   // Use StatefulShellRoute
  String? initialRoute, // Auto-redirects from the shell's path to this path
  String? pageBuilder, // Custom page builder function name
})
```

#### `@AutoGoRouteBase`

```dart
@AutoGoRouteBase({
  String? initialLocation,    // Initial route location
  String? errorBuilder,       // Error page builder function name
  String? redirect,          // Global redirect function name
  String navigatorExtensionName = 'AutoGoRouteNavigation', // Extension name for navigation
})
```

### Extensions

#### `GoRouterStateTypeExtension`

```dart
T getParam(String key)              // Get typed parameter
T getRequiredParam(String key)      // Get required parameter
T getOptionalParam(String key, T defaultValue) // Get optional parameter
Map getTypedPathParameters()     // Get all path parameters
Map getTypedQueryParameters()    // Get all query parameters
bool hasParam(String key)              // Check if parameter exists
```

#### `TypeSafeNavigation`

```dart
void goToRoute(RoutePaths route, {...})      // Navigate to route
void pushRoute(RoutePaths route, {...})     // Push route
void replaceRoute(RoutePaths route, {...})  // Replace current route
void goWithParams(T route, Map params)   // Navigate with typed params
void goToRouteIfAuth(RoutePaths route, bool isAuth, {...}) // Conditional navigation
void safePop([Object? result])              // Safe pop operation
```

#### `AutoGoRouteNavigation`

A built-in extension on `BuildContext` that provides a set of methods to navigate to routes. You can rename the extension with
`@AutoGoRouteBase` annotation.

```dart
extension AutoGoRouteNavigation on BuildContext {
  void goToProfileRoute({Map<String, String>? queries}) {
    go(ProfileRouteRoute().pathWith(queries: queries));
  }

  void pushToProfileRoute({Map<String, String>? queries}) {
    push(ProfileRouteRoute().pathWith(queries: queries));
  }

  void replaceWithProfileRoute({Map<String, String>? queries}) {
    pushReplacement(ProfileRouteRoute().pathWith(queries: queries));
  }
}

// Usage
context.goToProfileRoute();
context.pushToProfileRoute();
context.replaceWithProfileRoute();
```

### Route Registry

```dart
void register(RoutePaths route)              // Register single route
void registerAll(List routes)    // Register multiple routes
void validateAllRoutes()                     // Validate all routes
String generateDocumentation({...})          // Generate documentation
RegistryStatistics get statistics            // Get registry statistics
```

## Package Structure

```
auto_go_route/
├── lib/
│   ├── auto_go_route.dart                    // Main export file
│   └── src/
│       ├── annotations/
│       │   └── auto_go_route.dart           // Route annotations
│       ├── base/
│       │   ├── route_paths.dart             // Base route class
│       │   ├── nested_route_paths.dart      // Nested route base
│       │   └── shell_route_paths.dart       // Shell route base
│       ├── extensions/
│       │   ├── go_router_state_extension.dart // Parameter extraction
│       │   ├── navigation_extensions.dart     // Navigation helpers
│       │   └── string.dart                    // String utilities
│       ├── registry/
│       │   └── route_registry.dart          // Route management
│       ├── utils/
│       │   └── route_utils.dart            // Route utilities
│       └── exceptions/
│           └── route_exceptions.dart        // Custom exceptions
└── generator/
    ├── lib/
    │   ├── auto_go_route_generator.dart     // Main generator export
    │   ├── builder.dart                     // Build configuration
    │   └── src/
    │       ├── generators/
    │       │   └── route_generator.dart     // Code generator
    │       └── utils/
    │           └── generator_utils.dart     // Generator utilities
    ├── build.yaml                          // Build configuration
    └── pubspec.yaml                         // Generator dependencies
```

## Migration Guide

### From manual GoRouter setup:

**Before:**

```dart
GoRoute(
  path: '/user/:id',
  builder: (context, state) {
    final id = state.pathParameters['id'] ?? '';
    return UserPage(userId: id);
  },
)
```

**After:**

```dart
@AutoGoRoute(path: '/user/:id')
class UserPage extends StatelessWidget {
  final String id;
  const UserPage({required this.id});
  // ...
}
```

### From other routing packages:

1. Replace route definitions with `@AutoGoRoute` annotations
2. Create a route base class extending `_$YourRouteClass`
3. Run code generation: `dart run build_runner build`
4. Update navigation calls to use generated route instances
5. Register routes in `RouteRegistry` for additional features

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Development Setup

```bash
# Clone the repository
git clone https://github.com/itsarvinddev/auto_go_route.git

# Install dependencies
cd auto_go_route
flutter pub get

# Install generator dependencies
cd generator
dart pub get
cd ..

# Generate code
dart run build_runner build

# Run tests
flutter test

# Run example app
cd example
flutter run
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Github: [itsarvinddev](https://github.com/itsarvinddev)
- X: [@itsarvinddev](https://x.com/itsarvinddev)
- Issues: [GitHub Issues](https://github.com/itsarvinddev/auto_go_route/issues)

Made with ❤️ by [Arvind Sangwan](https://github.com/itsarvinddev)

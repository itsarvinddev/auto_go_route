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
  auto_go_route: ^1.0.3
  go_router: ^16.0.0

dev_dependencies:
  build_runner: ^2.4.15
  auto_go_route_generator: ^1.0.3
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Annotate Your Pages

```dart
import 'package:flutter/material.dart';
import 'package:auto_go_route/auto_go_route.dart';

@AutoGoRoute(
  path: '/login',
  name: 'login',
  description: 'User login page',
)
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

### 2. Create Route Base Class

```dart
// lib/app_router.dart
import 'package:auto_go_route/auto_go_route.dart';
import 'package:go_router/go_router.dart';

part 'app_router.g.dart'; // Add this line

@AutoGoRouteBase(
  // You can set global options for your router here
  initialLocation: '/home',
)
class AppRouter extends _$AppRouter {
  List<RouteBase> get routes => _buildNestedRoutes();
  GoRouter get router => buildRouter();
}
```

### 3. Generate Routes

```bash
dart run build_runner build
```

### 4. Navigate with Type Safety

```dart
// Access generated routes
final routes = AppRoutes();

// Simple navigation
context.go(routes.loginRoute.path);

// Navigation with parameters
context.goToRoute(routes.userProfileRoute, params: {
  'userId': 'user123',
  'tab': 'settings',
});

// Using path with parameters
final userPath = routes.userProfileRoute.pathWith(
  userId: 'user123',
  tab: 'settings',
);
context.go(userPath);
```

## Advanced Usage

### Routes with Parameters

```dart
@AutoGoRoute(
  path: '/user/:userId/profile/:tab?',
  name: 'userProfile',
  description: 'User profile with optional tab',
)
class UserProfilePage extends StatelessWidget {
  final String userId;
  final String? tab;

  const UserProfilePage({
    super.key,
    required this.userId,
    this.tab,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile: $userId')),
      body: Column(
        children: [
          Text('User ID: $userId'),
          if (tab != null) Text('Tab: $tab'),
        ],
      ),
    );
  }
}
```

### Shell Routes for Navigation Structure

```dart
@AutoGoRouteShell(
  path: '/',
  isStateful: false, // default is false
  initialRoute: '/home' // Automatically redirects from '/' to '/home'
)
class DashboardShell extends StatelessWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
```

### Nested Routes

```dart
// This route's full path will be '/home'
@AutoGoRoute(
  path: '/home',
  parent: DashboardShell, // Nested inside the shell
)
class HomePage extends StatelessWidget { /* ... */ }

// This route's full path will be '/profile'
@AutoGoRoute(
  path: '/profile',
  parent: DashboardShell, // Also nested inside the shell
)
class ProfilePage extends StatelessWidget { /* ... */ }
```

### Type-Safe Parameter Extraction

```dart
// In your route builder - parameters are automatically extracted
@AutoGoRoute(path: '/product/:id/:variant?')
class ProductPage extends StatelessWidget {
  final String id;
  final String? variant;

  const ProductPage({
    super.key,
    required this.id,
    this.variant,
  });

  @override
  Widget build(BuildContext context) {
    // Parameters are automatically extracted and type-converted
    return Scaffold(
      body: Column(
        children: [
          Text('Product ID: $id'),
          if (variant != null) Text('Variant: $variant'),
        ],
      ),
    );
  }
}
```

### Navigation Extensions

```dart
// Access generated route instances
final appRouter = AppRouter();

// Type-safe navigation with auto-completion
context.goToRoute(appRouter.productRoute, params: {
  'id': 'product123',
  'variant': 'red',
});

// Navigation with queries
context.goToRoute(appRouter.searchRoute,
  params: {'query': 'flutter'},
  queries: {'category': 'development', 'sort': 'newest'}
);

// Safe navigation
context.safePop(); // Won't crash if can't pop

// Navigation with parameters validation
context.goWithParams(appRouter.userRoute, {
  'userId': 123, // Automatically converted to string
  'tab': 'settings',
});
```

## Route Registry and Documentation

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

## Authentication and Middleware

```dart
@AutoGoRoute(
  path: '/admin/dashboard',
  middleware: ['authMiddleware', 'adminMiddleware'],
)
class AdminDashboard extends StatelessWidget {
  // Your admin dashboard implementation
}
```

Middleware (or guards) are functions that intercept navigation to a route. They are perfect for handling authentication, feature flags, or other conditional logic.

### Step 1: Create a Middleware Function

A middleware is a top-level function that matches the `GoRouterRedirect` signature.

- Return `null` to allow navigation to proceed.
- Return a `String` path (e.g., `'/login'`) to redirect the user.

<!-- end list -->

```dart
// lib/middleware/auth_middleware.dart
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Assume you have an AuthService to check the user's status
final authService = AuthService();

FutureOr<String?> authMiddleware(BuildContext context, GoRouterState state) {
  // If the user is not logged in, redirect to the login page
  if (!authService.isLoggedIn) {
    return '/login';
  }

  // User is logged in, allow navigation
  return null;
}
```

### Step 2: Apply Middleware to a Route

In your route annotation, add the name of your middleware function to the `middleware` list.

```dart
@AutoGoRoute(
  path: '/profile',
  middleware: ['authMiddleware'], // Apply the guard here
)
class ProfilePage extends StatelessWidget {
  //...
}
```

### Chaining Middleware

You can apply multiple middleware functions to a single route. They will execute in the order they are listed. The first middleware to return a path will stop the chain and trigger a redirect.

```dart
@AutoGoRoute(
  path: '/admin/dashboard',
  middleware: [
    'authMiddleware',       // First, check if the user is logged in
    'adminAccessMiddleware', // Then, check if they have admin privileges
  ],
)
class AdminDashboardPage extends StatelessWidget {
  //...
}
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
})
```

#### `@AutoGoRouteBase`

```dart
@AutoGoRouteBase({
  String? initialLocation,    // Initial route location
  String? errorBuilder,       // Error page builder function name
  String? redirect,          // Global redirect function name
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

class UserPage extends StatelessWidget {
  final String id;
  const UserPage({required this.id});
  // ...
}
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

# Example

This package is a `build_runner` generator: it has no runtime API of its own,
so there is nothing to demonstrate here in isolation.

The worked example is the app in the runtime package's repository, which
exercises every annotation this generator reads:

**<https://github.com/itsarvinddev/auto_go_route/tree/main/example>**

The short version — add the generator as a `dev_dependency`, annotate a widget,
and run the builder:

```yaml
dependencies:
  auto_go_route: ^2.0.0

dev_dependencies:
  auto_go_route_generator: ^2.0.0
  build_runner: ^2.15.1
```

```dart
// lib/home_page.dart
@AutoGoRoute(path: '/home')
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  // ...
}

// lib/app_router.dart
import 'package:auto_go_route/auto_go_route.dart';
import 'home_page.dart';

part 'app_router.routes.g.dart';

@AutoGoRouteBase(initialLocation: '/home')
class AppRouter extends _$AppRouter {}
```

```bash
dart run build_runner build
```

```dart
final router = AppRouter().buildRouter();
// ...
context.goToHomePage();
```

Full documentation: <https://pub.dev/packages/auto_go_route>.

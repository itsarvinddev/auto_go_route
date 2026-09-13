/// Type-safe, code-generated routing for Flutter, built on `go_router`.
///
/// Annotate your widgets and the generator writes the router:
///
/// ```dart
/// // lib/pages/product_page.dart
/// @AutoGoRoute(path: '/products/:id')
/// class ProductPage extends StatelessWidget {
///   const ProductPage({super.key, required this.id});
///   final int id;   // typed, read from the path
///   // ...
/// }
///
/// // lib/app_router.dart
/// part 'app_router.routes.g.dart';
///
/// @AutoGoRouteBase(initialLocation: '/products/1')
/// class AppRouter extends _$AppRouter {}
///
/// // anywhere
/// context.goToProductPage(id: 42);
/// ```
///
/// This library re-exports `go_router`, so importing it is enough — you do not
/// need a second import for `GoRouter`, `GoRouterState`, `context.go` and the
/// rest.
library;

// The generated file is a `part` of the user's router library, so every type
// its signatures name has to resolve there. Re-exporting those few types means
// the router library needs only this import (plus its own widgets). Exporting
// an element that the user also imports from Flutter directly is not a
// conflict: it is the same declaration.
export 'dart:convert' show Codec;

export 'package:flutter/foundation.dart' show Listenable, ValueListenable;
export 'package:flutter/widgets.dart'
    show
        BuildContext,
        GlobalKey,
        NavigatorObserver,
        NavigatorState,
        Page,
        Widget;

export 'package:go_router/go_router.dart';

export 'src/annotations/auto_go_route.dart';
export 'src/base/nested_route_paths.dart';
export 'src/base/route_guard.dart';
export 'src/base/route_paths.dart';
export 'src/base/shell_route_paths.dart';
export 'src/codec/route_codec.dart';
export 'src/exceptions/route_exceptions.dart';
export 'src/extensions/go_router_state_extension.dart';
export 'src/extensions/navigation_extensions.dart';
export 'src/extensions/string.dart';
export 'src/pages/auto_transition_page.dart';
export 'src/registry/route_registry.dart';
export 'src/utils/overlay_route.dart';
export 'src/utils/route_utils.dart';

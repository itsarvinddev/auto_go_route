# Migrating to auto_go_route 2.0.0

2.0.0 fixes a set of defects that could not be fixed compatibly, and raises the
`go_router` floor two majors. Most apps need three edits: the dependency bump,
one `@AutoGoRouteBase` field rename, and typed arguments at navigation call
sites. Everything else below applies only if you hit it.

Start here, then work down. The compiler finds most of it for you.

```bash
flutter pub upgrade --major-versions
dart run build_runner build
flutter analyze
```

---

## 1. Dependencies and SDK

```yaml
# before
dependencies:
  auto_go_route: ^1.1.0
  go_router: ^16.0.0
dev_dependencies:
  auto_go_route_generator: ^1.1.0

# after
dependencies:
  auto_go_route: ^2.0.0
dev_dependencies:
  auto_go_route_generator: ^2.0.0
  build_runner: ^2.15.1
```

**Upgrade both packages together.** A 1.x `auto_go_route_generator` still
builds against `auto_go_route` 2.x without an error, but it ignores every
field 2.0 added — `redirect:`, `metadata:`, `transition:`, `onExit:`, typed
parameters — so guards silently stop running. After upgrading, check that
`flutter pub deps | grep auto_go_route` lists both at 2.x.

**Drop your direct `go_router` dependency and its imports.**
`auto_go_route` now re-exports `go_router`, so one import covers both. If you
keep the dependency, raise it to `>=17.5.0 <19.0.0` — `go_router: ^16.0.0`
conflicts with `auto_go_route` 2.x (`flutter pub upgrade --major-versions`
does this for you). Keeping a redundant import only adds noise.

Requires Flutter `>=3.38.1` / Dart `>=3.10.0`, which is what `go_router`
`17.5.0` needs — the lowest version exposing route `metadata`. (Flutter 3.38.0
bundles a pre-release Dart 3.10 that neither package accepts.) On Flutter
`>=3.44` pub selects `go_router` 18.x automatically.

**This is also the fix for the hanging build**
([#3](https://github.com/itsarvinddev/auto_go_route/issues/3)). 1.x pinned
`analyzer: ^7.0.0`, whose supported language version is 3.9.0; on Dart 3.10+
the build died with
`Missing implementation of visitDotShorthandPropertyAccess`.

## 2. `context.pushNamed` compiles again

**No action needed — this used to be a hard compile error.**

1.x declared an extension member named `pushNamed` on `BuildContext`, which
collided with `go_router`'s own. Any file importing both packages failed with
`ambiguous_extension_member_access`; the method body also called itself, so it
would have overflowed the stack. It is gone.

If you worked around it with an extension override, drop the override:

```dart
// before
TypeSafeNavigation(context).pushNamed('home');
// after
context.pushNamed('home');
```

`pushWithTransition` is also gone — it was byte-identical to `pushRoute` and
ignored its `transitionDuration`. Use `pushRoute`, and put the transition on
the route with `@AutoGoRoute(transition: ...)`.

### Renamed helpers still work, deprecated

Every other 1.x navigation helper still compiles, marked `@Deprecated` and
forwarding to its replacement, so you can migrate at your own pace. Two of them
now fail loudly where 1.x silently navigated somewhere else:

| 1.x | 2.0 | Behaviour change |
|---|---|---|
| `context.safePop([result])` | `context.popOrGo('/', result)` | — |
| `context.popOrHome()` | `context.popOrGo()` | — |
| `context.canPopSafely()` | `context.canPop()` | — |
| `context.goWithParams(route, params)` | `context.goToRouteWithParams(route, params)` | a `null` value throws instead of building a URL for a different route |
| `context.goToNamed(name, ...)` | `context.goNamed(name, ...)` (go_router) | an unknown name throws instead of going to `/` |
| `context.popUntilRoute(path)` | `context.popUntilLocation(location)` | compares the matched location, and is bounded |
| `router.location`, `router.safeLocation` | `router.currentLocation` | follows imperative pushes |
| `router.safeCurrentRouteName` | `router.currentMatchedLocation` | — |
| `context.currentRouteName`, `router.currentRouteName` | same name | now returns the route's **name**; 1.x returned its matched location, so every name comparison failed |
| `context.isOnRoute(route)` | same name | compares templates, so `/products/42` is on `/products/:id` |

The `currentLocation`, `currentRouteName` and `isOnRoute` family also now report
the route that is actually visible after a `push`; 1.x reported the one
underneath. The extensions carrying them were renamed (`NavigationState` →
`GoRouterStateAccess`, `GoRouterExtensions`/`GoRouterLocation` →
`AutoGoRouterExtensions`), which matters only if you used an explicit extension
override.

## 3. Navigation call sites are typed

Path and query parameters now carry the type the widget declares.

```dart
// widget
@AutoGoRoute(path: '/products/:id')
class ProductPage extends StatelessWidget {
  const ProductPage({super.key, required this.id});
  final int id;
}

// before
context.goToProductPage(id: '42');
// after
context.goToProductPage(id: 42);
```

Passing `'42'` is now a compile error, which is the point. If you would rather
not touch call sites, declare the field as `String`.

`queries:` still accepts a `Map`, now `Map<String, dynamic>`, and merges
alongside the route's own typed query parameters. An `Iterable` value expands
to a repeated key.

Every helper also gained a `fragment:` argument and a `locationOf…` sibling
that builds the URL without navigating.

## 4. `buildRouter` and `routes`

`buildRouter` used to take a single positional-ish `navigatorKey`. It now takes
every `GoRouter` option by name, each defaulting to the annotation, and
`_buildNestedRoutes()` is public as `routes`.

```dart
// before — the private method forced apps to hand-roll the router
class AppRouter extends _$AppRouter {
  List<RouteBase> get routes => _buildNestedRoutes();

  GoRouter get router => GoRouter(
    routes: routes,
    initialLocation: homeRouteRoute.path,
    refreshListenable: authService,
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
    redirect: (context, state) => authGuard(context, state, authService),
  );
}

// after
@AutoGoRouteBase(
  initialLocation: '/home',
  errorWidget: 'ErrorScreen.new',
  redirect: 'appRedirect',
)
class AppRouter extends _$AppRouter {}

final router = AppRouter().buildRouter(
  refreshListenable: authService,     // runtime values go here
  debugLogDiagnostics: kDebugMode,
);
```

`appRouter.routes` is public, so composing the tree into a router you build
yourself still works.

## 5. Optional path parameters are rejected

`go_router` has no optional path segments. 1.x accepted `:id?` and registered
the literal pattern `/search/:$1`, which nothing could match — the route was
silently unreachable. It is now a build error.

```dart
// before
@AutoGoRoute(path: '/search/:query?')

// after — pick one

// (a) a query parameter
@AutoGoRoute(path: '/search')
class SearchPage extends StatelessWidget {
  const SearchPage({super.key, this.query});
  final String? query;        // ?query=shoes
}

// (b) two explicit routes
@AutoGoRoute(path: '/search', name: 'search')
class SearchPage extends StatelessWidget { /* ... */ }

@AutoGoRoute(path: '/search/:query', name: 'searchFor')
class SearchForPage extends StatelessWidget {
  const SearchForPage({super.key, required this.query});
  final String query;
}
```

## 6. Parameters must have a source

1.x read *every* simple-typed constructor parameter out of the URL, whether or
not the route declared it, defaulting to `''`. A required parameter with no
derivable source is now a build error naming the parameter.

```dart
// before — `action` was read from ?action= and silently became ''
@AutoGoRoute(path: '/notifications/:id/action')
class NotificationAction extends StatelessWidget {
  const NotificationAction({super.key, required this.action});
  final String action;
}

// after — say where it comes from
const NotificationAction({super.key, this.action = 'view'});   // a default
// or
const NotificationAction({super.key, this.action});            // nullable
// or add `:action` to the path
```

Similarly, a route can carry only one `extra`. Two parameters of
URL-unrepresentable type is now a build error instead of one object cast to two
types.

## 7. `getParam` no longer fabricates values

```dart
// before: returned 0 / '' / false for a missing parameter,
//         and threw for a *present* nullable one
final page = state.getParam<int>('page');

// after: throws RouteParamFormatException when absent and T is non-nullable;
//        nullable type arguments now work when the value is present
final page = state.getParam<int?>('page');              // null when absent
final page = state.getOptionalParam<int>('page', 1);    // the old forgiving shape
```

`getParam<int?>`, `<double?>`, `<bool?>` and `<num>` used to throw whenever the
value was actually there — they switched on `T == int`, which is false for
`int?`. They work now.

New: `getEnumParam`, `getParamList`, `metadataAs<T>`, `extraAs<T>`, and
`RouteCodec` for direct use in guards and tests.

## 8. `errorBuilder` changed shape; error handlers are exclusive

1.x's `errorBuilder` expected a widget constructor taking a named `error`. That
shape now has its own field, and the old name means what `go_router` means:

```dart
// before
@AutoGoRouteBase(errorBuilder: 'ErrorScreen.new')

// after — pick the one that matches your function
@AutoGoRouteBase(errorWidget: 'ErrorScreen.new')      // (error: state.error)
@AutoGoRouteBase(errorBuilder: 'myErrorBuilder')      // (context, state) => Widget
@AutoGoRouteBase(errorPageBuilder: 'myErrorPage')     // (context, state) => Page
@AutoGoRouteBase(onException: 'handleException')      // (context, state, router)
```

`go_router` accepts exactly one of these. Supplying two is now a build error
rather than an assertion at app startup.

## 9. `RoutePaths` API

| before | after |
|---|---|
| `pathWithParams(params, queries:)` | still works; `location(params:, queries:, fragment:)` is the fuller form |
| `route.path` for an absolute path | `route.template` — `path` is the *declared* path, relative for a nested route |
| `NestedRoutePaths(parentPath:)` | `parentTemplate:` (`parentPath` remains as a getter) |
| `fullPath` | `template` (`fullPath` remains as a getter) |
| `requiredParams` / `optionalParams` | `pathParameters`; `optionalParams` is deprecated and always empty |
| `builder` non-null | nullable, alongside `pageBuilder` |

`props` no longer contains `builder`. Two instances of the same generated route
are now equal and hash stably — in 1.x they never were, because `builder` is a
fresh closure per construction. Equality compares `path`, `template`, `name`,
`description`, `caseSensitive` and `metadata` — not guards — so use `identical`
if you relied on reference semantics.

`ShellRoutePaths` now separates stateless from stateful builders
(`builder`/`pageBuilder` versus `statefulBuilder`/`statefulPageBuilder`), so
`isStateful` can no longer disagree with the widget's constructor. `toGoRoute`
on a shell is gone — it was an `assert(false)` placeholder; use `toShellRoute`
or `toStatefulShellRoute`.

## 10. `RouteRegistry`

```dart
// before — a process-wide singleton, silently overwriting duplicates
final registry = RouteRegistry();

// after
final registry = RouteRegistry.scoped();   // isolated; use this in tests
final registry = RouteRegistry.instance;   // the singleton, explicitly
```

`RouteRegistry()` still returns the singleton. Registering two different routes
under one name now throws instead of overwriting; pass `replace: true` if you
meant it.

`generateGoRoutes(globalRedirect:)` now **composes** the global redirect ahead
of each route's guards. In 1.x it overwrote `GoRoute.redirect`, silently
deleting every route's auth guard.

`generateDocumentation` no longer stamps `DateTime.now()` unless you pass
`generatedAt:`, so its output is reproducible.

## 11. `RouteUtils`

| before | after |
|---|---|
| `isValidPath` rejected every parameterised path | `isValidTemplate` (and `isValidPath`) accept them |
| `extractParamsFromPath(path)` returned the next segment as each value | `extractParams(template, location)` matches properly, `null` when it does not |
| `sanitizePath` lower-cased | `normalizePath` preserves case — `go_router` URLs are case-sensitive since 15.0 |
| `generateBreadcrumb` | `breadcrumbSegments` and `breadcrumbTrail` |
| `parseQueryString` dropped `=` in values | handles them, plus `parseQueryStringAll` |

`StringExtension.toBoolOrNull` now returns `null` for unrecognised input.
Previously `'no'` and `''` both read as `true`.

## 12. `AdaptiveOverlayPage`

`backgroundColor` is now separate from `barrierColor` — 1.x passed one value as
both, so setting a scrim colour repainted the sheet. `breakpoint` and
`dialogShape`/`dialogConstraints` are configurable, content is clipped to the
sheet's `shape` or the dialog's `dialogShape` (`clipBehavior` now defaults to
`Clip.antiAlias` rather than 1.x's `Clip.none`, which ignored the shape), and
the dialog branch honours the fields it previously dropped.

```dart
// before — one colour for two jobs
AdaptiveOverlayPage(child: child, barrierColor: Colors.black54)
// after
AdaptiveOverlayPage(
  child: child,
  barrierColor: Colors.black54,      // the scrim
  backgroundColor: Colors.white,     // the surface
)
```

## 13. Route names must be Dart identifiers, and unique after capitalisation

Names become part of `goTo…`/`pushTo…`, so `name: 'user-profile'` produced
`goToUser-profile` and killed the build with a formatter error naming no route.
Both are now build errors, reported against the annotation. Names colliding
only by case (`userProfile` and `UserProfile`) are rejected too.

## 14. Child routes: a warning, not an error

`go_router` joins a child's path onto its parent's, so a child written
absolutely is still concatenated:

```dart
@AutoGoRoute(path: '/products')
class ProductPage ...

@AutoGoRoute(path: '/reviews', parent: ProductPage)   // reachable at /products/reviews
class ReviewsPage ...
```

That behaviour is unchanged and correct, but the leading slash reads as "from
the root". The generator now warns and suggests the relative spelling. 1.x also
computed `fullPath` with naive string joining, so `pathWith` and the registered
pattern could disagree; both now use `go_router`'s own algorithm.

## 15. Annotations on generated classes are no longer discovered

The builder dropped `required_inputs: ['.dart']`, which had forced it to run
after every other Dart generator. The upside is that this builder no longer
blocks the build graph; the cost is that a route annotation on *generated* code
is not seen. Annotate a hand-written widget.

This is not user-recoverable through configuration — if you depended on it,
open an issue.

---

## 16. Shapes that are now build errors

Each of these used to generate a file that did not compile, or a router that
asserted at startup. The build now stops with a message naming the widget and
the fix:

- a shell with no child routes;
- `navigatorKey` or `observers` on a **stateful** shell — move them to
  `@AutoGoRouteBranch` on the child rooting each branch;
- a stateful-shell branch whose first route takes path parameters, without
  `@AutoGoRouteBranch(initialLocation:)`;
- a nested shell whose `initialRoute` points outside its own branch;
- a constructor parameter named `queries`, `fragment` or `extra`, which the
  generated helpers already use — rename it, and keep the wire name with
  `@QueryParam('queries')`;
- a route name that is a Dart keyword or `values`, `index`, `routeName` or
  `template` while the route enum is generated;
- an annotated widget, a parameter's type, or a named function that is not
  imported into the router library;
- `initialExtra` or `overridePlatformDefaultLocation` on `@AutoGoRouteBase`
  without an `initialLocation`.

## 17. `caseSensitive` is a default, not an override

`@AutoGoRoute(caseSensitive:)` is now `bool?`. Leave it unset to inherit
`@AutoGoRouteBase(caseSensitive:)`; set it to override. Source that passes a
value is unaffected. The difference is behavioural: a router-wide
`caseSensitive: false` no longer forces routes that declare `true` to be
insensitive.

## 18. Two routers in one package

Each `@AutoGoRouteBase` scans the whole package, so two routers both received
every route. That is unchanged, but the build now warns, and
`@AutoGoRouteBase(sourceGlobs: [...])` scopes a router to part of the package.

## New in 2.0.0

Worth adopting once you are building:

- **`metadata:`** on routes and shells, read with `state.metadataAs<T>()` — the
  clean way to write one guard for many routes.
- **`onExit:`** confirm-before-leaving, **`parentNavigatorKey:`** full-screen
  routes over a shell, **`caseSensitive:`**, **`onEnter:`**, **`observers:`**,
  **`restorationScopeId:`**, **`notifyRootObserver:`**, **`extraCodec:`**.
- **`@AutoGoRouteBranch`** for `preload`, `initialLocation`, `navigatorKey`,
  `observers` and `restorationScopeId` on a stateful shell's branches.
- **`transition:`** with ten presets, plus `transitionDurationMs`,
  `fullscreenDialog`, `opaque`, `barrierDismissible`, `restorationId`.
- **`@PathParam` / `@QueryParam` / `@RouteExtra` / `@RouteIgnore`** to override
  classification or rename a wire parameter.
- **`locationOf…`** and **`replaceInPlaceWith…`** helpers; `routeName` and
  `routeTemplate` constants per route; an **`AppRoute` enum** of every route.
- **`source_globs`** build option to narrow the annotation scan, and
  **`@AutoGoRouteBase(sourceGlobs:)`** to scope one router among several.
- **`List<T>` query parameters** for every scalar type, not just strings.
- **`buildRoutingConfig()` / `buildDynamicRouter()`** for routes that change
  at runtime, and a **`<Shell>Branch` enum** per stateful shell to replace
  bare `goBranch(index)` calls.

## If something is still wrong

Please open an issue with the annotation, the widget's constructor and the
error: <https://github.com/itsarvinddev/auto_go_route/issues>.

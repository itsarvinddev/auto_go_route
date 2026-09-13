## 2.0.0

A breaking release. See **[MIGRATION.md](MIGRATION.md)** for a step-by-step
guide; most apps need a dependency bump, one annotation rename and typed
navigation arguments.

### Fixed

- **The build no longer hangs or dies on modern Dart.** The generator pinned
  `analyzer: ^7.0.0`, whose supported language version is 3.9.0, so on Dart
  3.10+ it failed with
  `Missing implementation of visitDotShorthandPropertyAccess`. The analyzer
  constraint is now `>=8.2.0 <15.0.0`, and a regression test builds a fixture
  using post-3.9 syntax
  ([#3](https://github.com/itsarvinddev/auto_go_route/issues/3)).
- **A `parent:` cycle is reported instead of hanging.** The parent chain was
  walked with no visited set, so a widget naming itself — or any two naming
  each other — spun forever inside the build step.
- **`context.pushNamed(...)` compiles again.** A 1.x extension member collided
  with go_router's, making every call site that imported both packages fail
  with `ambiguous_extension_member_access`. The method also recursed into
  itself. Removed.
- **Optional path parameters no longer produce unreachable routes.**
  `:id?` registered the literal pattern `/search/:$1`; it is now a build error
  naming the two things that do work.
- **Parameter values are no longer corrupted or fabricated.** A parameter name
  that prefixed another (`:id` and `:idCard`) silently produced
  `/user/5/card/5Card`; the required-parameter regex backtracked, so every
  optional parameter also generated a truncated phantom sibling; and
  `getParam<int>` returned `0` for a missing value while `getParam<int?>` threw
  for a present one.
- **A shell's `initialRoute` is honoured on every shell**, not only the root
  one, and a stateful shell's branches now receive an `initialLocation` — a
  nested shell as a branch previously landed outside itself.
- **The root shell is no longer emitted twice.** Removal matched a string in
  the generated source that only the stateful branch produced, so a plain or
  `pageBuilder` root shell was duplicated and go_router rejected the result.
- **Generated output is deterministic.** Asset discovery order is unspecified
  and sibling sorting was not total, so match precedence and stateful-shell
  branch indices could permute between builds.
- **A resolution failure is fatal.** Errors during discovery went to
  `log.info`, below default verbosity, so the build "succeeded" with routes
  missing.
- `toBoolOrNull` returns `null` for unrecognised input; `?admin=no` read as
  `true`.
- `RouteRegistry.generateGoRoutes(globalRedirect:)` composes rather than
  overwrites `GoRoute.redirect`, which had been silently deleting every route's
  guard; `validate()` accepts the shapes the generator emits; and
  `GoRoute.copyWith` forwards all ten fields instead of dropping five.
- `@AutoGoRoute(caseSensitive:)` is now `bool?` and overrides the router-wide
  default; the two were ANDed, so a route could not opt back in.
- `RoutePaths.props` excludes the `builder` closure, so two instances of a
  route are equal and hash stably.
- `currentRouteName` returns a route's name rather than its matched location,
  which had made `isOnNamedRoute` always false.
- `popUntilRoute` compared a URL against a template and popped the whole stack;
  `popUntilLocation` compares matched locations and is bounded.
- `RouteUtils.isValidPath` accepted no parameterised path at all; `sanitizePath`
  lower-cased, changing which route a URL matches under go_router 15+.
- `AdaptiveOverlayPage` separates `backgroundColor` from `barrierColor`, honours
  its configuration on the dialog branch, closes over its child instead of
  casting `ModalRoute.of(context)!.settings`, and takes a `breakpoint`.
- Route names are validated as Dart identifiers and for uniqueness after
  capitalisation; descriptions are escaped; duplicated path parameters, `metadata`
  values that cannot be re-emitted, and conflicting error handlers are all build
  errors now.
- Every function, key and constant an annotation names by string is resolved
  against the router library at build time, so a typo is reported at the
  annotation rather than as `Undefined name` inside the generated file.
- Removed `documentation:` from `pubspec.yaml`, which pointed at an unrelated
  package, and the `build_runner`/generator `dev_dependencies`, which this
  package does not use and which put the lowest supported Flutter out of reach
  of `pub get`.
- `currentLocation`, `currentRouteName`, `currentRouteTemplate`, `isOnRoute`
  and `popUntilLocation` follow imperative pushes to the visible route instead
  of reporting the one underneath.
- A stateful shell's `metadata` reaches its children. `StatefulShellRoute`'s
  `indexedStack` constructor has no `metadata` parameter, so it was dropped;
  shells now use the general constructor with an equivalent layout, exposed as
  `ShellRoutePaths.indexedStackContainerBuilder`.
- Animated pages and `AdaptiveOverlayPage` no longer crash outside a
  `MaterialApp` when a dismissible barrier needs a label.
- `RouteUtils.normalizePath` no longer drops the first segment of a location
  starting `//`; `isValidTemplate` accepts regex constraints containing `?` or
  `#`; `GoRoute.copyWith` accepts go_router's own `ExitCallback`;
  `getParam<dynamic>` returns the raw string instead of throwing.

### Added

- **Typed path and query parameters end to end.** `String`, `int`, `double`,
  `num`, `bool`, `BigInt`, `DateTime`, `Uri` and enums, nullable or not, plus
  `List<T>` for repeated query keys. Backed by the new public `RouteCodec`.
- **`@PathParam`, `@QueryParam`, `@RouteExtra`, `@RouteIgnore`** to override
  classification or rename a wire parameter. Markers are read from the backing
  field as well as the constructor parameter.
- **Full go_router parity.** New on `@AutoGoRoute`: `redirect`, `onExit`,
  `parentNavigatorKey`, `caseSensitive`, `metadata`, `pageBuilder`,
  `transition`, `transitionDurationMs`, `reverseTransitionDurationMs`,
  `fullscreenDialog`, `opaque`, `barrierDismissible`, `barrierColor`,
  `restorationId`. New on `@AutoGoRouteShell`: `middleware`, `redirect`,
  `parentNavigatorKey`, `metadata`, `observers`, `restorationScopeId`,
  `notifyRootObserver`, `navigatorContainerBuilder`. New on
  `@AutoGoRouteBase`: `navigatorKey`, `initialExtra`, `errorPageBuilder`,
  `errorWidget`, `onException`, `onEnter`, `observers`, `refreshListenable`,
  `extraCodec`, `redirectLimit`, `routerNeglect`, `debugLogDiagnostics`,
  `overridePlatformDefaultLocation`, `requestFocus`, `restorationScopeId`,
  `caseSensitive`, `generateRouteEnum`.
- **`@AutoGoRouteBranch`** for `preload`, `initialLocation`, `navigatorKey`,
  `observers` and `restorationScopeId` on a stateful shell's branches — declared
  on the child, where branch identity actually lives.
- **`buildRouter({...})` takes every `GoRouter` option**, defaulting to the
  annotation, and the route tree is public as `routes`. The package's own
  example no longer needs to hand-roll a `GoRouter`.
- **`AutoRouteTransition`** with nine presets and a public
  `buildAutoRoutePage()` so custom page builders can reuse them.
- **Generated conveniences**: `locationOf…` (build a URL without navigating),
  `replaceInPlaceWith…` (go_router's `replace`), `fragment:` on every helper,
  `routeName`/`routeTemplate` constants per route, and an `AppRoute` enum of
  every route.
- `state.metadataAs<T>()`, `getEnumParam`, `getParamList`, `extraAs<T>`, and
  `RouteParamFormatException`, which names the parameter, the expected type and
  the raw value.
- **Dynamic routing**: generated `buildRoutingConfig()` and
  `buildDynamicRouter(routingConfig:)` wrap `GoRouter.routingConfig`, so the
  route table can change at runtime while every other option keeps its
  annotation default.
- **Branch enums**: every stateful shell gets a `<Shell>Branch` enum in tab
  order, with `go`, `goFrom(context)`, `of` and `isActiveIn` — no more bare
  `goBranch(1)` indices drifting when `order:` changes.
- The barrel re-exports `go_router` and the handful of Flutter types generated
  code names (`BuildContext`, `GlobalKey`, `ValueListenable`, …), so a router
  library needs only `import 'package:auto_go_route/auto_go_route.dart'`.
- A `source_globs` build option to narrow the annotation scan, and
  `@AutoGoRouteBase(sourceGlobs:)` to scope one router in a package with
  several.
- `RouteCodec` list readers for every scalar type (`boolList`, `numList`,
  `bigIntList`, `dateTimeList`, `uriList`), and `RouteRegistry.findClosest`
  now treats path parameters as wildcards and credits near-miss typos.
- Every 1.x navigation helper removed from the API (`safePop`, `popOrHome`,
  `canPopSafely`, `goWithParams`, `goToNamed`, `popUntilRoute`,
  `GoRouter.location`, `safeLocation`, `safeCurrentRouteName`) is back as a
  deprecated shim over its replacement.
- **328 tests** across the runtime (198), the generator (98) and the example
  app (32), and a CI workflow covering the Flutter floor, both ends of the
  generator's dependency range, four platform builds, codegen drift and
  `pub publish --dry-run`.
- **AI assistant support**: an [`llms.txt`](llms.txt) brief ships with the
  package, and the README has copy-paste prompts for setting the package up,
  converting a go_router configuration, upgrading from 1.x, adding screens,
  guards and bottom navigation, and fixing build errors.
- **Documentation**: a restructured README with a table of contents, a
  screenshot gallery, collapsible reference sections and troubleshooting, plus
  [MIGRATION.md](MIGRATION.md) and [CONTRIBUTING.md](CONTRIBUTING.md). The
  example app was redesigned to show the live URL and decoded parameters on
  every screen, and its screenshots are the package's pub.dev gallery.

### Changed

- Requires `go_router >=17.5.0 <19.0.0`, Flutter `>=3.38.0`, Dart `>=3.10.0`.
  The old floor (`go_router: ^16.2.4` with `flutter: ">=3.0.0"`) was never
  satisfiable.
- The annotation scan skips libraries whose source does not mention
  `AutoGoRoute` before resolving them, which is most of the build cost on a
  large package; `required_inputs: ['.dart']` is gone, so this builder no
  longer runs behind every other Dart generator.
- `NestedRoutePaths` joins paths with go_router's own algorithm, so the URL it
  builds is the URL go_router matches.
- `RouteRegistry.scoped()` creates an isolated registry; `RouteRegistry()`
  still returns the singleton.
- Guard chains stay synchronous when their guards are, so a guarded route no
  longer defers navigation by a frame.

## 1.1.0

- Dependency updates.

## 1.0.9

- Add support for analyzer 7.0.0.

## 1.0.8

- Add support for pageBuilder.
- Enhance routing capabilities with new bottom sheet navigation features

## 1.0.7

- Add support for extra parameters.
- Fix nested routes.

## 1.0.6

- Enhance routing capabilities with new profile, settings, and notifications tabs; refactor ProfileRoute to use a tabbed interface.

## 1.0.5

- Fix pushRoute and pushToRoute methods to return Future<T?> instead of void.

## 1.0.4

- Fix redirect condition in AutoGoRouteGenerator to use fullPath instead of matchedLocation for accurate routing behavior.

## 1.0.3

- Queries are now optional.

## 1.0.2

- Added support for query parameters.

## 1.0.1

- Added support for middleware.
- Fixed some bugs.

## 1.0.0

- Initial release.

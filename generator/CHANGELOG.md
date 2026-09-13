## 2.0.0

Matches `auto_go_route` 2.0.0. See the
[migration guide](https://github.com/itsarvinddev/auto_go_route/blob/main/MIGRATION.md).

### Fixed

- **`analyzer` is no longer pinned to `^7.0.0`.** That constraint's supported
  language version is 3.9.0, so on Dart 3.10+ every build failed with
  `Missing implementation of visitDotShorthandPropertyAccess`. The range is now
  `>=8.2.0 <15.0.0`, migrated off the retired `element2.dart` element model, and
  a regression test builds a fixture using post-3.9 syntax
  ([#3](https://github.com/itsarvinddev/auto_go_route/issues/3)).
- A `parent:` cycle is reported as a build error instead of spinning forever.
- The whole-package annotation scan now filters on source text before resolving
  a library, and runs once rather than twice.
- `required_inputs: ['.dart']` removed — it forced this builder to wait behind
  every other Dart generator and pulled generated libraries into its own scan.
- Discovery failures are fatal instead of logged below default verbosity.
- Output is byte-stable: assets are visited in sorted order and sibling sorting
  is total.
- The graph is keyed on `library#ClassName`, so same-named widgets in different
  libraries no longer collide.
- `@AutoGoRouteBase` defaults are read through top-level getters outside
  `buildRouter`, whose parameters share their names — `onEnter: 'onEnter'`
  emitted `onEnter: onEnter ?? onEnter` and lost the default.
- Generated helpers call through `this`, so a parameter named `location`, `go`
  or `push` no longer shadows the method it forwards to.
- Redirects from a shell's own path are emitted before pattern routes that
  would otherwise swallow them, are skipped over a real route at the same path,
  default to the shell's first child, and the root-shell redirect no longer
  shadows a route declared at `/`.
- A root stateful shell's `/` redirect honours the first branch's
  `@AutoGoRouteBranch(initialLocation:)`; a first branch whose route takes path
  parameters used to be skipped, landing `/` on the second tab.
- A router library outside `lib/` also scans its own top-level directory.
- The `source_gen` floor is 4.1.1, the first release with
  `TypeChecker.typeNamedLiterally`; 4.0.1 could not compile the generator.
- The `glob` floor is 2.2.0. Under 2.1.3, `lib/**/*.dart` matched no file
  directly inside `lib/`, so routes declared there were silently missing.

### Added

- Typed parameter generation driven by the widget's declared types, with
  `@PathParam` / `@QueryParam` / `@RouteExtra` / `@RouteIgnore` overrides read
  from the field as well as the parameter.
- Full go_router parity across all four annotations, a `buildRouter` that
  accepts every `GoRouter` option, and generated `locationOf…`,
  `replaceInPlaceWith…`, `routeName`, `routeTemplate` and route-enum output.
- Build-time validation with actionable messages: unresolvable function
  references, non-identifier route names, colliding helper names, duplicated or
  optional path parameters, two `extra` parameters, a required query parameter
  with no default, conflicting error handlers, and `metadata` values that cannot
  be re-emitted as source.
- More build errors, each of which previously produced uncompilable code or a
  startup assertion: a shell with no children, `navigatorKey`/`observers` on a
  stateful shell, a branch with no parameter-free landing route, a nested
  shell's `initialRoute` outside its branch, parameters named `queries`,
  `fragment` or `extra`, enum-reserved route names, and an annotated widget or
  parameter type not visible from the router library.
- A `source_globs` builder option, `@AutoGoRouteBase(sourceGlobs:)`, and a
  warning when two unscoped routers share a package (detected on the resolved
  annotation, so a comment mentioning it does not trigger it).
- Generated `buildRoutingConfig()` / `buildDynamicRouter()` for dynamic routing,
  and a branch enum per stateful shell.
- `List<bool>`, `List<num>`, `List<BigInt>`, `List<DateTime>` and `List<Uri>`
  query parameters.
- 99 tests covering emitted output, every build error, determinism, and a check
  that the resolved analyzer keeps up with the SDK's language version.

### Changed

- Requires Dart `>=3.10.0`. Dropped the `code_builder` and `dart_style`
  dependencies: output is emitted as plain source and formatted by
  `PartBuilder` with the input library's own language version.

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

- Add support for shell routes.

## 1.0.5

- Fix pushRoute and pushToRoute methods to return Future<T?> instead of void.

## 1.0.4

- Fix redirect condition in AutoGoRouteGenerator to use fullPath instead of matchedLocation for accurate routing behavior.

## 1.0.3

- Queries are now optional.

## 1.0.2

- Added support for query parameters.

## 1.0.1

- Fixed some bugs.

## 1.0.0

- Initial release.
